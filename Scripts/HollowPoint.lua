-- ╔══════════════════════════════════════════════════════════════════╗
-- ║                    HOLLOW POINT  v6.0                           ║
-- ║               made by xsakyx  •  for RenHub                    ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  [1] Services & Globals      [8]  ESP Manager                   ║
-- ║  [2] Library Load (3-pass)   [9]  Aimbot (sticky-lock, recoil)  ║
-- ║  [3] Config                  [10] Night Vision (100k studs)     ║
-- ║  [4] Team Module             [11] Watch Mode (wall-checked)     ║
-- ║  [5] Utils                   [12] Default Keybinds              ║
-- ║  [6] Keybind Manager         [13] UI                            ║
-- ║  [7] ESP Module              [14] Startup                       ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════════════════════════════
-- [1]  SERVICES & GLOBALS
-- ══════════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════════════
-- [2]  LIBRARY LOAD  (3-pass detection)
-- ══════════════════════════════════════════════════════════════════════
local Library
do
    local ok, ret = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/xsakyx/RobloxUILib/main/RenLib.lua"
        ))()
    end)
    if ok and type(ret) == "table" and type(ret.CreateWindow) == "function" then Library = ret end
    if not Library and type(getgenv) == "function" then
        task.wait(0.05)
        for _, v in pairs(getgenv()) do
            if type(v) == "table" and type(v.CreateWindow) == "function" then Library = v; break end
        end
    end
    if not Library then
        for _, v in pairs(_G) do
            if type(v) == "table" and type(v.CreateWindow) == "function" then Library = v; break end
        end
    end
    assert(Library, "[HollowPoint] UI library not found.")
end

-- ══════════════════════════════════════════════════════════════════════
-- [3]  CONFIG
-- ══════════════════════════════════════════════════════════════════════
local Cfg = {

    ESP = {
        Enabled         = false,
        IgnoreTeammates = false,
        ShowName        = true,
        ShowHealth      = true,
        ShowDistance    = true,
        BoxThickness    = 2,
        TextSize        = 13,
    },

    -- ── Aimbot ─────────────────────────────────────────────────────────
    -- StickyRadius: inside this px zone → hard-snap every RenderStepped frame.
    --   Recoil can't hold because we re-apply the snap every tick.
    -- StickyLockFOVMult: target must go FOVRadius * this from center to break lock.
    Aimbot = {
        Enabled           = false,
        Key               = Enum.KeyCode.Y,
        Target            = "Head",
        Smoothness        = 0.13,   -- lerp alpha; set by UI: 1/sliderValue
        PredStrength      = 0.12,
        StickyRadius      = 30,     -- px — hard-snap zone (fights recoil)
        StickyLockFOVMult = 1.3,    -- how far target must travel to break lock
        FOVRadius         = 120,
        FOVColor          = Color3.fromRGB(255, 255, 255),
        FOVVisible        = true,
        IgnoreTeammates   = true,
        WallCheck         = false,
        Prediction        = true,
    },

    -- ── Night Vision ────────────────────────────────────────────────────
    -- Layer 1: Lighting.Ambient=white + Brightness=8 → full global illumination
    -- Layer 2: PointLight on Head at 100k studs
    NV = {
        Enabled    = false,
        Key        = Enum.KeyCode.U,
        Intensity  = 10,
        Range      = 100000,   -- 100,000 studs
    },

    -- ── Watch Mode ──────────────────────────────────────────────────────
    -- ThreatDot: cos angle threshold (0.85 ≈ 32° cone in front of enemy)
    -- Wall check via Raycast runs ONLY when angle gate passes (cheap-first).
    -- Max 2 new threat objects created per Heartbeat frame.
    Watch = {
        Enabled        = false,
        ArrowEnabled   = true,
        ThreatDot      = 0.85,
        LookRadius     = 100,
        ExpireTime     = 2.5,
        MaxNewPerFrame = 2,
    },
}

-- ══════════════════════════════════════════════════════════════════════
-- [4]  TEAM MODULE
-- Only reads Players[name]:FindFirstChild("HiddenTeam") BrickColorValue.
-- Name text + corners use the SAME TM.GetColor() call → no double-color.
-- ══════════════════════════════════════════════════════════════════════
local TM = {}

local TEAM_PALETTE = {
    ["Bright red"]    = Color3.fromRGB(255, 70,  70 ),
    ["Bright blue"]   = Color3.fromRGB(70,  140, 255),
    ["Bright green"]  = Color3.fromRGB(60,  210,  80),
    ["Bright yellow"] = Color3.fromRGB(245, 215,  40),
}

function TM.GetRaw(p)
    local ok, v = pcall(function()
        local node = Players:FindFirstChild(p.Name)
        if not node then return nil end
        local ht = node:FindFirstChild("HiddenTeam")
        if ht and ht:IsA("BrickColorValue") then return tostring(ht.Value) end
        return nil
    end)
    if ok and v and v ~= "" and v ~= "nil" then return v end
    return nil
end

function TM.IsSameTeam(p)
    local a = TM.GetRaw(LocalPlayer)
    local b = TM.GetRaw(p)
    if not a or not b then return false end
    return a == b
end

function TM.GetColor(p)
    local raw = TM.GetRaw(p)
    if not raw then return Color3.fromRGB(200, 200, 200) end
    if TEAM_PALETTE[raw] then return TEAM_PALETTE[raw] end
    local ok, c = pcall(function() return BrickColor.new(raw).Color end)
    return ok and c or Color3.fromRGB(200, 200, 200)
end

-- ══════════════════════════════════════════════════════════════════════
-- [5]  UTILS
-- ══════════════════════════════════════════════════════════════════════
local U = {}

function U.Char(p)    return workspace:FindFirstChild(p.Name) end
function U.Hum(p)     local c=U.Char(p); return c and c:FindFirstChildOfClass("Humanoid") end
function U.Part(p, n) local c=U.Char(p); return c and c:FindFirstChild(n) end
function U.Root(p)
    local c = U.Char(p); if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
        or c:FindFirstChild("Torso")
        or c:FindFirstChild("Head")
