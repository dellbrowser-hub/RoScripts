---------------------------------------------------------
-- Hub Loader Function
---------------------------------------------------------
local function startRenDHub()
    print("Starting RenD Hub...")
    -- Load from raw link
    -- RenD Hub - Complete Fixed Script with Improved Aimbot, ESP, and Invisibility
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- THEME MODULE (Define before creating window)
local ThemeModule = {}
ThemeModule.CurrentTheme = "Serenity"
ThemeModule.CustomRGB = {R = 25, G = 25, B = 25}

function ThemeModule.ApplyPresetTheme(themeName)
    ThemeModule.CurrentTheme = themeName
    _G.RenDHubSelectedTheme = themeName
    
    Rayfield:Notify({
        Title = "Theme Changed",
        Content = "Theme set to " .. themeName .. ". Please re-execute the script manually to see changes.",
        Duration = 4,
        Image = nil,
    })
end

function ThemeModule.UpdateCustomColor(component, r, g, b)
    ThemeModule.CustomRGB = {R = r, G = g, B = b}
    Rayfield:Notify({
        Title = "Custom Color",
        Content = "RGB set to (" .. r .. ", " .. g .. ", " .. b .. "). Re-execute script to apply custom theme.",
        Duration = 3,
        Image = nil,
    })
end

-- Check if a theme was previously selected
local selectedTheme = _G.RenDHubSelectedTheme or "Serenity"

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

-- Create UI Elements
local MainTab = Window:CreateTab("🏠 Main", nil)
local MainSection = MainTab:CreateSection("Main")

local MiscTab = Window:CreateTab("🔧 Misc", nil)
local AimbotSection = MiscTab:CreateSection("Aimbot")

local SettingsTab = Window:CreateTab("⚙️ Settings", nil)
local ThemeSection = SettingsTab:CreateSection("Theme Customization")

-- Show notification
Rayfield:Notify({
   Title = "RenD Hub",
   Content = "Script executed successfully",
   Duration = 6.5,
   Image = nil,
})

