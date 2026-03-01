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

--------------------------------------------------------------------------------
--// MOBILE DETECTION
-- UserInputService.TouchEnabled = true  → touch screen present
-- UserInputService.KeyboardEnabled = false → no physical keyboard
-- Both together = almost certainly mobile
--------------------------------------------------------------------------------
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

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
local MobileSprintActive = false   -- toggleable sprint state for mobile button
local MobileSprintLoop = nil       -- 0.5s loop for mobile sprint

--// Aimbot (mobile)
local MobileAimActive = false      -- true while mobile aim button is pressed

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
--// MOBILE GUI BUTTONS (ScreenGui via CoreGui or PlayerGui)
--------------------------------------------------------------------------------

-- We create a ScreenGui for the mobile buttons
local MobileGui = Instance.new("ScreenGui")
MobileGui.Name = "MasacreMobileButtons"
MobileGui.ResetOnSpawn = false
MobileGui.IgnoreGuiInset = true
MobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Try to parent to CoreGui for persistence; fall back to PlayerGui
local guiParentSuccess = pcall(function()
    MobileGui.Parent = game:GetService("CoreGui")
end)
if not guiParentSuccess then
    MobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

--------------------------------------------------------------------------------
-- Helper: make a round draggable button
-- Returns the button Frame so we can update its color / visibility later
--------------------------------------------------------------------------------
local function CreateMobileButton(label, startPos, onPress, onRelease)
    local SIZE = 64

    local btn = Instance.new("Frame")
    btn.Name = label .. "Btn"
    btn.Size = UDim2.new(0, SIZE, 0, SIZE)
    btn.Position = startPos
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.BorderSizePixel = 0
    btn.Active = true
    btn.Visible = false
    btn.ZIndex = 10
    btn.Parent = MobileGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0) -- fully round
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 200, 200)
    stroke.Thickness = 2
    stroke.Parent = btn

    local txtLabel = Instance.new("TextLabel")
    txtLabel.Size = UDim2.new(1, 0, 1, 0)
    txtLabel.BackgroundTransparency = 1
    txtLabel.Text = label
    txtLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    txtLabel.TextScaled = true
    txtLabel.Font = Enum.Font.GothamBold
    txtLabel.ZIndex = 11
    txtLabel.Parent = btn

    -- Drag logic
    local dragging = false
    local dragInput = nil
    local dragStartPos = nil
    local btnStartPos = nil

    -- Detect whether a touch is a drag or a tap
    local touchStartTime = 0
    local touchStartScreenPos = nil
    local TAP_MAX_DIST = 10   -- pixels; if finger moves less than this it's a tap
    local TAP_MAX_TIME = 0.35 -- seconds

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragInput = input
            dragStartPos = input.Position
            btnStartPos = btn.Position
            touchStartTime = tick()
            touchStartScreenPos = Vector2.new(input.Position.X, input.Position.Y)

            if onPress then onPress() end
        end
    end)

    btn.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStartPos
            btn.Position = UDim2.new(
                btnStartPos.X.Scale,
                btnStartPos.X.Offset + delta.X,
                btnStartPos.Y.Scale,
                btnStartPos.Y.Offset + delta.Y
            )
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input == dragInput then
            dragging = false
            dragInput = nil

            -- Check if this was a tap (short time + small movement)
            local elapsed = tick() - touchStartTime
            local moved = (Vector2.new(input.Position.X, input.Position.Y) - touchStartScreenPos).Magnitude
            local isTap = elapsed <= TAP_MAX_TIME and moved <= TAP_MAX_DIST

            if onRelease then onRelease(isTap) end
        end
    end)

    return btn, txtLabel
end

--------------------------------------------------------------------------------
-- AIMBOT BUTTON (mobile): hold to aim, releases when finger lifts
-- Color: white = idle, red = actively aiming
--------------------------------------------------------------------------------
local AimBtnFrame, AimBtnLabel = CreateMobileButton(
    "🎯",
    UDim2.new(1, -80, 0.6, 0),   -- bottom-right area by default
    function() -- onPress
        MobileAimActive = true
        -- color update happens in the main loop / aim loop
    end,
    function(isTap) -- onRelease
        MobileAimActive = false
    end
)

