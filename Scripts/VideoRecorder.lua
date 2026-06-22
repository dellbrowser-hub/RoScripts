--// Recorder Cinematic Script V2
--// RenLib UI + Freecam + Recording Mode + Physics Ghost + Smooth Keyframes + Curve Freecam
--// LocalScript / in-game executor script

--====================================================
-- CLEAN OLD VERSION
--====================================================

local GLOBAL_NAME = "__RECORDER_CINEMATIC_SCRIPT_V2"

if getgenv and getgenv()[GLOBAL_NAME] and getgenv()[GLOBAL_NAME].Cleanup then
	pcall(function()
		getgenv()[GLOBAL_NAME].Cleanup()
	end)
end

local Recorder = {}

if getgenv then
	getgenv()[GLOBAL_NAME] = Recorder
end

--====================================================
-- SERVICES
--====================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

while not Camera do
	task.wait()
	Camera = Workspace.CurrentCamera
end

local Mouse = LocalPlayer:GetMouse()

--====================================================
-- RENLIB UI
--====================================================

local RenLib
do
	local ok, result = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"))()
	end)

	if not ok then
		warn("[Recorder V2] RenLib failed to load:", result)
		return
	end

	RenLib = result
end

local Window = RenLib:CreateWindow({
	Name = "Recorder Script V2",
	SidebarMode = "Dynamic",
	ShowUserProfile = true,
	EnableGlobalSearch = true,
})

local function Notify(title, text, duration)
	pcall(function()
		RenLib:Notify({
			Title = title or "Recorder",
			Content = text or "",
			Duration = duration or 4
		})
	end)
end

--====================================================
-- SETTINGS / STATE
--====================================================

local Settings = {
	FreecamSpeed = 35,
	FreecamFastMultiplier = 3,
	FreecamSmoothness = 12,
	MouseSensitivity = 0.0025,

	DesyncCharacterMovement = true,
	HideCoreGui = true,

	PlaybackSegmentTime = 2.5,
	PlaybackSmoothPath = true,
	PlaybackLoop = false,
	StopAtEachKeyframe = false,
	KeyframePauseTime = 0.45,

	AutoHideGameUIWhenRecording = false,

	Curve = {
		Enabled = false,

		LockAngle = true,
		SliderMode = true,

		LockX = false,
		LockY = true,
		LockZ = false,

		X = 0,
		Y = 0,
		Z = 0,

		Yaw = 0,
		Pitch = 0
	}
}

local Connections = {}
local KeyDown = {}

local RuntimeFolder = Instance.new("Folder")
RuntimeFolder.Name = "Recorder_Runtime"
RuntimeFolder.Parent = Workspace

local FreecamEnabled = false
local MouseLook = false
local FreecamCFrame = Camera.CFrame
local CamYaw = 0
local CamPitch = 0
local FreecamVelocity = Vector3.zero

local UIHidden = false
local HiddenGuiStates = {}

local RecordingMode = false

local PhysicsGhostModel = nil
local PhysicsGhostWeld = nil
local CameraFollowingGhost = false

local Keyframes = {}
local KeyframeMarkers = {}

local PlaybackRunning = false
local ResumeFreecamAfterPlayback = false

--====================================================
-- HELPERS
--====================================================

local function AddConnection(connection)
	table.insert(Connections, connection)
	return connection
end

local function IsTyping()
	return UserInputService:GetFocusedTextBox() ~= nil
end

local function GetHumanoid()
	local character = LocalPlayer.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function GetYawPitchFromCFrame(cf)
	local look = cf.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	return yaw, pitch
end

local function SmoothAlpha(dt, smoothness)
	return 1 - math.exp(-dt * smoothness)
end

local function EaseSmooth(t)
	return t * t * (3 - 2 * t)
end

local function IsRecorderGui(gui)
	local name = string.lower(gui.Name)
	return name:find("rayfield") or name:find("recorder")
end

local function SetModelAnchored(model, anchored)
	if not model then
		return
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = anchored
		end
	end
end

local function SetModelCollision(model, canCollide)
	if not model then
		return
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CanCollide = canCollide
		end
	end
end

local function DestroyModel(model)
	if model then
		pcall(function()
			model:Destroy()
		end)
	end
end

