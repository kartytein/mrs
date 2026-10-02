--!nocheck
-- ============================================================
-- GREEN MODE — АВТОНОМНЫЙ ТЕСТ
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- КОНФИГ
-- ============================================================
local SERVER_URL          = "http://192.168.31.179:8000"
local POST_TRADE_NPC_NAME = "Dojo Trainer"

-- Y поднят на +50, чтобы не проваливаться сквозь текстуры
local GREEN_HOST_POS   = Vector3.new(5841.1, 1258.6, 887.2)
local GREEN_GUEST_POS  = Vector3.new(5848.3, 1258.6, 881.5)

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local TAB_FRUIT, OPT_FRUIT = 7, 7

local TELEPORT_TAB          = 19
local TELEPORT_OPT_TEXT     = 2
local TELEPORT_OPT_ACTIVATE = 3

local HUB_READY_TIMEOUT = 120

-- ============================================================
-- ЛОГГЕР
-- ============================================================
local T0 = tick()
local function LOG(tag, msg)
    print(string.format("[%7.2fs][%s] %s", tick() - T0, tag, msg))
end
local function WARN(tag, msg)
    warn(string.format("[%7.2fs][%s] %s", tick() - T0, tag, msg))
end

-- ============================================================
-- STATE
-- ============================================================
local State = {
    running = true,
    mode    = "none",
}

-- ============================================================
-- RF/InteractDragonQuest
-- ============================================================
local RF_InteractDragonQuest = nil
do
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local net = modules:FindFirstChild("Net")
        if net then
            RF_InteractDragonQuest = net:FindFirstChild("RF/InteractDragonQuest")
        end
    end
end

-- ============================================================
-- КОЛЛИЗИИ (без фонового таска — race устранён)
-- ============================================================
local collisionsDisabledGlobal = false
local savedCollisionsGlobal = {}

local function disableCollisionsNow()
    pcall(function()
        local myChar = player.Character
        local saved = savedCollisionsGlobal
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if not (myChar and obj:IsDescendantOf(myChar)) then
                    if obj.CanCollide then
                        saved[obj] = true
                        obj.CanCollide = false
                    end
                end
            end
        end
    end)
end

local function restoreCollisionsNow()
    for part, _ in pairs(savedCollisionsGlobal) do
        if part and part.Parent then
            pcall(function() part.CanCollide = true end)
        end
    end
    savedCollisionsGlobal = {}
end

-- ============================================================
-- FIRE SEQUENCE
-- ============================================================
local function fireSequence(btn)
    if not btn then return false end
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local fired = false
    for _, sigName in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn.Enabled and type(conn.Function) == "function" then
                        pcall(conn.Function); fired = true
                    end
                end
            end
        end
    end
    return fired
end

-- ============================================================
-- ХАБ
-- ============================================================
local function getRoot()
    for _, c in ipairs(CoreGui:GetChildren()) do
        local obj = c:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end

local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child)
        if found then return found end
    end
    return nil
end

local function findTab(root, tabIndex)
    local ts = safeFind(root, "Window","Components","TabsScroll")
    if not ts then return nil end
    local btn, count = nil, 0
    local function scan(p)
        if btn then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                count += 1
                if count == tabIndex then btn = c; return end
            end
            scan(c)
        end
    end
    scan(ts)
    return btn
end

