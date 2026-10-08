--!nocheck
-- ============================================================
-- GREEN MODE v13 — 3 drops + claim + подтверждение от Flask
-- Хост: 8,7 ON → fruit → 8,7 OFF → drop#1 → ждём fruit от guest
--       → drop#2 (guest остаётся с фруктом) → claim
-- Гест: ждём fruit#1 → drop#1 → ждём fruit#2 → claim
-- После claim — report на сервер, ждём both_ok, потом 6,1 ON.
-- ============================================================

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- ============================================================
-- КОНФИГ
-- ============================================================
local SERVER_URL          = "http://192.168.31.179:8000"
local POST_TRADE_NPC_NAME = "Dojo Trainer"

local GREEN_HOST_POS  = Vector3.new(5842.3, 1208.6, 886.3)
local GREEN_GUEST_POS = Vector3.new(5847.1, 1208.6, 882.4)

local MOVE_SPEED            = 250
local POS_TOLERANCE         = 8
local PARTNER_POS_TOLERANCE = 50

local DROP_TIMING          = 2   -- пауза после получения фрукта, перед дропом
local DROP_RETRY_DELAY     = 2   -- пауза между попытками дропа
local DROP_CONFIRM_TIMEOUT = 6   -- сколько ждём появление фрукта у партнёра

local CLAIM_RETRY_DELAY    = 3
local SERVER_POLL_DELAY    = 2
local SERVER_POLL_TIMEOUT  = 60

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local TAB_FRUIT, OPT_FRUIT   = 8, 7
local TAB_TOGGLE, OPT_TOGGLE = 6, 1

local TELEPORT_TAB          = 19
local TELEPORT_OPT_TEXT     = 2
local TELEPORT_OPT_ACTIVATE = 3

-- ============================================================
-- LOG
-- ============================================================
local T0 = tick()
local function LOG(t, m) print(string.format("[%7.2fs][%s] %s", tick()-T0, t, m)) end
local function WARN(t, m) warn(string.format("[%7.2fs][%s] %s", tick()-T0, t, m)) end
local State = { running = true }

-- ============================================================
-- RF
-- ============================================================
local RF_InteractDragonQuest = nil
do
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local net = modules and modules:FindFirstChild("Net")
    RF_InteractDragonQuest = net and net:FindFirstChild("RF/InteractDragonQuest")
end

-- ============================================================
-- HUB helpers
-- ============================================================
local function getRoot()
    for _, ch in ipairs(CoreGui:GetChildren()) do
        local o = ch:FindFirstChild("redz-library-v5")
        if o then return o end
    end
end
local function safeFind(o, ...)
    for _, n in ipairs({...}) do
        if not o then return nil end
        o = o:FindFirstChild(n)
    end
    return o
end
local function fireSequence(btn)
    if not btn then return end
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local ev = btn[sig]
        if ev then
            for _, c in ipairs(getconnections(ev) or {}) do
                if c.Enabled then pcall(c.Function) end
            end
        end
    end
end
local function findIndicatorFrame(parent)
    for _, ch in ipairs(parent:GetChildren()) do
        if ch:IsA("Frame") then
            local c = tostring(ch.BackgroundColor3)
            if c == COLOR_ON or c == COLOR_OFF then return ch end
        end
        local f = findIndicatorFrame(ch)
        if f then return f end
    end
end
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
local function getOptionState(tabIndex, optIndex)
    local root = getRoot() if not root then return nil end
    local ts = safeFind(root, "Window","Components","TabsScroll")
    if not ts then return nil end
    local tb = findNthTabButton(ts, tabIndex)
    if not tb then return nil end
    fireSequence(tb) task.wait(0.3)
    local cont = safeFind(root, "Window","Components","Containers","Container")
    if not cont then return nil end
    local ob = findNthOption(cont, optIndex)
    if not ob then return nil end
    local ind = findIndicatorFrame(ob)
    if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    if col == COLOR_ON then return "on" end
    if col == COLOR_OFF then return "off" end
