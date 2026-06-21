--// FIXED Enhanced Modular GUI Dumper Script - Complete Nested Capture
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Constants
local MAX_TEXTBOX_LENGTH = 16384 -- Safe limit for TextBox (16K characters)

-- GUI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.Name = "ModularGuiDumper"
ScreenGui.ResetOnSpawn = false

-- Main Frame
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 520, 0, 500)
Frame.Position = UDim2.new(0.5, -260, 0.5, -250)
Frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Frame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -90, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.Text = "FIXED GUI Dumper v2.1"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 16
TitleLabel.Parent = TitleBar

-- Window Controls
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -60, 0, 0)
MinimizeBtn.Text = "_"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 18
MinimizeBtn.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.BorderSizePixel = 0
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 18
CloseBtn.Parent = TitleBar

-- Content Frame
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -30)
ContentFrame.Position = UDim2.new(0, 0, 0, 30)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = Frame

-- Path Input
local PathLabel = Instance.new("TextLabel")
PathLabel.Size = UDim2.new(0, 100, 0, 25)
PathLabel.Position = UDim2.new(0, 10, 0, 10)
PathLabel.Text = "GUI Path:"
PathLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
PathLabel.BackgroundTransparency = 1
PathLabel.TextXAlignment = Enum.TextXAlignment.Left
PathLabel.Font = Enum.Font.SourceSans
PathLabel.TextSize = 14
PathLabel.Parent = ContentFrame

local PathBox = Instance.new("TextBox")
PathBox.Size = UDim2.new(1, -20, 0, 30)
PathBox.Position = UDim2.new(0, 10, 0, 35)
PathBox.Text = "game:GetService(\"StarterGui\").Shop"
PathBox.TextColor3 = Color3.fromRGB(255, 255, 255)
PathBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
PathBox.BorderColor3 = Color3.fromRGB(70, 70, 70)
PathBox.BorderSizePixel = 1
PathBox.ClearTextOnFocus = false
PathBox.Font = Enum.Font.Code
PathBox.TextSize = 14
PathBox.Parent = ContentFrame

-- Action Buttons
local ButtonFrame = Instance.new("Frame")
ButtonFrame.Size = UDim2.new(1, -20, 0, 35)
ButtonFrame.Position = UDim2.new(0, 10, 0, 75)
ButtonFrame.BackgroundTransparency = 1
ButtonFrame.Parent = ContentFrame

local SelectBtn = Instance.new("TextButton")
SelectBtn.Size = UDim2.new(0, 120, 1, 0)
SelectBtn.Position = UDim2.new(0, 0, 0, 0)
SelectBtn.Text = "Select GUI"
SelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
SelectBtn.BorderSizePixel = 0
SelectBtn.Font = Enum.Font.SourceSansSemibold
SelectBtn.TextSize = 14
SelectBtn.Parent = ButtonFrame

local GenerateBtn = Instance.new("TextButton")
GenerateBtn.Size = UDim2.new(0, 120, 1, 0)
GenerateBtn.Position = UDim2.new(0, 130, 0, 0)
GenerateBtn.Text = "Generate Fixed"
GenerateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GenerateBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
GenerateBtn.BorderSizePixel = 0
GenerateBtn.Font = Enum.Font.SourceSansSemibold
GenerateBtn.TextSize = 14
GenerateBtn.Parent = ButtonFrame

local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(0, 120, 1, 0)
ClearBtn.Position = UDim2.new(0, 260, 0, 0)
ClearBtn.Text = "Clear"
ClearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 50)
ClearBtn.BorderSizePixel = 0
ClearBtn.Font = Enum.Font.SourceSansSemibold
ClearBtn.TextSize = 14
ClearBtn.Parent = ButtonFrame

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 25)
StatusLabel.Position = UDim2.new(0, 10, 0, 120)
StatusLabel.Text = "Status: Ready - FIXED VERSION (No ClassName errors!)"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
StatusLabel.BorderSizePixel = 0
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 14
StatusLabel.Parent = ContentFrame

