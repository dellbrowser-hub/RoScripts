-- Ren Challenge Hub
-- Client-side challenge script built for RenLib V7.
-- The role detector is intentionally conservative: edit the aliases below if a
-- particular challenge uses custom weapon names.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local SETTINGS = {
	FlySpeed = 28,
	FlyResponse = 9,
	SwimSpeed = 42,
	SwimResponse = 7,
	VoidMargin = 4,
	DestroyHeightMargin = 18,
	VoidReturnToSafeGround = true,
	EspDistance = 1500,
	EspUpdateRate = 0.033,
	RoleScanRate = 0.45,
	AimFov = 170,
	AimSpeed = 78,
	AimPart = "Head",
	IgnoreTeammates = true,
	RequireLineOfSight = true,
	ShowFov = true,
	AutoShoot = false,
	KnifeProjectileSpeed = 95,
	SheriffFireDelay = 0.42,
	KnifeMeleeDelay = 0.48,
	KnifeThrowDelay = 0.85,
	GrabGunDuration = 2,
	CoinLimit = 50,
	CoinWalkSpeed = 22,
	AntiFlingLinearLimit = 190,
	AntiFlingAngularLimit = 55,

	-- Exact names are checked first; fragments are only checked on Tool names.
	MurdererExactNames = {
		knife = true,
		murderknife = true,
		murdererknife = true,
	},
	MurdererNameFragments = {"knife", "dagger", "blade", "machete"},
	SheriffExactNames = {
		gun = true,
		revolver = true,
		sheriffgun = true,
		handgun = true,
		pistol = true,
	},
	SheriffNameFragments = {"revolver", "sheriffgun", "handgun", "pistol"},

	-- Generic round-state objects are auto-discovered by these names. This is
	-- more reliable than teleport guessing when the game exposes round state.
	RoundStateNames = {
		inround = true,
		roundactive = true,
		roundstatus = true,
		gamestatus = true,
		matchstatus = true,
	},
}

local COLORS = {
	Default = Color3.fromRGB(106, 235, 165),
	Murderer = Color3.fromRGB(255, 74, 89),
	Sheriff = Color3.fromRGB(65, 150, 255),
	Dead = Color3.fromRGB(130, 136, 148),
}

local function getSharedEnvironment()
	local ok, environment = pcall(function()
		return getgenv()
	end)
	return ok and environment or _G
end

local sharedEnvironment = getSharedEnvironment()
if type(sharedEnvironment.RenChallengeHub) == "table" and type(sharedEnvironment.RenChallengeHub.Destroy) == "function" then
	pcall(sharedEnvironment.RenChallengeHub.Destroy, sharedEnvironment.RenChallengeHub)
end

local App = {
	Destroyed = false,
	Connections = {},
	Instances = {},
	PlayerConnections = {},
	EspRecords = {},
	Roles = {},
	NoclipForces = {},
	IntentionalMoveUntil = 0,
	Flags = {
		Noclip = false,
		Fly = false,
		Swim = false,
		Esp = false,
		Aimbot = false,
		GrabGun = false,
		CoinFarm = false,
		AutoShoot = false,
		AntiAfk = true,
		AntiFling = true,
	},
}
sharedEnvironment.RenChallengeHub = App

local function addConnection(connection, bucket)
	bucket = bucket or App.Connections
	table.insert(bucket, connection)
	return connection
end

local function addInstance(instance)
	table.insert(App.Instances, instance)
	return instance
end

local function disconnectBucket(bucket)
	for _, connection in ipairs(bucket) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(bucket)
end

local function destroyInstance(instance)
	if instance then
		pcall(function()
			instance:Destroy()
		end)
	end
end

local function notify(title, content, duration)
	if App.RenLib then
		App.RenLib:Notify({
			Title = title,
			Content = content,
			Duration = duration or 4,
		})
	end
end

local Character
local Humanoid
local RootPart
local lastSafeCFrame
local lastSafeSample = 0
local lastStableCFrame

local function refreshCharacter(character)
	Character = character
	Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
	RootPart = character and character:FindFirstChild("HumanoidRootPart") or nil
	if RootPart then
		lastSafeCFrame = RootPart.CFrame
		lastStableCFrame = RootPart.CFrame
	end
end

refreshCharacter(LocalPlayer.Character)
addConnection(LocalPlayer.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid", 8)
	character:WaitForChild("HumanoidRootPart", 8)
	refreshCharacter(character)
	if App.Flags.Fly then
		task.defer(function()
			App:SetFly(true)
		end)
	elseif App.Flags.Swim then
		task.defer(function()
			App:SetSwim(true)
		end)
	end
end))
addConnection(LocalPlayer.CharacterRemoving:Connect(function(character)
	if Character == character then
		refreshCharacter(nil)
	end
end))

-- World floor cache ---------------------------------------------------------

local floorPart
local floorSurfaceY
local floorDirty = true

local function partTopY(part)
	local half = part.Size * 0.5
	local rotation = part.CFrame
	local projectedHalfHeight = math.abs(rotation.RightVector.Y) * half.X
		+ math.abs(rotation.UpVector.Y) * half.Y
		+ math.abs(rotation.LookVector.Y) * half.Z
	return part.Position.Y + projectedHalfHeight
end

local function isFloorCandidate(instance)
	return instance:IsA("BasePart")
		and instance.Anchored
		and instance.CanCollide
		and instance.Size.X >= 3
		and instance.Size.Z >= 3
		and (not Character or not instance:IsDescendantOf(Character))
end

local function rebuildFloorCache()
	floorPart = nil
	floorSurfaceY = nil
	local lowestCenter = math.huge
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if isFloorCandidate(instance) and instance.Position.Y < lowestCenter then
			lowestCenter = instance.Position.Y
			floorPart = instance
			floorSurfaceY = partTopY(instance)
		end
	end
	floorDirty = false
end

task.defer(rebuildFloorCache)
addConnection(Workspace.DescendantAdded:Connect(function(instance)
	if isFloorCandidate(instance) and (not floorPart or instance.Position.Y < floorPart.Position.Y) then
		floorPart = instance
		floorSurfaceY = partTopY(instance)
	end
end))
addConnection(Workspace.DescendantRemoving:Connect(function(instance)
	if instance == floorPart then
		floorDirty = true
	end
end))

local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.IgnoreWater = false

local function updateSafeGround(now)
	if not RootPart or not Character or now - lastSafeSample < 0.2 then
		return
	end
	lastSafeSample = now
	groundRayParams.FilterDescendantsInstances = {Character}
	local result = Workspace:Raycast(RootPart.Position, Vector3.new(0, -9, 0), groundRayParams)
	if result and RootPart.AssemblyLinearVelocity.Y > -8 then
		lastSafeCFrame = RootPart.CFrame
	end
end

local function applyVoidProtection()
	if not RootPart or not (App.Flags.Noclip or next(App.NoclipForces) ~= nil) then
		return
	end
	if floorDirty then
		rebuildFloorCache()
	end
	local floorGuard = floorSurfaceY and (floorSurfaceY + SETTINGS.VoidMargin)
		or (Workspace.FallenPartsDestroyHeight + SETTINGS.DestroyHeightMargin)
	floorGuard = math.max(floorGuard, Workspace.FallenPartsDestroyHeight + SETTINGS.DestroyHeightMargin)
	if RootPart.Position.Y <= floorGuard and RootPart.AssemblyLinearVelocity.Y < 0 then
		local destination
		if SETTINGS.VoidReturnToSafeGround and lastSafeCFrame then
			destination = lastSafeCFrame + Vector3.new(0, 3, 0)
		else
			destination = CFrame.new(RootPart.Position.X, floorGuard + 2, RootPart.Position.Z) * RootPart.CFrame.Rotation
		end
		RootPart.CFrame = destination
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		notify("Void protection", "Fall stopped at the cached world floor.", 2.5)
	end
end

-- Noclip -------------------------------------------------------------------

local originalCollision = setmetatable({}, {__mode = "k"})

local function noclipIsActive()
	return App.Flags.Noclip or next(App.NoclipForces) ~= nil
end

local function restoreCollisionIfUnused()
	if noclipIsActive() then
		return
	end
	for part, wasCollidable in pairs(originalCollision) do
		if part.Parent then
			part.CanCollide = wasCollidable
		end
	end
	table.clear(originalCollision)
end

