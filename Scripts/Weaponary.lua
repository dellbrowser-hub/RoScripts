print("Weaponary Script loaded , made by xsakyx for RenHub .")
print("For Devs : Everything is commented in the script to make understanding better .")
-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Ultimate Aimbot + ESP V2.0",
   LoadingTitle = "Loading Advanced Systems...",
   LoadingSubtitle = "Aimbot + ESP + Health Display",
   ConfigurationSaving = {Enabled = false},
   Discord = {Enabled = false},
   KeySystem = false,
})

-- Create Tabs
local MainTab = Window:CreateTab("🎯 Aimbot", 4483362458)
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)
local VisualsTab = Window:CreateTab("🎨 Visuals", 4483362458)
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
local DebugTab = Window:CreateTab("🔧 Debug", 4483362458)

-- ============================================
-- AIMBOT SETTINGS
-- ============================================

local AimbotSettings = {
    Enabled = false,
    FOVRadius = 150,
    Accuracy = 5,
    ShowFOV = true,
    TeamCheck = false,
    VisibilityCheck = false,
    TargetPart = "HitboxHead",
    Hotkey = Enum.KeyCode.X,
    IgnoreDeadPlayers = true, -- ANTI-DEATH DETECTION (Always enabled)
}

-- ============================================
-- ESP SETTINGS
-- ============================================

local ESPSettings = {
    Enabled = false,
    ShowBox = true,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    ShowHealthBar = true,
    ShowTracers = false,
    
    -- Colors
    BoxColor = Color3.fromRGB(255, 255, 255),
    NameColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    DistanceColor = Color3.fromRGB(200, 200, 200),
    TracerColor = Color3.fromRGB(255, 255, 255),
    
    -- Box settings
    BoxThickness = 2,
    BoxTransparency = 1,
    
    -- Text settings
    TextSize = 14,
    TextOutline = true,
    
    -- Advanced
    MaxDistance = 2000,
    TeamCheck = false,
}

-- ============================================
-- GLOBAL VARIABLES
-- ============================================

local CurrentTarget = nil
local FOVCircle = nil
local AimbotConnection = nil
local ESPObjects = {}
local ESPConnection = nil

-- Status Labels
local StatusLabel = MainTab:CreateLabel("Status: Disabled")
local TargetLabel = MainTab:CreateLabel("Target: None")
local HotkeyLabel = MainTab:CreateLabel("Hotkey: Press X to toggle")
local ESPStatusLabel = ESPTab:CreateLabel("ESP Status: Disabled")
local ESPCountLabel = ESPTab:CreateLabel("Tracking: 0 players")

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function safeCall(func, errorContext)
    local success, err = pcall(func)
    if not success then
        warn("[ERROR] " .. (errorContext or "Unknown") .. ": " .. tostring(err))
    end
    return success
end

local function isAlive(player)
    if not player or not player.Character then
        return false
    end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return false
    end
    
    -- Check if player is dead
    if humanoid.Health <= 0 then
        return false
    end
    
    -- Check if humanoid died
    if humanoid:GetState() == Enum.HumanoidStateType.Dead then
        return false
    end
    
    return true
end

local function getHealth(player)
    if not player or not player.Character then
        return 0, 100
    end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return 0, 100
    end
    
    return humanoid.Health, humanoid.MaxHealth
end

local function getHealthPercentage(player)
    local health, maxHealth = getHealth(player)
    if maxHealth == 0 then
        return 0
    end
    return (health / maxHealth) * 100
end

local function getHealthColor(percentage)
    if percentage > 75 then
        return Color3.fromRGB(0, 255, 0) -- Green
    elseif percentage > 50 then
        return Color3.fromRGB(255, 255, 0) -- Yellow
    elseif percentage > 25 then
        return Color3.fromRGB(255, 165, 0) -- Orange
    else
        return Color3.fromRGB(255, 0, 0) -- Red
    end
end

-- ============================================
-- FOV CIRCLE
-- ============================================

local function createFOVCircle()
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 2
    FOVCircle.NumSides = 64
    FOVCircle.Radius = AimbotSettings.FOVRadius
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Transparency = 1
    FOVCircle.Visible = AimbotSettings.ShowFOV
    FOVCircle.Filled = false
end

local function updateFOVCircle()
    if FOVCircle then
        local ViewportSize = Camera.ViewportSize
        FOVCircle.Position = Vector2.new(ViewportSize.X / 2, ViewportSize.Y / 2)
        FOVCircle.Radius = AimbotSettings.FOVRadius
        FOVCircle.Visible = AimbotSettings.ShowFOV
    end
end

-- ============================================
-- PLAYER DETECTION
-- ============================================