-- Code Output Label
local CodeLabel = Instance.new("TextLabel")
CodeLabel.Size = UDim2.new(0, 200, 0, 25)
CodeLabel.Position = UDim2.new(0, 10, 0, 155)
CodeLabel.Text = "Generated Code:"
CodeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CodeLabel.BackgroundTransparency = 1
CodeLabel.TextXAlignment = Enum.TextXAlignment.Left
CodeLabel.Font = Enum.Font.SourceSans
CodeLabel.TextSize = 14
CodeLabel.Parent = ContentFrame

-- Page Navigation
local PageFrame = Instance.new("Frame")
PageFrame.Size = UDim2.new(0, 300, 0, 25)
PageFrame.Position = UDim2.new(1, -310, 0, 155)
PageFrame.BackgroundTransparency = 1
PageFrame.Parent = ContentFrame

local PrevPageBtn = Instance.new("TextButton")
PrevPageBtn.Size = UDim2.new(0, 60, 1, 0)
PrevPageBtn.Position = UDim2.new(0, 0, 0, 0)
PrevPageBtn.Text = "< Prev"
PrevPageBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PrevPageBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
PrevPageBtn.BorderSizePixel = 0
PrevPageBtn.Font = Enum.Font.SourceSans
PrevPageBtn.TextSize = 12
PrevPageBtn.Visible = false
PrevPageBtn.Parent = PageFrame

local PageLabel = Instance.new("TextLabel")
PageLabel.Size = UDim2.new(0, 100, 1, 0)
PageLabel.Position = UDim2.new(0, 70, 0, 0)
PageLabel.Text = "Page 1/1"
PageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
PageLabel.BackgroundTransparency = 1
PageLabel.Font = Enum.Font.SourceSans
PageLabel.TextSize = 12
PageLabel.Visible = false
PageLabel.Parent = PageFrame

local NextPageBtn = Instance.new("TextButton")
NextPageBtn.Size = UDim2.new(0, 60, 1, 0)
NextPageBtn.Position = UDim2.new(0, 180, 0, 0)
NextPageBtn.Text = "Next >"
NextPageBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NextPageBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
NextPageBtn.BorderSizePixel = 0
NextPageBtn.Font = Enum.Font.SourceSans
NextPageBtn.TextSize = 12
NextPageBtn.Visible = false
NextPageBtn.Parent = PageFrame

-- Code Display
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 0, 200)
ScrollFrame.Position = UDim2.new(0, 10, 0, 185)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
ScrollFrame.BorderColor3 = Color3.fromRGB(70, 70, 70)
ScrollFrame.BorderSizePixel = 1
ScrollFrame.ScrollBarThickness = 8
ScrollFrame.CanvasSize = UDim2.new(0, 0, 2, 0)
ScrollFrame.Parent = ContentFrame

local CodeBox = Instance.new("TextBox")
CodeBox.Size = UDim2.new(1, -10, 1, -5)
CodeBox.Position = UDim2.new(0, 0, 0, 0)
CodeBox.Text = ""
CodeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
CodeBox.BackgroundTransparency = 1
CodeBox.MultiLine = true
CodeBox.TextWrapped = false
CodeBox.TextXAlignment = Enum.TextXAlignment.Left
CodeBox.TextYAlignment = Enum.TextYAlignment.Top
CodeBox.ClearTextOnFocus = false
CodeBox.Font = Enum.Font.Code
CodeBox.TextSize = 13
CodeBox.Parent = ScrollFrame

-- Copy Buttons
local CopyFrame = Instance.new("Frame")
CopyFrame.Size = UDim2.new(1, -20, 0, 35)
CopyFrame.Position = UDim2.new(0, 10, 0, 390)
CopyFrame.BackgroundTransparency = 1
CopyFrame.Parent = ContentFrame