local function noclipStep()
	if not noclipIsActive() or not Character then
		return
	end
	for _, instance in ipairs(Character:GetDescendants()) do
		if instance:IsA("BasePart") and instance.CanCollide then
			if originalCollision[instance] == nil then
				originalCollision[instance] = true
			end
			instance.CanCollide = false
		end
	end
end

function App:SetNoclip(enabled)
	self.Flags.Noclip = enabled == true
	restoreCollisionIfUnused()
end

function App:SetNoclipForce(source, enabled)
	self.NoclipForces[source] = enabled and true or nil
	restoreCollisionIfUnused()
end

addConnection(RunService.Stepped:Connect(noclipStep))

-- Fly and swim --------------------------------------------------------------

local movementAttachment
local movementVelocity
local movementOrientation
local swimPlatform
local smoothedVelocity = Vector3.zero
local previousAutoRotate
local mobileVertical = 0

local function destroyMovementRig()
	destroyInstance(movementVelocity)
	destroyInstance(movementOrientation)
	destroyInstance(movementAttachment)
	destroyInstance(swimPlatform)
	movementVelocity = nil
	movementOrientation = nil
	movementAttachment = nil
	swimPlatform = nil
	smoothedVelocity = Vector3.zero
	if Humanoid and previousAutoRotate ~= nil then
		Humanoid.AutoRotate = previousAutoRotate
	end
	previousAutoRotate = nil
end

local function createMovementRig(includePlatform)
	destroyMovementRig()
	if not RootPart or not Humanoid then
		return false
	end
	previousAutoRotate = Humanoid.AutoRotate
	Humanoid.AutoRotate = false

	movementAttachment = Instance.new("Attachment")
	movementAttachment.Name = "RenMovementAttachment"
	movementAttachment.Parent = RootPart

	movementVelocity = Instance.new("LinearVelocity")
	movementVelocity.Name = "RenMovementVelocity"
	movementVelocity.Attachment0 = movementAttachment
	movementVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	movementVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	movementVelocity.MaxForce = math.huge
	movementVelocity.VectorVelocity = Vector3.zero
	movementVelocity.Parent = RootPart

	movementOrientation = Instance.new("AlignOrientation")
	movementOrientation.Name = "RenMovementOrientation"
	movementOrientation.Attachment0 = movementAttachment
	movementOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	movementOrientation.MaxTorque = math.huge
	movementOrientation.Responsiveness = 18
	movementOrientation.RigidityEnabled = false
	movementOrientation.Parent = RootPart

	if includePlatform then
		swimPlatform = Instance.new("Part")
		swimPlatform.Name = "RenSwimSurface"
		swimPlatform.Size = Vector3.new(5, 0.45, 5)
		swimPlatform.Anchored = true
		-- The surface is a local water reference/follower, not a floor. Keeping
		-- collision off is what lets Ctrl/C move downward cleanly.
		swimPlatform.CanCollide = false
		swimPlatform.CanQuery = false
		swimPlatform.CanTouch = false
		swimPlatform.Transparency = 1
		swimPlatform.Parent = Workspace
	end
	return true
end

local function keyDown(keyCode)
	return UserInputService:IsKeyDown(keyCode)
end

local function cameraMovementDirection()
	Camera = Workspace.CurrentCamera or Camera
	if not Camera then
		return Vector3.zero
	end
	local look = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
	local right = Vector3.new(Camera.CFrame.RightVector.X, 0, Camera.CFrame.RightVector.Z)
	look = look.Magnitude > 0.001 and look.Unit or Vector3.new(0, 0, -1)
	right = right.Magnitude > 0.001 and right.Unit or Vector3.new(1, 0, 0)

	local direction = Vector3.zero
	if keyDown(Enum.KeyCode.W) then direction += look end
	if keyDown(Enum.KeyCode.S) then direction -= look end
	if keyDown(Enum.KeyCode.D) then direction += right end
	if keyDown(Enum.KeyCode.A) then direction -= right end
	if keyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
	if keyDown(Enum.KeyCode.LeftControl) or keyDown(Enum.KeyCode.C) then direction -= Vector3.yAxis end
	if mobileVertical ~= 0 then direction += Vector3.yAxis * mobileVertical end

	-- Humanoid.MoveDirection preserves thumbstick support on phone/tablet.
	if direction.Magnitude < 0.01 and Humanoid and Humanoid.MoveDirection.Magnitude > 0.01 then
		direction = Humanoid.MoveDirection
	end
	return direction.Magnitude > 1 and direction.Unit or direction
end

local function updateMovement(dt)
	if not (App.Flags.Fly or App.Flags.Swim) or not RootPart or not Humanoid then
		return
	end
	if not movementVelocity or not movementVelocity.Parent then
		createMovementRig(App.Flags.Swim)
	end
	if not movementVelocity then
		return
	end

	local speed = App.Flags.Swim and SETTINGS.SwimSpeed or math.min(SETTINGS.FlySpeed, 30)
	local response = App.Flags.Swim and SETTINGS.SwimResponse or SETTINGS.FlyResponse
	local target = cameraMovementDirection() * speed
	local alpha = 1 - math.exp(-response * math.min(dt, 0.1))
	smoothedVelocity = smoothedVelocity:Lerp(target, alpha)
	movementVelocity.VectorVelocity = smoothedVelocity

	Camera = Workspace.CurrentCamera or Camera
	if Camera and movementOrientation then
		local facing = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
		if facing.Magnitude > 0.001 then
			movementOrientation.CFrame = CFrame.lookAt(Vector3.zero, facing.Unit, Vector3.yAxis)
		end
	end

	if App.Flags.Swim then
		if swimPlatform then
			swimPlatform.CFrame = CFrame.new(RootPart.Position - Vector3.new(0, 3.1, 0))
		end
		-- Reasserting Swimming lets the stock Animate controller keep its swim
		-- track even though this local surface is not Terrain water.
		Humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	end
end

function App:SetFly(enabled)
	enabled = enabled == true
	if enabled then
		self.Flags.Swim = false
		if self.Controls and self.Controls.Swim and self.Controls.Swim:Get() then
			self.Controls.Swim:Set(false)
		end
	end
	self.Flags.Fly = enabled
	if enabled then
		createMovementRig(false)
	elseif not self.Flags.Swim then
		destroyMovementRig()
	end
end

function App:SetSwim(enabled)
	enabled = enabled == true
	if enabled then
		self.Flags.Fly = false
		if self.Controls and self.Controls.Fly and self.Controls.Fly:Get() then
			self.Controls.Fly:Set(false)
		end
	end
	self.Flags.Swim = enabled
	if enabled then
		createMovementRig(true)
	elseif not self.Flags.Fly then
		destroyMovementRig()
	end
end

addConnection(RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	updateSafeGround(now)
	applyVoidProtection()
	updateMovement(dt)
end))

-- Coin route, AFK and fling protection -------------------------------------

local coinVisited = setmetatable({}, {__mode = "k"})
local coinPositionVisited = {}
local coinAttempts = 0
local coinFarmToken = 0
local coinRoundContainer

local function resetCoinRound()
	table.clear(coinVisited)
	table.clear(coinPositionVisited)
	coinAttempts = 0
	coinRoundContainer = nil
end

local function objectPosition(object)
	if object:IsA("BasePart") then
		return object.Position
	end
	if object:IsA("Model") then
		return object:GetPivot().Position
	end
	local part = object:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function coinPositionKey(position)
	return string.format("%d:%d:%d", math.floor(position.X * 0.5 + 0.5), math.floor(position.Y * 0.5 + 0.5), math.floor(position.Z * 0.5 + 0.5))
end

local function findCoinContainer()
	local milBase = Workspace:FindFirstChild("MilBase")
	local exact = milBase and milBase:FindFirstChild("CoinContainer")
	if exact then
		return exact
	end
	return Workspace:FindFirstChild("CoinContainer", true)
end

local function isCoinObject(object)
	local name = string.lower(object.Name):gsub("[%s%p_]", "")
	return name == "coinserve"
end

local function nearestUnvisitedCoin(container)
	if not RootPart then
		return nil
	end
	local nearest
	local nearestPosition
	local bestDistance = math.huge
	for _, object in ipairs(container:GetChildren()) do
		if isCoinObject(object) and not coinVisited[object] then
			local position = objectPosition(object)
			local key = position and coinPositionKey(position)
			if position and not coinPositionVisited[key] then
				local distance = (RootPart.Position - position).Magnitude
				if distance < bestDistance then
					nearest = object
					nearestPosition = position
					bestDistance = distance
				end
			end
		end
	end
	return nearest, nearestPosition