end
function U.Alive(p)
    local h = U.Hum(p)
    if not h or h.Health <= 0 then return false end
    local ok, dead = pcall(function() return h:GetState()==Enum.HumanoidStateType.Dead end)
    return not (ok and dead)
end
function U.Dist(p)
    local a=U.Root(LocalPlayer); local b=U.Root(p)
    if not a or not b then return 0 end
    return math.floor((a.Position-b.Position).Magnitude)
end
function U.W2S(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), sp.Z > 0 and on
end
function U.Targets(ignoreTM)
    local r = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if ignoreTM and TM.IsSameTeam(p) then continue end
        if U.Alive(p) then table.insert(r, p) end
    end
    return r
end

-- Tight 2D bounding box from 8 corners of every body part (R6 + R15 names).
function U.BBox(p)
    local c = U.Char(p); if not c then return nil,nil,false end
    local PARTS = {
        "Head","Torso","UpperTorso","LowerTorso","HumanoidRootPart",
        "Left Arm","Right Arm","Left Leg","Right Leg",
        "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm",
        "LeftHand","RightHand",
        "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg",
        "LeftFoot","RightFoot",
    }
    local mnX,mnY =  math.huge, math.huge
    local mxX,mxY = -math.huge,-math.huge
    local any = false
    for _, n in ipairs(PARTS) do
        local pt = c:FindFirstChild(n)
        if not pt or not pt:IsA("BasePart") then continue end
        local cf, s = pt.CFrame, pt.Size*0.5
        for _, off in ipairs({
            Vector3.new( s.X, s.Y, s.Z),Vector3.new(-s.X, s.Y, s.Z),
            Vector3.new( s.X,-s.Y, s.Z),Vector3.new(-s.X,-s.Y, s.Z),
            Vector3.new( s.X, s.Y,-s.Z),Vector3.new(-s.X, s.Y,-s.Z),
            Vector3.new( s.X,-s.Y,-s.Z),Vector3.new(-s.X,-s.Y,-s.Z),
        }) do
            local sp = Camera:WorldToViewportPoint(cf*off)
            if sp.Z > 0 then
                any = true
                mnX=math.min(mnX,sp.X); mxX=math.max(mxX,sp.X)
                mnY=math.min(mnY,sp.Y); mxY=math.max(mxY,sp.Y)
            end
        end
    end
    if not any then return nil,nil,false end
    return Vector2.new(mnX,mnY), Vector2.new(mxX-mnX, mxY-mnY), true
end

-- ══════════════════════════════════════════════════════════════════════
-- [6]  KEYBIND MANAGER
-- ══════════════════════════════════════════════════════════════════════
local KB = { _m = {} }
UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    local cb = KB._m[i.KeyCode]; if cb then cb() end
end)
function KB.Set(k, cb)  KB._m[k] = cb  end
function KB.Clear(k)    KB._m[k] = nil end
function KB.Rebind(done)
    Library:Notify({ Title="Keybind", Content="Press any key…", Emoji="⌨️", Duration=3 })
    local c; c = UserInputService.InputBegan:Connect(function(i, g)
        if g or i.KeyCode == Enum.KeyCode.Unknown then return end
        c:Disconnect(); done(i.KeyCode)
    end)
end

-- ══════════════════════════════════════════════════════════════════════
-- [7]  ESP MODULE  — 100% Drawing API
--
-- Per-player objects:
--   br[1..8]  corner-bracket box   → team color  (same color as nm)
--   hpBg      HP bar background    → dark square
--   hpFl      HP bar fill          → green→red gradient
--   hpTx      HP text "cur/max"    → grey
--   nm        username             → TEAM COLOR (same as corners)
--   ds        distance             → grey
--
-- Fix for double-color overlap:
--   Both nm.Color and DrawCorners use the SAME TM.GetColor(p) value.
--   There is no separate "team label" row — it was removed since the
--   corners already show the team, and the name already shows it.
-- ══════════════════════════════════════════════════════════════════════
local ESP = { _pool = {} }

local function Drw(kind, props)
    local o = Drawing.new(kind); o.Visible = false
    for k, v in pairs(props) do o[k] = v end
    return o
end

function ESP.Add(p)
    if ESP._pool[p] then return end
    local br = {}
    for i = 1, 8 do
        br[i] = Drw("Line", { Thickness=Cfg.ESP.BoxThickness, Color=Color3.new(1,1,1) })
    end
    ESP._pool[p] = {
        br   = br,
        hpBg = Drw("Square", { Filled=true, Color=Color3.fromRGB(15,15,15) }),
        hpFl = Drw("Square", { Filled=true, Color=Color3.fromRGB(80,230,80) }),
        hpTx = Drw("Text",   { Size=11, Center=false, Outline=true,
                                OutlineColor=Color3.new(0,0,0),
                                Color=Color3.fromRGB(220,220,220),
                                Font=Drawing.Fonts.UI }),
        -- nm.Color is overwritten every frame with teamCol
        nm   = Drw("Text",   { Size=Cfg.ESP.TextSize, Center=true, Outline=true,
                                OutlineColor=Color3.new(0,0,0),
                                Color=Color3.new(1,1,1),
                                Font=Drawing.Fonts.UI }),
        ds   = Drw("Text",   { Size=Cfg.ESP.TextSize-1, Center=true, Outline=true,
                                OutlineColor=Color3.new(0,0,0),
                                Color=Color3.fromRGB(160,160,160),
                                Font=Drawing.Fonts.UI }),
    }
end

function ESP.Remove(p)
    local d = ESP._pool[p]; if not d then return end
    for _, l in ipairs(d.br) do l:Remove() end
    d.hpBg:Remove(); d.hpFl:Remove(); d.hpTx:Remove()
    d.nm:Remove(); d.ds:Remove()
    ESP._pool[p] = nil
end

local function HideESP(d)
    for _, l in ipairs(d.br) do l.Visible=false end
    d.hpBg.Visible=false; d.hpFl.Visible=false; d.hpTx.Visible=false
    d.nm.Visible=false; d.ds.Visible=false
end

function ESP.Clear()
    for p in pairs(ESP._pool) do ESP.Remove(p) end
end

