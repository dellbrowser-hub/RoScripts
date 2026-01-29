pcall(function()
    if _G.BrainrotSniper then
        _G.BrainrotSniper.Active = false
        for _, c in pairs(_G.BrainrotSniper.Connections or {}) do pcall(function() c:Disconnect() end) end
        for _, t in pairs(_G.BrainrotSniper.Threads or {}) do pcall(function() task.cancel(t) end) end
    end
    for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
        if gui.Name == "BrainrotSniperV2" then gui:Destroy() end
    end
    for _, gui in pairs(game.Players.LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do
        if gui.Name == "BrainrotSniperV2" then gui:Destroy() end
    end
end)

task.wait(0.3)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

_G.BrainrotSniper = {
    Active = true,
    Version = "2.1 MULTI-SELECT",
    Connections = {},
    Threads = {},
    
    SelectedBrainrots = {},
    TargetCount = 0,
    CurrentCount = 0,
    AutoSnipeEnabled = false,
    IsSnipping = false,
    
    AutoLockEnabled = false,
    LastLockAttempt = 0,
    LockCooldown = 2,
    
    AntiAFKEnabled = false,
    LastAFKAction = 0,
    AFKInterval = 30,
    
    PlayerPlot = nil,
    PlotLastFound = 0,
    
    BrainrotSpeed = 8.5,
    SpawnPoint = nil,
    EndPoint = nil,
    
    SpawnedBrainrots = {},
    BoughtBrainrots = {},
    
    LastCoinTime = 0,
    LastCoinOld = 0,
    LastCoinNew = 0,
    LastNameTime = 0,
    LastNameText = "",
    
    FollowConnection = nil,
    HoldingE = false,
}

local State = _G.BrainrotSniper

local function Log(msg, level)
    level = level or "INFO"
    print(string.format("[%s][Sniper] %s", level, msg))
end

local function UpdateCharacter()
    pcall(function()
        Character = Player.Character
        if Character then
            Humanoid = Character:FindFirstChild("Humanoid")
            HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
        end
    end)
end

local function ValidateCharacter()
    if not Character or not Character.Parent then
        UpdateCharacter()
        return false
    end
    if not Humanoid or Humanoid.Health <= 0 then
        UpdateCharacter()
        return false
    end
    if not HumanoidRootPart or not HumanoidRootPart.Parent then
        UpdateCharacter()
        return false
    end
    return true
end

local function IsBrainrotModel(obj)
    if not obj or not obj:IsA("Model") then return false end
    if obj.Parent ~= Workspace then return false end
    local part = obj:FindFirstChild("Part")
    if not part then return false end
    return true
end

local function GetBrainrotDisplayName(model)
    if not model then return nil end
    
    local part = model:FindFirstChild("Part")
    if not part then return nil end
    
    local info = part:FindFirstChild("Info")
    if not info then return nil end
    
    local overhead = info:FindFirstChild("AnimalOverhead")
    if not overhead then return nil end
    
    local displayName = overhead:FindFirstChild("DisplayName")
    if not displayName or not displayName:IsA("TextLabel") then return nil end
    
    return displayName.Text
end

local function GetBrainrotPart(model)
    if not model then return nil end
    return model:FindFirstChild("Part")
end

local function IsSelectedBrainrot(name)
    for _, selectedName in pairs(State.SelectedBrainrots) do
        if selectedName == name then
            return true
        end
    end
    return false
end

local function InitializePathPoints()
    pcall(function()
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        
        local cave = map:FindFirstChild("Cave")
        if cave then
            local collisions = cave:FindFirstChild("Collisions")
            if collisions then
                local children = collisions:GetChildren()
                if children[2] then
                    State.SpawnPoint = children[2].Position
                    Log("Spawn point found: " .. tostring(State.SpawnPoint))
                end
            end
        end
        
        local model = map:FindFirstChild("Model")
        if model then
            local part = model:FindFirstChild("Part")
            if part then
                State.EndPoint = part.Position
                Log("End point found: " .. tostring(State.EndPoint))
            end
        end
    end)
end

local function GetBrainrotDirection()
    if not State.SpawnPoint or not State.EndPoint then return nil end
    return (State.EndPoint - State.SpawnPoint).Unit
end

local function PredictBrainrotPosition(currentPos, timeAhead)
    if not State.SpawnPoint or not State.EndPoint then return currentPos end
    
    local direction = GetBrainrotDirection()
    if not direction then return currentPos end
    
    local predictedPos = currentPos + (direction * State.BrainrotSpeed * timeAhead)
    return predictedPos
end

local function CalculateInterceptPoint(brainrotPos)
    if not ValidateCharacter() then return nil end
    if not State.SpawnPoint or not State.EndPoint then return brainrotPos end
    
    local direction = GetBrainrotDirection()
    if not direction then return brainrotPos end
    
    local playerPos = HumanoidRootPart.Position
    local distanceToBrainrot = (brainrotPos - playerPos).Magnitude
    
    local playerSpeed = 16
    local timeToReach = distanceToBrainrot / playerSpeed
    
    local interceptPos = brainrotPos + (direction * State.BrainrotSpeed * timeToReach * 0.8)
    
    return interceptPos
end

local function FindPlayerPlot()
    if State.PlayerPlot and State.PlayerPlot.Parent then
        if (tick() - State.PlotLastFound) < 30 then
            return State.PlayerPlot
        end
    end
    
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local surfaceGui = sign:FindFirstChild("SurfaceGui")
            if surfaceGui then
                local frame = surfaceGui:FindFirstChild("Frame")
                if frame then
                    local label = frame:FindFirstChild("TextLabel")
                    if label and label:IsA("TextLabel") then
                        if label.Text:find(Player.Name .. "'s Base") then
                            State.PlayerPlot = plot
                            State.PlotLastFound = tick()
                            Log("Found player plot")
                            return plot
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

local function CountPlotAttachments(plot)
    if not plot then return 0 end
    
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return 0 end
    
    local count = 0
    for _, podium in ipairs(podiums:GetChildren()) do
        local base = podium:FindFirstChild("Base")
        if base then
            local spawn = base:FindFirstChild("Spawn")
            if spawn then
                if spawn:FindFirstChild("Attachment") then
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

local function GetLockTimer(plot)
    if not plot then return nil end
    
    local purchases = plot:FindFirstChild("Purchases")
    if not purchases then return nil end
    
    local plotBlock = purchases:FindFirstChild("PlotBlock")
    if not plotBlock then return nil end
    
    local main = plotBlock:FindFirstChild("Main")
    if not main then return nil end
    
    local billboard = main:FindFirstChild("BillboardGui")
    if not billboard then return nil end
    
    local timeLabel = billboard:FindFirstChild("RemainingTime")
    if not timeLabel or not timeLabel:IsA("TextLabel") then return nil end
    
    local text = timeLabel.Text
    local seconds = tonumber(text:match("%d+"))
    
    return seconds
end

local function GetLockHitbox(plot)
    if not plot then return nil end
    
    local purchases = plot:FindFirstChild("Purchases")
    if not purchases then return nil end
    
    local plotBlock = purchases:FindFirstChild("PlotBlock")
    if not plotBlock then return nil end
    
    local hitbox = plotBlock:FindFirstChild("Hitbox")
    return hitbox
end

local BypassObstacles = true

local function CheckDirection(direction, plot)
    if not ValidateCharacter() then return false end
    if not BypassObstacles then return true end
    
    local origin = HumanoidRootPart.Position
    local rayDirection = direction * 5
    
    local raycastParams = RaycastParams.new()
    local filterList = {Character}
    
    if plot then
        local stealHitbox = plot:FindFirstChild("StealHitbox")
        local deliveryHitbox = plot:FindFirstChild("DeliveryHitbox")
        if stealHitbox then table.insert(filterList, stealHitbox) end
        if deliveryHitbox then table.insert(filterList, deliveryHitbox) end
    end
    
    raycastParams.FilterDescendantsInstances = filterList
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = Workspace:Raycast(origin, rayDirection, raycastParams)
    
    return result == nil
end

local function GetClearDirection(targetPos, plot)
    if not ValidateCharacter() then return nil end
    if not BypassObstacles then return (targetPos - HumanoidRootPart.Position).Unit end
    
    local toTarget = (targetPos - HumanoidRootPart.Position).Unit
    
    local forward = toTarget
    local right = Vector3.new(-forward.Z, 0, forward.X).Unit
    local left = Vector3.new(forward.Z, 0, -forward.X).Unit
    
    local forwardClear = CheckDirection(forward, plot)
    local rightClear = CheckDirection(right, plot)
    local leftClear = CheckDirection(left, plot)
    
    if forwardClear then
        return forward
    elseif rightClear and leftClear then
        return (HumanoidRootPart.Position + right * 2).X > (HumanoidRootPart.Position + left * 2).X and right or left
    elseif rightClear then
        return right
    elseif leftClear then
        return left
    else
        return -forward
    end
end

local function SmartWalkToPosition(targetPos, maxTime, plot)
    if not ValidateCharacter() then return false end
    
    Log("Smart walking to position...")
    
    local startTime = tick()
    
    while (tick() - startTime) < maxTime do
        if not State.Active or not ValidateCharacter() then return false end
        
        local distance = (HumanoidRootPart.Position - targetPos).Magnitude
        
        if distance < 5 then
            Log("Reached target position")
            return true
        end
        
        local clearDirection = GetClearDirection(targetPos, plot)
        if clearDirection then
            local moveTarget = HumanoidRootPart.Position + (clearDirection * 10)
            Humanoid:MoveTo(moveTarget)
        else
            Humanoid:MoveTo(targetPos)
        end
        
        task.wait(0.2)
    end
    
    Log("Failed to reach position in time", "WARN")
    return false
end

local function GetDecorationWaypoint(plot)
    if not plot then return nil end
    
    local decorations = plot:FindFirstChild("Decorations")
    if not decorations then return nil end
    
    local children = decorations:GetChildren()
    if children[12] then
        return children[12].Position
    end
    
    return nil
end

local function WalkToHitbox(hitbox, plot)
    if not hitbox or not ValidateCharacter() then return false end
    
    Log("Walking to lock hitbox with smart navigation...")
    
    local waypoint = GetDecorationWaypoint(plot)
    
    if waypoint then
        Log("Walking to decoration waypoint with obstacle avoidance...")
        BypassObstacles = true
        local reachedWaypoint = SmartWalkToPosition(waypoint, 15, plot)
        
        if not reachedWaypoint then
            Log("Failed to reach waypoint", "WARN")
            return false
        end
        
        Log("Reached waypoint! Disabling obstacle avoidance...")
        BypassObstacles = false
        
        Log("Walking straight to hitbox...")
        local reachedHitbox = SmartWalkToPosition(hitbox.Position, 10, plot)
        
        BypassObstacles = true
        
        return reachedHitbox
    else
        Log("No waypoint found, using direct path with avoidance")
        return SmartWalkToPosition(hitbox.Position, 20, plot)
    end
end

local function ReturnToWaypoint(plot)
    if not ValidateCharacter() then return false end
    
    local waypoint = GetDecorationWaypoint(plot)
    if not waypoint then
        Log("No waypoint to return to")
        return false
    end
    
    Log("Returning to decoration waypoint...")
    BypassObstacles = true
    local reached = SmartWalkToPosition(waypoint, 15, plot)
    
    if reached then
        Log("Returned to waypoint successfully")
    end
    
    return reached
end

local function JumpOnHitbox(hitbox)
    if not hitbox or not ValidateCharacter() then return false end
    
    Log("Jumping to trigger lock...")
    
    for i = 1, 8 do
        if not ValidateCharacter() then break end
        Humanoid.Jump = true
        task.wait(0.4)
    end
    
    return true
end

local function LockBase()
    local plot = FindPlayerPlot()
    if not plot then
        Log("No plot found for locking", "WARN")
        return false
    end
    
    local timer = GetLockTimer(plot)
    if not timer then
        Log("Cannot read lock timer", "WARN")
        return false
    end
    
    if timer > 7 then
        return false
    end
    
    Log("Timer at " .. timer .. "s, heading to base...")
    
    local hitbox = GetLockHitbox(plot)
    if not hitbox then
        Log("No hitbox found", "ERROR")
        return false
    end
    
    local walked = WalkToHitbox(hitbox, plot)
    if not walked then
        Log("Failed to walk to hitbox", "ERROR")
        return false
    end
    
    Log("At hitbox! Waiting for timer to reach 0...")
    
    local waitStart = tick()
    while (tick() - waitStart) < 15 do
        local currentTimer = GetLockTimer(plot)
        if not currentTimer then
            Log("Lost timer reading", "WARN")
            break
        end
        
        if currentTimer <= 0 then
            Log("Timer at 0! Locking now...")
            break
        end
        
        task.wait(0.2)
    end
    
    JumpOnHitbox(hitbox)
    
    task.wait(1)
    
    local newTimer = GetLockTimer(plot)
    if newTimer and newTimer > 7 then
        Log("✓ Base locked successfully!", "SUCCESS")
        
        task.wait(0.5)
        ReturnToWaypoint(plot)
        
        return true
    end
    
    Log("✗ Base lock failed", "ERROR")
    return false
end

local function AutoLockLoop()
    Log("Auto lock base started")
    
    while State.Active and State.AutoLockEnabled do
        if (tick() - State.LastLockAttempt) >= State.LockCooldown then
            pcall(function()
                local plot = FindPlayerPlot()
                if plot then
                    local timer = GetLockTimer(plot)
                    if timer and timer <= 7 then
                        State.LastLockAttempt = tick()
                        LockBase()
                    end
                end
            end)
        end
        
        task.wait(0.5)
    end
    
    Log("Auto lock base stopped")
end

local function AntiAFKLoop()
    Log("Anti-AFK started")
    
    while State.Active and State.AntiAFKEnabled do
        if (tick() - State.LastAFKAction) >= State.AFKInterval then
            pcall(function()
                if ValidateCharacter() then
                    local actions = {
                        function()
                            Humanoid.Jump = true
                        end,
                        function()
                            local currentPos = HumanoidRootPart.Position
                            local randomOffset = Vector3.new(
                                math.random(-3, 3),
                                0,
                                math.random(-3, 3)
                            )
                            Humanoid:MoveTo(currentPos + randomOffset)
                        end,
                        function()
                            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    }
                    
                    local randomAction = actions[math.random(1, #actions)]
                    randomAction()
                    
                    State.LastAFKAction = tick()
                    Log("Anti-AFK action performed", "DEBUG")
                end
            end)
        end
        
        task.wait(5)
    end
    
    Log("Anti-AFK stopped")
end

local function SetupRemoteMonitoring()
    pcall(function()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        if not packages then return end
        
        local synchronizer = packages:FindFirstChild("Synchronizer")
        if not synchronizer then return end
        
        local channel = synchronizer:FindFirstChild("Channel")
        if not channel then return end
        
        local playerNode = channel:FindFirstChild(Player.Name)
        if not playerNode then return end
        
        local remoteEvent = nil
        if playerNode:IsA("RemoteEvent") then
            remoteEvent = playerNode
        else
            for _, child in ipairs(playerNode:GetChildren()) do
                if child:IsA("RemoteEvent") then
                    remoteEvent = child
                    break
                end
            end
        end
        
        if not remoteEvent then return end
        
        local conn = remoteEvent.OnClientEvent:Connect(function(data)
            pcall(function()
                if type(data) == "table" then
                    for _, entry in ipairs(data) do
                        if type(entry) == "table" then
                            if entry[1] == "Coins" and entry[2] == "Changed" then
                                local oldValue = entry[3]
                                local newValue = entry[4]
                                
                                if type(oldValue) == "number" and type(newValue) == "number" then
                                    if newValue < oldValue then
                                        State.LastCoinTime = tick()
                                        State.LastCoinOld = oldValue
                                        State.LastCoinNew = newValue
                                        Log("Coins: " .. oldValue .. " -> " .. newValue, "DEBUG")
                                    end
                                end
                            end
                        elseif type(entry) == "string" then
                            for _, selectedName in pairs(State.SelectedBrainrots) do
                                if entry:lower():find(selectedName:lower()) then
                                    State.LastNameTime = tick()
                                    State.LastNameText = entry
                                    Log("Name mentioned: " .. entry, "DEBUG")
                                    break
                                end
                            end
                        end
                    end
                elseif type(data) == "string" then
                    for _, selectedName in pairs(State.SelectedBrainrots) do
                        if data:lower():find(selectedName:lower()) then
                            State.LastNameTime = tick()
                            State.LastNameText = data
                            Log("Name mentioned: " .. data, "DEBUG")
                            break
                        end
                    end
                end
            end)
        end)
        
        table.insert(State.Connections, conn)
        Log("Remote monitoring active")
    end)
end

local function VerifyPurchase(brainrotName, beforeCount)
    Log("Verifying purchase...")
    
    State.LastCoinTime = 0
    State.LastNameTime = 0
    
    local startTime = tick()
    local plot = FindPlayerPlot()
    
    if not plot then
        Log("No plot for verification", "WARN")
        return false
    end
    
    local coinVerified = false
    local nameVerified = false
    local attachmentVerified = false
    
    while (tick() - startTime) < 8 do
        if State.LastCoinTime > startTime then
            coinVerified = true
            Log("✓ Coin decrease verified", "DEBUG")
        end
        
        if State.LastNameTime > startTime then
            nameVerified = true
            Log("✓ Name mention verified", "DEBUG")
        end
        
        local currentCount = CountPlotAttachments(plot)
        if currentCount > beforeCount then
            attachmentVerified = true
            Log("✓ Attachment verified (" .. beforeCount .. " -> " .. currentCount .. ")", "DEBUG")
            break
        end
        
        if coinVerified and nameVerified then
            task.wait(1.5)
            currentCount = CountPlotAttachments(plot)
            if currentCount > beforeCount then
                attachmentVerified = true
                break
            end
        end
        
        task.wait(0.2)
    end
    
    local verified = attachmentVerified or (coinVerified and nameVerified)
    
    if verified then
        Log("✓✓✓ PURCHASE VERIFIED ✓✓✓", "SUCCESS")
    else
        Log("✗ Purchase NOT verified", "ERROR")
    end
    
    return verified
end

local function StopFollowingBrainrot()
    if State.FollowConnection then
        State.FollowConnection:Disconnect()
        State.FollowConnection = nil
    end
    
    if State.HoldingE then
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
        State.HoldingE = false
    end
end

local function FollowAndHoldE(brainrotModel)
    if not brainrotModel then return false end
    
    StopFollowingBrainrot()
    
    local brainrotPart = GetBrainrotPart(brainrotModel)
    if not brainrotPart then return false end
    
    Log("Following brainrot and holding E...")
    
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        State.HoldingE = true
    end)
    
    local followStartTime = tick()
    local maxFollowTime = 5
    
    State.FollowConnection = RunService.Heartbeat:Connect(function()
        if not State.Active or not ValidateCharacter() then
            StopFollowingBrainrot()
            return
        end
        
        if not brainrotModel or not brainrotModel.Parent then
            StopFollowingBrainrot()
            return
        end
        
        if (tick() - followStartTime) > maxFollowTime then
            StopFollowingBrainrot()
            return
        end
        
        brainrotPart = GetBrainrotPart(brainrotModel)
        if not brainrotPart then
            StopFollowingBrainrot()
            return
        end
        
        local predictedPos = PredictBrainrotPosition(brainrotPart.Position, 0.3)
        Humanoid:MoveTo(predictedPos)
    end)
    
    task.wait(3.5)
    
    StopFollowingBrainrot()
    
    return true
end

local function GetClosestSelectedBrainrot()
    if not ValidateCharacter() then return nil, nil end
    
    local closest = nil
    local closestName = nil
    local closestDistance = math.huge
    
    for brainrot, _ in pairs(State.SpawnedBrainrots) do
        if brainrot and brainrot.Parent and not State.BoughtBrainrots[brainrot] then
            local displayName = GetBrainrotDisplayName(brainrot)
            if displayName and IsSelectedBrainrot(displayName) then
                local part = GetBrainrotPart(brainrot)
                if part then
                    local distance = (part.Position - HumanoidRootPart.Position).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closest = brainrot
                        closestName = displayName
                    end
                end
            end
        end
    end
    
    return closest, closestName
end

local function WaitForSelectedBrainrotSpawn(timeout)
    local startTime = tick()
    
    while (tick() - startTime) < timeout do
        if not State.Active then return nil, nil end
        
        local brainrot, name = GetClosestSelectedBrainrot()
        if brainrot then
            return brainrot, name
        end
        
        task.wait(0.3)
    end
    
    return nil, nil
end

local function WalkToInterceptPoint(targetBrainrot)
    if not ValidateCharacter() then return false end
    if not targetBrainrot or not targetBrainrot.Parent then return false end
    
    local brainrotPart = GetBrainrotPart(targetBrainrot)
    if not brainrotPart then return false end
    
    local interceptPoint = CalculateInterceptPoint(brainrotPart.Position)
    if not interceptPoint then return false end
    
    Log("Walking to intercept point...")
    
    local startTime = tick()
    local maxWalkTime = 15
    
    while (tick() - startTime) < maxWalkTime do
        if not State.Active or not ValidateCharacter() then return false end
        
        if not targetBrainrot or not targetBrainrot.Parent then
            Log("Target disappeared", "WARN")
            return false
        end
        
        brainrotPart = GetBrainrotPart(targetBrainrot)
        if not brainrotPart then return false end
        
        local distanceToBrainrot = (brainrotPart.Position - HumanoidRootPart.Position).Magnitude
        
        if distanceToBrainrot < 10 then
            Log("Close enough to brainrot!")
            return true
        end
        
        interceptPoint = CalculateInterceptPoint(brainrotPart.Position)
        Humanoid:MoveTo(interceptPoint)
        
        task.wait(0.1)
    end
    
    Log("Walk timeout", "WARN")
    return false
end

local function SnipeSingleBrainrot()
    if State.IsSnipping then
        Log("Already snipping", "WARN")
        return false
    end
    
    if #State.SelectedBrainrots == 0 then
        Log("No brainrots selected", "ERROR")
        return false
    end
    
    State.IsSnipping = true
    
    Log("═══════════════════════════════════════")
    Log("Searching for any selected brainrot...")
    Log("═══════════════════════════════════════")
    
    local targetBrainrot, brainrotName = GetClosestSelectedBrainrot()
    
    if not targetBrainrot then
        Log("No selected brainrot found, waiting...")
        targetBrainrot, brainrotName = WaitForSelectedBrainrotSpawn(30)
    end
    
    if not targetBrainrot or not brainrotName then
        Log("Timeout waiting for spawn", "ERROR")
        State.IsSnipping = false
        return false
    end
    
    Log("Target acquired: " .. brainrotName)
    
    local displayName = GetBrainrotDisplayName(targetBrainrot)
    if displayName ~= brainrotName then
        Log("Name mismatch!", "ERROR")
        State.IsSnipping = false
        return false
    end
    
    local walked = WalkToInterceptPoint(targetBrainrot)
    
    if not walked then
        Log("Failed to reach intercept point", "ERROR")
        State.IsSnipping = false
        return false
    end
    
    if not targetBrainrot or not targetBrainrot.Parent then
        Log("Target disappeared during walk", "WARN")
        State.IsSnipping = false
        return false
    end
    
    displayName = GetBrainrotDisplayName(targetBrainrot)
    if displayName ~= brainrotName then
        Log("Name changed during walk!", "ERROR")
        State.IsSnipping = false
        return false
    end
    
    State.BoughtBrainrots[targetBrainrot] = true
    
    local plot = FindPlayerPlot()
    local beforeCount = plot and CountPlotAttachments(plot) or 0
    
    Log("Attachments before: " .. beforeCount)
    
    local followed = FollowAndHoldE(targetBrainrot)
    
    if not followed then
        Log("Failed to follow brainrot", "ERROR")
        State.BoughtBrainrots[targetBrainrot] = nil
        State.IsSnipping = false
        return false
    end
    
    Log("Verifying purchase...")
    local verified = VerifyPurchase(brainrotName, beforeCount)
    
    if verified then
        Log("✓✓✓ SUCCESSFULLY SNIPED: " .. brainrotName .. " ✓✓✓", "SUCCESS")
        State.IsSnipping = false
        return true, brainrotName
    else
        Log("✗ Verification failed", "ERROR")
        State.BoughtBrainrots[targetBrainrot] = nil
        State.IsSnipping = false
        return false, nil
    end
end

local function StartAutoSnipe()
    if #State.SelectedBrainrots == 0 then
        Log("No brainrots selected", "ERROR")
        return
    end
    
    if State.TargetCount <= 0 then
        Log("Invalid target count", "ERROR")
        return
    end
    
    State.CurrentCount = 0
    State.AutoSnipeEnabled = true
    
    Log("╔═══════════════════════════════════════╗")
    Log("║  AUTO-SNIPE STARTED                   ║")
    Log("║  Targets: " .. #State.SelectedBrainrots .. " brainrots")
    Log("║  Count: " .. State.TargetCount)
    Log("╚═══════════════════════════════════════╝")
    
    local thread = task.spawn(function()
        while State.Active and State.AutoSnipeEnabled and State.CurrentCount < State.TargetCount do
            local success, name = SnipeSingleBrainrot()
            
            if success then
                State.CurrentCount = State.CurrentCount + 1
                Log("Progress: " .. State.CurrentCount .. "/" .. State.TargetCount, "SUCCESS")
                
                pcall(function()
                    ShowSuccessPopup(name)
                end)
                
                if State.CurrentCount >= State.TargetCount then
                    Log("╔═══════════════════════════════════════╗")
                    Log("║  AUTO-SNIPE COMPLETE!                 ║")
                    Log("║  Sniped " .. State.CurrentCount .. " brainrots")
                    Log("╚═══════════════════════════════════════╝")
                    State.AutoSnipeEnabled = false
                    pcall(function()
                        UpdateToggleButton(false)
                    end)
                    break
                end
                
                task.wait(0.5)
            else
                Log("Snipe failed, retrying...", "WARN")
                task.wait(2)
            end
        end
    end)
    
    table.insert(State.Threads, thread)
end

local function StopAutoSnipe()
    State.AutoSnipeEnabled = false
    State.IsSnipping = false
    StopFollowingBrainrot()
    Log("Auto-snipe stopped")
end

local function InitializeSpawnTracking()
    Log("Initializing spawn tracking...")
    
    for _, obj in ipairs(Workspace:GetChildren()) do
        if IsBrainrotModel(obj) then
            State.SpawnedBrainrots[obj] = true
        end
    end
    
    local addConn = Workspace.ChildAdded:Connect(function(obj)
        if IsBrainrotModel(obj) then
            State.SpawnedBrainrots[obj] = true
            local name = GetBrainrotDisplayName(obj)
            if name then
                Log("Brainrot spawned: " .. name, "DEBUG")
            end
        end
    end)
    
    local removeConn = Workspace.ChildRemoved:Connect(function(obj)
        State.SpawnedBrainrots[obj] = nil
        State.BoughtBrainrots[obj] = nil
    end)
    
    table.insert(State.Connections, addConn)
    table.insert(State.Connections, removeConn)
    
    Log("Spawn tracking active")
end

local function InitializeCharacterTracking()
    local charConn = Player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        StopFollowingBrainrot()
        Log("Character respawned")
    end)
    
    table.insert(State.Connections, charConn)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BrainrotSniperV2"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)

if not ScreenGui.Parent then
    ScreenGui.Parent = Player:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 520)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleBottom = Instance.new("Frame")
TitleBottom.Size = UDim2.new(1, 0, 0, 10)
TitleBottom.Position = UDim2.new(0, 0, 1, -10)
TitleBottom.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
TitleBottom.BorderSizePixel = 0
TitleBottom.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎯 Brainrot Sniper V2.1"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 32, 0, 32)
MinimizeButton.Position = UDim2.new(1, -70, 0, 4)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Text = "━"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.TextSize = 12
MinimizeButton.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 32, 0, 32)
CloseButton.Position = UDim2.new(1, -34, 0, 4)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -20, 1, -50)
ContentFrame.Position = UDim2.new(0, 10, 0, 45)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, 0, 0, 32)
SearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
SearchBox.PlaceholderText = "🔍 Search brainrot..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 105)
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 11
SearchBox.BorderSizePixel = 0
SearchBox.Parent = ContentFrame

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 6)
SearchCorner.Parent = SearchBox

