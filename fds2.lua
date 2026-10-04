--!nocheck
-- ============================================================
-- GREEN MODE — v12 (без таймаутов, всё ждём бесконечно)
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ============================================================
-- КОНФИГ
-- ============================================================
local SERVER_URL          = "http://192.168.1.100:8000"
local POST_TRADE_NPC_NAME = "Dojo Trainer"

local GREEN_HOST_POS   = Vector3.new(5842.3, 1208.6, 886.3)
local GREEN_GUEST_POS  = Vector3.new(5847.1, 1208.6, 882.4)

local MOVE_SPEED          = 250
local POS_TOLERANCE       = 8

local PARTNER_NEAR_RADIUS = 30

local CLAIM_RETRY_DELAY   = 2

local DELAY_AFTER_ARRIVE  = 2
local DELAY_AFTER_DROP    = 2
local DELAY_BEFORE_CLAIM  = 5
local DELAY_AFTER_CLAIM   = 5
local DELAY_BEFORE_DROP2  = 2

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local TAB_FRUIT, OPT_FRUIT   = 8, 7
local TAB_TOGGLE, OPT_TOGGLE = 6, 1

local TELEPORT_TAB          = 19
local TELEPORT_OPT_TEXT     = 2
local TELEPORT_OPT_ACTIVATE = 3

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

local State = { running = true, mode = "none" }

-- ============================================================
-- RF
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
-- ХАБ
-- ============================================================
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
end
local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end
local function waitForInterface()
    return getRoot() and safeFind(getRoot(), "Window", "Components", "TabsScroll")
end
local function fireSequence(btn)
    if not btn then return end
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then pcall(conn.Function) end
            end
        end
    end
end
local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local c = tostring(child.BackgroundColor3)
            if c == COLOR_ON or c == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child)
        if found then return found end
    end
end
local function getOptionState(tabIndex, optIndex)
    local root = getRoot() if not root then return nil end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == tabIndex then tabButton = c; return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not tabButton then return nil end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == optIndex then optionBtn = c; break end
        end
    end
    if not optionBtn then return nil end
    local ind = findIndicatorFrame(optionBtn)
    if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    if col == COLOR_ON then return "on" end
    if col == COLOR_OFF then return "off" end
    return nil
end
local function setOptionState(tabIndex, optIndex, desiredState)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot() if not root then return false end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return false end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == tabIndex then tabButton = c; return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not tabButton then return false end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return false end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == optIndex then optionBtn = c; break end
        end
    end
    if not optionBtn then return false end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return false end
    local isOn = (tostring(indicator.BackgroundColor3) == COLOR_ON)
    local wantOn = (desiredState == "on")
    if isOn == wantOn then return true end
    fireSequence(optionBtn) task.wait(0.1)
    return true
end

-- ★ БЕЗ ЛИМИТА ПОПЫТОК — долбим пока не получим нужное состояние
local function ensureOptionOn(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == "on" then return true end
        setOptionState(tabIndex, optIndex, "on")
        task.wait(0.4)
    end
    return false
end
local function ensureOptionOff(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == "off" then return true end
        setOptionState(tabIndex, optIndex, "off")
        task.wait(0.4)
    end
    return false
end
local function waitForHubReady()
    while State.running and not waitForInterface() do
        task.wait(0.5)
    end
    LOG("Hub", "готов")
    return true
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
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p:GetPropertyChangedSignal("CanCollide"):Connect(function()
                if p.CanCollide then p.CanCollide = false end
            end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end
end
player.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    enableNoclip(char)
end)

-- ============================================================
-- ПОЗИЦИЯ / ДВИЖЕНИЕ
-- ============================================================
local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function isOnSpot(targetPos, tol)
    tol = tol or POS_TOLERANCE
    local hrp = getHRP()
    if not hrp then return false, math.huge end
    local d = (hrp.Position - targetPos).Magnitude
    return d <= tol, d
end
local function snapToSpot(targetPos, lookAtPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    enableNoclip(char)
    local lookDir
    if lookAtPos then
        lookDir = Vector3.new(lookAtPos.X - targetPos.X, 0, lookAtPos.Z - targetPos.Z)
    end
    if not lookDir or lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(0,0,1) end
    hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir.Unit)
    return true
end

local function goToAndFace(targetPos, lookAtPoint, speed)
    speed = speed or MOVE_SPEED
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end

    enableNoclip(char)

    local startPos = hrp.Position
    local delta    = targetPos - startPos
    local dist     = delta.Magnitude

    local lookSrc = lookAtPoint or targetPos
    local lookDir = Vector3.new(lookSrc.X - targetPos.X, 0, lookSrc.Z - targetPos.Z)
    if lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(delta.X, 0, delta.Z) end
    if lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(0, 0, 1) end
    lookDir = lookDir.Unit

    if dist < 0.1 then
        hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir)
        return true
    end

    local duration = dist / speed
    local elapsed  = 0
    LOG("Green", string.format("идём за %.2fs к (%.1f,%.1f,%.1f)",
        duration, targetPos.X, targetPos.Y, targetPos.Z))

    while elapsed < duration do
        elapsed += RunService.Heartbeat:Wait()
        local a   = math.min(elapsed / duration, 1)
        local pos = startPos:Lerp(targetPos, a)
        hrp.CFrame = CFrame.lookAt(pos, pos + lookDir)
    end

    hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir)
    task.wait(0.05)
    local ok, d = isOnSpot(targetPos)
    LOG("Green", string.format("встал на (%.1f,%.1f,%.1f) dist=%.2f onSpot=%s",
        hrp.Position.X, hrp.Position.Y, hrp.Position.Z, d, tostring(ok)))
    return ok
