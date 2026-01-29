local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
    SCRIPT_NAME = "Skyven Script",
    CREATOR = "xsakyx",
    TEAM = "by xsakyx ",
    VERSION = "2.0.0",
    DEFAULT_FLY_SPEED = 200,
}

-- Professional Theme Presets (Improved)
local THEMES = {
    Dark = {
        Primary = Color3.fromRGB(18, 18, 24),
        Secondary = Color3.fromRGB(24, 24, 32),
        Tertiary = Color3.fromRGB(32, 32, 42),
        Accent = Color3.fromRGB(88, 101, 242),
        AccentDark = Color3.fromRGB(71, 82, 196),
        Text = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(160, 160, 170),
        Success = Color3.fromRGB(67, 181, 129),
        Warning = Color3.fromRGB(250, 177, 21),
        Danger = Color3.fromRGB(240, 71, 71),
        Border = Color3.fromRGB(45, 45, 55)
    },
    Light = {
        Primary = Color3.fromRGB(250, 250, 252),
        Secondary = Color3.fromRGB(241, 242, 246),
        Tertiary = Color3.fromRGB(233, 235, 241),
        Accent = Color3.fromRGB(99, 102, 241),
        AccentDark = Color3.fromRGB(79, 82, 193),
        Text = Color3.fromRGB(17, 24, 39),
        TextSecondary = Color3.fromRGB(107, 114, 128),
        Success = Color3.fromRGB(34, 197, 94),
        Warning = Color3.fromRGB(251, 146, 60),
        Danger = Color3.fromRGB(239, 68, 68),
        Border = Color3.fromRGB(209, 213, 219)
    },
    AmberGlow = {
        Primary = Color3.fromRGB(26, 21, 16),
        Secondary = Color3.fromRGB(35, 28, 21),
        Tertiary = Color3.fromRGB(44, 35, 26),
        Accent = Color3.fromRGB(245, 158, 11),
        AccentDark = Color3.fromRGB(217, 119, 6),
        Text = Color3.fromRGB(254, 243, 199),
        TextSecondary = Color3.fromRGB(252, 211, 77),
        Success = Color3.fromRGB(251, 191, 36),
        Warning = Color3.fromRGB(245, 158, 11),
        Danger = Color3.fromRGB(220, 38, 38),
        Border = Color3.fromRGB(92, 69, 49)
    },
    Aurora = {
        Primary = Color3.fromRGB(10, 16, 31),
        Secondary = Color3.fromRGB(17, 25, 45),
        Tertiary = Color3.fromRGB(24, 35, 59),
        Accent = Color3.fromRGB(168, 85, 247),
        AccentDark = Color3.fromRGB(147, 51, 234),
        Text = Color3.fromRGB(241, 245, 249),
        TextSecondary = Color3.fromRGB(148, 163, 184),
        Success = Color3.fromRGB(52, 211, 153),
        Warning = Color3.fromRGB(251, 191, 36),
        Danger = Color3.fromRGB(251, 113, 133),
        Border = Color3.fromRGB(51, 65, 85)
    }
}

-- State Management
local State = {
    CurrentTheme = "Dark",
    CurrentFlySpeed = CONFIG.DEFAULT_FLY_SPEED,
    ResourceESP = false,
    PlayerESP = false,
    Flying = false,
    AutoTasks = false,
    DisableRollChecks = false,
    AutoFarmNest = false,
    UIVisible = true,
    UIMinimized = false,
    CurrentTab = "Main",
    CurrentMainSubTab = "Main",
    CurrentSettingsSubTab = "Themes",
    SelectedTeleportPlayer = nil,
    SelectedTeleportItem = nil,
    CustomColors = {},
    UITransparency = {}
}

-- Flying Variables
local flyConnection = nil
local bodyVelocity = nil
local bodyGyro = nil
local humanoid = nil
local rootPart = nil

-- ESP Storage
local espItems = {}
local espPlayers = {}
local espRefreshConnection = nil

-- Auto Tasks Variables
local autoTaskConnection = nil

-- Create Main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RenHubSkyvenUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame with Professional Design
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 550, 0, 400)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -200)
mainFrame.BackgroundColor3 = THEMES[State.CurrentTheme].Primary
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Professional rounded corners
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

-- Professional shadow
local shadowHolder = Instance.new("Frame")
shadowHolder.Name = "ShadowHolder"
shadowHolder.Size = UDim2.new(1, 30, 1, 30)
shadowHolder.Position = UDim2.new(0, -15, 0, -15)
shadowHolder.BackgroundTransparency = 1
shadowHolder.ZIndex = 0
shadowHolder.Parent = mainFrame

local shadowImage = Instance.new("ImageLabel")
shadowImage.Name = "Shadow"
shadowImage.BackgroundTransparency = 1
shadowImage.Position = UDim2.new(0, 0, 0, 0)
shadowImage.Size = UDim2.new(1, 0, 1, 0)
shadowImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
shadowImage.ImageColor3 = Color3.new(0, 0, 0)
shadowImage.ImageTransparency = 0.6
shadowImage.ScaleType = Enum.ScaleType.Slice
shadowImage.SliceCenter = Rect.new(20, 20, 20, 20)
shadowImage.Parent = shadowHolder

-- Professional Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 55)
header.BackgroundColor3 = THEMES[State.CurrentTheme].Secondary
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerGradient = Instance.new("UIGradient")
headerGradient.Rotation = 90
headerGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9))
}
headerGradient.Parent = header

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = header

local headerCover = Instance.new("Frame")
headerCover.Name = "Cover"
headerCover.Size = UDim2.new(1, 0, 0, 20)
headerCover.Position = UDim2.new(0, 0, 1, -20)
headerCover.BackgroundColor3 = THEMES[State.CurrentTheme].Secondary
headerCover.BorderSizePixel = 0
headerCover.Parent = header

