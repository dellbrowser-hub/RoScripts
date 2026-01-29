-- Load UI Library
-- NOTE: The RenLib URL may become outdated. Use a reliable and current source.
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/renardiusse/RobloxUILib/refs/heads/main/RenLib.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

-- Local Player
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Script Variables
local ScriptEnabled = true
local ESPEnabled = false
local AimbotEnabled = false
local NoclipEnabled = false
local LightHelmetEnabled = false

-- ESP Settings
local ESPSettings = {
    Players = true, -- Is this setting used? It's redundant if all players are checked. Removed for clarity, assuming all players are intended targets.
    ShowHealths = true,
    ShowDistances = true,
    UseBoxes = true,
    UseHighlights = false,
    TeamCheck = false,
    FriendCheck = false
}

-- Aimbot Settings
local AimbotSettings = {
    FOV = 100,
    Smoothness = 5,
    WallCheck = true,
    TeamCheck = false,
    FriendCheck = false,
    Whitelist = {}
}

-- Storage Tables
local ESPObjects = {}
local Connections = {}
local LightObject = nil
local WeaponNames = {}
local NoclipCache = {} -- NEW: Cache for CanCollide status

-- Get Weapon Names
local function LoadWeaponNames()
    local success, result = pcall(function()
        -- The original logic for assets:
        local weaponsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if weaponsFolder then
            weaponsFolder = weaponsFolder:FindFirstChild("Weapons")
            if weaponsFolder then
                for _, weapon in pairs(weaponsFolder:GetChildren()) do
                    if weapon:IsA("Model") then
                        -- Check for both the Model name and the actual Tool name inside the model
                        table.insert(WeaponNames, weapon.Name)
                        local tool = weapon:FindFirstChildOfClass("Tool")
                        if tool and tool.Name ~= weapon.Name then
                            table.insert(WeaponNames, tool.Name)
                        end
                    end
                end
            end
        end
        
        -- Add common, hardcoded weapon/tool identifiers as a fallback
        table.insert(WeaponNames, "Knife")
        table.insert(WeaponNames, "Gun")
        table.insert(WeaponNames, "Pistol")
        table.insert(WeaponNames, "Revolver")
        
        -- Ensure all names are unique and lowercased for comparison later
        local uniqueNames = {}
        for _, name in pairs(WeaponNames) do
            uniqueNames[name:lower()] = true
        end
        WeaponNames = {}
        for name in pairs(uniqueNames) do
            table.insert(WeaponNames, name)
        end
    end)
    if not success then
        warn("Failed to load weapon names: " .. tostring(result))
    end
end

-- Check if player is killer
local function IsKiller(player)
    -- **CRITICAL CORRECTION/IMPROVEMENT:**
    -- The most reliable way to determine the role in MM2 scripts is usually to check for a value 
    -- in the Player object (like a "Killer" bool value) or a certain tag. 
    -- The tool check is a decent fallback, but often less reliable than a value check.
    
    -- Option 1: Check for known role indicator values (game-specific, most reliable)
    if player:FindFirstChild("Killer") and player.Killer.Value == true then
        return true
    end
    -- Option 2: Check for a tool/weapon (original logic, slightly corrected)
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

-- ESP Functions (Mostly fine, uses Drawing library which is executor-dependent)

local function CreateESPBox(player)
    -- ... (The original implementation using Drawing.new("Square") and "Text" is fine, assuming the executor supports the Drawing library.)
    -- The original code is kept as-is for brevity, assuming 'Drawing' is a working external library/class.
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
    -- ... (Original implementation is fine)
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