end

-- ============================================================
-- ★ ЖДЁМ ПАРТНЁРА РЯДОМ (без таймаута — бесконечно)
-- ============================================================
local function waitPartnerNearby(partnerName, radius)
    radius = radius or PARTNER_NEAR_RADIUS
    local lastLog = 0
    local t0 = tick()
    while State.running do
        local myHrp = getHRP()
        local partner = Players:FindFirstChild(partnerName)
        local partnerHrp = partner
            and partner.Character
            and partner.Character:FindFirstChild("HumanoidRootPart")
        if myHrp and partnerHrp then
            local d = (myHrp.Position - partnerHrp.Position).Magnitude
            if d <= radius then
                LOG("Wait", string.format("★ партнёр %s рядом (dist=%.1f ≤ %d)",
                    partnerName, d, radius))
                return true, d
            end
            if tick() - t0 - lastLog >= 5 then
                lastLog = tick() - t0
                LOG("Wait", string.format("жду партнёра %s... dist=%.1f (нужно ≤ %d)",
                    partnerName, d, radius))
            end
        else
            if tick() - t0 - lastLog >= 5 then
                lastLog = tick() - t0
                LOG("Wait", "жду партнёра... (персонаж ещё не заспавнился)")
            end
        end
        task.wait(0.5)
    end
    return false, nil
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
-- INVENTORY / FRUIT
-- ============================================================
local function findFruitTool()
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
local function dumpInventory(tag)
    local char = player.Character
    local bp = player:FindFirstChild("Backpack")
    LOG(tag, "--- INVENTORY ---")
    if char then
        local any = false
        for _, ch in ipairs(char:GetChildren()) do
            if ch:IsA("Tool") then LOG(tag, "  [EQUIPPED] " .. ch.Name); any = true end
        end
        if not any then LOG(tag, "  [EQUIPPED] (пусто)") end
    end
    if bp then
        local any = false
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") then LOG(tag, "  [BACKPACK] " .. ch.Name); any = true end
        end
        if not any then LOG(tag, "  [BACKPACK] (пусто)") end
    end
    LOG(tag, "-----------------")
end

-- ★ БЕЗ ТАЙМАУТА — ждём фрукт бесконечно
local function waitFruitTool()
    local lastLog = 0
    local t0 = tick()
    while State.running do
        local t = findFruitTool()
        if t then return t end
        if tick() - t0 - lastLog >= 5 then
            lastLog = tick() - t0
            LOG("Wait", string.format("жду fruit-tool... (%.0fs)", lastLog))
        end
        task.wait(0.2)
    end
    return nil
end

local function eatFruitDrop()
    local char = player.Character
    if not char then return false, "нет Character" end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false, "нет Humanoid" end
    local tool = findFruitTool()
    if not tool then
        dumpInventory("eatFruitDrop")
        return false, "fruit-tool не найден"
    end
    LOG("Eat", "найден tool: " .. tool.Name .. " (parent=" .. tool.Parent.Name .. ")")
    if tool.Parent ~= char then
        hum:EquipTool(tool)
        task.wait(0.5)
    end
    if tool.Parent ~= char then return false, "не экипировалось: " .. tool.Name end
    LOG("Eat", "tool экипирован")
    local eatRemote = tool:FindFirstChild("EatRemote")
    if not eatRemote or not eatRemote:IsA("RemoteFunction") then
        return false, "нет EatRemote"
    end
    LOG("Eat", "вызываю EatRemote:InvokeServer(\"Drop\")")
    local ok, result = pcall(function()
        return eatRemote:InvokeServer("Drop")
    end)
    LOG("Eat", "ответ: ok=" .. tostring(ok) .. " result=" .. tostring(result))
    if not ok then return false, "eat error: " .. tostring(result) end
    return true, result
