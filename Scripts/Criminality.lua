print("Criminality Script loaded , made by xsakyx for RenCore .")
print("For Devs : Everything is commented in the script to make understanding better .")

local ScriptVersion = "1.0.0 MOTHER"
local ScriptActive = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

-- Local Player
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- RenLib UI with the compatibility facade so gameplay logic stays untouched.
local RenLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"))()


-- Register non-visual shortcuts with RenLib's Keybind Manager. The current
-- GitHub build exposes the virtual registry internally but not this public API,
-- so this compatibility method can be removed once RenLib ships it natively.
local function ensureManagedKeybindAPI(library)
    if type(library.IsCapturingKeybind) ~= "function" then
        function library:IsCapturingKeybind()
            local overlay = self.KeybindManagerOverlay
            if not overlay or not overlay.Visible then return false end
            for _, descendant in ipairs(overlay:GetDescendants()) do
                if descendant:IsA("TextButton")
                    and (descendant.Text == "Press…" or descendant.Text == "Press...")
                then
                    return true
                end
            end
            return false
        end
    end

    if type(library.RegisterKeybind) == "function" then return end

    function library:RegisterKeybind(options)
        options = options or {}
        local name = tostring(options.Name or "Shortcut")
        local flag = tostring(options.Flag or name)
        local mode = tostring(options.Mode or "Press")
        local defaultKey = typeof(options.Default) == "EnumItem" and options.Default.Name or tostring(options.Default or "None")
        local currentKey = self.Flags[flag] or defaultKey
        currentKey = typeof(currentKey) == "EnumItem" and currentKey.Name or tostring(currentKey)
        if not Enum.KeyCode[currentKey] then currentKey = defaultKey end

        for index = #self.KeybindList, 1, -1 do
            local existing = self.KeybindList[index]
            if existing.Virtual == true and existing.flag == flag then
                table.remove(self.KeybindList, index)
            end
        end

        local entry = {name = name, key = currentKey, default = defaultKey, mode = mode, flag = flag, Virtual = true}
        local controller = {Type = "RegisteredKeybind", Name = name}

        function controller:Set(value)
            local keyName = typeof(value) == "EnumItem" and value.Name or tostring(value)
            if not Enum.KeyCode[keyName] then return self end
            entry.key = keyName
            library.Flags[flag] = keyName
            if type(options.OnChanged) == "function" then pcall(options.OnChanged, keyName) end
            return self
        end

        function controller:Get() return entry.key end
        function controller:GetKey() return entry.key end

        entry.controller = controller
        library.Flags[flag] = currentKey
        library.KeybindDefaults[flag] = defaultKey
        table.insert(library.KeybindList, entry)
        if type(library.RegisterOption) == "function" then
            library:RegisterOption(flag, controller)
        else
            library.Options[flag] = controller
        end
        return controller
    end
end

ensureManagedKeybindAPI(RenLib)

local AimbotPrimaryKeybind = RenLib:RegisterKeybind({
    Name = "Aimbot Toggle (Primary)",
    Default = "LeftAlt",
    Flag = "CriminalityAimbotPrimaryKey",
    Mode = "Press",
})
local AimbotSecondaryKeybind = RenLib:RegisterKeybind({
    Name = "Aimbot Toggle (Secondary)",
    Default = "RightAlt",
    Flag = "CriminalityAimbotSecondaryKey",
    Mode = "Press",
})
-- Storage Tables
local ESPObjects = {}
local VaultESPObjects = {}
local Connections = {}
local FriendsList = {}
local TeamList = {}
local BlacklistList = {}
local IgnoreList = {}

-- Performance Optimization
local LastUpdateTime = {
    PlayerESP = 0,
    VaultESP = 0,
    FOVCircle = 0,
}

local UpdateCooldowns = {
    PlayerESP = 0.05, -- Update every 0.05 seconds (20 FPS)
    VaultESP = 0.1,   -- Update every 0.1 seconds (10 FPS)
    FOVCircle = 0.033, -- Update every 0.033 seconds (30 FPS)
}

local LastPositions = {}
local LastHealths = {}
local PositionThreshold = 5 -- Only update if moved more than 5 studs

-- Color Generation System
local function HSVtoRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return Color3.fromRGB(r * 255, g * 255, b * 255)
end

local function RGBtoHSV(color)
    local r, g, b = color.R, color.G, color.B
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v
    v = max
    local d = max - min
    if max == 0 then s = 0 else s = d / max end
    if max == min then
        h = 0
    else
        if max == r then
            h = (g - b) / d
            if g < b then h = h + 6 end
        elseif max == g then h = (b - r) / d + 2
        elseif max == b then h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, v
end

local function GetComplementaryColor(color)
    local h, s, v = RGBtoHSV(color)
    h = (h + 0.5) % 1
    return HSVtoRGB(h, s, v)
end

local function GetTriadicColor(color, offset)
    local h, s, v = RGBtoHSV(color)
    h = (h + (offset / 3)) % 1
    return HSVtoRGB(h, math.min(s + 0.2, 1), math.min(v + 0.1, 1))
end

local function ColorDistance(c1, c2)
    local dr = c1.R - c2.R
    local dg = c1.G - c2.G
    local db = c1.B - c2.B
    return math.sqrt(dr * dr + dg * dg + db * db)
end

local function GenerateDistinctColor(baseColor, usedColors, minDistance)
    minDistance = minDistance or 0.3
    local attempts = 0
    local maxAttempts = 50
    
    while attempts < maxAttempts do
        local offset = attempts / maxAttempts
        local newColor
        
        if attempts < 10 then
            newColor = GetComplementaryColor(baseColor)
        elseif attempts < 20 then
            newColor = GetTriadicColor(baseColor, 1)
        elseif attempts < 30 then
            newColor = GetTriadicColor(baseColor, 2)
        else
            local h, s, v = RGBtoHSV(baseColor)
            h = (h + (attempts * 0.13)) % 1
            s = math.clamp(s + ((attempts % 3) - 1) * 0.2, 0.6, 1)
            v = math.clamp(v + ((attempts % 2) - 0.5) * 0.2, 0.7, 1)
            newColor = HSVtoRGB(h, s, v)
        end
        
        local isFarEnough = true
        for _, usedColor in pairs(usedColors) do
            if ColorDistance(newColor, usedColor) < minDistance then
                isFarEnough = false
                break
            end
        end
        
        if isFarEnough then
            return newColor
        end
        
        attempts = attempts + 1
    end
    
    return HSVtoRGB(math.random(), 0.8, 0.9)
end

