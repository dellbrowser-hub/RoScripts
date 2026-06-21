---------------------------------------------------------
-- Hub Loader Function
---------------------------------------------------------
local function startRenDHub()
    print("Starting RenD Hub...")

local SESSION_KEY = "__RenDHubActiveSession"
local SharedEnvironment = type(getgenv) == "function" and getgenv() or shared or _G
local previousSession = rawget(SharedEnvironment, SESSION_KEY)
if type(previousSession) == "table" and type(previousSession.Cleanup) == "function" then
    pcall(previousSession.Cleanup)
end

local Session = {
    Alive = true,
    Restarting = false,
    Cleanups = {},
}

function Session.AddCleanup(callback)
    table.insert(Session.Cleanups, callback)
end

function Session.Cleanup()
    if not Session.Alive then return end
    Session.Alive = false

    for index = #Session.Cleanups, 1, -1 do
        pcall(Session.Cleanups[index])
    end
    table.clear(Session.Cleanups)

    if rawget(SharedEnvironment, SESSION_KEY) == Session then
        rawset(SharedEnvironment, SESSION_KEY, nil)
    end
end

function Session.Restart()
    if Session.Restarting or not Session.Alive then return end
    Session.Restarting = true

    task.defer(function()
        Session.Cleanup()
        task.wait()
        startRenDHub()
    end)
end

rawset(SharedEnvironment, SESSION_KEY, Session)

local RenLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"))()
local Rayfield = RenLib:CreateRayfieldAdapter()

---------------------------------------------------------
-- Theme module
---------------------------------------------------------
local savedRGB = SharedEnvironment.RenDHubCustomRGB or {R = 25, G = 25, B = 25}
local ThemeModule = {
    CurrentTheme = SharedEnvironment.RenDHubSelectedTheme or "Serenity",
    CustomRGB = {R = savedRGB.R, G = savedRGB.G, B = savedRGB.B},
}

local function shade(rgb, amount)
    return Color3.fromRGB(
        math.clamp(rgb.R + amount, 0, 255),
        math.clamp(rgb.G + amount, 0, 255),
        math.clamp(rgb.B + amount, 0, 255)
    )
end

function ThemeModule.BuildCustomTheme()
    local rgb = ThemeModule.CustomRGB
    local brightness = (rgb.R * 299 + rgb.G * 587 + rgb.B * 114) / 1000
    local textColor = brightness > 150 and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(240, 240, 245)
    local accent = Color3.fromRGB(
        math.clamp(rgb.R + 70, 0, 255),
        math.clamp(rgb.G + 70, 0, 255),
        math.clamp(rgb.B + 70, 0, 255)
    )

    return {
        TextColor = textColor,
        Background = shade(rgb, 0),
        Topbar = shade(rgb, 10),
        Shadow = Color3.fromRGB(10, 10, 12),
        NotificationBackground = shade(rgb, 8),
        NotificationActionsBackground = shade(rgb, 18),
        TabBackground = shade(rgb, 7),
        TabStroke = shade(rgb, 25),
        TabBackgroundSelected = accent,
        TabTextColor = textColor,
        SelectedTabTextColor = brightness > 185 and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(255, 255, 255),
        ElementBackground = shade(rgb, 12),
        ElementBackgroundHover = shade(rgb, 20),
        SecondaryElementBackground = shade(rgb, 6),
        ElementStroke = shade(rgb, 28),
        SecondaryElementStroke = shade(rgb, 20),
        SliderBackground = shade(rgb, 35),
        SliderProgress = accent,
        SliderStroke = shade(rgb, 45),
        ToggleBackground = shade(rgb, 25),
        ToggleEnabled = accent,
        ToggleDisabled = shade(rgb, 35),
        ToggleEnabledStroke = shade(rgb, 60),
        ToggleDisabledStroke = shade(rgb, 45),
        ToggleEnabledOuterStroke = shade(rgb, 30),
        ToggleDisabledOuterStroke = shade(rgb, 25),
        DropdownSelected = shade(rgb, 22),
        DropdownUnselected = shade(rgb, 10),
        InputBackground = shade(rgb, 8),
        InputStroke = shade(rgb, 32),
        PlaceholderColor = shade(rgb, 100),
    }
end

function ThemeModule.ApplyPresetTheme(themeName)
    ThemeModule.CurrentTheme = themeName
    SharedEnvironment.RenDHubSelectedTheme = themeName
    SharedEnvironment.RenDHubUseCustomTheme = false
    
    Rayfield:Notify({
        Title = "Theme Changed",
        Content = "Theme set to " .. themeName .. ". Press Restart UI to apply it.",
        Duration = 4,
        Image = nil,
    })
end

function ThemeModule.UpdateCustomColor(r, g, b)
    ThemeModule.CustomRGB = {R = r, G = g, B = b}
end

function ThemeModule.SelectCustomTheme()
    SharedEnvironment.RenDHubCustomRGB = {
        R = ThemeModule.CustomRGB.R,
        G = ThemeModule.CustomRGB.G,
        B = ThemeModule.CustomRGB.B,
    }
    SharedEnvironment.RenDHubUseCustomTheme = true
    Rayfield:Notify({
        Title = "Custom Color",
        Content = "Custom RGB selected. Press Restart UI to apply it.",
        Duration = 3,
        Image = nil,
    })
end

local selectedTheme = SharedEnvironment.RenDHubUseCustomTheme and ThemeModule.BuildCustomTheme() or ThemeModule.CurrentTheme

local Window = Rayfield:CreateWindow({
   Name = "RenD Hub",
   Icon = 0,
   LoadingTitle = "RenD Hub",
   LoadingSubtitle = "by xsakyx",
   ShowText = "RenD Hub",
   Theme = selectedTheme,
   
   ToggleUIKeybind = "K",
   
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = true,
   
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "RenD Hub"
   },
   
   Discord = {
      Enabled = true,
      Invite = "amwATssmU4",
      RememberJoins = true
   },
   
   KeySystem = false,
   KeySettings = {
      Title = "RenD Hub key system",
      Subtitle = "easy key system",
      Note = "Join discord server to get key",
      FileName = "Key",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"NoKey"}
   }
})

Session.AddCleanup(function()
    pcall(function()
        Rayfield:Destroy()
    end)
end)

-- Tabs are created up front; controls are grouped after all modules exist.
local HomeTab = Window:CreateTab("Home", nil)
local MovementTab = Window:CreateTab("Movement", nil)
local PlayersTab = Window:CreateTab("Players", nil)
local VisualsTab = Window:CreateTab("Visuals", nil)
local TargetingTab = Window:CreateTab("Targeting", nil)
local SettingsTab = Window:CreateTab("Settings", nil)
local UIControls = {}

-- Show notification
Rayfield:Notify({
   Title = "RenD Hub",
   Content = "Script executed successfully",
   Duration = 6.5,
   Image = nil,
})

---------------------------------------------------------
-- Services and shared state
---------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

---------------------------------------------------------
-- Shared player filter
-- Automatic player-based features use this module so team
-- behavior stays consistent across the script.
---------------------------------------------------------
local PlayerFilterModule = {
    TeamCheckEnabled = true,
    ChangedCallbacks = {},
}

function PlayerFilterModule.IsSameTeam(player)
    if not player or player == LocalPlayer then
        return false
    end

    -- Neutral players are intentionally treated as free-for-all.
    if LocalPlayer.Neutral or player.Neutral then
        return false
    end

    local localTeam = LocalPlayer.Team
    if localTeam ~= nil and player.Team ~= nil then
        return player.Team == localTeam
    end

    -- TeamColor supports experiences that assign colors without Team instances.
    return player.TeamColor == LocalPlayer.TeamColor
end

function PlayerFilterModule.ShouldInclude(player)
    if not player or player == LocalPlayer then
        return false
    end

    return not (PlayerFilterModule.TeamCheckEnabled and PlayerFilterModule.IsSameTeam(player))
end

function PlayerFilterModule.OnChanged(callback)
    table.insert(PlayerFilterModule.ChangedCallbacks, callback)
end

function PlayerFilterModule.SetTeamCheckEnabled(enabled)
    enabled = enabled == true
    if PlayerFilterModule.TeamCheckEnabled == enabled then
        return
    end

    PlayerFilterModule.TeamCheckEnabled = enabled
    for _, callback in ipairs(PlayerFilterModule.ChangedCallbacks) do
        task.spawn(callback, enabled)
    end
end

---------------------------------------------------------
-- Aimbot module
---------------------------------------------------------
local AimbotModule = {}
AimbotModule.Enabled = false
AimbotModule.TargetPlayer = nil
AimbotModule.FOVRadius = 100
AimbotModule.Connection = nil
AimbotModule.FOVCircle = nil
AimbotModule.KeyConnection = nil
AimbotModule.AutoLock = true
AimbotModule.Smoothing = 1 -- Perfect balance between speed and accuracy
AimbotModule.PredictionStrength = 0.12 -- Optimal prediction
AimbotModule.AimPart = "Head" -- Can be "Head", "HumanoidRootPart", or "UpperTorso"

