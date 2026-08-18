-- Criminality Helper - clean rewrite for RenCore / RenLib
-- Game-specific detection paths intentionally preserve the original script's Criminality contracts.

print("[Criminality] clean rewrite loading...")

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    Workspace = game:GetService("Workspace"),
    Stats = game:GetService("Stats"),
    Lighting = game:GetService("Lighting"),
}

local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local Workspace = Services.Workspace
local LocalPlayer = Players.LocalPlayer

local function getSharedEnvironment()
    local ok, environment = pcall(function()
        return getgenv()
    end)
    return ok and environment or _G
end

local Shared = getSharedEnvironment()
if type(Shared.RenCriminality) == "table" and type(Shared.RenCriminality.Destroy) == "function" then
    pcall(Shared.RenCriminality.Destroy, Shared.RenCriminality)
end

local Runtime = {
    Destroyed = false,
    Connections = {},
    Instances = {},
    Version = "2.2.8 SAFE",
    AimRenderStepName = "RenCriminalityAim_" .. tostring(game:GetService("Players").LocalPlayer.UserId),
}
Shared.RenCriminality = Runtime

function Runtime:AddConnection(connection)
    table.insert(self.Connections, connection)
    return connection
end

function Runtime:AddInstance(instance)
    table.insert(self.Instances, instance)
    return instance
end

local RenLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"))()
Runtime.RenLib = RenLib

local function notify(title, content, duration)
    pcall(function()
        RenLib:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
        })
    end)
end

local Config = {
    ESP = {
        Enabled = false,
        Skeleton = true,
        Highlight = true,
        ShowHealth = true,
        ShowDistance = true,
        ShowIdentity = true,
        NormalColor = Color3.fromRGB(238, 241, 247),
        FriendColor = Color3.fromRGB(80, 226, 150),
        BlacklistColor = Color3.fromRGB(255, 83, 91),
    },
    WorldESP = {
        Enabled = false,
        ShowHealth = true,
        ShowDrop = true,
        ShowDistance = true,
        VaultColor = Color3.fromRGB(255, 212, 78),
        RegisterColor = Color3.fromRGB(83, 179, 255),
        CrateColor = Color3.fromRGB(188, 117, 255),
    },
    Aim = {
        Enabled = false,
        TargetPart = "Head",
        FOV = 200,
        Response = 0.35,
        WallCheck = true,
        StickToTarget = true,
        IgnoreFriends = true,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255),
        FOVTransparency = 0.32,
    },
    Lists = {
        AutoDetectRobloxFriends = true,
    },
    Survival = {
        InfiniteStamina = false,
        CompatibilitySprintSpeed = 24,
        AntiRagdoll = false,
    },
    Utility = {
        NoFailLockpick = false,
        UnlockNearbyDoors = false,
        OpenNearbyDoors = false,
        InstantInteract = false,
        AutoPickupMoney = false,
        FPSBooster = false,
    },
}
Runtime.Config = Config

-- Criminality-specific detection layer. These paths intentionally match the original script.
local Game = {}

function Game.GetCharactersFolder()
    return Workspace:FindFirstChild("Characters")
end

function Game.GetCharacter(player)
    if not player then
        return nil
    end
    local characters = Game.GetCharactersFolder()
    local customCharacter = characters and characters:FindFirstChild(player.Name) or nil
    if customCharacter then
        return customCharacter
    end
    -- Keep the Criminality folder contract, but do not make every feature fail in
    -- places/rounds that temporarily use Roblox's normal Player.Character path.
    local character = player.Character
    return character and character.Parent and character or nil
end

function Game.GetHumanoid(character)
    return character and (character:FindFirstChild("Humanoid") or character:FindFirstChildOfClass("Humanoid")) or nil
end

function Game.GetRoot(character)
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
        or character.PrimaryPart
end

function Game.GetHead(character)
    return character and character:FindFirstChild("Head") or nil
end

function Game.IsAlive(player)
    local character = Game.GetCharacter(player)
    local humanoid = Game.GetHumanoid(character)
    return humanoid ~= nil and humanoid.Health > 0 and Game.GetRoot(character) ~= nil
end

function Game.GetLocalRoot()
    return Game.GetRoot(Game.GetCharacter(LocalPlayer))
end

function Game.GetDistanceFromLocal(position)
    local root = Game.GetLocalRoot()
    return root and (position - root.Position).Magnitude or math.huge
end

local RAGDOLL_STATE_NAMES = {
    ragdoll = true,
    ragdolled = true,
    downed = true,
    knocked = true,
    knockedout = true,
    unconscious = true,
    incapacitated = true,
    ko = true,
}

local function normalizedStateName(value)
    return string.lower(tostring(value or "")):gsub("[%s%p_]", "")
end

local function hasTrueRagdollAttribute(instance)
    if not instance then return false end
    for name, value in pairs(instance:GetAttributes()) do
        if RAGDOLL_STATE_NAMES[normalizedStateName(name)] and (value == true or tonumber(value) == 1) then
            return true
        end
    end
    return false
end

local function getSettingsState(player)
    if not player then return nil end
    local settings = player:FindFirstChild("Settings")
    return settings and (settings:FindFirstChild("Settings") or settings) or nil
end

local RagdollCache = {}

function Game.IsRagdolled(player)
    if not player then return false end
    local now = os.clock()
    local cached = RagdollCache[player.UserId]
    if cached and now - cached.Time < 0.05 then
        return cached.Value
    end

    local character = Game.GetCharacter(player)
    local humanoid = Game.GetHumanoid(character)
    local result = false
    if character and humanoid then
        local state = humanoid:GetState()
        result = humanoid.PlatformStand
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.GettingUp
            or state == Enum.HumanoidStateType.Dead

        if not result then
            result = hasTrueRagdollAttribute(character)
                or hasTrueRagdollAttribute(humanoid)
                or hasTrueRagdollAttribute(player)
        end
        if not result then
            local settingsState = getSettingsState(player)
            result = hasTrueRagdollAttribute(settingsState)
        end
    end

    RagdollCache[player.UserId] = {Time = now, Value = result}
    return result
end

function Game.IsCombatEligible(player)
    return Game.IsAlive(player) and not Game.IsRagdolled(player)
end

function Game.WorldToScreen(position)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil, false
    end
    local point, onScreen = camera:WorldToViewportPoint(position)
    if point.Z <= 0 then
        return Vector2.new(point.X, point.Y), false
    end
    return Vector2.new(point.X, point.Y), onScreen
end

-- Friend/blacklist engine: UserId-backed manual lists plus cached Roblox-friend detection.
local Lists = {
    Friends = {},
    Blacklist = {},
    AutoFriends = {},
}
Runtime.Lists = Lists

local function normalize(value)
    return string.lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

function Lists:EntryForPlayer(player)
    return {
        UserId = player.UserId,
        Name = player.Name,
        DisplayName = player.DisplayName,
    }
end

function Lists:IsBlacklisted(player)
    return player ~= nil and self.Blacklist[player.UserId] ~= nil
end

function Lists:IsFriend(player)
    if not player or self:IsBlacklisted(player) then
        return false
    end
    if self.Friends[player.UserId] ~= nil then
        return true
    end
    return Config.Lists.AutoDetectRobloxFriends and self.AutoFriends[player.UserId] == true
end

