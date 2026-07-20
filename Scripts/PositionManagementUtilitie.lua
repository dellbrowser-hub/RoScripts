--[[
    Position Library - single-file LocalScript

    Features
    - Mandatory naming popup before a position can be saved
    - Searchable dropdown
    - Sort by creation order or alphabetical order
    - Teleport, rename, and delete selected positions
    - Per-GameId or per-PlaceId libraries
    - Merge the current game's library into another game/place ID
    - Versioned JSON export/import (merge or replace)
    - Optional clipboard integration when setclipboard/getclipboard are exposed
    - Optional local JSON persistence when writefile/readfile/isfile are exposed

    Standard Roblox limitation:
    A normal LocalScript has no clipboard API, no local filesystem API, and cannot
    use DataStoreService directly. In that environment, this script remains
    session-only and JSON can still be copied/pasted manually from the text box.
]]

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Constants
local APP_NAME = "Position Library"
local SCHEMA_VERSION = 1
local FILE_NAME = string.format("PositionLibrary_v1_%s.json", tostring(LocalPlayer.UserId))
local ROOT_SIZE = Vector2.new(760, 540)

local COLORS = {
    Background = Color3.fromRGB(18, 20, 26),
    Panel = Color3.fromRGB(27, 30, 38),
    Panel2 = Color3.fromRGB(34, 38, 48),
    Panel3 = Color3.fromRGB(42, 47, 59),
    Accent = Color3.fromRGB(89, 126, 255),
    AccentHover = Color3.fromRGB(109, 143, 255),
    Positive = Color3.fromRGB(65, 184, 122),
    Warning = Color3.fromRGB(236, 173, 70),
    Danger = Color3.fromRGB(222, 82, 92),
    Text = Color3.fromRGB(239, 242, 250),
    Muted = Color3.fromRGB(155, 163, 181),
    Stroke = Color3.fromRGB(63, 69, 84),
    Overlay = Color3.fromRGB(7, 8, 11),
}

--// Optional executor-provided functions
local function getEnvironment(): {[any]: any}
    local environment = _G
    local getGenvValue = rawget(_G, "getgenv")

    if type(getGenvValue) == "function" then
        local ok, result = pcall(getGenvValue)
        if ok and type(result) == "table" then
            environment = result
        end
    end

    return environment
end

local Environment = getEnvironment()

local function findFunction(...: string): any
    for _, name in ipairs({...}) do
        local candidate = rawget(Environment, name)
        if type(candidate) == "function" then
            return candidate
        end

        candidate = rawget(_G, name)
        if type(candidate) == "function" then
            return candidate
        end
    end

    return nil
end

local setClipboard = findFunction("setclipboard", "toclipboard")
local getClipboard = findFunction("getclipboard")
local writeFile = findFunction("writefile")
local readFile = findFunction("readfile")
local isFile = findFunction("isfile")

local FILE_STORAGE_AVAILABLE = writeFile ~= nil and readFile ~= nil
local CLIPBOARD_WRITE_AVAILABLE = setClipboard ~= nil
local CLIPBOARD_READ_AVAILABLE = getClipboard ~= nil

--// Small utilities
local function trim(value: any): string
    return string.match(tostring(value or ""), "^%s*(.-)%s*$") or ""
end

local function normalizeName(value: any): string
    local name = trim(value)
    name = string.gsub(name, "[%c]", " ")
    name = string.gsub(name, "%s+", " ")

    if #name > 64 then
        name = string.sub(name, 1, 64)
    end

    return name
end

local function shallowCopy(source: {[any]: any}): {[any]: any}
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

local function round(value: number, decimals: number?): number
    local multiplier = 10 ^ (decimals or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
end

local function make(className: string, properties: {[string]: any}?, children: {Instance}?): Instance
    local instance = Instance.new(className)

    if properties then
        for property, value in pairs(properties) do
            if property ~= "Parent" then
                instance[property] = value
            end
        end
    end

    if children then
        for _, child in ipairs(children) do
            child.Parent = instance
        end
    end

    if properties and properties.Parent then
        instance.Parent = properties.Parent
    end

    return instance
end

local function addCorner(parent: Instance, radius: number?): UICorner
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    }) :: UICorner
end

local function addStroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
    return make("UIStroke", {
        Color = color or COLORS.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    }) :: UIStroke
end

local function addPadding(parent: Instance, left: number, right: number, top: number, bottom: number): UIPadding
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, left),
        PaddingRight = UDim.new(0, right),
        PaddingTop = UDim.new(0, top),
        PaddingBottom = UDim.new(0, bottom),
        Parent = parent,
    }) :: UIPadding
end

local function makeLabel(parent: Instance, text: string, size: UDim2, position: UDim2?, textSize: number?, color: Color3?): TextLabel
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Size = size,
        Position = position or UDim2.new(),
        Font = Enum.Font.Gotham,
        Text = text,
        TextColor3 = color or COLORS.Text,
        TextSize = textSize or 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = parent,
    }) :: TextLabel
end

local function makeButton(
    parent: Instance,
    text: string,
    size: UDim2,
    position: UDim2?,
    background: Color3?,
    textColor: Color3?
): TextButton
    local button = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = background or COLORS.Panel3,
        BorderSizePixel = 0,
        Size = size,
        Position = position or UDim2.new(),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = textColor or COLORS.Text,
        TextSize = 14,
        Parent = parent,
    }) :: TextButton

    addCorner(button, 7)
    addStroke(button)

    local baseColor = button.BackgroundColor3
    local hoverColor = baseColor:Lerp(Color3.new(1, 1, 1), 0.07)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = hoverColor}):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = baseColor}):Play()
    end)

    return button
end

local function makeTextBox(
    parent: Instance,
    placeholder: string,
    size: UDim2,
    position: UDim2?,
    multiLine: boolean?
): TextBox
    local textBox = make("TextBox", {
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        Size = size,
        Position = position or UDim2.new(),
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderColor3 = COLORS.Muted,
        PlaceholderText = placeholder,
        Text = "",
        TextColor3 = COLORS.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = multiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        MultiLine = multiLine == true,
        TextWrapped = false,
        Parent = parent,
    }) :: TextBox

    addCorner(textBox, 7)
    addStroke(textBox)
    addPadding(textBox, 10, 10, multiLine and 8 or 0, multiLine and 8 or 0)

    return textBox
end

local function makeSection(parent: Instance, title: string, height: number): Frame
    local section = make("Frame", {
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height),
        Parent = parent,
    }) :: Frame

    addCorner(section, 9)
    addStroke(section)
    makeLabel(section, title, UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 0), 14, COLORS.Text).Font = Enum.Font.GothamBold

    return section
end

