-- Masacre Script - Migrated to RenLibBêta (Mobile + PC)
-- ESP, Aimbot (FOV circle), Noclip, Light Helmet, Sprint

--// Load UI Library (RenLibBêta from main branch)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/refs/heads/main/RenLibB%C3%AAta.lua"))()

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

--// Local Player
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// State Variables
local ScriptEnabled = true
local ESPEnabled = false
local AimbotEnabled = false
local AimbotTargetEveryone = false
local NoclipEnabled = false
local LightHelmetEnabled = false
local SprintEnabled = false

--// ESP Settings
local ESPSettings = {
    ShowHealths = true,
    ShowDistances = true,
    UseBoxes = true,
    UseHighlights = false,
    TeamCheck = false,
    FriendCheck = false
}

--// Aimbot Settings
local AimbotSettings = {
    FOV = 100,
    Smoothness = 5,
    WallCheck = true,
    TeamCheck = false,
    FriendCheck = false
}

--// FOV Circle Settings
local FOVCircleSettings = {
    Visible = true,
    Color = Color3.fromRGB(255, 255, 255),
    Thickness = 1,
    Filled = false,
    Transparency = 0.7
}

--// Sprint Settings
local SprintSpeed = 20
local NormalSpeed = 15
local SprintHeld = false
local SprintConnection = nil

--// Storage
local ESPObjects = {}
local Connections = {}
local LightObject = nil
local WeaponNames = {}
local NoclipConnection = nil

--// FOV Circle Drawing
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = FOVCircleSettings.Thickness
FOVCircle.Color = FOVCircleSettings.Color
FOVCircle.Filled = false
FOVCircle.Transparency = FOVCircleSettings.Transparency
FOVCircle.NumSides = 64
FOVCircle.Radius = AimbotSettings.FOV
FOVCircle.Visible = false

--------------------------------------------------------------------------------
--// WEAPON DETECTION
--------------------------------------------------------------------------------
local function LoadWeaponNames()
    pcall(function()
        local weaponsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if weaponsFolder then
            weaponsFolder = weaponsFolder:FindFirstChild("Weapons")
            if weaponsFolder then
                for _, weapon in pairs(weaponsFolder:GetChildren()) do
                    if weapon:IsA("Model") then
                        table.insert(WeaponNames, weapon.Name)
                        local tool = weapon:FindFirstChildOfClass("Tool")
                        if tool and tool.Name ~= weapon.Name then
                            table.insert(WeaponNames, tool.Name)
                        end
                    end
                end
            end
        end

        local fallbacks = {"knife", "gun", "pistol", "revolver"}
        local uniqueNames = {}
        for _, name in pairs(WeaponNames) do
            uniqueNames[name:lower()] = true
        end
        for _, name in pairs(fallbacks) do
            uniqueNames[name] = true
        end
        WeaponNames = {}
        for name in pairs(uniqueNames) do
            table.insert(WeaponNames, name)
        end
    end)
end

local function IsKiller(player)
    local killerVal = player:FindFirstChild("Killer")
    if killerVal and killerVal.Value == true then
        return true
    end

    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")
    local containers = {character, backpack}

    for _, container in pairs(containers) do
        if container then
            for _, child in pairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    local nameLower = child.Name:lower()
                    for _, weaponName in pairs(WeaponNames) do
                        if nameLower:find(weaponName) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