end

local concealRayParams = RaycastParams.new()
concealRayParams.FilterType = Enum.RaycastFilterType.Exclude
concealRayParams.IgnoreWater = true

local function concealedWaypoint(target)
	for _, player in ipairs(Players:GetPlayers()) do
		local playerHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if player ~= LocalPlayer and playerHumanoid and playerHumanoid.Health > 0 then
			local character = player.Character
			local observer = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
			if observer then
				concealRayParams.FilterDescendantsInstances = Character and {character, Character} or {character}
				local toTarget = target - observer.Position
				local directHit = Workspace:Raycast(observer.Position, toTarget, concealRayParams)
				local targetVisible = not directHit or (directHit.Position - target).Magnitude <= 4
				if targetVisible then
					local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
					if flat.Magnitude > 1 then
						local side = Vector3.yAxis:Cross(flat.Unit)
						local candidates = {
							target + side * 14,
							target - side * 14,
							target + flat.Unit * 12,
						}
						for _, candidate in ipairs(candidates) do
							local ray = candidate - observer.Position
							local hit = Workspace:Raycast(observer.Position, ray, concealRayParams)
							if hit and (hit.Position - observer.Position).Magnitude < ray.Magnitude - 2 then
								return candidate
							end
						end
					end
				end
			end
		end
	end
	return nil
end

local function walkFarmRouteTo(target, token, radius)
	radius = radius or 2.4
	while App.Flags.CoinFarm and token == coinFarmToken and RootPart and Humanoid do
		local offset = target - RootPart.Position
		local distance = offset.Magnitude
		if distance <= radius then
			RootPart.AssemblyLinearVelocity = Vector3.zero
			Humanoid:Move(Vector3.zero, false)
			return true
		end
		local direction = offset.Unit
		local speed = math.min(SETTINGS.CoinWalkSpeed, math.max(8, distance * 2.5))
		App.IntentionalMoveUntil = os.clock() + 0.4
		RootPart.AssemblyLinearVelocity = direction * speed
		Humanoid:Move(Vector3.new(direction.X, 0, direction.Z), false)
		Humanoid:ChangeState(Enum.HumanoidStateType.Running)
		RunService.Heartbeat:Wait()
	end
	return false
end

local function runCoinFarm(token)
	App:SetNoclipForce("CoinFarm", true)
	while App.Flags.CoinFarm and token == coinFarmToken and not App.Destroyed do
		if coinAttempts >= SETTINGS.CoinLimit then
			notify("Coin farm", "Round limit reached: 50/50 coins.", 5)
			break
		end
		local container = findCoinContainer()
		if container and coinRoundContainer and container ~= coinRoundContainer then
			resetCoinRound()
		end
		if container then coinRoundContainer = container end
		local coin, position
		if container then
			coin, position = nearestUnvisitedCoin(container)
		end
		if not coin or not position then
			task.wait(0.35)
			continue
		end

		-- The first leg stays level with the coin and travels physically through
		-- walls. This keeps the character out of the void and usually out of other
		-- players' sight until the short final collection step.
		local hiddenLeg = concealedWaypoint(position + Vector3.new(0, 1.5, 0))
		if hiddenLeg and not walkFarmRouteTo(hiddenLeg, token, 3) then break end
		local approach = position + Vector3.new(0, 1.5, 0)
		if walkFarmRouteTo(approach, token, 2.2) then
			coinVisited[coin] = true
			coinPositionVisited[coinPositionKey(position)] = true
			coinAttempts += 1
			task.wait(0.18)
		end
	end
	if token == coinFarmToken then
		App.Flags.CoinFarm = false
		if App.Controls and App.Controls.CoinFarm and App.Controls.CoinFarm:Get() then
			App.Controls.CoinFarm:Set(false)
		end
	end
	App:SetNoclipForce("CoinFarm", false)
	if RootPart then RootPart.AssemblyLinearVelocity = Vector3.zero end
end

function App:SetCoinFarm(enabled)
	enabled = enabled == true
	if self.Flags.CoinFarm == enabled then
		return
	end
	self.Flags.CoinFarm = enabled
	coinFarmToken += 1
	local token = coinFarmToken
	if enabled then
		task.spawn(runCoinFarm, token)
	else
		self:SetNoclipForce("CoinFarm", false)
		if RootPart then RootPart.AssemblyLinearVelocity = Vector3.zero end
	end
end

addConnection(LocalPlayer.Idled:Connect(function()
	if not App.Flags.AntiAfk then
		return
	end
	local ok = pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.zero, Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.new())
	end)
	if not ok and VirtualInputManager then
		pcall(function()
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
		end)
	end
end))

addConnection(RunService.Heartbeat:Connect(function()
	if not App.Flags.AntiFling or not RootPart then
		return
	end
	local intentional = App.Flags.Fly or App.Flags.Swim or App.Flags.CoinFarm or os.clock() < App.IntentionalMoveUntil
	if intentional then
		lastStableCFrame = RootPart.CFrame
		return
	end
	local linear = RootPart.AssemblyLinearVelocity.Magnitude
	local angular = RootPart.AssemblyAngularVelocity.Magnitude
	if linear > SETTINGS.AntiFlingLinearLimit or angular > SETTINGS.AntiFlingAngularLimit then
		if lastStableCFrame then RootPart.CFrame = lastStableCFrame end
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		return
	end
	if linear < 70 and angular < 12 then
		lastStableCFrame = RootPart.CFrame
	end
end))

-- Role detection ------------------------------------------------------------

local currentMurderer
local currentSheriff
local lastRoleScan = 0
local lastRoundReset = 0
local roleSuppressedUntil = 0
local explicitLobbyState = false
local priorPositions = {}
local lastKnownPositions = {}
local grabGunToken = 0

local function normalizedName(value)
	return string.lower(value):gsub("[%s%p_]", "")
end

local function containsAny(value, fragments)
	for _, fragment in ipairs(fragments) do
		if string.find(value, fragment, 1, true) then
			return true
		end
	end
	return false
end

local function classifyTool(tool)
	if not tool:IsA("Tool") then
		return nil
	end
	local name = normalizedName(tool.Name)
	local declaredRole = normalizedName(tostring(tool:GetAttribute("Role") or tool:GetAttribute("WeaponType") or ""))
	if containsAny(declaredRole, {"murder", "melee", "knife", "blade"}) then
		return "Murderer"
	end
	if containsAny(declaredRole, {"sheriff", "revolver", "handgun", "pistol"}) or declaredRole == "gun" then
		return "Sheriff"
	end
	if SETTINGS.MurdererExactNames[name] or containsAny(name, SETTINGS.MurdererNameFragments) then
		return "Murderer"
	end
	if SETTINGS.SheriffExactNames[name] or containsAny(name, SETTINGS.SheriffNameFragments) then
		return "Sheriff"
	end
	return nil
end

local function playerIsAlive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function roleFromTeam(player)
	local teamName = player.Team and normalizedName(player.Team.Name) or ""
	if string.find(teamName, "murder", 1, true) then
		return "Murderer", "team"
	end
	if string.find(teamName, "sheriff", 1, true) or string.find(teamName, "detective", 1, true) then
		return "Sheriff", "team"
	end
	return nil
end

local function roleFromInventory(player)
	local containers = {player:FindFirstChildOfClass("Backpack"), player.Character}
	local sheriffSource
	for _, container in ipairs(containers) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				local role = classifyTool(item)
				if role == "Murderer" then
					-- Murderer evidence wins if a player happens to hold both tools.
					return role, "weapon: " .. item.Name
				elseif role == "Sheriff" then
					sheriffSource = "weapon: " .. item.Name
				end
			end
		end
	end
	if sheriffSource then
		return "Sheriff", sheriffSource
	end
	return roleFromTeam(player)
end