local function getPlayerFromHitbox(hitboxFolder)
    if #hitboxFolder:GetChildren() == 0 then
        return nil
    end
    
    local userId = hitboxFolder.Name
    
    for _, player in ipairs(Players:GetPlayers()) do
        if tostring(player.UserId) == userId then
            return player
        end
    end
    
    return nil
end

local function getAllTargets()
    local targets = {}
    
    local hitboxesFolder = Workspace:FindFirstChild("Hitboxes")
    if not hitboxesFolder then
        return targets
    end
    
    for _, hitboxFolder in ipairs(hitboxesFolder:GetChildren()) do
        if hitboxFolder:IsA("Folder") then
            if #hitboxFolder:GetChildren() > 0 then
                local player = getPlayerFromHitbox(hitboxFolder)
                
                if player and player ~= LocalPlayer then
                    -- ANTI-DEATH DETECTION: Skip dead players
                    if AimbotSettings.IgnoreDeadPlayers and not isAlive(player) then
                        continue
                    end
                    
                    -- Team check
                    if AimbotSettings.TeamCheck and player.Team == LocalPlayer.Team then
                        continue
                    end
                    
                    local head = hitboxFolder:FindFirstChild(AimbotSettings.TargetPart)
                    
                    if head then
                        table.insert(targets, {
                            Player = player,
                            Head = head,
                            HitboxFolder = hitboxFolder
                        })
                    end
                end
            end
        end
    end
    
    return targets
end

-- ============================================
-- AIMING LOGIC
-- ============================================

local function getScreenPosition(part)
    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function getDistanceFromCenter(screenPos)
    local ViewportSize = Camera.ViewportSize
    local center = Vector2.new(ViewportSize.X / 2, ViewportSize.Y / 2)
    return (screenPos - center).Magnitude
end

local function isInFOV(screenPos)
    local distance = getDistanceFromCenter(screenPos)
    return distance <= AimbotSettings.FOVRadius
end

local function isVisible(head)
    if not AimbotSettings.VisibilityCheck then
        return true
    end
    
    local character = LocalPlayer.Character
    if not character then
        return false
    end
    
    local origin = Camera.CFrame.Position
    local targetPos = head.Position
    local direction = (targetPos - origin).Unit * (targetPos - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    
    local filterList = {character}
    
    local hitboxesFolder = Workspace:FindFirstChild("Hitboxes")
    if hitboxesFolder then
        table.insert(filterList, hitboxesFolder)
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterList, player.Character)
        end
    end
    
    raycastParams.FilterDescendantsInstances = filterList
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    
    if not raycastResult then
        return true
    end
    
    local hitPart = raycastResult.Instance
    
    if hitPart.Transparency >= 0.9 then
        return true
    end
    
    if not hitPart.CanCollide then
        return true
    end
    
    return false
end

local function getClosestTarget()
    local targets = getAllTargets()
    local closestTarget = nil
    local shortestDistance = math.huge
    
    for _, target in ipairs(targets) do
        local screenPos, onScreen, depth = getScreenPosition(target.Head)
        
        if onScreen and depth > 0 then
            if isInFOV(screenPos) then
                if isVisible(target.Head) then
                    local distance = getDistanceFromCenter(screenPos)
                    
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestTarget = target
                    end
                end
            end
        end
    end
    
    return closestTarget
end

local function aimAtTarget(target)
    if not target or not target.Head then
        return
    end
    
    -- Double check if player is still alive before aiming
    if not isAlive(target.Player) then
        return
    end
    
    local head = target.Head
    
    local targetPos = head.Position
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
    
    local smoothness = (11 - AimbotSettings.Accuracy) / 10
    local newCFrame = currentCFrame:Lerp(targetCFrame, smoothness)
    
    Camera.CFrame = newCFrame
end

-- ============================================
-- ESP SYSTEM
-- ============================================

