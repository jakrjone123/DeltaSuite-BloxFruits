--!strict
--[[
    Delta Suite — Blox Fruits (PvP Silent Aim + 3D X/Y/Z Predictor + Player ESP)
    Compact Obsidian Tactical UI | Multi-Channel MovesetV2 & Classic Skill Hooks
]]

-- ============================================================================
-- 1. SERVICES, STATE & LIFECYCLE
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

local function getEnv(): { [string]: any }
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        return env
    end
    return _G :: any
end

local Env = getEnv()

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.05)
    LocalPlayer = Players.LocalPlayer
end

if type(rawget(Env, "__BFSilentStop")) == "function" then
    pcall(Env.__BFSilentStop)
end

local RUN_REF: any = rawget(_G, "RUN")

local Session = {
    Alive = true,
    Connections = {} :: { RBXScriptConnection },
    TrackedInstances = {} :: { Instance },
    StopCallbacks = {} :: { () -> () },
}

function Session.IsAlive(): boolean
    if not Session.Alive then
        return false
    end
    if RUN_REF and RUN_REF.alive == false then
        return false
    end
    return true
end

function Session.Bind(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
    local wrapped = function(...)
        if not Session.IsAlive() then
            return
        end
        fn(...)
    end
    local conn: RBXScriptConnection
    if RUN_REF and type(RUN_REF.connect) == "function" then
        conn = RUN_REF.connect(signal, wrapped)
    else
        conn = signal:Connect(wrapped)
        table.insert(Session.Connections, conn)
    end
    return conn
end

function Session.Track(inst: Instance): Instance
    if RUN_REF and type(RUN_REF.track) == "function" then
        pcall(RUN_REF.track, inst)
    else
        table.insert(Session.TrackedInstances, inst)
    end
    return inst
end

function Session.OnStop(fn: () -> ())
    if RUN_REF and type(RUN_REF.onStop) == "function" then
        pcall(RUN_REF.onStop, fn)
    end
    table.insert(Session.StopCallbacks, fn)
end

function Session.Stop()
    if not Session.Alive then
        return
    end
    Session.Alive = false
    for i = #Session.StopCallbacks, 1, -1 do
        pcall(Session.StopCallbacks[i])
    end
    table.clear(Session.StopCallbacks)
    for _, conn in ipairs(Session.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Session.Connections)
    for _, inst in ipairs(Session.TrackedInstances) do
        pcall(function() inst:Destroy() end)
    end
    table.clear(Session.TrackedInstances)
    Env.__BFSilentStop = nil
    if RUN_REF and type(RUN_REF.stop) == "function" then
        pcall(RUN_REF.stop)
    end
end

Env.__BFSilentStop = Session.Stop

local function getUiParent(): Instance
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok and typeof(root) == "Instance" then
            return root
        end
    end
    local okCore = pcall(function() return CoreGui.Name end)
    if okCore then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================================
-- 2. CONFIGURATION
-- ============================================================================
export type BindValue = Enum.KeyCode | Enum.UserInputType

local Config = {
    Silent = {
        Enabled = true,
        Key = Enum.KeyCode.Unknown :: BindValue, -- None needed (Always active by default)
        Mode = "Always", -- Always | Hold | Toggle
        SafeInteract = true, -- Yields to NPCs, Fruits, ClickDetectors, Prompts & UI
        ApplySkills = true, -- Fruit / Sword / Melee MovesetV2 & Classic skills
        ApplyGunsM1 = true, -- Gun shots & M1 projectiles
        AutoFaceCast = false, -- Optional yaw snap on skill keys (keep off for free movement)
        TargetPart = "Chest", -- Chest | RootPart | Closest Body (never Head)
        Priority = "Crosshair", -- Crosshair | Closest | Lowest HP
        MaxDistance = 1500,
        UseFOV = false, -- Locks players in view / close combat immediately without needing a key or tight FOV
        FOV = 340,
        ShowFOV = false,
        ShowLeadLine = true,
        StickyLock = true,
        TeamCheck = true, -- Ignores Allies + same-Marine (Pirates vs Pirates remain valid targets)
        IgnoreSafeZone = true,
        HitChance = 100,

        -- Strong 3D X / Y / Z Kinematic Prediction
        Prediction = true,
        AutoPing = true,
        AutoWeaponSpeed = true,
        ProjSpeed = 380, -- studs/sec fallback for fruit/sword/melee skills
        BaseLeadMs = 45, -- extra cast windup lead (ms)
        PredX = 1.15,
        PredY = 1.08,
        PredZ = 1.15,
        GravityCompY = true, -- Air drop / jump parabola + terrain ground clamp
        AccelLead = true, -- Smooth EMA acceleration for dashes/curves
    },
    ESP = {
        Enabled = true,
        Box = "Corner", -- Off | 2D | Corner
        Highlights = false,
        Skeleton = false,
        Tracers = false,
        Arrows = true,
        TeamCheck = false,
        ShowSafeZone = true,
        MaxDistance = 12000,
        NameLevel = true,
        HealthBar = true,
        HealthText = true,
        Distance = true,
        BountyStatus = true, -- Shows Bounty/Honor + [SAFE] / [KEN x/y]
        WeaponFruit = true, -- Shows active Tool / DevilFruit
        EnemyColor = Color3.fromRGB(239, 68, 68),
        AllyColor = Color3.fromRGB(34, 197, 94),
        SafeColor = Color3.fromRGB(56, 189, 248),
        LockedColor = Color3.fromRGB(250, 204, 21),
    },
    Settings = {
        MenuKey = Enum.KeyCode.RightControl :: BindValue,
        FontSize = 13,
        MenuTransparency = 0.08,
    },
}

local ToggleStates: { [string]: boolean } = { Silent = true }
local KeyHoldStates: { [any]: boolean } = {}

local function isBindDown(bind: BindValue): boolean
    if typeof(bind) ~= "EnumItem" or bind == Enum.KeyCode.Unknown then
        return false
    end
    if bind.EnumType == Enum.UserInputType then
        return UserInputService:IsMouseButtonPressed(bind :: Enum.UserInputType) or KeyHoldStates[bind] == true
    end
    return UserInputService:IsKeyDown(bind :: Enum.KeyCode) or KeyHoldStates[bind] == true
end

local function isSilentModeActive(): boolean
    if not Config.Silent.Enabled then
        return false
    end
    local mode = Config.Silent.Mode
    if mode == "Always" then
        return true
    elseif mode == "Toggle" then
        local b = Config.Silent.Key
        if typeof(b) ~= "EnumItem" or b == Enum.KeyCode.Unknown then
            return true
        end
        return ToggleStates.Silent ~= false
    end
    return isBindDown(Config.Silent.Key)
end

-- ============================================================================
-- 3. BLOX FRUITS DATA, TEAM/ALLY CHECK & 3D (X, Y, Z) PREDICTOR
-- ============================================================================
local AllianceUtil: any = nil
local WeaponDataMod: any = nil
pcall(function()
    local au = ReplicatedStorage:FindFirstChild("AllianceUtil")
    if au and au:IsA("ModuleScript") then
        local ok, m = pcall(require, au)
        if ok and type(m) == "table" then AllianceUtil = m end
    end
    local mods = ReplicatedStorage:FindFirstChild("Modules")
    local wd = mods and mods:FindFirstChild("WeaponData")
    if wd and wd:IsA("ModuleScript") then
        local ok, m = pcall(require, wd)
        if ok and type(m) == "table" then WeaponDataMod = m end
    end
end)

local BF = {}

function BF.IsPlayerAlive(player: Player, model: Model?): (boolean, Humanoid?, BasePart?)
    if not player or not player.Parent or not model or not model.Parent or not model:IsDescendantOf(Workspace) then
        return false, nil, nil
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = (model:FindFirstChild("HumanoidRootPart") :: BasePart?)
        or model.PrimaryPart
        or (model:FindFirstChild("UpperTorso") :: BasePart?)
        or (model:FindFirstChild("Torso") :: BasePart?)
        or (model:FindFirstChild("Head") :: BasePart?)
    if not hum or not root or hum.Health <= 0 then
        return false, nil, nil
    end
    local okSt, hState = pcall(function() return hum:GetState() end)
    if okSt and hState == Enum.HumanoidStateType.Dead then
        return false, nil, nil
    end
    local pos = root.Position
    if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
        return false, nil, nil
    end
    return true, hum, root
end

function BF.IsPlayerInSafeZone(player: Player, model: Model?): boolean
    if player:GetAttribute("InSafeZone") == true then
        return true
    end
    if model and model:FindFirstChildOfClass("ForceField") ~= nil then
        return true
    end
    return false
end

function BF.IsAlly(player: Player): boolean
    if player == LocalPlayer then
        return true
    end
    -- In Blox Fruits PvP, Marines cannot attack Marines; Pirates CAN fight non-allied Pirates
    if LocalPlayer.Team and player.Team and LocalPlayer.Team.Name == "Marines" and player.Team.Name == "Marines" then
        return true
    end
    if AllianceUtil and type(AllianceUtil.getIfAllied) == "function" then
        local ok, allied = pcall(AllianceUtil.getIfAllied, LocalPlayer, player)
        if ok and allied == true then
            return true
        end
    end
    return false
end

function BF.GetPlayerMeta(player: Player, model: Model?): (number?, string, number?, number?, string?)
    local lv: number? = nil
    local d = player:FindFirstChild("Data")
    local lvObj = d and d:FindFirstChild("Level")
    if lvObj and lvObj:IsA("ValueBase") then
        lv = tonumber((lvObj :: any).Value)
    end
    local bountyStr = ""
    local ls = player:FindFirstChild("leaderstats")
    local bObj = ls and (ls:FindFirstChild("Bounty/Honor") or ls:FindFirstChild("Bounty") or ls:FindFirstChild("Honor"))
    if bObj and bObj:IsA("ValueBase") then
        local bv = tonumber((bObj :: any).Value) or 0
        if bv >= 1e6 then
            bountyStr = string.format("%.1fM", bv / 1e6)
        elseif bv >= 1e3 then
            bountyStr = string.format("%.0fK", bv / 1e3)
        else
            bountyStr = tostring(math.floor(bv))
        end
    end
    local kenDodges: number? = nil
    local kenMax: number? = nil
    if player:GetAttribute("KenActive") == true or player:GetAttribute("KenDodgesLeft") ~= nil then
        kenDodges = tonumber(player:GetAttribute("KenDodgesLeft"))
        kenMax = tonumber(player:GetAttribute("KenMaxDodges"))
    end
    local tool = model and model:FindFirstChildOfClass("Tool")
    local fruitObj = d and d:FindFirstChild("DevilFruit")
    local heldName = tool and tool.Name or (fruitObj and fruitObj:IsA("ValueBase") and tostring((fruitObj :: any).Value) or nil)
    if heldName == "" then heldName = nil end
    return lv, bountyStr, kenDodges, kenMax, heldName
end

function BF.GetActiveWeaponProjSpeed(): number
    if not Config.Silent.AutoWeaponSpeed then
        return math.clamp(Config.Silent.ProjSpeed, 60, 3000)
    end
    local ch = LocalPlayer.Character
    local tool = ch and ch:FindFirstChildOfClass("Tool")
    if not tool then
        return math.clamp(Config.Silent.ProjSpeed, 60, 3000)
    end
    local wType = tostring(tool:GetAttribute("WeaponType") or tool.ToolTip or "")
    local wName = tostring(tool:GetAttribute("WeaponName") or tool.Name or "")
    if WeaponDataMod then
        local data = WeaponDataMod[wName] or WeaponDataMod[wName:lower():gsub("%s+", "")]
        if type(data) == "table" and data.WeaponType == "Gun" then
            if data.HitType == "Hitscan" then
                return 2400
            end
            local spd = tonumber(data.ProjectileSpeed or data.Speed or data.BulletSpeed)
            if spd and spd > 0 then
                return spd
            end
            if wName:find("Skull") or wName:find("Soul") then
                return 320
            end
        end
    end
    if wType == "Gun" then
        if wName:lower():find("guitar") then return 320 end
        return 1800
    end
    return math.clamp(Config.Silent.ProjSpeed, 60, 3000)
end

-- Per-Player 3D (X, Y, Z) Velocity + Acceleration Tracker (Soru/TP spike-proof)
type MotionSample = {
    LastPos: Vector3,
    SmoothedVel: Vector3,
    PrevVel: Vector3,
    Accel: Vector3,
    LastTime: number,
    LastSoruTick: number,
}
local MotionCache: { [Player]: MotionSample } = {}

local function samplePlayerMotion(player: Player, model: Model, root: BasePart, now: number): MotionSample
    local curPos = root.Position
    local rawAsmVel = root.AssemblyLinearVelocity
    if rawAsmVel.Magnitude > 260 or rawAsmVel.X ~= rawAsmVel.X then
        rawAsmVel = Vector3.zero
    end
    local soruTick = tonumber(model:GetAttribute("LastSoruTick")) or 0
    local rec = MotionCache[player]
    if not rec then
        rec = {
            LastPos = curPos,
            SmoothedVel = rawAsmVel,
            PrevVel = rawAsmVel,
            Accel = Vector3.zero,
            LastTime = now,
            LastSoruTick = soruTick,
        }
        MotionCache[player] = rec
        return rec
    end

    local dt = now - rec.LastTime
    if dt <= 0.001 then
        return rec
    end
    local disp = curPos - rec.LastPos
    -- Reject teleport / Soru / respawn discontinuities
    if disp.Magnitude > 48 or dt > 0.35 or soruTick ~= rec.LastSoruTick then
        rec.LastPos = curPos
        rec.SmoothedVel = rawAsmVel
        rec.PrevVel = rawAsmVel
        rec.Accel = Vector3.zero
        rec.LastTime = now
        rec.LastSoruTick = soruTick
        return rec
    end

    local posVel = disp / dt
    if posVel.Magnitude > 260 then
        posVel = rawAsmVel
    end
    -- Blend AssemblyLinearVelocity with positional delta so CFrame dashes/skills track cleanly
    local blendedVel = (rawAsmVel.Magnitude > 2 and posVel.Magnitude > 2)
        and (rawAsmVel * 0.55 + posVel * 0.45)
        or (posVel.Magnitude > rawAsmVel.Magnitude and posVel or rawAsmVel)

    local velAlpha = math.clamp(dt * 18, 0.25, 0.85)
    local nextVel = rec.SmoothedVel:Lerp(blendedVel, velAlpha)
    local rawAccel = (nextVel - rec.PrevVel) / math.max(dt, 0.016)
    if rawAccel.Magnitude > 190 then
        rawAccel = rawAccel.Unit * 190
    end
    local accAlpha = math.clamp(dt * 10, 0.15, 0.55)

    rec.Accel = rec.Accel:Lerp(rawAccel, accAlpha)
    rec.PrevVel = nextVel
    rec.SmoothedVel = nextVel
    rec.LastPos = curPos
    rec.LastTime = now
    return rec
end

local GroundRayParams = RaycastParams.new()
GroundRayParams.FilterType = Enum.RaycastFilterType.Exclude
GroundRayParams.IgnoreWater = false

function BF.PredictPosition3D(player: Player, model: Model, aimPart: BasePart, origin: Vector3, sample: MotionSample): Vector3
    local basePos = aimPart.Position
    if not Config.Silent.Prediction then
        return basePos
    end

    local vel = sample.SmoothedVel
    local acc = Config.Silent.AccelLead and sample.Accel or Vector3.zero

    local pingSec = 0
    if Config.Silent.AutoPing then
        local okPing, pingMs = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if okPing and type(pingMs) == "number" then
            pingSec = math.clamp(pingMs / 1000, 0.01, 0.45)
        end
    end
    local baseLeadSec = math.clamp(Config.Silent.BaseLeadMs / 1000, 0, 0.4)
    local projSpeed = BF.GetActiveWeaponProjSpeed()

    local sx = math.clamp(Config.Silent.PredX, 0, 2.5)
    local sy = math.clamp(Config.Silent.PredY, 0, 2.5)
    local sz = math.clamp(Config.Silent.PredZ, 0, 2.5)

    local hum = model:FindFirstChildOfClass("Humanoid")
    local airborne = false
    if hum then
        local okSt, hState = pcall(function() return hum:GetState() end)
        if okSt and (hState == Enum.HumanoidStateType.Freefall or hState == Enum.HumanoidStateType.Jumping or hState == Enum.HumanoidStateType.Flying) then
            airborne = true
        end
    end

    local t = pingSec + baseLeadSec + (basePos - origin).Magnitude / math.max(projSpeed, 60)
    local predPos = basePos

    for _ = 1, 4 do
        t = math.clamp(t, 0.01, 1.15)
        local t2 = 0.5 * t * t
        local dx = (vel.X * t + acc.X * t2) * sx
        local dz = (vel.Z * t + acc.Z * t2) * sz
        local dy = vel.Y * t

        if Config.Silent.GravityCompY and airborne then
            local g = Workspace.Gravity * 0.55
            dy = dy - g * t2
        else
            dy = dy + acc.Y * t2 * 0.5
        end
        dy = dy * sy

        predPos = Vector3.new(basePos.X + dx, basePos.Y + dy, basePos.Z + dz)
        t = pingSec + baseLeadSec + (predPos - origin).Magnitude / math.max(projSpeed, 60)
    end

    -- Clamp predicted Y cleanly above terrain/ground below the predicted X/Z column
    if Config.Silent.GravityCompY and predPos.Y < basePos.Y - 1.5 then
        local exclude: { Instance } = { model }
        if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
        local chars = Workspace:FindFirstChild("Characters")
        if chars then table.insert(exclude, chars) end
        GroundRayParams.FilterDescendantsInstances = exclude
        local probeStart = Vector3.new(predPos.X, math.max(basePos.Y, predPos.Y) + 8, predPos.Z)
        local gHit = Workspace:Raycast(probeStart, Vector3.new(0, -140, 0), GroundRayParams)
        if gHit then
            local minY = gHit.Position.Y + 2.4
            if predPos.Y < minY then
                predPos = Vector3.new(predPos.X, minY, predPos.Z)
            end
        end
    end

    if predPos.X ~= predPos.X or predPos.Y ~= predPos.Y or predPos.Z ~= predPos.Z then
        return basePos
    end
    local leadVec = predPos - basePos
    if leadVec.Magnitude > 140 then
        predPos = basePos + leadVec.Unit * 140
    end

    return predPos
end

-- ============================================================================
-- 4. SHARED HOOK STATE & MULTI-CHANNEL SILENT AIM HOOKS
-- ============================================================================
local HookState = rawget(Env, "__BFSilentState")
if type(HookState) ~= "table" then
    HookState = {
        Active = false,
        ApplySkills = true,
        ApplyGuns = true,
        HasCombatTool = false,
        EquippedTool = nil :: Tool?,
        ToolKind = "",
        AllowMouseOverride = false,
        TargetDist = math.huge,
        RSMouseHooked = false,
        PredPos = nil :: Vector3?,
        TargetPart = nil :: BasePart?,
        ShotOrigin = Vector3.zero,
        ScreenPos = Vector2.zero,
        RawMousePos = nil :: Vector3?,
    }
    Env.__BFSilentState = HookState
end
HookState.Active = false
HookState.PredPos = nil
HookState.TargetPart = nil
HookState.HasCombatTool = false
HookState.EquippedTool = nil
HookState.ToolKind = ""
HookState.AllowMouseOverride = false
HookState.TargetDist = math.huge
local MyRunToken = (tonumber(HookState.RunToken) or 0) + 1
HookState.RunToken = MyRunToken

local function isSilentHookReady(isGunRemote: boolean?, forMouse: boolean?): boolean
    if not Session.IsAlive() or not HookState.Active or HookState.PredPos == nil then
        return false
    end
    if HookState.HasCombatTool ~= true then
        return false
    end
    if forMouse and HookState.AllowMouseOverride ~= true then
        return false
    end
    if isGunRemote then
        return HookState.ApplyGuns == true
    end
    return HookState.ApplySkills == true
end

local function getHookHitCFrame(): CFrame?
    local pos = HookState.PredPos
    if not pos then return nil end
    local org = HookState.ShotOrigin
    local dir = pos - org
    if dir.Magnitude > 0.01 then
        return CFrame.lookAt(pos, pos + dir.Unit)
    end
    return CFrame.new(pos)
end

local function isTargetVectorArg(v: Vector3, rawHit: Vector3?, rootPos: Vector3, strictMatch: boolean?): boolean
    if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
        return false
    end
    if rawHit and (v - rawHit).Magnitude <= 95 then
        return true
    end
    if not strictMatch and rawHit then
        local dVec = v - rootPos
        local rVec = rawHit - rootPos
        if dVec.Magnitude >= 8 and rVec.Magnitude >= 8 then
            if dVec.Unit:Dot(rVec.Unit) > 0.65 then
                return true
            end
        end
    end
    return false
end

local function isAimCommECommand(cmd: string): boolean
    local low = string.lower(cmd)
    if low == "tap" or low == "z" or low == "x" or low == "c" or low == "v" then
        return true
    end
    if low:find("mouse", 1, true)
        or low:find("aim", 1, true)
        or low:find("skill", 1, true)
        or low:find("shoot", 1, true)
        or low:find("fire", 1, true)
        or low:find("cast", 1, true)
        or low:find("release", 1, true)
    then
        return true
    end
    return false
end

local function redirectRemoteArgs(selfInst: Instance, method: string, args: { any }, n: number): boolean
    local pred = HookState.PredPos
    if not pred or not HookState.Active or HookState.HasCombatTool ~= true then
        return false
    end
    if not HookState.AllowMouseOverride then
        return false
    end
    local lpChar = LocalPlayer.Character
    if not lpChar then return false end

    local iName = selfInst.Name
    local isNetGun = (iName == "RE/ShootGunEvent" or iName == "RemoteFunctionShoot")
    local eqTool = HookState.EquippedTool
    local isToolRemote = (eqTool ~= nil and eqTool.Parent == lpChar and selfInst:IsDescendantOf(eqTool))
        and (iName == "RemoteEvent" or iName == "LeftClickRemote" or iName == "RemoteFunctionShoot")
    local isCommE = (iName == "CommE")
    if not isNetGun and not isToolRemote and not isCommE then
        return false
    end

    if iName == "LeftClickRemote" then
        if not isSilentHookReady(true, true) then
            return false
        end
        local kind = HookState.ToolKind
        local maxM1Dist = (kind == "Gun" and 1500) or (kind == "Blox Fruit" and 420) or 110
        if (tonumber(HookState.TargetDist) or math.huge) > maxM1Dist then
            return false
        end
    elseif not isSilentHookReady(isNetGun, true) then
        return false
    end

    -- CommE is strictly allowlisted so NPC, Fruit, Buso, Ken, Dash, Dialogue, Interaction events stay untouched
    if isCommE then
        if type(args[1]) == "string" then
            if not isAimCommECommand(args[1]) then
                return false
            end
        elseif typeof(args[1]) ~= "Vector3" and typeof(args[1]) ~= "CFrame" then
            return false
        end
    end

    local lpRoot = lpChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    local rootPos = lpRoot and lpRoot.Position or HookState.ShotOrigin
    local rawHit = HookState.RawMousePos
    local changed = false
    local aimDir = (pred - rootPos)
    local aimUnit = aimDir.Magnitude > 0.01 and aimDir.Unit or Vector3.new(0, 0, -1)
    local strictVec = isCommE

    for i = 1, n do
        local a = args[i]
        if typeof(a) == "Vector3" then
            if isTargetVectorArg(a, rawHit, rootPos, strictVec) then
                args[i] = pred
                changed = true
            elseif (isNetGun or iName == "LeftClickRemote") and math.abs(a.Magnitude - 1) <= 0.02 and rawHit then
                local rawDir = (rawHit - rootPos)
                if rawDir.Magnitude > 0.1 and a:Dot(rawDir.Unit) > 0.5 then
                    args[i] = aimUnit
                    changed = true
                end
            end
        elseif typeof(a) == "CFrame" then
            if rawHit and (a.Position - rawHit).Magnitude <= 95 and (a.Position - rootPos).Magnitude > 14 then
                args[i] = CFrame.lookAt(pred, pred + aimUnit)
                changed = true
            end
        elseif type(a) == "table" and isNetGun then
            -- Hitscan / Gun shot arrays or hit info tables
            for k, tv in pairs(a) do
                if typeof(tv) == "Vector3" and isTargetVectorArg(tv, rawHit, rootPos, false) then
                    a[k] = pred
                    changed = true
                elseif typeof(tv) == "Instance" and HookState.TargetPart and tv:IsDescendantOf(Workspace) and k == "Hit" then
                    a[k] = HookState.TargetPart
                    changed = true
                end
            end
        end
    end
    return changed
end
HookState.RedirectFn = redirectRemoteArgs

local RSMouseTbl: { [string]: any }? = nil
pcall(function()
    local rsMouseMod = ReplicatedStorage:FindFirstChild("Mouse")
    if rsMouseMod and rsMouseMod:IsA("ModuleScript") then
        local t = require(rsMouseMod)
        if type(t) == "table" then RSMouseTbl = t end
    end
end)

local NativeRSMouse: { [string]: any } = {}
local NativeRSMouseHas: { [string]: boolean } = {}
local RSMOUSE_INTERCEPT_KEYS: { [string]: boolean } = {
    Hit = true,
    Target = true,
    Origin = true,
    UnitRay = true,
}

local function clearRSMouseRawKeys()
    if not RSMouseTbl then return end
    for k in pairs(RSMOUSE_INTERCEPT_KEYS) do
        local rv = rawget(RSMouseTbl, k)
        if rv ~= nil then
            NativeRSMouse[k] = rv
            NativeRSMouseHas[k] = true
            rawset(RSMouseTbl, k, nil)
        end
    end
end
clearRSMouseRawKeys()

HookState.ReadyFn = isSilentHookReady
HookState.HitCFrameFn = getHookHitCFrame
HookState.ClearRSMouseFn = clearRSMouseRawKeys
HookState.NativeRSMouse = NativeRSMouse
HookState.NativeRSMouseHas = NativeRSMouseHas
HookState.FromMouseFn = function(ctx: any): any
    if type(ctx) == "table" and not ctx.mouse and type(ctx.aim) == "function" then
        return ctx:aim(HookState.PredPos)
    end
    return HookState.PredPos
end

;(function()
    local hasNewC = (type(newcclosure) == "function")
    local wrapC: (any) -> any = hasNewC and newcclosure or function(fn) return fn end

    -- Restore Global.updateMouseWrapper, WrapMouse & WrapMouse2 if an older version hooked them
    -- (Hooking those ForeignState functions causes WrapMouse:68 "attempt to index nil with 'UserInputState'" on mouse move)
    if type(restorefunction) == "function" then
        pcall(function()
            local gMod = ReplicatedStorage:FindFirstChild("Global")
            if gMod and gMod:IsA("ModuleScript") then
                local gTbl = require(gMod)
                if type(gTbl) == "table" and type(gTbl.updateMouseWrapper) == "function" then
                    if not isfunctionhooked or isfunctionhooked(gTbl.updateMouseWrapper) then
                        pcall(restorefunction, gTbl.updateMouseWrapper)
                    end
                end
            end
            for _, wmName in ipairs({ "WrapMouse", "WrapMouse2" }) do
                local wmMod = ReplicatedStorage:FindFirstChild(wmName)
                if wmMod and wmMod:IsA("ModuleScript") then
                    local wmFn = require(wmMod)
                    if type(wmFn) == "function" and (not isfunctionhooked or isfunctionhooked(wmFn)) then
                        pcall(restorefunction, wmFn)
                    end
                end
            end
        end)
    end

    if (tonumber(rawget(Env, "__BFSilentCoreHookVer")) or 0) >= 4 then
        return
    end
    Env.__BFSilentCoreHookVer = 4
    Env.__BFSilentHooksInstalled = true

    local PlayerMouse: Mouse? = nil
    pcall(function() PlayerMouse = LocalPlayer:GetMouse() end)

    -- 1. ReplicatedStorage.Mouse metatable hook (__index + __newindex virtualized so tools can't bypass via raw write)
    pcall(function()
        local rsMouseMod = ReplicatedStorage:FindFirstChild("Mouse")
        if rsMouseMod and rsMouseMod:IsA("ModuleScript") and getrawmetatable then
            local mTbl = require(rsMouseMod)
            local mt = getrawmetatable(mTbl)
            if mt and type(mt.__index) == "function" then
                if setreadonly then pcall(setreadonly, mt, false) end
                local origIdx = rawget(Env, "__BFOrigRSMouseIdx") or mt.__index
                Env.__BFOrigRSMouseIdx = origIdx
                local origNewIdx = rawget(Env, "__BFOrigRSMouseNewIdx") or mt.__newindex
                if origNewIdx ~= nil then Env.__BFOrigRSMouseNewIdx = origNewIdx end

                mt.__newindex = wrapC(function(self, key, val)
                    if key == "Hit" or key == "Target" or key == "Origin" or key == "UnitRay" then
                        local nat = HookState.NativeRSMouse
                        local natHas = HookState.NativeRSMouseHas
                        if nat and natHas then
                            nat[key] = val
                            natHas[key] = true
                        end
                        return
                    end
                    if type(origNewIdx) == "function" then
                        return origNewIdx(self, key, val)
                    end
                    rawset(self, key, val)
                end)

                mt.__index = wrapC(function(self, key)
                    local readyFn = HookState.ReadyFn
                    if readyFn and readyFn(false, true) then
                        if key == "Hit" then
                            local cfFn = HookState.HitCFrameFn
                            local cf = cfFn and cfFn()
                            if cf then return cf end
                        elseif key == "Target" and HookState.TargetPart and HookState.ToolKind == "Gun" then
                            return HookState.TargetPart
                        elseif key == "Origin" then
                            local p = HookState.PredPos :: Vector3
                            return CFrame.lookAt(HookState.ShotOrigin, p)
                        elseif key == "UnitRay" then
                            local p = HookState.PredPos :: Vector3
                            return Ray.new(HookState.ShotOrigin, (p - HookState.ShotOrigin).Unit)
                        end
                    end
                    if key == "Hit" or key == "Target" or key == "Origin" or key == "UnitRay" then
                        local nat = HookState.NativeRSMouse
                        local natHas = HookState.NativeRSMouseHas
                        if nat and natHas and natHas[key] then
                            return nat[key]
                        end
                    end
                    return origIdx(self, key)
                end)
                HookState.RSMouseHooked = true
            end
        end
    end)

    -- 2. MovesetUtil.Aim.fromMouse hook (reload-safe; calls ctx:aim when ctx.mouse is nil)
    pcall(function()
        local mu = ReplicatedStorage:FindFirstChild("MovesetUtil")
        local aimMod = mu and mu:FindFirstChild("Aim")
        if aimMod and aimMod:IsA("ModuleScript") and hookfunction then
            local aimTbl = require(aimMod)
            if type(aimTbl) == "table" and type(aimTbl.fromMouse) == "function" then
                local origFromMouse
                origFromMouse = hookfunction(aimTbl.fromMouse, wrapC(function(ctx)
                    local readyFn = HookState.ReadyFn
                    if readyFn and readyFn(false, true) and HookState.PredPos then
                        local fmFn = HookState.FromMouseFn
                        if fmFn then
                            return fmFn(ctx)
                        end
                        return HookState.PredPos
                    end
                    return origFromMouse(ctx)
                end))
            end
        end
    end)

    -- 3. Util.GetMousePoint & CombatUtil.GetTargetPosition hooks (reload-safe dynamic dispatch)
    pcall(function()
        local util = ReplicatedStorage:FindFirstChild("Util")
        local gmp = util and util:FindFirstChild("GetMousePoint")
        if gmp and gmp:IsA("ModuleScript") and hookfunction then
            local gmpFn = require(gmp)
            if type(gmpFn) == "function" then
                local origGmp
                origGmp = hookfunction(gmpFn, wrapC(function(...)
                    local readyFn = HookState.ReadyFn
                    if readyFn and readyFn(true, true) and HookState.PredPos then
                        return HookState.PredPos
                    end
                    return origGmp(...)
                end))
            end
        end
        local mods = ReplicatedStorage:FindFirstChild("Modules")
        local cuMod = mods and mods:FindFirstChild("CombatUtil")
        if cuMod and cuMod:IsA("ModuleScript") and hookfunction then
            local cu = require(cuMod)
            if type(cu) == "table" and type(cu.GetTargetPosition) == "function" then
                local origGTP
                origGTP = hookfunction(cu.GetTargetPosition, wrapC(function(...)
                    local readyFn = HookState.ReadyFn
                    if readyFn and readyFn(true, true) and HookState.PredPos then
                        return HookState.PredPos
                    end
                    return origGTP(...)
                end))
            end
        end
    end)

    -- 4. game __index hook (reload-safe dynamic dispatch; only when newcclosure exists)
    pcall(function()
        if hookmetamethod and checkcaller and hasNewC then
            local origGameIndex
            origGameIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
                if not checkcaller() and PlayerMouse and typeof(self) == "Instance" and rawequal(self, PlayerMouse) then
                    local readyFn = HookState.ReadyFn
                    if readyFn and readyFn(false, true) then
                        if key == "Hit" then
                            local cfFn = HookState.HitCFrameFn
                            local cf = cfFn and cfFn()
                            if cf then return cf end
                        elseif key == "Target" and HookState.TargetPart and HookState.ToolKind == "Gun" then
                            return HookState.TargetPart
                        elseif key == "Origin" then
                            local p = HookState.PredPos :: Vector3
                            return CFrame.lookAt(HookState.ShotOrigin, p)
                        elseif key == "UnitRay" then
                            local p = HookState.PredPos :: Vector3
                            return Ray.new(HookState.ShotOrigin, (p - HookState.ShotOrigin).Unit)
                        end
                    end
                end
                return origGameIndex(self, key)
            end))
        end
    end)

    -- 5. game __namecall hook (pre-filters remote name before table.pack; never blocks NPC/Fruit/Interaction)
    pcall(function()
        if hookmetamethod and checkcaller and getnamecallmethod and hasNewC then
            local origNamecall
            origNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                if not checkcaller() and HookState.Active and HookState.PredPos and HookState.HasCombatTool == true and HookState.AllowMouseOverride == true then
                    local method = getnamecallmethod()
                    if method == "FireServer" or method == "InvokeServer" then
                        local rName = self.Name
                        if rName == "RE/ShootGunEvent"
                            or rName == "RemoteFunctionShoot"
                            or rName == "RemoteEvent"
                            or rName == "LeftClickRemote"
                            or rName == "CommE"
                        then
                            local args = table.pack(...)
                            local redir = HookState.RedirectFn or redirectRemoteArgs
                            local okRedir, changed = pcall(redir, self, method, args, args.n)
                            if okRedir and changed then
                                return origNamecall(self, table.unpack(args, 1, args.n))
                            end
                        end
                    end
                end
                return origNamecall(self, ...)
            end))
        end
    end)