end

-- ============================================================
-- CLAIM QUEST
-- ============================================================
local function tryClaimQuest(myPos, tag)
    tag = tag or "Claim"
    if not RF_InteractDragonQuest then return false, "no RF" end
    if myPos then
        local ok, d = isOnSpot(myPos)
        if not ok then
            WARN(tag, string.format("сдвинуло (dist=%.2f) — snap", d))
            snapToSpot(myPos, nil); task.wait(0.1)
        end
    end
    LOG(tag, "отправляю ClaimQuest...")
    local sOk, resp = pcall(function()
        return RF_InteractDragonQuest:InvokeServer({
            NPC = POST_TRADE_NPC_NAME,
            Command = "ClaimQuest"
        })
    end)
    LOG(tag, "ответ: ok=" .. tostring(sOk) .. " resp=" .. tostring(resp))
    if not sOk then return false, resp end
    return true, resp
end

-- ★ БЕЗ ЛИМИТА ПОПЫТОК — долбим claim пока не вернёт true
local function claimLoop(myPos, tag)
    tag = tag or "Claim"
    local i = 0
    while State.running do
        i += 1
        LOG(tag, "=== попытка " .. i .. " ===")
        local ok, resp = tryClaimQuest(myPos, tag)
        if ok and resp == true then
            LOG(tag, "УСПЕХ на попытке " .. i)
            return true
        end
        if myPos then
            local onSpot = isOnSpot(myPos)
            if not onSpot then snapToSpot(myPos, nil) end
        end
        task.wait(CLAIM_RETRY_DELAY)
    end
    return false
end

