--// Arena Aimbot + ESP for YOUR Roblox executor challenge game
--// Center FOV + auto lock + X quick toggle
--// Bright red ESP
--// No remote firing. Camera aim-assist only.

--// RenLib UI compatibility facade
local RenLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"))()
--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--// Config
local Config = {
    ESPEnabled = false,
    AimbotEnabled = false,
    TeamCheck = false,

    QuickToggleKey = Enum.KeyCode.X,

    FOVEnabled = true,
    FOVRadius = 180,

    -- 1 = smooth, 100 = snappy
    Smoothness = 0.18,

    MaxDistance = 1000,

    TargetViewmodels = true,
    TargetCharacters = true,

    IgnoreLocalCharacter = true,
    IgnoreLocalViewmodel = true,

    ShowNames = true,
    ShowDistance = true,
    ESPRefreshRate = 0.03,

    MouseBreakLock = true,
    MouseBreakThreshold = 9,
    MouseBreakCooldown = 0.28,

    ESPColor = Color3.fromRGB(255, 0, 0)
}

local ManualBreakUntil = 0
local AimbotToggleObject = nil

--// RenLib UI
RenLib:ApplyThemePreset("Celestial")
local Window = RenLib:CreateWindow({
    Name = "Arena Assist",
    Icon = 6034316009,
    SidebarMode = "Dynamic",
    ShowUserProfile = true,
    EnableGlobalSearch = true,
})

local CombatTab = Window:CreateTab({Name = "Combat", Icon = 6031154871})
local ESPTab = Window:CreateTab({Name = "ESP", Icon = 6034316009})
local SettingsTab = Window:CreateTab({Name = "Settings", Icon = 6031280882})

local CombatControls = CombatTab:CreateSection({Name = "Controls", Side = "Left"})
CombatControls:CreateParagraph({
    Title = "Smoothness Notice",
    Content = "Put smoothness on 100 for snappier aim, and 1 for smoother aim."
})

AimbotToggleObject = CombatControls:CreateToggle({
    Name = "Aimbot / Auto Lock",
    Default = false,
    Flag = "AimbotEnabled",
    Callback = function(Value)
        Config.AimbotEnabled = Value
    end
})

CombatControls:CreateLabel("Press X to quick toggle aimbot.")

CombatControls:CreateSlider({
    Name = "FOV Radius",
    Min = 50,
    Max = 600,
    Step = 5,
    Default = Config.FOVRadius,
    Flag = "FOVRadius",
    Callback = function(Value)
        Config.FOVRadius = Value
    end
})

CombatControls:CreateSlider({
    Name = "Smoothness",
    Min = 1,
    Max = 100,
    Step = 1,
    Default = math.floor(Config.Smoothness * 100),
    Flag = "Smoothness",
    Callback = function(Value)
        -- 1 = very smooth, 100 = instant/snappy
        Config.Smoothness = math.clamp(Value / 100, 0.01, 1)
    end
})

CombatControls:CreateSlider({
    Name = "Max Target Distance",
    Min = 100,
    Max = 5000,
    Step = 50,
    Default = Config.MaxDistance,
    Flag = "MaxDistance",
    Callback = function(Value)
        Config.MaxDistance = Value
    end
})

CombatControls:CreateToggle({
    Name = "Use FOV Limit",
    Default = true,
    Flag = "FOVEnabled",
    Callback = function(Value)
        Config.FOVEnabled = Value
    end
})

CombatControls:CreateToggle({
    Name = "Mouse Break Lock",
    Default = true,
    Flag = "MouseBreakLock",
    Callback = function(Value)
        Config.MouseBreakLock = Value
    end
})

local ESPControls = ESPTab:CreateSection({Name = "Controls", Side = "Left"})
ESPControls:CreateToggle({
    Name = "ESP Enabled",
    Default = false,
    Flag = "ESPEnabled",
    Callback = function(Value)
        Config.ESPEnabled = Value
    end
})