-- Title with icon placeholder
local titleContainer = Instance.new("Frame")
titleContainer.Name = "TitleContainer"
titleContainer.Size = UDim2.new(0.6, 0, 1, 0)
titleContainer.Position = UDim2.new(0, 20, 0, 0)
titleContainer.BackgroundTransparency = 1
titleContainer.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0.6, 0)
title.Position = UDim2.new(0, 0, 0, 5)
title.BackgroundTransparency = 1
title.Text = CONFIG.SCRIPT_NAME
title.TextColor3 = THEMES[State.CurrentTheme].Text
title.TextScaled = true
title.Font = Enum.Font.SourceSansBold
title.Parent = titleContainer

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, 0, 0.4, 0)
subtitle.Position = UDim2.new(0, 0, 0.5, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Professional Exploit Framework"
subtitle.TextColor3 = THEMES[State.CurrentTheme].TextSecondary
subtitle.TextScaled = true
subtitle.Font = Enum.Font.SourceSans
subtitle.Parent = titleContainer

-- Window Controls
local controlsContainer = Instance.new("Frame")
controlsContainer.Name = "Controls"
controlsContainer.Size = UDim2.new(0, 120, 0, 35)
controlsContainer.Position = UDim2.new(1, -130, 0.5, -17.5)
controlsContainer.BackgroundTransparency = 1
controlsContainer.Parent = header

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeButton"
minimizeBtn.Size = UDim2.new(0, 35, 0, 35)
minimizeBtn.Position = UDim2.new(0, 0, 0, 0)
minimizeBtn.BackgroundColor3 = THEMES[State.CurrentTheme].Tertiary
minimizeBtn.Text = "—"
minimizeBtn.TextColor3 = THEMES[State.CurrentTheme].Text
minimizeBtn.TextScaled = true
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = controlsContainer

local minimizeBtnCorner = Instance.new("UICorner")
minimizeBtnCorner.CornerRadius = UDim.new(0, 8)
minimizeBtnCorner.Parent = minimizeBtn

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(0, 40, 0, 0)
closeBtn.BackgroundColor3 = THEMES[State.CurrentTheme].Danger
closeBtn.Text = "✕"
closeBtn.TextColor3 = THEMES[State.CurrentTheme].Text
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = controlsContainer

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

-- Tab Container
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, -20, 0, 45)
tabContainer.Position = UDim2.new(0, 10, 0, 65)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

-- Create Tabs
local tabs = {"Main", "Settings", "Credits"}
local tabButtons = {}

for i, tabName in ipairs(tabs) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = tabName .. "Tab"
    tabBtn.Size = UDim2.new(0.33, -5, 1, 0)
    tabBtn.Position = UDim2.new(0.33 * (i-1), 5 * (i-1), 0, 0)
    tabBtn.BackgroundColor3 = State.CurrentTab == tabName and THEMES[State.CurrentTheme].Accent or THEMES[State.CurrentTheme].Tertiary
    tabBtn.Text = tabName
    tabBtn.TextColor3 = THEMES[State.CurrentTheme].Text
    tabBtn.TextScaled = true
    tabBtn.Font = Enum.Font.SourceSansSemibold
    tabBtn.BorderSizePixel = 0
    tabBtn.Parent = tabContainer
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 10)
    tabCorner.Parent = tabBtn
    
    tabButtons[tabName] = tabBtn
end

-- Content Frame
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -20, 1, -120)
contentFrame.Position = UDim2.new(0, 10, 0, 115)
contentFrame.BackgroundColor3 = THEMES[State.CurrentTheme].Secondary
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 10)
contentCorner.Parent = contentFrame

-- Notification System (Left Bottom)
local function createNotification(message, duration)
    duration = duration or 3
    
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 320, 0, 65)
    notif.Position = UDim2.new(0, -340, 1, -80)
    notif.BackgroundColor3 = THEMES[State.CurrentTheme].Secondary
    notif.BorderSizePixel = 0
    notif.Parent = screenGui
    
    local notifGradient = Instance.new("UIGradient")
    notifGradient.Rotation = 45
    notifGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, THEMES[State.CurrentTheme].Accent),
        ColorSequenceKeypoint.new(1, THEMES[State.CurrentTheme].AccentDark or THEMES[State.CurrentTheme].Accent)
    }
    notifGradient.Parent = notif
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 12)
    notifCorner.Parent = notif
    
    local notifText = Instance.new("TextLabel")
    notifText.Size = UDim2.new(1, -20, 1, 0)
    notifText.Position = UDim2.new(0, 10, 0, 0)
    notifText.BackgroundTransparency = 1
    notifText.Text = message
    notifText.TextColor3 = Color3.new(1, 1, 1)
    notifText.TextScaled = true
    notifText.Font = Enum.Font.SourceSans
    notifText.Parent = notif
    
    -- Slide in from left
    notif:TweenPosition(
        UDim2.new(0, 20, 1, -140),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Quart,
        0.5
    )
    
    spawn(function()
        wait(duration)
        local fadeOut = TweenService:Create(notif, TweenInfo.new(0.5), {BackgroundTransparency = 1})
        local fadeOutText = TweenService:Create(notifText, TweenInfo.new(0.5), {TextTransparency = 1})
        fadeOut:Play()
        fadeOutText:Play()
        wait(0.5)
        notif:Destroy()
    end)
end

-- Tab Frames Storage
local tabFrames = {}

-- Main Tab with SubTabs
local mainTabFrame = Instance.new("Frame")
mainTabFrame.Name = "MainTab"
mainTabFrame.Size = UDim2.new(1, 0, 1, 0)
mainTabFrame.BackgroundTransparency = 1
mainTabFrame.Visible = true
mainTabFrame.Parent = contentFrame
tabFrames.Main = mainTabFrame

-- Main SubTab Container
local mainSubTabContainer = Instance.new("Frame")
mainSubTabContainer.Name = "SubTabContainer"
mainSubTabContainer.Size = UDim2.new(1, -10, 0, 35)
mainSubTabContainer.Position = UDim2.new(0, 5, 0, 5)
mainSubTabContainer.BackgroundTransparency = 1
mainSubTabContainer.Parent = mainTabFrame

local mainSubTabs = {"Main", "Tasks Sub-Tab", "Teleport Sub-Tab"}
local mainSubTabButtons = {}

for i, subTabName in ipairs(mainSubTabs) do
    local subTabBtn = Instance.new("TextButton")
    subTabBtn.Name = subTabName:gsub(" ", "") .. "SubTab"
    subTabBtn.Size = UDim2.new(0.33, -3, 1, 0)
    subTabBtn.Position = UDim2.new(0.33 * (i-1), 3 * i, 0, 0)
    subTabBtn.BackgroundColor3 = i == 1 and THEMES[State.CurrentTheme].Accent or THEMES[State.CurrentTheme].Tertiary
    subTabBtn.Text = subTabName
    subTabBtn.TextColor3 = THEMES[State.CurrentTheme].Text
    subTabBtn.TextScaled = true
    subTabBtn.Font = Enum.Font.SourceSans
    subTabBtn.BorderSizePixel = 0
    subTabBtn.Parent = mainSubTabContainer
    
    local subTabCorner = Instance.new("UICorner")
    subTabCorner.CornerRadius = UDim.new(0, 8)
    subTabCorner.Parent = subTabBtn
    
    mainSubTabButtons[subTabName] = subTabBtn
end

-- Main SubTab Content Frames
local mainSubTabFrames = {}