-- Configuration
local Config = {
    -- ESP Settings
    ESP = {
        Enabled = false,
        ShowHealth = true,
        ShowDistance = true,
        ShowUsername = true,
        ShowRole = true,
        TeamCheck = false,
        BoxESP = true,
        HighlightESP = true,
        TextSize = 14,
        MaxDistance = 2000,
        ESPScale = 1.0,
        
        -- Colors
        NormalColor = Color3.fromRGB(255, 255, 255),
        FriendColor = nil,
        TeamColor = nil,
        BlacklistColor = nil,
        
        -- Transparency
        BoxTransparency = 0.7,
        HighlightTransparency = 0.5,
    },
    
    -- Vault/Register/Crate ESP Settings
    VaultESP = {
        Enabled = false,
        ShowHealth = true,
        ShowDrop = true,
        ShowType = true,
        ShowDistance = true,
        MaxDistance = 5000,
        ESPScale = 1.0,
        
        -- Auto-generated colors
        VaultColor = nil,
        RegisterColor = nil,
        CrateColor = nil,
        
        Transparency = 0.7,
    },
    
    -- Aimbot Settings
    Aimbot = {
        Enabled = false,
        TargetPart = "Head",
        FOV = 200,
        Smoothness = 0.5,
        Prediction = 0.147,
        IgnoreFriends = true,
        IgnoreTeam = true,
        WallCheck = true,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255),
        FOVTransparency = 0.7,
        StickToTarget = true,
    },
}

-- Initialize auto-generated colors
local usedColors = {Config.ESP.NormalColor}
Config.ESP.FriendColor = GenerateDistinctColor(Config.ESP.NormalColor, usedColors, 0.4)
table.insert(usedColors, Config.ESP.FriendColor)
Config.ESP.TeamColor = GenerateDistinctColor(Config.ESP.NormalColor, usedColors, 0.4)
table.insert(usedColors, Config.ESP.TeamColor)
Config.ESP.BlacklistColor = GenerateDistinctColor(Config.ESP.NormalColor, usedColors, 0.4)
table.insert(usedColors, Config.ESP.BlacklistColor)
Config.VaultESP.VaultColor = GenerateDistinctColor(Config.ESP.NormalColor, usedColors, 0.4)
table.insert(usedColors, Config.VaultESP.VaultColor)
Config.VaultESP.RegisterColor = GenerateDistinctColor(Config.ESP.NormalColor, usedColors, 0.4)
table.insert(usedColors, Config.VaultESP.RegisterColor)
Config.VaultESP.CrateColor = GenerateDistinctColor(Config.ESP.NormalColor, usedColors, 0.4)
table.insert(usedColors, Config.VaultESP.CrateColor)

-- Utility Functions
local function GetCharacter(player)
    if not player then return nil end
    local character = Workspace.Characters:FindFirstChild(player.Name)
    return character
end

local function GetHumanoid(character)
    if not character then return nil end
    return character:FindFirstChild("Humanoid")
end