--// State and serialization
local function defaultState(): {[string]: any}
    return {
        version = SCHEMA_VERSION,
        nextCreatedIndex = 1,
        settings = {
            sortMode = "Created", -- "Created" or "Alphabetical"
            idMode = "GameId", -- "GameId" or "PlaceId"
            autoSave = true,
            safeTeleport = true,
            closeDropdownAfterSelect = true,
        },
        games = {},
        aliases = {},
    }
end

local state = defaultState()

local function serializeCFrame(cframe: CFrame): {number}
    return {cframe:GetComponents()}
end

local function deserializeCFrame(components: any): CFrame?
    if type(components) ~= "table" or #components ~= 12 then
        return nil
    end

    local numbers = table.create(12)
    for index = 1, 12 do
        local value = tonumber(components[index])
        if value == nil then
            return nil
        end
        numbers[index] = value
    end

    return CFrame.new(table.unpack(numbers, 1, 12))
end

local function normalizeKey(rawValue: any, fallbackMode: string?): string?
    local value = trim(rawValue)
    if value == "" then
        return nil
    end

    local lower = string.lower(value)
    local explicitMode: string? = nil
    local numericPart = value

    if string.sub(lower, 1, 5) == "game:" then
        explicitMode = "GameId"
        numericPart = string.sub(value, 6)
    elseif string.sub(lower, 1, 6) == "place:" then
        explicitMode = "PlaceId"
        numericPart = string.sub(value, 7)
    end

    numericPart = trim(numericPart)
    if not string.match(numericPart, "^%d+$") then
        return nil
    end

    local mode = explicitMode or fallbackMode or state.settings.idMode or "GameId"
    local prefix = mode == "PlaceId" and "place:" or "game:"
    return prefix .. numericPart
end

local function currentRawKey(): string
    if state.settings.idMode == "PlaceId" then
        return "place:" .. tostring(game.PlaceId)
    end

    return "game:" .. tostring(game.GameId)
end

local function resolveCanonicalKey(rawKey: string): string
    local current = rawKey
    local visited = {}

    for _ = 1, 32 do
        if visited[current] then
            -- Break an imported alias loop safely.
            state.aliases[current] = nil
            return rawKey
        end

        visited[current] = true
        local nextKey = state.aliases[current]

        if type(nextKey) ~= "string" or nextKey == "" or nextKey == current then
            return current
        end

        current = nextKey
    end

    return current
end

local function ensureLibrary(key: string): {[string]: any}
    local canonical = resolveCanonicalKey(key)
    local library = state.games[canonical]

    if type(library) ~= "table" then
        library = {positions = {}}
        state.games[canonical] = library
    end

    if type(library.positions) ~= "table" then
        library.positions = {}
    end

    return library
end

local function currentLibrary(): {[string]: any}
    return ensureLibrary(currentRawKey())
end

local function sanitizePosition(position: any, fallbackIndex: number): {[string]: any}?
    if type(position) ~= "table" then
        return nil
    end

    local name = normalizeName(position.name)
    local cframe = deserializeCFrame(position.cframe)

    if name == "" or cframe == nil then
        return nil
    end

    local createdIndex = tonumber(position.createdIndex) or fallbackIndex
    createdIndex = math.max(1, math.floor(createdIndex))

    return {
        id = type(position.id) == "string" and position.id ~= "" and position.id or HttpService:GenerateGUID(false),
        name = name,
        cframe = serializeCFrame(cframe),
        createdAt = tonumber(position.createdAt) or os.time(),
        createdIndex = createdIndex,
    }
end

local function resolveAliasMap(rawKey: string, aliases: {[string]: any}): string
    local current = rawKey
    local visited = {}

    for _ = 1, 32 do
        if visited[current] then
            return rawKey
        end

        visited[current] = true
        local nextKey = aliases[current]
        if type(nextKey) ~= "string" or nextKey == "" or nextKey == current then
            return current
        end

        current = nextKey
    end

    return current
end

local function normalizeImportedState(decoded: any): ({[string]: any}?, string?)
    if type(decoded) ~= "table" then
        return nil, "The imported JSON root must be an object."
    end

    local imported = defaultState()
    local importedSettings = type(decoded.settings) == "table" and decoded.settings or {}

    if importedSettings.sortMode == "Alphabetical" or importedSettings.sortMode == "Created" then
        imported.settings.sortMode = importedSettings.sortMode
    end

    if importedSettings.idMode == "GameId" or importedSettings.idMode == "PlaceId" then
        imported.settings.idMode = importedSettings.idMode
    end

    for _, booleanSetting in ipairs({"autoSave", "safeTeleport", "closeDropdownAfterSelect"}) do
        if type(importedSettings[booleanSetting]) == "boolean" then
            imported.settings[booleanSetting] = importedSettings[booleanSetting]
        end
    end

    local maxCreatedIndex = 0
    local importedGames = type(decoded.games) == "table" and decoded.games or {}

    for rawKey, rawLibrary in pairs(importedGames) do
        if type(rawKey) == "string" and type(rawLibrary) == "table" then
            local key = normalizeKey(rawKey, imported.settings.idMode)
            if key then
                local cleanLibrary = {positions = {}}
                local positions = type(rawLibrary.positions) == "table" and rawLibrary.positions or {}

                for index, rawPosition in ipairs(positions) do
                    local cleanPosition = sanitizePosition(rawPosition, index)
                    if cleanPosition then
                        maxCreatedIndex = math.max(maxCreatedIndex, cleanPosition.createdIndex)
                        table.insert(cleanLibrary.positions, cleanPosition)
                    end
                end

                imported.games[key] = cleanLibrary
            end
        end
    end

    local importedAliases = type(decoded.aliases) == "table" and decoded.aliases or {}
    for rawSource, rawTarget in pairs(importedAliases) do
        if type(rawSource) == "string" and type(rawTarget) == "string" then
            local source = normalizeKey(rawSource, imported.settings.idMode)
            local target = normalizeKey(rawTarget, imported.settings.idMode)
            if source and target and source ~= target then
                imported.aliases[source] = target
            end
        end
    end

    -- Collapse imported alias-linked libraries into their canonical targets so
    -- positions never become hidden behind an alias after Replace or Merge.
    local canonicalGames = {}
    local seenIds = {}

    for importedKey, importedLibrary in pairs(imported.games) do
        local canonicalKey = resolveAliasMap(importedKey, imported.aliases)
        local targetLibrary = canonicalGames[canonicalKey]

        if not targetLibrary then
            targetLibrary = {positions = {}}
            canonicalGames[canonicalKey] = targetLibrary
        end

        for _, position in ipairs(importedLibrary.positions) do
            if seenIds[position.id] then
                position.id = HttpService:GenerateGUID(false)
            end
            seenIds[position.id] = true
            table.insert(targetLibrary.positions, position)
        end
    end

    imported.games = canonicalGames
    imported.nextCreatedIndex = math.max(
        maxCreatedIndex + 1,
        tonumber(decoded.nextCreatedIndex) or 1
    )

    return imported, nil
end