-- IMPROVED AIMBOT MODULE - 100% ACCURACY WITH PERFECT SMOOTHING
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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

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
    -- Enhanced player validation
    if not player or player == LocalPlayer then return false end
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
    
    for _, player in pairs(Players:GetPlayers()) do
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
                    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    
                    -- Check multiple points for better accuracy
                    local directions = {
                        (targetPart.Position - Camera.CFrame.Position).Unit,
                        (targetPart.Position + Vector3.new(0.5, 0, 0) - Camera.CFrame.Position).Unit,
                        (targetPart.Position + Vector3.new(-0.5, 0, 0) - Camera.CFrame.Position).Unit,
                        (targetPart.Position + Vector3.new(0, 0.5, 0) - Camera.CFrame.Position).Unit
                    }
                    
                    local validHit = false
                    for _, direction in pairs(directions) do
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
                spawn(function()
                    wait(3)
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

function AimbotModule.Disable()
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
    
    Rayfield:Notify({
        Title = "Aimbot",
        Content = "Disabled",
        Duration = 2,
        Image = nil,
    })
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

-- IMPROVED ESP MODULE - FIXED GUI COVERING AND BETTER VISIBILITY
local ESPModule = {}
ESPModule.Enabled = false
ESPModule.ESPObjects = {}
ESPModule.Connections = {}
ESPModule.ShowHealthBar = true
ESPModule.ShowDistance = true

function ESPModule.CreateESP(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    if player == LocalPlayer then return end
    
    -- Remove existing ESP first
    ESPModule.RemoveESP(player)
    
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
            
            -- Update health text
            if ESPModule.ShowHealthBar then
                healthLabel.Text = health .. "/" .. maxHealth
                
                -- Update health bar
                local healthPercent = health / maxHealth
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
                healthBar.Visible = false
                healthBarBG.Visible = false
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
    local distanceConnection
    
    if humanoid then
        healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(updateESP)
    end
    
    -- Update distance every second
    distanceConnection = spawn(function()
        while ESPModule.ESPObjects[player] and ESPModule.Enabled do
            updateESP()
            wait(0.5) -- Update distance twice per second
        end
    end)
    
    -- Store ESP objects for cleanup
    ESPModule.ESPObjects[player] = {
        highlight = highlight,
        billboard = billboard,
        healthConnection = healthConnection,
        distanceConnection = distanceConnection
    }
end

function ESPModule.RemoveESP(player)
    if ESPModule.ESPObjects[player] then
        if ESPModule.ESPObjects[player].highlight then
            ESPModule.ESPObjects[player].highlight:Destroy()
        end
        if ESPModule.ESPObjects[player].billboard then
            ESPModule.ESPObjects[player].billboard:Destroy()
        end
        if ESPModule.ESPObjects[player].healthConnection then
            ESPModule.ESPObjects[player].healthConnection:Disconnect()
        end
        ESPModule.ESPObjects[player] = nil
    end
end

function ESPModule.Enable()
    if ESPModule.Enabled then return end
    
    ESPModule.Enabled = true
    
    -- Add ESP to all current players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            spawn(function()
                wait(0.1)
                ESPModule.CreateESP(player)
            end)
        end
    end
    
    -- Connect to new players joining
    ESPModule.Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        if ESPModule.Enabled and player ~= LocalPlayer then
            if player.Character then
                ESPModule.CreateESP(player)
            else
                player.CharacterAdded:Connect(function()
                    wait(1)
                    if ESPModule.Enabled then
                        ESPModule.CreateESP(player)
                    end
                end)
            end
        end
    end)
    
    -- Connect to players leaving
    ESPModule.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        ESPModule.RemoveESP(player)
    end)
    
    -- Handle character respawning
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local connection = player.CharacterAdded:Connect(function()
                wait(1)
                if ESPModule.Enabled then
                    ESPModule.CreateESP(player)
                end
            end)
            ESPModule.Connections[player.Name .. "_CharacterAdded"] = connection
            
            local removingConnection = player.CharacterRemoving:Connect(function()
                ESPModule.RemoveESP(player)
            end)
            ESPModule.Connections[player.Name .. "_CharacterRemoving"] = removingConnection
        end
    end
    
    Rayfield:Notify({
        Title = "Improved ESP",
        Content = "Enabled - Better visibility and smaller GUI",
        Duration = 3,
        Image = nil,
    })
end

