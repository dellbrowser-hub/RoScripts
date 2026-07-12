print("Parkour Leagacy script loaded , made by xsakyx for RenCore .")
print("For Devs : Everything is commented in the script to make understanding better .")
print("You can use this script for any GAME to record your self , it may have recording drift")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Player Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local camera = Workspace.CurrentCamera

-- Recording System
local Recording = {
    PointA = nil,
    PointB = nil,
    IsRecording = false,
    IsReplaying = false,
    
    -- Recording Data
    Frames = {},
    StartTime = 0,
    CurrentFrameIndex = 1,
    
    -- Stats
    RecordingDuration = 0,
    TotalFrames = 0,
    
    -- FPS Adaptive
    RecordedFPS = 60,
    CurrentFPS = 60,
    FrameTimeAccumulator = 0,
    
    -- Drift Prevention
    LastValidationFrame = 1,
    CumulativeError = 0,
    MaxAllowedDrift = 15, -- Max drift before hard reset
}

-- Replay State
local ReplayLoopEnabled = false
local ReplayLoopIteration = 0
local LastKeysPressed = {}
local DebugMode = false
local IsTransitioning = false
local ForcedResetNeeded = false

-- Connections
local recordingConnection = nil
local replayConnection = nil
local fpsTracker = nil

-- ESP/Highlight for Point B
local pointBHighlight = nil

-- FPS Tracking
local frameCount = 0
local lastFPSUpdate = tick()

-- Load RenLib UI through its compatibility facade.
local RenLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"))()
local Window = RenLib:CreateWindow({
   Name = "Parkour Recorder V2.1 - Zero Drift",
   SidebarMode = "Dynamic",
   ShowUserProfile = true,
   EnableGlobalSearch = true,
})

local SetupTab = Window:CreateTab({Name = "Setup", Icon = 6031280882})
local RecordTab = Window:CreateTab({Name = "Record", Icon = 6026663699})
local ReplayTab = Window:CreateTab({Name = "Replay", Icon = 6031260800})
local SettingsTab = Window:CreateTab({Name = "Settings", Icon = 6031280882})

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function updateCharacter()
    local success = pcall(function()
        character = player.Character
        if character then
            humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            humanoid = character:FindFirstChild("Humanoid")
        end
    end)
    return success and humanoidRootPart ~= nil
end

local function log(message, important)
    if DebugMode or important then
        print("[RECORDER V2.1] " .. message)
    end
end

local function safeCall(func, errorMessage)
    local success, err = pcall(func)
    if not success then
        warn("[RECORDER ERROR] " .. (errorMessage or "Unknown") .. ": " .. tostring(err))
    end
    return success
end

-- ============================================
-- COMPLETE STATE RESET (NEW)
-- ============================================

local function completePhysicsReset(targetCFrame)
    if not humanoidRootPart then return false end
    
    safeCall(function()
        -- Stop all movement
        humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoidRootPart.CFrame = targetCFrame
        
        -- Force physics update
        RunService.Heartbeat:Wait()
        
        -- Double-verify reset
        humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        -- Reset humanoid state
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            task.wait(0.05)
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
        
        log("Complete physics reset at: " .. tostring(targetCFrame.Position))
    end, "completePhysicsReset")
    
    return true
end

-- ============================================
-- FPS TRACKING SYSTEM
-- ============================================

local function startFPSTracking()
    if fpsTracker then return end
    
    fpsTracker = RunService.Heartbeat:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        
        if now - lastFPSUpdate >= 1 then
            Recording.CurrentFPS = frameCount / (now - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = now
        end
    end)
end

local function stopFPSTracking()
    if fpsTracker then
        fpsTracker:Disconnect()
        fpsTracker = nil
    end
end

-- ============================================
-- KEY HANDLING
-- ============================================

local function releaseAllKeys()
    safeCall(function()
        local keysToRelease = {
            Enum.KeyCode.W,
            Enum.KeyCode.A,
            Enum.KeyCode.S,
            Enum.KeyCode.D,
            Enum.KeyCode.Space,
            Enum.KeyCode.LeftShift,
            Enum.KeyCode.LeftControl
        }
        
        for _, keyCode in ipairs(keysToRelease) do
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end
        
        LastKeysPressed = {}
    end, "releaseAllKeys")
end

local function getKeysPressed()
    local keys = {}
    
    safeCall(function()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then table.insert(keys, "W") end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then table.insert(keys, "A") end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then table.insert(keys, "S") end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then table.insert(keys, "D") end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then table.insert(keys, "Space") end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then table.insert(keys, "Shift") end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then table.insert(keys, "Ctrl") end
    end, "getKeysPressed")
    
    return keys
end

