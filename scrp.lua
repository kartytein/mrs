--!nocheck
-- ============================================================
-- КОНФИГ
-- ============================================================
local BLACKLIST = {
    "EdwardThornton360",
    "DorisVelasquez14332",
}

local BELT_SCAN_INTERVAL = 30
local HOLD_CHECK_INTERVAL = 30
local SERVER_URL         = "http://192.168.31.89:8000"
local BELT_ORDER         = {"White","Yellow","Orange","Green","Blue","Purple","Red","Black"}

local SCROLL_STEP_PIXELS  = 10
local SCROLL_WAIT_TIME    = 0.15
local SCROLL_INITIAL_WAIT = 0.5
local SCROLL_FINAL_WAIT   = 1.0

-- ============================================================
-- ЛОГГЕР
-- ============================================================
local T0 = tick()
local function LOG(tag, msg)
    local dt = tick() - T0
    print(string.format("[%7.2fs][%s] %s", dt, tag, msg))
end
local function WARN(tag, msg)
    local dt = tick() - T0
    warn(string.format("[%7.2fs][%s] %s", dt, tag, msg))
end

-- ============================================================
-- СЕРВИСЫ И СОСТОЯНИЕ
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local State = {
    currentBelt     = "Unknown",
    beltChangedAt   = tick(),
    beltScanPaused  = false,
    running         = true,
    nobeltDone      = false,
    tradeDone       = false,
}

-- ============================================================
-- УТИЛИТЫ
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

local function findObjectByPath(root, ...)
    local current = root
    for _, segment in ipairs({...}) do
        if not current then return nil end
        current = current:FindFirstChild(segment)
    end
    return current
end

local function findHudButtonByName(buttonName)
    local hudRoot = playerGui:FindFirstChild("HUDRoot")
    if not hudRoot then return nil end
    local frame = hudRoot:FindFirstChild("Frame")
    if not frame then return nil end
    local hud = frame:FindFirstChild("HUD")
    if not hud then return nil end
    local function search(node)
        for _, child in ipairs(node:GetChildren()) do
            if (child:IsA("TextButton") or child:IsA("ImageButton")) and child.Name == buttonName then
                return child
            end
            local found = search(child)
            if found then return found end
        end
        return nil
    end
    return search(hud)
end

local function waitForHudButton(buttonName, timeout)
    local waited = 0
    while waited < timeout do
        local btn = findHudButtonByName(buttonName)
        if btn then
            LOG("HUD", "найдена кнопка " .. buttonName .. " за " .. waited .. "с")
            return btn
        end
        task.wait(0.5); waited += 0.5
    end
    WARN("HUD", "кнопка " .. buttonName .. " НЕ найдена за " .. timeout .. "с")
    return nil
end

local function waitForObjectByPath(pathTable, timeout)
    local waited = 0
    local pathStr = table.concat(pathTable, ".")
    while waited < timeout do
        local obj = findObjectByPath(playerGui, table.unpack(pathTable))
        if obj then
            LOG("Path", "найден " .. pathStr .. " за " .. waited .. "с")
            return obj
        end
        task.wait(0.5); waited += 0.5
    end
    WARN("Path", "НЕ найден " .. pathStr .. " за " .. timeout .. "с")
    return nil
end