local function GetRootPart(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function GetHead(character)
    if not character then return nil end
    return character:FindFirstChild("Head")
end

local function IsAlive(player)
    local character = GetCharacter(player)
    if not character then return false end
    
    local humanoid = GetHumanoid(character)
    local rootPart = GetRootPart(character)
    
    return humanoid and rootPart and humanoid.Health > 0
end

local function GetDistance(part1, part2)
    if not part1 or not part2 then return math.huge end
    return (part1.Position - part2.Position).Magnitude
end

local function IsTeamMate(player)
    if not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function IsFriend(player)
    return table.find(FriendsList, player.Name) ~= nil
end

local function IsBlacklisted(player)
    return table.find(BlacklistList, player.Name) ~= nil
end

local function IsIgnored(player)
    return table.find(IgnoreList, player.Name) ~= nil
end

local function IsInTeamList(player)
    return table.find(TeamList, player.Name) ~= nil
end

local function GetPlayerColor(player)
    if IsBlacklisted(player) then
        return Config.ESP.BlacklistColor
    elseif IsFriend(player) then
        return Config.ESP.FriendColor
    elseif IsInTeamList(player) or (Config.ESP.TeamCheck and IsTeamMate(player)) then
        return Config.ESP.TeamColor
    else
        return Config.ESP.NormalColor
    end
end

local function GetPlayerRole(player)
    if IsBlacklisted(player) then
        return "BLACKLISTED"
    elseif IsFriend(player) then
        return "FRIEND"
    elseif IsInTeamList(player) or (Config.ESP.TeamCheck and IsTeamMate(player)) then
        return "TEAM"
    else
        return ""
    end
end

local function WorldToScreen(position)
    if not Camera then
        return Vector2.new(0, 0), false, 0
    end
    local success, screenPoint, onScreen = pcall(function()
        return Camera:WorldToViewportPoint(position)
    end)
    if not success then
        return Vector2.new(0, 0), false, 0
    end
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen, screenPoint.Z
end

-- ESP Creation Functions
local function CreateDrawing(type, properties)
    if not Drawing then
        return nil
    end
    local success, drawing = pcall(function()
        return Drawing.new(type)
    end)
    if not success or not drawing then
        return nil
    end
    for property, value in pairs(properties) do
        pcall(function()
            drawing[property] = value
        end)
    end
    return drawing
end

local function CreatePlayerESP(player)
    if ESPObjects[player] then
        return
    end
    
    local espData = {
        Player = player,
        Drawings = {},
        Highlight = nil,
    }
    
    -- Box ESP
    if Config.ESP.BoxESP then
        espData.Drawings.Box = CreateDrawing("Square", {
            Thickness = 2,
            Filled = false,
            Transparency = Config.ESP.BoxTransparency,
            Visible = false,
            ZIndex = 2,
        })
        
        espData.Drawings.BoxOutline = CreateDrawing("Square", {
            Thickness = 4,
            Filled = false,
            Color = Color3.new(0, 0, 0),
            Transparency = 1,
            Visible = false,
            ZIndex = 1,
        })
    end
    
    -- Text ESP
    espData.Drawings.NameText = CreateDrawing("Text", {
        Size = Config.ESP.TextSize,
        Center = true,
        Outline = true,
        OutlineColor = Color3.new(0, 0, 0),
        Visible = false,
        ZIndex = 3,
    })
    
    espData.Drawings.HealthText = CreateDrawing("Text", {
        Size = Config.ESP.TextSize,
        Center = true,
        Outline = true,
        OutlineColor = Color3.new(0, 0, 0),
        Visible = false,
        ZIndex = 3,
    })
    
    espData.Drawings.DistanceText = CreateDrawing("Text", {
        Size = Config.ESP.TextSize,
        Center = true,
        Outline = true,
        OutlineColor = Color3.new(0, 0, 0),
        Visible = false,
        ZIndex = 3,
    })
    
    espData.Drawings.RoleText = CreateDrawing("Text", {
        Size = Config.ESP.TextSize + 2,
        Center = true,
        Outline = true,
        OutlineColor = Color3.new(0, 0, 0),
        Visible = false,
        ZIndex = 3,
    })
    
    ESPObjects[player] = espData
end

local function RemovePlayerESP(player)
    local espData = ESPObjects[player]
    if not espData then return end
    
    for _, drawing in pairs(espData.Drawings) do
        if drawing and drawing.Remove then
            pcall(function()
                drawing:Remove()
            end)
        end
    end
    
    if espData.Highlight then
        pcall(function()
            espData.Highlight:Destroy()
        end)
    end
    
    -- Clean cache
    if player and player.UserId then
        LastPositions[player.UserId] = nil
        LastHealths[player.UserId] = nil
    end
    
    ESPObjects[player] = nil
end

local function UpdatePlayerESP(player, espData)
    if not Config.ESP.Enabled then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    if player == LocalPlayer then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    if IsIgnored(player) then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    if not IsAlive(player) then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    local character = GetCharacter(player)
    local rootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    
    if not character or not rootPart or not humanoid then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    local distance = GetDistance(rootPart, GetRootPart(GetCharacter(LocalPlayer)))
    
    if distance > Config.ESP.MaxDistance then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    -- Check if position or health changed significantly
    local currentPos = rootPart.Position
    local currentHealth = humanoid.Health
    local playerKey = player.UserId
    
    local lastPos = LastPositions[playerKey]
    local lastHealth = LastHealths[playerKey]
    
    local positionChanged = not lastPos or (currentPos - lastPos).Magnitude > PositionThreshold
    local healthChanged = not lastHealth or math.abs(currentHealth - lastHealth) > 5
    
    -- Only update if something changed
    if not positionChanged and not healthChanged then
        return
    end
    
    -- Update cache
    LastPositions[playerKey] = currentPos
    LastHealths[playerKey] = currentHealth
    
    local headPos = GetHead(character)
    if not headPos then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    local screenPos, onScreen = WorldToScreen(headPos.Position)
    
    if not onScreen then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
        return
    end
    
    -- Get color
    local color = GetPlayerColor(player)
    
    -- Calculate box size with scale
    local rootPos = rootPart.Position
    local rootScreenPos, rootOnScreen = WorldToScreen(rootPos)
    local legPos = rootPos - Vector3.new(0, 3, 0)
    local legScreenPos = WorldToScreen(legPos)
    
    local height = math.abs(screenPos.Y - legScreenPos.Y) * Config.ESP.ESPScale
    local width = (height / 2) * Config.ESP.ESPScale
    
    -- Update Box ESP
    if Config.ESP.BoxESP and espData.Drawings.Box then
        espData.Drawings.Box.Size = Vector2.new(width, height)
        espData.Drawings.Box.Position = Vector2.new(screenPos.X - width / 2, screenPos.Y)
        espData.Drawings.Box.Color = color
        espData.Drawings.Box.Transparency = Config.ESP.BoxTransparency
        espData.Drawings.Box.Visible = true
        
        espData.Drawings.BoxOutline.Size = Vector2.new(width, height)
        espData.Drawings.BoxOutline.Position = Vector2.new(screenPos.X - width / 2, screenPos.Y)
        espData.Drawings.BoxOutline.Visible = true
    end
    
    -- Update Text ESP
    local yOffset = 0
    
    -- Role Text
    if Config.ESP.ShowRole then
        local role = GetPlayerRole(player)
        if role ~= "" then
            espData.Drawings.RoleText.Text = role
            espData.Drawings.RoleText.Position = Vector2.new(screenPos.X, screenPos.Y - 20 + yOffset)
            espData.Drawings.RoleText.Color = color
            espData.Drawings.RoleText.Visible = true
            yOffset = yOffset - 18
        else
            espData.Drawings.RoleText.Visible = false
        end
    else
        espData.Drawings.RoleText.Visible = false
    end
    
    -- Username
    if Config.ESP.ShowUsername then
        espData.Drawings.NameText.Text = player.Name
        espData.Drawings.NameText.Position = Vector2.new(screenPos.X, screenPos.Y - 20 + yOffset)
        espData.Drawings.NameText.Color = color
        espData.Drawings.NameText.Visible = true
        yOffset = yOffset - 16
    else
        espData.Drawings.NameText.Visible = false
    end
    
    -- Health
    if Config.ESP.ShowHealth then
        local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
        espData.Drawings.HealthText.Text = string.format("HP: %d%%", healthPercent)
        espData.Drawings.HealthText.Position = Vector2.new(screenPos.X, screenPos.Y - 20 + yOffset)
        espData.Drawings.HealthText.Color = Color3.fromRGB(0, 255, 0)
        espData.Drawings.HealthText.Visible = true
        yOffset = yOffset - 16
    else
        espData.Drawings.HealthText.Visible = false
    end
    
    -- Distance
    if Config.ESP.ShowDistance then
        espData.Drawings.DistanceText.Text = string.format("%.0f studs", distance)
        espData.Drawings.DistanceText.Position = Vector2.new(screenPos.X, screenPos.Y - 20 + yOffset)
        espData.Drawings.DistanceText.Color = Color3.fromRGB(255, 255, 255)
        espData.Drawings.DistanceText.Visible = true
    else
        espData.Drawings.DistanceText.Visible = false
    end
    
    -- Highlight ESP
    if Config.ESP.HighlightESP then
        if not espData.Highlight then
            local highlight = Instance.new("Highlight")
            highlight.FillTransparency = Config.ESP.HighlightTransparency
            highlight.OutlineTransparency = 0
            highlight.Parent = character
            espData.Highlight = highlight
        end
        
        espData.Highlight.FillColor = color
        espData.Highlight.OutlineColor = color
        espData.Highlight.FillTransparency = Config.ESP.HighlightTransparency
        espData.Highlight.Enabled = true
    else
        if espData.Highlight then
            espData.Highlight.Enabled = false
        end
    end
end

-- Vault/Register ESP Functions
local function CreateVaultESP(vault)
    if not vault then return end
    
    local success, vaultKey = pcall(function()
        return vault:GetFullName()
    end)
    
    if not success or not vaultKey then return end
    
    if VaultESPObjects[vaultKey] then
        return
    end
    
    local espData = {
        Vault = vault,
        Drawings = {},
    }
    
    espData.Drawings.Box = CreateDrawing("Square", {
        Thickness = 2,
        Filled = false,
        Color = Config.VaultESP.VaultColor or Color3.fromRGB(255, 255, 0),
        Transparency = Config.VaultESP.Transparency,
        Visible = false,
        ZIndex = 2,
    })
    
    espData.Drawings.BoxOutline = CreateDrawing("Square", {
        Thickness = 4,
        Filled = false,
        Color = Color3.new(0, 0, 0),
        Transparency = 1,
        Visible = false,
        ZIndex = 1,
    })
    
    espData.Drawings.NameText = CreateDrawing("Text", {
        Size = 14,
        Center = true,
        Outline = true,
        OutlineColor = Color3.new(0, 0, 0),
        Color = Config.VaultESP.VaultColor or Color3.fromRGB(255, 255, 0),
        Visible = false,
        ZIndex = 3,
    })
    
    espData.Drawings.InfoText = CreateDrawing("Text", {
        Size = 12,
        Center = true,
        Outline = true,
        OutlineColor = Color3.new(0, 0, 0),
        Color = Color3.fromRGB(255, 255, 255),
        Visible = false,
        ZIndex = 3,
    })
    
    VaultESPObjects[vaultKey] = espData
end

local function RemoveVaultESP(vaultKey)
    local espData = VaultESPObjects[vaultKey]
    if not espData then return end
    
    for _, drawing in pairs(espData.Drawings) do
        if drawing and drawing.Remove then
            pcall(function()
                drawing:Remove()
            end)
        end
    end
    
    VaultESPObjects[vaultKey] = nil
end

local function UpdateVaultESP(vault, espData)
    if not Config.VaultESP.Enabled then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        return
    end
    
    if not vault or not vault.Parent then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        return
    end
    
    -- Determine vault type and color
    local vaultType = "Unknown"
    local vaultColor = Config.VaultESP.VaultColor
    local isSupplyCrate = vault.Name == "SupplyCrate"
    
    if isSupplyCrate then
        -- Check if empty crate
        local childCount = 0
        for _, child in pairs(vault:GetChildren()) do
            if not child:IsA("PlacementConstraint") then
                childCount = childCount + 1
            end
        end
        
        if childCount == 0 then
            for _, drawing in pairs(espData.Drawings) do
                if drawing then
                    drawing.Visible = false
                end
            end
            return
        end
        
        vaultType = "SupplyCrate"
        vaultColor = Config.VaultESP.CrateColor
    else
        -- Check if broken
        local brokenValue = vault:FindFirstChild("Values") and vault.Values:FindFirstChild("Broken")
        if brokenValue and brokenValue.Value == true then
            for _, drawing in pairs(espData.Drawings) do
                if drawing then
                    drawing.Visible = false
                end
            end
            return
        end
        
        -- Determine if vault or register
        local typeName = vault.Name
        if typeName:match("Register") then
            vaultType = "Register"
            vaultColor = Config.VaultESP.RegisterColor
        elseif typeName:match("Safe") or typeName:match("Vault") then
            vaultType = typeName:match("^(%w+)") or "Vault"
            vaultColor = Config.VaultESP.VaultColor
        else
            vaultType = typeName:match("^(%w+)") or typeName
            vaultColor = Config.VaultESP.VaultColor
        end
    end
    
    local primaryPart = vault:FindFirstChild("PrimaryPart") or vault:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        return
    end
    
    local localRoot = GetRootPart(GetCharacter(LocalPlayer))
    if not localRoot then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        return
    end
    
    local distance = GetDistance(primaryPart, localRoot)
    
    if distance > Config.VaultESP.MaxDistance then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        return
    end
    
    local screenPos, onScreen = WorldToScreen(primaryPart.Position)
    
    if not onScreen then
        for _, drawing in pairs(espData.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        return
    end
    
    -- Update Box with scale
    local boxSize = Vector2.new(100 * Config.VaultESP.ESPScale, 100 * Config.VaultESP.ESPScale)
    espData.Drawings.Box.Size = boxSize
    espData.Drawings.Box.Position = Vector2.new(screenPos.X - boxSize.X / 2, screenPos.Y - boxSize.Y / 2)
    espData.Drawings.Box.Color = vaultColor
    espData.Drawings.Box.Transparency = Config.VaultESP.Transparency
    espData.Drawings.Box.Visible = true
    
    espData.Drawings.BoxOutline.Size = boxSize
    espData.Drawings.BoxOutline.Position = Vector2.new(screenPos.X - boxSize.X / 2, screenPos.Y - boxSize.Y / 2)
    espData.Drawings.BoxOutline.Visible = true
    
    -- Update Name
    espData.Drawings.NameText.Text = vaultType
    espData.Drawings.NameText.Position = Vector2.new(screenPos.X, screenPos.Y - (70 * Config.VaultESP.ESPScale))
    espData.Drawings.NameText.Color = vaultColor
    espData.Drawings.NameText.Visible = true
    
    -- Build info text
    local infoText = {}
    
    if not isSupplyCrate then
        -- Get health
        if Config.VaultESP.ShowHealth then
            local healthValue = vault:FindFirstChild("Values") and vault.Values:FindFirstChild("Health")
            if healthValue then
                local currentHealth = healthValue.Value or 0
                local maxHealth = healthValue.MaxValue or 100
                local healthPercent = math.floor((currentHealth / maxHealth) * 100)
                table.insert(infoText, string.format("HP: %d%%", healthPercent))
            end
        end
        
        -- Get drop
        if Config.VaultESP.ShowDrop then
            local dropValue = vault:FindFirstChild("Values") and vault.Values:FindFirstChild("DropA")
            if dropValue then
                local minDrop = dropValue.MinValue or 0
                local maxDrop = dropValue.MaxValue or 0
                table.insert(infoText, string.format("$%d-$%d", minDrop, maxDrop))
            end
        end
    end
    
    if Config.VaultESP.ShowDistance then
        table.insert(infoText, string.format("%.0f studs", distance))
    end
    
    espData.Drawings.InfoText.Text = table.concat(infoText, " | ")
    espData.Drawings.InfoText.Position = Vector2.new(screenPos.X, screenPos.Y + (60 * Config.VaultESP.ESPScale))
    espData.Drawings.InfoText.Visible = #infoText > 0
end

-- Aimbot Functions
local FOVCircle = nil
local CurrentAimbotTarget = nil

local function CreateFOVCircle()
    if FOVCircle and FOVCircle.Remove then
        pcall(function()
            FOVCircle:Remove()
        end)
    end
    
    FOVCircle = CreateDrawing("Circle", {
        Thickness = 2,
        NumSides = 64,
        Radius = Config.Aimbot.FOV,
        Filled = false,
        Color = Config.Aimbot.FOVColor,
        Transparency = Config.Aimbot.FOVTransparency,
        Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled,
        ZIndex = 1,
    })
end

local function UpdateFOVCircle()
    -- Check cooldown
    local currentTime = tick()
    if currentTime - LastUpdateTime.FOVCircle < UpdateCooldowns.FOVCircle then
        return
    end
    LastUpdateTime.FOVCircle = currentTime
    
    if not FOVCircle or not Camera then
        CreateFOVCircle()
        return
    end
    
    if not FOVCircle then return end
    
    local success, viewportSize = pcall(function()
        return Camera.ViewportSize
    end)
    
    if not success then return end
    
    local centerScreen = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    
    pcall(function()
        FOVCircle.Radius = Config.Aimbot.FOV
        FOVCircle.Position = centerScreen
        FOVCircle.Color = Config.Aimbot.FOVColor
        FOVCircle.Transparency = Config.Aimbot.FOVTransparency
        FOVCircle.Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled
    end)
end

local function IsWallBetween(fromPos, toPos)
    if not Config.Aimbot.WallCheck then
        return false
    end
    
    local success, result = pcall(function()
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {GetCharacter(LocalPlayer), Workspace.Characters}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.IgnoreWater = true
        
        local direction = (toPos - fromPos)
        local ray = Workspace:Raycast(fromPos, direction, raycastParams)
        
        return ray ~= nil
    end)
    
    if not success then
        return false
    end
    
    return result
end

local function GetClosestPlayerToCenter()
    local viewportSize = Camera.ViewportSize
    local centerScreen = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not IsAlive(player) then continue end
        
        -- Check ignore conditions
        if Config.Aimbot.IgnoreFriends and IsFriend(player) then continue end
        if Config.Aimbot.IgnoreTeam and (IsInTeamList(player) or (Config.ESP.TeamCheck and IsTeamMate(player))) then continue end
        if IsIgnored(player) then continue end
        
        local character = GetCharacter(player)
        local targetPart = character:FindFirstChild(Config.Aimbot.TargetPart)
        
        if not targetPart then
            targetPart = GetHead(character) or GetRootPart(character)
        end
        
        if not targetPart then continue end
        
        -- Wall check (only for new targets)
        if player ~= CurrentAimbotTarget then
            local cameraCFrame = Camera.CFrame
            if IsWallBetween(cameraCFrame.Position, targetPart.Position) then
                continue
            end
        end
        
        local screenPos, onScreen = WorldToScreen(targetPart.Position)
        
        if not onScreen and player ~= CurrentAimbotTarget then continue end
        
        local distance = (screenPos - centerScreen).Magnitude
        
        if distance <= Config.Aimbot.FOV and distance < shortestDistance then
            closestPlayer = player
            shortestDistance = distance
        end
    end
    
    return closestPlayer
end

local function AimbotLoop()
    if not Config.Aimbot.Enabled then
        CurrentAimbotTarget = nil
        return
    end
    
    local target = nil
    
    -- Check if current target is still valid
    if Config.Aimbot.StickToTarget and CurrentAimbotTarget then
        if IsAlive(CurrentAimbotTarget) then
            if not (Config.Aimbot.IgnoreFriends and IsFriend(CurrentAimbotTarget)) and
               not (Config.Aimbot.IgnoreTeam and (IsInTeamList(CurrentAimbotTarget) or (Config.ESP.TeamCheck and IsTeamMate(CurrentAimbotTarget)))) and
               not IsIgnored(CurrentAimbotTarget) then
                target = CurrentAimbotTarget
            end
        end
    end
    
    -- If no valid current target, find new one
    if not target then
        target = GetClosestPlayerToCenter()
        CurrentAimbotTarget = target
    end
    
    if not target then return end
    
    local character = GetCharacter(target)
    if not character then
        CurrentAimbotTarget = nil
        return
    end
    
    local targetPart = character:FindFirstChild(Config.Aimbot.TargetPart)
    
    if not targetPart then
        targetPart = GetHead(character) or GetRootPart(character)
    end
    
    if not targetPart then
        CurrentAimbotTarget = nil
        return
    end
    
    -- Prediction
    local targetRoot = GetRootPart(character)
    if not targetRoot then
        CurrentAimbotTarget = nil
        return
    end
    
    local targetVelocity = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity
    local predictedPosition = targetPart.Position + (targetVelocity * Config.Aimbot.Prediction)
    
    -- Calculate aim direction
    local cameraPosition = Camera.CFrame.Position
    local aimDirection = (predictedPosition - cameraPosition).Unit
    
    -- Create target CFrame
    local targetCFrame = CFrame.new(cameraPosition, cameraPosition + aimDirection)
    
    -- Smooth aim with proper interpolation
    local currentCFrame = Camera.CFrame
    local newCFrame = currentCFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
    
    -- Apply to camera
    Camera.CFrame = newCFrame
end

-- Monitoring Functions
local function MonitorPlayers()
    -- Check cooldown
    local currentTime = tick()
    if currentTime - LastUpdateTime.PlayerESP < UpdateCooldowns.PlayerESP then
        return
    end
    LastUpdateTime.PlayerESP = currentTime
    
    for _, player in pairs(Players:GetPlayers()) do
        if not ESPObjects[player] then
            CreatePlayerESP(player)
        end
    end
    
    for player, espData in pairs(ESPObjects) do
        if not player or not player.Parent then
            RemovePlayerESP(player)
            -- Clean cache
            if player then
                LastPositions[player.UserId] = nil
                LastHealths[player.UserId] = nil
            end
        else
            UpdatePlayerESP(player, espData)
        end
    end
end

local function MonitorVaultsAndCrates()
    -- Check cooldown
    local currentTime = tick()
    if currentTime - LastUpdateTime.VaultESP < UpdateCooldowns.VaultESP then
        return
    end
    LastUpdateTime.VaultESP = currentTime
    
    -- Monitor BredMakurz vaults/registers
    local bredMakurz = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("BredMakurz")
    
    if bredMakurz then
        for _, vault in pairs(bredMakurz:GetChildren()) do
            if vault:IsA("Model") or vault:IsA("Folder") then
                local vaultKey = vault:GetFullName()
                if not VaultESPObjects[vaultKey] then
                    CreateVaultESP(vault)
                end
            end
        end
    end
    
    -- Monitor supply crates
    local vParts = Workspace:FindFirstChild("Debris") and Workspace.Debris:FindFirstChild("VParts")
    
    if vParts then
        for _, crate in pairs(vParts:GetChildren()) do
            if crate.Name == "SupplyCrate" then
                local crateKey = crate:GetFullName()
                if not VaultESPObjects[crateKey] then
                    CreateVaultESP(crate)
                end
            end
        end
    end
    
    -- Update all vault/crate ESP
    for vaultKey, espData in pairs(VaultESPObjects) do
        if not espData.Vault or not espData.Vault.Parent then
            RemoveVaultESP(vaultKey)
        else
            UpdateVaultESP(espData.Vault, espData)
        end
    end
end

-- Cleanup Functions
local function CleanupESP()
    for player, espData in pairs(ESPObjects) do
        RemovePlayerESP(player)
    end
    
    for vaultKey, espData in pairs(VaultESPObjects) do
        RemoveVaultESP(vaultKey)
    end
    
    if FOVCircle then
        pcall(function()
            FOVCircle:Remove()
        end)
        FOVCircle = nil
    end
    
    -- Clear all caches
    LastPositions = {}
    LastHealths = {}
    
    CurrentAimbotTarget = nil
end

local function DisableAllFeatures()
    Config.ESP.Enabled = false
    Config.VaultESP.Enabled = false
    Config.Aimbot.Enabled = false
    
    CleanupESP()
end

local function ForceKillAllFeatures()
    DisableAllFeatures()
    
    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    Connections = {}
end

local function KillScript()
    ForceKillAllFeatures()
    
    ScriptActive = false
    
    RenLib:Unload("script cleanup")
    
    print("[Criminality Helper] Script terminated")
end

-- Helper function for player dropdowns
local function GetPlayerNames()
    local names = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    return names
end

-- UI Creation
CreateFOVCircle()

local Window = RenLib:CreateWindow({
    Name = "Criminality Helper v" .. ScriptVersion,
    SidebarMode = "Dynamic",
    ShowUserProfile = true,
    EnableGlobalSearch = true,
})

-- 👁️ VISUALS TAB
local VisualsTab = Window:CreateTab({Name = "Visuals", Icon = 6034316009})

local PlayerESPSection = VisualsTab:CreateSection({Name = "Player ESP", Side = "Left"})

local ESPToggle = PlayerESPSection:CreateToggle({
    Name = "Enable Player ESP",
    Default = false,
    Flag = "ESPToggle",
    Callback = function(Value)
        Config.ESP.Enabled = Value
    end,
})

local ESPScaleSlider = PlayerESPSection:CreateSlider({
    Name = "ESP Scale",
    Min = 0.5,
    Max = 2,
    Step = 0.1,
    Default = 1.0,
    Flag = "ESPScale",
    Callback = function(Value)
        Config.ESP.ESPScale = Value
    end,
})

local ShowHealthToggle = PlayerESPSection:CreateToggle({
    Name = "Show Health",
    Default = true,
    Flag = "ShowHealth",
    Callback = function(Value)
        Config.ESP.ShowHealth = Value
    end,
})

local ShowDistanceToggle = PlayerESPSection:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Flag = "ShowDistance",
    Callback = function(Value)
        Config.ESP.ShowDistance = Value
    end,
})