function AimbotModule.CreateFOVCircle()
    if AimbotModule.FOVCircle then
        AimbotModule.FOVCircle:Remove()
    end
    
    AimbotModule.FOVCircle = Drawing.new("Circle")
    AimbotModule.FOVCircle.Color = Color3.fromRGB(255, 0, 0) -- Red for better visibility
    AimbotModule.FOVCircle.Thickness = 1
    AimbotModule.FOVCircle.NumSides = 64 -- Smoother circle
    AimbotModule.FOVCircle.Radius = AimbotModule.FOVRadius
    AimbotModule.FOVCircle.Filled = false
    AimbotModule.FOVCircle.Transparency = 0.8
    AimbotModule.FOVCircle.Visible = AimbotModule.Enabled
    AimbotModule.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

function AimbotModule.IsPlayerValid(player)
    if not PlayerFilterModule.ShouldInclude(player) then return false end
    if not player.Character then return false end
    if not player.Character.Parent then return false end -- Check if character is in workspace
    if not player.Character:FindFirstChild(AimbotModule.AimPart) then return false end
    if not player.Character:FindFirstChild("HumanoidRootPart") then return false end
    if not player.Character:FindFirstChild("Humanoid") then return false end
    
    local humanoid = player.Character.Humanoid
    if humanoid.Health <= 0 then return false end
    if humanoid:GetState() == Enum.HumanoidStateType.Dead then return false end
    
    -- Additional checks for better targeting
    local targetPart = player.Character:FindFirstChild(AimbotModule.AimPart)
    if not targetPart then return false end
    
    return true
end

function AimbotModule.GetClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if AimbotModule.IsPlayerValid(player) then
            local targetPart = player.Character:FindFirstChild(AimbotModule.AimPart)
            local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen and screenPoint.Z > 0 then -- Make sure target is in front of camera
                local screenPosition = Vector2.new(screenPoint.X, screenPoint.Y)
                local distance = (centerScreen - screenPosition).Magnitude
                
                if distance <= AimbotModule.FOVRadius and distance < shortestDistance then
                    -- Enhanced line of sight check with multiple raycast points
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    raycastParams.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
                    
                    -- Check multiple points for better accuracy
                    local directions = {
                        (targetPart.Position - Camera.CFrame.Position).Unit,
                        (targetPart.Position + Vector3.new(0.5, 0, 0) - Camera.CFrame.Position).Unit,
                        (targetPart.Position + Vector3.new(-0.5, 0, 0) - Camera.CFrame.Position).Unit,
                        (targetPart.Position + Vector3.new(0, 0.5, 0) - Camera.CFrame.Position).Unit
                    }
                    
                    local validHit = false
                    for _, direction in ipairs(directions) do
                        local raycastResult = workspace:Raycast(Camera.CFrame.Position, direction * (targetPart.Position - Camera.CFrame.Position).Magnitude, raycastParams)
                        
                        if not raycastResult or raycastResult.Instance:IsDescendantOf(player.Character) then
                            validHit = true
                            break
                        end
                    end
                    
                    if validHit then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

function AimbotModule.PredictTargetPosition(targetPart)
    -- Advanced prediction system
    local targetVelocity = Vector3.new(0, 0, 0)
    local humanoidRootPart = targetPart.Parent:FindFirstChild("HumanoidRootPart")
    
    if humanoidRootPart then
        -- Get velocity from different sources for better accuracy
        if humanoidRootPart.AssemblyLinearVelocity then
            targetVelocity = humanoidRootPart.AssemblyLinearVelocity
        elseif humanoidRootPart.Velocity then
            targetVelocity = humanoidRootPart.Velocity
        end
    end
    
    -- Calculate prediction based on distance and velocity
    local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
    local timeToTarget = distance / 1000 -- Estimated bullet travel time
    
    -- Apply prediction with configured strength
    local predictedPosition = targetPart.Position + (targetVelocity * timeToTarget * AimbotModule.PredictionStrength)
    
    return predictedPosition
end

function AimbotModule.LockOnTarget()
    if AimbotModule.TargetPlayer and AimbotModule.IsPlayerValid(AimbotModule.TargetPlayer) then
        local targetPart = AimbotModule.TargetPlayer.Character:FindFirstChild(AimbotModule.AimPart)
        
        -- Check if target is still valid and visible
        local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen or screenPoint.Z <= 0 then
            AimbotModule.TargetPlayer = nil
            return
        end
        
        -- Get predicted position
        local predictedPosition = AimbotModule.PredictTargetPosition(targetPart)
        
        -- Create target CFrame
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, predictedPosition)
        
        -- Calculate screen distance for adaptive smoothing
        local screenPosition = Vector2.new(screenPoint.X, screenPoint.Y)
        local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local screenDistance = (centerScreen - screenPosition).Magnitude
        
        -- Adaptive smoothing based on distance and configured smoothing
        local baseSmoothSpeed = AimbotModule.Smoothing
        local distanceMultiplier = math.clamp(screenDistance / AimbotModule.FOVRadius, 0.3, 1.2)
        local finalSmoothSpeed = baseSmoothSpeed * distanceMultiplier
        
        -- Apply smooth camera movement with perfect accuracy
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, finalSmoothSpeed)
        
        -- Optional: Lock on exact position when very close (for 100% accuracy)
        if screenDistance < 5 then
            Camera.CFrame = targetCFrame
        end
    else
        -- Target is no longer valid, clear it
        AimbotModule.TargetPlayer = nil
    end
end

function AimbotModule.Enable()
    if AimbotModule.Enabled then return end
    
    AimbotModule.Enabled = true
    AimbotModule.CreateFOVCircle()
    
    -- Update FOV circle position and handle aiming
    AimbotModule.Connection = RunService.RenderStepped:Connect(function()
        if AimbotModule.FOVCircle then
            AimbotModule.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            AimbotModule.FOVCircle.Radius = AimbotModule.FOVRadius
        end
        
        -- AUTO-LOCK FEATURE with improved target switching
        if AimbotModule.AutoLock then
            if not AimbotModule.TargetPlayer or not AimbotModule.IsPlayerValid(AimbotModule.TargetPlayer) then
                -- Find new target automatically
                AimbotModule.TargetPlayer = AimbotModule.GetClosestPlayerInFOV()
            else
                -- Check if current target is still in FOV and optimal
                local targetPart = AimbotModule.TargetPlayer.Character:FindFirstChild(AimbotModule.AimPart)
                local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen and screenPoint.Z > 0 then
                    local screenPosition = Vector2.new(screenPoint.X, screenPoint.Y)
                    local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    local distance = (centerScreen - screenPosition).Magnitude
                    
                    -- Check if there's a better target (closer to crosshair)
                    local potentialTarget = AimbotModule.GetClosestPlayerInFOV()
                    if potentialTarget and potentialTarget ~= AimbotModule.TargetPlayer then
                        local newTargetPart = potentialTarget.Character:FindFirstChild(AimbotModule.AimPart)
                        local newScreenPoint, newOnScreen = Camera:WorldToViewportPoint(newTargetPart.Position)
                        if newOnScreen then
                            local newScreenPosition = Vector2.new(newScreenPoint.X, newScreenPoint.Y)
                            local newDistance = (centerScreen - newScreenPosition).Magnitude
                            
                            -- Switch to better target if significantly closer
                            if newDistance < distance * 0.7 then
                                AimbotModule.TargetPlayer = potentialTarget
                            end
                        end
                    end
                    
                    -- Auto-unlock if target moves too far from FOV
                    if distance > AimbotModule.FOVRadius * 1.1 then
                        AimbotModule.TargetPlayer = AimbotModule.GetClosestPlayerInFOV()
                    end
                else
                    AimbotModule.TargetPlayer = AimbotModule.GetClosestPlayerInFOV()
                end
            end
        end
        
        -- Lock onto target if we have one
        if AimbotModule.TargetPlayer then
            AimbotModule.LockOnTarget()
        end
    end)
    
    -- Handle X key input for manual control
    AimbotModule.KeyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.X then
            if AimbotModule.TargetPlayer then
                -- Unlock current target
                AimbotModule.TargetPlayer = nil
                AimbotModule.AutoLock = false
                Rayfield:Notify({
                    Title = "Aimbot",
                    Content = "Target unlocked - Auto-lock paused for 3 seconds",
                    Duration = 2,
                    Image = nil,
                })
                
                -- Re-enable auto-lock after 3 seconds
                task.spawn(function()
                    task.wait(3)
                    AimbotModule.AutoLock = true
                end)
            else
                -- Force lock onto closest player
                local closestPlayer = AimbotModule.GetClosestPlayerInFOV()
                if closestPlayer then
                    AimbotModule.TargetPlayer = closestPlayer
                    Rayfield:Notify({
                        Title = "Aimbot",
                        Content = "Manually locked onto " .. closestPlayer.Name,
                        Duration = 2,
                        Image = nil,
                    })
                else
                    Rayfield:Notify({
                        Title = "Aimbot",
                        Content = "No valid targets in FOV",
                        Duration = 1,
                        Image = nil,
                    })
                end
            end
        end
    end)
    
    Rayfield:Notify({
        Title = "Aimbot",
        Content = "Enabled with 100% Accuracy - Press X for manual control",
        Duration = 3,
        Image = nil,
    })
