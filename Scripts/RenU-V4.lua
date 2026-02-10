--[[
    RenU V4.1 - Universal Hub (Full Rewrite)
    Migrated to RenLibBêta | Enhanced & Expanded
    Original by SoLoIsTe_Cry | Upgraded by Claude

    FIXES: TP fling, Follow (now walks naturally), Bang (from behind),
           Backpack/Head (animated), ESP toggles, FOV RGB sliders
    NEW:   Fling, Slap, Proposal, GetBanged, Orbit, Stare, Attach,
           Air Swim, Glitch Flicker, Doppelganger, Desync, Spin, Headless,
           Bang speed, Fling speed
]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLibB%C3%AAta.lua"))()

---------------------------------------------------------
-- SERVICES
---------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

---------------------------------------------------------
-- UTILITY
---------------------------------------------------------
local AllConnections = {}
local KeybindsEnabled = true

local function SafeConnect(signal, func)
    local conn = signal:Connect(func)
    table.insert(AllConnections, conn)
    return conn
end

local function GetCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil, nil, nil end
    return char, hum, root
end

local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return names
end

local function Notify(title, content, emoji, duration)
    Library:Notify({Title = title, Content = content, Emoji = emoji or "ℹ️", Duration = duration or 3})
end

local function FindPlayer(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and (p.Name == name or string.lower(p.Name):find(string.lower(name))) then
            return p
        end
    end
    return nil
end

local function DisableCollision(char)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

local function EnableCollision(char)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
    end
end

local function PlayAnim(hum, id, looped, speed)
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(id)
    local track = nil
    pcall(function()
        track = hum:LoadAnimation(anim)
        track.Looped = looped or false
        if speed then track:AdjustSpeed(speed) end
        track:Play()
    end)
    return track
end

---------------------------------------------------------
-- WINDOW + TABS
---------------------------------------------------------
local Window = Library:CreateWindow({Name = "RenU V4"})
Notify("RenU V4", "Universal Hub loaded", "✅", 4)

local MainTab = Window:CreateTab({Name = "Main", Emoji = "🏠"})
local CombatTab = Window:CreateTab({Name = "Combat", Emoji = "⚔️"})
local PlayersTab = Window:CreateTab({Name = "Players", Emoji = "👥"})
local TrollTab = Window:CreateTab({Name = "Troll", Emoji = "🎭"})
local VisualsTab = Window:CreateTab({Name = "Visuals", Emoji = "👁️"})
local MiscTab = Window:CreateTab({Name = "Misc", Emoji = "🔧"})
local HelpTab = Window:CreateTab({Name = "Help", Emoji = "❓"})

---------------------------------------------------------
-- MODULE: AIMBOT
---------------------------------------------------------
local Aim = {}
Aim.On = false; Aim.Target = nil; Aim.FOV = 120; Aim.Conn = nil; Aim.Circle = nil
Aim.KeyConn = nil; Aim.AutoLock = true; Aim.Smooth = 0.15; Aim.Predict = 0.12
Aim.Part = "Head"; Aim.ShowFOV = true; Aim.FOVColor = Color3.fromRGB(255,0,0)
Aim.Filled = false; Aim.Thick = 1; Aim.WallCheck = true

function Aim.MakeCircle()
    if Aim.Circle then pcall(function() Aim.Circle:Remove() end) end
    Aim.Circle = Drawing.new("Circle")
    Aim.Circle.Color = Aim.FOVColor
    Aim.Circle.Thickness = Aim.Thick
    Aim.Circle.NumSides = 64
    Aim.Circle.Radius = Aim.FOV
    Aim.Circle.Filled = Aim.Filled
    Aim.Circle.Transparency = 0.7
    Aim.Circle.Visible = Aim.ShowFOV and Aim.On
    Aim.Circle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end

function Aim.Valid(p)
    if not p or p == LocalPlayer then return false end
    if not p.Character or not p.Character.Parent then return false end
    if not p.Character:FindFirstChild(Aim.Part) then return false end
    if not p.Character:FindFirstChild("HumanoidRootPart") then return false end
    local h = p.Character:FindFirstChild("Humanoid")
    if not h or h.Health <= 0 then return false end
    return true
end

function Aim.Closest()
    local best, dist = nil, math.huge
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if Aim.Valid(p) then
            local part = p.Character:FindFirstChild(Aim.Part)
            local sp, on = Camera:WorldToViewportPoint(part.Position)
            if on and sp.Z > 0 then
                local d = (c - Vector2.new(sp.X, sp.Y)).Magnitude
                if d <= Aim.FOV and d < dist then
                    local ok = true
                    if Aim.WallCheck and LocalPlayer.Character then
                        local par = RaycastParams.new()
                        par.FilterType = Enum.RaycastFilterType.Blacklist
                        par.FilterDescendantsInstances = {LocalPlayer.Character}
                        local dir = (part.Position - Camera.CFrame.Position)
                        local r = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, par)
                        if r and not r.Instance:IsDescendantOf(p.Character) then ok = false end
                    end
                    if ok then best = p; dist = d end
                end
            end
        end
    end
    return best
end

function Aim.Lock()
    if not Aim.Target or not Aim.Valid(Aim.Target) then Aim.Target = nil; return end
    local part = Aim.Target.Character:FindFirstChild(Aim.Part)
    local sp, on = Camera:WorldToViewportPoint(part.Position)
    if not on or sp.Z <= 0 then Aim.Target = nil; return end

    local vel = Vector3.zero
    local hrp = Aim.Target.Character:FindFirstChild("HumanoidRootPart")
    if hrp then vel = hrp.AssemblyLinearVelocity or Vector3.zero end
    local predicted = part.Position + vel * ((part.Position - Camera.CFrame.Position).Magnitude / 1000) * Aim.Predict
    local tcf = CFrame.lookAt(Camera.CFrame.Position, predicted)

    local sd = (Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) - Vector2.new(sp.X, sp.Y)).Magnitude
    local s = Aim.Smooth * math.clamp(sd / Aim.FOV, 0.3, 1.2)
    Camera.CFrame = Camera.CFrame:Lerp(tcf, s)
    if sd < 5 then Camera.CFrame = tcf end
end

function Aim.Enable()
    if Aim.On then return end
    Aim.On = true; Aim.MakeCircle()
    Aim.Conn = RunService.RenderStepped:Connect(function()
        if Aim.Circle then
            Aim.Circle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            Aim.Circle.Radius = Aim.FOV; Aim.Circle.Color = Aim.FOVColor
            Aim.Circle.Filled = Aim.Filled; Aim.Circle.Thickness = Aim.Thick
            Aim.Circle.Visible = Aim.ShowFOV and Aim.On
        end
        if Aim.AutoLock then
            if not Aim.Target or not Aim.Valid(Aim.Target) then
                Aim.Target = Aim.Closest()
            else
                local part = Aim.Target.Character:FindFirstChild(Aim.Part)
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) - Vector2.new(sp.X, sp.Y)).Magnitude
                    if d > Aim.FOV * 1.1 then Aim.Target = Aim.Closest() end
                else Aim.Target = Aim.Closest() end
            end
        end
        if Aim.Target then Aim.Lock() end
    end)
    Aim.KeyConn = SafeConnect(UserInputService.InputBegan, function(i, g)
        if g or not KeybindsEnabled then return end
        if i.KeyCode == Enum.KeyCode.X then
            if Aim.Target then
                Aim.Target = nil; Aim.AutoLock = false
                Notify("Aimbot", "Unlocked (3s)", "🎯", 2)
                task.delay(3, function() Aim.AutoLock = true end)
            else
                local t = Aim.Closest()
                if t then Aim.Target = t; Notify("Aimbot", "Locked: "..t.Name, "🎯", 2)
                else Notify("Aimbot", "No targets", "🎯", 1) end
            end
        end
    end)
    Notify("Aimbot", "ON | X = lock", "🎯", 2)