-- ============================================================
-- ОСНОВНАЯ ФУНКЦИЯ
-- ============================================================
local function runGreenMode()
    State.mode = "green"
    LOG("Green", "=== START ===")

    local match = nil
    while State.running and not match do
        local data, err = requestMatch()
        if not data then
            WARN("Green", "match error: " .. tostring(err)); task.wait(3)
        elseif data.waiting then
            LOG("Green", "waiting for partner..."); task.wait(3)
        else
            match = data
        end
    end
    if not match then State.mode = "none"; return end

    LOG("Green", "role=" .. tostring(match.role)
        .. " partner=" .. tostring(match.partner_name))
    LOG("Green", "match data: " .. HttpService:JSONEncode(match))

    if not waitForHubReady() then State.mode = "none"; return end

    -- Guest телепорт
    if match.role == "guest"
       and match.job_id and match.job_id ~= ""
       and match.job_id ~= game.JobId then
        LOG("Green", "guest: телепорт на " .. tostring(match.job_id))
        local teleported = false
        while State.running and not teleported do
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
            LOG("Green", "guest: телепорт не удался, повтор"); task.wait(2)
        end
        LOG("Green", "guest: перелетели, ждём загрузку")
        task.wait(8)
        requestMatch()
    end

    -- 6,1 OFF перед движением
    LOG("Green", "★ проверяю (" .. TAB_TOGGLE .. "," .. OPT_TOGGLE .. ") — должно быть OFF")
    local st = getOptionState(TAB_TOGGLE, OPT_TOGGLE)
    LOG("Green", "  текущее: " .. tostring(st))
    if st ~= "off" then
        LOG("Green", "  выключаю (" .. TAB_TOGGLE .. "," .. OPT_TOGGLE .. ")")
        local okOff = ensureOptionOff(TAB_TOGGLE, OPT_TOGGLE)
        LOG("Green", "  ensureOptionOff = " .. tostring(okOff))
    else
        LOG("Green", "  уже OFF — ок")
    end

    -- Позиции
    local myPos, partnerPos
    if match.role == "host" then
        myPos, partnerPos = GREEN_HOST_POS, GREEN_GUEST_POS
    else
        myPos, partnerPos = GREEN_GUEST_POS, GREEN_HOST_POS
    end

    goToAndFace(myPos, partnerPos, MOVE_SPEED)
    task.wait(0.3)
    do
        local ok, d = isOnSpot(myPos)
        LOG("Green", string.format("после прилёта: dist=%.2f onSpot=%s", d, tostring(ok)))
        if not ok then snapToSpot(myPos, partnerPos) end
    end

    -- ★ ЖДЁМ ПАРТНЁРА (бесконечно)
    LOG("Green", "★ жду партнёра в радиусе " .. PARTNER_NEAR_RADIUS .. " стадов...")
    waitPartnerNearby(match.partner_name, PARTNER_NEAR_RADIUS)

    LOG("Green", "★ пауза " .. DELAY_AFTER_ARRIVE .. "с — оба на месте")
    task.wait(DELAY_AFTER_ARRIVE)

    -- Host: 8,7 ON → fruit → 8,7 OFF
    if match.role == "host" then
        dumpInventory("host:before-8,7")
        LOG("Green", "host: 8,7 ON (оба на месте)")
        ensureOptionOn(TAB_FRUIT, OPT_FRUIT)
        LOG("Green", "host: жду fruit-tool...")
        local tool = waitFruitTool()
        LOG("Green", "host: fruit появился = " .. tostring(tool and tool.Name))
        dumpInventory("host:after-8,7")
        LOG("Green", "host: 8,7 OFF")
        ensureOptionOff(TAB_FRUIT, OPT_FRUIT)
    else
        LOG("Green", "guest: 8,7 не трогаю")
    end

    local claimedMe = false

    if match.role == "host" then
        LOG("Green", "=== HOST PHASE ===")

        LOG("Green", "host: drop #1 (отдаю guest'у)")
        local ok1, err1 = eatFruitDrop()
        LOG("Green", "host: drop #1 = " .. tostring(ok1) .. " / " .. tostring(err1))
        dumpInventory("host:after-drop1")

        LOG("Green", "★ host: пауза " .. DELAY_AFTER_DROP .. "с после drop #1")
        task.wait(DELAY_AFTER_DROP)

        LOG("Green", "host: жду fruit обратно от guest'а...")
        local tool = waitFruitTool()
        LOG("Green", "host: получил обратно = " .. tostring(tool and tool.Name))
        dumpInventory("host:after-receive1")

        LOG("Green", "★ host: пауза " .. DELAY_BEFORE_CLAIM .. "с перед ClaimQuest")
        task.wait(DELAY_BEFORE_CLAIM)
        claimedMe = claimLoop(myPos, "Claim")

        LOG("Green", "★ host: пауза " .. DELAY_BEFORE_DROP2 .. "с перед drop #2")
        task.wait(DELAY_BEFORE_DROP2)

        LOG("Green", "host: drop #2 (отдаю guest'у для его ClaimQuest)")
        local ok2, err2 = eatFruitDrop()
        LOG("Green", "host: drop #2 = " .. tostring(ok2) .. " / " .. tostring(err2))
        dumpInventory("host:after-drop2")

        LOG("Green", "★ host: жду " .. DELAY_AFTER_CLAIM .. "с пока guest сделает ClaimQuest")
        task.wait(DELAY_AFTER_CLAIM)

        LOG("Green", "★ host: ВСЁ СДЕЛАНО. Включаю (" .. TAB_TOGGLE .. "," .. OPT_TOGGLE .. ")")
        local okOn = ensureOptionOn(TAB_TOGGLE, OPT_TOGGLE)
        LOG("Green", "  ensureOptionOn = " .. tostring(okOn))

    else
        LOG("Green", "=== GUEST PHASE ===")

        LOG("Green", "guest: жду fruit #1 от host'а...")
        local tool1 = waitFruitTool()
        LOG("Green", "guest: получил #1 = " .. tostring(tool1 and tool1.Name))
        dumpInventory("guest:after-receive1")

        LOG("Green", "★ guest: пауза " .. DELAY_AFTER_DROP .. "с")
        task.wait(DELAY_AFTER_DROP)

        LOG("Green", "guest: drop #1 (возвращаю host'у)")
        local ok1, err1 = eatFruitDrop()
        LOG("Green", "guest: drop #1 = " .. tostring(ok1) .. " / " .. tostring(err1))
        dumpInventory("guest:after-drop1")

        LOG("Green", "★ guest: пауза " .. DELAY_AFTER_DROP .. "с после drop #1")
        task.wait(DELAY_AFTER_DROP)

        LOG("Green", "guest: жду fruit #2 от host'а...")
        local tool2 = waitFruitTool()
        LOG("Green", "guest: получил #2 = " .. tostring(tool2 and tool2.Name))
        dumpInventory("guest:after-receive2")

        LOG("Green", "★ guest: пауза " .. DELAY_BEFORE_CLAIM .. "с перед ClaimQuest")
        task.wait(DELAY_BEFORE_CLAIM)
        local guestClaimed = claimLoop(myPos, "ClaimGuest")
        LOG("Green", "guest: ClaimQuest = " .. tostring(guestClaimed))

        LOG("Green", "★ guest: ВСЁ СДЕЛАНО. Включаю (" .. TAB_TOGGLE .. "," .. OPT_TOGGLE .. ")")
        local okOn = ensureOptionOn(TAB_TOGGLE, OPT_TOGGLE)
        LOG("Green", "  ensureOptionOn = " .. tostring(okOn))
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