local function encodeState(): (string?, string?)
    local exportState = {
        version = SCHEMA_VERSION,
        exportedAt = os.time(),
        source = {
            gameId = tostring(game.GameId),
            placeId = tostring(game.PlaceId),
            userId = tostring(LocalPlayer.UserId),
        },
        nextCreatedIndex = state.nextCreatedIndex,
        settings = shallowCopy(state.settings),
        games = state.games,
        aliases = state.aliases,
    }

    local ok, result = pcall(function()
        return HttpService:JSONEncode(exportState)
    end)

    if not ok then
        return nil, tostring(result)
    end

    return result, nil
end

local function decodeState(text: string): ({[string]: any}?, string?)
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(text)
    end)

    if not ok then
        return nil, "Invalid JSON: " .. tostring(decoded)
    end

    return normalizeImportedState(decoded)
end

local function isFileAvailable(path: string): boolean
    if isFile then
        local ok, result = pcall(isFile, path)
        return ok and result == true
    end

    -- Some custom environments expose readfile/writefile but not isfile.
    if readFile then
        local ok = pcall(readFile, path)
        return ok
    end

    return false
end

local function writePersistentState(): (boolean, string)
    if not FILE_STORAGE_AVAILABLE or not writeFile then
        return false, "Local file APIs are not available; storage is session-only."
    end

    local json, encodeError = encodeState()
    if not json then
        return false, encodeError or "Could not encode JSON."
    end

    local ok, result = pcall(writeFile, FILE_NAME, json)
    if not ok then
        return false, "writefile failed: " .. tostring(result)
    end

    return true, "Saved to " .. FILE_NAME
end

local function loadPersistentState(): (boolean, string)
    if not FILE_STORAGE_AVAILABLE or not readFile then
        return false, "No local file storage API detected."
    end

    if not isFileAvailable(FILE_NAME) then
        return false, "No saved local file exists yet."
    end

    local readOk, content = pcall(readFile, FILE_NAME)
    if not readOk or type(content) ~= "string" then
        return false, "readfile failed: " .. tostring(content)
    end

    local imported, decodeError = decodeState(content)
    if not imported then
        return false, decodeError or "Saved file is invalid."
    end

    state = imported
    return true, "Loaded " .. FILE_NAME
end

local function persistIfEnabled()
    if state.settings.autoSave and FILE_STORAGE_AVAILABLE then
        writePersistentState()
    end
end

-- Attempt local load before constructing the UI.
loadPersistentState()

--// Root UI
local existing = PlayerGui:FindFirstChild("PositionLibraryUI")
if existing then
    existing:Destroy()
end

local screenGui = make("ScreenGui", {
    Name = "PositionLibraryUI",
    DisplayOrder = 999,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui,
}) :: ScreenGui

local root = make("Frame", {
    Name = "Root",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.Background,
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(ROOT_SIZE.X, ROOT_SIZE.Y),
    Parent = screenGui,
}) :: Frame
addCorner(root, 12)
addStroke(root, COLORS.Stroke, 1)

local uiScale = make("UIScale", {
    Scale = 1,
    Parent = root,
}) :: UIScale

local function updateUIScale()
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local viewport = camera.ViewportSize
    uiScale.Scale = math.min(1, (viewport.X - 24) / ROOT_SIZE.X, (viewport.Y - 24) / ROOT_SIZE.Y)
end

updateUIScale()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale)
end

local topBar = make("Frame", {
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 48),
    Parent = root,
}) :: Frame
addCorner(topBar, 12)

local topBarMask = make("Frame", {
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -12),
    Size = UDim2.new(1, 0, 0, 12),
    Parent = topBar,
})

topBarMask.ZIndex = topBar.ZIndex

local title = makeLabel(topBar, APP_NAME, UDim2.new(1, -130, 1, 0), UDim2.fromOffset(18, 0), 17, COLORS.Text)
title.Font = Enum.Font.GothamBold

local subtitle = makeLabel(topBar, "Local position manager", UDim2.fromOffset(200, 48), UDim2.fromOffset(172, 0), 12, COLORS.Muted)

local minimizeButton = makeButton(topBar, "—", UDim2.fromOffset(38, 30), UDim2.new(1, -88, 0, 9), COLORS.Panel2)
local closeButton = makeButton(topBar, "×", UDim2.fromOffset(38, 30), UDim2.new(1, -44, 0, 9), COLORS.Danger)

local sideBar = make("Frame", {
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(0, 48),
    Size = UDim2.new(0, 150, 1, -48),
    Parent = root,
}) :: Frame

local content = make("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(150, 48),
    Size = UDim2.new(1, -150, 1, -48),
    Parent = root,
}) :: Frame

local statusLabel = makeLabel(sideBar, "Ready", UDim2.new(1, -20, 0, 62), UDim2.new(0, 10, 1, -72), 11, COLORS.Muted)
statusLabel.TextWrapped = true
statusLabel.TextYAlignment = Enum.TextYAlignment.Bottom

local function setStatus(message: string, kind: string?)
    statusLabel.Text = message

    if kind == "error" then
        statusLabel.TextColor3 = COLORS.Danger
    elseif kind == "warning" then
        statusLabel.TextColor3 = COLORS.Warning
    elseif kind == "success" then
        statusLabel.TextColor3 = COLORS.Positive
    else
        statusLabel.TextColor3 = COLORS.Muted
    end
end

local storageLabel = makeLabel(
    sideBar,
    FILE_STORAGE_AVAILABLE and "Storage: local file" or "Storage: session only",
    UDim2.new(1, -20, 0, 22),
    UDim2.fromOffset(10, 86),
    11,
    FILE_STORAGE_AVAILABLE and COLORS.Positive or COLORS.Warning
)
storageLabel.TextWrapped = true

local positionsTabButton = makeButton(sideBar, "Positions", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 16), COLORS.Accent)
local settingsTabButton = makeButton(sideBar, "Settings", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 62), COLORS.Panel2)

local positionsPage = make("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Parent = content,
}) :: Frame

local settingsPage = make("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Visible = false,
    Parent = content,
}) :: Frame

local activeTab = "Positions"

local function setTab(tabName: string)
    activeTab = tabName
    positionsPage.Visible = tabName == "Positions"
    settingsPage.Visible = tabName == "Settings"

    positionsTabButton.BackgroundColor3 = tabName == "Positions" and COLORS.Accent or COLORS.Panel2
    settingsTabButton.BackgroundColor3 = tabName == "Settings" and COLORS.Accent or COLORS.Panel2
end

positionsTabButton.Activated:Connect(function()
    setTab("Positions")
end)

settingsTabButton.Activated:Connect(function()
    setTab("Settings")
end)

--// Window dragging
local dragging = false
local dragStart: Vector2? = nil
local startPosition: UDim2? = nil
local dragInput: InputObject? = nil