local ShowUsernameToggle = PlayerESPSection:CreateToggle({
    Name = "Show Username",
    Default = true,
    Flag = "ShowUsername",
    Callback = function(Value)
        Config.ESP.ShowUsername = Value
    end,
})

local ShowRoleToggle = PlayerESPSection:CreateToggle({
    Name = "Show Role Labels",
    Default = true,
    Flag = "ShowRole",
    Callback = function(Value)
        Config.ESP.ShowRole = Value
    end,
})

local BoxESPToggle = PlayerESPSection:CreateToggle({
    Name = "Box ESP",
    Default = true,
    Flag = "BoxESP",
    Callback = function(Value)
        Config.ESP.BoxESP = Value
    end,
})

local HighlightESPToggle = PlayerESPSection:CreateToggle({
    Name = "Highlight ESP",
    Default = true,
    Flag = "HighlightESP",
    Callback = function(Value)
        Config.ESP.HighlightESP = Value
    end,
})

local TeamCheckToggle = PlayerESPSection:CreateToggle({
    Name = "Team Check",
    Default = false,
    Flag = "TeamCheck",
    Callback = function(Value)
        Config.ESP.TeamCheck = Value
    end,
})

local CustomizationSection = VisualsTab:CreateSection({Name = "Customization", Side = "Right"})