function ESPModule.Disable()
    if not ESPModule.Enabled then return end
    
    ESPModule.Enabled = false
    
    -- Remove ESP from all players
    for player, _ in pairs(ESPModule.ESPObjects) do
        ESPModule.RemoveESP(player)
    end
    
    -- Disconnect all connections
    for _, connection in pairs(ESPModule.Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    ESPModule.Connections = {}
    
    Rayfield:Notify({
        Title = "Improved ESP",
        Content = "Disabled",
        Duration = 2,
        Image = nil,
    })
end

function ESPModule.Toggle()
    if ESPModule.Enabled then
        ESPModule.Disable()
    else
        ESPModule.Enable()
    end
end

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

function InvisibilityModule.MakeVisible()
    if not InvisibilityModule.IsInvisible then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
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
    
    Rayfield:Notify({
        Title = "Invisibility",
        Content = "Disabled - You are now visible",
        Duration = 2,
        Image = nil,
    })
end

function InvisibilityModule.ToggleInvisibility()
    if InvisibilityModule.IsInvisible then
        InvisibilityModule.MakeVisible()
    else
        InvisibilityModule.MakeInvisible()
    end
end

-- FLY MODULE - Define at top level (OUTSIDE any button callbacks)
local FlyModule = {}
FlyModule.Flying = false
FlyModule.Speed = 50
FlyModule.bodyVelocity = nil
FlyModule.bodyAngularVelocity = nil

local flyConnection

-- Function to get current character and parts
local function getCharacterParts()
    local character = LocalPlayer.Character
    if not character then return nil, nil, nil end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return nil, nil, nil end
    
    return character, humanoid, rootPart
end

function FlyModule.StartFly()
    if FlyModule.Flying then return end
    
    local character, humanoid, rootPart = getCharacterParts()
    if not character or not humanoid or not rootPart then
        warn("Character not found or missing parts")
        return
    end
    
    FlyModule.Flying = true
    local camera = workspace.CurrentCamera
    
    -- Disable default character controls and physics
    humanoid.PlatformStand = true
    
    -- Create BodyVelocity to override gravity and physics
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = rootPart
    
    -- Create BodyAngularVelocity to prevent rotation
    local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    bodyAngularVelocity.Parent = rootPart
    
    flyConnection = RunService.RenderStepped:Connect(function(dt)
        -- Get move direction from input (WASD)
        local moveVector = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then 
            moveVector = moveVector + Vector3.new(0, 0, -1) 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then 
            moveVector = moveVector + Vector3.new(0, 0, 1) 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then 
            moveVector = moveVector + Vector3.new(-1, 0, 0) 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then 
            moveVector = moveVector + Vector3.new(1, 0, 0) 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then 
            moveVector = moveVector + Vector3.new(0, 1, 0) 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then 
            moveVector = moveVector + Vector3.new(0, -1, 0) 
        end
        
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit
            local moveWorld = camera.CFrame:VectorToWorldSpace(moveVector)
            bodyVelocity.Velocity = moveWorld * FlyModule.Speed
        else
            -- Stop moving when no keys are pressed
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
        
        -- Keep the character upright
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    end)
    
    -- Store body movers for cleanup
    FlyModule.bodyVelocity = bodyVelocity
    FlyModule.bodyAngularVelocity = bodyAngularVelocity
end

function FlyModule.StopFly()
    FlyModule.Flying = false
    
    -- Clean up body movers
    if FlyModule.bodyVelocity then
        FlyModule.bodyVelocity:Destroy()
        FlyModule.bodyVelocity = nil
    end
    if FlyModule.bodyAngularVelocity then
        FlyModule.bodyAngularVelocity:Destroy()
        FlyModule.bodyAngularVelocity = nil
    end
    
    -- Re-enable default character controls
    local character, humanoid, rootPart = getCharacterParts()
    if humanoid then
        humanoid.PlatformStand = false
    end
    
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
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

function ClickTeleportModule.Disable()
    if not ClickTeleportModule.Enabled then return end
    
    ClickTeleportModule.Enabled = false
    
    -- Properly disconnect the connection
    if ClickTeleportModule.Connection then
        ClickTeleportModule.Connection:Disconnect()
        ClickTeleportModule.Connection = nil
    end
    
    -- Notify user that click teleport is disabled
    Rayfield:Notify({
        Title = "Click Teleport",
        Content = "Disabled",
        Duration = 2,
        Image = nil,
    })
end

function ClickTeleportModule.Toggle()
    if ClickTeleportModule.Enabled then
        ClickTeleportModule.Disable()
    else
        ClickTeleportModule.Enable()
    end
end

-- PLAYER INTERACTION MODULE (Fixed with opposite facing and collision disable)
local PlayerInteractionModule = {}
PlayerInteractionModule.Enabled = false
PlayerInteractionModule.TargetPlayer = nil
PlayerInteractionModule.Mode = "Follow" -- "Follow", "Backpack", "Head"
PlayerInteractionModule.Distance = 5
PlayerInteractionModule.Connection = nil
PlayerInteractionModule.BodyVelocity = nil
PlayerInteractionModule.BodyPosition = nil
PlayerInteractionModule.BodyGyro = nil
PlayerInteractionModule.OriginalCanCollide = {}

function PlayerInteractionModule.FindTargetPlayer(username)
    -- Try exact match first
    local targetPlayer = Players:FindFirstChild(username)
    if targetPlayer then
        return targetPlayer
    end
    
    -- Try partial match
    for _, player in pairs(Players:GetPlayers()) do
        if string.lower(player.Name):find(string.lower(username)) then
            return player
        end
    end
    
    return nil
end

function PlayerInteractionModule.StartInteraction(username)
    if PlayerInteractionModule.Enabled then
        PlayerInteractionModule.StopInteraction()
    end
    
    local targetPlayer = PlayerInteractionModule.FindTargetPlayer(username)
    if not targetPlayer then
        Rayfield:Notify({
            Title = "Player Not Found",
            Content = "Could not find player: " .. username,
            Duration = 3,
            Image = nil,
        })
        return
    end
    
    if targetPlayer == LocalPlayer then
        Rayfield:Notify({
            Title = "Invalid Target",
            Content = "Cannot target yourself!",
            Duration = 2,
            Image = nil,
        })
        return
    end
    
    PlayerInteractionModule.Enabled = true
    PlayerInteractionModule.TargetPlayer = targetPlayer
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") or not character:FindFirstChild("HumanoidRootPart") then
        Rayfield:Notify({
            Title = "Character Error",
            Content = "Your character is not loaded!",
            Duration = 2,
            Image = nil,
        })
        return
    end
    
    local localRoot = character.HumanoidRootPart
    local localHumanoid = character.Humanoid
    
    if PlayerInteractionModule.Mode ~= "Follow" then
        -- Disable collision for Backpack and Head modes
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                PlayerInteractionModule.OriginalCanCollide[part] = part.CanCollide
                part.CanCollide = false
            end
        end
        
        -- Create BodyPosition for smooth positioning
        PlayerInteractionModule.BodyPosition = Instance.new("BodyPosition")
        PlayerInteractionModule.BodyPosition.MaxForce = Vector3.new(10000, 10000, 10000)
        PlayerInteractionModule.BodyPosition.P = 5000
        PlayerInteractionModule.BodyPosition.D = 1000
        PlayerInteractionModule.BodyPosition.Parent = localRoot
        
        -- Create BodyGyro for orientation control
        PlayerInteractionModule.BodyGyro = Instance.new("BodyGyro")
        PlayerInteractionModule.BodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
        PlayerInteractionModule.BodyGyro.P = 3000
        PlayerInteractionModule.BodyGyro.Parent = localRoot
        
        localHumanoid.PlatformStand = true
        localHumanoid.Sit = true
    else
        -- For Follow mode, create BodyVelocity for smooth horizontal following
        PlayerInteractionModule.BodyVelocity = Instance.new("BodyVelocity")
        PlayerInteractionModule.BodyVelocity.MaxForce = Vector3.new(4000, 0, 4000) -- Horizontal only
        PlayerInteractionModule.BodyVelocity.P = 1000
        PlayerInteractionModule.BodyVelocity.Parent = localRoot
    end
    
    PlayerInteractionModule.Connection = RunService.RenderStepped:Connect(function()
        PlayerInteractionModule.UpdateInteraction()
    end)
    
    Rayfield:Notify({
        Title = "Player Interaction",
        Content = "Started " .. PlayerInteractionModule.Mode .. " mode with " .. targetPlayer.Name,
        Duration = 3,
        Image = nil,
    })
end

function PlayerInteractionModule.UpdateInteraction()
    if not PlayerInteractionModule.Enabled or not PlayerInteractionModule.TargetPlayer then
        return
    end
    
    local targetPlayer = PlayerInteractionModule.TargetPlayer
    
    if not targetPlayer.Parent or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        PlayerInteractionModule.StopInteraction()
        return
    end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
        return
    end
    
    local targetRoot = targetPlayer.Character.HumanoidRootPart
    local localRoot = character.HumanoidRootPart
    local localHumanoid = character.Humanoid
    local targetHumanoid = targetPlayer.Character.Humanoid
    
    if PlayerInteractionModule.Mode == "Follow" then
        -- Smooth following with BodyVelocity
        local targetPosition = targetRoot.Position
        local targetDirection = targetRoot.CFrame.LookVector
        local followPosition = targetPosition - (targetDirection * PlayerInteractionModule.Distance)
        local velocity = (followPosition - localRoot.Position) * 20 -- Responsive speed
        velocity = Vector3.new(velocity.X, 0, velocity.Z)
        PlayerInteractionModule.BodyVelocity.Velocity = velocity
        
        -- Sync jump and sit
        localHumanoid.Jump = targetHumanoid.Jump
        localHumanoid.Sit = targetHumanoid.Sit
    elseif PlayerInteractionModule.Mode == "Backpack" then
        -- Back to back position, facing opposite
        local backOffset = targetRoot.CFrame.LookVector * -1.5 + Vector3.new(0, 0.5, 0)
        local targetPosition = targetRoot.Position + backOffset
        PlayerInteractionModule.BodyPosition.Position = targetPosition
        PlayerInteractionModule.BodyGyro.CFrame = CFrame.new(targetPosition, targetPosition - targetRoot.CFrame.LookVector) -- Face opposite
        
        -- Smooth camera
        local camera = workspace.CurrentCamera
        camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, targetRoot.Position + (-targetRoot.CFrame.LookVector)), 0.2)
        
        localHumanoid.Sit = true
    elseif PlayerInteractionModule.Mode == "Head" then
        -- Sit on head, facing opposite
        local headOffset = Vector3.new(0, 3, 0)
        local targetPosition = targetRoot.Position + headOffset
        PlayerInteractionModule.BodyPosition.Position = targetPosition
        PlayerInteractionModule.BodyGyro.CFrame = CFrame.new(targetPosition, targetPosition - targetRoot.CFrame.LookVector) -- Face opposite
        
        -- Smooth camera
        local camera = workspace.CurrentCamera
        camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, targetRoot.Position + (-targetRoot.CFrame.LookVector)), 0.2)
        
        localHumanoid.Sit = true
    end
