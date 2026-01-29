print("QcuikDraw script loaded , made by xsakyx for RenHub .")
print("For Devs : Only minor comments .")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ANALYZED FROM DECOMPILED CODE:
-- Line 79: Acceleration = Vector3.new(0, -workspace.Gravity / 5, 0)
-- This means bullet drop uses workspace.Gravity / 5
-- Game uses FastCast for realistic ballistics
-- Client-side raycasting with recoil

local CombatConfig = {
    -- BULLET PHYSICS (FROM DECOMPILED CODE)
    BulletSpeed = 1000,
    BulletGravity = workspace.Gravity / 5,
    
    -- AIMBOT SETTINGS (OPTIMIZED FOR SPEED)
    AimbotSmoothness = 0.5, -- FAST (0.1 = slow, 1 = instant)
    PredictionMultiplier = 0.13,
    MaxAimDistance = 500,
    
    -- FOV
    FOVSize = 200,
    
    -- ESP
    ESPColor = Color3.fromRGB(255, 0, 0),
    ESPMaxDistance = 1000,
}

local CombatSystem = {
    Aimbot = {
        Enabled = false,
        CurrentTarget = nil,
        FOVCircle = nil,
        IgnoreFriends = false,
        IgnoredPlayers = {},
        VisibilityCheck = true,
        TargetPart = "Head",
    },
    
    ESP = {
        Enabled = false,
        Objects = {},
        Connections = {},
        ShowNames = true,
        ShowDistance = true,
        ShowHealth = true,
    },
    
    Crosshair = {
        Enabled = false,
        Dynamic = true,
        Circle = nil,
        Dot = nil,
        PredictionDot = nil,
    },
    
    Blacklist = {
        Enabled = false,
        Players = {},
        Color = Color3.fromRGB(0, 255, 255),
    },
}

local DrawingLibrary = {}
DrawingLibrary.Objects = {}

function DrawingLibrary:New(type, props)
    local obj = Drawing.new(type)
    for prop, val in pairs(props or {}) do
        pcall(function() obj[prop] = val end)
    end
    table.insert(self.Objects, obj)
    return obj
end

function DrawingLibrary:Remove(obj)
    pcall(function() obj:Remove() end)
    for i, v in ipairs(self.Objects) do
        if v == obj then
            table.remove(self.Objects, i)
            break
        end
    end
end

function DrawingLibrary:Clear()
    for _, obj in ipairs(self.Objects) do
        pcall(function() obj:Remove() end)
    end
    self.Objects = {}
end

local function SafeCall(func)
    local success, err = pcall(func)
    if not success then
        warn("[Combat] Error:", err)
    end
    return success
end

local function WorldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function IsPlayerAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    return humanoid.Health > 0
end

local function GetPlayerPart(player, partName)
    if not IsPlayerAlive(player) then return nil end
    return player.Character:FindFirstChild(partName)
end

local function GetDistance(player)
    if not IsPlayerAlive(LocalPlayer) or not IsPlayerAlive(player) then return math.huge end
    
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local theirRoot = player.Character:FindFirstChild("HumanoidRootPart")
    
    if not myRoot or not theirRoot then return math.huge end
    
    return (myRoot.Position - theirRoot.Position).Magnitude
end

local function IsVisible(part)
    if not part then return false end
    
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, params)
    
    if not result then return true end
    
    return result.Instance:IsDescendantOf(part.Parent)
end

local function RGBtoHSV(color)
    local r, g, b = color.R, color.G, color.B
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min
    
    local h, s, v = 0, 0, max
    
    if delta > 0 then
        s = delta / max
        if max == r then
            h = ((g - b) / delta) % 6
        elseif max == g then
            h = ((b - r) / delta) + 2
        else
            h = ((r - g) / delta) + 4
        end
        h = h / 6
    end
    
    return h, s, v
end

local function HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs(((h * 6) % 2) - 1))
    local m = v - c
    
    local r, g, b = 0, 0, 0
    
    if h < 1/6 then
        r, g, b = c, x, 0
    elseif h < 2/6 then
        r, g, b = x, c, 0
    elseif h < 3/6 then
        r, g, b = 0, c, x
    elseif h < 4/6 then
        r, g, b = 0, x, c
    elseif h < 5/6 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    
    return Color3.new(r + m, g + m, b + m)
end

local function GetOppositeColor(color)
    local h, s, v = RGBtoHSV(color)
    h = (h + 0.5) % 1
    return HSVtoRGB(h, s, v)
end

local function UpdateBlacklistColor()
    CombatSystem.Blacklist.Color = GetOppositeColor(CombatConfig.ESPColor)
end

-- ============================================
-- BALLISTIC PREDICTION (FROM DECOMPILED CODE)
-- ============================================

local BallisticsEngine = {}

function BallisticsEngine.CalculateBulletDrop(distance)
    local timeToTarget = distance / CombatConfig.BulletSpeed
    local drop = 0.5 * CombatConfig.BulletGravity * (timeToTarget * timeToTarget)
    return drop
end

function BallisticsEngine.PredictTargetPosition(targetPart)
    if not targetPart then return nil end
    
    local currentPos = targetPart.Position
    local velocity = targetPart.AssemblyLinearVelocity or Vector3.zero
    
    -- Simple velocity-based prediction
    local predictedPos = currentPos + (velocity * CombatConfig.PredictionMultiplier)
    
    return predictedPos
end

function BallisticsEngine.CalculateAimPoint(targetPart)
    if not targetPart then return nil end
    
    -- Get predicted position
    local predictedPos = BallisticsEngine.PredictTargetPosition(targetPart)
    if not predictedPos then return nil end
    
    -- Calculate distance to predicted position
    local distance = (predictedPos - Camera.CFrame.Position).Magnitude
    
    -- Calculate bullet drop compensation
    local drop = BallisticsEngine.CalculateBulletDrop(distance)
    
    -- Add drop compensation (aim higher)
    local finalAimPoint = predictedPos + Vector3.new(0, drop, 0)
    
    return finalAimPoint
end

function BallisticsEngine.CalculateTrajectory(startPos, targetPos)
    local distance = (targetPos - startPos).Magnitude
    local timeToTarget = distance / CombatConfig.BulletSpeed
    
    local trajectoryPoints = {}
    local steps = 20
    
    for i = 0, steps do
        local t = (i / steps) * timeToTarget
        local horizontalProgress = t / timeToTarget
        
        local currentPos = startPos:Lerp(targetPos, horizontalProgress)
        
        local drop = 0.5 * CombatConfig.BulletGravity * (t * t)
        currentPos = currentPos - Vector3.new(0, drop, 0)
        
        table.insert(trajectoryPoints, currentPos)
    end
    
    return trajectoryPoints
end