local TextSizeSlider = CustomizationSection:CreateSlider({
    Name = "Text Size",
    Min = 10,
    Max = 30,
    Step = 1,
    Default = 14,
    Flag = "TextSize",
    Callback = function(Value)
        Config.ESP.TextSize = Value
    end,
})

local MaxDistanceSlider = CustomizationSection:CreateSlider({
    Name = "Max Distance",
    Min = 500,
    Max = 10000,
    Step = 100,
    Default = 2000,
    Flag = "MaxDistance",
    Callback = function(Value)
        Config.ESP.MaxDistance = Value
    end,
})

local BoxTransparencySlider = CustomizationSection:CreateSlider({
    Name = "Box Transparency",
    Min = 0,
    Max = 1,
    Step = 0.1,
    Default = 0.7,
    Flag = "BoxTransparency",
    Callback = function(Value)
        Config.ESP.BoxTransparency = Value
    end,
})

local HighlightTransparencySlider = CustomizationSection:CreateSlider({
    Name = "Highlight Transparency",
    Min = 0,
    Max = 1,
    Step = 0.1,
    Default = 0.5,
    Flag = "HighlightTransparency",
    Callback = function(Value)
        Config.ESP.HighlightTransparency = Value
    end,
})

local ColorCustomizationSection = VisualsTab:CreateSection({Name = "Color Settings", Side = "Left"})