local function updateDrag(input: InputObject)
    if not dragging or not dragStart or not startPosition then
        return
    end

    local delta = input.Position - dragStart
    root.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X / uiScale.Scale,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y / uiScale.Scale
    )
end

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = root.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput then
        updateDrag(input)
    end
end)

local minimized = false
minimizeButton.Activated:Connect(function()
    minimized = not minimized
    sideBar.Visible = not minimized
    content.Visible = not minimized
    root.Size = minimized and UDim2.fromOffset(ROOT_SIZE.X, 48) or UDim2.fromOffset(ROOT_SIZE.X, ROOT_SIZE.Y)
    minimizeButton.Text = minimized and "+" or "—"
end)

closeButton.Activated:Connect(function()
    screenGui:Destroy()
end)

--// Modal system
local modalOverlay = make("Frame", {
    Active = true,
    BackgroundColor3 = COLORS.Overlay,
    BackgroundTransparency = 0.22,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    Visible = false,
    ZIndex = 100,
    Parent = root,
}) :: Frame

local modalCard = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(390, 190),
    ZIndex = 101,
    Parent = modalOverlay,
}) :: Frame
addCorner(modalCard, 10)
addStroke(modalCard, COLORS.Stroke, 1)

local modalTitle = makeLabel(modalCard, "Name position", UDim2.new(1, -32, 0, 34), UDim2.fromOffset(16, 10), 17, COLORS.Text)
modalTitle.Font = Enum.Font.GothamBold
modalTitle.ZIndex = 102

local modalMessage = makeLabel(modalCard, "A non-empty name is required.", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 46), 12, COLORS.Muted)
modalMessage.ZIndex = 102

local modalInput = makeTextBox(modalCard, "Position name", UDim2.new(1, -32, 0, 40), UDim2.fromOffset(16, 78), false)
modalInput.ZIndex = 102

local modalCancel = makeButton(modalCard, "Cancel", UDim2.fromOffset(110, 38), UDim2.new(1, -236, 1, -54), COLORS.Panel3)
modalCancel.ZIndex = 102
local modalConfirm = makeButton(modalCard, "Save", UDim2.fromOffset(110, 38), UDim2.new(1, -126, 1, -54), COLORS.Accent)
modalConfirm.ZIndex = 102

local modalMode = "Save"
local modalCallback: ((string) -> ())? = nil

local function closeModal()
    modalOverlay.Visible = false
    modalInput.Text = ""
    modalMessage.TextColor3 = COLORS.Muted
    modalCallback = nil
end

local function openNameModal(mode: string, initialText: string?, callback: (string) -> ())
    modalMode = mode
    modalCallback = callback
    modalTitle.Text = mode == "Rename" and "Rename position" or "Name saved position"
    modalMessage.Text = "A non-empty, unique name is mandatory."
    modalMessage.TextColor3 = COLORS.Muted
    modalConfirm.Text = mode == "Rename" and "Rename" or "Save"
    modalInput.Text = initialText or ""
    modalOverlay.Visible = true

    task.defer(function()
        modalInput:CaptureFocus()
        modalInput.CursorPosition = #modalInput.Text + 1
    end)
end

local function positionNameExists(name: string, excludedId: string?): boolean
    local target = string.lower(name)
    for _, position in ipairs(currentLibrary().positions) do
        if position.id ~= excludedId and string.lower(position.name) == target then
            return true
        end
    end
    return false
end

modalCancel.Activated:Connect(closeModal)

local function submitModal()
    local name = normalizeName(modalInput.Text)
    if name == "" then
        modalMessage.Text = "You must enter a name before continuing."
        modalMessage.TextColor3 = COLORS.Danger
        return
    end

    if modalCallback then
        modalCallback(name)
    end
end

modalConfirm.Activated:Connect(submitModal)
modalInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and modalOverlay.Visible then
        submitModal()
    end
end)

--// Positions page
local pagePadding = 16

local pageTitle = makeLabel(positionsPage, "Saved positions", UDim2.new(1, -32, 0, 30), UDim2.fromOffset(pagePadding, 12), 20, COLORS.Text)
pageTitle.Font = Enum.Font.GothamBold

local gameContextLabel = makeLabel(positionsPage, "", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(pagePadding, 42), 11, COLORS.Muted)

local savePositionButton = makeButton(
    positionsPage,
    "Save current position",
    UDim2.fromOffset(190, 40),
    UDim2.fromOffset(pagePadding, 76),
    COLORS.Accent
)

local sortButton = makeButton(
    positionsPage,
    "Sort: Created",
    UDim2.fromOffset(155, 40),
    UDim2.fromOffset(pagePadding + 200, 76),
    COLORS.Panel3
)

local searchBox = makeTextBox(
    positionsPage,
    "Search saved locations...",
    UDim2.new(1, -(pagePadding * 2), 0, 40),
    UDim2.fromOffset(pagePadding, 126),
    false
)

local dropdownButton = makeButton(
    positionsPage,
    "Select a saved position  ▾",
    UDim2.new(1, -(pagePadding * 2), 0, 42),
    UDim2.fromOffset(pagePadding, 176),
    COLORS.Panel2
)
dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
local dropdownButtonPadding = addPadding(dropdownButton, 12, 12, 0, 0)

local dropdownPanel = make("Frame", {
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(pagePadding, 224),
    Size = UDim2.new(1, -(pagePadding * 2), 0, 205),
    Visible = false,
    ZIndex = 20,
    Parent = positionsPage,
}) :: Frame
addCorner(dropdownPanel, 8)
addStroke(dropdownPanel)

local dropdownScroll = make("ScrollingFrame", {
    Active = true,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(),
    ScrollBarImageColor3 = COLORS.Muted,
    ScrollBarThickness = 5,
    Size = UDim2.new(1, -8, 1, -8),
    Position = UDim2.fromOffset(4, 4),
    ZIndex = 21,
    Parent = dropdownPanel,
}) :: ScrollingFrame

local dropdownLayout = make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = dropdownScroll,
}) :: UIListLayout

addPadding(dropdownScroll, 4, 4, 4, 4)

dropdownLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    dropdownScroll.CanvasSize = UDim2.fromOffset(0, dropdownLayout.AbsoluteContentSize.Y + 8)
end)

local selectedCard = make("Frame", {
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(pagePadding, 232),
    Size = UDim2.new(1, -(pagePadding * 2), 0, 104),
    Parent = positionsPage,
}) :: Frame
addCorner(selectedCard, 9)
addStroke(selectedCard)

local selectedNameLabel = makeLabel(selectedCard, "No position selected", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 8), 16, COLORS.Text)
selectedNameLabel.Font = Enum.Font.GothamBold

local selectedCoordinatesLabel = makeLabel(selectedCard, "Select a location from the dropdown.", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 38), 12, COLORS.Muted)
selectedCoordinatesLabel.TextWrapped = true
selectedCoordinatesLabel.TextYAlignment = Enum.TextYAlignment.Top