local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 10)
SearchPadding.Parent = SearchBox

local SelectButtonsFrame = Instance.new("Frame")
SelectButtonsFrame.Size = UDim2.new(1, 0, 0, 28)
SelectButtonsFrame.Position = UDim2.new(0, 0, 0, 37)
SelectButtonsFrame.BackgroundTransparency = 1
SelectButtonsFrame.Parent = ContentFrame

local SelectAllButton = Instance.new("TextButton")
SelectAllButton.Size = UDim2.new(0.48, 0, 1, 0)
SelectAllButton.Position = UDim2.new(0, 0, 0, 0)
SelectAllButton.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
SelectAllButton.BorderSizePixel = 0
SelectAllButton.Text = "Select All"
SelectAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectAllButton.Font = Enum.Font.GothamBold
SelectAllButton.TextSize = 10
SelectAllButton.Parent = SelectButtonsFrame

local SelectAllCorner = Instance.new("UICorner")
SelectAllCorner.CornerRadius = UDim.new(0, 5)
SelectAllCorner.Parent = SelectAllButton

local DeselectAllButton = Instance.new("TextButton")
DeselectAllButton.Size = UDim2.new(0.48, 0, 1, 0)
DeselectAllButton.Position = UDim2.new(0.52, 0, 0, 0)
DeselectAllButton.BackgroundColor3 = Color3.fromRGB(200, 80, 50)
DeselectAllButton.BorderSizePixel = 0
DeselectAllButton.Text = "Deselect All"
DeselectAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DeselectAllButton.Font = Enum.Font.GothamBold
DeselectAllButton.TextSize = 10
DeselectAllButton.Parent = SelectButtonsFrame