local NormalColorPicker = ColorCustomizationSection:CreateColorPicker({
    Name = "Normal Player Color",
    Default = Color3.fromRGB(255, 255, 255),
    Flag = "NormalColor",
    Callback = function(Value)
        Config.ESP.NormalColor = Value
        -- Regenerate all other colors
        local usedColors = {Value}
        Config.ESP.FriendColor = GenerateDistinctColor(Value, usedColors, 0.4)
        table.insert(usedColors, Config.ESP.FriendColor)
        Config.ESP.TeamColor = GenerateDistinctColor(Value, usedColors, 0.4)
        table.insert(usedColors, Config.ESP.TeamColor)
        Config.ESP.BlacklistColor = GenerateDistinctColor(Value, usedColors, 0.4)
        table.insert(usedColors, Config.ESP.BlacklistColor)
        Config.VaultESP.VaultColor = GenerateDistinctColor(Value, usedColors, 0.4)
        table.insert(usedColors, Config.VaultESP.VaultColor)
        Config.VaultESP.RegisterColor = GenerateDistinctColor(Value, usedColors, 0.4)
        table.insert(usedColors, Config.VaultESP.RegisterColor)
        Config.VaultESP.CrateColor = GenerateDistinctColor(Value, usedColors, 0.4)
    end,
})

local ColorInfoLabel = ColorCustomizationSection:CreateLabel("ℹ️ Other colors auto-generated for maximum visibility")

-- Vault/Register/Crate ESP Section
local VaultESPSection = VisualsTab:CreateSection({Name = "Vault/Register/Crate ESP", Side = "Right"})

local VaultESPToggle = VaultESPSection:CreateToggle({
    Name = "Enable Vault/Register/Crate ESP",
    Default = false,
    Flag = "VaultESPToggle",
    Callback = function(Value)
        Config.VaultESP.Enabled = Value
    end,
})

local VaultESPScaleSlider = VaultESPSection:CreateSlider({
    Name = "ESP Scale",
    Min = 0.5,
    Max = 2,
    Step = 0.1,
    Default = 1.0,
    Flag = "VaultESPScale",
    Callback = function(Value)
        Config.VaultESP.ESPScale = Value
    end,
})

local VaultShowHealthToggle = VaultESPSection:CreateToggle({
    Name = "Show Vault/Register Health",
    Default = true,
    Flag = "VaultShowHealth",
    Callback = function(Value)
        Config.VaultESP.ShowHealth = Value
    end,
})

local VaultShowDropToggle = VaultESPSection:CreateToggle({
    Name = "Show Drop Amount",
    Default = true,
    Flag = "VaultShowDrop",
    Callback = function(Value)
        Config.VaultESP.ShowDrop = Value
    end,
})