local function droppedGunPosition(fallbackPosition)
	local bestPosition = fallbackPosition
	local bestDistance = math.huge
	for _, object in ipairs(Workspace:GetDescendants()) do
		local role
		if object:IsA("Tool") then
			role = classifyTool(object)
		elseif object:IsA("BasePart") then
			local name = normalizedName(object.Name)
			if SETTINGS.SheriffExactNames[name] or containsAny(name, SETTINGS.SheriffNameFragments) then
				role = "Sheriff"
			end
		end
		if role == "Sheriff" then
			local position = objectPosition(object)
			if position then
				local distance = fallbackPosition and (position - fallbackPosition).Magnitude or 0
				if distance < bestDistance then
					bestDistance = distance
					bestPosition = position
				end
			end
		end
	end
	return bestPosition, bestDistance < math.huge
end

local function startGrabGun(sheriff, deathPosition)
	if not App.Flags.GrabGun or not RootPart or not deathPosition then
		return
	end
	grabGunToken += 1
	local token = grabGunToken
	task.spawn(function()
		local target = deathPosition
		local deadline = os.clock() + 0.75
		repeat
			local foundPosition, found = droppedGunPosition(deathPosition)
			if found and foundPosition and (foundPosition - deathPosition).Magnitude <= 60 then
				target = foundPosition
				break
			end
			task.wait(0.15)
		until os.clock() >= deadline or token ~= grabGunToken
		if token ~= grabGunToken or not RootPart then return end
		local resumeCoinFarm = App.Flags.CoinFarm
		if resumeCoinFarm then App:SetCoinFarm(false) end
		local returnCFrame = RootPart and RootPart.CFrame
		if not returnCFrame then return end

		App:SetNoclipForce("GrabGun", true)
		App.IntentionalMoveUntil = os.clock() + SETTINGS.GrabGunDuration + 0.6
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		RootPart.CFrame = CFrame.new(target + Vector3.new(0, 2.2, 0)) * returnCFrame.Rotation
		notify("Grab gun", "Moved to " .. sheriff.Name .. "'s dropped gun for 2 seconds.", 3)

		local returnAt = os.clock() + SETTINGS.GrabGunDuration
		while token == grabGunToken and RootPart and os.clock() < returnAt do
			RunService.Heartbeat:Wait()
		end
		if token == grabGunToken and RootPart then
			App.IntentionalMoveUntil = os.clock() + 0.5
			RootPart.AssemblyLinearVelocity = Vector3.zero
			RootPart.AssemblyAngularVelocity = Vector3.zero
			RootPart.CFrame = returnCFrame
			App:SetNoclipForce("GrabGun", false)
			if resumeCoinFarm and App.Flags.GrabGun then App:SetCoinFarm(true) end
		end
	end)
end

function App:SetGrabGun(enabled)
	self.Flags.GrabGun = enabled == true
	if not self.Flags.GrabGun then
		grabGunToken += 1
		self:SetNoclipForce("GrabGun", false)
	end
end

local function refreshEspStyle(player)
	local record = App.EspRecords[player]
	if not record then
		return
	end
	local role = App.Roles[player] and App.Roles[player].Role
	local color = COLORS[role] or COLORS.Default
	for _, object in ipairs(record.ColorObjects or {}) do
		object.BackgroundColor3 = color
	end
	if record.NameLabel then record.NameLabel.TextColor3 = color end
	if record.WeaponLabel then record.WeaponLabel.TextColor3 = color end
end

local function clearPlayerRole(player)
	if currentMurderer == player then currentMurderer = nil end
	if currentSheriff == player then currentSheriff = nil end
	App.Roles[player] = nil
	refreshEspStyle(player)
end

local function assignRole(player, role, source)
	if not playerIsAlive(player) then
		return
	end
	local existing = App.Roles[player]
	if existing and existing.Role == role then
		existing.LastConfirmed = os.clock()
		existing.Source = source
		return
	end

	if role == "Murderer" then
		if currentSheriff == player then currentSheriff = nil end
		if currentMurderer and currentMurderer ~= player then
			clearPlayerRole(currentMurderer)
		end
		currentMurderer = player
	elseif role == "Sheriff" then
		if currentMurderer == player then currentMurderer = nil end
		if currentSheriff and currentSheriff ~= player then
			clearPlayerRole(currentSheriff)
		end
		currentSheriff = player
	end
	App.Roles[player] = {Role = role, Source = source, LastConfirmed = os.clock()}
	refreshEspStyle(player)
	if App.Flags.Esp then
		notify("Role detected", string.format("%s is the %s (%s)", player.Name, role, source), 3)
	end
end

local function clearRound(reason)
	local hadRoles = next(App.Roles) ~= nil
	currentMurderer = nil
	currentSheriff = nil
	table.clear(App.Roles)
	lastRoundReset = os.clock()
	-- Prevent corpse/backpack remnants from immediately recreating stale roles
	-- while the server is moving everyone back to spawn.
	roleSuppressedUntil = lastRoundReset + 2.5
	resetCoinRound()
	grabGunToken += 1
	App:SetNoclipForce("GrabGun", false)
	for player in pairs(App.EspRecords) do
		refreshEspStyle(player)
	end
	if hadRoles and reason then
		notify("Round reset", reason, 3)
	end
end

local function scanRoles()
	if explicitLobbyState or os.clock() < roleSuppressedUntil then
		return
	end
	local observedSheriff
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and playerIsAlive(player) then
			local role, source = roleFromInventory(player)
			if role then
				assignRole(player, role, source)
				if role == "Sheriff" then
					observedSheriff = player
				end
			end
		end
	end

	-- Sheriff ownership transfers with the gun. Murderer identity remains in
	-- memory while alive because many games briefly hide the knife.
	if currentSheriff and currentSheriff ~= observedSheriff then
		local memory = App.Roles[currentSheriff]
		-- Equipping briefly reparents a Tool through nil in some experiences.
		-- A short grace period prevents the Sheriff label from flickering while
		-- still allowing a real pickup to transfer ownership immediately.
		if not memory or os.clock() - memory.LastConfirmed >= 1.35 then
			clearPlayerRole(currentSheriff)
		end
	end
	if currentMurderer and not playerIsAlive(currentMurderer) then
		clearRound("The murderer died.")
	end
end

local function isLobbyState(instance)
	local key = normalizedName(instance.Name)
	if not SETTINGS.RoundStateNames[key] then
		return false
	end
	if instance:IsA("BoolValue") then
		return instance.Value == false
	end
	if instance:IsA("StringValue") then
		local value = normalizedName(instance.Value)
		return containsAny(value, {"lobby", "intermission", "waiting", "roundover", "gameover", "ended"})
	end
	if instance:IsA("IntValue") or instance:IsA("NumberValue") then
		return instance.Value <= 0 and (key == "inround" or key == "roundactive")
	end
	return false
end

local function isActiveRoundState(instance)
	local key = normalizedName(instance.Name)
	if not SETTINGS.RoundStateNames[key] or isLobbyState(instance) then
		return false
	end
	if instance:IsA("BoolValue") then
		return instance.Value == true
	end
	if instance:IsA("StringValue") then
		local value = normalizedName(instance.Value)
		return containsAny(value, {"playing", "active", "inprogress", "roundstarted", "gamestarted"})
	end
	if instance:IsA("IntValue") or instance:IsA("NumberValue") then
		return instance.Value > 0 and (key == "inround" or key == "roundactive")
	end
	return false
end

local roundStateWatched = setmetatable({}, {__mode = "k"})
local function watchRoundState(instance)
	if roundStateWatched[instance] or not instance:IsA("ValueBase") then
		return
	end
	if not SETTINGS.RoundStateNames[normalizedName(instance.Name)] then
		return
	end
	roundStateWatched[instance] = true
	local function updateRoundState()
		if isLobbyState(instance) then
			explicitLobbyState = true
			if os.clock() - lastRoundReset > 1 then
				clearRound("The game reported a lobby/intermission state.")
			end
		elseif isActiveRoundState(instance) then
			explicitLobbyState = false
			roleSuppressedUntil = 0
		end
	end
	addConnection(instance.Changed:Connect(updateRoundState))
	updateRoundState()
end

for _, root in ipairs({Workspace, ReplicatedStorage}) do
	for _, instance in ipairs(root:GetDescendants()) do
		watchRoundState(instance)
	end
	addConnection(root.DescendantAdded:Connect(watchRoundState))
end