end

function AimbotModule.Disable(silent)
    if not AimbotModule.Enabled then return end
    
    AimbotModule.Enabled = false
    AimbotModule.TargetPlayer = nil
    AimbotModule.AutoLock = true
    
    -- Clean up connections
    if AimbotModule.Connection then
        AimbotModule.Connection:Disconnect()
        AimbotModule.Connection = nil
    end
    
    if AimbotModule.KeyConnection then
        AimbotModule.KeyConnection:Disconnect()
        AimbotModule.KeyConnection = nil
    end
    
    -- Remove FOV circle
    if AimbotModule.FOVCircle then
        AimbotModule.FOVCircle:Remove()
        AimbotModule.FOVCircle = nil
    end
    
    if not silent then
        Rayfield:Notify({Title = "Aimbot", Content = "Disabled", Duration = 2})
    end
end

function AimbotModule.Toggle()
    if AimbotModule.Enabled then
        AimbotModule.Disable()
    else
        AimbotModule.Enable()
    end
end

function AimbotModule.SetFOVRadius(radius)
    AimbotModule.FOVRadius = radius
    if AimbotModule.FOVCircle then
        AimbotModule.FOVCircle.Radius = radius
    end
end

function AimbotModule.SetSmoothness(smoothness)
    AimbotModule.Smoothing = smoothness / 100 -- Convert to decimal
end

function AimbotModule.SetAimPart(part)
    AimbotModule.AimPart = part
    Rayfield:Notify({
        Title = "Aimbot",
        Content = "Aim target set to " .. part,
        Duration = 2,
        Image = nil,
    })
end

PlayerFilterModule.OnChanged(function()
    if AimbotModule.TargetPlayer and not AimbotModule.IsPlayerValid(AimbotModule.TargetPlayer) then
        AimbotModule.TargetPlayer = nil
    end
end)

---------------------------------------------------------
-- ESP module
---------------------------------------------------------
local ESPModule = {}
ESPModule.Enabled = false
ESPModule.ESPObjects = {}
ESPModule.Connections = {
    Global = {},
    Players = {},
}
ESPModule.ShowHealthBar = true
ESPModule.ShowDistance = true