local DeselectAllCorner = Instance.new("UICorner")
DeselectAllCorner.CornerRadius = UDim.new(0, 5)
DeselectAllCorner.Parent = DeselectAllButton

local DropdownFrame = Instance.new("ScrollingFrame")
DropdownFrame.Size = UDim2.new(1, 0, 0, 140)
DropdownFrame.Position = UDim2.new(0, 0, 0, 70)
DropdownFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
DropdownFrame.BorderSizePixel = 0
DropdownFrame.ScrollBarThickness = 4
DropdownFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 75)
DropdownFrame.Parent = ContentFrame

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 6)
DropdownCorner.Parent = DropdownFrame

local DropdownLayout = Instance.new("UIListLayout")
DropdownLayout.Padding = UDim.new(0, 3)
DropdownLayout.SortOrder = Enum.SortOrder.Name
DropdownLayout.Parent = DropdownFrame

local DropdownPadding = Instance.new("UIPadding")
DropdownPadding.PaddingTop = UDim.new(0, 4)
DropdownPadding.PaddingBottom = UDim.new(0, 4)
DropdownPadding.PaddingLeft = UDim.new(0, 4)
DropdownPadding.PaddingRight = UDim.new(0, 4)
DropdownPadding.Parent = DropdownFrame

local SelectedFrame = Instance.new("Frame")
SelectedFrame.Size = UDim2.new(1, 0, 0, 42)
SelectedFrame.Position = UDim2.new(0, 0, 0, 215)
SelectedFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
SelectedFrame.BorderSizePixel = 0
SelectedFrame.Parent = ContentFrame