end

function PlayerInteractionModule.StopInteraction()
    if not PlayerInteractionModule.Enabled then return end
    
    PlayerInteractionModule.Enabled = false
    PlayerInteractionModule.TargetPlayer = nil
    
    if PlayerInteractionModule.Connection then
        PlayerInteractionModule.Connection:Disconnect()
        PlayerInteractionModule.Connection = nil
    end
    if PlayerInteractionModule.BodyVelocity then
        PlayerInteractionModule.BodyVelocity:Destroy()
        PlayerInteractionModule.BodyVelocity = nil
    end
    if PlayerInteractionModule.BodyPosition then
        PlayerInteractionModule.BodyPosition:Destroy()
        PlayerInteractionModule.BodyPosition = nil
    end
    if PlayerInteractionModule.BodyGyro then
        PlayerInteractionModule.BodyGyro:Destroy()
        PlayerInteractionModule.BodyGyro = nil
    end
    
    -- Restore collision
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        local humanoid = character.Humanoid
        humanoid.PlatformStand = false
        humanoid.Sit = false
    end
    for part, canCollide in pairs(PlayerInteractionModule.OriginalCanCollide) do
        if part and part.Parent then
            part.CanCollide = canCollide
        end
    end
    PlayerInteractionModule.OriginalCanCollide = {}
    
    -- Restore camera
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    
    Rayfield:Notify({
        Title = "Player Interaction",
        Content = "Stopped interaction",
        Duration = 2,
        Image = nil,
    })