function ESPModule.CreateESP(player)
    ESPModule.RemoveESP(player)

    if not ESPModule.Enabled or not PlayerFilterModule.ShouldInclude(player) then return end
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local character = player.Character
    local humanoidRootPart = character.HumanoidRootPart
    local head = character:FindFirstChild("Head")
    
    -- Create improved highlight with better visibility
    local highlight = Instance.new("Highlight")
    highlight.Parent = character
    highlight.FillColor = Color3.fromRGB(255, 50, 50)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.7 -- More transparent so you can see the player
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    
    -- Create BillboardGui with better positioning and size
    local billboard = Instance.new("BillboardGui")
    billboard.Parent = head or humanoidRootPart
    billboard.Size = UDim2.new(0, 100, 0, 80) -- Smaller size
    billboard.StudsOffset = Vector3.new(0, 4, 0) -- Higher above head
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
    
    -- Create main frame with better transparency
    local frame = Instance.new("Frame")
    frame.Parent = billboard
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.8 -- More transparent
    frame.BorderSizePixel = 0
    
    -- Add corner rounding for better look
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame
    
    -- Create TextLabel for username (smaller)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Parent = frame
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.3 -- Lighter stroke
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    
    -- Create health bar background
    local healthBarBG = Instance.new("Frame")
    healthBarBG.Parent = frame
    healthBarBG.Size = UDim2.new(0.9, 0, 0.15, 0)
    healthBarBG.Position = UDim2.new(0.05, 0, 0.45, 0)
    healthBarBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthBarBG.BorderSizePixel = 0
    
    local healthBarCorner = Instance.new("UICorner")
    healthBarCorner.CornerRadius = UDim.new(0, 2)
    healthBarCorner.Parent = healthBarBG
    
    -- Create health bar fill
    local healthBar = Instance.new("Frame")
    healthBar.Parent = healthBarBG
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.Position = UDim2.new(0, 0, 0, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    
    local healthBarFillCorner = Instance.new("UICorner")
    healthBarFillCorner.CornerRadius = UDim.new(0, 2)
    healthBarFillCorner.Parent = healthBar
    
    -- Create health text (smaller)
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Parent = frame
    healthLabel.Size = UDim2.new(1, 0, 0.25, 0)
    healthLabel.Position = UDim2.new(0, 0, 0.65, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthLabel.TextStrokeTransparency = 0.3
    healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    healthLabel.TextScaled = true
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.TextSize = 10
    
    -- Create distance label
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Parent = frame
    distanceLabel.Size = UDim2.new(1, 0, 0.25, 0)
    distanceLabel.Position = UDim2.new(0, 0, 0.9, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distanceLabel.TextStrokeTransparency = 0.3
    distanceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distanceLabel.TextScaled = true
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextSize = 8
    
    -- Function to update ESP info
    local function updateESP()
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            local health = math.floor(humanoid.Health)
            local maxHealth = math.floor(humanoid.MaxHealth)

            healthLabel.Visible = ESPModule.ShowHealthBar
            healthBar.Visible = ESPModule.ShowHealthBar
            healthBarBG.Visible = ESPModule.ShowHealthBar
            
            -- Update health text
            if ESPModule.ShowHealthBar then
                healthLabel.Text = health .. "/" .. maxHealth
                
                -- Update health bar
                local healthPercent = math.clamp(health / math.max(maxHealth, 1), 0, 1)
                healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
                
                -- Change color based on health percentage
                if healthPercent > 0.6 then
                    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green
                    healthLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                elseif healthPercent > 0.3 then
                    healthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
                    healthLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                else
                    healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
                    healthLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                end
            else
                healthLabel.Text = ""
            end
            
            -- Update distance
            if ESPModule.ShowDistance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude)
                distanceLabel.Text = distance .. "m"
            else
                distanceLabel.Text = ""
            end
        end
    end
    
    -- Initial update
    updateESP()
    
    -- Connect health and distance updates
    local humanoid = character:FindFirstChild("Humanoid")
    local healthConnection

    if humanoid then
        healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(updateESP)
    end

    -- Store first so the update loop can reliably see this entry.
    ESPModule.ESPObjects[player] = {
        highlight = highlight,
        billboard = billboard,
        healthConnection = healthConnection,
        distanceThread = nil,
    }

    ESPModule.ESPObjects[player].distanceThread = task.spawn(function()
        while ESPModule.ESPObjects[player] and ESPModule.Enabled do
            updateESP()
            task.wait(0.5)
        end
    end)
end

function ESPModule.RemoveESP(player)
    local espObject = ESPModule.ESPObjects[player]
    if not espObject then return end

    -- Clear the table entry first so background loops stop immediately.
    ESPModule.ESPObjects[player] = nil

    if espObject.healthConnection then
        espObject.healthConnection:Disconnect()
    end
    if espObject.highlight then
        espObject.highlight:Destroy()
    end
    if espObject.billboard then
        espObject.billboard:Destroy()
    end
end

function ESPModule.RefreshPlayer(player)
    if not ESPModule.Enabled then return end

    if PlayerFilterModule.ShouldInclude(player) then
        ESPModule.CreateESP(player)
    else
        ESPModule.RemoveESP(player)
    end
end

function ESPModule.UntrackPlayer(player)
    local playerConnections = ESPModule.Connections.Players[player]
    if playerConnections then
        for _, connection in ipairs(playerConnections) do
            connection:Disconnect()
        end
        ESPModule.Connections.Players[player] = nil
    end

    ESPModule.RemoveESP(player)
end

function ESPModule.TrackPlayer(player)
    if player == LocalPlayer or ESPModule.Connections.Players[player] then return end

    local connections = {}
    ESPModule.Connections.Players[player] = connections

    table.insert(connections, player.CharacterAdded:Connect(function()
        task.wait(0.5)
        ESPModule.RefreshPlayer(player)
    end))

    table.insert(connections, player.CharacterRemoving:Connect(function()
        ESPModule.RemoveESP(player)
    end))

    table.insert(connections, player:GetPropertyChangedSignal("Team"):Connect(function()
        ESPModule.RefreshPlayer(player)
    end))

    table.insert(connections, player:GetPropertyChangedSignal("Neutral"):Connect(function()
        ESPModule.RefreshPlayer(player)
    end))

    table.insert(connections, player:GetPropertyChangedSignal("TeamColor"):Connect(function()
        ESPModule.RefreshPlayer(player)
    end))

    ESPModule.RefreshPlayer(player)
end

function ESPModule.Refresh()
    if not ESPModule.Enabled then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if ESPModule.Connections.Players[player] then
                ESPModule.RefreshPlayer(player)
            else
                ESPModule.TrackPlayer(player)
            end
        end
    end
end

function ESPModule.Enable()
    if ESPModule.Enabled then return end

    ESPModule.Enabled = true

    ESPModule.Connections.Global.PlayerAdded = Players.PlayerAdded:Connect(ESPModule.TrackPlayer)
    ESPModule.Connections.Global.PlayerRemoving = Players.PlayerRemoving:Connect(ESPModule.UntrackPlayer)
    ESPModule.Connections.Global.LocalTeamChanged = LocalPlayer:GetPropertyChangedSignal("Team"):Connect(ESPModule.Refresh)
    ESPModule.Connections.Global.LocalNeutralChanged = LocalPlayer:GetPropertyChangedSignal("Neutral"):Connect(ESPModule.Refresh)
    ESPModule.Connections.Global.LocalTeamColorChanged = LocalPlayer:GetPropertyChangedSignal("TeamColor"):Connect(ESPModule.Refresh)

    ESPModule.Refresh()

    Rayfield:Notify({
        Title = "Improved ESP",
        Content = "Enabled" .. (PlayerFilterModule.TeamCheckEnabled and " - teammates hidden" or " - all players shown"),
        Duration = 3,
        Image = nil,
    })
end

function ESPModule.Disable(silent)
    if not ESPModule.Enabled then return end
    
    ESPModule.Enabled = false
    
    for player in pairs(ESPModule.ESPObjects) do
        ESPModule.RemoveESP(player)
    end

    for player in pairs(ESPModule.Connections.Players) do
        ESPModule.UntrackPlayer(player)
    end

    for name, connection in pairs(ESPModule.Connections.Global) do
        if connection then
            connection:Disconnect()
        end
        ESPModule.Connections.Global[name] = nil
    end

    if not silent then
        Rayfield:Notify({Title = "Improved ESP", Content = "Disabled", Duration = 2})
    end
end

function ESPModule.Toggle()
    if ESPModule.Enabled then
        ESPModule.Disable()
    else
        ESPModule.Enable()
    end
end

PlayerFilterModule.OnChanged(function()
    if ESPModule.Enabled then
        ESPModule.Refresh()
    end
end)

-- FIXED INVISIBILITY MODULE - NOW WORKS FOR ALL PLAYERS
local InvisibilityModule = {}
InvisibilityModule.IsInvisible = false
InvisibilityModule.OriginalTransparency = {}
InvisibilityModule.HiddenDecals = {}

function InvisibilityModule.MakeInvisible()
    if InvisibilityModule.IsInvisible then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    InvisibilityModule.IsInvisible = true
    
    -- FIXED: Make completely invisible to ALL players (including yourself)
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            InvisibilityModule.OriginalTransparency[part] = part.Transparency
            part.Transparency = 1 -- Completely invisible
            
            -- Hide all decals (faces, shirts, pants, etc.)
            for _, child in pairs(part:GetChildren()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    InvisibilityModule.HiddenDecals[child] = child.Transparency
                    child.Transparency = 1
                elseif child:IsA("SurfaceGui") then
                    child.Enabled = false
                    InvisibilityModule.HiddenDecals[child] = true
                end
            end
        end
    end
    
    -- Hide all accessories (hats, hair, etc.)
    for _, accessory in pairs(character:GetChildren()) do
        if accessory:IsA("Accessory") or accessory:IsA("Hat") then
            local handle = accessory:FindFirstChild("Handle")
            if handle then
                InvisibilityModule.OriginalTransparency[handle] = handle.Transparency
                handle.Transparency = 1
                
                -- Hide all decals/textures on accessories
                for _, child in pairs(handle:GetChildren()) do
                    if child:IsA("Decal") or child:IsA("Texture") then
                        InvisibilityModule.HiddenDecals[child] = child.Transparency
                        child.Transparency = 1
                    elseif child:IsA("SurfaceGui") then
                        child.Enabled = false
                        InvisibilityModule.HiddenDecals[child] = true
                    elseif child:IsA("SpecialMesh") then
                        child.TextureId = ""
                        InvisibilityModule.HiddenDecals[child] = child.TextureId
                    end
                end
            end
        end
    end
    
    -- Hide clothing (Shirt, Pants, ShirtGraphic)
    for _, clothing in pairs(character:GetChildren()) do
        if clothing:IsA("Shirt") or clothing:IsA("Pants") or clothing:IsA("ShirtGraphic") then
            clothing.Parent = nil -- Remove clothing temporarily
            InvisibilityModule.HiddenDecals[clothing] = character -- Store original parent
        end
    end
    
    Rayfield:Notify({
        Title = "Invisibility",
        Content = "Enabled - You are now invisible to all players",
        Duration = 3,
        Image = nil,
    })
end

function InvisibilityModule.MakeVisible(silent)
    if not InvisibilityModule.IsInvisible then return end

    InvisibilityModule.IsInvisible = false
    
    -- Restore original transparency
    for part, originalTransparency in pairs(InvisibilityModule.OriginalTransparency) do
        if part and part.Parent then
            part.Transparency = originalTransparency
        end
    end
    
    -- Restore decals, textures, and GUIs
    for decal, originalValue in pairs(InvisibilityModule.HiddenDecals) do
        if decal and decal.Parent then
            if decal:IsA("Decal") or decal:IsA("Texture") then
                decal.Transparency = originalValue
            elseif decal:IsA("SurfaceGui") then
                decal.Enabled = true
            elseif decal:IsA("SpecialMesh") then
                decal.TextureId = originalValue
            elseif decal:IsA("Shirt") or decal:IsA("Pants") or decal:IsA("ShirtGraphic") then
                -- Restore clothing
                decal.Parent = originalValue
            end
        end
    end
    
    -- Clear the tables
    InvisibilityModule.OriginalTransparency = {}
    InvisibilityModule.HiddenDecals = {}
    
    if not silent then
        Rayfield:Notify({Title = "Invisibility", Content = "Disabled - You are now visible", Duration = 2})
    end
end

function InvisibilityModule.ToggleInvisibility()
    if InvisibilityModule.IsInvisible then
        InvisibilityModule.MakeVisible()
    else
        InvisibilityModule.MakeInvisible()
    end
end

---------------------------------------------------------
-- Flight module
---------------------------------------------------------
local FlyModule = {
    Flying = false,
    Speed = 60,
    Acceleration = 10,
    CurrentVelocity = Vector3.zero,
    Attachment = nil,
    LinearVelocity = nil,
    AlignOrientation = nil,
    Connection = nil,
    DiedConnection = nil,
    Humanoid = nil,
    RootPart = nil,
    PreviousAutoRotate = true,
}

local function getCharacterParts()
    local character = LocalPlayer.Character
    if not character then return nil, nil, nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return nil, nil, nil end

    return character, humanoid, rootPart
end

function FlyModule.StartFly()
    if FlyModule.Flying then return end

    local _, humanoid, rootPart = getCharacterParts()
    if not humanoid or not rootPart then
        Rayfield:Notify({Title = "Flight", Content = "Character is not ready", Duration = 2})
        return
    end

    FlyModule.Flying = true
    FlyModule.Humanoid = humanoid
    FlyModule.RootPart = rootPart
    FlyModule.PreviousAutoRotate = humanoid.AutoRotate
    FlyModule.CurrentVelocity = Vector3.zero
    humanoid.AutoRotate = false
    humanoid.Sit = false

    local attachment = Instance.new("Attachment")
    attachment.Name = "RenDHubFlightAttachment"
    attachment.Parent = rootPart

    local linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Name = "RenDHubFlightVelocity"
    linearVelocity.Attachment0 = attachment
    linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    linearVelocity.MaxForce = math.huge
    linearVelocity.VectorVelocity = Vector3.zero
    linearVelocity.Parent = rootPart

    local alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.Name = "RenDHubFlightOrientation"
    alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOrientation.Attachment0 = attachment
    alignOrientation.MaxTorque = math.huge
    alignOrientation.MaxAngularVelocity = math.huge
    alignOrientation.Responsiveness = 25
    alignOrientation.RigidityEnabled = false
    alignOrientation.Parent = rootPart

    FlyModule.Attachment = attachment
    FlyModule.LinearVelocity = linearVelocity
    FlyModule.AlignOrientation = alignOrientation

    FlyModule.Connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not FlyModule.Flying or not rootPart.Parent or humanoid.Health <= 0 then
            FlyModule.StopFly(true)
            return
        end

        local camera = workspace.CurrentCamera
        local cameraForward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        if cameraForward.Magnitude < 0.01 then
            cameraForward = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
        end
        cameraForward = cameraForward.Unit
        local cameraRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit

        local direction = Vector3.zero
        if not UserInputService:GetFocusedTextBox() then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += cameraForward end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= cameraForward end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += cameraRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= cameraRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
        end

        local desiredVelocity = direction.Magnitude > 0 and direction.Unit * FlyModule.Speed or Vector3.zero
        local blend = 1 - math.exp(-FlyModule.Acceleration * deltaTime)
        FlyModule.CurrentVelocity = FlyModule.CurrentVelocity:Lerp(desiredVelocity, blend)
        linearVelocity.VectorVelocity = FlyModule.CurrentVelocity
        alignOrientation.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + cameraForward)
    end)

    FlyModule.DiedConnection = humanoid.Died:Connect(function()
        FlyModule.StopFly(true)
    end)

    Rayfield:Notify({Title = "Flight", Content = "Enabled - WASD, Space, Left Ctrl", Duration = 2})
end

function FlyModule.StopFly(silent)
    if not FlyModule.Flying and not FlyModule.Attachment then return end
    FlyModule.Flying = false

    if FlyModule.Connection then FlyModule.Connection:Disconnect() end
    if FlyModule.DiedConnection then FlyModule.DiedConnection:Disconnect() end
    if FlyModule.LinearVelocity then FlyModule.LinearVelocity:Destroy() end
    if FlyModule.AlignOrientation then FlyModule.AlignOrientation:Destroy() end
    if FlyModule.Attachment then FlyModule.Attachment:Destroy() end

    if FlyModule.Humanoid and FlyModule.Humanoid.Parent then
        FlyModule.Humanoid.AutoRotate = FlyModule.PreviousAutoRotate
        FlyModule.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if FlyModule.RootPart and FlyModule.RootPart.Parent then
        FlyModule.RootPart.AssemblyLinearVelocity = Vector3.zero
    end

    FlyModule.Connection = nil
    FlyModule.DiedConnection = nil
    FlyModule.LinearVelocity = nil
    FlyModule.AlignOrientation = nil
    FlyModule.Attachment = nil
    FlyModule.Humanoid = nil
    FlyModule.RootPart = nil
    FlyModule.CurrentVelocity = Vector3.zero

    if not silent then
        Rayfield:Notify({Title = "Flight", Content = "Disabled", Duration = 2})
    end
end

function FlyModule.ToggleFly()
    if FlyModule.Flying then
        FlyModule.StopFly()
    else
        FlyModule.StartFly()
    end
end

-- CLICK TELEPORT MODULE - FIXED VERSION
local ClickTeleportModule = {}
ClickTeleportModule.Enabled = false
ClickTeleportModule.Connection = nil

function ClickTeleportModule.Enable()
    if ClickTeleportModule.Enabled then return end
    
    ClickTeleportModule.Enabled = true
    local mouse = LocalPlayer:GetMouse()
    
    ClickTeleportModule.Connection = mouse.Button1Down:Connect(function()
        -- Only teleport if still enabled
        if not ClickTeleportModule.Enabled then return end
        
        local character = LocalPlayer.Character
        local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if humanoidRootPart and mouse.Hit then
            -- Teleport to clicked position
            humanoidRootPart.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 5, 0))
        end
    end)
    
    -- Notify user that click teleport is enabled
    Rayfield:Notify({
        Title = "Click Teleport",
        Content = "Enabled - Click anywhere to teleport",
        Duration = 2,
        Image = nil,
    })