local function createESPForPlayer(player)
    if ESPObjects[player] then
        return
    end
    
    local espData = {
        Player = player,
        Drawings = {},
    }
    
    -- Box
    local box = Drawing.new("Square")
    box.Thickness = ESPSettings.BoxThickness
    box.Transparency = ESPSettings.BoxTransparency
    box.Color = ESPSettings.BoxColor
    box.Filled = false
    box.Visible = false
    espData.Drawings.Box = box
    
    -- Name
    local name = Drawing.new("Text")
    name.Text = player.Name
    name.Size = ESPSettings.TextSize
    name.Color = ESPSettings.NameColor
    name.Center = true
    name.Outline = ESPSettings.TextOutline
    name.Visible = false
    espData.Drawings.Name = name
    
    -- Health Text
    local healthText = Drawing.new("Text")
    healthText.Text = "100 HP"
    healthText.Size = ESPSettings.TextSize
    healthText.Color = ESPSettings.HealthColor
    healthText.Center = true
    healthText.Outline = ESPSettings.TextOutline
    healthText.Visible = false
    espData.Drawings.HealthText = healthText
    
    -- Health Bar Background
    local healthBarBG = Drawing.new("Square")
    healthBarBG.Thickness = 1
    healthBarBG.Transparency = 1
    healthBarBG.Color = Color3.fromRGB(0, 0, 0)
    healthBarBG.Filled = true
    healthBarBG.Visible = false
    espData.Drawings.HealthBarBG = healthBarBG
    
    -- Health Bar
    local healthBar = Drawing.new("Square")
    healthBar.Thickness = 1
    healthBar.Transparency = 1
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Filled = true
    healthBar.Visible = false
    espData.Drawings.HealthBar = healthBar
    
    -- Distance
    local distance = Drawing.new("Text")
    distance.Text = "0m"
    distance.Size = ESPSettings.TextSize
    distance.Color = ESPSettings.DistanceColor
    distance.Center = true
    distance.Outline = ESPSettings.TextOutline
    distance.Visible = false
    espData.Drawings.Distance = distance
    
    -- Tracer
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Transparency = 1
    tracer.Color = ESPSettings.TracerColor
    tracer.Visible = false
    espData.Drawings.Tracer = tracer
    
    ESPObjects[player] = espData
end

local function removeESPForPlayer(player)
    if not ESPObjects[player] then
        return
    end
    
    local espData = ESPObjects[player]
    
    for _, drawing in pairs(espData.Drawings) do
        drawing:Remove()
    end
    
    ESPObjects[player] = nil
end

local function updateESP()
    if not ESPSettings.Enabled then
        for player, espData in pairs(ESPObjects) do
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
        end
        return
    end
    
    local trackedCount = 0
    
    for player, espData in pairs(ESPObjects) do
        -- Check if player is valid and alive
        if not player or not player.Parent or not isAlive(player) then
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        -- Team check
        if ESPSettings.TeamCheck and player.Team == LocalPlayer.Team then
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local character = player.Character
        if not character then
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        -- Distance check
        local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
        if distance > ESPSettings.MaxDistance then
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        trackedCount = trackedCount + 1
        
        -- Get screen position
        local headPos = character:FindFirstChild("Head")
        if not headPos then
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(headPos.Position)
        local rootScreenPos = Camera:WorldToViewportPoint(rootPart.Position)
        
        if not onScreen then
            for _, drawing in pairs(espData.Drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        -- Calculate box size
        local head = character:FindFirstChild("Head")
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        
        if head and torso then
            local headPos2D = Camera:WorldToViewportPoint(head.Position)
            local torsoPos2D = Camera:WorldToViewportPoint(torso.Position)
            
            local height = math.abs(headPos2D.Y - torsoPos2D.Y) * 2.5
            local width = height / 2
            
            -- Update Box
            if ESPSettings.ShowBox then
                espData.Drawings.Box.Size = Vector2.new(width, height)
                espData.Drawings.Box.Position = Vector2.new(screenPos.X - width/2, screenPos.Y - height/2)
                espData.Drawings.Box.Color = ESPSettings.BoxColor
                espData.Drawings.Box.Thickness = ESPSettings.BoxThickness
                espData.Drawings.Box.Visible = true
            else
                espData.Drawings.Box.Visible = false
            end
            
            -- Update Name
            if ESPSettings.ShowName then
                espData.Drawings.Name.Position = Vector2.new(screenPos.X, screenPos.Y - height/2 - 15)
                espData.Drawings.Name.Text = player.Name
                espData.Drawings.Name.Color = ESPSettings.NameColor
                espData.Drawings.Name.Size = ESPSettings.TextSize
                espData.Drawings.Name.Visible = true
            else
                espData.Drawings.Name.Visible = false
            end
            
            -- Update Health
            local health, maxHealth = getHealth(player)
            local healthPercentage = getHealthPercentage(player)
            
            if ESPSettings.ShowHealth then
                espData.Drawings.HealthText.Position = Vector2.new(screenPos.X, screenPos.Y - height/2 - 30)
                espData.Drawings.HealthText.Text = string.format("%d/%d HP", math.floor(health), math.floor(maxHealth))
                espData.Drawings.HealthText.Color = getHealthColor(healthPercentage)
                espData.Drawings.HealthText.Size = ESPSettings.TextSize
                espData.Drawings.HealthText.Visible = true
            else
                espData.Drawings.HealthText.Visible = false
            end
            
            -- Update Health Bar
            if ESPSettings.ShowHealthBar then
                local barWidth = width
                local barHeight = 4
                local barX = screenPos.X - width/2
                local barY = screenPos.Y + height/2 + 2
                
                -- Background
                espData.Drawings.HealthBarBG.Size = Vector2.new(barWidth, barHeight)
                espData.Drawings.HealthBarBG.Position = Vector2.new(barX, barY)
                espData.Drawings.HealthBarBG.Visible = true
                
                -- Health bar
                local healthWidth = barWidth * (healthPercentage / 100)
                espData.Drawings.HealthBar.Size = Vector2.new(healthWidth, barHeight)
                espData.Drawings.HealthBar.Position = Vector2.new(barX, barY)
                espData.Drawings.HealthBar.Color = getHealthColor(healthPercentage)
                espData.Drawings.HealthBar.Visible = true
            else
                espData.Drawings.HealthBarBG.Visible = false
                espData.Drawings.HealthBar.Visible = false
            end
            
            -- Update Distance
            if ESPSettings.ShowDistance then
                espData.Drawings.Distance.Position = Vector2.new(screenPos.X, screenPos.Y + height/2 + 10)
                espData.Drawings.Distance.Text = string.format("%dm", math.floor(distance))
                espData.Drawings.Distance.Color = ESPSettings.DistanceColor
                espData.Drawings.Distance.Size = ESPSettings.TextSize
                espData.Drawings.Distance.Visible = true
            else
                espData.Drawings.Distance.Visible = false
            end
            
            -- Update Tracer
            if ESPSettings.ShowTracers then
                local ViewportSize = Camera.ViewportSize
                espData.Drawings.Tracer.From = Vector2.new(ViewportSize.X / 2, ViewportSize.Y)
                espData.Drawings.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                espData.Drawings.Tracer.Color = ESPSettings.TracerColor
                espData.Drawings.Tracer.Visible = true
            else
                espData.Drawings.Tracer.Visible = false
            end
        end
    end
    
    ESPCountLabel:Set("Tracking: " .. trackedCount .. " players")
end

-- ============================================
-- AIMBOT LOOP
-- ============================================

local function startAimbot()
    if AimbotConnection then
        AimbotConnection:Disconnect()
    end
    
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if not AimbotSettings.Enabled then
            return
        end
        
        updateFOVCircle()
        
        local target = getClosestTarget()
        CurrentTarget = target
        
        if target then
            -- Final anti-death check before aiming
            if isAlive(target.Player) then
                TargetLabel:Set("Target: " .. target.Player.Name)
                aimAtTarget(target)
            else
                TargetLabel:Set("Target: None (Dead)")
            end
        else
            TargetLabel:Set("Target: None in FOV")
        end
    end)