-- ============================================
-- AIMBOT ENGINE
-- ============================================

local AimbotEngine = {}

function AimbotEngine.CreateFOVCircle()
    if CombatSystem.Aimbot.FOVCircle then
        DrawingLibrary:Remove(CombatSystem.Aimbot.FOVCircle)
    end
    
    CombatSystem.Aimbot.FOVCircle = DrawingLibrary:New("Circle", {
        Thickness = 2,
        NumSides = 100,
        Radius = CombatConfig.FOVSize,
        Filled = false,
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.5,
        Visible = false,
    })
end

function AimbotEngine.UpdateFOVCircle()
    if not CombatSystem.Aimbot.FOVCircle then return end
    
    local center = GetScreenCenter()
    CombatSystem.Aimbot.FOVCircle.Position = center
    CombatSystem.Aimbot.FOVCircle.Radius = CombatConfig.FOVSize
    CombatSystem.Aimbot.FOVCircle.Visible = CombatSystem.Aimbot.Enabled
end

function AimbotEngine.ShouldIgnore(player)
    if player == LocalPlayer then return true end
    
    if not IsPlayerAlive(player) then return true end
    
    if CombatSystem.Aimbot.IgnoreFriends and LocalPlayer:IsFriendsWith(player.UserId) then
        return true
    end
    
    if table.find(CombatSystem.Aimbot.IgnoredPlayers, player.Name) then
        return true
    end
    
    return false
end

function AimbotEngine.IsInFOV(player)
    local part = GetPlayerPart(player, CombatSystem.Aimbot.TargetPart)
    if not part then return false end
    
    local screenPos, onScreen = WorldToScreen(part.Position)
    if not onScreen then return false end
    
    local center = GetScreenCenter()
    local distance = (screenPos - center).Magnitude
    
    return distance <= CombatConfig.FOVSize
end

function AimbotEngine.GetClosestInFOV()
    local closest = nil
    local closestDist = math.huge
    local center = GetScreenCenter()
    
    for _, player in ipairs(Players:GetPlayers()) do
        if not AimbotEngine.ShouldIgnore(player) then
            -- Check if in FOV FIRST
            if AimbotEngine.IsInFOV(player) then
                local distance = GetDistance(player)
                
                if distance <= CombatConfig.MaxAimDistance then
                    -- Visibility check
                    if CombatSystem.Aimbot.VisibilityCheck then
                        local part = GetPlayerPart(player, CombatSystem.Aimbot.TargetPart)
                        if not IsVisible(part) then
                            continue
                        end
                    end
                    
                    -- Get screen distance from center
                    local part = GetPlayerPart(player, CombatSystem.Aimbot.TargetPart)
                    if part then
                        local screenPos, _ = WorldToScreen(part.Position)
                        local screenDist = (screenPos - center).Magnitude
                        
                        if screenDist < closestDist then
                            closestDist = screenDist
                            closest = player
                        end
                    end
                end
            end
        end
    end
    
    return closest
end

function AimbotEngine.AimAtTarget()
    if not CombatSystem.Aimbot.Enabled then
        CombatSystem.Aimbot.CurrentTarget = nil
        return
    end
    
    -- Get closest player in FOV
    CombatSystem.Aimbot.CurrentTarget = AimbotEngine.GetClosestInFOV()
    
    if CombatSystem.Aimbot.CurrentTarget then
        local part = GetPlayerPart(CombatSystem.Aimbot.CurrentTarget, CombatSystem.Aimbot.TargetPart)
        
        if part then
            -- Calculate aim point with ballistics
            local aimPoint = BallisticsEngine.CalculateAimPoint(part)
            
            if aimPoint then
                -- Aim camera
                local aimCFrame = CFrame.new(Camera.CFrame.Position, aimPoint)
                Camera.CFrame = Camera.CFrame:Lerp(aimCFrame, CombatConfig.AimbotSmoothness)
            end
        end
    end
end

-- ============================================
-- CROSSHAIR SYSTEM
-- ============================================

local CrosshairEngine = {}

function CrosshairEngine.Create()
    if CombatSystem.Crosshair.Circle then
        DrawingLibrary:Remove(CombatSystem.Crosshair.Circle)
    end
    if CombatSystem.Crosshair.Dot then
        DrawingLibrary:Remove(CombatSystem.Crosshair.Dot)
    end
    if CombatSystem.Crosshair.PredictionDot then
        DrawingLibrary:Remove(CombatSystem.Crosshair.PredictionDot)
    end
    
    CombatSystem.Crosshair.Circle = DrawingLibrary:New("Circle", {
        Thickness = 2,
        NumSides = 30,
        Radius = 5,
        Filled = false,
        Color = Color3.fromRGB(0, 255, 0),
        Transparency = 1,
        Visible = false,
    })
    
    CombatSystem.Crosshair.Dot = DrawingLibrary:New("Circle", {
        Thickness = 1,
        NumSides = 20,
        Radius = 2,
        Filled = true,
        Color = Color3.fromRGB(0, 255, 0),
        Transparency = 1,
        Visible = false,
    })
    
    CombatSystem.Crosshair.PredictionDot = DrawingLibrary:New("Circle", {
        Thickness = 2,
        NumSides = 20,
        Radius = 3,
        Filled = false,
        Color = Color3.fromRGB(255, 255, 0),
        Transparency = 1,
        Visible = false,
    })
end

function CrosshairEngine.Update()
    if not CombatSystem.Crosshair.Enabled then
        if CombatSystem.Crosshair.Circle then CombatSystem.Crosshair.Circle.Visible = false end
        if CombatSystem.Crosshair.Dot then CombatSystem.Crosshair.Dot.Visible = false end
        if CombatSystem.Crosshair.PredictionDot then CombatSystem.Crosshair.PredictionDot.Visible = false end
        return
    end
    
    local center = GetScreenCenter()
    
    -- Main crosshair
    if CombatSystem.Crosshair.Circle then
        CombatSystem.Crosshair.Circle.Position = center
        CombatSystem.Crosshair.Circle.Visible = true
    end
    
    if CombatSystem.Crosshair.Dot then
        CombatSystem.Crosshair.Dot.Position = center
        CombatSystem.Crosshair.Dot.Visible = true
    end
    
    -- Dynamic prediction dot
    if CombatSystem.Crosshair.Dynamic and CombatSystem.Crosshair.PredictionDot then
        -- Raycast from camera to predict where bullet will land
        local origin = Camera.CFrame.Position
        local direction = Camera.CFrame.LookVector * 500
        
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
        params.IgnoreWater = false
        
        local result = Workspace:Raycast(origin, direction, params)
        
        if result then
            local hitPos = result.Position
            local distance = (hitPos - origin).Magnitude
            
            -- Calculate where bullet will actually hit with drop
            local drop = BallisticsEngine.CalculateBulletDrop(distance)
            local actualHitPos = hitPos - Vector3.new(0, drop, 0)
            
            local screenPos, onScreen = WorldToScreen(actualHitPos)
            
            if onScreen then
                CombatSystem.Crosshair.PredictionDot.Position = screenPos
                CombatSystem.Crosshair.PredictionDot.Visible = true
            else
                CombatSystem.Crosshair.PredictionDot.Visible = false
            end
        else
            CombatSystem.Crosshair.PredictionDot.Visible = false
        end
    end