local VaultShowDistanceToggle = VaultESPSection:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Flag = "VaultShowDistance",
    Callback = function(Value)
        Config.VaultESP.ShowDistance = Value
    end,
})

local VaultMaxDistanceSlider = VaultESPSection:CreateSlider({
    Name = "Max Distance",
    Min = 1000,
    Max = 10000,
    Step = 100,
    Default = 5000,
    Flag = "VaultMaxDistance",
    Callback = function(Value)
        Config.VaultESP.MaxDistance = Value
    end,
})

local VaultTransparencySlider = VaultESPSection:CreateSlider({
    Name = "Transparency",
    Min = 0,
    Max = 1,
    Step = 0.1,
    Default = 0.7,
    Flag = "VaultTransparency",
    Callback = function(Value)
        Config.VaultESP.Transparency = Value
    end,
})

local VaultColorInfoLabel = VaultESPSection:CreateLabel("🎨 Vaults, Registers, and Crates use distinct colors")

-- 🎯 COMBAT TAB
local CombatTab = Window:CreateTab({Name = "Combat", Icon = 6031154871})

local AimbotSection = CombatTab:CreateSection({Name = "Aimbot Settings", Side = "Left"})

local AimbotToggle = AimbotSection:CreateToggle({
    Name = "Enable Aimbot",
    Default = false,
    Flag = "AimbotToggle",
    Callback = function(Value)
        Config.Aimbot.Enabled = Value
        if not Value then
            CurrentAimbotTarget = nil
        end
    end,
})

local StickToTargetToggle = AimbotSection:CreateToggle({
    Name = "Stick to Target",
    Default = true,
    Flag = "StickToTarget",
    Callback = function(Value)
        Config.Aimbot.StickToTarget = Value
        if not Value then
            CurrentAimbotTarget = nil
        end
    end,
})

local WallCheckToggle = AimbotSection:CreateToggle({
    Name = "Wall Check",
    Default = true,
    Flag = "WallCheck",
    Callback = function(Value)
        Config.Aimbot.WallCheck = Value
    end,
})

local TargetPartDropdown = AimbotSection:CreateDropdown({
    Name = "Target Part",
    Values = {"Head", "Torso", "HumanoidRootPart"},
    Default = "Head",
    Multi = false,
    Flag = "TargetPart",
    Callback = function(Option)
        Config.Aimbot.TargetPart = Option
    end,
})

local AimbotTuningSection = CombatTab:CreateSection({Name = "Aimbot Tuning", Side = "Right"})

local FOVSlider = AimbotTuningSection:CreateSlider({
    Name = "FOV",
    Min = 50,
    Max = 500,
    Step = 10,
    Default = 200,
    Flag = "FOV",
    Callback = function(Value)
        Config.Aimbot.FOV = Value
    end,
})

local SmoothnessSlider = AimbotTuningSection:CreateSlider({
    Name = "Smoothness",
    Min = 0.1,
    Max = 1,
    Step = 0.05,
    Default = 0.5,
    Flag = "Smoothness",
    Callback = function(Value)
        Config.Aimbot.Smoothness = Value
    end,
})

local PredictionSlider = AimbotTuningSection:CreateSlider({
    Name = "Prediction",
    Min = 0,
    Max = 0.5,
    Step = 0.001,
    Default = 0.147,
    Flag = "Prediction",
    Callback = function(Value)
        Config.Aimbot.Prediction = Value
    end,
})

local AimbotFiltersSection = CombatTab:CreateSection({Name = "Target Filters", Side = "Left"})

local IgnoreFriendsToggle = AimbotFiltersSection:CreateToggle({
    Name = "Ignore Friends",
    Default = true,
    Flag = "IgnoreFriends",
    Callback = function(Value)
        Config.Aimbot.IgnoreFriends = Value
    end,
})

local IgnoreTeamToggle = AimbotFiltersSection:CreateToggle({
    Name = "Ignore Team",
    Default = true,
    Flag = "IgnoreTeam",
    Callback = function(Value)
        Config.Aimbot.IgnoreTeam = Value
    end,
})

local AimbotVisualSection = CombatTab:CreateSection({Name = "Visual Settings", Side = "Right"})

local ShowFOVToggle = AimbotVisualSection:CreateToggle({
    Name = "Show FOV Circle",
    Default = true,
    Flag = "ShowFOV",
    Callback = function(Value)
        Config.Aimbot.ShowFOV = Value
    end,
})

local FOVColorPicker = AimbotVisualSection:CreateColorPicker({
    Name = "FOV Color",
    Default = Color3.fromRGB(255, 255, 255),
    Flag = "FOVColor",
    Callback = function(Value)
        Config.Aimbot.FOVColor = Value
    end,
})

local FOVTransparencySlider = AimbotVisualSection:CreateSlider({
    Name = "FOV Transparency",
    Min = 0,
    Max = 1,
    Step = 0.1,
    Default = 0.7,
    Flag = "FOVTransparency",
    Callback = function(Value)
        Config.Aimbot.FOVTransparency = Value
    end,
})

local AimbotHelpLabel = AimbotVisualSection:CreateLabel("⌨️ Aimbot shortcuts are editable in the Keybind Manager")
local AimbotTipsLabel = AimbotVisualSection:CreateLabel("💡 Enable 'Stick to Target' to keep tracking targets")

-- 👥 PLAYERS TAB
local PlayersTab = Window:CreateTab({Name = "Players", Icon = 6022668898})

local FriendsSection = PlayersTab:CreateSection({Name = "👫 Friends List", Side = "Left"})

local AddFriendDropdown = FriendsSection:CreateDropdown({
    Name = "Add Friend",
    Values = GetPlayerNames(),
    Default = nil,
    Multi = false,
    Flag = "AddFriend",
    Callback = function(Option)
        if Option and not table.find(FriendsList, Option) then
            table.insert(FriendsList, Option)
            RenLib:Notify({
                Title = "✅ Friend Added",
                Content = Option .. " added to friends",
                Duration = 2,
            })
        end
    end,
})

local RemoveFriendDropdown = FriendsSection:CreateDropdown({
    Name = "Remove Friend",
    Values = FriendsList,
    Default = nil,
    Multi = false,
    Flag = "RemoveFriend",
    Callback = function(Option)
        if Option then
            local index = table.find(FriendsList, Option)
            if index then
                table.remove(FriendsList, index)
                RenLib:Notify({
                    Title = "❌ Friend Removed",
                    Content = Option .. " removed from friends",
                    Duration = 2,
                })
            end
        end
    end,
})

local TeamSection = PlayersTab:CreateSection({Name = "🤝 Team List", Side = "Right"})