end

function ClickTeleportModule.Disable(silent)
    if not ClickTeleportModule.Enabled then return end
    
    ClickTeleportModule.Enabled = false
    
    -- Properly disconnect the connection
    if ClickTeleportModule.Connection then
        ClickTeleportModule.Connection:Disconnect()
        ClickTeleportModule.Connection = nil
    end
    
    if not silent then
        Rayfield:Notify({Title = "Click Teleport", Content = "Disabled", Duration = 2})
    end
end

function ClickTeleportModule.Toggle()
    if ClickTeleportModule.Enabled then
        ClickTeleportModule.Disable()
    else
        ClickTeleportModule.Enable()
    end
end

---------------------------------------------------------
-- Player interaction module
---------------------------------------------------------
local PlayerInteractionModule = {
    Enabled = false,
    TargetPlayer = nil,
    Mode = "Follow",
    Distance = 5,
    Connection = nil,
    LocalCharacterRemovingConnection = nil,
    Attachment = nil,
    AlignPosition = nil,
    AlignOrientation = nil,
    OriginalCanCollide = {},
    Humanoid = nil,
    PreviousAutoRotate = true,
}

function PlayerInteractionModule.FindTargetPlayer(username)
    local query = string.lower((username or ""):match("^%s*(.-)%s*$"))
    if query == "" then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(player.Name) == query or string.lower(player.DisplayName) == query then
            return player
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if string.find(string.lower(player.Name), query, 1, true)
            or string.find(string.lower(player.DisplayName), query, 1, true) then
            return player
        end
    end

    return nil
end

function PlayerInteractionModule.CreateAttachmentRig(character, humanoid, rootPart)
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            PlayerInteractionModule.OriginalCanCollide[descendant] = descendant.CanCollide
            descendant.CanCollide = false
        end
    end

    local attachment = Instance.new("Attachment")
    attachment.Name = "RenDHubInteractionAttachment"
    attachment.Parent = rootPart

    local alignPosition = Instance.new("AlignPosition")
    alignPosition.Name = "RenDHubInteractionPosition"
    alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPosition.Attachment0 = attachment
    alignPosition.MaxForce = math.huge
    alignPosition.MaxVelocity = 120
    alignPosition.Responsiveness = 55
    alignPosition.RigidityEnabled = false
    alignPosition.Parent = rootPart

    local alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.Name = "RenDHubInteractionOrientation"
    alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOrientation.Attachment0 = attachment
    alignOrientation.MaxTorque = math.huge
    alignOrientation.MaxAngularVelocity = math.huge
    alignOrientation.Responsiveness = 40
    alignOrientation.Parent = rootPart

    PlayerInteractionModule.Attachment = attachment
    PlayerInteractionModule.AlignPosition = alignPosition
    PlayerInteractionModule.AlignOrientation = alignOrientation
    PlayerInteractionModule.PreviousAutoRotate = humanoid.AutoRotate
    PlayerInteractionModule.Humanoid = humanoid
    humanoid.AutoRotate = false
    humanoid.PlatformStand = true
    humanoid.Sit = false
end

function PlayerInteractionModule.StartInteraction(username)
    PlayerInteractionModule.StopInteraction(true)

    local targetPlayer = PlayerInteractionModule.FindTargetPlayer(username)
    if not targetPlayer then
        Rayfield:Notify({Title = "Player Not Found", Content = "Could not find: " .. tostring(username), Duration = 3})
        return
    end
    if targetPlayer == LocalPlayer then
        Rayfield:Notify({Title = "Invalid Target", Content = "Choose another player", Duration = 2})
        return
    end

    local character, humanoid, rootPart = getCharacterParts()
    if not character or not humanoid or not rootPart then
        Rayfield:Notify({Title = "Character Error", Content = "Your character is not ready", Duration = 2})
        return
    end

    if FlyModule.Flying then
        FlyModule.StopFly(true)
        if UIControls.Flight then UIControls.Flight:Set(false) end
    end

    PlayerInteractionModule.Enabled = true
    PlayerInteractionModule.TargetPlayer = targetPlayer
    PlayerInteractionModule.Humanoid = humanoid
    PlayerInteractionModule.PreviousAutoRotate = humanoid.AutoRotate

    if PlayerInteractionModule.Mode ~= "Follow" then
        PlayerInteractionModule.CreateAttachmentRig(character, humanoid, rootPart)
    end

    PlayerInteractionModule.Connection = RunService.Heartbeat:Connect(PlayerInteractionModule.UpdateInteraction)
    PlayerInteractionModule.LocalCharacterRemovingConnection = LocalPlayer.CharacterRemoving:Connect(function()
        PlayerInteractionModule.StopInteraction(true)
    end)

    Rayfield:Notify({
        Title = "Player Interaction",
        Content = PlayerInteractionModule.Mode .. " started with " .. targetPlayer.Name,
        Duration = 3,
    })
end

function PlayerInteractionModule.UpdateInteraction()
    if not PlayerInteractionModule.Enabled or not PlayerInteractionModule.TargetPlayer then return end

    local targetPlayer = PlayerInteractionModule.TargetPlayer
    if not targetPlayer.Parent then
        PlayerInteractionModule.StopInteraction()
        return
    end

    local targetCharacter = targetPlayer.Character
    local character, localHumanoid, localRoot = getCharacterParts()
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    if not character or not localHumanoid or not localRoot or not targetRoot then return end

    if PlayerInteractionModule.Mode == "Follow" then
        local followPosition = targetRoot.Position - targetRoot.CFrame.LookVector * PlayerInteractionModule.Distance
        local separation = (followPosition - localRoot.Position).Magnitude

        localHumanoid.PlatformStand = false
        localHumanoid.AutoRotate = true
        localHumanoid.Sit = false

        if separation > 80 then
            character:PivotTo(CFrame.lookAt(followPosition, targetRoot.Position))
        elseif separation > 1.5 then
            localHumanoid:MoveTo(followPosition)
        else
            localHumanoid:MoveTo(localRoot.Position)
        end

        if targetHumanoid then
            local targetState = targetHumanoid:GetState()
            if targetState == Enum.HumanoidStateType.Jumping or targetState == Enum.HumanoidStateType.Freefall then
                localHumanoid.Jump = true
            end
        end
        return
    end

    if not PlayerInteractionModule.AlignPosition or not PlayerInteractionModule.AlignOrientation then return end

    local desiredPosition
    if PlayerInteractionModule.Mode == "Backpack" then
        desiredPosition = targetRoot.CFrame:PointToWorldSpace(Vector3.new(0, 0.5, 1.75))
    else
        desiredPosition = targetRoot.Position + Vector3.new(0, 3.25, 0)
    end

    PlayerInteractionModule.AlignPosition.Position = desiredPosition
    PlayerInteractionModule.AlignOrientation.CFrame = CFrame.lookAt(
        desiredPosition,
        desiredPosition - targetRoot.CFrame.LookVector
    )