end)()

-- ============================================================================
-- 5. PLAYER ESP (LAZY DRAWING POOL + STREAMING SAFE)
-- ============================================================================
local HasDrawing = (type(Drawing) == "table" and type(Drawing.new) == "function")
local DrawingOpaqueIsZero = false
if HasDrawing then
    pcall(function()
        local probe = Drawing.new("Line")
        if probe then
            DrawingOpaqueIsZero = (probe.Transparency < 0.5)
            probe:Remove()
        end
    end)
end

local function drawTrans(op: number): number
    local c = math.clamp(op, 0, 1)
    if DrawingOpaqueIsZero then
        return 1 - c
    end
    return c
end

local function newDraw(kind: string, props: { [string]: any }): any
    if not HasDrawing then return nil end
    local ok, obj = pcall(Drawing.new, kind)
    if not ok or not obj then return nil end
    for k, v in pairs(props) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

local OUTLINE_DARK = Color3.fromRGB(6, 8, 12)
local BONE_PAIRS = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local function computeHealthColor(ratio: number): Color3
    local r = math.clamp(ratio, 0, 1)
    if r >= 0.5 then
        return Color3.fromRGB(math.floor(250 - (r - 0.5) * 2 * 216 + 0.5), math.floor(204 - (r - 0.5) * 2 * 7 + 0.5), math.floor(21 + (r - 0.5) * 2 * 73 + 0.5))
    end
    return Color3.fromRGB(math.floor(239 + (r * 2) * 11 + 0.5), math.floor(68 + (r * 2) * 136 + 0.5), math.floor(68 - (r * 2) * 47 + 0.5))