local AddTeamDropdown = TeamSection:CreateDropdown({
    Name = "Add to Team",
    Values = GetPlayerNames(),
    Default = nil,
    Multi = false,
    Flag = "AddTeam",
    Callback = function(Option)
        if Option and not table.find(TeamList, Option) then
            table.insert(TeamList, Option)
            RenLib:Notify({
                Title = "✅ Team Member Added",
                Content = Option .. " added to team",
                Duration = 2,
            })
        end
    end,
})

local RemoveTeamDropdown = TeamSection:CreateDropdown({
    Name = "Remove from Team",
    Values = TeamList,
    Default = nil,
    Multi = false,
    Flag = "RemoveTeam",
    Callback = function(Option)
        if Option then
            local index = table.find(TeamList, Option)
            if index then
                table.remove(TeamList, index)
                RenLib:Notify({
                    Title = "❌ Team Member Removed",
                    Content = Option .. " removed from team",
                    Duration = 2,
                })
            end
        end
    end,
})

local BlacklistSection = PlayersTab:CreateSection({Name = "⛔ Blacklist", Side = "Left"})

local BlacklistSearchInput = BlacklistSection:CreateInput({
    Name = "Search Player",
    Placeholder = "Enter player name...",
    Callback = function(Text)
        -- Search functionality can be expanded here
    end,
})

local AddBlacklistDropdown = BlacklistSection:CreateDropdown({
    Name = "Add to Blacklist",
    Values = GetPlayerNames(),
    Default = nil,
    Multi = false,
    Flag = "AddBlacklist",
    Callback = function(Option)
        if Option and not table.find(BlacklistList, Option) then
            table.insert(BlacklistList, Option)
            RenLib:Notify({
                Title = "🚫 Player Blacklisted",
                Content = Option .. " added to blacklist",
                Duration = 2,
            })
        end
    end,
})

local RemoveBlacklistDropdown = BlacklistSection:CreateDropdown({
    Name = "Remove from Blacklist",
    Values = BlacklistList,
    Default = nil,
    Multi = false,
    Flag = "RemoveBlacklist",
    Callback = function(Option)
        if Option then
            local index = table.find(BlacklistList, Option)
            if index then
                table.remove(BlacklistList, index)
                RenLib:Notify({
                    Title = "✅ Player Removed",
                    Content = Option .. " removed from blacklist",
                    Duration = 2,
                })
            end
        end
    end,
})

local IgnoreSection = PlayersTab:CreateSection({Name = "🙈 Ignore List", Side = "Right"})

local AddIgnoreDropdown = IgnoreSection:CreateDropdown({
    Name = "Add to Ignore",
    Values = GetPlayerNames(),
    Default = nil,
    Multi = false,
    Flag = "AddIgnore",
    Callback = function(Option)
        if Option and not table.find(IgnoreList, Option) then
            table.insert(IgnoreList, Option)
            RenLib:Notify({
                Title = "👻 Player Ignored",
                Content = Option .. " added to ignore list",
                Duration = 2,
            })
        end
    end,
})

local RemoveIgnoreDropdown = IgnoreSection:CreateDropdown({
    Name = "Remove from Ignore",
    Values = IgnoreList,
    Default = nil,
    Multi = false,
    Flag = "RemoveIgnore",
    Callback = function(Option)
        if Option then
            local index = table.find(IgnoreList, Option)
            if index then
                table.remove(IgnoreList, index)
                RenLib:Notify({
                    Title = "✅ Player Unignored",
                    Content = Option .. " removed from ignore list",
                    Duration = 2,
                })
            end
        end
    end,
})

local PlayerListsInfoLabel = IgnoreSection:CreateLabel("ℹ️ Each list shows different ESP colors automatically")

-- ⚙️ SETTINGS TAB
local SettingsTab = Window:CreateTab({Name = "Settings", Icon = 6031280882})

local ControlsSection = SettingsTab:CreateSection({Name = "Script Controls", Side = "Left"})

local DisableAllButton = ControlsSection:CreateButton({
    Name = "🛑 Disable All Features",
    Callback = function()
        DisableAllFeatures()
        RenLib:Notify({
            Title = "⚠️ Features Disabled",
            Content = "All features have been disabled",
            Duration = 2,
        })
    end,
})

local ForceKillButton = ControlsSection:CreateButton({
    Name = "⚡ Force Kill All Features",
    Callback = function()
        ForceKillAllFeatures()
        RenLib:Notify({
            Title = "⚠️ Features Killed",
            Content = "All features have been force killed",
            Duration = 2,
        })
    end,
})

local KillScriptButton = ControlsSection:CreateButton({
    Name = "🔴 Kill Script Completely",
    Callback = function()
        RenLib:Notify({
            Title = "💀 Script Terminating",
            Content = "Killing script in 2 seconds...",
            Duration = 2,
        })
        task.wait(2)
        KillScript()
    end,
})

local InfoSection = SettingsTab:CreateSection({Name = "Information", Side = "Right"})

local VersionLabel = InfoSection:CreateLabel("📦 Version: " .. ScriptVersion)
local AuthorLabel = InfoSection:CreateLabel("👤 Author: Saky")
local StatusLabel = InfoSection:CreateLabel("✅ Script Status: Running")

-- Main Loop
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not ScriptActive then return end
    
    pcall(MonitorPlayers)
    pcall(MonitorVaultsAndCrates)
    pcall(UpdateFOVCircle)
    pcall(AimbotLoop)
end))

-- Input Handling for Aimbot Toggle
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if RenLib:IsCapturingKeybind() then return end
    
    local keyName = input.KeyCode.Name
    if input.UserInputType == Enum.UserInputType.Keyboard
        and (keyName == AimbotPrimaryKeybind:Get() or keyName == AimbotSecondaryKeybind:Get())
    then
        Config.Aimbot.Enabled = not Config.Aimbot.Enabled
        local status = Config.Aimbot.Enabled and "ENABLED" or "DISABLED"
        RenLib:Notify({
            Title = "Aimbot " .. status,
            Content = "Shortcut managed by RenLib Keybind Manager",
            Duration = 1,
        })
    end
end))

-- Player Added/Removed Events
table.insert(Connections, Players.PlayerAdded:Connect(function(player)
    pcall(function()
        CreatePlayerESP(player)
    end)
end))

table.insert(Connections, Players.PlayerRemoving:Connect(function(player)
    pcall(function()
        RemovePlayerESP(player)
        
        -- Remove from lists
        local index = table.find(FriendsList, player.Name)
        if index then table.remove(FriendsList, index) end
        
        index = table.find(TeamList, player.Name)
        if index then table.remove(TeamList, index) end
        
        index = table.find(BlacklistList, player.Name)
        if index then table.remove(BlacklistList, index) end
        
        index = table.find(IgnoreList, player.Name)
        if index then table.remove(IgnoreList, index) end
    end)
end))

-- Initialize ESP for existing players
for _, player in pairs(Players:GetPlayers()) do
    pcall(function()
        CreatePlayerESP(player)
    end)
end

print("[Criminality Helper] Script loaded successfully")