local selectedCreatedLabel = makeLabel(selectedCard, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 78), 11, COLORS.Muted)

local teleportButton = makeButton(
    positionsPage,
    "Teleport to selected",
    UDim2.fromOffset(190, 42),
    UDim2.fromOffset(pagePadding, 350),
    COLORS.Positive
)

local renameButton = makeButton(
    positionsPage,
    "Rename",
    UDim2.fromOffset(130, 42),
    UDim2.fromOffset(pagePadding + 200, 350),
    COLORS.Panel3
)

local deleteButton = makeButton(
    positionsPage,
    "Delete",
    UDim2.fromOffset(130, 42),
    UDim2.fromOffset(pagePadding + 340, 350),
    COLORS.Danger
)

local countLabel = makeLabel(positionsPage, "0 saved positions", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(pagePadding, 407), 12, COLORS.Muted)

local selectedPositionId: string? = nil
local dropdownOpen = false

local refreshPositionsUI: () -> ()
local refreshSettingsUI: () -> ()

local function getPositionById(id: string?): {[string]: any}?
    if not id then
        return nil
    end

    for _, position in ipairs(currentLibrary().positions) do
        if position.id == id then
            return position
        end
    end

    return nil
end

local function sortedFilteredPositions(): {{[string]: any}}
    local query = string.lower(trim(searchBox.Text))
    local results = {}

    for _, position in ipairs(currentLibrary().positions) do
        if query == "" or string.find(string.lower(position.name), query, 1, true) then
            table.insert(results, position)
        end
    end

    table.sort(results, function(a, b)
        if state.settings.sortMode == "Alphabetical" then
            local aName = string.lower(a.name)
            local bName = string.lower(b.name)
            if aName == bName then
                return (a.createdIndex or 0) < (b.createdIndex or 0)
            end
            return aName < bName
        end

        local aIndex = tonumber(a.createdIndex) or 0
        local bIndex = tonumber(b.createdIndex) or 0
        if aIndex == bIndex then
            return string.lower(a.name) < string.lower(b.name)
        end
        return aIndex < bIndex
    end)

    return results
end

local function setDropdownOpen(value: boolean)
    dropdownOpen = value
    dropdownPanel.Visible = value
    selectedCard.Visible = not value
    teleportButton.Visible = not value
    renameButton.Visible = not value
    deleteButton.Visible = not value
    countLabel.Visible = not value
    dropdownButton.Text = value and "Close saved positions  ▴" or (
        getPositionById(selectedPositionId)
        and (getPositionById(selectedPositionId).name .. "  ▾")
        or "Select a saved position  ▾"
    )
end

local function clearDropdownRows()
    for _, child in ipairs(dropdownScroll:GetChildren()) do
        if child:IsA("GuiButton") or child.Name == "EmptyLabel" then
            child:Destroy()
        end
    end
end

local function renderDropdown()
    clearDropdownRows()
    local positions = sortedFilteredPositions()

    if #positions == 0 then
        local empty = makeLabel(
            dropdownScroll,
            trim(searchBox.Text) == "" and "No saved positions for this game." or "No matching positions.",
            UDim2.new(1, -8, 0, 38),
            nil,
            13,
            COLORS.Muted
        )
        empty.Name = "EmptyLabel"
        empty.TextXAlignment = Enum.TextXAlignment.Center
        empty.ZIndex = 22
        return
    end

    for order, position in ipairs(positions) do
        local row = makeButton(
            dropdownScroll,
            position.name,
            UDim2.new(1, -8, 0, 38),
            nil,
            position.id == selectedPositionId and COLORS.Accent or COLORS.Panel2
        )
        row.Name = "PositionRow"
        row.LayoutOrder = order
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.ZIndex = 22
        addPadding(row, 10, 10, 0, 0)

        row.Activated:Connect(function()
            selectedPositionId = position.id
            if state.settings.closeDropdownAfterSelect then
                setDropdownOpen(false)
            end
            refreshPositionsUI()
        end)
    end
end