--------------------------------------------------------------------------------
-- SPRINT BUTTON (mobile): tap to toggle sprint on/off
-- Color: green = sprinting, gray = not sprinting
--------------------------------------------------------------------------------
local SprintBtnFrame, SprintBtnLabel = CreateMobileButton(
    "🏃",
    UDim2.new(1, -80, 0.75, 0),  -- slightly below aim button
    function() end, -- nothing on raw press
    function(isTap)
        if not isTap then return end -- only act on taps, not drags
        MobileSprintActive = not MobileSprintActive

        if MobileSprintActive then
            SprintBtnFrame.BackgroundColor3 = Color3.fromRGB(0, 180, 60)
        else
            SprintBtnFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            -- Restore normal speed immediately
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = NormalSpeed end
            end
        end
    end
)

--------------------------------------------------------------------------------
-- Visibility update for mobile buttons (called when toggles change)
--------------------------------------------------------------------------------
local function UpdateMobileButtonVisibility()
    AimBtnFrame.Visible   = IsMobile and AimbotEnabled
    SprintBtnFrame.Visible = IsMobile and SprintEnabled
end

--------------------------------------------------------------------------------
-- Mobile sprint loop: every 0.5s set WalkSpeed while MobileSprintActive
--------------------------------------------------------------------------------
local function StartMobileSprintLoop()
    if MobileSprintLoop then return end
    MobileSprintLoop = task.spawn(function()
        while SprintEnabled do
            if MobileSprintActive then
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = SprintSpeed end
                end
            end
            task.wait(0.5)
        end
        MobileSprintLoop = nil
    end)
end

local function StopMobileSprintLoop()
    MobileSprintActive = false
    SprintBtnFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    -- MobileSprintLoop will exit on next iteration when SprintEnabled = false
    MobileSprintLoop = nil
end

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

table.insert(Connections, Players.PlayerRemoving:Connect(function(player)
    RemovePlayerESP(player)
end))

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
--// FOV CIRCLE UPDATE
-- Always visible when aimbot is enabled (not gated on RMB)
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
--// NOCLIP
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
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
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
--// SPRINT (PC hold-Shift version)
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

    if SprintConnection then
        SprintConnection:Disconnect()
        SprintConnection = nil
    end

    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = NormalSpeed
        end
    end
end

--------------------------------------------------------------------------------
--// NO JUMP COOLDOWN
-- Each frame we reset JumpCooldown to 0 so the player can jump again instantly
--------------------------------------------------------------------------------
local JumpCooldownConnection = RunService.Heartbeat:Connect(function()
    if not ScriptEnabled then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:SetAttribute("JumpCooldown", 0)
        -- Also works for some games using the older property:
        pcall(function() humanoid.JumpCooldown = 0 end)
    end
end)
table.insert(Connections, JumpCooldownConnection)

--------------------------------------------------------------------------------
--// CHARACTER RESPAWN HANDLER
--------------------------------------------------------------------------------
local function OnCharacterAdded(character)
    task.wait(1)
    if LightHelmetEnabled then
        CreateLightHelmet()
    end
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
        UpdateMobileButtonVisibility()
        Library:Notify({
            Title = "Aimbot",
            Content = value and "Enabled" .. (IsMobile and " (use 🎯 button)" or " (hold RMB)") or "Disabled",
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
    Name = "Infinite Sprint",
    Default = false,
    Flag = "SprintEnabled",
    Callback = function(value)
        SprintEnabled = value
        if value then
            if IsMobile then
                StartMobileSprintLoop()
            end
        else
            if SprintHeld then StopSprint() end
            StopMobileSprintLoop()
        end
        UpdateMobileButtonVisibility()
        Library:Notify({
            Title = "Sprint",
            Content = value and ("Enabled" .. (IsMobile and " (tap 🏃 button)" or " (hold Shift)")) or "Disabled",
            Emoji = value and "🏃" or "❌",
            Duration = 2
        })
    end
})

