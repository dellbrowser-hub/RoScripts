-- RenHub Fisch
-- Rebuilt from the updated Fisch automation while retaining RenLib and the safe FPS booster.
-- Fishing methods are intentionally unchanged: held primary input, live shake button,
-- live reel-controller state patching, and a sell-all-only remote lookup.

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G
local SINGLETON_KEY = "__RENHUB_FISCH"

local previous = env[SINGLETON_KEY]
if type(previous) == "table" and type(previous.Unload) == "function" then
    pcall(previous.Unload)
end

local Runtime = {
    alive = true,
    connections = {},
    version = "2.0.0-renhub",
}
env[SINGLETON_KEY] = Runtime

local State = {
    autoEquip = true,
    autoCast = false,
    autoShake = false,
    autoReel = false,
    autoSell = false,
    fastCast = false,
    perfectCast = true,
    castInterval = 2,
    shakeInterval = 0.12,
    sellInterval = 300,
}

local statusControl
local lastStatus
local RenLib
local controls = {}
local syncingCastMode = false
local unloadingLibrary = false

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    Runtime.connections[#Runtime.connections + 1] = connection
    return connection
end

local function setStatus(message)
    message = tostring(message)
    if message == lastStatus then
        return
    end
    lastStatus = message
    if statusControl and statusControl.SetContent then
        pcall(statusControl.SetContent, statusControl, message)
    end
end

local logLines = {}
local function log(message)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(message))
    logLines[#logLines + 1] = line
    if #logLines > 100 then
        table.remove(logLines, 1)
    end
    warn("[RenHub Fisch] " .. tostring(message))
end

local function normalize(value)
    return string.lower(tostring(value)):gsub("[^%w]", "")
end

local function fullName(instance)
    local ok, value = pcall(instance.GetFullName, instance)
    return ok and value or tostring(instance)
end

local remoteCache = {}
local function findRemote(names, allowContains)
    local wanted = {}
    for _, name in ipairs(names) do
        wanted[normalize(name)] = true
    end

    local cacheKey = table.concat(names, "|") .. tostring(allowContains)
    local cached = remoteCache[cacheKey]
    if cached and cached.Parent then
        return cached
    end

    local partial
    for _, item in ipairs(ReplicatedStorage:GetDescendants()) do
        if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
            local itemName = normalize(item.Name)
            if wanted[itemName] then
                remoteCache[cacheKey] = item
                log("resolved remote: " .. fullName(item))
                return item
            end
            if allowContains and not partial then
                for candidate in pairs(wanted) do
                    if string.find(itemName, candidate, 1, true) then
                        partial = item
                        break
                    end
                end
            end
        end
    end

    if partial then
        remoteCache[cacheKey] = partial
        log("resolved partial remote: " .. fullName(partial))
    end
    return partial
end

local function callRemote(remote, ...)
    if not remote then
        return false, "remote not found"
    end

    local args = table.pack(...)
    local ok, result = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
            return true
        end
        remote:InvokeServer(table.unpack(args, 1, args.n))
        return true
    end)
    return ok, result
end

local function character()
    return player.Character
end

local function humanoid()
    local currentCharacter = character()
    return currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
end

-- Rod checks are cached weakly because tool contents do not change during normal use.
local rodTypeCache = setmetatable({}, { __mode = "k" })
local function isRod(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end

    local cached = rodTypeCache[tool]
    if cached ~= nil then
        return cached
    end

    for _, item in ipairs(tool:GetDescendants()) do
        if (item:IsA("RemoteEvent") or item:IsA("RemoteFunction")) and normalize(item.Name) == "cast" then
            rodTypeCache[tool] = true
            return true
        end
    end

    local result = string.find(normalize(tool.Name), "rod", 1, true) ~= nil
    -- Cache only positive classifications so a tool populated after discovery
    -- is still eligible on the next check.
    if result then
        rodTypeCache[tool] = true
    end
    return result
end

local function equippedRod()
    local currentCharacter = character()
    if not currentCharacter then
        return nil
    end
    for _, child in ipairs(currentCharacter:GetChildren()) do
        if isRod(child) then
            return child
        end
    end
end

local function backpackRod()
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        return nil
    end

    local fallback
    for _, child in ipairs(backpack:GetChildren()) do
        if child:IsA("Tool") then
            if isRod(child) then
                return child
            end
            fallback = fallback or child
        end
    end
    return fallback
end

local function equipRod()
    local rod = equippedRod()
    if rod then
        return rod
    end

    rod = backpackRod()
    local currentHumanoid = humanoid()
    if rod and currentHumanoid then
        local ok = pcall(currentHumanoid.EquipTool, currentHumanoid, rod)
        if ok then
            log("equipped: " .. rod.Name)
            task.wait(0.2)
            return equippedRod() or rod
        end
    end
    return nil
end

local primaryInputDown = false
local function setPrimaryInput(down)
    if primaryInputDown == down then
        return true
    end

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(2, 2)
    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(
            viewport.X / 2,
            viewport.Y / 2,
            0,
            down,
            game,
            0
        )
    end)
    if ok then
        primaryInputDown = down
    end
    return ok