end

-- ============================================
-- ESP ENGINE
-- ============================================

local ESPEngine = {}

function ESPEngine.Create(player)
    if player == LocalPlayer then return end
    if CombatSystem.ESP.Objects[player] then
        ESPEngine.Remove(player)
    end
    
    local isBlacklisted = CombatSystem.Blacklist.Enabled and 
                         table.find(CombatSystem.Blacklist.Players, player.Name)
    
    local color = isBlacklisted and CombatSystem.Blacklist.Color or CombatConfig.ESPColor
    
    local objects = {
        BoxOutline = DrawingLibrary:New("Square", {
            Thickness = 3,
            Filled = false,
            Color = Color3.new(0, 0, 0),
            Transparency = 1,
            Visible = false,
        }),
        
        Box = DrawingLibrary:New("Square", {
            Thickness = 2,
            Filled = false,
            Color = color,
            Transparency = 0.8,
            Visible = false,
        }),
        
        HealthBarBG = DrawingLibrary:New("Square", {
            Thickness = 1,
            Filled = true,
            Color = Color3.new(0.1, 0.1, 0.1),
            Transparency = 0.5,
            Visible = false,
        }),
        
        HealthBar = DrawingLibrary:New("Square", {
            Thickness = 1,
            Filled = true,
            Color = Color3.new(0, 1, 0),
            Transparency = 0.8,
            Visible = false,
        }),
        
        Name = DrawingLibrary:New("Text", {
            Text = player.Name,
            Size = 13,
            Center = true,
            Outline = true,
            OutlineColor = Color3.new(0, 0, 0),
            Color = color,
            Transparency = 1,
            Visible = false,
            Font = 2,
        }),
        
        Distance = DrawingLibrary:New("Text", {
            Text = "0m",
            Size = 13,
            Center = true,
            Outline = true,
            OutlineColor = Color3.new(0, 0, 0),
            Color = Color3.new(1, 1, 1),
            Transparency = 1,
            Visible = false,
            Font = 2,
        }),
        
        HealthText = DrawingLibrary:New("Text", {
            Text = "100",
            Size = 12,
            Center = false,
            Outline = true,
            OutlineColor = Color3.new(0, 0, 0),
            Color = Color3.new(1, 1, 1),
            Transparency = 1,
            Visible = false,
            Font = 2,
        }),
    }
    
    if isBlacklisted then
        objects.BlacklistBox = DrawingLibrary:New("Square", {
            Thickness = 4,
            Filled = false,
            Color = CombatSystem.Blacklist.Color,
            Transparency = 1,
            Visible = false,
        })
        
        objects.BlacklistText = DrawingLibrary:New("Text", {
            Text = "[BLACKLISTED]",
            Size = 14,
            Center = true,
            Outline = true,
            OutlineColor = Color3.new(0, 0, 0),
            Color = CombatSystem.Blacklist.Color,
            Transparency = 1,
            Visible = false,
            Font = 3,
        })
    end
    
    CombatSystem.ESP.Objects[player] = objects
end

function ESPEngine.Update(player)
    local objects = CombatSystem.ESP.Objects[player]
    if not objects then return end
    
    SafeCall(function()
        if not IsPlayerAlive(player) then
            ESPEngine.Hide(player)
            return
        end
        
        local char = player.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
        if not root then
            ESPEngine.Hide(player)
            return
        end
        
        local distance = GetDistance(player)
        if distance > CombatConfig.ESPMaxDistance then
            ESPEngine.Hide(player)
            return
        end
        
        -- Get bounding box
        local corners = {}
        local size = Vector3.new(3, 5, 0)
        local cframe = root.CFrame
        
        local positions = {
            cframe * CFrame.new(-size.X, size.Y, 0),
            cframe * CFrame.new(size.X, size.Y, 0),
            cframe * CFrame.new(-size.X, -size.Y, 0),
            cframe * CFrame.new(size.X, -size.Y, 0),
        }
        
        for _, pos in ipairs(positions) do
            local screenPos, onScreen = WorldToScreen(pos.Position)
            if not onScreen then
                ESPEngine.Hide(player)
                return
            end
            table.insert(corners, screenPos)
        end
        
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        
        for _, corner in ipairs(corners) do
            minX = math.min(minX, corner.X)
            minY = math.min(minY, corner.Y)
            maxX = math.max(maxX, corner.X)
            maxY = math.max(maxY, corner.Y)
        end
        
        local boxPos = Vector2.new(minX, minY)
        local boxSize = Vector2.new(maxX - minX, maxY - minY)
        
        local isBlacklisted = CombatSystem.Blacklist.Enabled and 
                             table.find(CombatSystem.Blacklist.Players, player.Name)
        
        local color = isBlacklisted and CombatSystem.Blacklist.Color or CombatConfig.ESPColor
        
        -- Box
        objects.BoxOutline.Size = boxSize
        objects.BoxOutline.Position = boxPos
        objects.BoxOutline.Visible = true
        
        objects.Box.Size = boxSize
        objects.Box.Position = boxPos
        objects.Box.Color = color
        objects.Box.Visible = true
        
        -- Name
        if CombatSystem.ESP.ShowNames then
            objects.Name.Position = Vector2.new(boxPos.X + boxSize.X / 2, boxPos.Y - 16)
            objects.Name.Color = color
            objects.Name.Visible = true
        else
            objects.Name.Visible = false
        end
        
        -- Distance
        if CombatSystem.ESP.ShowDistance then
            objects.Distance.Text = math.floor(distance) .. "m"
            objects.Distance.Position = Vector2.new(boxPos.X + boxSize.X / 2, boxPos.Y + boxSize.Y + 2)
            objects.Distance.Visible = true
        else
            objects.Distance.Visible = false
        end
        
        -- Health
        if CombatSystem.ESP.ShowHealth and humanoid then
            local health = humanoid.Health
            local maxHealth = humanoid.MaxHealth
            local healthPct = health / maxHealth
            
            local barW = 3
            local barH = boxSize.Y
            local barX = boxPos.X - barW - 4
            local barY = boxPos.Y
            
            objects.HealthBarBG.Size = Vector2.new(barW, barH)
            objects.HealthBarBG.Position = Vector2.new(barX, barY)
            objects.HealthBarBG.Visible = true
            
            local currentBarH = barH * healthPct
            objects.HealthBar.Size = Vector2.new(barW, currentBarH)
            objects.HealthBar.Position = Vector2.new(barX, barY + (barH - currentBarH))
            
            if healthPct > 0.6 then
                objects.HealthBar.Color = Color3.new(0, 1, 0)
            elseif healthPct > 0.3 then
                objects.HealthBar.Color = Color3.new(1, 1, 0)
            else
                objects.HealthBar.Color = Color3.new(1, 0, 0)
            end
            
            objects.HealthBar.Visible = true
            
            objects.HealthText.Text = math.floor(health)
            objects.HealthText.Position = Vector2.new(barX - 18, barY + (barH - currentBarH) - 7)
            objects.HealthText.Visible = true
        else
            objects.HealthBarBG.Visible = false
            objects.HealthBar.Visible = false
            objects.HealthText.Visible = false
        end
        
        -- Blacklist indicators
        if isBlacklisted and objects.BlacklistBox then
            objects.BlacklistBox.Size = Vector2.new(boxSize.X + 8, boxSize.Y + 8)
            objects.BlacklistBox.Position = Vector2.new(boxPos.X - 4, boxPos.Y - 4)
            objects.BlacklistBox.Visible = true
            
            objects.BlacklistText.Position = Vector2.new(boxPos.X + boxSize.X / 2, boxPos.Y - 34)
            objects.BlacklistText.Visible = true
        end
    end)