local function findOption(root, optIndex)
    local cont = safeFind(root, "Window","Components","Containers","Container")
    if not cont then return nil end
    local btn, count = nil, 0
    for _, c in ipairs(cont:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            count += 1
            if count == optIndex then btn = c; break end
        end
    end
    return btn
end

local function waitForOptions(expectedMin, timeout)
    timeout = timeout or 8
    expectedMin = expectedMin or 1
    local t0 = tick()
    local last, stable = -1, 0
    while tick() - t0 < timeout do
        local root = getRoot()
        local cont = root and safeFind(root, "Window","Components","Containers","Container")
        local count = 0
        if cont then
            for _, c in ipairs(cont:GetChildren()) do
                if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                    count += 1
                end
            end
        end
        if count >= expectedMin then
            if count == last then
                stable += 1
                if stable >= 2 then return true end
            else stable, last = 0, count end
        else last, stable = -1, 0 end
        task.wait(0.15)
    end
    return false
end

local function getOptionState(tabIndex, optIndex)
    local root = getRoot()
    if not root then return nil end
    local tb = findTab(root, tabIndex)
    if not tb then return nil end
    fireSequence(tb)
    if not waitForOptions(optIndex, 8) then return nil end
    local opt = findOption(root, optIndex)
    if not opt then return nil end
    local ind = findIndicatorFrame(opt)
    if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    if col == COLOR_ON then return true end
    if col == COLOR_OFF then return false end
    return nil
end

local function setOption(tabIndex, optIndex, wantOn)
    local root = getRoot()
    if not root then return false end
    local tb = findTab(root, tabIndex)
    if not tb then return false end
    fireSequence(tb)
    if not waitForOptions(optIndex, 8) then return false end

    local opt = findOption(root, optIndex)
    if not opt then return false end
    local ind = findIndicatorFrame(opt)
    if not ind then return false end
    local isOn = (tostring(ind.BackgroundColor3) == COLOR_ON)
    if isOn == wantOn then return true end

    fireSequence(opt); task.wait(0.2)
    for _ = 1, 5 do
        local i2 = findIndicatorFrame(opt)
        if i2 and (tostring(i2.BackgroundColor3) == COLOR_ON) == wantOn then return true end
        fireSequence(opt); task.wait(0.25)
    end
    return false
end

local function ensureOptionState(tabIndex, optIndex, wantOn, maxTries)
    maxTries = maxTries or 6
    for i = 1, maxTries do
        local st = getOptionState(tabIndex, optIndex)
        if st == wantOn then return true end
        setOption(tabIndex, optIndex, wantOn)
        task.wait(0.4)
    end
    return getOptionState(tabIndex, optIndex) == wantOn
end

local function ensureOptionOff(tabIndex, optIndex, maxTries)
    return ensureOptionState(tabIndex, optIndex, false, maxTries)
end

local function ensureOptionOn(tabIndex, optIndex, maxTries)
    return ensureOptionState(tabIndex, optIndex, true, maxTries)
end

local function waitForHubReady(timeout)
    timeout = timeout or HUB_READY_TIMEOUT
    local t0 = tick()
    local firstSeen = false
    while tick() - t0 < timeout and State.running do
        if getRoot() then
            if not firstSeen then
                firstSeen = true
                LOG("Hub", "root появился, жду опции...")
            end
            if waitForOptions(1, 2) then
                LOG("Hub", "готов (t=" .. string.format("%.1f", tick() - t0) .. "s)")
                return true
            end
        end
        task.wait(0.5)
    end
    WARN("Hub", "не готов за " .. timeout .. "с")
    return false
end

-- ============================================================
-- ТЕЛЕПОРТ
-- ============================================================
local function findNthTabButton(ts, idx)
    local btn, cnt = nil, 0
    local function rec(p)
        if btn then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                cnt += 1
                if cnt == idx then btn = c; return end
            end
            rec(c)
        end
    end
    rec(ts)
    return btn
end

local function findNthOption(cont, idx)
    local btn, cnt = nil, 0
    for _, c in ipairs(cont:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            cnt += 1
            if cnt == idx then btn = c; break end
        end
    end
    return btn
end

local function teleportToJobId(jobId)
    local root = getRoot() if not root then return false end
    local ts = safeFind(root, "Window","Components","TabsScroll")
    if not ts then return false end
    local tb = findNthTabButton(ts, TELEPORT_TAB)
    if not tb then return false end
    fireSequence(tb); task.wait(0.5)
    local cont = safeFind(root, "Window","Components","Containers","Container")
    if not cont then return false end
    local optText = findNthOption(cont, TELEPORT_OPT_TEXT)
    if not optText then return false end
    local function findTB(p)
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextBox") then return c end
            local f = findTB(c)
            if f then return f end
        end
    end
    local tx = findTB(optText)
    if not tx then return false end
    tx:CaptureFocus(); task.wait(0.2)
    tx.Text = jobId; task.wait(0.2)
    tx:ReleaseFocus(true); task.wait(0.3)
    local optAct = findNthOption(cont, TELEPORT_OPT_ACTIVATE)
    if not optAct then return false end
    fireSequence(optAct)
    return true
end

-- ============================================================
-- ПЕРЕМЕЩЕНИЕ
-- ============================================================
local STEP_XZ          = 4
local TELEPORT_DIST_XZ = 12
local Y_UP_SPEED       = 50
local Y_TOLERANCE      = 3
local MAX_ITER         = 6000

-- Как goToPosition, но НЕ отпускает PlatformStand. Персонаж висит в воздухе.
local function goToPositionHoldAir(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end

    hum.PlatformStand = true

    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyPosition") or v:IsA("BodyGyro")
           or v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
            v:Destroy()
        end
    end

    local bv = hrp:FindFirstChildOfClass("BodyVelocity")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
    end

    local lastLogAt = tick()
    local iter = 0
    LOG("Move", string.format("старт-hold (%.0f,%.0f,%.0f)",
        targetPos.X, targetPos.Y, targetPos.Z))

    while iter < MAX_ITER do
        iter += 1

        char = player.Character
        if not char then break end
        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then break end
        if hum.Health <= 0 then break end

        bv = hrp:FindFirstChildOfClass("BodyVelocity")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
        end

        local cur = hrp.Position
        local dx, dz = targetPos.X - cur.X, targetPos.Z - cur.Z
        local dy = targetPos.Y - cur.Y
        local distXZ = math.sqrt(dx*dx + dz*dz)

        if distXZ < 1 and math.abs(dy) < Y_TOLERANCE then break end

        if distXZ < TELEPORT_DIST_XZ and distXZ > 0 then
            hrp.CFrame = CFrame.new(targetPos.X, cur.Y, targetPos.Z)
        elseif distXZ >= TELEPORT_DIST_XZ then
            local step = math.min(STEP_XZ, distXZ)
            local nx, nz = dx / distXZ, dz / distXZ
            hrp.CFrame = CFrame.new(cur.X + nx * step, cur.Y, cur.Z + nz * step)
        end

        local velY = 0
        if dy > Y_TOLERANCE then
            velY = math.min(Y_UP_SPEED, dy * 2)
        elseif dy < -Y_TOLERANCE then
            velY = -20
        end
        bv.Velocity = Vector3.new(0, velY, 0)

        if tick() - lastLogAt >= 2 then
            lastLogAt = tick()
            LOG("Move", string.format("hold dxz=%.1f dy=%.1f velY=%.1f", distXZ, dy, velY))
        end

        task.wait()
    end

    -- ВАЖНО: НЕ отпускаем персонажа. BodyVelocity виснет, PlatformStand=true.
    bv.Velocity = Vector3.zero
    LOG("Move", "hold: дошли, зависли в воздухе")
    return true
end

local function faceTowards(targetPoint)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    local myPos = hrp.Position
    local flatDir = Vector3.new(targetPoint.X - myPos.X, 0, targetPoint.Z - myPos.Z)
    if flatDir.Magnitude < 1e-4 then return end

    local cf = CFrame.lookAt(myPos, myPos + flatDir.Unit)
    hum.AutoRotate = false
    hrp.CFrame = cf

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 50000
    bg.D = 500
    bg.CFrame = cf
    bg.Parent = hrp

    task.wait(0.3)
    bg:Destroy()
end

-- Порядок: летим (коллизии OFF) → восстановили коллизии → отпустили
-- → упали на 50 стадов на пол → развернулись
local function goToAndFace(targetPos, lookAtPoint)
    -- 1) летим с коллизиями OFF, держим PlatformStand=true
    goToPositionHoldAir(targetPos)
    task.wait(0.3)

    -- 2) коллизии ON, пока персонаж висит (пол включится под ним)
    collisionsDisabledGlobal = false
    restoreCollisionsNow()
    task.wait(1.0)

    -- 3) отпускаем — падает на пол (коллизии уже работают)
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        hum.PlatformStand = false
        local bv = hrp:FindFirstChildOfClass("BodyVelocity")
        if bv then bv:Destroy() end
    end
    task.wait(1.5)   -- время упасть и устаканиться

    -- 4) разворот
    faceTowards(lookAtPoint)