local SelectedCorner = Instance.new("UICorner")
SelectedCorner.CornerRadius = UDim.new(0, 6)
SelectedCorner.Parent = SelectedFrame

local SelectedTitle = Instance.new("TextLabel")
SelectedTitle.Size = UDim2.new(1, -10, 0, 16)
SelectedTitle.Position = UDim2.new(0, 5, 0, 3)
SelectedTitle.BackgroundTransparency = 1
SelectedTitle.Text = "Selected Targets"
SelectedTitle.TextColor3 = Color3.fromRGB(120, 120, 125)
SelectedTitle.Font = Enum.Font.Gotham
SelectedTitle.TextSize = 9
SelectedTitle.TextXAlignment = Enum.TextXAlignment.Left
SelectedTitle.Parent = SelectedFrame

local SelectedLabel = Instance.new("TextLabel")
SelectedLabel.Size = UDim2.new(1, -10, 0, 20)
SelectedLabel.Position = UDim2.new(0, 5, 0, 19)
SelectedLabel.BackgroundTransparency = 1
SelectedLabel.Text = "None (0 selected)"
SelectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedLabel.Font = Enum.Font.GothamBold
SelectedLabel.TextSize = 11
SelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
SelectedLabel.Parent = SelectedFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 155, 0, 36)
ToggleButton.Position = UDim2.new(0, 0, 0, 262)
ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = "Auto-Snipe: OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 11
ToggleButton.Parent = ContentFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