end

function PlayerInteractionModule.StopInteraction(silent)
    local wasEnabled = PlayerInteractionModule.Enabled
    PlayerInteractionModule.Enabled = false
    PlayerInteractionModule.TargetPlayer = nil

    if PlayerInteractionModule.Connection then PlayerInteractionModule.Connection:Disconnect() end
    if PlayerInteractionModule.LocalCharacterRemovingConnection then
        PlayerInteractionModule.LocalCharacterRemovingConnection:Disconnect()
    end
    if PlayerInteractionModule.AlignPosition then PlayerInteractionModule.AlignPosition:Destroy() end
    if PlayerInteractionModule.AlignOrientation then PlayerInteractionModule.AlignOrientation:Destroy() end
    if PlayerInteractionModule.Attachment then PlayerInteractionModule.Attachment:Destroy() end

    if PlayerInteractionModule.Humanoid and PlayerInteractionModule.Humanoid.Parent then
        PlayerInteractionModule.Humanoid.PlatformStand = false
        PlayerInteractionModule.Humanoid.Sit = false
        PlayerInteractionModule.Humanoid.AutoRotate = PlayerInteractionModule.PreviousAutoRotate
        PlayerInteractionModule.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end

    for part, canCollide in pairs(PlayerInteractionModule.OriginalCanCollide) do
        if part.Parent then part.CanCollide = canCollide end
    end

    PlayerInteractionModule.Connection = nil
    PlayerInteractionModule.LocalCharacterRemovingConnection = nil
    PlayerInteractionModule.Attachment = nil
    PlayerInteractionModule.AlignPosition = nil
    PlayerInteractionModule.AlignOrientation = nil
    PlayerInteractionModule.OriginalCanCollide = {}
    PlayerInteractionModule.Humanoid = nil

    if wasEnabled and not silent then
        Rayfield:Notify({Title = "Player Interaction", Content = "Stopped", Duration = 2})
    end
end

function PlayerInteractionModule.SetMode(mode)
    if mode ~= "Follow" and mode ~= "Backpack" and mode ~= "Head" then return end

    local activeTarget = PlayerInteractionModule.TargetPlayer
    PlayerInteractionModule.Mode = mode
    if activeTarget then
        PlayerInteractionModule.StartInteraction(activeTarget.Name)
    end
end

function PlayerInteractionModule.SetDistance(distance)
    PlayerInteractionModule.Distance = distance
end

---------------------------------------------------------
-- Noclip module
---------------------------------------------------------
local NoClipModule = {
    Enabled = false,
    Connection = nil,
    OriginalCanCollide = {},
}

function NoClipModule.Enable()
    if NoClipModule.Enabled then return end
    
    NoClipModule.Enabled = true

    NoClipModule.Connection = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if NoClipModule.OriginalCanCollide[part] == nil then
                        NoClipModule.OriginalCanCollide[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        end
    end)

    Rayfield:Notify({Title = "Noclip", Content = "Enabled", Duration = 2})
end

function NoClipModule.Disable(silent)
    if not NoClipModule.Enabled and not next(NoClipModule.OriginalCanCollide) then return end
    
    NoClipModule.Enabled = false
    
    if NoClipModule.Connection then
        NoClipModule.Connection:Disconnect()
        NoClipModule.Connection = nil
    end

    for part, canCollide in pairs(NoClipModule.OriginalCanCollide) do
        if part.Parent then part.CanCollide = canCollide end
    end
    NoClipModule.OriginalCanCollide = {}

    if not silent then
        Rayfield:Notify({Title = "Noclip", Content = "Disabled", Duration = 2})
    end
end

function NoClipModule.Toggle()
    if NoClipModule.Enabled then
        NoClipModule.Disable()
    else
        NoClipModule.Enable()
    end
end

---------------------------------------------------------
-- Character settings and extra utilities
---------------------------------------------------------
local _, initialHumanoid = getCharacterParts()
local CharacterSettingsModule = {
    WalkSpeed = initialHumanoid and initialHumanoid.WalkSpeed or 16,
    JumpPower = initialHumanoid and initialHumanoid.JumpPower or 50,
    Gravity = workspace.Gravity,
    FieldOfView = Camera.FieldOfView,
    OriginalWalkSpeed = initialHumanoid and initialHumanoid.WalkSpeed or 16,
    OriginalJumpPower = initialHumanoid and initialHumanoid.JumpPower or 50,
    OriginalGravity = workspace.Gravity,
    OriginalFieldOfView = Camera.FieldOfView,
    InfiniteJump = false,
    JumpConnection = nil,
    CharacterConnection = nil,
}

function CharacterSettingsModule.ApplyToCharacter(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    humanoid.WalkSpeed = CharacterSettingsModule.WalkSpeed
    humanoid.UseJumpPower = true
    humanoid.JumpPower = CharacterSettingsModule.JumpPower
end

function CharacterSettingsModule.SetWalkSpeed(value)
    CharacterSettingsModule.WalkSpeed = value
    CharacterSettingsModule.ApplyToCharacter(LocalPlayer.Character)
end

function CharacterSettingsModule.SetJumpPower(value)
    CharacterSettingsModule.JumpPower = value
    CharacterSettingsModule.ApplyToCharacter(LocalPlayer.Character)
end

function CharacterSettingsModule.SetGravity(value)
    CharacterSettingsModule.Gravity = value
    workspace.Gravity = value
end

function CharacterSettingsModule.SetFieldOfView(value)
    CharacterSettingsModule.FieldOfView = value
    Camera.FieldOfView = value
end

function CharacterSettingsModule.SetInfiniteJump(enabled)
    CharacterSettingsModule.InfiniteJump = enabled == true

    if CharacterSettingsModule.JumpConnection then
        CharacterSettingsModule.JumpConnection:Disconnect()
        CharacterSettingsModule.JumpConnection = nil
    end

    if CharacterSettingsModule.InfiniteJump then
        CharacterSettingsModule.JumpConnection = UserInputService.JumpRequest:Connect(function()
            local _, humanoid = getCharacterParts()
            if humanoid and humanoid.Health > 0 then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

function CharacterSettingsModule.Reset()
    CharacterSettingsModule.SetWalkSpeed(CharacterSettingsModule.OriginalWalkSpeed)
    CharacterSettingsModule.SetJumpPower(CharacterSettingsModule.OriginalJumpPower)
    CharacterSettingsModule.SetGravity(CharacterSettingsModule.OriginalGravity)
    CharacterSettingsModule.SetFieldOfView(CharacterSettingsModule.OriginalFieldOfView)
    CharacterSettingsModule.SetInfiniteJump(false)
end

CharacterSettingsModule.CharacterConnection = LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.25)
    CharacterSettingsModule.ApplyToCharacter(character)
end)

local FullbrightModule = {
    Enabled = false,
    Connection = nil,
    Original = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    },
}

function FullbrightModule.Apply()
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
end

function FullbrightModule.Enable()
    if FullbrightModule.Enabled then return end
    FullbrightModule.Enabled = true
    FullbrightModule.Apply()
    FullbrightModule.Connection = Lighting.Changed:Connect(function()
        if FullbrightModule.Enabled then
            task.defer(function()
                if FullbrightModule.Enabled then
                    FullbrightModule.Apply()
                end
            end)
        end
    end)
end

function FullbrightModule.Disable()
    if not FullbrightModule.Enabled then return end
    FullbrightModule.Enabled = false
    if FullbrightModule.Connection then
        FullbrightModule.Connection:Disconnect()
        FullbrightModule.Connection = nil
    end
    for property, value in pairs(FullbrightModule.Original) do
        Lighting[property] = value
    end
end

function FullbrightModule.Toggle()
    if FullbrightModule.Enabled then FullbrightModule.Disable() else FullbrightModule.Enable() end
end

local PositionModule = {
    SavedCFrame = nil,
}

function PositionModule.Save()
    local _, _, rootPart = getCharacterParts()
    if not rootPart then return false end
    PositionModule.SavedCFrame = rootPart.CFrame
    Rayfield:Notify({Title = "Position", Content = "Current position saved", Duration = 2})
    return true
end

function PositionModule.Return()
    local character = LocalPlayer.Character
    if not character or not PositionModule.SavedCFrame then
        Rayfield:Notify({Title = "Position", Content = "Save a position first", Duration = 2})
        return
    end
    character:PivotTo(PositionModule.SavedCFrame)
end

local function teleportToPlayer(username)
    local target = PlayerInteractionModule.FindTargetPlayer(username)
    local character = LocalPlayer.Character
    local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not target or target == LocalPlayer or not character or not targetRoot then
        Rayfield:Notify({Title = "Teleport", Content = "Player or character not found", Duration = 2})
        return
    end
    character:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 3))