-- Main Features Frame
local mainFeaturesFrame = Instance.new("ScrollingFrame")
mainFeaturesFrame.Name = "MainFeatures"
mainFeaturesFrame.Size = UDim2.new(1, -10, 1, -50)
mainFeaturesFrame.Position = UDim2.new(0, 5, 0, 45)
mainFeaturesFrame.BackgroundTransparency = 1
mainFeaturesFrame.BorderSizePixel = 0
mainFeaturesFrame.ScrollBarThickness = 6
mainFeaturesFrame.ScrollBarImageColor3 = THEMES[State.CurrentTheme].Accent
mainFeaturesFrame.Visible = true
mainFeaturesFrame.Parent = mainTabFrame
mainSubTabFrames["Main"] = mainFeaturesFrame

local mainFeaturesLayout = Instance.new("UIListLayout")
mainFeaturesLayout.Padding = UDim.new(0, 8)
mainFeaturesLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainFeaturesLayout.Parent = mainFeaturesFrame

-- Function to create professional toggle button
local function createToggleButton(parent, name, state, callback)
    local container = Instance.new("Frame")
    container.Name = name:gsub(" ", "") .. "Container"
    container.Size = UDim2.new(1, -10, 0, 55)
    container.BackgroundColor3 = THEMES[State.CurrentTheme].Tertiary
    container.BorderSizePixel = 0
    container.Parent = parent
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 10)
    containerCorner.Parent = container
    
    local containerGradient = Instance.new("UIGradient")
    containerGradient.Rotation = 45
    containerGradient.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(1, 1)
    }
    containerGradient.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(0.55, 0, 0.6, 0)
    label.Position = UDim2.new(0, 20, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = THEMES[State.CurrentTheme].Text
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSansSemibold
    label.Parent = container
    
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(0.55, 0, 0.4, 0)
    description.Position = UDim2.new(0, 20, 0.5, 0)
    description.BackgroundTransparency = 1
    description.Text = "Click to toggle"
    description.TextColor3 = THEMES[State.CurrentTheme].TextSecondary
    description.TextScaled = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Font = Enum.Font.SourceSans
    description.Parent = container
    
    local toggle = Instance.new("Frame")
    toggle.Name = "Toggle"
    toggle.Size = UDim2.new(0, 65, 0, 32)
    toggle.Position = UDim2.new(1, -80, 0.5, -16)
    toggle.BackgroundColor3 = state and THEMES[State.CurrentTheme].Success or THEMES[State.CurrentTheme].Border
    toggle.BorderSizePixel = 0
    toggle.Parent = container
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggle
    
    local ball = Instance.new("Frame")
    ball.Name = "Ball"
    ball.Size = UDim2.new(0, 28, 0, 28)
    ball.Position = state and UDim2.new(1, -30, 0.5, -14) or UDim2.new(0, 2, 0.5, -14)
    ball.BackgroundColor3 = Color3.new(1, 1, 1)
    ball.BorderSizePixel = 0
    ball.Parent = toggle
    
    local ballCorner = Instance.new("UICorner")
    ballCorner.CornerRadius = UDim.new(1, 0)
    ballCorner.Parent = ball
    
    local button = Instance.new("TextButton")
    button.Name = "ClickDetector"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = container
    
    local currentState = state
    
    button.MouseButton1Click:Connect(function()
        currentState = not currentState
        callback(currentState)
        
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local ballTween = TweenService:Create(ball, tweenInfo, {
            Position = currentState and UDim2.new(1, -30, 0.5, -14) or UDim2.new(0, 2, 0.5, -14)
        })
        local bgTween = TweenService:Create(toggle, tweenInfo, {
            BackgroundColor3 = currentState and THEMES[State.CurrentTheme].Success or THEMES[State.CurrentTheme].Border
        })
        
        ballTween:Play()
        bgTween:Play()
    end)
    
    return container, function(newState)
        currentState = newState
        ball.Position = currentState and UDim2.new(1, -30, 0.5, -14) or UDim2.new(0, 2, 0.5, -14)
        toggle.BackgroundColor3 = currentState and THEMES[State.CurrentTheme].Success or THEMES[State.CurrentTheme].Border
    end
end

-- Function to create slider
local function createSlider(parent, name, min, max, default, callback)
    local container = Instance.new("Frame")
    container.Name = name:gsub(" ", "") .. "Container"
    container.Size = UDim2.new(1, -10, 0, 70)
    container.BackgroundColor3 = THEMES[State.CurrentTheme].Tertiary
    container.BorderSizePixel = 0
    container.Parent = parent
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 10)
    containerCorner.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(0.5, 0, 0, 30)
    label.Position = UDim2.new(0, 20, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = THEMES[State.CurrentTheme].Text
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSansSemibold
    label.Parent = container
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Size = UDim2.new(0, 60, 0, 30)
    valueLabel.Position = UDim2.new(1, -80, 0, 5)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = THEMES[State.CurrentTheme].Accent
    valueLabel.TextScaled = true
    valueLabel.Font = Enum.Font.SourceSansBold
    valueLabel.Parent = container
    
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = "SliderFrame"
    sliderFrame.Size = UDim2.new(1, -40, 0, 6)
    sliderFrame.Position = UDim2.new(0, 20, 0, 45)
    sliderFrame.BackgroundColor3 = THEMES[State.CurrentTheme].Border
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = container
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = sliderFrame
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "Fill"
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = THEMES[State.CurrentTheme].Accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderFrame
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill
    
    local sliderButton = Instance.new("Frame")
    sliderButton.Name = "Button"
    sliderButton.Size = UDim2.new(0, 20, 0, 20)
    sliderButton.Position = UDim2.new((default - min) / (max - min), -10, 0.5, -10)
    sliderButton.BackgroundColor3 = Color3.new(1, 1, 1)
    sliderButton.BorderSizePixel = 0
    sliderButton.Parent = sliderFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(1, 0)
    buttonCorner.Parent = sliderButton
    
    local dragging = false
    local function updateSlider(input)
        local relativeX = math.clamp((input.Position.X - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * relativeX)
        
        sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
        sliderButton.Position = UDim2.new(relativeX, -10, 0.5, -10)
        valueLabel.Text = tostring(value)
        
        callback(value)
    end
    
    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end)
    
    return container
end

-- ESP Functions
local function createESPHighlight(item, isWater)
    local highlight = Instance.new("Highlight")
    highlight.Name = isWater and "WaterESP" or "ItemESP"
    highlight.Parent = item
    
    if isWater then
        highlight.FillColor = Color3.new(0, 0.8, 1)
        highlight.OutlineColor = Color3.new(0, 0.4, 1)
        highlight.FillTransparency = 0.4
    else
        highlight.FillColor = Color3.new(1, 1, 0)
        highlight.OutlineColor = Color3.new(1, 0, 0)
        highlight.FillTransparency = 0.3
    end
    
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESPLabel"
    billboardGui.AlwaysOnTop = true
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.Parent = item
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
    textLabel.BackgroundTransparency = 0.3
    textLabel.Text = item.Name
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboardGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = textLabel
    
    table.insert(espItems, {item = item, highlight = highlight, billboard = billboardGui})
end

-- Player ESP Function
local function createPlayerESP(targetPlayer)
    if targetPlayer == player then return end
    
    local character = targetPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerESP"
    highlight.Parent = character
    highlight.FillColor = Color3.new(1, 0, 0)
    highlight.OutlineColor = Color3.new(0.5, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "PlayerESPLabel"
    billboardGui.AlwaysOnTop = true
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.Parent = humanoidRootPart
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundColor3 = Color3.new(0.5, 0, 0)
    textLabel.BackgroundTransparency = 0.3
    textLabel.Text = targetPlayer.Name
    textLabel.TextColor3 = Color3.new(1, 0, 0)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboardGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = textLabel
    
    table.insert(espPlayers, {player = targetPlayer, highlight = highlight, billboard = billboardGui})
end

-- Auto-refresh ESP Function
local function startESPAutoRefresh()
    if espRefreshConnection then
        espRefreshConnection:Disconnect()
    end
    
    espRefreshConnection = RunService.Heartbeat:Connect(function()
        if State.ResourceESP then
            -- Check for new items
            local itemsFolder = workspace:FindFirstChild("Items")
            if itemsFolder then
                for _, item in pairs(itemsFolder:GetChildren()) do
                    if item:IsA("BasePart") or item:IsA("Model") then
                        local hasESP = false
                        for _, espData in pairs(espItems) do
                            if espData.item == item then
                                hasESP = true
                                break
                            end
                        end
                        if not hasESP then
                            createESPHighlight(item, false)
                        end
                    end
                end
            end
            
            -- Clean up destroyed items
            for i = #espItems, 1, -1 do
                local espData = espItems[i]
                if not espData.item or not espData.item.Parent then
                    if espData.highlight then espData.highlight:Destroy() end
                    if espData.billboard then espData.billboard:Destroy() end
                    table.remove(espItems, i)
                end
            end
        end
        
        if State.PlayerESP then
            -- Check for new players
            for _, targetPlayer in pairs(Players:GetPlayers()) do
                if targetPlayer ~= player and targetPlayer.Character then
                    local hasESP = false
                    for _, espData in pairs(espPlayers) do
                        if espData.player == targetPlayer then
                            hasESP = true
                            break
                        end
                    end
                    if not hasESP then
                        createPlayerESP(targetPlayer)
                    end
                end
            end
            
            -- Clean up disconnected players
            for i = #espPlayers, 1, -1 do
                local espData = espPlayers[i]
                if not espData.player or not espData.player.Parent or not espData.player.Character then
                    if espData.highlight then espData.highlight:Destroy() end
                    if espData.billboard then espData.billboard:Destroy() end
                    table.remove(espPlayers, i)
                end
            end
        end
    end)
end

local function startResourceESP()
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder then
        for _, item in pairs(itemsFolder:GetChildren()) do
            if item:IsA("BasePart") or item:IsA("Model") then
                createESPHighlight(item, false)
            end
        end
    end
    
    local function findWater(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child.Name == "Water" and child.Parent.Name == "Water" then
                createESPHighlight(child, true)
            elseif child:IsA("Folder") or child:IsA("Model") then
                findWater(child)
            end
        end
    end
    
    local islandsFolder = workspace:FindFirstChild("Islands")
    if islandsFolder then
        findWater(islandsFolder)
    end
    
    startESPAutoRefresh()
end

local function stopResourceESP()
    for _, espData in pairs(espItems) do
        if espData.highlight then espData.highlight:Destroy() end
        if espData.billboard then espData.billboard:Destroy() end
    end
    espItems = {}
end

local function startPlayerESP()
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            createPlayerESP(targetPlayer)
        end
    end
end

local function stopPlayerESP()
    for _, espData in pairs(espPlayers) do
        if espData.highlight then espData.highlight:Destroy() end
        if espData.billboard then espData.billboard:Destroy() end
    end
    espPlayers = {}
end

-- IMPROVED FLYING SYSTEM
local function prepareCharacterForFlight()
    local character = player.Character
    if not character then return false end
    
    humanoid = character:FindFirstChildOfClass("Humanoid")
    rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then return false end
    
    pcall(function()
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        humanoid.PlatformStand = true
    end)
    
    return true
end

local function startFlying()
    if not prepareCharacterForFlight() then 
        createNotification("Failed to start flying!", 3)
        return 
    end
    
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = rootPart
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.D = 2500
    bodyGyro.P = 50000
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Parent = rootPart
    
    if flyConnection then flyConnection:Disconnect() end
    
    flyConnection = RunService.Heartbeat:Connect(function()
        if not rootPart or not rootPart.Parent or not bodyVelocity or not bodyVelocity.Parent then
            stopFlying()
            return
        end
        
        pcall(function()
            if humanoid then
                humanoid.PlatformStand = true
            end
        end)
        
        local camera = workspace.CurrentCamera
        local moveVector = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, 1, 0)
        end
        
        if moveVector.Magnitude > 0 then
            bodyVelocity.Velocity = moveVector.Unit * State.CurrentFlySpeed
        else
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
        
        bodyGyro.CFrame = camera.CFrame
    end)
    
    State.Flying = true
    createNotification("Flying enabled! Speed: " .. State.CurrentFlySpeed, 3)
end

local function stopFlying()
    State.Flying = false
    
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    
    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
    
    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end
    
    pcall(function()
        if humanoid then
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end)
end

-- AUTO TASKS SYSTEM
local function autoCompleteTasks()
    local dataFolder = player:FindFirstChild("Data")
    if not dataFolder then
        createNotification("Data folder not found!", 3)
        return
    end
    
    local dailyTasksFolder = dataFolder:FindFirstChild("DailyTasks")
    if not dailyTasksFolder then
        createNotification("DailyTasks folder not found!", 3)
        return
    end
    
    -- Check if roll check is disabled or if player has rolls
    if not State.DisableRollChecks then
        local changesLeft = dailyTasksFolder:GetAttribute("ChangesLeft")
        if not changesLeft or changesLeft <= 0 then
            createNotification("Not enough task rolls available!", 3)
            return
        end
    end
    
    local completedCount = 0
    local claimedCount = 0
    
    for i = 1, 16 do
        local taskName = "Task" .. i
        local taskFolder = dailyTasksFolder:FindFirstChild(taskName)
        
        if taskFolder then
            local completed = taskFolder:GetAttribute("Completed")
            
            if completed == false then
                taskFolder:SetAttribute("Completed", true)
                completedCount = completedCount + 1
                wait(0.1)
            end
            
            if taskFolder:GetAttribute("Completed") == true then
                local gui = playerGui:FindFirstChild("MainGUI")
                if gui then
                    local page = gui:FindFirstChild("Menu")
                    page = page and page:FindFirstChild("Pages")
                    page = page and page:FindFirstChild("Tasks")
                    page = page and page:FindFirstChild("Background")
                    page = page and page:FindFirstChild("Page")
                    
                    if page then
                        local taskButton = page:FindFirstChild(taskName)
                        if taskButton then
                            local rerollButton = taskButton:FindFirstChild("RerollTaskButton")
                            if rerollButton then
                                pcall(function()
                                    for _, connection in pairs(getconnections(rerollButton.MouseButton1Click)) do
                                        connection:Fire()
                                    end
                                end)
                                claimedCount = claimedCount + 1
                                wait(0.2)
                            end
                        end
                    end
                end
            end
        end
    end
    
    createNotification(string.format("Tasks: %d completed, %d claimed!", completedCount, claimedCount), 5)
end

local function startAutoTasks()
    if autoTaskConnection then return end
    
    autoCompleteTasks()
    
    autoTaskConnection = spawn(function()
        while State.AutoTasks do
            wait(5)
            if State.AutoTasks then
                autoCompleteTasks()
            end
        end
    end)
end

local function stopAutoTasks()
    State.AutoTasks = false
end

-- Teleport Functions
local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then
        createNotification("Player not found or has no character!", 3)
        return
    end
    
    local character = player.Character
    if not character then
        createNotification("Your character not found!", 3)
        return
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if humanoidRootPart and targetRoot then
        humanoidRootPart.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
        createNotification("Teleported to " .. targetPlayer.Name, 2)
    end
end

local function teleportToNearestItem()
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        createNotification("Items folder not found!", 3)
        return
    end
    
    local nearestItem = nil
    local nearestDistance = math.huge
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item:IsA("BasePart") or item:IsA("Model") then
            local itemPos = item:IsA("Model") and item:GetModelCFrame().Position or item.Position
            local distance = (itemPos - humanoidRootPart.Position).Magnitude
            
            if State.SelectedTeleportItem then
                if item.Name == State.SelectedTeleportItem and distance < nearestDistance then
                    nearestDistance = distance
                    nearestItem = item
                end
            elseif distance < nearestDistance then
                nearestDistance = distance
                nearestItem = item
            end
        end
    end
    
    if nearestItem then
        local itemPos = nearestItem:IsA("Model") and nearestItem:GetModelCFrame().Position or nearestItem.Position
        humanoidRootPart.CFrame = CFrame.new(itemPos + Vector3.new(0, 3, 0))
        createNotification("Teleported to " .. nearestItem.Name, 2)
    else
        createNotification("No items found!", 3)
    end
end

-- Add Main Features
local resourceESPToggle, updateResourceESP = createToggleButton(mainFeaturesFrame, "Resource ESP", State.ResourceESP, function(enabled)
    State.ResourceESP = enabled
    if enabled then
        startResourceESP()
    else
        stopResourceESP()
    end
end)

local playerESPToggle, updatePlayerESP = createToggleButton(mainFeaturesFrame, "Player ESP", State.PlayerESP, function(enabled)
    State.PlayerESP = enabled
    if enabled then
        startPlayerESP()
    else
        stopPlayerESP()
    end
end)

local flyToggle, updateFly = createToggleButton(mainFeaturesFrame, "Fly", State.Flying, function(enabled)
    if enabled then
        startFlying()
    else
        stopFlying()
    end
end)

-- Fly Speed Slider
local flySpeedSlider = createSlider(mainFeaturesFrame, "Fly Speed", 50, 1000, State.CurrentFlySpeed, function(value)
    State.CurrentFlySpeed = value
    if State.Flying then
        createNotification("Fly speed updated: " .. value, 1)
    end
end)

-- Tasks Sub-Tab Frame
local tasksFrame = Instance.new("ScrollingFrame")
tasksFrame.Name = "TasksFeatures"
tasksFrame.Size = UDim2.new(1, -10, 1, -50)
tasksFrame.Position = UDim2.new(0, 5, 0, 45)
tasksFrame.BackgroundTransparency = 1
tasksFrame.BorderSizePixel = 0
tasksFrame.ScrollBarThickness = 6
tasksFrame.ScrollBarImageColor3 = THEMES[State.CurrentTheme].Accent
tasksFrame.Visible = false
tasksFrame.Parent = mainTabFrame
mainSubTabFrames["Tasks Sub-Tab"] = tasksFrame

local tasksLayout = Instance.new("UIListLayout")
tasksLayout.Padding = UDim.new(0, 8)
tasksLayout.SortOrder = Enum.SortOrder.LayoutOrder
tasksLayout.Parent = tasksFrame

createToggleButton(tasksFrame, "Auto Do Tasks", State.AutoTasks, function(enabled)
    State.AutoTasks = enabled
    if enabled then
        startAutoTasks()
        createNotification("Auto Tasks Enabled!", 2)
    else
        stopAutoTasks()
        createNotification("Auto Tasks Disabled!", 2)
    end
end)

createToggleButton(tasksFrame, "Disable Roll Checks", State.DisableRollChecks, function(enabled)
    State.DisableRollChecks = enabled
    createNotification("Roll checks " .. (enabled and "disabled" or "enabled"), 2)
end)

-- Teleport Sub-Tab Frame
local teleportFrame = Instance.new("ScrollingFrame")
teleportFrame.Name = "TeleportFeatures"
teleportFrame.Size = UDim2.new(1, -10, 1, -50)
teleportFrame.Position = UDim2.new(0, 5, 0, 45)
teleportFrame.BackgroundTransparency = 1
teleportFrame.BorderSizePixel = 0
teleportFrame.ScrollBarThickness = 6
teleportFrame.ScrollBarImageColor3 = THEMES[State.CurrentTheme].Accent
teleportFrame.Visible = false
teleportFrame.Parent = mainTabFrame
mainSubTabFrames["Teleport Sub-Tab"] = teleportFrame

local teleportLayout = Instance.new("UIListLayout")
teleportLayout.Padding = UDim.new(0, 8)
teleportLayout.SortOrder = Enum.SortOrder.LayoutOrder
teleportLayout.Parent = teleportFrame

-- Player Teleport Section
local playerTeleportContainer = Instance.new("Frame")
playerTeleportContainer.Name = "PlayerTeleport"
playerTeleportContainer.Size = UDim2.new(1, -10, 0, 120)
playerTeleportContainer.BackgroundColor3 = THEMES[State.CurrentTheme].Tertiary
playerTeleportContainer.BorderSizePixel = 0
playerTeleportContainer.Parent = teleportFrame

local playerContainerCorner = Instance.new("UICorner")
playerContainerCorner.CornerRadius = UDim.new(0, 10)
playerContainerCorner.Parent = playerTeleportContainer

local playerLabel = Instance.new("TextLabel")
playerLabel.Size = UDim2.new(1, -20, 0, 30)
playerLabel.Position = UDim2.new(0, 10, 0, 5)
playerLabel.BackgroundTransparency = 1
playerLabel.Text = "Teleport to Player"
playerLabel.TextColor3 = THEMES[State.CurrentTheme].Text
playerLabel.TextScaled = true
playerLabel.TextXAlignment = Enum.TextXAlignment.Left
playerLabel.Font = Enum.Font.SourceSansSemibold
playerLabel.Parent = playerTeleportContainer

local playerDropdown = Instance.new("TextButton")
playerDropdown.Size = UDim2.new(1, -20, 0, 35)
playerDropdown.Position = UDim2.new(0, 10, 0, 40)
playerDropdown.BackgroundColor3 = THEMES[State.CurrentTheme].Secondary
playerDropdown.Text = "Select Player"
playerDropdown.TextColor3 = THEMES[State.CurrentTheme].Text
playerDropdown.TextScaled = true
playerDropdown.Font = Enum.Font.SourceSans
playerDropdown.BorderSizePixel = 0
playerDropdown.Parent = playerTeleportContainer

local playerDropdownCorner = Instance.new("UICorner")
playerDropdownCorner.CornerRadius = UDim.new(0, 8)
playerDropdownCorner.Parent = playerDropdown

local teleportPlayerBtn = Instance.new("TextButton")
teleportPlayerBtn.Size = UDim2.new(0, 120, 0, 30)
teleportPlayerBtn.Position = UDim2.new(1, -130, 0, 80)
teleportPlayerBtn.BackgroundColor3 = THEMES[State.CurrentTheme].Accent
teleportPlayerBtn.Text = "Teleport"
teleportPlayerBtn.TextColor3 = Color3.new(1, 1, 1)
teleportPlayerBtn.TextScaled = true
teleportPlayerBtn.Font = Enum.Font.SourceSansSemibold
teleportPlayerBtn.BorderSizePixel = 0
teleportPlayerBtn.Parent = playerTeleportContainer

local teleportPlayerCorner = Instance.new("UICorner")
teleportPlayerCorner.CornerRadius = UDim.new(0, 8)
teleportPlayerCorner.Parent = teleportPlayerBtn

-- Player dropdown functionality
local dropdownOpen = false
local dropdownFrame = nil

playerDropdown.MouseButton1Click:Connect(function()
    if dropdownOpen and dropdownFrame then
        dropdownFrame:Destroy()
        dropdownOpen = false
        return
    end
    
    dropdownFrame = Instance.new("Frame")
    dropdownFrame.Size = UDim2.new(1, -20, 0, 150)
    dropdownFrame.Position = UDim2.new(0, 10, 0, 78)
    dropdownFrame.BackgroundColor3 = THEMES[State.CurrentTheme].Secondary
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.ZIndex = 10
    dropdownFrame.Parent = playerTeleportContainer
    
    local dropCorner = Instance.new("UICorner")
    dropCorner.CornerRadius = UDim.new(0, 8)
    dropCorner.Parent = dropdownFrame
    
    local dropScroll = Instance.new("ScrollingFrame")
    dropScroll.Size = UDim2.new(1, -10, 1, -10)
    dropScroll.Position = UDim2.new(0, 5, 0, 5)
    dropScroll.BackgroundTransparency = 1
    dropScroll.BorderSizePixel = 0
    dropScroll.ScrollBarThickness = 4
    dropScroll.ZIndex = 11
    dropScroll.Parent = dropdownFrame
    
    local dropLayout = Instance.new("UIListLayout")
    dropLayout.Padding = UDim.new(0, 5)
    dropLayout.Parent = dropScroll
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            local playerBtn = Instance.new("TextButton")
            playerBtn.Size = UDim2.new(1, 0, 0, 25)
            playerBtn.BackgroundColor3 = THEMES[State.CurrentTheme].Tertiary
            playerBtn.Text = p.Name
            playerBtn.TextColor3 = THEMES[State.CurrentTheme].Text
            playerBtn.TextScaled = true
            playerBtn.Font = Enum.Font.SourceSans
            playerBtn.BorderSizePixel = 0
            playerBtn.ZIndex = 12
            playerBtn.Parent = dropScroll
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = playerBtn
            
            playerBtn.MouseButton1Click:Connect(function()
                State.SelectedTeleportPlayer = p
                playerDropdown.Text = p.Name
                dropdownFrame:Destroy()
                dropdownOpen = false
            end)
        end
    end
    
    dropdownOpen = true
end)

teleportPlayerBtn.MouseButton1Click:Connect(function()
    if State.SelectedTeleportPlayer then
        teleportToPlayer(State.SelectedTeleportPlayer)
    else
        createNotification("Please select a player first!", 3)
    end
end)

-- Item Teleport Button
local itemTeleportBtn = Instance.new("TextButton")
itemTeleportBtn.Name = "ItemTeleportButton"
itemTeleportBtn.Size = UDim2.new(1, -10, 0, 50)
itemTeleportBtn.BackgroundColor3 = THEMES[State.CurrentTheme].Accent
itemTeleportBtn.Text = "Teleport to Nearest Item"
itemTeleportBtn.TextColor3 = Color3.new(1, 1, 1)
itemTeleportBtn.TextScaled = true
itemTeleportBtn.Font = Enum.Font.SourceSansSemibold
itemTeleportBtn.BorderSizePixel = 0
itemTeleportBtn.Parent = teleportFrame

local itemTeleportCorner = Instance.new("UICorner")
itemTeleportCorner.CornerRadius = UDim.new(0, 10)
itemTeleportCorner.Parent = itemTeleportBtn

itemTeleportBtn.MouseButton1Click:Connect(function()
    teleportToNearestItem()
end)

-- Main SubTab switching
for name, btn in pairs(mainSubTabButtons) do
    btn.MouseButton1Click:Connect(function()
        State.CurrentMainSubTab = name
        
        for n, b in pairs(mainSubTabButtons) do
            b.BackgroundColor3 = n == name and THEMES[State.CurrentTheme].Accent or THEMES[State.CurrentTheme].Tertiary
        end
        
        for n, frame in pairs(mainSubTabFrames) do
            frame.Visible = n == name
        end
    end)
end

-- Settings Tab
local settingsTab = Instance.new("Frame")
settingsTab.Name = "SettingsTab"
settingsTab.Size = UDim2.new(1, 0, 1, 0)
settingsTab.BackgroundTransparency = 1
settingsTab.Visible = false
settingsTab.Parent = contentFrame
tabFrames.Settings = settingsTab

-- Settings SubTabs
local settingsSubTabContainer = Instance.new("Frame")
settingsSubTabContainer.Name = "SettingsSubTabs"
settingsSubTabContainer.Size = UDim2.new(1, -10, 0, 35)
settingsSubTabContainer.Position = UDim2.new(0, 5, 0, 5)
settingsSubTabContainer.BackgroundTransparency = 1
settingsSubTabContainer.Parent = settingsTab

local settingsSubTabs = {"Themes", "RGB Sub-Tab"}
local settingsSubTabButtons = {}

for i, subTabName in ipairs(settingsSubTabs) do
    local subTabBtn = Instance.new("TextButton")
    subTabBtn.Name = subTabName:gsub(" ", "") .. "SubTab"
    subTabBtn.Size = UDim2.new(0.5, -5, 1, 0)
    subTabBtn.Position = UDim2.new(0.5 * (i-1), 5 * (i-1), 0, 0)
    subTabBtn.BackgroundColor3 = i == 1 and THEMES[State.CurrentTheme].Accent or THEMES[State.CurrentTheme].Tertiary
    subTabBtn.Text = subTabName
    subTabBtn.TextColor3 = THEMES[State.CurrentTheme].Text
    subTabBtn.TextScaled = true
    subTabBtn.Font = Enum.Font.SourceSans
    subTabBtn.BorderSizePixel = 0
    subTabBtn.Parent = settingsSubTabContainer
    
    local subTabCorner = Instance.new("UICorner")
    subTabCorner.CornerRadius = UDim.new(0, 8)
    subTabCorner.Parent = subTabBtn
    
    settingsSubTabButtons[subTabName] = subTabBtn
end

-- Theme Selection Frame
local themeFrame = Instance.new("ScrollingFrame")
themeFrame.Name = "ThemeFrame"
themeFrame.Size = UDim2.new(1, -10, 1, -50)
themeFrame.Position = UDim2.new(0, 5, 0, 45)
themeFrame.BackgroundTransparency = 1
themeFrame.BorderSizePixel = 0
themeFrame.ScrollBarThickness = 6
themeFrame.ScrollBarImageColor3 = THEMES[State.CurrentTheme].Accent
themeFrame.Visible = true
themeFrame.Parent = settingsTab

local themeLayout = Instance.new("UIListLayout")
themeLayout.Padding = UDim.new(0, 8)
themeLayout.SortOrder = Enum.SortOrder.LayoutOrder
themeLayout.Parent = themeFrame

-- Apply Theme Function
function applyTheme(themeName)
    State.CurrentTheme = themeName
    local theme = THEMES[themeName]
    
    -- Update all UI colors
    mainFrame.BackgroundColor3 = theme.Primary
    header.BackgroundColor3 = theme.Secondary
    headerCover.BackgroundColor3 = theme.Secondary
    title.TextColor3 = theme.Text
    subtitle.TextColor3 = theme.TextSecondary
    contentFrame.BackgroundColor3 = theme.Secondary
    
    -- Update buttons
    closeBtn.BackgroundColor3 = theme.Danger
    minimizeBtn.BackgroundColor3 = theme.Tertiary
    
    -- Update tabs
    for name, btn in pairs(tabButtons) do
        btn.BackgroundColor3 = State.CurrentTab == name and theme.Accent or theme.Tertiary
        btn.TextColor3 = theme.Text
    end
    
    -- Update all elements
    for _, obj in pairs(screenGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            obj.TextColor3 = theme.Text
        elseif obj:IsA("ScrollingFrame") then
            obj.ScrollBarImageColor3 = theme.Accent
        end
    end
    
    createNotification("Theme changed to " .. themeName, 2)
end

-- Create theme buttons
for themeName, themeColors in pairs(THEMES) do
    local themeBtn = Instance.new("TextButton")
    themeBtn.Name = themeName .. "Theme"
    themeBtn.Size = UDim2.new(1, -10, 0, 60)
    themeBtn.BackgroundColor3 = themeColors.Primary
    themeBtn.BorderColor3 = themeColors.Accent
    themeBtn.BorderSizePixel = State.CurrentTheme == themeName and 3 or 0
    themeBtn.Text = ""
    themeBtn.Parent = themeFrame
    
    local themeBtnCorner = Instance.new("UICorner")
    themeBtnCorner.CornerRadius = UDim.new(0, 10)
    themeBtnCorner.Parent = themeBtn
    
    local themeNameLabel = Instance.new("TextLabel")
    themeNameLabel.Size = UDim2.new(0.5, 0, 1, 0)
    themeNameLabel.Position = UDim2.new(0, 15, 0, 0)
    themeNameLabel.BackgroundTransparency = 1
    themeNameLabel.Text = themeName
    themeNameLabel.TextColor3 = themeColors.Text
    themeNameLabel.TextScaled = true
    themeNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    themeNameLabel.Font = Enum.Font.SourceSansSemibold
    themeNameLabel.Parent = themeBtn
    
    -- Color preview
    local previewContainer = Instance.new("Frame")
    previewContainer.Size = UDim2.new(0, 150, 0, 30)
    previewContainer.Position = UDim2.new(1, -160, 0.5, -15)
    previewContainer.BackgroundTransparency = 1
    previewContainer.Parent = themeBtn
    
    local colors = {themeColors.Primary, themeColors.Secondary, themeColors.Accent, themeColors.Success}
    for i, color in ipairs(colors) do
        local colorPreview = Instance.new("Frame")
        colorPreview.Size = UDim2.new(0.25, -2, 1, 0)
        colorPreview.Position = UDim2.new(0.25 * (i-1), 2 * (i-1), 0, 0)
        colorPreview.BackgroundColor3 = color
        colorPreview.BorderSizePixel = 0
        colorPreview.Parent = previewContainer
        
        local prevCorner = Instance.new("UICorner")
        prevCorner.CornerRadius = UDim.new(0, 4)
        prevCorner.Parent = colorPreview
    end
    
    themeBtn.MouseButton1Click:Connect(function()
        -- Update border indicators
        for _, child in pairs(themeFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child.BorderSizePixel = 0
            end
        end
        themeBtn.BorderSizePixel = 3
        
        applyTheme(themeName)
    end)
end

-- RGB Customization Frame (Placeholder for now)
local rgbFrame = Instance.new("Frame")
rgbFrame.Name = "RGBFrame"
rgbFrame.Size = UDim2.new(1, -10, 1, -50)
rgbFrame.Position = UDim2.new(0, 5, 0, 45)
rgbFrame.BackgroundTransparency = 1
rgbFrame.Visible = false
rgbFrame.Parent = settingsTab

local rgbLabel = Instance.new("TextLabel")
rgbLabel.Size = UDim2.new(1, 0, 0, 50)
rgbLabel.BackgroundTransparency = 1
rgbLabel.Text = "RGB Customization Coming Soon!"
rgbLabel.TextColor3 = THEMES[State.CurrentTheme].Text
rgbLabel.TextScaled = true
rgbLabel.Font = Enum.Font.SourceSans
rgbLabel.Parent = rgbFrame

-- Settings SubTab switching
for name, btn in pairs(settingsSubTabButtons) do
    btn.MouseButton1Click:Connect(function()
        State.CurrentSettingsSubTab = name
        
        for n, b in pairs(settingsSubTabButtons) do
            b.BackgroundColor3 = n == name and THEMES[State.CurrentTheme].Accent or THEMES[State.CurrentTheme].Tertiary
        end
        
        themeFrame.Visible = name == "Themes"
        rgbFrame.Visible = name == "RGB Sub-Tab"
    end)
end

-- Credits Tab
local creditsTab = Instance.new("Frame")
creditsTab.Name = "CreditsTab"
creditsTab.Size = UDim2.new(1, -10, 1, -10)
creditsTab.Position = UDim2.new(0, 5, 0, 5)
creditsTab.BackgroundTransparency = 1
creditsTab.Visible = false
creditsTab.Parent = contentFrame
tabFrames.Credits = creditsTab

local creditsLayout = Instance.new("UIListLayout")
creditsLayout.Padding = UDim.new(0, 20)
creditsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
creditsLayout.SortOrder = Enum.SortOrder.LayoutOrder
creditsLayout.Parent = creditsTab

-- Professional Credits Design
local logoContainer = Instance.new("Frame")
logoContainer.Name = "LogoContainer"
logoContainer.Size = UDim2.new(0.9, 0, 0, 80)
logoContainer.BackgroundColor3 = THEMES[State.CurrentTheme].Tertiary
logoContainer.BorderSizePixel = 0
logoContainer.Parent = creditsTab

local logoCorner = Instance.new("UICorner")
logoCorner.CornerRadius = UDim.new(0, 12)
logoCorner.Parent = logoContainer

local logoGradient = Instance.new("UIGradient")
logoGradient.Rotation = 135
logoGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, THEMES[State.CurrentTheme].Accent),
    ColorSequenceKeypoint.new(1, THEMES[State.CurrentTheme].AccentDark or THEMES[State.CurrentTheme].Accent)
}
logoGradient.Parent = logoContainer

local logoLabel = Instance.new("TextLabel")
logoLabel.Name = "Logo"
logoLabel.Size = UDim2.new(1, 0, 0.6, 0)
logoLabel.Position = UDim2.new(0, 0, 0, 5)
logoLabel.BackgroundTransparency = 1
logoLabel.Text = CONFIG.SCRIPT_NAME
logoLabel.TextColor3 = Color3.new(1, 1, 1)
logoLabel.TextScaled = true
logoLabel.Font = Enum.Font.SourceSansBold
logoLabel.Parent = logoContainer

local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "Version"
versionLabel.Size = UDim2.new(1, 0, 0.4, 0)
versionLabel.Position = UDim2.new(0, 0, 0.5, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "Version " .. CONFIG.VERSION
versionLabel.TextColor3 = Color3.new(1, 1, 1)
versionLabel.TextTransparency = 0.3
versionLabel.TextScaled = true
versionLabel.Font = Enum.Font.SourceSansItalic
versionLabel.Parent = logoContainer

-- Creator Info
local creatorContainer = Instance.new("Frame")
creatorContainer.Name = "CreatorContainer"
creatorContainer.Size = UDim2.new(0.9, 0, 0, 100)
creatorContainer.BackgroundColor3 = THEMES[State.CurrentTheme].Tertiary
creatorContainer.BorderSizePixel = 0
creatorContainer.Parent = creditsTab

local creatorCorner = Instance.new("UICorner")
creatorCorner.CornerRadius = UDim.new(0, 12)
creatorCorner.Parent = creatorContainer

local creatorTitle = Instance.new("TextLabel")
creatorTitle.Size = UDim2.new(1, 0, 0, 30)
creatorTitle.Position = UDim2.new(0, 0, 0, 10)
creatorTitle.BackgroundTransparency = 1
creatorTitle.Text = "Created by"
creatorTitle.TextColor3 = THEMES[State.CurrentTheme].TextSecondary
creatorTitle.TextScaled = true
creatorTitle.Font = Enum.Font.SourceSans
creatorTitle.Parent = creatorContainer

local creatorName = Instance.new("TextLabel")
creatorName.Size = UDim2.new(1, 0, 0, 35)
creatorName.Position = UDim2.new(0, 0, 0, 35)
creatorName.BackgroundTransparency = 1
creatorName.Text = CONFIG.CREATOR
creatorName.TextColor3 = THEMES[State.CurrentTheme].Accent
creatorName.TextScaled = true
creatorName.Font = Enum.Font.SourceSansBold
creatorName.Parent = creatorContainer

local teamLabel = Instance.new("TextLabel")
teamLabel.Size = UDim2.new(1, 0, 0, 25)
teamLabel.Position = UDim2.new(0, 0, 0, 70)
teamLabel.BackgroundTransparency = 1
teamLabel.Text = CONFIG.TEAM
teamLabel.TextColor3 = THEMES[State.CurrentTheme].Text
teamLabel.TextScaled = true
teamLabel.Font = Enum.Font.SourceSansSemibold
teamLabel.Parent = creatorContainer

-- Tab Switching
for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        State.CurrentTab = name
        
        for n, b in pairs(tabButtons) do
            b.BackgroundColor3 = n == name and THEMES[State.CurrentTheme].Accent or THEMES[State.CurrentTheme].Tertiary
        end
        
        for n, frame in pairs(tabFrames) do
            frame.Visible = n == name
        end
    end)
end

-- Minimize functionality
minimizeBtn.MouseButton1Click:Connect(function()
    State.UIMinimized = not State.UIMinimized
    
    if State.UIMinimized then
        contentFrame.Visible = false
        tabContainer.Visible = false
        mainFrame.Size = UDim2.new(0, 550, 0, 55)
        minimizeBtn.Text = "□"
    else
        contentFrame.Visible = true
        tabContainer.Visible = true
        mainFrame.Size = UDim2.new(0, 550, 0, 400)
        minimizeBtn.Text = "—"
    end
end)

-- Close button functionality
closeBtn.MouseButton1Click:Connect(function()
    State.UIVisible = false
    screenGui.Enabled = false
end)

-- Toggle UI with key
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.RightShift then
        State.UIVisible = not State.UIVisible
        screenGui.Enabled = State.UIVisible
    end
end)

-- Make frame draggable
local dragging = false
local dragStart = nil
local startPos = nil

local function updateDrag(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)

-- Add UI to PlayerGui
screenGui.Parent = playerGui

-- Initialize ESP auto-refresh
startESPAutoRefresh()

-- Initialize message
spawn(function()
    wait(1)
    createNotification("RenD: Skyven v2.0 Loaded!", 4)
    wait(2)
    createNotification("Press Right Shift to toggle UI", 3)
end)

print("===============================================")
print(CONFIG.SCRIPT_NAME .. " - Professional Edition")
print("Version: " .. CONFIG.VERSION)
print("Created by: " .. CONFIG.CREATOR)
print(CONFIG.TEAM)
print("Press Right Shift to toggle UI")
print("===============================================")