--------------------------------------------------------------------------------
--// ESP SYSTEM
--------------------------------------------------------------------------------
local function CreateESPBox(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Thickness = 2
    box.Transparency = 1
    box.Filled = false

    local healthBar = Drawing.new("Square")
    healthBar.Visible = false
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = 1
    healthBar.Transparency = 1
    healthBar.Filled = true

    local nameText = Drawing.new("Text")
    nameText.Visible = false
    nameText.Color = Color3.fromRGB(255, 255, 255)
    nameText.Size = 14
    nameText.Center = true
    nameText.Outline = true
    nameText.Font = 2

    return {Box = box, HealthBar = healthBar, NameText = nameText}
end

local function CreateESPHighlight(character)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"
    highlight.Adornee = character
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = character
    return highlight
end

local function RemovePlayerESP(player)
    local espData = ESPObjects[player]
    if not espData then return end

    if espData.Box then
        espData.Box.Box:Remove()
        espData.Box.HealthBar:Remove()
        espData.Box.NameText:Remove()
    end
    if espData.Highlight then
        espData.Highlight:Destroy()
    end

    ESPObjects[player] = nil
end

local function HidePlayerESP(player)
    local espData = ESPObjects[player]
    if not espData then return end

    if espData.Box then
        espData.Box.Box.Visible = false
        espData.Box.HealthBar.Visible = false
        espData.Box.NameText.Visible = false
    end
    if espData.Highlight then
        espData.Highlight:Destroy()
        espData.Highlight = nil
    end
end

local function ClearAllESP()
    for player, _ in pairs(ESPObjects) do
        RemovePlayerESP(player)
    end
    ESPObjects = {}
end

local function UpdateESP()
    if not ESPEnabled then return end

    local localChar = LocalPlayer.Character
    local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")

    -- Clean up ESP for players no longer in game
    for player, _ in pairs(ESPObjects) do
        if not player or not player.Parent then
            RemovePlayerESP(player)
        end
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local head = character and character:FindFirstChild("Head")
            local humanoid = character and character:FindFirstChild("Humanoid")

            if character and hrp and head and humanoid and humanoid.Health > 0 then
                if ESPSettings.TeamCheck and player.Team == LocalPlayer.Team then
                    HidePlayerESP(player)
                    continue
                end
                if ESPSettings.FriendCheck and LocalPlayer:IsFriendsWith(player.UserId) then
                    HidePlayerESP(player)
                    continue
                end

                local isKiller = IsKiller(player)
                local espColor = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)

                if not ESPObjects[player] then
                    ESPObjects[player] = {
                        Box = CreateESPBox(player),
                        Highlight = nil
                    }
                end

                local espData = ESPObjects[player]

                if ESPSettings.UseBoxes then
                    local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)

                    if onScreen then
                        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height / 2
                        local centerPointX = (headPos.X + legPos.X) / 2
                        local topPointY = math.min(headPos.Y, legPos.Y)

                        espData.Box.Box.Size = Vector2.new(width, height)
                        espData.Box.Box.Position = Vector2.new(centerPointX - width / 2, topPointY)
                        espData.Box.Box.Color = espColor
                        espData.Box.Box.Visible = true

                        if ESPSettings.ShowHealths then
                            local healthPercent = humanoid.Health / humanoid.MaxHealth
                            espData.Box.HealthBar.Size = Vector2.new(2, height * healthPercent)
                            espData.Box.HealthBar.Position = Vector2.new(centerPointX - width / 2 - 5, topPointY + height - (height * healthPercent))
                            espData.Box.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                            espData.Box.HealthBar.Visible = true
                        else
                            espData.Box.HealthBar.Visible = false
                        end

                        local displayText = player.Name
                        if ESPSettings.ShowDistances and localHRP then
                            local distance = math.floor((hrp.Position - localHRP.Position).Magnitude)
                            displayText = displayText .. " [" .. distance .. "m]"
                        end
                        if isKiller then
                            displayText = "[KILLER] " .. displayText
                        end

                        espData.Box.NameText.Text = displayText
                        espData.Box.NameText.Position = Vector2.new(centerPointX, topPointY - 15)
                        espData.Box.NameText.Color = espColor
                        espData.Box.NameText.Visible = true
                    else
                        espData.Box.Box.Visible = false
                        espData.Box.HealthBar.Visible = false
                        espData.Box.NameText.Visible = false
                    end
                else
                    if espData.Box then
                        espData.Box.Box.Visible = false
                        espData.Box.HealthBar.Visible = false
                        espData.Box.NameText.Visible = false
                    end
                end

                if ESPSettings.UseHighlights then
                    if not espData.Highlight then
                        espData.Highlight = CreateESPHighlight(character)
                    end
                    if espData.Highlight then
                        espData.Highlight.FillColor = espColor
                        espData.Highlight.OutlineColor = espColor
                    end
                else
                    if espData.Highlight then
                        espData.Highlight:Destroy()
                        espData.Highlight = nil
                    end
                end
            else
                HidePlayerESP(player)
            end
        end
    end
end

-- Clean up ESP when player leaves
table.insert(Connections, Players.PlayerRemoving:Connect(function(player)
    RemovePlayerESP(player)
end))

-- Clean up ESP when character removed
local function HookCharacterRemoving(player)
    if player == LocalPlayer then return end
    table.insert(Connections, player.CharacterRemoving:Connect(function()
        HidePlayerESP(player)
    end))
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        HookCharacterRemoving(player)
    end
end