end

local function createLinePool(n: number, thick: number, col: Color3?, trans: number, z: number): { any }
    local pool = {}
    for i = 1, n do
        pool[i] = newDraw("Line", {
            Thickness = thick,
            Color = col or Color3.new(1, 1, 1),
            Transparency = trans,
            ZIndex = z,
            Visible = false,
        })
    end
    return pool
end

type EspEntry = {
    Player: Player,
    Draw: { [string]: any }?,
    Highlight: Highlight?,
}

local PlayerEsp: { [Player]: EspEntry } = {}

local function createEspDrawings(): { [string]: any }
    return {
        _Cleared = true,
        BoxFill = newDraw("Square", { Thickness = 1, Filled = true, Transparency = drawTrans(0.08), ZIndex = 1, Visible = false }),
        BoxOutline = newDraw("Square", { Thickness = 2.0, Filled = false, Color = OUTLINE_DARK, Transparency = drawTrans(0.65), ZIndex = 2, Visible = false }),
        CornerOutlines = createLinePool(8, 2.0, OUTLINE_DARK, drawTrans(0.65), 2),
        Box = newDraw("Square", { Thickness = 1.0, Filled = false, Transparency = drawTrans(0.98), ZIndex = 3, Visible = false }),
        Corners = createLinePool(8, 1.0, nil, drawTrans(0.98), 3),
        HpBg = newDraw("Square", { Thickness = 1, Filled = true, Color = OUTLINE_DARK, Transparency = drawTrans(0.75), ZIndex = 2, Visible = false }),
        HpFill = newDraw("Square", { Thickness = 1, Filled = true, Transparency = drawTrans(1.0), ZIndex = 3, Visible = false }),
        Tracer = newDraw("Line", { Thickness = 1.0, Transparency = drawTrans(0.65), ZIndex = 1, Visible = false }),
        Name = newDraw("Text", { Center = true, Outline = true, Size = 13, Font = 2, Transparency = drawTrans(1.0), ZIndex = 5, Visible = false }),
        Bottom1 = newDraw("Text", { Center = true, Outline = true, Size = 12, Font = 2, Transparency = drawTrans(1.0), ZIndex = 5, Visible = false }),
        Bottom2 = newDraw("Text", { Center = true, Outline = true, Size = 11, Font = 2, Transparency = drawTrans(1.0), ZIndex = 5, Visible = false }),
        Bottom3 = newDraw("Text", { Center = true, Outline = true, Size = 11, Font = 2, Transparency = drawTrans(1.0), ZIndex = 5, Visible = false }),
        ArrowOutline = newDraw("Triangle", { Filled = true, Color = OUTLINE_DARK, Transparency = drawTrans(0.75), ZIndex = 2, Visible = false }),
        Arrow = newDraw("Triangle", { Filled = true, Transparency = drawTrans(1.0), ZIndex = 3, Visible = false }),
    }
end

local function hideEspDrawings(d: { [string]: any }?, hl: Highlight?, keepArrow: boolean?)
    if not d then
        if hl and not keepArrow then hl.Enabled = false end
        return
    end
    if not keepArrow and d._Cleared then
        if hl then hl.Enabled = false end
        return
    end
    for k, v in pairs(d) do
        if k == "_Cleared" then continue end
        if keepArrow and (k == "Arrow" or k == "ArrowOutline") then continue end
        if k == "Corners" or k == "CornerOutlines" or k == "Bones" or k == "BoneOutlines" then
            for _, ln in ipairs(v) do if ln then ln.Visible = false end end
        elseif type(v) ~= "boolean" and v then
            v.Visible = false
        end
    end
    if not keepArrow then
        d._Cleared = true
        if hl then hl.Enabled = false end
    end
end

local function destroyEspEntry(entry: EspEntry)
    local d = entry.Draw
    if d then
        d._Cleared = false
        hideEspDrawings(d, entry.Highlight, false)
        for k, v in pairs(d) do
            if k == "Corners" or k == "CornerOutlines" or k == "Bones" or k == "BoneOutlines" then
                for _, ln in ipairs(v) do if ln then pcall(function() ln:Remove() end) end end
            elseif k ~= "_Cleared" and type(v) ~= "boolean" and v then
                pcall(function() v:Remove() end)
            end
        end
        entry.Draw = nil
    end
    if entry.Highlight then
        pcall(function() entry.Highlight:Destroy() end)
        entry.Highlight = nil
    end