end

local function hasBobber(rod)
    if not rod then
        return false
    end

    for _, item in ipairs(rod:GetDescendants()) do
        local itemName = normalize(item.Name)
        if itemName == "bobber" or itemName == "float" then
            return true
        end
    end

    local currentCharacter = character()
    if currentCharacter then
        for _, item in ipairs(currentCharacter:GetDescendants()) do
            if normalize(item.Name) == "bobber" then
                return true
            end
        end
    end
    return false
end

local function castPowerBar()
    local currentCharacter = character()
    if not currentCharacter then
        return nil
    end

    for _, item in ipairs(currentCharacter:GetDescendants()) do
        if item:IsA("GuiObject") and normalize(item.Name) == "bar" then
            local parent = item.Parent
            local grandparent = parent and parent.Parent
            local parentName = parent and normalize(parent.Name) or ""
            local grandparentName = grandparent and normalize(grandparent.Name) or ""
            if parentName == "powerbar" or grandparentName == "powerbar" then
                return item
            end
        end
    end
end

local casting = false
local castSequence = 0

local function cancelCast()
    castSequence += 1
    casting = false
    setPrimaryInput(false)
end

-- Both modes use the updated script's held-primary-input method.
-- Fast Cast keeps its old behavior: release when the visible charge bar appears,
-- with the old short fallback when the bar cannot be found.
-- Perfect Cast holds that same input for exactly 3 seconds.
local function cast()
    if casting then
        return false, "cast already in progress"
    end

    local rod = equippedRod() or (State.autoEquip and equipRod())
    if not rod then
        return false, "no rod found"
    end

    casting = true
    castSequence += 1
    local token = castSequence
    local mode = State.fastCast and "Fast Cast" or "Perfect Cast"

    if not setPrimaryInput(true) then
        casting = false
        return false, "primary input unavailable"
    end

    if mode == "Fast Cast" then
        local started = os.clock()
        repeat
            task.wait(0.01)
        until castPowerBar()
            or os.clock() - started >= 0.15
            or token ~= castSequence
            or not Runtime.alive
            or not State.autoCast
    else
        local releaseAt = os.clock() + 3
        repeat
            task.wait(math.min(0.05, math.max(0, releaseAt - os.clock())))
        until os.clock() >= releaseAt
            or token ~= castSequence
            or not Runtime.alive
            or not State.autoCast
    end

    local cancelled = token ~= castSequence
        or not Runtime.alive
        or not State.autoCast

    setPrimaryInput(false)
    casting = false

    if cancelled then
        return false, "cast cancelled"
    end
    return true, mode
end

local cachedShakeButton
local nextShakeScan = 0

local function isVisible(object)
    if not object or not object.Parent then
        return false
    end
    if object:IsA("GuiObject") then
        return object.Visible
    end
    if object:IsA("LayerCollector") then
        return object.Enabled
    end
    return true
end

local function isHierarchyVisible(object)
    local current = object
    while current and current ~= playerGui do
        if not isVisible(current) then
            return false
        end
        current = current.Parent
    end
    return current == playerGui
end

local function isShakeButton(button)
    if not button or not button:IsA("GuiButton") or not isHierarchyVisible(button) then
        return false
    end

    local current = button
    while current and current ~= playerGui do
        if string.find(normalize(current.Name), "shake", 1, true) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function shakeButton(now)
    if cachedShakeButton and cachedShakeButton.Parent and isHierarchyVisible(cachedShakeButton) then
        return cachedShakeButton
    end
    cachedShakeButton = nil

    now = now or os.clock()
    if now < nextShakeScan then
        return nil
    end
    nextShakeScan = now + 0.2

    for _, item in ipairs(playerGui:GetDescendants()) do
        if isShakeButton(item) then
            cachedShakeButton = item
            return item
        end
    end
end

local function clickGuiButton(button)
    if not button then
        return false
    end

    if type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(button.Activated)
            firesignal(button.MouseButton1Click)
        end)
        if ok then
            return true
        end
    end

    local ok = pcall(function()
        GuiService.SelectedObject = button
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        GuiService.SelectedObject = nil
    end)
    if ok then
        return true
    end

    local center = button.AbsolutePosition + (button.AbsoluteSize / 2)
    return pcall(function()
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)
end

connect(playerGui.DescendantAdded, function(descendant)
    if Runtime.alive and State.autoShake and isShakeButton(descendant) then
        cachedShakeButton = descendant
        nextShakeScan = 0
    end
end)

connect(playerGui.DescendantRemoving, function(descendant)
    if descendant == cachedShakeButton then
        cachedShakeButton = nil
        nextShakeScan = 0
    end
end)