local CopyPageBtn = Instance.new("TextButton")
CopyPageBtn.Size = UDim2.new(0.48, 0, 1, 0)
CopyPageBtn.Position = UDim2.new(0, 0, 0, 0)
CopyPageBtn.Text = "Copy Current Page"
CopyPageBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyPageBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
CopyPageBtn.BorderSizePixel = 0
CopyPageBtn.Font = Enum.Font.SourceSansSemibold
CopyPageBtn.TextSize = 14
CopyPageBtn.Parent = CopyFrame

local CopyAllBtn = Instance.new("TextButton")
CopyAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
CopyAllBtn.Position = UDim2.new(0.52, 0, 0, 0)
CopyAllBtn.Text = "Copy All Code"
CopyAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyAllBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
CopyAllBtn.BorderSizePixel = 0
CopyAllBtn.Font = Enum.Font.SourceSansSemibold
CopyAllBtn.TextSize = 14
CopyAllBtn.Parent = CopyFrame

-- Save to File Button
local SaveFileBtn = Instance.new("TextButton")
SaveFileBtn.Size = UDim2.new(1, -20, 0, 30)
SaveFileBtn.Position = UDim2.new(0, 10, 0, 430)
SaveFileBtn.Text = "Print Full Code to Console"
SaveFileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveFileBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
SaveFileBtn.BorderSizePixel = 0
SaveFileBtn.Font = Enum.Font.SourceSansSemibold
SaveFileBtn.TextSize = 14
SaveFileBtn.Parent = ContentFrame