local function detectMassLobbyTeleport()
	if not currentMurderer and not currentSheriff then
		return
	end
	local positions = {}
	local moved = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and playerIsAlive(player) then
			positions[player] = root.Position
			if priorPositions[player] and (root.Position - priorPositions[player]).Magnitude >= 85 then
				moved += 1
			end
		end
	end
	local count = 0
	local center = Vector3.zero
	for _, position in pairs(positions) do
		count += 1
		center += position
	end
	if count >= 3 then
		center /= count
		local clustered = 0
		for _, position in pairs(positions) do
			if (position - center).Magnitude <= 65 then
				clustered += 1
			end
		end
		if moved >= math.ceil(count * 0.55) and clustered >= math.ceil(count * 0.65) and os.clock() - lastRoundReset > 6 then
			clearRound("Mass teleport back to a shared spawn detected.")
		end
	end
	priorPositions = positions
end

-- ESP ----------------------------------------------------------------------

local overlayGui = addInstance(Instance.new("ScreenGui"))
overlayGui.Name = "RenChallengeOverlay"
overlayGui.ResetOnSpawn = false
overlayGui.IgnoreGuiInset = true
overlayGui.DisplayOrder = 999
overlayGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local fovCircle = Instance.new("Frame")
fovCircle.Name = "AimFov"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.Parent = overlayGui
local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Transparency = 0.38
fovStroke.Thickness = 1
fovStroke.Parent = fovCircle

local mobileDock = Instance.new("Frame")
mobileDock.Name = "MobileQuickDock"
mobileDock.AnchorPoint = Vector2.new(1, 0.5)
mobileDock.Position = UDim2.new(1, -10, 0.5, 0)
mobileDock.Size = UDim2.fromOffset(54, 216)
mobileDock.BackgroundTransparency = 1
mobileDock.Visible = UserInputService.TouchEnabled
mobileDock.Parent = overlayGui
local dockLayout = Instance.new("UIListLayout")
dockLayout.Padding = UDim.new(0, 5)
dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dockLayout.Parent = mobileDock

local mobileButtons = {}
local function makeMobileButton(name, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(48, 38)
	button.BackgroundColor3 = Color3.fromRGB(24, 28, 35)
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(235, 239, 244)
	button.TextSize = 11
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = mobileDock
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button
	mobileButtons[name] = button
	return button
end

for _, entry in ipairs({{"Aimbot", "AIM"}, {"Esp", "ESP"}, {"Noclip", "NOC"}, {"Fly", "FLY"}}) do
	local name, label = entry[1], entry[2]
	local button = makeMobileButton(name, label)
	button.Activated:Connect(function()
		local control = App.Controls and App.Controls[name]
		if control then control:Set(not control:Get()) end
	end)
end

local mobileVerticalDock = Instance.new("Frame")
mobileVerticalDock.AnchorPoint = Vector2.new(0, 0.5)
mobileVerticalDock.Position = UDim2.new(0, 10, 0.5, 0)
mobileVerticalDock.Size = UDim2.fromOffset(54, 86)
mobileVerticalDock.BackgroundTransparency = 1
mobileVerticalDock.Visible = false
mobileVerticalDock.Parent = overlayGui
local verticalLayout = Instance.new("UIListLayout")
verticalLayout.Padding = UDim.new(0, 6)
verticalLayout.Parent = mobileVerticalDock
local riseButton = makeMobileButton("Rise", "UP")
riseButton.Parent = mobileVerticalDock
local descendButton = makeMobileButton("Descend", "DOWN")
descendButton.Parent = mobileVerticalDock

local function bindVerticalButton(button, value)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			mobileVertical = value
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if mobileVertical == value then mobileVertical = 0 end
		end
	end)
end
bindVerticalButton(riseButton, 1)
bindVerticalButton(descendButton, -1)

local function destroyEsp(player)
	local record = App.EspRecords[player]
	if not record then
		return
	end
	destroyInstance(record.Container)
	App.EspRecords[player] = nil
end

local function newEspLine(parent, thickness)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = COLORS.Default
	line.BorderSizePixel = 0
	line.Size = UDim2.fromOffset(0, thickness or 1)
	line.Visible = false
	line.ZIndex = 12
	line.Parent = parent
	return line
end

local function setEspLine(line, pointA, pointB, thickness)
	local difference = pointB - pointA
	local length = difference.Magnitude
	if length < 0.5 then
		line.Visible = false
		return
	end
	line.Position = UDim2.fromOffset((pointA.X + pointB.X) * 0.5, (pointA.Y + pointB.Y) * 0.5)
	line.Size = UDim2.fromOffset(length, thickness or 1)
	line.Rotation = math.deg(math.atan2(difference.Y, difference.X))
	line.Visible = true
end

local function newEspText(parent, size, bold)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(220, 18)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(240, 243, 247)
	label.TextSize = size
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.12
	label.ZIndex = 14
	label.Parent = parent
	return label
end