end

function ESPEngine.Hide(player)
    local objects = CombatSystem.ESP.Objects[player]
    if not objects then return end
    
    for _, obj in pairs(objects) do
        pcall(function() obj.Visible = false end)
    end
end

function ESPEngine.Remove(player)
    local objects = CombatSystem.ESP.Objects[player]
    if not objects then return end
    
    for _, obj in pairs(objects) do
        DrawingLibrary:Remove(obj)
    end
    
    CombatSystem.ESP.Objects[player] = nil
end

function ESPEngine.Enable()
    if CombatSystem.ESP.Enabled then return end
    CombatSystem.ESP.Enabled = true
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ESPEngine.Create(player)
        end
    end
    
    CombatSystem.ESP.Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            task.wait(1)
            if CombatSystem.ESP.Enabled then
                ESPEngine.Create(player)
            end
        end
    end)
    
    CombatSystem.ESP.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        ESPEngine.Remove(player)
    end)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CombatSystem.ESP.Connections[player.Name .. "_CharAdded"] = 
                player.CharacterAdded:Connect(function()
                    task.wait(1)
                    if CombatSystem.ESP.Enabled then
                        ESPEngine.Create(player)
                    end
                end)
        end
    end
    
    CombatSystem.ESP.Connections.Update = RunService.RenderStepped:Connect(function()
        for player, _ in pairs(CombatSystem.ESP.Objects) do
            ESPEngine.Update(player)
        end
    end)
end

function ESPEngine.Disable()
    if not CombatSystem.ESP.Enabled then return end
    CombatSystem.ESP.Enabled = false
    
    for player, _ in pairs(CombatSystem.ESP.Objects) do
        ESPEngine.Remove(player)
    end
    
    for _, conn in pairs(CombatSystem.ESP.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    CombatSystem.ESP.Connections = {}
end

function ESPEngine.Refresh()
    local was = CombatSystem.ESP.Enabled
    if was then
        ESPEngine.Disable()
        task.wait(0.1)
        ESPEngine.Enable()
    end
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function GetAllPlayers()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    return names
end

-- ============================================
-- PERFORMANCE TRACKING
-- ============================================

local PerformanceStats = {
    FPS = 0,
    FrameTime = 0,
    LastUpdate = tick(),
}

task.spawn(function()
    local frameCount = 0
    local lastTime = tick()
    
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        
        local now = tick()
        PerformanceStats.FrameTime = (now - PerformanceStats.LastUpdate) * 1000
        PerformanceStats.LastUpdate = now
        
        if now - lastTime >= 1 then
            PerformanceStats.FPS = frameCount
            frameCount = 0
            lastTime = now
        end
    end)
end)

-- ============================================
-- ADVANCED FEATURES
-- ============================================

local TargetTracking = {}
TargetTracking.History = {}

function TargetTracking.Record(player)
    if not TargetTracking.History[player] then
        TargetTracking.History[player] = {
            Positions = {},
            Velocities = {},
            LastSeen = 0,
        }
    end
    
    local data = TargetTracking.History[player]
    local part = GetPlayerPart(player, "HumanoidRootPart")
    
    if part then
        table.insert(data.Positions, 1, {
            Pos = part.Position,
            Time = tick(),
        })
        
        if #data.Positions > 10 then
            table.remove(data.Positions)
        end
        
        local vel = part.AssemblyLinearVelocity or Vector3.zero
        table.insert(data.Velocities, 1, {
            Vel = vel,
            Time = tick(),
        })
        
        if #data.Velocities > 10 then
            table.remove(data.Velocities)
        end
        
        data.LastSeen = tick()
    end
end

function TargetTracking.GetAverageVelocity(player)
    local data = TargetTracking.History[player]
    if not data or #data.Velocities == 0 then
        return Vector3.zero
    end
    
    local sum = Vector3.zero
    for _, entry in ipairs(data.Velocities) do
        sum = sum + entry.Vel
    end
    
    return sum / #data.Velocities
end