end

-- ============================================================
-- HTTP
-- ============================================================
local function requestMatch()
    local url = SERVER_URL
        .. "/match?nickname=" .. HttpService:UrlEncode(player.Name)
        .. "&job_id="    .. HttpService:UrlEncode(game.JobId)
    local ok, resp = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil, "http fail: " .. tostring(resp) end
    local ok2, data = pcall(function() return HttpService:JSONDecode(resp) end)
    if not ok2 or type(data) ~= "table" then
        return nil, "bad json: " .. tostring(resp)
    end
    return data
end

local function requestUnmatch()
    local url = SERVER_URL
        .. "/unmatch?nickname=" .. HttpService:UrlEncode(player.Name)
    pcall(function() return game:HttpGet(url) end)
end

-- ============================================================
-- FRUIT HELPERS
-- ============================================================
local function hasFruitTool()
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    for _, cont in ipairs({char, backpack}) do
        if cont then
            for _, ch in ipairs(cont:GetChildren()) do
                if ch:IsA("Tool") and string.find(string.lower(ch.Name), "fruit", 1, true) then
                    return ch
                end
            end
        end
    end
    return nil
end

local function waitFruitTool()
    while State.running do
        local t = hasFruitTool()
        if t then return t end
        task.wait(0.2)
    end
    return nil
