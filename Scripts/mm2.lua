-- Ren Challenge Hub
-- v7: V5 coin engine restored, classic ESP, aggressive FPS booster + visual culling.
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
	AntiVoid = true,
	DestroyHeightMargin = 18,
	VoidReturnToSafeGround = true,
	EspUpdateRate = 1 / 60,
	RoleScanRate = 0.35,
	AimFov = 170,
	AimSpeed = 100,
	AimPart = "Head",
	AimPredictionBase = 0.105,
	AimPredictionMax = 0.24,
	AimLockGrace = 0.22,
	AimLockFovScale = 1.45,
	IgnoreTeammates = true,
	RequireLineOfSight = true,
	ShowFov = true,
	AutoShoot = false,
	SheriffFireDelay = 0.36,
	GrabGunDelay = 2.0,
	GrabGunAcquireTimeout = 1.5,
	GrabGunFlickDuration = 0.14,
	GrabGunRetries = 3,
	QuickDodgeDistance = 7,
	QuickDodgeCooldown = 0.62,
	QuickDodgeThreatRange = 58,
	QuickDodgeProjectileHorizon = 0.75,
	QuickDodgeMeleeRange = 12.5,
	QuickDodgeMeleeEmergencyRange = 8.8,
	QuickDodgeMeleeResetRange = 16,
	QuickDodgeMeleePrediction = 0.24,
	QuickDodgeExposure = 0.075,
	QuickDodgeThrowExposure = 0.13,
	CoinLimit = 50,
	CoinWalkSpeed = 15,
	FPSRenderDistance = 160,
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
		AntiVoid = true,
		Esp = false,
		GunEsp = false,
		Aimbot = false,
		GrabGun = false,
		QuickDodge = false,
		CoinFarm = false,
		AutoShoot = false,
		AntiAfk = true,
		AntiFling = true,
		FPSBooster = false,
		LimitRenderDistance = false,
	},
	RoundState = {SignalSeen = false, Active = nil, Lobby = false, Revision = 0},
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
end


local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.IgnoreWater = false

local function updateSafeGround(now)
	if not RootPart or not Character or now - lastSafeSample < 0.2 then
		return
	end
	lastSafeSample = now
	groundRayParams.FilterDescendantsInstances = {Character}
	local result = Workspace:Raycast(RootPart.Position, Vector3.new(0, -12, 0), groundRayParams)
	if result and result.Instance and result.Instance.CanCollide and result.Normal.Y > 0.35
		and RootPart.AssemblyLinearVelocity.Y > -10 then
		lastSafeCFrame = RootPart.CFrame
	end
end

local function applyVoidProtection()
	if not App.Flags.AntiVoid or not RootPart or not (App.Flags.Noclip or next(App.NoclipForces) ~= nil) then
		return
	end

	-- Use Roblox's actual destroy plane instead of guessing from the world's
	-- lowest anchored part. Maps often contain decorative/hidden parts far below
	-- gameplay, which made the old cache create false floor teleports.
	local floorGuard = Workspace.FallenPartsDestroyHeight + SETTINGS.DestroyHeightMargin
	if RootPart.Position.Y <= floorGuard and RootPart.AssemblyLinearVelocity.Y < -1 then
		local destination
		if SETTINGS.VoidReturnToSafeGround and lastSafeCFrame then
			destination = lastSafeCFrame + Vector3.new(0, 2.5, 0)
		else
			destination = CFrame.new(RootPart.Position.X, floorGuard + 3, RootPart.Position.Z) * RootPart.CFrame.Rotation
		end
		RootPart.CFrame = destination
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		notify("Void protection", "Fall intercepted at the Roblox destroy plane.", 2.5)
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

-- Fly -----------------------------------------------------------------------

local movementAttachment
local movementVelocity
local movementOrientation
local smoothedVelocity = Vector3.zero
local previousAutoRotate
local mobileVertical = 0

local function destroyMovementRig()
	destroyInstance(movementVelocity)
	destroyInstance(movementOrientation)
	destroyInstance(movementAttachment)
	movementVelocity = nil
	movementOrientation = nil
	movementAttachment = nil
	smoothedVelocity = Vector3.zero
	if Humanoid and previousAutoRotate ~= nil then
		Humanoid.AutoRotate = previousAutoRotate
	end
	previousAutoRotate = nil
end

local function createMovementRig()
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

	if direction.Magnitude < 0.01 and Humanoid and Humanoid.MoveDirection.Magnitude > 0.01 then
		direction = Humanoid.MoveDirection
	end
	return direction.Magnitude > 1 and direction.Unit or direction
end

local function updateMovement(dt)
	if not App.Flags.Fly or not RootPart or not Humanoid then
		return
	end
	if not movementVelocity or not movementVelocity.Parent then
		createMovementRig()
	end
	if not movementVelocity then
		return
	end

	local target = cameraMovementDirection() * math.min(SETTINGS.FlySpeed, 30)
	local alpha = 1 - math.exp(-SETTINGS.FlyResponse * math.min(dt, 0.1))
	smoothedVelocity = smoothedVelocity:Lerp(target, alpha)
	movementVelocity.VectorVelocity = smoothedVelocity

	Camera = Workspace.CurrentCamera or Camera
	if Camera and movementOrientation then
		local facing = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
		if facing.Magnitude > 0.001 then
			movementOrientation.CFrame = CFrame.lookAt(Vector3.zero, facing.Unit, Vector3.yAxis)
		end
	end
end

function App:SetFly(enabled)
	self.Flags.Fly = enabled == true
	if self.Flags.Fly then
		createMovementRig()
	else
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

-- The coin engine intentionally trusts live pickup state, not remembered positions.
-- A target must still expose a touch/prompt interaction when selected and while we
-- move to it. Collected/invisible/stale Coin_Server objects therefore fall out of
-- the route automatically instead of pulling the player back to an old spawn.
local coinFailures = setmetatable({}, {__mode = "k"})
local coinCandidates = setmetatable({}, {__mode = "k"})
local coinAttempts = 0
local coinFarmToken = 0
local lastCoinFullScan = 0

local function coinNormalize(value)
	return string.lower(tostring(value)):gsub("[%s%p_]", "")
end

local function coinContainsAny(value, fragments)
	for _, fragment in ipairs(fragments) do
		if string.find(value, fragment, 1, true) then return true end
	end
	return false
end

local function resetCoinRound()
	table.clear(coinFailures)
	table.clear(coinCandidates)
	coinAttempts = 0
	lastCoinFullScan = 0
end

local function objectPosition(object)
	if object:IsA("BasePart") then return object.Position end
	if object:IsA("Model") then return object:GetPivot().Position end
	local part = object:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function normalizedCoinName(object)
	return coinNormalize(object and object.Name or "")
end

local function coinContainerAncestor(object)
	local cursor = object and object.Parent
	while cursor and cursor ~= Workspace do
		local key = normalizedCoinName(cursor)
		if coinContainsAny(key, {"coincontainer", "coinfolder", "coinsfolder", "coinholder", "coincollection"}) then
			return cursor
		end
		cursor = cursor.Parent
	end
	return nil
end

local function coinPickupPart(object)
	if not object or not object.Parent then return nil end
	if object:IsA("BasePart") then return object end
	local best
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant:FindFirstChildOfClass("TouchTransmitter") then return descendant end
			if descendant.CanTouch and descendant.Transparency < 0.98 then best = best or descendant end
		end
	end
	return best or object:FindFirstChildWhichIsA("BasePart", true)
end

local function coinLooksLive(object)
	if not object or not object.Parent or not object:IsDescendantOf(Workspace) then return false end
	local part = coinPickupPart(object)
	if not part or not part.Parent then return false end

	local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
	local touch = part:FindFirstChildOfClass("TouchTransmitter")
	if not touch and not part.CanTouch and not (prompt and prompt.Enabled) then return false end

	local visible = part.Transparency < 0.98 and part.LocalTransparencyModifier < 0.98
	if not visible and object:IsA("Model") then
		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Transparency < 0.98 and descendant.LocalTransparencyModifier < 0.98 then
				visible = true
				break
			end
		end
	end
	-- A real TouchTransmitter is stronger evidence than visibility. Some challenge
	-- maps intentionally hide the mesh while leaving the pickup touch target live.
	return visible or touch ~= nil or (prompt and prompt.Enabled) == true
end

local function isCoinObject(object)
	if not (object and (object:IsA("BasePart") or object:IsA("Model"))) then return false end
	local key = normalizedCoinName(object)
	if coinContainsAny(key, {"spawn", "marker", "placeholder", "template", "decor"}) then return false end
	local exact = key == "coinserver" or key == "coinserve" or key == "coin" or key == "coinpickup" or key == "cointoken"
	local container = coinContainerAncestor(object)
	if not exact then
		-- Generic objects are accepted only as direct pickup children. Descendant mesh/
		-- hitbox parts are represented by their parent candidate instead of becoming
		-- separate route targets at the same physical coin.
		if not container or object.Parent ~= container then return false end
	end
	if container and coinContainsAny(normalizedCoinName(container), {"spawn", "template"}) then return false end
	return coinLooksLive(object)
end

local function rememberCoinCandidate(object)
	if isCoinObject(object) then coinCandidates[object] = true end
end

local function refreshCoinCandidates(force)
	local now = os.clock()
	if not force and now - lastCoinFullScan < 0.65 then return end
	lastCoinFullScan = now
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("BasePart") or object:IsA("Model") then rememberCoinCandidate(object) end
	end
end

refreshCoinCandidates(true)
addConnection(Workspace.DescendantAdded:Connect(function(object)
	rememberCoinCandidate(object)
	if object.Parent then rememberCoinCandidate(object.Parent) end
end))
addConnection(Workspace.DescendantRemoving:Connect(function(object)
	coinCandidates[object] = nil
	coinFailures[object] = nil
end))

local function nearestLiveCoin()
	if not RootPart then return nil end
	local now = os.clock()
	local nearest, nearestPart, nearestPosition
	local bestDistance = math.huge
	for object in pairs(coinCandidates) do
		if not object or not object.Parent or not object:IsDescendantOf(Workspace) then
			coinCandidates[object] = nil
			coinFailures[object] = nil
		elseif coinLooksLive(object) then
			local part = coinPickupPart(object)
			local position = part and part.Position
			if position then
				local failure = coinFailures[object]
				if failure and failure.Position and (position - failure.Position).Magnitude > 2.5 then
					coinFailures[object] = nil
					failure = nil
				end
				if not failure or now >= failure.RetryAt then
					local distance = (RootPart.Position - position).Magnitude
					if distance < bestDistance then
						nearest, nearestPart, nearestPosition, bestDistance = object, part, position, distance
					end
				end
			end
		end
	end
	return nearest, nearestPart, nearestPosition, bestDistance
end

local function touchCoinPart(part)
	if not RootPart or not part or not part.Parent then return end
	pcall(function()
		local fn = firetouchinterest
		if type(fn) == "function" then
			fn(RootPart, part, 0)
			fn(RootPart, part, 1)
		end
	end)
end