ESPControls:CreateToggle({
    Name = "Show Names",
    Default = true,
    Flag = "ShowNames",
    Callback = function(Value)
        Config.ShowNames = Value
    end
})

ESPControls:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Flag = "ShowDistance",
    Callback = function(Value)
        Config.ShowDistance = Value
    end
})

local SettingsControls = SettingsTab:CreateSection({Name = "Controls", Side = "Left"})
SettingsControls:CreateToggle({
    Name = "Target Viewmodels",
    Default = true,
    Flag = "TargetViewmodels",
    Callback = function(Value)
        Config.TargetViewmodels = Value
    end
})

SettingsControls:CreateToggle({
    Name = "Target Characters",
    Default = true,
    Flag = "TargetCharacters",
    Callback = function(Value)
        Config.TargetCharacters = Value
    end
})

SettingsControls:CreateButton({
    Name = "Destroy UI / Cleanup",
    Callback = function()
        getgenv().ArenaAssist_Unload = true
        RenLib:Unload("script cleanup")
    end
})

RenLib:Notify({
    Title = "Arena Assist Loaded",
    Content = "Center FOV, auto lock, X quick toggle, bright red ESP.",
    Duration = 5,
    Image = "crosshair"
})

--// Drawing helpers
local function NewDrawing(Type, Props)
    local Obj = Drawing.new(Type)
    for K, V in pairs(Props or {}) do
        Obj[K] = V
    end
    return Obj
end

local FOVCircle = NewDrawing("Circle", {
    Visible = false,
    Radius = Config.FOVRadius,
    Thickness = 2,
    Filled = false,
    Transparency = 1,
    Color = Config.ESPColor
})

local ESPObjects = {}

local function CreateESPObject(Id)
    if ESPObjects[Id] then
        return ESPObjects[Id]
    end

    local Box = NewDrawing("Square", {
        Visible = false,
        Thickness = 2,
        Filled = false,
        Transparency = 1,
        Color = Config.ESPColor
    })

    local NameText = NewDrawing("Text", {
        Visible = false,
        Center = true,
        Outline = true,
        Size = 13,
        Transparency = 1,
        Color = Config.ESPColor
    })

    local DistanceText = NewDrawing("Text", {
        Visible = false,
        Center = true,
        Outline = true,
        Size = 12,
        Transparency = 1,
        Color = Config.ESPColor
    })

    ESPObjects[Id] = {
        Box = Box,
        NameText = NameText,
        DistanceText = DistanceText
    }

    return ESPObjects[Id]
end

local function HideESPObject(Obj)
    if not Obj then return end
    Obj.Box.Visible = false
    Obj.NameText.Visible = false
    Obj.DistanceText.Visible = false
end

local function DestroyESPObject(Obj)
    if not Obj then return end
    pcall(function() Obj.Box:Remove() end)
    pcall(function() Obj.NameText:Remove() end)
    pcall(function() Obj.DistanceText:Remove() end)
end

--// Target detection
local function IsAliveModel(Model)
    if not Model or not Model:IsA("Model") then
        return false
    end

    local Humanoid = Model:FindFirstChildOfClass("Humanoid")
    if Humanoid and Humanoid.Health <= 0 then
        return false
    end

    return true
end

local function GetTargetPart(Model)
    if not Model then return nil end

    return Model:FindFirstChild("head", true)
        or Model:FindFirstChild("Head", true)
        or Model:FindFirstChild("collision3", true)
        or Model:FindFirstChild("HumanoidRootPart", true)
        or Model.PrimaryPart
end

local function IsLocalCharacter(Model)
    if not Model then return false end

    if LocalPlayer.Character and Model == LocalPlayer.Character then
        return true
    end

    if Model.Name == LocalPlayer.Name then
        return true
    end

    return false
end

local function IsLocalViewmodel(Model)
    if not Model then return false end
    return Model.Name == "LocalViewmodel"