local R15_JOINTS = {
	{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

local R6_JOINTS = {
	{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
	{"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function characterScreenBounds(character)
	local boxCFrame, boxSize = character:GetBoundingBox()
	local half = boxSize * 0.5
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local projected = 0
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local world = boxCFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
				local screen = Camera:WorldToViewportPoint(world)
				if screen.Z > 0 then
					projected += 1
					minX = math.min(minX, screen.X)
					minY = math.min(minY, screen.Y)
					maxX = math.max(maxX, screen.X)
					maxY = math.max(maxY, screen.Y)
				end
			end
		end
	end
	if projected < 4 then
		return nil
	end
	return minX, minY, maxX, maxY
end

local function equippedWeaponName(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then return child.Name end
	end
	return "UNARMED"
end

local function createEsp(player)
	if player == LocalPlayer then
		return
	end
	destroyEsp(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local container = Instance.new("Frame")
	container.Name = "TacticalESP_" .. player.Name
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Visible = false
	container.Parent = overlayGui

	local boxLines = {}
	local colorObjects = {}
	for index = 1, 4 do
		boxLines[index] = newEspLine(container, 1.5)
		table.insert(colorObjects, boxLines[index])
	end
	local tracer = newEspLine(container, 1)
	tracer.BackgroundTransparency = 0.48
	table.insert(colorObjects, tracer)

	local skeletonLines = {}
	for index = 1, #R15_JOINTS do
		skeletonLines[index] = newEspLine(container, 1.35)
		skeletonLines[index].BackgroundTransparency = 0.08
		table.insert(colorObjects, skeletonLines[index])
	end
	local jointDots = {}
	for index = 1, #R15_JOINTS + 1 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = COLORS.Default
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(3, 3)
		dot.Visible = false
		dot.ZIndex = 13
		dot.Parent = container
		jointDots[index] = dot
		table.insert(colorObjects, dot)
	end

	local nameLabel = newEspText(container, 13, true)
	nameLabel.Text = player.Name
	local weaponLabel = newEspText(container, 11, false)
	local distanceLabel = newEspText(container, 11, false)

	local healthBack = Instance.new("Frame")
	healthBack.AnchorPoint = Vector2.new(0, 0)
	healthBack.BackgroundColor3 = Color3.fromRGB(11, 13, 16)
	healthBack.BorderSizePixel = 0
	healthBack.ZIndex = 12
	healthBack.Parent = container
	local healthFill = Instance.new("Frame")
	healthFill.AnchorPoint = Vector2.new(0, 1)
	healthFill.BackgroundColor3 = Color3.fromRGB(75, 232, 108)
	healthFill.BorderSizePixel = 0
	healthFill.ZIndex = 13
	healthFill.Parent = container

	App.EspRecords[player] = {
		Character = character,
		Humanoid = humanoid,
		Container = container,
		BoxLines = boxLines,
		Tracer = tracer,
		SkeletonLines = skeletonLines,
		JointDots = jointDots,
		ColorObjects = colorObjects,
		NameLabel = nameLabel,
		WeaponLabel = weaponLabel,
		DistanceLabel = distanceLabel,
		HealthBack = healthBack,
		HealthFill = healthFill,
	}
	refreshEspStyle(player)
end

local function updateEsp()
	local localRoot = RootPart
	for player, record in pairs(App.EspRecords) do
		if record.Character ~= player.Character then
			createEsp(player)
			continue
		end
		local targetRoot = record.Character and record.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot then lastKnownPositions[player] = targetRoot.Position end
		local alive = record.Humanoid and record.Humanoid.Health > 0
		local distance = localRoot and targetRoot and (targetRoot.Position - localRoot.Position).Magnitude or math.huge
		local visible = App.Flags.Esp and alive and distance <= SETTINGS.EspDistance and Camera ~= nil
		local minX, minY, maxX, maxY
		if visible then minX, minY, maxX, maxY = characterScreenBounds(record.Character) end
		visible = visible and minX ~= nil
		record.Container.Visible = visible
		if not visible then continue end

		local width = math.max(18, maxX - minX)
		local height = math.max(28, maxY - minY)
		maxX, maxY = minX + width, minY + height
		setEspLine(record.BoxLines[1], Vector2.new(minX, minY), Vector2.new(maxX, minY), 1.5)
		setEspLine(record.BoxLines[2], Vector2.new(maxX, minY), Vector2.new(maxX, maxY), 1.5)
		setEspLine(record.BoxLines[3], Vector2.new(maxX, maxY), Vector2.new(minX, maxY), 1.5)
		setEspLine(record.BoxLines[4], Vector2.new(minX, maxY), Vector2.new(minX, minY), 1.5)
		setEspLine(record.Tracer, Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y), Vector2.new((minX + maxX) * 0.5, maxY), 1)

		local role = App.Roles[player] and App.Roles[player].Role or "PLAYER"
		record.NameLabel.Text = player.Name
		record.NameLabel.Position = UDim2.fromOffset((minX + maxX) * 0.5, minY - 25)
		record.WeaponLabel.Text = string.upper(equippedWeaponName(record.Character)) .. "  [" .. string.upper(role) .. "]"
		record.WeaponLabel.Position = UDim2.fromOffset((minX + maxX) * 0.5, minY - 10)
		record.DistanceLabel.Text = string.format("%dHP  |  %dm", math.max(0, math.floor(record.Humanoid.Health + 0.5)), math.floor(distance + 0.5))
		record.DistanceLabel.Position = UDim2.fromOffset((minX + maxX) * 0.5, maxY + 11)

		local ratio = math.clamp(record.Humanoid.Health / math.max(record.Humanoid.MaxHealth, 1), 0, 1)
		record.HealthBack.Position = UDim2.fromOffset(minX - 7, minY)
		record.HealthBack.Size = UDim2.fromOffset(3, height)
		record.HealthFill.Position = UDim2.fromOffset(minX - 7, maxY)
		record.HealthFill.Size = UDim2.fromOffset(3, height * ratio)
		record.HealthFill.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.85, 0.95)

		local joints = record.Character:FindFirstChild("UpperTorso") and R15_JOINTS or R6_JOINTS
		for _, dot in ipairs(record.JointDots) do dot.Visible = false end
		for index, line in ipairs(record.SkeletonLines) do
			local pair = joints[index]
			local partA = pair and record.Character:FindFirstChild(pair[1])
			local partB = pair and record.Character:FindFirstChild(pair[2])
			if partA and partB then
				local screenA = Camera:WorldToViewportPoint(partA.Position)
				local screenB = Camera:WorldToViewportPoint(partB.Position)
				if screenA.Z > 0 and screenB.Z > 0 then
					setEspLine(line, Vector2.new(screenA.X, screenA.Y), Vector2.new(screenB.X, screenB.Y), 1.35)
					local dot = record.JointDots[index]
					if dot then
						dot.Position = UDim2.fromOffset(screenB.X, screenB.Y)
						dot.Visible = true
					end
					if index == 1 then
						local startDot = record.JointDots[#record.JointDots]
						startDot.Position = UDim2.fromOffset(screenA.X, screenA.Y)
						startDot.Visible = true
					end
				else
					line.Visible = false
				end
			else
				line.Visible = false
			end
		end
	end
end

function App:SetEsp(enabled)
	self.Flags.Esp = enabled == true
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not self.EspRecords[player] then
			createEsp(player)
		end
	end
	updateEsp()
end

local function onPlayerDied(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local deathPosition = root and root.Position or lastKnownPositions[player]
	if player == currentSheriff then
		startGrabGun(player, deathPosition)
	end
	if player == currentMurderer then
		clearRound("The murderer died.")
	else
		clearPlayerRole(player)
	end
end

local function monitorPlayer(player)
	if player == LocalPlayer then
		return
	end
	local bucket = {}
	App.PlayerConnections[player] = bucket
	addConnection(player.CharacterAdded:Connect(function(character)
		task.defer(function()
			character:WaitForChild("Humanoid", 8)
			character:WaitForChild("HumanoidRootPart", 8)
			createEsp(player)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				addConnection(humanoid.Died:Connect(function() onPlayerDied(player) end), bucket)
			end
		end)
	end), bucket)
	addConnection(player.CharacterRemoving:Connect(function()
		destroyEsp(player)
		if player == currentMurderer then
			clearRound("The murderer left or respawned.")
		else
			clearPlayerRole(player)
		end
	end), bucket)
	if player.Character then
		createEsp(player)
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			addConnection(humanoid.Died:Connect(function() onPlayerDied(player) end), bucket)
		end
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	monitorPlayer(player)
end
addConnection(Players.PlayerAdded:Connect(monitorPlayer))
addConnection(Players.PlayerRemoving:Connect(function(player)
	disconnectBucket(App.PlayerConnections[player] or {})
	App.PlayerConnections[player] = nil
	destroyEsp(player)
	clearPlayerRole(player)
	priorPositions[player] = nil
	lastKnownPositions[player] = nil
end))

-- Aimbot -------------------------------------------------------------------

local aimRayParams = RaycastParams.new()
aimRayParams.FilterType = Enum.RaycastFilterType.Exclude
aimRayParams.IgnoreWater = false

local function activeTeamCount()
	local teams = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team then
			teams[player.Team] = true
		end
	end
	local count = 0
	for _ in pairs(teams) do count += 1 end
	return count
end

local function validAimTarget(player, teamCount, localRole)
	if player == LocalPlayer or not playerIsAlive(player) then
		return false
	end
	if SETTINGS.IgnoreTeammates then
		if teamCount <= 1 then
			if localRole == "Murderer" then
				local targetRole = App.Roles[player] and App.Roles[player].Role
				return targetRole ~= "Murderer"
			end
			return App.Roles[player] and App.Roles[player].Role == "Murderer"
		end
		if LocalPlayer.Team and player.Team == LocalPlayer.Team then
			return false
		end
	end
	return true
end

local function hasLineOfSight(character, position)
	if not SETTINGS.RequireLineOfSight or not Camera then
		return true
	end
	aimRayParams.FilterDescendantsInstances = Character and {Character, Camera} or {Camera}
	local origin = Camera.CFrame.Position
	local result = Workspace:Raycast(origin, position - origin, aimRayParams)
	return result == nil or result.Instance:IsDescendantOf(character)
end

local function findAimTarget(mousePosition)
	local bestPart
	local bestPlayer
	local bestScreenDistance = SETTINGS.AimFov
	local teamCount = activeTeamCount()
	local localRole = roleFromInventory(LocalPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		if validAimTarget(player, teamCount, localRole) then
			local character = player.Character
			local part = character and (character:FindFirstChild(SETTINGS.AimPart) or character:FindFirstChild("HumanoidRootPart"))
			if part then
				local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
				if onScreen and screen.Z > 0 then
					local distance = (Vector2.new(screen.X, screen.Y) - mousePosition).Magnitude
					if distance < bestScreenDistance and hasLineOfSight(character, part.Position) then
						bestScreenDistance = distance
						bestPart = part
						bestPlayer = player
					end
				end
			end
		end
	end
	return bestPart, bestPlayer
end

local lastAutoShot = 0

local function equippedLocalWeapon()
	if not Character or not Humanoid then return nil, nil end
	for _, child in ipairs(Character:GetChildren()) do
		local role = classifyTool(child)
		if role then return child, role end
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			local role = classifyTool(child)
			if role then
				pcall(function() Humanoid:EquipTool(child) end)
				return child, role
			end
		end
	end
	return nil, nil
end

local function throwKnife(tool, predictedPosition)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("RemoteEvent") and string.find(normalizedName(descendant.Name), "throw", 1, true) then
			local ok = pcall(function() descendant:FireServer(predictedPosition) end)
			if ok then return true end
		end
	end
	if VirtualInputManager and Camera then
		local center = Camera.ViewportSize * 0.5
		local ok = pcall(function()
			VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 1, true, game, 0)
			VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 1, false, game, 0)
		end)
		if ok then return true end
	end
	return false
end

local function autoFireAt(targetPart, predictedPosition)
	if not App.Flags.AutoShoot or not RootPart then return end
	local tool, role = equippedLocalWeapon()
	if not tool or not role then return end
	local now = os.clock()
	local distance = (targetPart.Position - RootPart.Position).Magnitude
	if role == "Sheriff" then
		if now - lastAutoShot >= SETTINGS.SheriffFireDelay then
			lastAutoShot = now
			pcall(function() tool:Activate() end)
		end
	elseif role == "Murderer" then
		if distance <= 12 then
			if now - lastAutoShot >= SETTINGS.KnifeMeleeDelay then
				lastAutoShot = now
				pcall(function() tool:Activate() end)
			end
		elseif now - lastAutoShot >= SETTINGS.KnifeThrowDelay then
			lastAutoShot = now
			if not throwKnife(tool, predictedPosition) then
				-- Experience-specific throw remotes are preferred; Activate remains a
				-- safe mobile fallback when the Tool maps throwing internally.
				pcall(function() tool:Activate() end)
			end
		end
	end
end

local function updateAimbot(dt)
	Camera = Workspace.CurrentCamera or Camera
	if not Camera then
		return
	end
	if UserInputService.TouchEnabled then
		for name, button in pairs(mobileButtons) do
			if App.Flags[name] ~= nil then
				button.BackgroundColor3 = App.Flags[name] and Color3.fromRGB(55, 132, 232) or Color3.fromRGB(24, 28, 35)
			end
		end
		mobileVerticalDock.Visible = App.Flags.Fly or App.Flags.Swim
		if not mobileVerticalDock.Visible then mobileVertical = 0 end
	end
	local mouse = UserInputService.TouchEnabled and Camera.ViewportSize * 0.5 or UserInputService:GetMouseLocation()
	fovCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	fovCircle.Size = UDim2.fromOffset(SETTINGS.AimFov * 2, SETTINGS.AimFov * 2)
	fovCircle.Visible = App.Flags.Aimbot and SETTINGS.ShowFov
	if not App.Flags.Aimbot or UserInputService:GetFocusedTextBox() then
		return
	end
	local target = findAimTarget(mouse)
	if target then
		local predictedPosition = target.Position
		local localRole
		if App.Flags.AutoShoot then
			local _, detectedRole = equippedLocalWeapon()
			localRole = detectedRole
		end
		if localRole == "Murderer" and RootPart then
			local distance = (target.Position - RootPart.Position).Magnitude
			local travelTime = math.clamp(distance / SETTINGS.KnifeProjectileSpeed, 0, 1.15)
			predictedPosition += target.AssemblyLinearVelocity * travelTime
		end
		local desired = CFrame.lookAt(Camera.CFrame.Position, predictedPosition)
		local speed = math.clamp(SETTINGS.AimSpeed, 1, 100)
		local alpha = speed >= 99 and 1 or 1 - math.exp(-(4 + speed * 0.55) * math.min(dt, 0.1))
		Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
		local aimDirection = (predictedPosition - Camera.CFrame.Position).Unit
		if Camera.CFrame.LookVector:Dot(aimDirection) >= 0.993 then
			autoFireAt(target, predictedPosition)
		end
	end
end

addConnection(RunService.RenderStepped:Connect(updateAimbot))
addConnection(RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastRoleScan >= SETTINGS.RoleScanRate then
		lastRoleScan = now
		scanRoles()
		detectMassLobbyTeleport()
	end
	if not App.LastEspUpdate or now - App.LastEspUpdate >= SETTINGS.EspUpdateRate then
		App.LastEspUpdate = now
		updateEsp()
	end
end))

function App:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Flags.Noclip = false
	self.Flags.Fly = false
	self.Flags.Swim = false
	self.Flags.Esp = false
	self.Flags.Aimbot = false
	self.Flags.GrabGun = false
	self.Flags.CoinFarm = false
	self.Flags.AutoShoot = false
	self.Flags.AntiAfk = false
	self.Flags.AntiFling = false
	coinFarmToken += 1
	grabGunToken += 1
	mobileVertical = 0
	table.clear(self.NoclipForces)
	for part, wasCollidable in pairs(originalCollision) do
		if part.Parent then part.CanCollide = wasCollidable end
	end
	table.clear(originalCollision)
	destroyMovementRig()
	for player in pairs(self.EspRecords) do destroyEsp(player) end
	for _, bucket in pairs(self.PlayerConnections) do disconnectBucket(bucket) end
	table.clear(self.PlayerConnections)
	disconnectBucket(self.Connections)
	for _, instance in ipairs(self.Instances) do destroyInstance(instance) end
	table.clear(self.Instances)
	if self.RenLib then
		pcall(function() self.RenLib:Unload() end)
	end
	if sharedEnvironment.RenChallengeHub == self then
		sharedEnvironment.RenChallengeHub = nil
	end
end

-- RenLib UI ----------------------------------------------------------------

local loaded, RenLibOrError = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"))()
end)
if not loaded then
	App:Destroy()
	error("Ren Challenge Hub could not load RenLib: " .. tostring(RenLibOrError))
end

local RenLib = RenLibOrError
App.RenLib = RenLib
RenLib:ApplyThemePreset("Nebula")

local Window = RenLib:CreateWindow({
	Name = "Ren Challenge Hub",
	Width = 900,
	Height = 600,
	ShowUserProfile = true,
	ProfileUserId = LocalPlayer.UserId,
	ProfileSubtitle = "Round tools ready",
	EnableGlobalSearch = true,
	EnableSidebarResize = true,
	SidebarMode = "Dynamic",
	MaterialMode = "Frosted",
	MaterialIntensity = 16,
	ShowInfiniteYield = false,
	BeforeRelaunch = function()
		App:Destroy()
	end,
})
App.Window = Window
App.Controls = {}

-- Loading another RenLib session or closing this one also tears down every
-- gameplay connection and restores character properties.
RenLib:RegisterAddon("ChallengeHubRuntime", {
	Start = function() end,
	Stop = function()
		if not App.Destroyed then App:Destroy() end
	end,
	Unload = function()
		if not App.Destroyed then App:Destroy() end
	end,
})
RenLib:LoadAutoloadConfig()

Window:CreateTabCategory("Challenge tools")
local MovementTab = Window:CreateTab({Name = "Movement", Icon = RenLib.Icons.Movement or "6034287594"})
local VisualsTab = Window:CreateTab({Name = "ESP", Icon = RenLib.Icons.Eye or "6031075938"})
local CombatTab = Window:CreateTab({Name = "Aim", Icon = RenLib.Icons.Target or "6031763426"})
local AutomationTab = Window:CreateTab({Name = "Automation", Icon = RenLib.Icons.Bolt or "6034287594"})
local SettingsTab = Window:CreateTab({Name = "Settings", Icon = RenLib.Icons.Settings or "6031280882"})

local Movement = MovementTab:CreateSection({Name = "Movement engine", Side = "Left"})
local MovementTuning = MovementTab:CreateSection({Name = "Tuning", Side = "Right"})

App.Controls.Noclip = Movement:CreateToggle({
	Name = "Noclip",
	Flag = "RenNoclip",
	Default = false,
	Tooltip = "Disables character collision and catches falls before the world void.",
	Callback = function(value) App:SetNoclip(value) end,
})
App.Controls.Fly = Movement:CreateToggle({
	Name = "Fly",
	Flag = "RenFly",
	Default = false,
	Tooltip = "Camera-relative LinearVelocity flight; keeps the Humanoid animation controller alive.",
	Callback = function(value) App:SetFly(value) end,
})
App.Controls.Swim = Movement:CreateToggle({
	Name = "Swim anywhere",
	Flag = "RenSwim",
	Default = false,
	Tooltip = "Uses Swimming state, a local follow surface, and camera-relative 3D movement.",
	Callback = function(value) App:SetSwim(value) end,
})
Movement:CreateParagraph({
	Title = "Controls",
	Content = "WASD to move, Space to rise, Left Ctrl or C to descend. Fly and swim are mutually exclusive.",
})

MovementTuning:CreateSlider({
	Name = "Fly speed",
	Flag = "RenFlySpeed",
	Min = 10,
	Max = 30,
	Step = 1,
	Default = SETTINGS.FlySpeed,
	Callback = function(value) SETTINGS.FlySpeed = value end,
})
MovementTuning:CreateSlider({
	Name = "Swim speed",
	Flag = "RenSwimSpeed",
	Min = 12,
	Max = 100,
	Step = 2,
	Default = SETTINGS.SwimSpeed,
	Callback = function(value) SETTINGS.SwimSpeed = value end,
})
MovementTuning:CreateToggle({
	Name = "Return to last safe floor",
	Flag = "RenVoidReturn",
	Default = SETTINGS.VoidReturnToSafeGround,
	Callback = function(value) SETTINGS.VoidReturnToSafeGround = value end,
})

local EspMain = VisualsTab:CreateSection({Name = "Player ESP", Side = "Left"})
local RoleMain = VisualsTab:CreateSection({Name = "Role intelligence", Side = "Right"})
App.Controls.Esp = EspMain:CreateToggle({
	Name = "ESP",
	Flag = "RenEsp",
	Default = false,
	Tooltip = "Shows username, display name, health, distance, and remembered round role.",
	Callback = function(value) App:SetEsp(value) end,
})
EspMain:CreateSlider({
	Name = "Maximum distance",
	Flag = "RenEspDistance",
	Min = 100,
	Max = 5000,
	Step = 100,
	Default = SETTINGS.EspDistance,
	Callback = function(value)
		SETTINGS.EspDistance = value
	end,
})
RoleMain:CreateParagraph({
	Title = "Accurate role memory",
	Content = "Knife/melee evidence marks Murderer and stays remembered while alive. Gun ownership marks Sheriff and transfers when another living player picks it up. Death, exposed round-state values, and mass lobby teleports clear stale roles.",
})
RoleMain:CreateButton({
	Name = "Clear remembered round",
	Description = "Use this if a custom game hides every normal round-end signal.",
	Callback = function() clearRound("Roles manually cleared.") end,
})

local AimMain = CombatTab:CreateSection({Name = "Aim assist", Side = "Left"})
local AimRules = CombatTab:CreateSection({Name = "Target rules", Side = "Right"})
App.Controls.Aimbot = AimMain:CreateToggle({
	Name = "Aimbot",
	Flag = "RenAimbot",
	Default = false,
	Tooltip = "Selects the closest visible target inside the FOV and smoothly turns the camera.",
	Callback = function(value) App.Flags.Aimbot = value end,
})
AimMain:CreateSlider({
	Name = "FOV radius",
	Flag = "RenAimFov",
	Min = 30,
	Max = 500,
	Step = 5,
	Default = SETTINGS.AimFov,
	Callback = function(value) SETTINGS.AimFov = value end,
})
AimMain:CreateSlider({
	Name = "Aim speed",
	Flag = "RenAimSpeed",
	Min = 1,
	Max = 100,
	Step = 1,
	Default = SETTINGS.AimSpeed,
	Tooltip = "100 snaps immediately; lower values retain smooth camera motion.",
	Callback = function(value) SETTINGS.AimSpeed = value end,
})
AimMain:CreateToggle({
	Name = "Show FOV circle",
	Flag = "RenShowFov",
	Default = SETTINGS.ShowFov,
	Callback = function(value) SETTINGS.ShowFov = value end,
})
AimRules:CreateDropdown({
	Name = "Aim part",
	Flag = "RenAimPart",
	Values = {"Head", "HumanoidRootPart", "UpperTorso"},
	Default = SETTINGS.AimPart,
	Callback = function(value) SETTINGS.AimPart = value end,
})
AimRules:CreateToggle({
	Name = "Ignore teammates",
	Flag = "RenIgnoreTeam",
	Default = SETTINGS.IgnoreTeammates,
	Tooltip = "With one team, survivors target only the Murderer; a local Murderer targets everyone else.",
	Callback = function(value) SETTINGS.IgnoreTeammates = value end,
})
AimRules:CreateToggle({
	Name = "Require line of sight",
	Flag = "RenAimVisibility",
	Default = SETTINGS.RequireLineOfSight,
	Tooltip = "Raycasts from the camera so aim never locks through walls.",
	Callback = function(value) SETTINGS.RequireLineOfSight = value end,
})
AimRules:CreateToggle({
	Name = "Auto shoot / throw",
	Flag = "RenAutoShoot",
	Default = SETTINGS.AutoShoot,
	Tooltip = "Gun and melee use Tool:Activate for desktop/mobile. Knife throws use a Throw remote or mobile-safe RMB fallback with movement prediction.",
	Callback = function(value)
		SETTINGS.AutoShoot = value
		App.Flags.AutoShoot = value
	end,
})

local AutoRound = AutomationTab:CreateSection({Name = "Round actions", Side = "Left"})
local AutoCoins = AutomationTab:CreateSection({Name = "Coin route", Side = "Right"})
App.Controls.GrabGun = AutoRound:CreateToggle({
	Name = "Grab dropped gun",
	Flag = "RenGrabGun",
	Default = false,
	Tooltip = "On Sheriff death, visits the dropped gun for 2 seconds, keeps movement enabled, then returns to the saved position.",
	Callback = function(value) App:SetGrabGun(value) end,
})
App.Controls.CoinFarm = AutoCoins:CreateToggle({
	Name = "Coin farm",
	Flag = "RenCoinFarm",
	Default = false,
	Tooltip = "Physically routes through walls with forced noclip. Never teleports/tweens and never attempts more than 50 coins per round.",
	Callback = function(value) App:SetCoinFarm(value) end,
})
AutoCoins:CreateSlider({
	Name = "Route speed",
	Flag = "RenCoinWalkSpeed",
	Min = 10,
	Max = 30,
	Step = 1,
	Default = SETTINGS.CoinWalkSpeed,
	Callback = function(value) SETTINGS.CoinWalkSpeed = value end,
})
AutoCoins:CreateParagraph({
	Title = "50 coin hard limit",
	Content = "Each coin instance and rounded spawn position is remembered for the current round, so persistent collected coins are not revisited.",
})

local Keybinds = SettingsTab:CreateSection({Name = "PC quick toggles", Side = "Left"})
local Session = SettingsTab:CreateSection({Name = "Session", Side = "Right"})
Keybinds:CreateKeyPicker({Name = "Aimbot key", Flag = "RenAimKey", Default = "Q", Mode = "Toggle", Callback = function(_, active)
	App.Controls.Aimbot:Set(active)
end})
Keybinds:CreateKeyPicker({Name = "ESP key", Flag = "RenEspKey", Default = "E", Mode = "Toggle", Callback = function(_, active)
	App.Controls.Esp:Set(active)
end})
Keybinds:CreateKeyPicker({Name = "Noclip key", Flag = "RenNoclipKey", Default = "N", Mode = "Toggle", Callback = function(_, active)
	App.Controls.Noclip:Set(active)
end})
Keybinds:CreateKeyPicker({Name = "Fly key", Flag = "RenFlyKey", Default = "F", Mode = "Toggle", Callback = function(_, active)
	App.Controls.Fly:Set(active)
end})
Keybinds:CreateParagraph({
	Title = "Defaults",
	Content = "Q Aimbot  |  E ESP  |  N Noclip  |  F Fly. Rebind any shortcut here; RenLib's keybind manager also lists them.",
})

Session:CreateToggle({
	Name = "Anti-AFK",
	Flag = "RenAntiAfk",
	Default = true,
	Tooltip = "Automatically handles Roblox's idle signal. Enabled by design.",
	Callback = function(value) App.Flags.AntiAfk = value end,
})
Session:CreateToggle({
	Name = "Anti-Fling",
	Flag = "RenAntiFling",
	Default = true,
	Tooltip = "Rejects abnormal linear/angular velocity and restores the last stable transform. Intentional hub movement is exempt.",
	Callback = function(value) App.Flags.AntiFling = value end,
})

Session:CreateButton({
	Name = "Open keybind manager",
	Callback = function() RenLib.KeybindManager:Show() end,
})
Session:CreateButton({
	Name = "Rebuild world floor cache",
	Description = "Refresh after a map is inserted or removed.",
	Callback = function()
		rebuildFloorCache()
		notify("Floor cache", floorPart and string.format("Lowest map surface: %.1f studs", floorSurfaceY) or "No collidable map floor found.")
	end,
})
Session:CreateButton({
	Name = "Unload challenge hub",
	Description = "Restores collision, movement state, camera overlays, and every connection.",
	Callback = function() App:Destroy() end,
})

scanRoles()
notify("Ren Challenge Hub", "Ready. Q Aim | E ESP | N Noclip | F Fly", 6)