function TargetTracking.IsMovingErratically(player)
    local data = TargetTracking.History[player]
    if not data or #data.Velocities < 3 then
        return false
    end
    
    local changes = 0
    for i = 1, math.min(3, #data.Velocities - 1) do
        local v1 = data.Velocities[i].Vel
        local v2 = data.Velocities[i + 1].Vel
        
        if v1.Magnitude > 0.1 and v2.Magnitude > 0.1 then
            local dot = v1.Unit:Dot(v2.Unit)
            local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
            
            if angle > 45 then
                changes = changes + 1
            end
        end
    end
    
    return changes >= 2
end

local WeaponInfo = {}

function WeaponInfo.GetEquipped(player)
    if not player or not player.Character then return nil end
    
    for _, child in ipairs(player.Character:GetChildren()) do
        if child:IsA("Tool") then
            return child.Name
        end
    end
    
    return nil
end

function WeaponInfo.IsReloading(player)
    if not player or not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local name = track.Animation.AnimationId:lower()
        if name:find("reload") then
            return true
        end
    end
    
    return false
end

local AntiAimDetector = {}

function AntiAimDetector.IsUsing(player)
    if not player or not player.Character then return false end
    
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    local head = player.Character:FindFirstChild("Head")
    
    if not root or not head then return false end
    
    local rootDir = root.CFrame.LookVector
    local headDir = head.CFrame.LookVector
    
    local angle = math.deg(math.acos(math.clamp(rootDir:Dot(headDir), -1, 1)))
    
    return angle > 90
end

function AntiAimDetector.GetRealPosition(player)
    if not player or not player.Character then return nil end
    
    if AntiAimDetector.IsUsing(player) then
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            return root.Position + Vector3.new(0, 2, 0)
        end
    end
    
    local head = player.Character:FindFirstChild("Head")
    return head and head.Position
end

-- ============================================
-- ADVANCED PREDICTION ENGINE
-- ============================================

local AdvancedPrediction = {}
AdvancedPrediction.Cache = {}

function AdvancedPrediction.CalculateInterception(targetPos, targetVel, shooterPos, projectileSpeed)
    local relativePos = targetPos - shooterPos
    local a = targetVel:Dot(targetVel) - (projectileSpeed * projectileSpeed)
    local b = 2 * targetVel:Dot(relativePos)
    local c = relativePos:Dot(relativePos)
    
    local discriminant = (b * b) - (4 * a * c)
    
    if discriminant < 0 then
        return targetPos
    end
    
    local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
    local t2 = (-b - math.sqrt(discriminant)) / (2 * a)
    
    local t = math.min(t1, t2)
    if t < 0 then
        t = math.max(t1, t2)
    end
    
    if t < 0 then
        return targetPos
    end
    
    return targetPos + (targetVel * t)
end

function AdvancedPrediction.PredictWithAcceleration(player)
    if not TargetTracking.History[player] then
        return nil
    end
    
    local data = TargetTracking.History[player]
    
    if #data.Velocities < 2 then
        return nil
    end
    
    local currentVel = data.Velocities[1].Vel
    local previousVel = data.Velocities[2].Vel
    
    local deltaTime = data.Velocities[1].Time - data.Velocities[2].Time
    
    if deltaTime == 0 then
        return nil
    end
    
    local acceleration = (currentVel - previousVel) / deltaTime
    
    return acceleration
end

function AdvancedPrediction.GetOptimalPrediction(player, targetPart)
    if not targetPart then return nil end
    
    local currentPos = targetPart.Position
    local currentVel = targetPart.AssemblyLinearVelocity or Vector3.zero
    
    local distance = (currentPos - Camera.CFrame.Position).Magnitude
    local timeToHit = distance / CombatConfig.BulletSpeed
    
    local basicPrediction = currentPos + (currentVel * timeToHit)
    
    local acceleration = AdvancedPrediction.PredictWithAcceleration(player)
    if acceleration then
        local accPrediction = 0.5 * acceleration * (timeToHit * timeToHit)
        basicPrediction = basicPrediction + accPrediction
    end
    
    local drop = BallisticsEngine.CalculateBulletDrop(distance)
    basicPrediction = basicPrediction + Vector3.new(0, drop, 0)
    
    return basicPrediction
end

-- ============================================
-- HIT DETECTION SYSTEM
-- ============================================

local HitDetection = {}
HitDetection.RecentHits = {}
HitDetection.RecentMisses = {}

function HitDetection.RecordHit(player)
    table.insert(HitDetection.RecentHits, 1, {
        Player = player,
        Time = tick(),
    })
    
    if #HitDetection.RecentHits > 50 then
        table.remove(HitDetection.RecentHits)
    end
end

function HitDetection.RecordMiss(player)
    table.insert(HitDetection.RecentMisses, 1, {
        Player = player,
        Time = tick(),
    })
    
    if #HitDetection.RecentMisses > 50 then
        table.remove(HitDetection.RecentMisses)
    end
end

function HitDetection.GetAccuracy()
    local totalShots = #HitDetection.RecentHits + #HitDetection.RecentMisses
    
    if totalShots == 0 then
        return 0
    end
    
    return (#HitDetection.RecentHits / totalShots) * 100
end

function HitDetection.GetHitRate(player)
    local hits = 0
    local misses = 0
    
    for _, hit in ipairs(HitDetection.RecentHits) do
        if hit.Player == player then
            hits = hits + 1
        end
    end
    
    for _, miss in ipairs(HitDetection.RecentMisses) do
        if miss.Player == player then
            misses = misses + 1
        end
    end
    
    local total = hits + misses
    
    if total == 0 then
        return 0
    end
    
    return (hits / total) * 100
end

-- ============================================
-- RECOIL COMPENSATION
-- ============================================

local RecoilCompensation = {}
RecoilCompensation.LastShot = 0
RecoilCompensation.ConsecutiveShots = 0
RecoilCompensation.RecoilPattern = {}

function RecoilCompensation.TrackShot()
    local now = tick()
    
    if now - RecoilCompensation.LastShot < 0.5 then
        RecoilCompensation.ConsecutiveShots = RecoilCompensation.ConsecutiveShots + 1
    else
        RecoilCompensation.ConsecutiveShots = 1
    end
    
    RecoilCompensation.LastShot = now
    
    table.insert(RecoilCompensation.RecoilPattern, 1, {
        Shot = RecoilCompensation.ConsecutiveShots,
        Time = now,
    })
    
    if #RecoilCompensation.RecoilPattern > 20 then
        table.remove(RecoilCompensation.RecoilPattern)
    end
end

function RecoilCompensation.GetRecoilOffset()
    if RecoilCompensation.ConsecutiveShots == 0 then
        return Vector3.zero
    end
    
    local verticalRecoil = RecoilCompensation.ConsecutiveShots * 0.05
    local horizontalRecoil = (math.sin(RecoilCompensation.ConsecutiveShots * 0.5) * 0.02)
    
    return Vector3.new(horizontalRecoil, verticalRecoil, 0)
end

function RecoilCompensation.CompensateAim(aimPoint)
    local offset = RecoilCompensation.GetRecoilOffset()
    
    return aimPoint - offset
end

-- ============================================
-- MOVEMENT PATTERN ANALYSIS
-- ============================================

local MovementAnalysis = {}
MovementAnalysis.Patterns = {}

function MovementAnalysis.AnalyzePlayer(player)
    if not TargetTracking.History[player] then
        return "Unknown"
    end
    
    local data = TargetTracking.History[player]
    
    if #data.Positions < 5 then
        return "Insufficient Data"
    end
    
    local speeds = {}
    for i = 1, math.min(5, #data.Positions - 1) do
        local p1 = data.Positions[i]
        local p2 = data.Positions[i + 1]
        
        local deltaTime = p1.Time - p2.Time
        if deltaTime > 0 then
            local distance = (p1.Pos - p2.Pos).Magnitude
            local speed = distance / deltaTime
            table.insert(speeds, speed)
        end
    end
    
    if #speeds == 0 then
        return "Stationary"
    end
    
    local avgSpeed = 0
    for _, speed in ipairs(speeds) do
        avgSpeed = avgSpeed + speed
    end
    avgSpeed = avgSpeed / #speeds
    
    local speedVariance = 0
    for _, speed in ipairs(speeds) do
        speedVariance = speedVariance + ((speed - avgSpeed) ^ 2)
    end
    speedVariance = speedVariance / #speeds
    
    if avgSpeed < 1 then
        return "Stationary"
    elseif avgSpeed < 10 then
        if speedVariance > 5 then
            return "Walking Erratically"
        else
            return "Walking"
        end
    elseif avgSpeed < 20 then
        if speedVariance > 10 then
            return "Running Erratically"
        else
            return "Running"
        end
    else
        if speedVariance > 20 then
            return "Sprinting Erratically"
        else
            return "Sprinting"
        end
    end
end

function MovementAnalysis.IsPredictable(player)
    local pattern = MovementAnalysis.AnalyzePlayer(player)
    
    return not pattern:find("Erratically")
end

function MovementAnalysis.GetDirectionChange(player)
    if not TargetTracking.History[player] then
        return 0
    end
    
    local data = TargetTracking.History[player]
    
    if #data.Velocities < 2 then
        return 0
    end
    
    local v1 = data.Velocities[1].Vel
    local v2 = data.Velocities[2].Vel
    
    if v1.Magnitude < 0.1 or v2.Magnitude < 0.1 then
        return 0
    end
    
    local dot = v1.Unit:Dot(v2.Unit)
    return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

-- ============================================
-- SMART TARGET SELECTION
-- ============================================

local SmartTargeting = {}

function SmartTargeting.ScoreTarget(player)
    local score = 1000
    
    -- Distance factor
    local distance = GetDistance(player)
    score = score - (distance * 0.5)
    
    -- FOV factor
    local part = GetPlayerPart(player, CombatSystem.Aimbot.TargetPart)
    if part then
        local screenPos, _ = WorldToScreen(part.Position)
        local center = GetScreenCenter()
        local distFromCenter = (screenPos - center).Magnitude
        score = score - distFromCenter
    end
    
    -- Health factor (prioritize low health)
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if humanoid then
        local healthPct = humanoid.Health / humanoid.MaxHealth
        score = score + ((1 - healthPct) * 100)
    end
    
    -- Movement predictability
    if MovementAnalysis.IsPredictable(player) then
        score = score + 50
    end
    
    -- Hit rate factor
    local hitRate = HitDetection.GetHitRate(player)
    score = score + (hitRate * 0.5)
    
    -- Weapon status
    if WeaponInfo.IsReloading(player) then
        score = score + 100
    end
    
    return score
end

function SmartTargeting.GetBestTarget()
    local best = nil
    local bestScore = -math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if not AimbotEngine.ShouldIgnore(player) and AimbotEngine.IsInFOV(player) then
            local score = SmartTargeting.ScoreTarget(player)
            
            if score > bestScore then
                bestScore = score
                best = player
            end
        end
    end
    
    return best
end

-- ============================================
-- TRIGGER BOT SYSTEM
-- ============================================

local TriggerBot = {}
TriggerBot.Enabled = false
TriggerBot.Delay = 0.05

function TriggerBot.Check()
    if not TriggerBot.Enabled then return end
    
    local origin = Camera.CFrame.Position
    local direction = Camera.CFrame.LookVector * 500
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    
    local result = Workspace:Raycast(origin, direction, params)
    
    if result then
        local char = result.Instance:FindFirstAncestorOfClass("Model")
        if char then
            local player = Players:GetPlayerFromCharacter(char)
            if player and player ~= LocalPlayer and IsPlayerAlive(player) then
                if not AimbotEngine.ShouldIgnore(player) then
                    task.wait(TriggerBot.Delay)
                    
                    -- Simulate click
                    return true
                end
            end
        end
    end
    
    return false
end

-- ============================================
-- SILENT AIM SYSTEM
-- ============================================

local SilentAim = {}
SilentAim.Enabled = false
SilentAim.HitChance = 100

function SilentAim.ModifyBulletDirection(originalDirection)
    if not SilentAim.Enabled then
        return originalDirection
    end
    
    if math.random(100) > SilentAim.HitChance then
        return originalDirection
    end
    
    local target = AimbotEngine.GetClosestInFOV()
    if not target then
        return originalDirection
    end
    
    local part = GetPlayerPart(target, CombatSystem.Aimbot.TargetPart)
    if not part then
        return originalDirection
    end
    
    local aimPoint = BallisticsEngine.CalculateAimPoint(part)
    if not aimPoint then
        return originalDirection
    end
    
    local newDirection = (aimPoint - Camera.CFrame.Position).Unit
    
    return newDirection
end

-- ============================================
-- AUTO SHOOT SYSTEM
-- ============================================

local AutoShoot = {}
AutoShoot.Enabled = false
AutoShoot.FOVCheck = true

function AutoShoot.ShouldShoot()
    if not AutoShoot.Enabled then return false end
    
    if not CombatSystem.Aimbot.CurrentTarget then return false end
    
    if AutoShoot.FOVCheck and not AimbotEngine.IsInFOV(CombatSystem.Aimbot.CurrentTarget) then
        return false
    end
    
    return true
end

-- ============================================
-- RAGE BOT FEATURES
-- ============================================

local RageBot = {}
RageBot.Enabled = false
RageBot.Features = {
    NoRecoil = false,
    NoSpread = false,
    InfiniteAmmo = false,
    RapidFire = false,
}

function RageBot.ApplyFeatures()
    if not RageBot.Enabled then return end
    
    -- These would hook into the game's shooting mechanics
    -- Implementation depends on game structure
end

-- ============================================
-- CUSTOM KEYBINDS
-- ============================================

local Keybinds = {}
Keybinds.AimbotToggle = Enum.KeyCode.V
Keybinds.ESPToggle = Enum.KeyCode.B
Keybinds.CrosshairToggle = Enum.KeyCode.N

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Keybinds.AimbotToggle then
        CombatSystem.Aimbot.Enabled = not CombatSystem.Aimbot.Enabled
    elseif input.KeyCode == Keybinds.ESPToggle then
        if CombatSystem.ESP.Enabled then
            ESPEngine.Disable()
        else
            ESPEngine.Enable()
        end
    elseif input.KeyCode == Keybinds.CrosshairToggle then
        CombatSystem.Crosshair.Enabled = not CombatSystem.Crosshair.Enabled
    end
end)

-- ============================================
-- CONFIGURATION MANAGER
-- ============================================

local ConfigManager = {}
ConfigManager.Configs = {}

function ConfigManager.Save(name)
    local config = {
        Aimbot = {
            Enabled = CombatSystem.Aimbot.Enabled,
            TargetPart = CombatSystem.Aimbot.TargetPart,
            VisibilityCheck = CombatSystem.Aimbot.VisibilityCheck,
            IgnoreFriends = CombatSystem.Aimbot.IgnoreFriends,
        },
        ESP = {
            Enabled = CombatSystem.ESP.Enabled,
            ShowNames = CombatSystem.ESP.ShowNames,
            ShowDistance = CombatSystem.ESP.ShowDistance,
            ShowHealth = CombatSystem.ESP.ShowHealth,
        },
        Crosshair = {
            Enabled = CombatSystem.Crosshair.Enabled,
            Dynamic = CombatSystem.Crosshair.Dynamic,
        },
        Settings = {
            FOVSize = CombatConfig.FOVSize,
            Smoothness = CombatConfig.AimbotSmoothness,
            Prediction = CombatConfig.PredictionMultiplier,
        }
    }
    
    ConfigManager.Configs[name] = config
    return true
end

function ConfigManager.Load(name)
    local config = ConfigManager.Configs[name]
    if not config then return false end
    
    CombatSystem.Aimbot.Enabled = config.Aimbot.Enabled
    CombatSystem.Aimbot.TargetPart = config.Aimbot.TargetPart
    CombatSystem.Aimbot.VisibilityCheck = config.Aimbot.VisibilityCheck
    CombatSystem.Aimbot.IgnoreFriends = config.Aimbot.IgnoreFriends
    
    CombatSystem.ESP.ShowNames = config.ESP.ShowNames
    CombatSystem.ESP.ShowDistance = config.ESP.ShowDistance
    CombatSystem.ESP.ShowHealth = config.ESP.ShowHealth
    
    if config.ESP.Enabled then
        ESPEngine.Enable()
    else
        ESPEngine.Disable()
    end
    
    CombatSystem.Crosshair.Enabled = config.Crosshair.Enabled
    CombatSystem.Crosshair.Dynamic = config.Crosshair.Dynamic
    
    CombatConfig.FOVSize = config.Settings.FOVSize
    CombatConfig.AimbotSmoothness = config.Settings.Smoothness
    CombatConfig.PredictionMultiplier = config.Settings.Prediction
    
    return true
end

function ConfigManager.Delete(name)
    ConfigManager.Configs[name] = nil
    return true
end

function ConfigManager.List()
    local names = {}
    for name, _ in pairs(ConfigManager.Configs) do
        table.insert(names, name)
    end
    return names
end

-- ============================================
-- FINAL INITIALIZATION
-- ============================================

local function InitializeCombatSystem()
    print("Initializing FastCast Combat System...")
    
    AimbotEngine.CreateFOVCircle()
    CrosshairEngine.Create()
    UpdateBlacklistColor()
    
    print("✓ Aimbot engine ready")
    print("✓ Crosshair system ready")
    print("✓ ESP engine ready")
    print("✓ Blacklist system ready")
    print("✓ Ballistics engine ready")
    print("✓ All systems operational")
end

InitializeCombatSystem()

-- ============================================
-- LOAD UI
-- ============================================

AimbotEngine.CreateFOVCircle()
CrosshairEngine.Create()
UpdateBlacklistColor()

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "FastCast Combat System",
   LoadingTitle = "Loading Realistic System...",
   LoadingSubtitle = "Optimized for FastCast Games",
   ConfigurationSaving = {
      Enabled = false,
   },
   Discord = {
      Enabled = false,
   },
   KeySystem = false
})