end

function PlayerInteractionModule.SetMode(mode)
    PlayerInteractionModule.Mode = mode
    if PlayerInteractionModule.Enabled then
        Rayfield:Notify({
            Title = "Mode Changed",
            Content = "Switched to " .. mode .. " mode",
            Duration = 2,
            Image = nil,
        })
    end
end

function PlayerInteractionModule.SetDistance(distance)
    PlayerInteractionModule.Distance = distance
end

-- NOCLIP MODULE
local NoClipModule = {}
NoClipModule.Enabled = false
NoClipModule.Connection = nil

function NoClipModule.Enable()
    if NoClipModule.Enabled then return end
    
    NoClipModule.Enabled = true
    local character = LocalPlayer.Character
    if not character then return end
    
    -- Disable collision for all parts
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    
    -- Keep disabling collision in case new parts are added
    NoClipModule.Connection = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

function NoClipModule.Disable()
    if not NoClipModule.Enabled then return end
    
    NoClipModule.Enabled = false
    
    -- Disconnect the connection
    if NoClipModule.Connection then
        NoClipModule.Connection:Disconnect()
        NoClipModule.Connection = nil
    end
    
    -- Re-enable collision for all parts
    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        
        -- Make sure HumanoidRootPart collision stays disabled (it should be by default)
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CanCollide = false
        end
    end