end

local function stopAimbot()
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
    
    CurrentTarget = nil
    TargetLabel:Set("Target: None")
end

local function startESP()
    if ESPConnection then
        ESPConnection:Disconnect()
    end
    
    -- Create ESP for all current players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createESPForPlayer(player)
        end
    end
    
    -- Update ESP every frame
    ESPConnection = RunService.RenderStepped:Connect(function()
        if ESPSettings.Enabled then
            updateESP()
        end
    end)
end

local function stopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    
    -- Hide all ESP
    for player, espData in pairs(ESPObjects) do
        for _, drawing in pairs(espData.Drawings) do
            drawing.Visible = false
        end
    end
end

-- ============================================
-- TOGGLE FUNCTIONS
-- ============================================

local function toggleAimbot()
    AimbotSettings.Enabled = not AimbotSettings.Enabled
    
    if AimbotSettings.Enabled then
        StatusLabel:Set("Status: 🟢 ACTIVE (Anti-Death ON)")
        startAimbot()
        
        print("🎯 Aimbot ENABLED")
        print("   ✅ Anti-Death Detection: ACTIVE")
        
        Rayfield:Notify({
           Title = "Aimbot Enabled",
           Content = "Locking targets (ignoring dead players)",
           Duration = 2,
           Image = 4483362458,
        })
    else
        StatusLabel:Set("Status: 🔴 Disabled")
        stopAimbot()
        
        print("🎯 Aimbot DISABLED")
        
        Rayfield:Notify({
           Title = "Aimbot Disabled",
           Content = "Aimbot is now off",
           Duration = 2,
           Image = 4483362458,
        })
    end
end

-- ============================================
-- HOTKEY SYSTEM
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == AimbotSettings.Hotkey then
        toggleAimbot()
    end
end)

-- ============================================
-- PLAYER EVENTS
-- ============================================

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createESPForPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESPForPlayer(player)
end)

-- ============================================
-- GUI: MAIN TAB (AIMBOT)
-- ============================================