table.insert(Connections, Players.PlayerAdded:Connect(function(player)
    HookCharacterRemoving(player)
end))

--------------------------------------------------------------------------------
--// AIMBOT
--------------------------------------------------------------------------------
local function GetAimbotTarget()
    local closestPlayer = nil
    local shortestDistance = AimbotSettings.FOV

    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetCharacter = player.Character
            if targetCharacter and targetCharacter:FindFirstChild("Head") and targetCharacter:FindFirstChild("Humanoid") then
                local humanoid = targetCharacter.Humanoid
                if humanoid.Health > 0 then
                    if not AimbotTargetEveryone then
                        if not IsKiller(player) then continue end
                    end

                    if AimbotSettings.TeamCheck and player.Team == LocalPlayer.Team then continue end
                    if AimbotSettings.FriendCheck and LocalPlayer:IsFriendsWith(player.UserId) then continue end

                    local head = targetCharacter.Head
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)

                    if onScreen then
                        local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local distance = (centerScreen - Vector2.new(screenPos.X, screenPos.Y)).Magnitude

                        if distance < shortestDistance then
                            if AimbotSettings.WallCheck then
                                local rayOrigin = Camera.CFrame.Position
                                local rayDirection = (head.Position - rayOrigin).Unit
                                local rayParams = RaycastParams.new()
                                rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                                rayParams.FilterType = Enum.RaycastFilterType.Exclude

                                local rayResult = Workspace:Raycast(rayOrigin, rayDirection * 1000, rayParams)
                                if rayResult and rayResult.Instance:IsDescendantOf(targetCharacter) then
                                    shortestDistance = distance
                                    closestPlayer = player
                                end
                            else
                                shortestDistance = distance
                                closestPlayer = player
                            end
                        end
                    end
                end
            end
        end
    end

    return closestPlayer
end

local function AimAt(player)
    if not player or not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end

    local targetPos = head.Position
    local cameraCFrame = Camera.CFrame
    local newCFrame = CFrame.new(cameraCFrame.Position, targetPos)
    Camera.CFrame = cameraCFrame:Lerp(newCFrame, 1 / math.max(1, AimbotSettings.Smoothness))
end

--------------------------------------------------------------------------------
--// FOV CIRCLE UPDATE (runs every frame in main loop)
--------------------------------------------------------------------------------
local function UpdateFOVCircle()
    if AimbotEnabled and FOVCircleSettings.Visible then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = AimbotSettings.FOV
        FOVCircle.Color = FOVCircleSettings.Color
        FOVCircle.Thickness = FOVCircleSettings.Thickness
        FOVCircle.Transparency = FOVCircleSettings.Transparency
        FOVCircle.Filled = FOVCircleSettings.Filled
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
end

--------------------------------------------------------------------------------
--// LIGHT HELMET
--------------------------------------------------------------------------------
local function CreateLightHelmet()
    if LightObject then
        LightObject:Destroy()
        LightObject = nil
    end

    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Head") then return end

    local light = Instance.new("PointLight")
    light.Name = "HelmetLight"
    light.Brightness = 5
    light.Range = 60
    light.Color = Color3.fromRGB(255, 255, 255)
    light.Parent = character.Head
    LightObject = light
end

local function ToggleLightHelmet(enabled)
    if enabled then
        CreateLightHelmet()
    else
        if LightObject then
            LightObject:Destroy()
            LightObject = nil
        end
    end
end

--------------------------------------------------------------------------------
--// NOCLIP (FIXED: dedicated connection, instant on/off)
--------------------------------------------------------------------------------
local function EnableNoclip()
    if NoclipConnection then return end
    NoclipConnection = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        if not character then return end
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

local function DisableNoclip()
    -- Disconnect the per-frame loop FIRST (instant stop)
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
    -- Force-restore collisions immediately
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        -- Let the humanoid recalculate collision state
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end

local function ToggleNoclip(enabled)
    NoclipEnabled = enabled
    if enabled then
        EnableNoclip()
    else
        DisableNoclip()
    end
end

--------------------------------------------------------------------------------
--// SPRINT (hold Shift = looped 20, release = set 15 and stop)
--------------------------------------------------------------------------------
local function StartSprint()
    if SprintConnection then return end
    SprintHeld = true

    SprintConnection = RunService.Heartbeat:Connect(function()
        if not SprintHeld then return end
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.WalkSpeed ~= SprintSpeed then
            humanoid.WalkSpeed = SprintSpeed
        end
    end)