end

function Aim.Disable()
    if not Aim.On then return end
    Aim.On = false; Aim.Target = nil; Aim.AutoLock = true
    if Aim.Conn then Aim.Conn:Disconnect(); Aim.Conn = nil end
    if Aim.KeyConn then Aim.KeyConn:Disconnect(); Aim.KeyConn = nil end
    if Aim.Circle then pcall(function() Aim.Circle:Remove() end); Aim.Circle = nil end
end

---------------------------------------------------------
-- MODULE: ESP (FIXED TOGGLES)
---------------------------------------------------------
local ESP = {}
ESP.On = false; ESP.Obj = {}; ESP.Conns = {}
ESP.ShowHP = true; ESP.ShowDist = true; ESP.ShowName = true

function ESP.Create(player)
    if player == LocalPlayer then return end
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    ESP.Remove(player)

    local char = player.Character
    local hrp = char.HumanoidRootPart
    local head = char:FindFirstChild("Head")

    local hl = Instance.new("Highlight")
    hl.Parent = char; hl.FillColor = Color3.fromRGB(255,50,50)
    hl.OutlineColor = Color3.fromRGB(255,255,255); hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local bb = Instance.new("BillboardGui")
    bb.Parent = head or hrp; bb.Size = UDim2.new(0,100,0,70)
    bb.StudsOffset = Vector3.new(0,4,0); bb.AlwaysOnTop = true; bb.LightInfluence = 0

    local fr = Instance.new("Frame"); fr.Parent = bb; fr.Size = UDim2.new(1,0,1,0)
    fr.BackgroundColor3 = Color3.fromRGB(0,0,0); fr.BackgroundTransparency = 0.8; fr.BorderSizePixel = 0
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0,4)

    local nm = Instance.new("TextLabel"); nm.Parent = fr
    nm.Size = UDim2.new(1,0,0.35,0); nm.BackgroundTransparency = 1
    nm.Text = player.Name; nm.TextColor3 = Color3.fromRGB(255,255,255)
    nm.TextStrokeTransparency = 0.3; nm.TextScaled = true; nm.Font = Enum.Font.GothamBold

    local hpBG = Instance.new("Frame"); hpBG.Parent = fr
    hpBG.Size = UDim2.new(0.9,0,0.12,0); hpBG.Position = UDim2.new(0.05,0,0.4,0)
    hpBG.BackgroundColor3 = Color3.fromRGB(50,50,50); hpBG.BorderSizePixel = 0
    Instance.new("UICorner", hpBG).CornerRadius = UDim.new(0,2)

    local hpF = Instance.new("Frame"); hpF.Parent = hpBG
    hpF.Size = UDim2.new(1,0,1,0); hpF.BackgroundColor3 = Color3.fromRGB(0,255,0); hpF.BorderSizePixel = 0
    Instance.new("UICorner", hpF).CornerRadius = UDim.new(0,2)

    local hpL = Instance.new("TextLabel"); hpL.Parent = fr
    hpL.Size = UDim2.new(1,0,0.25,0); hpL.Position = UDim2.new(0,0,0.55,0)
    hpL.BackgroundTransparency = 1; hpL.TextColor3 = Color3.fromRGB(255,255,255)
    hpL.TextStrokeTransparency = 0.3; hpL.TextScaled = true; hpL.Font = Enum.Font.Gotham

    local dL = Instance.new("TextLabel"); dL.Parent = fr
    dL.Size = UDim2.new(1,0,0.2,0); dL.Position = UDim2.new(0,0,0.8,0)
    dL.BackgroundTransparency = 1; dL.TextColor3 = Color3.fromRGB(200,200,200)
    dL.TextStrokeTransparency = 0.3; dL.TextScaled = true; dL.Font = Enum.Font.Gotham

    local hum = char:FindFirstChild("Humanoid")
    local alive = true

    task.spawn(function()
        while alive and ESP.On and ESP.Obj[player] do
            pcall(function()
                -- Name visibility
                nm.Visible = ESP.ShowName

                -- Health visibility
                if ESP.ShowHP and hum then
                    local hp = math.floor(hum.Health)
                    local mx = math.floor(hum.MaxHealth)
                    local pct = mx > 0 and hum.Health/mx or 0
                    hpL.Text = hp.."/"..mx; hpL.Visible = true
                    hpBG.Visible = true; hpF.Visible = true
                    hpF.Size = UDim2.new(pct,0,1,0)
                    hpF.BackgroundColor3 = pct > 0.6 and Color3.fromRGB(0,255,0) or pct > 0.3 and Color3.fromRGB(255,255,0) or Color3.fromRGB(255,0,0)
                    hpL.TextColor3 = hpF.BackgroundColor3
                else
                    hpL.Visible = false; hpBG.Visible = false; hpF.Visible = false
                end

                -- Distance visibility
                if ESP.ShowDist and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    dL.Text = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude).."m"
                    dL.Visible = true
                else
                    dL.Visible = false
                end
            end)
            task.wait(0.4)
        end
    end)

    ESP.Obj[player] = {hl = hl, bb = bb, kill = function() alive = false end}
end

function ESP.Remove(p)
    local o = ESP.Obj[p]
    if o then
        if o.kill then o.kill() end
        pcall(function() o.hl:Destroy() end)
        pcall(function() o.bb:Destroy() end)
        ESP.Obj[p] = nil
    end
end

function ESP.Enable()
    if ESP.On then return end; ESP.On = true
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then task.spawn(function() ESP.Create(p) end) end
    end
    ESP.Conns.add = SafeConnect(Players.PlayerAdded, function(p)
        if not ESP.On or p == LocalPlayer then return end
        ESP.Conns[p.Name.."_ca"] = p.CharacterAdded:Connect(function() task.wait(1); if ESP.On then ESP.Create(p) end end)
    end)
    ESP.Conns.rem = SafeConnect(Players.PlayerRemoving, function(p) ESP.Remove(p) end)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            ESP.Conns[p.Name.."_ca"] = p.CharacterAdded:Connect(function() task.wait(1); if ESP.On then ESP.Create(p) end end)
            ESP.Conns[p.Name.."_cr"] = p.CharacterRemoving:Connect(function() ESP.Remove(p) end)
        end
    end
    Notify("ESP", "ON", "👁️", 2)
end

function ESP.Disable()
    if not ESP.On then return end; ESP.On = false
    for p in pairs(ESP.Obj) do ESP.Remove(p) end
    for _, c in pairs(ESP.Conns) do pcall(function() c:Disconnect() end) end
    ESP.Conns = {}
    Notify("ESP", "OFF", "👁️", 2)
end

---------------------------------------------------------
-- MODULE: FLY
---------------------------------------------------------
local Fly = {}
Fly.On = false; Fly.Speed = 50; Fly.Boost = 2; Fly.Conn = nil; Fly.BV = nil; Fly.BAV = nil