MainTab:CreateSection("🎯 Aimbot Controls")

MainTab:CreateParagraph({
   Title = "Anti-Death Protection",
   Content = "✅ Built-in! Aimbot automatically ignores dead players. No need to toggle - always active for your safety."
})

local AimbotToggle = MainTab:CreateToggle({
   Name = "Enable Aimbot",
   CurrentValue = false,
   Flag = "AimbotEnabled",
   Callback = function(Value)
      AimbotSettings.Enabled = Value
      
      if Value then
         StatusLabel:Set("Status: 🟢 ACTIVE (Anti-Death ON)")
         startAimbot()
      else
         StatusLabel:Set("Status: 🔴 Disabled")
         stopAimbot()
      end
   end,
})

MainTab:CreateSection("⚙️ Aimbot Settings")

MainTab:CreateSlider({
   Name = "FOV Radius",
   Range = {50, 500},
   Increment = 10,
   CurrentValue = 150,
   Flag = "FOVRadius",
   Callback = function(Value)
      AimbotSettings.FOVRadius = Value
      
      if FOVCircle then
         FOVCircle.Radius = Value
      end
   end,
})

MainTab:CreateSlider({
   Name = "Accuracy (Speed)",
   Range = {1, 10},
   Increment = 1,
   CurrentValue = 5,
   Flag = "Accuracy",
   Callback = function(Value)
      AimbotSettings.Accuracy = Value
   end,
})

MainTab:CreateParagraph({
   Title = "Accuracy Guide",
   Content = "1-3: Smooth & Slow (Legit)\n4-6: Balanced (Recommended)\n7-10: Fast & Snappy (Rage)"
})

-- ============================================
-- GUI: ESP TAB
-- ============================================

ESPTab:CreateSection("👁️ ESP Controls")

local ESPToggle = ESPTab:CreateToggle({
   Name = "Enable ESP",
   CurrentValue = false,
   Flag = "ESPEnabled",
   Callback = function(Value)
      ESPSettings.Enabled = Value
      
      if Value then
         ESPStatusLabel:Set("ESP Status: 🟢 ACTIVE")
         startESP()
         
         Rayfield:Notify({
            Title = "ESP Enabled",
            Content = "Player information visible",
            Duration = 2,
            Image = 4483362458,
         })
      else
         ESPStatusLabel:Set("ESP Status: 🔴 Disabled")
         stopESP()
      end
   end,
})

ESPTab:CreateSection("📋 Display Options")

ESPTab:CreateToggle({
   Name = "Show Box",
   CurrentValue = true,
   Flag = "ShowBox",
   Callback = function(Value)
      ESPSettings.ShowBox = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Show Name",
   CurrentValue = true,
   Flag = "ShowName",
   Callback = function(Value)
      ESPSettings.ShowName = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Show Health",
   CurrentValue = true,
   Flag = "ShowHealth",
   Callback = function(Value)
      ESPSettings.ShowHealth = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Show Health Bar",
   CurrentValue = true,
   Flag = "ShowHealthBar",
   Callback = function(Value)
      ESPSettings.ShowHealthBar = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Show Distance",
   CurrentValue = true,
   Flag = "ShowDistance",
   Callback = function(Value)
      ESPSettings.ShowDistance = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Show Tracers",
   CurrentValue = false,
   Flag = "ShowTracers",
   Callback = function(Value)
      ESPSettings.ShowTracers = Value
   end,
})

ESPTab:CreateSection("⚙️ ESP Settings")

ESPTab:CreateSlider({
   Name = "Max Distance (meters)",
   Range = {100, 5000},
   Increment = 100,
   CurrentValue = 2000,
   Flag = "MaxDistance",
   Callback = function(Value)
      ESPSettings.MaxDistance = Value
   end,
})

ESPTab:CreateSlider({
   Name = "Text Size",
   Range = {10, 20},
   Increment = 1,
   CurrentValue = 14,
   Flag = "TextSize",
   Callback = function(Value)
      ESPSettings.TextSize = Value
   end,
})

ESPTab:CreateSlider({
   Name = "Box Thickness",
   Range = {1, 5},
   Increment = 1,
   CurrentValue = 2,
   Flag = "BoxThickness",
   Callback = function(Value)
      ESPSettings.BoxThickness = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Team Check (ESP)",
   CurrentValue = false,
   Flag = "ESPTeamCheck",
   Callback = function(Value)
      ESPSettings.TeamCheck = Value
   end,
})

-- ============================================
-- GUI: VISUALS TAB
-- ============================================

VisualsTab:CreateSection("🎨 FOV Circle")