refreshPositionsUI = function()
    local rawKey = currentRawKey()
    local canonicalKey = resolveCanonicalKey(rawKey)
    local library = currentLibrary()
    local selected = getPositionById(selectedPositionId)

    if selectedPositionId and not selected then
        selectedPositionId = nil
    end

    sortButton.Text = state.settings.sortMode == "Alphabetical" and "Sort: A → Z" or "Sort: Created"
    gameContextLabel.Text = string.format(
        "Current %s: %s%s",
        state.settings.idMode,
        rawKey,
        canonicalKey ~= rawKey and ("  • merged into " .. canonicalKey) or ""
    )

    countLabel.Text = string.format("%d saved position%s", #library.positions, #library.positions == 1 and "" or "s")

    selected = getPositionById(selectedPositionId)
    if selected then
        local cframe = deserializeCFrame(selected.cframe)
        selectedNameLabel.Text = selected.name

        if cframe then
            local position = cframe.Position
            selectedCoordinatesLabel.Text = string.format(
                "X: %.2f    Y: %.2f    Z: %.2f",
                position.X,
                position.Y,
                position.Z
            )
        else
            selectedCoordinatesLabel.Text = "This entry has invalid position data."
        end

        selectedCreatedLabel.Text = string.format("Created order #%d", tonumber(selected.createdIndex) or 0)
        dropdownButton.Text = selected.name .. (dropdownOpen and "  ▴" or "  ▾")
        teleportButton.Active = true
        renameButton.Active = true
        deleteButton.Active = true
        teleportButton.TextTransparency = 0
        renameButton.TextTransparency = 0
        deleteButton.TextTransparency = 0
    else
        selectedNameLabel.Text = "No position selected"
        selectedCoordinatesLabel.Text = "Select a location from the dropdown."
        selectedCreatedLabel.Text = ""
        dropdownButton.Text = dropdownOpen and "Close saved positions  ▴" or "Select a saved position  ▾"
        teleportButton.Active = false
        renameButton.Active = false
        deleteButton.Active = false
        teleportButton.TextTransparency = 0.45
        renameButton.TextTransparency = 0.45
        deleteButton.TextTransparency = 0.45
    end

    renderDropdown()
end

savePositionButton.Activated:Connect(function()
    local character = LocalPlayer.Character
    if not character then
        setStatus("Character is not loaded.", "error")
        return
    end

    local capturedCFrame = character:GetPivot()

    openNameModal("Save", "", function(name)
        if positionNameExists(name, nil) then
            modalMessage.Text = "That name already exists in the current list."
            modalMessage.TextColor3 = COLORS.Danger
            return
        end

        local newPosition = {
            id = HttpService:GenerateGUID(false),
            name = name,
            cframe = serializeCFrame(capturedCFrame),
            createdAt = os.time(),
            createdIndex = state.nextCreatedIndex,
        }

        state.nextCreatedIndex += 1
        table.insert(currentLibrary().positions, newPosition)
        selectedPositionId = newPosition.id
        persistIfEnabled()
        closeModal()
        setDropdownOpen(false)
        refreshPositionsUI()
        if refreshSettingsUI then
            refreshSettingsUI()
        end
        setStatus("Saved “" .. name .. "”.", "success")
    end)
end)

sortButton.Activated:Connect(function()
    state.settings.sortMode = state.settings.sortMode == "Created" and "Alphabetical" or "Created"
    persistIfEnabled()
    refreshPositionsUI()
    if refreshSettingsUI then
        refreshSettingsUI()
    end
end)

dropdownButton.Activated:Connect(function()
    setDropdownOpen(not dropdownOpen)
    renderDropdown()
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    renderDropdown()
end)

teleportButton.Activated:Connect(function()
    local selected = getPositionById(selectedPositionId)
    if not selected then
        setStatus("Select a saved position first.", "warning")
        return
    end

    local destination = deserializeCFrame(selected.cframe)
    if not destination then
        setStatus("The selected position data is invalid.", "error")
        return
    end

    local character = LocalPlayer.Character
    if not character then
        setStatus("Character is not loaded.", "error")
        return
    end

    if state.settings.safeTeleport then
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.AssemblyLinearVelocity = Vector3.zero
                descendant.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end

    character:PivotTo(destination)
    setStatus("Teleported to “" .. selected.name .. "”.", "success")
end)

renameButton.Activated:Connect(function()
    local selected = getPositionById(selectedPositionId)
    if not selected then
        return
    end

    openNameModal("Rename", selected.name, function(name)
        if positionNameExists(name, selected.id) then
            modalMessage.Text = "That name already exists in the current list."
            modalMessage.TextColor3 = COLORS.Danger
            return
        end

        selected.name = name
        persistIfEnabled()
        closeModal()
        refreshPositionsUI()
        setStatus("Renamed the selected position.", "success")
    end)
end)

deleteButton.Activated:Connect(function()
    local selected = getPositionById(selectedPositionId)
    if not selected then
        return
    end

    modalTitle.Text = "Delete position"
    modalMessage.Text = "Type DELETE to permanently remove “" .. selected.name .. "”."
    modalMessage.TextColor3 = COLORS.Warning
    modalInput.PlaceholderText = "DELETE"
    modalInput.Text = ""
    modalConfirm.Text = "Delete"
    modalConfirm.BackgroundColor3 = COLORS.Danger
    modalOverlay.Visible = true

    modalCallback = function(value)
        if string.upper(trim(value)) ~= "DELETE" then
            modalMessage.Text = "Enter DELETE exactly to confirm."
            modalMessage.TextColor3 = COLORS.Danger
            return
        end

        local positions = currentLibrary().positions
        for index, position in ipairs(positions) do
            if position.id == selected.id then
                table.remove(positions, index)
                break
            end
        end

        selectedPositionId = nil
        modalInput.PlaceholderText = "Position name"
        modalConfirm.BackgroundColor3 = COLORS.Accent
        persistIfEnabled()
        closeModal()
        refreshPositionsUI()
        setStatus("Deleted “" .. selected.name .. "”.", "success")
    end
end)

-- Restore modal defaults whenever it closes.
modalOverlay:GetPropertyChangedSignal("Visible"):Connect(function()
    if not modalOverlay.Visible then
        modalInput.PlaceholderText = "Position name"
        modalConfirm.BackgroundColor3 = COLORS.Accent
    end
end)

--// Settings page
local settingsScroll = make("ScrollingFrame", {
    Active = true,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(),
    Position = UDim2.fromOffset(12, 8),
    Size = UDim2.new(1, -24, 1, -16),
    ScrollBarImageColor3 = COLORS.Muted,
    ScrollBarThickness = 6,
    Parent = settingsPage,
}) :: ScrollingFrame

local settingsLayout = make("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = settingsScroll,
}) :: UIListLayout

settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    settingsScroll.CanvasSize = UDim2.fromOffset(0, settingsLayout.AbsoluteContentSize.Y + 12)
end)

local settingsHeader = make("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -10, 0, 48),
    LayoutOrder = 1,
    Parent = settingsScroll,
}) :: Frame

local settingsTitle = makeLabel(settingsHeader, "Settings and transfer", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(2, 0), 20, COLORS.Text)
settingsTitle.Font = Enum.Font.GothamBold
makeLabel(settingsHeader, "Exported JSON includes every game list, alias, and setting.", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(2, 28), 11, COLORS.Muted)

local behaviorSection = makeSection(settingsScroll, "Behavior", 156)
behaviorSection.LayoutOrder = 2

local behaviorSortButton = makeButton(behaviorSection, "", UDim2.fromOffset(180, 36), UDim2.fromOffset(12, 42), COLORS.Panel3)
local idModeButton = makeButton(behaviorSection, "", UDim2.fromOffset(180, 36), UDim2.fromOffset(202, 42), COLORS.Panel3)
local safeTeleportButton = makeButton(behaviorSection, "", UDim2.fromOffset(180, 36), UDim2.fromOffset(12, 88), COLORS.Panel3)
local closeDropdownButton = makeButton(behaviorSection, "", UDim2.fromOffset(180, 36), UDim2.fromOffset(202, 88), COLORS.Panel3)
local autoSaveButton = makeButton(behaviorSection, "", UDim2.fromOffset(180, 36), UDim2.fromOffset(392, 42), COLORS.Panel3)
local saveFileButton = makeButton(behaviorSection, "Save local file", UDim2.fromOffset(180, 36), UDim2.fromOffset(392, 88), COLORS.Panel3)

local mergeSection = makeSection(settingsScroll, "Game / place library merge", 188)
mergeSection.LayoutOrder = 3

local currentIdsLabel = makeLabel(
    mergeSection,
    "",
    UDim2.new(1, -24, 0, 38),
    UDim2.fromOffset(12, 38),
    11,
    COLORS.Muted
)
currentIdsLabel.TextWrapped = true
currentIdsLabel.TextYAlignment = Enum.TextYAlignment.Top

local mergeIdBox = makeTextBox(
    mergeSection,
    "Target ID, game:123..., or place:123...",
    UDim2.new(1, -24, 0, 38),
    UDim2.fromOffset(12, 82),
    false
)

local mergeButton = makeButton(mergeSection, "Merge current into target", UDim2.fromOffset(220, 38), UDim2.fromOffset(12, 132), COLORS.Accent)
local unmergeButton = makeButton(mergeSection, "Unmerge current", UDim2.fromOffset(170, 38), UDim2.fromOffset(242, 132), COLORS.Panel3)
local clearCurrentButton = makeButton(mergeSection, "Clear current list", UDim2.fromOffset(154, 38), UDim2.fromOffset(410, 132), COLORS.Danger)

local transferSection = makeSection(settingsScroll, "JSON import / export", 380)
transferSection.LayoutOrder = 4