function Fly.Start()
    if Fly.On then return end
    local c, h, r = GetCharacter(); if not c then return end
    Fly.On = true; h.PlatformStand = true
    Fly.BV = Instance.new("BodyVelocity"); Fly.BV.MaxForce = Vector3.one * math.huge; Fly.BV.Velocity = Vector3.zero; Fly.BV.Parent = r
    Fly.BAV = Instance.new("BodyAngularVelocity"); Fly.BAV.MaxTorque = Vector3.one * math.huge; Fly.BAV.AngularVelocity = Vector3.zero; Fly.BAV.Parent = r
    Fly.Conn = RunService.RenderStepped:Connect(function()
        local mv = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += Vector3.new(0,0,-1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv += Vector3.new(0,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv += Vector3.new(-1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += Vector3.new(1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv += Vector3.new(0,-1,0) end
        local spd = Fly.Speed; if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then spd *= Fly.Boost end
        Fly.BV.Velocity = mv.Magnitude > 0 and Camera.CFrame:VectorToWorldSpace(mv.Unit) * spd or Vector3.zero
        Fly.BAV.AngularVelocity = Vector3.zero
    end)
end

function Fly.Stop()
    Fly.On = false
    if Fly.BV then Fly.BV:Destroy(); Fly.BV = nil end
    if Fly.BAV then Fly.BAV:Destroy(); Fly.BAV = nil end
    if Fly.Conn then Fly.Conn:Disconnect(); Fly.Conn = nil end
    local _,h = GetCharacter(); if h then h.PlatformStand = false end
end

function Fly.Toggle() if Fly.On then Fly.Stop() else Fly.Start() end end

---------------------------------------------------------
-- MODULE: NOCLIP
---------------------------------------------------------
local Noclip = {On = false, Conn = nil}
function Noclip.Enable()
    if Noclip.On then return end; Noclip.On = true
    Noclip.Conn = RunService.Stepped:Connect(function()
        local c = LocalPlayer.Character; if c then DisableCollision(c) end
    end)
end
function Noclip.Disable()
    if not Noclip.On then return end; Noclip.On = false
    if Noclip.Conn then Noclip.Conn:Disconnect(); Noclip.Conn = nil end
    local c = LocalPlayer.Character; if c then EnableCollision(c)
        local h = c:FindFirstChild("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end
function Noclip.Toggle() if Noclip.On then Noclip.Disable() else Noclip.Enable() end end

---------------------------------------------------------
-- MODULE: INVISIBILITY
---------------------------------------------------------
local Invis = {On = false, Parts = {}, Decals = {}, Clothing = {}, Meshes = {}}
function Invis.Hide()
    if Invis.On then return end; local ch = LocalPlayer.Character; if not ch then return end
    Invis.On = true; Invis.Parts = {}; Invis.Decals = {}; Invis.Clothing = {}; Invis.Meshes = {}
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then Invis.Parts[p] = p.Transparency; p.Transparency = 1 end
        if p:IsA("Decal") or p:IsA("Texture") then Invis.Decals[p] = p.Transparency; p.Transparency = 1 end
        if p:IsA("SurfaceGui") then Invis.Decals[p] = p.Enabled; p.Enabled = false end
        if p:IsA("SpecialMesh") then Invis.Meshes[p] = p.TextureId; p.TextureId = "" end
    end
    for _, i in ipairs(ch:GetChildren()) do
        if i:IsA("Shirt") or i:IsA("Pants") or i:IsA("ShirtGraphic") then
            Invis.Clothing[i] = ch; i.Parent = ReplicatedStorage
        end
    end
    Notify("Invis", "ON", "👻", 2)
end
function Invis.Show()
    if not Invis.On then return end; Invis.On = false
    for p, v in pairs(Invis.Parts) do if p and p.Parent then p.Transparency = v end end
    for d, v in pairs(Invis.Decals) do if d and d.Parent then
        if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = v
        elseif d:IsA("SurfaceGui") then d.Enabled = v end
    end end
    for m, v in pairs(Invis.Meshes) do if m and m.Parent then m.TextureId = v end end
    for c, p in pairs(Invis.Clothing) do pcall(function() c.Parent = p end) end
    Invis.Parts = {}; Invis.Decals = {}; Invis.Clothing = {}; Invis.Meshes = {}
    Notify("Invis", "OFF", "👻", 2)
end

---------------------------------------------------------
-- MODULE: UNIFIED PLAYER INTERACTION
-- Modes: Follow, Backpack, Head, Bang, GetBanged,
--        Proposal, Slap, Orbit, Stare, Attach
---------------------------------------------------------
local Interact = {}
Interact.On = false; Interact.Target = nil; Interact.Mode = "Follow"
Interact.Dist = 5; Interact.BangSpeed = 1; Interact.FlingPower = 100
Interact.Conn = nil; Interact.Anim = nil; Interact.BP = nil; Interact.BG = nil
Interact.OrbitAngle = 0

function Interact.CleanupBody()
    if Interact.Conn then Interact.Conn:Disconnect(); Interact.Conn = nil end
    if Interact.Anim then pcall(function() Interact.Anim:Stop() end); Interact.Anim = nil end
    if Interact.BP then Interact.BP:Destroy(); Interact.BP = nil end
    if Interact.BG then Interact.BG:Destroy(); Interact.BG = nil end
    local _, h = GetCharacter()
    if h then h.PlatformStand = false; h.Sit = false end
    local ch = LocalPlayer.Character
    if ch then EnableCollision(ch) end
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

function Interact.Stop()
    if not Interact.On then return end
    Interact.On = false; Interact.Target = nil
    Interact.CleanupBody()
    Notify("Interact", "Stopped", "👥", 2)
end

function Interact.Start(playerName)
    if Interact.On then Interact.Stop() end
    local target = FindPlayer(playerName)
    if not target then Notify("Interact", "Not found: "..playerName, "❌", 2); return end
    if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        Notify("Interact", target.Name.." has no character", "❌", 2); return
    end
    local ch, hum, root = GetCharacter(); if not ch then return end

    Interact.On = true; Interact.Target = target; Interact.OrbitAngle = 0
    local mode = Interact.Mode

    -- FOLLOW: Use MoveTo for natural walking
    if mode == "Follow" then
        Interact.Conn = RunService.Heartbeat:Connect(function()
            if not Interact.On or not Interact.Target then return end
            local tp = Interact.Target
            if not tp.Parent or not tp.Character or not tp.Character:FindFirstChild("HumanoidRootPart") then Interact.Stop(); return end
            local _, h, r = GetCharacter(); if not r then return end
            local tR = tp.Character.HumanoidRootPart
            local tH = tp.Character:FindFirstChild("Humanoid")
            local d = (r.Position - tR.Position).Magnitude
            -- Walk toward follow position
            local behindPos = tR.Position - tR.CFrame.LookVector * Interact.Dist
            if d > Interact.Dist + 0.5 then
                h:MoveTo(behindPos)
            end
            -- Mirror jumping
            if tH and tH.Jump then h.Jump = true end
        end)

    -- ORBIT: Circle around target
    elseif mode == "Orbit" then
        Interact.Conn = RunService.Heartbeat:Connect(function(dt)
            if not Interact.On or not Interact.Target then return end
            local tp = Interact.Target
            if not tp.Parent or not tp.Character or not tp.Character:FindFirstChild("HumanoidRootPart") then Interact.Stop(); return end
            local _, h, r = GetCharacter(); if not r then return end
            local tR = tp.Character.HumanoidRootPart
            Interact.OrbitAngle = Interact.OrbitAngle + dt * 2
            local ox = math.cos(Interact.OrbitAngle) * Interact.Dist
            local oz = math.sin(Interact.OrbitAngle) * Interact.Dist
            local pos = tR.Position + Vector3.new(ox, 2, oz)
            r.CFrame = CFrame.new(pos, tR.Position)
        end)

    -- STARE: Face target always, don't move
    elseif mode == "Stare" then
        Interact.BG = Instance.new("BodyGyro")
        Interact.BG.MaxTorque = Vector3.one * math.huge
        Interact.BG.P = 30000; Interact.BG.Parent = root
        Interact.Conn = RunService.Heartbeat:Connect(function()
            if not Interact.On or not Interact.Target then return end
            local tp = Interact.Target
            if not tp.Parent or not tp.Character or not tp.Character:FindFirstChild("HumanoidRootPart") then Interact.Stop(); return end
            local _, _, r = GetCharacter(); if not r then return end
            Interact.BG.CFrame = CFrame.new(r.Position, tp.Character.HumanoidRootPart.Position)
        end)

    -- ATTACH: Ride inside target exactly
    elseif mode == "Attach" then
        DisableCollision(ch)
        Interact.Conn = RunService.Heartbeat:Connect(function()
            if not Interact.On or not Interact.Target then return end
            local tp = Interact.Target
            if not tp.Parent or not tp.Character or not tp.Character:FindFirstChild("HumanoidRootPart") then Interact.Stop(); return end
            local _, _, r = GetCharacter(); if not r then return end
            r.CFrame = tp.Character.HumanoidRootPart.CFrame
            DisableCollision(LocalPlayer.Character)
        end)

    -- SLAP: Move to target, punch animation, fling them
    elseif mode == "Slap" then
        DisableCollision(ch); hum.PlatformStand = true
        Interact.BP = Instance.new("BodyPosition")
        Interact.BP.MaxForce = Vector3.one * math.huge; Interact.BP.P = 50000; Interact.BP.D = 1000
        Interact.BP.Parent = root
        Interact.BG = Instance.new("BodyGyro")
        Interact.BG.MaxTorque = Vector3.one * math.huge; Interact.BG.P = 50000; Interact.BG.Parent = root
        -- Play punch animation
        Interact.Anim = PlayAnim(hum, 891636393, true, 2)
        -- Create BodyAngularVelocity for fling effect
        local bav = Instance.new("BodyAngularVelocity")
        bav.MaxTorque = Vector3.one * math.huge
        bav.AngularVelocity = Vector3.new(0, Interact.FlingPower, 0)
        bav.Parent = root

        Interact.Conn = RunService.Heartbeat:Connect(function()
            if not Interact.On or not Interact.Target then return end
            local tp = Interact.Target
            if not tp.Parent or not tp.Character or not tp.Character:FindFirstChild("HumanoidRootPart") then Interact.Stop(); return end
            local _, _, r = GetCharacter(); if not r then return end
            local tR = tp.Character.HumanoidRootPart
            Interact.BP.Position = tR.Position + tR.CFrame.RightVector * 1.5
            Interact.BG.CFrame = CFrame.new(r.Position, tR.Position)
            bav.AngularVelocity = Vector3.new(0, Interact.FlingPower, 0)
            DisableCollision(LocalPlayer.Character)
        end)

    -- MODES WITH BODY POSITION (Backpack, Head, Bang, GetBanged, Proposal)
    else
        DisableCollision(ch); hum.PlatformStand = true

        Interact.BP = Instance.new("BodyPosition")
        Interact.BP.MaxForce = Vector3.one * math.huge; Interact.BP.P = 30000; Interact.BP.D = 1000
        Interact.BP.Parent = root

        Interact.BG = Instance.new("BodyGyro")
        Interact.BG.MaxTorque = Vector3.one * math.huge; Interact.BG.P = 30000
        Interact.BG.Parent = root

        -- Load animations
        if mode == "Bang" or mode == "GetBanged" then
            Interact.Anim = PlayAnim(hum, 148840371, true, Interact.BangSpeed)
        elseif mode == "Proposal" then
            Interact.Anim = PlayAnim(hum, 507770239, true, 0.5) -- wave/offer
        elseif mode == "Backpack" or mode == "Head" then
            -- Sit animation for riding
            Interact.Anim = PlayAnim(hum, 2506281703, true, 1)
        end

        Interact.Conn = RunService.Heartbeat:Connect(function()
            if not Interact.On or not Interact.Target then return end
            local tp = Interact.Target
            if not tp.Parent or not tp.Character or not tp.Character:FindFirstChild("HumanoidRootPart") then Interact.Stop(); return end
            local _, _, r = GetCharacter(); if not r then return end
            local tR = tp.Character.HumanoidRootPart
            local pos, look

            if mode == "Backpack" then
                pos = tR.Position + tR.CFrame.LookVector * -1.5 + Vector3.new(0, 0.3, 0)
                look = CFrame.new(pos, pos + tR.CFrame.LookVector) -- face same direction
            elseif mode == "Head" then
                pos = tR.Position + Vector3.new(0, 3, 0)
                look = CFrame.new(pos, pos + tR.CFrame.LookVector) -- face same direction
            elseif mode == "Bang" then
                -- BEHIND target, face toward target
                pos = tR.Position - tR.CFrame.LookVector * 1.5
                look = CFrame.new(pos, tR.Position)
            elseif mode == "GetBanged" then
                -- IN FRONT of target, face away
                pos = tR.Position + tR.CFrame.LookVector * 1.5
                look = CFrame.new(pos, pos + tR.CFrame.LookVector)
            elseif mode == "Proposal" then
                -- In front, lower, facing target
                pos = tR.Position + tR.CFrame.LookVector * 3 + Vector3.new(0, -1.5, 0)
                look = CFrame.new(pos, tR.Position)
            end

            Interact.BP.Position = pos
            Interact.BG.CFrame = look
            DisableCollision(LocalPlayer.Character)
        end)
    end

    Notify("Interact", mode.." -> "..target.Name, "👥", 3)
end

---------------------------------------------------------
-- MODULE: FLING (self-spin to fling others)
---------------------------------------------------------
local Fling = {On = false, Speed = 100, Conn = nil, BAV = nil}
function Fling.Enable()
    if Fling.On then return end; local _, h, r = GetCharacter(); if not r then return end
    Fling.On = true
    Fling.BAV = Instance.new("BodyAngularVelocity")
    Fling.BAV.MaxTorque = Vector3.one * math.huge
    Fling.BAV.AngularVelocity = Vector3.new(0, Fling.Speed, 0)
    Fling.BAV.Parent = r
    Fling.Conn = RunService.Stepped:Connect(function()
        local ch = LocalPlayer.Character; if ch then DisableCollision(ch) end
        if Fling.BAV then Fling.BAV.AngularVelocity = Vector3.new(0, Fling.Speed, 0) end
    end)
    Notify("Fling", "ON - Touch players to fling them", "🌀", 3)
end
function Fling.Disable()
    if not Fling.On then return end; Fling.On = false
    if Fling.BAV then Fling.BAV:Destroy(); Fling.BAV = nil end
    if Fling.Conn then Fling.Conn:Disconnect(); Fling.Conn = nil end
    local ch = LocalPlayer.Character; if ch then EnableCollision(ch) end
    Notify("Fling", "OFF", "🌀", 2)
end

---------------------------------------------------------
-- MODULE: CLICK TELEPORT
---------------------------------------------------------
local ClickTP = {On = false, Conn = nil}
function ClickTP.Enable()
    if ClickTP.On then return end; ClickTP.On = true
    ClickTP.Conn = Mouse.Button1Down:Connect(function()
        if not ClickTP.On then return end; local _,_,r = GetCharacter()
        if r and Mouse.Hit then r.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0,3,0)) end
    end)
end
function ClickTP.Disable()
    if not ClickTP.On then return end; ClickTP.On = false
    if ClickTP.Conn then ClickTP.Conn:Disconnect(); ClickTP.Conn = nil end
end

---------------------------------------------------------
-- MODULE: INFINITE JUMP
---------------------------------------------------------
local InfJump = {On = false, Conn = nil}
function InfJump.Enable()
    if InfJump.On then return end; InfJump.On = true
    InfJump.Conn = SafeConnect(UserInputService.JumpRequest, function()
        if not InfJump.On then return end; local _,h = GetCharacter()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
function InfJump.Disable()
    if not InfJump.On then return end; InfJump.On = false
    if InfJump.Conn then InfJump.Conn:Disconnect(); InfJump.Conn = nil end
end

---------------------------------------------------------
-- MODULE: ANTI-AFK
---------------------------------------------------------
local AntiAFK = {On = false, Conn = nil}
function AntiAFK.Enable()
    if AntiAFK.On then return end; AntiAFK.On = true
    local vu = game:GetService("VirtualUser")
    AntiAFK.Conn = SafeConnect(LocalPlayer.Idled, function()
        if AntiAFK.On then vu:Button2Down(Vector2.zero, Camera.CFrame); task.wait(1); vu:Button2Up(Vector2.zero, Camera.CFrame) end
    end)
end
function AntiAFK.Disable()
    if not AntiAFK.On then return end; AntiAFK.On = false
    if AntiAFK.Conn then AntiAFK.Conn:Disconnect(); AntiAFK.Conn = nil end
end

---------------------------------------------------------
-- MODULE: FULLBRIGHT
---------------------------------------------------------
local FB = {On = false, A = nil, B = nil, O = nil, F = nil}
function FB.Enable()
    if FB.On then return end; FB.On = true
    FB.A = Lighting.Ambient; FB.B = Lighting.Brightness; FB.O = Lighting.OutdoorAmbient; FB.F = Lighting.FogEnd
    Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 2; Lighting.OutdoorAmbient = Color3.new(1,1,1); Lighting.FogEnd = 1e10
end
function FB.Disable()
    if not FB.On then return end; FB.On = false
    if FB.A then Lighting.Ambient = FB.A end; if FB.B then Lighting.Brightness = FB.B end
    if FB.O then Lighting.OutdoorAmbient = FB.O end; if FB.F then Lighting.FogEnd = FB.F end
end

---------------------------------------------------------
-- MODULE: FREECAM
---------------------------------------------------------
local FC = {On = false, Speed = 50, Conn = nil, Saved = nil}
function FC.Enable()
    if FC.On then return end; local _,_,r = GetCharacter(); if not r then return end
    FC.On = true; FC.Saved = r.CFrame; Camera.CameraType = Enum.CameraType.Scriptable
    FC.Conn = RunService.RenderStepped:Connect(function(dt)
        local mv = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += Vector3.new(0,0,-1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv += Vector3.new(0,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv += Vector3.new(-1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += Vector3.new(1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv += Vector3.new(0,-1,0) end
        local s = FC.Speed; if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then s *= 2 end
        if mv.Magnitude > 0 then Camera.CFrame = Camera.CFrame + Camera.CFrame:VectorToWorldSpace(mv.Unit) * s * dt end
    end)
end
function FC.Disable()
    if not FC.On then return end; FC.On = false
    if FC.Conn then FC.Conn:Disconnect(); FC.Conn = nil end
    Camera.CameraType = Enum.CameraType.Custom
end

---------------------------------------------------------
-- MODULE: AIR SWIM
---------------------------------------------------------
local AirSwim = {On = false, Speed = 30, Conn = nil, BV = nil, Anim = nil}
function AirSwim.Enable()
    if AirSwim.On then return end; local _, h, r = GetCharacter(); if not r then return end
    AirSwim.On = true; h.PlatformStand = true
    AirSwim.Anim = PlayAnim(h, 913402848, true, 1) -- swim animation
    AirSwim.BV = Instance.new("BodyVelocity"); AirSwim.BV.MaxForce = Vector3.one * math.huge
    AirSwim.BV.Velocity = Vector3.zero; AirSwim.BV.Parent = r
    local bav = Instance.new("BodyAngularVelocity"); bav.MaxTorque = Vector3.one * math.huge
    bav.AngularVelocity = Vector3.zero; bav.Parent = r; AirSwim._bav = bav
    AirSwim.Conn = RunService.RenderStepped:Connect(function()
        local mv = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += Vector3.new(0,0,-1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv += Vector3.new(0,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv += Vector3.new(-1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += Vector3.new(1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv += Vector3.new(0,-1,0) end
        AirSwim.BV.Velocity = mv.Magnitude > 0 and Camera.CFrame:VectorToWorldSpace(mv.Unit) * AirSwim.Speed or Vector3.zero
        bav.AngularVelocity = Vector3.zero
    end)
    Notify("Air Swim", "ON - Swim through the air!", "🏊", 3)
end
function AirSwim.Disable()
    if not AirSwim.On then return end; AirSwim.On = false
    if AirSwim.Conn then AirSwim.Conn:Disconnect(); AirSwim.Conn = nil end
    if AirSwim.BV then AirSwim.BV:Destroy(); AirSwim.BV = nil end
    if AirSwim._bav then AirSwim._bav:Destroy(); AirSwim._bav = nil end
    if AirSwim.Anim then pcall(function() AirSwim.Anim:Stop() end); AirSwim.Anim = nil end
    local _,h = GetCharacter(); if h then h.PlatformStand = false end
    Notify("Air Swim", "OFF", "🏊", 2)
end

---------------------------------------------------------
-- MODULE: GLITCH FLICKER
---------------------------------------------------------
local Flicker = {On = false, Conn = nil, Range = 12}
function Flicker.Enable()
    if Flicker.On then return end; Flicker.On = true
    Flicker.Conn = RunService.Heartbeat:Connect(function()
        if not Flicker.On then return end
        local _, _, r = GetCharacter(); if not r then return end
        local orig = r.CFrame
        local rx = (math.random() - 0.5) * Flicker.Range * 2
        local ry = (math.random() - 0.5) * 4
        local rz = (math.random() - 0.5) * Flicker.Range * 2
        r.CFrame = orig * CFrame.new(rx, ry, rz)
        -- Create echo
        pcall(function()
            local echo = Instance.new("Part")
            echo.Size = Vector3.new(2, 5, 1); echo.CFrame = r.CFrame
            echo.Anchored = true; echo.CanCollide = false
            echo.Material = Enum.Material.ForceField
            echo.Color = Color3.fromRGB(math.random(100,255), math.random(0,100), math.random(200,255))
            echo.Transparency = 0.5; echo.Parent = workspace
            task.spawn(function()
                for i = 0.5, 1, 0.05 do echo.Transparency = i; task.wait(0.02) end
                echo:Destroy()
            end)
        end)
        task.wait(0.05)
        if r and r.Parent then r.CFrame = orig end
    end)
    Notify("Flicker", "ON - Glitch phasing!", "⚡", 3)
end
function Flicker.Disable()
    if not Flicker.On then return end; Flicker.On = false
    if Flicker.Conn then Flicker.Conn:Disconnect(); Flicker.Conn = nil end
    Notify("Flicker", "OFF", "⚡", 2)
end

---------------------------------------------------------
-- MODULE: DOPPELGANGER (Clone)
---------------------------------------------------------
local Doppel = {On = false, Clone = nil, Conn = nil}
function Doppel.Enable()
    if Doppel.On then return end; local ch = LocalPlayer.Character; if not ch then return end
    Doppel.On = true
    Doppel.Clone = ch:Clone()
    for _, v in ipairs(Doppel.Clone:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
    end
    local cloneHum = Doppel.Clone:FindFirstChild("Humanoid")
    if cloneHum then cloneHum.DisplayName = LocalPlayer.Name.." (Clone)" end
    Doppel.Clone.Name = "Doppelganger"
    Doppel.Clone.Parent = workspace
    local cloneRoot = Doppel.Clone:FindFirstChild("HumanoidRootPart")
    if cloneRoot then
        cloneRoot.CFrame = ch.HumanoidRootPart.CFrame * CFrame.new(5, 0, 0)
    end
    -- Mirror movements with delay
    local history = {}
    Doppel.Conn = RunService.Heartbeat:Connect(function()
        if not Doppel.On or not Doppel.Clone or not Doppel.Clone.Parent then return end
        local _, _, r = GetCharacter(); if not r then return end
        table.insert(history, r.CFrame)
        if #history > 15 then -- 15 frame delay
            local cr = Doppel.Clone:FindFirstChild("HumanoidRootPart")
            if cr then cr.CFrame = history[1] end
            table.remove(history, 1)
        end
    end)
    Notify("Clone", "ON - Your shadow follows you", "👤", 3)
end
function Doppel.Disable()
    if not Doppel.On then return end; Doppel.On = false
    if Doppel.Conn then Doppel.Conn:Disconnect(); Doppel.Conn = nil end
    if Doppel.Clone then pcall(function() Doppel.Clone:Destroy() end); Doppel.Clone = nil end
    Notify("Clone", "OFF", "👤", 2)
end

---------------------------------------------------------
-- MODULE: DESYNC
---------------------------------------------------------
local Desync = {On = false, Conn = nil}
function Desync.Enable()
    if Desync.On then return end; Desync.On = true
    Desync.Conn = RunService.Stepped:Connect(function()
        if not Desync.On then return end
        local _, _, r = GetCharacter(); if not r then return end
        local saved = r.CFrame
        r.CFrame = CFrame.new(r.Position + Vector3.new(0, 1e6, 0))
        RunService.RenderStepped:Wait()
        if r and r.Parent then r.CFrame = saved end
    end)
    Notify("Desync", "ON - Server pos desynced", "🔀", 3)
end
function Desync.Disable()
    if not Desync.On then return end; Desync.On = false
    if Desync.Conn then Desync.Conn:Disconnect(); Desync.Conn = nil end
    Notify("Desync", "OFF", "🔀", 2)
end

---------------------------------------------------------
-- MODULE: SPIN
---------------------------------------------------------
local Spin = {On = false, Speed = 30, BAV = nil}
function Spin.Enable()
    if Spin.On then return end; local _,_,r = GetCharacter(); if not r then return end
    Spin.On = true
    Spin.BAV = Instance.new("BodyAngularVelocity")
    Spin.BAV.MaxTorque = Vector3.one * math.huge
    Spin.BAV.AngularVelocity = Vector3.new(0, Spin.Speed, 0)
    Spin.BAV.Parent = r
end
function Spin.Disable()
    if not Spin.On then return end; Spin.On = false
    if Spin.BAV then Spin.BAV:Destroy(); Spin.BAV = nil end
end

---------------------------------------------------------
-- MODULE: HEADLESS
---------------------------------------------------------
local Headless = {On = false, Saved = {}}
function Headless.Enable()
    if Headless.On then return end; local ch = LocalPlayer.Character; if not ch then return end
    Headless.On = true; Headless.Saved = {}
    local head = ch:FindFirstChild("Head")
    if head then
        for _, m in ipairs(head:GetChildren()) do
            if m:IsA("SpecialMesh") then
                Headless.Saved.meshScale = m.Scale; m.Scale = Vector3.zero
            end
            if m:IsA("Decal") then
                Headless.Saved[m] = m.Transparency; m.Transparency = 1
            end
        end
        Headless.Saved.headTransp = head.Transparency; head.Transparency = 1
    end
    Notify("Headless", "ON", "💀", 2)
end
function Headless.Disable()
    if not Headless.On then return end; Headless.On = false
    local ch = LocalPlayer.Character; if not ch then return end
    local head = ch:FindFirstChild("Head")
    if head then
        head.Transparency = Headless.Saved.headTransp or 0
        for _, m in ipairs(head:GetChildren()) do
            if m:IsA("SpecialMesh") and Headless.Saved.meshScale then m.Scale = Headless.Saved.meshScale end
            if m:IsA("Decal") and Headless.Saved[m] then m.Transparency = Headless.Saved[m] end
        end
    end
end

---------------------------------------------------------
-- =====================================================
-- UI: MAIN TAB
-- =====================================================
---------------------------------------------------------
local MovSec = MainTab:CreateSection({Name = "Movement", Side = "Left"})

MovSec:CreateToggle({Name = "Fly (E)", Default = false, Flag = "Fly", Callback = function(v) if v then Fly.Start() else Fly.Stop() end end})
MovSec:CreateSlider({Name = "Fly Speed", Min = 10, Max = 300, Default = 50, Flag = "FlySpd", Callback = function(v) Fly.Speed = v end})
MovSec:CreateSlider({Name = "Walk Speed", Min = 5, Max = 150, Default = 16, Flag = "WSpd", Callback = function(v) local _,h = GetCharacter(); if h then h.WalkSpeed = v end end})
MovSec:CreateSlider({Name = "Jump Power", Min = 10, Max = 300, Default = 50, Flag = "JP", Callback = function(v) local _,h = GetCharacter(); if h then h.JumpPower = v end end})
MovSec:CreateSlider({Name = "Gravity", Min = 0, Max = 400, Default = 196, Flag = "Grav", Callback = function(v) workspace.Gravity = v end})
MovSec:CreateToggle({Name = "Noclip (G)", Default = false, Flag = "Noclip", Callback = function(v) if v then Noclip.Enable() else Noclip.Disable() end end})
MovSec:CreateToggle({Name = "Infinite Jump", Default = false, Flag = "InfJ", Callback = function(v) if v then InfJump.Enable() else InfJump.Disable() end end})
MovSec:CreateToggle({Name = "Click Teleport", Default = false, Flag = "CTP", Callback = function(v) if v then ClickTP.Enable() else ClickTP.Disable() end end})

-- TP to player (FIXED - no fling, offset behind target)
local TPSec = MainTab:CreateSection({Name = "Teleport to Player", Side = "Right"})
local selTP = ""
local tpDrop = TPSec:CreateDropdown({Name = "Player", Values = GetPlayerNames(), Flag = "TPP", Callback = function(v) selTP = v end})
TPSec:CreateButton({Name = "Teleport", Callback = function()
    if selTP == "" then Notify("TP", "Select a player", "❌", 2); return end
    local t = Players:FindFirstChild(selTP)
    if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") then
        local _,_,r = GetCharacter(); if not r then return end
        local tR = t.Character.HumanoidRootPart
        -- Teleport BEHIND them to avoid fling from collision
        r.CFrame = tR.CFrame * CFrame.new(0, 0, 4)
        Notify("TP", "Teleported to "..selTP, "✅", 2)
    else Notify("TP", "Player not available", "❌", 2) end
end})
TPSec:CreateButton({Name = "Refresh", Callback = function() tpDrop:Refresh(GetPlayerNames()); Notify("TP", "Refreshed", "🔄", 1) end})

---------------------------------------------------------
-- UI: COMBAT TAB
---------------------------------------------------------
local AimSec = CombatTab:CreateSection({Name = "Aimbot", Side = "Left"})
AimSec:CreateToggle({Name = "Enable Aimbot", Default = false, Flag = "AimOn", Callback = function(v) if v then Aim.Enable() else Aim.Disable() end end})
AimSec:CreateSlider({Name = "FOV Radius", Min = 30, Max = 400, Default = 120, Flag = "FOVRad", Callback = function(v) Aim.FOV = v end})
AimSec:CreateSlider({Name = "Smoothness (1=snap 100=slow)", Min = 1, Max = 100, Default = 15, Flag = "AimSm", Callback = function(v) Aim.Smooth = v/100 end})
AimSec:CreateDropdown({Name = "Aim Part", Values = {"Head","HumanoidRootPart","UpperTorso"}, Default = "Head", Flag = "AimP", Callback = function(v) Aim.Part = v end})
AimSec:CreateToggle({Name = "Wall Check", Default = true, Flag = "WC", Callback = function(v) Aim.WallCheck = v end})

-- FOV Circle with RGB sliders
local FOVSec = CombatTab:CreateSection({Name = "FOV Circle (RGB)", Side = "Right"})
FOVSec:CreateToggle({Name = "Show FOV", Default = true, Flag = "SFOV", Callback = function(v) Aim.ShowFOV = v end})
FOVSec:CreateToggle({Name = "Filled", Default = false, Flag = "FFil", Callback = function(v) Aim.Filled = v end})
FOVSec:CreateSlider({Name = "Thickness", Min = 1, Max = 5, Default = 1, Flag = "FTh", Callback = function(v) Aim.Thick = v end})

local fovR, fovG, fovB = 255, 0, 0
FOVSec:CreateSlider({Name = "Red", Min = 0, Max = 255, Default = 255, Flag = "FR", Callback = function(v) fovR = v; Aim.FOVColor = Color3.fromRGB(fovR, fovG, fovB) end})
FOVSec:CreateSlider({Name = "Green", Min = 0, Max = 255, Default = 0, Flag = "FG", Callback = function(v) fovG = v; Aim.FOVColor = Color3.fromRGB(fovR, fovG, fovB) end})
FOVSec:CreateSlider({Name = "Blue", Min = 0, Max = 255, Default = 0, Flag = "FB", Callback = function(v) fovB = v; Aim.FOVColor = Color3.fromRGB(fovR, fovG, fovB) end})

-- ESP
local ESPSec = CombatTab:CreateSection({Name = "ESP", Side = "Left"})
ESPSec:CreateToggle({Name = "Enable ESP", Default = false, Flag = "ESPOn", Callback = function(v) if v then ESP.Enable() else ESP.Disable() end end})
ESPSec:CreateToggle({Name = "Show Names", Default = true, Flag = "ESPN", Callback = function(v) ESP.ShowName = v end})
ESPSec:CreateToggle({Name = "Show Health", Default = true, Flag = "ESPH", Callback = function(v) ESP.ShowHP = v end})
ESPSec:CreateToggle({Name = "Show Distance", Default = true, Flag = "ESPD", Callback = function(v) ESP.ShowDist = v end})

-- Fling
local FlingSec = CombatTab:CreateSection({Name = "Fling", Side = "Right"})
FlingSec:CreateToggle({Name = "Fling (spin to fling others)", Default = false, Flag = "FlingOn", Callback = function(v) if v then Fling.Enable() else Fling.Disable() end end})
FlingSec:CreateSlider({Name = "Fling Speed", Min = 10, Max = 500, Default = 100, Flag = "FlSpd", Callback = function(v) Fling.Speed = v; if Fling.BAV then Fling.BAV.AngularVelocity = Vector3.new(0,v,0) end end})

---------------------------------------------------------
-- UI: PLAYERS TAB
---------------------------------------------------------
local IntSec = PlayersTab:CreateSection({Name = "Player Interaction", Side = "Left"})

local selInt = ""
local intDrop = IntSec:CreateDropdown({Name = "Target Player", Values = GetPlayerNames(), Flag = "IntP", Callback = function(v) selInt = v end})

IntSec:CreateDropdown({
    Name = "Mode",
    Values = {"Follow", "Backpack", "Head", "Bang", "GetBanged", "Proposal", "Slap", "Orbit", "Stare", "Attach"},
    Default = "Follow", Flag = "IntMode",
    Callback = function(v) Interact.Mode = v end
})

IntSec:CreateSlider({Name = "Follow/Orbit Distance", Min = 1, Max = 20, Default = 5, Flag = "IntDist", Callback = function(v) Interact.Dist = v end})
IntSec:CreateSlider({Name = "Bang Speed", Min = 1, Max = 5, Default = 1, Flag = "BangSpd", Callback = function(v)
    Interact.BangSpeed = v
    if Interact.Anim and (Interact.Mode == "Bang" or Interact.Mode == "GetBanged") then
        pcall(function() Interact.Anim:AdjustSpeed(v) end)
    end
end})
IntSec:CreateSlider({Name = "Slap Fling Power", Min = 10, Max = 500, Default = 100, Flag = "SlapPow", Callback = function(v) Interact.FlingPower = v end})

IntSec:CreateButton({Name = "Start", Callback = function()
    if selInt == "" then Notify("Interact", "Select a player", "❌", 2); return end
    Interact.Start(selInt)
end})
IntSec:CreateButton({Name = "Stop", Callback = function() Interact.Stop() end})
IntSec:CreateButton({Name = "Refresh Players", Callback = function()
    local n = GetPlayerNames(); intDrop:Refresh(n); tpDrop:Refresh(n)
    Notify("Players", "Refreshed", "🔄", 1)
end})

-- Mode descriptions
local DescSec = PlayersTab:CreateSection({Name = "Mode Info", Side = "Right"})
DescSec:CreateLabel("Follow: Walk behind, mimic jumps")
DescSec:CreateLabel("Backpack: Ride on their back")
DescSec:CreateLabel("Head: Sit on their head")
DescSec:CreateLabel("Bang: From behind with animation")
DescSec:CreateLabel("GetBanged: You receive it")
DescSec:CreateLabel("Proposal: Kneel in front, offer ring")
DescSec:CreateLabel("Slap: Punch + fling them")
DescSec:CreateLabel("Orbit: Circle around them")
DescSec:CreateLabel("Stare: Always face them (creepy)")
DescSec:CreateLabel("Attach: Ride inside them")

---------------------------------------------------------
-- UI: TROLL TAB
---------------------------------------------------------
local SwimSec = TrollTab:CreateSection({Name = "Air Swim", Side = "Left"})
SwimSec:CreateToggle({Name = "Air Swim", Default = false, Flag = "ASwim", Callback = function(v) if v then AirSwim.Enable() else AirSwim.Disable() end end})
SwimSec:CreateSlider({Name = "Swim Speed", Min = 10, Max = 150, Default = 30, Flag = "SwSpd", Callback = function(v) AirSwim.Speed = v end})

local FlkSec = TrollTab:CreateSection({Name = "Glitch Flicker", Side = "Left"})
FlkSec:CreateToggle({Name = "Glitch Flicker", Default = false, Flag = "Flk", Callback = function(v) if v then Flicker.Enable() else Flicker.Disable() end end})
FlkSec:CreateSlider({Name = "Flicker Range", Min = 5, Max = 30, Default = 12, Flag = "FlkR", Callback = function(v) Flicker.Range = v end})

local CloneSec = TrollTab:CreateSection({Name = "Doppelganger", Side = "Right"})
CloneSec:CreateToggle({Name = "Spawn Clone", Default = false, Flag = "Clone", Callback = function(v) if v then Doppel.Enable() else Doppel.Disable() end end})
CloneSec:CreateLabel("Clone follows you with a delay")

local DsSec = TrollTab:CreateSection({Name = "Desync", Side = "Right"})
DsSec:CreateToggle({Name = "Desync (experimental)", Default = false, Flag = "Dsync", Callback = function(v) if v then Desync.Enable() else Desync.Disable() end end})
DsSec:CreateLabel("Server sees you somewhere else")

local SpnSec = TrollTab:CreateSection({Name = "Spin / Headless", Side = "Right"})
SpnSec:CreateToggle({Name = "Spin", Default = false, Flag = "Spin", Callback = function(v) if v then Spin.Enable() else Spin.Disable() end end})
SpnSec:CreateSlider({Name = "Spin Speed", Min = 5, Max = 100, Default = 30, Flag = "SpnSpd", Callback = function(v) Spin.Speed = v; if Spin.BAV then Spin.BAV.AngularVelocity = Vector3.new(0,v,0) end end})
SpnSec:CreateToggle({Name = "Headless", Default = false, Flag = "Hdlss", Callback = function(v) if v then Headless.Enable() else Headless.Disable() end end})

---------------------------------------------------------
-- UI: VISUALS TAB
---------------------------------------------------------
local VisSec = VisualsTab:CreateSection({Name = "Character", Side = "Left"})
VisSec:CreateToggle({Name = "Invisibility", Default = false, Flag = "Inv", Callback = function(v) if v then Invis.Hide() else Invis.Show() end end})
VisSec:CreateToggle({Name = "Fullbright", Default = false, Flag = "FBr", Callback = function(v) if v then FB.Enable() else FB.Disable() end end})
VisSec:CreateLabel("Invisibility is client-side only")

local CamSec = VisualsTab:CreateSection({Name = "Camera", Side = "Right"})
CamSec:CreateToggle({Name = "Freecam", Default = false, Flag = "FCam", Callback = function(v) if v then FC.Enable() else FC.Disable() end end})
CamSec:CreateSlider({Name = "Freecam Speed", Min = 10, Max = 200, Default = 50, Flag = "FCSpd", Callback = function(v) FC.Speed = v end})
CamSec:CreateSlider({Name = "Field of View", Min = 30, Max = 120, Default = 70, Flag = "CamFOV", Callback = function(v) Camera.FieldOfView = v end})

---------------------------------------------------------
-- UI: MISC TAB
---------------------------------------------------------
local UtilSec = MiscTab:CreateSection({Name = "Utilities", Side = "Left"})
UtilSec:CreateToggle({Name = "Anti-AFK", Default = false, Flag = "AAFK", Callback = function(v) if v then AntiAFK.Enable() else AntiAFK.Disable() end end})
UtilSec:CreateToggle({Name = "Quick Keybinds (E/G/X)", Default = true, Flag = "KB", Callback = function(v) KeybindsEnabled = v end})

UtilSec:CreateButton({Name = "Rejoin", Callback = function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId) end})
UtilSec:CreateButton({Name = "Server Hop", Callback = function()
    Notify("Hop", "Finding server...", "🔄", 2)
    task.spawn(function()
        pcall(function()
            local d = game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/0?sortOrder=2&excludeFullGames=true&limit=100"))
            for _, s in ipairs(d.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id); return
                end
            end
            Notify("Hop", "No servers", "❌", 2)
        end)
    end)
end})
UtilSec:CreateButton({Name = "Reset Character", Callback = function() local _,h = GetCharacter(); if h then h.Health = 0 end end})

-- Server info
local InfoSec = MiscTab:CreateSection({Name = "Server Info", Side = "Right"})
local infoLbl = InfoSec:CreateLabel("Loading...")
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            local pc = #Players:GetPlayers(); local mx = Players.MaxPlayers
            local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            local fps = math.floor(1/RunService.RenderStepped:Wait())
            infoLbl:SetText("Players: "..pc.."/"..mx.." | Ping: "..ping.."ms | FPS: "..fps)
        end)
    end
end)

-- Tools
local ToolSec = MiscTab:CreateSection({Name = "Tools", Side = "Right"})
ToolSec:CreateButton({Name = "Infinity Yield", Callback = function()
    task.spawn(function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/InfiniteYield-MyOwneUpload/refs/heads/main/infiniteyield.lua"))() end) end)
end})
ToolSec:CreateButton({Name = "Dark Dex", Callback = function()
    task.spawn(function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/xsakyx/DarkDex-MyOwnUpload/refs/heads/main/Dex.lua"))() end) end)
end})

-- Script control
local CtrlSec = MiscTab:CreateSection({Name = "Script Control", Side = "Right"})
CtrlSec:CreateButton({Name = "Disable All", Callback = function()
    pcall(function() Aim.Disable() end); pcall(function() ESP.Disable() end)
    pcall(function() Fly.Stop() end); pcall(function() Noclip.Disable() end)
    pcall(function() Invis.Show() end); pcall(function() Interact.Stop() end)
    pcall(function() Fling.Disable() end); pcall(function() ClickTP.Disable() end)
    pcall(function() InfJump.Disable() end); pcall(function() AntiAFK.Disable() end)
    pcall(function() FB.Disable() end); pcall(function() FC.Disable() end)
    pcall(function() AirSwim.Disable() end); pcall(function() Flicker.Disable() end)
    pcall(function() Doppel.Disable() end); pcall(function() Desync.Disable() end)
    pcall(function() Spin.Disable() end); pcall(function() Headless.Disable() end)
    pcall(function() Camera.FieldOfView = 70; workspace.Gravity = 196.2 end)
    local _,h = GetCharacter(); if h then h.WalkSpeed = 16; h.JumpPower = 50 end
    Notify("RenU V4", "All disabled", "🛑", 3)
end})
CtrlSec:CreateButton({Name = "Destroy Script", Callback = function()
    pcall(function() Aim.Disable() end); pcall(function() ESP.Disable() end)
    pcall(function() Fly.Stop() end); pcall(function() Noclip.Disable() end)
    pcall(function() Invis.Show() end); pcall(function() Interact.Stop() end)
    pcall(function() Fling.Disable() end); pcall(function() AirSwim.Disable() end)
    pcall(function() Flicker.Disable() end); pcall(function() Doppel.Disable() end)
    pcall(function() Desync.Disable() end); pcall(function() Spin.Disable() end)
    pcall(function() Headless.Disable() end)
    for _, c in pairs(AllConnections) do pcall(function() c:Disconnect() end) end
    Library:Unload()
end})

---------------------------------------------------------
-- UI: HELP TAB
---------------------------------------------------------
local KBSec = HelpTab:CreateSection({Name = "Keybinds", Side = "Left"})
KBSec:CreateLabel("K = Toggle UI")
KBSec:CreateLabel("E = Toggle Fly")
KBSec:CreateLabel("G = Toggle Noclip")
KBSec:CreateLabel("X = Aimbot Lock/Unlock")
KBSec:CreateLabel("Shift = Fly/Swim Boost")
KBSec:CreateLabel("Space/Ctrl = Fly Up/Down")

local FISec = HelpTab:CreateSection({Name = "Features", Side = "Right"})
FISec:CreateLabel("10 interaction modes (Follow to Attach)")
FISec:CreateLabel("Air Swim - fly through air with swim anim")
FISec:CreateLabel("Glitch Flicker - teleport chaos with echoes")
FISec:CreateLabel("Doppelganger - shadow clone follows you")
FISec:CreateLabel("Desync - server/client position mismatch")
FISec:CreateLabel("Fling - spin to fling others on contact")
FISec:CreateLabel("Slap mode - punch animation + fling target")

local CrSec = HelpTab:CreateSection({Name = "Credits", Side = "Right"})
CrSec:CreateLabel("RenU V4.1 | Original: SoLoIsTe_Cry")
CrSec:CreateLabel("Enhanced by Claude | RenLibBeta")

---------------------------------------------------------
-- KEYBIND HANDLER
---------------------------------------------------------
SafeConnect(UserInputService.InputBegan, function(i, g)
    if g or not KeybindsEnabled then return end
    if i.KeyCode == Enum.KeyCode.E then Fly.Toggle()
    elseif i.KeyCode == Enum.KeyCode.G then Noclip.Toggle() end
end)

---------------------------------------------------------
-- AUTO-REFRESH PLAYER LISTS
---------------------------------------------------------
SafeConnect(Players.PlayerAdded, function()
    task.wait(1); pcall(function() local n = GetPlayerNames(); tpDrop:Refresh(n); intDrop:Refresh(n) end)
end)
SafeConnect(Players.PlayerRemoving, function()
    task.wait(0.5); pcall(function() local n = GetPlayerNames(); tpDrop:Refresh(n); intDrop:Refresh(n) end)
end)

print("[RenU V4.1] Loaded successfully")