local function CatmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t

	return 0.5 * (
		(2 * p1)
		+ (-p0 + p2) * t
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
		+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

--====================================================
-- GHOST VISIBILITY / RECORDING MODE
--====================================================

local function SetGhostsVisible(visible)
	for _, obj in ipairs(RuntimeFolder:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.LocalTransparencyModifier = visible and 0 or 1
		elseif obj:IsA("BillboardGui") then
			obj.Enabled = visible
		end
	end
end

local function RefreshGhostVisibility()
	SetGhostsVisible(not RecordingMode)
end

local function StartRecordingMode()
	if RecordingMode then
		return
	end

	RecordingMode = true
	SetGhostsVisible(false)

	if Settings.AutoHideGameUIWhenRecording then
		-- defined later, called safely
		task.defer(function()
			if Recorder.HideGameUI then
				Recorder.HideGameUI()
			end
		end)
	end

	Notify("Recording Mode", "Ghosts and keyframe labels are now invisible.")
end

local function StopRecordingMode()
	if not RecordingMode then
		return
	end

	RecordingMode = false
	SetGhostsVisible(true)

	if Settings.AutoHideGameUIWhenRecording then
		task.defer(function()
			if Recorder.RestoreGameUI then
				Recorder.RestoreGameUI()
			end
		end)
	end

	Notify("Recording Mode", "Ghosts and keyframe labels are visible again.")
end

local function ToggleRecordingMode()
	if RecordingMode then
		StopRecordingMode()
	else
		StartRecordingMode()
	end
end

--====================================================
-- CAMERA CONTROL
--====================================================

local function ReturnCameraToPlayer()
	RunService:UnbindFromRenderStep("Recorder_Freecam")
	RunService:UnbindFromRenderStep("Recorder_Playback")
	RunService:UnbindFromRenderStep("Recorder_GhostFollow")

	FreecamEnabled = false
	PlaybackRunning = false
	CameraFollowingGhost = false

	ContextActionService:UnbindAction("Recorder_SinkMovement")

	Camera.CameraType = Enum.CameraType.Custom

	local humanoid = GetHumanoid()
	if humanoid then
		Camera.CameraSubject = humanoid
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

--====================================================
-- UI HIDER
--====================================================

local function HideGameUI()
	if UIHidden then
		return
	end

	UIHidden = true
	HiddenGuiStates = {}

	for _, gui in ipairs(PlayerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and not IsRecorderGui(gui) then
			HiddenGuiStates[gui] = gui.Enabled
			gui.Enabled = false
		end
	end

	if Settings.HideCoreGui then
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
	end

	Notify("Recorder", "Game UI hidden.")
end

local function RestoreGameUI()
	if not UIHidden then
		return
	end

	UIHidden = false

	for gui, oldState in pairs(HiddenGuiStates) do
		if gui and gui.Parent then
			gui.Enabled = oldState
		end
	end

	table.clear(HiddenGuiStates)

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)

	Notify("Recorder", "Game UI restored.")
end

Recorder.HideGameUI = HideGameUI
Recorder.RestoreGameUI = RestoreGameUI

AddConnection(PlayerGui.ChildAdded:Connect(function(gui)
	if UIHidden and gui:IsA("ScreenGui") and not IsRecorderGui(gui) then
		task.wait()
		HiddenGuiStates[gui] = gui.Enabled
		gui.Enabled = false
	end
end))

--====================================================
-- INPUT
--====================================================

AddConnection(UserInputService.InputBegan:Connect(function(input)
	if IsTyping() then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		MouseLook = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	if input.KeyCode then
		KeyDown[input.KeyCode] = true
	end
end))

AddConnection(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		MouseLook = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	if input.KeyCode then
		KeyDown[input.KeyCode] = false
	end
end))

local function SinkMovementAction()
	return Enum.ContextActionResult.Sink
end

local function BindMovementSink()
	ContextActionService:BindActionAtPriority(
		"Recorder_SinkMovement",
		SinkMovementAction,
		false,
		9999,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Space,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right
	)
end

local function UnbindMovementSink()
	ContextActionService:UnbindAction("Recorder_SinkMovement")
end

--====================================================
-- CURVE FREECAM
--====================================================

local function CaptureCurvePosition()
	local pos = Camera.CFrame.Position
	Settings.Curve.X = pos.X
	Settings.Curve.Y = pos.Y
	Settings.Curve.Z = pos.Z
	Notify("Curve Freecam", "Captured current X/Y/Z position.")
end

local function CaptureCurveAngle()
	local yaw, pitch = GetYawPitchFromCFrame(Camera.CFrame)
	Settings.Curve.Yaw = yaw
	Settings.Curve.Pitch = pitch
	Notify("Curve Freecam", "Captured current camera angle.")
end

local function CaptureCurveAll()
	CaptureCurvePosition()
	CaptureCurveAngle()
end

local function ApplyCurveConstraints(position)
	if not Settings.Curve.Enabled then
		return position
	end

	local x = position.X
	local y = position.Y
	local z = position.Z

	if Settings.Curve.LockX then
		x = Settings.Curve.X
	end

	if Settings.Curve.LockY then
		y = Settings.Curve.Y
	end

	if Settings.Curve.LockZ then
		z = Settings.Curve.Z
	end

	return Vector3.new(x, y, z)
end

local function SetCurveFreecam(value)
	Settings.Curve.Enabled = value

	if value then
		CaptureCurveAll()

		if not FreecamEnabled then
			task.defer(function()
				-- EnableFreecam is defined later, so this is called safely after script loads
				if Recorder.EnableFreecam then
					Recorder.EnableFreecam()
				end
			end)
		end

		Notify("Curve Freecam", "Enabled. Current position and angle captured.")
	else
		Notify("Curve Freecam", "Disabled.")
	end
end

--====================================================
-- FREECAM
--====================================================

local function EnableFreecam()
	if FreecamEnabled then
		return
	end

	FreecamEnabled = true
	PlaybackRunning = false

	RunService:UnbindFromRenderStep("Recorder_Playback")

	Camera.CameraType = Enum.CameraType.Scriptable
	FreecamCFrame = Camera.CFrame
	CamYaw, CamPitch = GetYawPitchFromCFrame(FreecamCFrame)
	FreecamVelocity = Vector3.zero

	if Settings.DesyncCharacterMovement then
		BindMovementSink()
	end

	RunService:BindToRenderStep("Recorder_Freecam", Enum.RenderPriority.Camera.Value + 10, function(dt)
		if not FreecamEnabled then
			return
		end

		if Settings.Curve.Enabled and Settings.Curve.LockAngle then
			CamYaw = Settings.Curve.Yaw
			CamPitch = Settings.Curve.Pitch
		else
			if MouseLook and not IsTyping() then
				local delta = UserInputService:GetMouseDelta()
				CamYaw -= delta.X * Settings.MouseSensitivity
				CamPitch = math.clamp(
					CamPitch - delta.Y * Settings.MouseSensitivity,
					math.rad(-85),
					math.rad(85)
				)
			end
		end

		local rotation =
			CFrame.Angles(0, CamYaw, 0)
			* CFrame.Angles(-CamPitch, 0, 0)

		local direction = Vector3.zero

		if Settings.Curve.Enabled and Settings.Curve.SliderMode then
			-- Stabilized slider mode:
			-- A/D moves sideways along captured camera angle.
			-- E/Space and Q/Shift move vertically unless Y is locked.
			if KeyDown[Enum.KeyCode.D] or KeyDown[Enum.KeyCode.Right] then
				direction += rotation.RightVector
			end

			if KeyDown[Enum.KeyCode.A] or KeyDown[Enum.KeyCode.Left] then
				direction -= rotation.RightVector
			end

			if KeyDown[Enum.KeyCode.Space] or KeyDown[Enum.KeyCode.E] then
				direction += Vector3.yAxis
			end

			if KeyDown[Enum.KeyCode.LeftShift] or KeyDown[Enum.KeyCode.Q] then
				direction -= Vector3.yAxis
			end
		else
			-- Normal freecam movement.
			if KeyDown[Enum.KeyCode.W] or KeyDown[Enum.KeyCode.Up] then
				direction += rotation.LookVector
			end

			if KeyDown[Enum.KeyCode.S] or KeyDown[Enum.KeyCode.Down] then
				direction -= rotation.LookVector
			end

			if KeyDown[Enum.KeyCode.D] or KeyDown[Enum.KeyCode.Right] then
				direction += rotation.RightVector
			end

			if KeyDown[Enum.KeyCode.A] or KeyDown[Enum.KeyCode.Left] then
				direction -= rotation.RightVector
			end

			if KeyDown[Enum.KeyCode.Space] or KeyDown[Enum.KeyCode.E] then
				direction += Vector3.yAxis
			end

			if KeyDown[Enum.KeyCode.LeftShift] or KeyDown[Enum.KeyCode.Q] then
				direction -= Vector3.yAxis
			end
		end

		if direction.Magnitude > 0 then
			direction = direction.Unit
		end

		local speed = Settings.FreecamSpeed

		if KeyDown[Enum.KeyCode.LeftControl] then
			speed *= Settings.FreecamFastMultiplier
		end

		local alpha = SmoothAlpha(dt, Settings.FreecamSmoothness)
		FreecamVelocity = FreecamVelocity:Lerp(direction * speed, alpha)

		local newPosition = FreecamCFrame.Position + FreecamVelocity * dt
		newPosition = ApplyCurveConstraints(newPosition)

		FreecamCFrame =
			CFrame.new(newPosition)
			* CFrame.Angles(0, CamYaw, 0)
			* CFrame.Angles(-CamPitch, 0, 0)

		Camera.CFrame = FreecamCFrame
	end)

	Notify("Recorder", "Freecam enabled. Hold right click to look around.")
end

Recorder.EnableFreecam = EnableFreecam

local function DisableFreecam(keepScriptable)
	if not FreecamEnabled then
		return
	end

	FreecamEnabled = false

	RunService:UnbindFromRenderStep("Recorder_Freecam")
	UnbindMovementSink()

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	if not keepScriptable and not PlaybackRunning and not CameraFollowingGhost then
		ReturnCameraToPlayer()
	end

	Notify("Recorder", "Freecam disabled.")
end

local function ToggleFreecam(value)
	if value then
		EnableFreecam()
	else
		DisableFreecam(false)
	end
end

--====================================================
-- PHYSICS GHOST CAMERA
--====================================================

local function CreateCameraModel(cf, color, name, labelText)
	local model = Instance.new("Model")
	model.Name = name

	local body = Instance.new("Part")
	body.Name = "CameraBody"
	body.Size = Vector3.new(1.2, 0.75, 0.75)
	body.CFrame = cf
	body.Color = color
	body.Material = Enum.Material.Neon
	body.Transparency = 0.5
	body.Anchored = true
	body.CanCollide = false
	body.Massless = false
	body.Parent = model

	local lens = Instance.new("Part")
	lens.Name = "CameraLens"
	lens.Shape = Enum.PartType.Cylinder
	lens.Size = Vector3.new(0.45, 0.45, 0.45)
	lens.CFrame = cf * CFrame.new(0, 0, -0.58) * CFrame.Angles(0, math.rad(90), 0)
	lens.Color = color
	lens.Material = Enum.Material.Neon
	lens.Transparency = 0.25
	lens.Anchored = true
	lens.CanCollide = false
	lens.Massless = true
	lens.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = lens
	weld.Parent = body

	if labelText then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "RecorderLabel"
		billboard.Size = UDim2.new(0, 100, 0, 28)
		billboard.StudsOffset = Vector3.new(0, 1.15, 0)
		billboard.AlwaysOnTop = true
		billboard.Enabled = not RecordingMode
		billboard.Parent = body

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 0.25
		text.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.Text = labelText
		text.Parent = billboard
	end

	model.PrimaryPart = body
	model.Parent = RuntimeFolder

	task.defer(RefreshGhostVisibility)

	return model
end

local function DeletePhysicsGhost()
	if PhysicsGhostWeld then
		PhysicsGhostWeld:Destroy()
		PhysicsGhostWeld = nil
	end

	DestroyModel(PhysicsGhostModel)
	PhysicsGhostModel = nil

	if CameraFollowingGhost then
		CameraFollowingGhost = false
		RunService:UnbindFromRenderStep("Recorder_GhostFollow")
	end
end

local function SpawnPhysicsGhostAtCamera()
	DeletePhysicsGhost()

	PhysicsGhostModel = CreateCameraModel(
		Camera.CFrame,
		Color3.fromRGB(0, 170, 255),
		"Recorder_PhysicsGhostCamera",
		"PHYS CAM"
	)

	SetModelAnchored(PhysicsGhostModel, true)
	SetModelCollision(PhysicsGhostModel, true)

	RefreshGhostVisibility()

	Notify("Recorder", "Physics ghost camera spawned.")
end

local function LockGhostToMouseTarget()
	if not PhysicsGhostModel or not PhysicsGhostModel.PrimaryPart then
		Notify("Recorder", "Spawn the physics ghost first.", 3)
		return
	end

	local target = Mouse.Target

	if not target or not target:IsA("BasePart") then
		Notify("Recorder", "Aim at a block/part first.", 3)
		return
	end

	if target:IsDescendantOf(PhysicsGhostModel) then
		Notify("Recorder", "You cannot lock the ghost to itself.", 3)
		return
	end

	if PhysicsGhostWeld then
		PhysicsGhostWeld:Destroy()
		PhysicsGhostWeld = nil
	end

	SetModelAnchored(PhysicsGhostModel, false)
	SetModelCollision(PhysicsGhostModel, false)

	local body = PhysicsGhostModel.PrimaryPart

	PhysicsGhostWeld = Instance.new("WeldConstraint")
	PhysicsGhostWeld.Name = "Recorder_GhostLockWeld"
	PhysicsGhostWeld.Part0 = body
	PhysicsGhostWeld.Part1 = target
	PhysicsGhostWeld.Parent = body

	Notify("Recorder", "Ghost locked to: " .. target.Name)
end

local function ToggleGhostAnchor(anchored)
	if not PhysicsGhostModel then
		Notify("Recorder", "No physics ghost exists.", 3)
		return
	end

	if anchored and PhysicsGhostWeld then
		PhysicsGhostWeld:Destroy()
		PhysicsGhostWeld = nil
	end

	SetModelAnchored(PhysicsGhostModel, anchored)
	SetModelCollision(PhysicsGhostModel, not anchored)

	if anchored then
		Notify("Recorder", "Ghost camera anchored.")
	else
		Notify("Recorder", "Ghost camera unanchored. It can fall now.")
	end
end

local function SetCameraFollowGhost(value)
	if value then
		if not PhysicsGhostModel or not PhysicsGhostModel.PrimaryPart then
			Notify("Recorder", "Spawn the physics ghost first.", 3)
			return
		end

		DisableFreecam(true)

		CameraFollowingGhost = true
		Camera.CameraType = Enum.CameraType.Scriptable

		RunService:BindToRenderStep("Recorder_GhostFollow", Enum.RenderPriority.Camera.Value + 11, function()
			if PhysicsGhostModel and PhysicsGhostModel.PrimaryPart then
				Camera.CFrame = PhysicsGhostModel.PrimaryPart.CFrame
			end
		end)

		Notify("Recorder", "Camera now follows physics ghost.")
	else
		CameraFollowingGhost = false
		RunService:UnbindFromRenderStep("Recorder_GhostFollow")
		Notify("Recorder", "Camera stopped following ghost.")
	end
end

--====================================================
-- KEYFRAMES
--====================================================

local function CreateKeyframeMarker(index, cf)
	local model = CreateCameraModel(
		cf,
		Color3.fromRGB(190, 70, 255),
		"Recorder_Keyframe_" .. tostring(index),
		"KF " .. tostring(index)
	)

	SetModelAnchored(model, true)
	SetModelCollision(model, false)

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Size *= 0.7
			obj.Transparency = 0.35
		end
	end

	RefreshGhostVisibility()

	return model
end

local function AddKeyframe()
	local cf = Camera.CFrame

	table.insert(Keyframes, {
		CFrame = cf,
		FOV = Camera.FieldOfView
	})

	local index = #Keyframes
	local marker = CreateKeyframeMarker(index, cf)
	KeyframeMarkers[index] = marker

	Notify("Recorder", "Added keyframe #" .. tostring(index))
end

local function ClearKeyframes()
	for _, marker in ipairs(KeyframeMarkers) do
		DestroyModel(marker)
	end

	table.clear(Keyframes)
	table.clear(KeyframeMarkers)

	Notify("Recorder", "All keyframes cleared.")
end

local function JumpToKeyframe(index)
	local keyframe = Keyframes[index]

	if not keyframe then
		Notify("Recorder", "Keyframe does not exist.", 3)
		return
	end

	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = keyframe.CFrame
	Camera.FieldOfView = keyframe.FOV

	Notify("Recorder", "Jumped to keyframe #" .. tostring(index))
end

local function BuildPlaybackCFrame(segment, alpha)
	local from = Keyframes[segment]
	local to = Keyframes[segment + 1]

	if not from or not to then
		return Camera.CFrame
	end

	if Settings.StopAtEachKeyframe or not Settings.PlaybackSmoothPath then
		local easedAlpha = Settings.StopAtEachKeyframe and EaseSmooth(alpha) or alpha
		return from.CFrame:Lerp(to.CFrame, easedAlpha)
	end

	local p0 = Keyframes[math.max(segment - 1, 1)].CFrame.Position
	local p1 = from.CFrame.Position
	local p2 = to.CFrame.Position
	local p3 = Keyframes[math.min(segment + 2, #Keyframes)].CFrame.Position

	local curvedPosition = CatmullRom(p0, p1, p2, p3, alpha)

	local rotationLerp = from.CFrame:Lerp(to.CFrame, alpha)
	local rotationOnly = rotationLerp - rotationLerp.Position

	return CFrame.new(curvedPosition) * rotationOnly
end

local function StopPlayback(keepCamera)
	if not PlaybackRunning then
		return
	end

	PlaybackRunning = false
	RunService:UnbindFromRenderStep("Recorder_Playback")

	if ResumeFreecamAfterPlayback then
		ResumeFreecamAfterPlayback = false
		EnableFreecam()
	end

	Notify("Recorder", "Playback stopped.")
end

local function PlayKeyframes()
	if #Keyframes < 2 then
		Notify("Recorder", "You need at least 2 keyframes.", 3)
		return
	end

	if PlaybackRunning then
		StopPlayback(true)
	end

	ResumeFreecamAfterPlayback = FreecamEnabled

	if FreecamEnabled then
		DisableFreecam(true)
	end

	if CameraFollowingGhost then
		SetCameraFollowGhost(false)
	end

	PlaybackRunning = true
	Camera.CameraType = Enum.CameraType.Scriptable

	local segment = 1
	local timer = 0
	local pauseTimer = 0

	Camera.CFrame = Keyframes[1].CFrame
	Camera.FieldOfView = Keyframes[1].FOV

	RunService:BindToRenderStep("Recorder_Playback", Enum.RenderPriority.Camera.Value + 12, function(dt)
		if not PlaybackRunning then
			return
		end

		local segmentTime = math.max(Settings.PlaybackSegmentTime, 0.05)

		if pauseTimer > 0 then
			pauseTimer -= dt

			local current = Keyframes[segment]
			if current then
				Camera.CFrame = current.CFrame
				Camera.FieldOfView = current.FOV
			end

			return
		end

		timer += dt

		while timer >= segmentTime do
			timer -= segmentTime
			segment += 1

			if segment >= #Keyframes then
				if Settings.PlaybackLoop then
					segment = 1
					timer = 0
				else
					local last = Keyframes[#Keyframes]
					Camera.CFrame = last.CFrame
					Camera.FieldOfView = last.FOV

					PlaybackRunning = false
					RunService:UnbindFromRenderStep("Recorder_Playback")
					Notify("Recorder", "Playback finished.")
					return
				end
			end

			if Settings.StopAtEachKeyframe then
				pauseTimer = Settings.KeyframePauseTime
				timer = 0
				return
			end
		end

		local from = Keyframes[segment]
		local to = Keyframes[segment + 1]

		if not from or not to then
			return
		end

		local alpha = math.clamp(timer / segmentTime, 0, 1)

		Camera.CFrame = BuildPlaybackCFrame(segment, alpha)
		Camera.FieldOfView = from.FOV + (to.FOV - from.FOV) * alpha
	end)

	if Settings.StopAtEachKeyframe then
		Notify("Recorder", "Playing keyframes with stop-at-each-keyframe mode.")
	else
		Notify("Recorder", "Playing continuous smooth cinematic path.")
	end
end

--====================================================
-- CLEANUP
--====================================================

local function CleanRuntimeOnly()
	StopPlayback(true)
	DisableFreecam(true)
	SetCameraFollowGhost(false)
	DeletePhysicsGhost()
	ClearKeyframes()
	RestoreGameUI()
	UnbindMovementSink()

	RecordingMode = false
	SetGhostsVisible(true)

	Notify("Recorder", "Recorder runtime cleaned.")
end

function Recorder.Cleanup()
	pcall(function()
		RunService:UnbindFromRenderStep("Recorder_Freecam")
		RunService:UnbindFromRenderStep("Recorder_Playback")
		RunService:UnbindFromRenderStep("Recorder_GhostFollow")
	end)

	pcall(function()
		UnbindMovementSink()
	end)

	pcall(function()
		RestoreGameUI()
	end)

	pcall(function()
		DeletePhysicsGhost()
	end)

	pcall(function()
		ClearKeyframes()
	end)

	for _, connection in ipairs(Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(Connections)

	pcall(function()
		RuntimeFolder:Destroy()
	end)

	pcall(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)

	pcall(function()
		ReturnCameraToPlayer()
	end)

	pcall(function()
		RenLib:Unload("script cleanup")
	end)

	if getgenv then
		getgenv()[GLOBAL_NAME] = nil
	end
end

--====================================================
-- NATIVE RENLIB V7 UI
--====================================================

local MainTab = Window:CreateTab({Name = "Main", Icon = 6034287594})
local RecordingTab = Window:CreateTab({Name = "Recording", Icon = 6026663699})
local GhostTab = Window:CreateTab({Name = "Physics Ghost", Icon = 6022668898})
local KeyframeTab = Window:CreateTab({Name = "Keyframes", Icon = 6034328955})
local CurveTab = Window:CreateTab({Name = "Curve Freecam", Icon = 6034925618})
local CleanupTab = Window:CreateTab({Name = "Cleanup", Icon = 6031094678})

--====================================================
-- MAIN TAB
--====================================================

local MainControls = MainTab:CreateSection({Name = "Controls", Side = "Left"})
MainControls:CreateToggle({
	Name = "Freecam",
	Default = false,
	Flag = "Recorder_FreecamToggle",
	Callback = function(value)
		ToggleFreecam(value)
	end
})

MainControls:CreateSlider({
	Name = "Freecam Speed",
	Min = 5,
	Max = 250,
	Step = 1,
	Default = Settings.FreecamSpeed,
	Flag = "Recorder_FreecamSpeed",
	Callback = function(value)
		Settings.FreecamSpeed = value
	end
})

MainControls:CreateSlider({
	Name = "Freecam Smoothness",
	Min = 1,
	Max = 40,
	Step = 1,
	Default = Settings.FreecamSmoothness,
	Flag = "Recorder_FreecamSmoothness",
	Callback = function(value)
		Settings.FreecamSmoothness = value
	end
})

MainControls:CreateSlider({
	Name = "Mouse Sensitivity",
	Min = 1,
	Max = 10,
	Step = 1,
	Default = 3,
	Flag = "Recorder_MouseSensitivity",
	Callback = function(value)
		Settings.MouseSensitivity = value / 1000
	end
})

MainControls:CreateToggle({
	Name = "Desync/Sink Character Movement During Freecam",
	Default = Settings.DesyncCharacterMovement,
	Flag = "Recorder_DesyncMovement",
	Callback = function(value)
		Settings.DesyncCharacterMovement = value

		if FreecamEnabled then
			if value then
				BindMovementSink()
			else
				UnbindMovementSink()
			end
		end
	end
})

MainControls:CreateToggle({
	Name = "Hide Game UI",
	Default = false,
	Flag = "Recorder_HideUI",
	Callback = function(value)
		if value then
			HideGameUI()
		else
			RestoreGameUI()
		end
	end
})

MainControls:CreateToggle({
	Name = "Also Hide Roblox CoreGui",
	Default = Settings.HideCoreGui,
	Flag = "Recorder_HideCoreGui",
	Callback = function(value)
		Settings.HideCoreGui = value
	end
})

MainControls:CreateButton({
	Name = "Return Camera To Player",
	Callback = function()
		ReturnCameraToPlayer()
	end
})

--====================================================
-- RECORDING TAB
--====================================================

local RecordingControls = RecordingTab:CreateSection({Name = "Controls", Side = "Left"})
RecordingControls:CreateButton({
	Name = "Start Recording Mode",
	Callback = function()
		StartRecordingMode()
	end
})

RecordingControls:CreateButton({
	Name = "Stop Recording Mode",
	Callback = function()
		StopRecordingMode()
	end
})

RecordingControls:CreateKeyPicker({
	Name = "Toggle Recording Mode Keybind",
	Default = "R",
	Flag = "Recorder_ToggleRecordingKey",
	Mode = "Press",
	Callback = function()
		ToggleRecordingMode()
	end
})

RecordingControls:CreateToggle({
	Name = "Auto Hide Game UI While Recording",
	Default = Settings.AutoHideGameUIWhenRecording,
	Flag = "Recorder_AutoHideUIRecording",
	Callback = function(value)
		Settings.AutoHideGameUIWhenRecording = value
	end
})

RecordingControls:CreateButton({
	Name = "Force Hide Ghosts",
	Callback = function()
		SetGhostsVisible(false)
	end
})

RecordingControls:CreateButton({
	Name = "Force Show Ghosts",
	Callback = function()
		SetGhostsVisible(true)
	end
})

--====================================================
-- PHYSICS GHOST TAB
--====================================================

local GhostControls = GhostTab:CreateSection({Name = "Controls", Side = "Left"})
GhostControls:CreateButton({
	Name = "Spawn Physics Ghost At Current Camera",
	Callback = function()
		SpawnPhysicsGhostAtCamera()
	end
})

GhostControls:CreateKeyPicker({
	Name = "Spawn Physics Ghost Keybind",
	Default = "G",
	Flag = "Recorder_SpawnGhostKey",
	Mode = "Press",
	Callback = function()
		SpawnPhysicsGhostAtCamera()
	end
})

GhostControls:CreateButton({
	Name = "Lock Ghost To Mouse Target",
	Callback = function()
		LockGhostToMouseTarget()
	end
})

GhostControls:CreateKeyPicker({
	Name = "Lock Ghost Keybind",
	Default = "L",
	Flag = "Recorder_LockGhostKey",
	Mode = "Press",
	Callback = function()
		LockGhostToMouseTarget()
	end
})

GhostControls:CreateToggle({
	Name = "Camera Follows Physics Ghost",
	Default = false,
	Flag = "Recorder_FollowGhost",
	Callback = function(value)
		SetCameraFollowGhost(value)
	end
})

GhostControls:CreateToggle({
	Name = "Ghost Anchored",
	Default = true,
	Flag = "Recorder_GhostAnchored",
	Callback = function(value)
		ToggleGhostAnchor(value)
	end
})

GhostControls:CreateButton({
	Name = "Delete Physics Ghost",
	Callback = function()
		DeletePhysicsGhost()
		Notify("Recorder", "Physics ghost deleted.")
	end
})

--====================================================
-- KEYFRAME TAB
--====================================================

local KeyframeControls = KeyframeTab:CreateSection({Name = "Controls", Side = "Left"})
KeyframeControls:CreateButton({
	Name = "Add Camera Keyframe",
	Callback = function()
		AddKeyframe()
	end
})

KeyframeControls:CreateKeyPicker({
	Name = "Add Keyframe Keybind",
	Default = "K",
	Flag = "Recorder_AddKeyframeKey",
	Mode = "Press",
	Callback = function()
		AddKeyframe()
	end
})

KeyframeControls:CreateSlider({
	Name = "Playback Time Per Segment",
	Min = 0.25,
	Max = 10,
	Step = 0.25,
	Default = Settings.PlaybackSegmentTime,
	Flag = "Recorder_PlaybackSegmentTime",
	Callback = function(value)
		Settings.PlaybackSegmentTime = value
	end
})

KeyframeControls:CreateToggle({
	Name = "Continuous Smooth Path",
	Default = Settings.PlaybackSmoothPath,
	Flag = "Recorder_SmoothPath",
	Callback = function(value)
		Settings.PlaybackSmoothPath = value
	end
})

KeyframeControls:CreateToggle({
	Name = "Stop At Each Keyframe",
	Default = Settings.StopAtEachKeyframe,
	Flag = "Recorder_StopAtEachKeyframe",
	Callback = function(value)
		Settings.StopAtEachKeyframe = value
	end
})

KeyframeControls:CreateSlider({
	Name = "Stop Time At Keyframe",
	Min = 0,
	Max = 3,
	Step = 0.05,
	Default = Settings.KeyframePauseTime,
	Flag = "Recorder_KeyframePause",
	Callback = function(value)
		Settings.KeyframePauseTime = value
	end
})

KeyframeControls:CreateToggle({
	Name = "Loop Playback",
	Default = Settings.PlaybackLoop,
	Flag = "Recorder_PlaybackLoop",
	Callback = function(value)
		Settings.PlaybackLoop = value
	end
})

KeyframeControls:CreateButton({
	Name = "Play Keyframes",
	Callback = function()
		PlayKeyframes()
	end
})

KeyframeControls:CreateButton({
	Name = "Stop Playback",
	Callback = function()
		StopPlayback(true)
	end
})

KeyframeControls:CreateInput({
	Name = "Jump To Keyframe Number",
	Placeholder = "Example: 1",
	Flag = "Recorder_JumpInput",
	Callback = function(text)
		local index = tonumber(text)

		if index then
			JumpToKeyframe(index)
		end
	end
})

KeyframeControls:CreateButton({
	Name = "Clear All Keyframes",
	Callback = function()
		ClearKeyframes()
	end
})

--====================================================
-- CURVE FREECAM TAB
--====================================================

local CurveControls = CurveTab:CreateSection({Name = "Controls", Side = "Left"})
CurveControls:CreateToggle({
	Name = "Enable Curve Freecam Stabilizer",
	Default = Settings.Curve.Enabled,
	Flag = "Recorder_CurveEnabled",
	Callback = function(value)
		SetCurveFreecam(value)
	end
})

CurveControls:CreateButton({
	Name = "Capture Current Position + Angle",
	Callback = function()
		CaptureCurveAll()
	end
})

CurveControls:CreateToggle({
	Name = "Lock Camera Angle",
	Default = Settings.Curve.LockAngle,
	Flag = "Recorder_CurveLockAngle",
	Callback = function(value)
		Settings.Curve.LockAngle = value

		if value then
			CaptureCurveAngle()
		end
	end
})

CurveControls:CreateToggle({
	Name = "Slider Mode: A/D Right-Left Only",
	Default = Settings.Curve.SliderMode,
	Flag = "Recorder_CurveSliderMode",
	Callback = function(value)
		Settings.Curve.SliderMode = value
	end
})

local CurveSection2 = CurveTab:CreateSection({Name = "X Axis", Side = "Right"})

CurveSection2:CreateToggle({
	Name = "Lock X",
	Default = Settings.Curve.LockX,
	Flag = "Recorder_CurveLockX",
	Callback = function(value)
		Settings.Curve.LockX = value

		if value then
			Settings.Curve.X = Camera.CFrame.Position.X
			Notify("Curve Freecam", "Locked X to current value.")
		end
	end
})

CurveSection2:CreateButton({
	Name = "Capture Current X",
	Callback = function()
		Settings.Curve.X = Camera.CFrame.Position.X
		Notify("Curve Freecam", "Captured current X.")
	end
})

local CurveSection3 = CurveTab:CreateSection({Name = "Y Axis / Height", Side = "Left"})

CurveSection3:CreateToggle({
	Name = "Lock Y Height",
	Default = Settings.Curve.LockY,
	Flag = "Recorder_CurveLockY",
	Callback = function(value)
		Settings.Curve.LockY = value

		if value then
			Settings.Curve.Y = Camera.CFrame.Position.Y
			Notify("Curve Freecam", "Locked Y height to current value.")
		end
	end
})

CurveSection3:CreateButton({
	Name = "Capture Current Y Height",
	Callback = function()
		Settings.Curve.Y = Camera.CFrame.Position.Y
		Notify("Curve Freecam", "Captured current Y height.")
	end
})

local CurveSection4 = CurveTab:CreateSection({Name = "Z Axis", Side = "Right"})

CurveSection4:CreateToggle({
	Name = "Lock Z",
	Default = Settings.Curve.LockZ,
	Flag = "Recorder_CurveLockZ",
	Callback = function(value)
		Settings.Curve.LockZ = value

		if value then
			Settings.Curve.Z = Camera.CFrame.Position.Z
			Notify("Curve Freecam", "Locked Z to current value.")
		end
	end
})

CurveSection4:CreateButton({
	Name = "Capture Current Z",
	Callback = function()
		Settings.Curve.Z = Camera.CFrame.Position.Z
		Notify("Curve Freecam", "Captured current Z.")
	end
})

local CurveSection5 = CurveTab:CreateSection({Name = "Presets", Side = "Left"})

CurveSection5:CreateButton({
	Name = "Car Side Shot Preset",
	Callback = function()
		CaptureCurveAll()

		Settings.Curve.Enabled = true
		Settings.Curve.LockAngle = true
		Settings.Curve.SliderMode = true
		Settings.Curve.LockY = true
		Settings.Curve.LockX = false
		Settings.Curve.LockZ = false

		if not FreecamEnabled then
			EnableFreecam()
		end

		Notify("Curve Freecam", "Preset active: locked height + locked angle + smooth A/D side movement.")
	end
})

CurveSection5:CreateButton({
	Name = "Vertical Crane Shot Preset",
	Callback = function()
		CaptureCurveAll()

		Settings.Curve.Enabled = true
		Settings.Curve.LockAngle = true
		Settings.Curve.SliderMode = true
		Settings.Curve.LockX = true
		Settings.Curve.LockZ = true
		Settings.Curve.LockY = false

		if not FreecamEnabled then
			EnableFreecam()
		end

		Notify("Curve Freecam", "Preset active: X/Z locked, move up/down with E/Q or Space/Shift.")
	end
})

--====================================================
-- CLEANUP TAB
--====================================================

local CleanupControls = CleanupTab:CreateSection({Name = "Controls", Side = "Left"})
CleanupControls:CreateButton({
	Name = "Clean Runtime Only",
	Callback = function()
		CleanRuntimeOnly()
	end
})

CleanupControls:CreateButton({
	Name = "Destroy Recorder Script",
	Callback = function()
		Recorder.Cleanup()
	end
})

pcall(function()
	RenLib:LoadConfig("RecorderSettings")
end)

Notify("Recorder V2 Loaded", "Recording mode, smooth path playback, and curve freecam are ready.", 5)