local function walkFarmRouteTo(coin, token)
	if not RootPart or not Humanoid or not coin or not coin.Parent then return false, "gone" end
	local startPart = coinPickupPart(coin)
	if not startPart then return false, "gone" end
	local startDistance = (startPart.Position - RootPart.Position).Magnitude
	local deadline = os.clock() + math.clamp(startDistance / math.max(SETTINGS.CoinWalkSpeed, 1) * 1.8 + 1.5, 2.2, 10)
	local stagnantSince = os.clock()
	local lastDistance = startDistance

	while App.Flags.CoinFarm and token == coinFarmToken and RootPart and Humanoid do
		if not coinLooksLive(coin) then return false, "gone" end
		local part = coinPickupPart(coin)
		if not part then return false, "gone" end
		local target = part.Position + Vector3.new(0, 0.8, 0)
		local offset = target - RootPart.Position
		local distance = offset.Magnitude

		if distance <= 2.35 then
			-- Stay on the live pickup briefly and require an observable state change.
			-- We do not mark a coordinate as collected just because we reached it.
			local contactDeadline = os.clock() + 0.42
			repeat
				if not coin.Parent or not coinLooksLive(coin) then
					RootPart.AssemblyLinearVelocity = Vector3.zero
					return true, "collected"
				end
				part = coinPickupPart(coin)
				if not part then return true, "collected" end
				RootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 0.55, 0)) * RootPart.CFrame.Rotation
				RootPart.AssemblyLinearVelocity = Vector3.zero
				touchCoinPart(part)
				task.wait(0.045)
			until os.clock() >= contactDeadline or token ~= coinFarmToken or not App.Flags.CoinFarm
			return false, "contact"
		end

		if os.clock() >= deadline then return false, "timeout" end
		if distance < lastDistance - 0.18 then
			lastDistance = distance
			stagnantSince = os.clock()
		elseif os.clock() - stagnantSince > 0.75 then
			return false, "stale"
		end

		local dt = RunService.Heartbeat:Wait()
		if not RootPart then break end
		local step = math.min(distance, math.max(12, SETTINGS.CoinWalkSpeed * 1.45) * math.clamp(dt, 1 / 240, 0.05))
		local nextPosition = RootPart.Position + offset.Unit * step
		App.IntentionalMoveUntil = os.clock() + 0.35
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		RootPart.CFrame = CFrame.new(nextPosition) * RootPart.CFrame.Rotation
		Humanoid:Move(Vector3.zero, false)
	end
	return false, "stopped"
end

local function runCoinFarm(token)
	App:SetNoclipForce("CoinFarm", true)
	refreshCoinCandidates(true)

	local liveAtStart = 0
	for object in pairs(coinCandidates) do if coinLooksLive(object) then liveAtStart += 1 end end
	notify("Coin farm", liveAtStart > 0 and ("Tracking " .. liveAtStart .. " live pickups.") or "No live coin pickups detected yet; waiting for round coins.", 3)

	while App.Flags.CoinFarm and token == coinFarmToken and not App.Destroyed do
		if coinAttempts >= SETTINGS.CoinLimit then
			notify("Coin farm", "Round collection limit reached.", 4)
			break
		end
		local coin, _, position = nearestLiveCoin()
		if not coin then
			refreshCoinCandidates(false)
			task.wait(0.10)
			continue
		end

		local collected, reason = walkFarmRouteTo(coin, token)
		if token ~= coinFarmToken or not App.Flags.CoinFarm then break end
		if collected then
			coinAttempts += 1
			coinFailures[coin] = nil
		else
			local old = coinFailures[coin]
			local count = old and old.Count or 0
			coinFailures[coin] = {
				Count = count + 1,
				RetryAt = os.clock() + ((reason == "contact") and math.min(30, 6 + count * 8) or math.min(10, 1.4 + count * 2.0)),
				Position = position,
			}
		end
	end

	if token == coinFarmToken then
		App.Flags.CoinFarm = false
		if App.Controls and App.Controls.CoinFarm and App.Controls.CoinFarm:Get() then App.Controls.CoinFarm:Set(false) end
	end
	App:SetNoclipForce("CoinFarm", false)
	if RootPart then RootPart.AssemblyLinearVelocity = Vector3.zero end
end

function App:SetCoinFarm(enabled)
	enabled = enabled == true
	if self.Flags.CoinFarm == enabled then return end
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
	local intentional = App.Flags.Fly or App.Flags.CoinFarm or os.clock() < App.IntentionalMoveUntil
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

-- Coin-cap hide --------------------------------------------------------------
-- Kept outside the restored V5 farm block. Once V5 confirms 50 pickups, hold the
-- local character just under the nearest floor when that is safely above the void;
-- otherwise use a high out-of-play fallback. A round reset clears coinAttempts and
-- releases the hold automatically.
local function installCoinCapParking()
	local active = false
	local parkedRoot
	local parkedCFrame
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = false

	local function release()
		active = false
		parkedRoot = nil
		parkedCFrame = nil
		App:SetNoclipForce("CoinCapPark", false)
	end

	local function chooseParkCFrame()
		if not RootPart then return nil end
		rayParams.FilterDescendantsInstances = Character and {Character} or {}
		local origin = RootPart.Position + Vector3.new(0, 8, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -220, 0), rayParams)
		local rotation = RootPart.CFrame.Rotation
		if hit then
			local underY = hit.Position.Y - 8
			local safeVoidY = Workspace.FallenPartsDestroyHeight + SETTINGS.DestroyHeightMargin + 8
			if underY > safeVoidY then
				return CFrame.new(RootPart.Position.X, underY, RootPart.Position.Z) * rotation
			end
		end
		-- Some maps do not have a useful floor directly below the player. In that case
		-- park well above the current play space instead of risking the void.
		return CFrame.new(RootPart.Position + Vector3.new(0, 120, 0)) * rotation
	end

	addConnection(RunService.Heartbeat:Connect(function()
		if App.Destroyed then return end
		if coinAttempts < SETTINGS.CoinLimit then
			if active then release() end
			return
		end
		if not RootPart or not Character or not Humanoid or Humanoid.Health <= 0 then
			if active then release() end
			return
		end
		if not active or parkedRoot ~= RootPart then
			parkedRoot = RootPart
			parkedCFrame = chooseParkCFrame()
			if not parkedCFrame then return end
			active = true
			App:SetNoclipForce("CoinCapPark", true)
			notify("Coin farm", "50/50 reached — hiding until the round resets.", 4)
		end
		if active and parkedRoot == RootPart and parkedCFrame then
			App.IntentionalMoveUntil = os.clock() + 0.25
			RootPart.CFrame = parkedCFrame
			RootPart.AssemblyLinearVelocity = Vector3.zero
			RootPart.AssemblyAngularVelocity = Vector3.zero
		end
	end))
end
installCoinCapParking()