end

local function GetPlayerFromArenaCharacter(Model)
    if not Model then return nil end
    return Players:FindFirstChild(Model.Name)
end

local function IsTeamAllowed(Model)
    if not Config.TeamCheck then
        return true
    end

    local TargetPlayer = GetPlayerFromArenaCharacter(Model)
    if not TargetPlayer then
        return true
    end

    if TargetPlayer == LocalPlayer then
        return false
    end

    if LocalPlayer.Team and TargetPlayer.Team and LocalPlayer.Team == TargetPlayer.Team then
        return false
    end

    return true
end

local function AddCandidate(List, Model, SourceType)
    if not Model or not Model:IsA("Model") then return end
    if not IsAliveModel(Model) then return end

    if Config.IgnoreLocalCharacter and IsLocalCharacter(Model) then
        return
    end

    if Config.IgnoreLocalViewmodel and IsLocalViewmodel(Model) then
        return
    end

    if not IsTeamAllowed(Model) then
        return
    end

    local Part = GetTargetPart(Model)
    if not Part or not Part:IsA("BasePart") then
        return
    end

    table.insert(List, {
        Model = Model,
        Part = Part,
        SourceType = SourceType,
        Name = Model.Name
    })
end

local function GetCandidates()
    local Candidates = {}

    --// Characters at workspace.playerusername
    if Config.TargetCharacters then
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer then
                local Model = workspace:FindFirstChild(Player.Name)
                AddCandidate(Candidates, Model, "Character")
            end
        end

        -- fallback scan
        for _, Obj in ipairs(workspace:GetChildren()) do
            if Obj:IsA("Model") and Players:FindFirstChild(Obj.Name) then
                AddCandidate(Candidates, Obj, "Character")
            end
        end
    end

    --// Viewmodels at workspace.Viewmodels
    if Config.TargetViewmodels then
        local ViewmodelsFolder = workspace:FindFirstChild("Viewmodels")
        if ViewmodelsFolder then
            for _, VM in ipairs(ViewmodelsFolder:GetChildren()) do
                if VM:IsA("Model") then
                    AddCandidate(Candidates, VM, "Viewmodel")
                end
            end
        end
    end

    return Candidates
end

--// Screen math
local function GetScreenCenter()
    local ViewportSize = Camera.ViewportSize
    return Vector2.new(ViewportSize.X / 2, ViewportSize.Y / 2)
end

local function WorldToScreen(Position)
    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Position)
    return Vector2.new(ScreenPos.X, ScreenPos.Y), OnScreen, ScreenPos.Z
end

local function GetDistanceFromCamera(Part)
    return (Camera.CFrame.Position - Part.Position).Magnitude
end

local function GetClosestTarget()
    local CenterPos = GetScreenCenter()
    local Closest = nil
    local ClosestScore = math.huge

    for _, Candidate in ipairs(GetCandidates()) do
        local Part = Candidate.Part
        local Distance3D = GetDistanceFromCamera(Part)

        if Distance3D <= Config.MaxDistance then
            local ScreenPos, OnScreen, Depth = WorldToScreen(Part.Position)

            if OnScreen and Depth > 0 then
                local ScreenDistance = (ScreenPos - CenterPos).Magnitude

                if (not Config.FOVEnabled) or ScreenDistance <= Config.FOVRadius then
                    if ScreenDistance < ClosestScore then
                        ClosestScore = ScreenDistance
                        Closest = Candidate
                    end
                end
            end
        end
    end

    return Closest
end

local function AimAt(TargetPart)
    if not TargetPart then return end

    local CamPos = Camera.CFrame.Position
    local Wanted = CFrame.new(CamPos, TargetPart.Position)

    Camera.CFrame = Camera.CFrame:Lerp(Wanted, Config.Smoothness)
end