VisualsTab:CreateToggle({
   Name = "Show FOV Circle",
   CurrentValue = true,
   Flag = "ShowFOV",
   Callback = function(Value)
      AimbotSettings.ShowFOV = Value
      
      if FOVCircle then
         FOVCircle.Visible = Value
      end
   end,
})

VisualsTab:CreateColorPicker({
   Name = "FOV Circle Color",
   Color = Color3.fromRGB(255, 255, 255),
   Flag = "FOVColor",
   Callback = function(Value)
      if FOVCircle then
         FOVCircle.Color = Value
      end
   end,
})

VisualsTab:CreateSlider({
   Name = "FOV Circle Thickness",
   Range = {1, 5},
   Increment = 1,
   CurrentValue = 2,
   Flag = "FOVThickness",
   Callback = function(Value)
      if FOVCircle then
         FOVCircle.Thickness = Value
      end
   end,
})

VisualsTab:CreateToggle({
   Name = "Filled FOV Circle",
   CurrentValue = false,
   Flag = "FOVFilled",
   Callback = function(Value)
      if FOVCircle then
         FOVCircle.Filled = Value
         FOVCircle.Transparency = Value and 0.2 or 1
      end
   end,
})

VisualsTab:CreateSection("🎨 ESP Colors")

VisualsTab:CreateColorPicker({
   Name = "Box Color",
   Color = Color3.fromRGB(255, 255, 255),
   Flag = "BoxColor",
   Callback = function(Value)
      ESPSettings.BoxColor = Value
   end,
})

VisualsTab:CreateColorPicker({
   Name = "Name Color",
   Color = Color3.fromRGB(255, 255, 255),
   Flag = "NameColor",
   Callback = function(Value)
      ESPSettings.NameColor = Value
   end,
})

VisualsTab:CreateColorPicker({
   Name = "Distance Color",
   Color = Color3.fromRGB(200, 200, 200),
   Flag = "DistanceColor",
   Callback = function(Value)
      ESPSettings.DistanceColor = Value
   end,
})

VisualsTab:CreateColorPicker({
   Name = "Tracer Color",
   Color = Color3.fromRGB(255, 255, 255),
   Flag = "TracerColor",
   Callback = function(Value)
      ESPSettings.TracerColor = Value
   end,
})

VisualsTab:CreateParagraph({
   Title = "Health Bar Colors",
   Content = "Health bar automatically changes:\n• Green (>75%)\n• Yellow (50-75%)\n• Orange (25-50%)\n• Red (<25%)"
})

-- ============================================
-- GUI: SETTINGS TAB
-- ============================================

SettingsTab:CreateSection("🔧 Aimbot Advanced")

SettingsTab:CreateToggle({
   Name = "Team Check (Aimbot)",
   CurrentValue = false,
   Flag = "TeamCheck",
   Callback = function(Value)
      AimbotSettings.TeamCheck = Value
   end,
})

SettingsTab:CreateToggle({
   Name = "Visibility Check (Wall Check)",
   CurrentValue = false,
   Flag = "VisibilityCheck",
   Callback = function(Value)
      AimbotSettings.VisibilityCheck = Value
      
      if Value then
         Rayfield:Notify({
            Title = "Wall Check Enabled",
            Content = "Only targeting visible enemies",
            Duration = 2,
            Image = 4483362458,
         })
      end
   end,
})

SettingsTab:CreateParagraph({
   Title = "Visibility Check Info",
   Content = "When enabled, aimbot ignores targets behind walls. Hitboxes are properly filtered!\n\nRecommended: Keep OFF for maximum locks."
})

SettingsTab:CreateSection("🛡️ Anti-Death System")

SettingsTab:CreateParagraph({
   Title = "Anti-Death Protection",
   Content = "✅ ALWAYS ACTIVE\n\nThe aimbot automatically detects and ignores:\n• Dead players (0 HP)\n• Dying players\n• Respawning players\n\nThis prevents locking onto corpses and ensures you only target alive enemies."
})

SettingsTab:CreateSection("⌨️ Hotkey")

SettingsTab:CreateParagraph({
   Title = "Toggle Hotkey",
   Content = "Press X to quickly toggle aimbot on/off without opening the UI. This is much faster for quick enable/disable."
})