local CountBox = Instance.new("TextBox")
CountBox.Size = UDim2.new(1, -160, 0, 36)
CountBox.Position = UDim2.new(0, 160, 0, 262)
CountBox.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
CountBox.PlaceholderText = "Amount"
CountBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 105)
CountBox.Text = ""
CountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
CountBox.Font = Enum.Font.Gotham
CountBox.TextSize = 11
CountBox.BorderSizePixel = 0
CountBox.Parent = ContentFrame

local CountCorner = Instance.new("UICorner")
CountCorner.CornerRadius = UDim.new(0, 6)
CountCorner.Parent = CountBox

local CountPadding = Instance.new("UIPadding")
CountPadding.PaddingLeft = UDim.new(0, 10)
CountPadding.Parent = CountBox

local LockButton = Instance.new("TextButton")
LockButton.Size = UDim2.new(1, 0, 0, 36)
LockButton.Position = UDim2.new(0, 0, 0, 303)
LockButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
LockButton.BorderSizePixel = 0
LockButton.Text = "🔒 Auto Lock Base: OFF"
LockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LockButton.Font = Enum.Font.GothamBold
LockButton.TextSize = 11
LockButton.Parent = ContentFrame

local LockCorner = Instance.new("UICorner")
LockCorner.CornerRadius = UDim.new(0, 6)
LockCorner.Parent = LockButton