local function findInventoryButtonByName(buttonName)
    local inv = playerGui:FindFirstChild("Inventory")
    if not inv then return nil end
    for _, obj in ipairs(inv:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == buttonName then
            return obj
        end
    end
    return nil
end

-- ============================================================
-- БЛЭКЛИСТ
-- ============================================================
local function normalizeName(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    return s:lower()
end

local function sanitizeBlacklist(list)
    local clean, seen = {}, {}
    local myName = normalizeName(player.Name)
    for _, name in ipairs(list) do
        local n = normalizeName(name)
        if n and n ~= myName and not seen[n] then
            seen[n] = true
            table.insert(clean, n)
        end
    end
    return clean
end

BLACKLIST = sanitizeBlacklist(BLACKLIST)
LOG("Blacklist", #BLACKLIST .. " записей после чистки (me: " .. player.Name .. ")")

local function getBlacklistedPlayer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local n = normalizeName(plr.Name)
            for _, bad in ipairs(BLACKLIST) do
                if n == bad then return plr.Name end
            end
        end
    end
    return nil
end

-- ============================================================
-- ЗАГРУЗКА ХАБА
-- ============================================================
LOG("Hub", "загружаю хаб...")
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

-- ============================================================
-- БЕЛТ-СКАНЕР
-- ============================================================
local function extractBeltFromTile(tileObject)
    local details = tileObject:FindFirstChild("Details")
    if details then
        for _, o in ipairs(details:GetDescendants()) do
            if o:IsA("TextLabel") and o.Text and o.Text:find("Belt %(") then
                return o.Text
            end
        end
        for _, o in ipairs(details:GetDescendants()) do
            if o:IsA("TextLabel") and o.Text and o.Text:find("Belt") then
                return o.Text
            end
        end
    end
    for _, o in ipairs(tileObject:GetDescendants()) do
        if o:IsA("TextLabel") and o.Text and o.Text:find("Belt %(") then
            return o.Text
        end
    end
    return nil
end

local function doBeltScan()
    LOG("BeltScan", ">>> старт скана")

    local menuButton = waitForHudButton("Menu", 10)
    if not menuButton then WARN("BeltScan", "нет Menu — стоп"); return nil end
    LOG("BeltScan", "клик Menu")
    fireSequence(menuButton); task.wait(1.5)

    local itemsButton = waitForHudButton("Items", 10)
    if not itemsButton then WARN("BeltScan", "нет Items — стоп"); return nil end
    LOG("BeltScan", "клик Items")
    fireSequence(itemsButton); task.wait(1.5)

    LOG("BeltScan", "ищу Category3...")
    local category3 = waitForObjectByPath({"Inventory","Inventory","Main","NavigationRail","Category3"}, 5)
    if not category3 then
        LOG("BeltScan", "fallback: findInventoryButtonByName(Category3)")
        category3 = findInventoryButtonByName("Category3")
    end
    if not category3 then WARN("BeltScan", "нет Category3 — стоп"); return nil end
    LOG("BeltScan", "клик Category3: " .. category3:GetFullName())
    fireSequence(category3); task.wait(SCROLL_INITIAL_WAIT)

    LOG("BeltScan", "ищу TileGrid...")
    local tileGrid = waitForObjectByPath({"Inventory","Inventory","Main","PageContent","TileGrid"}, 5)
    if not tileGrid then
        local inv = playerGui:FindFirstChild("Inventory")
        if inv then
            LOG("BeltScan", "fallback: глубокий поиск TileGrid в Inventory")
            tileGrid = inv:FindFirstChild("TileGrid", true)
        end
    end
    if not tileGrid then WARN("BeltScan", "нет TileGrid — стоп"); return nil end
    LOG("BeltScan", "TileGrid: " .. tileGrid:GetFullName())

    local scrollingFrame = nil
    local obj = tileGrid
    while obj do
        if obj:IsA("ScrollingFrame") then scrollingFrame = obj; break end
        obj = obj.Parent
    end
    if not scrollingFrame then WARN("BeltScan", "нет ScrollingFrame — стоп"); return nil end
    LOG("BeltScan", "ScrollingFrame: " .. scrollingFrame:GetFullName())

    local collected, beltList = {}, {}
    local function collectVisible()
        local newFound = 0
        for _, child in ipairs(tileGrid:GetDescendants()) do
            if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
                if not collected[child.Name] then
                    collected[child.Name] = true
                    local t = extractBeltFromTile(child)
                    if t then
                        table.insert(beltList, t)
                        newFound += 1
                    end
                end
            end
        end
        return newFound
    end

    if scrollingFrame then
        local cy = scrollingFrame.AbsoluteCanvasSize.Y
        local wy = scrollingFrame.AbsoluteSize.Y
        LOG("BeltScan", "CanvasSize.Y=" .. cy .. "  WindowY=" .. wy .. "  max=" .. (cy - wy))
        scrollingFrame.CanvasPosition = Vector2.new(0, 0)
        task.wait(SCROLL_INITIAL_WAIT)
        local nf = collectVisible()
        LOG("BeltScan", "стартовый сбор: " .. nf .. " новых, всего " .. #beltList)

        local maxY = math.max(0, cy - wy)
        local y, s = 0, 0
        while y < maxY and s < 1000 do
            y = math.min(y + SCROLL_STEP_PIXELS, maxY)
            scrollingFrame.CanvasPosition = Vector2.new(0, y)
            task.wait(SCROLL_WAIT_TIME)
            local newF = collectVisible()
            if newF > 0 then
                LOG("BeltScan", "scroll y=" .. y .. " +" .. newF .. " тайлов")
            end
            s += 1
        end
        scrollingFrame.CanvasPosition = Vector2.new(0, maxY)
        task.wait(SCROLL_FINAL_WAIT)
        collectVisible()
        LOG("BeltScan", "скролл завершён, итераций: " .. s)
    else
        collectVisible()
    end

    LOG("BeltScan", "всего тайлов: " .. #beltList)
    for i, t in ipairs(beltList) do
        LOG("BeltScan", "  [" .. i .. "] " .. t)
    end

    local highestBelt, highestIdx = nil, 0
    for _, t in ipairs(beltList) do
        local bp = t:find("Belt %(")
        if bp then
            local sp = bp + 6
            local ep = t:find(")", sp)
            if ep then
                local color = t:sub(sp, ep - 1)
                for i, oc in ipairs(BELT_ORDER) do
                    if color == oc and i > highestIdx then
                        highestIdx = i; highestBelt = color; break
                    end
                end
            end
        end
    end

    local result = highestBelt or "None"
    LOG("BeltScan", "<<< результат: " .. result)
    return result
end

task.spawn(function()
    LOG("BeltScan", "поток сканера запущен, ждём персонажа...")
    if not player.Character then player.CharacterAdded:Wait() end
    LOG("BeltScan", "персонаж есть")

    local w = 0
    while not findHudButtonByName("Menu") and w < 90 do task.wait(1); w += 1 end
    if not findHudButtonByName("Menu") then
        WARN("BeltScan", "HUD Menu не появилась за 90с — выходим")
        return
    end
    LOG("BeltScan", "HUD Menu найдена через " .. w .. "с")
    task.wait(3)

    local iter = 0
    while State.running do
        iter += 1
        if not State.beltScanPaused then
            LOG("BeltScan", "итерация #" .. iter)
            local ok, belt = pcall(doBeltScan)
            if not ok then
                WARN("BeltScan", "ошибка: " .. tostring(belt))
            elseif belt then
                if belt ~= State.currentBelt then
                    LOG("BeltScan", "НОВЫЙ РЕЖИМ: " .. State.currentBelt .. " -> " .. belt)
                    State.currentBelt   = belt
                    State.beltChangedAt = tick()
                else
                    LOG("BeltScan", "режим тот же: " .. belt)
                end
            end
        else
            LOG("BeltScan", "итерация #" .. iter .. " пропущена (paused)")
        end
        task.wait(BELT_SCAN_INTERVAL)
    end
end)

-- ============================================================
-- СЕРВЕР-ХОП
-- ============================================================
local function serverHop()
    LOG("Hop", "=== старт сервер-хопа ===")
    local function findSB()
        local tb = playerGui:FindFirstChild("Topbar")
        if tb then
            local f = tb:FindFirstChild("Frame")
            if f then return f:FindFirstChild("ServerBrowserButton") end
        end
        return nil
    end

    local w = 0
    while not findSB() and w < 15 do task.wait(0.5); w += 0.5 end
    local sb = findSB()
    if not sb then WARN("Hop", "ServerBrowserButton не найдена"); return false end
    LOG("Hop", "клик ServerBrowserButton")
    fireSequence(sb); task.wait(1)

    local function findJoin()
        for _, v in ipairs(playerGui:GetDescendants()) do
            if (v:IsA("TextButton") or v:IsA("TextBox")) and v.Text == "Join" and v.Visible then
                return v
            end
        end
        return nil
    end

    w = 0
    while not findJoin() and w < 20 do task.wait(0.5); w += 0.5 end
    if not findJoin() then WARN("Hop", "Join не найдена"); return false end
    LOG("Hop", "кнопка Join появилась за " .. w .. "с")

    local sBrowser = playerGui:FindFirstChild("ServerBrowser")
    if not sBrowser then WARN("Hop", "нет ServerBrowser"); return false end
    local f = sBrowser:FindFirstChild("Frame")
    if not f then WARN("Hop", "нет Frame"); return false end
    local sf = f:FindFirstChild("ScrollingFrame")
    if not sf then WARN("Hop", "нет ScrollingFrame"); return false end

    local cY = sf.CanvasSize.Y
    local maxY = (typeof(cY) == "UDim") and cY.Offset or cY
    local dur = math.random(1, 10)
    LOG("Hop", "скролл " .. dur .. "с, max=" .. maxY)
    local y, t0 = 0, tick()
    sf.CanvasPosition = Vector2.new(0, 0)
    task.wait(0.2)
    while (tick() - t0) < dur and y < maxY do
        y = math.min(y + 150, maxY)
        sf.CanvasPosition = Vector2.new(0, y)
        task.wait(0.03)
    end

    local btns = {}
    local function collect(p)
        for _, c in ipairs(p:GetChildren()) do
            if (c:IsA("TextButton") or c:IsA("TextBox")) and c.Text == "Join" and c.Visible then
                table.insert(btns, c)
            end
            collect(c)
        end
    end
    collect(sBrowser)
    LOG("Hop", "найдено кнопок Join: " .. #btns)
    if #btns == 0 then WARN("Hop", "нет кнопок Join"); return false end
    fireSequence(btns[math.random(1, #btns)])
    LOG("Hop", "нажали Join, ожидаем телепорт...")
    return true
end

-- ============================================================
-- ХАБ: опции
-- ============================================================
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local TAB_MAIN, OPT_MAIN = 6, 1

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
    if not root then LOG("Opt", "setOption("..tabIndex..","..optIndex..","..tostring(wantOn)..") нет root"); return false end
    local tb = findTab(root, tabIndex)
    if not tb then LOG("Opt", "нет таба "..tabIndex); return false end
    fireSequence(tb)
    if not waitForOptions(optIndex, 8) then LOG("Opt", "опции не прогрузились"); return false end

    local opt = findOption(root, optIndex)
    if not opt then LOG("Opt", "нет опции "..optIndex); return false end
    local ind = findIndicatorFrame(opt)
    if not ind then LOG("Opt", "нет индикатора"); return false end
    local isOn = (tostring(ind.BackgroundColor3) == COLOR_ON)
    if isOn == wantOn then
        return true
    end

    LOG("Opt", "клик ("..tabIndex..","..optIndex..") -> "..tostring(wantOn))
    fireSequence(opt); task.wait(0.2)
    for i = 1, 5 do
        local i2 = findIndicatorFrame(opt)
        if i2 and (tostring(i2.BackgroundColor3) == COLOR_ON) == wantOn then
            return true
        end
        fireSequence(opt); task.wait(0.25)
    end
    WARN("Opt", "не удалось переключить ("..tabIndex..","..optIndex..") на "..tostring(wantOn))
    return false
end

-- ============================================================
-- NO BELT
-- ============================================================
local function hasDragonTalon()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return false end
    local wac = pg:FindFirstChild("WeaponAssetCache")
    if not wac then return false end
    return wac:FindFirstChild("dragontalon") ~= nil
end

local function isOnIsland()
    local world = Workspace:FindFirstChild("_WorldOrigin")
    if not world then return false end
    local sounds = world:FindFirstChild("Sounds")
    if not sounds then return false end
    local locs = sounds:FindFirstChild("Locations")
    if not locs then return false end
    return locs:FindFirstChild("Submerged Island") ~= nil
end

local function getMastery()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then return nil end
    local lbl = main:FindFirstChild("MobileMasteryLevel")
    if not lbl then return nil end
    return tonumber(string.match(lbl.Text or "", "%d+"))
end

local function runNoBeltMode()
    LOG("NoBelt", "=== START ===")
    LOG("NoBelt", "belt=" .. State.currentBelt)

    LOG("NoBelt", "фаза 1: ждём dragon talon")
    local guard, guardT = 0, tick()
    while not hasDragonTalon() and State.running and State.currentBelt == "None" do
        setOption(TAB_MAIN, OPT_MAIN, true); task.wait(2); guard += 1
        if guard % 15 == 0 then
            LOG("NoBelt", "ожидание talon, guard=" .. guard)
            guardT = tick()
        end
    end
    if State.currentBelt ~= "None" then
        LOG("NoBelt", "belt сменился на " .. State.currentBelt .. " — выход")
        return
    end
    LOG("NoBelt", "dragon talon OK")

    LOG("NoBelt", "фаза 2: ждём остров")
    while not isOnIsland() and State.running and State.currentBelt == "None" do
        setOption(TAB_MAIN, OPT_MAIN, true); task.wait(2)
    end
    if State.currentBelt ~= "None" then
        LOG("NoBelt", "belt сменился — выход")
        return
    end
    LOG("NoBelt", "на острове")

    LOG("NoBelt", "фаза 3: 6,1 off; 2,4 on")
    setOption(TAB_MAIN, OPT_MAIN, false); task.wait(0.5)
    setOption(2, 4, true)

    LOG("NoBelt", "фаза 4: ждём mastery > 500")
    local lastM = -1
    while State.running and State.currentBelt == "None" do
        task.wait(2)
        local m = getMastery() or 0
        if m ~= lastM then
            LOG("NoBelt", "mastery=" .. m)
            lastM = m
        end
        if m > 500 then break end
    end
    if State.currentBelt ~= "None" then
        LOG("NoBelt", "belt сменился — выход")
        return
    end

    LOG("NoBelt", "фаза 5: 2,4 off; 6,1 on")
    setOption(2, 4, false); task.wait(0.5)
    setOption(TAB_MAIN, OPT_MAIN, true)
    LOG("NoBelt", "=== DONE ===")
    State.nobeltDone = true
end

-- ============================================================
-- HOLD 6,1
-- ============================================================
local function runHoldSixOne()
    local modeAtStart = State.currentBelt
    LOG("Hold", "=== START === belt=" .. modeAtStart)

    pcall(function() setOption(TAB_MAIN, OPT_MAIN, true) end)

    local failStreak = 0
    local checkCount = 0

    while State.running do
        if State.currentBelt ~= modeAtStart then
            LOG("Hold", "belt сменился: " .. modeAtStart .. " -> " .. State.currentBelt .. " — выход")
            return
        end

        checkCount += 1
        LOG("Hold", "проверка #" .. checkCount)

        local state = getOptionState(TAB_MAIN, OPT_MAIN)
        local ok
        if state == true then
            ok = true
        elseif state == false then
            LOG("Hold", "6,1 выключен — включаю")
            ok = setOption(TAB_MAIN, OPT_MAIN, true)
        else
            LOG("Hold", "state=nil — пробую включить")
            ok = setOption(TAB_MAIN, OPT_MAIN, true)
        end

        if ok then
            if failStreak > 0 then
                LOG("Hold", "восстановлен после " .. failStreak .. " провалов")
            end
            failStreak = 0
        else
            failStreak += 1
            WARN("Hold", "провал #" .. failStreak)
            if failStreak >= 3 then
                WARN("Hold", "3 провала — пауза 15с")
                task.wait(15)
                local root = getRoot()
                if root then
                    local anyTab = findTab(root, 1)
                    if anyTab then fireSequence(anyTab); task.wait(1) end
                end
                failStreak = 0
            end
        end

        if checkCount % 10 == 0 then
            LOG("Hold", "статус: belt=" .. State.currentBelt .. " 6,1 ok=" .. tostring(ok))
        end

        task.wait(HOLD_CHECK_INTERVAL)
    end
end

-- ============================================================
-- ТРЕЙД
-- ============================================================
local function runTradeMode()
    LOG("Trade", "=== START ===")
    State.beltScanPaused = true
    LOG("Trade", "сканер пояса на паузе")

    local SEND_INVENTORY_INTERVAL = 20
    local CONFIG_POLL_INTERVAL    = 10
    local MOVE_TIMEOUT            = 60
    local ARRIVE_DISTANCE         = 6
    local MOVE_SPEED              = 80

    local TELEPORT_TAB          = 19
    local TELEPORT_OPT_TEXT     = 2
    local TELEPORT_OPT_ACTIVATE = 3
    local WAYPOINT_POSITION     = Vector3.new(-12549.7, 337.5, -7501.1)

    local collisionsDisabled = false

    local function selectTeam()
        LOG("Trade", "SetTeam Marines")
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", "Marines")
        end)
        task.wait(3)
    end

    local function extractTileInfo(tileObject)
        local details = tileObject:FindFirstChild("Details")
        local text = nil
        if details then
            local l1 = details:FindFirstChild("Line-1")
            if l1 and l1:IsA("TextLabel") and l1.Text ~= "" then text = l1.Text end
            if not text then
                local l2 = details:FindFirstChild("Line-2")
                if l2 and l2:IsA("TextLabel") and l2.Text ~= "" then text = l2.Text end
            end
            if not text then
                for _, o in ipairs(details:GetDescendants()) do
                    if o:IsA("TextLabel") and o.Text ~= "" then text = o.Text; break end
                end
            end
        end
        if not text then
            for _, o in ipairs(tileObject:GetDescendants()) do
                if o:IsA("TextLabel") and o.Text ~= "" then text = o.Text; break end
            end
        end
        if not text then return nil end
        local clean = text
        local ci = clean:find(",")
        if ci then clean = clean:sub(1, ci - 1) end
        clean = clean:gsub("%s+$", "")
        local num = tonumber(tileObject.Name:sub(6)) or 0
        return {Name = tileObject.Name, Number = num, Text = clean}
    end

    local function collectInventory()
        LOG("Inv", "открываю Menu/Items/Category2")
        local menuButton = waitForHudButton("Menu", 10)
        if not menuButton then WARN("Inv", "нет Menu"); return {} end
        fireSequence(menuButton); task.wait(1.5)

        local itemsButton = waitForHudButton("Items", 10)
        if not itemsButton then WARN("Inv", "нет Items"); return {} end
        fireSequence(itemsButton); task.wait(1.5)

        local category2 = waitForObjectByPath({"Inventory","Inventory","Main","NavigationRail","Category2"}, 5)
        if not category2 then category2 = findInventoryButtonByName("Category2") end
        if not category2 then WARN("Inv", "нет Category2"); return {} end
        fireSequence(category2); task.wait(SCROLL_INITIAL_WAIT)

        local tileGrid = waitForObjectByPath({"Inventory","Inventory","Main","PageContent","TileGrid"}, 5)
        if not tileGrid then WARN("Inv", "нет TileGrid"); return {} end

        local scrollingFrame = nil
        local obj = tileGrid
        while obj do
            if obj:IsA("ScrollingFrame") then scrollingFrame = obj; break end
            obj = obj.Parent
        end

        local collected, list = {}, {}
        local function collectVisible()
            for _, child in ipairs(tileGrid:GetDescendants()) do
                if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
                    local info = extractTileInfo(child)
                    if info and not collected[info.Name] then
                        collected[info.Name] = true
                        table.insert(list, info)
                    end
                end
            end
        end

        if scrollingFrame then
            local cy = scrollingFrame.AbsoluteCanvasSize.Y
            local wy = scrollingFrame.AbsoluteSize.Y
            scrollingFrame.CanvasPosition = Vector2.new(0, 0)
            task.wait(SCROLL_INITIAL_WAIT)
            collectVisible()
            local maxY = math.max(0, cy - wy)
            local y, s = 0, 0
            while y < maxY and s < 1000 do
                y = math.min(y + 10, maxY)
                scrollingFrame.CanvasPosition = Vector2.new(0, y)
                task.wait(0.15)
                collectVisible()
                s += 1
            end
            scrollingFrame.CanvasPosition = Vector2.new(0, maxY)
            task.wait(SCROLL_FINAL_WAIT)
            collectVisible()
        else
            collectVisible()
        end

        table.sort(list, function(a,b) return a.Number < b.Number end)
        local fruits = {}
        for _, t in ipairs(list) do if t.Text ~= "" then table.insert(fruits, t.Text) end end
        LOG("Inv", "собрано: " .. #fruits)
        return fruits
    end

    local function sendInventory(fruits)
        local url = SERVER_URL .. "/send_inventory?nickname=" .. HttpService:UrlEncode(player.Name)
            .. "&fruits=" .. HttpService:UrlEncode(table.concat(fruits, ","))
            .. "&job_id=" .. HttpService:UrlEncode(game.JobId)
        local ok, err = pcall(function() return game:HttpGet(url) end)
        if ok then LOG("HTTP", "send_inventory OK")
        else WARN("HTTP", "send_inventory err: " .. tostring(err)) end
    end

    local function fetchConfig()
        local url = SERVER_URL .. "/get_config?nickname=" .. HttpService:UrlEncode(player.Name)
        local ok, response = pcall(function() return game:HttpGet(url) end)
        if not ok then return nil end
        local ok2, data = pcall(function() return HttpService:JSONDecode(response) end)
        if not ok2 then return nil end
        if data and data.partner_name then return data end
        return nil
    end

    local function formatItemName(n)
        local l = n:lower()
        local c = l:sub(1,1):upper() .. l:sub(2)
        return c .. "-" .. c
    end

    local function invokeLoadFruit(f)
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("LoadFruit", f) end)
    end

    local function respawn()
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("Humanoid")
        if h then pcall(function() h.Health = 0 end) end
    end

    local function waitRespawn()
        local old = player.Character
        local w = 0
        while w < 30 do
            if player.Character and player.Character ~= old then return end
            task.wait(0.5); w += 0.5
        end
    end

    local function processLoadFruit(items)
        if #items == 0 then return true end
        for _, item in ipairs(items) do
            LOG("Fruit", "load " .. item)
            invokeLoadFruit(formatItemName(item))
            respawn(); waitRespawn(); task.wait(1)
        end
        return true
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

    local function teleportToJobId(jobId)
        LOG("TP", "телепорт на " .. jobId)
        local root = getRoot() if not root then return false end
        local ts = safeFind(root, "Window","Components","TabsScroll")
        if not ts then return false end
        local tb = findNthTabButton(ts, TELEPORT_TAB)
        if not tb then WARN("TP", "нет таба " .. TELEPORT_TAB); return false end
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

    task.spawn(function()
        while true do
            if collisionsDisabled then
                pcall(function()
                    local myChar = player.Character
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and not (myChar and obj:IsDescendantOf(myChar)) then
                            obj.CanCollide = false
                        end
                    end
                end)
            end
            task.wait(2)
        end
    end)

    -- ============================================================
    -- moveToPosition: CFrame каждый кадр
    -- ============================================================
    local function moveToPosition(target)
        local tx, tz, ty = target.X, target.Z, target.Y + 3
        local startTime = tick()
        local lastLog = 0
        local startPos = nil
        LOG("Move", "старт, цель X=" .. math.floor(tx) .. " Y=" .. math.floor(ty) .. " Z=" .. math.floor(tz))

        while tick() - startTime < MOVE_TIMEOUT do
            local c = player.Character
            if not c then
                LOG("Move", "нет персонажа, ждём")
                task.wait(0.05); continue
            end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local h = c:FindFirstChild("Humanoid")
            if not hrp or not h or h.Health <= 0 then
                task.wait(0.05); continue
            end

            if h.Sit then
                LOG("Move", "сел, выходим")
                return true
            end

            local cur = hrp.Position
            if not startPos then startPos = cur end
            local dx, dz = tx - cur.X, tz - cur.Z
            local dist = math.sqrt(dx*dx + dz*dz)

            if dist < ARRIVE_DISTANCE then
                LOG("Move", "прибыл, dist=" .. string.format("%.1f", dist))
                pcall(function() h:MoveTo(Vector3.new(tx, cur.Y, tz)) end)
                return true
            end

            local step = math.min(MOVE_SPEED * 0.05, dist)
            local nx, nz = dx / math.max(dist, 0.001), dz / math.max(dist, 0.001)
            local newX = cur.X + nx * step
            local newZ = cur.Z + nz * step

            pcall(function()
                hrp.CFrame = CFrame.new(newX, ty, newZ)
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)

            if tick() - lastLog >= 1 then
                lastLog = tick()
                LOG("Move", string.format("pos=(%.0f,%.0f,%.0f) dist=%.1f", cur.X, cur.Y, cur.Z, dist))
            end

            task.wait(0.05)
        end

        WARN("Move", "TIMEOUT, не дошли")
        return false
    end

    local function findTradeTable(expectedPartner)
        local tables = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "TradeTable" then table.insert(tables, obj) end
        end
        LOG("Table", "всего TradeTable: " .. #tables)
        local free, partial, partner = {}, {}, {}
        for _, tbl in ipairs(tables) do
            local seats = {}
            for _, part in ipairs(tbl:GetDescendants()) do
                if part:IsA("Seat") or part:IsA("VehicleSeat") then table.insert(seats, part) end
            end
            if #seats >= 2 then
                local occ, freeSeats, occSeat = 0, {}, nil
                for _, s in ipairs(seats) do
                    if s.Occupant then occ += 1; occSeat = s else table.insert(freeSeats, s) end
                end
                if occ == 0 then
                    table.insert(free, {tbl = tbl, seat = freeSeats[1]})
                elseif occ == 1 then
                    local on = nil
                    if occSeat then
                        for _, pl in ipairs(Players:GetPlayers()) do
                            local c = pl.Character
                            if c then
                                local h = c:FindFirstChild("Humanoid")
                                if h and h.SeatPart == occSeat then on = pl.Name; break end
                            end
                        end
                    end
                    local e = {tbl = tbl, seat = freeSeats[1], on = on}
                    if expectedPartner ~= "" and on == expectedPartner then
                        table.insert(partner, e)
                    else table.insert(partial, e) end
                end
            end
        end
        LOG("Table", "free=" .. #free .. " partial=" .. #partial .. " partner=" .. #partner)
        if #partner > 0 then return partner[1].tbl, partner[1].seat end
        if #free > 0 then return free[1].tbl, free[1].seat end
        if #partial > 0 then return partial[1].tbl, partial[1].seat end
        return nil, nil
    end

    local function waitForSeat(seat, t)
        local w = 0
        while w < t do
            local c = player.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                if h and h.Sit and h.SeatPart == seat then return true end
            end
            task.wait(0.5); w += 0.5
        end
        return false
    end

    local function isSeated(seat)
        local c = player.Character
        if not c then return false end
        local h = c:FindFirstChild("Humanoid")
        if not h then return false end
        return h.Sit and h.SeatPart == seat
    end

    local function getPartnerName(tbl, mySeat)
        local seats = {}
        for _, part in ipairs(tbl:GetDescendants()) do
            if part:IsA("Seat") or part:IsA("VehicleSeat") then table.insert(seats, part) end
        end
        local other
        for _, s in ipairs(seats) do if s ~= mySeat then other = s; break end end
        if not other then return nil end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= player then
                local c = pl.Character
                if c then
                    local h = c:FindFirstChild("Humanoid")
                    if h and h.Sit and h.SeatPart == other then return pl.Name end
                end
            end
        end
        return nil
    end

    local function resetSeatAndWait(seat, pos)
        while true do
            local c = player.Character
            if not c then return false end
            local h = c:FindFirstChild("Humanoid")
            if not h then return false end
            if isSeated(seat) then return true end
            pcall(function() h.Sit = false end); task.wait(0.2)
            h.Jump = true; task.wait(0.2)
            for _ = 1, 5 do
                if isSeated(seat) then return true end
                local dir = math.random(1,2) == 1 and 1 or -1
                local off = Vector3.new(dir * math.random(3,6), 0, 0)
                h:MoveTo(pos + off); task.wait(0.3)
                h:MoveTo(pos); task.wait(0.3)
                for _ = 1, 5 do
                    if isSeated(seat) then return true end
                    task.wait(0.2)
                end
            end
        end
    end

    local addBtnPath      = {"Main","Trade","Container","1","Frame","AddButton"}
    local firstContPath   = {"Main","Trade","Container","FrameAdd","Frame"}
    local resultContPath  = {"Main","Trade","Container","1","Frame"}
    local secondContPath  = {"Main","Trade","Container","2","Frame"}
    local acceptPath      = {"Main","Trade","Info","Accept"}
    local ready1Path      = {"Main","Trade","Info","Ready1"}
    local bottomTitlePath = {"Main","Trade","BottomTitle"}

    local RESULT_TIMEOUT        = 30
    local MAX_ATTEMPTS_PER_ITEM = 3
    local READY_TIMEOUT         = 30
    local ACCEPT_CHECK_INTERVAL = 0.5
    local ACCEPT_WAIT_TIMEOUT   = 30

    local function findParentButton(obj)
        local cur = obj
        while cur do
            if cur:IsA("TextButton") or cur:IsA("ImageButton") then return cur end
            cur = cur.Parent
        end
    end

    local function findTextInContainer(cont, search)
        for _, obj in ipairs(cont:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then return obj end
            end
        end
    end

    local function findResultElement(search)
        local cont = findObjectByPath(playerGui, table.unpack(resultContPath))
        if not cont then return nil end
        for _, obj in ipairs(cont:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then
                    local p = obj.Parent
                    if p and p.Name == "Title" then return obj end
                end
            end
        end
    end

    local function waitForObject(path, t)
        local w = 0
        while w < t do
            local o = findObjectByPath(playerGui, table.unpack(path))
            if o then return o end
            task.wait(0.5); w += 0.5
        end
    end

    local function getPercent()
        local bt = findObjectByPath(playerGui, table.unpack(bottomTitlePath))
        if not bt then return nil end
        local p = bt.Text:match("(%d+)%%")
        return p and tonumber(p) or nil
    end

    local function checkSecondCont(items)
        local c = findObjectByPath(playerGui, table.unpack(secondContPath))
        if not c then return false end
        for _, item in ipairs(items) do
            if not findTextInContainer(c, item) then return false end
        end
        return true
    end

    local function isTradeCompleted()
        local n = playerGui:FindFirstChild("Notifications")
        if not n then return false end
        for _, obj in ipairs(n:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find("trade completed", 1, true) then return true end
            end
        end
        return false
    end

    local function processItem(search)
        LOG("Item", "добавляю '" .. search .. "'")
        if findResultElement(search) then LOG("Item", "уже добавлен"); return true end
        for att = 1, MAX_ATTEMPTS_PER_ITEM do
            local ab = findObjectByPath(playerGui, table.unpack(addBtnPath))
            if not ab then LOG("Item", "попытка "..att..": нет AddButton"); task.wait(2); continue end
            fireSequence(ab)
            local fc = waitForObject(firstContPath, 5)
            if not fc then LOG("Item", "попытка "..att..": нет firstContainer"); task.wait(2); continue end
            local te = findTextInContainer(fc, search)
            if not te then LOG("Item", "попытка "..att..": не найден текст"); task.wait(2); continue end
            local btn = findParentButton(te)
            if not btn then LOG("Item", "попытка "..att..": нет кнопки"); task.wait(2); continue end
            fireSequence(btn)
            local w = 0
            while w < RESULT_TIMEOUT do
                task.wait(0.5); w += 0.5
                if findResultElement(search) then LOG("Item", "OK"); return true end
            end
        end
        WARN("Item", "провал '" .. search .. "'")
        return false
    end

    local function waitPreAccept(items, seat)
        local w = 0
        while w < ACCEPT_WAIT_TIMEOUT do
            if not isSeated(seat) then return false end
            local p = getPercent()
            if p and p <= 40 and checkSecondCont(items) then return true end
            task.wait(ACCEPT_CHECK_INTERVAL); w += ACCEPT_CHECK_INTERVAL
        end
        return false
    end

    local function acceptAndWait(items, seat)
        if not isSeated(seat) then return false end
        if not waitPreAccept(items, seat) then
            LOG("Accept", "preaccept не выполнены")
            return false
        end
        local ab = findObjectByPath(playerGui, table.unpack(acceptPath))
        if not ab then return false end
        LOG("Accept", "жму Accept")
        fireSequence(ab)
        local w = 0
        local r1 = findObjectByPath(playerGui, table.unpack(ready1Path))
        while w < READY_TIMEOUT do
            task.wait(0.5); w += 0.5
            if not isSeated(seat) then
                LOG("Accept", "слетел со стула"); return false
            end
            if isTradeCompleted() then return true end
            if r1 and r1:IsA("TextLabel") then
                if r1.Text == "Not ready." or r1.Text ~= "Ready!" then
                    LOG("Accept", "ready1.Text=" .. r1.Text); return false
                end
            end
        end
        return false
    end

    selectTeam()

    local config = nil
    local att = 0
    while config == nil and State.running and att < 50 do
        att += 1
        LOG("Config", "попытка #" .. att)
        local inv = collectInventory()
        if #inv > 0 then sendInventory(inv) else task.wait(SEND_INVENTORY_INTERVAL); continue end
        local w = 0
        while w < 120 do
            config = fetchConfig()
            if config then break end
            task.wait(CONFIG_POLL_INTERVAL); w += CONFIG_POLL_INTERVAL
        end
        if not config then task.wait(SEND_INVENTORY_INTERVAL) end
    end
    if not config then
        WARN("Trade", "не получили config — выход")
        State.beltScanPaused = false
        return
    end
    LOG("Config", "получен: partner=" .. tostring(config.partner_name) .. " job=" .. tostring(config.teleport_to_job_id))

    local tele = config.teleport_to_job_id
    if tele and tele ~= "" and tele ~= game.JobId then
        LOG("TP", "нужен телепорт на " .. tele .. " (сейчас " .. game.JobId .. ")")
        for _ = 1, 5 do
            if teleportToJobId(tele) then
                local w = 0
                while w < 30 and game.JobId ~= tele do task.wait(1); w += 1 end
                if game.JobId == tele then break end
            end
            task.wait(2)
        end
        if game.JobId ~= tele then
            WARN("Trade", "не удалось телепортнуться")
            State.beltScanPaused = false
            return
        end
    end

    processLoadFruit(config.load_fruit_items or {})

    collisionsDisabled = true
    LOG("Trade", "коллизии выключены")

    LOG("Trade", "иду к waypoint")
    if not moveToPosition(WAYPOINT_POSITION) then
        WARN("Trade", "waypoint не достигнут")
    end
    task.wait(1)

    local done = false
    local round = 0
    while not done and State.running do
        round += 1
        LOG("Trade", "раунд поиска стола #" .. round)
        local tbl, seat = findTradeTable(config.partner_name or "")
        if not tbl then
            LOG("Trade", "нет стола, ждём 5с")
            task.wait(5); continue
        end
        local pos = seat.Position
        LOG("Trade", "стол найден, seat=" .. seat:GetFullName())

        if not moveToPosition(pos) then task.wait(2); continue end
        do
            local c = player.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                if h and not h.Sit then pcall(function() h:MoveTo(pos) end) end
            end
        end
        if not waitForSeat(seat, 30) then
            LOG("Trade", "не сел за 30с, ресет")
            if not resetSeatAndWait(seat, pos) then task.wait(2); continue end
        end
        LOG("Trade", "сижу на стуле")

        while not done and State.running do
            if not isSeated(seat) then
                LOG("Trade", "слетел со стула")
                if not resetSeatAndWait(seat, pos) then break end
            end
            local pn = getPartnerName(tbl, seat)
            local ep = config.partner_name or ""
            LOG("Trade", "партнёр сейчас: " .. tostring(pn) .. " | ждём: " .. ep)

            if pn == nil then task.wait(1)
            elseif ep ~= "" and pn ~= ep then
                if not resetSeatAndWait(seat, pos) then break end
            else
                LOG("Trade", "партнёр подходит, добавляю items")
                local ok = true
                for _, item in ipairs(config.trade_items or {}) do
                    if not isSeated(seat) or not processItem(item) then ok = false; break end
                end
                if not ok then
                    if not resetSeatAndWait(seat, pos) then break end
                else
                    if acceptAndWait(config.load_fruit_items or {}, seat) then
                        LOG("Trade", "=== TRADE COMPLETED ===")
                        pcall(function()
                            game:HttpGet(SERVER_URL .. "/trade_completed?nickname=" .. HttpService.UrlEncode(player.Name))
                        end)
                        collisionsDisabled = false
                        done = true
                        break
                    else
                        if not resetSeatAndWait(seat, pos) then break end
                    end
                end
            end
        end
    end

    State.beltScanPaused = false
    State.tradeDone = true
    LOG("Trade", "=== DONE ===")
end

-- ============================================================
-- ГЛАВНЫЙ ДИСПЕТЧЕР
-- ============================================================
LOG("Main", "=== START === Blacklist: " .. #BLACKLIST .. " | Me: " .. player.Name)

LOG("Main", "ждём первый скан пояса (макс 240с)...")
local waitStart = tick()
while State.currentBelt == "Unknown" and tick() - waitStart < 240 do task.wait(1) end
if State.currentBelt == "Unknown" then
    WARN("Main", "пояс не определён за 240с — выход")
    return
end
LOG("Main", "belt = " .. State.currentBelt)

do
    if State.currentBelt ~= "Yellow" then
        local bad = getBlacklistedPlayer()
        if bad then
            LOG("Main", "blacklist найден " .. bad .. " — hop")
            serverHop()
            return
        end
    else
        LOG("Main", "пояс Yellow — blacklist игнорируется")
    end
end

local loop = 0
while State.running do
    loop += 1
    LOG("Main", "---- цикл #" .. loop .. " ----")
    do
        if State.currentBelt ~= "Yellow" then
            local bad = getBlacklistedPlayer()
            if bad then
                LOG("Main", "blacklist найден " .. bad .. " — hop")
                serverHop()
                return
            end
        end
    end

    local belt = State.currentBelt
    LOG("Main", "belt=" .. belt .. " nobeltDone=" .. tostring(State.nobeltDone) .. " tradeDone=" .. tostring(State.tradeDone))

    if belt == "Yellow" and not State.tradeDone then
        LOG("Main", "-> runTradeMode")
        runTradeMode()
    elseif not State.nobeltDone then
        LOG("Main", "-> runNoBeltMode")
        runNoBeltMode()
    else
        LOG("Main", "-> runHoldSixOne")
        runHoldSixOne()
    end
    LOG("Main", "выход из режима, следующий цикл через 3с")
    task.wait(3)
end