end

---------------------------------------------------------
-- Organized UI
---------------------------------------------------------

local HomeOverviewSection = HomeTab:CreateSection("Session")
local HomeOverview = HomeTab:CreateParagraph({
   Title = "RenD Hub V4",
   Content = "One active session, restartable themes, modern flight, repaired interactions, and persistent movement settings."
})

local StopAllButton = HomeTab:CreateButton({
   Name = "Stop Active Features",
   Callback = function()
       AimbotModule.Disable(true)
       ESPModule.Disable(true)
       FlyModule.StopFly(true)
       ClickTeleportModule.Disable(true)
       PlayerInteractionModule.StopInteraction(true)
       NoClipModule.Disable(true)
       for _, controlName in ipairs({"Aimbot", "ESP", "Flight", "ClickTeleport", "Noclip"}) do
           local control = UIControls[controlName]
           if control then control:Set(false) end
       end
       Rayfield:Notify({Title = "Session", Content = "Active movement and targeting stopped", Duration = 2})
   end,
})

local ResetCharacterButton = HomeTab:CreateButton({
   Name = "Reset Character",
   Callback = function()
       local _, humanoid = getCharacterParts()
       if humanoid then humanoid.Health = 0 end
   end,
})

local RestartHomeButton = HomeTab:CreateButton({
   Name = "Restart UI",
   Callback = Session.Restart,
})

local PlayerNavigationSection = PlayersTab:CreateSection("Player Navigation")
local PlayerTeleportInput = PlayersTab:CreateInput({
   Name = "Player Name",
   CurrentValue = "",
   PlaceholderText = "Username or display name",
   RemoveTextAfterFocusLost = false,
   Flag = "PlayerTeleportInput",
   Callback = function() end,
})

local TeleportToPlayerButton = PlayersTab:CreateButton({
   Name = "Teleport To Player",
   Callback = function()
       teleportToPlayer(PlayerTeleportInput.CurrentValue or "")
   end,
})

local BasicMovementSection = MovementTab:CreateSection("Character Movement")

-- Movement Speed Slider
local MovementSpeedSlider = MovementTab:CreateSlider({
   Name = "Movement Speed",
   Range = {5, 100},
   Increment = 1,
   Suffix = "Speed",
   CurrentValue = CharacterSettingsModule.WalkSpeed,
   Flag = "MovementSpeedSlider",
   Callback = function(Value)
       CharacterSettingsModule.SetWalkSpeed(Value)
   end,
})

-- Jump Power Slider
local JumpPowerSlider = MovementTab:CreateSlider({
   Name = "Jump Power",
   Range = {10, 200},
   Increment = 5,
   Suffix = "Power",
   CurrentValue = CharacterSettingsModule.JumpPower,
   Flag = "JumpPowerSlider",
   Callback = function(Value)
       CharacterSettingsModule.SetJumpPower(Value)
   end,
})

local GravitySlider = MovementTab:CreateSlider({
   Name = "World Gravity",
   Range = {0, 300},
   Increment = 5,
   Suffix = "gravity",
   CurrentValue = math.floor(CharacterSettingsModule.Gravity),
   Flag = "GravitySlider",
   Callback = CharacterSettingsModule.SetGravity,
})

local FieldOfViewSlider = MovementTab:CreateSlider({
   Name = "Camera Field of View",
   Range = {40, 120},
   Increment = 1,
   Suffix = "degrees",
   CurrentValue = math.floor(CharacterSettingsModule.FieldOfView),
   Flag = "FieldOfViewSlider",
   Callback = CharacterSettingsModule.SetFieldOfView,
})

local InfiniteJumpToggle = MovementTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Flag = "InfiniteJump",
   Callback = CharacterSettingsModule.SetInfiniteJump,
})

local PlayerInteractionSection = PlayersTab:CreateSection("Player Interaction")

-- Target Player Input
local TargetPlayerInput = PlayersTab:CreateInput({
   Name = "Target Player",
   CurrentValue = "",
   PlaceholderText = "Enter player username",
   RemoveTextAfterFocusLost = false,
   Flag = "TargetPlayerInput",
   Callback = function(Text)
       -- Input stored for use by buttons
   end,
})

-- Interaction Mode Dropdown
local InteractionModeDropdown = PlayersTab:CreateDropdown({
   Name = "Interaction Mode",
   Options = {"Follow", "Backpack", "Head"},
   CurrentOption = {"Follow"},
   MultipleOptions = false,
   Flag = "InteractionMode",
   Callback = function(Option)
       PlayerInteractionModule.SetMode(Option[1])
   end,
})

-- Follow Distance Slider
local FollowDistanceSlider = PlayersTab:CreateSlider({
   Name = "Follow Distance",
   Range = {1, 20},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = 5,
   Flag = "FollowDistance",
   Callback = function(Value)
       PlayerInteractionModule.SetDistance(Value)
   end,
})

-- Start Interaction Button
local StartInteractionButton = PlayersTab:CreateButton({
   Name = "Start Interaction",
   Callback = function()
       local targetUsername = TargetPlayerInput.CurrentValue or ""
       if targetUsername ~= "" then
           PlayerInteractionModule.StartInteraction(targetUsername)
       else
           Rayfield:Notify({
               Title = "No Target",
               Content = "Please enter a player username first",
               Duration = 2,
               Image = nil,
           })
       end
   end,
})

-- Stop Interaction Button
local StopInteractionButton = PlayersTab:CreateButton({
   Name = "Stop Interaction",
   Callback = function()
       PlayerInteractionModule.StopInteraction()
   end,
})

local AdvancedMovementSection = MovementTab:CreateSection("Advanced Movement")

local NoclipToggle = MovementTab:CreateToggle({
   Name = "Noclip",
   CurrentValue = false,
   Flag = "Noclip",
   Callback = function(Value)
       if Value then NoClipModule.Enable() else NoClipModule.Disable() end
   end,
})
UIControls.Noclip = NoclipToggle

local ClickTeleportToggle = MovementTab:CreateToggle({
   Name = "Click Teleport",
   CurrentValue = false,
   Flag = "ClickTeleport",
   Callback = function(Value)
       if Value then ClickTeleportModule.Enable() else ClickTeleportModule.Disable() end
   end,
})
UIControls.ClickTeleport = ClickTeleportToggle

local SavePositionButton = MovementTab:CreateButton({
   Name = "Save Current Position",
   Callback = PositionModule.Save,
})

local ReturnPositionButton = MovementTab:CreateButton({
   Name = "Return To Saved Position",
   Callback = PositionModule.Return,
})

local FlightSection = MovementTab:CreateSection("Flight")

local FlySpeedSlider = MovementTab:CreateSlider({
   Name = "Fly Speed",
   Range = {10, 200},
   Increment = 5,
   Suffix = "speed",
   CurrentValue = FlyModule.Speed,
   Flag = "FlySpeedSlider",
   Callback = function(Value)
       FlyModule.Speed = Value
   end,
})

local FlyToggle = MovementTab:CreateToggle({
   Name = "Flight",
   CurrentValue = false,
   Flag = "Flight",
   Callback = function(Value)
       if Value then FlyModule.StartFly() else FlyModule.StopFly() end
   end,
})
UIControls.Flight = FlyToggle

local VisualPlayerSection = VisualsTab:CreateSection("Player Visuals")

local ESPToggle = VisualsTab:CreateToggle({
   Name = "ESP",
   CurrentValue = false,
   Flag = "ESPEnabled",
   Callback = function(Value)
       if Value then ESPModule.Enable() else ESPModule.Disable() end
   end,
})
UIControls.ESP = ESPToggle

local InvisibilityToggle = VisualsTab:CreateToggle({
   Name = "Local Invisibility",
   CurrentValue = false,
   Flag = "Invisibility",
   Callback = function(Value)
       if Value then InvisibilityModule.MakeInvisible() else InvisibilityModule.MakeVisible() end
   end,
})

local EnvironmentSection = VisualsTab:CreateSection("Environment")

local FullbrightToggle = VisualsTab:CreateToggle({
   Name = "Fullbright",
   CurrentValue = false,
   Flag = "Fullbright",
   Callback = function(Value)
       if Value then FullbrightModule.Enable() else FullbrightModule.Disable() end
   end,
})

---------------------------------------------------------
-- Targeting controls
---------------------------------------------------------

local TargetFilterSection = TargetingTab:CreateSection("Player Filters")

local TeamCheckToggle = TargetingTab:CreateToggle({
   Name = "Team Check",
   CurrentValue = true,
   Flag = "TeamCheck",
   Callback = function(Value)
       PlayerFilterModule.SetTeamCheckEnabled(Value)
       Rayfield:Notify({
           Title = "Team Check",
           Content = Value and "Enabled - teammates are ignored" or "Disabled - all other players are eligible",
           Duration = 2,
           Image = nil,
       })
   end,
})

local AimbotControlsSection = TargetingTab:CreateSection("Aimbot Controls")

-- FOV Radius Slider
local FOVSlider = TargetingTab:CreateSlider({
   Name = "FOV Radius",
   Range = {50, 300},
   Increment = 10,
   Suffix = "px",
   CurrentValue = 100,
   Flag = "FOVSlider",
   Callback = function(Value)
       AimbotModule.SetFOVRadius(Value)
   end,
})