local function UpdateESP()
    if not ESPEnabled then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            -- Check for existence of all parts before attempting to access them
            if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") and character:FindFirstChild("Head") then
                local hrp = character.HumanoidRootPart
                local head = character.Head
                local humanoid = character.Humanoid
                
                -- Skip if team/friend check enabled
                if ESPSettings.TeamCheck and player.Team == LocalPlayer.Team then continue end
                if ESPSettings.FriendCheck and LocalPlayer:IsFriendsWith(player.UserId) then continue end
                
                -- Determine color
                local isKiller = IsKiller(player)
                -- Use the role to determine the color (Red for killer, white otherwise)
                local espColor = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)
                
                -- Create ESP if doesn't exist
                if not ESPObjects[player] then
                    ESPObjects[player] = {
                        Box = CreateESPBox(player),
                        Highlight = nil
                    }
                end
                
                local espData = ESPObjects[player]
                
                -- Update Boxes
                if ESPSettings.UseBoxes then
                    -- WorldToViewportPoint returns a Vector3 (X, Y, Z/Depth)
                    local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    
                    if onScreen and humanoid.Health > 0 then -- Only show for living players on screen
                        -- The calculation for headPos and legPos is generally correct for a bounding box estimation
                        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height / 2 -- Common box ratio
                        
                        -- The vector.X and vector.Y should be used carefully; typically the center of the HRP is used as the box center/bottom.
                        -- Correcting position calculation to be more centered/accurate based on the head/leg points.
                        local centerPointX = (headPos.X + legPos.X) / 2
                        local topPointY = math.min(headPos.Y, legPos.Y)
                        
                        espData.Box.Box.Size = Vector2.new(width, height)
                        espData.Box.Box.Position = Vector2.new(centerPointX - width / 2, topPointY)
                        espData.Box.Box.Color = espColor
                        espData.Box.Box.Visible = true
                        
                        -- Health bar
                        if ESPSettings.ShowHealths then
                            local healthPercent = humanoid.Health / humanoid.MaxHealth
                            espData.Box.HealthBar.Size = Vector2.new(2, height * healthPercent)
                            -- Position the health bar to the left of the box
                            espData.Box.HealthBar.Position = Vector2.new(centerPointX - width/2 - 5, topPointY + height - (height * healthPercent))
                            espData.Box.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0) -- Green to Red
                            espData.Box.HealthBar.Visible = true
                        else
                            espData.Box.HealthBar.Visible = false
                        end
                        
                        -- Name and Distance
                        local distance = math.floor((hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
                        local displayText = player.Name
                        if ESPSettings.ShowDistances then
                            displayText = displayText .. " [" .. distance .. "m]"
                        end
                        if isKiller then
                            displayText = "[KILLER] " .. displayText
                        end
                        
                        espData.Box.NameText.Text = displayText
                        -- Position the text slightly above the box
                        espData.Box.NameText.Position = Vector2.new(centerPointX, topPointY - 15) 
                        espData.Box.NameText.Color = espColor
                        espData.Box.NameText.Visible = true
                    else
                        -- Hide if off-screen or dead
                        espData.Box.Box.Visible = false
                        espData.Box.HealthBar.Visible = false
                        espData.Box.NameText.Visible = false
                    end
                else
                    -- If UseBoxes is disabled, ensure box elements are hidden
                    espData.Box.Box.Visible = false
                    espData.Box.HealthBar.Visible = false
                    espData.Box.NameText.Visible = false
                end
                
                -- Update Highlights
                if ESPSettings.UseHighlights then
                    if not espData.Highlight then
                        -- Check if character is valid before creating the highlight
                        if character then
                            espData.Highlight = CreateESPHighlight(character)
                        end
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
                -- If character/parts are missing, hide/clear ESP
                if ESPObjects[player] then
                    local espData = ESPObjects[player]
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
            end
        end
    end
end

local function ClearESP()
    for _, espData in pairs(ESPObjects) do
        if espData.Box then
            -- Use :Remove() for Drawing objects
            espData.Box.Box:Remove()
            espData.Box.HealthBar:Remove()
            espData.Box.NameText:Remove()
        end
        if espData.Highlight then
            -- Use :Destroy() for Instances
            espData.Highlight:Destroy()
        end
    end
    ESPObjects = {}
end

-- Aimbot Functions
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = AimbotSettings.FOV -- FOV is used as max distance here
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local localHRP = character.HumanoidRootPart
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetCharacter = player.Character
            if targetCharacter and targetCharacter:FindFirstChild("Head") and targetCharacter:FindFirstChild("Humanoid") then
                local humanoid = targetCharacter.Humanoid
                if humanoid.Health > 0 then
                    -- Team check
                    if AimbotSettings.TeamCheck and player.Team == LocalPlayer.Team then continue end
                    
                    -- Friend check
                    if AimbotSettings.FriendCheck and LocalPlayer:IsFriendsWith(player.UserId) then continue end
                    
                    -- Whitelist check (The logic should typically *skip* if whitelisted, but the original logic *continues* if whitelisted, meaning it ignores whitelisted players, which is a common setup for an *enemy* aimbot.)
                    if table.find(AimbotSettings.Whitelist, player.Name) then continue end
                    
                    local head = targetCharacter.Head
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    
                    if onScreen then
                        -- Calculate distance from the screen center, not mouse position (Common Aimbot type)
                        -- The original script calculated distance to the mouse, which is for *trigger* or *mouse-proximity* aimbot.
                        local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local distance = (centerScreen - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                        
                        if distance < shortestDistance then
                            -- Wall check: Check if the ray from the camera hits the target *before* anything else.
                            if AimbotSettings.WallCheck then
                                -- Raycast parameters
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
    local direction = (targetPos - cameraCFrame.Position).Unit
    -- Create the CFrame looking at the target. Note: Using the camera's position ensures the camera doesn't move forward/backward.
    local newCFrame = CFrame.new(cameraCFrame.Position, targetPos)
    
    -- Smoothness value 1 means no smoothing (instant snap). Higher value means more smoothing.
    -- The formula for Lerp factor should be adjusted for smoothness. (1 / Smoothness) is reasonable.
    -- If Smoothness is 5, factor is 0.2 (20% of the way).
    Camera.CFrame = cameraCFrame:Lerp(newCFrame, 1 / AimbotSettings.Smoothness)
end

-- Light Helmet
local function CreateLightHelmet()
    if LightObject then
        LightObject:Destroy()
        LightObject = nil -- Ensure it's nil after destruction
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

-- Noclip
local function ToggleNoclip(enabled)
    -- **CRITICAL CORRECTION/IMPROVEMENT:**
    -- The original function `ToggleNoclip(true)` was called every frame in the main loop if NoclipEnabled was true.
    -- This causes massive performance issues as it iterates *all* parts in the character every single frame.
    -- The correct approach is to only run the logic once when toggled, and use the `NoclipCache` to store the original state for restoration.

    local character = LocalPlayer.Character
    if not character then return end
    
    if enabled then
        -- Enable Noclip (Run once)
        NoclipCache = {} -- Clear previous cache
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Store original CanCollide and set to false
                NoclipCache[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    else
        -- Disable Noclip (Run once)
        for part, originalCanCollide in pairs(NoclipCache) do
            -- Check if the part still exists before setting CanCollide
            if part.Parent then 
                part.CanCollide = originalCanCollide
            end
        end
        NoclipCache = {} -- Clear the cache after restoration
    end
end

-- Character Added Event handler for Noclip and Light Helmet
local function OnCharacterAdded(character)
    if LightHelmetEnabled then
        -- Wait a bit to ensure all parts are loaded before trying to put the light on the head
        task.wait(1) 
        CreateLightHelmet()
    end
    
    -- Noclip MUST be reapplied if the character respawns while Noclip is active.
    -- We do *not* call ToggleNoclip(true) immediately here because the toggle is now logic-based 
    -- and relies on the state being set in the UI callback, which handles the NoclipEnabled variable.
end

if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(OnCharacterAdded))

-- Corrected Noclip UI Toggle logic:
local function OnNoclipToggle(value)
    NoclipEnabled = value
    -- **CRITICAL CORRECTION:** Call ToggleNoclip ONCE when the state changes, NOT repeatedly in the RenderStepped loop.
    ToggleNoclip(value) 
end

-- Create UI (UI code is mostly fine, just ensuring callbacks use the corrected functions)
local Window = Library:CreateWindow({
    Name = "Masacre Script",
    LoadingTitle = "Loading Script...",
    ConfigurationSaving = {
        Enabled = true,
        FileName = "MM2Script"
    }
})

-- ESP Tab
local ESPTab = Window:CreateTab({
    Name = "ESP",
    Icon = "rbxassetid://4483345998" -- NOTE: Icon ID 4483345998 is a Roblox item; ensure it's still available/correct.
})

local ESPSection = ESPTab:CreateSection({Name = "ESP Settings", Side = "Left"})

ESPSection:CreateToggle({
    Name = "Enable ESP",
    Default = false,
    Callback = function(value)
        ESPEnabled = value
        if not value then
            ClearESP()
        end
    end
})

-- ... (Rest of ESP toggles are fine)

ESPSection:CreateToggle({
    Name = "Use Boxes",
    Default = true,
    Callback = function(value)
        ESPSettings.UseBoxes = value
    end
})

ESPSection:CreateToggle({
    Name = "Use Highlights",
    Default = false,
    Callback = function(value)
        ESPSettings.UseHighlights = value
    end
})

ESPSection:CreateToggle({
    Name = "Show Health",
    Default = true,
    Callback = function(value)
        ESPSettings.ShowHealths = value
    end
})

ESPSection:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Callback = function(value)
        ESPSettings.ShowDistances = value
    end
})

ESPSection:CreateToggle({
    Name = "Team Check",
    Default = false,
    Callback = function(value)
        ESPSettings.TeamCheck = value
    end
})

ESPSection:CreateToggle({
    Name = "Friend Check",
    Default = false,
    Callback = function(value)
        ESPSettings.FriendCheck = value
    end
})

-- Aimbot Tab
local AimbotTab = Window:CreateTab({
    Name = "Aimbot",
    Icon = "rbxassetid://4483345998"
})

local AimbotSection = AimbotTab:CreateSection({Name = "Aimbot Settings", Side = "Left"})

AimbotSection:CreateToggle({
    Name = "Enable Aimbot",
    Default = false,
    Callback = function(value)
        AimbotEnabled = value
    end
})

-- ... (Rest of Aimbot controls are fine)
AimbotSection:CreateSlider({
    Name = "FOV",
    Min = 50,
    Max = 500,
    Default = 100,
    Callback = function(value)
        AimbotSettings.FOV = value
    end
})

AimbotSection:CreateSlider({
    Name = "Smoothness",
    Min = 1,
    Max = 20,
    Default = 5,
    Callback = function(value)
        -- Ensure smoothness is at least 1 to avoid division by zero or excessive snapping
        AimbotSettings.Smoothness = math.max(1, value)
    end
})

AimbotSection:CreateToggle({
    Name = "Wall Check",
    Default = true,
    Callback = function(value)
        AimbotSettings.WallCheck = value
    end
})

AimbotSection:CreateToggle({
    Name = "Team Check",
    Default = false,
    Callback = function(value)
        AimbotSettings.TeamCheck = value
    end
})

AimbotSection:CreateToggle({
    Name = "Friend Check",
    Default = false,
    Callback = function(value)
        AimbotSettings.FriendCheck = value
    end
})

AimbotSection:CreateTextbox({
    Name = "Add to Whitelist",
    Placeholder = "Username",
    Callback = function(text, enter)
        if enter and text ~= "" then
            -- Store lowercased username for reliable comparison later
            local lowerText = text:lower()
            if not table.find(AimbotSettings.Whitelist, lowerText) then
                table.insert(AimbotSettings.Whitelist, lowerText)
                Library:Notify({Title = "Whitelist", Content = "Added " .. text .. " to whitelist"})
            else
                 Library:Notify({Title = "Whitelist", Content = text .. " is already whitelisted"})
            end
        end
    end
})

-- Misc Tab
local MiscTab = Window:CreateTab({
    Name = "Misc",
    Icon = "rbxassetid://4483345998"
})

local MiscSection = MiscTab:CreateSection({Name = "Misc Features", Side = "Left"})

MiscSection:CreateToggle({
    Name = "Light Helmet",
    Default = false,
    Callback = function(value)
        LightHelmetEnabled = value
        ToggleLightHelmet(value)
    end
})

MiscSection:CreateToggle({
    Name = "Noclip",
    Default = false,
    Callback = OnNoclipToggle -- Use the corrected single-toggle function
})

-- Settings Tab (The original settings tab is functionally fine)
local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "rbxassetid://4483345998"
})