local transferInfo = makeLabel(
    transferSection,
    "Paste exported .json/.txt content below. Merge keeps existing entries; Replace overwrites all lists.",
    UDim2.new(1, -24, 0, 34),
    UDim2.fromOffset(12, 36),
    11,
    COLORS.Muted
)
transferInfo.TextWrapped = true
transferInfo.TextYAlignment = Enum.TextYAlignment.Top

local jsonBox = makeTextBox(
    transferSection,
    "Exported JSON appears here, or paste JSON here to import...",
    UDim2.new(1, -24, 0, 160),
    UDim2.fromOffset(12, 76),
    true
)
jsonBox.TextSize = 12
jsonBox.Font = Enum.Font.Code

local exportBoxButton = makeButton(transferSection, "Export to box", UDim2.fromOffset(120, 38), UDim2.fromOffset(12, 248), COLORS.Accent)
local copyButton = makeButton(transferSection, "Copy JSON", UDim2.fromOffset(110, 38), UDim2.fromOffset(142, 248), COLORS.Panel3)
local pasteButton = makeButton(transferSection, "Paste clipboard", UDim2.fromOffset(135, 38), UDim2.fromOffset(262, 248), COLORS.Panel3)
local importMergeButton = makeButton(transferSection, "Import + merge", UDim2.fromOffset(160, 38), UDim2.fromOffset(12, 296), COLORS.Positive)
local replaceButton = makeButton(transferSection, "Replace all", UDim2.fromOffset(140, 38), UDim2.fromOffset(182, 296), COLORS.Danger)

local capabilitySection = makeSection(settingsScroll, "Runtime capabilities", 112)
capabilitySection.LayoutOrder = 5

local capabilitiesLabel = makeLabel(
    capabilitySection,
    "",
    UDim2.new(1, -24, 0, 64),
    UDim2.fromOffset(12, 38),
    11,
    COLORS.Muted
)
capabilitiesLabel.TextWrapped = true
capabilitiesLabel.TextYAlignment = Enum.TextYAlignment.Top

local function booleanText(label: string, enabled: boolean): string
    return string.format("%s: %s", label, enabled and "ON" or "OFF")
end

local function uniqueNameForLibrary(library: {[string]: any}, desiredName: string): string
    local used = {}
    for _, position in ipairs(library.positions) do
        used[string.lower(position.name)] = true
    end

    if not used[string.lower(desiredName)] then
        return desiredName
    end

    local number = 2
    while used[string.lower(string.format("%s (%d)", desiredName, number))] do
        number += 1
    end

    return string.format("%s (%d)", desiredName, number)
end

local function clonePosition(position: {[string]: any}, targetLibrary: {[string]: any}): {[string]: any}
    local clean = sanitizePosition(position, state.nextCreatedIndex)
    assert(clean, "Position should already be valid")

    clean.id = HttpService:GenerateGUID(false)
    clean.name = uniqueNameForLibrary(targetLibrary, clean.name)
    clean.createdIndex = state.nextCreatedIndex
    state.nextCreatedIndex += 1
    return clean
end

local function mergeLibraries(sourceKey: string, targetKey: string): number
    sourceKey = resolveCanonicalKey(sourceKey)
    targetKey = resolveCanonicalKey(targetKey)

    if sourceKey == targetKey then
        return 0
    end

    local sourceLibrary = ensureLibrary(sourceKey)
    local targetLibrary = ensureLibrary(targetKey)
    local copied = 0

    for _, position in ipairs(sourceLibrary.positions) do
        table.insert(targetLibrary.positions, clonePosition(position, targetLibrary))
        copied += 1
    end

    state.games[sourceKey] = nil
    state.aliases[sourceKey] = targetKey

    return copied
end

local function mergeImportedState(imported: {[string]: any})
    -- Apply imported settings so the exported file behaves the same in the new instance.
    state.settings = shallowCopy(imported.settings)

    -- Install imported aliases first, then place imported positions into the
    -- canonical library selected by the combined alias map.
    for source, target in pairs(imported.aliases) do
        if source ~= target then
            state.aliases[source] = target
        end
    end

    for importedKey, importedLibrary in pairs(imported.games) do
        local targetLibrary = ensureLibrary(resolveCanonicalKey(importedKey))
        for _, position in ipairs(importedLibrary.positions) do
            table.insert(targetLibrary.positions, clonePosition(position, targetLibrary))
        end
    end

    state.nextCreatedIndex = math.max(state.nextCreatedIndex, imported.nextCreatedIndex or 1)
end

refreshSettingsUI = function()
    behaviorSortButton.Text = state.settings.sortMode == "Alphabetical" and "Sort mode: A → Z" or "Sort mode: Created"
    idModeButton.Text = "List key: " .. state.settings.idMode
    safeTeleportButton.Text = booleanText("Zero velocity", state.settings.safeTeleport)
    closeDropdownButton.Text = booleanText("Close after select", state.settings.closeDropdownAfterSelect)
    autoSaveButton.Text = booleanText("Auto local save", state.settings.autoSave)

    saveFileButton.Active = FILE_STORAGE_AVAILABLE
    saveFileButton.TextTransparency = FILE_STORAGE_AVAILABLE and 0 or 0.45
    copyButton.Active = CLIPBOARD_WRITE_AVAILABLE
    copyButton.TextTransparency = CLIPBOARD_WRITE_AVAILABLE and 0 or 0.45
    pasteButton.Active = CLIPBOARD_READ_AVAILABLE
    pasteButton.TextTransparency = CLIPBOARD_READ_AVAILABLE and 0 or 0.45

    currentIdsLabel.Text = string.format(
        "GameId: %s    PlaceId: %s\nActive raw key: %s    Canonical key: %s",
        tostring(game.GameId),
        tostring(game.PlaceId),
        currentRawKey(),
        resolveCanonicalKey(currentRawKey())
    )

    capabilitiesLabel.Text = string.format(
        "Clipboard write: %s   •   Clipboard read: %s   •   Local file: %s\nFile name: %s",
        CLIPBOARD_WRITE_AVAILABLE and "available" or "unavailable",
        CLIPBOARD_READ_AVAILABLE and "available" or "unavailable",
        FILE_STORAGE_AVAILABLE and "available" or "unavailable",
        FILE_NAME
    )
end

behaviorSortButton.Activated:Connect(function()
    state.settings.sortMode = state.settings.sortMode == "Created" and "Alphabetical" or "Created"
    persistIfEnabled()
    refreshSettingsUI()
    refreshPositionsUI()
end)

idModeButton.Activated:Connect(function()
    state.settings.idMode = state.settings.idMode == "GameId" and "PlaceId" or "GameId"
    selectedPositionId = nil
    setDropdownOpen(false)
    persistIfEnabled()
    refreshSettingsUI()
    refreshPositionsUI()
    setStatus("Active list key changed to " .. state.settings.idMode .. ".", "success")
end)