local function DrawCorners(br, bx, by, bw, bh, col, th)
    local lx, ly = bw*0.22, bh*0.22
    br[1].From=Vector2.new(bx,    by);    br[1].To=Vector2.new(bx+lx,   by)
    br[2].From=Vector2.new(bx,    by);    br[2].To=Vector2.new(bx,      by+ly)
    br[3].From=Vector2.new(bx+bw, by);    br[3].To=Vector2.new(bx+bw-lx,by)
    br[4].From=Vector2.new(bx+bw, by);    br[4].To=Vector2.new(bx+bw,   by+ly)
    br[5].From=Vector2.new(bx,    by+bh); br[5].To=Vector2.new(bx+lx,   by+bh)
    br[6].From=Vector2.new(bx,    by+bh); br[6].To=Vector2.new(bx,      by+bh-ly)
    br[7].From=Vector2.new(bx+bw, by+bh); br[7].To=Vector2.new(bx+bw-lx,by+bh)
    br[8].From=Vector2.new(bx+bw, by+bh); br[8].To=Vector2.new(bx+bw,   by+bh-ly)
    for _, l in ipairs(br) do l.Color=col; l.Thickness=th; l.Visible=true end
end

function ESP.Update(p)
    local d = ESP._pool[p]; if not d then return end
    local hum       = U.Hum(p)
    local tl,sz,on  = U.BBox(p)
    if not on or not tl then HideESP(d); return end

    local bx,by = tl.X,tl.Y; local bw,bh = sz.X,sz.Y; local cx = bx+bw*0.5
    -- Single TM.GetColor call used for BOTH corners and name — prevents overlap
    local teamCol   = TM.GetColor(p)

    -- Corner brackets (team color)
    DrawCorners(d.br, bx, by, bw, bh, teamCol, Cfg.ESP.BoxThickness)

    -- HP bar (left of box, vertical)
    local hpOn = Cfg.ESP.ShowHealth and hum ~= nil
    d.hpBg.Visible=hpOn; d.hpFl.Visible=hpOn; d.hpTx.Visible=hpOn
    if hpOn then
        local mx    = math.max(hum.MaxHealth,1)
        local cur   = math.clamp(hum.Health,0,mx)
        local ratio = cur/mx
        local BW=4; local BX=bx-BW-4; local fillH=math.max(bh*ratio,1)
        d.hpBg.Size=Vector2.new(BW,bh);    d.hpBg.Position=Vector2.new(BX,by)
        d.hpFl.Size=Vector2.new(BW,fillH); d.hpFl.Position=Vector2.new(BX,by+bh-fillH)
        d.hpFl.Color = Color3.fromRGB(
            math.floor((1-ratio)*255),
            math.floor(ratio*200+55),
            40
        )
        d.hpTx.Text     = string.format("%d/%d",math.floor(cur),math.floor(mx))
        d.hpTx.Size     = math.max(Cfg.ESP.TextSize-2, 9)
        d.hpTx.Position = Vector2.new(BX-1, by+bh*0.5-5)
    end

    -- Username — TEAM COLOR (same as corner brackets, no overlap/conflict)
    d.nm.Visible = Cfg.ESP.ShowName
    if Cfg.ESP.ShowName then
        d.nm.Text     = p.Name
        d.nm.Size     = Cfg.ESP.TextSize
        d.nm.Color    = teamCol          -- red name for red team, blue for blue
        d.nm.Position = Vector2.new(cx, by - Cfg.ESP.TextSize - 2)
    end

    -- Distance (below box, grey)
    d.ds.Visible = Cfg.ESP.ShowDistance
    if Cfg.ESP.ShowDistance then
        d.ds.Text     = string.format("%dm", U.Dist(p))
        d.ds.Size     = Cfg.ESP.TextSize - 1
        d.ds.Position = Vector2.new(cx, by+bh+3)
    end
end

-- ══════════════════════════════════════════════════════════════════════
-- [8]  ESP MANAGER
-- ══════════════════════════════════════════════════════════════════════
local ESPMgr = { _c = nil }
function ESPMgr.Refresh()
    ESP.Clear()
    if not Cfg.ESP.Enabled then return end
    for _, p in ipairs(U.Targets(Cfg.ESP.IgnoreTeammates)) do ESP.Add(p) end
end
function ESPMgr.Start()
    ESPMgr.Stop()
    ESPMgr._c = RunService.Heartbeat:Connect(function()
        if not Cfg.ESP.Enabled then return end
        local live = {}
        for _, p in ipairs(U.Targets(Cfg.ESP.IgnoreTeammates)) do
            live[p]=true; ESP.Add(p); ESP.Update(p)
        end
        for p in pairs(ESP._pool) do
            if not live[p] then ESP.Remove(p) end
        end
    end)
end
function ESPMgr.Stop()
    if ESPMgr._c then ESPMgr._c:Disconnect(); ESPMgr._c=nil end
end

-- ══════════════════════════════════════════════════════════════════════
-- [9]  AIMBOT  — Sticky-lock recoil-resistant design
--
-- PROBLEM with classic lerp-only aimbot:
--   After getting close to target, gun recoil moves camera.
--   Next frame: target is still "close" but lerp applies low factor.
--   Camera drifts off target slightly → miss.
--
-- SOLUTION: StickyRadius zone.
--   When target is within StickyRadius pixels of screen center:
--     → Camera.CFrame = targetCFrame (hard snap, no lerp)
--   Since this runs EVERY RenderStepped (60+ fps), the snap re-applies
--   before the next frame renders. Recoil physically cannot hold because
--   we undo it every single tick. Net drift = zero.
--
--   Target must travel FOVRadius * StickyLockFOVMult from center to
--   break the lock — prevents accidental release from minor movements.
-- ══════════════════════════════════════════════════════════════════════
local Aim = { _conn=nil, _fov=nil, _target=nil }

function Aim.IsValid(p)
    if not p or p == LocalPlayer then return false end
    if not p.Character or not p.Character.Parent then return false end
    local hum = p.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local ok, dead = pcall(function() return hum:GetState()==Enum.HumanoidStateType.Dead end)
    if ok and dead then return false end
    return true
end