local keyCodeMap = {
    W = Enum.KeyCode.W,
    A = Enum.KeyCode.A,
    S = Enum.KeyCode.S,
    D = Enum.KeyCode.D,
    Space = Enum.KeyCode.Space,
    Shift = Enum.KeyCode.LeftShift,
    Ctrl = Enum.KeyCode.LeftControl
}

local function applyKeys(keys)
    safeCall(function()
        -- Build lookup tables
        local currentKeys = {}
        for _, key in ipairs(LastKeysPressed) do
            currentKeys[key] = true
        end
        
        local newKeys = {}
        for _, key in ipairs(keys) do
            newKeys[key] = true
        end
        
        -- Release keys no longer pressed
        for _, key in ipairs(LastKeysPressed) do
            if not newKeys[key] then
                local keyCode = keyCodeMap[key]
                if keyCode then
                    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
                end
            end
        end
        
        -- Press new keys
        for _, key in ipairs(keys) do
            if not currentKeys[key] then
                local keyCode = keyCodeMap[key]
                if keyCode then
                    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                end
            end
        end
        
        LastKeysPressed = keys
    end, "applyKeys")
end

-- ============================================
-- FRAME INTERPOLATION
-- ============================================

local function interpolateFrame(frame1, frame2, alpha)
    alpha = math.clamp(alpha, 0, 1)
    
    return {
        Position = frame1.Position:Lerp(frame2.Position, alpha),
        CFrame = frame1.CFrame:Lerp(frame2.CFrame, alpha),
        CameraPosition = frame1.CameraPosition:Lerp(frame2.CameraPosition, alpha),
        CameraCFrame = frame1.CameraCFrame:Lerp(frame2.CameraCFrame, alpha),
        Velocity = frame1.Velocity:Lerp(frame2.Velocity, alpha),
        KeysPressed = alpha < 0.5 and frame1.KeysPressed or frame2.KeysPressed,
        Time = frame1.Time + (frame2.Time - frame1.Time) * alpha
    }
end

-- ============================================
-- DRIFT DETECTION & CORRECTION (NEW)
-- ============================================

local function checkAndCorrectDrift()
    if not humanoidRootPart or not Recording.Frames[Recording.CurrentFrameIndex] then 
        return false 
    end
    
    local currentPos = humanoidRootPart.Position
    local targetFrame = Recording.Frames[Recording.CurrentFrameIndex]
    local targetPos = targetFrame.Position
    local error = (targetPos - currentPos).Magnitude
    
    Recording.CumulativeError = Recording.CumulativeError + error
    
    -- Check if we need a forced reset
    if error > Recording.MaxAllowedDrift then
        log("⚠️ CRITICAL DRIFT: " .. math.floor(error) .. " studs - FORCE RESET", true)
        ForcedResetNeeded = true
        return false
    end
    
    -- Aggressive correction for medium errors
    if error > 8 then
        log("⚠️ Drift detected: " .. math.floor(error) .. " studs - Correcting", DebugMode)
        
        -- Hard position correction
        humanoidRootPart.CFrame = targetFrame.CFrame
        humanoidRootPart.AssemblyLinearVelocity = targetFrame.Velocity
        humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        return true
    end
    
    -- Soft correction for small errors
    if error > 3 then
        local direction = (targetPos - currentPos).Unit
        humanoidRootPart.AssemblyLinearVelocity = humanoidRootPart.AssemblyLinearVelocity + (direction * error * 2)
    end
    
    return true
end

-- ============================================
-- ESP SYSTEM
-- ============================================