safeTeleportButton.Activated:Connect(function()
    state.settings.safeTeleport = not state.settings.safeTeleport
    persistIfEnabled()
    refreshSettingsUI()
end)

closeDropdownButton.Activated:Connect(function()
    state.settings.closeDropdownAfterSelect = not state.settings.closeDropdownAfterSelect
    persistIfEnabled()
    refreshSettingsUI()
end)

autoSaveButton.Activated:Connect(function()
    state.settings.autoSave = not state.settings.autoSave
    if state.settings.autoSave then
        writePersistentState()
    end
    refreshSettingsUI()
end)

saveFileButton.Activated:Connect(function()
    local ok, message = writePersistentState()
    setStatus(message, ok and "success" or "error")
end)

mergeButton.Activated:Connect(function()
    local sourceRaw = currentRawKey()
    local sourceCanonical = resolveCanonicalKey(sourceRaw)
    local targetRaw = normalizeKey(mergeIdBox.Text, state.settings.idMode)

    if not targetRaw then
        setStatus("Enter a numeric ID, game:ID, or place:ID.", "error")
        return
    end

    local targetCanonical = resolveCanonicalKey(targetRaw)
    if targetCanonical == sourceCanonical then
        setStatus("Those keys already use the same library.", "warning")
        return
    end

    local copied = mergeLibraries(sourceCanonical, targetCanonical)

    -- Redirect the actual current raw key, plus any old canonical source, to target.
    state.aliases[sourceRaw] = targetCanonical
    if sourceCanonical ~= sourceRaw then
        state.aliases[sourceCanonical] = targetCanonical
    end

    selectedPositionId = nil
    mergeIdBox.Text = ""
    persistIfEnabled()
    refreshSettingsUI()
    refreshPositionsUI()
    setStatus(string.format("Merged %d position%s into %s.", copied, copied == 1 and "" or "s", targetCanonical), "success")
end)

unmergeButton.Activated:Connect(function()
    local rawKey = currentRawKey()
    local canonical = resolveCanonicalKey(rawKey)

    if canonical == rawKey then
        setStatus("The current key is not merged.", "warning")
        return
    end

    local canonicalLibrary = ensureLibrary(canonical)
    local newLibrary = {positions = {}}
    state.games[rawKey] = newLibrary

    for _, position in ipairs(canonicalLibrary.positions) do
        table.insert(newLibrary.positions, clonePosition(position, newLibrary))
    end

    state.aliases[rawKey] = nil
    selectedPositionId = nil
    persistIfEnabled()
    refreshSettingsUI()
    refreshPositionsUI()
    setStatus("Current key was separated into its own copied list.", "success")
end)

clearCurrentButton.Activated:Connect(function()
    modalTitle.Text = "Clear current list"
    modalMessage.Text = "Type CLEAR to remove every position in the active list."
    modalMessage.TextColor3 = COLORS.Warning
    modalInput.PlaceholderText = "CLEAR"
    modalInput.Text = ""
    modalConfirm.Text = "Clear"
    modalConfirm.BackgroundColor3 = COLORS.Danger
    modalOverlay.Visible = true

    modalCallback = function(value)
        if string.upper(trim(value)) ~= "CLEAR" then
            modalMessage.Text = "Enter CLEAR exactly to confirm."
            modalMessage.TextColor3 = COLORS.Danger
            return
        end

        currentLibrary().positions = {}
        selectedPositionId = nil
        persistIfEnabled()
        closeModal()
        refreshPositionsUI()
        setStatus("Cleared the active list.", "success")
    end
end)

exportBoxButton.Activated:Connect(function()
    local json, encodeError = encodeState()
    if not json then
        setStatus(encodeError or "Export failed.", "error")
        return
    end

    jsonBox.Text = json
    jsonBox.CursorPosition = 1
    setStatus("Exported all lists and settings to the text box.", "success")
end)

copyButton.Activated:Connect(function()
    if not setClipboard then
        setStatus("Clipboard write is unavailable. Use Export to box and copy manually.", "warning")
        return
    end

    local json, encodeError = encodeState()
    if not json then
        setStatus(encodeError or "Export failed.", "error")
        return
    end

    local ok, result = pcall(setClipboard, json)
    if not ok then
        setStatus("Clipboard copy failed: " .. tostring(result), "error")
        return
    end

    jsonBox.Text = json
    setStatus("Copied exported JSON to the clipboard.", "success")
end)

pasteButton.Activated:Connect(function()
    if not getClipboard then
        setStatus("Clipboard read is unavailable. Paste into the box manually.", "warning")
        return
    end

    local ok, result = pcall(getClipboard)
    if not ok or type(result) ~= "string" then
        setStatus("Clipboard paste failed: " .. tostring(result), "error")
        return
    end

    jsonBox.Text = result
    setStatus("Pasted clipboard content into the import box.", "success")
end)

importMergeButton.Activated:Connect(function()
    local text = trim(jsonBox.Text)
    if text == "" then
        setStatus("Paste JSON into the box first.", "warning")
        return
    end

    local imported, decodeError = decodeState(text)
    if not imported then
        setStatus(decodeError or "Import failed.", "error")
        return
    end

    mergeImportedState(imported)
    selectedPositionId = nil
    persistIfEnabled()
    refreshSettingsUI()
    refreshPositionsUI()
    setStatus("Imported and merged the JSON library.", "success")
end)

replaceButton.Activated:Connect(function()
    local text = trim(jsonBox.Text)
    if text == "" then
        setStatus("Paste JSON into the box first.", "warning")
        return
    end

    local imported, decodeError = decodeState(text)
    if not imported then
        setStatus(decodeError or "Import failed.", "error")
        return
    end

    modalTitle.Text = "Replace every list"
    modalMessage.Text = "Type REPLACE to overwrite all current lists and settings."
    modalMessage.TextColor3 = COLORS.Warning
    modalInput.PlaceholderText = "REPLACE"
    modalInput.Text = ""
    modalConfirm.Text = "Replace"
    modalConfirm.BackgroundColor3 = COLORS.Danger
    modalOverlay.Visible = true

    modalCallback = function(value)
        if string.upper(trim(value)) ~= "REPLACE" then
            modalMessage.Text = "Enter REPLACE exactly to confirm."
            modalMessage.TextColor3 = COLORS.Danger
            return
        end

        state = imported
        selectedPositionId = nil
        persistIfEnabled()
        closeModal()
        setDropdownOpen(false)
        refreshSettingsUI()
        refreshPositionsUI()
        setStatus("Replaced all lists and settings from JSON.", "success")
    end
end)

--// Initial render
refreshSettingsUI()
refreshPositionsUI()

if FILE_STORAGE_AVAILABLE then
    setStatus("Ready. Local file persistence is available.", "success")
else
    setStatus("Ready. Export JSON to keep data between script instances.", "warning")
end