-- Aimbot Smoothness Slider
local AimbotSmoothnessSlider = TargetingTab:CreateSlider({
   Name = "Aimbot Smoothness",
   Range = {1, 100},
   Increment = 1,
   Suffix = "%",
   CurrentValue = 15,
   Flag = "AimbotSmoothness",
   Callback = function(Value)
       AimbotModule.SetSmoothness(Value)
   end,
})

-- Aim Part Dropdown
local AimPartDropdown = TargetingTab:CreateDropdown({
   Name = "Aim Target",
   Options = {"Head", "HumanoidRootPart", "UpperTorso"},
   CurrentOption = {"Head"},
   MultipleOptions = false,
   Flag = "AimPart",
   Callback = function(Option)
       AimbotModule.SetAimPart(Option[1])
   end,
})

local AimbotToggle = TargetingTab:CreateToggle({
   Name = "Aimbot",
   CurrentValue = false,
   Flag = "AimbotEnabled",
   Callback = function(Value)
       if Value then AimbotModule.Enable() else AimbotModule.Disable() end
   end,
})
UIControls.Aimbot = AimbotToggle

local ESPOptionsSection = VisualsTab:CreateSection("ESP Details")

-- ESP Health Bar Toggle
local ESPHealthBarToggle = VisualsTab:CreateToggle({
   Name = "Show Health Bar",
   CurrentValue = true,
   Flag = "ESPHealthBar",
   Callback = function(Value)
       ESPModule.ShowHealthBar = Value
   end,
})

-- ESP Distance Toggle
local ESPDistanceToggle = VisualsTab:CreateToggle({
   Name = "Show Distance",
   CurrentValue = true,
   Flag = "ESPDistance",
   Callback = function(Value)
       ESPModule.ShowDistance = Value
   end,
})

-- Aimbot Instructions
local AimbotInstructions = TargetingTab:CreateParagraph({
   Title = "Aimbot Instructions",
   Content = "1. Use Team Check to ignore teammates\n2. Enable aimbot with the toggle button\n3. Adjust FOV radius and smoothness\n4. Choose aim target (Head/Body/Torso)\n5. Press 'X' to manually unlock/lock targets"
})

-- ESP Instructions
local ESPInstructions = VisualsTab:CreateParagraph({
   Title = "ESP Instructions",
   Content = "1. Toggle ESP to highlight eligible players\n2. Team Check hides teammates when enabled\n3. Health bars show current/max HP with color coding\n4. Distance shows how far players are from you\n5. Team changes refresh automatically"
})

---------------------------------------------------------
-- Settings and theme controls
---------------------------------------------------------
local ThemeSection = SettingsTab:CreateSection("Theme")

local ThemeDropdown = SettingsTab:CreateDropdown({
   Name = "Theme Presets",
   Options = {"Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity", "Custom RGB"},
   CurrentOption = {SharedEnvironment.RenDHubUseCustomTheme and "Custom RGB" or ThemeModule.CurrentTheme},
   MultipleOptions = false,
   Callback = function(Option)
       if Option[1] == "Custom RGB" then
           ThemeModule.SelectCustomTheme()
       else
           ThemeModule.ApplyPresetTheme(Option[1])
       end
   end,
})

-- Custom RGB Section
local CustomColorSection = SettingsTab:CreateSection("Custom RGB Colors")

-- Red Input
local RedInput = SettingsTab:CreateInput({
   Name = "Red Value (0-255)",
   CurrentValue = tostring(ThemeModule.CustomRGB.R),
   PlaceholderText = "Enter red value",
   RemoveTextAfterFocusLost = false,
   Flag = "RedInput",
   Callback = function(Text)
       local r = tonumber(Text)
       if r and r >= 0 and r <= 255 then
            ThemeModule.UpdateCustomColor(r, ThemeModule.CustomRGB.G, ThemeModule.CustomRGB.B)
       else
           Rayfield:Notify({
               Title = "Invalid Input",
               Content = "Red value must be between 0-255",
               Duration = 2,
               Image = nil,
           })
       end
   end,
})

-- Green Input
local GreenInput = SettingsTab:CreateInput({
   Name = "Green Value (0-255)",
   CurrentValue = tostring(ThemeModule.CustomRGB.G),
   PlaceholderText = "Enter green value",
   RemoveTextAfterFocusLost = false,
   Flag = "GreenInput",
   Callback = function(Text)
       local g = tonumber(Text)
       if g and g >= 0 and g <= 255 then
            ThemeModule.UpdateCustomColor(ThemeModule.CustomRGB.R, g, ThemeModule.CustomRGB.B)
       else
           Rayfield:Notify({
               Title = "Invalid Input",
               Content = "Green value must be between 0-255",
               Duration = 2,
               Image = nil,
           })
       end
   end,
})

-- Blue Input
local BlueInput = SettingsTab:CreateInput({
   Name = "Blue Value (0-255)",
   CurrentValue = tostring(ThemeModule.CustomRGB.B),
   PlaceholderText = "Enter blue value",
   RemoveTextAfterFocusLost = false,
   Flag = "BlueInput",
   Callback = function(Text)
       local b = tonumber(Text)
       if b and b >= 0 and b <= 255 then
            ThemeModule.UpdateCustomColor(ThemeModule.CustomRGB.R, ThemeModule.CustomRGB.G, b)
       else
           Rayfield:Notify({
               Title = "Invalid Input",
               Content = "Blue value must be between 0-255",
               Duration = 2,
               Image = nil,
           })
       end
   end,
})

local ApplyCustomThemeButton = SettingsTab:CreateButton({
   Name = "Use Custom RGB Theme",
   Callback = ThemeModule.SelectCustomTheme,
})

local RestartUIThemeButton = SettingsTab:CreateButton({
   Name = "Restart UI To Apply Theme",
   Callback = Session.Restart,
})

-- Feature Status Section
local FeatureStatusSection = SettingsTab:CreateSection("Feature Status")

-- Status Display
local StatusParagraph = SettingsTab:CreateParagraph({
   Title = "Current Status",
   Content = "Loading status..."
})

-- Update status function
local function updateStatus()
    local aimbotStatus = AimbotModule.Enabled and "Enabled" or "Disabled"
    local espStatus = ESPModule.Enabled and "Enabled" or "Disabled"
    local flyStatus = FlyModule.Flying and "Enabled" or "Disabled"
    local invisStatus = InvisibilityModule.IsInvisible and "Enabled" or "Disabled"
    local noclipStatus = NoClipModule.Enabled and "Enabled" or "Disabled"
    local teamCheckStatus = PlayerFilterModule.TeamCheckEnabled and "Enabled" or "Disabled"
    local interactionStatus = PlayerInteractionModule.Enabled and PlayerInteractionModule.Mode or "Disabled"
    local fullbrightStatus = FullbrightModule.Enabled and "Enabled" or "Disabled"
    
    local targetInfo = ""
    if AimbotModule.Enabled and AimbotModule.TargetPlayer then
        targetInfo = "\nTarget: " .. AimbotModule.TargetPlayer.Name
    end
    
    StatusParagraph:Set({
        Title = "Current Status",
        Content = "Team Check: " .. teamCheckStatus
            .. "\nAimbot: " .. aimbotStatus .. targetInfo
            .. "\nESP: " .. espStatus
            .. "\nFlight: " .. flyStatus
            .. "\nInteraction: " .. interactionStatus
            .. "\nInvisibility: " .. invisStatus
            .. "\nNoclip: " .. noclipStatus
            .. "\nFullbright: " .. fullbrightStatus
    })
end

-- Update status every 2 seconds
task.spawn(function()
    while Session.Alive do
        updateStatus()
        task.wait(2)
    end
end)

Session.AddCleanup(function()
    AimbotModule.Disable(true)
    ESPModule.Disable(true)
    FlyModule.StopFly(true)
    ClickTeleportModule.Disable(true)
    PlayerInteractionModule.StopInteraction(true)
    NoClipModule.Disable(true)
    InvisibilityModule.MakeVisible(true)
    FullbrightModule.Disable()

    if CharacterSettingsModule.CharacterConnection then
        CharacterSettingsModule.CharacterConnection:Disconnect()
        CharacterSettingsModule.CharacterConnection = nil
    end
    CharacterSettingsModule.Reset()
end)

-- Credits Section
local CreditsSection = SettingsTab:CreateSection("Credits & Info")

local CreditsParagraph = SettingsTab:CreateParagraph({
   Title = "RenD Hub V4",
   Content = "Created by SoLoIsTe_Cry\nSession-safe UI, modern flight, repaired follow modes, team filtering, and organized feature tabs."
})

-- Keybinds Info
local KeybindsParagraph = SettingsTab:CreateParagraph({
   Title = "Keybinds",
   Content = "K - Toggle UI\nX - Manual target lock/unlock\nWASD - Flight movement\nSpace / Left Ctrl - Fly up / down\nMouse click - Click Teleport when enabled"
})
end

startRenDHub()