end
local function setOptionState(tabIndex, optIndex, desired)
    if desired ~= "on" and desired ~= "off" then return false end
    local root = getRoot() if not root then return false end
    local ts = safeFind(root, "Window","Components","TabsScroll")
    if not ts then return false end
    local tb = findNthTabButton(ts, tabIndex)
    if not tb then return false end
    fireSequence(tb) task.wait(0.3)
    local cont = safeFind(root, "Window","Components","Containers","Container")
    if not cont then return false end
    local ob = findNthOption(cont, optIndex)
    if not ob then return false end
    local ind = findIndicatorFrame(ob)
    if not ind then return false end
    local isOn = (tostring(ind.BackgroundColor3) == COLOR_ON)
    local wantOn = (desired == "on")
    if isOn == wantOn then return true end
    fireSequence(ob) task.wait(0.1)
    return true
end
local function ensureOptionOn(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == "on" then return true end
        setOptionState(tabIndex, optIndex, "on")
        task.wait(0.4)
    end
end
local function ensureOptionOff(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == "off" then return true end
        setOptionState(tabIndex, optIndex, "off")
        task.wait(0.4)
    end
end
local function waitForHubReady()
    while State.running and not (getRoot() and safeFind(getRoot(),"Window","Components","TabsScroll")) do
        task.wait(0.5)
    end
    LOG("Hub", "готов")
end

-- ============================================================
-- ТЕЛЕПОРТ
-- ============================================================
local function teleportToJobId(jobId)
    local root = getRoot() if not root then return false end
    local ts = safeFind(root, "Window","Components","TabsScroll")
    if not ts then return false end
    local tb = findNthTabButton(ts, TELEPORT_TAB)
    if not tb then return false end
    fireSequence(tb) task.wait(0.5)
    local cont = safeFind(root, "Window","Components","Containers","Container")
    if not cont then return false end
    local optText = findNthOption(cont, TELEPORT_OPT_TEXT)
    if not optText then return false end
    local function findTB(p)
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextBox") then return c end
            local f = findTB(c) if f then return f end
        end
    end
    local tx = findTB(optText)
    if not tx then return false end
    tx:CaptureFocus() task.wait(0.2)
    tx.Text = jobId   task.wait(0.2)
    tx:ReleaseFocus(true) task.wait(0.3)
    local optAct = findNthOption(cont, TELEPORT_OPT_ACTIVATE)
    if not optAct then return false end
    fireSequence(optAct)
    return true
end

-- ============================================================
-- NOCLIP
-- ============================================================
local function enableNoclip(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then d.CanCollide = false end
    end)
end
player.CharacterAdded:Connect(function(char) task.wait(0.3) enableNoclip(char) end)
if player.Character then enableNoclip(player.Character) end

-- ============================================================
-- ПОЗИЦИЯ / МАГНИТ
-- ============================================================
local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local MAGNET = { active = false, pos = nil, look = nil }

RunService.Heartbeat:Connect(function()
    if not MAGNET.active or not MAGNET.pos then return end
    local hrp = getHRP()
    if not hrp then return end
    local dir = Vector3.new(MAGNET.look.X - MAGNET.pos.X, 0, MAGNET.look.Z - MAGNET.pos.Z)
    if dir.Magnitude < 1e-4 then dir = Vector3.new(0,0,1) end
    hrp.CFrame = CFrame.lookAt(MAGNET.pos, MAGNET.pos + dir.Unit)
    hrp.AssemblyLinearVelocity  = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end)

local function magnetStart(pos, look)
    MAGNET.pos, MAGNET.look = pos, look
    MAGNET.active = true
    -- разово телепортим, дальше heartbeat будет держать
    local hrp = getHRP()
    if hrp then
        local dir = Vector3.new(look.X - pos.X, 0, look.Z - pos.Z)
        if dir.Magnitude < 1e-4 then dir = Vector3.new(0,0,1) end
        hrp.CFrame = CFrame.lookAt(pos, pos + dir.Unit)
    end
end
local function magnetStop()
    MAGNET.active = false
end

-- ============================================================
-- FRUIT
-- ============================================================
local function isFruitTool(obj)
    return obj and obj:IsA("Tool") and string.find(string.lower(obj.Name), "fruit", 1, true) ~= nil
end
local function findFruitTool()  -- в моём char/backpack
    local char = player.Character
    local bp = player:FindFirstChild("Backpack")
    for _, cont in ipairs({char, bp}) do
        if cont then
            for _, ch in ipairs(cont:GetChildren()) do
                if isFruitTool(ch) then return ch end
            end
        end
    end
    return nil
end
local function charFruit(plr)  -- fruit Tool внутри Character у произвольного игрока
    local c = plr and plr.Character
    if not c then return nil end
    for _, ch in ipairs(c:GetChildren()) do
        if isFruitTool(ch) then return ch end
    end
    return nil
end
local function waitFruitInSelf()
    local last = 0
    local t0 = tick()
    while State.running do
        local t = findFruitTool()
        if t then return t end
        local el = tick() - t0
        if el - last >= 5 then
            last = el
            LOG("Wait", string.format("ждём fruit у себя... %.0fs", el))
        end
        task.wait(0.2)
    end
end
local function waitFruitInPartner(name, timeout)
    local t0 = tick()
    while State.running do
        local p = Players:FindFirstChild(name)
        if p and charFruit(p) then return true end
        if tick() - t0 > timeout then return false end
        task.wait(0.15)
    end
    return false
end

local function equipFruit()
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local tool = findFruitTool()
    if not tool then return nil end
    if tool.Parent ~= char then
        hum:EquipTool(tool)
        task.wait(0.3)
    end
    if tool.Parent ~= char then return nil end
    return tool
end

-- дроп одного фрукта с подтверждением появления у партнёра
local function dropOnce(partnerName)
    local tool = equipFruit()
    if not tool then return false, "нет fruit для дропа" end
    local eatRemote = tool:FindFirstChild("EatRemote")
    if not eatRemote or not eatRemote:IsA("RemoteFunction") then
        return false, "нет EatRemote"
    end
    local ok, res = pcall(function() return eatRemote:InvokeServer("Drop") end)
    LOG("Drop", "invoke ok=" .. tostring(ok) .. " res=" .. tostring(res))
    if not ok then return false, "invoke err" end
    -- успех = появился fruit в character партнёра
    if waitFruitInPartner(partnerName, DROP_CONFIRM_TIMEOUT) then
        return true
    end
    return false, "fruit не появился у партнёра"
end

local function dropWithRetry(partnerName, tag)
    local i = 0
    while State.running do
        i += 1
        if not findFruitTool() then
            -- может уже улетел и подтвердилось
            if waitFruitInPartner(partnerName, 1.5) then
                LOG(tag, "fruit уже у партнёра — ок")
                return true
            end
            return false, "нет fruit локально"
        end
        local ok, err = dropOnce(partnerName)
        if ok then
            LOG(tag, "drop #" .. i .. " OK")
            return true
        end
        LOG(tag, "drop #" .. i .. " FAIL: " .. tostring(err))
        task.wait(DROP_RETRY_DELAY)
    end
end

-- ============================================================
-- HTTP
-- ============================================================
local function httpGet(url)
    local ok, resp = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil, tostring(resp) end
    local ok2, data = pcall(function() return HttpService:JSONDecode(resp) end)
    if not ok2 or type(data) ~= "table" then return nil, "bad json: " .. tostring(resp) end
    return data
end

local function requestMatch()
    return httpGet(SERVER_URL
        .. "/match?nickname=" .. HttpService:UrlEncode(player.Name)
        .. "&job_id="    .. HttpService:UrlEncode(game.JobId))
end
local function requestUnmatch()
    pcall(function()
        return game:HttpGet(SERVER_URL .. "/unmatch?nickname=" .. HttpService:UrlEncode(player.Name))
    end)
end
local function reportClaim(success)
    pcall(function()
        return game:HttpGet(SERVER_URL
            .. "/claim_result?nickname=" .. HttpService:UrlEncode(player.Name)
            .. "&ok=" .. tostring(success))
    end)
end
local function checkClaimBothOk()
    local d = httpGet(SERVER_URL .. "/claim_check?nickname=" .. HttpService:UrlEncode(player.Name))
    return d and d.both_ok == true
end
local function requestSwap()
    local d = httpGet(SERVER_URL .. "/swap_roles?nickname=" .. HttpService:UrlEncode(player.Name))
    return d and d.my_role
end

-- ============================================================
-- CLAIM
-- ============================================================
local function tryClaim()
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
-- ОСНОВНАЯ ЛОГИКА
-- ============================================================
local function partnerAtCoords(partnerName, coords)
    local p = Players:FindFirstChild(partnerName)
    local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, math.huge end
    local d = (hrp.Position - coords).Magnitude
    return d <= PARTNER_POS_TOLERANCE, d
end

local function waitPartnerAtCoords(partnerName, coords)
    local last = 0
    local t0 = tick()
    while State.running do
        local ok, d = partnerAtCoords(partnerName, coords)
        if ok then
            LOG("Wait", string.format("партнёр на координатах (d=%.1f)", d))
            return true
        end
        local el = tick() - t0
        if el - last >= 5 then
            last = el
            LOG("Wait", string.format("ждём партнёра на координатах... d=%.1f", d))
        end
        task.wait(0.5)
    end
end

-- последовательность дропов для host'а
local function hostSequence(partnerName)
    LOG("Host", "8,7 ON — получаем fruit")
    ensureOptionOn(TAB_FRUIT, OPT_FRUIT)
    waitFruitInSelf()
    LOG("Host", "8,7 OFF")
    ensureOptionOff(TAB_FRUIT, OPT_FRUIT)

    task.wait(DROP_TIMING)
    LOG("Host", "drop #1 → " .. partnerName)
    dropWithRetry(partnerName, "host-drop1")

    LOG("Host", "ждём fruit обратно от " .. partnerName)
    waitFruitInSelf()
    task.wait(DROP_TIMING)

    LOG("Host", "drop #2 → " .. partnerName)
    dropWithRetry(partnerName, "host-drop2")
end

-- последовательность для guest'а
local function guestSequence(partnerName)
    LOG("Guest", "ждём fruit #1 от " .. partnerName)
    waitFruitInSelf()
    task.wait(DROP_TIMING)
    LOG("Guest", "drop #1 → " .. partnerName)
    dropWithRetry(partnerName, "guest-drop1")

    LOG("Guest", "ждём fruit #2 от " .. partnerName)
    waitFruitInSelf()
end

-- claim + report + ждём both_ok от сервера (с повтором claim)
local function claimAndWaitServer()
    while State.running do
        local ok, resp = tryClaim()
        local success = (ok and resp == true)
        LOG("Claim", "tryClaim ok=" .. tostring(ok) .. " resp=" .. tostring(resp))
        reportClaim(success)

        local t0 = tick()
        while State.running and tick() - t0 < SERVER_POLL_TIMEOUT do
            if checkClaimBothOk() then
                LOG("Claim", "★ оба подтвердили — сервер OK")
                return true
            end
            task.wait(SERVER_POLL_DELAY)
        end
        LOG("Claim", "таймаут ожидания сервера — повтор")
        task.wait(CLAIM_RETRY_DELAY)
    end
    return false
end

local function runGreenMode()
    LOG("Green", "=== START ===")

    local match = nil
    while State.running and not match do
        local data, err = requestMatch()
        if not data then
            WARN("Green", "match err: " .. tostring(err)); task.wait(3)
        elseif data.waiting then
            LOG("Green", "waiting for partner..."); task.wait(3)
        else
            match = data
        end
    end
    if not match then return end

    LOG("Green", "role=" .. tostring(match.role) .. " partner=" .. tostring(match.partner_name))

    waitForHubReady()

    -- guest: телепорт
    if match.role == "guest" and match.job_id and match.job_id ~= "" and match.job_id ~= game.JobId then
        LOG("Green", "guest: телепорт на " .. match.job_id)
        while State.running and game.JobId ~= match.job_id do
            teleportToJobId(match.job_id)
            task.wait(3)
            requestMatch()
        end
        task.wait(8)
        requestMatch()
    end

    -- 6,1 OFF на старте
    LOG("Green", "6,1 OFF")
    ensureOptionOff(TAB_TOGGLE, OPT_TOGGLE)

    local myPos, partnerPos
    if match.role == "host" then
        myPos, partnerPos = GREEN_HOST_POS, GREEN_GUEST_POS
    else
        myPos, partnerPos = GREEN_GUEST_POS, GREEN_HOST_POS
    end

    -- магнит
    LOG("Green", "магнит → моя позиция")
    magnetStart(myPos, partnerPos)

    -- ждём партнёра
    waitPartnerAtCoords(match.partner_name, partnerPos)

    -- последовательность
    if match.role == "host" then
        hostSequence(match.partner_name)
    else
        guestSequence(match.partner_name)
    end

    -- claim + сервер
    if not claimAndWaitServer() then return end

    -- отключаем магнит, включаем 6,1
    LOG("Green", "магнит OFF, 6,1 ON")
    magnetStop()
    ensureOptionOn(TAB_TOGGLE, OPT_TOGGLE)

    LOG("Green", "=== DONE ===")
    requestUnmatch()
end

LOG("Main", "=== GREEN TEST START === " .. player.Name)
runGreenMode()
LOG("Main", "=== GREEN TEST END ===")