end

local function ensurePlayerEsp(plr: Player): EspEntry
    local e = PlayerEsp[plr]
    if not e then
        e = { Player = plr, Draw = nil, Highlight = nil }
        PlayerEsp[plr] = e
    end
    return e
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then ensurePlayerEsp(p) end
end
Session.Bind(Players.PlayerAdded, function(p: Player)
    if p ~= LocalPlayer then ensurePlayerEsp(p) end
end)
Session.Bind(Players.PlayerRemoving, function(p: Player)
    MotionCache[p] = nil
    local e = PlayerEsp[p]
    if e then
        destroyEspEntry(e)
        PlayerEsp[p] = nil
    end
end)

local function updateCornerBox(d: { [string]: any }, boxMode: string, x: number, y: number, w: number, h: number, col: Color3)
    d._Cleared = false
    local px, py = math.floor(x + 0.5), math.floor(y + 0.5)
    local pw, ph = math.max(math.floor(w + 0.5), 6), math.max(math.floor(h + 0.5), 6)
    if boxMode == "2D" then
        if d.BoxFill then
            d.BoxFill.Size = Vector2.new(math.max(pw - 2, 1), math.max(ph - 2, 1))
            d.BoxFill.Position = Vector2.new(px + 1, py + 1)
            d.BoxFill.Color = col
            d.BoxFill.Visible = pw > 4 and ph > 4
        end
        if d.BoxOutline then
            d.BoxOutline.Size = Vector2.new(pw, ph)
            d.BoxOutline.Position = Vector2.new(px, py)
            d.BoxOutline.Visible = true
        end
        if d.Box then
            d.Box.Size = Vector2.new(pw, ph)
            d.Box.Position = Vector2.new(px, py)
            d.Box.Color = col
            d.Box.Visible = true
        end
        for i = 1, 8 do
            if d.CornerOutlines and d.CornerOutlines[i] then d.CornerOutlines[i].Visible = false end
            if d.Corners and d.Corners[i] then d.Corners[i].Visible = false end
        end
    elseif boxMode == "Corner" then
        if d.BoxFill then
            d.BoxFill.Size = Vector2.new(math.max(pw - 2, 1), math.max(ph - 2, 1))
            d.BoxFill.Position = Vector2.new(px + 1, py + 1)
            d.BoxFill.Color = col
            d.BoxFill.Visible = pw > 4 and ph > 4
        end
        if d.BoxOutline then d.BoxOutline.Visible = false end
        if d.Box then d.Box.Visible = false end
        if d.Corners then
            local R, B = px + pw, py + ph
            local lx = math.clamp(math.floor(pw * 0.24 + 0.5), 4, 18)
            local ly = math.clamp(math.floor(ph * 0.19 + 0.5), 4, 22)
            local fg = {
                { Vector2.new(px - 0.5, py), Vector2.new(px + lx, py) },
                { Vector2.new(px, py - 0.5), Vector2.new(px, py + ly) },
                { Vector2.new(R + 0.5, py), Vector2.new(R - lx, py) },
                { Vector2.new(R, py - 0.5), Vector2.new(R, py + ly) },
                { Vector2.new(px - 0.5, B), Vector2.new(px + lx, B) },
                { Vector2.new(px, B + 0.5), Vector2.new(px, B - ly) },
                { Vector2.new(R + 0.5, B), Vector2.new(R - lx, B) },
                { Vector2.new(R, B + 0.5), Vector2.new(R, B - ly) },
            }
            local bg = {
                { Vector2.new(px - 1, py), Vector2.new(px + lx + 1, py) },
                { Vector2.new(px, py - 1), Vector2.new(px, py + ly + 1) },
                { Vector2.new(R + 1, py), Vector2.new(R - lx - 1, py) },
                { Vector2.new(R, py - 1), Vector2.new(R, py + ly + 1) },
                { Vector2.new(px - 1, B), Vector2.new(px + lx + 1, B) },
                { Vector2.new(px, B + 1), Vector2.new(px, B - ly - 1) },
                { Vector2.new(R + 1, B), Vector2.new(R - lx - 1, B) },
                { Vector2.new(R, B + 1), Vector2.new(R, B - ly - 1) },
            }
            for i = 1, 8 do
                local out = d.CornerOutlines and d.CornerOutlines[i]
                if out then out.From = bg[i][1]; out.To = bg[i][2]; out.Visible = true end
                local ln = d.Corners[i]
                if ln then ln.From = fg[i][1]; ln.To = fg[i][2]; ln.Color = col; ln.Visible = true end
            end
        end
    else
        if d.BoxFill then d.BoxFill.Visible = false end
        if d.BoxOutline then d.BoxOutline.Visible = false end
        if d.Box then d.Box.Visible = false end
        for i = 1, 8 do
            if d.CornerOutlines and d.CornerOutlines[i] then d.CornerOutlines[i].Visible = false end
            if d.Corners and d.Corners[i] then d.Corners[i].Visible = false end
        end
    end
end

local function computeBoxScreen(model: Model, root: BasePart, cam: Camera, vp: Vector2): (boolean, number, number, number, number)
    local rootZ = -cam.CFrame:PointToObjectSpace(root.Position).Z
    if rootZ <= 0.35 then
        return false, 0, 0, 0, 0
    end
    local head = model:FindFirstChild("Head") :: BasePart?
    local topA = (head and head:IsA("BasePart") and head.Position or root.Position) + Vector3.new(0, 0.72, 0)
    local botA = root.Position - Vector3.new(0, 2.85, 0)
    local t2d = cam:WorldToViewportPoint(topA)
    local b2d = cam:WorldToViewportPoint(botA)
    local r2d = cam:WorldToViewportPoint(root.Position)
    if r2d.Z <= 0.35 then
        return false, 0, 0, 0, 0
    end
    local rawH = (t2d.Z > 0.35 and b2d.Z > 0.35) and math.abs(b2d.Y - t2d.Y) or 0
    if rawH < 4 then
        local focal = (vp.Y * 0.5) / math.max(math.tan(math.rad(cam.FieldOfView * 0.5)), 0.1)
        rawH = (5.6 / math.max(rootZ, 0.8)) * focal
    end
    local boxH = math.clamp(rawH, 10, vp.Y * 0.90)
    local boxW = math.clamp(boxH * 0.58, 8, vp.X * 0.55)
    local cx = (t2d.Z > 0.8 and b2d.Z > 0.8) and ((t2d.X + b2d.X) * 0.5) or r2d.X
    local topY = (t2d.Z > 0.8) and t2d.Y or (r2d.Y - boxH * 0.48)
    local bx = math.floor(cx - boxW * 0.5 + 0.5)
    local by = math.floor(topY + 0.5)
    local bw = math.floor(boxW + 0.5)
    local bh = math.floor(boxH + 0.5)
    if (bx + bw < -48) or (bx > vp.X + 48) or (by + bh < -48) or (by > vp.Y + 48) then
        return false, 0, 0, 0, 0
    end
    return true, bx, by, bw, bh
end

local R6_BONE_PAIRS = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