-- 4-ray wall check: returns true if ANY ray reaches target unobstructed.
function Aim.WallCheck(part)
    if not Cfg.Aimbot.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType                 = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { U.Char(LocalPlayer) }
    local dirs = {
        (part.Position - Camera.CFrame.Position).Unit,
        (part.Position + Vector3.new( 0.5,0,0) - Camera.CFrame.Position).Unit,
        (part.Position + Vector3.new(-0.5,0,0) - Camera.CFrame.Position).Unit,
        (part.Position + Vector3.new( 0, 0.5,0) - Camera.CFrame.Position).Unit,
    }
    for _, dir in ipairs(dirs) do
        local dist = (part.Position - Camera.CFrame.Position).Magnitude
        local res  = workspace:Raycast(Camera.CFrame.Position, dir*dist, params)
        if not res or res.Instance:IsDescendantOf(part.Parent) then return true end
    end
    return false
end

function Aim.FindTarget()
    local vp     = Camera.ViewportSize
    local center = Vector2.new(vp.X*0.5, vp.Y*0.5)
    local bestP, bestD = nil, math.huge
    for _, p in ipairs(U.Targets(Cfg.Aimbot.IgnoreTeammates)) do
        if not Aim.IsValid(p) then continue end
        local part = U.Part(p, Cfg.Aimbot.Target) or U.Part(p, "HumanoidRootPart")
        if not part then continue end
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on or sp.Z <= 0 then continue end
        local d = (center - Vector2.new(sp.X, sp.Y)).Magnitude
        if d > Cfg.Aimbot.FOVRadius then continue end
        if not Aim.WallCheck(part) then continue end
        if d < bestD then bestD=d; bestP=p end
    end
    return bestP
end

function Aim.LockOn(p)
    if not Aim.IsValid(p) then Aim._target=nil; return end
    local part = U.Part(p, Cfg.Aimbot.Target) or U.Part(p, "HumanoidRootPart")
    if not part then return end
    local sp, on = Camera:WorldToViewportPoint(part.Position)
    if not on or sp.Z <= 0 then Aim._target=nil; return end

    -- Velocity prediction (AssemblyLinearVelocity with .Velocity fallback)
    local predicted = part.Position
    if Cfg.Aimbot.Prediction then
        local hrp = U.Part(p, "HumanoidRootPart")
        if hrp then
            local vel = Vector3.new(0,0,0)
            local ok, v = pcall(function() return hrp.AssemblyLinearVelocity end)
            if ok and v then vel = v
            else
                local ok2, v2 = pcall(function() return hrp.Velocity end)
                if ok2 and v2 then vel = v2 end
            end
            local dist = (part.Position - Camera.CFrame.Position).Magnitude
            predicted  = part.Position + vel*(dist/1000)*Cfg.Aimbot.PredStrength
        end
    end

    local targetCFrame = CFrame.new(Camera.CFrame.Position, predicted)
    local vp           = Camera.ViewportSize
    local center       = Vector2.new(vp.X*0.5, vp.Y*0.5)
    local screenDist   = (center - Vector2.new(sp.X, sp.Y)).Magnitude

    -- ── Sticky zone: hard-snap every frame → recoil physically cannot hold ──
    if screenDist <= Cfg.Aimbot.StickyRadius then
        Camera.CFrame = targetCFrame   -- zero drift guaranteed
    else
        -- Approach zone: adaptive lerp (faster near FOV edge)
        local distMult    = math.clamp(screenDist / Cfg.Aimbot.FOVRadius, 0.3, 1.2)
        local finalSmooth = math.max(Cfg.Aimbot.Smoothness * distMult, 0.10)
        Camera.CFrame     = Camera.CFrame:Lerp(targetCFrame, finalSmooth)
    end
end

function Aim.BuildFOV()
    Aim.RemoveFOV()
    local ok = pcall(function() Drawing.new("Circle"):Remove() end)
    if not ok then return end
    local f = Drawing.new("Circle")
    f.Visible=false; f.Color=Cfg.Aimbot.FOVColor
    f.Radius=Cfg.Aimbot.FOVRadius; f.Thickness=1.5
    f.Filled=false; f.NumSides=64
    Aim._fov = f
end
function Aim.RemoveFOV()
    if Aim._fov then Aim._fov:Remove(); Aim._fov=nil end
end
function Aim.SyncFOV()
    local f = Aim._fov; if not f then return end
    local vp = Camera.ViewportSize
    f.Position = Vector2.new(vp.X*0.5, vp.Y*0.5)
    f.Color    = Cfg.Aimbot.FOVColor
    f.Radius   = Cfg.Aimbot.FOVRadius
    f.Visible  = Cfg.Aimbot.FOVVisible and Cfg.Aimbot.Enabled
end

function Aim.Start()
    Aim.Stop(); Aim.BuildFOV()
    Aim._conn = RunService.RenderStepped:Connect(function()
        Aim.SyncFOV()
        if not Cfg.Aimbot.Enabled then return end
        if Aim._target and not Aim.IsValid(Aim._target) then Aim._target=nil end

        if Aim._target then
            local part = U.Part(Aim._target, Cfg.Aimbot.Target)
                      or U.Part(Aim._target, "HumanoidRootPart")
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    local center  = Vector2.new(Camera.ViewportSize.X*0.5, Camera.ViewportSize.Y*0.5)
                    local d       = (center - Vector2.new(sp.X,sp.Y)).Magnitude
                    local maxDist = Cfg.Aimbot.FOVRadius * Cfg.Aimbot.StickyLockFOVMult
                    if d > maxDist then
                        Aim._target = Aim.FindTarget()
                    else
                        -- Only switch if new target is >30% closer (prevents jitter)
                        local newT = Aim.FindTarget()
                        if newT and newT ~= Aim._target then
                            local nPart = U.Part(newT,Cfg.Aimbot.Target) or U.Part(newT,"HumanoidRootPart")
                            if nPart then
                                local nSp = Camera:WorldToViewportPoint(nPart.Position)
                                local nD  = (center-Vector2.new(nSp.X,nSp.Y)).Magnitude
                                if nD < d*0.7 then Aim._target = newT end
                            end
                        end
                    end
                else
                    Aim._target = nil
                end
            end
        else
            Aim._target = Aim.FindTarget()
        end

        if Aim._target then Aim.LockOn(Aim._target) end
    end)