local AntiAFKButton = Instance.new("TextButton")
AntiAFKButton.Size = UDim2.new(1, 0, 0, 36)
AntiAFKButton.Position = UDim2.new(0, 0, 0, 344)
AntiAFKButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
AntiAFKButton.BorderSizePixel = 0
AntiAFKButton.Text = "⚡ Anti-AFK: OFF"
AntiAFKButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AntiAFKButton.Font = Enum.Font.GothamBold
AntiAFKButton.TextSize = 11
AntiAFKButton.Parent = ContentFrame

local AntiAFKCorner = Instance.new("UICorner")
AntiAFKCorner.CornerRadius = UDim.new(0, 6)
AntiAFKCorner.Parent = AntiAFKButton

local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(1, 0, 0, 55)
StatusFrame.Position = UDim2.new(0, 0, 0, 385)
StatusFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = ContentFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 1, -6)
StatusLabel.Position = UDim2.new(0, 5, 0, 3)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Idle\nProgress: 0/0\nLock: Disabled | AFK: Disabled"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.Parent = StatusFrame

local SuccessPopup = Instance.new("Frame")
SuccessPopup.Size = UDim2.new(0, 380, 0, 50)
SuccessPopup.Position = UDim2.new(0.5, -190, 0, -60)
SuccessPopup.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
SuccessPopup.BorderSizePixel = 0
SuccessPopup.Parent = ScreenGui