local function createPointBHighlight()
    safeCall(function()
        if pointBHighlight then
            pointBHighlight:Destroy()
        end
        
        if not Recording.PointB then return end
        
        local highlightPart = Instance.new("Part")
        highlightPart.Name = "PointBMarker"
        highlightPart.Size = Vector3.new(5, 10, 5)
        highlightPart.Position = Recording.PointB
        highlightPart.Anchored = true
        highlightPart.CanCollide = false
        highlightPart.Transparency = 0.5
        highlightPart.Color = Color3.fromRGB(0, 255, 0)
        highlightPart.Material = Enum.Material.Neon
        highlightPart.Parent = Workspace
        
        local highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(0, 255, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = highlightPart
        
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Size = UDim2.new(0, 200, 0, 50)
        billboardGui.StudsOffset = Vector3.new(0, 5, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.Parent = highlightPart
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "POINT B - GO HERE!"
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.GothamBold
        textLabel.Parent = billboardGui
        
        pointBHighlight = highlightPart
        log("Point B ESP created!")
    end, "createPointBHighlight")
end

local function removePointBHighlight()
    safeCall(function()
        if pointBHighlight then
            pointBHighlight:Destroy()
            pointBHighlight = nil
        end
    end, "removePointBHighlight")
end

-- ============================================
-- RECORDING SYSTEM
-- ============================================

local function startRecording()
    if not Recording.PointA or not Recording.PointB then
        log("ERROR: Set Point A and Point B first!", true)
        return false
    end
    
    if Recording.IsRecording then
        log("Already recording!", true)
        return false
    end
    
    log("Starting recording...", true)
    
    -- Clear previous recording
    Recording.Frames = {}
    Recording.StartTime = tick()
    Recording.IsRecording = true
    Recording.CurrentFrameIndex = 1
    Recording.RecordedFPS = Recording.CurrentFPS
    Recording.CumulativeError = 0
    
    -- Complete reset and teleport to Point A
    safeCall(function()
        if humanoidRootPart then
            completePhysicsReset(CFrame.new(Recording.PointA))
            task.wait(0.3)
            log("Teleported to Point A")
        end
    end, "startRecording teleport")
    
    -- Create ESP
    createPointBHighlight()
    
    -- Start FPS tracking
    startFPSTracking()
    
    -- Start recording
    local lastFrameTime = tick()
    
    recordingConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not Recording.IsRecording then return end
        
        safeCall(function()
            if not updateCharacter() then return end
            
            local currentTime = tick()
            local frameTime = currentTime - lastFrameTime
            lastFrameTime = currentTime
            
            -- Record frame
            local frameData = {
                Time = currentTime - Recording.StartTime,
                DeltaTime = frameTime,
                Position = humanoidRootPart.Position,
                CFrame = humanoidRootPart.CFrame,
                CameraPosition = camera.CFrame.Position,
                CameraCFrame = camera.CFrame,
                Velocity = humanoidRootPart.AssemblyLinearVelocity,
                AngularVelocity = humanoidRootPart.AssemblyAngularVelocity,
                KeysPressed = getKeysPressed(),
                FPS = Recording.CurrentFPS
            }
            
            table.insert(Recording.Frames, frameData)
            
            -- Check if reached Point B
            local distanceToB = (Recording.PointB - humanoidRootPart.Position).Magnitude
            
            if distanceToB < 8 then
                stopRecording()
                log("Recording complete! " .. #Recording.Frames .. " frames recorded", true)
                log("Average FPS: " .. math.floor(Recording.RecordedFPS), true)
                
                RenLib:Notify({
                   Title = "Recording Complete",
                   Content = "Recorded " .. #Recording.Frames .. " frames @ " .. math.floor(Recording.RecordedFPS) .. " FPS",
                   Duration = 5,
                   Image = 4483362458,
                })
            end
        end, "recordingConnection")
    end)
    
    log("Recording started! Go to Point B!")
    return true
end

local function stopRecording()
    Recording.IsRecording = false
    
    if recordingConnection then
        recordingConnection:Disconnect()
        recordingConnection = nil
    end
    
    Recording.RecordingDuration = tick() - Recording.StartTime
    Recording.TotalFrames = #Recording.Frames
    
    removePointBHighlight()
    releaseAllKeys()
    
    log("Recording stopped. Total: " .. Recording.TotalFrames .. " frames in " .. string.format("%.2f", Recording.RecordingDuration) .. "s")
end

-- ============================================
-- REPLAY SYSTEM (ENHANCED WITH DRIFT PREVENTION)
-- ============================================

local function startReplay()
    if #Recording.Frames == 0 then
        log("ERROR: No recording to replay!", true)
        return false
    end
    
    if Recording.IsReplaying then
        log("Already replaying!", true)
        return false
    end
    
    log("Starting zero-drift replay with " .. #Recording.Frames .. " frames...", true)
    
    Recording.IsReplaying = true
    Recording.CurrentFrameIndex = 1
    Recording.FrameTimeAccumulator = 0
    Recording.CumulativeError = 0
    Recording.LastValidationFrame = 1
    ForcedResetNeeded = false
    IsTransitioning = true
    
    -- COMPLETE RESET to Point A
    safeCall(function()
        if humanoidRootPart and Recording.PointA then
            -- Stop all keys
            releaseAllKeys()
            
            -- Complete physics reset
            completePhysicsReset(CFrame.new(Recording.PointA))
            
            -- Extra settling time
            task.wait(0.4)
            
            -- Verify reset
            local distToStart = (Recording.PointA - humanoidRootPart.Position).Magnitude
            if distToStart > 2 then
                log("⚠️ Reset verification failed, re-resetting...", true)
                completePhysicsReset(CFrame.new(Recording.PointA))
                task.wait(0.2)
            end
            
            IsTransitioning = false
            log("✓ Perfect reset at Point A - Starting replay!", true)
        end
    end, "startReplay reset")
    
    local replayStartTime = tick()
    local lastCorrectionTime = 0
    local correctionInterval = 0.15 -- Check every 150ms for tighter control
    local consecutiveErrors = 0
    local maxConsecutiveErrors = 5
    
    -- Enhanced FPS-adaptive replay
    replayConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not Recording.IsReplaying or IsTransitioning then return end
        
        -- Check if forced reset needed
        if ForcedResetNeeded then
            log("🔄 Forced reset triggered", true)
            stopReplay()
            return
        end
        
        safeCall(function()
            if not updateCharacter() then 
                consecutiveErrors = consecutiveErrors + 1
                if consecutiveErrors >= maxConsecutiveErrors then
                    log("Too many errors, stopping replay", true)
                    stopReplay()
                end
                return 
            end
            
            consecutiveErrors = 0
            
            -- Accumulate time for FPS adaptation
            Recording.FrameTimeAccumulator = Recording.FrameTimeAccumulator + deltaTime
            
            -- Get frames
            local currentFrameIndex = Recording.CurrentFrameIndex
            local nextFrameIndex = math.min(currentFrameIndex + 1, #Recording.Frames)
            
            if currentFrameIndex >= #Recording.Frames then
                log("✓ Replay complete! Reached end", true)
                stopReplay()
                return
            end
            
            local currentFrame = Recording.Frames[currentFrameIndex]
            local nextFrame = Recording.Frames[nextFrameIndex]
            
            -- Calculate frame time
            local expectedFrameTime = nextFrame.Time - currentFrame.Time
            
            -- Advance frame if needed
            if Recording.FrameTimeAccumulator >= expectedFrameTime then
                Recording.FrameTimeAccumulator = Recording.FrameTimeAccumulator - expectedFrameTime
                Recording.CurrentFrameIndex = nextFrameIndex
                
                -- Clamp accumulator
                if Recording.FrameTimeAccumulator > expectedFrameTime * 2 then
                    Recording.FrameTimeAccumulator = expectedFrameTime
                end
            end
            
            -- Interpolate between frames
            local alpha = 0
            if expectedFrameTime > 0 then
                alpha = math.clamp(Recording.FrameTimeAccumulator / expectedFrameTime, 0, 1)
            end
            
            local interpolatedFrame = interpolateFrame(currentFrame, nextFrame, alpha)
            
            -- Apply camera
            camera.CFrame = interpolatedFrame.CameraCFrame
            
            -- Apply keys
            applyKeys(interpolatedFrame.KeysPressed)
            
            -- AGGRESSIVE POSITION VALIDATION
            local currentTime = tick()
            if currentTime - lastCorrectionTime >= correctionInterval then
                lastCorrectionTime = currentTime
                
                local currentPos = humanoidRootPart.Position
                local targetPos = interpolatedFrame.Position
                local positionError = (targetPos - currentPos).Magnitude
                
                -- Critical drift - hard reset
                if positionError > 20 then
                    log("🚨 CRITICAL: " .. math.floor(positionError) .. " studs - HARD RESET", true)
                    humanoidRootPart.CFrame = interpolatedFrame.CFrame
                    humanoidRootPart.AssemblyLinearVelocity = interpolatedFrame.Velocity
                    humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    
                -- Major drift - position + velocity correction
                elseif positionError > 8 then
                    log("⚠️ Major drift: " .. math.floor(positionError) .. " studs", DebugMode)
                    humanoidRootPart.CFrame = interpolatedFrame.CFrame
                    humanoidRootPart.AssemblyLinearVelocity = interpolatedFrame.Velocity
                    
                -- Medium drift - CFrame correction only
                elseif positionError > 4 then
                    log("⚠️ Medium drift: " .. math.floor(positionError) .. " studs", DebugMode)
                    local lerpFactor = 0.7
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(interpolatedFrame.CFrame, lerpFactor)
                    humanoidRootPart.AssemblyLinearVelocity = interpolatedFrame.Velocity * 0.8
                    
                -- Small drift - velocity nudge
                elseif positionError > 2 then
                    local velocityCorrection = (targetPos - currentPos).Unit * (positionError * 3)
                    humanoidRootPart.AssemblyLinearVelocity = humanoidRootPart.AssemblyLinearVelocity + velocityCorrection
                end
            end
            
            -- Periodic full sync (every 30 frames) to prevent cumulative drift
            if Recording.CurrentFrameIndex % 30 == 0 and Recording.CurrentFrameIndex ~= Recording.LastValidationFrame then
                Recording.LastValidationFrame = Recording.CurrentFrameIndex
                
                local syncFrame = Recording.Frames[Recording.CurrentFrameIndex]
                local syncError = (syncFrame.Position - humanoidRootPart.Position).Magnitude
                
                if syncError > 5 then
                    log("🔄 Periodic sync: " .. math.floor(syncError) .. " studs error", DebugMode)
                    humanoidRootPart.CFrame = syncFrame.CFrame
                    humanoidRootPart.AssemblyLinearVelocity = syncFrame.Velocity
                    humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
            
        end, "replayConnection")
    end)
    
    log("Replay started with enhanced drift prevention!")
    return true
end

local function stopReplay()
    if not Recording.IsReplaying then return end
    
    Recording.IsReplaying = false
    IsTransitioning = true
    
    if replayConnection then
        replayConnection:Disconnect()
        replayConnection = nil
    end
    
    releaseAllKeys()
    
    task.wait(0.1)
    IsTransitioning = false
    
    log("Replay stopped cleanly")
end

-- ============================================
-- LOOP SYSTEM (ENHANCED WITH ZERO-DRIFT)
-- ============================================

local loopCoroutine = nil

local function startReplayLoop()
    if loopCoroutine then
        log("Loop already running!", true)
        return
    end
    
    log("Starting zero-drift loop system...", true)
    
    loopCoroutine = task.spawn(function()
        while ReplayLoopEnabled do
            if not ReplayLoopEnabled then break end
            
            ReplayLoopIteration = ReplayLoopIteration + 1
            log("=== Loop #" .. ReplayLoopIteration .. " ===", true)
            
            -- Ensure completely clean state
            if Recording.IsReplaying then
                log("Cleaning up previous replay...", true)
                stopReplay()
                task.wait(0.5)
            end
            
            -- CRITICAL: Complete reset before each loop
            safeCall(function()
                if humanoidRootPart and Recording.PointA then
                    IsTransitioning = true
                    releaseAllKeys()
                    
                    -- Triple-verified reset
                    completePhysicsReset(CFrame.new(Recording.PointA))
                    task.wait(0.3)
                    
                    -- Verify reset quality
                    local resetError = (Recording.PointA - humanoidRootPart.Position).Magnitude
                    if resetError > 1 then
                        log("⚠️ Reset not perfect (" .. math.floor(resetError) .. "s), re-resetting...", true)
                        completePhysicsReset(CFrame.new(Recording.PointA))
                        task.wait(0.2)
                    end
                    
                    IsTransitioning = false
                    log("✓ Perfect reset for loop #" .. ReplayLoopIteration, true)
                end
            end, "loop reset")
            
            task.wait(0.2)
            
            -- Start replay
            local success = startReplay()
            
            if not success then
                log("Failed to start replay, retrying in 3s...", true)
                task.wait(3)
                continue
            end
            
            -- Wait for completion with timeout
            local replayTimeout = (Recording.RecordingDuration or 30) + 15
            local replayStartTime = tick()
            
            while Recording.IsReplaying and ReplayLoopEnabled do
                -- Timeout check
                if tick() - replayStartTime > replayTimeout then
                    log("⚠️ Replay timeout! Forcing stop...", true)
                    stopReplay()
                    break
                end
                
                -- Check if forced reset was triggered
                if ForcedResetNeeded then
                    log("⚠️ Forced reset detected, stopping this iteration", true)
                    stopReplay()
                    break
                end
                
                task.wait(0.1)
            end
            
            -- Check loop status
            if not ReplayLoopEnabled then
                log("Loop disabled, exiting", true)
                break
            end
            
            log("✓ Loop #" .. ReplayLoopIteration .. " complete", true)
            
            -- Ensure stopped
            if Recording.IsReplaying then
                stopReplay()
            end
            
            -- Delay between loops
            task.wait(1.5)
        end
        
        log("Loop system ended. Total: " .. ReplayLoopIteration .. " loops", true)
        loopCoroutine = nil
    end)
end

local function stopReplayLoop()
    ReplayLoopEnabled = false
    
    if Recording.IsReplaying then
        stopReplay()
    end
    
    if loopCoroutine then
        task.wait(1)
        loopCoroutine = nil
    end
    
    log("Loop system stopped", true)
end

-- ============================================
-- DEATH HANDLER
-- ============================================

local function setupDeathHandler()
    humanoid.Died:Connect(function()
        if Recording.IsReplaying or ReplayLoopEnabled then
            log("Died during replay!", true)
            
            stopReplay()
            
            task.wait(1)
            
            safeCall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.T, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.T, false, game)
            end, "respawn key")
            
            log("Respawning...")
        end
    end)
end

player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    
    safeCall(function()
        character = newChar
        humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        humanoid = newChar:WaitForChild("Humanoid")
        
        log("Character respawned", true)
        
        setupDeathHandler()
        
        if ReplayLoopEnabled and not Recording.IsReplaying then
            log("Resuming loop after respawn...", true)
            task.wait(2)
            if ReplayLoopEnabled then
                startReplay()
            end
        end
    end, "CharacterAdded")
end)