end

local function StopSprint()
    SprintHeld = false

    -- Disconnect the loop
    if SprintConnection then
        SprintConnection:Disconnect()
        SprintConnection = nil
    end

    -- Set normal speed once
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = NormalSpeed
        end
    end
end

--------------------------------------------------------------------------------
--// CHARACTER RESPAWN HANDLER
--------------------------------------------------------------------------------
local function OnCharacterAdded(character)
    task.wait(1)
    if LightHelmetEnabled then
        CreateLightHelmet()
    end
    -- Re-enable noclip if it was on
    if NoclipEnabled then
        DisableNoclip()
        EnableNoclip()
    end
end

if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(OnCharacterAdded))

--------------------------------------------------------------------------------
--// UI (RenLibBêta)
--------------------------------------------------------------------------------
local Window = Library:CreateWindow({
    Name = "Masacre Script"
})

--// ===================== ESP TAB =====================
local ESPTab = Window:CreateTab({
    Name = "ESP",
    Emoji = "👁️"
})

local ESPSection = ESPTab:CreateSection({Name = "ESP Settings", Side = "Left"})

ESPSection:CreateToggle({
    Name = "Enable ESP",
    Default = false,
    Flag = "ESPEnabled",
    Callback = function(value)
        ESPEnabled = value
        if not value then
            ClearAllESP()
        end
    end
})

ESPSection:CreateToggle({
    Name = "Use Boxes",
    Default = true,
    Flag = "ESPBoxes",
    Callback = function(value)
        ESPSettings.UseBoxes = value
    end
})

ESPSection:CreateToggle({
    Name = "Use Highlights",
    Default = false,
    Flag = "ESPHighlights",
    Callback = function(value)
        ESPSettings.UseHighlights = value
    end
})

ESPSection:CreateToggle({
    Name = "Show Health",
    Default = true,
    Flag = "ESPHealth",
    Callback = function(value)
        ESPSettings.ShowHealths = value
    end
})

ESPSection:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Flag = "ESPDistance",
    Callback = function(value)
        ESPSettings.ShowDistances = value
    end
})

local ESPFilters = ESPTab:CreateSection({Name = "Filters", Side = "Right"})

ESPFilters:CreateToggle({
    Name = "Team Check",
    Default = false,
    Flag = "ESPTeamCheck",
    Callback = function(value)
        ESPSettings.TeamCheck = value
    end
})

ESPFilters:CreateToggle({
    Name = "Friend Check",
    Default = false,
    Flag = "ESPFriendCheck",
    Callback = function(value)
        ESPSettings.FriendCheck = value
    end
})

--// ===================== AIMBOT TAB =====================
local AimbotTab = Window:CreateTab({
    Name = "Aimbot",
    Emoji = "🎯"
})

local AimbotSection = AimbotTab:CreateSection({Name = "Aimbot Settings", Side = "Left"})

AimbotSection:CreateToggle({
    Name = "Enable Aimbot",
    Default = false,
    Flag = "AimbotEnabled",
    Callback = function(value)
        AimbotEnabled = value
        Library:Notify({
            Title = "Aimbot",
            Content = value and "Enabled (hold RMB to aim)" or "Disabled",
            Emoji = value and "✅" or "❌",
            Duration = 2
        })
    end
})

AimbotSection:CreateToggle({
    Name = "Target Everyone",
    Default = false,
    Flag = "AimbotTargetAll",
    Callback = function(value)
        AimbotTargetEveryone = value
        Library:Notify({
            Title = "Aimbot Target",
            Content = value and "Targeting ALL players" or "Targeting KILLER only",
            Emoji = value and "🌐" or "🔪",
            Duration = 2
        })
    end
})

AimbotSection:CreateLabel("OFF = killer only | ON = everyone")

AimbotSection:CreateSlider({
    Name = "FOV (circle radius)",
    Min = 50,
    Max = 500,
    Default = 100,
    Flag = "AimbotFOV",
    Callback = function(value)
        AimbotSettings.FOV = value
    end
})

AimbotSection:CreateSlider({
    Name = "Smoothness",
    Min = 1,
    Max = 20,
    Default = 5,
    Flag = "AimbotSmooth",
    Callback = function(value)
        AimbotSettings.Smoothness = math.max(1, value)
    end
})

AimbotSection:CreateLabel("Smoothness: 1 = instant snap | 20 = very slow tracking")