end
function Aim.Stop()
    if Aim._conn then Aim._conn:Disconnect(); Aim._conn=nil end
    Aim.RemoveFOV()
end
function Aim.Toggle()
    Cfg.Aimbot.Enabled = not Cfg.Aimbot.Enabled
    if Cfg.Aimbot.Enabled then
        Aim.Start()
        Library:Notify({ Title="Aimbot", Content="ON",  Emoji="🎯", Duration=2 })
    else
        Aim.Stop(); Aim.Start()  -- standby: FOV stays visible
        Library:Notify({ Title="Aimbot", Content="OFF", Emoji="🎯", Duration=2 })
    end
end

-- ══════════════════════════════════════════════════════════════════════
-- [10] NIGHT VISION  — 100,000 stud range two-layer illumination
--
-- Why 100k studs?
--   A PointLight's Range is in Roblox studs. 100,000 is effectively
--   infinite for any standard map. Combined with Lighting.Ambient=white
--   (which illuminates the entire world regardless of light range),
--   every player at any distance becomes visible instantly on enable.
--
-- Layer 1 (Lighting globals):
--   Ambient = Color3.new(1,1,1)   → removes all shadow darkness globally
--   Brightness = 8                → amplifies existing light sources
--
-- Layer 2 (Head PointLight):
--   Fills pitch-black areas that global ambient doesn't reach (tunnels etc)
--   Head-mounted (not Camera) → correct position in closed spaces
--
-- Both layers are restored exactly on disable.
-- Re-attach on respawn with max 0.5s poll for Head (usually instant).
-- ══════════════════════════════════════════════════════════════════════
local NV = {
    _light          = nil,
    _respawnConn    = nil,
    _origAmbient    = nil,
    _origBrightness = nil,
}

function NV.AttachLight()
    if NV._light then pcall(function() NV._light:Destroy() end); NV._light=nil end
    local char = LocalPlayer.Character; if not char then return end
    local head = char:FindFirstChild("Head"); if not head then return end
    local pl      = Instance.new("PointLight")
    pl.Name       = "HP_NightVision"
    pl.Brightness = Cfg.NV.Intensity
    pl.Range      = Cfg.NV.Range      -- 100,000 studs
    pl.Shadows    = false
    pl.Color      = Color3.new(1,1,1)
    pl.Parent     = head
    NV._light     = pl
end

function NV.Enable()
    NV.Disable()
    NV._origAmbient    = Lighting.Ambient
    NV._origBrightness = Lighting.Brightness
    -- Full global illumination — makes every player visible at any range
    Lighting.Ambient    = Color3.new(1,1,1)
    Lighting.Brightness = 8
    NV.AttachLight()
    NV._respawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
        if not Cfg.NV.Enabled then return end
        local head = char:FindFirstChild("Head")
        if not head then
            for _ = 1, 10 do
                task.wait(0.05)
                head = char:FindFirstChild("Head")
                if head then break end
            end
        end
        if not head then return end
        if NV._light then pcall(function() NV._light:Destroy() end); NV._light=nil end
        local pl      = Instance.new("PointLight")
        pl.Name       = "HP_NightVision"
        pl.Brightness = Cfg.NV.Intensity
        pl.Range      = Cfg.NV.Range
        pl.Shadows    = false
        pl.Color      = Color3.new(1,1,1)
        pl.Parent     = head
        NV._light     = pl
    end)
    Cfg.NV.Enabled = true
end

function NV.Disable()
    if NV._light       then pcall(function() NV._light:Destroy() end); NV._light=nil end
    if NV._respawnConn then NV._respawnConn:Disconnect(); NV._respawnConn=nil end
    if NV._origAmbient then
        Lighting.Ambient    = NV._origAmbient
        Lighting.Brightness = NV._origBrightness
        NV._origAmbient=nil; NV._origBrightness=nil
    end
    Cfg.NV.Enabled = false
end

function NV.SetIntensity(v)
    Cfg.NV.Intensity = v
    if NV._light then NV._light.Brightness = v end
end
function NV.Toggle()
    if Cfg.NV.Enabled then
        NV.Disable(); Library:Notify({ Title="Night Vision", Content="OFF", Emoji="🌙", Duration=2 })
    else
        NV.Enable();  Library:Notify({ Title="Night Vision", Content="ON",  Emoji="💡", Duration=2 })
    end
end

-- ══════════════════════════════════════════════════════════════════════
-- [11] WATCH MODE  — "Someone is aiming at me" detector
--
-- Detection (per enemy per Heartbeat):
--   Gate 1 (cheap)  — dot product: enemy facing me within ThreatDot cone?
--   Gate 2 (LoS)    — single Raycast enemy→me, both chars blacklisted
--   Both must pass. Max 2 new threat objects per frame (cap).
--
-- Visuals per threat (Drawing API only):
--   vg[1..3]  Edge vignette: colored square layers on screen edge toward threat
--             intensity = number of threats from same quadrant
--   fa[1..3]  FOV arrow: triangle on FOV circle rim, points toward threat
--             (shown while NOT looking at them)
--   ha[1..3]  Head arrow: downward triangle above their head
--             (shown once I look at them — replaces FOV arrow)
--
-- Each threat gets a unique color hashed by p.UserId.
-- Same-quadrant threats compound the vignette glow (more enemies = brighter).
-- Expires after ExpireTime seconds of no aiming, or 2s after being looked at.
-- ══════════════════════════════════════════════════════════════════════
local Watch = { _threats={}, _conn=nil }