-- BlackHub's reel is not an instant-finish call.  The reel LocalScript keeps
-- the effective player-bar/hitbox width in Lua state, so changing GuiObject.Size
-- alone is only cosmetic.  Patch the live controller values and let the game's
-- ordinary reel loop do all progress and completion work.
local reelPlayerGui = player:WaitForChild("PlayerGui")
local reelPatch = {
    reel = nil,
    changes = {},
    tableSlots = setmetatable({}, {__mode = "k"}),
    functionSlots = setmetatable({}, {__mode = "k"}),
    applied = 0,
    attempts = 0,
    lastScan = 0,
    reported = false,
}

local debugLibrary = type(debug) == "table" and debug or nil
local getUpvalues = debugLibrary and debugLibrary.getupvalues or getupvalues
local setUpvalue = debugLibrary and debugLibrary.setupvalue or setupvalue
local getConstants = debugLibrary and debugLibrary.getconstants or getconstants
local getEnvironment = getfenv
local getGarbage = getgc
local getConnections = getconnections
local getScriptEnvironment = getsenv

local INTERNAL_SIZE_KEYS = {
    control = true,
    barsize = true,
    barwidth = true,
    playerbarsize = true,
    playerbarwidth = true,
    reelbarsize = true,
    reelbarwidth = true,
    controlbarsize = true,
    controlbarwidth = true,
    hitboxsize = true,
    hitboxwidth = true,
    reelhitboxsize = true,
    reelhitboxwidth = true,
}

local function clearReelPatchBookkeeping()
    reelPatch.reel = nil
    table.clear(reelPatch.changes)
    reelPatch.tableSlots = setmetatable({}, {__mode = "k"})
    reelPatch.functionSlots = setmetatable({}, {__mode = "k"})
    reelPatch.applied = 0
    reelPatch.attempts = 0
    reelPatch.lastScan = 0
    reelPatch.reported = false
end

local function restoreReelControl()
    for index = #reelPatch.changes, 1, -1 do
        local change = reelPatch.changes[index]
        if change.kind == "table" then
            pcall(function() change.target[change.key] = change.original end)
        elseif change.kind == "upvalue" and type(setUpvalue) == "function" then
            pcall(setUpvalue, change.target, change.key, change.original)
        end
    end
    clearReelPatchBookkeeping()
end