-- ============================================
-- UI TABS
-- ============================================

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

AimbotTab:CreateSection("Main Controls")

AimbotTab:CreateToggle({
   Name = "Enable Aimbot",
   CurrentValue = false,
   Flag = "Aimbot",
   Callback = function(Value)
      CombatSystem.Aimbot.Enabled = Value
      
      if Value then
         Rayfield:Notify({
            Title = "Aimbot Enabled",
            Content = "Fast targeting active!",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

AimbotTab:CreateSection("Settings")

AimbotTab:CreateToggle({
   Name = "Visibility Check",
   CurrentValue = true,
   Flag = "VisCheck",
   Callback = function(Value)
      CombatSystem.Aimbot.VisibilityCheck = Value
   end,
})

AimbotTab:CreateToggle({
   Name = "Ignore Friends",
   CurrentValue = false,
   Flag = "IgnoreFriends",
   Callback = function(Value)
      CombatSystem.Aimbot.IgnoreFriends = Value
   end,
})

AimbotTab:CreateDropdown({
   Name = "Target Part",
   Options = {"Head", "HumanoidRootPart", "UpperTorso"},
   CurrentOption = {"Head"},
   MultipleOptions = false,
   Flag = "TargetPart",
   Callback = function(Option)
      CombatSystem.Aimbot.TargetPart = Option[1]
   end,
})

AimbotTab:CreateSlider({
   Name = "FOV Size",
   Range = {50, 500},
   Increment = 10,
   CurrentValue = 200,
   Flag = "FOV",
   Callback = function(Value)
      CombatConfig.FOVSize = Value
   end,
})

AimbotTab:CreateSlider({
   Name = "Smoothness (Higher = Faster)",
   Range = {0.1, 1},
   Increment = 0.05,
   CurrentValue = 0.5,
   Flag = "Smooth",
   Callback = function(Value)
      CombatConfig.AimbotSmoothness = Value
   end,
})

AimbotTab:CreateSlider({
   Name = "Prediction",
   Range = {0, 0.3},
   Increment = 0.01,
   CurrentValue = 0.13,
   Flag = "Pred",
   Callback = function(Value)
      CombatConfig.PredictionMultiplier = Value
   end,
})

AimbotTab:CreateSection("Ignore List")

local IgnoreDropdown = AimbotTab:CreateDropdown({
   Name = "Players to Ignore",
   Options = GetAllPlayers(),
   CurrentOption = {},
   MultipleOptions = true,
   Flag = "Ignore",
   Callback = function(Options)
      CombatSystem.Aimbot.IgnoredPlayers = Options
   end,
})

AimbotTab:CreateButton({
   Name = "Refresh Player List",
   Callback = function()
      IgnoreDropdown:Refresh(GetAllPlayers())
   end,
})

local CrosshairTab = Window:CreateTab("Crosshair", 4483362458)

CrosshairTab:CreateSection("Crosshair Controls")

CrosshairTab:CreateToggle({
   Name = "Enable Crosshair",
   CurrentValue = false,
   Flag = "Crosshair",
   Callback = function(Value)
      CombatSystem.Crosshair.Enabled = Value
   end,
})

CrosshairTab:CreateToggle({
   Name = "Dynamic Prediction",
   CurrentValue = true,
   Flag = "DynamicCross",
   Callback = function(Value)
      CombatSystem.Crosshair.Dynamic = Value
   end,
})

CrosshairTab:CreateLabel("Dynamic prediction shows where")
CrosshairTab:CreateLabel("your bullet will land (yellow dot)")

local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateSection("ESP Controls")

ESPTab:CreateToggle({
   Name = "Enable ESP",
   CurrentValue = false,
   Flag = "ESP",
   Callback = function(Value)
      if Value then
         ESPEngine.Enable()
      else
         ESPEngine.Disable()
      end
   end,
})

ESPTab:CreateSection("Settings")

ESPTab:CreateToggle({
   Name = "Show Names",
   CurrentValue = true,
   Flag = "Names",
   Callback = function(Value)
      CombatSystem.ESP.ShowNames = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Show Distance",
   CurrentValue = true,
   Flag = "Dist",
   Callback = function(Value)
      CombatSystem.ESP.ShowDistance = Value
   end,
})

ESPTab:CreateToggle({
   Name = "Show Health",
   CurrentValue = true,
   Flag = "Health",
   Callback = function(Value)
      CombatSystem.ESP.ShowHealth = Value
   end,
})

ESPTab:CreateColorPicker({
   Name = "ESP Color",
   Color = Color3.fromRGB(255, 0, 0),
   Flag = "ESPColor",
   Callback = function(Value)
      CombatConfig.ESPColor = Value
      UpdateBlacklistColor()
      ESPEngine.Refresh()
   end
})

ESPTab:CreateButton({
   Name = "Refresh ESP",
   Callback = function()
      ESPEngine.Refresh()
   end,
})

local BlacklistTab = Window:CreateTab("Blacklist", 4483362458)

BlacklistTab:CreateSection("Blacklist System")

BlacklistTab:CreateLabel("Blacklisted players show in")
BlacklistTab:CreateLabel("opposite color with extra box")

BlacklistTab:CreateToggle({
   Name = "Enable Blacklist",
   CurrentValue = false,
   Flag = "Blacklist",
   Callback = function(Value)
      CombatSystem.Blacklist.Enabled = Value
      ESPEngine.Refresh()
   end,
})

local BlacklistDropdown = BlacklistTab:CreateDropdown({
   Name = "Select Players",
   Options = GetAllPlayers(),
   CurrentOption = {},
   MultipleOptions = true,
   Flag = "BlacklistPlayers",
   Callback = function(Options)
      CombatSystem.Blacklist.Players = Options
      ESPEngine.Refresh()
   end,
})

BlacklistTab:CreateButton({
   Name = "Refresh List",
   Callback = function()
      BlacklistDropdown:Refresh(GetAllPlayers())
   end,
})

BlacklistTab:CreateSection("Colors")

local ColorLabel1 = BlacklistTab:CreateLabel("ESP: RGB(255, 0, 0)")
local ColorLabel2 = BlacklistTab:CreateLabel("Blacklist: RGB(0, 255, 255)")

task.spawn(function()
    while task.wait(1) do
        SafeCall(function()
            local c = CombatConfig.ESPColor
            ColorLabel1:Set("ESP: RGB(" .. math.floor(c.R*255) .. ", " .. math.floor(c.G*255) .. ", " .. math.floor(c.B*255) .. ")")
            
            local b = CombatSystem.Blacklist.Color
            ColorLabel2:Set("Blacklist: RGB(" .. math.floor(b.R*255) .. ", " .. math.floor(b.G*255) .. ", " .. math.floor(b.B*255) .. ")")
        end)
    end
end)

local StatsTab = Window:CreateTab("Stats", 4483362458)

StatsTab:CreateSection("Performance")

local FPSLabel = StatsTab:CreateLabel("FPS: 0")
local FrameLabel = StatsTab:CreateLabel("Frame Time: 0ms")

StatsTab:CreateSection("Aimbot")

local TargetLabel = StatsTab:CreateLabel("Target: None")
local DistLabel = StatsTab:CreateLabel("Distance: 0m")

task.spawn(function()
    while task.wait(0.5) do
        SafeCall(function()
            FPSLabel:Set("FPS: " .. PerformanceStats.FPS)
            FrameLabel:Set("Frame Time: " .. string.format("%.1f", PerformanceStats.FrameTime) .. "ms")
            
            if CombatSystem.Aimbot.CurrentTarget then
                TargetLabel:Set("Target: " .. CombatSystem.Aimbot.CurrentTarget.Name)
                DistLabel:Set("Distance: " .. math.floor(GetDistance(CombatSystem.Aimbot.CurrentTarget)) .. "m")
            else
                TargetLabel:Set("Target: None")
                DistLabel:Set("Distance: 0m")
            end
        end)
    end
end)

local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("Information")

SettingsTab:CreateLabel("FastCast Combat System")
SettingsTab:CreateLabel("Optimized for realistic games")
SettingsTab:CreateLabel("")
SettingsTab:CreateLabel("Features:")
SettingsTab:CreateLabel("✓ Fast Aimbot (No Priority)")
SettingsTab:CreateLabel("✓ Only targets players in FOV")
SettingsTab:CreateLabel("✓ Bullet drop compensation")
SettingsTab:CreateLabel("✓ Dynamic crosshair prediction")
SettingsTab:CreateLabel("✓ Box ESP with health bars")
SettingsTab:CreateLabel("✓ Blacklist system")
SettingsTab:CreateLabel("✓ 2000+ lines of code")

SettingsTab:CreateSection("Controls")

SettingsTab:CreateButton({
   Name = "Disable All",
   Callback = function()
      CombatSystem.Aimbot.Enabled = false
      CombatSystem.Crosshair.Enabled = false
      ESPEngine.Disable()
      CombatSystem.Blacklist.Enabled = false
   end,
})

SettingsTab:CreateButton({
   Name = "Destroy GUI",
   Callback = function()
      CombatSystem.Aimbot.Enabled = false
      CombatSystem.Crosshair.Enabled = false
      ESPEngine.Disable()
      DrawingLibrary:Clear()
      task.wait(0.5)
      Rayfield:Destroy()
   end,
})

-- ============================================
-- MAIN LOOP
-- ============================================

RunService.RenderStepped:Connect(function()
    SafeCall(function()
        AimbotEngine.AimAtTarget()
        AimbotEngine.UpdateFOVCircle()
        CrosshairEngine.Update()
        
        -- Track all players for better prediction
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                TargetTracking.Record(player)
            end
        end
    end)
end)

Rayfield:Notify({
   Title = "Combat System Loaded",
   Content = "FastCast optimized!",
   Duration = 5,
   Image = 4483362458,
})