local AimbotFilters = AimbotTab:CreateSection({Name = "Filters", Side = "Right"})

AimbotFilters:CreateToggle({
    Name = "Wall Check",
    Default = true,
    Flag = "AimbotWallCheck",
    Callback = function(value)
        AimbotSettings.WallCheck = value
    end
})

AimbotFilters:CreateToggle({
    Name = "Team Check",
    Default = false,
    Flag = "AimbotTeamCheck",
    Callback = function(value)
        AimbotSettings.TeamCheck = value
    end
})

AimbotFilters:CreateToggle({
    Name = "Friend Check",
    Default = false,
    Flag = "AimbotFriendCheck",
    Callback = function(value)
        AimbotSettings.FriendCheck = value
    end
})

--// FOV Circle customization
local FOVSection = AimbotTab:CreateSection({Name = "FOV Circle", Side = "Right"})

FOVSection:CreateToggle({
    Name = "Show FOV Circle",
    Default = true,
    Flag = "FOVCircleVisible",
    Callback = function(value)
        FOVCircleSettings.Visible = value
    end
})

FOVSection:CreateToggle({
    Name = "Filled Circle",
    Default = false,
    Flag = "FOVCircleFilled",
    Callback = function(value)
        FOVCircleSettings.Filled = value
    end
})

FOVSection:CreateSlider({
    Name = "Circle Thickness",
    Min = 1,
    Max = 5,
    Default = 1,
    Flag = "FOVCircleThickness",
    Callback = function(value)
        FOVCircleSettings.Thickness = value
    end
})

FOVSection:CreateDropdown({
    Name = "Circle Color",
    Values = {"White", "Red", "Green", "Blue", "Yellow", "Cyan", "Purple"},
    Default = "White",
    Flag = "FOVCircleColor",
    Callback = function(value)
        local colors = {
            White = Color3.fromRGB(255, 255, 255),
            Red = Color3.fromRGB(255, 0, 0),
            Green = Color3.fromRGB(0, 255, 0),
            Blue = Color3.fromRGB(0, 150, 255),
            Yellow = Color3.fromRGB(255, 255, 0),
            Cyan = Color3.fromRGB(0, 255, 255),
            Purple = Color3.fromRGB(180, 0, 255)
        }
        FOVCircleSettings.Color = colors[value] or Color3.fromRGB(255, 255, 255)
    end
})

--// ===================== MISC TAB =====================
local MiscTab = Window:CreateTab({
    Name = "Misc",
    Emoji = "⚙️"
})

local MiscSection = MiscTab:CreateSection({Name = "Features", Side = "Left"})

MiscSection:CreateToggle({
    Name = "Light Helmet",
    Default = false,
    Flag = "LightHelmet",
    Callback = function(value)
        LightHelmetEnabled = value
        ToggleLightHelmet(value)
    end
})

MiscSection:CreateToggle({
    Name = "Noclip",
    Default = false,
    Flag = "Noclip",
    Callback = function(value)
        ToggleNoclip(value)
        Library:Notify({
            Title = "Noclip",
            Content = value and "Enabled" or "Disabled",
            Emoji = value and "👻" or "❌",
            Duration = 2
        })
    end
})

MiscSection:CreateToggle({
    Name = "Infinite Sprint (hold Shift)",
    Default = false,
    Flag = "SprintEnabled",
    Callback = function(value)
        SprintEnabled = value
        if not value and SprintHeld then
            StopSprint()
        end
        Library:Notify({
            Title = "Sprint",
            Content = value and "Enabled (hold Shift to run)" or "Disabled",
            Emoji = value and "🏃" or "❌",
            Duration = 2
        })
    end
})

local ScriptControls = MiscTab:CreateSection({Name = "Script Controls", Side = "Right"})

ScriptControls:CreateButton({
    Name = "Disable All Features",
    Callback = function()
        ESPEnabled = false
        AimbotEnabled = false
        LightHelmetEnabled = false
        SprintEnabled = false
        ToggleNoclip(false)
        ClearAllESP()
        ToggleLightHelmet(false)
        if SprintHeld then StopSprint() end
        FOVCircle.Visible = false
        Library:Notify({Title = "Settings", Content = "All features disabled", Emoji = "✅"})
    end
})