local function rememberTableValue(target, key, desired)
    local slots = reelPatch.tableSlots[target]
    if not slots then
        slots = {}
        reelPatch.tableSlots[target] = slots
    end
    local change = slots[key]
    if not change then
        change = {kind = "table", target = target, key = key, original = target[key], desired = desired}
        slots[key] = change
        reelPatch.changes[#reelPatch.changes + 1] = change
        reelPatch.applied = reelPatch.applied + 1
    else
        change.desired = desired
    end
    pcall(function() target[key] = desired end)
end

local function rememberUpvalue(target, key, original, desired)
    if type(setUpvalue) ~= "function" or type(key) ~= "number" then return end
    local slots = reelPatch.functionSlots[target]
    if not slots then
        slots = {}
        reelPatch.functionSlots[target] = slots
    end
    local change = slots[key]
    if not change then
        change = {kind = "upvalue", target = target, key = key, original = original, desired = desired}
        slots[key] = change
        reelPatch.changes[#reelPatch.changes + 1] = change
        reelPatch.applied = reelPatch.applied + 1
    else
        change.desired = desired
    end
    pcall(setUpvalue, target, key, desired)
end

local function enforceRememberedReelValues()
    for _, change in ipairs(reelPatch.changes) do
        if change.kind == "table" then
            pcall(function()
                if change.target[change.key] ~= change.desired then
                    change.target[change.key] = change.desired
                end
            end)
        elseif change.kind == "upvalue" and type(setUpvalue) == "function" then
            pcall(setUpvalue, change.target, change.key, change.desired)
        end
    end
end

local function readUpvalues(callback)
    if type(getUpvalues) ~= "function" then return nil end
    local ok, values = pcall(getUpvalues, callback)
    return ok and type(values) == "table" and values or nil
end

local function valueContainsTarget(value, targets, depth, seen)
    if targets[value] then return true end
    if depth <= 0 or type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    local inspected = 0
    for key, child in pairs(value) do
        inspected = inspected + 1
        if inspected > 100 then break end
        if targets[key] or targets[child] then return true end
        if valueContainsTarget(child, targets, depth - 1, seen) then return true end
    end
    return false
end

local function matchingWidthNumber(value, widthScale, widthRatio)
    if type(value) ~= "number" or value <= 0 or value >= 0.99 then return false end
    local tolerance = math.max(0.002, math.abs(widthRatio) * 0.025)
    return (widthScale > 0.01 and math.abs(value - widthScale) <= tolerance)
        or math.abs(value - widthRatio) <= tolerance
end

local function internalMaxValue(value, keyName, metrics)
    local kind = typeof(value)
    if kind == "number" then
        if value >= 0 and value < 1.01 then return 1 end
    elseif kind == "UDim" then
        return UDim.new(1, 0)
    elseif kind == "UDim2" then
        return UDim2.new(1, 0, value.Y.Scale, value.Y.Offset)
    elseif kind == "Vector2" and metrics.barWidth > 0 then
        return Vector2.new(metrics.barWidth, value.Y)
    end
    return nil
end

local function patchNamedControllerTable(target, metrics, depth, seen)
    if type(target) ~= "table" or depth < 0 then return end
    seen = seen or {}
    if seen[target] then return end
    seen[target] = true
    local inspected = 0
    for key, value in pairs(target) do
        inspected = inspected + 1
        if inspected > 250 then break end
        if type(key) == "string" and INTERNAL_SIZE_KEYS[normalize(key)] then
            local desired = internalMaxValue(value, key, metrics)
            if desired ~= nil and desired ~= value then rememberTableValue(target, key, desired) end
        elseif matchingWidthNumber(value, metrics.widthScale, metrics.widthRatio) then
            rememberTableValue(target, key, 1)
        elseif typeof(value) == "UDim" and value == metrics.playerSize.X then
            rememberTableValue(target, key, UDim.new(1, 0))
        elseif typeof(value) == "UDim2" and value == metrics.playerSize then
            rememberTableValue(target, key, UDim2.new(1, 0, value.Y.Scale, value.Y.Offset))
        end
        if type(value) == "table" and depth > 0 then
            patchNamedControllerTable(value, metrics, depth - 1, seen)
        end
    end
end

local function reelOwnedScript(owner, reel)
    if typeof(owner) ~= "Instance" or not owner:IsA("LuaSourceContainer") then return false end
    if owner:IsDescendantOf(reel) then return true end
    if not owner:IsDescendantOf(reelPlayerGui) then return false end
    local name = normalize(owner.Name)
    return string.find(name, "reel", 1, true) ~= nil or string.find(name, "fish", 1, true) ~= nil
end

local function functionMentionsReel(callback)
    if type(getConstants) ~= "function" then return false end
    local ok, constants = pcall(getConstants, callback)
    if not ok or type(constants) ~= "table" then return false end
    for _, constant in pairs(constants) do
        if type(constant) == "string" then
            local name = normalize(constant)
            if name == "playerbar" or name == "reel" or name == "reelbar" then
                return true
            end
        end
    end
    return false
end

local function patchControllerFunction(callback, reel, bar, playerBar, metrics, allowTargetProbe)
    local relevant = functionMentionsReel(callback)
    if not relevant and type(getEnvironment) == "function" then
        local ok, environment = pcall(getEnvironment, callback)
        local owner = ok and type(environment) == "table" and rawget(environment, "script") or nil
        relevant = reelOwnedScript(owner, reel)
    end
    if not relevant and not allowTargetProbe then return end
    local values = readUpvalues(callback)
    if not values then return end
    if not relevant then
        local targets = {[reel] = true, [bar] = true, [playerBar] = true}
        for _, value in pairs(values) do
            if valueContainsTarget(value, targets, 2) then relevant = true break end
        end
    end
    if not relevant then return end

    for key, value in pairs(values) do
        if type(value) == "table" then
            patchNamedControllerTable(value, metrics, 3)
        elseif type(key) == "number" then
            local kind = typeof(value)
            if matchingWidthNumber(value, metrics.widthScale, metrics.widthRatio) then
                rememberUpvalue(callback, key, value, 1)
            elseif kind == "UDim" and value == metrics.playerSize.X then
                rememberUpvalue(callback, key, value, UDim.new(1, 0))
            elseif kind == "UDim2" and value == metrics.playerSize then
                rememberUpvalue(callback, key, value, UDim2.new(1, 0, value.Y.Scale, value.Y.Offset))
            elseif kind == "Vector2" and metrics.playerWidth > 0 and math.abs(value.X - metrics.playerWidth) <= 2 then
                rememberUpvalue(callback, key, value, Vector2.new(metrics.barWidth, value.Y))
            end
        end
    end
end

local function addCandidate(candidates, callback, allowTargetProbe)
    if type(callback) ~= "function" then return end
    if candidates[callback] == nil or allowTargetProbe then
        candidates[callback] = allowTargetProbe == true
    end
end

local function collectSignalCallbacks(candidates, signal)
    if type(getConnections) ~= "function" then return end
    local ok, connections = pcall(getConnections, signal)
    if not ok or type(connections) ~= "table" then return end
    for _, connection in ipairs(connections) do
        local callback
        pcall(function() callback = connection.Function or connection.Callback end)
        addCandidate(candidates, callback, true)
    end
end

local function patchInternalReelController(reel, bar, playerBar)
    if reelPatch.reel ~= reel then
        restoreReelControl()
        reelPatch.reel = reel
    end
    local now = os.clock()
    if reelPatch.applied > 0 then
        enforceRememberedReelValues()
        return true
    end
    if reelPatch.attempts >= 6 then return false end
    if now - reelPatch.lastScan < 0.25 then return false end
    reelPatch.lastScan = now
    reelPatch.attempts = reelPatch.attempts + 1

    local barWidth = bar.AbsoluteSize.X
    local playerWidth = playerBar.AbsoluteSize.X
    local widthScale = playerBar.Size.X.Scale
    local widthRatio = barWidth > 0 and playerWidth / barWidth or widthScale
    local metrics = {
        barWidth = barWidth,
        playerWidth = playerWidth,
        widthScale = widthScale,
        widthRatio = widthRatio,
        tolerance = math.max(0.002, math.abs(widthRatio) * 0.025),
        playerSize = playerBar.Size,
    }
    local candidates = {}

    collectSignalCallbacks(candidates, RunService.RenderStepped)
    collectSignalCallbacks(candidates, RunService.Heartbeat)
    pcall(function() collectSignalCallbacks(candidates, RunService.PreRender) end)

    if type(getScriptEnvironment) == "function" then
        for _, owner in ipairs(reelPlayerGui:GetDescendants()) do
            if owner:IsA("LocalScript") and reelOwnedScript(owner, reel) then
                local ok, environment = pcall(getScriptEnvironment, owner)
                if ok and type(environment) == "table" then
                    for _, value in pairs(environment) do addCandidate(candidates, value, true) end
                end
            end
        end
    end

    if type(getGarbage) == "function" and (reelPatch.attempts == 1 or reelPatch.attempts == 4) then
        local ok, objects = pcall(getGarbage, true)
        if ok and type(objects) == "table" then
            local targets = {[reel] = true, [bar] = true, [playerBar] = true}
            for index = 1, math.min(#objects, 12000) do
                local object = objects[index]
                if type(object) == "function" then
                    addCandidate(candidates, object, false)
                elseif type(object) == "table" and valueContainsTarget(object, targets, 2) then
                    patchNamedControllerTable(object, metrics, 3)
                end
            end
        end
    end

    for callback, allowTargetProbe in pairs(candidates) do
        patchControllerFunction(callback, reel, bar, playerBar, metrics, allowTargetProbe)
    end
    if reelPatch.applied > 0 and not reelPatch.reported then
        reelPatch.reported = true
        log("internal reel controller patched: " .. tostring(reelPatch.applied) .. " captured gameplay value(s)")
    end
    return reelPatch.applied > 0
end

local function normalReel(reelGui)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local reel = reelGui or (playerGui and playerGui:FindFirstChild("reel"))
    if not reel then
        if reelPatch.reel then restoreReelControl() end
        return false
    end
    if normalize(reel.Name) ~= "reel" or not reel:IsA("ScreenGui") then return false end
    local bar = reel:FindFirstChild("bar")
    local playerBar = bar and bar:FindFirstChild("playerbar")
    if bar and playerBar and playerBar:IsA("GuiObject") then
        patchInternalReelController(reel, bar, playerBar)
    end
    return true
end

connect(reelPlayerGui.ChildAdded, function(child)
    if Runtime.alive and State.autoReel then normalReel(child) end
end)

local function sellAll()
    -- Require a sell-all name so an arbitrary sell remote can never sell only the held item.
    local remote = findRemote({
        "sellall",
        "SellAll",
        "sellallfish",
        "SellAllFish",
        "sellallitems",
        "SellAllItems",
    }, true)
    if not remote then
        return false, "sell-all remote not found"
    end
    return callRemote(remote)
end

-- Reversible aggressive FPS booster. Every changed property is captured once
-- and restored when the toggle is disabled.
local fpsBoosterEnabled = false
local fpsBoostGeneration = 0
local fpsChanges = {}
local fpsSlots = {}
local fpsDescendantConnection
local previousFpsCap

local function setBoostProperty(target, property, desired)
    local slots = fpsSlots[target]
    if not slots then
        slots = {}
        fpsSlots[target] = slots
    end
    if slots[property] then
        pcall(function()
            target[property] = desired
        end)
        return
    end

    local ok, original = pcall(function()
        return target[property]
    end)
    if not ok or original == desired then
        return
    end

    local change = {
        target = target,
        property = property,
        original = original,
    }
    slots[property] = change
    fpsChanges[#fpsChanges + 1] = change
    pcall(function()
        target[property] = desired
    end)
end

local function reduceVisualCost(instance)
    if instance:IsA("BasePart") then
        setBoostProperty(instance, "CastShadow", false)
        setBoostProperty(instance, "Material", Enum.Material.SmoothPlastic)
        setBoostProperty(instance, "Reflectance", 0)
        if instance:IsA("MeshPart") then
            setBoostProperty(instance, "RenderFidelity", Enum.RenderFidelity.Performance)
            setBoostProperty(instance, "TextureID", "")
        end
    elseif instance:IsA("Decal") or instance:IsA("Texture") then
        setBoostProperty(instance, "Transparency", 1)
    elseif instance:IsA("ParticleEmitter")
        or instance:IsA("Trail")
        or instance:IsA("Beam")
        or instance:IsA("Smoke")
        or instance:IsA("Fire")
        or instance:IsA("Sparkles")
        or instance:IsA("PostEffect")
        or instance:IsA("PointLight")
        or instance:IsA("SpotLight")
        or instance:IsA("SurfaceLight")
        or instance:IsA("Highlight")
    then
        setBoostProperty(instance, "Enabled", false)
    elseif instance:IsA("Atmosphere") then
        setBoostProperty(instance, "Density", 0)
        setBoostProperty(instance, "Haze", 0)
        setBoostProperty(instance, "Glare", 0)
    elseif instance:IsA("Clouds") then
        setBoostProperty(instance, "Enabled", false)
        setBoostProperty(instance, "Cover", 0)
        setBoostProperty(instance, "Density", 0)
    elseif instance:IsA("Sky") then
        setBoostProperty(instance, "StarCount", 0)
        setBoostProperty(instance, "CelestialBodiesShown", false)
    elseif instance:IsA("Explosion") or instance:IsA("ForceField") then
        setBoostProperty(instance, "Visible", false)
    end
end

local function restoreFpsBooster()
    if fpsDescendantConnection then
        pcall(fpsDescendantConnection.Disconnect, fpsDescendantConnection)
        fpsDescendantConnection = nil
    end

    for index = #fpsChanges, 1, -1 do
        local change = fpsChanges[index]
        pcall(function()
            change.target[change.property] = change.original
        end)
    end
    table.clear(fpsChanges)
    table.clear(fpsSlots)

    if previousFpsCap and type(setfpscap) == "function" then
        pcall(setfpscap, previousFpsCap)
    end
    previousFpsCap = nil
end

local function setFpsBooster(value, silent)
    value = value == true
    if value == fpsBoosterEnabled then
        return
    end

    fpsBoosterEnabled = value
    fpsBoostGeneration += 1
    local generation = fpsBoostGeneration

    if not value then
        restoreFpsBooster()
        if not silent then
            setStatus("FPS booster disabled and visuals restored")
        end
        return
    end

    setStatus("Applying aggressive FPS booster...")

    local rendering = settings().Rendering
    setBoostProperty(rendering, "QualityLevel", Enum.QualityLevel.Level01)

    local lighting = game:GetService("Lighting")
    setBoostProperty(lighting, "GlobalShadows", false)
    setBoostProperty(lighting, "EnvironmentDiffuseScale", 0)
    setBoostProperty(lighting, "EnvironmentSpecularScale", 0)
    pcall(function()
        setBoostProperty(lighting, "Technology", Enum.Technology.Compatibility)
    end)

    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        setBoostProperty(terrain, "Decoration", false)
        setBoostProperty(terrain, "WaterWaveSize", 0)
        setBoostProperty(terrain, "WaterWaveSpeed", 0)
        setBoostProperty(terrain, "WaterReflectance", 0)
        setBoostProperty(terrain, "WaterTransparency", 1)
    end
    setBoostProperty(workspace, "GlobalWind", Vector3.zero)

    if type(getfpscap) == "function" and type(setfpscap) == "function" then
        local ok, cap = pcall(getfpscap)
        if ok and type(cap) == "number" then
            previousFpsCap = cap
            pcall(setfpscap, math.max(cap, 240))
        end
    end

    fpsDescendantConnection = game.DescendantAdded:Connect(function(instance)
        if fpsBoosterEnabled
            and (instance:IsDescendantOf(workspace) or instance:IsDescendantOf(lighting))
        then
            reduceVisualCost(instance)
        end
    end)

    task.spawn(function()
        local descendants = workspace:GetDescendants()
        for _, instance in ipairs(lighting:GetDescendants()) do
            descendants[#descendants + 1] = instance
        end
        for index, instance in ipairs(descendants) do
            if not Runtime.alive
                or not fpsBoosterEnabled
                or generation ~= fpsBoostGeneration
            then
                return
            end
            reduceVisualCost(instance)
            if index % 300 == 0 then
                task.wait()
            end
        end
        table.clear(descendants)
        if fpsBoosterEnabled and generation == fpsBoostGeneration then
            setStatus("Aggressive FPS booster active")
        end
    end)
end

local function setOption(key, value)
    State[key] = value == true

    if key == "autoCast" and not State.autoCast then
        cancelCast()
    end
    if key == "autoShake" and not State.autoShake then
        cachedShakeButton = nil
    end
    if key == "autoReel" and not State.autoReel then
        restoreReelControl()
    end

    setStatus(key .. ": " .. (State[key] and "ON" or "OFF"))
end

local function syncCastControls()
    if syncingCastMode then
        return
    end
    syncingCastMode = true

    local fastControl = controls.FastCast
    local perfectControl = controls.PerfectCast
    if fastControl and fastControl.Get and fastControl.Set
        and fastControl:Get() ~= State.fastCast
    then
        fastControl:Set(State.fastCast)
    end
    if perfectControl and perfectControl.Get and perfectControl.Set
        and perfectControl:Get() ~= State.perfectCast
    then
        perfectControl:Set(State.perfectCast)
    end

    syncingCastMode = false
end

local function selectCastMode(mode)
    State.fastCast = mode == "Fast Cast"
    State.perfectCast = not State.fastCast
    syncCastControls()
    setStatus("Cast mode: " .. mode)
end

local function onFastCast(value)
    if syncingCastMode then
        return
    end
    if value then
        selectCastMode("Fast Cast")
    elseif State.fastCast then
        selectCastMode("Perfect Cast")
    else
        syncCastControls()
    end
end

local function onPerfectCast(value)
    if syncingCastMode then
        return
    end
    if value then
        selectCastMode("Perfect Cast")
    elseif State.perfectCast then
        selectCastMode("Fast Cast")
    else
        syncCastControls()
    end
end

local function loadRenLib()
    local source = game:HttpGet(
        "https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"
    )
    local chunk, compileError = loadstring(source)
    if not chunk then
        error("RenLib compile failed: " .. tostring(compileError))
    end
    return chunk()
end

local okLibrary, libraryOrError = pcall(loadRenLib)
if not okLibrary then
    Runtime.alive = false
    env[SINGLETON_KEY] = nil
    error("Could not load RenLib: " .. tostring(libraryOrError))
end
RenLib = libraryOrError

local Window = RenLib:CreateWindow({
    Name = "RenHub | Fisch",
    Width = 860,
    Height = 560,
    DisplayOrder = 1000,
    ShowUserProfile = true,
    ProfileUserId = player.UserId,
    ProfileSubtitle = "Updated fishing automation",
    ShowInfiniteYield = false,
    EnableGlobalSearch = false,
    EnableSidebarResize = true,
    SidebarMode = "Dynamic",
    MaterialMode = "Solid",
})

local FishingTab = Window:CreateTab({
    Name = "Fishing",
    Icon = RenLib.Icons.Play,
})

local AutomationSection = FishingTab:CreateSection({
    Name = "Automation",
    Side = "Left",
    Icon = RenLib.Icons.Play,
})

local CastSection = FishingTab:CreateSection({
    Name = "Casting",
    Side = "Right",
    Icon = RenLib.Icons.Star or RenLib.Icons.Play,
})

local SellingSection = FishingTab:CreateSection({
    Name = "Selling",
    Side = "Left",
    Icon = RenLib.Icons.Star or RenLib.Icons.Info,
})

local UtilitySection = FishingTab:CreateSection({
    Name = "Utilities",
    Side = "Right",
    Icon = RenLib.Icons.Terminal or RenLib.Icons.Info,
})

controls.AutoEquip = AutomationSection:CreateToggle({
    Name = "Auto Equip Rod",
    Flag = "RenHubFischAutoEquip",
    Default = true,
    Callback = function(value)
        setOption("autoEquip", value)
    end,
})

controls.AutoCast = AutomationSection:CreateToggle({
    Name = "Auto Cast",
    Flag = "RenHubFischAutoCast",
    Default = false,
    Callback = function(value)
        setOption("autoCast", value)
    end,
})

controls.AutoShake = AutomationSection:CreateToggle({
    Name = "Auto Shake",
    Flag = "RenHubFischAutoShake",
    Default = false,
    Callback = function(value)
        setOption("autoShake", value)
    end,
})

controls.AutoReel = AutomationSection:CreateToggle({
    Name = "Auto Reel",
    Flag = "RenHubFischAutoReel",
    Default = false,
    Tooltip = "Patches the live internal reel width and lets the normal game reel finish.",
    Callback = function(value)
        setOption("autoReel", value)
    end,
})

controls.FastCast = CastSection:CreateToggle({
    Name = "Fast Cast",
    Flag = "RenHubFischFastCast",
    Default = false,
    Tooltip = "Uses the old Fast Cast behavior: release when the visible charge bar appears, with a short fallback.",
    Callback = onFastCast,
})

controls.PerfectCast = CastSection:CreateToggle({
    Name = "Perfect Cast",
    Flag = "RenHubFischPerfectCast",
    Default = true,
    Tooltip = "Holds the same cast input for exactly 3 seconds, then releases.",
    Callback = onPerfectCast,
})

CastSection:CreateParagraph({
    Title = "Cast mode rule",
    Content = "Fast Cast and Perfect Cast are mutually exclusive. Turning either mode off automatically enables the other, so one mode is always active.",
})

controls.AutoSell = SellingSection:CreateToggle({
    Name = "Auto Sell Fish",
    Flag = "RenHubFischAutoSell",
    Default = false,
    Tooltip = "Uses only a verified sell-all remote.",
    Callback = function(value)
        setOption("autoSell", value)
    end,
})

SellingSection:CreateSlider({
    Name = "Sell Interval (seconds)",
    Flag = "RenHubFischSellInterval",
    Min = 30,
    Max = 3600,
    Step = 30,
    Default = State.sellInterval,
    Callback = function(value)
        State.sellInterval = value
    end,
})

SellingSection:CreateButton({
    Name = "Sell All Now",
    Callback = function()
        task.spawn(function()
            local ok, result = sellAll()
            if ok then
                setStatus("Sell-all request sent")
            else
                setStatus("Sell failed: " .. tostring(result))
                log("manual sell: " .. tostring(result))
            end
        end)
    end,
})

controls.FpsBooster = UtilitySection:CreateToggle({
    Name = "Aggressive FPS Booster",
    Flag = "RenHubFischFpsBooster",
    Default = false,
    Tooltip = "Reversibly reduces materials, textures, shadows, lights, effects, atmosphere, water, and render quality.",
    Callback = setFpsBooster,
})

UtilitySection:CreateParagraph({
    Title = "FPS booster",
    Content = "Aggressively lowers visual cost without deleting gameplay parts or changing collisions. Turning it off restores every captured property. Actual FPS gain depends on the device and current scene.",
})

statusControl = UtilitySection:CreateParagraph({
    Title = "Status",
    Content = "Ready",
})

UtilitySection:CreateParagraph({
    Title = "Optimizations",
    Content = "Independent fishing toggles, event-aware shake discovery, cached rod classification, bounded reel-controller scans, cached remotes, deduplicated status updates, and lifecycle-managed cleanup.",
})

-- Enforce the requested default after both controls exist.
selectCastMode("Perfect Cast")

function Runtime.Unload(fromLibrary)
    if not Runtime.alive then
        return
    end

    Runtime.alive = false
    cancelCast()
    restoreReelControl()
    if fpsBoosterEnabled then
        setFpsBooster(false, true)
    end

    for _, connection in ipairs(Runtime.connections) do
        pcall(connection.Disconnect, connection)
    end
    table.clear(Runtime.connections)

    if env[SINGLETON_KEY] == Runtime then
        env[SINGLETON_KEY] = nil
    end

    if not fromLibrary and RenLib and not RenLib.Unloaded and not unloadingLibrary then
        unloadingLibrary = true
        pcall(RenLib.Unload, RenLib, "Fisch automation stopped")
    end
end

RenLib:RegisterAddon("RenHubFischRuntime", {
    AutoStart = true,
    Start = function()
        setStatus("Ready - each automation toggle works independently")
    end,
    Stop = function() end,
    Unload = function()
        Runtime.Unload(true)
    end,
})

local nextCast = 0
local lastShake = 0
local nextSell = os.clock() + State.sellInterval
local lastError = ""

task.spawn(function()
    while Runtime.alive do
        local now = os.clock()

        if State.autoCast or State.autoShake or State.autoReel then
            local ok, result = pcall(function()
                local rod
                if State.autoCast then
                    rod = equippedRod()
                    if not rod and State.autoEquip then
                        rod = equipRod()
                    end
                end

                local reeling = State.autoReel and normalReel() or false
                local button = not reeling and State.autoShake and shakeButton(now) or nil

                if reeling then
                    setStatus(
                        reelPatch.applied > 0
                            and "Auto Reel: internal max bar active"
                            or "Auto Reel: finding controller"
                    )
                elseif button and now - lastShake >= State.shakeInterval then
                    lastShake = now
                    clickGuiButton(button)
                    setStatus("Auto Shake: activated")
                elseif State.autoCast and rod and now >= nextCast and not hasBobber(rod) then
                    local castOk, castMode = cast()
                    nextCast = os.clock() + State.castInterval
                    if castOk then
                        setStatus("Auto Cast: " .. castMode)
                    elseif castMode ~= "cast cancelled" then
                        error(castMode)
                    end
                end
            end)

            if not ok then
                local message = tostring(result)
                if message ~= lastError then
                    log("fishing automation: " .. message)
                    lastError = message
                end
                setStatus("Automation waiting: " .. message)
            else
                lastError = ""
            end
        end

        if State.autoSell and now >= nextSell then
            nextSell = now + State.sellInterval
            local ok, result = sellAll()
            if not ok then
                log("auto sell: " .. tostring(result))
            end
        elseif not State.autoSell then
            nextSell = now + State.sellInterval
        end

        task.wait(0.05)
    end
end)

log("started version " .. Runtime.version)
setStatus("Ready - each automation toggle works independently")