local PopupCorner = Instance.new("UICorner")
PopupCorner.CornerRadius = UDim.new(0, 8)
PopupCorner.Parent = SuccessPopup

local PopupText = Instance.new("TextLabel")
PopupText.Size = UDim2.new(1, -16, 1, 0)
PopupText.Position = UDim2.new(0, 8, 0, 0)
PopupText.BackgroundTransparency = 1
PopupText.Text = ""
PopupText.TextColor3 = Color3.fromRGB(255, 255, 255)
PopupText.Font = Enum.Font.GothamBold
PopupText.TextSize = 13
PopupText.TextWrapped = true
PopupText.Parent = SuccessPopup

function ShowSuccessPopup(brainrotName)
    pcall(function()
        PopupText.Text = "✓ Successfully bought \"" .. brainrotName .. "\"!"
        
        TweenService:Create(
            SuccessPopup,
            TweenInfo.new(0.3, Enum.EasingStyle.Back),
            {Position = UDim2.new(0.5, -190, 0, 10)}
        ):Play()
        
        task.delay(3, function()
            if SuccessPopup and SuccessPopup.Parent then
                TweenService:Create(
                    SuccessPopup,
                    TweenInfo.new(0.3),
                    {Position = UDim2.new(0.5, -190, 0, -60)}
                ):Play()
            end
        end)
    end)
end

function UpdateToggleButton(enabled)
    pcall(function()
        State.AutoSnipeEnabled = enabled
        
        if enabled then
            ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
            ToggleButton.Text = "Auto-Snipe: ON"
        else
            ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            ToggleButton.Text = "Auto-Snipe: OFF"
        end
    end)
end

function UpdateLockButton(enabled)
    pcall(function()
        State.AutoLockEnabled = enabled
        
        if enabled then
            LockButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
            LockButton.Text = "🔒 Auto Lock Base: ON"
        else
            LockButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            LockButton.Text = "🔒 Auto Lock Base: OFF"
        end
    end)
end

function UpdateAntiAFKButton(enabled)
    pcall(function()
        State.AntiAFKEnabled = enabled
        
        if enabled then
            AntiAFKButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
            AntiAFKButton.Text = "⚡ Anti-AFK: ON"
        else
            AntiAFKButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            AntiAFKButton.Text = "⚡ Anti-AFK: OFF"
        end
    end)
end

function UpdateSelectedLabel()
    pcall(function()
        local count = #State.SelectedBrainrots
        if count == 0 then
            SelectedLabel.Text = "None (0 selected)"
        elseif count == 1 then
            SelectedLabel.Text = State.SelectedBrainrots[1] .. " (1 selected)"
        else
            SelectedLabel.Text = count .. " brainrots selected"
        end
    end)
end

function UpdateStatus()
    pcall(function()
        local status = "Idle"
        if State.IsSnipping then
            status = "Snipping..."
        elseif State.AutoSnipeEnabled then
            status = "Active"
        end
        
        local lockStatus = State.AutoLockEnabled and "Enabled" or "Disabled"
        local afkStatus = State.AntiAFKEnabled and "Enabled" or "Disabled"
        
        StatusLabel.Text = string.format(
            "Status: %s\nProgress: %d/%d\nLock: %s | AFK: %s",
            status,
            State.CurrentCount,
            State.TargetCount,
            lockStatus,
            afkStatus
        )
    end)
end

MinimizeButton.MouseButton1Click:Connect(function()
    pcall(function()
        local minimized = ContentFrame.Visible
        
        if minimized then
            ContentFrame.Visible = false
            TweenService:Create(
                MainFrame,
                TweenInfo.new(0.2),
                {Size = UDim2.new(0, 360, 0, 40)}
            ):Play()
            MinimizeButton.Text = "□"
        else
            TweenService:Create(
                MainFrame,
                TweenInfo.new(0.2),
                {Size = UDim2.new(0, 360, 0, 520)}
            ):Play()
            task.wait(0.1)
            ContentFrame.Visible = true
            MinimizeButton.Text = "━"
        end
    end)
end)