end

function NoClipModule.Toggle()
    if NoClipModule.Enabled then
        NoClipModule.Disable()
    else
        NoClipModule.Enable()
    end
end

-- UI ELEMENTS - All at the same level

-- Player Teleport Input
local Input = MainTab:CreateInput({
   Name = "Player Teleport",
   CurrentValue = "",
   PlaceholderText = "Player username",
   RemoveTextAfterFocusLost = false,
   Flag = "Input1",
   Callback = function(Text)
       local pl = LocalPlayer.Character.HumanoidRootPart
       local pl2 = Text
       local humanoid = LocalPlayer.Character.Humanoid
       humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
       wait(0.1)
       pl.CFrame = Players[pl2].Character.HumanoidRootPart.CFrame
   end,
})

-- Fly Speed Slider
local FlySpeedSlider = MainTab:CreateSlider({
   Name = "Fly Speed",
   Range = {10, 200},
   Increment = 10,
   Suffix = "Speed",
   CurrentValue = 50,
   Flag = "FlySpeedSlider",
   Callback = function(Value)
       FlyModule.Speed = Value
   end,
})

-- Movement Speed Slider
local MovementSpeedSlider = MainTab:CreateSlider({
   Name = "Movement Speed",
   Range = {5, 100},
   Increment = 1,
   Suffix = "Speed",
   CurrentValue = 16,
   Flag = "MovementSpeedSlider",
   Callback = function(Value)
       local character = LocalPlayer.Character
       if character and character:FindFirstChild("Humanoid") then
           character.Humanoid.WalkSpeed = Value
       end
   end,
})

-- Jump Power Slider
local JumpPowerSlider = MainTab:CreateSlider({
   Name = "Jump Power",
   Range = {10, 200},
   Increment = 5,
   Suffix = "Power",
   CurrentValue = 50,
   Flag = "JumpPowerSlider",
   Callback = function(Value)
       local character = LocalPlayer.Character
       if character and character:FindFirstChild("Humanoid") then
           character.Humanoid.JumpPower = Value
       end
   end,
})

-- PLAYER INTERACTION SECTION
local PlayerInteractionSection = MainTab:CreateSection("Player Interaction")