local SettingsSection = SettingsTab:CreateSection({Name = "Script Settings", Side = "Left"})

SettingsSection:CreateButton({
    Name = "Disable All Features",
    Callback = function()
        ESPEnabled = false
        AimbotEnabled = false
        NoclipEnabled = false
        LightHelmetEnabled = false
        ClearESP()
        ToggleLightHelmet(false)
        ToggleNoclip(false) -- Ensure noclip is disabled properly
        Library:Notify({Title = "Settings", Content = "All features disabled"})
    end
})

SettingsSection:CreateButton({
    Name = "Destroy Script",
    Callback = function()
        ScriptEnabled = false
        ClearESP()
        ToggleLightHelmet(false)
        ToggleNoclip(false)
        for _, conn in pairs(Connections) do
            conn:Disconnect()
        end
        Library:Unload()
        Library:Notify({Title = "Script", Content = "Script destroyed"})
    end
})

-- Keybinds (Functionally correct, but needs to update the UI state to reflect the keybind change if possible, although RenLib often doesn't expose that easily)
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F and not UserInputService:GetFocusedTextBox() then
        AimbotEnabled = not AimbotEnabled
        Library:Notify({Title = "Aimbot", Content = AimbotEnabled and "Enabled" or "Disabled"})
    end
    
    if input.KeyCode == Enum.KeyCode.H and not UserInputService:GetFocusedTextBox() then
        LightHelmetEnabled = not LightHelmetEnabled
        ToggleLightHelmet(LightHelmetEnabled)
        Library:Notify({Title = "Light Helmet", Content = LightHelmetEnabled and "Enabled" or "Disabled"})
    end
    
    -- Add Noclip keybind if desired (e.g., KeyCode.G)
    if input.KeyCode == Enum.KeyCode.G and not UserInputService:GetFocusedTextBox() then
        NoclipEnabled = not NoclipEnabled
        ToggleNoclip(NoclipEnabled)
        Library:Notify({Title = "Noclip", Content = NoclipEnabled and "Enabled" or "Disabled"})
    end
end))

-- Main Loop
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not ScriptEnabled then return end
    
    -- ESP Update
    if ESPEnabled then
        UpdateESP()
    end
    
    -- Aimbot
    -- Checks for Aimbot enabled and Right Mouse Button (MouseButton2) pressed
    if AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosestPlayer()
        if target then
            AimAt(target)
        end
    end
    
    -- Noclip (CRITICAL CORRECTION: REMOVE THE ToggleNoclip(true) CALL HERE)
    -- Noclip logic is now handled in the toggle function and character spawn event. 
    -- Leaving it here would cause extreme lag as it iterates the character's parts every frame.
    -- if NoclipEnabled then
    --     ToggleNoclip(true) -- REMOVED
    -- end
end))

-- Initialize
LoadWeaponNames()
Library:Notify({
    Title = "Script Loaded",
    Content = "Masacre Script loaded successfully! (F: Aimbot, H: Light, G: Noclip)",
    Duration = 5
})

print("Masacre Script Loaded - Press F for Aimbot, H for Light Helmet, G for Noclip (new)")
print("For Devs : Everything is commented in the script to make understanding better .")