-- FPS / graphics reduction --------------------------------------------------
-- Aggressive but reversible client-side graphics reduction. In addition to normal
-- Roblox quality settings, optional render distance has a local visual-culling
-- fallback because StreamingTargetRadius is ignored by many experiences/clients.
local function installPerformanceEngine()
	local Lighting = game:GetService("Lighting")
	local saved = setmetatable({}, {__mode = "k"})
	local cullSaved = setmetatable({}, {__mode = "k"})
	local cullParts = {}
	local cullIndex = 1
	local lastCullUpdate = 0
	local generation = 0
	local originalStreaming = {}
	local streamingTouched = false
	local originalQuality
	local originalTechnology
	local technologyTouched = false

	local function saveAndSet(instance, property, value)
		local state = saved[instance]
		if not state then state = {}; saved[instance] = state end
		if state[property] == nil then
			local ok, old = pcall(function() return instance[property] end)
			if ok then state[property] = old end
		end
		pcall(function() instance[property] = value end)
	end

	local function characterOwned(instance)
		local model = instance:FindFirstAncestorOfClass("Model")
		return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
	end

	local function gameplayCritical(instance)
		if characterOwned(instance) then return true end
		if instance:FindFirstAncestorOfClass("Tool") then return true end
		local cursor = instance
		for _ = 1, 5 do
			if not cursor or cursor == Workspace then break end
			local key = string.lower(cursor.Name):gsub("[%s%p_]", "")
			if string.find(key, "coin", 1, true) or string.find(key, "gun", 1, true)
				or string.find(key, "revolver", 1, true) or string.find(key, "knife", 1, true)
				or string.find(key, "pickup", 1, true) then return true end
			cursor = cursor.Parent
		end
		if instance:IsA("BasePart") then
			-- V5 coin detection intentionally accepts live CanTouch pickup parts even
			-- when their names are generic. Never visually cull those candidates.
			if instance.CanTouch then return true end
			if instance:FindFirstChildOfClass("TouchTransmitter") then return true end
			if instance:FindFirstChildWhichIsA("ProximityPrompt", true) then return true end
		end
		return false
	end

	local function applyObject(instance)
		if not App.Flags.FPSBooster or not instance or not instance.Parent then return end
		if characterOwned(instance) then return end

		if instance:IsA("MeshPart") then
			saveAndSet(instance, "CastShadow", false)
			saveAndSet(instance, "Material", Enum.Material.SmoothPlastic)
			pcall(function() saveAndSet(instance, "MaterialVariant", "") end)
			saveAndSet(instance, "Reflectance", 0)
			saveAndSet(instance, "TextureID", "")
			pcall(function() saveAndSet(instance, "RenderFidelity", Enum.RenderFidelity.Performance) end)
		elseif instance:IsA("UnionOperation") then
			saveAndSet(instance, "CastShadow", false)
			saveAndSet(instance, "Material", Enum.Material.SmoothPlastic)
			saveAndSet(instance, "Reflectance", 0)
			pcall(function() saveAndSet(instance, "RenderFidelity", Enum.RenderFidelity.Performance) end)
		elseif instance:IsA("BasePart") then
			saveAndSet(instance, "CastShadow", false)
			saveAndSet(instance, "Material", Enum.Material.SmoothPlastic)
			pcall(function() saveAndSet(instance, "MaterialVariant", "") end)
			saveAndSet(instance, "Reflectance", 0)
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			saveAndSet(instance, "Transparency", 1)
		elseif instance:IsA("SpecialMesh") then
			saveAndSet(instance, "TextureId", "")
		elseif instance:IsA("SurfaceAppearance") then
			for _, property in ipairs({"ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap"}) do
				saveAndSet(instance, property, "")
			end
		elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
			or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles") then
			saveAndSet(instance, "Enabled", false)
		elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
			saveAndSet(instance, "Enabled", false)
		elseif instance:IsA("PostEffect") then
			saveAndSet(instance, "Enabled", false)
		elseif instance:IsA("Atmosphere") then
			saveAndSet(instance, "Density", 0)
			saveAndSet(instance, "Haze", 0)
			saveAndSet(instance, "Glare", 0)
		elseif instance:IsA("Clouds") then
			saveAndSet(instance, "Enabled", false)
		elseif instance:IsA("Sky") then
			for _, property in ipairs({"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId"}) do
				pcall(function() saveAndSet(instance, property, "") end)
			end
			pcall(function() saveAndSet(instance, "StarCount", 0) end)
			pcall(function() saveAndSet(instance, "CelestialBodiesShown", false) end)
		elseif (instance:IsA("SurfaceGui") or instance:IsA("BillboardGui")) and instance:IsDescendantOf(Workspace) then
			-- World-space decoration/signage is expensive in some maps. Player UI and
			-- RenChallengeOverlay live outside Workspace and are never touched.
			saveAndSet(instance, "Enabled", false)
		elseif instance:IsA("Model") then
			pcall(function() saveAndSet(instance, "LevelOfDetail", Enum.ModelLevelOfDetail.StreamingMesh) end)
		end
	end

	local function applyGlobalQuality()
		pcall(function()
			local rendering = settings().Rendering
			if originalQuality == nil then originalQuality = rendering.QualityLevel end
			rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		if not technologyTouched then
			pcall(function()
				if type(gethiddenproperty) == "function" then originalTechnology = gethiddenproperty(Lighting, "Technology")
				else originalTechnology = Lighting.Technology end
			end)
			technologyTouched = true
		end
		pcall(function()
			if type(sethiddenproperty) == "function" then sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
			else Lighting.Technology = Enum.Technology.Compatibility end
		end)
	end

	local function applyGlobals()
		applyGlobalQuality()
		saveAndSet(Lighting, "GlobalShadows", false)
		saveAndSet(Lighting, "EnvironmentDiffuseScale", 0)
		saveAndSet(Lighting, "EnvironmentSpecularScale", 0)
		saveAndSet(Lighting, "ShadowSoftness", 0)
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			saveAndSet(terrain, "WaterWaveSize", 0)
			saveAndSet(terrain, "WaterWaveSpeed", 0)
			saveAndSet(terrain, "WaterReflectance", 0)
			saveAndSet(terrain, "WaterTransparency", 1)
			pcall(function() saveAndSet(terrain, "Decoration", false) end)
		end
	end

	local function restoreAll()
		for instance, state in pairs(saved) do
			if instance then
				for property, value in pairs(state) do pcall(function() instance[property] = value end) end
			end
		end
		table.clear(saved)
		pcall(function()
			if originalQuality ~= nil then settings().Rendering.QualityLevel = originalQuality end
		end)
		if technologyTouched and originalTechnology ~= nil then
			pcall(function()
				if type(sethiddenproperty) == "function" then sethiddenproperty(Lighting, "Technology", originalTechnology)
				else Lighting.Technology = originalTechnology end
			end)
		end
	end

	local function readStreaming(property)
		local ok, value = pcall(function()
			if type(gethiddenproperty) == "function" then return gethiddenproperty(Workspace, property) end
			return Workspace[property]
		end)
		return ok and value or nil
	end

	local function writeStreaming(property, value)
		return pcall(function()
			if type(sethiddenproperty) == "function" then sethiddenproperty(Workspace, property, value)
			else Workspace[property] = value end
		end)
	end

	local function registerCullPart(instance)
		if instance:IsA("BasePart") then table.insert(cullParts, instance) end
	end

	for _, instance in ipairs(Workspace:GetDescendants()) do registerCullPart(instance) end

	local function restoreCullPart(part)
		local old = cullSaved[part]
		if old ~= nil and part and part.Parent then pcall(function() part.LocalTransparencyModifier = old end) end
		cullSaved[part] = nil
	end

	local function restoreCullAll()
		for part in pairs(cullSaved) do restoreCullPart(part) end
	end

	local function updateCullBatch()
		if not App.Flags.LimitRenderDistance or #cullParts == 0 then return end
		local now = os.clock()
		if now - lastCullUpdate < 0.12 then return end
		lastCullUpdate = now
		if cullIndex > #cullParts then
			local rebuilt = {}
			for _, part in ipairs(cullParts) do if part and part.Parent then table.insert(rebuilt, part) end end
			cullParts = rebuilt
			cullIndex = 1
			if #cullParts == 0 then return end
		end
		local originPart = RootPart
		local origin = originPart and originPart.Position or (Camera and Camera.CFrame.Position)
		if not origin then return end
		local limit = math.max(24, SETTINGS.FPSRenderDistance)
		local batch = math.min(450, #cullParts)
		for _ = 1, batch do
			if cullIndex > #cullParts then cullIndex = 1 end
			local part = cullParts[cullIndex]
			cullIndex += 1
			if part and part.Parent then
				if gameplayCritical(part) then
					restoreCullPart(part)
				else
					local far = (part.Position - origin).Magnitude > limit
					if far then
						if cullSaved[part] == nil then
							local ok, old = pcall(function() return part.LocalTransparencyModifier end)
							if ok then cullSaved[part] = old end
						end
						pcall(function() part.LocalTransparencyModifier = 1 end)
					else
						restoreCullPart(part)
					end
				end
			end
		end
	end

	function App:SetRenderDistanceLimit(enabled)
		enabled = enabled == true
		self.Flags.LimitRenderDistance = enabled
		if enabled then
			if not streamingTouched then
				originalStreaming.Target = readStreaming("StreamingTargetRadius")
				originalStreaming.Min = readStreaming("StreamingMinRadius")
				streamingTouched = true
			end
			local visualTarget = math.clamp(math.floor(SETTINGS.FPSRenderDistance + 0.5), 24, 1024)
			local streamingTarget = math.max(64, visualTarget)
			writeStreaming("StreamingTargetRadius", streamingTarget)
			writeStreaming("StreamingMinRadius", math.max(32, math.min(streamingTarget, math.floor(streamingTarget * 0.5))))
		else
			restoreCullAll()
			if streamingTouched then
				if originalStreaming.Target ~= nil then writeStreaming("StreamingTargetRadius", originalStreaming.Target) end
				if originalStreaming.Min ~= nil then writeStreaming("StreamingMinRadius", originalStreaming.Min) end
			end
		end
	end

	function App:SetFPSBooster(enabled)
		enabled = enabled == true
		if self.Flags.FPSBooster == enabled then return end
		self.Flags.FPSBooster = enabled
		generation += 1
		local token = generation
		if not enabled then
			restoreAll()
			return
		end
		applyGlobals()
		task.spawn(function()
			local objects = Workspace:GetDescendants()
			local lightingObjects = Lighting:GetDescendants()
			for _, object in ipairs(lightingObjects) do table.insert(objects, object) end
			for index, object in ipairs(objects) do
				if token ~= generation or not App.Flags.FPSBooster then return end
				applyObject(object)
				if index % 220 == 0 then RunService.Heartbeat:Wait() end
			end
		end)
	end

	addConnection(Workspace.DescendantAdded:Connect(function(instance)
		registerCullPart(instance)
		if App.Flags.FPSBooster then task.defer(applyObject, instance) end
	end))
	addConnection(Lighting.DescendantAdded:Connect(function(instance)
		if App.Flags.FPSBooster then task.defer(applyObject, instance) end
	end))
	addConnection(RunService.Heartbeat:Connect(updateCullBatch))
end
installPerformanceEngine()

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

local gunCandidates = setmetatable({}, {__mode = "k"})
local lastSheriffDeathPosition
local lastSheriffDeathAt = -math.huge

local function objectInsideCharacter(object)
	local cursor = object
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Model") and cursor:FindFirstChildOfClass("Humanoid") then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

local function droppedGunTouchPart(object)
	if not object or not object.Parent then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Tool") then
		return object:FindFirstChild("Handle") or object:FindFirstChildWhichIsA("BasePart", true)
	end
	if object:IsA("Model") then
		return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
	end
	return object:FindFirstChildWhichIsA("BasePart", true)
end

local function strongDroppedGunName(object)
	local key = normalizedName(object.Name)
	return containsAny(key, {
		"gundrop", "droppedgun", "gunpickup", "sheriffdrop",
		"revolverdrop", "weaponpickup", "droppedrevolver",
	})
end

local function ancestryLooksDecorative(object)
	local cursor = object
	while cursor and cursor ~= Workspace do
		local key = normalizedName(cursor.Name)
		if containsAny(key, {"decor", "decoration", "display", "showcase", "cosmetic", "propdisplay", "weaponrack"}) then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

local function hasPickupInteraction(object)
	if object:IsA("ProximityPrompt") or object:IsA("ClickDetector") or object:IsA("TouchTransmitter") then
		return true
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ProximityPrompt")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("TouchTransmitter") then
			return true
		end
	end
	return false
end

local function droppedGunRootFrom(object)
	local cursor = object
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Tool") and classifyTool(cursor) == "Sheriff" then
			return cursor, "tool"
		end
		if (cursor:IsA("Model") or cursor:IsA("BasePart")) and strongDroppedGunName(cursor) then
			return cursor, "drop"
		end
		cursor = cursor.Parent
	end
	return nil
end

local function rememberGunCandidate(object, initialScan)
	local root, kind = droppedGunRootFrom(object)
	if not root or not root:IsDescendantOf(Workspace) or objectInsideCharacter(root) then return end
	if ancestryLooksDecorative(root) then return end

	local part = droppedGunTouchPart(root)
	if not part then return end

	if kind == "drop" then
		local interactive = hasPickupInteraction(root)
		-- Static map geometry named "Gun", "Pistol", etc. is never considered.
		-- A non-Tool object must have a strong drop/pickup name, and during the
		-- initial map scan it must also expose a real pickup interaction.
		if initialScan and not interactive then return end
		if not interactive and (part.Anchored or not part.CanTouch) then return end
	end

	local existing = gunCandidates[root]
	gunCandidates[root] = existing or {
		Kind = kind,
		SeenAt = os.clock(),
	}
end

for _, object in ipairs(Workspace:GetDescendants()) do
	rememberGunCandidate(object, true)
end
addConnection(Workspace.DescendantAdded:Connect(function(object)
	rememberGunCandidate(object, false)
	if object.Parent then
		rememberGunCandidate(object.Parent, false)
	end
end))
addConnection(Workspace.DescendantRemoving:Connect(function(object)
	gunCandidates[object] = nil
end))

local function validDroppedGunCandidate(object, meta, referencePosition)
	if not object or not meta or not object.Parent or not object:IsDescendantOf(Workspace) then
		return false
	end
	if objectInsideCharacter(object) or ancestryLooksDecorative(object) then
		return false
	end
	if meta.Kind == "tool" then
		if not object:IsA("Tool") or classifyTool(object) ~= "Sheriff" then return false end
		local part = droppedGunTouchPart(object)
		if not part then return false end
		local parent = object.Parent
		local parentKey = parent and normalizedName(parent.Name) or ""
		local worldDropParent = parent == Workspace
			or containsAny(parentKey, {"drop", "pickup", "weapon", "item"})
		if not worldDropParent then return false end
		if not part.CanTouch and not hasPickupInteraction(object) then return false end
		if part.Anchored and not hasPickupInteraction(object) then return false end
		return true
	end

	local part = droppedGunTouchPart(object)
	if not part then return false end
	local interactive = hasPickupInteraction(object)
	if interactive and not part.Anchored then
		return true
	end

	-- Anchored/custom pickup parts are only accepted when they actually appeared
	-- around the recorded Sheriff death. This deliberately prefers a missed marker
	-- over tagging an interactive gun prop built into the map.
	if lastSheriffDeathPosition and meta.SeenAt >= lastSheriffDeathAt - 1.0 then
		local position = part.Position
		return (position - lastSheriffDeathPosition).Magnitude <= 55
			and (not referencePosition or (position - referencePosition).Magnitude <= 90)
	end
	return false
end

local function findDroppedGun(referencePosition, maxDistance)
	local bestObject
	local bestPart
	local bestPosition
	local bestDistance = math.huge
	for object, meta in pairs(gunCandidates) do
		if validDroppedGunCandidate(object, meta, referencePosition) then
			local part = droppedGunTouchPart(object)
			local position = part and part.Position or objectPosition(object)
			if position then
				local distance = referencePosition and (position - referencePosition).Magnitude or 0
				if (not maxDistance or distance <= maxDistance) and distance < bestDistance then
					bestObject = object
					bestPart = part
					bestPosition = position
					bestDistance = distance
				end
			end
		end
	end
	return bestObject, bestPart, bestPosition, bestDistance
end

local function localHasSheriffGun()
	for _, container in ipairs({Character, LocalPlayer:FindFirstChildOfClass("Backpack")}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and classifyTool(child) == "Sheriff" then
					return true
				end
			end
		end
	end
	return false
end

local function bestEffortTouch(part)
	if not RootPart or not part or not part.Parent then
		return
	end
	pcall(function()
		local fn = firetouchinterest
		if type(fn) == "function" then
			fn(RootPart, part, 0)
			RunService.Heartbeat:Wait()
			fn(RootPart, part, 1)
		end
	end)
end

local function startGrabGun(sheriff, deathPosition)
	if not App.Flags.GrabGun or not RootPart or not deathPosition then
		return
	end

	grabGunToken += 1
	local token = grabGunToken
	task.spawn(function()
		-- The two-second delay starts at the confirmed Sheriff death. We intentionally
		-- do not save the return position yet so normal player movement during those
		-- two seconds is preserved.
		local wakeAt = os.clock() + SETTINGS.GrabGunDelay
		while token == grabGunToken and App.Flags.GrabGun and os.clock() < wakeAt do
			task.wait(math.min(0.08, wakeAt - os.clock()))
		end
		if token ~= grabGunToken or not App.Flags.GrabGun or not RootPart then return end

		local gunObject, gunPart, gunPosition
		local acquireDeadline = os.clock() + SETTINGS.GrabGunAcquireTimeout
		repeat
			gunObject, gunPart, gunPosition = findDroppedGun(deathPosition, 75)
			if gunObject and gunPart and gunPosition then break end
			task.wait(0.05)
		until token ~= grabGunToken or os.clock() >= acquireDeadline

		if token ~= grabGunToken or not RootPart then return end
		if not gunObject or not gunPart or not gunPosition then
			notify("Grab gun", "Dropped gun was not found; no fallback teleport was used.", 3)
			return
		end

		local returnCFrame = RootPart.CFrame
		local resumeCoinFarm = App.Flags.CoinFarm
		if resumeCoinFarm then App:SetCoinFarm(false) end
		App:SetNoclipForce("GrabGun", true)
		App.IntentionalMoveUntil = os.clock() + 0.8

		local success = localHasSheriffGun()
		local flickDeadline = os.clock() + SETTINGS.GrabGunFlickDuration
		for attempt = 1, SETTINGS.GrabGunRetries do
			if success or token ~= grabGunToken or not RootPart then break end
			local _, livePart, livePosition = findDroppedGun(deathPosition, 75)
			if livePart and livePosition then
				gunPart, gunPosition = livePart, livePosition
			end
			if not gunPart or not gunPart.Parent then break end

			RootPart.AssemblyLinearVelocity = Vector3.zero
			RootPart.AssemblyAngularVelocity = Vector3.zero
			local jitter = (attempt - 2) * 0.55
			RootPart.CFrame = CFrame.new(gunPosition + Vector3.new(jitter, 1.25, -jitter)) * returnCFrame.Rotation
			bestEffortTouch(gunPart)
			RunService.Heartbeat:Wait()
			success = localHasSheriffGun()
			if os.clock() >= flickDeadline then break end
		end

		if token == grabGunToken and RootPart then
			RootPart.AssemblyLinearVelocity = Vector3.zero
			RootPart.AssemblyAngularVelocity = Vector3.zero
			RootPart.CFrame = returnCFrame
		end
		App:SetNoclipForce("GrabGun", false)
		if resumeCoinFarm and App.Flags.GrabGun then App:SetCoinFarm(true) end

		if success then
			notify("Grab gun", "Pickup flick completed and your position was restored.", 2.5)
		else
			notify("Grab gun", "Gun contact was attempted, but pickup was not confirmed.", 3)
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
	if record.WeaponLabel then record.WeaponLabel.TextColor3 = Color3.fromRGB(235, 238, 242) end
	if record.Highlight then
		record.Highlight.FillColor = color
		record.Highlight.OutlineColor = color
	end
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
	if App.RoundState.Active ~= true then
		App.RoundState.Active = true
		App.RoundState.Lobby = false
		App.RoundState.Revision += 1
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
	App.RoundState.Active = false
	App.RoundState.Lobby = true
	App.RoundState.Revision += 1
	-- Prevent corpse/backpack remnants from immediately recreating stale roles
	-- while the server is moving everyone back to spawn.
	roleSuppressedUntil = lastRoundReset + 2.5
	resetCoinRound()
	lastSheriffDeathPosition = nil
	lastSheriffDeathAt = -math.huge
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
			App.RoundState.SignalSeen = true
			explicitLobbyState = true
			App.RoundState.Active = false
			App.RoundState.Lobby = true
			App.RoundState.Revision += 1
			if os.clock() - lastRoundReset > 1 then
				clearRound("The game reported a lobby/intermission state.")
			end
		elseif isActiveRoundState(instance) then
			App.RoundState.SignalSeen = true
			explicitLobbyState = false
			App.RoundState.Active = true
			App.RoundState.Lobby = false
			App.RoundState.Revision += 1
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

function App:IsRoundActiveForAutomation()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return false end
	local teamKey = LocalPlayer.Team and normalizedName(LocalPlayer.Team.Name) or ""
	if containsAny(teamKey, {"lobby", "spect", "waiting", "dead"}) then return false end
	for _, holder in ipairs({LocalPlayer, character}) do
		for name, value in pairs(holder:GetAttributes()) do
			local key = normalizedName(name)
			if value == true and containsAny(key, {"spectating", "isspectator", "inlobby", "islobby"}) then return false end
			if value == false and containsAny(key, {"inround", "roundactive", "isingame"}) then return false end
		end
	end
	if self.RoundState.SignalSeen then
		return self.RoundState.Active == true and not self.RoundState.Lobby
	end
	if explicitLobbyState or os.clock() < roleSuppressedUntil then return false end
	if self.RoundState.Active == true or currentMurderer or currentSheriff then return true end
	local localRole = roleFromInventory(LocalPlayer)
	if localRole then
		self.RoundState.Active = true
		self.RoundState.Lobby = false
		return true
	end
	return false
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
overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
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
fovStroke.Transparency = 0.42
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

-- Player ESP ----------------------------------------------------------------
-- Competitive ESP: perspective-correct corner box, prominent health bar,
-- role-coloured skeleton and readable identity text. Screen coordinates are applied
-- directly every RenderStepped frame; no positional smoothing is used, so the box
-- cannot trail behind a moving character.
local destroyEsp, createEsp, hideEspRecord, updateEsp
local function installEspEngine()
	local ESP_R15_JOINTS = {
		{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
		{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
		{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
		{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
		{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
	}
	local ESP_R6_JOINTS = {
		{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
		{"Torso", "Left Leg"}, {"Torso", "Right Leg"},
	}

	App.EspRayParams = RaycastParams.new()
	App.EspRayParams.FilterType = Enum.RaycastFilterType.Exclude
	App.EspRayParams.IgnoreWater = false

	destroyEsp = function(player)
		local record = App.EspRecords[player]
		if not record then return end
		destroyInstance(record.Container)
		destroyInstance(record.Highlight)
		App.EspRecords[player] = nil
	end

	local function makeEspLine(parent, thickness, z)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = COLORS.Default
		line.BackgroundTransparency = 0
		line.Size = UDim2.fromOffset(0, thickness or 1)
		line.Visible = false
		line.ZIndex = z or 22
		line.Parent = parent
		return line
	end

	local function setEspLine(line, a, b, thickness)
		local delta = b - a
		local length = delta.Magnitude
		if length < 0.35 then line.Visible = false; return end
		line.Position = UDim2.fromOffset((a.X + b.X) * 0.5, (a.Y + b.Y) * 0.5)
		line.Size = UDim2.fromOffset(length, thickness or 1)
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		line.Visible = true
	end

	local function makeLinePair(parent, thickness)
		local shadow = makeEspLine(parent, (thickness or 1) + 2, 20)
		shadow.BackgroundColor3 = Color3.fromRGB(3, 3, 3)
		shadow.BackgroundTransparency = 0.08
		local main = makeEspLine(parent, thickness or 1, 21)
		return {Shadow = shadow, Main = main}
	end

	local function setLinePair(pair, a, b, thickness, color, transparency)
		setEspLine(pair.Shadow, a, b, (thickness or 1) + 2)
		setEspLine(pair.Main, a, b, thickness or 1)
		pair.Shadow.BackgroundTransparency = 0.08
		pair.Main.BackgroundColor3 = color
		pair.Main.BackgroundTransparency = transparency or 0
	end

	local function hideLinePair(pair)
		pair.Shadow.Visible = false
		pair.Main.Visible = false
	end

	local function newEspText(parent, size, bold)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
		label.TextColor3 = Color3.fromRGB(248, 249, 252)
		label.TextSize = size
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 32
		label.Visible = false
		label.Parent = parent
		return label
	end

	local function cacheRigParts(character)
		local parts = {}
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("BasePart") then parts[child.Name] = child end
		end
		return parts
	end

	local function equippedWeaponName(character)
		if not character then return "-" end
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then return child.Name end
		end
		return "-"
	end

	createEsp = function(player)
		if player == LocalPlayer then return nil end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or not root then return nil end
		destroyEsp(player)

		local container = Instance.new("Frame")
		container.Name = "ESP_" .. player.Name
		container.BackgroundTransparency = 1
		container.Size = UDim2.fromScale(1, 1)
		container.Visible = true
		container.Parent = overlayGui

		local boxPairs = {}
		local colorObjects = {}
		for i = 1, 8 do
			boxPairs[i] = makeLinePair(container, 1.25)
			table.insert(colorObjects, boxPairs[i].Main)
		end

		local skeletonLines = {}
		for i = 1, 14 do
			local line = makeEspLine(container, 1.65, 24)
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(0, 0, 0)
			stroke.Thickness = 1
			stroke.Transparency = 0.08
			stroke.Parent = line
			skeletonLines[i] = line
			table.insert(colorObjects, line)
		end

		local healthBack = Instance.new("Frame")
		healthBack.AnchorPoint = Vector2.new(0, 0)
		healthBack.BorderSizePixel = 0
		healthBack.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
		healthBack.ZIndex = 25
		healthBack.Visible = false
		healthBack.Parent = container
		local healthFill = Instance.new("Frame")
		healthFill.AnchorPoint = Vector2.new(0, 1)
		healthFill.BorderSizePixel = 0
		healthFill.BackgroundColor3 = Color3.fromRGB(80, 235, 105)
		healthFill.ZIndex = 26
		healthFill.Visible = false
		healthFill.Parent = container

		local nameLabel = newEspText(container, 16, true)
		nameLabel.Size = UDim2.fromOffset(360, 20)
		local metaLabel = newEspText(container, 13, true)
		metaLabel.Size = UDim2.fromOffset(340, 18)

		local highlight = Instance.new("Highlight")
		highlight.Name = "RenESPHighlight"
		highlight.Adornee = character
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillTransparency = 0.94
		highlight.OutlineTransparency = 0.05
		highlight.Enabled = false
		highlight.Parent = character

		local extents = character:GetExtentsSize()
		local record = {
			Character = character, Humanoid = humanoid, Root = root, Parts = cacheRigParts(character),
			Container = container, BoxPairs = boxPairs, SkeletonLines = skeletonLines,
			NameLabel = nameLabel, WeaponLabel = metaLabel, HealthBack = healthBack, HealthFill = healthFill,
			Highlight = highlight, ColorObjects = colorObjects,
			BodyHeight = math.clamp(extents.Y, 4.5, 8.5),
			NextPartsRefresh = 0, NextTextRefresh = 0, NextVisibilityUpdate = 0,
			Occluded = false, WallDepth = 0,
		}
		App.EspRecords[player] = record
		refreshEspStyle(player)
		return record
	end

	hideEspRecord = function(record)
		if not record then return end
		for _, pair in ipairs(record.BoxPairs or {}) do hideLinePair(pair) end
		for _, line in ipairs(record.SkeletonLines or {}) do line.Visible = false end
		if record.NameLabel then record.NameLabel.Visible = false end
		if record.WeaponLabel then record.WeaponLabel.Visible = false end
		if record.HealthBack then record.HealthBack.Visible = false end
		if record.HealthFill then record.HealthFill.Visible = false end
		if record.Highlight then record.Highlight.Enabled = false end
	end

	local function drawCornerBox(record, left, top, right, bottom, color, transparency)
		local width, height = right - left, bottom - top
		local corner = math.clamp(math.min(width, height) * 0.26, 5, 18)
		local p = record.BoxPairs
		setLinePair(p[1], Vector2.new(left, top), Vector2.new(left + corner, top), 1.5, color, transparency)
		setLinePair(p[2], Vector2.new(left, top), Vector2.new(left, top + corner), 1.5, color, transparency)
		setLinePair(p[3], Vector2.new(right - corner, top), Vector2.new(right, top), 1.5, color, transparency)
		setLinePair(p[4], Vector2.new(right, top), Vector2.new(right, top + corner), 1.5, color, transparency)
		setLinePair(p[5], Vector2.new(left, bottom - corner), Vector2.new(left, bottom), 1.5, color, transparency)
		setLinePair(p[6], Vector2.new(left, bottom), Vector2.new(left + corner, bottom), 1.5, color, transparency)
		setLinePair(p[7], Vector2.new(right, bottom - corner), Vector2.new(right, bottom), 1.5, color, transparency)
		setLinePair(p[8], Vector2.new(right - corner, bottom), Vector2.new(right, bottom), 1.5, color, transparency)
	end

	local function updateSingleEsp(player, record, now)
		if record.Character ~= player.Character or not record.Root or not record.Root.Parent or not record.Humanoid or not record.Humanoid.Parent then
			destroyEsp(player)
			record = createEsp(player)
			if not record then return end
		end
		if now >= record.NextPartsRefresh then
			record.NextPartsRefresh = now + 0.20
			record.Parts = cacheRigParts(record.Character)
			record.Root = record.Character:FindFirstChild("HumanoidRootPart") or record.Root
			record.Humanoid = record.Character:FindFirstChildOfClass("Humanoid") or record.Humanoid
			local extents = record.Character:GetExtentsSize()
			record.BodyHeight = math.clamp(extents.Y, 4.5, 8.5)
		end
		local targetRoot = record.Root
		if targetRoot and targetRoot.Parent then lastKnownPositions[player] = targetRoot.Position end
		if not App.Flags.Esp or not targetRoot or record.Humanoid.Health <= 0 then hideEspRecord(record); return end

		local bodyHeight = record.BodyHeight or 6
		local topScreen = Camera:WorldToViewportPoint(targetRoot.Position + Vector3.new(0, bodyHeight * 0.54, 0))
		local bottomScreen = Camera:WorldToViewportPoint(targetRoot.Position - Vector3.new(0, bodyHeight * 0.50, 0))
		if topScreen.Z <= 0.1 or bottomScreen.Z <= 0.1 then hideEspRecord(record); return end

		local rawCenter = Vector2.new((topScreen.X + bottomScreen.X) * 0.5, (topScreen.Y + bottomScreen.Y) * 0.5)
		local rawHeight = math.abs(bottomScreen.Y - topScreen.Y)
		if rawHeight < 5 then hideEspRecord(record); return end
		rawHeight = math.min(rawHeight, Camera.ViewportSize.Y * 0.88)

		-- Direct screen-space placement: this deliberately does NOT Lerp. Any smoothing
		-- here creates visible trailing when the target changes direction or the camera pans.
		local center = rawCenter
		local height = rawHeight
		local width = math.clamp(height * 0.48, 10, Camera.ViewportSize.X * 0.28)
		local left, right = center.X - width * 0.5, center.X + width * 0.5
		local top, bottom = center.Y - height * 0.5, center.Y + height * 0.5
		local onScreen = right >= -20 and left <= Camera.ViewportSize.X + 20 and bottom >= -20 and top <= Camera.ViewportSize.Y + 20
		if not onScreen then hideEspRecord(record); return end

		local distance = RootPart and (targetRoot.Position - RootPart.Position).Magnitude or 0
		if now >= record.NextVisibilityUpdate then
			record.NextVisibilityUpdate = now + 0.07
			App.EspRayParams.FilterDescendantsInstances = Character and {Character, Camera, record.Character} or {Camera, record.Character}
			local origin = Camera.CFrame.Position
			local ray = targetRoot.Position - origin
			local hit = Workspace:Raycast(origin, ray, App.EspRayParams)
			record.Occluded = hit ~= nil
			record.WallDepth = hit and math.max(0, ray.Magnitude - (hit.Position - origin).Magnitude) or 0
		end

		local role = App.Roles[player] and App.Roles[player].Role or "PLAYER"
		local color = COLORS[role] or COLORS.Default
		local boxTransparency = record.Occluded and 0.28 or 0
		drawCornerBox(record, left, top, right, bottom, color, boxTransparency)

		-- Occluded targets gain a real 3D silhouette, which gives the eye wall/depth
		-- context that a flat box cannot. Visible targets keep only a thin outline.
		record.Highlight.Enabled = true
		record.Highlight.FillColor = color
		record.Highlight.OutlineColor = color
		record.Highlight.FillTransparency = record.Occluded and 0.76 or 0.91
		record.Highlight.OutlineTransparency = record.Occluded and 0 or 0.08

		local ratio = math.clamp(record.Humanoid.Health / math.max(record.Humanoid.MaxHealth, 1), 0, 1)
		record.HealthBack.Position = UDim2.fromOffset(left - 9, top - 1)
		record.HealthBack.Size = UDim2.fromOffset(7, height + 2)
		record.HealthBack.Visible = height >= 18
		record.HealthFill.Position = UDim2.fromOffset(left - 8, bottom)
		record.HealthFill.Size = UDim2.fromOffset(5, math.max(2, height * ratio))
		record.HealthFill.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.85, 0.98)
		record.HealthFill.Visible = record.HealthBack.Visible

		record.NameLabel.Position = UDim2.fromOffset(center.X, top - 13)
		record.WeaponLabel.Position = UDim2.fromOffset(center.X, bottom + 12)
		record.NameLabel.Visible = true
		record.WeaponLabel.Visible = true
		if now >= record.NextTextRefresh then
			record.NextTextRefresh = now + 0.08
			local identity = player.DisplayName ~= player.Name and string.format("%s  @%s", player.DisplayName, player.Name) or ("@" .. player.Name)
			record.NameLabel.Text = string.format("%s  [%s]", identity, string.upper(role))
			record.NameLabel.TextColor3 = color
			local wall = record.Occluded and string.format(" | WALL +%dm", math.floor(record.WallDepth + 0.5)) or ""
			record.WeaponLabel.Text = string.format("HP %d  |  %dm  |  %s%s", math.max(0, math.floor(record.Humanoid.Health + 0.5)), math.floor(distance + 0.5), string.lower(equippedWeaponName(record.Character)), wall)
			record.WeaponLabel.TextColor3 = Color3.fromRGB(242, 244, 247)
		end

		local skeletonEligible = height >= 30 and distance <= 320
		if not skeletonEligible then
			for _, line in ipairs(record.SkeletonLines) do line.Visible = false end
		else
			-- Skeleton is projected every render update. It is intentionally NOT visibility-
			-- culled by walls; the ScreenGui line stays stable while Highlight supplies depth.
			local joints = record.Parts.UpperTorso and ESP_R15_JOINTS or ESP_R6_JOINTS
			for index, line in ipairs(record.SkeletonLines) do
				local pair = joints[index]
				local a = pair and record.Parts[pair[1]]
				local b = pair and record.Parts[pair[2]]
				if a and b and a.Parent and b.Parent then
					local sa = Camera:WorldToViewportPoint(a.Position)
					local sb = Camera:WorldToViewportPoint(b.Position)
					if sa.Z > 0.08 and sb.Z > 0.08 then
						setEspLine(line, Vector2.new(sa.X, sa.Y), Vector2.new(sb.X, sb.Y), math.clamp(1.85 - distance / 650, 1.15, 1.75))
						line.BackgroundColor3 = color
						line.BackgroundTransparency = record.Occluded and 0.03 or 0
					else line.Visible = false end
				else line.Visible = false end
			end
		end
	end

	updateEsp = function()
		Camera = Workspace.CurrentCamera or Camera
		if not Camera then return end
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local record = App.EspRecords[player]
				if not record and App.Flags.Esp then record = createEsp(player) end
				if record then updateSingleEsp(player, record, now) end
			end
		end
		for player in pairs(App.EspRecords) do if player.Parent ~= Players then destroyEsp(player) end end
	end

end
installEspEngine()
local lastGunEspUpdate = 0
local function updateGunEsp(now)
	if not App.Flags.GunEsp or not Camera then
		gunCrossH.Visible = false; gunCrossV.Visible = false; gunLabel.Visible = false; return
	end
	if now - lastGunEspUpdate < 0.05 then return end
	lastGunEspUpdate = now
	local reference = lastSheriffDeathPosition or (RootPart and RootPart.Position) or nil
	local _, _, position = findDroppedGun(reference, lastSheriffDeathPosition and 90 or nil)
	if not position then gunCrossH.Visible = false; gunCrossV.Visible = false; gunLabel.Visible = false; return end
	local viewport = Camera.ViewportSize
	local screen = Camera:WorldToViewportPoint(position)
	local center = viewport * 0.5
	local point = Vector2.new(screen.X, screen.Y)
	if screen.Z <= 0 then point = center - (point - center) end
	local margin = 24
	point = Vector2.new(math.clamp(point.X, margin, viewport.X - margin), math.clamp(point.Y, margin + 18, viewport.Y - margin))
	gunCrossH.Position = UDim2.fromOffset(point.X, point.Y)
	gunCrossV.Position = UDim2.fromOffset(point.X, point.Y)
	gunCrossH.Visible, gunCrossV.Visible = true, true
	local distance = RootPart and (position - RootPart.Position).Magnitude or 0
	gunLabel.Text = string.format("GUN  %dm", math.floor(distance + 0.5))
	gunLabel.Position = UDim2.fromOffset(point.X, point.Y - 8)
	gunLabel.Visible = true
end

function App:SetEsp(enabled)
	self.Flags.Esp = enabled == true
	if not self.Flags.Esp then for _, record in pairs(self.EspRecords) do hideEspRecord(record) end end
	updateEsp()
end

local function onPlayerDied(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local deathPosition = root and root.Position or lastKnownPositions[player]
	if player == currentSheriff then
		lastSheriffDeathPosition = deathPosition
		lastSheriffDeathAt = os.clock()
		startGrabGun(player, deathPosition)
	end
	if player == currentMurderer then
		clearRound("The murderer died.")
	else
		clearPlayerRole(player)
	end
end

local function monitorPlayer(player)
	if player == LocalPlayer then return end
	if App.PlayerConnections[player] then
		disconnectBucket(App.PlayerConnections[player])
	end

	local bucket = {}
	App.PlayerConnections[player] = bucket
	local boundHumanoids = setmetatable({}, {__mode = "k"})

	local function bindCharacter(character)
		task.defer(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			if player.Character ~= character then return end
			createEsp(player)
			if humanoid and not boundHumanoids[humanoid] then
				boundHumanoids[humanoid] = true
				addConnection(humanoid.Died:Connect(function()
					onPlayerDied(player)
				end), bucket)
			end
		end)
	end

	addConnection(player.CharacterAdded:Connect(bindCharacter), bucket)
	addConnection(player.CharacterRemoving:Connect(function(character)
		destroyEsp(player)
		if player == currentMurderer then
			clearRound("The murderer left or respawned.")
		else
			clearPlayerRole(player)
		end
	end), bucket)

	if player.Character then
		bindCharacter(player.Character)
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

-- Aim + predictive combat ---------------------------------------------------

local aimRayParams = RaycastParams.new()
aimRayParams.FilterType = Enum.RaycastFilterType.Exclude
aimRayParams.IgnoreWater = false

local function activeTeamCount()
	local teams = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team then teams[player.Team] = true end
	end
	local count = 0
	for _ in pairs(teams) do count += 1 end
	return count
end

local cachedLocalRole
local cachedLocalRoleAt = 0
local function getLocalRole()
	local now = os.clock()
	if now - cachedLocalRoleAt >= 0.12 then
		local detectedRole = roleFromInventory(LocalPlayer)
		if detectedRole then
			cachedLocalRole = detectedRole
		elseif playerIsAlive(LocalPlayer) then
			cachedLocalRole = "Innocent"
		else
			cachedLocalRole = nil
		end
		cachedLocalRoleAt = now
	end
	return cachedLocalRole
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
	return result == nil or (result.Instance and result.Instance:IsDescendantOf(character))
end

local aimMotion = {}
local function sampleTargetMotion(player, part, now)
	local entry = aimMotion[player]
	local rawVelocity = part.AssemblyLinearVelocity
	if not entry or entry.Part ~= part then
		entry = {Part = part, Position = part.Position, Velocity = rawVelocity, Acceleration = Vector3.zero, Time = now}
		aimMotion[player] = entry
		return entry.Velocity, entry.Acceleration
	end

	local dt = math.clamp(now - entry.Time, 1 / 240, 0.12)
	local measuredVelocity = (part.Position - entry.Position) / dt
	local velocity = rawVelocity:Lerp(measuredVelocity, 0.28)
	velocity = entry.Velocity:Lerp(velocity, 0.55)
	local acceleration = (velocity - entry.Velocity) / dt
	if acceleration.Magnitude > 190 then
		acceleration = acceleration.Unit * 190
	end
	acceleration = entry.Acceleration:Lerp(acceleration, 0.38)

	entry.Position = part.Position
	entry.Velocity = velocity
	entry.Acceleration = acceleration
	entry.Time = now
	return velocity, acceleration
end

local function predictedAimPosition(player, part, now)
	local velocity, acceleration = sampleTargetMotion(player, part, now)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local distance = RootPart and (part.Position - RootPart.Position).Magnitude or (part.Position - Camera.CFrame.Position).Magnitude
	local horizon = SETTINGS.AimPredictionBase + math.clamp(distance / 2200, 0, 0.055)
	local airborne = humanoid and humanoid.FloorMaterial == Enum.Material.Air
	if airborne then horizon += 0.02 end
	horizon = math.clamp(horizon, 0.045, SETTINGS.AimPredictionMax)

	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local horizontalAcceleration = Vector3.new(acceleration.X, 0, acceleration.Z)
	local predicted = part.Position + horizontalVelocity * horizon + horizontalAcceleration * (0.5 * horizon * horizon)
	if airborne then
		predicted += Vector3.new(0, velocity.Y * horizon - 0.5 * Workspace.Gravity * horizon * horizon, 0)
	else
		predicted += Vector3.new(0, velocity.Y * math.min(horizon, 0.07), 0)
	end
	return predicted
end

local aimLockedPlayer
local aimLockLastVisible = 0

local function aimCandidate(player, mousePosition, fovLimit, now, teamCount, localRole)
	if not validAimTarget(player, teamCount, localRole) then return nil end
	local character = player.Character
	local part = character and (character:FindFirstChild(SETTINGS.AimPart) or character:FindFirstChild("HumanoidRootPart"))
	if not part then return nil end
	local predicted = predictedAimPosition(player, part, now)
	local screen, onScreen = Camera:WorldToViewportPoint(predicted)
	if not onScreen or screen.Z <= 0 then return nil end
	local screenDistance = (Vector2.new(screen.X, screen.Y) - mousePosition).Magnitude
	if screenDistance > fovLimit then return nil end
	if not hasLineOfSight(character, predicted) then return nil end
	return part, predicted, screenDistance
end

local function findAimTarget(mousePosition, now)
	local teamCount = activeTeamCount()
	local localRole = getLocalRole()

	if aimLockedPlayer then
		local part, predicted, distance = aimCandidate(aimLockedPlayer, mousePosition, SETTINGS.AimFov * SETTINGS.AimLockFovScale, now, teamCount, localRole)
		if part then
			aimLockLastVisible = now
			return part, aimLockedPlayer, predicted
		elseif now - aimLockLastVisible <= SETTINGS.AimLockGrace then
			return nil
		else
			aimLockedPlayer = nil
		end
	end

	local bestPart
	local bestPlayer
	local bestPredicted
	local bestDistance = SETTINGS.AimFov
	for _, player in ipairs(Players:GetPlayers()) do
		local part, predicted, distance = aimCandidate(player, mousePosition, SETTINGS.AimFov, now, teamCount, localRole)
		if part and distance < bestDistance then
			bestPart, bestPlayer, bestPredicted, bestDistance = part, player, predicted, distance
		end
	end
	if bestPlayer then
		aimLockedPlayer = bestPlayer
		aimLockLastVisible = now
	end
	return bestPart, bestPlayer, bestPredicted
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

local function autoFireAt()
	if not App.Flags.AutoShoot then return end
	local tool, role = equippedLocalWeapon()
	if not tool or role ~= "Sheriff" then return end
	local now = os.clock()
	if now - lastAutoShot >= SETTINGS.SheriffFireDelay then
		lastAutoShot = now
		pcall(function() tool:Activate() end)
	end
end

-- Quick dodge [BETA] --------------------------------------------------------
-- Remote camera aim is not replicated by Roblox, so this engine does not pretend it
-- can read another player's exact crosshair. It uses deterministic threat windows:
-- close Murderer melee, clear-LOS throw exposure, clear-LOS Sheriff gun exposure,
-- plus real projectile motion when the experience exposes a projectile part.

local dodgeRayParams = RaycastParams.new()
dodgeRayParams.FilterType = Enum.RaycastFilterType.Exclude
dodgeRayParams.IgnoreWater = false
local dodgeOverlapParams = OverlapParams.new()
dodgeOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
dodgeOverlapParams.MaxParts = 20
local lastQuickDodge = -math.huge

local function equippedRoleTool(player, role)
	local character = player and player.Character
	if not character then return nil end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and classifyTool(child) == role then return child end
	end
	return nil
end

local function screenThreatGeometry(player)
	if not RootPart or not player or not playerIsAlive(player) then return nil end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local originPart = head or root
	if not originPart then return nil end
	local toLocal = RootPart.Position - originPart.Position
	local distance = toLocal.Magnitude
	if distance < 0.1 or distance > SETTINGS.QuickDodgeThreatRange then return nil end
	dodgeRayParams.FilterDescendantsInstances = Character and {Character, character} or {character}
	local hit = Workspace:Raycast(originPart.Position, toLocal, dodgeRayParams)
	if hit then return nil end
	return originPart.Position, toLocal.Unit, distance
end

local function groundedDodgePosition(rawPosition)
	if not RootPart or not Humanoid then return nil end
	dodgeRayParams.FilterDescendantsInstances = Character and {Character} or {}
	local ground = Workspace:Raycast(rawPosition + Vector3.new(0, 7, 0), Vector3.new(0, -18, 0), dodgeRayParams)
	if not ground or not ground.Instance or not ground.Instance.CanCollide or ground.Normal.Y < 0.22 then return nil end
	local y = ground.Position.Y + math.clamp(Humanoid.HipHeight + RootPart.Size.Y * 0.5, 2.0, 4.0)
	local position = Vector3.new(rawPosition.X, y, rawPosition.Z)
	dodgeOverlapParams.FilterDescendantsInstances = Character and {Character, ground.Instance} or {ground.Instance}
	local parts = Workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(1.55, 2.7, 1.55), dodgeOverlapParams)
	for _, part in ipairs(parts) do
		if part.CanCollide and not (Character and part:IsDescendantOf(Character)) then return nil end
	end
	return position
end

local function lineDistance(point, lineOrigin, lineDirection)
	local offset = point - lineOrigin
	local along = offset:Dot(lineDirection)
	return (offset - lineDirection * along).Magnitude
end

local function performQuickDodge(threatOrigin, threatDirection, threatCharacter)
	if not App.Flags.QuickDodge or not RootPart or not Humanoid then return false end
	local now = os.clock()
	if now - lastQuickDodge < SETTINGS.QuickDodgeCooldown then return false end
	local flat = Vector3.new(threatDirection.X, 0, threatDirection.Z)
	if flat.Magnitude < 0.05 then flat = Vector3.new(RootPart.Position.X - threatOrigin.X, 0, RootPart.Position.Z - threatOrigin.Z) end
	if flat.Magnitude < 0.05 then return false end
	flat = flat.Unit
	local side = Vector3.yAxis:Cross(flat).Unit
	local d = SETTINGS.QuickDodgeDistance
	local candidates = {
		RootPart.Position + side * d,
		RootPart.Position - side * d,
		RootPart.Position + side * (d * 0.78) - flat * 2.5,
		RootPart.Position - side * (d * 0.78) - flat * 2.5,
		RootPart.Position - flat * math.max(4.5, d * 0.70),
	}
	local bestPosition, bestScore
	bestScore = -math.huge
	for _, raw in ipairs(candidates) do
		local candidate = groundedDodgePosition(raw)
		if candidate then
			local score = lineDistance(candidate, threatOrigin, threatDirection.Unit) * 4 - (candidate - RootPart.Position).Magnitude * 0.25
			dodgeRayParams.FilterDescendantsInstances = Character and threatCharacter and {Character, threatCharacter} or (Character and {Character} or {})
			local cover = Workspace:Raycast(threatOrigin, candidate - threatOrigin, dodgeRayParams)
			if cover and (cover.Position - threatOrigin).Magnitude < (candidate - threatOrigin).Magnitude - 1.2 then score += 15 end
			if score > bestScore then bestScore, bestPosition = score, candidate end
		end
	end
	if not bestPosition then return false end
	lastQuickDodge = now
	App.IntentionalMoveUntil = now + 0.30
	App:SetNoclipForce("QuickDodge", true)
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero
	RootPart.CFrame = CFrame.new(bestPosition) * RootPart.CFrame.Rotation
	task.delay(0.12, function() if not App.Destroyed then App:SetNoclipForce("QuickDodge", false) end end)
	return true
end

local function performMeleeDodge(murderer)
	if not App.Flags.QuickDodge or not RootPart or not Humanoid or not murderer or not murderer.Character then return false end
	local murderRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
	if not murderRoot then return false end
	local now = os.clock()
	if now - lastQuickDodge < SETTINGS.QuickDodgeCooldown then return false end
	local away = Vector3.new(RootPart.Position.X - murderRoot.Position.X, 0, RootPart.Position.Z - murderRoot.Position.Z)
	if away.Magnitude < 0.05 then away = Vector3.new(0, 0, 1) end
	away = away.Unit
	local side = Vector3.yAxis:Cross(away).Unit
	local d = SETTINGS.QuickDodgeDistance
	local candidates = {
		RootPart.Position + away * d,
		RootPart.Position + away * (d * 0.72) + side * (d * 0.62),
		RootPart.Position + away * (d * 0.72) - side * (d * 0.62),
		RootPart.Position + side * d,
		RootPart.Position - side * d,
	}
	local bestPosition, bestScore
	bestScore = -math.huge
	for _, raw in ipairs(candidates) do
		local candidate = groundedDodgePosition(raw)
		if candidate then
			local separation = (Vector3.new(candidate.X, murderRoot.Position.Y, candidate.Z) - murderRoot.Position).Magnitude
			local score = separation * 5 - (candidate - RootPart.Position).Magnitude * 0.20
			if score > bestScore then bestScore, bestPosition = score, candidate end
		end
	end
	if not bestPosition then return false end
	lastQuickDodge = now
	App.IntentionalMoveUntil = now + 0.30
	App:SetNoclipForce("QuickDodge", true)
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero
	RootPart.CFrame = CFrame.new(bestPosition) * RootPart.CFrame.Rotation
	task.delay(0.12, function() if not App.Destroyed then App:SetNoclipForce("QuickDodge", false) end end)
	return true
end

local meleeThreatArmed = true
local meleeThreatPlayer
local lastMeleeThreatCheck = 0

local function updateCloseMeleeThreat(now)
	if not App.Flags.QuickDodge or not RootPart or now - lastMeleeThreatCheck < 0.035 then return end
	lastMeleeThreatCheck = now
	local localRole = getLocalRole()
	if localRole == "Murderer" or not playerIsAlive(LocalPlayer) then meleeThreatArmed = true; meleeThreatPlayer = nil; return end
	local murderer = currentMurderer
	if not murderer or not playerIsAlive(murderer) then
		for player, info in pairs(App.Roles) do if info.Role == "Murderer" and playerIsAlive(player) then murderer = player; break end end
	end
	if not murderer then
		for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer and playerIsAlive(player) and equippedRoleTool(player, "Murderer") then murderer = player; break end end
	end
	if not murderer or not playerIsAlive(murderer) then meleeThreatArmed = true; meleeThreatPlayer = nil; return end
	local murderRoot = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
	if not murderRoot then return end
	local distance = (RootPart.Position - murderRoot.Position).Magnitude
	if murderer ~= meleeThreatPlayer then meleeThreatPlayer = murderer; meleeThreatArmed = true end
	if distance >= SETTINGS.QuickDodgeMeleeResetRange then meleeThreatArmed = true; return end
	if not meleeThreatArmed then return end
	local knifeEquipped = equippedRoleTool(murderer, "Murderer") ~= nil
	if not knifeEquipped and distance > SETTINGS.QuickDodgeMeleeEmergencyRange then return end
	local relativeVelocity = murderRoot.AssemblyLinearVelocity - RootPart.AssemblyLinearVelocity
	local futureDistance = (RootPart.Position - (murderRoot.Position + relativeVelocity * SETTINGS.QuickDodgeMeleePrediction)).Magnitude
	local closing = futureDistance < distance - 0.06
	local danger = distance <= SETTINGS.QuickDodgeMeleeEmergencyRange or (knifeEquipped and distance <= SETTINGS.QuickDodgeMeleeRange and closing)
	if not danger then return end
	dodgeRayParams.FilterDescendantsInstances = Character and {Character, murderer.Character} or {murderer.Character}
	if Workspace:Raycast(murderRoot.Position, RootPart.Position - murderRoot.Position, dodgeRayParams) then return end
	if performMeleeDodge(murderer) then meleeThreatArmed = false end
end

local function projectileKind(part)
	if not part:IsA("BasePart") or objectInsideCharacter(part) then return nil end
	local key = normalizedName(part.Name)
	if containsAny(key, {"thrownknife", "throwknife", "knifeprojectile", "bladeprojectile", "thrownblade", "throwingknife"}) then return "Murderer" end
	if containsAny(key, {"bullet", "tracer", "gunprojectile", "shotprojectile"}) then return "Sheriff" end
	return nil
end

local function inspectProjectile(part, threatRole)
	if not App.Flags.QuickDodge or not RootPart or not part.Parent then return end
	local localRole = getLocalRole()
	if localRole == "Murderer" and threatRole ~= "Sheriff" then return end
	if localRole ~= "Murderer" and threatRole ~= "Murderer" then return end
	local p0, t0 = part.Position, os.clock()
	RunService.Heartbeat:Wait()
	if not part.Parent or not RootPart then return end
	local dt = math.max(os.clock() - t0, 1 / 240)
	local measured = (part.Position - p0) / dt
	local velocity = part.AssemblyLinearVelocity
	if measured.Magnitude > velocity.Magnitude then velocity = measured end
	if velocity.Magnitude < 18 then return end
	local relative = RootPart.Position - part.Position
	local t = math.clamp(relative:Dot(velocity) / math.max(velocity:Dot(velocity), 1), 0, SETTINGS.QuickDodgeProjectileHorizon)
	local closest = part.Position + velocity * t
	if t > 0 and (closest - RootPart.Position).Magnitude <= 5.8 then performQuickDodge(part.Position, velocity.Unit, nil) end
end

addConnection(Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("BasePart") then
		local kind = projectileKind(instance)
		if kind then task.spawn(inspectProjectile, instance, kind) end
	end
end))

App.DodgePressure = {Player = nil, Role = nil, Armed = true, Since = 0, BreakSince = 0}
function App:UpdateDodgePressure(now)
	local state = self.DodgePressure
	if not self.Flags.QuickDodge or not RootPart or not playerIsAlive(LocalPlayer) then
		state.Player = nil; state.Armed = true; state.Since = 0; state.BreakSince = 0; return
	end
	local localRole = getLocalRole()
	local threatRole = localRole == "Murderer" and "Sheriff" or "Murderer"
	local threat = threatRole == "Sheriff" and currentSheriff or currentMurderer
	if not threat or not playerIsAlive(threat) then
		for player, info in pairs(App.Roles) do if info.Role == threatRole and playerIsAlive(player) then threat = player; break end end
	end
	if not threat then
		for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer and playerIsAlive(player) and equippedRoleTool(player, threatRole) then threat = player; break end end
	end
	local tool = threat and equippedRoleTool(threat, threatRole) or nil
	local origin, direction, distance = threat and tool and screenThreatGeometry(threat) or nil
	local valid = origin ~= nil
	if threatRole == "Murderer" and distance and distance <= SETTINGS.QuickDodgeMeleeRange then valid = false end

	if not valid then
		state.Since = 0
		if not state.Armed then
			if state.BreakSince == 0 then state.BreakSince = now end
			if now - state.BreakSince >= 0.45 then state.Armed = true; state.BreakSince = 0 end
		end
		return
	end
	state.BreakSince = 0
	if state.Player ~= threat or state.Role ~= threatRole then
		state.Player, state.Role, state.Armed, state.Since = threat, threatRole, true, now
	elseif state.Since == 0 then state.Since = now end
	local dwell = threatRole == "Sheriff" and SETTINGS.QuickDodgeExposure or SETTINGS.QuickDodgeThrowExposure
	if state.Armed and now - state.Since >= dwell then
		if performQuickDodge(origin, direction, threat.Character) then state.Armed = false end
		state.Since = now
	end
end

function App:TestQuickDodge()
	if not RootPart or not Camera then notify("Quick dodge", "Character/camera not ready.", 2.5); return end
	local wasEnabled = self.Flags.QuickDodge
	self.Flags.QuickDodge = true
	lastQuickDodge = -math.huge
	local flat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
	if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
	local origin = RootPart.Position - flat * 12
	local ok = performQuickDodge(origin, flat, nil)
	self.Flags.QuickDodge = wasEnabled
	notify("Quick dodge", ok and "Movement test passed." or "No safe landing point found here.", 2.5)
end

local function updateMobileOverlay()
	if not UserInputService.TouchEnabled then return end
	for name, button in pairs(mobileButtons) do
		if App.Flags[name] ~= nil then
			button.BackgroundColor3 = App.Flags[name] and Color3.fromRGB(55, 132, 232) or Color3.fromRGB(24, 28, 35)
		end
	end
	mobileVerticalDock.Visible = App.Flags.Fly
	if not mobileVerticalDock.Visible then mobileVertical = 0 end
end

local function updateAimbot(dt, now)
	Camera = Workspace.CurrentCamera or Camera
	if not Camera then return end
	local mouse = UserInputService.TouchEnabled and Camera.ViewportSize * 0.5 or UserInputService:GetMouseLocation()
	fovCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	fovCircle.Size = UDim2.fromOffset(SETTINGS.AimFov * 2, SETTINGS.AimFov * 2)
	fovCircle.Visible = App.Flags.Aimbot and SETTINGS.ShowFov
	if not App.Flags.Aimbot or UserInputService:GetFocusedTextBox() then
		aimLockedPlayer = nil
		return
	end

	local target, targetPlayer, predicted = findAimTarget(mouse, now)
	if not target or not predicted then return end
	local desired = CFrame.lookAt(Camera.CFrame.Position, predicted)
	local speed = math.clamp(SETTINGS.AimSpeed, 1, 100)
	local alpha = speed >= 99 and 1 or 1 - math.exp(-(5 + speed * 0.58) * math.min(dt, 0.1))
	Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)

	if App.Flags.AutoShoot and targetPlayer then
		local screen = Camera:WorldToViewportPoint(predicted)
		local center = Camera.ViewportSize * 0.5
		local miss = (Vector2.new(screen.X, screen.Y) - center).Magnitude
		if screen.Z > 0 and miss <= 5.5 and hasLineOfSight(targetPlayer.Character, predicted) then
			autoFireAt()
		end
	end
end

addConnection(RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	updateMobileOverlay()
	updateAimbot(dt, now)
	-- ESP is intentionally tied 1:1 to rendered frames. A 1/60 time gate can alias
	-- against Roblox's own frame timing and effectively update at 30 Hz.
	updateEsp()
	updateGunEsp(now)
end))

addConnection(RunService.Heartbeat:Connect(function()
	local now = os.clock()
	updateCloseMeleeThreat(now)
	App:UpdateDodgePressure(now)
	if now - lastRoleScan >= SETTINGS.RoleScanRate then
		lastRoleScan = now
		scanRoles()
		detectMassLobbyTeleport()
	end
end))

function App:Destroy()
	if self.Destroyed then
		return
	end
	if self.Flags.FPSBooster and self.SetFPSBooster then self:SetFPSBooster(false) end
	if self.Flags.LimitRenderDistance and self.SetRenderDistanceLimit then self:SetRenderDistanceLimit(false) end
	self.Destroyed = true
	self.Flags.Noclip = false
	self.Flags.Fly = false
	self.Flags.AntiVoid = false
	self.Flags.Esp = false
	self.Flags.GunEsp = false
	self.Flags.Aimbot = false
	self.Flags.GrabGun = false
	self.Flags.QuickDodge = false
	self.Flags.CoinFarm = false
	self.Flags.AutoShoot = false
	self.Flags.AntiAfk = false
	self.Flags.AntiFling = false
	self.Flags.FPSBooster = false
	self.Flags.LimitRenderDistance = false
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

-- Keep UI locals out of the main chunk: Luau has a 200-register local limit.
function App:BuildUI()

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
	local MovementTuning = MovementTab:CreateSection({Name = "Safety + tuning", Side = "Right"})

	App.Controls.Noclip = Movement:CreateToggle({
		Name = "Noclip",
		Flag = "RenNoclip",
		Default = false,
		Tooltip = "Disables character collision. Anti-void is controlled separately.",
		Callback = function(value) App:SetNoclip(value) end,
	})
	App.Controls.Fly = Movement:CreateToggle({
		Name = "Fly",
		Flag = "RenFly",
		Default = false,
		Tooltip = "Camera-relative LinearVelocity flight with normal Humanoid animation state.",
		Callback = function(value) App:SetFly(value) end,
	})
	Movement:CreateParagraph({
		Title = "Controls",
		Content = "WASD to move, Space to rise, Left Ctrl or C to descend. Air-swim has been removed.",
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
	App.Controls.AntiVoid = MovementTuning:CreateToggle({
		Name = "Anti-void fall",
		Flag = "RenAntiVoid",
		Default = SETTINGS.AntiVoid,
		Tooltip = "Uses Workspace.FallenPartsDestroyHeight instead of guessing the lowest map part.",
		Callback = function(value)
			SETTINGS.AntiVoid = value
			App.Flags.AntiVoid = value
		end,
	})
	MovementTuning:CreateToggle({
		Name = "Return to last safe floor",
		Flag = "RenVoidReturn",
		Default = SETTINGS.VoidReturnToSafeGround,
		Tooltip = "When anti-void catches a fall, restore the last grounded transform instead of only raising Y.",
		Callback = function(value) SETTINGS.VoidReturnToSafeGround = value end,
	})
	MovementTuning:CreateParagraph({
		Title = "Void logic",
		Content = "The guard no longer follows a cached 'lowest part' Y level, so hidden/decorative map pieces cannot pin your character to a false floor.",
	})

	local EspMain = VisualsTab:CreateSection({Name = "Player ESP", Side = "Left"})
	local RoleMain = VisualsTab:CreateSection({Name = "Role intelligence", Side = "Right"})
	App.Controls.Esp = EspMain:CreateToggle({
		Name = "ESP",
		Flag = "RenEsp",
		Default = false,
		Tooltip = "3D silhouette highlight with stable world tags, wall depth, health/distance and close-range skeleton detail.",
		Callback = function(value) App:SetEsp(value) end,
	})
	App.Controls.GunEsp = RoleMain:CreateToggle({
		Name = "Dropped gun ESP",
		Flag = "RenGunEsp",
		Default = false,
		Tooltip = "Only tracks real Sheriff Tool drops or strong interactive GunDrop/pickup objects. Plain map parts named Gun/Pistol are ignored.",
		Callback = function(value) App.Flags.GunEsp = value end,
	})
	RoleMain:CreateParagraph({
		Title = "Accurate role memory",
		Content = "Knife/melee evidence marks Murderer and stays remembered while alive. Gun ownership marks Sheriff and transfers on pickup. Death, round-state values, and mass lobby teleports clear stale roles.",
	})
	RoleMain:CreateButton({
		Name = "Clear remembered round",
		Description = "Use this if a custom challenge hides every normal round-end signal.",
		Callback = function() clearRound("Roles manually cleared.") end,
	})

	local AimMain = CombatTab:CreateSection({Name = "Predictive aim", Side = "Left"})
	local AimRules = CombatTab:CreateSection({Name = "Target rules", Side = "Right"})
	App.Controls.Aimbot = AimMain:CreateToggle({
		Name = "Aimbot",
		Flag = "RenAimbot",
		Default = false,
		Tooltip = "Sticky target lock with movement/jump prediction instead of reacquiring a new target every frame.",
		Callback = function(value) App.Flags.Aimbot = value end,
	})
	AimMain:CreateSlider({
		Name = "FOV radius",
		Flag = "RenAimFov",
		Min = 50,
		Max = 200,
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
		Tooltip = "100 snaps immediately; lower values retain smooth camera motion while prediction continues updating.",
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
		Tooltip = "Raycasts from the camera so aim never locks or fires through walls.",
		Callback = function(value) SETTINGS.RequireLineOfSight = value end,
	})
	AimRules:CreateToggle({
		Name = "Auto shoot",
		Flag = "RenAutoShoot",
		Default = SETTINGS.AutoShoot,
		Tooltip = "Sheriff gun only. Fires once predicted aim is tightly aligned. Knife throw and automatic knife melee are removed.",
		Callback = function(value)
			SETTINGS.AutoShoot = value
			App.Flags.AutoShoot = value
		end,
	})

	local AutoRound = AutomationTab:CreateSection({Name = "Round", Side = "Left"})
	local AutoCoins = AutomationTab:CreateSection({Name = "Coins", Side = "Right"})
	App.Controls.GrabGun = AutoRound:CreateToggle({
		Name = "Grab dropped gun",
		Flag = "RenGrabGun",
		Default = false,
		Tooltip = "Waits 2 seconds after Sheriff death, requires the real dropped gun, micro-flicks for pickup, then restores your current position.",
		Callback = function(value) App:SetGrabGun(value) end,
	})
	App.Controls.QuickDodge = AutoRound:CreateToggle({
		Name = "Quick dodge  [BETA]",
		Flag = "RenQuickDodge",
		Default = false,
		Tooltip = "Murderer dodges clear-LOS Sheriff gun exposure. Sheriff/Innocents prioritize close stab escape, then throw/projectile threats.",
		Callback = function(value) App.Flags.QuickDodge = value end,
	})
	AutoRound:CreateSlider({
		Name = "Dodge distance",
		Flag = "RenDodgeDistance",
		Min = 5,
		Max = 14,
		Step = 1,
		Default = SETTINGS.QuickDodgeDistance,
		Callback = function(value) SETTINGS.QuickDodgeDistance = value end,
	})
	AutoRound:CreateButton({
		Name = "Test dodge",
		Description = "Runs one dodge locally so movement can be verified separately from threat detection.",
		Callback = function() App:TestQuickDodge() end,
	})
	App.Controls.CoinFarm = AutoCoins:CreateToggle({
		Name = "Coin farm",
		Flag = "RenCoinFarm",
		Default = false,
		Tooltip = "Tracks only live touch/prompt coin pickups and requires collection state to change before counting a target.",
		Callback = function(value) App:SetCoinFarm(value) end,
	})
	AutoCoins:CreateParagraph({
		Title = "Underground route",
		Content = "V5 live-pickup routing restored. Speed stays locked to 15; targets are continuously revalidated and failed/stale pickups back off instead of trapping the route.",
	})

	local Keybinds = SettingsTab:CreateSection({Name = "PC quick toggles", Side = "Left"})
	local Session = SettingsTab:CreateSection({Name = "Session", Side = "Right"})
	local Performance = SettingsTab:CreateSection({Name = "Performance", Side = "Left"})
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

	App.Controls.FPSBooster = Performance:CreateToggle({
		Name = "FPS booster",
		Flag = "RenFPSBooster",
		Default = false,
		Tooltip = "Aggressive reversible mode: forces quality level 1 when possible, strips textures/material detail, disables shadows/lights/effects/world-space decoration, simplifies terrain/water and lowers mesh fidelity. Player characters are preserved.",
		Callback = function(value) App:SetFPSBooster(value) end,
	})
	App.Controls.RenderDistance = Performance:CreateToggle({
		Name = "Limit render distance",
		Flag = "RenLimitRenderDistance",
		Default = false,
		Tooltip = "Optional. Uses Roblox streaming radius when available and local visual culling as a fallback, so the chosen distance still has a visible effect when streaming properties are ignored.",
		Callback = function(value) App:SetRenderDistanceLimit(value) end,
	})
	Performance:CreateSlider({
		Name = "Render distance",
		Flag = "RenRenderDistance",
		Min = 32,
		Max = 768,
		Step = 16,
		Default = SETTINGS.FPSRenderDistance,
		Tooltip = "Only applied while Limit render distance is enabled. Values below Roblox's streaming minimum are enforced by local visual culling.",
		Callback = function(value)
			SETTINGS.FPSRenderDistance = value
			if App.Flags.LimitRenderDistance then App:SetRenderDistanceLimit(true) end
		end,
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
		Name = "Map floor diagnostic",
		Description = "Optional diagnostic only; anti-void no longer uses the lowest-part cache.",
		Callback = function()
			rebuildFloorCache()
			notify("Floor diagnostic", floorPart and string.format("Lowest collidable surface: %.1f studs", floorSurfaceY) or "No collidable map floor found.")
		end,
	})
	Session:CreateButton({
		Name = "Unload challenge hub",
		Description = "Restores collision, movement state, camera overlays, and every connection.",
		Callback = function() App:Destroy() end,
	})

	scanRoles()
	notify("Ren Challenge Hub", "Ready. Q Aim | E ESP | N Noclip | F Fly", 6)
end

App:BuildUI()