-- Target Player Input
local TargetPlayerInput = MainTab:CreateInput({
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
local InteractionModeDropdown = MainTab:CreateDropdown({
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
local FollowDistanceSlider = MainTab:CreateSlider({
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
local StartInteractionButton = MainTab:CreateButton({
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
local StopInteractionButton = MainTab:CreateButton({
   Name = "Stop Interaction",
   Callback = function()
       PlayerInteractionModule.StopInteraction()
   end,
})

-- Noclip Button
local NoclipButton = MainTab:CreateButton({
   Name = "Noclip Toggle",
   Callback = function()
       NoClipModule.Toggle()
   end,
})

-- Invisibility Button
local InvisibilityButton = MainTab:CreateButton({
   Name = "Invisibility Toggle",
   Callback = function()
       InvisibilityModule.ToggleInvisibility()
   end,
})

-- Click Teleport Button - FIXED
local ClickTeleportButton = MainTab:CreateButton({
   Name = "Click Teleport Toggle",
   Callback = function()
       ClickTeleportModule.Toggle()
   end,
})

-- ESP Button
local ESPButton = MainTab:CreateButton({
   Name = "ESP Toggle",
   Callback = function()
       ESPModule.Toggle()
   end,
})

-- Fly Button (NOT nested inside another button!)
local FlyButton = MainTab:CreateButton({
   Name = "Fly Toggle",
   Callback = function()
       FlyModule.ToggleFly()
   end,
})

-- AIMBOT UI ELEMENTS (Misc Tab)

-- FOV Radius Slider
local FOVSlider = MiscTab:CreateSlider({
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
local AimbotSmoothnessSlider = MiscTab:CreateSlider({
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
local AimPartDropdown = MiscTab:CreateDropdown({
   Name = "Aim Target",
   Options = {"Head", "HumanoidRootPart", "UpperTorso"},
   CurrentOption = {"Head"},
   MultipleOptions = false,
   Flag = "AimPart",
   Callback = function(Option)
       AimbotModule.SetAimPart(Option[1])
   end,
})

-- Aimbot Toggle Button
local AimbotToggleButton = MiscTab:CreateButton({
   Name = "Aimbot Toggle",
   Callback = function()
       AimbotModule.Toggle()
   end,
})

-- ESP Options Section
local ESPOptionsSection = MiscTab:CreateSection("ESP Options")

-- ESP Health Bar Toggle
local ESPHealthBarToggle = MiscTab:CreateToggle({
   Name = "Show Health Bar",
   CurrentValue = true,
   Flag = "ESPHealthBar",
   Callback = function(Value)
       ESPModule.ShowHealthBar = Value
   end,
})

-- ESP Distance Toggle
local ESPDistanceToggle = MiscTab:CreateToggle({
   Name = "Show Distance",
   CurrentValue = true,
   Flag = "ESPDistance",
   Callback = function(Value)
       ESPModule.ShowDistance = Value
   end,
})

-- Aimbot Instructions
local AimbotInstructions = MiscTab:CreateParagraph({
   Title = "Aimbot Instructions",
   Content = "1. Enable aimbot with the toggle button\n2. Adjust FOV radius and smoothness\n3. Choose aim target (Head/Body/Torso)\n4. Press 'X' to manually unlock/lock targets\n5. Auto-lock finds closest targets automatically"
})

-- ESP Instructions
local ESPInstructions = MiscTab:CreateParagraph({
   Title = "ESP Instructions",
   Content = "1. Toggle ESP to highlight all players\n2. Health bars show current/max HP with color coding\n3. Distance shows how far players are from you\n4. Smaller GUI for better visibility\n5. Works through walls and obstacles"
})

-- SETTINGS TAB UI ELEMENTS

-- Theme Preset Dropdown
local ThemeDropdown = SettingsTab:CreateDropdown({
   Name = "Theme Presets",
   Options = {"Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity"},
   CurrentOption = {"Default"},
   MultipleOptions = false,
   Flag = "ThemeDropdown",
   Callback = function(Option)
       ThemeModule.ApplyPresetTheme(Option[1])
   end,
})

-- Custom RGB Section
local CustomColorSection = SettingsTab:CreateSection("Custom RGB Colors")

-- Red Input
local RedInput = SettingsTab:CreateInput({
   Name = "Red Value (0-255)",
   CurrentValue = "25",
   PlaceholderText = "Enter red value",
   RemoveTextAfterFocusLost = false,
   Flag = "RedInput",
   Callback = function(Text)
       local r = tonumber(Text)
       if r and r >= 0 and r <= 255 then
           ThemeModule.CustomRGB.R = r
           ThemeModule.UpdateCustomColor("Background", ThemeModule.CustomRGB.R, ThemeModule.CustomRGB.G, ThemeModule.CustomRGB.B)
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
   CurrentValue = "25",
   PlaceholderText = "Enter green value",
   RemoveTextAfterFocusLost = false,
   Flag = "GreenInput",
   Callback = function(Text)
       local g = tonumber(Text)
       if g and g >= 0 and g <= 255 then
           ThemeModule.CustomRGB.G = g
           ThemeModule.UpdateCustomColor("Background", ThemeModule.CustomRGB.R, ThemeModule.CustomRGB.G, ThemeModule.CustomRGB.B)
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
   CurrentValue = "25",
   PlaceholderText = "Enter blue value",
   RemoveTextAfterFocusLost = false,
   Flag = "BlueInput",
   Callback = function(Text)
       local b = tonumber(Text)
       if b and b >= 0 and b <= 255 then
           ThemeModule.CustomRGB.B = b
           ThemeModule.UpdateCustomColor("Background", ThemeModule.CustomRGB.R, ThemeModule.CustomRGB.G, ThemeModule.CustomRGB.B)
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

-- Apply Custom Theme Button
local ApplyCustomThemeButton = SettingsTab:CreateButton({
   Name = "Preview Custom Colors",
   Callback = function()
       local r, g, b = ThemeModule.CustomRGB.R, ThemeModule.CustomRGB.G, ThemeModule.CustomRGB.B
       Rayfield:Notify({
           Title = "Custom Theme Preview",
           Content = "Current RGB: (" .. r .. ", " .. g .. ", " .. b .. ") - Restart script with custom theme to apply fully",
           Duration = 4,
           Image = nil,
       })
   end,
})

-- Feature Status Section
local FeatureStatusSection = SettingsTab:CreateSection("Feature Status")

-- Status Display
local StatusParagraph = SettingsTab:CreateParagraph({
   Title = "Current Status",
   Content = "Aimbot: Disabled\nESP: Disabled\nFly: Disabled\nInvisibility: Disabled\nNoclip: Disabled"
})

-- Update status function
local function updateStatus()
    local aimbotStatus = AimbotModule.Enabled and "Enabled" or "Disabled"
    local espStatus = ESPModule.Enabled and "Enabled" or "Disabled"
    local flyStatus = FlyModule.Flying and "Enabled" or "Disabled"
    local invisStatus = InvisibilityModule.IsInvisible and "Enabled" or "Disabled"
    local noclipStatus = NoClipModule.Enabled and "Enabled" or "Disabled"
    
    local targetInfo = ""
    if AimbotModule.Enabled and AimbotModule.TargetPlayer then
        targetInfo = "\nTarget: " .. AimbotModule.TargetPlayer.Name
    end
    
    StatusParagraph:Set({
        Title = "Current Status",
        Content = "Aimbot: " .. aimbotStatus .. targetInfo .. "\nESP: " .. espStatus .. "\nFly: " .. flyStatus .. "\nInvisibility: " .. invisStatus .. "\nNoclip: " .. noclipStatus
    })
end

-- Update status every 2 seconds
spawn(function()
    while true do
        updateStatus()
        wait(2)
    end
end)

-- Credits Section
local CreditsSection = SettingsTab:CreateSection("Credits & Info")

local CreditsParagraph = SettingsTab:CreateParagraph({
   Title = "RenD Hub v2.0 - Improved",
   Content = "Created by: SoLoIsTe_Cry\nImproved with:\n• 100% Accurate Aimbot\n• Fixed ESP (smaller GUI)\n• Working Invisibility\n• Better performance\n• Enhanced targeting system"
})

-- Keybinds Info
local KeybindsParagraph = SettingsTab:CreateParagraph({
   Title = "Keybinds",
   Content = "K - Toggle UI\nX - Manual Aimbot Lock/Unlock\nWASD - Fly Movement\nSpace/Ctrl - Fly Up/Down\nClick - Teleport (when enabled)"
})
end

startRenDHub()