ScriptControls:CreateButton({
    Name = "Destroy Script",
    Callback = function()
        ScriptEnabled = false
        ClearAllESP()
        ToggleLightHelmet(false)
        ToggleNoclip(false)
        if SprintHeld then StopSprint() end
        FOVCircle:Remove()
        for _, conn in pairs(Connections) do
            pcall(function() conn:Disconnect() end)
        end
        Library:Unload()
    end
})

--// ===================== HELP TAB (?) =====================
local HelpTab = Window:CreateTab({
    Name = "Help",
    Emoji = "❓"
})

local KeybindsSection = HelpTab:CreateSection({Name = "Keybinds (PC)", Side = "Left"})

KeybindsSection:CreateLabel("F = Toggle Aimbot ON/OFF")
KeybindsSection:CreateLabel("B = Toggle Target Everyone")
KeybindsSection:CreateLabel("H = Toggle Light Helmet")
KeybindsSection:CreateLabel("G = Toggle Noclip")
KeybindsSection:CreateLabel("Shift (hold) = Sprint")
KeybindsSection:CreateLabel("RMB (hold) = Aim at target")
KeybindsSection:CreateLabel("K = Toggle UI visibility")

local InfoSection = HelpTab:CreateSection({Name = "How It Works", Side = "Right"})

InfoSection:CreateLabel("ESP: Shows players through walls with boxes/highlights and health bars")
InfoSection:CreateLabel("Aimbot: Hold right-click to lock onto targets. FOV = detection range circle")
InfoSection:CreateLabel("Target Everyone OFF = aims at killer only. ON = aims at anyone")
InfoSection:CreateLabel("Noclip: Walk through walls. Press G to toggle instantly")
InfoSection:CreateLabel("Sprint: Hold Shift for speed 20, release for speed 15")
InfoSection:CreateLabel("Light Helmet: Adds a light to your head for dark maps")

--------------------------------------------------------------------------------
--// KEYBINDS
--------------------------------------------------------------------------------
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end

    -- F = Toggle Aimbot
    if input.KeyCode == Enum.KeyCode.F then
        AimbotEnabled = not AimbotEnabled
        Library:Notify({
            Title = "Aimbot",
            Content = AimbotEnabled and "Enabled" or "Disabled",
            Emoji = AimbotEnabled and "✅" or "❌",
            Duration = 2
        })
    end

    -- B = Toggle Target Everyone
    if input.KeyCode == Enum.KeyCode.B then
        AimbotTargetEveryone = not AimbotTargetEveryone
        Library:Notify({
            Title = "Aimbot Target",
            Content = AimbotTargetEveryone and "ALL players" or "KILLER only",
            Emoji = AimbotTargetEveryone and "🌐" or "🔪",
            Duration = 2
        })
    end

    -- H = Toggle Light Helmet
    if input.KeyCode == Enum.KeyCode.H then
        LightHelmetEnabled = not LightHelmetEnabled
        ToggleLightHelmet(LightHelmetEnabled)
        Library:Notify({
            Title = "Light Helmet",
            Content = LightHelmetEnabled and "Enabled" or "Disabled",
            Emoji = LightHelmetEnabled and "💡" or "❌",
            Duration = 2
        })
    end

    -- G = Toggle Noclip
    if input.KeyCode == Enum.KeyCode.G then
        ToggleNoclip(not NoclipEnabled)
        Library:Notify({
            Title = "Noclip",
            Content = NoclipEnabled and "Enabled" or "Disabled",
            Emoji = NoclipEnabled and "👻" or "❌",
            Duration = 2
        })
    end

    -- Shift = Start Sprint
    if input.KeyCode == Enum.KeyCode.LeftShift and SprintEnabled then
        StartSprint()
    end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    -- Shift released = Stop Sprint
    if input.KeyCode == Enum.KeyCode.LeftShift and SprintHeld then
        StopSprint()
    end
end))

--------------------------------------------------------------------------------
--// MAIN LOOP
--------------------------------------------------------------------------------
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not ScriptEnabled then return end

    -- ESP
    if ESPEnabled then
        UpdateESP()
    end

    -- FOV Circle
    UpdateFOVCircle()

    -- Aimbot (hold right mouse button to aim)
    if AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetAimbotTarget()
        if target then
            AimAt(target)
        end
    end
end))

--------------------------------------------------------------------------------
--// INIT
--------------------------------------------------------------------------------
LoadWeaponNames()

Library:Notify({
    Title = "Masacre Script",
    Content = "Loaded! F:Aimbot B:TargetAll H:Light G:Noclip",
    Emoji = "🔥",
    Duration = 5
})