end

local function eatFruitDrop()
    local char = player.Character
    if not char then return false, "нет Character" end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false, "нет Humanoid" end

    local tool = hasFruitTool()
    if not tool then return false, "fruit-tool не найден" end

    if tool.Parent ~= char then
        hum:EquipTool(tool)
    end

    if tool.Parent ~= char then
        local t0 = tick()
        while tool.Parent ~= char and tick() - t0 < 2 do
            task.wait()
        end
    end

    if tool.Parent ~= char then
        return false, "не экипировалось: " .. tool.Name
    end

    task.wait(1)

    local eatRemote = tool:FindFirstChild("EatRemote")
    if not eatRemote or not eatRemote:IsA("RemoteFunction") then
        return false, "нет EatRemote"
    end

    local ok, result = pcall(function()
        return eatRemote:InvokeServer("Drop")
    end)
    if not ok then return false, "eat error: " .. tostring(result) end
    return true, result
end

-- ============================================================
-- CLAIM QUEST
-- ============================================================
local function claimQuestOnce()
    if not RF_InteractDragonQuest then return false, "no RF" end
    local ok, resp = pcall(function()
        return RF_InteractDragonQuest:InvokeServer({
            NPC = POST_TRADE_NPC_NAME,
            Command = "ClaimQuest"
        })
    end)
    if not ok then return false, resp end
    return true, resp
end

