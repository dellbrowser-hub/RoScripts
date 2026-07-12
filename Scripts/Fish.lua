-- FishingAutoFarm.client.lua
-- Event-driven, performance-focused fishing automation.
--
-- Uses only confirmed client behavior:
--   * Any Tool with events/castAsync + values/state is treated as a rod.
--   * Casting is performed with a real held/released input.
--   * Shake uses the live PlayerGui.shakeui.safezone.button.
--   * Reeling follows PlayerGui.reel.bar.fish with reel.bar.playerbar.
--
-- No controller require, no getgc scan, no game-wide scan, no pixel/framebuffer API.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SINGLETON_KEY = "__FishingAutoFarmVisionV1"

local old = rawget(_G, SINGLETON_KEY)
if type(old) == "table" and type(old.Destroy) == "function" then
	pcall(old.Destroy)
end

local oldAnalyzer = rawget(_G, "__FishingWorkflowAnalyzer")
if type(oldAnalyzer) == "table" and type(oldAnalyzer.Destroy) == "function" then
	pcall(oldAnalyzer.Destroy)
end

local App = {}
_G[SINGLETON_KEY] = App

local State = {
	Destroyed = 0,
	Unequipped = 1,
	Equipping = 2,
	Equipped = 3,
	Casting = 4,
	Searching = 5,
	Luring = 6,
	PreReel = 7,
	Reeling = 8,
	CatchFinished = 9,
}

local Settings = {
	FullAutoFarm = false,
	AutoEquip = false,
	AutoCast = false,
	AutoShake = false,
	AutoReel = false,
	CastMode = "Perfect Cast", -- "Perfect Cast" or "Fast Cast"
}

local destroyed = false
local connections = {}
local rodConnections = {}
local shakeConnections = {}
local reelGuiConnections = {}
local characterContainerConnections = {}
local backpackContainerConnections = {}
local castConnection = nil
local reelConnection = nil

local activeRod = nil
local activeStateValue = nil
local activeShakeGui = nil
local activeReelGui = nil

local castSession = nil
local castSequence = 0
local castRatioCalibration = 0.90
local castScheduleToken = 0

local reelHeld = false
local reelMissingSince = nil
local lastReelSwitch = 0

local statusControl
local inputControl
local RenLib
local Window
local uiControls = {}
local syncingMasterControls = false

local VirtualInputManager
local VirtualUser

pcall(function()
	VirtualInputManager = game:GetService("VirtualInputManager")
end)

pcall(function()
	VirtualUser = game:GetService("VirtualUser")
end)

local function getGlobalFunction(name)
	local ok, value = pcall(function()
		if name == "getconnections" then
			return getconnections
		elseif name == "firesignal" then
			return firesignal
		elseif name == "mouse1press" then
			return mouse1press
		elseif name == "mouse1release" then
			return mouse1release
		elseif name == "mouse1click" then
			return mouse1click
		elseif name == "mousemoveabs" then
			return mousemoveabs
		end
	end)

	if ok and type(value) == "function" then
		return value
	end

	return nil
end

local function addConnection(connection, bucket)
	if connection then
		table.insert(bucket or connections, connection)
	end
	return connection
end

local function disconnectBucket(bucket)
	for _, connection in ipairs(bucket) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(bucket)
end

local function setStatus(text)
	if statusControl and statusControl.SetContent then
		pcall(function()
			statusControl:SetContent(tostring(text))
		end)
	end
end

local function setInputStatus(text)
	if inputControl and inputControl.SetContent then
		pcall(function()
			inputControl:SetContent(tostring(text))
		end)
	end
end

local function character()
	return LocalPlayer.Character
end

local function backpack()
	return LocalPlayer:FindFirstChildOfClass("Backpack")
end

local function safePoint()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return Vector2.new(viewport.X * 0.55, viewport.Y * 0.45)
end

-- Input adapter --------------------------------------------------------------

local Input = {
	CastHeld = false,
	ReelHeld = false,
}

function Input.Mouse(down, point)
	point = point or safePoint()

	if VirtualInputManager then
		local ok = pcall(function()
			VirtualInputManager:SendMouseButtonEvent(
				point.X,
				point.Y,
				0,
				down,
				game,
				0
			)
		end)

		if ok then
			setInputStatus("VirtualInputManager")
			return true
		end
	end

	if VirtualUser then
		local camera = workspace.CurrentCamera
		local ok

		if down then
			ok = pcall(function()
				VirtualUser:Button1Down(
					point,
					camera and camera.CFrame or CFrame.new()
				)
			end)
		else
			ok = pcall(function()
				VirtualUser:Button1Up(
					point,
					camera and camera.CFrame or CFrame.new()
				)
			end)
		end

		if ok then
			setInputStatus("VirtualUser")
			return true
		end
	end

	-- Optional low-UNC fallback. Casting requires separate press/release
	-- functions; shake clicks can additionally use mouse1click later.
	local moveAbsolute = getGlobalFunction("mousemoveabs")
	local press = getGlobalFunction("mouse1press")
	local release = getGlobalFunction("mouse1release")

	if press and release then
		local moved = true

		if moveAbsolute then
			moved = pcall(
				moveAbsolute,
				math.floor(point.X + 0.5),
				math.floor(point.Y + 0.5)
			)
		end

		if moved then
			local ok

			if down then
				ok = pcall(press)
			else
				ok = pcall(release)
			end

			if ok then
				setInputStatus("mouse1press/release")
				return true
			end
		end
	end

	return false
end

function Input.Space(down)
	if VirtualInputManager then
		local ok = pcall(function()
			VirtualInputManager:SendKeyEvent(
				down,
				Enum.KeyCode.Space,
				false,
				game
			)
		end)

		if ok then
			setInputStatus("VirtualInputManager/Space")
			return true
		end
	end

	return Input.Mouse(down, safePoint())
end

function Input.SetCastHeld(held)
	if held == Input.CastHeld then
		return true
	end

	local ok = Input.Mouse(held, safePoint())
	if ok then
		Input.CastHeld = held
	end
	return ok
end

function Input.SetReelHeld(held)
	if held == Input.ReelHeld then
		return true
	end

	local ok = Input.Space(held)
	if ok then
		Input.ReelHeld = held
		reelHeld = held
	end
	return ok
end

function Input.ReleaseAll()
	Input.Mouse(false, safePoint())
	Input.Space(false)
	Input.CastHeld = false
	Input.ReelHeld = false
	reelHeld = false
end

-- Rod discovery --------------------------------------------------------------

local function isRod(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	local events = tool:FindFirstChild("events")
	local values = tool:FindFirstChild("values")

	if not events or not values then
		return false
	end

	local castAsync = events:FindFirstChild("castAsync")
	local stateValue = values:FindFirstChild("state")

	return castAsync ~= nil
		and castAsync:IsA("RemoteFunction")
		and stateValue ~= nil
		and stateValue:IsA("ValueBase")
end

local function findRod()
	local currentCharacter = character()
	if currentCharacter then
		for _, child in ipairs(currentCharacter:GetChildren()) do
			if isRod(child) then
				return child
			end
		end
	end

	local currentBackpack = backpack()
	if currentBackpack then
		for _, child in ipairs(currentBackpack:GetChildren()) do
			if isRod(child) then
				return child
			end
		end
	end

	return nil
end

local function rodState(rod)
	if not rod then
		return nil, nil
	end

	local values = rod:FindFirstChild("values")
	local stateValue = values and values:FindFirstChild("state")

	if stateValue and stateValue:IsA("ValueBase") then
		return tonumber(stateValue.Value), stateValue
	end

	return nil, nil
end

local function rodHasBobber(rod)
	return rod and rod:FindFirstChild("bobber") ~= nil
end

local function tryEquip()
	if destroyed or not Settings.AutoEquip then
		return
	end

	local rod = activeRod or findRod()
	if not rod then
		setStatus("No fishing rod found")
		return
	end

	local currentCharacter = character()
	local currentBackpack = backpack()

	if not currentCharacter or not currentBackpack then
		return
	end

	if rod.Parent == currentCharacter then
		setStatus("Rod equipped")
		return
	end

	if rod.Parent ~= currentBackpack then
		return
	end

	local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local ok = pcall(function()
		humanoid:EquipTool(rod)
	end)

	setStatus(ok and ("Equipping " .. rod.Name) or "Equip failed")
end

-- Cast charge-bar model ------------------------------------------------------

-- GUI-only perfect-cast controller.
--
-- It discovers the charge UI continuously, classifies horizontal/vertical
-- motion, tracks either a moving marker or a growing fill, detects green
-- target zones from ordinary GUI properties/gradients, and releases early
-- using measured visual velocity. It never reads internal game values.

local CAST_VISION_KEY = "__FishingAutoFarmCastVisionV4"

local castVision = rawget(_G, CAST_VISION_KEY)
if type(castVision) ~= "table" or castVision.Version ~= 4 then
	castVision = {
		Version = 4,
		ReleaseLead = 0.050,
		FallbackTarget = castRatioCalibration,
		PerfectSamples = 0,
	}
	_G[CAST_VISION_KEY] = castVision
end

castRatioCalibration = math.clamp(
	tonumber(castVision.FallbackTarget) or castRatioCalibration,
	0.74,
	0.98
)

local function guiObjectVisible(object)
	if not object or not object.Parent then
		return false
	end

	local current = object

	while current and current ~= PlayerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end

		if current:IsA("LayerCollector") and not current.Enabled then
			return false
		end

		current = current.Parent
	end

	return true
end

local function stopCastTracker(releaseInput)
	if castConnection then
		pcall(function()
			castConnection:Disconnect()
		end)
		castConnection = nil
	end

	if releaseInput then
		Input.SetCastHeld(false)
	end
end

local function disconnectCastSessionConnections(session)
	if not session then
		return
	end

	for _, connection in ipairs(session.Connections or {}) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(session.Connections or {})
end

local function guiColor(object)
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		return object.ImageColor3
	end

	if object:IsA("TextLabel") or object:IsA("TextButton") then
		return object.BackgroundTransparency < 0.98
			and object.BackgroundColor3
			or object.TextColor3
	end

	if object:IsA("Frame") or object:IsA("ScrollingFrame") then
		return object.BackgroundColor3
	end

	return nil
end

local function greenStrength(color)
	if typeof(color) ~= "Color3" then
		return 0
	end

	local h, s, v = color:ToHSV()

	if h < 0.16 or h > 0.48 or s < 0.20 or v < 0.18 then
		return 0
	end

	local centerScore = 1 - math.min(math.abs(h - 0.33) / 0.17, 1)
	return math.clamp(
		0.35 + centerScore * 0.35 + s * 0.20 + v * 0.10,
		0,
		1
	)
end

local function objectGreenStrength(object)
	local score = greenStrength(guiColor(object))

	for _, child in ipairs(object:GetChildren()) do
		if child:IsA("UIGradient") then
			for _, keypoint in ipairs(child.Color.Keypoints) do
				score = math.max(
					score,
					greenStrength(keypoint.Value)
				)
			end
		end
	end

	return score
end

local function castGeometry(object)
	local position = object.AbsolutePosition
	local size = object.AbsoluteSize

	return {
		X = position.X,
		Y = position.Y,
		W = size.X,
		H = size.Y,
		CX = position.X + size.X / 2,
		CY = position.Y + size.Y / 2,
		Right = position.X + size.X,
		Bottom = position.Y + size.Y,
	}
end

local function castRootScore(object)
	if not object:IsA("GuiObject")
		or not guiObjectVisible(object)
	then
		return -math.huge
	end

	local size = object.AbsoluteSize
	local position = object.AbsolutePosition
	local camera = workspace.CurrentCamera
	local viewport =
		camera and camera.ViewportSize
		or Vector2.new(1280, 720)

	if size.X < 8 or size.Y < 8 then
		return -math.huge
	end

	if size.X > viewport.X * 0.50
		or size.Y > viewport.Y * 0.90
	then
		return -math.huge
	end

	local aspect = math.max(
		size.X / math.max(size.Y, 1),
		size.Y / math.max(size.X, 1)
	)

	if aspect < 1.45 then
		return -math.huge
	end

	local score = math.min(aspect * 8, 40)
	local lowered = string.lower(object.Name)

	if string.find(lowered, "cast", 1, true)
		or string.find(lowered, "power", 1, true)
		or string.find(lowered, "charge", 1, true)
		or string.find(lowered, "meter", 1, true)
	then
		score += 55
	elseif string.find(lowered, "bar", 1, true) then
		score += 25
	end

	if position.X > viewport.X * 0.55 then
		score += 18
	end

	if position.Y > viewport.Y * 0.20
		and position.Y < viewport.Y * 0.85
	then
		score += 8
	end

	local greenCount = 0
	local inspected = 0

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			inspected += 1

			if objectGreenStrength(descendant) >= 0.45 then
				greenCount += 1
			end

			if inspected >= 140 then
				break
			end
		end
	end

	score += math.min(greenCount * 20, 70)

	if object:FindFirstAncestor("FishingAutoFarm") then
		score -= 500
	end

	return score
end

local function chooseCastRoot(objects)
	local best
	local bestScore = -math.huge

	for _, object in ipairs(objects) do
		if object:IsA("GuiObject") then
			local score = castRootScore(object)

			if score > bestScore then
				best = object
				bestScore = score
			end
		end
	end

	if bestScore >= 42 then
		return best, bestScore
	end

	return nil, bestScore
end

local function scanPlayerGuiForCastRoot()
	local candidates = {}
	local descendants = PlayerGui:GetDescendants()
	local limit = math.min(#descendants, 4200)

	for index = 1, limit do
		local object = descendants[index]

		if object:IsA("GuiObject") then
			table.insert(candidates, object)
		end
	end

	return chooseCastRoot(candidates)
end

local function collectCastObjects(root)
	local objects = { root }

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			table.insert(objects, descendant)
		end

		if #objects >= 220 then
			break
		end
	end

	return objects
end

local function updateCastMotion(session, object, now)
	local geometry = castGeometry(object)
	local stat = session.Motion[object]

	if not stat then
		stat = {
			Previous = geometry,
			LastTime = now,
			CenterXMotion = 0,
			CenterYMotion = 0,
			WidthMotion = 0,
			HeightMotion = 0,
			LeftMotion = 0,
			RightMotion = 0,
			TopMotion = 0,
			BottomMotion = 0,
			Frames = 0,
		}
		session.Motion[object] = stat
		return stat
	end

	local previous = stat.Previous

	stat.CenterXMotion += math.abs(geometry.CX - previous.CX)
	stat.CenterYMotion += math.abs(geometry.CY - previous.CY)
	stat.WidthMotion += math.abs(geometry.W - previous.W)
	stat.HeightMotion += math.abs(geometry.H - previous.H)
	stat.LeftMotion += math.abs(geometry.X - previous.X)
	stat.RightMotion += math.abs(geometry.Right - previous.Right)
	stat.TopMotion += math.abs(geometry.Y - previous.Y)
	stat.BottomMotion += math.abs(geometry.Bottom - previous.Bottom)
	stat.Frames += 1
	stat.Previous = geometry
	stat.LastTime = now

	return stat
end

local function castAxis(root)
	local size = root.AbsoluteSize

	if size.Y >= size.X then
		return "Y"
	end

	return "X"
end

local function objectInsideRoot(object, root)
	local objectGeometry = castGeometry(object)
	local rootGeometry = castGeometry(root)
	local margin = 8

	return objectGeometry.CX >= rootGeometry.X - margin
		and objectGeometry.CX <= rootGeometry.Right + margin
		and objectGeometry.CY >= rootGeometry.Y - margin
		and objectGeometry.CY <= rootGeometry.Bottom + margin
end

local function moverScore(session, root, object, axis)
	if object == root
		or not object.Parent
		or not guiObjectVisible(object)
		or not objectInsideRoot(object, root)
	then
		return -math.huge
	end

	local geometry = castGeometry(object)
	local rootGeometry = castGeometry(root)
	local stat = session.Motion[object]

	if not stat or stat.Frames < 2 then
		return -math.huge
	end

	local axisLength
	local crossLength
	local rootAxisLength
	local rootCrossLength
	local axisMotion
	local crossMotion
	local edgeMotion
	local sizeMotion

	if axis == "Y" then
		axisLength = geometry.H
		crossLength = geometry.W
		rootAxisLength = rootGeometry.H
		rootCrossLength = rootGeometry.W
		axisMotion = stat.CenterYMotion
		crossMotion = stat.CenterXMotion
		edgeMotion = math.max(
			stat.TopMotion,
			stat.BottomMotion
		)
		sizeMotion = stat.HeightMotion
	else
		axisLength = geometry.W
		crossLength = geometry.H
		rootAxisLength = rootGeometry.W
		rootCrossLength = rootGeometry.H
		axisMotion = stat.CenterXMotion
		crossMotion = stat.CenterYMotion
		edgeMotion = math.max(
			stat.LeftMotion,
			stat.RightMotion
		)
		sizeMotion = stat.WidthMotion
	end

	if axisLength < 1
		or crossLength < 1
		or axisLength > rootAxisLength * 1.15
		or crossLength > rootCrossLength * 1.30
	then
		return -math.huge
	end

	local meaningfulMotion =
		math.max(axisMotion, edgeMotion, sizeMotion)

	if meaningfulMotion < 1.2 then
		return -math.huge
	end

	local score =
		meaningfulMotion * 5
		+ sizeMotion * 2
		- crossMotion * 1.5

	if crossLength >= rootCrossLength * 0.25 then
		score += 8
	end

	local lowered = string.lower(object.Name)

	if string.find(lowered, "fill", 1, true)
		or string.find(lowered, "power", 1, true)
		or string.find(lowered, "marker", 1, true)
		or string.find(lowered, "cursor", 1, true)
		or string.find(lowered, "bar", 1, true)
	then
		score += 15
	end

	if geometry.W >= rootGeometry.W * 0.95
		and geometry.H >= rootGeometry.H * 0.95
		and meaningfulMotion < 5
	then
		score -= 100
	end

	return score
end

local function chooseCastMover(session, root, objects, axis)
	local best
	local bestScore = -math.huge

	for _, object in ipairs(objects) do
		local score = moverScore(
			session,
			root,
			object,
			axis
		)

		if score > bestScore then
			best = object
			bestScore = score
		end
	end

	if bestScore >= 10 then
		return best
	end

	return nil
end

local function targetZoneScore(session, root, object, mover, axis)
	if object == root
		or object == mover
		or not object.Parent
		or not guiObjectVisible(object)
		or not objectInsideRoot(object, root)
	then
		return -math.huge
	end

	local geometry = castGeometry(object)
	local rootGeometry = castGeometry(root)
	local green = objectGreenStrength(object)
	local lowered = string.lower(object.Name)
	local nameScore = 0

	if string.find(lowered, "perfect", 1, true)
		or string.find(lowered, "target", 1, true)
		or string.find(lowered, "green", 1, true)
		or string.find(lowered, "zone", 1, true)
	then
		nameScore = 55
	end

	local axisLength
	local crossLength
	local rootAxisLength
	local rootCrossLength
	local motion = 0
	local stat = session.Motion[object]

	if axis == "Y" then
		axisLength = geometry.H
		crossLength = geometry.W
		rootAxisLength = rootGeometry.H
		rootCrossLength = rootGeometry.W

		if stat then
			motion =
				stat.CenterYMotion
				+ stat.HeightMotion
		end
	else
		axisLength = geometry.W
		crossLength = geometry.H
		rootAxisLength = rootGeometry.W
		rootCrossLength = rootGeometry.H

		if stat then
			motion =
				stat.CenterXMotion
				+ stat.WidthMotion
		end
	end

	if axisLength < 2
		or axisLength > rootAxisLength * 0.55
		or crossLength < rootCrossLength * 0.12
	then
		return -math.huge
	end

	local score =
		green * 120
		+ nameScore
		+ math.min(
			crossLength
				/ math.max(rootCrossLength, 1)
				* 20,
			20
		)
		- motion * 2

	if green < 0.25 and nameScore == 0 then
		return -math.huge
	end

	return score
end

local function findCastTargetZone(
	session,
	root,
	objects,
	mover,
	axis
)
	local best
	local bestScore = -math.huge

	for _, object in ipairs(objects) do
		local score = targetZoneScore(
			session,
			root,
			object,
			mover,
			axis
		)

		if score > bestScore then
			best = object
			bestScore = score
		end
	end

	if bestScore >= 48 then
		return best
	end

	return nil
end

local function castMoverCoordinate(session, root, mover, axis, now)
	local geometry = castGeometry(mover)
	local rootGeometry = castGeometry(root)
	local stat = session.Motion[mover]

	if not stat then
		return nil
	end

	local coordinate
	local motionType
	local startMotion
	local endMotion
	local centerMotion
	local sizeMotion

	if axis == "Y" then
		startMotion = stat.TopMotion
		endMotion = stat.BottomMotion
		centerMotion = stat.CenterYMotion
		sizeMotion = stat.HeightMotion

		if math.max(startMotion, endMotion) >
			centerMotion * 1.10
			or sizeMotion > centerMotion * 0.75
		then
			motionType = "Fill"
			coordinate =
				startMotion >= endMotion
					and geometry.Y
					or geometry.Bottom
		else
			motionType = "Marker"
			coordinate = geometry.CY
		end
	else
		startMotion = stat.LeftMotion
		endMotion = stat.RightMotion
		centerMotion = stat.CenterXMotion
		sizeMotion = stat.WidthMotion

		if math.max(startMotion, endMotion) >
			centerMotion * 1.10
			or sizeMotion > centerMotion * 0.75
		then
			motionType = "Fill"
			coordinate =
				startMotion >= endMotion
					and geometry.X
					or geometry.Right
		else
			motionType = "Marker"
			coordinate = geometry.CX
		end
	end

	local velocity = session.MoverVelocity or 0

	if session.LastMoverCoordinate
		and session.LastMoverTime
	then
		local deltaTime = math.clamp(
			now - session.LastMoverTime,
			1 / 240,
			0.12
		)

		local rawVelocity =
			(coordinate - session.LastMoverCoordinate)
			/ deltaTime

		local alpha =
			1 - math.exp(-28 * deltaTime)

		velocity +=
			(rawVelocity - velocity) * alpha
	end

	session.LastMoverCoordinate = coordinate
	session.LastMoverTime = now
	session.MoverVelocity = velocity
	session.MotionType = motionType

	if math.abs(velocity) > 4 then
		session.Direction =
			velocity > 0 and 1 or -1
	end

	local rootStart =
		axis == "Y" and rootGeometry.Y or rootGeometry.X

	local rootLength =
		axis == "Y" and rootGeometry.H or rootGeometry.W

	local direction = session.Direction or 1
	local progress

	if direction >= 0 then
		progress =
			(coordinate - rootStart)
			/ math.max(rootLength, 1)
	else
		progress =
			(rootStart + rootLength - coordinate)
			/ math.max(rootLength, 1)
	end

	progress = math.clamp(progress, 0, 1.25)
	session.LastRatio = progress

	return coordinate, velocity, progress
end

local function perfectTextCandidate(object)
	if not (
		object:IsA("TextLabel")
		or object:IsA("TextButton")
	) then
		return false
	end

	if not guiObjectVisible(object) then
		return false
	end

	local normalized =
		string.upper(object.Text or "")
			:gsub("%s+", " ")

	return string.find(
		normalized,
		"PERFECT",
		1,
		true
	) ~= nil
end

local function markPerfectResult(session, object)
	if session.PerfectDetected then
		return
	end

	if not perfectTextCandidate(object) then
		if session.BaselinePerfect then
			session.BaselinePerfect[object] = nil
		end
		return
	end

	if session.BaselinePerfect
		and session.BaselinePerfect[object]
	then
		return
	end

	session.PerfectDetected = true
	setStatus("Perfect cast confirmed")
end

local function scanPerfectResult(session)
	local descendants = PlayerGui:GetDescendants()
	local limit = math.min(#descendants, 3200)

	for index = 1, limit do
		local object = descendants[index]

		if object:IsA("TextLabel")
			or object:IsA("TextButton")
		then
			markPerfectResult(session, object)

			if session.PerfectDetected then
				return true
			end
		end
	end

	return false
end

local function beginCastResultWatcher(session)
	session.BaselinePerfect =
		setmetatable({}, { __mode = "k" })

	local descendants = PlayerGui:GetDescendants()
	local limit = math.min(#descendants, 3200)

	for index = 1, limit do
		local object = descendants[index]

		if perfectTextCandidate(object) then
			session.BaselinePerfect[object] = true
		end
	end

	table.insert(
		session.Connections,
		PlayerGui.DescendantAdded:Connect(function(object)
			if castSession ~= session then
				return
			end

			if object:IsA("TextLabel")
				or object:IsA("TextButton")
			then
				markPerfectResult(session, object)
			end
		end)
	)
end

local function finalizeCastResult(session)
	task.spawn(function()
		local deadline = os.clock() + 1.65

		while not destroyed
			and not session.PerfectDetected
			and os.clock() < deadline
		do
			scanPerfectResult(session)

			if not session.PerfectDetected then
				task.wait(0.10)
			end
		end

		if session.PerfectDetected
			and type(session.ReleaseRatio) == "number"
		then
			castVision.PerfectSamples += 1
			castVision.FallbackTarget =
				math.clamp(
					castVision.FallbackTarget * 0.72
						+ session.ReleaseRatio * 0.28,
					0.74,
					0.98
				)

			castRatioCalibration =
				castVision.FallbackTarget

			_G[CAST_VISION_KEY] = castVision
		end

		disconnectCastSessionConnections(session)
		session.BaselinePerfect = nil
	end)
end

local function releaseCast(session, reason, ratio)
	if not session or session.Released then
		return
	end

	session.Released = true
	session.ReleaseRatio = ratio

	stopCastTracker(true)

	if session.DiscoveryConnection then
		pcall(function()
			session.DiscoveryConnection:Disconnect()
		end)
		session.DiscoveryConnection = nil
	end

	setStatus(reason or "Cast released")
	finalizeCastResult(session)
end

local function castTargetCrossed(
	session,
	target,
	axis,
	coordinate,
	velocity
)
	if not target
		or not target.Parent
		or not guiObjectVisible(target)
	then
		return false
	end

	local geometry = castGeometry(target)
	local targetStart
	local targetEnd
	local targetLength

	if axis == "Y" then
		targetStart = geometry.Y
		targetEnd = geometry.Bottom
		targetLength = geometry.H
	else
		targetStart = geometry.X
		targetEnd = geometry.Right
		targetLength = geometry.W
	end

	local lead =
		math.clamp(
			tonumber(castVision.ReleaseLead) or 0.050,
			0.020,
			0.110
		)

	local predicted =
		coordinate + velocity * lead

	local tolerance =
		math.max(2, targetLength * 0.20)

	local segmentStart = math.min(coordinate, predicted)
	local segmentEnd = math.max(coordinate, predicted)

	if coordinate >= targetStart - tolerance
		and coordinate <= targetEnd + tolerance
	then
		return true
	end

	return segmentEnd >= targetStart - tolerance
		and segmentStart <= targetEnd + tolerance
end

local function startCast()
	if destroyed
		or not Settings.AutoCast
		or castSession
	then
		return
	end

	local rod = activeRod
	local currentCharacter = character()

	if not rod
		or not currentCharacter
		or rod.Parent ~= currentCharacter
	then
		return
	end

	local state = rodState(rod)

	if state ~= State.Equipped
		or rodHasBobber(rod)
	then
		return
	end

	castSequence += 1

	local session = {
		Id = castSequence,
		StartedAt = os.clock(),
		Released = false,
		Root = nil,
		RootScore = -math.huge,
		Mover = nil,
		Target = nil,
		Axis = nil,
		Motion = setmetatable({}, { __mode = "k" }),
		Connections = {},
		LastRatio = 0,
		LastScanAt = 0,
		MoverVelocity = 0,
		Direction = nil,
		PerfectDetected = false,
		Objects = nil,
		LastObjectRefresh = 0,
		RootDetectedAt = nil,
		MoverDetectedAt = nil,
		HadTarget = false,
		TargetLostAt = nil,
	}

	castSession = session
	beginCastResultWatcher(session)

	if not Input.SetCastHeld(true) then
		disconnectCastSessionConnections(session)
		castSession = nil
		setStatus("No usable cast input backend")
		return
	end

	setStatus("Charging cast — detecting meter")

	session.DiscoveryConnection =
		PlayerGui.DescendantAdded:Connect(function(object)
			if castSession ~= session
				or session.Released
				or not object:IsA("GuiObject")
			then
				return
			end

			local candidates = { object }
			local ancestor = object.Parent

			for _ = 1, 7 do
				if not ancestor
					or ancestor == PlayerGui
				then
					break
				end

				if ancestor:IsA("GuiObject") then
					table.insert(
						candidates,
						ancestor
					)
				end

				ancestor = ancestor.Parent
			end

			local root, score =
				chooseCastRoot(candidates)

			if root and score > session.RootScore then
				session.Root = root
				session.RootScore = score
				session.RootDetectedAt = os.clock()
				session.Mover = nil
				session.MoverDetectedAt = nil
				session.Target = nil
				session.HadTarget = false
				session.TargetLostAt = nil
				session.Objects = nil
				session.LastObjectRefresh = 0
				session.Motion =
					setmetatable({}, { __mode = "k" })
			end
		end)

	local accumulator = 0

	castConnection =
		RunService.RenderStepped:Connect(function(deltaTime)
			if destroyed
				or castSession ~= session
			then
				stopCastTracker(true)
				return
			end

			accumulator += deltaTime

			if accumulator < 1 / 60 then
				return
			end

			accumulator = 0

			local now = os.clock()
			local elapsed = now - session.StartedAt

			if now - session.LastScanAt >= 0.10 then
				session.LastScanAt = now

				if not session.Root
					or not session.Root.Parent
					or not guiObjectVisible(session.Root)
				then
					local root, score =
						scanPlayerGuiForCastRoot()

					if root then
						session.Root = root
						session.RootScore = score
						session.RootDetectedAt = now
						session.Mover = nil
						session.MoverDetectedAt = nil
						session.Target = nil
						session.HadTarget = false
						session.TargetLostAt = nil
						session.Objects = nil
						session.LastObjectRefresh = 0
						session.Motion =
							setmetatable(
								{},
								{ __mode = "k" }
							)
					end
				end
			end

			if not session.Root
				or not session.Root.Parent
				or not guiObjectVisible(session.Root)
			then
				if elapsed > 1.10 then
					releaseCast(
						session,
						"Cast meter unavailable — fallback cast",
						nil
					)
				end
				return
			end

			local root = session.Root

			if not session.RootDetectedAt then
				session.RootDetectedAt = now
			end

			-- Fast Cast releases as soon as the visible charge meter appears.
			if Settings.CastMode == "Fast Cast" then
				releaseCast(
					session,
					"Fast cast — meter detected",
					session.LastRatio
				)
				return
			end

			local axis = castAxis(root)
			session.Axis = axis

			if not session.Objects
				or now - session.LastObjectRefresh >= 0.08
			then
				session.Objects = collectCastObjects(root)
				session.LastObjectRefresh = now
			end

			local objects = session.Objects

			for _, object in ipairs(objects) do
				if guiObjectVisible(object) then
					updateCastMotion(
						session,
						object,
						now
					)
				end
			end

			if not session.Mover
				or not session.Mover.Parent
				or not guiObjectVisible(session.Mover)
			then
				session.Mover =
					chooseCastMover(
						session,
						root,
						objects,
						axis
					)

				if session.Mover then
					session.MoverDetectedAt = now
				end
			end

			local targetWasInvalid =
				session.Target
				and (
					not session.Target.Parent
					or not guiObjectVisible(session.Target)
				)

			if targetWasInvalid then
				session.Target = nil
				session.TargetLostAt =
					session.TargetLostAt or now
			end

			if session.Mover and not session.Target then
				session.Target =
					findCastTargetZone(
						session,
						root,
						objects,
						session.Mover,
						axis
					)

				if session.Target then
					session.HadTarget = true
					session.TargetLostAt = nil
				end
			end

			if session.HadTarget
				and not session.Target
				and session.TargetLostAt
				and now - session.TargetLostAt > 0.14
			then
				releaseCast(
					session,
					"Perfect target lost — fallback cast",
					session.LastRatio
				)
				return
			end

			if not session.Mover then
				local rootAge =
					now - (session.RootDetectedAt or now)

				if rootAge > 0.38 then
					releaseCast(
						session,
						"Perfect tracking unavailable — fallback cast",
						session.LastRatio
					)
				end
				return
			end

			if not session.Target
				and session.MoverDetectedAt
				and now - session.MoverDetectedAt > 0.40
			then
				releaseCast(
					session,
					"Perfect zone unavailable — fallback cast",
					session.LastRatio
				)
				return
			end

			local coordinate, velocity, ratio =
				castMoverCoordinate(
					session,
					root,
					session.Mover,
					axis,
					now
				)

			if not coordinate then
				return
			end

			if session.Target
				and castTargetCrossed(
					session,
					session.Target,
					axis,
					coordinate,
					velocity
				)
			then
				releaseCast(
					session,
					"Predictive perfect-zone release",
					ratio
				)
				return
			end

			if elapsed > 2.60 then
				releaseCast(
					session,
					"Perfect cast timeout — fallback cast",
					ratio
				)
			end
		end)

	-- Rod state is confirmation only. Entering Casting must never trigger an
	-- early release; that was the main bug in the previous implementation.
	task.spawn(function()
		while castSession == session
			and not session.Released
		do
			task.wait(0.05)

			local currentState = rodState(rod)

			if rodHasBobber(rod)
				or (
					currentState
					and currentState >= State.Searching
				)
			then
				releaseCast(
					session,
					"Cast accepted",
					session.LastRatio
				)
				break
			end
		end
	end)
end

local function clearCastSession()
	stopCastTracker(true)

	if castSession then
		if castSession.DiscoveryConnection then
			pcall(function()
				castSession.DiscoveryConnection
					:Disconnect()
			end)
		end

		disconnectCastSessionConnections(castSession)
	end

	castSession = nil
end

-- Shake ----------------------------------------------------------------------

-- Persistent GUI-only shake controller.
--
-- It supports buttons that are created late, nested under extra containers,
-- reused by changing Visible/Position, or ignored by very short synthetic
-- clicks. A click is accepted only after the visible prompt responds.

local shakeButtonStates =
	setmetatable({}, { __mode = "k" })

local shakeCandidates =
	setmetatable({}, { __mode = "k" })

local shakeScanGeneration = 0

local function shakeGeometry(button)
	local position = button.AbsolutePosition
	local size = button.AbsoluteSize

	return {
		X = position.X,
		Y = position.Y,
		W = size.X,
		H = size.Y,
		Parent = button.Parent,
	}
end

local function shakeSignature(button)
	local geometry = shakeGeometry(button)

	return table.concat({
		math.floor(geometry.X / 4 + 0.5),
		math.floor(geometry.Y / 4 + 0.5),
		math.floor(geometry.W / 4 + 0.5),
		math.floor(geometry.H / 4 + 0.5),
	}, ":")
end

local function shakeGeometryChanged(before, button)
	if not button.Parent
		or not guiObjectVisible(button)
	then
		return true
	end

	local after = shakeGeometry(button)

	return after.Parent ~= before.Parent
		or math.abs(after.X - before.X) >= 3
		or math.abs(after.Y - before.Y) >= 3
		or math.abs(after.W - before.W) >= 3
		or math.abs(after.H - before.H) >= 3
end

local function waitForShakeResponse(
	button,
	before,
	timeout
)
	local deadline = os.clock() + timeout

	while os.clock() < deadline do
		if destroyed or not Settings.AutoShake then
			return false
		end

		if shakeGeometryChanged(before, button) then
			return true
		end

		RunService.Heartbeat:Wait()
	end

	return shakeGeometryChanged(before, button)
end

local function clickViaConnections(button)
	local getConnections =
		getGlobalFunction("getconnections")

	if not getConnections then
		return false
	end

	local fired = false

	for _, signal in ipairs({
		button.MouseButton1Click,
		button.Activated,
	}) do
		local ok, result =
			pcall(getConnections, signal)

		if ok and type(result) == "table" then
			for _, connection in ipairs(result) do
				local callback =
					connection.Function

				if type(callback) == "function" then
					fired =
						pcall(callback)
						or fired
				end
			end
		end
	end

	if fired then
		setInputStatus("getconnections")
	end

	return fired
end

local function guiInset()
	local ok, topLeft =
		pcall(function()
			local inset =
				GuiService:GetGuiInset()
			return inset
		end)

	if ok and typeof(topLeft) == "Vector2" then
		return topLeft
	end

	return Vector2.zero
end

local function shakeClickPoints(button)
	local center =
		button.AbsolutePosition
		+ button.AbsoluteSize / 2

	local inset = guiInset()
	local points = { center }

	if inset.Magnitude > 0.5 then
		table.insert(points, center + inset)
		table.insert(points, center - inset)
	end

	return points
end

local function sendTimedMouseClick(point, duration)
	local pressed = Input.Mouse(true, point)

	if not pressed then
		return false
	end

	task.wait(duration)

	local released = Input.Mouse(false, point)

	if not released then
		Input.Mouse(false, point)
	end

	return released
end

local function sendLowUncClick(point)
	local moveAbsolute =
		getGlobalFunction("mousemoveabs")

	local click =
		getGlobalFunction("mouse1click")

	if not click then
		return false
	end

	if moveAbsolute then
		local moved = pcall(
			moveAbsolute,
			math.floor(point.X + 0.5),
			math.floor(point.Y + 0.5)
		)

		if not moved then
			return false
		end
	end

	local ok = pcall(click)

	if ok then
		setInputStatus("mouse1click")
	end

	return ok
end

local function shakeButtonScore(button)
	if not button:IsA("GuiButton")
		or not guiObjectVisible(button)
	then
		return -math.huge
	end

	local size = button.AbsoluteSize
	local position = button.AbsolutePosition
	local camera = workspace.CurrentCamera
	local viewport =
		camera and camera.ViewportSize
		or Vector2.new(1280, 720)

	if size.X < 8
		or size.Y < 8
		or position.X + size.X < 0
		or position.Y + size.Y < 0
		or position.X > viewport.X
		or position.Y > viewport.Y
	then
		return -math.huge
	end

	local score = 10
	local lowered = string.lower(button.Name)

	if lowered == "button" then
		score += 90
	elseif string.find(lowered, "shake", 1, true) then
		score += 65
	elseif string.find(lowered, "click", 1, true) then
		score += 25
	end

	local ancestor = button.Parent

	for _ = 1, 8 do
		if not ancestor
			or ancestor == PlayerGui
		then
			break
		end

		local ancestorName =
			string.lower(ancestor.Name)

		if string.find(
			ancestorName,
			"safezone",
			1,
			true
		) then
			score += 70
			break
		end

		ancestor = ancestor.Parent
	end

	if button.Active then
		score += 8
	end

	if size.X >= 20 and size.Y >= 20 then
		score += 8
	end

	return score
end

local function clickShake(button, state)
	if destroyed
		or not Settings.AutoShake
		or not button
		or not button.Parent
		or state.Busy
	then
		return
	end

	state.Busy = true
	state.LastAttempt = os.clock()

	task.spawn(function()
		local success = false
		local durations = {
			0.045,
			0.070,
			0.100,
		}

		local clickPoints = shakeClickPoints(button)

		for _, duration in ipairs(durations) do
			for _, point in ipairs(clickPoints) do
				if destroyed
					or not Settings.AutoShake
					or not button.Parent
					or not guiObjectVisible(button)
				then
					break
				end

				local before = shakeGeometry(button)
				local sent =
					sendTimedMouseClick(
						point,
						duration
					)

				if sent and waitForShakeResponse(
					button,
					before,
					0.13
				) then
					success = true
					break
				end
			end

			if success
				or destroyed
				or not Settings.AutoShake
				or not button.Parent
				or not guiObjectVisible(button)
			then
				break
			end
		end

		if not success
			and button.Parent
			and guiObjectVisible(button)
		then
			local before = shakeGeometry(button)
			local center =
				button.AbsolutePosition
				+ button.AbsoluteSize / 2

			if sendLowUncClick(center)
				and waitForShakeResponse(
					button,
					before,
					0.13
				)
			then
				success = true
			end
		end

		if not success
			and button.Parent
			and guiObjectVisible(button)
		then
			local before = shakeGeometry(button)
			local activated = pcall(function()
				button:Activate()
			end)

			if activated
				and waitForShakeResponse(
					button,
					before,
					0.13
				)
			then
				success = true
			end
		end

		if not success
			and button.Parent
			and guiObjectVisible(button)
		then
			local before = shakeGeometry(button)

			if clickViaConnections(button)
				and waitForShakeResponse(
					button,
					before,
					0.13
				)
			then
				success = true
			end
		end

		state.Busy = false
		state.LastAttempt = os.clock()

		if success then
			state.HandledSignature =
				state.LastSignature

			setStatus("Shake confirmed")
		else
			setStatus("Shake retrying")
		end
	end)
end

local function considerShakeButton(button)
	local score = shakeButtonScore(button)

	if score < 55 then
		return
	end

	local now = os.clock()
	local state = shakeButtonStates[button]

	if not state then
		state = {
			LastVisible = false,
			LastSignature = nil,
			HandledSignature = nil,
			StableSince = now,
			LastAttempt = 0,
			Busy = false,
		}

		shakeButtonStates[button] = state
	end

	local visible =
		guiObjectVisible(button)
		and button.AbsoluteSize.X >= 8
		and button.AbsoluteSize.Y >= 8

	if not visible then
		state.LastVisible = false
		state.HandledSignature = nil
		state.StableSince = now
		return
	end

	local signature = shakeSignature(button)

	if not state.LastVisible then
		state.LastVisible = true
		state.LastSignature = signature
		state.HandledSignature = nil
		state.StableSince = now
		return
	end

	if state.LastSignature ~= signature then
		state.LastSignature = signature
		state.HandledSignature = nil
		state.StableSince = now
		return
	end

	if state.Busy
		or state.HandledSignature == signature
		or now - state.StableSince < 0.025
		or now - state.LastAttempt < 0.10
	then
		return
	end

	clickShake(button, state)
end

local function isShakeGuiCandidate(gui)
	if not gui
		or not gui:IsA("LayerCollector")
	then
		return false
	end

	local lowered = string.lower(gui.Name)

	if lowered == "shakeui"
		or string.find(lowered, "shake", 1, true)
	then
		return true
	end

	return gui:FindFirstChild("safezone", true) ~= nil
end

local function registerShakeCandidate(object)
	if object and object:IsA("GuiButton") then
		shakeCandidates[object] = true
	end
end

local function attachShakeGui(shakeGui)
	if not isShakeGuiCandidate(shakeGui) then
		return
	end

	disconnectBucket(shakeConnections)
	table.clear(shakeCandidates)
	activeShakeGui = shakeGui

	for _, object in ipairs(shakeGui:GetDescendants()) do
		registerShakeCandidate(object)
	end

	shakeScanGeneration += 1
	local generation = shakeScanGeneration

	addConnection(
		shakeGui.DescendantAdded:Connect(function(object)
			registerShakeCandidate(object)

			if object:IsA("GuiButton") then
				task.defer(function()
					if activeShakeGui == shakeGui then
						considerShakeButton(object)
					end
				end)
			end
		end),
		shakeConnections
	)

	addConnection(
		shakeGui.DescendantRemoving:Connect(function(object)
			if object:IsA("GuiButton") then
				shakeCandidates[object] = nil
				shakeButtonStates[object] = nil
			end
		end),
		shakeConnections
	)

	addConnection(
		shakeGui.Destroying:Connect(function()
			if activeShakeGui == shakeGui then
				activeShakeGui = nil
				shakeScanGeneration += 1
				table.clear(shakeCandidates)
				disconnectBucket(shakeConnections)
			end
		end),
		shakeConnections
	)

	task.spawn(function()
		while not destroyed
			and Settings.AutoShake
			and activeShakeGui == shakeGui
			and shakeGui.Parent
			and generation == shakeScanGeneration
		do
			for button in pairs(shakeCandidates) do
				if button.Parent
					and button:IsDescendantOf(shakeGui)
				then
					considerShakeButton(button)
				else
					shakeCandidates[button] = nil
					shakeButtonStates[button] = nil
				end
			end

			task.wait(0.03)
		end
	end)
end

local function existingShakeGui()
	local exact = PlayerGui:FindFirstChild("shakeui")

	if isShakeGuiCandidate(exact) then
		return exact
	end

	for _, child in ipairs(PlayerGui:GetChildren()) do
		if isShakeGuiCandidate(child) then
			return child
		end
	end

	return nil
end

-- Reel -----------------------------------------------------------------------

-- One-time, GUI-only reel physics calibration and predictive hybrid control.
--
-- The player-bar model is measured from its visible motion while ordinary
-- control pulses are being sent. Once enough samples are collected, the model
-- is cached in _G and reused for all later catches during the client session.
--
-- No internal reel values, modules, remotes, or controller state are read.

local REEL_PHYSICS_KEY = "__FishingAutoFarmReelPhysicsV5"

local function validReelPhysics(value)
	return type(value) == "table"
		and value.Version == 5
		and value.Ready == true
		and type(value.HoldAcceleration) == "number"
		and type(value.ReleaseAcceleration) == "number"
		and type(value.RightBrake) == "number"
		and type(value.LeftBrake) == "number"
		and type(value.NeutralDuty) == "number"
		and value.HoldAcceleration > 0.05
		and value.ReleaseAcceleration < -0.05
		and value.RightBrake > 0.05
		and value.LeftBrake > 0.05
end

local reelPhysics = rawget(_G, REEL_PHYSICS_KEY)

if not validReelPhysics(reelPhysics) then
	reelPhysics = {
		Version = 5,
		Ready = false,

		-- Conservative normalized fallback values.
		-- Units are track-widths per second squared.
		HoldAcceleration = 4.50,
		ReleaseAcceleration = -4.50,
		RightBrake = 4.50,
		LeftBrake = 4.50,
		NeutralDuty = 0.50,

		HoldMaxSpeed = 1.40,
		ReleaseMaxSpeed = -1.40,
	}

	_G[REEL_PHYSICS_KEY] = reelPhysics
end

local calibrationSamples = {
	HoldAcceleration = {},
	ReleaseAcceleration = {},
	RightBrake = {},
	LeftBrake = {},
	HoldSpeed = {},
	ReleaseSpeed = {},

	HoldStableTime = 0,
	ReleaseStableTime = 0,
}

local reelTracker = {
	LastTime = nil,
	LastPlayerCenter = nil,
	LastFishCenter = nil,

	PlayerVelocity = 0,
	FishVelocity = 0,
	FishAcceleration = 0,

	OutputHeld = false,
	OutputChangedAt = 0,

	Duty = reelPhysics.NeutralDuty or 0.50,
	PulseAccumulator = 0,
	NextPulseAt = 0,

	State = "WAITING",
	LastStatusAt = 0,
}

local function clearArray(array)
	table.clear(array)
end

local function resetCalibrationSamples()
	clearArray(calibrationSamples.HoldAcceleration)
	clearArray(calibrationSamples.ReleaseAcceleration)
	clearArray(calibrationSamples.RightBrake)
	clearArray(calibrationSamples.LeftBrake)
	clearArray(calibrationSamples.HoldSpeed)
	clearArray(calibrationSamples.ReleaseSpeed)

	calibrationSamples.HoldStableTime = 0
	calibrationSamples.ReleaseStableTime = 0
end

local function resetReelTracker()
	reelTracker.LastTime = nil
	reelTracker.LastPlayerCenter = nil
	reelTracker.LastFishCenter = nil

	reelTracker.PlayerVelocity = 0
	reelTracker.FishVelocity = 0
	reelTracker.FishAcceleration = 0

	reelTracker.OutputHeld = false
	reelTracker.OutputChangedAt = 0

	reelTracker.Duty =
		reelPhysics.Ready
			and reelPhysics.NeutralDuty
			or 0.50

	reelTracker.PulseAccumulator = 0
	reelTracker.NextPulseAt = 0

	reelTracker.State = "WAITING"
	reelTracker.LastStatusAt = 0
end

local function pushSample(array, value, limit)
	if type(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge
	then
		return
	end

	table.insert(array, value)

	if #array > (limit or 96) then
		table.remove(array, 1)
	end
end

local function median(array)
	if #array == 0 then
		return nil
	end

	local copy = table.clone(array)
	table.sort(copy)

	local middle = math.floor(#copy / 2)

	if #copy % 2 == 1 then
		return copy[middle + 1]
	end

	return (copy[middle] + copy[middle + 1]) / 2
end

local function percentile(array, ratio)
	if #array == 0 then
		return nil
	end

	local copy = table.clone(array)
	table.sort(copy)

	local index = math.clamp(
		math.floor((#copy - 1) * ratio + 1.5),
		1,
		#copy
	)

	return copy[index]
end

local function calibrationProgress()
	if reelPhysics.Ready then
		return 1
	end

	local holdCount =
		math.min(#calibrationSamples.HoldAcceleration / 12, 1)

	local releaseCount =
		math.min(#calibrationSamples.ReleaseAcceleration / 12, 1)

	local holdTime =
		math.min(calibrationSamples.HoldStableTime / 0.35, 1)

	local releaseTime =
		math.min(calibrationSamples.ReleaseStableTime / 0.35, 1)

	return math.min(
		holdCount,
		releaseCount,
		holdTime,
		releaseTime
	)
end

local function finalizeReelCalibration()
	if reelPhysics.Ready then
		return true
	end

	if #calibrationSamples.HoldAcceleration < 12
		or #calibrationSamples.ReleaseAcceleration < 12
		or calibrationSamples.HoldStableTime < 0.35
		or calibrationSamples.ReleaseStableTime < 0.35
	then
		return false
	end

	local holdAcceleration =
		median(calibrationSamples.HoldAcceleration)

	local releaseAcceleration =
		median(calibrationSamples.ReleaseAcceleration)

	if not holdAcceleration
		or not releaseAcceleration
		or holdAcceleration <= 0.05
		or releaseAcceleration >= -0.05
	then
		return false
	end

	local rightBrake =
		median(calibrationSamples.RightBrake)
		or math.abs(releaseAcceleration)

	local leftBrake =
		median(calibrationSamples.LeftBrake)
		or math.abs(holdAcceleration)

	rightBrake = math.max(
		rightBrake,
		math.abs(releaseAcceleration) * 0.55,
		0.10
	)

	leftBrake = math.max(
		leftBrake,
		math.abs(holdAcceleration) * 0.55,
		0.10
	)

	local accelerationSpan =
		holdAcceleration - releaseAcceleration

	if accelerationSpan < 0.20 then
		return false
	end

	local neutralDuty =
		math.clamp(
			-releaseAcceleration / accelerationSpan,
			0.08,
			0.92
		)

	local holdMaxSpeed =
		percentile(calibrationSamples.HoldSpeed, 0.90)
		or reelPhysics.HoldMaxSpeed

	local releaseMaxSpeed =
		percentile(calibrationSamples.ReleaseSpeed, 0.10)
		or reelPhysics.ReleaseMaxSpeed

	reelPhysics.Version = 5
	reelPhysics.Ready = true
	reelPhysics.HoldAcceleration = holdAcceleration
	reelPhysics.ReleaseAcceleration = releaseAcceleration
	reelPhysics.RightBrake = rightBrake
	reelPhysics.LeftBrake = leftBrake
	reelPhysics.NeutralDuty = neutralDuty
	reelPhysics.HoldMaxSpeed = math.max(holdMaxSpeed, 0.15)
	reelPhysics.ReleaseMaxSpeed = math.min(releaseMaxSpeed, -0.15)
	reelPhysics.CalibratedAt = os.clock()

	_G[REEL_PHYSICS_KEY] = reelPhysics

	reelTracker.Duty = neutralDuty
	reelTracker.PulseAccumulator = 0

	warn(string.format(
		"[FishingAutoFarm] Reel physics calibrated: "
			.. "hold=%.3f release=%.3f rightBrake=%.3f "
			.. "leftBrake=%.3f neutralDuty=%.3f",
		holdAcceleration,
		releaseAcceleration,
		rightBrake,
		leftBrake,
		neutralDuty
	))

	setStatus("Reel physics calibrated")
	return true
end

local function updateReelCalibration(
	now,
	deltaTime,
	playerVelocity,
	playerAcceleration,
	playerLeft,
	playerRight
)
	if reelPhysics.Ready then
		return
	end

	if reelTracker.OutputChangedAt <= 0 then
		return
	end

	local actionAge =
		now - reelTracker.OutputChangedAt

	-- Ignore the immediate input-transition frames.
	if actionAge < 0.014 then
		return
	end

	-- Wall collisions corrupt acceleration measurements.
	local awayFromWalls =
		playerLeft > 0.018
		and playerRight < 0.982

	if not awayFromWalls then
		return
	end

	if math.abs(playerAcceleration) > 35
		or math.abs(playerVelocity) > 4
	then
		return
	end

	if reelTracker.OutputHeld then
		calibrationSamples.HoldStableTime += deltaTime

		if playerAcceleration > 0.05 then
			pushSample(
				calibrationSamples.HoldAcceleration,
				playerAcceleration
			)
		end

		if playerVelocity < -0.06
			and playerAcceleration > 0.05
		then
			pushSample(
				calibrationSamples.LeftBrake,
				playerAcceleration
			)
		end

		if playerVelocity > 0 then
			pushSample(
				calibrationSamples.HoldSpeed,
				playerVelocity
			)
		end
	else
		calibrationSamples.ReleaseStableTime += deltaTime

		if playerAcceleration < -0.05 then
			pushSample(
				calibrationSamples.ReleaseAcceleration,
				playerAcceleration
			)
		end

		if playerVelocity > 0.06
			and playerAcceleration < -0.05
		then
			pushSample(
				calibrationSamples.RightBrake,
				-playerAcceleration
			)
		end

		if playerVelocity < 0 then
			pushSample(
				calibrationSamples.ReleaseSpeed,
				playerVelocity
			)
		end
	end

	finalizeReelCalibration()
end

local function stopReel()
	if reelConnection then
		pcall(function()
			reelConnection:Disconnect()
		end)

		reelConnection = nil
	end

	Input.SetReelHeld(false)

	reelHeld = false
	reelMissingSince = nil
	lastReelSwitch = 0

	resetReelTracker()
end

local FIXED_REEL_PROFILE = {
	LookAhead = 0.078,
	FishVelocityResponse = 27,
	PlayerVelocityResponse = 24,
	FishAccelerationResponse = 9,

	PositionKp = 31,
	ApproachKd = 6.8,
	MatchKd = 9.2,
	CenterKd = 10.5,
	FishAccelerationFeed = 0.23,

	SafeMarginFactor = 0.17,
	ChaseDistanceFactor = 0.50,
	BrakeBuffer = 0.016,
	CenterVelocityTolerance = 0.090,

	DutyResponse = 32,

	CalibrationQuantum = 0.048,
	ChaseQuantum = 0.033,
	ApproachQuantum = 0.027,
	FineQuantum = 0.022,
	CenterQuantum = 0.025,
}

local function reelProfile()
	return FIXED_REEL_PROFILE
end

local function reelObjects(gui)
	if not gui or not gui.Parent then
		return nil
	end

	local bar = gui:FindFirstChild("bar")
	if not bar then
		return nil
	end

	local playerBar = bar:FindFirstChild("playerbar")
	local fish = bar:FindFirstChild("fish")

	if not (
		playerBar
		and fish
		and playerBar:IsA("GuiObject")
		and fish:IsA("GuiObject")
	) then
		return nil
	end

	local progressContainer = bar:FindFirstChild("progress")
	local progressFill =
		progressContainer
		and progressContainer:FindFirstChild("bar")

	return bar, playerBar, fish, progressFill
end

local function setReelOutput(held, now)
	if held ~= reelTracker.OutputHeld then
		reelTracker.OutputHeld = held
		reelTracker.OutputChangedAt = now
	end

	Input.SetReelHeld(held)
end

local function pulseQuantumForState(profile, state)
	if not reelPhysics.Ready then
		return profile.CalibrationQuantum
	elseif state == "CHASE" then
		return profile.ChaseQuantum
	elseif state == "APPROACH" then
		return profile.ApproachQuantum
	elseif state == "BRAKE"
		or state == "MATCH"
		or state == "RECOVER"
	then
		return profile.FineQuantum
	end

	return profile.CenterQuantum
end

local function updatePulseOutput(now, duty, quantum)
	if reelTracker.NextPulseAt <= 0 then
		reelTracker.NextPulseAt = now
	end

	if now < reelTracker.NextPulseAt then
		return
	end

	local steps = 0
	local output = reelTracker.OutputHeld

	while now >= reelTracker.NextPulseAt
		and steps < 4
	do
		reelTracker.PulseAccumulator += duty

		if reelTracker.PulseAccumulator >= 1 then
			reelTracker.PulseAccumulator -= 1
			output = true
		else
			output = false
		end

		reelTracker.NextPulseAt += quantum
		steps += 1
	end

	if reelTracker.NextPulseAt < now - quantum then
		reelTracker.NextPulseAt = now + quantum
	end

	setReelOutput(output, now)
end

local function safeCenterInterval(
	predictedFishLeft,
	predictedFishRight,
	playerWidth,
	marginFactor
)
	local playerHalf = playerWidth / 2
	local margin = math.clamp(
		playerWidth * marginFactor,
		0.004,
		playerWidth * 0.35
	)

	local usableHalf =
		math.max(
			playerHalf - margin,
			playerHalf * 0.28
		)

	local minimumCenter =
		predictedFishRight - usableHalf

	local maximumCenter =
		predictedFishLeft + usableHalf

	if minimumCenter > maximumCenter then
		local fishCenter =
			(predictedFishLeft + predictedFishRight) / 2

		minimumCenter = fishCenter
		maximumCenter = fishCenter
	end

	return minimumCenter, maximumCenter
end

local function intervalError(
	playerCenter,
	minimumCenter,
	maximumCenter
)
	if playerCenter < minimumCenter then
		return minimumCenter - playerCenter
	elseif playerCenter > maximumCenter then
		return maximumCenter - playerCenter
	end

	return 0
end

local function chooseReelState(
	errorValue,
	relativeVelocity,
	stoppingDistance,
	minimumCenter,
	maximumCenter,
	predictedPlayerCenter,
	playerWidth,
	profile,
	playerLeft,
	playerRight
)
	if playerLeft <= 0.006
		and relativeVelocity < -0.015
	then
		return "RECOVER", 1
	end

	if playerRight >= 0.994
		and relativeVelocity > 0.015
	then
		return "RECOVER", -1
	end

	local speed =
		math.abs(relativeVelocity)

	if errorValue == 0 then
		if speed <= profile.CenterVelocityTolerance then
			return "CENTER", 0
		end

		local distanceToEdge

		if relativeVelocity > 0 then
			distanceToEdge =
				math.max(
					maximumCenter - predictedPlayerCenter,
					0
				)
		else
			distanceToEdge =
				math.max(
					predictedPlayerCenter - minimumCenter,
					0
				)
		end

		if stoppingDistance + profile.BrakeBuffer
			>= distanceToEdge
		then
			return "BRAKE", 0
		end

		return "MATCH", 0
	end

	local movingToward =
		errorValue * relativeVelocity > 0

	if movingToward
		and math.abs(errorValue)
			<= stoppingDistance + profile.BrakeBuffer
	then
		return "BRAKE", 0
	end

	if math.abs(errorValue)
		>= playerWidth * profile.ChaseDistanceFactor
	then
		return "CHASE", 0
	end

	return "APPROACH", 0
end

local function desiredDutyForState(
	state,
	recoverDirection,
	errorValue,
	relativeVelocity,
	fishAcceleration,
	profile
)
	local holdAcceleration =
		reelPhysics.HoldAcceleration

	local releaseAcceleration =
		reelPhysics.ReleaseAcceleration

	local accelerationSpan =
		holdAcceleration - releaseAcceleration

	if accelerationSpan < 0.20 then
		holdAcceleration = 4.50
		releaseAcceleration = -4.50
		accelerationSpan = 9.00
	end

	local desiredAcceleration

	if state == "RECOVER" then
		desiredAcceleration =
			recoverDirection > 0
				and holdAcceleration
				or releaseAcceleration
	elseif state == "BRAKE" then
		if relativeVelocity > 0 then
			desiredAcceleration =
				-math.max(
					reelPhysics.RightBrake,
					math.abs(releaseAcceleration) * 0.65
				)
		elseif relativeVelocity < 0 then
			desiredAcceleration =
				math.max(
					reelPhysics.LeftBrake,
					math.abs(holdAcceleration) * 0.65
				)
		else
			desiredAcceleration =
				profile.PositionKp * errorValue
		end
	elseif state == "CENTER" then
		desiredAcceleration =
			fishAcceleration
				* profile.FishAccelerationFeed
			- profile.CenterKd
				* relativeVelocity
	elseif state == "MATCH" then
		desiredAcceleration =
			fishAcceleration
				* profile.FishAccelerationFeed
			+ profile.PositionKp
				* errorValue
				* 0.35
			- profile.MatchKd
				* relativeVelocity
	else
		desiredAcceleration =
			fishAcceleration
				* profile.FishAccelerationFeed
			+ profile.PositionKp
				* errorValue
			- profile.ApproachKd
				* relativeVelocity
	end

	desiredAcceleration =
		math.clamp(
			desiredAcceleration,
			releaseAcceleration * 1.15,
			holdAcceleration * 1.15
		)

	local duty =
		(desiredAcceleration - releaseAcceleration)
		/ accelerationSpan

	local neutral =
		math.clamp(
			reelPhysics.NeutralDuty,
			0.08,
			0.92
		)

	if state == "CHASE" then
		if errorValue > 0 then
			duty = math.max(duty, 0.76)
		else
			duty = math.min(duty, 0.24)
		end
	elseif state == "BRAKE" then
		if relativeVelocity > 0 then
			duty = math.min(duty, 0.10)
		elseif relativeVelocity < 0 then
			duty = math.max(duty, 0.90)
		end
	elseif state == "RECOVER" then
		duty =
			recoverDirection > 0
				and 0.94
				or 0.06
	elseif state == "MATCH" then
		duty = math.clamp(
			duty,
			neutral - 0.34,
			neutral + 0.34
		)
	elseif state == "CENTER" then
		duty = math.clamp(
			duty,
			neutral - 0.22,
			neutral + 0.22
		)
	end

	if not reelPhysics.Ready then
		-- Ensure both actions are observed during the one-time calibration.
		duty = math.clamp(duty, 0.15, 0.85)
	end

	return math.clamp(duty, 0.02, 0.98)
end

local function updateReelStatus(now, state)
	if now - reelTracker.LastStatusAt < 0.25 then
		return
	end

	reelTracker.LastStatusAt = now

	if not reelPhysics.Ready then
		local percent =
			math.floor(
				calibrationProgress() * 100 + 0.5
			)

		setStatus(
			"Calibrating reel physics "
				.. tostring(percent)
				.. "%"
		)
	else
		setStatus("Auto reel: " .. state)
	end
end

local function startReel(gui)
	stopReel()

	activeReelGui = gui
	resetReelTracker()

	reelConnection =
		RunService.RenderStepped:Connect(function(deltaTime)
			if destroyed
				or not Settings.AutoReel
				or activeReelGui ~= gui
				or not gui.Parent
			then
				stopReel()
				return
			end

			local bar, playerBar, fish, progressFill =
				reelObjects(gui)

			if not bar
				or not playerBar.Visible
				or not fish.Visible
				or bar.AbsoluteSize.X < 4
				or playerBar.AbsoluteSize.X < 2
				or fish.AbsoluteSize.X < 2
			then
				reelMissingSince =
					reelMissingSince or os.clock()

				Input.SetReelHeld(false)
				resetReelTracker()

				if os.clock() - reelMissingSince > 2 then
					setStatus("Waiting for reel objects")
				end

				return
			end

			reelMissingSince = nil

			if progressFill
				and progressFill:IsA("GuiObject")
				and progressFill.Parent
			then
				local progressWidth =
					progressFill.AbsoluteSize.X

				local parentWidth =
					progressFill.Parent.AbsoluteSize.X

				if parentWidth > 0
					and progressWidth / parentWidth
						>= 0.985
				then
					Input.SetReelHeld(false)
					setStatus("Reel progress complete")
					return
				end
			end

			local profile = reelProfile()
			local now = os.clock()

			local trackLeft =
				bar.AbsolutePosition.X

			local trackWidth =
				math.max(bar.AbsoluteSize.X, 1)

			local playerLeft =
				(
					playerBar.AbsolutePosition.X
						- trackLeft
				) / trackWidth

			local playerWidth =
				playerBar.AbsoluteSize.X
				/ trackWidth

			local playerRight =
				playerLeft + playerWidth

			local playerCenter =
				playerLeft + playerWidth / 2

			local fishLeft =
				(
					fish.AbsolutePosition.X
						- trackLeft
				) / trackWidth

			local fishWidth =
				fish.AbsoluteSize.X
				/ trackWidth

			local fishRight =
				fishLeft + fishWidth

			local fishCenter =
				fishLeft + fishWidth / 2

			if not reelTracker.LastTime then
				reelTracker.LastTime = now
				reelTracker.LastPlayerCenter =
					playerCenter
				reelTracker.LastFishCenter =
					fishCenter

				reelTracker.OutputHeld =
					fishCenter >= playerCenter

				reelTracker.OutputChangedAt = now
				reelTracker.NextPulseAt = now

				setReelOutput(
					reelTracker.OutputHeld,
					now
				)

				updateReelStatus(
					now,
					"INITIALIZING"
				)

				return
			end

			local sampleTime =
				math.clamp(
					now - reelTracker.LastTime,
					1 / 300,
					0.10
				)

			local rawPlayerVelocity =
				math.clamp(
					(
						playerCenter
							- reelTracker.LastPlayerCenter
					) / sampleTime,
					-5,
					5
				)

			local rawFishVelocity =
				math.clamp(
					(
						fishCenter
							- reelTracker.LastFishCenter
					) / sampleTime,
					-8,
					8
				)

			local previousPlayerVelocity =
				reelTracker.PlayerVelocity

			local previousFishVelocity =
				reelTracker.FishVelocity

			local playerVelocityAlpha =
				1 - math.exp(
					-profile.PlayerVelocityResponse
						* sampleTime
				)

			local fishVelocityAlpha =
				1 - math.exp(
					-profile.FishVelocityResponse
						* sampleTime
				)

			reelTracker.PlayerVelocity +=
				(
					rawPlayerVelocity
						- reelTracker.PlayerVelocity
				) * playerVelocityAlpha

			reelTracker.FishVelocity +=
				(
					rawFishVelocity
						- reelTracker.FishVelocity
				) * fishVelocityAlpha

			local playerAcceleration =
				math.clamp(
					(
						reelTracker.PlayerVelocity
							- previousPlayerVelocity
					) / sampleTime,
					-40,
					40
				)

			local rawFishAcceleration =
				math.clamp(
					(
						reelTracker.FishVelocity
							- previousFishVelocity
					) / sampleTime,
					-60,
					60
				)

			local fishAccelerationAlpha =
				1 - math.exp(
					-profile.FishAccelerationResponse
						* sampleTime
				)

			reelTracker.FishAcceleration +=
				(
					rawFishAcceleration
						- reelTracker.FishAcceleration
				) * fishAccelerationAlpha

			reelTracker.LastTime = now
			reelTracker.LastPlayerCenter =
				playerCenter
			reelTracker.LastFishCenter =
				fishCenter

			updateReelCalibration(
				now,
				sampleTime,
				reelTracker.PlayerVelocity,
				playerAcceleration,
				playerLeft,
				playerRight
			)

			local speedLookAhead =
				math.clamp(
					math.abs(
						reelTracker.FishVelocity
					) * 0.020,
					0,
					0.045
				)

			local lookAhead =
				profile.LookAhead
				+ speedLookAhead

			local predictedPlayerCenter =
				playerCenter
				+ reelTracker.PlayerVelocity
					* lookAhead

			local predictedFishLeft =
				fishLeft
				+ reelTracker.FishVelocity
					* lookAhead

			local predictedFishRight =
				fishRight
				+ reelTracker.FishVelocity
					* lookAhead

			local minimumCenter, maximumCenter =
				safeCenterInterval(
					predictedFishLeft,
					predictedFishRight,
					playerWidth,
					profile.SafeMarginFactor
				)

			local errorValue =
				intervalError(
					predictedPlayerCenter,
					minimumCenter,
					maximumCenter
				)

			local relativeVelocity =
				reelTracker.PlayerVelocity
				- reelTracker.FishVelocity

			local brakingAcceleration

			if relativeVelocity > 0 then
				brakingAcceleration =
					math.max(
						reelPhysics.RightBrake,
						0.10
					)
			else
				brakingAcceleration =
					math.max(
						reelPhysics.LeftBrake,
						0.10
					)
			end

			local stoppingDistance =
				(relativeVelocity * relativeVelocity)
				/ (2 * brakingAcceleration)

			local state, recoverDirection =
				chooseReelState(
					errorValue,
					relativeVelocity,
					stoppingDistance,
					minimumCenter,
					maximumCenter,
					predictedPlayerCenter,
					playerWidth,
					profile,
					playerLeft,
					playerRight
				)

			reelTracker.State = state

			local targetDuty =
				desiredDutyForState(
					state,
					recoverDirection,
					errorValue,
					relativeVelocity,
					reelTracker.FishAcceleration,
					profile
				)

			local dutyAlpha

			if state == "BRAKE"
				or state == "RECOVER"
			then
				dutyAlpha = 1
			else
				dutyAlpha =
					1 - math.exp(
						-profile.DutyResponse
							* sampleTime
					)
			end

			reelTracker.Duty +=
				(targetDuty - reelTracker.Duty)
				* dutyAlpha

			local quantum =
				pulseQuantumForState(
					profile,
					state
				)

			updatePulseOutput(
				now,
				reelTracker.Duty,
				quantum
			)

			updateReelStatus(now, state)
		end)

	setStatus(
		reelPhysics.Ready
			and "Predictive auto reel ready"
			or "Calibrating reel physics"
	)
end

local function attachReelGui(gui)
	if activeReelGui == gui then
		if Settings.AutoReel and not reelConnection then
			startReel(gui)
		end
		return
	end

	disconnectBucket(reelGuiConnections)
	activeReelGui = gui

	if Settings.AutoReel then
		task.defer(function()
			if not destroyed and activeReelGui == gui then
				startReel(gui)
			end
		end)
	end

	addConnection(gui.Destroying:Connect(function()
		if activeReelGui == gui then
			activeReelGui = nil
			stopReel()
			setStatus("Catch complete")
		end

		disconnectBucket(reelGuiConnections)
	end), reelGuiConnections)
end

local function existingReelGui()
	local gui = PlayerGui:FindFirstChild("reel")
	if gui and gui:IsA("LayerCollector") then
		return gui
	end
	return nil
end

-- Rod-state orchestration ----------------------------------------------------

local function cancelScheduledCast()
	castScheduleToken += 1
end

local function scheduleNextCast()
	if destroyed or not Settings.AutoCast then
		return
	end

	castScheduleToken += 1
	local token = castScheduleToken

	task.delay(0.35, function()
		if destroyed
			or not Settings.AutoCast
			or token ~= castScheduleToken
		then
			return
		end

		local state = rodState(activeRod)

		if state == State.Equipped
			and not rodHasBobber(activeRod)
		then
			clearCastSession()
			startCast()
		end
	end)
end

local function onStateChanged(value)
	local state = tonumber(value)
	if not state then
		return
	end

	if state == State.Unequipped then
		clearCastSession()
		stopReel()

		if Settings.AutoEquip then
			task.defer(tryEquip)
		end
	elseif state == State.Equipped then
		clearCastSession()

		if Settings.AutoCast then
			scheduleNextCast()
		end
	elseif state == State.Casting then
		-- Entering Casting means the charge meter has started.
		-- Keep holding and let the visual perfect-cast tracker decide
		-- the release moment.
		if castSession and not castSession.Released then
			setStatus("Charging cast — visual tracking")
		end
	elseif state == State.Luring then
		local shakeGui = activeShakeGui or existingShakeGui()
		if shakeGui and Settings.AutoShake then
			attachShakeGui(shakeGui)
		end
	elseif state == State.Reeling then
		clearCastSession()

		local reelGui = activeReelGui or existingReelGui()
		if reelGui and Settings.AutoReel then
			startReel(reelGui)
		end
	elseif state == State.CatchFinished then
		stopReel()
	end
end

local function setActiveRod(rod)
	if activeRod == rod then
		return
	end

	disconnectBucket(rodConnections)
	activeRod = rod
	activeStateValue = nil
	clearCastSession()

	if not rod then
		setStatus("Waiting for rod")
		return
	end

	local _, stateValue = rodState(rod)
	activeStateValue = stateValue
	setStatus("Rod: " .. rod.Name)

	if stateValue then
		addConnection(
			stateValue.Changed:Connect(onStateChanged),
			rodConnections
		)
		onStateChanged(stateValue.Value)
	end

	addConnection(rod.AncestryChanged:Connect(function()
		if destroyed then
			return
		end

		if Settings.AutoEquip then
			task.defer(tryEquip)
		end
	end), rodConnections)

	addConnection(rod.Destroying:Connect(function()
		if activeRod == rod then
			setActiveRod(nil)
		end
	end), rodConnections)

	if Settings.AutoEquip then
		task.defer(tryEquip)
	end
end

local function refreshRod()
	local rod = findRod()
	if rod ~= activeRod then
		setActiveRod(rod)
	end
end

local function watchRodContainer(container, bucket)
	if not container then
		return
	end

	addConnection(container.ChildAdded:Connect(function(child)
		if isRod(child) then
			setActiveRod(child)
		end
	end), bucket)

	addConnection(container.ChildRemoved:Connect(function(child)
		if child == activeRod then
			task.defer(refreshRod)
		end
	end), bucket)
end

-- RenLib UI ------------------------------------------------------------------

local function setAutoEquip(value)
	Settings.AutoEquip = value == true

	if Settings.AutoEquip then
		refreshRod()
		tryEquip()
	end
end

local function setAutoCast(value)
	Settings.AutoCast = value == true

	if Settings.AutoCast then
		refreshRod()
		scheduleNextCast()
	else
		cancelScheduledCast()
		clearCastSession()
	end
end

local function setAutoShake(value)
	Settings.AutoShake = value == true

	if Settings.AutoShake then
		local shakeGui = existingShakeGui()

		if shakeGui then
			attachShakeGui(shakeGui)
		else
			setStatus("Waiting for shake prompt")
		end
	else
		shakeScanGeneration += 1
		table.clear(shakeCandidates)
		disconnectBucket(shakeConnections)
		activeShakeGui = nil
	end
end

local function setAutoReel(value)
	Settings.AutoReel = value == true

	if Settings.AutoReel then
		local reelGui = existingReelGui()

		if reelGui then
			startReel(reelGui)
		else
			setStatus("Waiting for reel")
		end
	else
		stopReel()
	end
end

local function applyMaster(value)
	value = value == true
	Settings.FullAutoFarm = value

	if syncingMasterControls then
		return
	end

	syncingMasterControls = true

	for _, name in ipairs({
		"AutoEquip",
		"AutoCast",
		"AutoShake",
		"AutoReel",
	}) do
		local control = uiControls[name]

		if control
			and control.Get
			and control.Set
			and control:Get() ~= value
		then
			control:Set(value)
		end
	end

	syncingMasterControls = false

	if value then
		setStatus("Full AutoFarm enabled")
	else
		cancelScheduledCast()
		clearCastSession()
		stopReel()
		Input.ReleaseAll()
		setStatus("Full AutoFarm disabled")
	end
end

-- The supplied RenLib V7 source is embedded so the UI does not depend on an
-- external HTTP request or a separate runtime file.
RenLib = (function()
-- RenLib V7.0.0
-- Responsive Roblox UI framework with centralized navigation, non-destructive
-- search, mobile-first input, live theming, addons, and deterministic cleanup.

--// SERVICES
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")

--// LOCAL SHORTCUTS
local Plr = Players.LocalPlayer
local Mouse = Plr:GetMouse()
local Camera = workspace.CurrentCamera

--// DEVICE DETECTION
local function getViewport()
    Camera = workspace.CurrentCamera or Camera
    return Camera and Camera.ViewportSize or Vector2.new(800, 600)
end

local function getDeviceMode(scale)
    local viewport = getViewport()
    local normalizedScale = math.max(tonumber(scale) or 1, 0.01)
    -- Larger UI scales reduce usable physical space, so responsive mode is
    -- chosen from the canvas people can actually see rather than raw pixels.
    local scalePressure = normalizedScale < 1 and normalizedScale or (1 / normalizedScale)
    local effectiveWidth = viewport.X * scalePressure
    if effectiveWidth <= 620 then
        return "Phone"
    elseif effectiveWidth <= 960 or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
        return "Tablet"
    end
    return "Desktop"
end

local DeviceMode = getDeviceMode(1)
local IsMobile = DeviceMode ~= "Desktop"
local ScreenSize = getViewport()

--// CONSTANTS
local CONFIG_FOLDER = "RenLib/Configs"
local RUNTIME_KEY = "__RENLIB_V6_RUNTIME"
local INFINITE_YIELD_URL = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
local RenCore_LOADER_URL = "https://raw.githubusercontent.com/xsakyx/RobloxUILib/refs/heads/main/Loaders/RenCoreLoader"
local BRAND_ICON_MANIFEST_URL = "https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/Assets/Brand/icon.txt"
local RuntimeEnvironment = (getgenv and getgenv()) or shared or _G

-- Only one RenLib session may own input and UI at a time.
local PreviousSession = RuntimeEnvironment[RUNTIME_KEY]
if PreviousSession and type(PreviousSession.Unload) == "function" then
    pcall(function()
        PreviousSession:Unload("replaced")
    end)
end

--// EMOJI ICONS
local EMOJIS = {
    Logo = "</>",
    Settings = "⚙️",
    Search = "🔍",
    Close = "❌",
    Minimize = "➖",
    Arrow = "▼",
    Check = "✓",
    Star = "⭐",
    Play = "▶",
    Trash = "🗑️",
    Refresh = "🔄",
    Info = "ℹ️",
    Warning = "⚠️",
    Success = "✅",
    Error = "❌",
    Home = "🏠",
    Code = "</>",
    Terminal = "💻",
    User = "👤",
    Lock = "🔒",
    Unlock = "🔓"
}

-- Material icons hosted on Roblox. These keep core chrome crisp at every UI scale.
local ICONS = {
    Settings = "rbxassetid://6031280882",
    Search = "rbxassetid://6031154871",
    Close = "rbxassetid://6031094678",
    Minimize = "rbxassetid://6026568240",
    ChevronDown = "rbxassetid://6034818372",
    ChevronRight = "rbxassetid://6034818365",
    Home = "rbxassetid://9080449299",
    Profile = "rbxassetid://6022668898",
    Play = "rbxassetid://6026663699",
    Palette = "rbxassetid://6034316009",
    Restore = "rbxassetid://6031260800",
    Dashboard = "rbxassetid://6034287594",
    Layers = "rbxassetid://6034328955",
    Glass = "rbxassetid://6034925618",
    Check = "rbxassetid://6031094667",
    Menu = "rbxassetid://6031091002"
}

--// ROOT LIBRARY
local Library = {}
Library.Version = "7.0.0"
Library.Title = "RenLib"
Library.Connections = {}
Library.Tasks = {}
Library.Flags = {}
Library.Options = {}
Library.PendingAutoloadFlags = {}
Library.AutoloadConfigName = nil
Library.AutoloadThemeName = nil
Library.KnownConfigs = {}
Library.Unloaded = false
Library.Keybinds = {}
Library.KeybindDefaults = {}
Library.Addons = {}
Library.AddonOrder = {}
Library.ToggleKey = Enum.KeyCode.K
Library.IsMinimized = false
Library.IsMobile = IsMobile
Library.DeviceMode = DeviceMode
Library.DPIScale = 1
Library.ReducedMotion = false
Library.MotionScale = 1
Library.ActiveTweens = setmetatable({}, {__mode = "k"})
Library.LayoutTweens = setmetatable({}, {__mode = "k"})
Library.VisibilityTweens = setmetatable({}, {__mode = "k"})
Library.GradientRegistry = setmetatable({}, {__mode = "k"})
Library.ActiveTheme = "Celestial"
Library.ScalePreview = nil
Library.MaterialMode = "Solid"
Library.MaterialIntensity = 18
Library.MaterialRegistry = setmetatable({}, {__mode = "k"})
Library.MaterialDecorations = setmetatable({}, {__mode = "k"})
Library.BrandIcon = ICONS.Palette
-- Brand marks use semantic text contrast. A dark theme therefore receives a
-- bright mark while a light theme receives a dark mark, without hard-coded
-- per-theme exceptions.
Library.BrandIconTint = "Text"
Library.BrandMarks = setmetatable({}, {__mode = "k"})
Library.Icons = ICONS

-- Theme (can be changed at runtime)
Library.Theme = {
    Main = Color3.fromRGB(24, 26, 37),
    Secondary = Color3.fromRGB(29, 32, 44),
    Surface = Color3.fromRGB(36, 39, 53),
    SurfaceAlt = Color3.fromRGB(44, 47, 63),
    Stroke = Color3.fromRGB(82, 86, 111),
    Divider = Color3.fromRGB(57, 60, 79),
    Text = Color3.fromRGB(245, 245, 249),
    SubText = Color3.fromRGB(158, 160, 178),
    Hover = Color3.fromRGB(48, 51, 68),
    Click = Color3.fromRGB(55, 59, 77),
    Accent = Color3.fromRGB(157, 112, 255),
    Accent2 = Color3.fromRGB(91, 190, 255),
    Accent3 = Color3.fromRGB(255, 142, 216),
    Success = Color3.fromRGB(75, 215, 155),
    Warn = Color3.fromRGB(247, 190, 78),
    Error = Color3.fromRGB(247, 91, 121)
}

Library.ThemePresets = {
    Midnight = {
        Main = Color3.fromRGB(23, 26, 36), Secondary = Color3.fromRGB(29, 32, 44),
        Surface = Color3.fromRGB(36, 40, 53), SurfaceAlt = Color3.fromRGB(44, 48, 63),
        Stroke = Color3.fromRGB(82, 87, 108), Divider = Color3.fromRGB(58, 62, 79),
        Text = Color3.fromRGB(244, 245, 248), SubText = Color3.fromRGB(158, 160, 176),
        Hover = Color3.fromRGB(49, 53, 68), Click = Color3.fromRGB(57, 61, 78),
        Accent = Color3.fromRGB(96, 164, 255), Accent2 = Color3.fromRGB(120, 220, 226), Success = Color3.fromRGB(60, 220, 120),
        Warn = Color3.fromRGB(240, 200, 60), Error = Color3.fromRGB(240, 60, 60)
    },
    Nebula = {
        Main = Color3.fromRGB(29, 23, 43), Secondary = Color3.fromRGB(36, 29, 52),
        Surface = Color3.fromRGB(44, 35, 63), SurfaceAlt = Color3.fromRGB(53, 42, 75),
        Stroke = Color3.fromRGB(91, 75, 122), Divider = Color3.fromRGB(70, 59, 95),
        Text = Color3.fromRGB(246, 243, 255), SubText = Color3.fromRGB(174, 164, 199),
        Hover = Color3.fromRGB(58, 47, 80), Click = Color3.fromRGB(66, 53, 90),
        Accent = Color3.fromRGB(170, 106, 255), Accent2 = Color3.fromRGB(89, 189, 255), Success = Color3.fromRGB(76, 218, 157),
        Warn = Color3.fromRGB(255, 198, 88), Error = Color3.fromRGB(255, 94, 117)
    },
    Celestial = {
        Main = Color3.fromRGB(24, 26, 37), Secondary = Color3.fromRGB(29, 32, 44),
        Surface = Color3.fromRGB(36, 39, 53), SurfaceAlt = Color3.fromRGB(44, 47, 63),
        Stroke = Color3.fromRGB(82, 86, 111), Divider = Color3.fromRGB(57, 60, 79),
        Text = Color3.fromRGB(245, 245, 249), SubText = Color3.fromRGB(158, 160, 178),
        Hover = Color3.fromRGB(48, 51, 68), Click = Color3.fromRGB(55, 59, 77),
        Accent = Color3.fromRGB(157, 112, 255), Accent2 = Color3.fromRGB(91, 190, 255), Success = Color3.fromRGB(66, 224, 171),
        Warn = Color3.fromRGB(255, 205, 92), Error = Color3.fromRGB(255, 92, 120)
    },
    Rose = {
        Main = Color3.fromRGB(42, 27, 36), Secondary = Color3.fromRGB(50, 32, 43),
        Surface = Color3.fromRGB(61, 38, 52), SurfaceAlt = Color3.fromRGB(72, 44, 61),
        Stroke = Color3.fromRGB(111, 70, 91), Divider = Color3.fromRGB(86, 55, 73),
        Text = Color3.fromRGB(255, 241, 247), SubText = Color3.fromRGB(201, 157, 178),
        Hover = Color3.fromRGB(77, 48, 65), Click = Color3.fromRGB(86, 53, 73),
        Accent = Color3.fromRGB(255, 105, 180), Accent2 = Color3.fromRGB(177, 117, 255), Success = Color3.fromRGB(73, 219, 157),
        Warn = Color3.fromRGB(255, 198, 91), Error = Color3.fromRGB(255, 86, 107)
    },
    Aurora = {
        Main = Color3.fromRGB(18, 32, 38), Secondary = Color3.fromRGB(23, 40, 47),
        Surface = Color3.fromRGB(29, 49, 57), SurfaceAlt = Color3.fromRGB(36, 59, 67),
        Stroke = Color3.fromRGB(71, 110, 118), Divider = Color3.fromRGB(50, 81, 88),
        Text = Color3.fromRGB(238, 253, 252), SubText = Color3.fromRGB(147, 185, 185),
        Hover = Color3.fromRGB(41, 65, 73), Click = Color3.fromRGB(47, 74, 82),
        Accent = Color3.fromRGB(48, 226, 183), Accent2 = Color3.fromRGB(102, 149, 255), Success = Color3.fromRGB(64, 226, 158),
        Warn = Color3.fromRGB(255, 205, 94), Error = Color3.fromRGB(255, 92, 117)
    },
    Ember = {
        Main = Color3.fromRGB(42, 28, 23), Secondary = Color3.fromRGB(51, 34, 28),
        Surface = Color3.fromRGB(62, 41, 33), SurfaceAlt = Color3.fromRGB(74, 48, 38),
        Stroke = Color3.fromRGB(118, 79, 62), Divider = Color3.fromRGB(90, 59, 48),
        Text = Color3.fromRGB(255, 247, 239), SubText = Color3.fromRGB(201, 169, 146),
        Hover = Color3.fromRGB(80, 52, 41), Click = Color3.fromRGB(91, 59, 46),
        Accent = Color3.fromRGB(255, 132, 72), Accent2 = Color3.fromRGB(255, 83, 129), Accent3 = Color3.fromRGB(255, 202, 102), Success = Color3.fromRGB(87, 220, 153),
        Warn = Color3.fromRGB(255, 201, 87), Error = Color3.fromRGB(255, 83, 99)
    },
    ["Prism Frost"] = {
        Main = Color3.fromRGB(218, 228, 232), Secondary = Color3.fromRGB(230, 238, 241),
        Surface = Color3.fromRGB(242, 246, 248), SurfaceAlt = Color3.fromRGB(250, 252, 253),
        Stroke = Color3.fromRGB(123, 145, 155), Divider = Color3.fromRGB(168, 184, 191),
        Text = Color3.fromRGB(31, 39, 43), SubText = Color3.fromRGB(100, 111, 117),
        Hover = Color3.fromRGB(224, 234, 239), Click = Color3.fromRGB(211, 224, 230),
        Accent = Color3.fromRGB(168, 208, 255), Accent2 = Color3.fromRGB(255, 222, 166), Accent3 = Color3.fromRGB(186, 222, 255),
        Success = Color3.fromRGB(67, 171, 127), Warn = Color3.fromRGB(218, 150, 51), Error = Color3.fromRGB(211, 75, 102)
    },
    ["Moss Archive"] = {
        Main = Color3.fromRGB(31, 40, 42), Secondary = Color3.fromRGB(38, 48, 50),
        Surface = Color3.fromRGB(45, 56, 57), SurfaceAlt = Color3.fromRGB(52, 65, 64),
        Stroke = Color3.fromRGB(96, 111, 96), Divider = Color3.fromRGB(117, 119, 91),
        Text = Color3.fromRGB(236, 235, 222), SubText = Color3.fromRGB(190, 181, 151),
        Hover = Color3.fromRGB(52, 64, 63), Click = Color3.fromRGB(59, 72, 69),
        Accent = Color3.fromRGB(156, 186, 105), Accent2 = Color3.fromRGB(196, 207, 148), Accent3 = Color3.fromRGB(126, 160, 89),
        Success = Color3.fromRGB(113, 196, 128), Warn = Color3.fromRGB(223, 180, 88), Error = Color3.fromRGB(225, 104, 105)
    },
    ["Velvet Latte"] = {
        Main = Color3.fromRGB(27, 28, 45), Secondary = Color3.fromRGB(35, 36, 56),
        Surface = Color3.fromRGB(43, 44, 66), SurfaceAlt = Color3.fromRGB(52, 53, 78),
        Stroke = Color3.fromRGB(101, 105, 143), Divider = Color3.fromRGB(76, 80, 113),
        Text = Color3.fromRGB(232, 236, 255), SubText = Color3.fromRGB(175, 181, 215),
        Hover = Color3.fromRGB(51, 52, 77), Click = Color3.fromRGB(59, 60, 87),
        Accent = Color3.fromRGB(232, 164, 207), Accent2 = Color3.fromRGB(181, 148, 238), Accent3 = Color3.fromRGB(120, 174, 239),
        Success = Color3.fromRGB(120, 207, 157), Warn = Color3.fromRGB(238, 190, 104), Error = Color3.fromRGB(239, 117, 144)
    }
}

-- Registry for dynamic theming
Library.Registry = setmetatable({}, {__mode = "k"})
Library.Scales = {}

-- Global keybinds list
Library.KeybindManager = nil
Library.KeybindList = {}

--// MODULE: UTILITY (extended)
local Utility = {}

function Library:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function Utility:SafeCall(callback, ...)
    if type(callback) ~= "function" then return true end
    local args = table.pack(...)
    local ok, err = xpcall(function()
        callback(table.unpack(args, 1, args.n))
    end, debug.traceback)
    if not ok then
        warn("[RenLib] Callback error:\n" .. tostring(err))
        if Library.Notify and not Library.Unloaded then
            Library:Notify({Title = "Callback error", Content = tostring(err):match("^[^\n]+") or "Unknown error", Duration = 5})
        end
    end
    return ok, err
end

function Utility:RandomString(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    for i = 1, length do
        local rand = math.random(1, #chars)
        result = result .. chars:sub(rand, rand)
    end
    return result
end

function Utility:NormalizeAssetId(asset, fallback)
    if asset == nil or asset == "" then return fallback end
    local value = tostring(asset)
    if value:match("^%d+$") then
        if tonumber(value) <= 0 then return fallback end
        return "rbxassetid://" .. value
    end
    if value:match("^rbxassetid://%d+$") or value:match("^https?://") then
        return value
    end
    return fallback
end

local THEME_PROPERTY_KEYS = {
    BackgroundColor3 = {"Main", "Secondary", "Surface", "SurfaceAlt", "Hover", "Click", "Accent", "Accent2", "Accent3", "Success", "Warn", "Error", "Divider"},
    TextColor3 = {"Text", "SubText", "Accent", "Accent2", "Accent3", "Success", "Warn", "Error"},
    PlaceholderColor3 = {"SubText", "Text"},
    ImageColor3 = {"Text", "SubText", "Accent", "Accent2", "Accent3", "Success", "Warn", "Error"},
    ScrollBarImageColor3 = {"Accent", "Accent2", "SubText", "Text"},
    Color = {"Stroke", "Divider", "Accent", "Accent2", "Accent3", "Text", "SubText"}
}

local function resolveThemeKey(property, value)
    if typeof(value) ~= "Color3" then return nil end
    for _, key in ipairs(THEME_PROPERTY_KEYS[property] or {}) do
        if Library.Theme[key] == value then return key end
    end
    return nil
end

function Utility:Create(class, properties)
    local instance = Instance.new(class)
    if class == "UIStroke" and properties.Transparency == nil then
        instance.Transparency = 0.24
    end
    for k, v in pairs(properties) do
        if k ~= "Parent" then
            instance[k] = v
        end
    end
    -- Theme registration is automatic for semantic theme colors. Explicit
    -- RegisterProperty calls still override this, but missed labels can no
    -- longer keep a stale color after a preset change.
    for property, value in pairs(properties) do
        local colorKey = resolveThemeKey(property, value)
        if colorKey then
            Library.Registry[instance] = Library.Registry[instance] or {}
            Library.Registry[instance][property] = colorKey
        end
    end
    if properties.Parent then
        instance.Parent = properties.Parent
    end
    return instance
end

function Utility:LoadBrandIcon(callback)
    task.spawn(function()
        local resolved = Library.BrandIcon
        local tintKey = Library.BrandIconTint
        local ok, manifest = pcall(function()
            return game:HttpGet(BRAND_ICON_MANIFEST_URL)
        end)
        if ok and type(manifest) == "string" then
            local assetLine = manifest:match("^%s*([^\r\n]+)")
            local requestedTint = manifest:match("[\r\n]+%s*[Tt][Ii][Nn][Tt]%s*=%s*([%w_]+)")
            resolved = Utility:NormalizeAssetId(assetLine, resolved)
            tintKey = requestedTint and Library.Theme[requestedTint] and requestedTint or nil
        end
        Library.BrandIcon = resolved
        Library.BrandIconTint = tintKey
        for mark in pairs(Library.BrandMarks) do
            if mark and mark.Parent then
                mark.Image = resolved
                if tintKey then
                    Utility:RegisterProperty(mark, "ImageColor3", tintKey)
                else
                    if Library.Registry[mark] then Library.Registry[mark].ImageColor3 = nil end
                    mark.ImageColor3 = Color3.new(1, 1, 1)
                end
            end
        end
        if callback then Utility:SafeCall(callback, resolved) end
    end)
end

function Utility:Tween(instance, info, properties, callback)
    if not instance or not instance.Parent then return nil end
    local previous = Library.ActiveTweens[instance]
    if previous then
        pcall(function() previous:Cancel() end)
        Library.ActiveTweens[instance] = nil
    end

    local duration = Library.ReducedMotion and 0 or math.max(0, info.Time * Library.MotionScale)
    if duration == 0 then
        for property, value in pairs(properties) do
            instance[property] = value
        end
        if callback then task.defer(callback) end
        return nil
    end

    local tweenInfo = TweenInfo.new(duration, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    Library.ActiveTweens[instance] = tween
    tween:Play()
    Library:Connect(tween.Completed, function(playbackState)
        if Library.ActiveTweens[instance] == tween then
            Library.ActiveTweens[instance] = nil
        end
        if callback and playbackState == Enum.PlaybackState.Completed then callback() end
    end)
    return tween
end

function Utility:StopTween(instance)
    local tween = instance and Library.ActiveTweens[instance]
    if not tween then return false end
    Library.ActiveTweens[instance] = nil
    pcall(function() tween:Cancel() end)
    return true
end

-- Geometry and visual-state animations must not cancel one another. A hover
-- color tween used to stop an in-flight sidebar resize tween, leaving active
-- tabs and profile cards permanently stuck in their compact geometry.
function Utility:TweenLayout(instance, info, properties, callback)
    if not instance or not instance.Parent then return nil end
    local previous = Library.LayoutTweens[instance]
    if previous then
        pcall(function() previous:Cancel() end)
        Library.LayoutTweens[instance] = nil
    end

    local duration = Library.ReducedMotion and 0 or math.max(0, info.Time * Library.MotionScale)
    if duration == 0 then
        for property, value in pairs(properties) do instance[property] = value end
        if callback then task.defer(callback) end
        return nil
    end

    local tweenInfo = TweenInfo.new(duration, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    Library.LayoutTweens[instance] = tween
    tween:Play()
    Library:Connect(tween.Completed, function(playbackState)
        if Library.LayoutTweens[instance] == tween then Library.LayoutTweens[instance] = nil end
        if callback and playbackState == Enum.PlaybackState.Completed then callback() end
    end)
    return tween
end

function Utility:StopLayoutTween(instance)
    local tween = instance and Library.LayoutTweens[instance]
    if not tween then return false end
    Library.LayoutTweens[instance] = nil
    pcall(function() tween:Cancel() end)
    return true
end

function Utility:TweenVisibility(instance, info, properties, callback)
    if not instance or not instance.Parent then return nil end
    local previous = Library.VisibilityTweens[instance]
    if previous then
        pcall(function() previous:Cancel() end)
        Library.VisibilityTweens[instance] = nil
    end
    local duration = Library.ReducedMotion and 0 or math.max(0, info.Time * Library.MotionScale)
    if duration == 0 then
        for property, value in pairs(properties) do instance[property] = value end
        if callback then task.defer(callback) end
        return nil
    end
    local tweenInfo = TweenInfo.new(duration, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    Library.VisibilityTweens[instance] = tween
    tween:Play()
    Library:Connect(tween.Completed, function(playbackState)
        if Library.VisibilityTweens[instance] == tween then Library.VisibilityTweens[instance] = nil end
        if callback and playbackState == Enum.PlaybackState.Completed then callback() end
    end)
    return tween
end

function Utility:StopVisibilityTween(instance)
    local tween = instance and Library.VisibilityTweens[instance]
    if not tween then return false end
    Library.VisibilityTweens[instance] = nil
    pcall(function() tween:Cancel() end)
    return true
end

function Utility:MakeDraggable(topbar, object)
    local dragging, dragInput, dragStart, startPos
    local dragState = {Moved = false}

    function dragState:ConsumeDrag()
        local moved = self.Moved
        self.Moved = false
        return moved
    end

    local function keepRecoverable()
        if not object or not object.Parent then return end
        local viewport = getViewport()
        local position = object.AbsolutePosition
        local size = object.AbsoluteSize
        local minimumVisible = math.min(52, math.max(28, viewport.X * 0.12))
        local deltaX, deltaY = 0, 0
        if position.X + size.X < minimumVisible then
            deltaX = minimumVisible - (position.X + size.X)
        elseif position.X > viewport.X - minimumVisible then
            deltaX = (viewport.X - minimumVisible) - position.X
        end
        if position.Y + 40 < 0 then
            deltaY = -(position.Y + 40)
        elseif position.Y > viewport.Y - minimumVisible then
            deltaY = (viewport.Y - minimumVisible) - position.Y
        end
        if deltaX ~= 0 or deltaY ~= 0 then
            local scale = math.max(0.01, Library.DPIScale)
            object.Position = UDim2.new(
                object.Position.X.Scale,
                object.Position.X.Offset + deltaX / scale,
                object.Position.Y.Scale,
                object.Position.Y.Offset + deltaY / scale
            )
        end
    end

    Library:Connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragState.Moved = false
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos = object.Position
            dragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil

            Library:Connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    task.defer(keepRecoverable)
                end
            end)
        end
    end)

    Library:Connect(topbar.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    Library:Connect(UserInputService.InputChanged, function(input)
        local isPointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
        if dragging and isPointerMove then
            local pointer = Vector2.new(input.Position.X, input.Position.Y)
            local delta = (pointer - dragStart) / math.max(0.01, Library.DPIScale)
            if delta.Magnitude >= 4 then dragState.Moved = true end
            object.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    return dragState
end

function Utility:GetColor(colorKey)
    if type(colorKey) == "string" then
        return Library.Theme[colorKey] or Color3.new(1,1,1)
    end
    return colorKey
end

function Utility:RegisterProperty(instance, property, colorKey)
    if not Library.Registry[instance] then
        Library.Registry[instance] = {}
    end
    Library.Registry[instance][property] = colorKey
    instance[property] = Utility:GetColor(colorKey)
end

local function buildGradient(keys)
    local points = {}
    local count = math.max(#keys, 2)
    for index, key in ipairs(keys) do
        table.insert(points, ColorSequenceKeypoint.new((index - 1) / (count - 1), Utility:GetColor(key)))
    end
    if #points == 1 then
        table.insert(points, ColorSequenceKeypoint.new(1, points[1].Value))
    end
    return ColorSequence.new(points)
end

function Utility:RegisterGradient(instance, ...)
    local keys = {...}
    Library.GradientRegistry[instance] = keys
    instance.Color = buildGradient(keys)
end

function Utility:RegisterMaterial(instance, frostedTransparency, solidTransparency, property)
    property = property or "BackgroundTransparency"
    Library.MaterialRegistry[instance] = {
        Frosted = math.clamp(tonumber(frostedTransparency) or 0.18, 0, 1),
        Solid = math.clamp(tonumber(solidTransparency) or instance[property] or 0, 0, 1),
        Property = property
    }
    local state = Library.MaterialRegistry[instance]
    instance[property] = Library:ResolveMaterialTransparency(state)
end

--// DYNAMIC THEME UPDATE
function Library:UpdateColors()
    for instance, props in pairs(self.Registry) do
        for prop, colorKey in pairs(props) do
            pcall(function()
                instance[prop] = Utility:GetColor(colorKey)
            end)
        end
    end
    for gradient, keys in pairs(self.GradientRegistry) do
        pcall(function()
            gradient.Color = buildGradient(keys)
        end)
    end
end

function Library:SetTheme(newTheme)
    local nextAccent = newTheme.Accent or self.Theme.Accent
    local nextAccent2 = newTheme.Accent2 or nextAccent
    newTheme.Accent3 = newTheme.Accent3 or nextAccent2
    for k, v in pairs(newTheme) do
        self.Theme[k] = v
    end
    self:UpdateColors()
    self:SetMaterialIntensity(self.MaterialIntensity)
    if self.Window and self.Window.RefreshThemeState then self.Window:RefreshThemeState() end
end

function Library:ApplyThemePreset(name)
    if name == "Starlight" then name = "Celestial" end -- V6.2 compatibility alias
    local preset = self.ThemePresets[name]
    if not preset then
        return false, "Unknown theme preset: " .. tostring(name)
    end
    self:SetTheme(preset)
    self.ActiveTheme = name
    return true
end

function Library:SetReducedMotion(enabled)
    self.ReducedMotion = enabled == true
end

function Library:SetMotionScale(scale)
    self.MotionScale = math.clamp(tonumber(scale) or 1, 0, 2)
end

function Library:GetThemeLuminance()
    local color = self.Theme.Main
    return color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
end

function Library:ResolveMaterialTransparency(state)
    if not state then return 0 end
    if self.MaterialMode ~= "Frosted" then return state.Solid end
    local transparencyBoost = (self.MaterialIntensity / 32) * 0.24
    if self:GetThemeLuminance() < 0.35 then transparencyBoost = transparencyBoost + 0.08 end
    return math.clamp(state.Frosted + transparencyBoost, 0, 0.84)
end

function Library:SetMaterialIntensity(value)
    self.MaterialIntensity = math.clamp(tonumber(value) or 18, 0, 32)
    if self.MaterialMode == "Frosted" then
        for instance, state in pairs(self.MaterialRegistry) do
            pcall(function()
                instance[state.Property or "BackgroundTransparency"] = self:ResolveMaterialTransparency(state)
            end)
        end
    end
    return self.MaterialIntensity
end

function Library:RefreshMaterialVisibility()
    local visible = self.MaterialMode == "Frosted" and not self.Unloaded and not self.IsMinimized
    for decoration in pairs(self.MaterialDecorations) do
        pcall(function() decoration.Visible = visible end)
    end
end

function Library:SetMaterialMode(mode)
    mode = tostring(mode or "Solid")
    if mode ~= "Solid" and mode ~= "Frosted" then
        return false, "Unknown material mode: " .. mode
    end
    self.MaterialMode = mode
    for instance, state in pairs(self.MaterialRegistry) do
        pcall(function()
            local property = state.Property or "BackgroundTransparency"
            Utility:Tween(instance, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                [property] = self:ResolveMaterialTransparency(state)
            })
        end)
    end
    self:RefreshMaterialVisibility()
    return true
end

--// DPI SCALING
function Library:SetDPIScale(percent)
    percent = math.clamp(tonumber(percent) or 100, 100, 150)
    local scale = percent / 100
    for _, uiScale in ipairs(self.Scales) do
        uiScale.Scale = scale
    end
    self.DPIScale = scale
    if self.Window and self.Window.ApplyResponsiveLayout then
        task.defer(function()
            RunService.RenderStepped:Wait()
            if self.Window and not self.Unloaded then
                self.Window:ApplyResponsiveLayout(true)
                task.defer(function()
                    if self.Window and not self.Unloaded then self.Window:ApplyResponsiveLayout(false) end
                end)
            end
        end)
    end
    return percent
end

function Library:KeepDPIScale(token)
    local preview = self.ScalePreview
    if not preview or (token and preview.Token ~= token) then return false end
    preview.Kept = true
    self.ScalePreview = nil
    return true
end

function Library:RevertDPIScale(token)
    local preview = self.ScalePreview
    if not preview or (token and preview.Token ~= token) then return false end
    self.ScalePreview = nil
    self:SetDPIScale(preview.OriginalPercent)
    self.Flags.__RenLibScale = preview.OriginalPercent
    local scaleOption = self.Options.__RenLibScale
    if scaleOption and scaleOption.SetSilent then scaleOption:SetSilent(preview.OriginalPercent) end
    return true
end

function Library:PreviewDPIScale(percent, timeout)
    timeout = math.clamp(tonumber(timeout) or 10, 5, 30)
    local activePreview = self.ScalePreview
    local originalPercent = activePreview and activePreview.OriginalPercent or math.floor(self.DPIScale * 100 + 0.5)
    local token = Utility:RandomString(12)
    local candidate = self:SetDPIScale(percent)
    self.Flags.__RenLibScale = candidate
    self.ScalePreview = {
        Token = token,
        OriginalPercent = originalPercent,
        CandidatePercent = candidate,
        Kept = false
    }

    if self.Notify then
        self:Notify({
            Title = "Keep this UI size?",
            Content = tostring(candidate) .. "% preview. It will reset in " .. tostring(timeout) .. " seconds unless you keep it.",
            Duration = timeout,
            Actions = {
                {Name = "Keep", Callback = function()
                    if self:KeepDPIScale(token) and self.Notify then
                        self:Notify({Title = "UI size kept", Content = tostring(candidate) .. "%", Duration = 2})
                    end
                end},
                {Name = "Revert", Callback = function()
                    if self:RevertDPIScale(token) and self.Notify then
                        self:Notify({Title = "UI size restored", Content = tostring(originalPercent) .. "%", Duration = 2})
                    end
                end}
            }
        })
    end

    task.delay(timeout, function()
        local preview = self.ScalePreview
        if preview and preview.Token == token and not preview.Kept then
            self:RevertDPIScale(token)
            if self.Notify and not self.Unloaded then
                self:Notify({Title = "UI size restored", Content = "The preview timed out safely.", Duration = 3})
            end
        end
    end)
    return token
end

local function hasFileSystem()
    return type(isfolder) == "function" and type(makefolder) == "function"
        and type(isfile) == "function" and type(readfile) == "function"
        and type(writefile) == "function"
end

local function ensureConfigFolders()
    if not hasFileSystem() then return false end
    if not isfolder("RenLib") then makefolder("RenLib") end
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    return true
end

local function cleanConfigName(name)
    local cleaned = tostring(name or "default"):gsub("[^%w_%-%s]", ""):sub(1, 64)
    cleaned = cleaned:match("^%s*(.-)%s*$") or ""
    return cleaned ~= "" and cleaned or "default"
end

local CONFIG_MANAGER_FLAGS = {
    __RenLibConfigSelection = true,
    __RenLibConfigName = true,
    __RenLibConfigRename = true
}

local function encodeValue(value)
    if typeof(value) == "Color3" then
        return {__type = "Color3", r = value.R, g = value.G, b = value.B}
    elseif type(value) == "table" then
        local encoded = {}
        for key, item in pairs(value) do encoded[key] = encodeValue(item) end
        return encoded
    end
    return value
end

local function decodeValue(value)
    if type(value) == "table" and value.__type == "Color3" then
        return Color3.new(value.r or 1, value.g or 1, value.b or 1)
    elseif type(value) == "table" then
        local decoded = {}
        for key, item in pairs(value) do decoded[key] = decodeValue(item) end
        return decoded
    end
    return value
end

function Library:SaveConfig(name)
    if not ensureConfigFolders() then return false, "Filesystem APIs are unavailable" end
    local payload = {version = self.Version, flags = {}}
    for flag, value in pairs(self.Flags) do
        if not CONFIG_MANAGER_FLAGS[flag] then payload.flags[flag] = encodeValue(value) end
    end
    local cleaned = cleanConfigName(name)
    local ok, result = pcall(function()
        writefile(CONFIG_FOLDER .. "/" .. cleaned .. ".json", HttpService:JSONEncode(payload))
    end)
    if ok then self.KnownConfigs[cleaned] = true end
    return ok, ok and nil or result
end

function Library:GetConfigList()
    if not ensureConfigFolders() then return {} end
    local names, seen = {}, {}
    for name in pairs(self.KnownConfigs) do
        seen[name:lower()] = true
        table.insert(names, name)
    end
    if type(listfiles) == "function" then
        local ok, files = pcall(listfiles, CONFIG_FOLDER)
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local normalized = tostring(path):gsub("\\", "/")
                local name = normalized:match("/([^/]+)%.json$") or normalized:match("^([^/]+)%.json$")
                if name and not seen[name:lower()] then
                    seen[name:lower()] = true
                    table.insert(names, name)
                end
            end
        end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function Library:LoadConfig(name)
    if not ensureConfigFolders() then return false, "Filesystem APIs are unavailable" end
    local path = CONFIG_FOLDER .. "/" .. cleanConfigName(name) .. ".json"
    if not isfile(path) then return false, "Config does not exist" end
    local ok, payload = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(payload) ~= "table" then return false, payload end
    self.KnownConfigs[cleanConfigName(name)] = true
    for flag, rawValue in pairs(payload.flags or {}) do
        local value = decodeValue(rawValue)
        self.Flags[flag] = value
        local option = self.Options[flag]
        if option and option.Set then Utility:SafeCall(function() option:Set(value) end) end
    end
    return true
end

function Library:DeleteConfig(name)
    if not ensureConfigFolders() or type(delfile) ~= "function" then return false, "Delete API is unavailable" end
    local cleaned = cleanConfigName(name)
    local path = CONFIG_FOLDER .. "/" .. cleaned .. ".json"
    local ok, err = pcall(function() if isfile(path) then delfile(path) end end)
    if not ok then return false, err end
    self.KnownConfigs[cleaned] = nil
    if self:GetAutoloadConfigName() == cleaned then
        local cleared, clearError = self:ClearAutoloadConfig()
        if not cleared then return false, "Config deleted, but autoload cleanup failed: " .. tostring(clearError) end
    end
    return true
end

function Library:RenameConfig(oldName, newName)
    if not ensureConfigFolders() or type(delfile) ~= "function" then return false, "Rename APIs are unavailable" end
    local oldClean, newClean = cleanConfigName(oldName), cleanConfigName(newName)
    local oldPath = CONFIG_FOLDER .. "/" .. oldClean .. ".json"
    local newPath = CONFIG_FOLDER .. "/" .. newClean .. ".json"
    if not isfile(oldPath) then return false, "Config does not exist" end
    if oldClean ~= newClean and isfile(newPath) then return false, "A config already uses that name" end
    if oldClean == newClean then return true end
    local ok, err = pcall(function()
        writefile(newPath, readfile(oldPath))
        delfile(oldPath)
    end)
    if not ok then return false, err end
    self.KnownConfigs[oldClean] = nil
    self.KnownConfigs[newClean] = true
    if self:GetAutoloadConfigName() == oldClean then
        local updated, updateError = self:SetAutoloadConfig(newClean)
        if not updated then return false, "Config renamed, but autoload update failed: " .. tostring(updateError) end
    end
    return true
end

function Library:GetAutoloadConfigName()
    if not ensureConfigFolders() or not isfile("RenLib/autoload.txt") then return nil end
    local ok, name = pcall(readfile, "RenLib/autoload.txt")
    if not ok then return nil end
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if not name or name == "" then return nil end
    return cleanConfigName(name)
end

function Library:SetAutoloadConfig(name)
    if not ensureConfigFolders() then return false, "Filesystem APIs are unavailable" end
    local cleaned = cleanConfigName(name)
    if not isfile(CONFIG_FOLDER .. "/" .. cleaned .. ".json") then return false, "Config does not exist" end
    local ok, err = pcall(writefile, "RenLib/autoload.txt", cleaned)
    if ok then self.AutoloadConfigName = cleaned end
    return ok, ok and nil or err
end

function Library:ClearAutoloadConfig()
    if not ensureConfigFolders() then return false, "Filesystem APIs are unavailable" end
    local ok, err = pcall(function()
        if isfile("RenLib/autoload.txt") then
            if type(delfile) == "function" then delfile("RenLib/autoload.txt") else writefile("RenLib/autoload.txt", "") end
        end
    end)
    if ok then
        self.AutoloadConfigName = nil
        self.AutoloadThemeName = nil
    end
    return ok, ok and nil or err
end

function Library:PrepareAutoloadConfig()
    self.AutoloadThemeName = nil
    local name = self:GetAutoloadConfigName()
    if not name then return false, "No autoload config" end
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if not isfile(path) then
        self:ClearAutoloadConfig()
        return false, "Autoload config no longer exists"
    end
    local ok, payload = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(payload) ~= "table" then return false, payload end
    self.AutoloadConfigName = name
    self.KnownConfigs[name] = true
    self.PendingAutoloadFlags = {}
    for flag, rawValue in pairs(payload.flags or {}) do
        local value = decodeValue(rawValue)
        self.PendingAutoloadFlags[flag] = value
        self.Flags[flag] = value
    end
    local preset = self.PendingAutoloadFlags.__RenLibTheme
    if type(preset) == "string" and self.ThemePresets[preset] then
        self.AutoloadThemeName = preset
        self:ApplyThemePreset(preset)
    end
    local material = self.PendingAutoloadFlags.__RenLibMaterial
    if material == "Solid" or material == "Frosted" then self:SetMaterialMode(material) end
    if self.PendingAutoloadFlags.__RenLibFrostIntensity ~= nil then
        self:SetMaterialIntensity(self.PendingAutoloadFlags.__RenLibFrostIntensity)
    end
    if self.PendingAutoloadFlags.__RenLibReducedMotion ~= nil then
        self:SetReducedMotion(self.PendingAutoloadFlags.__RenLibReducedMotion)
    end
    if self.PendingAutoloadFlags.__RenLibScale ~= nil then
        self:SetDPIScale(self.PendingAutoloadFlags.__RenLibScale)
    end
    -- Core appearance values are already applied before the window exists;
    -- their controls will read Library.Flags without replaying preview dialogs.
    self.PendingAutoloadFlags.__RenLibTheme = nil
    self.PendingAutoloadFlags.__RenLibMaterial = nil
    self.PendingAutoloadFlags.__RenLibFrostIntensity = nil
    self.PendingAutoloadFlags.__RenLibReducedMotion = nil
    self.PendingAutoloadFlags.__RenLibScale = nil
    return true
end

function Library:RegisterOption(flag, controller)
    self.Options[flag] = controller
    if self.PendingAutoloadFlags[flag] ~= nil and controller and controller.Set then
        local value = self.PendingAutoloadFlags[flag]
        self.PendingAutoloadFlags[flag] = nil
        task.defer(function()
            if not self.Unloaded and self.Options[flag] == controller then
                Utility:SafeCall(function() controller:Set(value) end)
            end
        end)
    end
    return controller
end

function Library:RegisterIcon(name, asset)
    name = tostring(name or "")
    assert(name ~= "", "[RenLib] RegisterIcon requires a name")
    local normalized = Utility:NormalizeAssetId(asset)
    assert(normalized, "[RenLib] RegisterIcon requires a Roblox image asset")
    self.Icons[name] = normalized
    return normalized
end

function Library:GetIcon(name, fallback)
    if name == nil then return Utility:NormalizeAssetId(fallback) end
    return self.Icons[tostring(name)] or Utility:NormalizeAssetId(name, fallback)
end

function Library:RegisterAddon(name, addon)
    name = tostring(name or "")
    assert(name ~= "", "[RenLib] RegisterAddon requires a name")
    assert(type(addon) == "table", "[RenLib] RegisterAddon requires an addon table")
    if self.Addons[name] then self:DisableAddon(name) end
    local record = {Name = name, Module = addon, Enabled = false}
    self.Addons[name] = record
    table.insert(self.AddonOrder, name)
    if type(addon.Init) == "function" then
        local ok = Utility:SafeCall(addon.Init, addon, self)
        if not ok then
            self.Addons[name] = nil
            return nil
        end
    end
    if addon.AutoStart ~= false then self:EnableAddon(name) end
    return record
end

function Library:GetAddon(name)
    local record = self.Addons[tostring(name or "")]
    return record and record.Module or nil
end

function Library:EnableAddon(name)
    local record = self.Addons[tostring(name or "")]
    if not record or record.Enabled then return record ~= nil end
    record.Enabled = true
    if type(record.Module.Start) == "function" then
        local ok = Utility:SafeCall(record.Module.Start, record.Module, self)
        if not ok then record.Enabled = false end
    end
    return record.Enabled
end

function Library:DisableAddon(name)
    local record = self.Addons[tostring(name or "")]
    if not record or not record.Enabled then return record ~= nil end
    record.Enabled = false
    if type(record.Module.Stop) == "function" then
        Utility:SafeCall(record.Module.Stop, record.Module, self)
    end
    return true
end

function Library:UnregisterAddon(name)
    name = tostring(name or "")
    local record = self.Addons[name]
    if not record then return false end
    self:DisableAddon(name)
    if type(record.Module.Unload) == "function" then
        Utility:SafeCall(record.Module.Unload, record.Module, self)
    end
    self.Addons[name] = nil
    for index, registeredName in ipairs(self.AddonOrder) do
        if registeredName == name then table.remove(self.AddonOrder, index) break end
    end
    return true
end

function Library:LoadAutoloadConfig()
    local name = self:GetAutoloadConfigName()
    if not name then return false, "No autoload config" end
    return self:LoadConfig(name)
end

function Library:LaunchInfiniteYield()
    if type(loadstring) ~= "function" then
        if self.Notify then self:Notify({Title = "Infinite Yield unavailable", Content = "This environment does not expose loadstring.", Duration = 4}) end
        return false, "loadstring is unavailable"
    end

    local ok, source = pcall(function()
        return game:HttpGet(INFINITE_YIELD_URL)
    end)
    if not ok or type(source) ~= "string" or source == "" then
        if self.Notify then self:Notify({Title = "Infinite Yield failed", Content = tostring(source), Duration = 5}) end
        return false, source
    end

    local chunk, compileError = loadstring(source)
    if not chunk then
        if self.Notify then self:Notify({Title = "Infinite Yield failed", Content = tostring(compileError), Duration = 5}) end
        return false, compileError
    end

    task.spawn(function()
        local ran, runtimeError = pcall(chunk)
        if not ran and self.Notify and not self.Unloaded then
            self:Notify({Title = "Infinite Yield error", Content = tostring(runtimeError), Duration = 5})
        end
    end)
    if self.Notify then self:Notify({Title = "Infinite Yield launched", Content = "Loaded from the official EdgeIY source.", Duration = 3}) end
    return true
end

function Library:RelaunchRenCore(beforeRelaunch)
    if type(loadstring) ~= "function" then
        if self.Notify then self:Notify({Title = "RenCore unavailable", Content = "This environment does not expose loadstring.", Duration = 4}) end
        return false, "loadstring is unavailable"
    end
    local ok, source = pcall(function() return game:HttpGet(RenCore_LOADER_URL) end)
    if not ok or type(source) ~= "string" or source == "" then
        if self.Notify then self:Notify({Title = "RenCore failed to load", Content = tostring(source), Duration = 5}) end
        return false, source
    end
    local chunk, compileError = loadstring(source)
    if not chunk then
        if self.Notify then self:Notify({Title = "RenCore failed to compile", Content = tostring(compileError), Duration = 5}) end
        return false, compileError
    end
    Utility:SafeCall(beforeRelaunch)
    self:Unload("relaunching RenCore")
    task.defer(function()
        local ran, runtimeError = pcall(chunk)
        if not ran then warn("[RenLib] RenCore relaunch failed: " .. tostring(runtimeError)) end
    end)
    return true
end

-- Compatibility facade for safely migrating scripts that were authored
-- against Rayfield's tab-level control API. The rendered UI, persistence,
-- cleanup, input handling, and controllers are all RenLib-owned.
function Library:CreateRayfieldAdapter()
    local source = self
    local adapter = {ConfigName = nil, Window = nil}

    local function safeCallback(callback, ...)
        if callback then Utility:SafeCall(callback, ...) end
    end

    local function unwrapSingle(value)
        if type(value) == "table" then return value[1] end
        return value
    end

    local function selectedArray(value, values)
        local selected = {}
        if type(value) ~= "table" then
            if value ~= nil then table.insert(selected, value) end
            return selected
        end
        for _, option in ipairs(values or {}) do
            if value[option] == true then table.insert(selected, option) end
        end
        if #selected == 0 then
            for key, item in pairs(value) do
                if type(key) == "number" then table.insert(selected, item) end
            end
        end
        return selected
    end

    local function proxyController(controller, transformSet)
        local proxy = {Raw = controller}
        function proxy:Set(value)
            if controller and controller.Set then controller:Set(transformSet and transformSet(value) or value) end
            return self
        end
        function proxy:Get()
            return controller and controller.Get and controller:Get() or nil
        end
        return setmetatable(proxy, {__index = controller})
    end

    function adapter:Notify(options)
        return source:Notify(options or {})
    end

    function adapter:Destroy()
        return source:Unload("compatibility adapter")
    end

    function adapter:LoadConfiguration()
        if self.ConfigName then
            local ok = source:LoadConfig(self.ConfigName)
            if ok then return true end
        end
        return source:LoadAutoloadConfig()
    end

    function adapter:CreateWindow(options)
        options = options or {}
        local saving = options.ConfigurationSaving or {}
        if saving.Enabled then self.ConfigName = cleanConfigName(saving.FileName or options.Name or "default") end
        local themeAliases = {
            Default = "Celestial", AmberGlow = "Ember", Amethyst = "Nebula",
            Bloom = "Rose", DarkBlue = "Midnight", Green = "Moss Archive",
            Light = "Prism Frost", Ocean = "Aurora", Serenity = "Celestial"
        }
        -- A saved autoload theme is the user's explicit choice and must win
        -- over a legacy script's hard-coded Rayfield theme.
        if not source.AutoloadThemeName and type(options.Theme) == "string" then
            source:ApplyThemePreset(themeAliases[options.Theme] or options.Theme)
        elseif not source.AutoloadThemeName and type(options.Theme) == "table" then
            source:SetTheme({
                Main = options.Theme.Background,
                Secondary = options.Theme.Topbar or options.Theme.Background,
                Surface = options.Theme.ElementBackground,
                SurfaceAlt = options.Theme.SecondaryElementBackground or options.Theme.ElementBackground,
                Stroke = options.Theme.ElementStroke,
                Divider = options.Theme.SecondaryElementStroke or options.Theme.ElementStroke,
                Text = options.Theme.TextColor,
                SubText = options.Theme.PlaceholderColor,
                Hover = options.Theme.ElementBackgroundHover,
                Click = options.Theme.DropdownSelected,
                Accent = options.Theme.ToggleEnabled or options.Theme.SliderProgress,
                Accent2 = options.Theme.ToggleEnabledStroke or options.Theme.SliderProgress,
                Accent3 = options.Theme.TabBackgroundSelected or options.Theme.ToggleEnabled
            })
        end
        local toggleKey = options.ToggleUIKeybind
        if typeof(toggleKey) == "EnumItem" then
            source.ToggleKey = toggleKey
        elseif type(toggleKey) == "string" and Enum.KeyCode[toggleKey] then
            source.ToggleKey = Enum.KeyCode[toggleKey]
        end
        local rawWindow = source:CreateWindow({
            Name = options.Name or options.LoadingTitle or "RenLib Script",
            Icon = options.Icon,
            SidebarMode = "Dynamic",
            ShowUserProfile = true,
            ShowInfiniteYield = false,
            EnableGlobalSearch = true
        })
        self.Window = rawWindow
        local window = {Raw = rawWindow}

        function window:CreateTab(name, icon)
            local rawTab = rawWindow:CreateTab({Name = tostring(name or "Tab"), Icon = icon})
            local tab = {Raw = rawTab, CurrentSection = nil, SectionCount = 0}

            local function currentSection()
                if not tab.CurrentSection then
                    tab.SectionCount = tab.SectionCount + 1
                    tab.CurrentSection = rawTab:CreateSection({Name = "Controls", Side = "Left"})
                end
                return tab.CurrentSection
            end

            function tab:CreateSection(sectionOptions)
                local sectionName = type(sectionOptions) == "table" and sectionOptions.Name or sectionOptions
                self.SectionCount = self.SectionCount + 1
                self.CurrentSection = rawTab:CreateSection({
                    Name = tostring(sectionName or "Section"),
                    Side = self.SectionCount % 2 == 1 and "Left" or "Right"
                })
                return self.CurrentSection
            end

            function tab:CreateButton(controlOptions)
                controlOptions = controlOptions or {}
                return currentSection():CreateButton({
                    Name = controlOptions.Name,
                    Description = controlOptions.Description,
                    Icon = controlOptions.Icon,
                    Callback = controlOptions.Callback
                })
            end

            function tab:CreateToggle(controlOptions)
                controlOptions = controlOptions or {}
                return proxyController(currentSection():CreateToggle({
                    Name = controlOptions.Name,
                    Default = controlOptions.CurrentValue,
                    Flag = controlOptions.Flag,
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateSlider(controlOptions)
                controlOptions = controlOptions or {}
                local range = controlOptions.Range or {0, 100}
                return proxyController(currentSection():CreateSlider({
                    Name = controlOptions.Name,
                    Min = range[1],
                    Max = range[2],
                    Step = controlOptions.Increment or 1,
                    Default = controlOptions.CurrentValue or range[1],
                    Flag = controlOptions.Flag,
                    CallbackMode = controlOptions.CallbackMode or "Changed",
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateDropdown(controlOptions)
                controlOptions = controlOptions or {}
                local values = controlOptions.Options or {}
                local multi = controlOptions.MultipleOptions == true
                local default = multi and (controlOptions.CurrentOption or {}) or unwrapSingle(controlOptions.CurrentOption)
                local callback = controlOptions.Callback
                local raw = currentSection():CreateDropdown({
                    Name = controlOptions.Name,
                    Values = values,
                    Multi = multi,
                    Default = default,
                    Flag = controlOptions.Flag,
                    Callback = function(value)
                        safeCallback(callback, multi and selectedArray(value, values) or {value})
                    end
                })
                local proxy = proxyController(raw, function(value) return multi and value or unwrapSingle(value) end)
                function proxy:Refresh(newValues, newSelection)
                    values = type(newValues) == "table" and newValues or {}
                    raw:Refresh(values)
                    if newSelection ~= nil and newSelection ~= true then self:Set(newSelection) end
                    return self
                end
                return proxy
            end

            function tab:CreateInput(controlOptions)
                controlOptions = controlOptions or {}
                return proxyController(currentSection():CreateInput({
                    Name = controlOptions.Name,
                    Default = controlOptions.CurrentValue or "",
                    Placeholder = controlOptions.PlaceholderText or controlOptions.Placeholder,
                    Flag = controlOptions.Flag,
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateColorPicker(controlOptions)
                controlOptions = controlOptions or {}
                return proxyController(currentSection():CreateColorPicker({
                    Name = controlOptions.Name,
                    Default = controlOptions.Color or controlOptions.CurrentColor or Color3.new(1, 1, 1),
                    Flag = controlOptions.Flag,
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateLabel(labelOptions)
                local text = type(labelOptions) == "table" and (labelOptions.Text or labelOptions.Name) or labelOptions
                local raw = currentSection():CreateLabel(tostring(text or ""))
                local proxy = {Raw = raw}
                function proxy:Set(nextText) raw:SetText(tostring(nextText or "")); return self end
                return setmetatable(proxy, {__index = raw})
            end

            function tab:CreateParagraph(controlOptions)
                controlOptions = type(controlOptions) == "table" and controlOptions or {Content = controlOptions}
                local raw = currentSection():CreateParagraph({Title = controlOptions.Title, Content = controlOptions.Content})
                local proxy = {Raw = raw}
                function proxy:Set(value)
                    if type(value) == "table" then
                        if value.Title ~= nil then raw:SetTitle(value.Title) end
                        if value.Content ~= nil then raw:SetContent(value.Content) end
                    else
                        raw:SetContent(tostring(value or ""))
                    end
                    return self
                end
                return setmetatable(proxy, {__index = raw})
            end

            function tab:CreateKeybind(controlOptions)
                controlOptions = controlOptions or {}
                local key = controlOptions.CurrentKeybind
                if typeof(key) == "EnumItem" then key = key.Name end
                key = tostring(key or "None")
                local callback = controlOptions.Callback
                local raw = currentSection():CreateKeyPicker({
                    Name = controlOptions.Name,
                    Default = key,
                    Flag = controlOptions.Flag,
                    Mode = "Toggle",
                    Callback = function() end
                })
                source:Connect(UserInputService.InputBegan, function(input, processed)
                    if not processed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == raw:GetKey() then
                        safeCallback(callback)
                    end
                end)
                return proxyController(raw, function(value)
                    return typeof(value) == "EnumItem" and value.Name or tostring(value)
                end)
            end

            return tab
        end

        return window
    end

    return adapter
end

--// CORE UI: WINDOW
function Library:CreateWindow(options)
    options = options or {}
    local WindowTitle = options.Name or "RenLib"
    local EnableSidebarResize = options.EnableSidebarResize == nil and true or options.EnableSidebarResize
    local EnableGlobalSearch = options.EnableGlobalSearch == nil and true or options.EnableGlobalSearch
    local SidebarCompactMode = options.SidebarCompactMode or false
    local SidebarMode = tostring(options.SidebarMode or (SidebarCompactMode and "Compact" or "Dynamic"))
    if SidebarMode ~= "Dynamic" and SidebarMode ~= "Expanded" and SidebarMode ~= "Compact" then SidebarMode = "Dynamic" end
    local WindowIcon = Utility:NormalizeAssetId(options.Icon or options.Logo)
    local SettingsIcon = Utility:NormalizeAssetId(options.SettingsIcon, ICONS.Settings)
    local ShowUserProfile = options.ShowUserProfile == nil and true or options.ShowUserProfile
    local RequestedMaterialMode = options.MaterialMode or self.MaterialMode or "Solid"

    local brandLoadStarted = false
    local function createWindowMark(parent, textSize, zIndex)
        local mark = Utility:Create("ImageLabel", {
            Parent = parent,
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.16, 0.16),
            Size = UDim2.fromScale(0.68, 0.68),
            Image = WindowIcon or Library.BrandIcon,
            ImageColor3 = WindowIcon and Color3.new(1, 1, 1) or Library.Theme[Library.BrandIconTint or "Text"],
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = zIndex
        })
        if not WindowIcon then
            Library.BrandMarks[mark] = true
            if Library.BrandIconTint then Utility:RegisterProperty(mark, "ImageColor3", Library.BrandIconTint) end
            if not brandLoadStarted then
                brandLoadStarted = true
                Utility:LoadBrandIcon()
            end
        end
        return mark
    end

    if self.ScreenGui then
        pcall(function() self.ScreenGui:Destroy() end)
        self.ScreenGui = nil
    end
    self.Unloaded = false
    DeviceMode = getDeviceMode(self.DPIScale)
    IsMobile = DeviceMode ~= "Desktop"
    self.DeviceMode = DeviceMode
    self.IsMobile = IsMobile

    -- Calculate sizes based on device
    local initialViewport = getViewport()
    local initialLayoutWidth = initialViewport.X / math.max(self.DPIScale, 0.01)
    local initialLayoutHeight = initialViewport.Y / math.max(self.DPIScale, 0.01)
    local WinWidth, WinHeight, SidebarWidth, FontScale
    if IsMobile then
        WinWidth = math.min(720, math.max(1, initialLayoutWidth - 12))
        WinHeight = math.min(680, math.max(1, initialLayoutHeight - 12))
        SidebarWidth = WinWidth < 340 and 54 or 60
        FontScale = 0.9
        EnableSidebarResize = false
    else
        WinWidth = math.min(options.Width or 880, math.max(1, initialLayoutWidth - 32))
        WinHeight = math.min(options.Height or 580, math.max(1, initialLayoutHeight - 32))
        SidebarWidth = SidebarMode == "Expanded" and 190 or 80
        FontScale = 1
    end

    -- Main ScreenGui with UIScale for DPI
    local ScreenGui = Utility:Create("ScreenGui", {
        Name = "RenLibV6_" .. Utility:RandomString(8),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = options.DisplayOrder or 1000
    })
    ScreenGui:SetAttribute("RenLibVersion", Library.Version)
    local uiScale = Utility:Create("UIScale", {Parent = ScreenGui})
    table.insert(Library.Scales, uiScale)

    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end
    Library.ScreenGui = ScreenGui

    -- Main Container
    local MainFrame = Utility:Create("Frame", {
        Name = "Main",
        Parent = ScreenGui,
        BackgroundColor3 = Library.Theme.Main,
        Position = UDim2.new(0.5, -WinWidth / 2, 0.5, -WinHeight / 2),
        Size = UDim2.new(0, WinWidth, 0, WinHeight),
        ClipsDescendants = true,
        ZIndex = 1,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(MainFrame, "BackgroundColor3", "Main")
    Utility:RegisterMaterial(MainFrame, 0.24, 0)
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = MainFrame})
    local mainGradient = Utility:Create("UIGradient", {Parent = MainFrame, Rotation = 115})
    Utility:RegisterGradient(mainGradient, "Main", "Secondary")
    local glassTint = Utility:Create("ImageLabel", {
        Name = "GlassTint",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://9968344105",
        ImageColor3 = Library.Theme.Accent2,
        ImageTransparency = 0.95,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(128, 128),
        Visible = false,
        ZIndex = 1
    })
    Utility:RegisterProperty(glassTint, "ImageColor3", "Accent2")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = glassTint})
    Library.MaterialDecorations[glassTint] = true
    local glassNoise = Utility:Create("ImageLabel", {
        Name = "GlassNoise",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://9968344227",
        ImageColor3 = Color3.new(1, 1, 1),
        ImageTransparency = 0.93,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(128, 128),
        Visible = false,
        ZIndex = 1
    })
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = glassNoise})
    Library.MaterialDecorations[glassNoise] = true
    local WindowScale = Utility:Create("UIScale", {Parent = MainFrame, Scale = 1})
    local mainStroke = Utility:Create("UIStroke", {Parent = MainFrame, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(mainStroke, "Color", "Stroke")
    -- Sidebar
    local Sidebar = Utility:Create("Frame", {
        Name = "Sidebar",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, SidebarWidth, 1, 0),
        ZIndex = 2,
        BorderSizePixel = 0
    })
    -- The rounded shell and square inner extension are composited once by the
    -- CanvasGroup. Frosted themes therefore keep one uniform tint instead of
    -- revealing a darker double-layer seam behind the sidebar.
    local sidebarSurfaceGroup = Utility:Create("CanvasGroup", {
        Name = "SidebarSurface",
        Parent = Sidebar,
        BackgroundTransparency = 1,
        GroupTransparency = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        BorderSizePixel = 0
    })
    Utility:RegisterMaterial(sidebarSurfaceGroup, 0.32, 0, "GroupTransparency")
    local sidebarRoundedSurface = Utility:Create("Frame", {
        Name = "RoundedSurface",
        Parent = sidebarSurfaceGroup,
        BackgroundColor3 = Library.Theme.Secondary,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(sidebarRoundedSurface, "BackgroundColor3", "Secondary")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = sidebarRoundedSurface})
    local sidebarGradient = Utility:Create("UIGradient", {Parent = sidebarRoundedSurface, Rotation = 90})
    Utility:RegisterGradient(sidebarGradient, "Secondary", "Main")
    local sidebarSquareEdge = Utility:Create("Frame", {
        Name = "SidebarSquareInnerEdge",
        Parent = sidebarSurfaceGroup,
        BackgroundColor3 = Library.Theme.Secondary,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -14, 1, 0),
        BorderSizePixel = 0,
        ZIndex = 2
    })
    Utility:RegisterProperty(sidebarSquareEdge, "BackgroundColor3", "Secondary")
    local sidebarSquareGradient = Utility:Create("UIGradient", {Parent = sidebarSquareEdge, Rotation = 90})
    Utility:RegisterGradient(sidebarSquareGradient, "Secondary", "Main")
    local sidebarDivider = Utility:Create("Frame", {
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Divider,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        ZIndex = 3
    })
    Utility:RegisterProperty(sidebarDivider, "BackgroundColor3", "Divider")

    local TabContainer = Utility:Create("ScrollingFrame", {
        Name = "Tabs",
        Parent = Sidebar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, IsMobile and 0 or 8, 0, IsMobile and 70 or 78),
        Size = UDim2.new(1, IsMobile and 0 or -16, 1, IsMobile and -122 or -142),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        Active = true,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 4,
        BorderSizePixel = 0
    })

    local TabLayout = Utility:Create("UIListLayout", {
        Parent = TabContainer,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, IsMobile and 8 or 6)
    })

    Library:Connect(TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        TabContainer.CanvasSize = UDim2.new(0, 0, 0, TabLayout.AbsoluteContentSize.Y + 20)
    end)

    -- NAVIGATION HEADER
    -- One container owns the logo, wordmark, and sidebar toggle. This avoids
    -- stacked corner treatments and guarantees that compact controls never
    -- occupy the same pixels.
    local NavHeader = Utility:Create("Frame", {
        Name = "NavigationHeader",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Surface,
        BackgroundTransparency = 0.56,
        Position = UDim2.fromOffset(8, 10),
        Size = UDim2.new(1, -16, 0, 46),
        ClipsDescendants = true,
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(NavHeader, "BackgroundColor3", "Surface")
    Utility:RegisterMaterial(NavHeader, 0.18, 0.56)
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = NavHeader})
    local navHeaderStroke = Utility:Create("UIStroke", {
        Parent = NavHeader,
        Color = Library.Theme.Stroke,
        Transparency = 0.28,
        Thickness = 1
    })
    Utility:RegisterProperty(navHeaderStroke, "Color", "Stroke")

    -- LOGO
    local logoSize = IsMobile and 28 or (SidebarWidth < 132 and 26 or 36)
    local LogoContainer = Utility:Create("Frame", {
        Name = "LogoContainer",
        Parent = NavHeader,
        BackgroundTransparency = 1,
        Position = IsMobile and UDim2.fromOffset(5, 9)
            or (SidebarWidth < 132 and UDim2.fromOffset(4, 10) or UDim2.fromOffset(7, 5)),
        Size = UDim2.new(0, logoSize, 0, logoSize),
        ZIndex = 100,
        BorderSizePixel = 0
    })
    local Logo = createWindowMark(LogoContainer, IsMobile and 14 or 18, 101)
    Logo.Name = "Logo"

    local BrandLabel = Utility:Create("TextLabel", {
        Parent = NavHeader,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 4),
        Size = UDim2.new(1, -118, 0, 22),
        Font = Enum.Font.GothamBold,
        Text = Library.Title,
        TextColor3 = Library.Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = not IsMobile,
        ZIndex = 101
    })
    Utility:RegisterProperty(BrandLabel, "TextColor3", "Text")
    local BrandSubtitle = Utility:Create("TextLabel", {
        Parent = NavHeader,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 24),
        Size = UDim2.new(1, -118, 0, 16),
        Font = Enum.Font.Gotham,
        Text = "Interface Suite",
        TextColor3 = Library.Theme.SubText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = not IsMobile,
        ZIndex = 101
    })
    Utility:RegisterProperty(BrandSubtitle, "TextColor3", "SubText")

    local SidebarModeButton = Utility:Create("TextButton", {
        Name = "SidebarModeButton",
        Parent = NavHeader,
        BackgroundColor3 = Library.Theme.SurfaceAlt,
        BackgroundTransparency = 0.34,
        Position = SidebarMode == "Expanded" and UDim2.new(1, -62, 0, 9) or UDim2.new(1, -32, 0, 9),
        Size = SidebarMode == "Expanded" and UDim2.fromOffset(58, 28) or UDim2.fromOffset(28, 28),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 104,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(SidebarModeButton, "BackgroundColor3", "SurfaceAlt")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = SidebarModeButton})
    local sidebarModeStroke = Utility:Create("UIStroke", {
        Parent = SidebarModeButton,
        Color = Library.Theme.Stroke,
        Transparency = 0.28,
        Thickness = 1
    })
    Utility:RegisterProperty(sidebarModeStroke, "Color", "Stroke")
    local SidebarModeIcon = Utility:Create("ImageLabel", {
        Parent = SidebarModeButton,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(16, 16),
        Image = ICONS.ChevronRight,
        ImageColor3 = Library.Theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 105
    })
    Utility:RegisterProperty(SidebarModeIcon, "ImageColor3", "Text")
    local SidebarModeLabel = Utility:Create("TextLabel", {
        Parent = SidebarModeButton,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(27, 0),
        Size = UDim2.new(1, -32, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = SidebarMode == "Expanded" and "Auto" or "Pin",
        TextColor3 = Library.Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = SidebarMode == "Expanded",
        ZIndex = 105
    })
    Utility:RegisterProperty(SidebarModeLabel, "TextColor3", "Text")

    -- SETTINGS BUTTON
    local settingsBtnSize = IsMobile and 36 or 44
    local SettingsBtn = Utility:Create("TextButton", {
        Name = "SettingsBtn",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Accent,
        BackgroundTransparency = 0.64,
        Position = IsMobile and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 12)) or UDim2.new(0, 10, 1, -54),
        Size = IsMobile and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(SettingsBtn, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = SettingsBtn})
    local settingsStroke = Utility:Create("UIStroke", {Parent = SettingsBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(settingsStroke, "Color", "Stroke")
    local settingsGradient = Utility:Create("UIGradient", {Parent = SettingsBtn, Rotation = 18})
    Utility:RegisterGradient(settingsGradient, "Accent", "Accent2", "Accent3")

    local SettingsEmoji = Utility:Create("ImageLabel", {
        Parent = SettingsBtn,
        BackgroundTransparency = 1,
        Position = IsMobile and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
        Size = IsMobile and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
        Image = SettingsIcon,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 101
    })
    Utility:RegisterProperty(SettingsEmoji, "ImageColor3", "SubText")

    local SettingsLabel = Utility:Create("TextLabel", {
        Parent = SettingsBtn, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -58, 1, 0),
        Font = Enum.Font.Gotham, Text = "Settings", TextColor3 = Library.Theme.SubText,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        Visible = not IsMobile, ZIndex = 101
    })
    Utility:RegisterProperty(SettingsLabel, "TextColor3", "SubText")

    local SettingsIndicator = Utility:Create("Frame", {
        Parent = SettingsBtn,
        BackgroundColor3 = Library.Theme.Accent,
        Position = UDim2.new(0, 0, 0.5, -10),
        Size = UDim2.new(0, 4, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 102,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(SettingsIndicator, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = SettingsIndicator})

    -- NATIVE OVERVIEW BUTTON
    -- Overview is pinned with the profile and settings destinations so user
    -- tabs can scroll independently without hiding the session launcher.
    local OverviewBtn = Utility:Create("TextButton", {
        Name = "OverviewBtn",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Accent,
        BackgroundTransparency = 0.64,
        Position = IsMobile and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 62)) or UDim2.new(0, 10, 1, -102),
        Size = IsMobile and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(OverviewBtn, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = OverviewBtn})
    local overviewStroke = Utility:Create("UIStroke", {Parent = OverviewBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(overviewStroke, "Color", "Stroke")
    local overviewGradient = Utility:Create("UIGradient", {Parent = OverviewBtn, Rotation = 18})
    Utility:RegisterGradient(overviewGradient, "Accent", "Accent2", "Accent3")
    local OverviewIcon = Utility:Create("ImageLabel", {
        Parent = OverviewBtn,
        BackgroundTransparency = 1,
        Position = IsMobile and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
        Size = IsMobile and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
        Image = ICONS.Dashboard,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 101
    })
    Utility:RegisterProperty(OverviewIcon, "ImageColor3", "SubText")
    local OverviewLabel = Utility:Create("TextLabel", {
        Parent = OverviewBtn,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -58, 1, 0),
        Font = Enum.Font.Gotham,
        Text = "Overview",
        TextColor3 = Library.Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = not IsMobile,
        ZIndex = 101
    })
    Utility:RegisterProperty(OverviewLabel, "TextColor3", "SubText")
    local OverviewIndicator = Utility:Create("Frame", {
        Parent = OverviewBtn,
        BackgroundColor3 = Library.Theme.Accent,
        Position = UDim2.new(0, 0, 0.5, -10),
        Size = UDim2.new(0, 4, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 102,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(OverviewIndicator, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = OverviewIndicator})

    -- A single selection surface moves between every navigation destination.
    -- Keeping it outside the UIListLayout lets it travel cleanly across
    -- category gaps and down to the pinned Settings destination.
    local NavigationSelection = Utility:Create("Frame", {
        Name = "NavigationSelection",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Accent,
        BackgroundTransparency = 0.1,
        Position = UDim2.fromOffset(8, 78),
        Size = UDim2.fromOffset(42, 42),
        Visible = false,
        -- Keep the moving surface below the TabContainer sibling group. In
        -- Sibling ZIndex mode, matching the container's ZIndex can place this
        -- later-created frame over every icon and label inside that group.
        ZIndex = 3,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(NavigationSelection, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = NavigationSelection})
    local navigationSelectionStroke = Utility:Create("UIStroke", {
        Parent = NavigationSelection,
        Color = Library.Theme.Accent2,
        Transparency = 0.2,
        Thickness = 1
    })
    Utility:RegisterProperty(navigationSelectionStroke, "Color", "Accent2")
    local navigationSelectionGradient = Utility:Create("UIGradient", {
        Parent = NavigationSelection,
        Rotation = 18
    })
    Utility:RegisterGradient(navigationSelectionGradient, "Accent", "Accent2", "Accent3")
    local NavigationSelectionRail = Utility:Create("Frame", {
        Parent = NavigationSelection,
        BackgroundColor3 = Library.Theme.Text,
        BackgroundTransparency = 0.08,
        Position = UDim2.new(0, 3, 0.5, -9),
        Size = UDim2.fromOffset(3, 18),
        ZIndex = 5,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(NavigationSelectionRail, "BackgroundColor3", "Text")
    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = NavigationSelectionRail})

    -- USER PROFILE
    local ProfileCard, ProfileAvatar, ProfileNameLabel, ProfileSubtitleLabel, ProfileStroke
    local ProfileCompact = IsMobile
    local SetProfileData = function() end
    if ShowUserProfile then
        ProfileCard = Utility:Create("Frame", {
            Name = "UserProfile",
            Parent = Sidebar,
            BackgroundColor3 = Library.Theme.Surface,
            BackgroundTransparency = ProfileCompact and 1 or 0,
            Position = ProfileCompact and UDim2.new(0.5, -19, 1, -(settingsBtnSize + 112)) or UDim2.new(0, 10, 1, -158),
            Size = ProfileCompact and UDim2.fromOffset(38, 38) or UDim2.new(1, -20, 0, 48),
            ClipsDescendants = true,
            ZIndex = 98,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(ProfileCard, "BackgroundColor3", "Surface")
        Utility:RegisterMaterial(ProfileCard, 0.28, 0)
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 9), Parent = ProfileCard})
        ProfileStroke = Utility:Create("UIStroke", {Parent = ProfileCard, Color = Library.Theme.Stroke, Thickness = 1, Enabled = not ProfileCompact})
        Utility:RegisterProperty(ProfileStroke, "Color", "Stroke")

        ProfileAvatar = Utility:Create("ImageLabel", {
            Parent = ProfileCard,
            BackgroundColor3 = Library.Theme.SurfaceAlt,
            Position = ProfileCompact and UDim2.fromOffset(2, 2) or UDim2.fromOffset(6, 6),
            Size = ProfileCompact and UDim2.new(1, -4, 1, -4) or UDim2.fromOffset(36, 36),
            Image = Utility:NormalizeAssetId(options.ProfileAvatar, ICONS.Profile),
            ImageColor3 = Color3.new(1, 1, 1),
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 99
        })
        Utility:RegisterProperty(ProfileAvatar, "BackgroundColor3", "SurfaceAlt")
        Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ProfileAvatar})
        local avatarStroke = Utility:Create("UIStroke", {Parent = ProfileAvatar, Color = Library.Theme.Accent, Thickness = 1})
        Utility:RegisterProperty(avatarStroke, "Color", "Accent")

        ProfileNameLabel = Utility:Create("TextLabel", {
            Parent = ProfileCard,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(50, 7),
            Size = UDim2.new(1, -58, 0, 18),
            Font = Enum.Font.GothamMedium,
            Text = tostring(options.ProfileTitle or Plr.DisplayName or Plr.Name),
            TextColor3 = Library.Theme.Text,
            TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not ProfileCompact,
            ZIndex = 99
        })
        Utility:RegisterProperty(ProfileNameLabel, "TextColor3", "Text")
        ProfileSubtitleLabel = Utility:Create("TextLabel", {
            Parent = ProfileCard,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(50, 24),
            Size = UDim2.new(1, -58, 0, 16),
            Font = Enum.Font.Gotham,
            Text = tostring(options.ProfileSubtitle or ("@" .. Plr.Name)),
            TextColor3 = Library.Theme.SubText,
            TextSize = 9,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not ProfileCompact,
            ZIndex = 99
        })
        Utility:RegisterProperty(ProfileSubtitleLabel, "TextColor3", "SubText")

        local ProfileButton = Utility:Create("TextButton", {
            Parent = ProfileCard,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 100
        })
        Library:Connect(ProfileButton.MouseEnter, function()
            if not ProfileCompact then Utility:Tween(ProfileCard, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme.Hover}) end
        end)
        Library:Connect(ProfileButton.MouseLeave, function()
            Utility:Tween(ProfileCard, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme.Surface})
        end)
        Library:Connect(ProfileButton.MouseButton1Click, function()
            Utility:SafeCall(options.OnProfileClick, Plr)
        end)

        SetProfileData = function(data)
            data = data or {}
            if data.Title ~= nil then ProfileNameLabel.Text = tostring(data.Title) end
            if data.Subtitle ~= nil then ProfileSubtitleLabel.Text = tostring(data.Subtitle) end
            local customAvatar = Utility:NormalizeAssetId(data.Avatar)
            if customAvatar then ProfileAvatar.Image = customAvatar end
        end

        if not Utility:NormalizeAssetId(options.ProfileAvatar) then
            local profileUserId = tonumber(options.ProfileUserId) or Plr.UserId
            task.spawn(function()
                local ok, thumbnail = pcall(function()
                    return Players:GetUserThumbnailAsync(profileUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                end)
                if ok and ProfileAvatar and ProfileAvatar.Parent then ProfileAvatar.Image = thumbnail end
            end)
        end
    end

    local navigationLabelTokens = setmetatable({}, {__mode = "k"})
    local function applyLayout(instance, properties, animated)
        if animated then
            Utility:TweenLayout(instance, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
        else
            Utility:StopLayoutTween(instance)
            for property, value in pairs(properties) do instance[property] = value end
        end
    end

    local function setNavigationLabel(label, visible, animated)
        if not label then return end
        local token = (navigationLabelTokens[label] or 0) + 1
        navigationLabelTokens[label] = token
        if not animated then
            Utility:StopVisibilityTween(label)
            label.Visible = visible
            label.TextTransparency = visible and 0 or 1
            return
        end
        if visible then
            label.Visible = true
            label.TextTransparency = 1
            Utility:TweenVisibility(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
        else
            Utility:TweenVisibility(label, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}, function()
                if navigationLabelTokens[label] == token then label.Visible = false end
            end)
        end
    end

    local function getNavigationBottomInset(compact, mobile, hideProfile)
        if ShowUserProfile and not hideProfile then return compact and 224 or 234 end
        return 176
    end

    local function applyProfileLayout(compact, hidden, animated)
        ProfileCompact = compact
        if not ProfileCard then return end
        ProfileCard.Visible = not hidden
        applyLayout(ProfileCard, {
            BackgroundTransparency = compact and 1 or Library:ResolveMaterialTransparency(Library.MaterialRegistry[ProfileCard]),
            Position = compact and UDim2.new(0.5, -19, 1, -(settingsBtnSize + 112)) or UDim2.new(0, 10, 1, -158),
            Size = compact and UDim2.fromOffset(38, 38) or UDim2.new(1, -20, 0, 48)
        }, animated)
        applyLayout(ProfileAvatar, {
            Position = compact and UDim2.fromOffset(2, 2) or UDim2.fromOffset(6, 6),
            Size = compact and UDim2.new(1, -4, 1, -4) or UDim2.fromOffset(36, 36)
        }, animated)
        setNavigationLabel(ProfileNameLabel, not compact, animated)
        setNavigationLabel(ProfileSubtitleLabel, not compact, animated)
        ProfileStroke.Enabled = not compact
    end

    applyProfileLayout(IsMobile)
    TabContainer.Size = UDim2.new(1, IsMobile and 0 or -16, 1, -getNavigationBottomInset(IsMobile, IsMobile))

    -- Content Area
    local Pages = Utility:Create("Frame", {
        Name = "Pages",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, SidebarWidth, 0, 0),
        Size = UDim2.new(1, -SidebarWidth, 1, 0),
        ClipsDescendants = true,
        ZIndex = 1,
        BorderSizePixel = 0
    })

    -- TOP BAR
    local TopBar = Utility:Create("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        BackgroundColor3 = Library.Theme.Secondary,
        BackgroundTransparency = 0.08,
        Position = UDim2.new(0, SidebarWidth, 0, 0),
        Size = UDim2.new(1, -SidebarWidth, 0, IsMobile and 88 or 60),
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(TopBar, "BackgroundColor3", "Secondary")
    Utility:RegisterMaterial(TopBar, 0.4, 0.08)

    Utility:MakeDraggable(TopBar, MainFrame)

    local TitleLabel = Utility:Create("TextLabel", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 20, 0, IsMobile and 13 or 16),
        Size = UDim2.new(0, 200, 0, 30),
        Font = Enum.Font.GothamBold,
        Text = WindowTitle,
        TextColor3 = Library.Theme.Text,
        TextSize = IsMobile and 17 or 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 101
    })
    Utility:RegisterProperty(TitleLabel, "TextColor3", "Text")

    local TopDivider = Utility:Create("Frame", {
        Parent = MainFrame,
        BackgroundColor3 = Library.Theme.Divider,
        Position = UDim2.new(0, SidebarWidth, 0, IsMobile and 87 or 59),
        Size = UDim2.new(1, -SidebarWidth, 0, 1),
        BorderSizePixel = 0,
        ZIndex = 90
    })
    Utility:RegisterProperty(TopDivider, "BackgroundColor3", "Divider")

    -- MINIMIZE BUTTON
    local MinimizeBtn = Utility:Create("TextButton", {
        Name = "MinimizeBtn",
        Parent = TopBar,
        BackgroundColor3 = Library.Theme.Surface,
        Position = UDim2.new(1, -80, 0, IsMobile and 10 or 15),
        Size = UDim2.new(0, IsMobile and 26 or 28, 0, IsMobile and 26 or 28),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 101,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(MinimizeBtn, "BackgroundColor3", "Surface")
    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = MinimizeBtn})
    local minimizeStroke = Utility:Create("UIStroke", {Parent = MinimizeBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(minimizeStroke, "Color", "Stroke")

    local MinimizeIcon = Utility:Create("ImageLabel", {
        Parent = MinimizeBtn,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.22, 0.22),
        Size = UDim2.fromScale(0.56, 0.56),
        Image = ICONS.Minimize,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 102
    })
    Utility:RegisterProperty(MinimizeIcon, "ImageColor3", "SubText")

    -- CLOSE BUTTON
    local CloseBtn = Utility:Create("TextButton", {
        Name = "CloseBtn",
        Parent = TopBar,
        BackgroundColor3 = Library.Theme.Surface,
        Position = UDim2.new(1, -40, 0, IsMobile and 10 or 15),
        Size = UDim2.new(0, IsMobile and 26 or 28, 0, IsMobile and 26 or 28),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 101,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(CloseBtn, "BackgroundColor3", "Surface")
    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = CloseBtn})
    local closeStroke = Utility:Create("UIStroke", {Parent = CloseBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(closeStroke, "Color", "Stroke")

    local CloseIcon = Utility:Create("ImageLabel", {
        Parent = CloseBtn,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.22, 0.22),
        Size = UDim2.fromScale(0.56, 0.56),
        Image = ICONS.Close,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 102
    })
    Utility:RegisterProperty(CloseIcon, "ImageColor3", "SubText")

    -- SEARCH BOX (Global Search)
    local SearchBox = nil
    if EnableGlobalSearch then
        SearchBox = Utility:Create("TextBox", {
            Parent = TopBar,
            BackgroundColor3 = Library.Theme.Surface,
            AnchorPoint = IsMobile and Vector2.new(0, 0) or Vector2.new(0.5, 0),
            Position = IsMobile and UDim2.new(0, 8, 0, 50) or UDim2.new(0.5, 0, 0, 15),
            Size = IsMobile and UDim2.new(1, -16, 0, 30) or UDim2.new(0, 250, 0, 30),
            PlaceholderText = "Search controls...",
            Text = "",
            TextColor3 = Library.Theme.Text,
            Font = Enum.Font.Gotham,
            TextSize = IsMobile and 12 or 14,
            ClearTextOnFocus = false,
            ZIndex = 101,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(SearchBox, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(SearchBox, "TextColor3", "Text")
        Utility:RegisterProperty(SearchBox, "PlaceholderColor3", "SubText")
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SearchBox})
        Utility:Create("UIPadding", {Parent = SearchBox, PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 54)})
        local SearchIcon = Utility:Create("ImageLabel", {
            Parent = SearchBox,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, -25, 0.5, -8),
            Size = UDim2.fromOffset(16, 16),
            Image = ICONS.Search,
            ImageColor3 = Library.Theme.SubText,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 102
        })
        Utility:RegisterProperty(SearchIcon, "ImageColor3", "SubText")
        local searchStroke = Utility:Create("UIStroke", {Parent = SearchBox, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(searchStroke, "Color", "Stroke")
    end

    -- Notification Container
    local NotifyArea = Utility:Create("Frame", {
        Name = "Notifications",
        Parent = ScreenGui,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, IsMobile and -220 or -320, 1, -20),
        Size = UDim2.new(0, IsMobile and 200 or 300, 1, 0),
        AnchorPoint = Vector2.new(1, 1),
        ZIndex = 200
    })
    Utility:Create("UIListLayout", {
        Parent = NotifyArea,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom
    })

    -- Minimized Icon
    local MinimizedIcon = Utility:Create("Frame", {
        Name = "MinimizedIcon",
        Parent = ScreenGui,
        BackgroundColor3 = Library.Theme.Main,
        Position = UDim2.new(1, -70, 0, 20),
        Size = UDim2.new(0, 50, 0, 50),
        Visible = false,
        ZIndex = 300,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(MinimizedIcon, "BackgroundColor3", "Main")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = MinimizedIcon})
    local minIconStroke = Utility:Create("UIStroke", {Parent = MinimizedIcon, Color = Library.Theme.Accent, Thickness = 2})
    Utility:RegisterProperty(minIconStroke, "Color", "Accent")
    local MinimizedLogo = createWindowMark(MinimizedIcon, 20, 301)
    local MinIconBtn = Utility:Create("TextButton", {
        Parent = MinimizedIcon,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 302
    })

    -- Mobile Toggle Button
    local MobileToggleBtn
    do
        MobileToggleBtn = Utility:Create("Frame", {
            Name = "MobileToggle",
            Parent = ScreenGui,
            BackgroundColor3 = Library.Theme.Main,
            Position = UDim2.new(0, 10, 0.5, -25),
            Size = UDim2.new(0, 40, 0, 40),
            Visible = false,
            ZIndex = 400,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(MobileToggleBtn, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = MobileToggleBtn})
        local mobileStroke = Utility:Create("UIStroke", {Parent = MobileToggleBtn, Color = Library.Theme.Accent, Thickness = 2})
        Utility:RegisterProperty(mobileStroke, "Color", "Accent")
        local MobileToggleLogo = createWindowMark(MobileToggleBtn, 16, 401)
        local MobileToggleTapBtn = Utility:Create("TextButton", {
            Parent = MobileToggleBtn,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            ZIndex = 402
        })
        local mobileToggleDrag = Utility:MakeDraggable(MobileToggleTapBtn, MobileToggleBtn)
        Library:Connect(MobileToggleTapBtn.MouseButton1Click, function()
            if mobileToggleDrag:ConsumeDrag() then return end
            if Library.IsMinimized then
                Library.IsMinimized = false
                Library:RefreshMaterialVisibility()
                MinimizedIcon.Visible = false
                MainFrame.Visible = true
                MobileToggleBtn.Visible = false
            else
                MainFrame.Visible = not MainFrame.Visible
                Library.IsMinimized = not MainFrame.Visible
                if not MainFrame.Visible then
                    MobileToggleBtn.Visible = true
                end
                Library:RefreshMaterialVisibility()
            end
        end)
    end

    -- Window Object (declared early so resizer can reference it)
    local Window = {
        Tabs = {},
        TabCategories = {},
        CurrentTabCategory = nil,
        NextNavOrder = 0,
        ActiveTab = nil,
        Gui = ScreenGui,
        Main = MainFrame,
        SettingsTab = nil,
        SearchBox = SearchBox,
        Sidebar = Sidebar,
        SidebarMode = SidebarMode,
        NavigationListeners = {},
        NavigationRevision = 0,
        SearchResults = {},
        SearchQuery = ""
    }

    function Window:OnTabChanged(callback)
        if type(callback) == "function" then table.insert(self.NavigationListeners, callback) end
        return self
    end

    function Window:SelectTab(tab, selectOptions)
        selectOptions = selectOptions or {}
        if tab ~= nil then
            local known = false
            for _, candidate in ipairs(self.Tabs) do
                if candidate == tab then known = true break end
            end
            if not known then return false, "Unknown tab" end
        end

        local previous = self.ActiveTab
        self.NavigationRevision = self.NavigationRevision + 1
        self.ActiveTab = tab

        for _, candidate in ipairs(self.Tabs) do
            local active = candidate == tab
            candidate.Active = active
            if candidate.Page then candidate.Page.Visible = active end
            if candidate.ApplyActiveVisual then candidate:ApplyActiveVisual(active, selectOptions.Animate ~= false) end
        end

        if tab then
            TitleLabel.Text = tab.Name
            if selectOptions.ResetScroll ~= false and tab.Page then tab.Page.CanvasPosition = Vector2.new(0, 0) end
            task.defer(function()
                if Window.ActiveTab == tab and not Library.Unloaded then
                    Window:MoveNavigationSelection(selectOptions.Animate ~= false)
                end
            end)
        else
            NavigationSelection.Visible = false
        end

        if previous ~= tab then
            for _, callback in ipairs(self.NavigationListeners) do
                Utility:SafeCall(callback, tab, previous, self.NavigationRevision)
            end
        end
        return true
    end

    local navigationSelectionToken = 0
    function Window:MoveNavigationSelection(animate)
        local active = self.ActiveTab
        local button = active and active.TabBtn
        if not button or not button.Parent or not Sidebar.Parent then
            NavigationSelection.Visible = false
            return
        end
        local effectiveScale = math.max(Library.DPIScale * WindowScale.Scale, 0.01)
        local offset = button.AbsolutePosition - Sidebar.AbsolutePosition
        local absoluteSize = button.AbsoluteSize
        if absoluteSize.X < 1 or absoluteSize.Y < 1 then return end
        local target = {
            Position = UDim2.fromOffset(offset.X / effectiveScale, offset.Y / effectiveScale),
            Size = UDim2.fromOffset(absoluteSize.X / effectiveScale, absoluteSize.Y / effectiveScale)
        }
        NavigationSelection.Visible = true
        if animate then
            Utility:Tween(NavigationSelection, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), target)
        else
            Utility:StopTween(NavigationSelection)
            NavigationSelection.Position = target.Position
            NavigationSelection.Size = target.Size
        end
    end

    function Window:TrackNavigationSelection(duration)
        navigationSelectionToken = navigationSelectionToken + 1
        local token = navigationSelectionToken
        task.spawn(function()
            local started = os.clock()
            repeat
                RunService.RenderStepped:Wait()
                if token ~= navigationSelectionToken or Library.Unloaded then return end
                Window:MoveNavigationSelection(false)
            until os.clock() - started >= (duration or 0.32)
            Window:MoveNavigationSelection(false)
        end)
    end

    Library:Connect(TabContainer:GetPropertyChangedSignal("CanvasPosition"), function()
        Window:MoveNavigationSelection(false)
    end)

    function Window:GetLayoutDiagnostics()
        local issues = {}
        local function add(code, message)
            table.insert(issues, {Code = code, Message = message})
        end
        local function overlaps(a, b, padding)
            padding = padding or 0
            local ap, as = a.AbsolutePosition, a.AbsoluteSize
            local bp, bs = b.AbsolutePosition, b.AbsoluteSize
            return ap.X + as.X + padding > bp.X
                and bp.X + bs.X + padding > ap.X
                and ap.Y + as.Y + padding > bp.Y
                and bp.Y + bs.Y + padding > ap.Y
        end
        if Library.DPIScale < 1 then
            add("scale-floor", "UI scale is below the supported 100% minimum")
        end
        if MainFrame.ClipsDescendants ~= true then
            add("shell-clip", "The root shell is not clipping internal chrome to its corner")
        end
        if SidebarModeButton.Visible and overlaps(LogoContainer, SidebarModeButton, 2) then
            add("nav-header-overlap", "The brand mark and sidebar-mode control overlap")
        end
        if BrandLabel.Visible and SidebarModeButton.Visible and overlaps(BrandLabel, SidebarModeButton, 2) then
            add("nav-header-label-overlap", "The sidebar-mode control overlaps the RenLib wordmark")
        end
        if SidebarModeButton.Visible and (SidebarModeButton.AbsoluteSize.X < 28 or SidebarModeButton.AbsoluteSize.Y < 28) then
            add("nav-toggle-hit-area", "The sidebar-mode control is smaller than its safe pointer target")
        end
        if self.SidebarVisualExpanded and self.ActiveTab and self.ActiveTab.TabBtn
            and self.ActiveTab.TabBtn.AbsoluteSize.X < Sidebar.AbsoluteSize.X * 0.6 then
            add("active-tab-state", "The selected tab is still using compact geometry inside an expanded sidebar")
        end
        if self.SidebarVisualExpanded and ProfileCard and ProfileCard.Visible
            and ProfileCard.AbsoluteSize.X < Sidebar.AbsoluteSize.X * 0.6 then
            add("profile-state", "The profile card is still using compact geometry inside an expanded sidebar")
        end
        if OverviewBtn.Visible and overlaps(OverviewBtn, SettingsBtn, 4) then
            add("native-navigation-overlap", "Overview and Settings overlap")
        end
        if ProfileCard and ProfileCard.Visible and overlaps(ProfileCard, OverviewBtn, 4) then
            add("profile-overview-overlap", "The profile card overlaps Overview")
        end
        local seamDistance = math.abs((Sidebar.AbsolutePosition.X + Sidebar.AbsoluteSize.X) - TopBar.AbsolutePosition.X)
        if seamDistance > 2 then
            add("chrome-seam", "The sidebar and top bar no longer share one seam")
        end
        return #issues == 0, issues
    end

    function Window:SetProfile(data)
        SetProfileData(data)
    end

    function Window:RefreshThemeState()
        for _, tab in ipairs(self.Tabs) do
            local textKey = tab.Active and "Text" or "SubText"
            if tab.TabLabel then tab.TabLabel.TextColor3 = Library.Theme[textKey] end
            if tab.TabEmoji then
                if tab.TabEmoji:IsA("TextLabel") then
                    tab.TabEmoji.TextColor3 = Library.Theme[textKey]
                elseif tab.TabEmoji:IsA("ImageLabel") then
                    tab.TabEmoji.ImageColor3 = Library.Theme[textKey]
                end
            end
            if tab.TabBtn then tab.TabBtn.BackgroundTransparency = tab.Active and 1 or 0.64 end
            if tab.TabStroke then
                tab.TabStroke.Color = tab.Active and Library.Theme.Accent or Library.Theme.Stroke
                tab.TabStroke.Transparency = tab.Active and 0.08 or 0.24
            end
        end
        self:MoveNavigationSelection(false)
    end

    -- RESIZABLE SIDEBAR (PC only)
    local sidebarResizer = nil
    local dividerLine = nil
    local currentSidebarWidth = math.clamp(tonumber(options.SidebarWidth) or 190, 132, 240)
    local sidebarHoverExpanded = false
    local isCompact = IsMobile or SidebarMode ~= "Expanded"
    if EnableSidebarResize and not IsMobile then
        dividerLine = Utility:Create("Frame", {
            Parent = MainFrame,
            BackgroundColor3 = Library.Theme.Stroke,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SidebarWidth, 0, 0),
            Size = UDim2.new(0, 1, 1, 0),
            ZIndex = 5,
            BorderSizePixel = 0
        })
        sidebarResizer = Utility:Create("TextButton", {
            Parent = dividerLine,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 4, 1, 0),
            Position = UDim2.new(1, -2, 0, 0),
            Text = "",
            ZIndex = 6,
            AutoButtonColor = false
        })
        local dragging = false
        local startX, startWidth
        Library:Connect(sidebarResizer.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and not isCompact then
                dragging = true
                startX = input.Position.X
                startWidth = currentSidebarWidth
                Library:Connect(input.Changed, function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        Library:Connect(UserInputService.InputChanged, function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position.X - startX
                local newWidth = math.clamp(startWidth + delta, 62, 240)
                currentSidebarWidth = newWidth
                SidebarMode = "Expanded"
                Window.SidebarMode = SidebarMode
                Window:ApplyResponsiveLayout(false)
            end
        end)
    end

    local lastDeviceMode = DeviceMode

    function Window:ApplyResponsiveLayout(recenter, animateNavigation)
        local viewport = getViewport()
        local scale = math.max(Library.DPIScale, 0.01)
        local layoutViewport = Vector2.new(viewport.X / scale, viewport.Y / scale)
        local mode = getDeviceMode(scale)
        local mobile = mode ~= "Desktop"
        local horizontalMargin = mobile and 6 or 16
        local verticalMargin = mobile and 6 or 16
        local maximumWidth = math.max(1, layoutViewport.X - horizontalMargin * 2)
        local maximumHeight = math.max(1, layoutViewport.Y - verticalMargin * 2)
        local width = math.min(mobile and 720 or (options.Width or 880), maximumWidth)
        local height = math.min(mobile and 680 or (options.Height or 580), maximumHeight)
        if self.Maximized then
            width = maximumWidth
            height = maximumHeight
        end
        local navigationExpanded = SidebarMode == "Expanded" or (SidebarMode == "Dynamic" and sidebarHoverExpanded)
        local sidebarWidth = mobile and (width < 340 and 54 or 60)
            or (navigationExpanded and math.clamp(currentSidebarWidth, 132, math.min(240, width * 0.32)) or 80)
        local shortViewport = mobile and height < 420
        local hideSearch = mobile and height < 300
        local hideProfile = height < 380
        local topBarHeight = mobile and (hideSearch and 48 or (shortViewport and 74 or 88)) or 60
        Window.ContentTopInset = topBarHeight

        DeviceMode = mode
        IsMobile = mobile
        Library.DeviceMode = mode
        Library.IsMobile = mobile
        MainFrame.Size = UDim2.fromOffset(width, height)
        local absolutePosition = MainFrame.AbsolutePosition
        local absoluteSize = MainFrame.AbsoluteSize
        local unreachable = absolutePosition.X + absoluteSize.X < 40
            or absolutePosition.Y + 40 < 0
            or absolutePosition.X > viewport.X - 40
            or absolutePosition.Y > viewport.Y - 40
        if recenter or unreachable then
            MainFrame.Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2)
        end
        applyLayout(Sidebar, {Size = UDim2.new(0, sidebarWidth, 1, 0)}, animateNavigation)
        applyLayout(Pages, {
            Position = UDim2.new(0, sidebarWidth, 0, 0),
            Size = UDim2.new(1, -sidebarWidth, 1, 0)
        }, animateNavigation)
        isCompact = mobile or sidebarWidth < 132
        local visibleContentWidth = math.max(1, (width - sidebarWidth) * scale)
        local singleColumn = mobile or visibleContentWidth < 640
        applyLayout(TopBar, {
            Position = UDim2.new(0, sidebarWidth, 0, 0),
            Size = UDim2.new(1, -sidebarWidth, 0, topBarHeight)
        }, animateNavigation)
        applyLayout(TitleLabel, {
            Position = UDim2.new(0, 16, 0, mobile and (hideSearch and 9 or 11) or 16),
            Size = UDim2.new(1, -(mobile and 108 or 430), 0, 30)
        }, animateNavigation)
        TitleLabel.TextSize = mobile and 17 or 19
        applyLayout(TopDivider, {
            Position = UDim2.new(0, sidebarWidth, 0, topBarHeight - 1),
            Size = UDim2.new(1, -sidebarWidth, 0, 1)
        }, animateNavigation)
        MinimizeBtn.Position = UDim2.new(1, -76, 0, mobile and 8 or 15)
        CloseBtn.Position = UDim2.new(1, -40, 0, mobile and 8 or 15)
        local activeLogoSize = mobile and 28 or (isCompact and 26 or 36)
        local showWordmark = not isCompact and sidebarWidth >= 174
        applyLayout(LogoContainer, {
            Size = UDim2.fromOffset(activeLogoSize, activeLogoSize),
            Position = mobile and UDim2.new(0.5, -activeLogoSize / 2, 0, 9)
                or (isCompact and UDim2.fromOffset(4, 10) or UDim2.fromOffset(7, 5))
        }, animateNavigation)
        setNavigationLabel(BrandLabel, showWordmark, animateNavigation)
        setNavigationLabel(BrandSubtitle, showWordmark, animateNavigation)
        SidebarModeButton.Visible = not mobile
        SidebarModeLabel.Text = SidebarMode == "Expanded" and "Auto" or "Pin"
        applyLayout(SidebarModeButton, {
            Position = isCompact and UDim2.new(1, -32, 0, 9) or UDim2.new(1, -62, 0, 9),
            Size = isCompact and UDim2.fromOffset(28, 28) or UDim2.fromOffset(58, 28)
        }, animateNavigation)
        applyLayout(SidebarModeIcon, {
            Position = isCompact and UDim2.fromOffset(6, 6) or UDim2.fromOffset(7, 6),
            Size = UDim2.fromOffset(16, 16),
            Rotation = isCompact and 0 or 180
        }, animateNavigation)
        setNavigationLabel(SidebarModeLabel, not isCompact, animateNavigation)
        applyLayout(TabContainer, {
            Position = UDim2.new(0, isCompact and 0 or 8, 0, mobile and 70 or 68),
            Size = UDim2.new(1, isCompact and 0 or -16, 1, -getNavigationBottomInset(isCompact, mobile, hideProfile))
        }, animateNavigation)
        applyLayout(SettingsBtn, {
            Position = isCompact and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 12)) or UDim2.new(0, 10, 1, -54),
            Size = isCompact and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42)
        }, animateNavigation)
        applyLayout(SettingsEmoji, {
            Position = isCompact and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
            Size = isCompact and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32)
        }, animateNavigation)
        setNavigationLabel(SettingsLabel, not isCompact, animateNavigation)
        applyLayout(OverviewBtn, {
            Position = isCompact and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 62)) or UDim2.new(0, 10, 1, -102),
            Size = isCompact and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42)
        }, animateNavigation)
        applyLayout(OverviewIcon, {
            Position = isCompact and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
            Size = isCompact and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32)
        }, animateNavigation)
        setNavigationLabel(OverviewLabel, not isCompact, animateNavigation)
        applyProfileLayout(isCompact, hideProfile, animateNavigation)
        NotifyArea.Position = UDim2.new(1, mobile and -12 or -20, 1, -20)
        NotifyArea.Size = UDim2.new(0, mobile and math.max(180, math.min(300, layoutViewport.X - 24)) or 300, 1, 0)
        if SearchBox then
            SearchBox.Visible = not hideSearch
            SearchBox.AnchorPoint = mobile and Vector2.new(0, 0) or Vector2.new(0.5, 0)
            SearchBox.Position = mobile and UDim2.new(0, 8, 0, shortViewport and 41 or 50)
                or UDim2.new(0.5, 0, 0, 15)
            SearchBox.Size = mobile and UDim2.new(1, -16, 0, shortViewport and 26 or 30) or UDim2.new(0, 270, 0, 30)
        end
        if dividerLine then
            dividerLine.Visible = not mobile and not isCompact
            dividerLine.Position = UDim2.new(0, sidebarWidth, 0, 0)
        end
        for _, tab in ipairs(Window.Tabs) do
            if tab.ApplyNavigationLayout then tab:ApplyNavigationLayout(mobile, isCompact, animateNavigation) end
            if tab.ApplyResponsiveLayout then
                tab:ApplyResponsiveLayout(singleColumn, topBarHeight)
            end
        end
        for _, category in ipairs(Window.TabCategories) do
            category.Label.Visible = true
            applyLayout(category.Label, {
                Size = UDim2.new(1, -8, 0, isCompact and 0 or 20),
                TextTransparency = isCompact and 1 or 0
            }, animateNavigation)
        end
        if animateNavigation then
            self:TrackNavigationSelection(0.34)
        else
            task.defer(function() if not Library.Unloaded then self:MoveNavigationSelection(false) end end)
        end
        self.SidebarVisualExpanded = not isCompact
        if Library.IsMinimized then
            MobileToggleBtn.Visible = mobile
            MinimizedIcon.Visible = not mobile
        end
        if mode ~= lastDeviceMode then
            lastDeviceMode = mode
            Utility:SafeCall(options.OnDeviceChanged, mode)
        end
        task.delay(animateNavigation and 0.34 or 0, function()
            if not Library.Unloaded then
                local passed, issues = self:GetLayoutDiagnostics()
                self.LastLayoutAudit = {Passed = passed, Issues = issues, CheckedAt = os.clock()}
            end
        end)
        return mode
    end

    function Window:SetSidebarMode(mode)
        mode = tostring(mode or "Dynamic")
        if mode ~= "Dynamic" and mode ~= "Expanded" and mode ~= "Compact" then return false end
        SidebarMode = mode
        self.SidebarMode = mode
        sidebarHoverExpanded = false
        SidebarModeLabel.Text = mode == "Expanded" and "Auto" or "Pin"
        self:ApplyResponsiveLayout(false, true)
        return true
    end

    local sidebarHoverToken = 0
    local function setSidebarHover(expanded)
        if SidebarMode ~= "Dynamic" or IsMobile then return end
        sidebarHoverToken = sidebarHoverToken + 1
        local token = sidebarHoverToken
        if expanded then
            if not sidebarHoverExpanded then
                sidebarHoverExpanded = true
                Window:ApplyResponsiveLayout(false, true)
            end
        else
            task.delay(0.35, function()
                if token == sidebarHoverToken and SidebarMode == "Dynamic" then
                    sidebarHoverExpanded = false
                    Window:ApplyResponsiveLayout(false, true)
                end
            end)
        end
    end

    -- Hover expansion belongs to navigation content, not the mode button.
    -- The compact button therefore stays under the pointer and can be clicked
    -- immediately instead of moving away on the first hover.
    Library:Connect(TabContainer.MouseEnter, function() setSidebarHover(true) end)
    Library:Connect(TabContainer.MouseLeave, function() setSidebarHover(false) end)
    Library:Connect(SettingsBtn.MouseEnter, function() setSidebarHover(true) end)
    Library:Connect(SettingsBtn.MouseLeave, function() setSidebarHover(false) end)
    Library:Connect(OverviewBtn.MouseEnter, function() setSidebarHover(true) end)
    Library:Connect(OverviewBtn.MouseLeave, function() setSidebarHover(false) end)
    if ProfileCard then
        Library:Connect(ProfileCard.MouseEnter, function() setSidebarHover(true) end)
        Library:Connect(ProfileCard.MouseLeave, function() setSidebarHover(false) end)
    end
    Library:Connect(NavHeader.MouseEnter, function()
        if sidebarHoverExpanded then sidebarHoverToken = sidebarHoverToken + 1 end
    end)
    Library:Connect(NavHeader.MouseLeave, function()
        if sidebarHoverExpanded then setSidebarHover(false) end
    end)
    Library:Connect(SidebarModeButton.MouseEnter, function()
        Utility:Tween(SidebarModeButton, TweenInfo.new(0.14), {BackgroundTransparency = 0.12})
        Utility:Tween(sidebarModeStroke, TweenInfo.new(0.14), {Transparency = 0.05})
    end)
    Library:Connect(SidebarModeButton.MouseLeave, function()
        Utility:Tween(SidebarModeButton, TweenInfo.new(0.14), {BackgroundTransparency = 0.34})
        Utility:Tween(sidebarModeStroke, TweenInfo.new(0.14), {Transparency = 0.28})
    end)
    Library:Connect(SidebarModeButton.MouseButton1Click, function()
        Window:SetSidebarMode(SidebarMode == "Expanded" and "Dynamic" or "Expanded")
    end)

    function Window:SetTitle(title)
        WindowTitle = tostring(title)
        TitleLabel.Text = WindowTitle
    end

    function Window:SetVisible(visible)
        if visible then Window:Restore() else Window:Minimize() end
    end

    function Window:SetSearch(query)
        if SearchBox then SearchBox.Text = tostring(query or "") end
    end

    local normalPosition = MainFrame.Position
    local normalSize = MainFrame.Size
    function Window:SetMaximized(maximized)
        if maximized and not self.Maximized then
            normalPosition = MainFrame.Position
            normalSize = MainFrame.Size
        end
        self.Maximized = maximized == true
        local viewport = getViewport()
        local scale = math.max(Library.DPIScale, 0.01)
        local margin = 8 / scale
        Utility:Tween(MainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = self.Maximized and UDim2.fromOffset(margin, margin) or normalPosition,
            Size = self.Maximized and UDim2.fromOffset(viewport.X / scale - margin * 2, viewport.Y / scale - margin * 2) or normalSize
        })
    end

    local TooltipFrame = Utility:Create("Frame", {
        Name = "Tooltip", Parent = ScreenGui, BackgroundColor3 = Library.Theme.Secondary,
        BackgroundTransparency = 0.04, AutomaticSize = Enum.AutomaticSize.XY,
        Visible = false, ZIndex = 950, BorderSizePixel = 0
    })
    Utility:RegisterProperty(TooltipFrame, "BackgroundColor3", "Secondary")
    Utility:Create("UICorner", {Parent = TooltipFrame, CornerRadius = UDim.new(0, 6)})
    local tooltipStroke = Utility:Create("UIStroke", {Parent = TooltipFrame, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(tooltipStroke, "Color", "Stroke")
    Utility:Create("UIPadding", {
        Parent = TooltipFrame, PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9),
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7)
    })
    local TooltipText = Utility:Create("TextLabel", {
        Parent = TooltipFrame, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.fromOffset(220, 0), TextWrapped = true, TextColor3 = Library.Theme.Text,
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 951
    })
    Utility:RegisterProperty(TooltipText, "TextColor3", "Text")
    local activeTooltipTarget = nil

    function Window:ShowTooltip(text, position, target)
        text = tostring(text or "")
        if text == "" then return end
        activeTooltipTarget = target
        TooltipText.Text = text
        TooltipFrame.Visible = true
        task.defer(function()
            if not TooltipFrame.Visible or (target and activeTooltipTarget ~= target) then return end
            local viewport = getViewport()
            local size = TooltipFrame.AbsoluteSize
            local x = math.clamp((position and position.X or 0) + 14, 8, math.max(8, viewport.X - size.X - 8))
            local y = math.clamp((position and position.Y or 0) + 16, 8, math.max(8, viewport.Y - size.Y - 8))
            TooltipFrame.Position = UDim2.fromOffset(x, y)
        end)
    end

    function Window:HideTooltip(target)
        if target and activeTooltipTarget ~= target then return end
        activeTooltipTarget = nil
        TooltipFrame.Visible = false
    end

    function Window:AttachTooltip(target, text)
        if not target or not target:IsA("GuiObject") or text == nil or tostring(text) == "" then return nil end
        local touching = false
        Library:Connect(target.MouseEnter, function()
            local mouse = UserInputService:GetMouseLocation()
            Window:ShowTooltip(text, mouse, target)
        end)
        Library:Connect(target.MouseMoved, function(x, y)
            if activeTooltipTarget == target then Window:ShowTooltip(text, Vector2.new(x, y), target) end
        end)
        Library:Connect(target.MouseLeave, function() Window:HideTooltip(target) end)
        Library:Connect(target.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            touching = true
            task.delay(0.45, function()
                if touching and target.Parent and not Library.Unloaded then Window:ShowTooltip(text, input.Position, target) end
            end)
        end)
        Library:Connect(target.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.Touch then touching = false Window:HideTooltip(target) end
        end)
        return {Show = function() Window:ShowTooltip(text, target.AbsolutePosition + target.AbsoluteSize, target) end,
            Hide = function() Window:HideTooltip(target) end,
            Set = function(_, value) text = tostring(value or "") end}
    end

    function Window:Dialog(dialogOptions)
        dialogOptions = dialogOptions or {}
        local overlay = Utility:Create("TextButton", {
            Name = "DialogOverlay", Parent = ScreenGui, BackgroundColor3 = Color3.new(0,0,0),
            BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), Text = "",
            AutoButtonColor = false, ZIndex = 800
        })
        local dialogLayoutWidth = getViewport().X / math.max(Library.DPIScale, 0.01)
        local card = Utility:Create("Frame", {
            Parent = overlay, AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
            Size = UDim2.fromOffset(math.max(1, math.min(IsMobile and 320 or 400, dialogLayoutWidth - 24)), 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Library.Theme.Main,
            BorderSizePixel = 0, ZIndex = 801
        })
        Utility:RegisterProperty(card, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0,10)})
        local cardStroke = Utility:Create("UIStroke", {Parent = card, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(cardStroke, "Color", "Stroke")
        Utility:Create("UIPadding", {
            Parent = card, PaddingTop = UDim.new(0,16), PaddingBottom = UDim.new(0,16),
            PaddingLeft = UDim.new(0,16), PaddingRight = UDim.new(0,16)
        })
        Utility:Create("UIListLayout", {Parent = card, Padding = UDim.new(0,10), SortOrder = Enum.SortOrder.LayoutOrder})
        local dialogTitle = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,24),
            Text = tostring(dialogOptions.Title or "Confirm"), TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 802
        })
        Utility:RegisterProperty(dialogTitle, "TextColor3", "Text")
        local dialogContent = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,20), AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(dialogOptions.Content or ""), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
            TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 802
        })
        Utility:RegisterProperty(dialogContent, "TextColor3", "SubText")
        local actionBar = Utility:Create("Frame", {Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,34), ZIndex = 802})
        Utility:Create("UIListLayout", {Parent = actionBar, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0,8)})
        local closed = false
        local function close()
            if closed then return end
            closed = true
            Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 1}, function() if overlay.Parent then overlay:Destroy() end end)
            if Library.ReducedMotion and overlay.Parent then overlay:Destroy() end
        end
        local actions = dialogOptions.Actions or {{Name = "Okay"}}
        for _, action in ipairs(actions) do
            local actionButton = Utility:Create("TextButton", {
                Parent = actionBar, BackgroundColor3 = action.Primary and Library.Theme.Accent or Library.Theme.Hover,
                Size = UDim2.fromOffset(90,32), Text = tostring(action.Name or "Okay"), TextColor3 = Library.Theme.Text,
                Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 803
            })
            Utility:Create("UICorner", {Parent = actionButton, CornerRadius = UDim.new(0,6)})
            Library:Connect(actionButton.MouseButton1Click, function()
                Utility:SafeCall(action.Callback)
                if action.Close ~= false then close() end
            end)
        end
        Library:Connect(overlay.MouseButton1Click, function() if dialogOptions.Dismissable ~= false then close() end end)
        Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 0.35})
        return {Close = close, Frame = card}
    end

    function Window:Prompt(promptOptions)
        promptOptions = promptOptions or {}
        local overlay = Utility:Create("TextButton", {
            Name = "PromptOverlay", Parent = ScreenGui, BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "",
            AutoButtonColor = false, ZIndex = 820
        })
        local layoutWidth = getViewport().X / math.max(Library.DPIScale, 0.01)
        local card = Utility:Create("Frame", {
            Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(math.max(1, math.min(IsMobile and 320 or 420, layoutWidth - 24)), 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Library.Theme.Main,
            BorderSizePixel = 0, ZIndex = 821
        })
        Utility:RegisterProperty(card, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 10)})
        local stroke = Utility:Create("UIStroke", {Parent = card, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(stroke, "Color", "Stroke")
        Utility:Create("UIPadding", {
            Parent = card, PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16),
            PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)
        })
        Utility:Create("UIListLayout", {Parent = card, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder})
        local title = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
            Text = tostring(promptOptions.Title or "Enter a value"), TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 822
        })
        Utility:RegisterProperty(title, "TextColor3", "Text")
        if promptOptions.Content then
            local content = Utility:Create("TextLabel", {
                Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y,
                Text = tostring(promptOptions.Content), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
                TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 822
            })
            Utility:RegisterProperty(content, "TextColor3", "SubText")
        end
        local input = Utility:Create("TextBox", {
            Parent = card, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, 38),
            Text = tostring(promptOptions.Default or ""), PlaceholderText = tostring(promptOptions.Placeholder or "Type here..."),
            ClearTextOnFocus = false, TextColor3 = Library.Theme.Text, PlaceholderColor3 = Library.Theme.SubText,
            Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 822, BorderSizePixel = 0
        })
        Utility:RegisterProperty(input, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(input, "TextColor3", "Text")
        Utility:RegisterProperty(input, "PlaceholderColor3", "SubText")
        Utility:Create("UICorner", {Parent = input, CornerRadius = UDim.new(0, 6)})
        Utility:Create("UIPadding", {Parent = input, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
        local errorLabel = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Text = "", TextColor3 = Library.Theme.Error, Font = Enum.Font.Gotham, TextSize = 11,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 822
        })
        Utility:RegisterProperty(errorLabel, "TextColor3", "Error")
        local actions = Utility:Create("Frame", {Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), ZIndex = 822})
        Utility:Create("UIListLayout", {Parent = actions, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8)})
        local closed = false
        local function close(cancelled)
            if closed then return end
            closed = true
            if cancelled then Utility:SafeCall(promptOptions.OnCancel) end
            Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 1}, function()
                if overlay.Parent then overlay:Destroy() end
            end)
            if Library.ReducedMotion and overlay.Parent then overlay:Destroy() end
        end
        local function submit()
            local value = input.Text
            if type(promptOptions.Validate) == "function" then
                local ok, valid, message = pcall(promptOptions.Validate, value)
                if not ok or valid == false then
                    errorLabel.Text = tostring(ok and message or valid)
                    errorLabel.Visible = true
                    return
                end
            end
            Utility:SafeCall(promptOptions.Callback, value)
            close(false)
        end
        local function makeAction(name, primary, callback)
            local button = Utility:Create("TextButton", {
                Parent = actions, BackgroundColor3 = primary and Library.Theme.Accent or Library.Theme.Hover,
                Size = UDim2.fromOffset(96, 32), Text = name, TextColor3 = Library.Theme.Text,
                Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 823
            })
            Utility:Create("UICorner", {Parent = button, CornerRadius = UDim.new(0, 6)})
            Library:Connect(button.MouseButton1Click, callback)
        end
        makeAction(tostring(promptOptions.CancelText or "Cancel"), false, function() close(true) end)
        makeAction(tostring(promptOptions.SubmitText or "Submit"), true, submit)
        Library:Connect(input.FocusLost, function(enterPressed) if enterPressed then submit() end end)
        Library:Connect(overlay.MouseButton1Click, function() if promptOptions.Dismissable ~= false then close(true) end end)
        Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 0.35})
        task.defer(function() if input.Parent then input:CaptureFocus() end end)
        return {Close = function() close(true) end, Submit = submit, Get = function() return input.Text end,
            Set = function(_, value) input.Text = tostring(value or "") end, Frame = card, Input = input}
    end

    local function ensureBuiltinKeybinds()
    if Library.__BuiltinKeybindsRegistered then
        return
    end

    Library.__BuiltinKeybindsRegistered = true

    local savedToggleKey = Library.Flags.__RenLibToggleUI
    if type(savedToggleKey) == "string" and Enum.KeyCode[savedToggleKey] then
        Library.ToggleKey = Enum.KeyCode[savedToggleKey]
    end

    local entry
    entry = {
        name = "Toggle UI",
        key = Library.ToggleKey.Name,
        default = Library.ToggleKey.Name,
        mode = "Press",
        flag = "__RenLibToggleUI",
        Virtual = true,
    }

    entry.controller = {
        Set = function(_, key)
            local keyName = typeof(key) == "EnumItem" and key.Name or tostring(key)

            if Enum.KeyCode[keyName] then
                Library.ToggleKey = Enum.KeyCode[keyName]
                Library.Flags.__RenLibToggleUI = keyName
                entry.key = keyName
            end
        end,

        Get = function()
            return entry.key
        end,

        GetKey = function()
            return entry.key
        end,
    }

    table.insert(Library.KeybindList, entry)
end

function Window:ShowKeybindManager()
    ensureBuiltinKeybinds()

    if self.KeybindManagerOverlay and self.KeybindManagerOverlay.Parent then
        if self.KeybindManagerRebuild then
            self.KeybindManagerRebuild()
        end

        self.KeybindManagerOverlay.Visible = true
        return self.KeybindManagerOverlay
    end
        local overlay = Utility:Create("TextButton", {
            Name = "KeybindManagerOverlay", Parent = ScreenGui, BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Text = "",
            AutoButtonColor = false, ZIndex = 840
        })
        self.KeybindManagerOverlay = overlay
        local card = Utility:Create("Frame", {
            Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(math.min(IsMobile and 330 or 460, getViewport().X - 24), math.min(430, getViewport().Y - 24)),
            BackgroundColor3 = Library.Theme.Main, BorderSizePixel = 0, ZIndex = 841
        })
        Utility:RegisterProperty(card, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 10)})
        local stroke = Utility:Create("UIStroke", {Parent = card, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(stroke, "Color", "Stroke")
        local title = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12),
            Size = UDim2.new(1, -72, 0, 28), Text = "Keybind manager", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 842
        })
        Utility:RegisterProperty(title, "TextColor3", "Text")
        local closeButton = Utility:Create("TextButton", {
            Parent = card, BackgroundColor3 = Library.Theme.Surface, Position = UDim2.new(1, -46, 0, 10),
            Size = UDim2.fromOffset(34, 30), Text = "×", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 843
        })
        Utility:RegisterProperty(closeButton, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(closeButton, "TextColor3", "Text")
        Utility:Create("UICorner", {Parent = closeButton, CornerRadius = UDim.new(0, 6)})
        local list = Utility:Create("ScrollingFrame", {
            Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 52),
            Size = UDim2.new(1, -24, 1, -104), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 842
        })
        Utility:RegisterProperty(list, "ScrollBarImageColor3", "Accent")
        Utility:Create("UIListLayout", {Parent = list, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder})
local function rebuild()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    local rendered = 0

    for _, entry in ipairs(Library.KeybindList) do
        local isVisibleEntry =
            entry.Virtual == true
            or (entry.controller and entry.controller.Holder and entry.controller.Holder.Parent)

        if isVisibleEntry then
            rendered += 1

            local row = Utility:Create("Frame", {
                Parent = list,
                BackgroundColor3 = Library.Theme.Surface,
                Size = UDim2.new(1, -4, 0, 42),
                BorderSizePixel = 0,
                ZIndex = 843
            })

            Utility:RegisterProperty(row, "BackgroundColor3", "Surface")
            Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 6)})

            local label = Utility:Create("TextLabel", {
                Parent = row,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -160, 1, 0),
                Text = entry.name .. "  ·  " .. entry.mode,
                TextColor3 = Library.Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 844
            })

            Utility:RegisterProperty(label, "TextColor3", "Text")

            local keyButton = Utility:Create("TextButton", {
                Parent = row,
                BackgroundColor3 = Library.Theme.Secondary,
                Position = UDim2.new(1, -142, 0.5, -14),
                Size = UDim2.fromOffset(76, 28),
                Text = tostring(entry.key),
                TextColor3 = Library.Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 844
            })

            Utility:RegisterProperty(keyButton, "BackgroundColor3", "Secondary")
            Utility:RegisterProperty(keyButton, "TextColor3", "Text")
            Utility:Create("UICorner", {Parent = keyButton, CornerRadius = UDim.new(0, 5)})

            local resetButton = Utility:Create("TextButton", {
                Parent = row,
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -60, 0.5, -14),
                Size = UDim2.fromOffset(52, 28),
                Text = "Reset",
                TextColor3 = Library.Theme.SubText,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                AutoButtonColor = false,
                ZIndex = 844
            })

            Utility:RegisterProperty(resetButton, "TextColor3", "SubText")

            Library:Connect(keyButton.MouseButton1Click, function()
                keyButton.Text = "Press…"

                local connection
                connection = UserInputService.InputBegan:Connect(function(input, processed)
                    if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end

                    connection:Disconnect()

                    if entry.controller and entry.controller.Set then
                        entry.controller:Set(input.KeyCode.Name)
                    end

                    entry.key = input.KeyCode.Name
                    keyButton.Text = input.KeyCode.Name
                end)
            end)

            Library:Connect(resetButton.MouseButton1Click, function()
                if entry.controller and entry.controller.Set then
                    entry.controller:Set(entry.default)
                end

                entry.key = entry.default
                keyButton.Text = tostring(entry.default)
            end)
        end
    end

    if rendered == 0 then
        local empty = Utility:Create("TextLabel", {
            Parent = list,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -8, 0, 90),
            Text = "No keybinds registered yet.\nUse CreateKeyPicker(...) to add shortcuts here.",
            TextColor3 = Library.Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 843
        })

        Utility:RegisterProperty(empty, "TextColor3", "SubText")
    end
end

self.KeybindManagerRebuild = rebuild
        local footer = Utility:Create("TextButton", {
            Parent = card, BackgroundColor3 = Library.Theme.Surface, Position = UDim2.new(0, 12, 1, -42),
            Size = UDim2.new(1, -24, 0, 30), Text = "Reset all keybinds", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 843
        })
        Utility:RegisterProperty(footer, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(footer, "TextColor3", "Text")
        Utility:Create("UICorner", {Parent = footer, CornerRadius = UDim.new(0, 6)})
        Library:Connect(footer.MouseButton1Click, function()
            for _, entry in ipairs(Library.KeybindList) do
                if entry.controller then entry.controller:Set(entry.default) end
            end
            rebuild()
        end)
        local function hide() overlay.Visible = false end
        Library:Connect(closeButton.MouseButton1Click, hide)
        Library:Connect(overlay.MouseButton1Click, hide)
        rebuild()
        return overlay
    end

    Library.KeybindManager = {Show = function() return Window:ShowKeybindManager() end,
        Hide = function() if Window.KeybindManagerOverlay then Window.KeybindManagerOverlay.Visible = false end end}

    Window:ApplyResponsiveLayout(true)
    Library:SetMaterialIntensity(options.MaterialIntensity or Library.MaterialIntensity)
    Library:SetMaterialMode(RequestedMaterialMode)
    if Camera then
        Library:Connect(Camera:GetPropertyChangedSignal("ViewportSize"), function()
            Window:ApplyResponsiveLayout(false)
        end)
    end

    -- MINIMIZE/RESTORE/CLOSE
    local visibilityToken = 0
    function Window:Minimize()
        if Library.IsMinimized then return end
        visibilityToken = visibilityToken + 1
        local token = visibilityToken
        Library.IsMinimized = true
        Library:RefreshMaterialVisibility()
        if IsMobile then
            if MobileToggleBtn then
                MobileToggleBtn.Visible = true
            end
        else
            MinimizedIcon.Visible = true
        end
        Utility:Tween(WindowScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.96})
        Utility:Tween(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}, function()
            if token == visibilityToken and Library.IsMinimized then MainFrame.Visible = false end
        end)
        if Library.ReducedMotion then MainFrame.Visible = false end
    end

    function Window:Restore()
        visibilityToken = visibilityToken + 1
        Library.IsMinimized = false
        Library:RefreshMaterialVisibility()
        MinimizedIcon.Visible = false
        MainFrame.Visible = true
        MainFrame.BackgroundTransparency = 1
        WindowScale.Scale = 0.96
        Utility:Tween(WindowScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
        local mainMaterial = Library.MaterialRegistry[MainFrame]
        local restoredTransparency = mainMaterial and (Library.MaterialMode == "Frosted" and mainMaterial.Frosted or mainMaterial.Solid) or 0
        Utility:Tween(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = restoredTransparency})
        if IsMobile and MobileToggleBtn then
            MobileToggleBtn.Visible = false
        end
    end

    function Window:Toggle()
        if Library.IsMinimized then
            Window:Restore()
        else
            Window:Minimize()
        end
    end

    function Window:Close()
        Library:Unload()
    end

    Library:Connect(MinimizeBtn.MouseButton1Click, function() Window:Minimize() end)
    Library:Connect(MinimizeBtn.MouseEnter, function()
        Utility:Tween(MinimizeBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Hover})
    end)
    Library:Connect(MinimizeBtn.MouseLeave, function()
        Utility:Tween(MinimizeBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Surface})
    end)
    local minimizedIconDrag = Utility:MakeDraggable(MinIconBtn, MinimizedIcon)
    Library:Connect(MinIconBtn.MouseButton1Click, function()
        if minimizedIconDrag:ConsumeDrag() then return end
        Window:Restore()
    end)
    Library:Connect(CloseBtn.MouseButton1Click, function() Window:Close() end)
    Library:Connect(CloseBtn.MouseEnter, function()
        Utility:Tween(CloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Error})
    end)
    Library:Connect(CloseBtn.MouseLeave, function()
        Utility:Tween(CloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Surface})
    end)

-- GLOBAL SEARCH: indexes controls and highlights matches without changing the
-- structural visibility of tabs, pages, sections, or controls. Navigation is
-- still owned exclusively by Window:SelectTab.
if SearchBox then
    local highlights = setmetatable({}, {__mode = "k"})
    local SearchStatus = Utility:Create("TextLabel", {
        Name = "SearchStatus", Parent = SearchBox, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(42, 18),
        BackgroundTransparency = 1, Text = "", TextColor3 = Library.Theme.SubText,
        Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = SearchBox.ZIndex + 1
    })
    Utility:RegisterProperty(SearchStatus, "TextColor3", "SubText")

    local function clearHighlights()
        for holder, stroke in pairs(highlights) do
            if stroke and stroke.Parent then stroke:Destroy() end
            highlights[holder] = nil
        end
    end

    local function highlight(holder)
        if not holder or not holder:IsA("GuiObject") or highlights[holder] then return end
        local stroke = Utility:Create("UIStroke", {
            Name = "RenSearchHighlight", Parent = holder, Color = Library.Theme.Accent,
            Thickness = 2, Transparency = 0.05, ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        })
        Utility:RegisterProperty(stroke, "Color", "Accent")
        highlights[holder] = stroke
    end

    function Window:FocusSearchResult(index)
        local count = #self.SearchResults
        if count == 0 then return false end
        index = ((tonumber(index) or self.SearchIndex or 0) - 1) % count + 1
        self.SearchIndex = index
        local result = self.SearchResults[index]
        self:SelectTab(result.Tab, {ResetScroll = false, Animate = true})
        SearchStatus.Text = tostring(index) .. "/" .. tostring(count)
        task.defer(function()
            local holder, page = result.Holder, result.Tab.Page
            if not holder or not holder.Parent or not page or not page.Parent then return end
            local localY = holder.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y
            page.CanvasPosition = Vector2.new(0, math.max(0, localY - 12))
            local stroke = highlights[holder]
            if stroke then
                stroke.Transparency = 0
                Utility:Tween(stroke, TweenInfo.new(0.45), {Transparency = 0.18})
            end
        end)
        return true
    end

    function Window:RefreshSearch(query)
        query = tostring(query or ""):lower():match("^%s*(.-)%s*$") or ""
        self.SearchQuery = query
        self.SearchIndex = 0
        self.SearchResults = {}
        clearHighlights()

        if query == "" then
            SearchStatus.Text = ""
            return self.SearchResults
        end

        local seen = {}
        for _, tab in ipairs(self.Tabs) do
            for _, section in ipairs(tab.Sections or {}) do
                for _, element in ipairs(section.Elements or {}) do
                    local holder = element.Holder
                    local haystack = table.concat({tab.Name or "", section.Name or "", element.Text or element.Name or ""}, " "):lower()
                    if holder and holder.Parent and haystack:find(query, 1, true) and not seen[holder] then
                        seen[holder] = true
                        table.insert(self.SearchResults, {Tab = tab, Section = section, Element = element, Holder = holder})
                        highlight(holder)
                        if element.NestedParentHolder then highlight(element.NestedParentHolder) end
                    end
                end
            end
        end

        SearchStatus.Text = #self.SearchResults == 0 and "0" or tostring(#self.SearchResults)
        return self.SearchResults
    end

    function Window:ClearSearch()
        SearchBox.Text = ""
        self:RefreshSearch("")
        return self
    end

    Library:Connect(SearchBox:GetPropertyChangedSignal("Text"), function()
        Window:RefreshSearch(SearchBox.Text)
    end)
    Library:Connect(SearchBox.FocusLost, function(enterPressed)
        if enterPressed and Window.SearchQuery ~= "" then
            Window:FocusSearchResult((Window.SearchIndex or 0) + 1)
        end
    end)
end

    -- NOTIFICATIONS
    function Library:Notify(notifyOpts)
        notifyOpts = notifyOpts or {}
        local Title = notifyOpts.Title or "Notification"
        local Content = notifyOpts.Content or ""
        local Duration = notifyOpts.Duration or 3
        local Emoji = notifyOpts.Emoji or EMOJIS.Info
        local Progress = notifyOpts.Progress
        local Actions = notifyOpts.Actions or {}

        local notifHeight = (IsMobile and 58 or 66) + (#Actions > 0 and 34 or 0)
        local NotifyFrame = Utility:Create("Frame", {
            Name = "Notify",
            Parent = NotifyArea,
            BackgroundColor3 = Library.Theme.Main,
            Size = UDim2.new(1, 0, 0, notifHeight),
            Position = UDim2.new(2, 0, 0, 0),
            ClipsDescendants = true,
            ZIndex = 201,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(NotifyFrame, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = NotifyFrame})
        local stroke = Utility:Create("UIStroke", {Parent = NotifyFrame, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(stroke, "Color", "Stroke")

        local titleText = Utility:Create("TextLabel", {
            Parent = NotifyFrame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 10),
            Size = UDim2.new(0, IsMobile and 28 or 36, 0, IsMobile and 28 or 36),
            Font = Enum.Font.GothamBold,
            Text = Emoji,
            TextColor3 = Library.Theme.Accent,
            TextSize = IsMobile and 18 or 24,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 202
        })
        Utility:Create("TextLabel", {
            Parent = NotifyFrame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, IsMobile and 44 or 58, 0, IsMobile and 8 or 12),
            Size = UDim2.new(1, IsMobile and -76 or -92, 0, 16),
            Font = Enum.Font.GothamBold,
            Text = Title,
            TextColor3 = Library.Theme.Text,
            TextSize = IsMobile and 12 or 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202
        })
        local contentText = Utility:Create("TextLabel", {
            Parent = NotifyFrame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, IsMobile and 44 or 58, 0, IsMobile and 24 or 30),
            Size = UDim2.new(1, IsMobile and -76 or -92, 0, #Actions > 0 and 26 or 28),
            Font = Enum.Font.Gotham,
            Text = Content,
            TextColor3 = Library.Theme.SubText,
            TextSize = IsMobile and 11 or 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 202
        })

        local closeButton = Utility:Create("TextButton", {
            Parent = NotifyFrame, BackgroundTransparency = 1,
            Position = UDim2.new(1, -30, 0, 6), Size = UDim2.fromOffset(24, 24),
            Text = "×", TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold,
            TextSize = 18, AutoButtonColor = false, ZIndex = 204
        })
        Utility:RegisterProperty(closeButton, "TextColor3", "SubText")

        -- Progress bar
        local progressBar = nil
        if Progress ~= nil then
            progressBar = Utility:Create("Frame", {
                Parent = NotifyFrame,
                BackgroundColor3 = Library.Theme.Accent,
                Position = UDim2.new(0, 0, 1, -4),
                Size = UDim2.new(Progress, 0, 0, 4),
                ZIndex = 203,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(progressBar, "BackgroundColor3", "Accent")
        end


        local Closed = false
        local function Close()
            if Closed then return end
            Closed = true
            Utility:Tween(NotifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 300, 0, 0),
                BackgroundTransparency = 1
            }, function()
                if NotifyFrame.Parent then NotifyFrame:Destroy() end
            end)
            if Library.ReducedMotion and NotifyFrame.Parent then NotifyFrame:Destroy() end
        end

        Library:Connect(closeButton.MouseButton1Click, Close)

        if #Actions > 0 then
            local actionBar = Utility:Create("Frame", {
                Parent = NotifyFrame, BackgroundTransparency = 1,
                Position = UDim2.new(0, IsMobile and 44 or 58, 1, -38),
                Size = UDim2.new(1, IsMobile and -52 or -68, 0, 28), ZIndex = 203
            })
            Utility:Create("UIListLayout", {
                Parent = actionBar, FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6)
            })
            for _, action in ipairs(Actions) do
                local actionButton = Utility:Create("TextButton", {
                    Parent = actionBar, BackgroundColor3 = Library.Theme.Hover,
                    Size = UDim2.fromOffset(math.max(64, TextService:GetTextSize(tostring(action.Name or "Action"), 11, Enum.Font.GothamBold, Vector2.new(160, 24)).X + 20), 26),
                    Text = tostring(action.Name or "Action"), TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
                    BorderSizePixel = 0, ZIndex = 204
                })
                Utility:RegisterProperty(actionButton, "BackgroundColor3", "Hover")
                Utility:RegisterProperty(actionButton, "TextColor3", "Text")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = actionButton})
                Library:Connect(actionButton.MouseButton1Click, function()
                    Utility:SafeCall(action.Callback)
                    if action.Close ~= false then Close() end
                end)
            end
        end

        NotifyFrame.Position = UDim2.new(1, 300, 0, 0)
        Utility:Tween(NotifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        })

        if Duration and Duration > 0 then
            if not progressBar then
                progressBar = Utility:Create("Frame", {
                    Parent = NotifyFrame, BackgroundColor3 = Library.Theme.Accent,
                    Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3),
                    BorderSizePixel = 0, ZIndex = 203
                })
                Utility:RegisterProperty(progressBar, "BackgroundColor3", "Accent")
                Utility:Tween(progressBar, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
            end
            task.delay(Duration, Close)
        end
        return {
            Close = Close,
            SetProgress = function(self, amount)
                if progressBar then progressBar.Size = UDim2.new(math.clamp(amount, 0, 1), 0, 0, 4) end
            end,
            SetContent = function(self, text) contentText.Text = tostring(text) end,
            SetTitle = function(self, text) titleText.Text = tostring(text) end
        }
    end

    --// TABS
    function Window:CreateTabCategory(name)
        self.NextNavOrder = self.NextNavOrder + 1
        local category = Utility:Create("TextLabel", {
            Name = "Category_" .. tostring(name), Parent = TabContainer,
            BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, isCompact and 0 or 20),
            Text = string.upper(tostring(name or "")), TextColor3 = Library.Theme.SubText,
            Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = isCompact and 1 or 0,
            ZIndex = 5, Visible = true, LayoutOrder = self.NextNavOrder
        })
        Utility:RegisterProperty(category, "TextColor3", "SubText")
        local categoryEntry = {Label = category, Tabs = {}}
        table.insert(self.TabCategories, categoryEntry)
        self.CurrentTabCategory = categoryEntry
        return category
    end

    function Window:CreateTab(options)
        options = options or {}
        local Name = options.Name or "Tab"
        local Emoji = options.Emoji
        local IsSettings = options.IsSettings or false
        local IsOverview = options.IsOverview or false
        local Icon = Utility:NormalizeAssetId(options.Icon)
        self.NextNavOrder = self.NextNavOrder + 1
        if not Icon and Emoji == nil and not IsSettings and not IsOverview then Icon = ICONS.Home end

        local Tab = {
            Name = Name,
            Active = false,
            Sections = {},
            HeaderHeight = 0,
            ResponsiveCallbacks = {},
            IsSettings = IsSettings,
            IsOverview = IsOverview,
            Page = nil,
            TabBtn = nil,
            TabLabel = nil
        }
        if not IsSettings and not IsOverview and self.CurrentTabCategory then
            table.insert(self.CurrentTabCategory.Tabs, Tab)
        end

        local TabBtn, TabEmoji, Indicator, TabGradient
        local tabBtnSize = IsMobile and 38 or 42

        if not IsSettings and not IsOverview then
            TabBtn = Utility:Create("TextButton", {
                Name = Name,
                Parent = TabContainer,
                BackgroundColor3 = Library.Theme.Accent,
                BackgroundTransparency = 0.64,
                Size = (IsMobile or isCompact) and UDim2.fromOffset(tabBtnSize, tabBtnSize) or UDim2.new(1, 0, 0, tabBtnSize),
                AutoButtonColor = false,
                Text = "",
                ZIndex = 5,
                LayoutOrder = self.NextNavOrder,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(TabBtn, "BackgroundColor3", "Accent")
            Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = TabBtn})
            local tabStroke = Utility:Create("UIStroke", {Parent = TabBtn, Color = Library.Theme.Stroke, Thickness = 1})
            Utility:RegisterProperty(tabStroke, "Color", "Stroke")
            TabGradient = Utility:Create("UIGradient", {Parent = TabBtn, Rotation = 18})
            Utility:RegisterGradient(TabGradient, "Accent", "Accent2", "Accent3")

            if Icon then
                TabEmoji = Utility:Create("ImageLabel", {
                    Parent = TabBtn,
                    BackgroundTransparency = 1,
                    Position = (IsMobile or isCompact) and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(6, 5),
                    Size = (IsMobile or isCompact) and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
                    Image = Icon,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 6
                })
                Utility:RegisterProperty(TabEmoji, "ImageColor3", "SubText")
            else
                TabEmoji = Utility:Create("TextLabel", {
                    Parent = TabBtn,
                    BackgroundTransparency = 1,
                    Position = (IsMobile or isCompact) and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(6, 5),
                    Size = (IsMobile or isCompact) and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
                    Font = Enum.Font.GothamBold,
                    Text = Emoji or "",
                    TextColor3 = Library.Theme.SubText,
                    TextSize = IsMobile and 16 or 20,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    ZIndex = 6
                })
                Utility:RegisterProperty(TabEmoji, "TextColor3", "SubText")
            end

            Indicator = Utility:Create("Frame", {
                Parent = TabBtn,
                BackgroundColor3 = Library.Theme.Accent,
                Position = UDim2.new(0, 3, 0.5, -9),
                Size = UDim2.new(0, 3, 0, 18),
                BackgroundTransparency = 1,
                ZIndex = 7,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(Indicator, "BackgroundColor3", "Accent")
            Utility:Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = Indicator})

            local TabLabel = Utility:Create("TextLabel", {
                Parent = TabBtn,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 48, 0, 0),
                Size = UDim2.new(1, -58, 1, 0),
                Font = Enum.Font.Gotham,
                Text = Name,
                TextColor3 = Library.Theme.SubText,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not (IsMobile or isCompact),
                ZIndex = 6
            })
            Utility:RegisterProperty(TabLabel, "TextColor3", "SubText")

            Tab.TabBtn = TabBtn
            Tab.TabEmoji = TabEmoji
            Tab.Indicator = Indicator
            Tab.TabLabel = TabLabel
            Tab.TabGradient = TabGradient
            Tab.TabStroke = tabStroke
        elseif IsOverview then
            TabBtn = OverviewBtn
            TabEmoji = OverviewIcon
            Indicator = OverviewIndicator
            Tab.TabBtn = OverviewBtn
            Tab.TabLabel = OverviewLabel
            Tab.TabEmoji = TabEmoji
            Tab.Indicator = Indicator
            Tab.TabStroke = overviewStroke
        else
            TabEmoji = SettingsEmoji
            Indicator = SettingsIndicator
            Tab.TabBtn = SettingsBtn
            Tab.TabLabel = SettingsLabel
            Tab.TabEmoji = TabEmoji
            Tab.Indicator = Indicator
            Tab.TabStroke = settingsStroke
        end

        function Tab:ApplyNavigationLayout(mobile, compact, animated)
            if self.IsSettings or self.IsOverview or not self.TabBtn then return end
            local iconOnly = mobile or compact
            applyLayout(self.TabBtn, {
                Size = iconOnly and UDim2.fromOffset(tabBtnSize, tabBtnSize) or UDim2.new(1, 0, 0, tabBtnSize)
            }, animated)
            if self.TabEmoji then
                applyLayout(self.TabEmoji, {
                    Position = iconOnly and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(6, 5),
                    Size = iconOnly and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32)
                }, animated)
            end
            setNavigationLabel(self.TabLabel, not iconOnly, animated)
        end

        local useSingleColumn = IsMobile
        local Page = Utility:Create("ScrollingFrame", {
            Name = Name,
            Parent = Pages,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, IsMobile and 10 or 20, 0, IsMobile and 92 or 70),
            Size = UDim2.new(1, IsMobile and -20 or -40, 1, IsMobile and -102 or -90),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.Theme.Accent,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
            VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
            Active = true,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            ZIndex = 2,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(Page, "ScrollBarImageColor3", "Accent")
        Tab.Page = Page

        local LeftColumn = Utility:Create("Frame", {
            Name = "Left",
            Parent = Page,
            BackgroundTransparency = 1,
            Size = useSingleColumn and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -6, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            ZIndex = 2,
            BorderSizePixel = 0
        })
        local RightColumn = Utility:Create("Frame", {
            Name = "Right",
            Parent = Page,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -6, 1, 0),
            Position = UDim2.new(0.5, 6, 0, 0),
            Visible = not useSingleColumn,
            ZIndex = 2,
            BorderSizePixel = 0
        })
        local LeftLayout = Utility:Create("UIListLayout", {
            Parent = LeftColumn,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, useSingleColumn and 10 or 12)
        })
        local RightLayout = Utility:Create("UIListLayout", {
            Parent = RightColumn,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 12)
        })

        local function UpdateCanvas()
            local LeftH = LeftLayout.AbsoluteContentSize.Y
            local RightH = useSingleColumn and 0 or RightLayout.AbsoluteContentSize.Y
            Page.CanvasSize = UDim2.new(0, 0, 0, Tab.HeaderHeight + math.max(LeftH, RightH) + 20)
        end
        Library:Connect(LeftLayout:GetPropertyChangedSignal("AbsoluteContentSize"), UpdateCanvas)
        Library:Connect(RightLayout:GetPropertyChangedSignal("AbsoluteContentSize"), UpdateCanvas)

        function Tab:ApplyResponsiveLayout(mobile, topInset)
            useSingleColumn = mobile
            local pageTop = mobile and ((topInset or 88) + 4) or 70
            Page.Position = UDim2.new(0, mobile and 8 or 20, 0, pageTop)
            Page.Size = UDim2.new(1, mobile and -16 or -40, 1, -(pageTop + 10))
            Page.ScrollBarThickness = mobile and 3 or 2
            LeftColumn.Size = mobile and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -6, 1, 0)
            LeftColumn.Position = UDim2.new(0, 0, 0, Tab.HeaderHeight)
            RightColumn.Size = UDim2.new(0.5, -6, 1, 0)
            RightColumn.Position = UDim2.new(0.5, 6, 0, Tab.HeaderHeight)
            RightColumn.Visible = not mobile
            LeftLayout.Padding = UDim.new(0, mobile and 10 or 12)
            for _, section in ipairs(Tab.Sections) do
                if mobile then
                    section.SectionFrame.Parent = LeftColumn
                elseif section.RequestedSide == "Right" then
                    section.SectionFrame.Parent = RightColumn
                elseif section.RequestedSide == "Auto" and LeftLayout.AbsoluteContentSize.Y > RightLayout.AbsoluteContentSize.Y then
                    section.SectionFrame.Parent = RightColumn
                else
                    section.SectionFrame.Parent = LeftColumn
                end
            end
            UpdateCanvas()
            task.defer(UpdateCanvas)
            for _, callback in ipairs(Tab.ResponsiveCallbacks) do
                Utility:SafeCall(callback, mobile, Page.AbsoluteSize)
            end
        end

        function Tab:OnResponsive(callback)
            table.insert(self.ResponsiveCallbacks, callback)
            return self
        end

        function Tab:SetHeader(frame, height)
            frame.Parent = Page
            frame.LayoutOrder = -1000
            self.HeaderHeight = math.max(0, tonumber(height) or 0)
            LeftColumn.Position = UDim2.new(0, 0, 0, self.HeaderHeight)
            RightColumn.Position = UDim2.new(0.5, 6, 0, self.HeaderHeight)
            UpdateCanvas()
            return frame
        end

        function Tab:ApplyActiveVisual(active, animated)
            local tweenInfo = TweenInfo.new(animated == false and 0 or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            if Tab.TabBtn then
                Utility:Tween(Tab.TabBtn, tweenInfo, {BackgroundTransparency = active and 1 or 0.64})
            end
            if Tab.TabStroke then
                Utility:Tween(Tab.TabStroke, tweenInfo, {
                    Color = active and Library.Theme.Accent or Library.Theme.Stroke,
                    Transparency = active and 0.08 or 0.24
                })
            end
            if Tab.TabLabel then
                Utility:Tween(Tab.TabLabel, tweenInfo, {TextColor3 = active and Library.Theme.Text or Library.Theme.SubText})
            end
            if TabEmoji then
                if TabEmoji:IsA("TextLabel") then
                    Utility:Tween(TabEmoji, tweenInfo, {TextColor3 = active and Library.Theme.Text or Library.Theme.SubText})
                elseif TabEmoji:IsA("ImageLabel") then
                    Utility:Tween(TabEmoji, tweenInfo, {ImageColor3 = active and Library.Theme.Text or Library.Theme.SubText})
                end
            end
            if Indicator then Indicator.BackgroundTransparency = 1 end
        end

        function Tab:Activate(selectOptions)
            selectOptions = selectOptions or {}
            if selectOptions.ResetScroll == nil then selectOptions.ResetScroll = true end
            return Window:SelectTab(Tab, selectOptions)
        end

        function Tab:Deactivate()
            if Window.ActiveTab == Tab then return Window:SelectTab(nil) end
            return true
        end

        if TabBtn then
            Library:Connect(TabBtn.MouseButton1Click, function() Tab:Activate() end)
            Library:Connect(TabBtn.MouseEnter, function()
                if not Tab.Active then Utility:Tween(TabBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.4}) end
            end)
            Library:Connect(TabBtn.MouseLeave, function()
                if not Tab.Active then Utility:Tween(TabBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.64}) end
            end)
        end

        table.insert(Window.Tabs, Tab)
        Tab:ApplyResponsiveLayout(IsMobile, Window.ContentTopInset)
        if not IsSettings and not IsOverview and not Window.ActiveTab then
            Tab:Activate()
        end

        --// SECTIONS
        function Tab:CreateSection(options)
            options = options or {}
            local SectionName = options.Name or "Section"
            local Side = options.Side or "Auto"
            local SectionIcon = Utility:NormalizeAssetId(options.Icon)

            local ParentCol = LeftColumn
            if not useSingleColumn then
                if Side == "Right" then
                    ParentCol = RightColumn
                elseif Side == "Auto" then
                    if LeftLayout.AbsoluteContentSize.Y > RightLayout.AbsoluteContentSize.Y then
                        ParentCol = RightColumn
                    end
                end
            end

            local Section = { Name = SectionName, RequestedSide = Side, Elements = {}, SectionFrame = nil, ContentContainer = nil }
            table.insert(Tab.Sections, Section)

            local SectionFrame = Utility:Create("Frame", {
                Name = SectionName,
                Parent = ParentCol,
                BackgroundColor3 = Library.Theme.Surface,
                Size = UDim2.new(1, 0, 0, 50),
                -- Allow expanded controls to render above the section frame.
                ClipsDescendants = false,
                ZIndex = 3,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(SectionFrame, "BackgroundColor3", "Surface")
            Utility:RegisterMaterial(SectionFrame, 0.24, 0)
            Utility:Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = SectionFrame})
            local sectionStroke = Utility:Create("UIStroke", {
                Parent = SectionFrame,
                Color = Library.Theme.Stroke,
                Thickness = 1
            })
            Utility:RegisterProperty(sectionStroke, "Color", "Stroke")
            local sectionGradient = Utility:Create("UIGradient", {Parent = SectionFrame, Rotation = 105})
            Utility:RegisterGradient(sectionGradient, "SurfaceAlt", "Surface")
            local sectionAccent = Utility:Create("Frame", {
                Parent = SectionFrame,
                BackgroundColor3 = Library.Theme.Accent,
                Position = UDim2.fromOffset(12, 12),
                Size = UDim2.fromOffset(3, 16),
                BorderSizePixel = 0,
                ZIndex = 5
            })
            Utility:RegisterProperty(sectionAccent, "BackgroundColor3", "Accent")
            Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = sectionAccent})
            if SectionIcon then
                sectionAccent.Visible = false
                local sectionIcon = Utility:Create("ImageLabel", {
                    Parent = SectionFrame, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(20, 20),
                    Image = SectionIcon, ImageColor3 = Library.Theme.Accent,
                    ScaleType = Enum.ScaleType.Fit, ZIndex = 5
                })
                Utility:RegisterProperty(sectionIcon, "ImageColor3", "Accent")
            end
            Section.SectionFrame = SectionFrame

            local Head = Utility:Create("TextLabel", {
                Parent = SectionFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, SectionIcon and 38 or 22, 0, 10),
                Size = UDim2.new(1, SectionIcon and -50 or -34, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = SectionName,
                TextColor3 = Library.Theme.Text,
                TextSize = IsMobile and 12 or 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 4
            })
            Utility:RegisterProperty(Head, "TextColor3", "Text")

            local ContentContainer = Utility:Create("Frame", {
                Parent = SectionFrame,
                BackgroundColor3 = Library.Theme.Main,
                BackgroundTransparency = 0.12,
                Position = UDim2.new(0, 8, 0, IsMobile and 34 or 36),
                Size = UDim2.new(1, -16, 0, 0),
                ZIndex = 4,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(ContentContainer, "BackgroundColor3", "Main")
            Utility:RegisterMaterial(ContentContainer, 0.4, 0.12)
            Utility:Create("UICorner", {CornerRadius = UDim.new(0, 9), Parent = ContentContainer})
            local contentStroke = Utility:Create("UIStroke", {Parent = ContentContainer, Color = Library.Theme.Divider, Thickness = 1, Transparency = 0.2})
            Utility:RegisterProperty(contentStroke, "Color", "Divider")
            Utility:Create("UIPadding", {
                Parent = ContentContainer,
                PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
                PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)
            })
            Section.ContentContainer = ContentContainer

            local ContentLayout = Utility:Create("UIListLayout", {
                Parent = ContentContainer,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, IsMobile and 6 or 8)
            })

            local function RefreshLayout()
                ContentContainer.Size = UDim2.new(1, -16, 0, ContentLayout.AbsoluteContentSize.Y + 16)
                SectionFrame.Size = UDim2.new(1, 0, 0, ContentLayout.AbsoluteContentSize.Y + (IsMobile and 58 or 60))
            end

            Library:Connect(ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                ContentContainer.Size = UDim2.new(1, -16, 0, ContentLayout.AbsoluteContentSize.Y + 16)
                Utility:Tween(SectionFrame, TweenInfo.new(0.2), {
                    Size = UDim2.new(1, 0, 0, ContentLayout.AbsoluteContentSize.Y + (IsMobile and 58 or 60))
                })
            end)

            local function addElement(element)
                table.insert(Section.Elements, element)
                -- Only re-parent if the holder isn't already in ContentContainer
                if element.Holder and element.Holder.Parent ~= ContentContainer then
                    element.Holder.Parent = ContentContainer
                end
                if Window.SearchQuery ~= "" and Window.RefreshSearch then
                    task.defer(function()
                        if not Library.Unloaded then Window:RefreshSearch(Window.SearchQuery) end
                    end)
                end
            end

            local function finishController(controller, holder, name, tooltip)
                controller = controller or {}
                controller.Holder = holder
                controller.Name = name
                controller.Locked = false
                if holder:IsA("GuiObject") and holder.BackgroundTransparency < 0.98 and not Library.MaterialRegistry[holder] then
                    Utility:RegisterMaterial(holder, math.min(0.48, holder.BackgroundTransparency + 0.3), holder.BackgroundTransparency)
                end
                local nestedHost, nestedLayout
                local nestedBaseHeight = holder.Size.Y.Offset
                local nestedVisible = true

                local function refreshNested()
                    if not nestedHost then return end
                    local nestedHeight = nestedVisible and (nestedLayout.AbsoluteContentSize.Y + 16) or 0
                    nestedHost.Visible = nestedVisible
                    nestedHost.Size = UDim2.new(1, -16, 0, nestedHeight)
                    holder.Size = UDim2.new(holder.Size.X.Scale, holder.Size.X.Offset, 0, nestedBaseHeight + (nestedHeight > 0 and nestedHeight + 8 or 0))
                    RefreshLayout()
                end

                function controller:AddNested(childController)
                    if not childController or not childController.Holder then return self end
                    if not nestedHost then
                        holder.ClipsDescendants = true
                        nestedHost = Utility:Create("Frame", {
                            Name = "NestedControls", Parent = holder, BackgroundColor3 = Library.Theme.Main,
                            BackgroundTransparency = 0.22, Position = UDim2.new(0, 8, 0, nestedBaseHeight),
                            Size = UDim2.new(1, -16, 0, 0), BorderSizePixel = 0,
                            ClipsDescendants = true, ZIndex = holder.ZIndex + 2
                        })
                        Utility:RegisterProperty(nestedHost, "BackgroundColor3", "Main")
                        Utility:RegisterMaterial(nestedHost, 0.48, 0.22)
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = nestedHost})
                        local nestedStroke = Utility:Create("UIStroke", {Parent = nestedHost, Color = Library.Theme.Divider, Thickness = 1, Transparency = 0.15})
                        Utility:RegisterProperty(nestedStroke, "Color", "Divider")
                        Utility:Create("UIPadding", {
                            Parent = nestedHost, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
                            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)
                        })
                        nestedLayout = Utility:Create("UIListLayout", {
                            Parent = nestedHost, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)
                        })
                        Library:Connect(nestedLayout:GetPropertyChangedSignal("AbsoluteContentSize"), refreshNested)
                    end
                    childController.Holder.Parent = nestedHost
                    childController.NestedParent = self
                    for _, sectionElement in ipairs(Section.Elements) do
                        if sectionElement.Holder == childController.Holder then
                            sectionElement.NestedParentHolder = holder
                            break
                        end
                    end
                    childController.Holder.LayoutOrder = #nestedHost:GetChildren()
                    Library:Connect(childController.Holder:GetPropertyChangedSignal("Size"), refreshNested)
                    task.defer(refreshNested)
                    return self
                end

                function controller:SetNestedVisible(visible)
                    nestedVisible = visible == true
                    refreshNested()
                    return self
                end
                local blocker
                local loadingOverlay
                local loadingToken = 0
                function controller:SetVisible(visible)
                    holder.Visible = visible == true
                    RefreshLayout()
                end
                function controller:Destroy()
                    holder:Destroy()
                    RefreshLayout()
                end
                function controller:SetLocked(locked)
                    self.Locked = locked == true
                    if self.Locked and not blocker then
                        blocker = Utility:Create("TextButton", {
                            Name = "RenLibLock",
                            Parent = holder,
                            BackgroundColor3 = Library.Theme.Main,
                            BackgroundTransparency = 0.35,
                            Size = UDim2.fromScale(1, 1),
                            Text = EMOJIS.Lock,
                            TextColor3 = Library.Theme.SubText,
                            TextSize = 14,
                            AutoButtonColor = false,
                            ZIndex = 100
                        })
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = blocker})
                    elseif blocker then
                        blocker:Destroy()
                        blocker = nil
                    end
                end
                function controller:SetLoading(loading, message)
                    loadingToken = loadingToken + 1
                    local token = loadingToken
                    if loading == true then
                        if not loadingOverlay then
                            loadingOverlay = Utility:Create("Frame", {
                                Name = "RenLibLoading", Parent = holder, BackgroundColor3 = Library.Theme.Main,
                                BackgroundTransparency = 0.18, Size = UDim2.fromScale(1, 1),
                                BorderSizePixel = 0, ZIndex = 110
                            })
                            Utility:RegisterProperty(loadingOverlay, "BackgroundColor3", "Main")
                            Utility:Create("UICorner", {Parent = loadingOverlay, CornerRadius = UDim.new(0, 6)})
                            local loadingText = Utility:Create("TextLabel", {
                                Name = "Status", Parent = loadingOverlay, BackgroundTransparency = 1,
                                Size = UDim2.fromScale(1, 1), Text = tostring(message or "Loading…"),
                                TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold,
                                TextSize = 12, ZIndex = 111
                            })
                            Utility:RegisterProperty(loadingText, "TextColor3", "Text")
                        else
                            loadingOverlay.Status.Text = tostring(message or "Loading…")
                            loadingOverlay.Status.TextTransparency = 0
                            loadingOverlay.Visible = true
                        end
                        task.spawn(function()
                            local dim = false
                            while token == loadingToken and loadingOverlay and loadingOverlay.Parent and not Library.Unloaded do
                                dim = not dim
                                Utility:Tween(loadingOverlay.Status, TweenInfo.new(0.45), {TextTransparency = dim and 0.45 or 0})
                                task.wait(0.5)
                            end
                        end)
                    elseif loadingOverlay then
                        loadingOverlay.Visible = false
                    end
                    return self
                end
                function controller:SetTooltip(text)
                    self.Tooltip = tostring(text or "")
                    if self._TooltipAttached then
                        self._TooltipAttached:Set(self.Tooltip)
                    elseif self.Tooltip ~= "" then
                        self._TooltipAttached = Window:AttachTooltip(holder, self.Tooltip)
                    end
                    return self
                end
                function controller:Lock() self:SetLocked(true) end
                function controller:Unlock() self:SetLocked(false) end
                if tooltip ~= nil then controller:SetTooltip(tooltip) end
                return controller
            end

            -- TEXT INPUT
            function Section:CreateInput(options)
                options = options or {}
                local name = options.Name or "Input"
                local flag = options.Flag or name
                local value = tostring(Library.Flags[flag] ~= nil and Library.Flags[flag] or options.Default or "")
                local listeners = {}
                local multiline = options.MultiLine == true
                local container = Utility:Create("Frame", {
                    Name = name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, multiline and 82 or 44),
                    BorderSizePixel = 0,
                    ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local inputStroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(inputStroke, "Color", "Stroke")
                local box = Utility:Create("TextBox", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, multiline and 8 or 0),
                    Size = UDim2.new(1, -24, 1, multiline and -16 or 0),
                    ClearTextOnFocus = false,
                    MultiLine = multiline,
                    PlaceholderText = options.Placeholder or name,
                    Text = value,
                    TextColor3 = Library.Theme.Text,
                    PlaceholderColor3 = Library.Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
                    TextWrapped = multiline,
                    ZIndex = 6
                })
                Utility:RegisterProperty(box, "TextColor3", "Text")
                Utility:RegisterProperty(box, "PlaceholderColor3", "SubText")

                local function setValue(nextValue, fire)
                    value = tostring(nextValue or "")
                    if options.Numeric then
                        value = value:gsub("[^%d%.%-]", "")
                    end
                    box.Text = value
                    Library.Flags[flag] = options.Numeric and tonumber(value) or value
                    if fire ~= false then
                        Utility:SafeCall(options.Callback, Library.Flags[flag])
                        for _, listener in ipairs(listeners) do Utility:SafeCall(listener, Library.Flags[flag]) end
                    end
                end
                Library.Flags[flag] = options.Numeric and tonumber(value) or value
                Library:Connect(box.Focused, function()
                    Utility:Tween(inputStroke, TweenInfo.new(0.18), {Color = Library.Theme.Accent})
                end)
                Library:Connect(box.FocusLost, function(enterPressed)
                    setValue(box.Text, true)
                    Utility:Tween(inputStroke, TweenInfo.new(0.18), {Color = Library.Theme.Stroke})
                    if options.Finished then Utility:SafeCall(options.Finished, Library.Flags[flag], enterPressed) end
                end)
                local controller = finishController({
                    Type = "Input",
                    Set = function(self, nextValue) setValue(nextValue, true) end,
                    Get = function() return Library.Flags[flag] end,
                    OnChanged = function(self, fn) table.insert(listeners, fn) end
                }, container, name, options.Tooltip)
                Library:RegisterOption(flag, controller)
                addElement({Holder = container, Text = name})
                return controller
            end

            function Section:CreateParagraph(options)
                if type(options) == "string" then options = {Content = options} end
                options = options or {}
                local title = options.Title or ""
                local content = options.Content or options.Text or ""
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, 56),
                    BorderSizePixel = 0,
                    ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local titleLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8),
                    Size = UDim2.new(1, -24, 0, title == "" and 0 or 18), Font = Enum.Font.GothamBold,
                    Text = title, TextColor3 = Library.Theme.Text, TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                local contentLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(12, title == "" and 8 or 29), Size = UDim2.new(1, -24, 0, 20),
                    Font = Enum.Font.Gotham, Text = content, TextColor3 = Library.Theme.SubText,
                    TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 6
                })
                Utility:RegisterProperty(titleLabel, "TextColor3", "Text")
                Utility:RegisterProperty(contentLabel, "TextColor3", "SubText")
                local function resize()
                    container.Size = UDim2.new(1, 0, 0, (title == "" and 16 or 37) + math.max(20, contentLabel.TextBounds.Y))
                    RefreshLayout()
                end
                Library:Connect(contentLabel:GetPropertyChangedSignal("TextBounds"), resize)
                local controller = finishController({
                    SetTitle = function(self, text) title = tostring(text); titleLabel.Text = title; resize() end,
                    SetContent = function(self, text) contentLabel.Text = tostring(text); resize() end
                }, container, title, options.Tooltip)
                addElement({Holder = container, Text = title .. " " .. content})
                task.defer(resize)
                return controller
            end

            function Section:CreateMetric(options)
                options = options or {}
                local name = tostring(options.Name or "Metric")
                local value = tostring(options.Value or "--")
                local detail = tostring(options.Detail or "")
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, detail ~= "" and 54 or 42),
                    BorderSizePixel = 0,
                    ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local accent = Utility:Create("Frame", {
                    Parent = container, BackgroundColor3 = Library.Theme.Accent,
                    Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(0, 3, 1, -16),
                    BorderSizePixel = 0, ZIndex = 6
                })
                Utility:RegisterProperty(accent, "BackgroundColor3", "Accent")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = accent})
                local nameLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 5),
                    Size = UDim2.new(0.62, -12, 0, 20), Text = name, TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamMedium, TextSize = IsMobile and 11 or 12,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                Utility:RegisterProperty(nameLabel, "TextColor3", "Text")
                local valueLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.new(0.62, 0, 0, 5),
                    Size = UDim2.new(0.38, -12, 0, 20), Text = value, TextColor3 = Library.Theme.Accent,
                    Font = Enum.Font.GothamBold, TextSize = IsMobile and 12 or 14,
                    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6
                })
                Utility:RegisterProperty(valueLabel, "TextColor3", "Accent")
                local detailLabel
                if detail ~= "" then
                    detailLabel = Utility:Create("TextLabel", {
                        Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 27),
                        Size = UDim2.new(1, -24, 0, 17), Text = detail, TextColor3 = Library.Theme.SubText,
                        Font = Enum.Font.Gotham, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                    })
                    Utility:RegisterProperty(detailLabel, "TextColor3", "SubText")
                end
                local controller = finishController({
                    Type = "Metric",
                    SetValue = function(self, nextValue) valueLabel.Text = tostring(nextValue) end,
                    SetDetail = function(self, nextDetail) if detailLabel then detailLabel.Text = tostring(nextDetail) end end
                }, container, name, options.Tooltip)
                addElement({Holder = container, Text = name .. " " .. value .. " " .. detail})
                return controller
            end

            function Section:CreateDivider(text)
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, text and 24 or 12), ZIndex = 5
                })
                local line = Utility:Create("Frame", {
                    Parent = container, BackgroundColor3 = Library.Theme.Divider,
                    Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 5
                })
                Utility:RegisterProperty(line, "BackgroundColor3", "Divider")
                if text then
                    local label = Utility:Create("TextLabel", {
                        Parent = container, BackgroundColor3 = Library.Theme.Secondary,
                        Position = UDim2.new(0.5, -50, 0.5, -10), Size = UDim2.fromOffset(100, 20),
                        Text = tostring(text), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
                        TextSize = 11, ZIndex = 6
                    })
                    Utility:RegisterProperty(label, "BackgroundColor3", "Secondary")
                    Utility:RegisterProperty(label, "TextColor3", "SubText")
                end
                addElement({Holder = container, Text = text or ""})
                return finishController({}, container, text or "Divider")
            end

            -- BUTTON
            function Section:CreateButton(options)
                options = options or {}
                local Name = options.Name or "Button"
                local Callback = options.Callback or function() end
                local Description = tostring(options.Description or "")
                local ButtonIconAsset = Utility:NormalizeAssetId(options.Icon)

                local btnHeight = Description ~= "" and (IsMobile and 56 or 54) or (IsMobile and 44 or 42)
                local ButtonContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, btnHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(ButtonContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ButtonContainer})
                local Stroke = Utility:Create("UIStroke", {
                    Parent = ButtonContainer,
                    Color = Library.Theme.Stroke,
                    Thickness = 1
                })
                Utility:RegisterProperty(Stroke, "Color", "Stroke")

                local Btn = Utility:Create("TextButton", {
                    Parent = ButtonContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 9,
                    BorderSizePixel = 0
                })

                local textInset = ButtonIconAsset and 44 or 12
                if ButtonIconAsset then
                    local ButtonIcon = Utility:Create("ImageLabel", {
                        Parent = ButtonContainer,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 12, 0.5, -10),
                        Size = UDim2.fromOffset(20, 20),
                        Image = ButtonIconAsset,
                        ImageColor3 = Library.Theme.SubText,
                        ScaleType = Enum.ScaleType.Fit,
                        ZIndex = 7
                    })
                    Utility:RegisterProperty(ButtonIcon, "ImageColor3", "SubText")
                end
                local ButtonTitle = Utility:Create("TextLabel", {
                    Parent = ButtonContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, textInset, 0, Description ~= "" and 7 or 0),
                    Size = UDim2.new(1, -(textInset + 32), 0, Description ~= "" and 20 or btnHeight),
                    Font = Enum.Font.GothamMedium,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7
                })
                Utility:RegisterProperty(ButtonTitle, "TextColor3", "Text")
                local ButtonDescription
                if Description ~= "" then
                    ButtonDescription = Utility:Create("TextLabel", {
                        Parent = ButtonContainer,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, textInset, 0, 27),
                        Size = UDim2.new(1, -(textInset + 32), 0, 17),
                        Font = Enum.Font.Gotham,
                        Text = Description,
                        TextColor3 = Library.Theme.SubText,
                        TextSize = IsMobile and 10 or 11,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7
                    })
                    Utility:RegisterProperty(ButtonDescription, "TextColor3", "SubText")
                end
                local ButtonArrow = Utility:Create("ImageLabel", {
                    Parent = ButtonContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -24, 0.5, -8),
                    Size = UDim2.fromOffset(16, 16),
                    Image = ICONS.ChevronRight,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 7
                })
                Utility:RegisterProperty(ButtonArrow, "ImageColor3", "SubText")

                Library:Connect(Btn.MouseEnter, function()
                    Utility:Tween(Stroke, TweenInfo.new(0.2), {Color = Library.Theme.Accent})
                    Utility:Tween(ButtonContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Hover})
                end)
                Library:Connect(Btn.MouseLeave, function()
                    Utility:Tween(Stroke, TweenInfo.new(0.2), {Color = Library.Theme.Stroke})
                    Utility:Tween(ButtonContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Surface})
                end)
                Library:Connect(Btn.MouseButton1Click, function()
                    if IsMobile then
                        Utility:Tween(Stroke, TweenInfo.new(0.1), {Color = Library.Theme.Accent})
                        Utility:Tween(ButtonContainer, TweenInfo.new(0.1), {BackgroundColor3 = Library.Theme.Hover})
                        task.delay(0.15, function()
                            Utility:Tween(Stroke, TweenInfo.new(0.2), {Color = Library.Theme.Stroke})
                            Utility:Tween(ButtonContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Surface})
                        end)
                    end
                    Utility:SafeCall(Callback)
                end)
                addElement({Holder = ButtonContainer, Text = Name .. " " .. Description})
                return finishController({
                    SetText = function(self, text) ButtonTitle.Text = tostring(text) end,
                    SetDescription = function(self, text)
                        if ButtonDescription then ButtonDescription.Text = tostring(text) end
                    end
                }, ButtonContainer, Name, options.Tooltip)
            end

            -- TOGGLE
            function Section:CreateToggle(options)
                options = options or {}
                local Name = options.Name or "Toggle"
                local Default = options.Default or false
                local Callback = options.Callback or function() end
                local Flag = options.Flag or Name

                local CurrentValue = Default
                if Library.Flags[Flag] ~= nil then
                    CurrentValue = Library.Flags[Flag]
                end
                Library.Flags[Flag] = CurrentValue

                local toggleHeight = IsMobile and 40 or 40
                local ToggleContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, toggleHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(ToggleContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ToggleContainer})
                local stroke = Utility:Create("UIStroke", {Parent = ToggleContainer, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                local ToggleBtn = Utility:Create("TextButton", {
                    Parent = ToggleContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Enum.Font.Gotham,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    ZIndex = 6,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(ToggleBtn, "TextColor3", "Text")
                Utility:Create("UIPadding", {Parent = ToggleBtn, PaddingLeft = UDim.new(0, 12)})

                local switchWidth = IsMobile and 30 or 35
                local switchHeight = IsMobile and 17 or 20
                local dotSize = IsMobile and 13 or 16

                local SwitchBg = Utility:Create("Frame", {
                    Parent = ToggleBtn,
                    BackgroundColor3 = CurrentValue and Library.Theme.Accent or Library.Theme.SurfaceAlt,
                    Position = UDim2.new(1, -(switchWidth + 10), 0.5, -math.floor(switchHeight / 2)),
                    Size = UDim2.new(0, switchWidth, 0, switchHeight),
                    BorderSizePixel = 0,
                    ZIndex = 6
                })
                Utility:RegisterProperty(SwitchBg, "BackgroundColor3", CurrentValue and "Accent" or "SurfaceAlt")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SwitchBg})
                local SwitchDot = Utility:Create("Frame", {
                    Parent = SwitchBg,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Position = CurrentValue and UDim2.new(1, -(dotSize + 2), 0.5, -math.floor(dotSize / 2)) or UDim2.new(0, 2, 0.5, -math.floor(dotSize / 2)),
                    Size = UDim2.new(0, dotSize, 0, dotSize),
                    ZIndex = 7,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SwitchDot})

                local changeListeners = {}

                local function Update()
                    Library.Flags[Flag] = CurrentValue
                    Utility:SafeCall(Callback, CurrentValue)
                    if CurrentValue then
                        Library.Registry[SwitchBg]["BackgroundColor3"] = "Accent"
                        Utility:Tween(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent})
                        Utility:Tween(SwitchDot, TweenInfo.new(0.2), {Position = UDim2.new(1, -(dotSize + 2), 0.5, -math.floor(dotSize / 2))})
                    else
                        Library.Registry[SwitchBg]["BackgroundColor3"] = "SurfaceAlt"
                        Utility:Tween(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.SurfaceAlt})
                        Utility:Tween(SwitchDot, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -math.floor(dotSize / 2))})
                    end
                    for _, listener in ipairs(changeListeners) do
                        pcall(listener, CurrentValue)
                    end
                end

                Library:Connect(ToggleBtn.MouseButton1Click, function()
                    CurrentValue = not CurrentValue
                    Update()
                end)
                Library:Connect(ToggleBtn.MouseEnter, function()
                    Utility:Tween(ToggleContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Hover})
                end)
                Library:Connect(ToggleBtn.MouseLeave, function()
                    Utility:Tween(ToggleContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Surface})
                end)

                addElement({Holder = ToggleContainer, Text = Name})

                local toggleObj = {
                    Type = "Toggle",
                    Set = function(self, val)
                        CurrentValue = val
                        Update()
                    end,
                    Get = function() return CurrentValue end,
                    OnChanged = function(self, fn)
                        table.insert(changeListeners, fn)
                    end
                }
                finishController(toggleObj, ToggleContainer, Name, options.Tooltip)
                Library:RegisterOption(Flag, toggleObj)
                return toggleObj
            end

            -- SLIDER
            function Section:CreateSlider(options)
                options = options or {}
                local Name = options.Name or "Slider"
                local Min = options.Min or 0
                local Max = options.Max or 100
                local Default = options.Default or Min
                local Callback = options.Callback or function() end
                local Flag = options.Flag or Name
                local Step = math.max(tonumber(options.Step) or 1, 0.000001)
                local CallbackMode = options.CallbackMode or (options.CallbackOnRelease and "Release" or "Changed")

                local Value = Default
                if Library.Flags[Flag] ~= nil then Value = Library.Flags[Flag] end
                Library.Flags[Flag] = Value

                local sliderHeight = IsMobile and 44 or 50
                local SliderContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, sliderHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(SliderContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SliderContainer})
                local stroke = Utility:Create("UIStroke", {Parent = SliderContainer, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                Utility:Create("TextLabel", {
                    Parent = SliderContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, IsMobile and 6 or 8),
                    Size = UDim2.new(1, -24, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })
                local ValueLabel = Utility:Create("TextLabel", {
                    Parent = SliderContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, IsMobile and 6 or 8),
                    Size = UDim2.new(1, -24, 0, 20),
                    Font = Enum.Font.GothamBold,
                    Text = tostring(Value),
                    TextColor3 = Library.Theme.SubText,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 6
                })
                local trackHeight = IsMobile and 10 or 6
                local Track = Utility:Create("TextButton", {
                    Parent = SliderContainer,
                    BackgroundColor3 = Library.Theme.SurfaceAlt,
                    Position = UDim2.new(0, 12, 0, IsMobile and 28 or 34),
                    Size = UDim2.new(1, -24, 0, trackHeight),
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 6,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(Track, "BackgroundColor3", "SurfaceAlt")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Track})
                local Fill = Utility:Create("Frame", {
                    Parent = Track,
                    BackgroundColor3 = Library.Theme.Accent,
                    Size = UDim2.new((Value - Min) / (Max - Min), 0, 1, 0),
                    BorderSizePixel = 0,
                    ZIndex = 7
                })
                Utility:RegisterProperty(Fill, "BackgroundColor3", "Accent")
                local fillGradient = Utility:Create("UIGradient", {Parent = Fill})
                Utility:RegisterGradient(fillGradient, "Accent", "Accent2", "Accent3")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Fill})
                local Dragging = false
                local DragInput = nil
                local pendingCallback = false

                local function EmitValue()
                    pendingCallback = false
                    Utility:SafeCall(Callback, Value)
                end

                local function UpdateSlider(input)
                    local SizeX = math.clamp((input.Position.X - Track.AbsolutePosition.X) / math.max(1, Track.AbsoluteSize.X), 0, 1)
                    local NewValue = Min + ((Max - Min) * SizeX)
                    NewValue = math.clamp(Min + math.floor(((NewValue - Min) / Step) + 0.5) * Step, Min, Max)
                    Value = NewValue
                    ValueLabel.Text = tostring(Value)
                    Library.Flags[Flag] = Value
                    pendingCallback = true
                    if CallbackMode ~= "Release" then EmitValue() end
                    Utility:Tween(Fill, TweenInfo.new(0.05), {Size = UDim2.new((Value - Min) / math.max(0.000001, Max - Min), 0, 1, 0)})
                end

                Library:Connect(Track.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        Dragging = true
                        DragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
                        UpdateSlider(input)
                    end
                end)
                Library:Connect(UserInputService.InputChanged, function(input)
                    local pointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
                        or (input.UserInputType == Enum.UserInputType.Touch and input == DragInput)
                    if Dragging and pointerMove then
                        UpdateSlider(input)
                    end
                end)
                Library:Connect(UserInputService.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        local wasDragging = Dragging
                        Dragging = false
                        if wasDragging and pendingCallback then task.defer(EmitValue) end
                        if wasDragging and options.Finished then task.defer(function() Utility:SafeCall(options.Finished, Value) end) end
                    end
                end)

                addElement({Holder = SliderContainer, Text = Name})
                local function SetValue(val, fire)
                    Value = math.clamp(tonumber(val) or Min, Min, Max)
                    ValueLabel.Text = tostring(Value)
                    Library.Flags[Flag] = Value
                    Utility:Tween(Fill, TweenInfo.new(0.1), {Size = UDim2.new((Value - Min) / math.max(0.000001, Max - Min), 0, 1, 0)})
                    pendingCallback = false
                    if fire ~= false then EmitValue() end
                end
                local sliderObj = {
                    Type = "Slider",
                    Set = function(self, val)
                        SetValue(val, true)
                    end,
                    SetSilent = function(self, val) SetValue(val, false) end,
                    Get = function() return Value end
                }
                finishController(sliderObj, SliderContainer, Name, options.Tooltip)
                Library:RegisterOption(Flag, sliderObj)
                return sliderObj
            end

            -- DROPDOWN
            function Section:CreateDropdown(options)
                options = options or {}
                local Name = options.Name or "Dropdown"
                local Values = options.Values or {}
                local Multi = options.Multi or false
                local Default = options.Default or (Multi and {} or Values[1])
                local Callback = options.Callback or function() end
                local Flag = options.Flag or Name

                local function normalizeMulti(value)
                    if not Multi then return value end
                    local normalized = {}
                    if type(value) == "table" then
                        for key, selected in pairs(value) do
                            if type(key) == "number" then
                                normalized[selected] = true
                            elseif selected == true then
                                normalized[key] = true
                            end
                        end
                    end
                    return normalized
                end

                local CurrentValue = normalizeMulti(Default)
                if Library.Flags[Flag] ~= nil then CurrentValue = Library.Flags[Flag] end
                CurrentValue = normalizeMulti(CurrentValue)
                Library.Flags[Flag] = CurrentValue

                local headerHeight = IsMobile and 38 or 44
                local Expanded = false
                local listHeight = 0

                local changeListeners = {}

                local DropdownContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(DropdownContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = DropdownContainer})
                local stroke = Utility:Create("UIStroke", {Parent = DropdownContainer, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                -- Header clip frame to prevent button overflow
                local HeaderClip = Utility:Create("Frame", {
                    Parent = DropdownContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    ClipsDescendants = true,
                    ZIndex = 5
                })

                local Header = Utility:Create("TextButton", {
                    Parent = HeaderClip,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 6,
                    BorderSizePixel = 0
                })
                Utility:Create("TextLabel", {
                    Parent = Header,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, IsMobile and 10 or 12),
                    Size = UDim2.new(0.5, 0, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7
                })
                local Status = Utility:Create("TextLabel", {
                    Parent = Header,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0, IsMobile and 10 or 12),
                    Size = UDim2.new(0.5, -30, 0, 20),
                    Font = Enum.Font.GothamBold,
                    Text = (Multi and "..." or tostring(CurrentValue)),
                    TextColor3 = Library.Theme.SubText,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7
                })
                local Arrow = Utility:Create("ImageLabel", {
                    Parent = Header,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -28, 0.5, -8),
                    Size = UDim2.fromOffset(16, 16),
                    Image = ICONS.ChevronDown,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 7
                })
                Utility:RegisterProperty(Arrow, "ImageColor3", "SubText")

                -- List rendered outside HeaderClip so it can overflow
                local ListFrame = Utility:Create("ScrollingFrame", {
                    Parent = DropdownContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Position = UDim2.new(0, 8, 0, headerHeight),
                    Size = UDim2.new(1, -16, 0, 0),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Library.Theme.Accent,
                    ZIndex = 20,
                    BorderSizePixel = 0,
                    Visible = false
                })
                Utility:RegisterProperty(ListFrame, "BackgroundColor3", "Surface")
                Utility:RegisterMaterial(ListFrame, 0.24, 0)
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ListFrame})
                local listStroke = Utility:Create("UIStroke", {Parent = ListFrame, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(listStroke, "Color", "Stroke")

                local itemHeight = IsMobile and 30 or 26

                local function SetExpanded(open)
                    Expanded = open == true
                    if Expanded then ListFrame.Visible = true end
                    Utility:Tween(Arrow, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = Expanded and 180 or 0})
                    Utility:Tween(DropdownContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, Expanded and (headerHeight + listHeight + 8) or headerHeight)
                    }, function()
                        if not Expanded then ListFrame.Visible = false end
                    end)
                    if Library.ReducedMotion and not Expanded then ListFrame.Visible = false end
                end

                local function UpdateStatus()
                    if Multi then
                        local selected = {}
                        for _, optionValue in ipairs(Values) do
                            if CurrentValue[optionValue] then table.insert(selected, tostring(optionValue)) end
                        end
                        if #selected == 0 then
                            Status.Text = "None selected"
                        elseif #selected <= 2 then
                            Status.Text = table.concat(selected, ", ")
                        else
                            Status.Text = selected[1] .. ", " .. selected[2] .. " +" .. tostring(#selected - 2)
                        end
                    else
                        Status.Text = CurrentValue ~= nil and tostring(CurrentValue) or "No options"
                    end
                end

                local function Refresh()
                    UpdateStatus()
                    Library.Flags[Flag] = CurrentValue
                    Utility:SafeCall(Callback, CurrentValue)
                    for _, listener in ipairs(changeListeners) do
                        pcall(listener, CurrentValue)
                    end
                end

                local function BuildList()
                    ListFrame:ClearAllChildren()
                    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = ListFrame})
                    local rebuiltStroke = Utility:Create("UIStroke", {Parent = ListFrame, Color = Library.Theme.Stroke, Thickness = 1})
                    Utility:RegisterProperty(rebuiltStroke, "Color", "Stroke")
                    Utility:Create("UIListLayout", {Parent = ListFrame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
                    Utility:Create("UIPadding", {Parent = ListFrame, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4)})
                    for _, val in pairs(Values) do
                        local Item = Utility:Create("TextButton", {
                            Parent = ListFrame,
                            BackgroundColor3 = Library.Theme.SurfaceAlt,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, itemHeight),
                            AutoButtonColor = false,
                            Text = "",
                            ZIndex = 21,
                            BorderSizePixel = 0
                        })
                        Utility:RegisterProperty(Item, "BackgroundColor3", "SurfaceAlt")
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = Item})
                        local IsSelected = Multi and CurrentValue[val] or (not Multi and CurrentValue == val)
                        local itemText = Utility:Create("TextLabel", {
                            Parent = Item, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 0),
                            Size = UDim2.new(1, -38, 1, 0), Text = tostring(val),
                            TextColor3 = IsSelected and Library.Theme.Text or Library.Theme.SubText,
                            Font = Enum.Font.Gotham, TextSize = IsMobile and 12 or 13,
                            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22
                        })
                        Utility:RegisterProperty(itemText, "TextColor3", IsSelected and "Text" or "SubText")
                        local checkIcon = Utility:Create("ImageLabel", {
                            Parent = Item, BackgroundTransparency = 1, Position = UDim2.new(1, -25, 0.5, -7),
                            Size = UDim2.fromOffset(14, 14), Image = ICONS.Check,
                            ImageColor3 = Library.Theme.Accent, ImageTransparency = IsSelected and 0 or 1,
                            ScaleType = Enum.ScaleType.Fit, ZIndex = 22
                        })
                        Utility:RegisterProperty(checkIcon, "ImageColor3", "Accent")
                        if IsSelected then
                            Item.BackgroundTransparency = 0.08
                        end
                        Library:Connect(Item.MouseButton1Click, function()
                            if Multi then
                                CurrentValue[val] = not CurrentValue[val]
                                BuildList()
                            else
                                CurrentValue = val
                                SetExpanded(false)
                                BuildList()
                            end
                            Refresh()
                        end)
                    end
                    listHeight = math.min(#Values * (itemHeight + 4) + 10, IsMobile and 132 or 156)
                    ListFrame.CanvasSize = UDim2.new(0, 0, 0, #Values * (itemHeight + 4) + 10)
                    ListFrame.Size = UDim2.new(1, -16, 0, listHeight)
                    if Expanded then DropdownContainer.Size = UDim2.new(1, 0, 0, headerHeight + listHeight + 8) end
                end

                Library:Connect(Header.MouseButton1Click, function()
                    SetExpanded(not Expanded)
                end)
                BuildList()
                UpdateStatus()
                addElement({Holder = DropdownContainer, Text = Name})

                local dropObj = {
                    Type = "Dropdown",
                    Set = function(self, val)
                        CurrentValue = normalizeMulti(val)
                        Refresh()
                        BuildList()
                    end,
                    Refresh = function(self, newVals, preserveSelection)
                        Values = type(newVals) == "table" and newVals or {}
                        if not Multi then
                            local stillExists = false
                            for _, optionValue in ipairs(Values) do
                                if optionValue == CurrentValue then stillExists = true break end
                            end
                            if not stillExists and preserveSelection ~= true then CurrentValue = Values[1] end
                        end
                        Refresh()
                        BuildList()
                    end,
                    Get = function() return CurrentValue end,
                    GetList = function()
                        local selected = {}
                        if Multi then
                            for _, value in ipairs(Values) do if CurrentValue[value] then table.insert(selected, value) end end
                        elseif CurrentValue ~= nil then
                            table.insert(selected, CurrentValue)
                        end
                        return selected
                    end,
                    Clear = function(self)
                        if Multi then CurrentValue = {} else CurrentValue = nil end
                        Refresh(); BuildList()
                    end,
                    SelectAll = function(self)
                        if Multi then
                            CurrentValue = {}
                            for _, value in ipairs(Values) do CurrentValue[value] = true end
                            Refresh(); BuildList()
                        end
                    end,
                    OnChanged = function(self, fn)
                        table.insert(changeListeners, fn)
                    end,
                    SetExpanded = function(self, open) SetExpanded(open) end
                }
                finishController(dropObj, DropdownContainer, Name, options.Tooltip)
                Library:RegisterOption(Flag, dropObj)
                return dropObj
            end

            function Section:CreateMultiDropdown(options)
                options = options or {}
                options.Multi = true
                return self:CreateDropdown(options)
            end

            -- LABEL
            function Section:CreateLabel(Text)
                local Container = Utility:Create("Frame", {
                    Name = "Label",
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local Lab = Utility:Create("TextLabel", {
                    Parent = Container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Enum.Font.Gotham,
                    Text = Text,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 6
                })
                Utility:RegisterProperty(Lab, "TextColor3", "Text")
                Library:Connect(Lab:GetPropertyChangedSignal("TextBounds"), function()
                    Container.Size = UDim2.new(1, 0, 0, Lab.TextBounds.Y + 4)
                end)
                addElement({Holder = Container, Text = Text})
                return finishController({
                    SetText = function(self, t)
                        Lab.Text = t
                    end
                }, Container, Text)
            end

            -- DEPENDENCY BOX
            function Section:CreateDependencyBox(dependencies)
                local depContainer = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local layout = Utility:Create("UIListLayout", {
                    Parent = depContainer,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, IsMobile and 6 or 8)
                })

                local function updateVisibility()
                    local allMatch = true
                    for _, dep in ipairs(dependencies) do
                        local element, expected = dep[1], dep[2]
                        local val = element.Get and element.Get() or nil
                        if val == nil then
                            allMatch = false; break
                        end
                        if element.Type == "Toggle" then
                            if val ~= expected then allMatch = false; break end
                        elseif element.Type == "Dropdown" then
                            if type(val) == "table" then
                                if not val[expected] then allMatch = false; break end
                            elseif val ~= expected then
                                allMatch = false; break
                            end
                        end
                    end
                    depContainer.Visible = allMatch
                    -- Manually update canvas size
                    if allMatch then
                        depContainer.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
                    else
                        depContainer.Size = UDim2.new(1, 0, 0, 0)
                    end
                    RefreshLayout()
                end

                for _, dep in ipairs(dependencies) do
                    local element = dep[1]
                    if element.OnChanged then
                        element:OnChanged(updateVisibility)
                    end
                end
                updateVisibility()
                addElement({Holder = depContainer})
                return depContainer
            end

            -- WARNING BOX
            function Section:CreateWarningBox(options)
                options = options or {}
                local title = options.Title or "Warning"
                local text = options.Text or ""
                local color = options.Color or "Warn"
                local closable = options.Closable or false

                local bgColor = Library.Theme[color] or Library.Theme.Warn
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = bgColor,
                    Size = UDim2.new(1, 0, 0, 40),
                    ClipsDescendants = false,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})

                local titleLabel = Utility:Create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 8),
                    Size = UDim2.new(1, closable and -30 or -20, 0, 20),
                    Font = Enum.Font.GothamBold,
                    Text = title,
                    TextColor3 = Library.Theme.Text,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })

                local textLabel = Utility:Create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 30),
                    Size = UDim2.new(1, -20, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = text,
                    TextColor3 = Library.Theme.SubText,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 6
                })

                Library:Connect(textLabel:GetPropertyChangedSignal("TextBounds"), function()
                    local textH = textLabel.TextBounds.Y + 4
                    textLabel.Size = UDim2.new(1, -20, 0, textH)
                    local totalHeight = 30 + textH + 10
                    container.Size = UDim2.new(1, 0, 0, totalHeight)
                    RefreshLayout()
                end)

                if closable then
                    local closeBtn = Utility:Create("TextButton", {
                        Parent = container,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(1, -24, 0, 4),
                        Size = UDim2.new(0, 20, 0, 20),
                        Text = "✖",
                        TextColor3 = Library.Theme.Text,
                        Font = Enum.Font.Gotham,
                        TextSize = 14,
                        ZIndex = 7
                    })
                    Library:Connect(closeBtn.MouseButton1Click, function()
                        container:Destroy()
                        RefreshLayout()
                    end)
                end
                addElement({Holder = container})
                return container
            end

            -- IMAGE
            function Section:CreateImage(options)
                options = options or {}
                local image = options.Image or ""
                local width = options.Width or 200
                local height = options.Height or 200
                local scaleType = options.ScaleType or Enum.ScaleType.Fit

                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, width, 0, height),
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local img = Utility:Create("ImageLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Image = image,
                    ScaleType = scaleType,
                    ZIndex = 6
                })
                addElement({Holder = container})
                return finishController({
                    SetImage = function(self, newImage) img.Image = newImage end,
                    SetSize = function(self, w, h) container.Size = UDim2.new(0, w, 0, h) end
                }, container, "Image", options.Tooltip)
            end

            -- KEYBIND PICKER
            function Section:CreateKeyPicker(options)
                options = options or {}
                local name = options.Name or "Keybind"
                local defaultKey = options.Default or "None"
                if typeof(defaultKey) == "EnumItem" then defaultKey = defaultKey.Name else defaultKey = tostring(defaultKey) end
                local mode = options.Mode or "Toggle"
                local callback = options.Callback or function() end
                local flag = options.Flag or name

                local currentKey = Library.Flags[flag] or defaultKey
                if typeof(currentKey) == "EnumItem" then currentKey = currentKey.Name else currentKey = tostring(currentKey) end
                local toggled = false
                local listening = false
                local keyHeld = false
                local keybindEntry = {name = name, key = currentKey, default = defaultKey, mode = mode, callback = callback, flag = flag}
                table.insert(Library.KeybindList, keybindEntry)
                Library.KeybindDefaults[flag] = defaultKey

                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, IsMobile and 32 or 36),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local stroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                local label = Utility:Create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0.5, -10),
                    Size = UDim2.new(0.6, 0, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })
                Utility:RegisterProperty(label, "TextColor3", "Text")

                local keyBtn = Utility:Create("TextButton", {
                    Parent = container,
                    BackgroundColor3 = Library.Theme.Secondary,
                    Position = UDim2.new(0.7, 0, 0.5, -12),
                    Size = UDim2.new(0.25, 0, 0, 24),
                    Text = currentKey,
                    TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    ZIndex = 6
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = keyBtn})
                Utility:RegisterProperty(keyBtn, "BackgroundColor3", "Secondary")
                Utility:RegisterProperty(keyBtn, "TextColor3", "Text")

                local stateIndicator = Utility:Create("Frame", {
                    Parent = container,
                    BackgroundColor3 = Library.Theme.Accent,
                    Position = UDim2.new(0.96, 0, 0.5, -4),
                    Size = UDim2.new(0, 8, 0, 8),
                    Visible = false,
                    ZIndex = 7
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = stateIndicator})
                Utility:RegisterProperty(stateIndicator, "BackgroundColor3", "Accent")

                local listenBtn = Utility:Create("TextButton", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.96, 0, 0, 0),
                    Size = UDim2.new(0, 20, 1, 0),
                    Text = "✎",
                    TextColor3 = Library.Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 14,
                    ZIndex = 7
                })
                Utility:RegisterProperty(listenBtn, "TextColor3", "SubText")

                Library:Connect(listenBtn.MouseButton1Click, function()
                    if listening then return end
                    listening = true
                    keyBtn.Text = "..."
                    local conn
                    conn = Library:Connect(UserInputService.InputBegan, function(input, gpe)
                        if gpe then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            currentKey = input.KeyCode.Name
                            Library.Flags[flag] = currentKey
                            keyBtn.Text = currentKey
                            listening = false
                            conn:Disconnect()
                            keybindEntry.key = currentKey
                        end
                    end)
                end)

                if mode == "Hold" then
                    local holding = false
                    local holdConn
                    Library:Connect(keyBtn.InputBegan, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            if listening then return end
                            holding = true
                            stateIndicator.Visible = true
                            Utility:SafeCall(callback, currentKey, true)
                            holdConn = Library:Connect(RunService.Heartbeat, function()
                                if holding then
                                    Utility:SafeCall(callback, currentKey, true)
                                end
                            end)
                        end
                    end)
                    Library:Connect(keyBtn.InputEnded, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            if holding then
                                holding = false
                                stateIndicator.Visible = false
                                if holdConn then holdConn:Disconnect() end
                                Utility:SafeCall(callback, currentKey, false)
                            end
                        end
                    end)
                elseif mode == "Toggle" then
                    Library:Connect(keyBtn.MouseButton1Click, function()
                        if listening then return end
                        toggled = not toggled
                        stateIndicator.Visible = toggled
                        Utility:SafeCall(callback, currentKey, toggled)
                    end)
                end

                Library:Connect(UserInputService.InputBegan, function(input, processed)
                    if processed or listening or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                    if input.KeyCode.Name ~= currentKey then return end
                    if mode == "Hold" then
                        if keyHeld then return end
                        keyHeld = true
                        stateIndicator.Visible = true
                        Utility:SafeCall(callback, currentKey, true)
                    elseif mode == "Toggle" then
                        toggled = not toggled
                        stateIndicator.Visible = toggled
                        Utility:SafeCall(callback, currentKey, toggled)
                    else
                        Utility:SafeCall(callback, currentKey, true)
                    end
                end)
                Library:Connect(UserInputService.InputEnded, function(input)
                    if mode ~= "Hold" or input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode.Name ~= currentKey then return end
                    keyHeld = false
                    stateIndicator.Visible = false
                    Utility:SafeCall(callback, currentKey, false)
                end)

                addElement({Holder = container, Text = name})
                local controller = finishController({
                    Type = "KeyPicker",
                    Set = function(self, key)
                        currentKey = typeof(key) == "EnumItem" and key.Name or tostring(key)
                        keyBtn.Text = currentKey
                        Library.Flags[flag] = currentKey
                        keybindEntry.key = currentKey
                    end,
                    Get = function() return currentKey end,
                    GetKey = function() return currentKey end,
                    GetState = function() return toggled end
                }, container, name, options.Tooltip)
                Library.Flags[flag] = currentKey
                Library:RegisterOption(flag, controller)
                keybindEntry.controller = controller
                return controller
            end

            -- COLOR PICKER (touch-friendly HSV editor)
            function Section:CreateColorPicker(options)
                options = options or {}
                local name = options.Name or "Color"
                local defaultColor = options.Default or Color3.new(1,1,1)
                local callback = options.Callback or function() end
                local flag = options.Flag or name
                local currentColor = Library.Flags[flag] or defaultColor
                local hue, saturation, value = Color3.toHSV(currentColor)
                local expanded = false
                local listeners = {}
                local headerHeight = IsMobile and 40 or 38

                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local stroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                local headerButton = Utility:Create("TextButton", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 7
                })

                local label = Utility:Create("TextLabel", {
                    Parent = headerButton,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, 0),
                    Size = UDim2.new(1, -92, 0, headerHeight),
                    Font = Enum.Font.Gotham,
                    Text = name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })
                Utility:RegisterProperty(label, "TextColor3", "Text")

                local headerSwatch = Utility:Create("Frame", {
                    Parent = headerButton,
                    BackgroundColor3 = currentColor,
                    Position = UDim2.new(1, -58, 0.5, -10),
                    Size = UDim2.fromOffset(20, 20),
                    BorderSizePixel = 0,
                    ZIndex = 8
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = headerSwatch})
                local colorStroke = Utility:Create("UIStroke", {Parent = headerSwatch, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(colorStroke, "Color", "Stroke")

                local headerArrow = Utility:Create("ImageLabel", {
                    Parent = headerButton,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -28, 0.5, -8),
                    Size = UDim2.fromOffset(16, 16),
                    Image = ICONS.ChevronDown,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 8
                })
                Utility:RegisterProperty(headerArrow, "ImageColor3", "SubText")

                local editor = Utility:Create("Frame", {
                    Parent = container, BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, headerHeight + 4),
                    Size = UDim2.new(1, -24, 0, 132), ZIndex = 6
                })

                local hueGradient = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
                })

                local function createColorTrack(title, y, gradient)
                    local trackLabel = Utility:Create("TextLabel", {
                        Parent = editor, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y),
                        Size = UDim2.fromOffset(18, 22), Text = title, TextColor3 = Library.Theme.SubText,
                        Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 7
                    })
                    Utility:RegisterProperty(trackLabel, "TextColor3", "SubText")
                    local track = Utility:Create("TextButton", {
                        Parent = editor, BackgroundColor3 = Color3.new(1, 1, 1),
                        Position = UDim2.new(0, 24, 0, y + 5), Size = UDim2.new(1, -24, 0, 12),
                        Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 7
                    })
                    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
                    local uiGradient = Utility:Create("UIGradient", {Parent = track, Color = gradient})
                    local marker = Utility:Create("Frame", {
                        Parent = track, BackgroundColor3 = Color3.new(1, 1, 1),
                        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                        Size = UDim2.fromOffset(4, 18), BorderSizePixel = 0, ZIndex = 8
                    })
                    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = marker})
                    Utility:Create("UIStroke", {Parent = marker, Color = Color3.new(0, 0, 0), Transparency = 0.35, Thickness = 1})
                    return track, marker, uiGradient
                end

                local hueTrack, hueMarker = createColorTrack("H", 0, hueGradient)
                local satTrack, satMarker, satGradient = createColorTrack("S", 30, ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(hue,1,1)))
                local valTrack, valMarker, valGradient = createColorTrack("V", 60, ColorSequence.new(Color3.new(0,0,0), Color3.fromHSV(hue,saturation,1)))

                local colorDisplay = Utility:Create("TextButton", {
                    Parent = editor,
                    BackgroundColor3 = currentColor,
                    Position = UDim2.new(0, 24, 0, 94),
                    Size = UDim2.new(1, -24, 0, 30),
                    Text = "",
                    TextColor3 = Color3.new(1, 1, 1),
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 7
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = colorDisplay})
                local previewStroke = Utility:Create("UIStroke", {Parent = colorDisplay, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(previewStroke, "Color", "Stroke")

                local function refreshColor(fire)
                    currentColor = Color3.fromHSV(hue, saturation, value)
                    Library.Flags[flag] = currentColor
                    headerSwatch.BackgroundColor3 = currentColor
                    colorDisplay.BackgroundColor3 = currentColor
                    colorDisplay.Text = string.format("#%02X%02X%02X", math.floor(currentColor.R * 255 + 0.5), math.floor(currentColor.G * 255 + 0.5), math.floor(currentColor.B * 255 + 0.5))
                    local luminance = currentColor.R * 0.299 + currentColor.G * 0.587 + currentColor.B * 0.114
                    colorDisplay.TextColor3 = luminance > 0.62 and Color3.fromRGB(18, 18, 24) or Color3.new(1, 1, 1)
                    hueMarker.Position = UDim2.new(hue, 0, 0.5, 0)
                    satMarker.Position = UDim2.new(saturation, 0, 0.5, 0)
                    valMarker.Position = UDim2.new(value, 0, 0.5, 0)
                    satGradient.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(hue,1,1))
                    valGradient.Color = ColorSequence.new(Color3.new(0,0,0), Color3.fromHSV(hue,saturation,1))
                    if fire ~= false then
                        Utility:SafeCall(callback, currentColor)
                        for _, listener in ipairs(listeners) do Utility:SafeCall(listener, currentColor) end
                    end
                end

                local function bindTrack(track, setter)
                    local dragging = false
                    local dragInput = nil
                    local function update(input)
                        setter(math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1))
                        refreshColor(true)
                    end
                    Library:Connect(track.InputBegan, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = true
                            dragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
                            update(input)
                        end
                    end)
                    Library:Connect(UserInputService.InputChanged, function(input)
                        local pointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
                            or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
                        if dragging and pointerMove then update(input) end
                    end)
                    Library:Connect(UserInputService.InputEnded, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
                    end)
                end
                bindTrack(hueTrack, function(x) hue = x end)
                bindTrack(satTrack, function(x) saturation = x end)
                bindTrack(valTrack, function(x) value = x end)

                local function setExpanded(open)
                    expanded = open == true
                    Utility:Tween(headerArrow, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = expanded and 180 or 0})
                    Utility:Tween(container, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, expanded and (headerHeight + 142) or headerHeight)
                    })
                    task.delay(Library.ReducedMotion and 0 or 0.23, RefreshLayout)
                end
                Library:Connect(headerButton.MouseButton1Click, function()
                    setExpanded(not expanded)
                end)
                Library:Connect(colorDisplay.MouseButton1Click, function()
                    if type(setclipboard) == "function" then
                        setclipboard(colorDisplay.Text)
                        Library:Notify({Title = "Color copied", Content = colorDisplay.Text, Duration = 2})
                    end
                end)
                refreshColor(false)
                addElement({Holder = container, Text = name})
                local controller = finishController({
                    Type = "ColorPicker",
                    Set = function(self, color) hue, saturation, value = Color3.toHSV(color); refreshColor(true) end,
                    SetColor = function(self, color) self:Set(color) end,
                    Get = function() return currentColor end,
                    OnChanged = function(self, fn) table.insert(listeners, fn) end,
                    SetExpanded = function(self, open) if expanded ~= (open == true) then setExpanded(open) end end
                }, container, name, options.Tooltip)
                Library:RegisterOption(flag, controller)
                return controller
            end

            function Section:CreateGroup(options)
                if type(options) == "string" then options = {Name = options} end
                options = options or {}
                local name = tostring(options.Name or "Group")
                local expanded = options.Expanded ~= false
                local headerHeight = IsMobile and 38 or 42
                local container = Utility:Create("Frame", {
                    Name = "Group_" .. name, Parent = ContentContainer, BackgroundColor3 = Library.Theme.Secondary,
                    Size = UDim2.new(1, 0, 0, headerHeight), ClipsDescendants = true,
                    BorderSizePixel = 0, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Secondary")
                Utility:RegisterMaterial(container, 0.42, 0.08)
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 8)})
                local groupStroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Divider, Thickness = 1})
                Utility:RegisterProperty(groupStroke, "Color", "Divider")
                local header = Utility:Create("TextButton", {
                    Parent = container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, headerHeight),
                    Text = "", AutoButtonColor = false, ZIndex = 6
                })
                local title = Utility:Create("TextLabel", {
                    Parent = header, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0),
                    Size = UDim2.new(1, -48, 1, 0), Text = name, TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7
                })
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local chevron = Utility:Create("ImageLabel", {
                    Parent = header, BackgroundTransparency = 1, Position = UDim2.new(1, -28, 0.5, -7),
                    Size = UDim2.fromOffset(14, 14), Image = ICONS.ChevronDown,
                    ImageColor3 = Library.Theme.SubText, Rotation = expanded and 0 or -90, ZIndex = 7
                })
                Utility:RegisterProperty(chevron, "ImageColor3", "SubText")
                local body = Utility:Create("Frame", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, headerHeight),
                    Size = UDim2.new(1, 0, 0, 0), Visible = expanded, ZIndex = 6
                })
                Utility:Create("UIPadding", {
                    Parent = body, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
                    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8)
                })
                local bodyLayout = Utility:Create("UIListLayout", {Parent = body, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder})
                local function refresh()
                    local bodyHeight = expanded and bodyLayout.AbsoluteContentSize.Y + 12 or 0
                    body.Visible = expanded
                    body.Size = UDim2.new(1, 0, 0, bodyHeight)
                    Utility:Tween(container, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, headerHeight + bodyHeight)
                    })
                    Utility:Tween(chevron, TweenInfo.new(0.2), {Rotation = expanded and 0 or -90})
                    RefreshLayout()
                end
                Library:Connect(bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), refresh)
                addElement({Holder = container, Text = name})
                local group = finishController({Type = "Group"}, container, name, options.Tooltip)
                function group:SetExpanded(value) expanded = value == true refresh() return self end
                function group:Toggle() return self:SetExpanded(not expanded) end
                function group:IsExpanded() return expanded end
                function group:SetTitle(value) name = tostring(value); title.Text = name; self.Name = name return self end
                local function attach(method, value)
                    local controller = Section[method](Section, value)
                    if controller and controller.Holder then
                        controller.Holder.Parent = body
                        for _, element in ipairs(Section.Elements) do
                            if element.Holder == controller.Holder then element.NestedParentHolder = container break end
                        end
                        Library:Connect(controller.Holder:GetPropertyChangedSignal("Size"), refresh)
                        task.defer(refresh)
                    end
                    return controller
                end
                function group:CreateButton(value) return attach("CreateButton", value) end
                function group:CreateToggle(value) return attach("CreateToggle", value) end
                function group:CreateSlider(value) return attach("CreateSlider", value) end
                function group:CreateDropdown(value) return attach("CreateDropdown", value) end
                function group:CreateMultiDropdown(value) return attach("CreateMultiDropdown", value) end
                function group:CreateInput(value) return attach("CreateInput", value) end
                function group:CreateParagraph(value) return attach("CreateParagraph", value) end
                function group:CreateMetric(value) return attach("CreateMetric", value) end
                function group:CreateKeyPicker(value) return attach("CreateKeyPicker", value) end
                function group:CreateColorPicker(value) return attach("CreateColorPicker", value) end
                function group:CreateImage(value) return attach("CreateImage", value) end
                function group:CreateLabel(value) return attach("CreateLabel", value) end
                function group:CreateDivider(value) return attach("CreateDivider", value) end
                function group:CreateGroup(value) return attach("CreateGroup", value) end
                function group:CreateList(value) return attach("CreateList", value) end
                function group:CreateTable(value) return attach("CreateTable", value) end
                function group:CreatePlayerList(value) return attach("CreatePlayerList", value) end
                function group:CreateLogConsole(value) return attach("CreateLogConsole", value) end
                function group:CreateSkeleton(value) return attach("CreateSkeleton", value) end
                Library:Connect(header.MouseButton1Click, function() group:Toggle() end)
                task.defer(refresh)
                return group
            end

            function Section:CreateList(options)
                options = options or {}
                local name = tostring(options.Name or "List")
                local items = type(options.Items) == "table" and options.Items or {}
                local selected = options.Default
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 176),
                    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local stroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")
                local title = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 5),
                    Size = UDim2.new(1, -20, 0, 24), Text = name, TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local list = Utility:Create("ScrollingFrame", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 32),
                    Size = UDim2.new(1, -14, 1, -39), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6
                })
                Utility:RegisterProperty(list, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIListLayout", {Parent = list, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
                local controller
                local function parts(item)
                    if type(item) == "table" then return tostring(item.Label or item.Name or item.Value or "Item"), item.Value ~= nil and item.Value or item, item.Description end
                    return tostring(item), item, nil
                end
                local function render()
                    for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
                    for index, item in ipairs(items) do
                        local labelText, value, description = parts(item)
                        local row = Utility:Create("TextButton", {
                            Parent = list, BackgroundColor3 = Library.Theme.Secondary,
                            BackgroundTransparency = value == selected and 0 or 0.24,
                            Size = UDim2.new(1, -4, 0, description and 44 or 34), Text = "",
                            AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = index, ZIndex = 7
                        })
                        Utility:RegisterProperty(row, "BackgroundColor3", value == selected and "Accent" or "Secondary")
                        Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 5)})
                        local label = Utility:Create("TextLabel", {
                            Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, description and 4 or 0),
                            Size = UDim2.new(1, -18, 0, description and 20 or 34), Text = labelText,
                            TextColor3 = Library.Theme.Text, Font = Enum.Font.Gotham, TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
                        })
                        Utility:RegisterProperty(label, "TextColor3", "Text")
                        if description then
                            local detail = Utility:Create("TextLabel", {
                                Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 22),
                                Size = UDim2.new(1, -18, 0, 16), Text = tostring(description), TextColor3 = Library.Theme.SubText,
                                Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
                            })
                            Utility:RegisterProperty(detail, "TextColor3", "SubText")
                        end
                        Library:Connect(row.MouseButton1Click, function()
                            selected = value
                            render()
                            Utility:SafeCall(options.Callback, value, item, index)
                        end)
                    end
                end
                addElement({Holder = container, Text = name})
                controller = finishController({Type = "List"}, container, name, options.Tooltip)
                function controller:SetItems(nextItems) items = type(nextItems) == "table" and nextItems or {} render() return self end
                function controller:GetItems() return items end
                function controller:Add(item) table.insert(items, item) render() return self end
                function controller:Remove(value)
                    for index, item in ipairs(items) do local _, itemValue = parts(item) if itemValue == value then table.remove(items, index) break end end
                    if selected == value then selected = nil end render() return self
                end
                function controller:Clear() table.clear(items) selected = nil render() return self end
                function controller:Select(value) selected = value render() return self end
                function controller:GetSelected() return selected end
                render()
                return controller
            end

            function Section:CreateTable(options)
                options = options or {}
                local name = tostring(options.Name or "Table")
                local columns = type(options.Columns) == "table" and options.Columns or {{Key = "value", Name = "Value"}}
                local rows = type(options.Rows) == "table" and options.Rows or {}
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 196), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local title = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 24),
                    Text = name, TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local header = Utility:Create("Frame", {Parent = container, BackgroundColor3 = Library.Theme.Secondary, Position = UDim2.fromOffset(7, 30), Size = UDim2.new(1, -14, 0, 28), BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(header, "BackgroundColor3", "Secondary")
                Utility:Create("UICorner", {Parent = header, CornerRadius = UDim.new(0, 5)})
                local list = Utility:Create("ScrollingFrame", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 63), Size = UDim2.new(1, -14, 1, -70),
                    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6
                })
                Utility:RegisterProperty(list, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIListLayout", {Parent = list, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
                local function cell(parent, text, index, count, bold)
                    local label = Utility:Create("TextLabel", {
                        Parent = parent, BackgroundTransparency = 1, Position = UDim2.new((index - 1) / count, 7, 0, 0),
                        Size = UDim2.new(1 / count, -12, 1, 0), Text = tostring(text or ""), TextColor3 = bold and Library.Theme.Text or Library.Theme.SubText,
                        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = bold and 10 or 11,
                        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = parent.ZIndex + 1
                    })
                    Utility:RegisterProperty(label, "TextColor3", bold and "Text" or "SubText")
                end
                local function render()
                    for _, child in ipairs(header:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
                    for index, column in ipairs(columns) do cell(header, column.Name or column.Label or column.Key or index, index, #columns, true) end
                    for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
                    for rowIndex, rowData in ipairs(rows) do
                        local row = Utility:Create("Frame", {Parent = list, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.3, Size = UDim2.new(1, -4, 0, 30), BorderSizePixel = 0, LayoutOrder = rowIndex, ZIndex = 7})
                        Utility:RegisterProperty(row, "BackgroundColor3", "Secondary")
                        Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 4)})
                        for columnIndex, column in ipairs(columns) do
                            local key = column.Key or column.Field or columnIndex
                            cell(row, type(rowData) == "table" and rowData[key] or rowData, columnIndex, #columns, false)
                        end
                    end
                end
                addElement({Holder = container, Text = name})
                local controller = finishController({Type = "Table"}, container, name, options.Tooltip)
                function controller:SetRows(nextRows) rows = type(nextRows) == "table" and nextRows or {} render() return self end
                function controller:SetColumns(nextColumns) columns = type(nextColumns) == "table" and nextColumns or columns render() return self end
                function controller:AddRow(row) table.insert(rows, row) render() return self end
                function controller:Clear() table.clear(rows) render() return self end
                function controller:GetRows() return rows end
                render()
                return controller
            end

            function Section:CreatePlayerList(options)
                options = options or {}
                local listOptions = {}
                for key, value in pairs(options) do listOptions[key] = value end
                listOptions.Name = options.Name or "Players"
                local userCallback = options.Callback
                listOptions.Callback = function(player) Utility:SafeCall(userCallback, player) end
                local controller = self:CreateList(listOptions)
                controller.Type = "PlayerList"
                local function refreshPlayers()
                    local values = {}
                    for _, player in ipairs(Players:GetPlayers()) do
                        table.insert(values, {Label = player.DisplayName, Description = "@" .. player.Name, Value = player})
                    end
                    table.sort(values, function(a, b) return a.Label:lower() < b.Label:lower() end)
                    controller:SetItems(values)
                end
                Library:Connect(Players.PlayerAdded, function() task.defer(refreshPlayers) end)
                Library:Connect(Players.PlayerRemoving, function() task.defer(refreshPlayers) end)
                refreshPlayers()
                return controller
            end

            function Section:CreateLogConsole(options)
                options = options or {}
                local name = tostring(options.Name or "Console")
                local maxLines = math.max(10, tonumber(options.MaxLines) or 150)
                local entries = {}
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundColor3 = Library.Theme.Main,
                    Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 190), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Main")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local title = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -78, 0, 24), Text = name, TextColor3 = Library.Theme.Text, Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local clearButton = Utility:Create("TextButton", {Parent = container, BackgroundTransparency = 1, Position = UDim2.new(1, -64, 0, 4), Size = UDim2.fromOffset(54, 24), Text = "Clear", TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false, ZIndex = 7})
                Utility:RegisterProperty(clearButton, "TextColor3", "SubText")
                local output = Utility:Create("ScrollingFrame", {Parent = container, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.25, Position = UDim2.fromOffset(7, 31), Size = UDim2.new(1, -14, 1, -38), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(output, "BackgroundColor3", "Secondary")
                Utility:RegisterProperty(output, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIPadding", {Parent = output, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)})
                Utility:Create("UIListLayout", {Parent = output, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})
                local function render()
                    for _, child in ipairs(output:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
                    for index, entry in ipairs(entries) do
                        local semantic = entry.Level == "Error" and "Error" or entry.Level == "Warn" and "Warn" or entry.Level == "Success" and "Success" or "SubText"
                        local line = Utility:Create("TextLabel", {Parent = output, BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 16), AutomaticSize = Enum.AutomaticSize.Y, Text = "[" .. entry.Level .. "] " .. entry.Text, TextColor3 = Library.Theme[semantic], Font = Enum.Font.Code, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = index, ZIndex = 7})
                        Utility:RegisterProperty(line, "TextColor3", semantic)
                    end
                    task.defer(function() output.CanvasPosition = Vector2.new(0, math.max(0, output.AbsoluteCanvasSize.Y)) end)
                end
                addElement({Holder = container, Text = name})
                local controller = finishController({Type = "LogConsole"}, container, name, options.Tooltip)
                function controller:Write(text, level)
                    table.insert(entries, {Text = tostring(text), Level = tostring(level or "Info")})
                    while #entries > maxLines do table.remove(entries, 1) end
                    render() return self
                end
                function controller:Log(text) return self:Write(text, "Info") end
                function controller:Warn(text) return self:Write(text, "Warn") end
                function controller:Error(text) return self:Write(text, "Error") end
                function controller:Success(text) return self:Write(text, "Success") end
                function controller:Clear() table.clear(entries) render() return self end
                function controller:GetEntries() return entries end
                Library:Connect(clearButton.MouseButton1Click, function() controller:Clear() end)
                for _, entry in ipairs(options.Entries or {}) do controller:Write(entry.Text or entry[1] or entry, entry.Level or entry[2]) end
                return controller
            end

            function Section:CreateSkeleton(options)
                options = options or {}
                local lineCount = math.clamp(tonumber(options.Lines) or 3, 1, 8)
                local container = Utility:Create("Frame", {Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, 22 + lineCount * 18), BorderSizePixel = 0, ZIndex = 5})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local bars = {}
                for index = 1, lineCount do
                    local bar = Utility:Create("Frame", {Parent = container, BackgroundColor3 = Library.Theme.Hover, BackgroundTransparency = 0.15, Position = UDim2.new(0, 10, 0, 10 + (index - 1) * 18), Size = UDim2.new(index == lineCount and 0.62 or 1, index == lineCount and -10 or -20, 0, 10), BorderSizePixel = 0, ZIndex = 6})
                    Utility:RegisterProperty(bar, "BackgroundColor3", "Hover")
                    Utility:Create("UICorner", {Parent = bar, CornerRadius = UDim.new(1, 0)})
                    table.insert(bars, bar)
                end
                addElement({Holder = container, Text = tostring(options.Name or "Loading placeholder")})
                local controller = finishController({Type = "Skeleton"}, container, options.Name or "Skeleton")
                local animationToken = 1
                task.spawn(function()
                    local bright = false
                    while animationToken == 1 and container.Parent and not Library.Unloaded do
                        bright = not bright
                        for _, bar in ipairs(bars) do Utility:Tween(bar, TweenInfo.new(0.55), {BackgroundTransparency = bright and 0.48 or 0.15}) end
                        task.wait(0.62)
                    end
                end)
                local destroy = controller.Destroy
                function controller:Destroy() animationToken = 0 destroy(self) end
                return controller
            end

            -- TABBOX (minitabs)
            function Section:CreateTabbox()
                local tabboxContainer = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local buttonBar = Utility:Create("Frame", {
                    Parent = tabboxContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 30),
                    ZIndex = 6
                })
                local buttonLayout = Utility:Create("UIListLayout", {
                    Parent = buttonBar,
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Left,
                    Padding = UDim.new(0, 4)
                })
                local contentArea = Utility:Create("Frame", {
                    Parent = tabboxContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 34),
                    Size = UDim2.new(1, 0, 1, -34),
                    ZIndex = 6,
                    ClipsDescendants = true
                })
                local tabs = {}
                local activeTab = nil

                local function resize()
                    local totalHeight = 34 + (activeTab and activeTab.ContentSize or 0)
                    tabboxContainer.Size = UDim2.new(1, 0, 0, totalHeight)
                    RefreshLayout()
                end

                local tabbox = {
                    AddTab = function(self, tabName, contentBuilder)
                        local btn = Utility:Create("TextButton", {
                            Parent = buttonBar,
                            BackgroundColor3 = Library.Theme.Surface,
                            Size = UDim2.new(0, 80, 1, 0),
                            Text = tabName,
                            TextColor3 = Library.Theme.Text,
                            Font = Enum.Font.GothamBold,
                            TextSize = 12,
                            AutoButtonColor = false,
                            ZIndex = 7
                        })
                        Utility:RegisterProperty(btn, "BackgroundColor3", "Surface")
                        Utility:RegisterProperty(btn, "TextColor3", "Text")
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = btn})
                        local content = Utility:Create("Frame", {
                            Parent = contentArea,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 1, 0),
                            Visible = false,
                            ZIndex = 7
                        })
                        local tab = { Button = btn, Content = content, ContentSize = 0, Built = false }
                        table.insert(tabs, tab)
                        local function activate()
                            for _, t in ipairs(tabs) do
                                t.Content.Visible = false
                                t.Button.BackgroundColor3 = Library.Theme.Surface
                                t.Button.TextColor3 = Library.Theme.Text
                            end
                            content.Visible = true
                            btn.BackgroundColor3 = Library.Theme.Accent
                            btn.TextColor3 = Color3.new(1, 1, 1)
                            activeTab = tab
                            if contentBuilder and not tab.Built then
                                tab.Built = true
                                Utility:SafeCall(contentBuilder, content)
                            end
                            local list = content:FindFirstChildWhichIsA("UIListLayout")
                            if list then
                                tab.ContentSize = list.AbsoluteContentSize.Y
                            else
                                tab.ContentSize = content.AbsoluteSize.Y
                            end
                            resize()
                        end
                        Library:Connect(btn.MouseButton1Click, activate)
                        if #tabs == 1 then task.defer(activate) end
                        return content
                    end
                }
                addElement({Holder = tabboxContainer})
                return tabbox
            end

            return Section
        end

        return Tab
    end

    function Window:CreateDashboard(options)
        options = options or {}
        local dashboardTab = Window:CreateTab({
            Name = options.Name or "Overview",
            Icon = options.Icon or ICONS.Dashboard,
            IsOverview = options.IsNative == true
        })
        local heroHeight = IsMobile and 118 or 132
        local hero = Utility:Create("Frame", {
            Name = "DashboardHero", Parent = dashboardTab.Page,
            BackgroundColor3 = Library.Theme.Surface, BackgroundTransparency = 0,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -4, 0, heroHeight),
            BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3
        })
        Utility:RegisterProperty(hero, "BackgroundColor3", "Surface")
        Utility:RegisterMaterial(hero, 0.28, 0)
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 13), Parent = hero})
        local heroStroke = Utility:Create("UIStroke", {Parent = hero, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(heroStroke, "Color", "Stroke")
        local heroGradient = Utility:Create("UIGradient", {Parent = hero, Rotation = 12})
        Utility:RegisterGradient(heroGradient, "SurfaceAlt", "Surface", "Main")
        local heroRail = Utility:Create("Frame", {
            Parent = hero, BackgroundColor3 = Library.Theme.Accent,
            Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, ZIndex = 4
        })
        Utility:RegisterProperty(heroRail, "BackgroundColor3", "Accent")
        local heroRailGradient = Utility:Create("UIGradient", {Parent = heroRail})
        Utility:RegisterGradient(heroRailGradient, "Accent", "Accent2", "Accent3")

        local avatar = Utility:Create("ImageLabel", {
            Parent = hero, BackgroundColor3 = Library.Theme.Main,
            Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(88, 88),
            Image = Utility:NormalizeAssetId(options.Avatar, ICONS.Profile),
            ScaleType = Enum.ScaleType.Crop, BorderSizePixel = 0, ZIndex = 5
        })
        Utility:RegisterProperty(avatar, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 13), Parent = avatar})
        local avatarStroke = Utility:Create("UIStroke", {Parent = avatar, Color = Library.Theme.Accent, Thickness = 1})
        Utility:RegisterProperty(avatarStroke, "Color", "Accent")

        local greeting = Utility:Create("TextLabel", {
            Parent = hero, BackgroundTransparency = 1, Position = UDim2.fromOffset(128, 31),
            Size = UDim2.new(1, -156, 0, 30), Font = Enum.Font.GothamBold,
            Text = tostring(options.Greeting or ("Welcome, " .. (Plr.DisplayName or Plr.Name))),
            TextColor3 = Library.Theme.Text, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5
        })
        Utility:RegisterProperty(greeting, "TextColor3", "Text")
        local subtitle = Utility:Create("TextLabel", {
            Parent = hero, BackgroundTransparency = 1, Position = UDim2.fromOffset(128, 63),
            Size = UDim2.new(1, -156, 0, 22), Font = Enum.Font.Gotham,
            Text = tostring(options.Subtitle or ("Your control center · @" .. Plr.Name)),
            TextColor3 = Library.Theme.SubText, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5
        })
        Utility:RegisterProperty(subtitle, "TextColor3", "SubText")
        if not Utility:NormalizeAssetId(options.Avatar) then
            task.spawn(function()
                local ok, image = pcall(function()
                    return Players:GetUserThumbnailAsync(tonumber(options.UserId) or Plr.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
                end)
                if ok and avatar.Parent then avatar.Image = image end
            end)
        end

        dashboardTab:SetHeader(hero, heroHeight + 12)
        dashboardTab:OnResponsive(function(mobile)
            heroHeight = mobile and 112 or 132
            hero.Size = UDim2.new(1, -4, 0, heroHeight)
            avatar.Position = mobile and UDim2.fromOffset(14, 20) or UDim2.fromOffset(20, 20)
            avatar.Size = mobile and UDim2.fromOffset(58, 58) or UDim2.fromOffset(88, 88)
            greeting.Position = mobile and UDim2.fromOffset(84, 24) or UDim2.fromOffset(128, 31)
            greeting.Size = mobile and UDim2.new(1, -98, 0, 26) or UDim2.new(1, -156, 0, 30)
            greeting.TextSize = mobile and 17 or 22
            subtitle.Position = mobile and UDim2.fromOffset(84, 51) or UDim2.fromOffset(128, 63)
            subtitle.Size = mobile and UDim2.new(1, -98, 0, 34) or UDim2.new(1, -156, 0, 22)
            subtitle.TextWrapped = mobile
            dashboardTab:SetHeader(hero, heroHeight + 12)
        end)

        local dashboard = {Tab = dashboardTab, Hero = hero, Cards = {}}
        function dashboard:AddCard(cardOptions)
            cardOptions = cardOptions or {}
            local section = dashboardTab:CreateSection({
                Name = cardOptions.Name or "Card",
                Side = cardOptions.Side or "Auto",
                Icon = cardOptions.Icon
            })
            if cardOptions.Description then
                section:CreateParagraph({Content = cardOptions.Description})
            end
            for _, metric in ipairs(cardOptions.Metrics or {}) do
                section:CreateMetric(metric)
            end
            if cardOptions.Action then
                section:CreateButton({
                    Name = cardOptions.Action.Name or "Open",
                    Description = cardOptions.Action.Description,
                    Icon = cardOptions.Action.Icon,
                    Callback = cardOptions.Action.Callback
                })
            end
            table.insert(self.Cards, section)
            return section
        end
        function dashboard:SetGreeting(text) greeting.Text = tostring(text) end
        function dashboard:SetSubtitle(text) subtitle.Text = tostring(text) end
        function dashboard:SetAvatar(asset) avatar.Image = Utility:NormalizeAssetId(asset, avatar.Image) end
        for _, card in ipairs(options.Cards or {}) do dashboard:AddCard(card) end
        return dashboard
    end

    -- Native Overview is always available directly above UI Settings. It is
    -- intentionally created after user-navigation plumbing but outside the
    -- scrollable tab list, so scripts cannot accidentally push it offscreen.
    local NativeOverview = Window:CreateDashboard({
        Name = "Overview",
        IsNative = true,
        Greeting = "Welcome, " .. (Plr.DisplayName or Plr.Name),
        Subtitle = "RenLib session · @" .. Plr.Name,
        Cards = {
            {
                Name = "RenCore launcher",
                Side = "Left",
                Icon = ICONS.Play,
                Description = "Close this RenLib session and return to the official RenCore script selector.",
                Action = {
                    Name = "Relaunch RenCore",
                    Description = "Unload this interface, then start the official RenCore loader.",
                    Icon = ICONS.Restore,
                    Callback = function()
                        Window:Dialog({
                            Title = "Relaunch RenCore?",
                            Content = "RenLib will close this interface and start the official RenCore selector.",
                            Actions = {
                                {Name = "Cancel"},
                                {Name = "Relaunch", Primary = true, Callback = function()
                                    Library:RelaunchRenCore(options.BeforeRelaunch)
                                end}
                            }
                        })
                    end
                }
            },
            {
                Name = "Session",
                Side = "Right",
                Icon = ICONS.Dashboard,
                Metrics = {
                    {Name = "Library", Value = "V" .. Library.Version, Detail = "Current RenLib release"},
                    {Name = "Device", Value = Library.DeviceMode, Detail = "Responsive layout mode"},
                    {Name = "Material", Value = Library.MaterialMode, Detail = "Current window material"}
                }
            }
        }
    })
    Window.OverviewTab = NativeOverview.Tab

    -- Create Settings Tab
    local SettingsTab = Window:CreateTab({
        Name = "UI Settings",
        Emoji = EMOJIS.Settings,
        IsSettings = true
    })
    Window.SettingsTab = SettingsTab

    task.defer(function()
        if not Library.Unloaded and not Window.ActiveTab and Window.OverviewTab then
            Window.OverviewTab:Activate()
        end
    end)

    local UISection = SettingsTab:CreateSection({ Name = "UI Controls", Side = "Left" })
    if not IsMobile then
        UISection:CreateLabel("Toggle UI Key: " .. Library.ToggleKey.Name)
        UISection:CreateButton({
            Name = "Change Toggle Key",
            Callback = function()
                Library:Notify({ Title = "Press Any Key", Content = "Press a key to set as toggle...", Emoji = "⌨️", Duration = 5 })
                local conn
                conn = Library:Connect(UserInputService.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        Library.ToggleKey = input.KeyCode
                        Library:Notify({ Title = "Success", Content = "Toggle key set to: " .. input.KeyCode.Name, Emoji = EMOJIS.Success })
                        conn:Disconnect()
                    end
                end)
            end
        })
    else
        UISection:CreateLabel("Tap the floating RenCore button to toggle UI")
    end
    UISection:CreateButton({ Name = "Minimize UI", Icon = ICONS.Minimize, Callback = function() Window:Minimize() end })
    UISection:CreateButton({ Name = "Close UI", Icon = ICONS.Close, Callback = function() Window:Close() end })

    local AppearanceSection = SettingsTab:CreateSection({ Name = "Appearance & motion", Side = "Right" })
    AppearanceSection:CreateDropdown({
        Name = "Theme preset",
        Values = {"Midnight", "Nebula", "Celestial", "Rose", "Aurora", "Ember", "Prism Frost", "Moss Archive", "Velvet Latte"},
        Default = Library.ActiveTheme or "Midnight",
        Flag = "__RenLibTheme",
        Callback = function(theme)
            Library:ApplyThemePreset(theme)
        end
    })
    AppearanceSection:CreateDropdown({
        Name = "Window material",
        Values = {"Solid", "Frosted"},
        Default = Library.MaterialMode,
        Flag = "__RenLibMaterial",
        Callback = function(mode)
            Library:SetMaterialMode(mode)
        end
    })
    AppearanceSection:CreateSlider({
        Name = "Glass transparency",
        Min = 0,
        Max = 32,
        Step = 2,
        Default = Library.MaterialIntensity,
        Flag = "__RenLibFrostIntensity",
        CallbackMode = "Release",
        Callback = function(value) Library:SetMaterialIntensity(value) end
    })
    local ScaleSlider = AppearanceSection:CreateSlider({
        Name = "UI scale",
        Min = 100,
        Max = 150,
        Step = 5,
        Default = math.floor(Library.DPIScale * 100),
        Flag = "__RenLibScale",
        CallbackMode = "Release",
        Callback = function(scale)
            task.defer(function() Library:PreviewDPIScale(scale, 10) end)
        end
    })
    AppearanceSection:CreateButton({
        Name = "Reset UI size",
        Description = "Preview the safe 100% size with the same 10-second recovery.",
        Icon = ICONS.Restore,
        Callback = function()
            ScaleSlider:SetSilent(100)
            Library:PreviewDPIScale(100, 10)
        end
    })
    AppearanceSection:CreateToggle({
        Name = "Reduced motion",
        Default = Library.ReducedMotion,
        Flag = "__RenLibReducedMotion",
        Callback = function(enabled) Library:SetReducedMotion(enabled) end
    })
    AppearanceSection:CreateParagraph({
        Title = "Responsive by default",
        Content = "RenLib reflows from the UI's real visible width, so small scales and phones use one safe column. Frosted material is local to the RenLib window and never changes the game screen."
    })

    local UtilitySection = SettingsTab:CreateSection({ Name = "Utilities", Side = "Right" })
    UtilitySection:CreateButton({
        Name = "Keybind manager",
        Description = "Review, edit, or reset every registered shortcut in one place.",
        Icon = ICONS.Menu,
        Callback = function() Window:ShowKeybindManager() end
    })
    if options.ShowInfiniteYield == nil or options.ShowInfiniteYield then
        UtilitySection:CreateButton({
            Name = "Launch Infinite Yield",
            Description = "Fetch the current official EdgeIY source after confirmation.",
            Icon = ICONS.Play,
            Callback = function()
                Window:Dialog({
                    Title = "Launch Infinite Yield?",
                    Content = "This downloads and runs the current script directly from the official EdgeIY/infiniteyield repository.",
                    Actions = {
                        {Name = "Cancel"},
                        {Name = "Launch", Primary = true, Callback = function() Library:LaunchInfiniteYield() end}
                    }
                })
            end
        })
    end

    local ConfigSection = SettingsTab:CreateSection({ Name = "Configuration", Side = "Left" })
    local configNames = Library:GetConfigList()
    local selectedConfig = configNames[1]
    local desiredConfigName = selectedConfig or "default"
    local ConfigDropdown, AutoloadStatus

    local function hasConfig(name, values)
        for _, item in ipairs(values or {}) do if item == name then return true end end
        return false
    end

    local function refreshConfigManager(preferred)
        configNames = Library:GetConfigList()
        local target
        if preferred and hasConfig(preferred, configNames) then
            target = preferred
        elseif hasConfig(selectedConfig, configNames) then
            target = selectedConfig
        else
            target = configNames[1]
        end
        if ConfigDropdown then
            ConfigDropdown:Refresh(configNames)
            selectedConfig = target
            if target then ConfigDropdown:Set(target) end
        else
            selectedConfig = target
        end
        if AutoloadStatus then
            AutoloadStatus:SetContent(Library:GetAutoloadConfigName() or "None")
        end
    end

    ConfigDropdown = ConfigSection:CreateDropdown({
        Name = "Saved configs",
        Values = configNames,
        Default = selectedConfig,
        Flag = "__RenLibConfigSelection",
        Callback = function(value) selectedConfig = value end
    })
    ConfigSection:CreateInput({
        Name = "Config name / rename target",
        Default = desiredConfigName,
        Placeholder = "default",
        Flag = "__RenLibConfigName",
        Callback = function(value) desiredConfigName = cleanConfigName(value) end
    })
    AutoloadStatus = ConfigSection:CreateParagraph({
        Title = "Current autoload",
        Content = Library:GetAutoloadConfigName() or "None"
    })
    ConfigSection:CreateButton({Name = "Save or overwrite", Callback = function()
        local ok, err = Library:SaveConfig(desiredConfigName)
        if ok then selectedConfig = desiredConfigName; refreshConfigManager(desiredConfigName) end
        Library:Notify({Title = ok and "Config saved" or "Save unavailable", Content = ok and desiredConfigName or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Load selected", Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Save or select a config first.", Duration = 3})
            return
        end
        local ok, err = Library:LoadConfig(selectedConfig)
        Library:Notify({Title = ok and "Config loaded" or "Load failed", Content = ok and selectedConfig or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Rename selected", Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Choose a saved config first.", Duration = 3})
            return
        end
        local oldName = selectedConfig
        local ok, err = Library:RenameConfig(oldName, desiredConfigName)
        if ok then selectedConfig = desiredConfigName; refreshConfigManager(desiredConfigName) end
        Library:Notify({Title = ok and "Config renamed" or "Rename failed", Content = ok and (oldName .. " → " .. desiredConfigName) or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Set selected as autoload", Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Choose a saved config first.", Duration = 3})
            return
        end
        local ok, err = Library:SetAutoloadConfig(selectedConfig)
        refreshConfigManager(selectedConfig)
        Library:Notify({Title = ok and "Autoload set" or "Autoload unavailable", Content = ok and selectedConfig or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Delete selected", Icon = EMOJIS.Trash, Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Choose a saved config first.", Duration = 3})
            return
        end
        local deleting = selectedConfig
        Window:Dialog({
            Title = "Delete " .. deleting .. "?",
            Content = "This permanently removes the saved config. Its autoload link will also be cleared.",
            Actions = {
                {Name = "Cancel"},
                {Name = "Delete", Primary = true, Callback = function()
                    local ok, err = Library:DeleteConfig(deleting)
                    if ok then selectedConfig = nil; refreshConfigManager() end
                    Library:Notify({Title = ok and "Config deleted" or "Delete failed", Content = ok and deleting or tostring(err), Duration = 3})
                end}
            }
        })
    end})
    ConfigSection:CreateButton({Name = "Clear autoload", Callback = function()
        local ok, err = Library:ClearAutoloadConfig()
        refreshConfigManager(selectedConfig)
        Library:Notify({Title = ok and "Autoload cleared" or "Clear failed", Content = ok and "No config will load automatically." or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Refresh config list", Icon = EMOJIS.Refresh, Callback = function()
        refreshConfigManager(selectedConfig)
    end})

    Library:Connect(SettingsBtn.MouseButton1Click, function()
        if SettingsTab then
            SettingsTab:Activate()
        end
    end)

    Library.Window = Window
    return Window
end

--// UNLOAD
function Library:Unload(reason)
    if self.Unloaded then return end
    self.Unloaded = true
    self.ScalePreview = nil
    for index = #self.AddonOrder, 1, -1 do
        self:UnregisterAddon(self.AddonOrder[index])
    end
    for _, tween in pairs(self.ActiveTweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, tween in pairs(self.LayoutTweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, tween in pairs(self.VisibilityTweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, conn in pairs(Library.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if Library.ScreenGui then
        Library.ScreenGui:Destroy()
    end
    table.clear(self.Connections)
    table.clear(self.Registry)
    table.clear(self.GradientRegistry)
    table.clear(self.MaterialRegistry)
    table.clear(self.MaterialDecorations)
    table.clear(self.BrandMarks)
    table.clear(self.Scales)
    table.clear(self.Options)
    table.clear(self.KeybindList)
    table.clear(self.KeybindDefaults)
    table.clear(self.PendingAutoloadFlags)
    table.clear(self.LayoutTweens)
    table.clear(self.VisibilityTweens)
    self.Window = nil
    self.KeybindManager = nil
    self.ScreenGui = nil
    if RuntimeEnvironment[RUNTIME_KEY] == self then RuntimeEnvironment[RUNTIME_KEY] = nil end
    print("[RenLib] Unloaded" .. (reason and (" (" .. tostring(reason) .. ")") or ""))
end

--// TOGGLE KEY (PC only)
Library:Connect(UserInputService.InputBegan, function(input, gpe)
    if gpe then return end
    if input.KeyCode == Library.ToggleKey then
        if Library.Window then Library.Window:Toggle() end
    end
end)

RuntimeEnvironment[RUNTIME_KEY] = Library
ensureConfigFolders()
Library:PrepareAutoloadConfig()

print("[RenLib] Loaded - Version " .. Library.Version .. " (" .. Library.DeviceMode .. ")")

return Library
end)()

Window = RenLib:CreateWindow({
	Name = "Fishing AutoFarm",
	Width = 860,
	Height = 560,
	DisplayOrder = 1000,
	ShowUserProfile = true,
	ProfileUserId = LocalPlayer.UserId,
	ProfileSubtitle = "GUI-only automation",
	ShowInfiniteYield = false,
	EnableGlobalSearch = false,
	EnableSidebarResize = true,
	SidebarMode = "Dynamic",
	MaterialMode = "Solid",
})

local FishingTab = Window:CreateTab({
	Name = "Fishing",
	Icon = RenLib.Icons.Play,
})

local AutomationSection = FishingTab:CreateSection({
	Name = "Automation",
	Side = "Left",
	Icon = RenLib.Icons.Play,
})

local CastSection = FishingTab:CreateSection({
	Name = "Casting",
	Side = "Right",
	Icon = RenLib.Icons.Star or RenLib.Icons.Play,
})

local RuntimeSection = FishingTab:CreateSection({
	Name = "Runtime",
	Side = "Right",
	Icon = RenLib.Icons.Terminal or RenLib.Icons.Info,
})

uiControls.FullAuto = AutomationSection:CreateToggle({
	Name = "Full AutoFarm",
	Flag = "FishingFullAuto",
	Default = false,
	Tooltip = "Enables equip, cast, shake, and reel together.",
	Callback = applyMaster,
})

uiControls.AutoEquip = AutomationSection:CreateToggle({
	Name = "Auto Equip Rod",
	Flag = "FishingAutoEquip",
	Default = false,
	Callback = setAutoEquip,
})

uiControls.AutoCast = AutomationSection:CreateToggle({
	Name = "Auto Cast",
	Flag = "FishingAutoCast",
	Default = false,
	Callback = setAutoCast,
})

uiControls.AutoShake = AutomationSection:CreateToggle({
	Name = "Auto Shake",
	Flag = "FishingAutoShake",
	Default = false,
	Callback = setAutoShake,
})

uiControls.AutoReel = AutomationSection:CreateToggle({
	Name = "Auto Reel",
	Flag = "FishingAutoReel",
	Default = false,
	Tooltip = "Uses the calibrated fixed hybrid reel controller.",
	Callback = setAutoReel,
})

local castModeParagraph

uiControls.FastCast = CastSection:CreateToggle({
	Name = "Fast Cast",
	Flag = "FishingFastCast",
	Default = false,
	Tooltip = "OFF uses Perfect Cast. ON releases as soon as the visible charge meter appears.",
	Callback = function(value)
		Settings.CastMode =
			value and "Fast Cast" or "Perfect Cast"

		if castModeParagraph
			and castModeParagraph.SetContent
		then
			castModeParagraph:SetContent(
				Settings.CastMode
			)
		end

		if castSession and not castSession.Released then
			setStatus(
				"Cast mode changed to "
					.. Settings.CastMode
			)
		end
	end,
})

castModeParagraph = CastSection:CreateParagraph({
	Title = "Current cast mode",
	Content = Settings.CastMode,
})

CastSection:CreateParagraph({
	Title = "Cast behavior",
	Content = "Perfect Cast releases predictively inside the target. If visual tracking fails, it immediately completes the current cast instead of waiting. Fast Cast releases when the visible meter first appears.",
})

statusControl = RuntimeSection:CreateParagraph({
	Title = "Status",
	Content = "Ready",
})

inputControl = RuntimeSection:CreateParagraph({
	Title = "Input backend",
	Content = "Waiting",
})

RuntimeSection:CreateParagraph({
	Title = "Performance safeguards",
	Content = "Bounded calibration samples, weak GUI caches, cached cast descendants, cancellable delayed casts, lifecycle-managed connections, and no per-frame full-GUI scans.",
})

-- Runtime event wiring -------------------------------------------------------

disconnectBucket(backpackContainerConnections)
watchRodContainer(
	backpack(),
	backpackContainerConnections
)

disconnectBucket(characterContainerConnections)
watchRodContainer(
	character(),
	characterContainerConnections
)

addConnection(LocalPlayer.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		disconnectBucket(backpackContainerConnections)
		watchRodContainer(
			child,
			backpackContainerConnections
		)
		task.defer(refreshRod)
	end
end))

addConnection(LocalPlayer.CharacterAdded:Connect(function(newCharacter)
	disconnectBucket(characterContainerConnections)
	watchRodContainer(
		newCharacter,
		characterContainerConnections
	)

	task.defer(function()
		refreshRod()

		if Settings.AutoEquip then
			tryEquip()
		end
	end)
end))

addConnection(PlayerGui.ChildAdded:Connect(function(child)
	if isShakeGuiCandidate(child)
		and Settings.AutoShake
	then
		attachShakeGui(child)
	elseif child.Name == "reel"
		and child:IsA("LayerCollector")
	then
		attachReelGui(child)
	end
end))

addConnection(PlayerGui.ChildRemoved:Connect(function(child)
	if child == activeShakeGui then
		activeShakeGui = nil
		shakeScanGeneration += 1
		table.clear(shakeCandidates)
		disconnectBucket(shakeConnections)
	elseif child == activeReelGui then
		activeReelGui = nil
		stopReel()
		disconnectBucket(reelGuiConnections)

		if Settings.AutoCast then
			scheduleNextCast()
		end
	end
end))

function App.Destroy(fromRenLib)
	if destroyed then
		return
	end

	destroyed = true
	cancelScheduledCast()

	Settings.FullAutoFarm = false
	Settings.AutoEquip = false
	Settings.AutoCast = false
	Settings.AutoShake = false
	Settings.AutoReel = false

	clearCastSession()
	stopReel()
	Input.ReleaseAll()

	shakeScanGeneration += 1
	table.clear(shakeCandidates)
	table.clear(shakeButtonStates)
	resetCalibrationSamples()

	disconnectBucket(shakeConnections)
	disconnectBucket(reelGuiConnections)
	disconnectBucket(rodConnections)
	disconnectBucket(characterContainerConnections)
	disconnectBucket(backpackContainerConnections)
	disconnectBucket(connections)

	statusControl = nil
	inputControl = nil
	table.clear(uiControls)

	if not fromRenLib
		and RenLib
		and not RenLib.Unloaded
	then
		RenLib:Unload("Fishing AutoFarm stopped")
	end

	if rawget(_G, SINGLETON_KEY) == App then
		_G[SINGLETON_KEY] = nil
	end
end

RenLib:RegisterAddon("FishingAutoFarmRuntime", {
	AutoStart = true,
	Start = function()
		setStatus("Ready — enable Full AutoFarm")
	end,
	Stop = function() end,
	Unload = function()
		App.Destroy(true)
	end,
})

refreshRod()

local shakeGui = existingShakeGui()
if shakeGui and Settings.AutoShake then
	attachShakeGui(shakeGui)
end

local reelGui = existingReelGui()
if reelGui then
	attachReelGui(reelGui)
end

setStatus("Ready — enable Full AutoFarm")
setInputStatus("waiting")