setupDeathHandler()

-- ============================================
-- UI: SETUP TAB
-- ============================================

local SetupSection1 = SetupTab:CreateSection({Name = "Point Selection", Side = "Left"})

local PointALabel = SetupSection1:CreateLabel("Point A: Not Set")
local PointBLabel = SetupSection1:CreateLabel("Point B: Not Set")

SetupSection1:CreateButton({
   Name = "Select Point A (Current Position)",
   Callback = function()
      safeCall(function()
         if humanoidRootPart then
            Recording.PointA = humanoidRootPart.Position
            PointALabel:SetText("Point A: Set ✓")
            
            RenLib:Notify({
               Title = "Point A Set",
               Content = "Start position saved!",
               Duration = 3,
               Image = 4483362458,
            })
         end
      end, "Select Point A")
   end,
})

SetupSection1:CreateButton({
   Name = "Select Point B (Current Position)",
   Callback = function()
      safeCall(function()
         if humanoidRootPart then
            Recording.PointB = humanoidRootPart.Position
            PointBLabel:SetText("Point B: Set ✓")
            
            RenLib:Notify({
               Title = "Point B Set",
               Content = "End position saved!",
               Duration = 3,
               Image = 4483362458,
            })
         end
      end, "Select Point B")
   end,
})

SetupSection1:CreateButton({
   Name = "Clear Points",
   Callback = function()
      Recording.PointA = nil
      Recording.PointB = nil
      PointALabel:SetText("Point A: Not Set")
      PointBLabel:SetText("Point B: Not Set")
      removePointBHighlight()
      
      RenLib:Notify({
         Title = "Points Cleared",
         Content = "Reset point selection",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

local SetupSection2 = SetupTab:CreateSection({Name = "Info", Side = "Right"})

local DistanceLabel = SetupSection2:CreateLabel("Distance: N/A")
local CurrentFPSLabel = SetupSection2:CreateLabel("Current FPS: 60")

task.spawn(function()
    while task.wait(1) do
        safeCall(function()
            if Recording.PointA and Recording.PointB then
                local dist = (Recording.PointB - Recording.PointA).Magnitude
                DistanceLabel:SetText("Distance: " .. math.floor(dist) .. " studs")
            else
                DistanceLabel:SetText("Distance: N/A")
            end
            
            CurrentFPSLabel:SetText("Current FPS: " .. math.floor(Recording.CurrentFPS))
        end, "info update")
    end
end)

-- ============================================
-- UI: RECORD TAB
-- ============================================

local RecordSection1 = RecordTab:CreateSection({Name = "Recording", Side = "Left"})

local RecordStatusLabel = RecordSection1:CreateLabel("Status: Not Recording")
local FramesLabel = RecordSection1:CreateLabel("Frames: 0")
local RecordedFPSLabel = RecordSection1:CreateLabel("Recording FPS: N/A")

RecordSection1:CreateButton({
   Name = "Start Path Training",
   Callback = function()
      if not Recording.PointA or not Recording.PointB then
         RenLib:Notify({
            Title = "Error",
            Content = "Set Point A and Point B first!",
            Duration = 3,
            Image = 4483362458,
         })
         return
      end
      
      if Recording.IsReplaying or ReplayLoopEnabled then
         RenLib:Notify({
            Title = "Error",
            Content = "Stop replay first!",
            Duration = 3,
            Image = 4483362458,
         })
         return
      end
      
      if startRecording() then
         RenLib:Notify({
            Title = "Recording Started",
            Content = "Follow the green marker to Point B!",
            Duration = 5,
            Image = 4483362458,
         })
      end
   end,
})

RecordSection1:CreateButton({
   Name = "Stop Recording",
   Callback = function()
      if Recording.IsRecording then
         stopRecording()
         RenLib:Notify({
            Title = "Recording Stopped",
            Content = "Saved " .. Recording.TotalFrames .. " frames",
            Duration = 3,
            Image = 4483362458,
         })
      else
         RenLib:Notify({
            Title = "Not Recording",
            Content = "No active recording to stop",
            Duration = 2,
            Image = 4483362458,
         })
      end
   end,
})

task.spawn(function()
    while task.wait(0.5) do
        safeCall(function()
            if Recording.IsRecording then
                RecordStatusLabel:SetText("Status: 🔴 RECORDING")
                FramesLabel:SetText("Frames: " .. #Recording.Frames)
                RecordedFPSLabel:SetText("Recording FPS: " .. math.floor(Recording.CurrentFPS))
            else
                RecordStatusLabel:SetText("Status: Not Recording")
                FramesLabel:SetText("Frames: " .. Recording.TotalFrames)
                if Recording.TotalFrames > 0 then
                    RecordedFPSLabel:SetText("Recorded @ " .. math.floor(Recording.RecordedFPS) .. " FPS")
                else
                    RecordedFPSLabel:SetText("Recording FPS: N/A")
                end
            end
        end, "record tab update")
    end
end)

-- ============================================
-- UI: REPLAY TAB
-- ============================================

local ReplaySection1 = ReplayTab:CreateSection({Name = "Replay Control", Side = "Left"})

local ReplayStatusLabel = ReplaySection1:CreateLabel("Status: Idle")
local LoopCountLabel = ReplaySection1:CreateLabel("Loops: 0")
local ProgressLabel = ReplaySection1:CreateLabel("Progress: 0%")
local PositionErrorLabel = ReplaySection1:CreateLabel("Drift: 0 studs")
local DriftStatusLabel = ReplaySection1:CreateLabel("Drift Status: ✓ Perfect")

ReplaySection1:CreateToggle({
   Name = "Enable Replay Loop",
   Default = false,
   Flag = "ReplayLoop",
   Callback = function(Value)
      if Value then
         if #Recording.Frames == 0 then
            RenLib:Notify({
               Title = "Error",
               Content = "No recording to replay!",
               Duration = 3,
               Image = 4483362458,
            })
            return
         end
         
         if Recording.IsRecording then
            RenLib:Notify({
               Title = "Error",
               Content = "Stop recording first!",
               Duration = 3,
               Image = 4483362458,
            })
            return
         end
         
         ReplayLoopEnabled = true
         ReplayLoopIteration = 0
         startReplayLoop()
         
         RenLib:Notify({
            Title = "Loop Started",
            Content = "Zero-drift loop activated!",
            Duration = 3,
            Image = 4483362458,
         })
      else
         stopReplayLoop()
         
         RenLib:Notify({
            Title = "Loop Stopped",
            Content = "Completed " .. ReplayLoopIteration .. " loops",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

ReplaySection1:CreateButton({
   Name = "Replay Once",
   Callback = function()
      if #Recording.Frames == 0 then
         RenLib:Notify({
            Title = "Error",
            Content = "No recording to replay!",
            Duration = 3,
            Image = 4483362458,
         })
         return
      end
      
      if Recording.IsRecording then
         RenLib:Notify({
            Title = "Error",
            Content = "Stop recording first!",
            Duration = 3,
            Image = 4483362458,
         })
         return
      end
      
      if ReplayLoopEnabled then
         RenLib:Notify({
            Title = "Error",
            Content = "Disable loop first!",
            Duration = 3,
            Image = 4483362458,
         })
         return
      end
      
      if startReplay() then
         RenLib:Notify({
            Title = "Replaying",
            Content = "Zero-drift playback active!",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

ReplaySection1:CreateButton({
   Name = "Stop Replay",
   Callback = function()
      if Recording.IsReplaying then
         stopReplay()
         RenLib:Notify({
            Title = "Stopped",
            Content = "Replay stopped",
            Duration = 2,
            Image = 4483362458,
         })
      end
   end,
})

local ReplaySection2 = ReplayTab:CreateSection({Name = "Statistics", Side = "Right"})

task.spawn(function()
    while task.wait(0.2) do
        safeCall(function()
            if Recording.IsReplaying then
                local progress = 0
                if Recording.TotalFrames > 0 then
                    progress = (Recording.CurrentFrameIndex / Recording.TotalFrames) * 100
                end
                
                local statusText = "Status: 🟢 REPLAYING"
                if ReplayLoopEnabled then
                    statusText = statusText .. " (Loop #" .. ReplayLoopIteration .. ")"
                end
                ReplayStatusLabel:SetText(statusText)
                
                ProgressLabel:SetText("Progress: " .. math.floor(progress) .. "% (" .. Recording.CurrentFrameIndex .. "/" .. Recording.TotalFrames .. ")")
                
                -- Show drift
                if humanoidRootPart and Recording.Frames[Recording.CurrentFrameIndex] then
                    local targetPos = Recording.Frames[Recording.CurrentFrameIndex].Position
                    local currentPos = humanoidRootPart.Position
                    local error = (targetPos - currentPos).Magnitude
                    
                    PositionErrorLabel:SetText("Drift: " .. string.format("%.1f", error) .. " studs")
                    
                    if error < 2 then
                        DriftStatusLabel:SetText("Drift Status: ✓ Perfect")
                    elseif error < 5 then
                        DriftStatusLabel:SetText("Drift Status: ⚠️ Minor")
                    elseif error < 10 then
                        DriftStatusLabel:SetText("Drift Status: ⚠️ Medium")
                    else
                        DriftStatusLabel:SetText("Drift Status: 🚨 Critical")
                    end
                end
                
            elseif ReplayLoopEnabled then
                ReplayStatusLabel:SetText("Status: ⏳ Resetting...")
                ProgressLabel:SetText("Progress: 0%")
                PositionErrorLabel:SetText("Drift: 0 studs")
                DriftStatusLabel:SetText("Drift Status: ✓ Perfect")
            else
                ReplayStatusLabel:SetText("Status: Idle")
                ProgressLabel:SetText("Progress: 0%")
                PositionErrorLabel:SetText("Drift: 0 studs")
                DriftStatusLabel:SetText("Drift Status: ✓ Perfect")
            end
            
            LoopCountLabel:SetText("Loops: " .. ReplayLoopIteration)
        end, "replay tab update")
    end
end)

-- ============================================
-- UI: SETTINGS TAB
-- ============================================

local SettingsSection1 = SettingsTab:CreateSection({Name = "Debug", Side = "Left"})

SettingsSection1:CreateToggle({
   Name = "Debug Mode (Console Output)",
   Default = false,
   Flag = "Debug",
   Callback = function(Value)
      DebugMode = Value
      
      if Value then
         log("Debug mode ENABLED - Check console (F9)", true)
      else
         log("Debug mode DISABLED", true)
      end
   end,
})

SettingsSection1:CreateButton({
   Name = "Print Recording Stats",
   Callback = function()
      if Recording.TotalFrames > 0 then
         print("=== RECORDING STATS ===")
         print("Total Frames: " .. Recording.TotalFrames)
         print("Duration: " .. string.format("%.2f", Recording.RecordingDuration) .. "s")
         print("Recorded FPS: " .. math.floor(Recording.RecordedFPS))
         print("Distance: " .. math.floor((Recording.PointB - Recording.PointA).Magnitude) .. " studs")
         print("=====================")
         
         RenLib:Notify({
            Title = "Stats Printed",
            Content = "Check console (F9)",
            Duration = 2,
            Image = 4483362458,
         })
      else
         RenLib:Notify({
            Title = "No Recording",
            Content = "Record a path first!",
            Duration = 2,
            Image = 4483362458,
         })
      end
   end,
})

local SettingsSection2 = SettingsTab:CreateSection({Name = "Advanced Settings", Side = "Right"})

local DriftToleranceSlider = SettingsSection2:CreateSlider({
   Name = "Max Drift Before Reset (studs)",
   Min = 10,
   Max = 30,
   Step = 1,
   Default = 15,
   Flag = "DriftTolerance",
   Callback = function(Value)
      Recording.MaxAllowedDrift = Value
      log("Max drift tolerance set to: " .. Value .. " studs", true)
   end,
})

local SettingsSection3 = SettingsTab:CreateSection({Name = "Controls", Side = "Left"})

SettingsSection3:CreateButton({
   Name = "🛑 EMERGENCY STOP",
   Callback = function()
      ReplayLoopEnabled = false
      stopRecording()
      stopReplay()
      stopReplayLoop()
      releaseAllKeys()
      removePointBHighlight()
      
      RenLib:Notify({
         Title = "Emergency Stop",
         Content = "All systems stopped!",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

SettingsSection3:CreateButton({
   Name = "Clear Recording Data",
   Callback = function()
      if Recording.IsReplaying or Recording.IsRecording or ReplayLoopEnabled then
         RenLib:Notify({
            Title = "Error",
            Content = "Stop all actions first!",
            Duration = 3,
            Image = 4483362458,
         })
         return
      end
      
      Recording.Frames = {}
      Recording.TotalFrames = 0
      Recording.RecordingDuration = 0
      Recording.RecordedFPS = 60
      ReplayLoopIteration = 0
      
      RenLib:Notify({
         Title = "Data Cleared",
         Content = "Recording deleted",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

SettingsSection3:CreateButton({
   Name = "Teleport to Point A",
   Callback = function()
      safeCall(function()
         if Recording.PointA and humanoidRootPart then
            completePhysicsReset(CFrame.new(Recording.PointA))
            
            RenLib:Notify({
               Title = "Teleported",
               Content = "Moved to Point A",
               Duration = 2,
               Image = 4483362458,
            })
         else
            RenLib:Notify({
               Title = "Error",
               Content = "Set Point A first!",
               Duration = 2,
               Image = 4483362458,
            })
         end
      end, "teleport to A")
   end,
})

SettingsSection3:CreateButton({
   Name = "Teleport to Point B",
   Callback = function()
      safeCall(function()
         if Recording.PointB and humanoidRootPart then
            completePhysicsReset(CFrame.new(Recording.PointB))
            
            RenLib:Notify({
               Title = "Teleported",
               Content = "Moved to Point B",
               Duration = 2,
               Image = 4483362458,
            })
         else
            RenLib:Notify({
               Title = "Error",
               Content = "Set Point B first!",
               Duration = 2,
               Image = 4483362458,
            })
         end
      end, "teleport to B")
   end,
})

local SettingsSection4 = SettingsTab:CreateSection({Name = "GUI", Side = "Right"})

SettingsSection4:CreateButton({
   Name = "Destroy GUI",
   Callback = function()
      ReplayLoopEnabled = false
      stopRecording()
      stopReplay()
      stopReplayLoop()
      stopFPSTracking()
      releaseAllKeys()
      removePointBHighlight()
      
      task.wait(0.5)
      RenLib:Unload("script cleanup")
   end,
})

-- Start systems
startFPSTracking()

-- Load notification
RenLib:Notify({
   Title = "V2.1 Loaded",
   Content = "Perfect loop stability ready!",
   Duration = 5,
   Image = 4483362458,
})