-- FIXED Properties List - Only essential properties that work
local Properties = {
    -- Basic Properties (NO ClassName - it's read-only!)
    "Name", "Text", "Size", "Position", "BackgroundColor3", "TextColor3", "Visible",
    "Font", "TextSize", "BorderSizePixel", "BorderColor3", "AnchorPoint", "Rotation",
    "BackgroundTransparency", "TextTransparency", "ZIndex", "LayoutOrder",
    
    -- Image Properties
    "Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter", "SliceScale", 
    "TileSize", "ImageRectOffset", "ImageRectSize", "ResampleMode",
    
    -- Text Properties
    "TextWrapped", "TextScaled", "TextStrokeTransparency", "TextStrokeColor3", 
    "TextXAlignment", "TextYAlignment", "RichText", "TextTruncate", "LineHeight", "MaxVisibleGraphemes",
    
    -- TextBox Specific
    "PlaceholderText", "ClearTextOnFocus", "MultiLine", "TextEditable", "ShowNativeInput",
    
    -- Interactive Properties
    "Active", "Selectable", "ClipsDescendants", "AutomaticSize", "Enabled", "Modal",
    
    -- Scrolling Frame Properties
    "ScrollBarThickness", "ScrollingDirection", "CanvasSize", "CanvasPosition", 
    "ScrollBarImageColor3", "ScrollBarImageTransparency", "TopImage", "MidImage", "BottomImage", 
    "AutomaticCanvasSize", "ScrollingEnabled", "ElasticBehavior", "HorizontalScrollBarInset", 
    "VerticalScrollBarInset", "VerticalScrollBarPosition",
    
    -- Container Properties
    "DisplayOrder", "ResetOnSpawn", "IgnoreGuiInset", "ScreenInsets",
    
    -- Special Properties
    "GroupTransparency", "GroupColor3", "NextSelectionUp", "NextSelectionDown", 
    "NextSelectionLeft", "NextSelectionRight", "SelectionImageObject", "SelectionOrder",
    
    -- Style Properties
    "Style", "AutoButtonColor", "Selected"
}

-- Global variables
local usedNames = {}
local selectedGui = nil
local codeChunks = {}
local currentPage = 1
local fullCode = ""
local processedCount = 0

-- Function to generate unique variable names
local function generateUniqueVarName(baseName)
    baseName = baseName:gsub("[^%w_]", ""):gsub("^%d", "")
    if baseName == "" then baseName = "Element" end
    
    if baseName:match("^%d") then
        baseName = "Element" .. baseName
    end
    
    if not usedNames[baseName] then
        usedNames[baseName] = true
        return baseName
    end
    
    local counter = 1
    local newName = baseName .. counter
    while usedNames[newName] do
        counter = counter + 1
        newName = baseName .. counter
    end
    
    usedNames[newName] = true
    return newName
end

-- Function to format property values
local function formatPropertyValue(prop, val)
    if typeof(val) == "string" then
        local escaped = val:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return "\"" .. escaped .. "\""
    elseif typeof(val) == "boolean" then
        return tostring(val)
    elseif typeof(val) == "Color3" then
        return "Color3.fromRGB("..math.floor(val.R*255)..","..math.floor(val.G*255)..","..math.floor(val.B*255)..")"
    elseif typeof(val) == "UDim2" then
        return "UDim2.new("..val.X.Scale..","..val.X.Offset..","..val.Y.Scale..","..val.Y.Offset..")"
    elseif typeof(val) == "UDim" then
        return "UDim.new("..val.Scale..","..val.Offset..")"
    elseif typeof(val) == "Vector2" then
        return "Vector2.new("..val.X..","..val.Y..")"
    elseif typeof(val) == "Vector3" then
        return "Vector3.new("..val.X..","..val.Y..","..val.Z..")"
    elseif typeof(val) == "number" then
        return tostring(val)
    elseif typeof(val) == "EnumItem" then
        return tostring(val)
    elseif typeof(val) == "Rect" then
        return "Rect.new("..val.Min.X..","..val.Min.Y..","..val.Max.X..","..val.Max.Y..")"
    end
    return nil
end

-- COMPLETELY FIXED serialization - Exactly like website version
local function serialize(instance, depth, parentVarName, isRoot)
    depth = depth or 0
    local lines = {}
    
    -- Skip LocalScript and Script instances (they cause issues without source)
    if instance.ClassName == "LocalScript" or instance.ClassName == "Script" then
        return lines, nil
    end
    
    processedCount = processedCount + 1
    local varName = generateUniqueVarName(instance.Name)
    
    -- Create instance comment and declaration
    table.insert(lines, "")
    table.insert(lines, "-- Create " .. instance.ClassName .. ": " .. instance.Name)
    table.insert(lines, "local " .. varName .. " = Instance.new(\"" .. instance.ClassName .. "\")")
    
    -- Set properties (only non-default ones to keep it clean)
    for _, prop in ipairs(Properties) do
        local success, val = pcall(function() return instance[prop] end)
        
        if success and val ~= nil then
            -- Check if it's different from default
            local isDefault = false
            pcall(function()
                local temp = Instance.new(instance.ClassName)
                isDefault = (temp[prop] == val)
                temp:Destroy()
            end)
            
            if not isDefault then
                local formattedValue = formatPropertyValue(prop, val)
                if formattedValue then
                    table.insert(lines, varName .. "." .. prop .. " = " .. formattedValue)
                end
            end
        end
    end
    
    -- Process children BEFORE setting parent (like website)
    for _, child in ipairs(instance:GetChildren()) do
        local childLines, childVarName = serialize(child, depth + 1, varName, false)
        if childVarName then -- Only add if child was successfully processed
            for _, line in ipairs(childLines) do
                table.insert(lines, line)
            end
        end
    end
    
    -- Set parent (clean like website)
    if parentVarName then
        table.insert(lines, varName .. ".Parent = " .. parentVarName)
    end
    
    return lines, varName
end

-- Split code into chunks
local function splitIntoChunks(code)
    local chunks = {}
    local lines = code:split("\n")
    local currentChunk = ""
    
    for _, line in ipairs(lines) do
        local testChunk = currentChunk .. line .. "\n"
        if #testChunk > MAX_TEXTBOX_LENGTH then
            if #currentChunk > 0 then
                table.insert(chunks, currentChunk)
                currentChunk = line .. "\n"
            else
                -- Single line too long, split it
                local splitLine = line
                while #splitLine > MAX_TEXTBOX_LENGTH do
                    table.insert(chunks, splitLine:sub(1, MAX_TEXTBOX_LENGTH))
                    splitLine = splitLine:sub(MAX_TEXTBOX_LENGTH + 1)
                end
                if #splitLine > 0 then
                    currentChunk = splitLine .. "\n"
                end
            end
        else
            currentChunk = testChunk
        end
    end
    
    if #currentChunk > 0 then
        table.insert(chunks, currentChunk)
    end
    
    return chunks
end

-- WORKING solution for large GUIs - Function-based to avoid 200 local limit
local function serializeForStudio(instance)
    usedNames = {}
    processedCount = 0
    local allElements = {}
    
    -- First pass: collect all elements and their info
    local function collectElements(inst, parentVar, depth)
        if inst.ClassName == "LocalScript" or inst.ClassName == "Script" then
            return
        end
        
        processedCount = processedCount + 1
        local varName = generateUniqueVarName(inst.Name)
        
        local element = {
            instance = inst,
            varName = varName,
            parentVar = parentVar,
            depth = depth or 0,
            properties = {},
            children = {}
        }
        
        -- Collect properties
        for _, prop in ipairs(Properties) do
            local success, val = pcall(function() return inst[prop] end)
            if success and val ~= nil then
                local isDefault = false
                pcall(function()
                    local temp = Instance.new(inst.ClassName)
                    isDefault = (temp[prop] == val)
                    temp:Destroy()
                end)
                if not isDefault then
                    local formattedValue = formatPropertyValue(prop, val)
                    if formattedValue then
                        table.insert(element.properties, {prop = prop, value = formattedValue})
                    end
                end
            end
        end
        
        table.insert(allElements, element)
        
        -- Recursively collect children
        for _, child in ipairs(inst:GetChildren()) do
            collectElements(child, varName, (depth or 0) + 1)
        end
        
        return element
    end
    
    collectElements(instance, nil, 0)
    
    local lines = {}
    table.insert(lines, "-- Complete GUI Script - FIXED FOR LARGE GUIs")
    table.insert(lines, "-- IMPORTANT: This must be a LocalScript, NOT a ServerScript!")
    table.insert(lines, "-- Place this LocalScript in StarterPlayerScripts or StarterGui")
    table.insert(lines, "-- This script uses functions to avoid Roblox's 200 local variable limit")
    table.insert(lines, "")
    table.insert(lines, "local Players = game:GetService(\"Players\")")
    table.insert(lines, "local LocalPlayer = Players.LocalPlayer")
    table.insert(lines, "local PlayerGui = LocalPlayer:WaitForChild(\"PlayerGui\")")
    table.insert(lines, "")
    table.insert(lines, "-- Storage for all GUI elements")
    table.insert(lines, "local gui = {}")
    table.insert(lines, "")
    
    -- Split elements into chunks of 150 to stay well below 200 limit
    local CHUNK_SIZE = 150
    local chunks = {}
    for i = 1, #allElements, CHUNK_SIZE do
        local chunk = {}
        for j = i, math.min(i + CHUNK_SIZE - 1, #allElements) do
            table.insert(chunk, allElements[j])
        end
        table.insert(chunks, chunk)
    end
    
    -- Generate functions for each chunk
    for chunkIndex, chunk in ipairs(chunks) do
        table.insert(lines, "-- Function " .. chunkIndex .. ": Create elements " .. ((chunkIndex-1)*CHUNK_SIZE + 1) .. " to " .. math.min(chunkIndex*CHUNK_SIZE, #allElements))
        table.insert(lines, "local function createElements" .. chunkIndex .. "()")
        
        for _, element in ipairs(chunk) do
            table.insert(lines, "    -- Create " .. element.instance.ClassName .. ": " .. element.instance.Name)
            table.insert(lines, "    gui." .. element.varName .. " = Instance.new(\"" .. element.instance.ClassName .. "\")")
            
            for _, prop in ipairs(element.properties) do
                table.insert(lines, "    gui." .. element.varName .. "." .. prop.prop .. " = " .. prop.value)
            end
        end
        
        table.insert(lines, "end")
        table.insert(lines, "")
    end
    
    -- Generate parenting function
    table.insert(lines, "-- Set up parent relationships")
    table.insert(lines, "local function setupParenting()")
    
    -- Handle ScreenGui specially
    local rootElement = allElements[1]
    if rootElement.instance.ClassName == "ScreenGui" then
        table.insert(lines, "    gui." .. rootElement.varName .. ".Parent = PlayerGui")
    else
        table.insert(lines, "    -- Create container for non-ScreenGui root")
        table.insert(lines, "    local container = Instance.new(\"ScreenGui\")")
        table.insert(lines, "    container.Name = \"GeneratedGui\"")
        table.insert(lines, "    container.Parent = PlayerGui")
        table.insert(lines, "    gui." .. rootElement.varName .. ".Parent = container")
    end
    
    -- Set up all other parent relationships
    for _, element in ipairs(allElements) do
        if element.parentVar then
            table.insert(lines, "    gui." .. element.varName .. ".Parent = gui." .. element.parentVar)
        end
    end
    
    table.insert(lines, "end")
    table.insert(lines, "")
    
    -- Generate button events function
    table.insert(lines, "-- Set up button events")
    table.insert(lines, "local function setupEvents()")
    local hasButtons = false
    for _, element in ipairs(allElements) do
        if element.varName:find("Button") then
            hasButtons = true
            table.insert(lines, "    if gui." .. element.varName .. " and gui." .. element.varName .. ".MouseButton1Click then")
            table.insert(lines, "        gui." .. element.varName .. ".MouseButton1Click:Connect(function()")
            table.insert(lines, "            print(\"" .. element.varName .. " was clicked!\")")
            table.insert(lines, "            -- Add your custom logic here")
            table.insert(lines, "        end)")
            table.insert(lines, "    end")
        end
    end
    if not hasButtons then
        table.insert(lines, "    -- No buttons found")
    end
    table.insert(lines, "end")
    table.insert(lines, "")
    
    -- Execute everything
    table.insert(lines, "-- Execute all functions to create the GUI")
    for i = 1, #chunks do
        table.insert(lines, "createElements" .. i .. "()")
    end
    table.insert(lines, "setupParenting()")
    table.insert(lines, "setupEvents()")
    table.insert(lines, "")
    table.insert(lines, "print(\"Large GUI created successfully with " .. processedCount .. " elements!\")")
    table.insert(lines, "print(\"All elements stored in 'gui' table for easy access\")")
    
    return table.concat(lines, "\n")
end

-- Parse path
local function parsePath(pathStr)
    local success, result = pcall(function()
        local func = loadstring("return " .. pathStr)
        if func then
            return func()
        end
    end)
    
    if success and result then
        return result
    end
    return nil
end

-- Update status
local function updateStatus(text, color)
    StatusLabel.Text = "Status: " .. text
    StatusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
end

-- Display current page
local function displayPage()
    if #codeChunks > 0 then
        CodeBox.Text = codeChunks[currentPage] or ""
        PageLabel.Text = "Page " .. currentPage .. "/" .. #codeChunks
        
        -- Update scroll
        local textSize = CodeBox.TextBounds
        ScrollFrame.CanvasSize = UDim2.new(0, textSize.X + 20, 0, math.max(200, textSize.Y + 10))
        
        -- Update navigation buttons
        PrevPageBtn.Visible = #codeChunks > 1
        NextPageBtn.Visible = #codeChunks > 1
        PageLabel.Visible = #codeChunks > 1
        
        PrevPageBtn.BackgroundColor3 = currentPage > 1 and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(40, 40, 40)
        NextPageBtn.BackgroundColor3 = currentPage < #codeChunks and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(40, 40, 40)
    end
end

-- Button Handlers
SelectBtn.MouseButton1Click:Connect(function()
    local pathStr = PathBox.Text
    if pathStr == "" then
        updateStatus("Please enter a GUI path!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    local obj = parsePath(pathStr)
    if obj and (obj:IsA("GuiObject") or obj:IsA("ScreenGui") or obj:IsA("LayerCollector")) then
        selectedGui = obj
        
        -- Count nested elements for preview
        local totalElements = 0
        pcall(function()
            totalElements = #obj:GetDescendants() + 1
        end)
        
        updateStatus("Selected: " .. obj.Name .. " (" .. totalElements .. " total elements found)", Color3.fromRGB(100, 255, 100))
    else
        updateStatus("Invalid GUI path or object not found!", Color3.fromRGB(255, 100, 100))
    end
end)

GenerateBtn.MouseButton1Click:Connect(function()
    if not selectedGui then
        updateStatus("Please select a GUI first!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    updateStatus("Generating FIXED code...", Color3.fromRGB(255, 255, 100))
    
    local success, result = pcall(function()
        return serializeForStudio(selectedGui)
    end)
    
    if success then
        fullCode = result
        local codeLength = #fullCode
        
        if codeLength > MAX_TEXTBOX_LENGTH then
            codeChunks = splitIntoChunks(fullCode)
            currentPage = 1
            updateStatus("FIXED code generated! " .. #codeChunks .. " pages, " .. processedCount .. " elements", Color3.fromRGB(100, 255, 100))
        else
            codeChunks = {fullCode}
            currentPage = 1
            updateStatus("FIXED code generated! " .. processedCount .. " elements (" .. codeLength .. " chars)", Color3.fromRGB(100, 255, 100))
        end
        
        displayPage()
    else
        updateStatus("Error: " .. tostring(result), Color3.fromRGB(255, 100, 100))
    end
end)

ClearBtn.MouseButton1Click:Connect(function()
    CodeBox.Text = ""
    PathBox.Text = "game:GetService(\"StarterGui\").Shop"
    selectedGui = nil
    codeChunks = {}
    fullCode = ""
    currentPage = 1
    processedCount = 0
    PrevPageBtn.Visible = false
    NextPageBtn.Visible = false
    PageLabel.Visible = false
    updateStatus("Cleared - Ready for action!", Color3.fromRGB(200, 200, 200))
end)

-- Page Navigation
PrevPageBtn.MouseButton1Click:Connect(function()
    if currentPage > 1 then
        currentPage = currentPage - 1
        displayPage()
    end
end)

NextPageBtn.MouseButton1Click:Connect(function()
    if currentPage < #codeChunks then
        currentPage = currentPage + 1
        displayPage()
    end
end)

-- Copy Functions
local function copyToClipboard(text)
    local success = false
    local clipboardFunctions = {
        {func = syn and syn.write_clipboard, name = "syn"},
        {func = setclipboard, name = "setclipboard"},
        {func = toclipboard, name = "toclipboard"},
        {func = writeclipboard, name = "writeclipboard"}
    }
    
    for _, clipboard in ipairs(clipboardFunctions) do
        if clipboard.func then
            local ok = pcall(clipboard.func, text)
            if ok then
                return true
            end
        end
    end
    
    return false
end

CopyPageBtn.MouseButton1Click:Connect(function()
    if CodeBox.Text == "" then
        updateStatus("No code to copy!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if copyToClipboard(CodeBox.Text) then
        updateStatus("Page " .. currentPage .. " copied!", Color3.fromRGB(100, 255, 100))
    else
        updateStatus("Clipboard not available. Select text manually.", Color3.fromRGB(255, 200, 100))
        CodeBox:CaptureFocus()
    end
end)

CopyAllBtn.MouseButton1Click:Connect(function()
    if fullCode == "" then
        updateStatus("No code to copy!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if copyToClipboard(fullCode) then
        updateStatus("All code copied! " .. processedCount .. " elements", Color3.fromRGB(100, 255, 100))
    else
        updateStatus("Code too large for clipboard. Use console instead.", Color3.fromRGB(255, 200, 100))
    end
end)

SaveFileBtn.MouseButton1Click:Connect(function()
    if fullCode == "" then
        updateStatus("No code to print!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    print("\n" .. string.rep("=", 60))
    print("FIXED GUI CODE - NO ERRORS!")
    print("Elements processed: " .. processedCount)
    print("Ready to use in LocalScript:")
    print(string.rep("=", 60))
    print(fullCode)
    print(string.rep("=", 60))
    print("END - Copy from console to LocalScript")
    print(string.rep("=", 60) .. "\n")
    
    updateStatus("FIXED code printed to console! F9 to view, copy to LocalScript", Color3.fromRGB(100, 255, 100))
end)

-- Window Controls
local minimized = false
local originalSize = Frame.Size

MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        ContentFrame.Visible = false
        Frame.Size = UDim2.new(0, 520, 0, 30)
        MinimizeBtn.Text = "□"
    else
        ContentFrame.Visible = true
        Frame.Size = originalSize
        MinimizeBtn.Text = "_"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Dragging functionality
local dragging = false
local dragStart = nil
local startPos = nil

local function updateDrag(input)
    if dragging then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
        
        local connection
        connection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                connection:Disconnect()
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Add rounded corners
local function addCornerRadius(frame, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = frame
end

addCornerRadius(Frame, 12)
addCornerRadius(PathBox, 6)
addCornerRadius(SelectBtn, 6)
addCornerRadius(GenerateBtn, 6)
addCornerRadius(ClearBtn, 6)
addCornerRadius(StatusLabel, 6)
addCornerRadius(ScrollFrame, 8)
addCornerRadius(CopyPageBtn, 6)
addCornerRadius(CopyAllBtn, 6)
addCornerRadius(SaveFileBtn, 6)

-- Button hover effects
local function addHoverEffect(button, hoverColor, normalColor)
    button.MouseEnter:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor})
        tween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = normalColor})
        tween:Play()
    end)
end

addHoverEffect(SelectBtn, Color3.fromRGB(80, 140, 220), Color3.fromRGB(60, 120, 200))
addHoverEffect(GenerateBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(60, 160, 60))
addHoverEffect(ClearBtn, Color3.fromRGB(170, 170, 70), Color3.fromRGB(150, 150, 50))
addHoverEffect(CopyPageBtn, Color3.fromRGB(220, 120, 70), Color3.fromRGB(200, 100, 50))
addHoverEffect(CopyAllBtn, Color3.fromRGB(200, 80, 80), Color3.fromRGB(180, 60, 60))
addHoverEffect(SaveFileBtn, Color3.fromRGB(120, 120, 220), Color3.fromRGB(100, 100, 200))
addHoverEffect(MinimizeBtn, Color3.fromRGB(65, 65, 65), Color3.fromRGB(45, 45, 45))
addHoverEffect(CloseBtn, Color3.fromRGB(220, 70, 70), Color3.fromRGB(200, 50, 50))

-- Final message
updateStatus("FIXED GUI Dumper loaded! No more ClassName errors - generates clean LocalScript code!", Color3.fromRGB(100, 255, 100))

-- Cleanup
game.Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        if ScreenGui and ScreenGui.Parent then
            ScreenGui:Destroy()
        end
    end
end)