local function SetAimbotEnabled(Value)
    Config.AimbotEnabled = Value

    if AimbotToggleObject and AimbotToggleObject.Set then
        pcall(function()
            AimbotToggleObject:Set(Value)
        end)
    end

    RenLib:Notify({
        Title = "Aimbot",
        Content = Value and "Aimbot enabled." or "Aimbot disabled.",
        Duration = 2,
        Image = "crosshair"
    })
end

--// Input
UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then return end

    if Input.KeyCode == Config.QuickToggleKey then
        SetAimbotEnabled(not Config.AimbotEnabled)
    end
end)

--// ESP rendering
local function UpdateESP()
    local UsedIds = {}

    if not Config.ESPEnabled then
        for _, Obj in pairs(ESPObjects) do
            HideESPObject(Obj)
        end
        return
    end

    for _, Candidate in ipairs(GetCandidates()) do
        local Model = Candidate.Model
        local Part = Candidate.Part

        if Model and Part then
            local Id = Candidate.SourceType .. "_" .. Model:GetDebugId()
            UsedIds[Id] = true

            local ESP = CreateESPObject(Id)

            ESP.Box.Color = Config.ESPColor
            ESP.NameText.Color = Config.ESPColor
            ESP.DistanceText.Color = Config.ESPColor

            local ScreenPos, OnScreen, Depth = WorldToScreen(Part.Position)
            local Distance = GetDistanceFromCamera(Part)

            if OnScreen and Depth > 0 and Distance <= Config.MaxDistance then
                local Scale = math.clamp(1800 / Distance, 25, 250)
                local Width = Scale * 0.65
                local Height = Scale

                ESP.Box.Size = Vector2.new(Width, Height)
                ESP.Box.Position = Vector2.new(ScreenPos.X - Width / 2, ScreenPos.Y - Height / 2)
                ESP.Box.Visible = true

                ESP.NameText.Text = Candidate.Name .. " [" .. Candidate.SourceType .. "]"
                ESP.NameText.Position = Vector2.new(ScreenPos.X, ScreenPos.Y - Height / 2 - 15)
                ESP.NameText.Visible = Config.ShowNames

                ESP.DistanceText.Text = tostring(math.floor(Distance)) .. " studs"
                ESP.DistanceText.Position = Vector2.new(ScreenPos.X, ScreenPos.Y + Height / 2 + 3)
                ESP.DistanceText.Visible = Config.ShowDistance
            else
                HideESPObject(ESP)
            end
        end
    end

    for Id, Obj in pairs(ESPObjects) do
        if not UsedIds[Id] then
            HideESPObject(Obj)
        end
    end
end

--// Main loop
local LastESPUpdate = 0

RunService.RenderStepped:Connect(function(DeltaTime)
    if getgenv().ArenaAssist_Unload then
        FOVCircle.Visible = false

        for _, Obj in pairs(ESPObjects) do
            DestroyESPObject(Obj)
        end

        ESPObjects = {}
        return
    end

    local CenterPos = GetScreenCenter()

    FOVCircle.Position = CenterPos
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Color = Config.ESPColor
    FOVCircle.Visible = Config.FOVEnabled and Config.AimbotEnabled

    if Config.ESPEnabled then
        LastESPUpdate += DeltaTime
        if LastESPUpdate >= Config.ESPRefreshRate then
            LastESPUpdate = 0
            UpdateESP()
        end
    else
        UpdateESP()
    end

    --// Moving mouse hard breaks lock for a tiny moment
    if Config.MouseBreakLock and Config.AimbotEnabled then
        local MouseDelta = UserInputService:GetMouseDelta()
        if MouseDelta.Magnitude >= Config.MouseBreakThreshold then
            ManualBreakUntil = tick() + Config.MouseBreakCooldown
        end
    end

    if Config.AimbotEnabled and tick() >= ManualBreakUntil then
        local Target = GetClosestTarget()
        if Target and Target.Part then
            AimAt(Target.Part)
        end
    end
end)

RenLib:LoadConfig("ArenaAssistConfig")