CloseButton.MouseButton1Click:Connect(function()
    pcall(function()
        State.Active = false
        StopAutoSnipe()
        
        for _, conn in pairs(State.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        
        for _, thread in pairs(State.Threads) do
            pcall(function() task.cancel(thread) end)
        end
        
        ScreenGui:Destroy()
        Log("Script closed")
    end)
end)

ToggleButton.MouseButton1Click:Connect(function()
    pcall(function()
        if State.AutoSnipeEnabled then
            StopAutoSnipe()
            UpdateToggleButton(false)
        else
            if #State.SelectedBrainrots == 0 then
                Log("Select at least one brainrot!", "WARN")
                return
            end
            
            local countText = CountBox.Text
            local count = tonumber(countText)
            
            if not count or count <= 0 then
                if countText == "" then
                    count = 1
                    CountBox.Text = "1"
                    Log("Defaulting to count: 1")
                else
                    Log("Enter a valid count!", "WARN")
                    return
                end
            end
            
            State.TargetCount = count
            UpdateToggleButton(true)
            StartAutoSnipe()
        end
    end)
end)

LockButton.MouseButton1Click:Connect(function()
    pcall(function()
        State.AutoLockEnabled = not State.AutoLockEnabled
        UpdateLockButton(State.AutoLockEnabled)
        
        if State.AutoLockEnabled then
            local thread = task.spawn(AutoLockLoop)
            table.insert(State.Threads, thread)
        end
    end)
end)

AntiAFKButton.MouseButton1Click:Connect(function()
    pcall(function()
        State.AntiAFKEnabled = not State.AntiAFKEnabled
        UpdateAntiAFKButton(State.AntiAFKEnabled)
        
        if State.AntiAFKEnabled then
            State.LastAFKAction = tick()
            local thread = task.spawn(AntiAFKLoop)
            table.insert(State.Threads, thread)
            Log("Anti-AFK enabled")
        else
            Log("Anti-AFK disabled")
        end
    end)
end)

CountBox:GetPropertyChangedSignal("Text"):Connect(function()
    pcall(function()
        local filtered = CountBox.Text:gsub("[^%d]", "")
        if filtered ~= CountBox.Text then
            CountBox.Text = filtered
        end
    end)
end)

local brainrotNames = {}

pcall(function()
    local models = ReplicatedStorage:FindFirstChild("Models")
    if models then
        local animals = models:FindFirstChild("Animals")
        if animals then
            for _, model in ipairs(animals:GetChildren()) do
                if model:IsA("Model") then
                    table.insert(brainrotNames, model.Name)
                end
            end
        end
    end
end)

table.sort(brainrotNames)

local checkboxButtons = {}

local function RefreshDropdown(filterText)
    pcall(function()
        for _, child in ipairs(DropdownFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        checkboxButtons = {}
        
        local filter = filterText and filterText:lower() or ""
        
        for _, name in ipairs(brainrotNames) do
            if filter == "" or name:lower():find(filter, 1, true) then
                local itemFrame = Instance.new("Frame")
                itemFrame.Size = UDim2.new(1, -8, 0, 28)
                itemFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
                itemFrame.BorderSizePixel = 0
                itemFrame.Parent = DropdownFrame
                
                local itemCorner = Instance.new("UICorner")
                itemCorner.CornerRadius = UDim.new(0, 5)
                itemCorner.Parent = itemFrame
                
                local checkbox = Instance.new("TextButton")
                checkbox.Size = UDim2.new(0, 24, 0, 24)
                checkbox.Position = UDim2.new(0, 3, 0.5, -12)
                checkbox.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
                checkbox.BorderSizePixel = 0
                checkbox.Text = ""
                checkbox.Parent = itemFrame
                
                local checkCorner = Instance.new("UICorner")
                checkCorner.CornerRadius = UDim.new(0, 4)
                checkCorner.Parent = checkbox
                
                local checkmark = Instance.new("TextLabel")
                checkmark.Size = UDim2.new(1, 0, 1, 0)
                checkmark.BackgroundTransparency = 1
                checkmark.Text = "✓"
                checkmark.TextColor3 = Color3.fromRGB(50, 180, 80)
                checkmark.Font = Enum.Font.GothamBold
                checkmark.TextSize = 16
                checkmark.Visible = IsSelectedBrainrot(name)
                checkmark.Parent = checkbox
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -35, 1, 0)
                label.Position = UDim2.new(0, 32, 0, 0)
                label.BackgroundTransparency = 1
                label.Text = name
                label.TextColor3 = Color3.fromRGB(255, 255, 255)
                label.Font = Enum.Font.Gotham
                label.TextSize = 10
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = itemFrame
                
                checkboxButtons[name] = {frame = itemFrame, checkbox = checkbox, checkmark = checkmark}
                
                local function toggleSelection()
                    pcall(function()
                        local isSelected = IsSelectedBrainrot(name)
                        
                        if isSelected then
                            for i, selectedName in ipairs(State.SelectedBrainrots) do
                                if selectedName == name then
                                    table.remove(State.SelectedBrainrots, i)
                                    break
                                end
                            end
                            checkmark.Visible = false
                        else
                            table.insert(State.SelectedBrainrots, name)
                            checkmark.Visible = true
                        end
                        
                        UpdateSelectedLabel()
                        Log("Selected: " .. #State.SelectedBrainrots .. " brainrots")
                    end)
                end
                
                checkbox.MouseButton1Click:Connect(toggleSelection)
                
                local clickButton = Instance.new("TextButton")
                clickButton.Size = UDim2.new(1, 0, 1, 0)
                clickButton.BackgroundTransparency = 1
                clickButton.Text = ""
                clickButton.Parent = itemFrame
                clickButton.MouseButton1Click:Connect(toggleSelection)
            end
        end
        
        DropdownFrame.CanvasSize = UDim2.new(0, 0, 0, DropdownLayout.AbsoluteContentSize.Y + 8)
    end)
end

SelectAllButton.MouseButton1Click:Connect(function()
    pcall(function()
        State.SelectedBrainrots = {}
        for _, name in ipairs(brainrotNames) do
            table.insert(State.SelectedBrainrots, name)
        end
        RefreshDropdown(SearchBox.Text)
        UpdateSelectedLabel()
        Log("Selected all brainrots")
    end)
end)

DeselectAllButton.MouseButton1Click:Connect(function()
    pcall(function()
        State.SelectedBrainrots = {}
        RefreshDropdown(SearchBox.Text)
        UpdateSelectedLabel()
        Log("Deselected all brainrots")
    end)
end)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RefreshDropdown(SearchBox.Text)
end)

RefreshDropdown()

local statusUpdateThread = task.spawn(function()
    while State.Active and ScreenGui.Parent do
        UpdateStatus()
        task.wait(0.5)
    end
end)

table.insert(State.Threads, statusUpdateThread)

InitializePathPoints()
SetupRemoteMonitoring()
InitializeSpawnTracking()
InitializeCharacterTracking()
FindPlayerPlot()

Log("╔═══════════════════════════════════════════════════════╗")
Log("║           BRAINROT SNIPER V2.1 MULTI-SELECT           ║")
Log("║                                                        ║")
Log("║  Multi-Selection: ENABLED                             ║")
Log("║  Auto Lock Base: Smart Navigation                     ║")
Log("║  Anti-AFK: ENABLED                                    ║")
Log("║  Obstacle Avoidance: Raycasting                       ║")
Log("║  Movement Prediction: ENABLED                         ║")
Log("║  Dynamic Following: ENABLED                           ║")
Log("║  Brainrot Speed: 8.5                                  ║")
Log("║  Verification: Triple Layer                           ║")
Log("║                                                        ║")
Log("╚═══════════════════════════════════════════════════════╝")

print("Steal a brainrot Script loaded , made by xsakyx for RenHub .")
print("For Devs : This script wasnt commented fully .")