function Lists:DetectRobloxFriend(player)
    if not player or player == LocalPlayer then
        return
    end
    task.spawn(function()
        local ok, isFriend = pcall(function()
            return LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if ok then
            self.AutoFriends[player.UserId] = isFriend == true
            if Runtime.UI and type(Runtime.UI.RefreshLists) == "function" then
                task.defer(function() Runtime.UI:RefreshLists() end)
            end
        end
    end)
end

function Lists:DetectAllRobloxFriends()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            self:DetectRobloxFriend(player)
        end
    end
end

function Lists:ResolveLive(query)
    local wanted = normalize(query)
    if wanted == "" then
        return nil, "Select or enter a player first."
    end
    local exact
    local prefixMatches = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local username = normalize(player.Name)
            local display = normalize(player.DisplayName)
            if username == wanted or display == wanted or tostring(player.UserId) == wanted then
                exact = player
                break
            end
            if string.sub(username, 1, #wanted) == wanted or string.sub(display, 1, #wanted) == wanted then
                table.insert(prefixMatches, player)
            end
        end
    end
    if exact then return exact end
    if #prefixMatches == 1 then return prefixMatches[1] end
    if #prefixMatches > 1 then return nil, "That entry matches multiple live players." end
    return nil, "No live player matched that entry."
end

function Lists:AddFriend(query)
    local player, reason = self:ResolveLive(query)
    if not player then return false, reason end
    self.Blacklist[player.UserId] = nil
    self.Friends[player.UserId] = self:EntryForPlayer(player)
    if Runtime.UI and Runtime.UI.RefreshLists then Runtime.UI:RefreshLists() end
    return true, player.Name .. " is now a manual friend."
end

function Lists:RemoveFriendByUserId(userId)
    userId = tonumber(userId)
    local entry = userId and self.Friends[userId]
    if not entry then return false, "That player is not in the manual friend list." end
    self.Friends[userId] = nil
    if Runtime.UI and Runtime.UI.RefreshLists then Runtime.UI:RefreshLists() end
    return true, entry.Name .. " removed from manual friends."
end

function Lists:AddBlacklist(query)
    local player, reason = self:ResolveLive(query)
    if not player then return false, reason end
    self.Friends[player.UserId] = nil
    self.Blacklist[player.UserId] = self:EntryForPlayer(player)
    if Runtime.UI and Runtime.UI.RefreshLists then Runtime.UI:RefreshLists() end
    return true, player.Name .. " is now blacklisted."
end

function Lists:RemoveBlacklistByUserId(userId)
    userId = tonumber(userId)
    local entry = userId and self.Blacklist[userId]
    if not entry then return false, "That player is not in the blacklist." end
    self.Blacklist[userId] = nil
    if Runtime.UI and Runtime.UI.RefreshLists then Runtime.UI:RefreshLists() end
    return true, entry.Name .. " removed from blacklist."
end

function Lists:GetColor(player)
    if self:IsBlacklisted(player) then return Config.ESP.BlacklistColor end
    if self:IsFriend(player) then return Config.ESP.FriendColor end
    return Config.ESP.NormalColor
end

function Lists:GetRole(player)
    if self:IsBlacklisted(player) then return "BLACKLIST" end
    if self:IsFriend(player) then
        return self.Friends[player.UserId] and "FRIEND" or "ROBLOX FRIEND"
    end
    return nil
end

function Lists:GetFriendItems()
    local byId = {}
    for userId, entry in pairs(self.Friends) do
        byId[userId] = {Label = entry.DisplayName, Description = "@" .. entry.Name .. "  • manual", Value = userId}
    end
    if Config.Lists.AutoDetectRobloxFriends then
        for userId, enabled in pairs(self.AutoFriends) do
            if enabled and not self.Blacklist[userId] and not byId[userId] then
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    byId[userId] = {Label = player.DisplayName, Description = "@" .. player.Name .. "  • Roblox friend", Value = userId}
                end
            end
        end
    end
    local items = {}
    for _, item in pairs(byId) do table.insert(items, item) end
    table.sort(items, function(a, b) return string.lower(a.Label) < string.lower(b.Label) end)
    return items
end

function Lists:GetBlacklistItems()
    local items = {}
    for userId, entry in pairs(self.Blacklist) do
        table.insert(items, {Label = entry.DisplayName, Description = "@" .. entry.Name, Value = userId})
    end
    table.sort(items, function(a, b) return string.lower(a.Label) < string.lower(b.Label) end)
    return items
end
-- Player ESP. Fixed professional layout: corner box + health + identity + highlight + skeleton.
local ESP = {
    Records = {},
}
Runtime.ESP = ESP

local R15_JOINT_NAMES = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local R6_JOINT_NAMES = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local function makeFrame(parent, zIndex)
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.Visible = false
    frame.ZIndex = zIndex or 10
    frame.Parent = parent
    return frame
end

local function makeOutlinedLine(parent, thickness, zIndex)
    return {
        Back = makeFrame(parent, (zIndex or 10) - 1),
        Front = makeFrame(parent, zIndex or 10),
        Thickness = thickness or 1,
    }
end

local function setLine(bundle, a, b, color, visible, transparency)
    if not bundle then
        return
    end
    if not visible then
        bundle.Back.Visible = false
        bundle.Front.Visible = false
        return
    end
    local delta = b - a
    local length = delta.Magnitude
    if length < 0.5 then
        bundle.Back.Visible = false
        bundle.Front.Visible = false
        return
    end

    local center = (a + b) * 0.5
    local rotation = math.deg(math.atan2(delta.Y, delta.X))
    local thickness = bundle.Thickness

    bundle.Back.Position = UDim2.fromOffset(center.X, center.Y)
    bundle.Back.Size = UDim2.fromOffset(length + 1, thickness + 2)
    bundle.Back.Rotation = rotation
    bundle.Back.BackgroundColor3 = Color3.fromRGB(4, 5, 7)
    bundle.Back.BackgroundTransparency = math.clamp((transparency or 0) + 0.15, 0, 0.8)
    bundle.Back.Visible = true

    bundle.Front.Position = UDim2.fromOffset(center.X, center.Y)
    bundle.Front.Size = UDim2.fromOffset(length, thickness)
    bundle.Front.Rotation = rotation
    bundle.Front.BackgroundColor3 = color
    bundle.Front.BackgroundTransparency = transparency or 0
    bundle.Front.Visible = true
end

local function makeText(parent, size, bold)
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromOffset(360, 22)
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
    label.TextSize = size
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.05
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 30
    label.Visible = false
    label.Parent = parent
    return label
end

function ESP:CreateOverlay()
    if self.Gui and self.Gui.Parent then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "RenCriminalityESP"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 990
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = Runtime:AddInstance(gui)
end

function ESP:HideRecord(record)
    if not record then
        return
    end
    record.Container.Visible = false
    if record.Highlight then
        record.Highlight.Enabled = false
    end
end

function ESP:DestroyRecord(player)
    local record = self.Records[player]
    if not record then
        return
    end
    pcall(function()
        record.Container:Destroy()
    end)
    if record.Highlight then
        pcall(function()
            record.Highlight:Destroy()
        end)
    end
    self.Records[player] = nil
end

function ESP:BuildJoints(character)
    local names = character:FindFirstChild("UpperTorso") and R15_JOINT_NAMES or R6_JOINT_NAMES
    local joints = {}
    for _, pair in ipairs(names) do
        table.insert(joints, {
            character:FindFirstChild(pair[1]),
            character:FindFirstChild(pair[2]),
        })
    end
    return joints
end

function ESP:CreateRecord(player, character)
    self:CreateOverlay()
    self:DestroyRecord(player)

    local humanoid = Game.GetHumanoid(character)
    local root = Game.GetRoot(character)
    if not humanoid or not root then
        return nil
    end

    local container = Instance.new("Frame")
    container.Name = "Player_" .. player.Name
    container.BackgroundTransparency = 1
    container.Size = UDim2.fromScale(1, 1)
    container.Visible = false
    container.Parent = self.Gui

    local corners = {}
    for index = 1, 8 do
        corners[index] = makeOutlinedLine(container, 1.5, 18)
    end

    local skeleton = {}
    for index = 1, #R15_JOINT_NAMES do
        skeleton[index] = makeOutlinedLine(container, 1.25, 15)
    end

    local healthBack = Instance.new("Frame")
    healthBack.BorderSizePixel = 0
    healthBack.BackgroundColor3 = Color3.fromRGB(5, 7, 10)
    healthBack.ZIndex = 19
    healthBack.Parent = container

    local healthFill = Instance.new("Frame")
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.BorderSizePixel = 0
    healthFill.BackgroundColor3 = Color3.fromRGB(84, 230, 118)
    healthFill.ZIndex = 20
    healthFill.Parent = container

    local nameLabel = makeText(container, 14, true)
    local infoLabel = makeText(container, 12, false)

    local highlight = Instance.new("Highlight")
    highlight.Name = "RenESP"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.76
    highlight.OutlineTransparency = 0.08
    highlight.Enabled = false
    highlight.Parent = character

    local record = {
        Player = player,
        Character = character,
        Humanoid = humanoid,
        Root = root,
        Container = container,
        Corners = corners,
        SkeletonLines = skeleton,
        Joints = self:BuildJoints(character),
        JointsBuiltAt = os.clock(),
        HealthBack = healthBack,
        HealthFill = healthFill,
        NameLabel = nameLabel,
        InfoLabel = infoLabel,
        Highlight = highlight,
    }
    self.Records[player] = record
    return record
end

function ESP:SetCornerBox(record, left, top, right, bottom, color)
    local width = right - left
    local height = bottom - top
    local corner = math.clamp(math.min(width, height) * 0.28, 2, 16)
    local c = record.Corners
    setLine(c[1], Vector2.new(left, top), Vector2.new(left + corner, top), color, true)
    setLine(c[2], Vector2.new(left, top), Vector2.new(left, top + corner), color, true)
    setLine(c[3], Vector2.new(right - corner, top), Vector2.new(right, top), color, true)
    setLine(c[4], Vector2.new(right, top), Vector2.new(right, top + corner), color, true)
    setLine(c[5], Vector2.new(left, bottom - corner), Vector2.new(left, bottom), color, true)
    setLine(c[6], Vector2.new(left, bottom), Vector2.new(left + corner, bottom), color, true)
    setLine(c[7], Vector2.new(right, bottom - corner), Vector2.new(right, bottom), color, true)
    setLine(c[8], Vector2.new(right - corner, bottom), Vector2.new(right, bottom), color, true)
end

function ESP:UpdateSkeleton(record, color, shouldRender)
    if not Config.ESP.Skeleton or not shouldRender then
        for _, line in ipairs(record.SkeletonLines) do
            setLine(line, Vector2.zero, Vector2.zero, color, false)
        end
        return
    end

    if os.clock() - record.JointsBuiltAt > 1.5 then
        record.Joints = self:BuildJoints(record.Character)
        record.JointsBuiltAt = os.clock()
    end

    for index, line in ipairs(record.SkeletonLines) do
        local joint = record.Joints[index]
        local a = joint and joint[1]
        local b = joint and joint[2]
        if a and a.Parent and b and b.Parent then
            local a2d, aVisible = Game.WorldToScreen(a.Position)
            local b2d, bVisible = Game.WorldToScreen(b.Position)
            if a2d and b2d and aVisible and bVisible then
                setLine(line, a2d, b2d, color, true, 0.08)
            else
                setLine(line, Vector2.zero, Vector2.zero, color, false)
            end
        else
            setLine(line, Vector2.zero, Vector2.zero, color, false)
        end
    end
end

function ESP:UpdatePlayer(player)
    if player == LocalPlayer then
        self:DestroyRecord(player)
        return
    end

    local character = Game.GetCharacter(player)
    local record = self.Records[player]
    if not character then
        if record then self:HideRecord(record) end
        return
    end

    if not record or record.Character ~= character then
        record = self:CreateRecord(player, character)
        if not record then return end
    end

    local humanoid = Game.GetHumanoid(character)
    local root = Game.GetRoot(character)
    if not Config.ESP.Enabled or not humanoid or humanoid.Health <= 0 or not root then
        self:HideRecord(record)
        return
    end

    record.Humanoid = humanoid
    record.Root = root

    local camera = Workspace.CurrentCamera
    if not camera then
        self:HideRecord(record)
        return
    end

    local topWorld = root.Position + Vector3.new(0, 3.35, 0)
    local bottomWorld = root.Position - Vector3.new(0, 3.15, 0)
    local topPoint, topOnScreen = camera:WorldToViewportPoint(topWorld)
    local bottomPoint, bottomOnScreen = camera:WorldToViewportPoint(bottomWorld)
    if topPoint.Z <= 0 or bottomPoint.Z <= 0 or not topOnScreen or not bottomOnScreen then
        record.Container.Visible = false
        if record.Highlight then
            local color = Lists:GetColor(player)
            record.Highlight.Enabled = Config.ESP.Highlight
            record.Highlight.FillColor = color
            record.Highlight.OutlineColor = color
        end
        return
    end

    local rawHeight = math.abs(bottomPoint.Y - topPoint.Y)
    local maxHeight = math.max(80, camera.ViewportSize.Y * 0.86)
    local height = math.clamp(rawHeight, 7, maxHeight)
    local width = math.clamp(height * 0.47, 4, maxHeight * 0.48)
    local centerX = (topPoint.X + bottomPoint.X) * 0.5
    local centerY = (topPoint.Y + bottomPoint.Y) * 0.5
    local top = centerY - height * 0.5
    local bottom = centerY + height * 0.5
    local left = centerX - width * 0.5
    local right = centerX + width * 0.5
    local color = Lists:GetColor(player)
    local farLod = rawHeight < 20
    local midLod = rawHeight < 38

    record.Container.Visible = true
    self:SetCornerBox(record, left, top, right, bottom, color)

    local healthRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    local showHealthBar = Config.ESP.ShowHealth and not farLod
    record.HealthBack.Visible = showHealthBar
    record.HealthFill.Visible = showHealthBar
    if showHealthBar then
        local barWidth = midLod and 3 or 4
        record.HealthBack.Position = UDim2.fromOffset(left - 6, top)
        record.HealthBack.Size = UDim2.fromOffset(barWidth, height)
        record.HealthFill.Position = UDim2.fromOffset(left - 5, bottom - 1)
        record.HealthFill.Size = UDim2.fromOffset(math.max(1, barWidth - 2), math.max(1, (height - 2) * healthRatio))
        record.HealthFill.BackgroundColor3 = Color3.fromHSV(healthRatio * 0.33, 0.82, 0.95)
    end

    if Config.ESP.ShowIdentity then
        local identity
        if farLod then
            identity = "@" .. player.Name
        else
            identity = player.DisplayName ~= player.Name
                and (player.DisplayName .. "  @" .. player.Name)
                or ("@" .. player.Name)
        end
        local role = Lists:GetRole(player)
        if role then identity ..= "  [" .. role .. "]" end
        record.NameLabel.Text = identity
        record.NameLabel.TextColor3 = color
        record.NameLabel.TextSize = farLod and 10 or (midLod and 11 or 14)
        record.NameLabel.Position = UDim2.fromOffset(centerX, top - (farLod and 8 or 12))
        record.NameLabel.Visible = true
    else
        record.NameLabel.Visible = false
    end

    local info = {}
    if Config.ESP.ShowHealth and not farLod then
        table.insert(info, string.format("%d HP", math.max(0, math.floor(humanoid.Health + 0.5))))
    end
    if Config.ESP.ShowDistance then
        table.insert(info, string.format("%dm", math.floor(Game.GetDistanceFromLocal(root.Position) + 0.5)))
    end
    record.InfoLabel.Text = table.concat(info, "   ")
    record.InfoLabel.TextColor3 = Color3.fromRGB(230, 233, 239)
    record.InfoLabel.TextSize = farLod and 9 or (midLod and 10 or 12)
    record.InfoLabel.Position = UDim2.fromOffset(centerX, bottom + (farLod and 7 or 10))
    record.InfoLabel.Visible = #info > 0

    self:UpdateSkeleton(record, color, rawHeight >= 30)

    if record.Highlight then
        record.Highlight.Enabled = Config.ESP.Highlight
        record.Highlight.FillColor = color
        record.Highlight.OutlineColor = color
        record.Highlight.FillTransparency = farLod and 0.88 or 0.76
        record.Highlight.OutlineTransparency = farLod and 0.18 or 0.08
    end
end

function ESP:UpdateAll()
    if Runtime.Destroyed then
        return
    end
    if not Config.ESP.Enabled then
        for _, record in pairs(self.Records) do
            self:HideRecord(record)
        end
        return
    end
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            seen[player] = true
            self:UpdatePlayer(player)
        end
    end
    for player in pairs(self.Records) do
        if not seen[player] or not player.Parent then
            self:DestroyRecord(player)
        end
    end
end

function ESP:Destroy()
    for player in pairs(self.Records) do
        self:DestroyRecord(player)
    end
end

-- Vault/Register/Crate ESP. Detection remains Criminality-specific; rendering mirrors Player ESP.
local WorldESP = {
    Records = {},
    ScanClock = 0,
    BoundsRefresh = 2.0,
    -- Roblox only renders a limited number of Highlight instances. Reserve the
    -- available slots for players first so a busy map cannot erase player ESP.
    HighlightLimit = 31,
    HighlightReserve = 2,
}
Runtime.WorldESP = WorldESP

local TAKEN_STATE_NAMES = {
    taken = true,
    looted = true,
    claimed = true,
    collected = true,
    empty = true,
    emptied = true,
    depleted = true,
    robbed = true,
    broken = true,
}

function WorldESP:CreateOverlay()
    if self.Gui and self.Gui.Parent then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "RenCriminalityWorldESP"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 988
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = Runtime:AddInstance(gui)
end

function WorldESP:GetPrimary(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true) end
    return object:FindFirstChildWhichIsA("BasePart", true)
end

function WorldESP:IsSupplyCrate(object)
    return object and object.Name == "SupplyCrate"
end

function WorldESP:HasTakenState(object)
    if not object then return true end
    for name, value in pairs(object:GetAttributes()) do
        if TAKEN_STATE_NAMES[normalizedStateName(name)] and (value == true or tonumber(value) == 1) then
            return true
        end
    end
    local values = object:FindFirstChild("Values")
    if values then
        for _, child in ipairs(values:GetChildren()) do
            local key = normalizedStateName(child.Name)
            if TAKEN_STATE_NAMES[key] then
                if child:IsA("BoolValue") and child.Value then return true end
                if (child:IsA("IntValue") or child:IsA("NumberValue")) and child.Value ~= 0 then return true end
            end
        end
    end
    return false
end

function WorldESP:IsUsable(object)
    if not object or not object.Parent or self:HasTakenState(object) then return false end

    local values = object:FindFirstChild("Values")
    local broken = values and values:FindFirstChild("Broken")
    if broken and broken:IsA("BoolValue") and broken.Value then return false end
    local health = values and values:FindFirstChild("Health")
    if health and tonumber(health.Value) and tonumber(health.Value) <= 0 then return false end

    if self:IsSupplyCrate(object) then
        local contents = object:FindFirstChild("Contents", true) or object:FindFirstChild("Loot", true) or object:FindFirstChild("Items", true)
        if contents and #contents:GetChildren() == 0 then return false end
        local physical = object:FindFirstChildWhichIsA("BasePart", true)
        if not physical then return false end
    end
    return true
end

function WorldESP:GetTypeAndColor(object)
    if self:IsSupplyCrate(object) then return "SUPPLY CRATE", Config.WorldESP.CrateColor end
    local name = tostring(object.Name or "OBJECT")
    if string.find(string.lower(name), "register", 1, true) then
        return string.upper(name), Config.WorldESP.RegisterColor
    end
    if string.find(string.lower(name), "safe", 1, true) or string.find(string.lower(name), "vault", 1, true) then
        return string.upper(name), Config.WorldESP.VaultColor
    end
    return string.upper(name), Config.WorldESP.VaultColor
end

local function safeNumericProperty(instance, property)
    if not instance then return nil end
    local ok, value = pcall(function() return instance[property] end)
    return ok and tonumber(value) or nil
end

function WorldESP:CalculateBounds(object, primary)
    if not object or not primary then return CFrame.new(primary and primary.Position or Vector3.zero), Vector3.new(3, 3, 3) end
    if object:IsA("Model") then
        local ok, cf, size = pcall(function() return object:GetBoundingBox() end)
        if ok and cf and size then return cf, size end
    end

    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
    local found = false
    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA("BasePart") then
            found = true
            local half = descendant.Size * 0.5
            local p = descendant.Position
            minV = Vector3.new(math.min(minV.X, p.X - half.X), math.min(minV.Y, p.Y - half.Y), math.min(minV.Z, p.Z - half.Z))
            maxV = Vector3.new(math.max(maxV.X, p.X + half.X), math.max(maxV.Y, p.Y + half.Y), math.max(maxV.Z, p.Z + half.Z))
        end
    end
    if not found then return primary.CFrame, Vector3.new(3, 3, 3) end
    local center = (minV + maxV) * 0.5
    return CFrame.new(center), Vector3.new(math.max(0.5, maxV.X - minV.X), math.max(0.5, maxV.Y - minV.Y), math.max(0.5, maxV.Z - minV.Z))
end

function WorldESP:RefreshBounds(record, force)
    if not record or not record.Object or not record.Primary then return end
    local now = os.clock()
    if not force and record.BoundsTime and now - record.BoundsTime < self.BoundsRefresh then return end
    local cf, size = self:CalculateBounds(record.Object, record.Primary)
    record.CenterOffset = record.Primary.CFrame:PointToObjectSpace(cf.Position)
    record.WorldSize = size
    record.BoundsTime = now
end

function WorldESP:HideRecord(record)
    if not record then return end
    record.Container.Visible = false
    if record.Highlight then record.Highlight.Enabled = false end
end

function WorldESP:DestroyRecord(object)
    local record = self.Records[object]
    if not record then return end
    pcall(function() record.Container:Destroy() end)
    if record.Highlight then pcall(function() record.Highlight:Destroy() end) end
    self.Records[object] = nil
end

function WorldESP:CreateRecord(object)
    self:CreateOverlay()
    self:DestroyRecord(object)
    local primary = self:GetPrimary(object)
    if not primary then return nil end

    local container = Instance.new("Frame")
    container.Name = "World_" .. tostring(object.Name)
    container.BackgroundTransparency = 1
    container.Size = UDim2.fromScale(1, 1)
    container.Visible = false
    container.Parent = self.Gui

    local corners = {}
    for index = 1, 8 do corners[index] = makeOutlinedLine(container, 1.35, 18) end

    local healthBack = Instance.new("Frame")
    healthBack.BorderSizePixel = 0
    healthBack.BackgroundColor3 = Color3.fromRGB(5, 7, 10)
    healthBack.ZIndex = 19
    healthBack.Parent = container

    local healthFill = Instance.new("Frame")
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.BorderSizePixel = 0
    healthFill.BackgroundColor3 = Color3.fromRGB(84, 230, 118)
    healthFill.ZIndex = 20
    healthFill.Parent = container

    local title = makeText(container, 13, true)
    local info = makeText(container, 11, false)

    local highlight = Instance.new("Highlight")
    highlight.Name = "RenWorldESP"
    highlight.Adornee = object:IsA("Model") and object or primary
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.86
    highlight.OutlineTransparency = 0.08
    highlight.Enabled = false
    highlight.Parent = primary

    local record = {
        Object = object,
        Primary = primary,
        Container = container,
        Corners = corners,
        HealthBack = healthBack,
        HealthFill = healthFill,
        Title = title,
        Info = info,
        Highlight = highlight,
    }
    self.Records[object] = record
    self:RefreshBounds(record, true)
    return record
end

function WorldESP:UpdateRecord(object, record, allowHighlight)
    -- Expensive taken/broken/loot-state checks are handled by Discover().
    -- The render loop only projects already-valid records so movement stays frame-synchronous.
    if not Config.WorldESP.Enabled or not object or not object.Parent then
        self:HideRecord(record)
        return
    end

    local primary = self:GetPrimary(object)
    local camera = Workspace.CurrentCamera
    if not primary or not camera then
        self:HideRecord(record)
        return
    end
    if record.Primary ~= primary then
        record.Primary = primary
        self:RefreshBounds(record, true)
    else
        self:RefreshBounds(record, false)
    end

    local colorName, color = self:GetTypeAndColor(object)
    record.Highlight.Enabled = allowHighlight == true
    record.Highlight.FillColor = color
    record.Highlight.OutlineColor = color

    local worldSize = record.WorldSize or Vector3.new(3, 3, 3)
    local centerWorld = primary.CFrame:PointToWorldSpace(record.CenterOffset or Vector3.zero)
    local halfY = math.max(worldSize.Y * 0.5, 0.65)
    local halfX = math.max(worldSize.X * 0.5, 0.65)
    local topPoint, topOn = camera:WorldToViewportPoint(centerWorld + Vector3.new(0, halfY, 0))
    local bottomPoint, bottomOn = camera:WorldToViewportPoint(centerWorld - Vector3.new(0, halfY, 0))
    local leftPoint = camera:WorldToViewportPoint(centerWorld - camera.CFrame.RightVector * halfX)
    local rightPoint = camera:WorldToViewportPoint(centerWorld + camera.CFrame.RightVector * halfX)

    if topPoint.Z <= 0 or bottomPoint.Z <= 0 or not topOn or not bottomOn then
        record.Container.Visible = false
        return
    end

    local rawHeight = math.abs(bottomPoint.Y - topPoint.Y)
    local rawWidth = math.abs(rightPoint.X - leftPoint.X)
    local maxHeight = math.max(72, camera.ViewportSize.Y * 0.38)
    local height = math.clamp(rawHeight, 5, maxHeight)
    local width = math.clamp(rawWidth, 5, math.max(90, maxHeight * 1.35))
    local centerX = (leftPoint.X + rightPoint.X) * 0.5
    local centerY = (topPoint.Y + bottomPoint.Y) * 0.5
    local top = centerY - height * 0.5
    local bottom = centerY + height * 0.5
    local left = centerX - width * 0.5
    local right = centerX + width * 0.5
    local farLod = rawHeight < 13 or Game.GetDistanceFromLocal(primary.Position) > 650
    local midLod = rawHeight < 28 or Game.GetDistanceFromLocal(primary.Position) > 350

    record.Container.Visible = true
    ESP:SetCornerBox(record, left, top, right, bottom, color)

    local values = object:FindFirstChild("Values")
    local healthRatio
    local healthText
    if not self:IsSupplyCrate(object) and Config.WorldESP.ShowHealth then
        local health = values and values:FindFirstChild("Health")
        if health then
            local current = tonumber(health.Value) or 0
            local maximum = safeNumericProperty(health, "MaxValue") or tonumber(health:GetAttribute("Max")) or tonumber(health:GetAttribute("Maximum")) or 100
            healthRatio = math.clamp(current / math.max(maximum, 1), 0, 1)
            healthText = string.format("%d%% HP", math.floor(healthRatio * 100 + 0.5))
        end
    end

    local showBar = healthRatio ~= nil and not farLod
    record.HealthBack.Visible = showBar
    record.HealthFill.Visible = showBar
    if showBar then
        local barWidth = midLod and 3 or 4
        record.HealthBack.Position = UDim2.fromOffset(left - 6, top)
        record.HealthBack.Size = UDim2.fromOffset(barWidth, height)
        record.HealthFill.Position = UDim2.fromOffset(left - 5, bottom - 1)
        record.HealthFill.Size = UDim2.fromOffset(math.max(1, barWidth - 2), math.max(1, (height - 2) * healthRatio))
        record.HealthFill.BackgroundColor3 = Color3.fromHSV(healthRatio * 0.33, 0.82, 0.95)
    end

    record.Title.Text = colorName
    record.Title.TextColor3 = color
    record.Title.TextSize = farLod and 9 or (midLod and 10 or 13)
    record.Title.Position = UDim2.fromOffset(centerX, top - (farLod and 7 or 11))
    record.Title.Visible = true

    local infoParts = {}
    if healthText and not farLod then table.insert(infoParts, healthText) end
    if not self:IsSupplyCrate(object) and Config.WorldESP.ShowDrop and not farLod then
        local drop = values and values:FindFirstChild("DropA")
        if drop then
            local minimum = safeNumericProperty(drop, "MinValue") or tonumber(drop:GetAttribute("Min")) or 0
            local maximum = safeNumericProperty(drop, "MaxValue") or tonumber(drop:GetAttribute("Max")) or tonumber(drop.Value) or 0
            table.insert(infoParts, string.format("$%d-$%d", minimum, maximum))
        end
    end
    if Config.WorldESP.ShowDistance then
        table.insert(infoParts, string.format("%dm", math.floor(Game.GetDistanceFromLocal(primary.Position) + 0.5)))
    end
    record.Info.Text = table.concat(infoParts, "   ")
    record.Info.TextColor3 = Color3.fromRGB(230, 233, 239)
    record.Info.TextSize = farLod and 8 or (midLod and 9 or 11)
    record.Info.Position = UDim2.fromOffset(centerX, bottom + (farLod and 6 or 9))
    record.Info.Visible = #infoParts > 0

    record.Highlight.FillTransparency = farLod and 0.94 or (midLod and 0.9 or 0.86)
    record.Highlight.OutlineTransparency = farLod and 0.2 or 0.08
end

function WorldESP:Discover()
    if not Config.WorldESP.Enabled then return end
    local found = {}
    local map = Workspace:FindFirstChild("Map")
    local bredMakurz = map and map:FindFirstChild("BredMakurz")
    if bredMakurz then
        for _, object in ipairs(bredMakurz:GetChildren()) do
            if (object:IsA("Model") or object:IsA("Folder")) and self:IsUsable(object) then found[object] = true end
        end
    end
    local debris = Workspace:FindFirstChild("Debris")
    local vParts = debris and debris:FindFirstChild("VParts")
    if vParts then
        for _, object in ipairs(vParts:GetChildren()) do
            if object.Name == "SupplyCrate" and self:IsUsable(object) then found[object] = true end
        end
    end
    for object in pairs(found) do
        if not self.Records[object] then self:CreateRecord(object) end
    end
    for object in pairs(self.Records) do
        if not found[object] or not object.Parent or not self:IsUsable(object) then self:DestroyRecord(object) end
    end
end

function WorldESP:UpdateAll()
    if Runtime.Destroyed then return end
    if not Config.WorldESP.Enabled then
        for _, record in pairs(self.Records) do self:HideRecord(record) end
        return
    end
    local localRoot = Game.GetLocalRoot()
    local candidates = {}
    for object, record in pairs(self.Records) do
        if object.Parent and record.Primary and record.Primary.Parent then
            local distance = localRoot and (record.Primary.Position - localRoot.Position).Magnitude or math.huge
            table.insert(candidates, {Object = object, Distance = distance})
        end
    end
    table.sort(candidates, function(a, b) return a.Distance < b.Distance end)

    local playerHighlightCount = 0
    if Config.ESP.Enabled and Config.ESP.Highlight then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and Game.IsAlive(player) then
                playerHighlightCount += 1
            end
        end
    end
    local worldHighlightBudget = math.max(0, self.HighlightLimit - self.HighlightReserve - playerHighlightCount)
    local highlighted = {}
    for index = 1, math.min(worldHighlightBudget, #candidates) do
        highlighted[candidates[index].Object] = true
    end

    for object, record in pairs(self.Records) do
        if object.Parent then
            self:UpdateRecord(object, record, highlighted[object] == true)
        else
            self:DestroyRecord(object)
        end
    end
end

function WorldESP:Destroy()
    for object in pairs(self.Records) do self:DestroyRecord(object) end
end

-- Aim engine: sticky targeting, low-rate acquisition, adaptive prediction without a user prediction slider.
local Aim = {
    CurrentTarget = nil,
    LastAcquire = 0,
    AcquireInterval = 0.075,
    LastWallCheck = 0,
    CachedWallClear = false,
    PingSeconds = 0.065,
    ManualOverrideUntil = 0,
    ManualOverrideDuration = 0.12,
    MouseOverrideThreshold = 7.5,
    StickFOVMultiplier = 1.35,
    TargetGraceDuration = 0.22,
    LastTargetValidAt = 0,
    LastPingUpdate = 0,
    Motion = {},
}
Runtime.Aim = Aim

function Aim:CreateFOV()
    if self.Gui and self.Gui.Parent then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "RenCriminalityAim"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 980
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = Runtime:AddInstance(gui)

    local circle = Instance.new("Frame")
    circle.Name = "FOV"
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1
    circle.Visible = false
    circle.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = circle

    self.Circle = circle
    self.CircleStroke = stroke
end

function Aim:UpdatePing(now)
    if now - self.LastPingUpdate < 0.75 then
        return
    end
    self.LastPingUpdate = now
    local ok, milliseconds = pcall(function()
        local network = Services.Stats:FindFirstChild("Network")
        local server = network and network:FindFirstChild("ServerStatsItem")
        local pingItem = server and server:FindFirstChild("Data Ping")
        return pingItem and pingItem:GetValue() or nil
    end)
    if ok and type(milliseconds) == "number" and milliseconds > 0 then
        local seconds = math.clamp(milliseconds / 1000, 0.015, 0.35)
        self.PingSeconds += (seconds - self.PingSeconds) * 0.25
    end
end

function Aim:GetTargetPart(player)
    local character = Game.GetCharacter(player)
    if not character then
        return nil, nil, nil
    end
    local target = character:FindFirstChild(Config.Aim.TargetPart)
        or Game.GetHead(character)
        or Game.GetRoot(character)
    return target, character, Game.GetRoot(character)
end

function Aim:IsWallClear(character, targetPosition)
    if not Config.Aim.WallCheck then
        return true
    end
    local camera = Workspace.CurrentCamera
    if not camera then
        return false
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local localCharacter = Game.GetCharacter(LocalPlayer)
    params.FilterDescendantsInstances = localCharacter and {localCharacter, camera} or {camera}
    params.IgnoreWater = true
    local result = Workspace:Raycast(camera.CFrame.Position, targetPosition - camera.CFrame.Position, params)
    return result == nil or (character and result.Instance:IsDescendantOf(character))
end

function Aim:IsEligible(player, allowOutsideFov)
    if player == LocalPlayer or not Game.IsCombatEligible(player) then
        return false
    end
    if Config.Aim.IgnoreFriends and Lists:IsFriend(player) then
        return false
    end

    local target, character = self:GetTargetPart(player)
    local camera = Workspace.CurrentCamera
    if not target or not camera then
        return false
    end

    local point, onScreen = camera:WorldToViewportPoint(target.Position)
    if point.Z <= 0 then
        return false
    end
    if not onScreen and not allowOutsideFov then
        return false
    end

    local center = camera.ViewportSize * 0.5
    local screenDistance = (Vector2.new(point.X, point.Y) - center).Magnitude
    if not allowOutsideFov and screenDistance > Config.Aim.FOV then
        return false
    end

    if Config.Aim.WallCheck and not self:IsWallClear(character, target.Position) then
        return false
    end
    return true, screenDistance
end

function Aim:AcquireTarget(now)
    if now - self.LastAcquire < self.AcquireInterval then
        return self.CurrentTarget
    end
    self.LastAcquire = now

    local current = self.CurrentTarget
    if Config.Aim.StickToTarget and current and Game.IsCombatEligible(current) and not (Config.Aim.IgnoreFriends and Lists:IsFriend(current)) then
        local target, character = self:GetTargetPart(current)
        local camera = Workspace.CurrentCamera
        if target and camera then
            local point, onScreen = camera:WorldToViewportPoint(target.Position)
            local center = camera.ViewportSize * 0.5
            local distance = (Vector2.new(point.X, point.Y) - center).Magnitude
            local insideStickyFov = point.Z > 0 and onScreen and distance <= Config.Aim.FOV * self.StickFOVMultiplier
            local wallClear = insideStickyFov and self:IsWallClear(character, target.Position)
            if insideStickyFov and wallClear then
                self.LastTargetValidAt = now
                return current
            end
            -- Brief camera/animation/raycast changes should not throw away a lock.
            if now - self.LastTargetValidAt <= self.TargetGraceDuration then return current end
        end
    end

    local best
    local bestScore = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local eligible, screenDistance = self:IsEligible(player, false)
        if eligible then
            local score = screenDistance
            if Lists:IsBlacklisted(player) then
                -- Blacklist remains a visual/list classification, but equal candidates naturally favor it slightly.
                score *= 0.96
            end
            if score < bestScore then
                bestScore = score
                best = player
            end
        end
    end

    if best ~= self.CurrentTarget then
        self.Motion = {}
        self.LastTargetValidAt = best and now or 0
    end
    self.CurrentTarget = best
    return best
end

function Aim:AdaptivePosition(player, targetPart, rootPart, humanoid, now)
    local camera = Workspace.CurrentCamera
    if not camera or not rootPart then return targetPart.Position end

    local velocity = rootPart.AssemblyLinearVelocity
    local state = self.Motion
    local acceleration = Vector3.zero
    if state.LastVelocity and state.LastTime then
        local dt = math.clamp(now - state.LastTime, 1 / 240, 0.15)
        local rawAcceleration = (velocity - state.LastVelocity) / dt
        if rawAcceleration.Magnitude > 80 then rawAcceleration = rawAcceleration.Unit * 80 end
        acceleration = state.Acceleration and state.Acceleration:Lerp(rawAcceleration, 0.12) or rawAcceleration
    end
    state.LastVelocity = velocity
    state.LastTime = now
    state.Acceleration = acceleration

    local distance = (targetPart.Position - camera.CFrame.Position).Magnitude
    local pingLead = math.clamp(self.PingSeconds * 0.07, 0.001, 0.012)
    local distanceLead = math.clamp(distance / 42000, 0, 0.012)
    local speedLead = math.clamp(velocity.Magnitude / 14000, 0, 0.006)
    local horizon = math.clamp(0.003 + pingLead + distanceLead + speedLead, 0.004, 0.035)

    local lead = velocity * horizon + acceleration * (0.5 * horizon * horizon)
    local horizontal = Vector3.new(lead.X, 0, lead.Z)
    if horizontal.Magnitude > 2.0 then horizontal = horizontal.Unit * 2.0 end
    local vertical = math.clamp(lead.Y, -0.9, 0.9)
    if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then vertical = math.clamp(vertical, -0.35, 0.35) end
    return targetPart.Position + horizontal + Vector3.new(0, vertical, 0)
end

function Aim:ManualOverride()
    if not Config.Aim.Enabled then return end
    self.ManualOverrideUntil = os.clock() + self.ManualOverrideDuration
end

function Aim:UpdateFOV()
    self:CreateFOV()
    local camera = Workspace.CurrentCamera
    if not camera or not self.Circle then
        return
    end
    local diameter = Config.Aim.FOV * 2
    self.Circle.Position = UDim2.fromOffset(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
    self.Circle.Size = UDim2.fromOffset(diameter, diameter)
    self.Circle.Visible = Config.Aim.Enabled and Config.Aim.ShowFOV
    self.CircleStroke.Color = Config.Aim.FOVColor
    self.CircleStroke.Transparency = Config.Aim.FOVTransparency
end

function Aim:Update(dt)
    if Runtime.Destroyed then
        return
    end

    self:UpdateFOV()
    if not Config.Aim.Enabled or UserInputService:GetFocusedTextBox() then
        self.CurrentTarget = nil
        self.Motion = {}
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local now = os.clock()
    if now < self.ManualOverrideUntil then
        return
    end
    self:UpdatePing(now)
    local player = self:AcquireTarget(now)
    if not player then
        return
    end
    if not Game.IsCombatEligible(player) then
        self.CurrentTarget = nil
        self.Motion = {}
        return
    end

    local targetPart, character, rootPart = self:GetTargetPart(player)
    local humanoid = Game.GetHumanoid(character)
    if not targetPart or not rootPart or not humanoid or humanoid.Health <= 0 then
        self.CurrentTarget = nil
        self.Motion = {}
        return
    end

    local predicted = self:AdaptivePosition(player, targetPart, rootPart, humanoid, now)
    local origin = camera.CFrame.Position
    local delta = predicted - origin
    if delta.Magnitude < 0.01 then
        return
    end

    local desired = CFrame.lookAt(origin, predicted)
    local response = math.clamp(Config.Aim.Response, 0.05, 1)
    -- Exponential smoothing stays frame-rate independent without behaving like
    -- an instant camera snap at ordinary response values.
    local rate = 2.0 + response * 18
    local alpha = response >= 0.995 and 1 or (1 - math.exp(-rate * math.min(dt, 0.1)))
    camera.CFrame = camera.CFrame:Lerp(desired, alpha)
end

function Aim:SetEnabled(enabled)
    Config.Aim.Enabled = enabled == true
    if not Config.Aim.Enabled then
        self.CurrentTarget = nil
        self.Motion = {}
    end
end

-- Survival utilities: targeted Criminality-style paths only; no brute-force descendant loops.
local Survival = {
    LastEnergyPulse = 0,
    StaminaCacheAt = 0,
    StaminaValues = {},
    LastRagdollPulse = 0,
    LastMovementSample = 0,
    RagdollConnection = nil,
    HealthyWalkSpeed = 16,
    HealthyJumpPower = 50,
    HealthyJumpHeight = 7.2,
}
Runtime.Survival = Survival

local STAMINA_STATE_NAMES = {
    stamina = true,
    energy = true,
    endurance = true,
    sprintenergy = true,
    sprintstamina = true,
    currentstamina = true,
    currentenergy = true,
}

function Survival:SetInfiniteStamina(enabled)
    Config.Survival.InfiniteStamina = enabled == true
    if Config.Survival.InfiniteStamina then
        notify("Safe stamina", "Compatibility mode enabled. Unsafe function hooks are disabled.", 3)
    end
end

function Survival:GetStaminaRoots()
    local character = Game.GetCharacter(LocalPlayer)
    local roots, seen = {}, {}
    local function add(root)
        if root and not seen[root] then
            seen[root] = true
            table.insert(roots, root)
        end
    end
    add(LocalPlayer:FindFirstChild("Data"))
    add(LocalPlayer:FindFirstChild("Stats"))
    add(LocalPlayer:FindFirstChild("Values"))
    add(LocalPlayer:FindFirstChild("Settings"))
    add(getSettingsState(LocalPlayer))
    add(character)
    add(Game.GetHumanoid(character))
    return roots
end

function Survival:GetStaminaValues(now)
    now = now or os.clock()
    if now - self.StaminaCacheAt < 0.75 then
        local live = {}
        for _, value in ipairs(self.StaminaValues) do
            if value and value.Parent then table.insert(live, value) end
        end
        if #live > 0 then
            self.StaminaValues = live
            return live
        end
    end

    local found, seen = {}, {}
    local function consider(instance)
        if not instance or seen[instance] then return end
        seen[instance] = true
        local key = normalizedStateName(instance.Name)
        if STAMINA_STATE_NAMES[key] and (instance:IsA("NumberValue") or instance:IsA("IntValue")) then
            table.insert(found, instance)
        end
    end
    for _, root in ipairs(self:GetStaminaRoots()) do
        if root then
            consider(root)
            for _, descendant in ipairs(root:GetDescendants()) do consider(descendant) end
        end
    end
    -- Some places store the value directly under Player rather than in Data.
    for _, child in ipairs(LocalPlayer:GetChildren()) do consider(child) end

    self.StaminaValues = found
    self.StaminaCacheAt = now
    return found
end

function Survival:GetStaminaValue()
    return self:GetStaminaValues(os.clock())[1]
end

function Survival:GetStaminaCeiling(value)
    local current = tonumber(value.Value) or 0
    for _, attribute in ipairs({"Max", "Maximum", "MaxValue", "Capacity"}) do
        local maximum = tonumber(value:GetAttribute(attribute))
        if maximum and maximum > 0 then return math.max(current, maximum) end
    end

    local parent = value.Parent
    if parent then
        local base = normalizedStateName(value.Name)
        local candidates = base == "energy"
            and {"MaxEnergy", "EnergyMax", "MaximumEnergy"}
            or {"MaxStamina", "StaminaMax", "MaximumStamina", "MaxEnergy", "EnergyMax"}
        for _, name in ipairs(candidates) do
            local maximumValue = parent:FindFirstChild(name)
            if maximumValue and (maximumValue:IsA("NumberValue") or maximumValue:IsA("IntValue")) then
                local maximum = tonumber(maximumValue.Value)
                if maximum and maximum > 0 then return math.max(current, maximum) end
            end
            local maximum = tonumber(parent:GetAttribute(name))
            if maximum and maximum > 0 then return math.max(current, maximum) end
        end
    end
    return math.max(current, 100)
end

function Survival:RefillStaminaAttributes()
    for _, root in ipairs(self:GetStaminaRoots()) do
        if root then
            for name, value in pairs(root:GetAttributes()) do
                local key = normalizedStateName(name)
                if STAMINA_STATE_NAMES[key] and type(value) == "number" then
                    local maximum = tonumber(root:GetAttribute("Max" .. name))
                        or tonumber(root:GetAttribute(name .. "Max"))
                        or tonumber(root:GetAttribute("Maximum" .. name))
                        or math.max(value, 100)
                    if value < maximum then pcall(function() root:SetAttribute(name, maximum) end) end
                end
            end
        end
    end
end

function Survival:GetLocalSettingsState()
    return getSettingsState(LocalPlayer)
end

function Survival:ApplyInfiniteStamina(now)
    if not Config.Survival.InfiniteStamina or now - self.LastEnergyPulse < 0.05 then return end
    self.LastEnergyPulse = now

    for _, stamina in ipairs(self:GetStaminaValues(now)) do
        local current = tonumber(stamina.Value) or 0
        local ceiling = self:GetStaminaCeiling(stamina)
        if current < ceiling then pcall(function() stamina.Value = ceiling end) end
    end
    self:RefillStaminaAttributes()
end

function Survival:SampleHealthyMovement(now)
    if now - self.LastMovementSample < 0.45 then return end
    self.LastMovementSample = now
    local character = Game.GetCharacter(LocalPlayer)
    local humanoid = Game.GetHumanoid(character)
    if not humanoid or humanoid.Health <= 0 or Game.IsRagdolled(LocalPlayer) then return end
    if humanoid.WalkSpeed > self.HealthyWalkSpeed then self.HealthyWalkSpeed = humanoid.WalkSpeed end
    if humanoid.JumpPower > 2 then self.HealthyJumpPower = humanoid.JumpPower end
    if humanoid.JumpHeight > 1 then self.HealthyJumpHeight = humanoid.JumpHeight end
end

function Survival:MaintainInfiniteSprintFrame()
    if not Config.Survival.InfiniteStamina then return end
    local character = LocalPlayer.Character or Game.GetCharacter(LocalPlayer)
    local humanoid = Game.GetHumanoid(character)
    if not humanoid or humanoid.Health <= 0 or humanoid.MoveDirection.Magnitude <= 0 then return end

    local sprintHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
    if sprintHeld then
        local sprintSpeed = math.max(Config.Survival.CompatibilitySprintSpeed, self.HealthyWalkSpeed)
        if humanoid.WalkSpeed < sprintSpeed then pcall(function() humanoid.WalkSpeed = sprintSpeed end) end
    end
end

function Survival:RequestJump()
    if not Config.Survival.AntiRagdoll or not Game.IsRagdolled(LocalPlayer) then return end
    local character = Game.GetCharacter(LocalPlayer)
    local humanoid = Game.GetHumanoid(character)
    if not humanoid or humanoid.Health <= 0 then return end
    pcall(function()
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.Jump = true
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end)
end

function Survival:RecoverLocalRagdoll()
    if not Config.Survival.AntiRagdoll then return end
    local character = Game.GetCharacter(LocalPlayer)
    local humanoid = Game.GetHumanoid(character)
    if not character or not humanoid or humanoid.Health <= 0 then return end

    local settingsState = self:GetLocalSettingsState()
    if settingsState then
        for _, name in ipairs({"KnockedOut", "Ragdolled", "Ragdoll", "Downed", "Knocked"}) do
            if settingsState:GetAttribute(name) == true then
                pcall(function() settingsState:SetAttribute(name, false) end)
            end
        end
    end

    for _, instance in ipairs({LocalPlayer, character, humanoid}) do
        if instance then
            for _, name in ipairs({"KnockedOut", "Ragdolled", "Ragdoll", "Downed", "Knocked"}) do
                if instance:GetAttribute(name) == true then pcall(function() instance:SetAttribute(name, false) end) end
            end
        end
    end

    local state = humanoid:GetState()
    if Game.IsRagdolled(LocalPlayer)
        or humanoid.PlatformStand
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics then
        pcall(function() humanoid.PlatformStand = false end)
        pcall(function() humanoid.Sit = false end)
        pcall(function() humanoid.AutoRotate = true end)
        pcall(function()
            if humanoid.WalkSpeed < self.HealthyWalkSpeed then humanoid.WalkSpeed = self.HealthyWalkSpeed end
            if humanoid.UseJumpPower then
                if humanoid.JumpPower < self.HealthyJumpPower then humanoid.JumpPower = self.HealthyJumpPower end
            elseif humanoid.JumpHeight < self.HealthyJumpHeight then
                humanoid.JumpHeight = self.HealthyJumpHeight
            end
        end)
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        task.defer(function()
            if Config.Survival.AntiRagdoll and humanoid.Parent and humanoid.Health > 0 then
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            end
        end)
    end
end

function Survival:PreventRagdollFrame()
    if not Config.Survival.AntiRagdoll then return end
    local character = LocalPlayer.Character or Game.GetCharacter(LocalPlayer)
    local humanoid = Game.GetHumanoid(character)
    if not humanoid or humanoid.Health <= 0 then return end

    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown then
        pcall(function()
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
end

function Survival:BindHumanoid()
    if self.RagdollConnection then pcall(function() self.RagdollConnection:Disconnect() end) end
    self.RagdollConnection = nil
    local humanoid = Game.GetHumanoid(Game.GetCharacter(LocalPlayer))
    if humanoid then
        self.RagdollConnection = humanoid.StateChanged:Connect(function(_, newState)
            if Config.Survival.AntiRagdoll and (
                newState == Enum.HumanoidStateType.Ragdoll
                or newState == Enum.HumanoidStateType.FallingDown
                or newState == Enum.HumanoidStateType.Physics
            ) then
                task.defer(function() self:RecoverLocalRagdoll() end)
            end
        end)
        Runtime:AddConnection(self.RagdollConnection)
    end
end

function Survival:SetAntiRagdoll(enabled)
    Config.Survival.AntiRagdoll = enabled == true
    if Config.Survival.AntiRagdoll then self:RecoverLocalRagdoll() end
end

function Survival:Update(now)
    self:ApplyInfiniteStamina(now)
    self:SampleHealthyMovement(now)
    if Config.Survival.AntiRagdoll and now - self.LastRagdollPulse >= 0.12 then
        self.LastRagdollPulse = now
        self:RecoverLocalRagdoll()
    end
end

-- Lightweight interaction/effect utilities. Everything is path/name gated and reversible where possible.
local Utility = {
    PromptOriginals = setmetatable({}, {__mode = "k"}),
    PromptConnections = setmetatable({}, {__mode = "k"}),
    FPSOriginals = setmetatable({}, {__mode = "k"}),
    LockpickOriginals = setmetatable({}, {__mode = "k"}),
    LockpickConnection = nil,
    PromptCooldowns = setmetatable({}, {__mode = "k"}),
    LastNearby = 0,
    LastMoney = 0,
    LastLockpick = 0,
}
Runtime.Utility = Utility

local function normalizedObjectName(instance)
    return normalizedStateName(instance and instance.Name or "")
end

local function ancestorNameMatches(instance, terms)
    local current = instance
    for _ = 1, 5 do
        if not current then break end
        local key = normalizedObjectName(current)
        for _, term in ipairs(terms) do
            if string.find(key, term, 1, true) then return true end
        end
        current = current.Parent
    end
    return false
end

local function firePromptSafe(prompt)
    if not prompt or not prompt.Parent then return false end
    if type(fireproximityprompt) == "function" then
        local ok = pcall(function() fireproximityprompt(prompt, 0) end)
        if ok then return true end
        return pcall(function() fireproximityprompt(prompt) end)
    end
    return false
end

function Utility:ApplyPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    if not self.PromptConnections[prompt] then
        local connection = prompt.PromptButtonHoldBegan:Connect(function()
            if not Config.Utility.InstantInteract then return end
            pcall(function() prompt.HoldDuration = 0 end)
            task.spawn(function()
                for _ = 1, 3 do
                    if not Config.Utility.InstantInteract or not prompt.Parent then break end
                    pcall(function() prompt:InputHoldBegin() end)
                    task.wait()
                end
            end)
        end)
        self.PromptConnections[prompt] = connection
        Runtime:AddConnection(connection)
    end
    if Config.Utility.InstantInteract then
        if self.PromptOriginals[prompt] == nil then self.PromptOriginals[prompt] = prompt.HoldDuration end
        pcall(function() prompt.HoldDuration = 0 end)
    end
end

function Utility:SetInstantInteract(enabled)
    Config.Utility.InstantInteract = enabled == true
    if enabled then
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") then self:ApplyPrompt(descendant) end
        end
    else
        for prompt, duration in pairs(self.PromptOriginals) do
            if prompt.Parent then pcall(function() prompt.HoldDuration = duration end) end
        end
        table.clear(self.PromptOriginals)
    end
end

function Utility:SetFPSProperty(object, property, value)
    if not object then return end
    local ok, current = pcall(function() return object[property] end)
    if not ok then return end
    local originals = self.FPSOriginals[object]
    if not originals then
        originals = {}
        self.FPSOriginals[object] = originals
    end
    if originals[property] == nil then originals[property] = current end
    pcall(function() object[property] = value end)
end

function Utility:ApplyFPSBooster(instance)
    if not Config.Utility.FPSBooster or not instance then return end
    if instance:IsA("BasePart") then
        self:SetFPSProperty(instance, "CastShadow", false)
        self:SetFPSProperty(instance, "Material", Enum.Material.Plastic)
        self:SetFPSProperty(instance, "MaterialVariant", "")
        self:SetFPSProperty(instance, "Reflectance", 0)
    end
    if instance:IsA("MeshPart") then self:SetFPSProperty(instance, "TextureID", "") end
    if instance:IsA("SpecialMesh") then self:SetFPSProperty(instance, "TextureId", "") end
    if instance:IsA("Decal") or instance:IsA("Texture") then self:SetFPSProperty(instance, "Transparency", 1) end
    if instance:IsA("SurfaceAppearance") then
        self:SetFPSProperty(instance, "ColorMap", "")
        self:SetFPSProperty(instance, "NormalMap", "")
        self:SetFPSProperty(instance, "MetalnessMap", "")
        self:SetFPSProperty(instance, "RoughnessMap", "")
    end
    if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
        or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles")
        or instance:IsA("PostEffect") then
        self:SetFPSProperty(instance, "Enabled", false)
    end
    if instance:IsA("Atmosphere") then
        self:SetFPSProperty(instance, "Density", 0)
        self:SetFPSProperty(instance, "Haze", 0)
        self:SetFPSProperty(instance, "Glare", 0)
    end
    if instance:IsA("Clouds") then self:SetFPSProperty(instance, "Enabled", false) end
    if instance:IsA("Terrain") then
        self:SetFPSProperty(instance, "Decoration", false)
        self:SetFPSProperty(instance, "WaterWaveSize", 0)
        self:SetFPSProperty(instance, "WaterWaveSpeed", 0)
        self:SetFPSProperty(instance, "WaterReflectance", 0)
    end
end

function Utility:SetFPSBooster(enabled)
    Config.Utility.FPSBooster = enabled == true
    if enabled then
        self:SetFPSProperty(Services.Lighting, "GlobalShadows", false)
        self:SetFPSProperty(Services.Lighting, "EnvironmentDiffuseScale", 0)
        self:SetFPSProperty(Services.Lighting, "EnvironmentSpecularScale", 0)
        local okRendering, rendering = pcall(function() return settings().Rendering end)
        if okRendering and rendering then self:SetFPSProperty(rendering, "QualityLevel", Enum.QualityLevel.Level01) end
        self:ApplyFPSBooster(Workspace.Terrain)
        for _, descendant in ipairs(Workspace:GetDescendants()) do self:ApplyFPSBooster(descendant) end
        for _, descendant in ipairs(Services.Lighting:GetDescendants()) do self:ApplyFPSBooster(descendant) end
    else
        for object, properties in pairs(self.FPSOriginals) do
            for property, value in pairs(properties) do pcall(function() object[property] = value end) end
        end
        table.clear(self.FPSOriginals)
    end
end

function Utility:GetNearbyParts(radius)
    local root = Game.GetLocalRoot()
    if not root then return {} end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local character = Game.GetCharacter(LocalPlayer)
    params.FilterDescendantsInstances = character and {character} or {}
    local ok, parts = pcall(function() return Workspace:GetPartBoundsInRadius(root.Position, radius, params) end)
    return ok and parts or {}
end

function Utility:PromptLooksLike(prompt, terms)
    if not prompt then return false end
    local text = normalizedStateName((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "") .. " " .. prompt.Name)
    for _, term in ipairs(terms) do if string.find(text, term, 1, true) then return true end end
    return false
end

function Utility:FirePromptWithCooldown(prompt, cooldown)
    local now = os.clock()
    if (self.PromptCooldowns[prompt] or 0) > now then return false end
    if firePromptSafe(prompt) then
        self.PromptCooldowns[prompt] = now + (cooldown or 0.35)
        return true
    end
    return false
end

function Utility:ProcessNearbyDoors(now)
    if not Config.Utility.UnlockNearbyDoors and not Config.Utility.OpenNearbyDoors then return end
    if now - self.LastNearby < 0.16 then return end
    self.LastNearby = now

    local character = LocalPlayer.Character or Game.GetCharacter(LocalPlayer)
    local humanoid = Game.GetHumanoid(character)
    local root = Game.GetRoot(character)
    if not root or not humanoid or humanoid.Health <= 0 then return end

    local map = Workspace:FindFirstChild("Map")
    local doors = map and map:FindFirstChild("Doors")
    if not doors then return end

    for _, door in ipairs(doors:GetChildren()) do
        local doorBase = door:FindFirstChild("DoorBase")
        if doorBase and doorBase:IsA("BasePart") and (root.Position - doorBase.Position).Magnitude <= 5 then
            local values = door:FindFirstChild("Values")
            local events = door:FindFirstChild("Events")
            local toggle = events and events:FindFirstChild("Toggle")
            if values and toggle and toggle:IsA("RemoteEvent") then
                if Config.Utility.UnlockNearbyDoors then
                    local locked = values:FindFirstChild("Locked")
                    local lock = door:FindFirstChild("Lock")
                    if locked and lock and locked.Value == true then
                        pcall(function() toggle:FireServer("Unlock", lock) end)
                    end
                end
                if Config.Utility.OpenNearbyDoors then
                    local open = values:FindFirstChild("Open")
                    local knob = door:FindFirstChild("Knob2")
                    if open and knob and open.Value == false then
                        pcall(function() toggle:FireServer("Open", knob) end)
                    end
                end
            end
        end
    end
end

function Utility:IsMoneyObject(instance)
    return ancestorNameMatches(instance, {"droppedcash", "dropcash", "cashdrop", "moneydrop", "droppedmoney", "cash"})
end

function Utility:ProcessMoney(now)
    if not Config.Utility.AutoPickupMoney or now - self.LastMoney < 0.10 then return end
    self.LastMoney = now
    local root = Game.GetLocalRoot()
    if not root then return end
    for _, part in ipairs(self:GetNearbyParts(15)) do
        if self:IsMoneyObject(part) then
            local parent = part.Parent
            local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true) or (parent and parent:FindFirstChildWhichIsA("ProximityPrompt", true))
            if prompt then
                self:FirePromptWithCooldown(prompt, 0.22)
            elseif type(firetouchinterest) == "function" then
                pcall(function()
                    firetouchinterest(root, part, 0)
                    firetouchinterest(root, part, 1)
                end)
            end
        end
    end
end

function Utility:ApplyLockpickMagnifier(lockpickGui, waitForChildren)
    if not Config.Utility.NoFailLockpick or not lockpickGui or lockpickGui.Name ~= "LockpickGUI" then return false end
    local function getChild(parent, name)
        if not parent then return nil end
        return waitForChildren and parent:WaitForChild(name, 10) or parent:FindFirstChild(name)
    end

    local mf = getChild(lockpickGui, "MF")
    local lpFrame = getChild(mf, "LP_Frame")
    local frames = getChild(lpFrame, "Frames")
    if not frames then return false end

    local changed = false
    for _, name in ipairs({"B1", "B2", "B3"}) do
        local holder = getChild(frames, name)
        local bar = holder and getChild(holder, "Bar")
        local scale = bar and (bar:FindFirstChild("UIScale") or bar:FindFirstChildOfClass("UIScale"))
        if scale then
            if self.LockpickOriginals[scale] == nil then self.LockpickOriginals[scale] = scale.Scale end
            pcall(function() scale.Scale = 10 end)
            changed = true
        end
    end
    return changed
end

function Utility:AssistLockpick(now)
    if not Config.Utility.NoFailLockpick or now - self.LastLockpick < 0.10 then return end
    self.LastLockpick = now
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local lockpickGui = playerGui and playerGui:FindFirstChild("LockpickGUI")
    if lockpickGui then self:ApplyLockpickMagnifier(lockpickGui, false) end
end

function Utility:SetNoFailLockpick(enabled)
    Config.Utility.NoFailLockpick = enabled == true
    if self.LockpickConnection then
        pcall(function() self.LockpickConnection:Disconnect() end)
        self.LockpickConnection = nil
    end

    if enabled then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then return end
        local existing = playerGui:FindFirstChild("LockpickGUI")
        if existing then self:ApplyLockpickMagnifier(existing, false) end
        self.LockpickConnection = playerGui.ChildAdded:Connect(function(item)
            if item.Name == "LockpickGUI" and Config.Utility.NoFailLockpick then
                task.spawn(function() self:ApplyLockpickMagnifier(item, true) end)
            end
        end)
        Runtime:AddConnection(self.LockpickConnection)
    else
        for scale, original in pairs(self.LockpickOriginals) do
            if scale.Parent then pcall(function() scale.Scale = original end) end
        end
        table.clear(self.LockpickOriginals)
    end
end

function Utility:OnDescendantAdded(descendant)
    if descendant:IsA("ProximityPrompt") then self:ApplyPrompt(descendant) end
    if Config.Utility.FPSBooster then self:ApplyFPSBooster(descendant) end
end

function Utility:Update(now)
    self:ProcessNearbyDoors(now)
    self:ProcessMoney(now)
    self:AssistLockpick(now)
end

-- UI: Visuals, Combat, Players, and Utility. Shortcuts are visible/rebindable.
local UI = {Controls = {}}
Runtime.UI = UI

function UI:GetLivePlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)
    if #names == 0 then
        table.insert(names, "<no players>")
    end
    return names
end

function UI:RefreshLists()
    if self.FriendList then
        self.FriendList:SetItems(Lists:GetFriendItems())
    end
    if self.BlacklistList then
        self.BlacklistList:SetItems(Lists:GetBlacklistItems())
    end
    local live = self:GetLivePlayerNames()
    if self.FriendDropdown then
        self.FriendDropdown:Refresh(live, true)
    end
    if self.BlacklistDropdown then
        self.BlacklistDropdown:Refresh(live, true)
    end
end

function UI:Build()
    local window = RenLib:CreateWindow({
        Name = "Criminality Helper v" .. Runtime.Version,
        SidebarMode = "Dynamic",
        ShowUserProfile = true,
        ProfileUserId = LocalPlayer.UserId,
        ProfileSubtitle = "Criminality runtime",
        EnableGlobalSearch = true,
        BeforeRelaunch = function()
            Runtime:Destroy()
        end,
    })
    self.Window = window

    window:CreateTabCategory("Gameplay")
    local visualsTab = window:CreateTab({Name = "Visuals", Icon = 6034316009})
    local combatTab = window:CreateTab({Name = "Combat", Icon = 6031154871})
    local playersTab = window:CreateTab({Name = "Players", Icon = 6022668898})
    local utilityTab = window:CreateTab({Name = "Utility", Icon = RenLib.Icons.Settings or 6031280882})

    local playerEsp = visualsTab:CreateSection({Name = "Player ESP", Side = "Left"})
    local playerColors = visualsTab:CreateSection({Name = "Player colors", Side = "Right"})
    local worldEsp = visualsTab:CreateSection({Name = "World ESP", Side = "Left"})
    local worldColors = visualsTab:CreateSection({Name = "World colors", Side = "Right"})

    self.Controls.ESP = playerEsp:CreateToggle({
        Name = "Player ESP",
        Flag = "CrimESP",
        Default = Config.ESP.Enabled,
        Callback = function(value)
            Config.ESP.Enabled = value
        end,
    })
    playerEsp:CreateToggle({
        Name = "Skeleton",
        Flag = "CrimSkeleton",
        Default = Config.ESP.Skeleton,
        Callback = function(value)
            Config.ESP.Skeleton = value
        end,
    })
    playerEsp:CreateToggle({
        Name = "Character highlight",
        Flag = "CrimHighlight",
        Default = Config.ESP.Highlight,
        Callback = function(value)
            Config.ESP.Highlight = value
        end,
    })
    playerEsp:CreateToggle({
        Name = "Show health",
        Flag = "CrimHealth",
        Default = Config.ESP.ShowHealth,
        Callback = function(value)
            Config.ESP.ShowHealth = value
        end,
    })
    playerEsp:CreateToggle({
        Name = "Show distance",
        Flag = "CrimDistance",
        Default = Config.ESP.ShowDistance,
        Callback = function(value)
            Config.ESP.ShowDistance = value
        end,
    })
    playerEsp:CreateToggle({
        Name = "Show identity",
        Flag = "CrimIdentity",
        Default = Config.ESP.ShowIdentity,
        Callback = function(value)
            Config.ESP.ShowIdentity = value
        end,
    })
    playerEsp:CreateLabel("Distance LOD automatically reduces skeleton/text/health clutter on far targets.")

    playerColors:CreateColorPicker({
        Name = "Normal player",
        Flag = "CrimNormalColor",
        Default = Config.ESP.NormalColor,
        Callback = function(value)
            Config.ESP.NormalColor = value
        end,
    })
    playerColors:CreateColorPicker({
        Name = "Friend",
        Flag = "CrimFriendColor",
        Default = Config.ESP.FriendColor,
        Callback = function(value)
            Config.ESP.FriendColor = value
        end,
    })
    playerColors:CreateColorPicker({
        Name = "Blacklist",
        Flag = "CrimBlacklistColor",
        Default = Config.ESP.BlacklistColor,
        Callback = function(value)
            Config.ESP.BlacklistColor = value
        end,
    })

    self.Controls.WorldESP = worldEsp:CreateToggle({
        Name = "Vault / register / crate ESP",
        Flag = "CrimWorldESP",
        Default = Config.WorldESP.Enabled,
        Callback = function(value)
            Config.WorldESP.Enabled = value
        end,
    })
    worldEsp:CreateToggle({
        Name = "Show health",
        Flag = "CrimWorldHealth",
        Default = Config.WorldESP.ShowHealth,
        Callback = function(value)
            Config.WorldESP.ShowHealth = value
        end,
    })
    worldEsp:CreateToggle({
        Name = "Show drop amount",
        Flag = "CrimWorldDrop",
        Default = Config.WorldESP.ShowDrop,
        Callback = function(value)
            Config.WorldESP.ShowDrop = value
        end,
    })
    worldEsp:CreateToggle({
        Name = "Show distance",
        Flag = "CrimWorldDistance",
        Default = Config.WorldESP.ShowDistance,
        Callback = function(value)
            Config.WorldESP.ShowDistance = value
        end,
    })
    worldEsp:CreateLabel("Looted/broken/empty objects are filtered before rendering.")

    worldColors:CreateColorPicker({
        Name = "Vault / safe",
        Flag = "CrimVaultColor",
        Default = Config.WorldESP.VaultColor,
        Callback = function(value)
            Config.WorldESP.VaultColor = value
        end,
    })
    worldColors:CreateColorPicker({
        Name = "Register",
        Flag = "CrimRegisterColor",
        Default = Config.WorldESP.RegisterColor,
        Callback = function(value)
            Config.WorldESP.RegisterColor = value
        end,
    })
    worldColors:CreateColorPicker({
        Name = "Supply crate",
        Flag = "CrimCrateColor",
        Default = Config.WorldESP.CrateColor,
        Callback = function(value)
            Config.WorldESP.CrateColor = value
        end,
    })

    local aimMain = combatTab:CreateSection({Name = "Aim assist", Side = "Left"})
    local aimTuning = combatTab:CreateSection({Name = "Aim tuning", Side = "Right"})
    local aimVisuals = combatTab:CreateSection({Name = "FOV visuals", Side = "Right"})

    self.Controls.Aim = aimMain:CreateToggle({
        Name = "Aimbot",
        Flag = "CrimAim",
        Default = Config.Aim.Enabled,
        Callback = function(value)
            Aim:SetEnabled(value)
        end,
    })
    aimMain:CreateToggle({
        Name = "Stick to target",
        Flag = "CrimAimSticky",
        Default = Config.Aim.StickToTarget,
        Callback = function(value)
            Config.Aim.StickToTarget = value
            if not value then
                Aim.CurrentTarget = nil
                Aim.Motion = {}
            end
        end,
    })
    aimMain:CreateToggle({
        Name = "Wall check",
        Flag = "CrimAimWall",
        Default = Config.Aim.WallCheck,
        Callback = function(value)
            Config.Aim.WallCheck = value
        end,
    })
    aimMain:CreateToggle({
        Name = "Ignore friends",
        Flag = "CrimAimFriends",
        Default = Config.Aim.IgnoreFriends,
        Callback = function(value)
            Config.Aim.IgnoreFriends = value
        end,
    })
    aimMain:CreateDropdown({
        Name = "Target part",
        Flag = "CrimAimPart",
        Values = {"Head", "Torso", "HumanoidRootPart"},
        Default = Config.Aim.TargetPart,
        Multi = false,
        Callback = function(value)
            Config.Aim.TargetPart = value
            Aim.Motion = {}
        end,
    })
    aimMain:CreateLabel("Ragdolled/downed targets are rejected and prediction is automatically bounded to a small lead.")

    aimTuning:CreateSlider({
        Name = "FOV radius",
        Flag = "CrimAimFOV",
        Min = 50,
        Max = 500,
        Step = 5,
        Default = Config.Aim.FOV,
        Callback = function(value)
            Config.Aim.FOV = value
        end,
    })
    aimTuning:CreateSlider({
        Name = "Response",
        Flag = "CrimAimResponse",
        Min = 0.05,
        Max = 1,
        Step = 0.05,
        Default = Config.Aim.Response,
        Callback = function(value)
            Config.Aim.Response = value
        end,
    })

    aimVisuals:CreateToggle({
        Name = "Show FOV circle",
        Flag = "CrimAimShowFOV",
        Default = Config.Aim.ShowFOV,
        Callback = function(value)
            Config.Aim.ShowFOV = value
        end,
    })
    aimVisuals:CreateColorPicker({
        Name = "FOV color",
        Flag = "CrimAimFOVColor",
        Default = Config.Aim.FOVColor,
        Callback = function(value)
            Config.Aim.FOVColor = value
        end,
    })
    aimVisuals:CreateSlider({
        Name = "FOV transparency",
        Flag = "CrimAimFOVTransparency",
        Min = 0,
        Max = 1,
        Step = 0.05,
        Default = Config.Aim.FOVTransparency,
        Callback = function(value)
            Config.Aim.FOVTransparency = value
        end,
    })

    local friends = playersTab:CreateSection({Name = "Friends", Side = "Left"})
    local blacklist = playersTab:CreateSection({Name = "Blacklist", Side = "Right"})
    local friendSelection = ""
    local blacklistSelection = ""
    local selectedFriendId
    local selectedBlacklistId

    friends:CreateToggle({
        Name = "Auto-detect Roblox friends",
        Flag = "CrimAutoFriends",
        Default = Config.Lists.AutoDetectRobloxFriends,
        Callback = function(value)
            Config.Lists.AutoDetectRobloxFriends = value
            Lists:DetectAllRobloxFriends()
            self:RefreshLists()
        end,
    })
    self.FriendDropdown = friends:CreateDropdown({
        Name = "Live player",
        Flag = "CrimFriendLive",
        Values = self:GetLivePlayerNames(),
        Callback = function(value)
            friendSelection = value == "<no players>" and "" or tostring(value or "")
        end,
    })
    friends:CreateButton({
        Name = "Add selected as manual friend",
        Callback = function()
            local ok, message = Lists:AddFriend(friendSelection)
            notify(ok and "Friends" or "Friend error", message, 3)
        end,
    })
    self.FriendList = friends:CreateList({
        Name = "Friend list",
        Height = 190,
        Items = Lists:GetFriendItems(),
        Callback = function(value)
            selectedFriendId = value
        end,
    })
    friends:CreateButton({
        Name = "Remove selected manual friend",
        Callback = function()
            local ok, message = Lists:RemoveFriendByUserId(selectedFriendId)
            notify(ok and "Friends" or "Friend error", message, 3)
        end,
    })
    friends:CreateLabel("Roblox friends appear automatically; manual entries persist for the script session.")

    self.BlacklistDropdown = blacklist:CreateDropdown({
        Name = "Live player",
        Flag = "CrimBlacklistLive",
        Values = self:GetLivePlayerNames(),
        Callback = function(value)
            blacklistSelection = value == "<no players>" and "" or tostring(value or "")
        end,
    })
    blacklist:CreateButton({
        Name = "Blacklist selected player",
        Callback = function()
            local ok, message = Lists:AddBlacklist(blacklistSelection)
            notify(ok and "Blacklist" or "Blacklist error", message, 3)
        end,
    })
    self.BlacklistList = blacklist:CreateList({
        Name = "Blacklist",
        Height = 190,
        Items = Lists:GetBlacklistItems(),
        Callback = function(value)
            selectedBlacklistId = value
        end,
    })
    blacklist:CreateButton({
        Name = "Remove selected blacklist entry",
        Callback = function()
            local ok, message = Lists:RemoveBlacklistByUserId(selectedBlacklistId)
            notify(ok and "Blacklist" or "Blacklist error", message, 3)
        end,
    })
    blacklist:CreateLabel("Blacklist overrides both manual and automatically detected friend status.")

    local survivalSection = utilityTab:CreateSection({Name = "Local player", Side = "Left"})
    local interactionSection = utilityTab:CreateSection({Name = "Interactions", Side = "Right"})
    local performanceSection = utilityTab:CreateSection({Name = "Performance", Side = "Left"})
    local shortcuts = utilityTab:CreateSection({Name = "Quick toggles", Side = "Right"})
    local session = utilityTab:CreateSection({Name = "Session", Side = "Left"})

    self.Controls.Stamina = survivalSection:CreateToggle({
        Name = "Safe Infinite Sprint",
        Flag = "CrimInfiniteStamina",
        Default = Config.Survival.InfiniteStamina,
        Tooltip = "Crash-safe alternative: refills accessible local values and maintains sprint speed while Shift is held. No function hooks.",
        Callback = function(value)
            Survival:SetInfiniteStamina(value)
        end,
    })
    survivalSection:CreateLabel("SAFE MODE ONLY: the true upvalue-hook version was removed because this executor crashes when it is used.")
    survivalSection:CreateSlider({
        Name = "Safe sprint speed",
        Flag = "CrimCompatibilitySprintSpeed",
        Min = 16,
        Max = 40,
        Step = 1,
        Default = Config.Survival.CompatibilitySprintSpeed,
        Callback = function(value)
            Config.Survival.CompatibilitySprintSpeed = value
        end,
    })
    survivalSection:CreateLabel("This alternative does not freeze the stamina meter; it preserves the sprinting effect without unsafe executor APIs.")
    self.Controls.AntiRagdoll = survivalSection:CreateToggle({
        Name = "Anti-ragdoll mobility",
        Flag = "CrimAntiRagdoll",
        Default = Config.Survival.AntiRagdoll,
        Tooltip = "Forces Physics/Ragdoll/FallingDown humanoid states back to Running every rendered frame.",
        Callback = function(value)
            Survival:SetAntiRagdoll(value)
        end,
    })

    self.Controls.NoFailLockpick = interactionSection:CreateToggle({
        Name = "Lockpick Magnifier",
        Flag = "CrimNoFailLockpick",
        Default = Config.Utility.NoFailLockpick,
        Tooltip = "Magnifies LockpickGUI B1/B2/B3 bars by setting their UIScale to 10.",
        Callback = function(value) Utility:SetNoFailLockpick(value) end,
    })
    self.Controls.UnlockDoors = interactionSection:CreateToggle({
        Name = "Unlock Nearby Doors",
        Flag = "CrimUnlockDoors",
        Default = Config.Utility.UnlockNearbyDoors,
        Tooltip = "Calls Map.Doors.Events.Toggle with Unlock and the door Lock within 5 studs.",
        Callback = function(value) Config.Utility.UnlockNearbyDoors = value end,
    })
    self.Controls.OpenDoors = interactionSection:CreateToggle({
        Name = "Open Nearby Doors",
        Flag = "CrimOpenDoors",
        Default = Config.Utility.OpenNearbyDoors,
        Tooltip = "Calls Map.Doors.Events.Toggle with Open and Knob2 within 5 studs.",
        Callback = function(value) Config.Utility.OpenNearbyDoors = value end,
    })
    self.Controls.InstantInteract = interactionSection:CreateToggle({
        Name = "Instant Interact",
        Flag = "CrimInstantInteract",
        Default = Config.Utility.InstantInteract,
        Tooltip = "Sets prompt hold time to zero and repeats InputHoldBegin three times when interaction starts.",
        Callback = function(value) Utility:SetInstantInteract(value) end,
    })
    self.Controls.AutoPickupMoney = interactionSection:CreateToggle({
        Name = "Auto Pickup Money",
        Flag = "CrimAutoPickupMoney",
        Default = Config.Utility.AutoPickupMoney,
        Tooltip = "Collects nearby dropped cash within 15 studs without teleporting.",
        Callback = function(value) Config.Utility.AutoPickupMoney = value end,
    })

    self.Controls.FPSBooster = performanceSection:CreateToggle({
        Name = "FPS Booster",
        Flag = "CrimFPSBooster",
        Default = Config.Utility.FPSBooster,
        Tooltip = "Disables shadows, textures, particles, post effects, clouds, terrain decoration, and costly water effects; restores them when disabled.",
        Callback = function(value) Utility:SetFPSBooster(value) end,
    })

    shortcuts:CreateKeyPicker({
        Name = "Aimbot",
        Flag = "CrimKeyAim",
        Default = "LeftAlt",
        Mode = "Toggle",
        Callback = function(_, active)
            self.Controls.Aim:Set(active)
        end,
    })
    shortcuts:CreateKeyPicker({
        Name = "Player ESP",
        Flag = "CrimKeyESP",
        Default = "RightShift",
        Mode = "Toggle",
        Callback = function(_, active)
            self.Controls.ESP:Set(active)
        end,
    })
    shortcuts:CreateKeyPicker({
        Name = "World ESP",
        Flag = "CrimKeyWorldESP",
        Default = "RightControl",
        Mode = "Toggle",
        Callback = function(_, active)
            self.Controls.WorldESP:Set(active)
        end,
    })
    shortcuts:CreateKeyPicker({
        Name = "Safe infinite sprint",
        Flag = "CrimKeyStamina",
        Default = "PageUp",
        Mode = "Toggle",
        Callback = function(_, active)
            self.Controls.Stamina:Set(active)
        end,
    })
    shortcuts:CreateKeyPicker({
        Name = "Anti-ragdoll",
        Flag = "CrimKeyRagdoll",
        Default = "PageDown",
        Mode = "Toggle",
        Callback = function(_, active)
            self.Controls.AntiRagdoll:Set(active)
        end,
    })
    shortcuts:CreateKeyPicker({
        Name = "Instant interact",
        Flag = "CrimKeyInteract",
        Default = "None",
        Mode = "Toggle",
        Callback = function(_, active)
            self.Controls.InstantInteract:Set(active)
        end,
    })
    shortcuts:CreateKeyPicker({
        Name = "Auto pickup money",
        Flag = "CrimKeyMoney",
        Default = "None",
        Mode = "Toggle",
        Callback = function(_, active)
            self.Controls.AutoPickupMoney:Set(active)
        end,
    })

    session:CreateButton({
        Name = "Unload Criminality helper",
        Callback = function()
            Runtime:Destroy()
        end,
    })

    self:RefreshLists()
    pcall(function()
        RenLib:LoadAutoloadConfig()
    end)
end

function Runtime:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true
    pcall(function() RunService:UnbindFromRenderStep(self.AimRenderStepName) end)
    Config.ESP.Enabled = false
    Config.WorldESP.Enabled = false
    Config.Aim.Enabled = false
    Config.Survival.InfiniteStamina = false
    Config.Survival.AntiRagdoll = false
    Config.Utility.UnlockNearbyDoors = false
    Config.Utility.OpenNearbyDoors = false
    Config.Utility.AutoPickupMoney = false
    Utility:SetInstantInteract(false)
    Utility:SetNoFailLockpick(false)
    Utility:SetFPSBooster(false)

    ESP:Destroy()
    WorldESP:Destroy()
    Aim.CurrentTarget = nil
    Aim.Motion = {}
    Survival:SetAntiRagdoll(false)

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    for _, instance in ipairs(self.Instances) do
        pcall(function()
            if instance and instance.Parent then
                instance:Destroy()
            end
        end)
    end
    table.clear(self.Instances)

    if self.RenLib then
        pcall(function()
            self.RenLib:Unload("Criminality helper unloaded")
        end)
    end
    if Shared.RenCriminality == self then
        Shared.RenCriminality = nil
    end
end

UI:Build()
ESP:CreateOverlay()
WorldESP:CreateOverlay()
Aim:CreateFOV()
Lists:DetectAllRobloxFriends()
Survival:BindHumanoid()
WorldESP:Discover()

Runtime:AddConnection(RunService.RenderStepped:Connect(function(dt)
    if Runtime.Destroyed then
        return
    end
    Survival:MaintainInfiniteSprintFrame()
    Survival:PreventRagdollFrame()
    ESP:UpdateAll()
    WorldESP:UpdateAll()
end))

-- Apply camera correction after Roblox's camera controller, otherwise the
-- default camera step can overwrite the aim CFrame in the same frame.
RunService:BindToRenderStep(Runtime.AimRenderStepName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not Runtime.Destroyed then Aim:Update(dt) end
end)

Runtime:AddConnection(RunService.Heartbeat:Connect(function(dt)
    if Runtime.Destroyed then
        return
    end
    local now = os.clock()
    Survival:Update(now)
    Utility:Update(now)
    WorldESP.ScanClock += dt
    if WorldESP.ScanClock >= 0.55 then
        WorldESP.ScanClock = 0
        WorldESP:Discover()
    end
end))

Runtime:AddConnection(UserInputService.JumpRequest:Connect(function()
    if not Runtime.Destroyed then Survival:RequestJump() end
end))

Runtime:AddConnection(UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if Runtime.Destroyed or gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and Config.Aim.Enabled then
        local delta = input.Delta
        if delta and delta.Magnitude >= Aim.MouseOverrideThreshold then Aim:ManualOverride() end
    end
end))

Runtime:AddConnection(Workspace.DescendantAdded:Connect(function(descendant)
    if Runtime.Destroyed then return end
    Utility:OnDescendantAdded(descendant)
end))

Runtime:AddConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.delay(0.4, function()
        if not Runtime.Destroyed then
            Survival:BindHumanoid()
        end
    end)
end))

Runtime:AddConnection(Players.PlayerAdded:Connect(function(player)
    Lists:DetectRobloxFriend(player)
    if Runtime.UI and Runtime.UI.RefreshLists then
        task.defer(function()
            Runtime.UI:RefreshLists()
        end)
    end
end))

Runtime:AddConnection(Players.PlayerRemoving:Connect(function(player)
    ESP:DestroyRecord(player)
    RagdollCache[player.UserId] = nil
    Lists.AutoFriends[player.UserId] = nil
    if Aim.CurrentTarget == player then
        Aim.CurrentTarget = nil
        Aim.Motion = {}
    end
    if Runtime.UI and Runtime.UI.RefreshLists then
        task.defer(function()
            Runtime.UI:RefreshLists()
        end)
    end
end))

print("[Criminality] clean rewrite loaded successfully")