local WATCH_COLORS = {
    Color3.fromRGB(255, 50,  50 ),
    Color3.fromRGB(255, 160,  0 ),
    Color3.fromRGB(220, 50,  255),
    Color3.fromRGB( 50, 220, 255),
    Color3.fromRGB(255, 230,  50),
}
local function ThreatColor(p) return WATCH_COLORS[(p.UserId % #WATCH_COLORS)+1] end

local function NewThreat(p)
    local col = ThreatColor(p)
    local vg,fa,ha = {},{},{}
    for i = 1, 3 do
        vg[i]=Drawing.new("Square"); vg[i].Filled=true; vg[i].Color=col; vg[i].Visible=false
        fa[i]=Drawing.new("Line");   fa[i].Thickness=2; fa[i].Color=col; fa[i].Visible=false
        ha[i]=Drawing.new("Line");   ha[i].Thickness=2; ha[i].Color=col; ha[i].Visible=false
    end
    return { player=p, color=col, timer=Cfg.Watch.ExpireTime, aiming=false, lookTimer=0,
             vg=vg, fa=fa, ha=ha }
end
local function DestroyThreat(t)
    for _, o in ipairs(t.vg) do o:Remove() end
    for _, o in ipairs(t.fa) do o:Remove() end
    for _, o in ipairs(t.ha) do o:Remove() end
end
local function HideThreat(t)
    for _, o in ipairs(t.vg) do o.Visible=false end
    for _, o in ipairs(t.fa) do o.Visible=false end
    for _, o in ipairs(t.ha) do o.Visible=false end
end

-- Gate 1 (angle) + Gate 2 (wall check raycast).
-- Cheap dot first — raycast only fires when dot passes.
local function EnemyAimingAtMe(enemy)
    local ec=U.Char(enemy); local lc=U.Char(LocalPlayer)
    if not ec or not lc then return false end
    local ehr=ec:FindFirstChild("HumanoidRootPart")
    local lhr=lc:FindFirstChild("HumanoidRootPart")
    if not ehr or not lhr then return false end
    local toMe = lhr.Position - ehr.Position
    if toMe.Magnitude < 0.1 then return false end
    -- Gate 1: angle (no raycast cost if this fails)
    if ehr.CFrame.LookVector:Dot(toMe.Unit) < Cfg.Watch.ThreatDot then return false end
    -- Gate 2: line-of-sight (only reached if angle gate passed)
    local params = RaycastParams.new()
    params.FilterType                 = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { ec, lc }
    local result = workspace:Raycast(ehr.Position, toMe, params)
    if result then return false end  -- wall between us
    return true
end

local function AngleToEnemy(enemy)
    local ec=U.Char(enemy); local lc=U.Char(LocalPlayer)
    if not ec or not lc then return 0 end
    local ehr=ec:FindFirstChild("HumanoidRootPart")
    local lhr=lc:FindFirstChild("HumanoidRootPart")
    if not ehr or not lhr then return 0 end
    local dir = ehr.Position - lhr.Position
    local sx  =  dir:Dot(Camera.CFrame.RightVector)
    local sy  = -dir:Dot(Camera.CFrame.UpVector)
    return math.atan2(sy, sx)
end

local function ILookAt(enemy)
    local part = U.Part(enemy,"Head") or U.Part(enemy,"HumanoidRootPart")
    if not part then return false end
    local sp, on = U.W2S(part.Position)
    if not on then return false end
    local vp = Camera.ViewportSize
    return (Vector2.new(vp.X*0.5, vp.Y*0.5)-sp).Magnitude < Cfg.Watch.LookRadius
end

local _PI = math.pi
local function AngleQuadrant(a)
    local ab = math.abs(a)
    if   ab >  _PI*0.75 then return "left"
    elseif ab < _PI*0.25 then return "right"
    elseif a  < 0        then return "top"
    else                      return "bottom"
    end
end

local function DrawVignette(t, angle, intensity)
    local vp = Camera.ViewportSize; local W,H = vp.X, vp.Y
    local BASE = 80
    intensity   = math.clamp(intensity, 1, 4)
    local transp = {
        math.clamp(0.22/intensity, 0.05, 0.90),
        math.clamp(0.48/intensity, 0.05, 0.90),
        math.clamp(0.74/intensity, 0.05, 0.90),
    }
    local q = AngleQuadrant(angle)
    for i, sq in ipairs(t.vg) do
        local th = BASE*(4-i)/3.0
        if     q=="left"   then sq.Size=Vector2.new(th,H); sq.Position=Vector2.new(0,   0)
        elseif q=="right"  then sq.Size=Vector2.new(th,H); sq.Position=Vector2.new(W-th,0)
        elseif q=="top"    then sq.Size=Vector2.new(W,th); sq.Position=Vector2.new(0,   0)
        else                    sq.Size=Vector2.new(W,th); sq.Position=Vector2.new(0, H-th)
        end
        sq.Transparency=transp[i]; sq.Color=t.color; sq.Visible=true
    end
end

local function DrawFOVArrow(t, angle)
    if not Cfg.Watch.ArrowEnabled then
        for _, l in ipairs(t.fa) do l.Visible=false end; return
    end
    local vp = Camera.ViewportSize
    local cx,cy = vp.X*0.5, vp.Y*0.5
    local fov   = Cfg.Aimbot.FOVRadius
    local tipX  = cx + math.cos(angle)*fov
    local tipY  = cy + math.sin(angle)*fov
    local tip   = Vector2.new(tipX, tipY)
    local inward = math.atan2(cy-tipY, cx-tipX)
    local WING=11; local SPREAD=math.rad(36)
    local lw = Vector2.new(tipX+math.cos(inward+SPREAD)*WING, tipY+math.sin(inward+SPREAD)*WING)
    local rw = Vector2.new(tipX+math.cos(inward-SPREAD)*WING, tipY+math.sin(inward-SPREAD)*WING)
    t.fa[1].From=tip; t.fa[1].To=lw
    t.fa[2].From=tip; t.fa[2].To=rw
    t.fa[3].From=lw;  t.fa[3].To=rw
    for _, l in ipairs(t.fa) do l.Color=t.color; l.Visible=true end
end

local function DrawHeadArrow(t)
    if not Cfg.Watch.ArrowEnabled then
        for _, l in ipairs(t.ha) do l.Visible=false end; return
    end
    local part = U.Part(t.player,"Head")
    if not part then for _, l in ipairs(t.ha) do l.Visible=false end; return end
    local sp, on = U.W2S(part.Position + Vector3.new(0,2.2,0))
    if not on then for _, l in ipairs(t.ha) do l.Visible=false end; return end
    local tip=Vector2.new(sp.X,    sp.Y-3)
    local lw =Vector2.new(sp.X-10, sp.Y-19)
    local rw =Vector2.new(sp.X+10, sp.Y-19)
    t.ha[1].From=tip; t.ha[1].To=lw
    t.ha[2].From=tip; t.ha[2].To=rw
    t.ha[3].From=lw;  t.ha[3].To=rw
    for _, l in ipairs(t.ha) do l.Color=t.color; l.Visible=true end
end

function Watch.Start()
    Watch.Stop()
    Watch._conn = RunService.Heartbeat:Connect(function(dt)
        if not Cfg.Watch.Enabled then return end
        if not U.Char(LocalPlayer) then return end

        -- Pass 1: scan, register/refresh threats (cap new ones at MaxNewPerFrame)
        local dirCount = { left=0, right=0, top=0, bottom=0 }
        local newCount = 0

        for _, p in ipairs(U.Targets(true)) do
            if EnemyAimingAtMe(p) then
                if not Watch._threats[p] then
                    if newCount >= Cfg.Watch.MaxNewPerFrame then continue end
                    Watch._threats[p] = NewThreat(p)
                    newCount = newCount + 1
                end
                Watch._threats[p].aiming = true
                Watch._threats[p].timer  = Cfg.Watch.ExpireTime
                local q = AngleQuadrant(AngleToEnemy(p))
                dirCount[q] = dirCount[q] + 1
            end
        end

        -- Pass 2: update visuals, expire old threats
        local toRemove = {}
        for p, t in pairs(Watch._threats) do
            if not t.aiming then t.timer = t.timer - dt end
            t.aiming = false

            if t.timer <= 0 then
                table.insert(toRemove, p); DestroyThreat(t)
            elseif ILookAt(p) then
                t.lookTimer = t.lookTimer + dt
                for _, sq in ipairs(t.vg) do sq.Visible=false end
                for _, l  in ipairs(t.fa) do l.Visible=false end
                DrawHeadArrow(t)
                if t.lookTimer >= 2 then t.timer = math.min(t.timer, 0.4) end
            else
                t.lookTimer = 0
                for _, l in ipairs(t.ha) do l.Visible=false end
                local angle     = AngleToEnemy(p)
                local intensity = dirCount[AngleQuadrant(angle)]
                DrawVignette(t, angle, math.max(intensity, 1))
                DrawFOVArrow(t, angle)
            end
        end
        for _, p in ipairs(toRemove) do Watch._threats[p] = nil end
    end)
end

function Watch.Stop()
    if Watch._conn then Watch._conn:Disconnect(); Watch._conn=nil end
    for _, t in pairs(Watch._threats) do DestroyThreat(t) end
    Watch._threats = {}
end

function Watch.Toggle()
    Cfg.Watch.Enabled = not Cfg.Watch.Enabled
    if not Cfg.Watch.Enabled then
        for _, t in pairs(Watch._threats) do HideThreat(t) end
    end
    Library:Notify({ Title="Watch Mode", Content=Cfg.Watch.Enabled and "ON" or "OFF",
                     Emoji="🔴", Duration=2 })
end

-- ══════════════════════════════════════════════════════════════════════
-- [12] DEFAULT KEYBINDS
-- ══════════════════════════════════════════════════════════════════════
KB.Set(Cfg.Aimbot.Key, function() Aim.Toggle() end)
KB.Set(Cfg.NV.Key,     function() NV.Toggle()  end)

-- ══════════════════════════════════════════════════════════════════════
-- [13] UI
-- ══════════════════════════════════════════════════════════════════════
local Win = Library:CreateWindow({ Name = "Hollow Point" })

-- ─── TAB: ESP ────────────────────────────────────────────────────────
local tESP  = Win:CreateTab({ Name="ESP", Emoji="👁️" })
local sEGen = tESP:CreateSection({ Name="General",      Side="Left"  })
local sEInf = tESP:CreateSection({ Name="Info Display", Side="Right" })

sEGen:CreateToggle({ Name="Enable ESP", Default=false, Flag="esp_on",
    Callback=function(v)
        Cfg.ESP.Enabled=v
        if v then ESPMgr.Start() else ESPMgr.Stop(); ESP.Clear() end
    end })
sEGen:CreateToggle({ Name="Ignore Teammates", Default=false, Flag="esp_tm",
    Callback=function(v) Cfg.ESP.IgnoreTeammates=v; ESPMgr.Refresh() end })

sEInf:CreateToggle({ Name="Show Username", Default=true,  Flag="esp_nm",
    Callback=function(v) Cfg.ESP.ShowName=v end })
sEInf:CreateToggle({ Name="Show Health",   Default=true,  Flag="esp_hp",
    Callback=function(v) Cfg.ESP.ShowHealth=v end })
sEInf:CreateToggle({ Name="Show Distance", Default=true,  Flag="esp_ds",
    Callback=function(v) Cfg.ESP.ShowDistance=v end })

-- ─── TAB: AIMBOT ─────────────────────────────────────────────────────
local tAim  = Win:CreateTab({ Name="Aimbot", Emoji="🎯" })
local sASet = tAim:CreateSection({ Name="Settings", Side="Left"  })
local sAFov = tAim:CreateSection({ Name="FOV",      Side="Right" })
local sAKey = tAim:CreateSection({ Name="Keybind",  Side="Right" })

sASet:CreateToggle({ Name="Enable Aimbot", Default=false, Flag="aim_on",
    Callback=function(v)
        Cfg.Aimbot.Enabled=v
        if v then Aim.Start() else Aim.Stop(); Aim.Start() end
    end })
sASet:CreateDropdown({ Name="Aim Target",
    Values={"Head","Torso","HumanoidRootPart","Left Arm","Right Arm","Left Leg","Right Leg"},
    Default="Head", Flag="aim_pt",
    Callback=function(v) Cfg.Aimbot.Target=v end })
sASet:CreateSlider({ Name="Smoothness  (1=Instant | 20=Smooth)",
    Min=1, Max=20, Default=8, Flag="aim_sm",
    Callback=function(v) Cfg.Aimbot.Smoothness = 1/math.max(v,1) end })
sASet:CreateSlider({ Name="Sticky Radius  (px — recoil-lock zone)",
    Min=5, Max=80, Default=30, Flag="aim_sr",
    Callback=function(v) Cfg.Aimbot.StickyRadius=v end })
sASet:CreateToggle({ Name="Target Prediction",  Default=true,  Flag="aim_pr",
    Callback=function(v) Cfg.Aimbot.Prediction=v end })
sASet:CreateToggle({ Name="Ignore Teammates",   Default=true,  Flag="aim_tm",
    Callback=function(v) Cfg.Aimbot.IgnoreTeammates=v end })
sASet:CreateToggle({ Name="Wall Check",         Default=false, Flag="aim_wc",
    Callback=function(v) Cfg.Aimbot.WallCheck=v end })

sAFov:CreateToggle({ Name="Show FOV Circle", Default=true, Flag="aim_fv",
    Callback=function(v)
        Cfg.Aimbot.FOVVisible=v
        if Aim._fov then Aim._fov.Visible = v and Cfg.Aimbot.Enabled end
    end })
sAFov:CreateSlider({ Name="FOV Radius", Min=20, Max=500, Default=120, Flag="aim_fr",
    Callback=function(v)
        Cfg.Aimbot.FOVRadius=v
        if Aim._fov then Aim._fov.Radius=v end
    end })

local aimBtn
aimBtn = sAKey:CreateButton({ Name="Toggle Key: Y",
    Callback=function()
        KB.Rebind(function(k)
            KB.Clear(Cfg.Aimbot.Key); Cfg.Aimbot.Key=k
            KB.Set(k, function() Aim.Toggle() end)
            local n=tostring(k):gsub("Enum%.KeyCode%.","")
            aimBtn:SetText("Toggle Key: "..n)
            Library:Notify({ Title="Aimbot", Content="Bound to "..n, Emoji="⌨️", Duration=2 })
        end)
    end })

-- ─── TAB: NIGHT VISION ───────────────────────────────────────────────
local tNV   = Win:CreateTab({ Name="Night Vision", Emoji="🌙" })
local sNSet = tNV:CreateSection({ Name="Settings", Side="Left"  })
local sNKey = tNV:CreateSection({ Name="Keybind",  Side="Right" })

sNSet:CreateToggle({ Name="Enable Night Vision", Default=false, Flag="nv_on",
    Callback=function(v) if v then NV.Enable() else NV.Disable() end end })
sNSet:CreateSlider({ Name="Head Light Brightness", Min=1, Max=5, Default=1, Flag="nv_br",
    Callback=function(v) NV.SetIntensity(v) end })
-- Range is locked at 100,000 studs (config default).
-- Adjusting it via slider is intentionally omitted — any value below 100k
-- would reduce visibility at range which is the opposite of what's wanted.

local nvBtn
nvBtn = sNKey:CreateButton({ Name="Toggle Key: U",
    Callback=function()
        KB.Rebind(function(k)
            KB.Clear(Cfg.NV.Key); Cfg.NV.Key=k
            KB.Set(k, function() NV.Toggle() end)
            local n=tostring(k):gsub("Enum%.KeyCode%.","")
            nvBtn:SetText("Toggle Key: "..n)
            Library:Notify({ Title="Night Vision", Content="Bound to "..n, Emoji="⌨️", Duration=2 })
        end)
    end })

-- ─── TAB: WATCH MODE ─────────────────────────────────────────────────
local tWatch = Win:CreateTab({ Name="Watch Mode", Emoji="🔴" })
local sWMain = tWatch:CreateSection({ Name="Detection", Side="Left"  })
local sWVis  = tWatch:CreateSection({ Name="Visuals",   Side="Right" })

sWMain:CreateToggle({ Name="Enable Watch Mode", Default=false, Flag="watch_on",
    Callback=function(v)
        Cfg.Watch.Enabled=v
        if v then Watch.Start() else Watch.Stop() end
    end })
sWMain:CreateSlider({ Name="Detection Angle  (higher=wider cone)",
    Min=50, Max=99, Default=85, Flag="watch_dot",
    Callback=function(v) Cfg.Watch.ThreatDot=v/100 end })
sWMain:CreateSlider({ Name="Indicator Duration  (sec)",
    Min=1, Max=6, Default=3, Flag="watch_exp",
    Callback=function(v) Cfg.Watch.ExpireTime=v end })

sWVis:CreateToggle({ Name="Show Arrows", Default=true, Flag="watch_arr",
    Callback=function(v) Cfg.Watch.ArrowEnabled=v end })
sWVis:CreateSlider({ Name="Look Radius  (px from screen center)",
    Min=30, Max=200, Default=100, Flag="watch_lr",
    Callback=function(v) Cfg.Watch.LookRadius=v end })

-- ─── TAB: SETTINGS ───────────────────────────────────────────────────
local tSet  = Win:CreateTab({ Name="Settings", Emoji="⚙️", IsSettings=true })
local sSESP = tSet:CreateSection({ Name="ESP Appearance",  Side="Left"  })
local sSCtl = tSet:CreateSection({ Name="Script Controls", Side="Right" })

sSESP:CreateSlider({ Name="Text Size",     Min=9, Max=20, Default=13, Flag="set_ts",
    Callback=function(v) Cfg.ESP.TextSize=v end })
sSESP:CreateSlider({ Name="Box Thickness", Min=1, Max=4,  Default=2,  Flag="set_bt",
    Callback=function(v) Cfg.ESP.BoxThickness=v end })

sSCtl:CreateButton({ Name="Unload Script",
    Callback=function()
        ESPMgr.Stop(); ESP.Clear()
        Aim.Stop(); NV.Disable(); Watch.Stop()
        Library:Unload()
    end })

-- ══════════════════════════════════════════════════════════════════════
-- [14] STARTUP
-- ══════════════════════════════════════════════════════════════════════
Aim.Start()   -- standby: FOV circle rendered immediately

Library:Notify({
    Title    = "Hollow Point",
    Content  = "v6.0 loaded! Press K to toggle UI.",
    Emoji    = "💀",
    Duration = 4,
})
