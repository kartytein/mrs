--!nocheck
-- ============================================================
-- GREEN MODE — АВТОНОМНЫЙ ТЕСТ (v4)
-- • fireSequence ВЕРНУЛ КАК В ОРИГИНАЛЕ (с Activated) — телепорт работает
-- • Noclip CFrame-lerp 250 studs/s
-- • Хаб: переключение таба ПЕРЕД каждой операцией с опцией
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- КОНФИГ
-- ============================================================
local SERVER_URL          = "http://192.168.31.179:8000"
local POST_TRADE_NPC_NAME = "Dojo Trainer"

local GREEN_HOST_POS   = Vector3.new(5841.1, 1208.6, 887.2)
local GREEN_GUEST_POS  = Vector3.new(5848.3, 1208.6, 881.5)

local MOVE_SPEED = 250

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local TAB_FRUIT, OPT_FRUIT = 7, 7

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

-- ОРИГИНАЛ (с Activated) — для табов и телепорта
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

-- Открыть таб и вернуть (optBtn, indicator) — ОДИН раз переключаем таб
local function openTabAndGetOption(tabIndex, optIndex)
    local root = getRoot() if not root then return nil, nil end
    local ts = safeFind(root, "Window", "Components", "TabsScroll")
    if not ts then return nil, nil end
    local tabBtn = findNthTabButton(ts, tabIndex)
    if not tabBtn then
        WARN("Hub", "таб " .. tabIndex .. " не найден")
        return nil, nil
    end
    fireSequence(tabBtn)
    task.wait(0.5)

    local cont = safeFind(root, "Window", "Components", "Containers", "Container")
    if not cont then return nil, nil end

    local optBtn = findNthOption(cont, optIndex)
    if not optBtn then
        WARN("Hub", "опция " .. optIndex .. " не найдена в табе " .. tabIndex)
        return nil, nil
    end
    return optBtn, findIndicatorFrame(optBtn)
end

-- Гарантирует состояние "on"/"off" — на каждой итерации ЗАНОВО открывает таб
local function ensureOptionState(tabIndex, optIndex, desiredState, tries)
    tries = tries or 8
    local wantOn = (desiredState == "on")

    for i = 1, tries do
        local optBtn, ind = openTabAndGetOption(tabIndex, optIndex)
        if not optBtn or not ind then
            task.wait(0.4)
            continue
        end

        local isOn = (tostring(ind.BackgroundColor3) == COLOR_ON)
        if isOn == wantOn then
            LOG("Hub", string.format("%d,%d = %s (try %d)",
                tabIndex, optIndex, string.upper(desiredState), i))
            return true
        end

        LOG("Hub", string.format("%d,%d state=%s → клик %s (try %d)",
            tabIndex, optIndex, isOn and "ON" or "OFF",
            string.upper(desiredState), i))

        fireSequence(optBtn)
        task.wait(0.5)
    end

    local _, indFinal = openTabAndGetOption(tabIndex, optIndex)
    local col = indFinal and tostring(indFinal.BackgroundColor3) or "nil"
    WARN("Hub", string.format("%d,%d FAILED final=%s", tabIndex, optIndex, col))
    return false
end

local function ensureOptionOn(tabIndex, optIndex, tries)
    return ensureOptionState(tabIndex, optIndex, "on", tries)
end

local function ensureOptionOff(tabIndex, optIndex, tries)
    return ensureOptionState(tabIndex, optIndex, "off", tries)
end

local function waitForHubReady()
    local t0 = tick()
    while State.running and not waitForInterface() do
        task.wait(0.5)
        if tick() - t0 > 300 then return false end
    end
    LOG("Hub", "готов")
    return true
end

-- ============================================================
-- ТЕЛЕПОРТ — КАК В ОРИГИНАЛЕ (НЕ ТРОГАЛ)
-- ============================================================
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
-- ПОСТАНОВКА НА ТОЧКУ + РАЗВОРОТ (noclip CFrame-lerp)
-- ============================================================
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
    if lookDir.Magnitude < 1e-4 then
        lookDir = Vector3.new(delta.X, 0, delta.Z)
    end
    if lookDir.Magnitude < 1e-4 then
        lookDir = Vector3.new(0, 0, 1)
    end
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

    LOG("Green", string.format("встал на (%.1f,%.1f,%.1f)",
        hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
    return true
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

    if not waitForHubReady() then
        State.mode = "none"; return
    end

    -- Guest телепорт
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
        waitForHubReady()
    end

    -- Позиция + разворот
    local myPos, partnerPos
    if match.role == "host" then
        myPos, partnerPos = GREEN_HOST_POS, GREEN_GUEST_POS
    else
        myPos, partnerPos = GREEN_GUEST_POS, GREEN_HOST_POS
    end

    LOG("Green", "goTo " .. string.format("(%.1f,%.1f,%.1f)",
        myPos.X, myPos.Y, myPos.Z))

    goToAndFace(myPos, partnerPos, MOVE_SPEED)
    task.wait(0.3)

    -- Host: 7,7 ON → fruit → 7,7 OFF
    if match.role == "host" then
        LOG("Green", "host: 7,7 ON")
        local ok77 = ensureOptionOn(TAB_FRUIT, OPT_FRUIT)
        LOG("Green", "host: 7,7 ON result = " .. tostring(ok77))

        LOG("Green", "host: ждём fruit-tool...")
        local tool = waitFruitTool()
        LOG("Green", "host: fruit появился = " .. tostring(tool and tool.Name))

        LOG("Green", "host: 7,7 OFF")
        local off77 = ensureOptionOff(TAB_FRUIT, OPT_FRUIT)
        LOG("Green", "host: 7,7 OFF result = " .. tostring(off77))
    else
        LOG("Green", "guest: 7,7 не трогаю (активирует host)")
    end

    -- Ping-pong
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