MiscSection:CreateLabel("No Jump Cooldown is always active")

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
        StopMobileSprintLoop()
        FOVCircle.Visible = false
        UpdateMobileButtonVisibility()
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
        StopMobileSprintLoop()
        FOVCircle:Remove()
        MobileGui:Destroy()
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

local MobileSection = HelpTab:CreateSection({Name = "Mobile Controls", Side = "Right"})
MobileSection:CreateLabel("🎯 button appears when Aimbot is ON")
MobileSection:CreateLabel("Hold 🎯 to aim, release to stop")
MobileSection:CreateLabel("🏃 button appears when Sprint is ON")
MobileSection:CreateLabel("Tap 🏃 to toggle sprint (green = active)")
MobileSection:CreateLabel("Both buttons are draggable anywhere on screen")

local InfoSection = HelpTab:CreateSection({Name = "How It Works", Side = "Left"})

InfoSection:CreateLabel("ESP: Shows players through walls with boxes/highlights and health bars")
InfoSection:CreateLabel("Aimbot: FOV circle always shows when aimbot is ON")
InfoSection:CreateLabel("Target Everyone OFF = aims at killer only. ON = aims at anyone")
InfoSection:CreateLabel("Noclip: Walk through walls. Press G to toggle instantly")
InfoSection:CreateLabel("Sprint: Hold Shift (PC) or tap button (Mobile) for speed 20")
InfoSection:CreateLabel("Light Helmet: Adds a light to your head for dark maps")
InfoSection:CreateLabel("No Jump Cooldown: Always active, jump immediately after landing")

--------------------------------------------------------------------------------
--// KEYBINDS (PC only)
--------------------------------------------------------------------------------
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.F then
        AimbotEnabled = not AimbotEnabled
        UpdateMobileButtonVisibility()
        Library:Notify({
            Title = "Aimbot",
            Content = AimbotEnabled and "Enabled" or "Disabled",
            Emoji = AimbotEnabled and "✅" or "❌",
            Duration = 2
        })
    end

    if input.KeyCode == Enum.KeyCode.B then
        AimbotTargetEveryone = not AimbotTargetEveryone
        Library:Notify({
            Title = "Aimbot Target",
            Content = AimbotTargetEveryone and "ALL players" or "KILLER only",
            Emoji = AimbotTargetEveryone and "🌐" or "🔪",
            Duration = 2
        })
    end

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

    if input.KeyCode == Enum.KeyCode.G then
        ToggleNoclip(not NoclipEnabled)
        Library:Notify({
            Title = "Noclip",
            Content = NoclipEnabled and "Enabled" or "Disabled",
            Emoji = NoclipEnabled and "👻" or "❌",
            Duration = 2
        })
    end

    if input.KeyCode == Enum.KeyCode.LeftShift and SprintEnabled and not IsMobile then
        StartSprint()
    end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
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

    -- FOV Circle (always shown when aimbot is on, regardless of aim button state)
    UpdateFOVCircle()

    -- PC aimbot: hold RMB
    local pcAiming = not IsMobile and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    -- Mobile aimbot: hold the on-screen button
    local mobileAiming = IsMobile and MobileAimActive

    if AimbotEnabled and (pcAiming or mobileAiming) then
        local target = GetAimbotTarget()
        if target then
            AimAt(target)
        end
        -- Color the mobile aim button red while actively aiming
        if IsMobile then
            AimBtnFrame.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        end
    else
        -- Restore aim button to neutral color
        if IsMobile then
            AimBtnFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end
end))

--------------------------------------------------------------------------------
--// INIT
--------------------------------------------------------------------------------
LoadWeaponNames()

Library:Notify({
    Title = "Masacre Script",
    Content = IsMobile
        and "Loaded! Mobile mode active. Enable features to show buttons."
        or  "Loaded! F:Aimbot B:TargetAll H:Light G:Noclip",
    Emoji = "🔥",
    Duration = 5
})