local function updateSkeleton(d: { [string]: any }, model: Model, cam: Camera, vp: Vector2, col: Color3, on: boolean)
    if on then
        if not d.Bones then
            d.BoneOutlines = createLinePool(#BONE_PAIRS, 2.8, OUTLINE_DARK, drawTrans(0.7), 3)
            d.Bones = createLinePool(#BONE_PAIRS, 1.6, nil, drawTrans(1.0), 4)
        end
        d._Cleared = false
        local pairsList = model:FindFirstChild("UpperTorso") and BONE_PAIRS or R6_BONE_PAIRS
        local maxSeg = math.max(vp.X, vp.Y) * 0.9
        for i = 1, #BONE_PAIRS do
            local pair = pairsList[i]
            local ln = d.Bones[i]
            local out = d.BoneOutlines and d.BoneOutlines[i]
            local p1 = pair and model:FindFirstChild(pair[1]) or nil
            local p2 = pair and model:FindFirstChild(pair[2]) or nil
            if ln and p1 and p1:IsA("BasePart") and p2 and p2:IsA("BasePart") then
                local v1, ok1 = cam:WorldToViewportPoint(p1.Position)
                local v2, ok2 = cam:WorldToViewportPoint(p2.Position)
                if v1.Z > 0.35 and v2.Z > 0.35 and (ok1 or ok2) then
                    local f, t = Vector2.new(v1.X, v1.Y), Vector2.new(v2.X, v2.Y)
                    if (f - t).Magnitude <= maxSeg then
                        if out then out.From = f; out.To = t; out.Visible = true end
                        ln.From = f; ln.To = t; ln.Color = col; ln.Visible = true
                        continue
                    end
                end
            end
            if out then out.Visible = false end
            if ln then ln.Visible = false end
        end
    elseif d.Bones or d.BoneOutlines then
        for i = 1, #BONE_PAIRS do
            if d.BoneOutlines and d.BoneOutlines[i] then d.BoneOutlines[i].Visible = false end
            if d.Bones and d.Bones[i] then d.Bones[i].Visible = false end
        end
    end
end

-- HUD Drawings (FOV + Lead Line + Predicted 3D Dot)
local FOVOutline = newDraw("Circle", { Thickness = 2.8, NumSides = 72, Filled = false, Color = OUTLINE_DARK, Transparency = drawTrans(0.5), ZIndex = 8, Visible = false })
local FOVCircle = newDraw("Circle", { Thickness = 1.6, NumSides = 72, Filled = false, Color = Color3.fromRGB(56, 189, 248), Transparency = drawTrans(0.92), ZIndex = 9, Visible = false })
local LeadLine = newDraw("Line", { Thickness = 1.4, Color = Color3.fromRGB(250, 204, 21), Transparency = drawTrans(0.85), ZIndex = 9, Visible = false })
local LeadDotOut = newDraw("Circle", { Filled = true, Radius = 5.0, NumSides = 16, Color = OUTLINE_DARK, Transparency = drawTrans(0.85), ZIndex = 9, Visible = false })
local LeadDot = newDraw("Circle", { Filled = true, Radius = 3.2, NumSides = 16, Color = Color3.fromRGB(250, 204, 21), Transparency = drawTrans(1.0), ZIndex = 10, Visible = false })

-- ============================================================================
-- 6. TARGETING ENGINE & RUNTIME LOOP
-- ============================================================================
local StickyTargetPlayer: Player? = nil
local ActiveLockPlayer: Player? = nil

local function getAimOrigin2D(): Vector2
    local mouseLoc = UserInputService:GetMouseLocation()
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        local cam = Workspace.CurrentCamera
        if cam then
            return Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
        end
    end
    return mouseLoc
end

local function pickAimPart(model: Model, origin2D: Vector2, cam: Camera): BasePart?
    local mode = Config.Silent.TargetPart
    if mode == "Closest Body" then
        local bestP: BasePart? = nil
        local bestD = math.huge
        for _, name in ipairs({ "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }) do
            local pt = model:FindFirstChild(name)
            if pt and pt:IsA("BasePart") then
                local sp, onScr = cam:WorldToViewportPoint(pt.Position)
                if sp.Z > 0.35 then
                    local d2 = (Vector2.new(sp.X, sp.Y) - origin2D).Magnitude + (onScr and 0 or 500)
                    if d2 < bestD then
                        bestD = d2
                        bestP = pt
                    end
                end
            end
        end
        if bestP then return bestP end
    elseif mode == "RootPart" then
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then return hrp end
    else
        -- Default: always target the chest (UpperTorso R15 / Torso R6), never Head
        local chest = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
        if chest and chest:IsA("BasePart") then
            return chest
        end
    end
    return (model:FindFirstChild("UpperTorso") :: BasePart?)
        or (model:FindFirstChild("Torso") :: BasePart?)
        or (model:FindFirstChild("HumanoidRootPart") :: BasePart?)
        or model.PrimaryPart
end

local function evaluateSilentTarget(cam: Camera, origin3D: Vector3, aim2D: Vector2, now: number, onlyPlayer: Player?, fovMult: number?): (Player?, Model?, BasePart?, Vector3?, number, number)
    local bestP: Player? = nil
    local bestM: Model? = nil
    local bestPart: BasePart? = nil
    local bestPred: Vector3? = nil
    local bestScore = math.huge
    local bestScreenDist = math.huge

    local maxDist = Config.Silent.MaxDistance
    local useFov = Config.Silent.UseFOV
    local fovLim = Config.Silent.FOV * (fovMult or 1)
    local prio = Config.Silent.Priority

    local list = onlyPlayer and { onlyPlayer } or Players:GetPlayers()
    for _, plr in ipairs(list) do
        if plr == LocalPlayer then continue end
        local ch = plr.Character
        local alive, hum, root = BF.IsPlayerAlive(plr, ch)
        if not alive or not ch or not hum or not root then continue end

        local sample = samplePlayerMotion(plr, ch, root, now)
        if Config.Silent.TeamCheck and BF.IsAlly(plr) then continue end
        if Config.Silent.IgnoreSafeZone and BF.IsPlayerInSafeZone(plr, ch) then continue end

        local worldDist = (root.Position - origin3D).Magnitude
        if worldDist > maxDist then continue end

        local part = pickAimPart(ch, aim2D, cam)
        if not part then continue end

        local sp, onScr = cam:WorldToViewportPoint(part.Position)
        local screenDist = (sp.Z > 0.35) and (Vector2.new(sp.X, sp.Y) - aim2D).Magnitude or math.huge
        if useFov then
            if sp.Z <= 0.35 or screenDist > fovLim then
                continue
            end
        else
            local offscreenCap = onlyPlayer and 550 or 260
            if (sp.Z <= 0.35 or not onScr) and worldDist > offscreenCap then
                continue
            end
        end

        local score: number
        if prio == "Closest" then
            score = worldDist
        elseif prio == "Lowest HP" then
            score = hum.Health * 100 + worldDist * 0.05
        else
            if onScr and sp.Z > 0.35 then
                score = screenDist
            else
                score = 4000 + worldDist
            end
        end

        if score < bestScore then
            bestScore = score
            bestScreenDist = screenDist
            bestP = plr
            bestM = ch
            bestPart = part
            bestPred = BF.PredictPosition3D(plr, ch, part, origin3D, sample)
        end
    end
    return bestP, bestM, bestPart, bestPred, bestScore, bestScreenDist
end

-- Keep Tool.MousePos & Skill Auto-Face updated seamlessly
local lastFaceSnapAt = 0
local function snapCharacterToward(pos: Vector3)
    if not Config.Silent.AutoFaceCast then return end
    if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then return end
    local ch = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end
    local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
    if (flat - root.Position).Magnitude > 0.25 then
        root.CFrame = CFrame.lookAt(root.Position, flat)
    end
end

local SKILL_KEYS = {
    [Enum.KeyCode.Z] = true,
    [Enum.KeyCode.X] = true,
    [Enum.KeyCode.C] = true,
    [Enum.KeyCode.V] = true,
}

-- ============================================================================
-- 7. COMPACT OBSIDIAN TACTICAL UI (468 x 362 px)
-- ============================================================================
local THEME = {
    BgMain = Color3.fromRGB(11, 14, 20),
    BgHeader = Color3.fromRGB(15, 19, 27),
    BgCard = Color3.fromRGB(17, 22, 31),
    BgControl = Color3.fromRGB(24, 30, 42),
    Border = Color3.fromRGB(40, 48, 64),
    Accent = Color3.fromRGB(56, 189, 248),
    AccentGlow = Color3.fromRGB(34, 211, 238),
    TextPrimary = Color3.fromRGB(241, 245, 249),
    TextMuted = Color3.fromRGB(148, 163, 184),
    Success = Color3.fromRGB(52, 211, 153),
    Danger = Color3.fromRGB(239, 68, 68),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaBF_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.AutoLocalize = false
ScreenGui.DisplayOrder = 120
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getUiParent()
Session.Track(ScreenGui)

local function addCorner(p: GuiObject, r: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
end

local function addStroke(p: GuiObject, col: Color3, thick: number, trans: number)
    local s = Instance.new("UIStroke")
    s.Color = col
    s.Thickness = thick
    s.Transparency = trans
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function formatBind(b: BindValue): string
    if typeof(b) ~= "EnumItem" or b == Enum.KeyCode.Unknown then return "None" end
    if b == Enum.UserInputType.MouseButton1 then return "M1" end
    if b == Enum.UserInputType.MouseButton2 then return "M2" end
    if b == Enum.KeyCode.RightControl then return "RCtrl" end
    if b == Enum.KeyCode.RightAlt then return "RAlt" end
    return b.Name
end

local MainWin = Instance.new("Frame")
MainWin.Name = "MainWindow"
MainWin.Size = UDim2.fromOffset(472, 396)
MainWin.Position = UDim2.new(0, 22, 0.5, -198)
MainWin.BackgroundColor3 = THEME.BgMain
MainWin.BackgroundTransparency = Config.Settings.MenuTransparency
MainWin.ClipsDescendants = true
MainWin.Parent = ScreenGui
addCorner(MainWin, 10)
addStroke(MainWin, THEME.Border, 1.1, 0.15)

-- Header Bar (38px)
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = THEME.BgHeader
Header.BackgroundTransparency = 0.08
Header.BorderSizePixel = 0
Header.Parent = MainWin
addCorner(Header, 10)

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 10)
HeaderFix.Position = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = THEME.BgHeader
HeaderFix.BackgroundTransparency = 0.08
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local TitleDot = Instance.new("Frame")
TitleDot.Size = UDim2.fromOffset(7, 7)
TitleDot.Position = UDim2.fromOffset(12, 16)
TitleDot.BackgroundColor3 = THEME.Accent
TitleDot.BorderSizePixel = 0
TitleDot.Parent = Header
addCorner(TitleDot, 4)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.BackgroundTransparency = 1
TitleLbl.Position = UDim2.fromOffset(25, 0)
TitleLbl.Size = UDim2.fromOffset(165, 38)
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 12
TitleLbl.TextColor3 = THEME.TextPrimary
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Text = "DELTA · Blox Fruits v4.3"
TitleLbl.Parent = Header

-- Tab Pill Switcher (Silent | ESP) right in header
local TabHolder = Instance.new("Frame")
TabHolder.Position = UDim2.fromOffset(186, 6)
TabHolder.Size = UDim2.fromOffset(146, 26)
TabHolder.BackgroundColor3 = THEME.BgControl
TabHolder.BorderSizePixel = 0
TabHolder.Parent = Header
addCorner(TabHolder, 6)
addStroke(TabHolder, THEME.Border, 1, 0.45)

-- Live Stats / Status Badge
local StatusLbl = Instance.new("TextLabel")
StatusLbl.BackgroundTransparency = 1
StatusLbl.Position = UDim2.new(1, -134, 0, 0)
StatusLbl.Size = UDim2.fromOffset(96, 38)
StatusLbl.Font = Enum.Font.GothamMedium
StatusLbl.TextSize = 10
StatusLbl.TextColor3 = THEME.TextMuted
StatusLbl.TextXAlignment = Enum.TextXAlignment.Right
StatusLbl.Text = "--ms"
StatusLbl.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Position = UDim2.new(1, -30, 0, 8)
MinBtn.Size = UDim2.fromOffset(22, 22)
MinBtn.BackgroundColor3 = THEME.BgControl
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 11
MinBtn.TextColor3 = THEME.TextMuted
MinBtn.AutoButtonColor = false
MinBtn.Parent = Header
addCorner(MinBtn, 5)

-- Smooth Dragging on Header
;(function()
    local dragging, dragStart, winStart = false, Vector2.zero, MainWin.Position
    Session.Bind(Header.InputBegan, function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            winStart = MainWin.Position
        end
    end)
    Session.Bind(UserInputService.InputChanged, function(inp: InputObject)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
            MainWin.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset + delta.X, winStart.Y.Scale, winStart.Y.Offset + delta.Y)
        end
    end)
    Session.Bind(UserInputService.InputEnded, function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end)()

-- Mini Target Status Strip at bottom (22px)
local FooterBar = Instance.new("Frame")
FooterBar.Position = UDim2.new(0, 0, 1, -24)
FooterBar.Size = UDim2.new(1, 0, 0, 24)
FooterBar.BackgroundColor3 = THEME.BgHeader
FooterBar.BackgroundTransparency = 0.08
FooterBar.BorderSizePixel = 0
FooterBar.Parent = MainWin

local FooterBorder = Instance.new("Frame")
FooterBorder.Size = UDim2.new(1, 0, 0, 1)
FooterBorder.BackgroundColor3 = THEME.Border
FooterBorder.BackgroundTransparency = 0.35
FooterBorder.BorderSizePixel = 0
FooterBorder.Parent = FooterBar

local TargetStatusLbl = Instance.new("TextLabel")
TargetStatusLbl.BackgroundTransparency = 1
TargetStatusLbl.Position = UDim2.fromOffset(10, 0)
TargetStatusLbl.Size = UDim2.new(1, -110, 1, 0)
TargetStatusLbl.Font = Enum.Font.GothamMedium
TargetStatusLbl.TextSize = 10
TargetStatusLbl.TextColor3 = THEME.TextMuted
TargetStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
TargetStatusLbl.Text = "Target: None  |  Standby"
TargetStatusLbl.Parent = FooterBar

local MenuKeyLbl = Instance.new("TextLabel")
MenuKeyLbl.BackgroundTransparency = 1
MenuKeyLbl.Position = UDim2.new(1, -104, 0, 0)
MenuKeyLbl.Size = UDim2.fromOffset(94, 24)
MenuKeyLbl.Font = Enum.Font.Gotham
MenuKeyLbl.TextSize = 10
MenuKeyLbl.TextColor3 = THEME.TextMuted
MenuKeyLbl.TextXAlignment = Enum.TextXAlignment.Right
MenuKeyLbl.Text = "RCtrl: Hide"
MenuKeyLbl.Parent = FooterBar

-- Pages Container
local PagesHost = Instance.new("Frame")
PagesHost.BackgroundTransparency = 1
PagesHost.Position = UDim2.fromOffset(8, 44)
PagesHost.Size = UDim2.new(1, -16, 1, -72)
PagesHost.Parent = MainWin

local RefreshCallbacks: { () -> () } = {}
local ListeningPicker: { Set: (BindValue) -> (), Refresh: () -> () }? = nil

local function makeColumnCard(parent: Instance, xScale: number, title: string): ScrollingFrame
    local card = Instance.new("Frame")
    card.Position = UDim2.new(xScale, xScale > 0 and 4 or 0, 0, 0)
    card.Size = UDim2.new(0.5, -4, 1, 0)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.25
    card.Parent = parent
    addCorner(card, 8)
    addStroke(card, THEME.Border, 1, 0.35)

    local hdr = Instance.new("TextLabel")
    hdr.BackgroundTransparency = 1
    hdr.Position = UDim2.fromOffset(10, 6)
    hdr.Size = UDim2.new(1, -20, 0, 16)
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 10
    hdr.TextColor3 = THEME.Accent
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.Text = title:upper()
    hdr.Parent = card

    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.Position = UDim2.fromOffset(4, 24)
    scroll.Size = UDim2.new(1, -8, 1, -28)
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = THEME.Border
    scroll.BorderSizePixel = 0
    scroll.Parent = card

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 4)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = scroll

    return scroll
end

local function addToggle(parent: Instance, label: string, getFn: () -> boolean, setFn: (boolean) -> ())
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = parent

    local txt = Instance.new("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Position = UDim2.fromOffset(2, 0)
    txt.Size = UDim2.new(1, -34, 1, 0)
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 11
    txt.TextColor3 = THEME.TextPrimary
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Text = label
    txt.Parent = row

    local sw = Instance.new("Frame")
    sw.Position = UDim2.new(1, -30, 0.5, -7)
    sw.Size = UDim2.fromOffset(28, 14)
    sw.BackgroundColor3 = THEME.BgControl
    sw.Parent = row
    addCorner(sw, 7)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(10, 10)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = THEME.TextPrimary
    knob.BorderSizePixel = 0
    knob.Parent = sw
    addCorner(knob, 5)

    local function sync(anim: boolean?)
        local on = getFn()
        local col = on and THEME.Accent or THEME.BgControl
        local pos = on and UDim2.fromOffset(16, 2) or UDim2.fromOffset(2, 2)
        txt.TextColor3 = on and THEME.TextPrimary or THEME.TextMuted
        if anim then
            TweenService:Create(sw, TweenInfo.new(0.12), { BackgroundColor3 = col }):Play()
            TweenService:Create(knob, TweenInfo.new(0.12), { Position = pos }):Play()
        else
            sw.BackgroundColor3 = col
            knob.Position = pos
        end
    end
    sync(false)
    table.insert(RefreshCallbacks, function() sync(false) end)

    Session.Bind(row.MouseButton1Click, function()
        setFn(not getFn())
        sync(true)
    end)
end

local function addSlider(parent: Instance, label: string, minV: number, maxV: number, stepV: number, fmt: string, getFn: () -> number, setFn: (number) -> ())
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 30)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent

    local txt = Instance.new("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Position = UDim2.fromOffset(2, 0)
    txt.Size = UDim2.new(1, -46, 0, 14)
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 10
    txt.TextColor3 = THEME.TextMuted
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Text = label
    txt.Parent = wrap

    local valLbl = Instance.new("TextLabel")
    valLbl.BackgroundTransparency = 1
    valLbl.Position = UDim2.new(1, -46, 0, 0)
    valLbl.Size = UDim2.fromOffset(44, 14)
    valLbl.Font = Enum.Font.GothamMedium
    valLbl.TextSize = 10
    valLbl.TextColor3 = THEME.Accent
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = wrap

    local hitbox = Instance.new("TextButton")
    hitbox.Position = UDim2.fromOffset(0, 13)
    hitbox.Size = UDim2.new(1, 0, 0, 16)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.AutoButtonColor = false
    hitbox.Parent = wrap

    local track = Instance.new("Frame")
    track.Position = UDim2.fromOffset(2, 18)
    track.Size = UDim2.new(1, -4, 0, 6)
    track.BackgroundColor3 = THEME.BgControl
    track.Parent = wrap
    addCorner(track, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    addCorner(fill, 3)

    local function sync()
        local v = math.clamp(getFn(), minV, maxV)
        local alpha = (v - minV) / math.max(maxV - minV, 1e-6)
        fill.Size = UDim2.fromScale(alpha, 1)
        valLbl.Text = string.format(fmt, v)
    end
    sync()
    table.insert(RefreshCallbacks, sync)

    local dragging = false
    local function applyX(px: number)
        local absX = track.AbsolutePosition.X
        local absW = math.max(track.AbsoluteSize.X, 1)
        local a = math.clamp((px - absX) / absW, 0, 1)
        local raw = minV + a * (maxV - minV)
        local snapped = math.floor(raw / stepV + 0.5) * stepV
        snapped = math.clamp(snapped, minV, maxV)
        setFn(snapped)
        sync()
    end

    Session.Bind(hitbox.InputBegan, function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            applyX(inp.Position.X)
        end
    end)
    Session.Bind(UserInputService.InputChanged, function(inp: InputObject)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            applyX(inp.Position.X)
        end
    end)
    Session.Bind(UserInputService.InputEnded, function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

local function addCycle(parent: Instance, label: string, options: { string }, getFn: () -> string, setFn: (string) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local txt = Instance.new("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Position = UDim2.fromOffset(2, 0)
    txt.Size = UDim2.new(0.48, 0, 1, 0)
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 11
    txt.TextColor3 = THEME.TextMuted
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Text = label
    txt.Parent = row

    local btn = Instance.new("TextButton")
    btn.Position = UDim2.new(0.48, 2, 0.5, -9)
    btn.Size = UDim2.new(0.52, -4, 0, 18)
    btn.BackgroundColor3 = THEME.BgControl
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 10
    btn.TextColor3 = THEME.TextPrimary
    btn.AutoButtonColor = false
    btn.Parent = row
    addCorner(btn, 4)
    addStroke(btn, THEME.Border, 1, 0.45)

    local function sync()
        btn.Text = getFn()
    end
    sync()
    table.insert(RefreshCallbacks, sync)

    Session.Bind(btn.MouseButton1Click, function()
        local cur = getFn()
        local idx = 1
        for i, v in ipairs(options) do
            if v == cur then
                idx = (i % #options) + 1
                break
            end
        end
        setFn(options[idx])
        sync()
    end)
end

local function addKeybind(parent: Instance, label: string, getFn: () -> BindValue, setFn: (BindValue) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local txt = Instance.new("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Position = UDim2.fromOffset(2, 0)
    txt.Size = UDim2.new(0.56, 0, 1, 0)
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 11
    txt.TextColor3 = THEME.TextMuted
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Text = label
    txt.Parent = row

    local btn = Instance.new("TextButton")
    btn.Position = UDim2.new(0.56, 2, 0.5, -9)
    btn.Size = UDim2.new(0.44, -4, 0, 18)
    btn.BackgroundColor3 = THEME.BgControl
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 10
    btn.TextColor3 = THEME.Accent
    btn.AutoButtonColor = false
    btn.Parent = row
    addCorner(btn, 4)
    addStroke(btn, THEME.Border, 1, 0.45)

    local function sync()
        btn.Text = formatBind(getFn())
    end
    sync()
    table.insert(RefreshCallbacks, sync)

    Session.Bind(btn.MouseButton1Click, function()
        btn.Text = "..."
        ListeningPicker = {
            Set = setFn,
            Refresh = sync,
        }
    end)
end

-- Create 2 Compact Pages: Silent & ESP
local SilentPage = Instance.new("Frame")
SilentPage.BackgroundTransparency = 1
SilentPage.Size = UDim2.fromScale(1, 1)
SilentPage.Visible = true
SilentPage.Parent = PagesHost

local EspPage = Instance.new("Frame")
EspPage.BackgroundTransparency = 1
EspPage.Size = UDim2.fromScale(1, 1)
EspPage.Visible = false
EspPage.Parent = PagesHost

local function makeTabButton(text: string, xOffset: number, page: Frame)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(xOffset, 2)
    b.Size = UDim2.fromOffset(70, 22)
    b.BackgroundColor3 = page.Visible and THEME.Accent or THEME.BgControl
    b.BackgroundTransparency = page.Visible and 0.12 or 1
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = page.Visible and THEME.BgMain or THEME.TextMuted
    b.Text = text
    b.AutoButtonColor = false
    b.Parent = TabHolder
    addCorner(b, 5)
    return b
end

local TabSilentBtn = makeTabButton("Silent", 2, SilentPage)
local TabEspBtn = makeTabButton("ESP", 74, EspPage)

local function selectTab(which: string)
    local sOn = (which == "Silent")
    SilentPage.Visible = sOn
    EspPage.Visible = not sOn
    TabSilentBtn.BackgroundColor3 = sOn and THEME.Accent or THEME.BgControl
    TabSilentBtn.BackgroundTransparency = sOn and 0.12 or 1
    TabSilentBtn.TextColor3 = sOn and THEME.BgMain or THEME.TextMuted
    TabEspBtn.BackgroundColor3 = (not sOn) and THEME.Accent or THEME.BgControl
    TabEspBtn.BackgroundTransparency = (not sOn) and 0.12 or 1
    TabEspBtn.TextColor3 = (not sOn) and THEME.BgMain or THEME.TextMuted
end

Session.Bind(TabSilentBtn.MouseButton1Click, function() selectTab("Silent") end)
Session.Bind(TabEspBtn.MouseButton1Click, function() selectTab("ESP") end)

-- Populate Tab 1: SILENT (Core + Strong 3D X/Y/Z Prediction)
local silentLeft = makeColumnCard(SilentPage, 0, "Silent Aim Core")
addToggle(silentLeft, "Silent Aim", function() return Config.Silent.Enabled end, function(v) Config.Silent.Enabled = v end)
addCycle(silentLeft, "Mode", { "Always", "Hold", "Toggle" }, function() return Config.Silent.Mode end, function(v) Config.Silent.Mode = v end)
addKeybind(silentLeft, "Silent Key", function() return Config.Silent.Key end, function(k) Config.Silent.Key = k end)
addToggle(silentLeft, "Safe NPC / Fruit", function() return Config.Silent.SafeInteract end, function(v) Config.Silent.SafeInteract = v end)
addToggle(silentLeft, "Skills (Z/X/C/V)", function() return Config.Silent.ApplySkills end, function(v) Config.Silent.ApplySkills = v end)
addToggle(silentLeft, "Guns & M1", function() return Config.Silent.ApplyGunsM1 end, function(v) Config.Silent.ApplyGunsM1 = v end)
addToggle(silentLeft, "Auto Face on Skill", function() return Config.Silent.AutoFaceCast end, function(v) Config.Silent.AutoFaceCast = v end)
addCycle(silentLeft, "HitPart", { "Chest", "RootPart", "Closest Body" }, function() return Config.Silent.TargetPart end, function(v) Config.Silent.TargetPart = v end)
addCycle(silentLeft, "Priority", { "Crosshair", "Closest", "Lowest HP" }, function() return Config.Silent.Priority end, function(v) Config.Silent.Priority = v end)
addToggle(silentLeft, "Sticky Lock", function() return Config.Silent.StickyLock end, function(v) Config.Silent.StickyLock = v end)
addToggle(silentLeft, "Team / Ally Check", function() return Config.Silent.TeamCheck end, function(v) Config.Silent.TeamCheck = v end)
addToggle(silentLeft, "Ignore SafeZone", function() return Config.Silent.IgnoreSafeZone end, function(v) Config.Silent.IgnoreSafeZone = v end)
addToggle(silentLeft, "Use FOV Circle", function() return Config.Silent.UseFOV end, function(v) Config.Silent.UseFOV = v end)
addToggle(silentLeft, "Show FOV", function() return Config.Silent.ShowFOV end, function(v) Config.Silent.ShowFOV = v end)
addToggle(silentLeft, "Show Lead Dot", function() return Config.Silent.ShowLeadLine end, function(v) Config.Silent.ShowLeadLine = v end)
addSlider(silentLeft, "FOV Radius", 30, 650, 5, "%.0f", function() return Config.Silent.FOV end, function(v) Config.Silent.FOV = v end)
addSlider(silentLeft, "Max Distance", 150, 3500, 50, "%.0fm", function() return Config.Silent.MaxDistance end, function(v) Config.Silent.MaxDistance = v end)

local silentRight = makeColumnCard(SilentPage, 0.5, "3D Prediction (X/Y/Z)")
addToggle(silentRight, "3D Prediction", function() return Config.Silent.Prediction end, function(v) Config.Silent.Prediction = v end)
addToggle(silentRight, "Auto Ping Lead", function() return Config.Silent.AutoPing end, function(v) Config.Silent.AutoPing = v end)
addToggle(silentRight, "Auto Gun Speed", function() return Config.Silent.AutoWeaponSpeed end, function(v) Config.Silent.AutoWeaponSpeed = v end)
addToggle(silentRight, "Gravity / Air Y", function() return Config.Silent.GravityCompY end, function(v) Config.Silent.GravityCompY = v end)
addToggle(silentRight, "Accel / Dash Lead", function() return Config.Silent.AccelLead end, function(v) Config.Silent.AccelLead = v end)
addSlider(silentRight, "Predict X", 0.0, 2.2, 0.05, "%.2fx", function() return Config.Silent.PredX end, function(v) Config.Silent.PredX = v end)
addSlider(silentRight, "Predict Y", 0.0, 2.2, 0.05, "%.2fx", function() return Config.Silent.PredY end, function(v) Config.Silent.PredY = v end)
addSlider(silentRight, "Predict Z", 0.0, 2.2, 0.05, "%.2fx", function() return Config.Silent.PredZ end, function(v) Config.Silent.PredZ = v end)
addSlider(silentRight, "Skill Speed", 100, 1500, 10, "%.0f", function() return Config.Silent.ProjSpeed end, function(v) Config.Silent.ProjSpeed = v end)
addSlider(silentRight, "Cast Lead (ms)", 0, 260, 5, "%.0fms", function() return Config.Silent.BaseLeadMs end, function(v) Config.Silent.BaseLeadMs = v end)
addSlider(silentRight, "Hit Chance", 10, 100, 5, "%.0f%%", function() return Config.Silent.HitChance end, function(v) Config.Silent.HitChance = v end)

-- Populate Tab 2: ESP (Player Visuals + Compact Controls)
local espLeft = makeColumnCard(EspPage, 0, "Player Visuals")
addToggle(espLeft, "Player ESP", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v end)
addCycle(espLeft, "Box Style", { "Corner", "2D", "Off" }, function() return Config.ESP.Box end, function(v) Config.ESP.Box = v end)
addToggle(espLeft, "Chams Highlights", function() return Config.ESP.Highlights end, function(v) Config.ESP.Highlights = v end)
addToggle(espLeft, "Health Bar", function() return Config.ESP.HealthBar end, function(v) Config.ESP.HealthBar = v end)
addToggle(espLeft, "Skeleton", function() return Config.ESP.Skeleton end, function(v) Config.ESP.Skeleton = v end)
addToggle(espLeft, "Tracers", function() return Config.ESP.Tracers end, function(v) Config.ESP.Tracers = v end)
addToggle(espLeft, "Offscreen Arrows", function() return Config.ESP.Arrows end, function(v) Config.ESP.Arrows = v end)
addToggle(espLeft, "Hide Allies / Team", function() return Config.ESP.TeamCheck end, function(v) Config.ESP.TeamCheck = v end)
addSlider(espLeft, "Max Distance", 250, 20000, 250, "%.0f", function() return Config.ESP.MaxDistance end, function(v) Config.ESP.MaxDistance = v end)

local espRight = makeColumnCard(EspPage, 0.5, "Tags & Menu")
addToggle(espRight, "Name & Level", function() return Config.ESP.NameLevel end, function(v) Config.ESP.NameLevel = v end)
addToggle(espRight, "Health Text", function() return Config.ESP.HealthText end, function(v) Config.ESP.HealthText = v end)
addToggle(espRight, "Distance (m)", function() return Config.ESP.Distance end, function(v) Config.ESP.Distance = v end)
addToggle(espRight, "Bounty / Safe / Ken", function() return Config.ESP.BountyStatus end, function(v) Config.ESP.BountyStatus = v end)
addToggle(espRight, "Fruit / Tool", function() return Config.ESP.WeaponFruit end, function(v) Config.ESP.WeaponFruit = v end)
addToggle(espRight, "Show SafeZone", function() return Config.ESP.ShowSafeZone end, function(v) Config.ESP.ShowSafeZone = v end)
addKeybind(espRight, "Menu Key", function() return Config.Settings.MenuKey end, function(k) Config.Settings.MenuKey = k; MenuKeyLbl.Text = formatBind(k) .. ": Hide" end)

local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(1, 0, 0, 22)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(68, 24, 30)
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.TextSize = 10
UnloadBtn.TextColor3 = Color3.fromRGB(254, 202, 202)
UnloadBtn.Text = "Unload Script"
UnloadBtn.AutoButtonColor = false
UnloadBtn.Parent = espRight
addCorner(UnloadBtn, 5)
addStroke(UnloadBtn, Color3.fromRGB(153, 27, 27), 1, 0.2)
Session.Bind(UnloadBtn.MouseButton1Click, function() Session.Stop() end)

-- Menu Visibility Toggle
local MenuVisible = true
local function setMenuVisible(vis: boolean)
    MenuVisible = vis
    MainWin.Visible = vis
end
Session.Bind(MinBtn.MouseButton1Click, function() setMenuVisible(false) end)

-- ============================================================================
-- 8. INPUT & MAIN LOOP + POST-CAMERA ESP RENDER STEP
-- ============================================================================
Session.Bind(UserInputService.InputBegan, function(inp: InputObject, gp: boolean)
    local code: BindValue = (inp.KeyCode ~= Enum.KeyCode.Unknown) and inp.KeyCode or inp.UserInputType
    if ListeningPicker then
        if inp.UserInputType == Enum.UserInputType.MouseMovement then return end
        local p = ListeningPicker
        ListeningPicker = nil
        if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then
            p.Set(Enum.KeyCode.Unknown)
        else
            p.Set(code)
        end
        p.Refresh()
        return
    end
    if gp then return end

    KeyHoldStates[code] = true
    if code == Config.Settings.MenuKey then
        setMenuVisible(not MenuVisible)
        return
    end
    if code ~= Enum.KeyCode.Unknown and code == Config.Silent.Key then
        if Config.Silent.Enabled and Config.Silent.Mode == "Toggle" then
            ToggleStates.Silent = not (ToggleStates.Silent ~= false)
        end
    end
    if isSilentHookReady(false, true) and HookState.PredPos and SKILL_KEYS[inp.KeyCode] then
        local nowK = os.clock()
        if nowK - lastFaceSnapAt > 0.04 then
            lastFaceSnapAt = nowK
            pcall(snapCharacterToward, HookState.PredPos :: Vector3)
        end
    end
end)

Session.Bind(UserInputService.InputEnded, function(inp: InputObject)
    local code: BindValue = (inp.KeyCode ~= Enum.KeyCode.Unknown) and inp.KeyCode or inp.UserInputType
    KeyHoldStates[code] = false
    if isSilentHookReady(false, true) and HookState.PredPos and SKILL_KEYS[inp.KeyCode] then
        local nowR = os.clock()
        if nowR - lastFaceSnapAt > 0.03 then
            lastFaceSnapAt = nowR
            pcall(snapCharacterToward, HookState.PredPos :: Vector3)
        end
    end
end)

local COMBAT_KINDS: { [string]: boolean } = {
    Melee = true,
    ["Blox Fruit"] = true,
    Sword = true,
    Gun = true,
}

local NON_COMBAT_ITEM_PATTERNS = {
    " fruit",
    "compass",
    "chalice",
    "goblet",
    "fishing rod",
    "flower",
    "present",
    "gift",
}

local NON_COMBAT_TOOLTIPS: { [string]: boolean } = {
    wear = true,
    jobtool = true,
    accessory = true,
}

local function classifyEquippedTool(ch: Model?): (boolean, Tool?, string)
    if not ch then
        return false, nil, ""
    end
    local tool = ch:FindFirstChildOfClass("Tool")
    if not tool then
        if ch:GetAttribute("Transformed") == true or ch:GetAttribute("BeastForm") == true then
            return true, nil, "Blox Fruit"
        end
        return false, nil, ""
    end
    -- Physical uneaten Devil Fruits, wearables & utility items must NEVER be treated as combat silent-aim weapons
    if tool:FindFirstChild("Eat") or tool:FindFirstChild("EatRemote") or tool:FindFirstChild("DropRemote") or tool:FindFirstChild("FruitModel") or tool:FindFirstChild("Store") then
        return false, tool, ""
    end
    local tipLow = tostring(tool.ToolTip or ""):lower()
    if NON_COMBAT_TOOLTIPS[tipLow] then
        return false, tool, ""
    end
    local typeVal = tool:FindFirstChild("Type")
    if typeVal and typeVal:IsA("StringValue") and typeVal.Value:lower() == "accessory" then
        return false, tool, ""
    end
    local nameLow = tool.Name:lower()
    if nameLow == "fruit" or nameLow == "torch" or nameLow == "cup" or nameLow == "bait" then
        return false, tool, ""
    end
    for _, pat in ipairs(NON_COMBAT_ITEM_PATTERNS) do
        if nameLow:find(pat, 1, true) ~= nil then
            return false, tool, ""
        end
    end

    local wType = tostring(tool:GetAttribute("WeaponType") or "")
    local tip = tostring(tool.ToolTip or "")
    local kind = COMBAT_KINDS[wType] and wType or (COMBAT_KINDS[tip] and tip or "")
    if kind == "" then
        if tool:FindFirstChild("RemoteFunctionShoot") ~= nil or nameLow:find("gun", 1, true) or nameLow:find("rifle", 1, true) or nameLow:find("guitar", 1, true) or nameLow:find("slingshot", 1, true) or nameLow:find("cannon", 1, true) or nameLow:find("bazooka", 1, true) or nameLow:find("kabucha", 1, true) or nameLow:find("bizarre", 1, true) or nameLow:find("flintlock", 1, true) or nameLow:find("musket", 1, true) or nameLow:find("acidum", 1, true) then
            kind = "Gun"
        elseif tool.Name:find("-", 1, true) ~= nil then
            kind = "Blox Fruit"
        else
            kind = "Melee"
        end
    end
    return true, tool, kind
end

local InteractRayParams = RaycastParams.new()
InteractRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function detectCursorAndNpcConflict(cam: Camera, aim2D: Vector2, origin3D: Vector3, lpChar: Model?): (boolean, number, string)
    if UserInputService:GetFocusedTextBox() ~= nil then
        return true, math.huge, "Chat/Box"
    end

    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local pgMain = pg:FindFirstChild("Main")
        local dlg = pgMain and pgMain:FindFirstChild("Dialogue")
        if dlg and dlg:IsA("GuiObject") and dlg.Visible then
            return true, math.huge, "Dialogue"
        end
    end

    local isShiftLock = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
    if not isShiftLock then
        local rawMouse = UserInputService:GetMouseLocation()
        -- Only yield to our own Menu while actively clicking/dragging inside it (leave open while testing!)
        if MenuVisible and MainWin.Visible and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            local mp, ms = MainWin.AbsolutePosition, MainWin.AbsoluteSize
            if rawMouse.X >= mp.X and rawMouse.X <= mp.X + ms.X and rawMouse.Y >= mp.Y and rawMouse.Y <= mp.Y + ms.Y then
                return true, math.huge, "Menu Click"
            end
        end

        if pg then
            local vpSize = cam.ViewportSize
            local inset = GuiService:GetGuiInset()
            local okG, objs = pcall(function()
                return pg:GetGuiObjectsAtPosition(rawMouse.X - inset.X, rawMouse.Y - inset.Y)
            end)
            if okG and type(objs) == "table" then
                for _, g in ipairs(objs) do
                    if not g:IsA("GuiObject") or not g.Visible then continue end
                    local sz = g.AbsoluteSize
                    if sz.X > vpSize.X * 0.55 and sz.Y > vpSize.Y * 0.55 then continue end
                    local ancVis = true
                    local cur: Instance? = g.Parent
                    while cur and cur ~= pg do
                        if cur:IsA("GuiObject") and not cur.Visible then ancVis = false; break end
                        if cur:IsA("ScreenGui") and not cur.Enabled then ancVis = false; break end
                        if cur:IsA("CanvasGroup") and cur.GroupTransparency >= 0.99 then ancVis = false; break end
                        cur = cur.Parent
                    end
                    if not ancVis then continue end
                    if (g:IsA("GuiButton") or g:IsA("TextBox")) and g.Active then
                        local hasVisual = g.BackgroundTransparency < 0.98
                            or (g:IsA("TextButton") and g.Text ~= "")
                            or (g:IsA("TextBox") and g.Text ~= "")
                            or (g:IsA("ImageButton") and g.Image ~= "")
                        if hasVisual then
                            return true, math.huge, "UI"
                        end
                    elseif g.Active and g.BackgroundTransparency < 0.95 then
                        local nm = g.Name:lower()
                        if nm:find("dialog", 1, true)
                            or nm:find("shop", 1, true)
                            or nm:find("quest", 1, true)
                            or nm:find("fruit", 1, true)
                            or nm:find("menu", 1, true)
                            or nm:find("prompt", 1, true)
                        then
                            return true, math.huge, "Dialogue/UI"
                        end
                    end
                end
            end
        end
    end

    -- Raycast directly under cursor: detect ClickDetectors, ProximityPrompts, Dropped Fruits, or NPCs
    if lpChar then
        InteractRayParams.FilterDescendantsInstances = { lpChar }
    else
        InteractRayParams.FilterDescendantsInstances = {}
    end
    local ray = cam:ViewportPointToRay(aim2D.X, aim2D.Y)
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 240, InteractRayParams)
    if hit and hit.Instance then
        local inst = hit.Instance
        local mdl = inst:FindFirstAncestorOfClass("Model")
        if inst:FindFirstChildOfClass("ClickDetector")
            or inst:FindFirstChildOfClass("ProximityPrompt")
            or (inst.Parent and (inst.Parent:FindFirstChildOfClass("ClickDetector") or inst.Parent:FindFirstChildOfClass("ProximityPrompt")))
            or (mdl and (mdl:FindFirstChildOfClass("ClickDetector") or mdl:FindFirstChildOfClass("ProximityPrompt")))
        then
            return true, 0, "Interact"
        end
        local droppedTool = inst:FindFirstChildOfClass("Tool") or inst:FindFirstAncestorOfClass("Tool")
        if droppedTool and not Players:GetPlayerFromCharacter(droppedTool.Parent :: any) then
            return true, 0, "Fruit/Drop"
        end
        if inst.Name:lower():find("fruit", 1, true) ~= nil then
            return true, 0, "Fruit/Drop"
        end
        if mdl and Players:GetPlayerFromCharacter(mdl) == nil then
            local npcsFolder = Workspace:FindFirstChild("NPCs")
            local enemiesFolder = Workspace:FindFirstChild("Enemies")
            if (npcsFolder and mdl:IsDescendantOf(npcsFolder))
                or (enemiesFolder and mdl:IsDescendantOf(enemiesFolder))
                or mdl:FindFirstChildOfClass("Humanoid") ~= nil
                or mdl.Name:lower():find("fruit", 1, true) ~= nil
            then
                return true, 0, "NPC/Fruit"
            end
        end
    end

    -- Proximity check for friendly NPCs right beside you (safe even if NPC Humanoid parts have CanQuery = false)
    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, npc in ipairs(npcsFolder:GetChildren()) do
            if npc:IsA("Model") then
                local nRoot = (npc:FindFirstChild("UpperTorso") :: BasePart?) or (npc:FindFirstChild("HumanoidRootPart") :: BasePart?) or npc.PrimaryPart
                if nRoot and (nRoot.Position - origin3D).Magnitude <= 40 then
                    local sp, onScr = cam:WorldToViewportPoint(nRoot.Position)
                    if onScr and sp.Z > 0.35 and (Vector2.new(sp.X, sp.Y) - aim2D).Magnitude <= 70 then
                        return true, 0, "NPC"
                    end
                end
            end
        end
    end

    -- Scan loaded Enemy NPCs near cursor so fighting NPCs naturally takes priority over bystanders
    local closestNpcDist = math.huge
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, npc in ipairs(enemiesFolder:GetChildren()) do
            if npc:IsA("Model") then
                local nHum = npc:FindFirstChildOfClass("Humanoid")
                local nRoot = (npc:FindFirstChild("HumanoidRootPart") :: BasePart?) or (npc:FindFirstChild("UpperTorso") :: BasePart?) or npc.PrimaryPart
                if nHum and nHum.Health > 0 and nRoot and (nRoot.Position - origin3D).Magnitude <= 350 then
                    local sp, onScr = cam:WorldToViewportPoint(nRoot.Position)
                    if onScr and sp.Z > 0.35 then
                        local d2 = (Vector2.new(sp.X, sp.Y) - aim2D).Magnitude
                        if d2 < closestNpcDist then
                            closestNpcDist = d2
                        end
                    end
                end
            end
        end
    end

    return false, closestNpcDist, ""
end

local function getRawMouseHitPos(cam: Camera): Vector3?
    local aim2D = getAimOrigin2D()
    local ray = cam:ViewportPointToRay(aim2D.X, aim2D.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if LocalPlayer.Character then
        params.FilterDescendantsInstances = { LocalPlayer.Character }
    end
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1200, params)
    if hit then
        return hit.Position
    end
    return ray.Origin + ray.Direction * 500
end

local lastStatsClock = 0
local fpsFrames, fpsAcc = 0, 0
local standbyReason = ""

Session.Bind(RunService.RenderStepped, function(dt: number)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = os.clock()

    -- Reconcile PlayerEsp registry
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not PlayerEsp[p] then
            ensurePlayerEsp(p)
        end
    end

    local aim2D = getAimOrigin2D()
    local lpChar = LocalPlayer.Character
    local lpAlive, _, lpRoot = BF.IsPlayerAlive(LocalPlayer, lpChar)
    local shotOrigin = lpRoot and (lpRoot.Position + Vector3.new(0, 1.4, 0)) or cam.CFrame.Position

    HookState.ShotOrigin = shotOrigin
    HookState.RawMousePos = getRawMouseHitPos(cam)
    HookState.ApplySkills = Config.Silent.ApplySkills
    HookState.ApplyGuns = Config.Silent.ApplyGunsM1

    local hasCombatTool, eqTool, toolKind = classifyEquippedTool(lpAlive and lpChar or nil)
    HookState.HasCombatTool = hasCombatTool
    HookState.EquippedTool = eqTool
    HookState.ToolKind = toolKind

    local silentOn = isSilentModeActive()
    local blockedInteract, closestNpcDist, blockReason = false, math.huge, ""
    if silentOn and Config.Silent.SafeInteract then
        blockedInteract, closestNpcDist, blockReason = detectCursorAndNpcConflict(cam, aim2D, shotOrigin, lpChar)
    end

    local targetPlr: Player? = nil
    local targetModel: Model? = nil
    local targetPart: BasePart? = nil
    local predPos: Vector3? = nil
    local targetScreenDist = math.huge

    local canLock = silentOn and lpAlive and hasCombatTool and not blockedInteract
    if canLock then
        if Config.Silent.StickyLock and StickyTargetPlayer then
            local p1, m1, pt1, pr1, _, sd1 = evaluateSilentTarget(cam, shotOrigin, aim2D, now, StickyTargetPlayer, 1.35)
            targetPlr, targetModel, targetPart, predPos, targetScreenDist = p1, m1, pt1, pr1, sd1
        end
        if not targetPlr then
            local p2, m2, pt2, pr2, _, sd2 = evaluateSilentTarget(cam, shotOrigin, aim2D, now, nil, 1.0)
            targetPlr, targetModel, targetPart, predPos, targetScreenDist = p2, m2, pt2, pr2, sd2
        end

        -- Yield to nearby NPC if player is actually aiming at that NPC rather than the enemy Player
        if targetPlr and Config.Silent.SafeInteract and closestNpcDist <= 75 and closestNpcDist < (targetScreenDist * 0.85) then
            targetPlr, targetModel, targetPart, predPos = nil, nil, nil, nil
            blockReason = "NPC Aim"
        end
        StickyTargetPlayer = targetPlr
    else
        StickyTargetPlayer = nil
        if silentOn and not hasCombatTool and lpAlive then
            blockReason = "No Weapon"
        end
    end

    standbyReason = blockReason
    ActiveLockPlayer = targetPlr

    local chancePass = true
    if predPos and Config.Silent.HitChance < 100 then
        chancePass = math.random(1, 100) <= Config.Silent.HitChance
    end

    if canLock and predPos and targetPart and chancePass then
        HookState.Active = true
        HookState.AllowMouseOverride = true
        HookState.PredPos = predPos
        HookState.TargetPart = targetPart
        HookState.TargetDist = (targetPart.Position - shotOrigin).Magnitude
        local sp = cam:WorldToViewportPoint(predPos)
        HookState.ScreenPos = Vector2.new(sp.X, sp.Y)

        -- Sync held weapon's MousePos Vector3Value only while actively locked onto a Player
        local mp = eqTool and eqTool:FindFirstChild("MousePos")
        if mp and mp:IsA("Vector3Value") then
            mp.Value = predPos
        end
    else
        HookState.Active = false
        HookState.AllowMouseOverride = false
        HookState.PredPos = nil
        HookState.TargetPart = nil
        HookState.TargetDist = math.huge
        clearRSMouseRawKeys()
    end

    -- FOV Circle & Predicted Lead Visuals
    local showFov = silentOn and Config.Silent.UseFOV and Config.Silent.ShowFOV
    if FOVCircle then
        if showFov then
            if FOVOutline then
                FOVOutline.Position = aim2D
                FOVOutline.Radius = Config.Silent.FOV
                FOVOutline.Visible = true
            end
            FOVCircle.Position = aim2D
            FOVCircle.Radius = Config.Silent.FOV
            FOVCircle.Color = targetPlr and THEME.AccentGlow or THEME.Accent
            FOVCircle.Visible = true
        else
            if FOVOutline then FOVOutline.Visible = false end
            FOVCircle.Visible = false
        end
    end

    if LeadDot then
        if silentOn and Config.Silent.ShowLeadLine and predPos and targetPart then
            local p2d, onScr = cam:WorldToViewportPoint(predPos)
            local r2d, rOn = cam:WorldToViewportPoint(targetPart.Position)
            if p2d.Z > 0.35 and onScr then
                local pt = Vector2.new(p2d.X, p2d.Y)
                if LeadDotOut then LeadDotOut.Position = pt; LeadDotOut.Visible = true end
                LeadDot.Position = pt
                LeadDot.Visible = true
                if LeadLine then
                    LeadLine.From = (rOn and r2d.Z > 0.35) and Vector2.new(r2d.X, r2d.Y) or aim2D
                    LeadLine.To = pt
                    LeadLine.Visible = true
                end
            else
                if LeadDotOut then LeadDotOut.Visible = false end
                LeadDot.Visible = false
                if LeadLine then LeadLine.Visible = false end
            end
        else
            if LeadDotOut then LeadDotOut.Visible = false end
            LeadDot.Visible = false
            if LeadLine then LeadLine.Visible = false end
        end
    end

    -- Footer Status & Stats (~4 Hz)
    fpsAcc += dt
    fpsFrames += 1
    if now - lastStatsClock >= 0.25 then
        local fps = math.floor(fpsFrames / math.max(fpsAcc, 0.001) + 0.5)
        fpsFrames, fpsAcc = 0, 0
        lastStatsClock = now
        local okP, pVal = pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        StatusLbl.Text = string.format("%d FPS · %dms", fps, okP and pVal or 0)
        if targetPlr and predPos and lpRoot then
            local distM = math.floor((predPos - lpRoot.Position).Magnitude + 0.5)
            local safeTxt = (targetModel and BF.IsPlayerInSafeZone(targetPlr, targetModel)) and " [SAFE]" or ""
            TargetStatusLbl.Text = string.format("Lock: %s (%dm)%s", targetPlr.DisplayName, distM, safeTxt)
            TargetStatusLbl.TextColor3 = THEME.Accent
        elseif silentOn then
            if standbyReason == "No Weapon" then
                TargetStatusLbl.Text = "Silent: ACTIVE (Draw Weapon)"
                TargetStatusLbl.TextColor3 = THEME.Success
            elseif standbyReason ~= "" then
                TargetStatusLbl.Text = string.format("Silent: Safe (%s)", standbyReason)
                TargetStatusLbl.TextColor3 = THEME.AccentGlow
            else
                TargetStatusLbl.Text = "Silent: ACTIVE (No Key Needed)"
                TargetStatusLbl.TextColor3 = THEME.Success
            end
        else
            TargetStatusLbl.Text = "Silent: Standby"
            TargetStatusLbl.TextColor3 = THEME.TextMuted
        end
    end
end)

-- Post-Camera Player ESP Loop
local function renderPlayerEsp(plr: Player, entry: EspEntry, cam: Camera, vp: Vector2, camPos: Vector3)
    local ch = plr.Character
    local alive, hum, root = BF.IsPlayerAlive(plr, ch)
    if not Config.ESP.Enabled or not alive or not ch or not hum or not root then
        hideEspDrawings(entry.Draw, entry.Highlight, false)
        return
    end

    local isAlly = BF.IsAlly(plr)
    if Config.ESP.TeamCheck and isAlly then
        hideEspDrawings(entry.Draw, entry.Highlight, false)
        return
    end
    local inSafe = BF.IsPlayerInSafeZone(plr, ch)
    if inSafe and not Config.ESP.ShowSafeZone then
        hideEspDrawings(entry.Draw, entry.Highlight, false)
        return
    end

    local dist = (root.Position - camPos).Magnitude
    if dist > Config.ESP.MaxDistance then
        hideEspDrawings(entry.Draw, entry.Highlight, false)
        return
    end

    local col = Config.ESP.EnemyColor
    if ActiveLockPlayer == plr then
        col = Config.ESP.LockedColor
    elseif isAlly then
        col = Config.ESP.AllyColor
    elseif inSafe then
        col = Config.ESP.SafeColor
    end

    -- Highlight Chams
    if Config.ESP.Highlights then
        if not entry.Highlight or entry.Highlight.Parent ~= ch then
            if entry.Highlight then pcall(function() entry.Highlight:Destroy() end) end
            local hl = Instance.new("Highlight")
            hl.Name = "__DeltaBFChams"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.65
            hl.OutlineTransparency = 0.05
            hl.Parent = ch
            Session.Track(hl)
            entry.Highlight = hl
        end
        entry.Highlight.FillColor = col
        entry.Highlight.OutlineColor = Color3.new(1, 1, 1)
        entry.Highlight.Enabled = true
    elseif entry.Highlight then
        entry.Highlight.Enabled = false
    end

    if not entry.Draw then
        entry.Draw = createEspDrawings()
    end
    local d = entry.Draw :: { [string]: any }

    -- Offscreen Arrow
    if Config.ESP.Arrows and d.Arrow then
        local spA, onA = cam:WorldToViewportPoint(root.Position)
        local inScreen = onA and spA.Z > 0.35 and spA.X >= 10 and spA.X <= vp.X - 10 and spA.Y >= 10 and spA.Y <= vp.Y - 10
        if inScreen then
            d.Arrow.Visible = false
            if d.ArrowOutline then d.ArrowOutline.Visible = false end
        else
            local lv = cam.CFrame:PointToObjectSpace(root.Position)
            local fl = Vector2.new(lv.X, -lv.Y)
            if fl.Magnitude < 0.001 then fl = Vector2.new(0, -1) end
            local dir = fl.Unit
            local perp = Vector2.new(-dir.Y, dir.X)
            local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
            local tip = center + dir * math.min(vp.X, vp.Y) * 0.36
            local bL = tip - dir * 13 + perp * 6.5
            local bR = tip - dir * 13 - perp * 6.5
            d._Cleared = false
            if d.ArrowOutline then
                d.ArrowOutline.PointA = tip + dir * 1.5
                d.ArrowOutline.PointB = bL - dir * 1 + perp * 1.2
                d.ArrowOutline.PointC = bR - dir * 1 - perp * 1.2
                d.ArrowOutline.Visible = true
            end
            d.Arrow.PointA = tip
            d.Arrow.PointB = bL
            d.Arrow.PointC = bR
            d.Arrow.Color = col
            d.Arrow.Visible = true
        end
    else
        if d.Arrow then d.Arrow.Visible = false end
        if d.ArrowOutline then d.ArrowOutline.Visible = false end
    end

    local okBox, bx, by, bw, bh = computeBoxScreen(ch, root, cam, vp)
    if not okBox then
        hideEspDrawings(d, entry.Highlight, true)
        return
    end

    updateCornerBox(d, Config.ESP.Box, bx, by, bw, bh, col)

    local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    if Config.ESP.HealthBar and d.HpBg and d.HpFill then
        local barX = bx - 5
        local fillH = math.max(math.floor(bh * hpRatio + 0.5), 1)
        d.HpBg.Position = Vector2.new(barX - 1, by - 1)
        d.HpBg.Size = Vector2.new(4, bh + 2)
        d.HpBg.Visible = true
        d.HpFill.Position = Vector2.new(barX, by + (bh - fillH))
        d.HpFill.Size = Vector2.new(2, fillH)
        d.HpFill.Color = computeHealthColor(hpRatio)
        d.HpFill.Visible = true
    else
        if d.HpBg then d.HpBg.Visible = false end
        if d.HpFill then d.HpFill.Visible = false end
    end

    local okMeta, lv, bountyStr, kenDodges, kenMax, heldName = pcall(BF.GetPlayerMeta, plr, ch)
    local cx = math.floor(bx + bw * 0.5 + 0.5)
    local fs = Config.Settings.FontSize

    if Config.ESP.NameLevel and d.Name then
        local prefix = (okMeta and lv) and string.format("[Lv.%d] ", lv) or ""
        local lockTag = (ActiveLockPlayer == plr) and "★ " or ""
        d.Name.Text = lockTag .. prefix .. plr.DisplayName
        d.Name.Color = col
        d.Name.Size = fs
        d.Name.Position = Vector2.new(cx, by - fs - 3)
        d.Name.Visible = true
    elseif d.Name then
        d.Name.Visible = false
    end

    local botLines: { { Text: string, Color: Color3 } } = {}
    local l1Parts: { string } = {}
    if Config.ESP.HealthText then
        table.insert(l1Parts, string.format("%.0f HP", hum.Health))
    end
    if Config.ESP.Distance then
        table.insert(l1Parts, string.format("%.0fm", dist))
    end
    if #l1Parts > 0 then
        table.insert(botLines, { Text = table.concat(l1Parts, " · "), Color = Color3.fromRGB(226, 232, 240) })
    end

    if Config.ESP.BountyStatus and okMeta then
        local stParts: { string } = {}
        if bountyStr ~= "" then table.insert(stParts, bountyStr) end
        if inSafe then table.insert(stParts, "SAFE") end
        if kenDodges ~= nil then
            table.insert(stParts, string.format("KEN %d/%d", kenDodges, kenMax or 8))
        end
        if #stParts > 0 then
            table.insert(botLines, { Text = table.concat(stParts, " · "), Color = inSafe and THEME.SafeColor or Color3.fromRGB(250, 204, 21) })
        end
    end

    if Config.ESP.WeaponFruit and okMeta and heldName then
        table.insert(botLines, { Text = heldName, Color = Color3.fromRGB(165, 180, 252) })
    end

    local bLabels = { d.Bottom1, d.Bottom2, d.Bottom3 }
    for idx, lbl in ipairs(bLabels) do
        if lbl then
            local info = botLines[idx]
            if info then
                lbl.Text = info.Text
                lbl.Color = info.Color
                lbl.Position = Vector2.new(cx, by + bh + 3 + (idx - 1) * (fs - 1))
                lbl.Visible = true
            else
                lbl.Visible = false
            end
        end
    end

    if d.Tracer then
        if Config.ESP.Tracers then
            d.Tracer.From = Vector2.new(vp.X * 0.5, vp.Y)
            d.Tracer.To = Vector2.new(cx, by + bh)
            d.Tracer.Color = col
            d.Tracer.Visible = true
        else
            d.Tracer.Visible = false
        end
    end

    updateSkeleton(d, ch, cam, vp, col, Config.ESP.Skeleton)
end

pcall(RunService.UnbindFromRenderStep, RunService, "DeltaBFSilentESP")
RunService:BindToRenderStep("DeltaBFSilentESP", Enum.RenderPriority.Last.Value, function()
    if not Session.IsAlive() then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if vp.X <= 1 or vp.Y <= 1 then return end

    local camPos = cam.CFrame.Position
    for plr, entry in pairs(PlayerEsp) do
        local okEsp = pcall(renderPlayerEsp, plr, entry, cam, vp, camPos)
        if not okEsp then
            hideEspDrawings(entry.Draw, entry.Highlight, false)
        end
    end
end)

Session.OnStop(function()
    if HookState.RunToken == MyRunToken then
        HookState.Active = false
        HookState.AllowMouseOverride = false
        HookState.HasCombatTool = false
        HookState.EquippedTool = nil
        HookState.PredPos = nil
        HookState.TargetPart = nil
        HookState.TargetDist = math.huge
        HookState.ReadyFn = nil
        clearRSMouseRawKeys()
    end
    pcall(RunService.UnbindFromRenderStep, RunService, "DeltaBFSilentESP")
    for _, e in pairs(PlayerEsp) do
        destroyEspEntry(e)
    end
    table.clear(PlayerEsp)
    for _, obj in ipairs({ FOVOutline, FOVCircle, LeadLine, LeadDotOut, LeadDot }) do
        if obj then pcall(function() obj:Remove() end) end
    end
end)