SettingsTab:CreateButton({
   Name = "Test Hotkey (Press X)",
   Callback = function()
      Rayfield:Notify({
         Title = "Hotkey Test",
         Content = "Press X to toggle aimbot",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

-- ============================================
-- GUI: DEBUG TAB
-- ============================================

DebugTab:CreateSection("🔍 Detection Tests")

DebugTab:CreateButton({
   Name = "Test Hitbox Detection",
   Callback = function()
      local hitboxesFolder = Workspace:FindFirstChild("Hitboxes")
      
      if not hitboxesFolder then
         print("❌ Hitboxes folder not found!")
         Rayfield:Notify({
            Title = "Error",
            Content = "Hitboxes folder not found!",
            Duration = 3,
            Image = 4483362458,
         })
         return
      end
      
      print("\n" .. string.rep("=", 60))
      print("🔍 HITBOX DETECTION TEST")
      print(string.rep("=", 60))
      
      local activeCount = 0
      local emptyCount = 0
      local deadCount = 0
      local aliveCount = 0
      
      for _, folder in ipairs(hitboxesFolder:GetChildren()) do
         if folder:IsA("Folder") then
            local childCount = #folder:GetChildren()
            
            if childCount > 0 then
               activeCount = activeCount + 1
               local player = getPlayerFromHitbox(folder)
               local head = folder:FindFirstChild("HitboxHead")
               local alive = player and isAlive(player)
               
               if alive then
                  aliveCount = aliveCount + 1
               else
                  deadCount = deadCount + 1
               end
               
               print(string.format("\n✅ Active Hitbox: %s", folder.Name))
               print(string.format("   Player: %s", player and player.Name or "Unknown"))
               print(string.format("   Status: %s", alive and "🟢 ALIVE" or "💀 DEAD"))
               print(string.format("   Children: %d", childCount))
               print(string.format("   Has Head: %s", head and "Yes" or "No"))
               
               if player and alive then
                  local health, maxHealth = getHealth(player)
                  print(string.format("   Health: %d/%d (%.1f%%)", 
                     math.floor(health), 
                     math.floor(maxHealth), 
                     getHealthPercentage(player)
                  ))
               end
            else
               emptyCount = emptyCount + 1
            end
         end
      end
      
      print(string.rep("=", 60))
      print(string.format("📊 Summary:"))
      print(string.format("   Total Active: %d", activeCount))
      print(string.format("   🟢 Alive: %d (will be targeted)", aliveCount))
      print(string.format("   💀 Dead: %d (will be ignored)", deadCount))
      print(string.format("   Empty Slots: %d", emptyCount))
      print(string.rep("=", 60) .. "\n")
      
      Rayfield:Notify({
         Title = "Detection Test",
         Content = string.format("%d alive, %d dead", aliveCount, deadCount),
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

DebugTab:CreateButton({
   Name = "Show Current Targets",
   Callback = function()
      local targets = getAllTargets()
      
      print("\n🎯 CURRENT VALID TARGETS:")
      for i, target in ipairs(targets) do
         local health, maxHealth = getHealth(target.Player)
         print(string.format("[%d] %s | HP: %d/%d | Status: 🟢 ALIVE", 
            i, 
            target.Player.Name,
            math.floor(health),
            math.floor(maxHealth)
         ))
      end
      print("Total: " .. #targets .. " targetable players\n")
      
      Rayfield:Notify({
         Title = "Valid Targets",
         Content = #targets .. " alive targets",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

DebugTab:CreateButton({
   Name = "Test Visibility System",
   Callback = function()
      local targets = getAllTargets()
      
      print("\n" .. string.rep("=", 60))
      print("👁️ VISIBILITY TEST")
      print(string.rep("=", 60))
      
      if #targets == 0 then
         print("❌ No valid targets found!")
      else
         for i, target in ipairs(targets) do
            local visible = isVisible(target.Head)
            local screenPos, onScreen = getScreenPosition(target.Head)
            local inFOV = isInFOV(screenPos)
            local alive = isAlive(target.Player)
            
            print(string.format("\n[%d] %s", i, target.Player.Name))
            print(string.format("   Alive: %s", alive and "✅ YES" or "❌ NO"))
            print(string.format("   Visible: %s", visible and "✅ YES" or "❌ NO"))
            print(string.format("   On Screen: %s", onScreen and "✅ YES" or "❌ NO"))
            print(string.format("   In FOV: %s", inFOV and "✅ YES" or "❌ NO"))
            print(string.format("   Would Lock: %s", (visible and onScreen and inFOV and alive) and "✅ YES" or "❌ NO"))
         end
      end
      
      print(string.rep("=", 60) .. "\n")
      
      Rayfield:Notify({
         Title = "Visibility Test",
         Content = "Results in console (F9)",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

DebugTab:CreateSection("📊 Statistics")

DebugTab:CreateButton({
   Name = "Show All Stats",
   Callback = function()
      print("\n📊 SYSTEM STATISTICS:")
      print("─────────────────────────────────────")
      print("AIMBOT:")
      print("   Enabled: " .. tostring(AimbotSettings.Enabled))
      print("   FOV Radius: " .. AimbotSettings.FOVRadius)
      print("   Accuracy: " .. AimbotSettings.Accuracy)
      print("   Anti-Death: ✅ ACTIVE (Always On)")
      print("   Show FOV: " .. tostring(AimbotSettings.ShowFOV))
      print("   Team Check: " .. tostring(AimbotSettings.TeamCheck))
      print("   Visibility Check: " .. tostring(AimbotSettings.VisibilityCheck))
      print("   Current Target: " .. (CurrentTarget and CurrentTarget.Player.Name or "None"))
      print("\nESP:")
      print("   Enabled: " .. tostring(ESPSettings.Enabled))
      print("   Show Box: " .. tostring(ESPSettings.ShowBox))
      print("   Show Name: " .. tostring(ESPSettings.ShowName))
      print("   Show Health: " .. tostring(ESPSettings.ShowHealth))
      print("   Show Health Bar: " .. tostring(ESPSettings.ShowHealthBar))
      print("   Show Distance: " .. tostring(ESPSettings.ShowDistance))
      print("   Show Tracers: " .. tostring(ESPSettings.ShowTracers))
      print("   Max Distance: " .. ESPSettings.MaxDistance .. "m")
      print("   Players Tracked: " .. #Players:GetPlayers() - 1)
      print("─────────────────────────────────────\n")
      
      Rayfield:Notify({
         Title = "Statistics",
         Content = "Full stats in console (F9)",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

DebugTab:CreateButton({
   Name = "Test ESP System",
   Callback = function()
      print("\n🎨 ESP SYSTEM TEST:")
      print("   Total ESP Objects: " .. #ESPObjects)
      
      local visibleCount = 0
      for player, espData in pairs(ESPObjects) do
         local anyVisible = false
         for _, drawing in pairs(espData.Drawings) do
            if drawing.Visible then
               anyVisible = true
               break
            end
         end
         if anyVisible then
            visibleCount = visibleCount + 1
         end
      end
      
      print("   Visible ESP: " .. visibleCount)
      print("   ESP Enabled: " .. tostring(ESPSettings.Enabled))
      
      Rayfield:Notify({
         Title = "ESP Test",
         Content = visibleCount .. " ESPs visible",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

DebugTab:CreateSection("🛠️ Performance")

DebugTab:CreateButton({
   Name = "Refresh All Systems",
   Callback = function()
      -- Refresh aimbot
      if AimbotSettings.Enabled then
         stopAimbot()
         task.wait(0.1)
         startAimbot()
      end
      
      -- Refresh ESP
      if ESPSettings.Enabled then
         stopESP()
         task.wait(0.1)
         startESP()
      end
      
      print("✅ All systems refreshed!")
      
      Rayfield:Notify({
         Title = "Refreshed",
         Content = "All systems restarted",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

-- ============================================
-- INITIALIZATION
-- ============================================

print("[INIT] Creating FOV Circle...")
createFOVCircle()

print("[INIT] Starting ESP system...")
startESP()

print("[INIT] Starting update loops...")
RunService.RenderStepped:Connect(function()
    updateFOVCircle()
end)

-- Initial notification
Rayfield:Notify({
   Title = "Ultimate Aimbot + ESP Loaded",
   Content = "Press X to toggle | Anti-Death: Always Active",
   Duration = 5,
   Image = 4483362458,
})

print("\n✅ Ultimate Aimbot + ESP V2.0 loaded successfully!")
print("\n📋 CONTROLS:")
print("   • Press X - Toggle aimbot on/off")
print("   • Open UI - Configure all settings")
print("\n⚙️ SETTINGS:")
print("   • FOV Radius: " .. AimbotSettings.FOVRadius)
print("   • Accuracy: " .. AimbotSettings.Accuracy)
print("   • Anti-Death: ✅ ALWAYS ACTIVE")
print("\n🎨 ESP FEATURES:")
print("   • Player Names")
print("   • Health Display (Text + Bar)")
print("   • Distance Indicators")
print("   • Box ESP")
print("   • Tracers")
print("   • Works Through Walls!")
print("\n💡 TIP: Enable ESP in ESP tab for full visibility!")
print("\n🎯 Target: workspace.Hitboxes[UserId].HitboxHead")
print("🔴 Status: Disabled (Press X to enable)")
print("\n🛡️ ANTI-DEATH PROTECTION: Built-in and always active!")
print("   Never locks onto dead players - guaranteed!")

StatusLabel:Set("Status: 🔴 Disabled - Press X to enable")
TargetLabel:Set("Target: None")
HotkeyLabel:Set("Hotkey: Press X to toggle instantly")
ESPStatusLabel:Set("ESP Status: 🔴 Disabled - Enable in ESP tab")
ESPCountLabel:Set("Tracking: 0 players")