-- ============================================================
-- ОСНОВНАЯ ФУНКЦИЯ
-- ============================================================
local function runGreenMode()
    State.mode = "green"
    LOG("Green", "=== START ===")

    -- 1) Матч
    local match = nil
    while State.running and not match do
        local data, err = requestMatch()
        if not data then
            WARN("Green", "match error: " .. tostring(err))
            task.wait(3)
        elseif data.waiting then
            LOG("Green", "waiting for partner...")
            task.wait(3)
        else
            match = data
        end
    end
    if not match then State.mode = "none"; return end

    LOG("Green", "role=" .. tostring(match.role)
        .. " partner=" .. tostring(match.partner_name))

    -- 2) Хаб
    if not waitForHubReady() then
        State.mode = "none"; return
    end

    -- 3) Guest телепорт
    if match.role == "guest"
       and match.job_id and match.job_id ~= ""
       and match.job_id ~= game.JobId then

        LOG("Green", "guest: телепорт на " .. tostring(match.job_id))

        local teleported = false
        for attempt = 1, 5 do
            if teleportToJobId(match.job_id) then
                local w = 0
                while w < 30 and game.JobId ~= match.job_id do
                    task.wait(1); w += 1
                end
                if game.JobId == match.job_id then
                    teleported = true
                    break
                end
            end
            LOG("Green", "guest: телепорт попытка #" .. attempt .. " не удалась, повтор")
            task.wait(2)
        end

        if not teleported then
            WARN("Green", "guest: телепорт не удался — выход")
            requestUnmatch()
            State.mode = "none"
            return
        end

        LOG("Green", "guest: перелетели, ждём загрузку")
        task.wait(8)
        requestMatch()
    end

    -- 4) Позиция + разворот на партнёра
    local myPos, partnerPos
    if match.role == "host" then
        myPos, partnerPos = GREEN_HOST_POS, GREEN_GUEST_POS
    else
        myPos, partnerPos = GREEN_GUEST_POS, GREEN_HOST_POS
    end

    LOG("Green", "goTo " .. string.format("(%.1f,%.1f,%.1f)",
        myPos.X, myPos.Y, myPos.Z))
    LOG("Green", "looking at partner " .. string.format("(%.1f,%.1f,%.1f)",
        partnerPos.X, partnerPos.Y, partnerPos.Z))

    -- коллизии OFF → летим → коллизии ON → отпускаем → падаем на пол
    collisionsDisabledGlobal = true
    disableCollisionsNow()
    task.wait(0.3)
    goToAndFace(myPos, partnerPos)
    task.wait(0.5)

    -- Лог позиции
    do
        local c = player.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then
            local d = hrp.Position - myPos
            LOG("Green", string.format(
                "позиция (%.1f,%.1f,%.1f) Δ=(%.1f,%.1f,%.1f)",
                hrp.Position.X, hrp.Position.Y, hrp.Position.Z,
                d.X, d.Y, d.Z))
        end
    end

    -- 5) Host: 7,7 ON → ждём fruit → 7,7 OFF
    if match.role == "host" then
        LOG("Green", "host: 7,7 ON")
        local ok77 = ensureOptionOn(TAB_FRUIT, OPT_FRUIT)
        LOG("Green", "host: 7,7 ON result = " .. tostring(ok77))
        if not ok77 then
            WARN("Green", "host: НЕ УДАЛОСЬ включить 7,7")
        end

        LOG("Green", "host: ждём fruit-tool...")
        local tool = waitFruitTool()
        LOG("Green", "host: fruit появился = " .. tostring(tool and tool.Name))

        LOG("Green", "host: 7,7 OFF")
        local off77 = ensureOptionOff(TAB_FRUIT, OPT_FRUIT)
        LOG("Green", "host: 7,7 OFF result = " .. tostring(off77))
    else
        LOG("Green", "guest: 7,7 не трогаю (активирует host)")
    end

    -- 6) Ping-pong
    local claimedMe = false
    local iteration = 0

    while State.running and not claimedMe do
        iteration += 1

        if match.role == "host" then
            LOG("Green", "host #" .. iteration .. ": drop")
            local ok, err = eatFruitDrop()
            if not ok then WARN("Green", "eat: " .. tostring(err)) end

            local _, resp = claimQuestOnce()
            LOG("Green", "host #" .. iteration .. ": ClaimQuest → " .. tostring(resp))
            if resp == true then claimedMe = true; break end

            LOG("Green", "host #" .. iteration .. ": ждём от guest")
            waitFruitTool()
        else
            LOG("Green", "guest #" .. iteration .. ": ждём от host")
            waitFruitTool()

            LOG("Green", "guest #" .. iteration .. ": drop")
            local ok, err = eatFruitDrop()
            if not ok then WARN("Green", "eat: " .. tostring(err)) end

            local _, resp = claimQuestOnce()
            LOG("Green", "guest #" .. iteration .. ": ClaimQuest → " .. tostring(resp))
            if resp == true then claimedMe = true; break end
        end
    end

    LOG("Green", "=== DONE claimed=" .. tostring(claimedMe) .. " ===")

    requestUnmatch()
    State.mode = "none"
end

-- ============================================================
-- ЗАПУСК
-- ============================================================
LOG("Main", "=== GREEN TEST START === Me: " .. player.Name)
runGreenMode()
LOG("Main", "=== GREEN TEST END ===")
