--!nocheck
-- ============================================================
-- КОНФИГ
-- ============================================================
local BLACKLIST = {
    "PhilipHenry11750",
    "EdwardThornton360",
}

local BELT_SCAN_INTERVAL         = 30
local YELLOW_WHITE_TIMEOUT       = 30 * 60
local SERVER_URL                 = "http://192.168.31.89:8000"
local BELT_ORDER                 = {"White","Yellow","Orange","Green","Blue","Purple","Red","Black"}

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
}

-- ============================================================
-- ОБЩИЕ УТИЛИТЫ
-- ============================================================
local function fireSequence(btn)
    if not btn then return false end
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local fired = false
    local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
    for _, sigName in ipairs(signals) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn.Enabled and type(conn.Function) == "function" then
                        pcall(conn.Function)
                        fired = true
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

-- ============================================================
-- БЛЭКЛИСТ
-- ============================================================
local function sanitizeBlacklist(list)
    local clean, seen = {}, {}
    for _, name in ipairs(list) do
        if type(name) == "string" and name ~= "" and name ~= player.Name and not seen[name] then
            seen[name] = true
            table.insert(clean, name)
        end
    end
    return clean
end

BLACKLIST = sanitizeBlacklist(BLACKLIST)

local function getBlacklistedPlayer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            for _, bad in ipairs(BLACKLIST) do
                if plr.Name == bad then return plr.Name end
            end
        end
    end
    return nil
end

-- ============================================================
-- ЗАГРУЗКА ХАБА
-- ============================================================
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

-- ============================================================
-- БЕЛТ-СКАНЕР
-- ============================================================
-- Проверка: открыт ли инвентарь (по видимости Main внутри Inventory)
local function isInventoryOpen()
    local main = findObjectByPath(playerGui, "Inventory", "Inventory", "Main")
    if not main then return false end
    if not main:IsA("GuiObject") then return false end
    return main.Visible == true
end

-- Открытие инвентаря. Возвращает true если удалось.
local function ensureInventoryOpen()
    if isInventoryOpen() then return true end

    local menuBtn = findObjectByPath(playerGui, "Main", "MenuButton")
    if not menuBtn then return false end
    fireSequence(menuBtn); task.wait(1.0)

    local invBtn = findObjectByPath(playerGui, "Main", "InventoryButton")
    if not invBtn then return false end
    fireSequence(invBtn); task.wait(1.5)

    -- Даже если isInventoryOpen не сработал, попробуем найти Inventory напрямую
    if isInventoryOpen() then return true end
    local invGui = playerGui:FindFirstChild("Inventory")
    if invGui and invGui:FindFirstChild("Inventory") then return true end
    return false
end

local function doBeltScan()
    print("[BeltScan] >>> старт скана")

    -- 1. Открываем инвентарь
    if not ensureInventoryOpen() then
        warn("[BeltScan] не удалось открыть инвентарь")
        return nil
    end

    -- 2. Ждём пока появятся ключевые элементы инвентаря
    local waited = 0
    local cat3, tileGrid
    while waited < 10 do
        cat3 = findObjectByPath(playerGui, "Inventory", "Inventory", "Main", "NavigationRail", "HoverBox", "UpperBar", "Category3")
        tileGrid = findObjectByPath(playerGui, "Inventory", "Inventory", "Main", "PageContent", "TileGrid")
        if cat3 and tileGrid then break end
        task.wait(0.5); waited += 0.5
    end
    if not cat3 then warn("[BeltScan] Category3 не найдена"); return nil end
    if not tileGrid then warn("[BeltScan] TileGrid не найден"); return nil end

    -- 3. Открываем Category3
    fireSequence(cat3); task.wait(0.6)

    -- 4. Ищем ScrollingFrame
    local scrollingFrame = nil
    local obj = tileGrid
    while obj do
        if obj:IsA("ScrollingFrame") then scrollingFrame = obj; break end
        obj = obj.Parent
    end
    if not scrollingFrame then warn("[BeltScan] ScrollingFrame не найден"); return nil end

    local collected, collectedList = {}, {}
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
        return {Name = tileObject.Name, Text = clean}
    end

    local function collectVisible()
        for _, child in ipairs(tileGrid:GetDescendants()) do
            if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
                local info = extractTileInfo(child)
                if info and not collected[info.Name] then
                    collected[info.Name] = true
                    table.insert(collectedList, info)
                end
            end
        end
    end

    local canvasY = scrollingFrame.AbsoluteCanvasSize.Y
    local windowY = scrollingFrame.AbsoluteSize.Y
    local maxY = math.max(0, canvasY - windowY)

    scrollingFrame.CanvasPosition = Vector2.new(0, 0)
    task.wait(0.4)
    collectVisible()

    local step, curY, safety = 300, 0, 0
    while curY < maxY and safety < 1000 do
        curY = math.min(curY + step, maxY)
        scrollingFrame.CanvasPosition = Vector2.new(0, curY)
        task.wait(0.15)
        collectVisible()
        safety += 1
    end
    scrollingFrame.CanvasPosition = Vector2.new(0, maxY)
    task.wait(0.8)
    collectVisible()

    local highestBelt, highestIdx = nil, 0
    for _, tile in ipairs(collectedList) do
        local bp = tile.Text:find("Belt %(")
        if bp then
            local sp = bp + 6
            local ep = tile.Text:find(")", sp)
            if ep then
                local color = tile.Text:sub(sp, ep - 1)
                for i, oc in ipairs(BELT_ORDER) do
                    if color == oc and i > highestIdx then
                        highestIdx = i
                        highestBelt = color
                        break
                    end
                end
            end
        end
    end

    local result = highestBelt or "None"
    print("[BeltScan] <<< результат: " .. result .. " (тайлов: " .. #collectedList .. ")")
    return result
end

-- Фоновый поток сканера: сначала ждём загрузку игры, потом крутим цикл
task.spawn(function()
    -- Ждём персонажа
    if not player.Character then
        print("[BeltScan] ждём персонажа...")
        player.CharacterAdded:Wait()
    end

    -- Ждём, пока прогрузится Main.MenuButton
    local waited = 0
    while waited < 90 do
        if findObjectByPath(playerGui, "Main", "MenuButton") then break end
        task.wait(1); waited += 1
    end
    print("[BeltScan] инициализация готова (ждали " .. waited .. "с)")

    -- Небольшая пауза, чтобы игра/хаб устаканились
    task.wait(3)

    while State.running do
        if not State.beltScanPaused then
            local ok, belt = pcall(doBeltScan)
            if not ok then
                warn("[BeltScan] ошибка в скане: " .. tostring(belt))
            elseif belt then
                if belt ~= State.currentBelt then
                    State.currentBelt   = belt
                    State.beltChangedAt = tick()
                    print("[BeltScan] Новый режим: " .. belt)
                else
                    -- обновляем время последнего УСПЕШНОГО скана
                    State.beltChangedAt = tick()
                end
            end
        end
        task.wait(BELT_SCAN_INTERVAL)
    end
end)

-- ============================================================
-- СЕРВЕР-ХОП
-- ============================================================
local function serverHop()
    local function findServerBrowserButton()
        local topbar = playerGui:FindFirstChild("Topbar")
        if topbar then
            local frame = topbar:FindFirstChild("Frame")
            if frame then return frame:FindFirstChild("ServerBrowserButton") end
        end
        return nil
    end

    print("[Hop] Ждём ServerBrowserButton...")
    local waited = 0
    while not findServerBrowserButton() and waited < 30 do task.wait(0.5); waited += 0.5 end
    local sb = findServerBrowserButton()
    if not sb then warn("[Hop] Кнопка не найдена"); return false end
    fireSequence(sb)

    local function findVisibleJoin()
        for _, v in ipairs(playerGui:GetDescendants()) do
            if (v:IsA("TextButton") or v:IsA("TextBox")) and v.Text == "Join" and v.Visible then
                return v
            end
        end
        return nil
    end

    waited = 0
    while not findVisibleJoin() and waited < 30 do task.wait(0.5); waited += 0.5 end
    if not findVisibleJoin() then warn("[Hop] Join не найдена"); return false end

    local serverBrowser = playerGui:FindFirstChild("ServerBrowser")
    if not serverBrowser then return false end
    local frame = serverBrowser:FindFirstChild("Frame")
    if not frame then return false end
    local sf = frame:FindFirstChild("ScrollingFrame")
    if not sf then return false end

    local canvasSizeY = sf.CanvasSize.Y
    local maxY = (typeof(canvasSizeY) == "UDim") and canvasSizeY.Offset or canvasSizeY

    local scrollDuration = math.random(1, 10)
    local STEP, DELAY = 150, 0.03
    local curY = 0
    local start = tick()
    sf.CanvasPosition = Vector2.new(0, 0)
    task.wait(0.2)

    while (tick() - start) < scrollDuration and curY < maxY do
        curY = math.min(curY + STEP, maxY)
        sf.CanvasPosition = Vector2.new(0, curY)
        task.wait(DELAY)
    end

    local joinButtons = {}
    local function collectJoins(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if (child:IsA("TextButton") or child:IsA("TextBox")) and child.Text == "Join" and child.Visible then
                table.insert(joinButtons, child)
            end
            collectJoins(child)
        end
    end
    collectJoins(serverBrowser)
    if #joinButtons == 0 then warn("[Hop] Нет Join"); return false end

    local chosen = joinButtons[math.random(1, #joinButtons)]
    fireSequence(chosen)
    print("[Hop] Переходим на другой сервер")
    return true
end

-- ============================================================
-- ХАБ: опции
-- ============================================================
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local TAB_MAIN, OPT_MAIN = 6, 1

local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
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
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    local tabButton, count = nil, 0
    local function scan(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                count += 1
                if count == tabIndex then tabButton = c; return end
            end
            scan(c)
        end
    end
    scan(tabsScroll)
    return tabButton
end

local function findOption(root, optIndex)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optionBtn, count = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            count += 1
            if count == optIndex then optionBtn = c; break end
        end
    end
    return optionBtn
end

local function waitForOptions(expectedMin, timeout)
    timeout = timeout or 8
    expectedMin = expectedMin or 1
    local t0 = tick()
    local lastCount, stable = -1, 0
    while tick() - t0 < timeout do
        local root = getRoot()
        local container = root and safeFind(root, "Window", "Components", "Containers", "Container")
        local count = 0
        if container then
            for _, c in ipairs(container:GetChildren()) do
                if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                    count += 1
                end
            end
        end
        if count >= expectedMin then
            if count == lastCount then
                stable += 1
                if stable >= 2 then return true end
            else
                stable, lastCount = 0, count
            end
        else
            lastCount, stable = -1, 0
        end
        task.wait(0.15)
    end
    return false
end

local function setOption(tabIndex, optIndex, wantOn)
    local root = getRoot()
    if not root then return false end
    local tabButton = findTab(root, tabIndex)
    if not tabButton then return false end
    fireSequence(tabButton)
    if not waitForOptions(optIndex, 8) then return false end

    local optionBtn = findOption(root, optIndex)
    if not optionBtn then return false end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return false end
    local currentOn = (tostring(indicator.BackgroundColor3) == COLOR_ON)
    if currentOn == wantOn then return true end

    fireSequence(optionBtn); task.wait(0.2)
    for _ = 1, 5 do
        local ind2 = findIndicatorFrame(optionBtn)
        if ind2 and (tostring(ind2.BackgroundColor3) == COLOR_ON) == wantOn then return true end
        fireSequence(optionBtn)
        task.wait(0.25)
    end
    return false
end

-- ============================================================
-- РЕЖИМ "NO BELT"
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
    print("[Mode:NoBelt] dragon talon flow")

    local guard, guardT = 0, tick()
    while not hasDragonTalon() and State.running and State.currentBelt == "None" do
        setOption(TAB_MAIN, OPT_MAIN, true)
        task.wait(2)
        guard += 1
        if guard % 15 == 0 and tick() - guardT > 120 then
            warn("[Mode:NoBelt] dragon talon долго не появляется"); guardT = tick()
        end
    end
    if State.currentBelt ~= "None" then return end
    print("[Mode:NoBelt] dragon talon есть")

    while not isOnIsland() and State.running and State.currentBelt == "None" do
        setOption(TAB_MAIN, OPT_MAIN, true)
        task.wait(2)
    end
    if State.currentBelt ~= "None" then return end
    print("[Mode:NoBelt] на острове")

    setOption(TAB_MAIN, OPT_MAIN, false); task.wait(0.5)
    setOption(2, 4, true)

    local mastery = 0
    while State.running and State.currentBelt == "None" do
        task.wait(2)
        mastery = getMastery() or 0
        if mastery > 500 then break end
    end
    if State.currentBelt ~= "None" then return end

    setOption(2, 4, false); task.wait(0.5)
    setOption(TAB_MAIN, OPT_MAIN, true)
    print("[Mode:NoBelt] готово")
end

-- ============================================================
-- РЕЖИМ "YELLOW/WHITE"
-- ============================================================
local function runYellowWhiteMode()
    print("[Mode:YellowWhite] активирую 6,1 и жду обновления пояса")
    pcall(function() setOption(TAB_MAIN, OPT_MAIN, true) end)

    local modeAtStart = State.currentBelt

    while State.running do
        if State.currentBelt ~= modeAtStart then
            print("[Mode:YellowWhite] пояс изменился на " .. State.currentBelt .. " — переключение")
            return
        end

        if tick() - State.beltChangedAt > YELLOW_WHITE_TIMEOUT then
            print("[Mode:YellowWhite] пояс не обновлялся " .. YELLOW_WHITE_TIMEOUT .. " сек — смена сервера")
            serverHop()
            State.running = false
            return
        end

        pcall(function() setOption(TAB_MAIN, OPT_MAIN, true) end)
        task.wait(60)
    end
end

-- ============================================================
-- РЕЖИМ "ORANGE"
-- ============================================================
local function runOrangeMode()
    print("[Mode:Orange] трейд-режим запущен")
    State.beltScanPaused = true

    local SEND_INVENTORY_INTERVAL = 20
    local CONFIG_POLL_INTERVAL    = 10
    local MOVE_TIMEOUT            = 60
    local ARRIVE_DISTANCE         = 6
    local MOVE_SPEED              = 80
    local SPEED_Y                 = -2

    local SCROLL_STEP_PIXELS      = 10
    local SCROLL_WAIT_TIME        = 0.15
    local SCROLL_INITIAL_WAIT     = 0.5
    local SCROLL_FINAL_WAIT       = 1.0

    local TELEPORT_TAB            = 19
    local TELEPORT_OPT_TEXT       = 2
    local TELEPORT_OPT_ACTIVATE   = 3

    local WAYPOINT_POSITION       = Vector3.new(-12549.7, 337.5, -7501.1)

    local collisionsDisabled = false

    local function waitForObjectByPath(pathTable, timeout, description)
        local waited = 0
        while waited < timeout do
            local obj = findObjectByPath(playerGui, table.unpack(pathTable))
            if obj then return obj end
            task.wait(0.5); waited += 0.5
        end
        warn("Объект не найден: " .. (description or "?"))
        return nil
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
            if btn then return btn end
            task.wait(0.5); waited += 0.5
        end
        warn("HUD кнопка не найдена: " .. buttonName)
        return nil
    end

    local function selectTeam()
        local ok, err = pcall(function()
            local r = ReplicatedStorage:FindFirstChild("Remotes")
            if not r then error("Remotes исчезли") end
            local c = r:FindFirstChild("CommF_")
            if not c then error("CommF_ исчез") end
            c:InvokeServer("SetTeam", "Marines")
        end)
        if ok then print("[Team] Marines выбрана") else warn("[Team]", err) end
        task.wait(3)
    end

    local function extractTileInfo(tileObject)
        local function getTextFromDetails(details)
            if not details then return nil end
            local line1 = details:FindFirstChild("Line-1")
            if line1 and line1:IsA("TextLabel") and line1.Text ~= "" then return line1.Text end
            local line2 = details:FindFirstChild("Line-2")
            if line2 and line2:IsA("TextLabel") and line2.Text ~= "" then return line2.Text end
            for _, obj in ipairs(details:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Text ~= "" then return obj.Text end
            end
            return nil
        end
        local details = tileObject:FindFirstChild("Details")
        local text = getTextFromDetails(details)
        if not text then
            for _, obj in ipairs(tileObject:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Text ~= "" then text = obj.Text; break end
            end
        end
        if not text then return nil end
        local cleanText = text
        if cleanText:find(",") then cleanText = cleanText:sub(1, cleanText:find(",") - 1) end
        cleanText = cleanText:gsub("%s+$", "")
        local tileNumber = tonumber(tileObject.Name:sub(6)) or 0
        return {Name = tileObject.Name, Number = tileNumber, Text = cleanText}
    end

    local function findInventoryButtonByName(buttonName)
        local inv = playerGui:FindFirstChild("Inventory")
        if not inv then return nil end
        for _, obj in ipairs(inv:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == buttonName then return obj end
        end
        return nil
    end

    local function collectInventory()
        print("[Inventory] Открываю меню и инвентарь...")
        local menuButton = waitForHudButton("Menu", 10)
        if not menuButton then return {} end
        fireSequence(menuButton); task.wait(1.5)

        local itemsButton = waitForHudButton("Items", 10)
        if not itemsButton then return {} end
        fireSequence(itemsButton); task.wait(1.5)

        local category2 = waitForObjectByPath({"Inventory", "Inventory", "Main", "NavigationRail", "Category2"}, 5, "Category2")
        if not category2 then category2 = findInventoryButtonByName("Category2") end
        if not category2 then warn("[Inventory] Category2 не найдена"); return {} end
        fireSequence(category2); task.wait(SCROLL_INITIAL_WAIT)

        local tileGrid = waitForObjectByPath({"Inventory", "Inventory", "Main", "PageContent", "TileGrid"}, 5, "TileGrid")
        if not tileGrid then
            local inv = playerGui:FindFirstChild("Inventory")
            if inv then tileGrid = inv:FindFirstChild("TileGrid", true) end
        end
        if not tileGrid then warn("[Inventory] TileGrid не найден"); return {} end

        local scrollingFrame = nil
        local obj = tileGrid
        while obj do
            if obj:IsA("ScrollingFrame") then scrollingFrame = obj; break end
            obj = obj.Parent
        end

        local collected, collectedList = {}, {}
        local function collectVisibleTiles()
            for _, child in ipairs(tileGrid:GetDescendants()) do
                if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
                    local info = extractTileInfo(child)
                    if info and not collected[info.Name] then
                        collected[info.Name] = true
                        table.insert(collectedList, info)
                    end
                end
            end
        end

        if scrollingFrame then
            local canvasAbsoluteY = scrollingFrame.AbsoluteCanvasSize.Y
            local windowAbsoluteY = scrollingFrame.AbsoluteSize.Y
            scrollingFrame.CanvasPosition = Vector2.new(0, 0)
            task.wait(SCROLL_INITIAL_WAIT)
            collectVisibleTiles()
            local maxScrollY = math.max(0, canvasAbsoluteY - windowAbsoluteY)
            local currentY, safetyCounter, maxIterations = 0, 0, 1000
            while currentY < maxScrollY and safetyCounter < maxIterations do
                currentY = math.min(currentY + SCROLL_STEP_PIXELS, maxScrollY)
                scrollingFrame.CanvasPosition = Vector2.new(0, currentY)
                task.wait(SCROLL_WAIT_TIME)
                collectVisibleTiles()
                safetyCounter += 1
            end
            scrollingFrame.CanvasPosition = Vector2.new(0, maxScrollY)
            task.wait(SCROLL_FINAL_WAIT)
            collectVisibleTiles()
        else
            collectVisibleTiles()
        end

        table.sort(collectedList, function(a, b) return a.Number < b.Number end)
        local fruits = {}
        for _, tile in ipairs(collectedList) do
            if tile.Text ~= "" then table.insert(fruits, tile.Text) end
        end
        print("[Inventory] Собрано: " .. #fruits)
        return fruits
    end

    local function sendInventory(fruits)
        local fruitsStr = table.concat(fruits, ",")
        local url = SERVER_URL .. "/send_inventory?nickname=" .. HttpService:UrlEncode(player.Name)
            .. "&fruits=" .. HttpService:UrlEncode(fruitsStr)
            .. "&job_id=" .. HttpService:UrlEncode(game.JobId)
        local ok, result = pcall(function() return game:HttpGet(url) end)
        if ok then print("Инвентарь отправлен:", result) else warn("Ошибка отправки:", result) end
    end

    local function fetchConfig()
        local url = SERVER_URL .. "/get_config?nickname=" .. HttpService:UrlEncode(player.Name)
        local ok, response = pcall(function() return game:HttpGet(url) end)
        if not ok then warn("Ошибка запроса конфигурации:", response); return nil end
        local data = HttpService:JSONDecode(response)
        if data and data.partner_name then print("Конфигурация:", data); return data
        elseif data and data.error then print("Сервер:", data.error); return nil
        else print("Конфигурация не готова"); return nil end
    end

    local function formatItemName(name)
        local lower = name:lower()
        local cap = lower:sub(1, 1):upper() .. lower:sub(2)
        return cap .. "-" .. cap
    end

    local function invokeLoadFruit(fruitName)
        local ok, result = pcall(function()
            return ReplicatedStorage.Remotes.CommF_:InvokeServer("LoadFruit", fruitName)
        end)
        if ok then print("[OK] LoadFruit " .. fruitName .. " | " .. tostring(result))
        else warn("[ERR] LoadFruit " .. fruitName .. " | " .. tostring(result)) end
    end

    local function respawnCharacter()
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return false end
        pcall(function() hum.Health = 0 end)
        return true
    end

    local function waitForCharacterRespawn()
        local oldChar = player.Character
        local waited = 0
        while waited < 30 do
            local char = player.Character
            if char and char ~= oldChar then return char end
            task.wait(0.5); waited += 0.5
        end
        return nil
    end

    local function processLoadFruit(loadFruitItems)
        if #loadFruitItems == 0 then return true end
        for _, item in ipairs(loadFruitItems) do
            local formatted = formatItemName(item)
            print("LoadFruit '" .. item .. "' -> '" .. formatted .. "'")
            invokeLoadFruit(formatted)
            respawnCharacter()
            waitForCharacterRespawn()
            task.wait(1)
        end
        return true
    end

    local function findIndicatorFrame2(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Frame") then
                if tostring(child.BackgroundColor3) == COLOR_ON or tostring(child.BackgroundColor3) == COLOR_OFF then
                    return child
                end
            end
            local found = findIndicatorFrame2(child) if found then return found end
        end
    end

    local function findNthTabButton(tabsScroll, tabIndex)
        local tabButton, tabCount = nil, 0
        local function rec(p)
            if tabButton then return end
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("TextButton") or c:IsA("ImageButton") then
                    tabCount += 1
                    if tabCount == tabIndex then tabButton = c; return end
                end
                rec(c)
            end
        end
        rec(tabsScroll)
        return tabButton
    end

    local function findNthOption(container, optIndex)
        local optionBtn, optCount = nil, 0
        for _, c in ipairs(container:GetChildren()) do
            if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                optCount += 1
                if optCount == optIndex then optionBtn = c; break end
            end
        end
        return optionBtn
    end

    local function teleportToJobId(targetJobId)
        print("[Teleport] Телепорт на JobId:", targetJobId)
        local root = getRoot() if not root then warn("[Teleport] Хаб не найден"); return false end
        local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
        if not tabsScroll then warn("[Teleport] TabsScroll не найден"); return false end

        local tabButton = findNthTabButton(tabsScroll, TELEPORT_TAB)
        if not tabButton then warn("[Teleport] Вкладка " .. TELEPORT_TAB .. " не найдена"); return false end
        fireSequence(tabButton); task.wait(0.5)

        local container = safeFind(root, "Window", "Components", "Containers", "Container")
        if not container then warn("[Teleport] Container не найден"); return false end

        local optionText = findNthOption(container, TELEPORT_OPT_TEXT)
        if not optionText then warn("[Teleport] Опция " .. TELEPORT_OPT_TEXT .. " не найдена"); return false end

        local function findTextBox(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("TextBox") then return child end
                local found = findTextBox(child)
                if found then return found end
            end
            return nil
        end
        local textBox = findTextBox(optionText)
        if not textBox then warn("[Teleport] TextBox не найден"); return false end

        textBox:CaptureFocus(); task.wait(0.2)
        textBox.Text = targetJobId; task.wait(0.2)
        textBox:ReleaseFocus(true); task.wait(0.3)

        local optionActivate = findNthOption(container, TELEPORT_OPT_ACTIVATE)
        if not optionActivate then warn("[Teleport] Опция " .. TELEPORT_OPT_ACTIVATE .. " не найдена"); return false end
        fireSequence(optionActivate)
        print("[Teleport] Опция " .. TELEPORT_OPT_ACTIVATE .. " активирована")
        return true
    end

    local function waitForTeleport(targetJobId, timeout)
        local waited = 0
        while waited < timeout do
            if game.JobId == targetJobId then return true end
            task.wait(1); waited += 1
        end
        return false
    end

    task.spawn(function()
        while true do
            if collisionsDisabled then
                pcall(function()
                    local myChar = player.Character
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("BasePart") then
                            if not (myChar and obj:IsDescendantOf(myChar)) then
                                obj.CanCollide = false
                            end
                        end
                    end
                end)
            end
            task.wait(2)
        end
    end)

    local function moveToPosition(targetPosition)
        local targetX = targetPosition.X
        local targetZ = targetPosition.Z
        local targetY = targetPosition.Y + 3

        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        local rootPart = character:WaitForChild("HumanoidRootPart")
        local upper = character:FindFirstChild("UpperTorso")
        if not upper then return false end

        local oldBV = upper:FindFirstChildOfClass("BodyVelocity")
        if oldBV then oldBV:Destroy() end

        local mv = Instance.new("BodyVelocity")
        mv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        mv.Parent = upper

        do
            local p = rootPart.Position
            if math.abs(p.Y - targetY) > 0.5 then
                rootPart.CFrame = CFrame.new(p.X, targetY, p.Z)
            end
        end

        local isMoving = true
        local stuckThread = task.spawn(function()
            local lastPos = rootPart.Position
            local stuckSeconds = 0
            while isMoving do
                task.wait(1)
                local c = player.Character
                if not c then break end
                local hrp = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChild("Humanoid")
                if not hrp or not h then break end
                local moved = (hrp.Position - lastPos).Magnitude
                local toTarget = (Vector3.new(targetX, targetY, targetZ) - hrp.Position).Magnitude
                if toTarget < ARRIVE_DISTANCE or h.Sit then break end
                if moved < 1 then
                    stuckSeconds += 1
                    if stuckSeconds >= 2 then
                        pcall(function() h.Jump = true end)
                        stuckSeconds = 0
                    end
                else
                    stuckSeconds = 0
                end
                lastPos = hrp.Position
            end
        end)

        local waited = 0
        while waited < MOVE_TIMEOUT do
            local c = player.Character
            if not c then break end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local h = c:FindFirstChild("Humanoid")
            if not hrp or not h or h.Health <= 0 then break end

            if h.Sit then
                isMoving = false
                if mv then mv:Destroy() end
                task.cancel(stuckThread)
                return true
            end

            local cur = hrp.Position
            local dx = targetX - cur.X
            local dz = targetZ - cur.Z
            local dist = math.sqrt(dx*dx + dz*dz)

            if dist < ARRIVE_DISTANCE then
                isMoving = false
                if mv then mv:Destroy() end
                task.cancel(stuckThread)
                pcall(function() h:MoveTo(Vector3.new(targetX, cur.Y, targetZ)) end)
                return true
            end

            local nx = dx / math.max(dist, 0.001)
            local nz = dz / math.max(dist, 0.001)
            mv.Velocity = Vector3.new(nx * MOVE_SPEED, SPEED_Y, nz * MOVE_SPEED)

            local p = hrp.Position
            if math.abs(p.Y - targetY) > 0.5 then
                hrp.CFrame = CFrame.new(p.X, targetY, p.Z)
            end

            task.wait(0.05)
            waited += 0.05
        end

        isMoving = false
        if mv then mv:Destroy() end
        task.cancel(stuckThread)
        return false
    end

    local function findTradeTable(expectedPartnerName)
        local tradeTables = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "TradeTable" then table.insert(tradeTables, obj) end
        end
        local fullyFree, partiallyOccupied, withPartner = {}, {}, {}
        for _, tradeTable in ipairs(tradeTables) do
            local seats = {}
            for _, part in ipairs(tradeTable:GetDescendants()) do
                if part:IsA("Seat") or part:IsA("VehicleSeat") then table.insert(seats, part) end
            end
            if #seats >= 2 then
                local occupiedCount, freeSeats, occupiedSeat = 0, {}, nil
                for _, seat in ipairs(seats) do
                    if seat.Occupant then occupiedCount += 1; occupiedSeat = seat
                    else table.insert(freeSeats, seat) end
                end
                if occupiedCount == 0 then
                    table.insert(fullyFree, {tradeTable = tradeTable, freeSeat = freeSeats[1]})
                elseif occupiedCount == 1 then
                    local occupantName = nil
                    if occupiedSeat then
                        for _, plr in ipairs(Players:GetPlayers()) do
                            local c = plr.Character
                            if c then
                                local h = c:FindFirstChild("Humanoid")
                                if h and h.SeatPart == occupiedSeat then occupantName = plr.Name; break end
                            end
                        end
                    end
                    local entry = {tradeTable = tradeTable, freeSeat = freeSeats[1], occupantName = occupantName}
                    if expectedPartnerName ~= "" and occupantName == expectedPartnerName then
                        table.insert(withPartner, entry)
                    else
                        table.insert(partiallyOccupied, entry)
                    end
                end
            end
        end
        if #withPartner > 0 then return withPartner[1].tradeTable, withPartner[1].freeSeat, false end
        if #fullyFree > 0 then return fullyFree[1].tradeTable, fullyFree[1].freeSeat, true end
        if #partiallyOccupied > 0 then return partiallyOccupied[1].tradeTable, partiallyOccupied[1].freeSeat, false end
        return nil, nil, nil
    end

    local function waitForSeat(seatPart, timeout)
        local waited = 0
        while waited < timeout do
            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Sit and hum.SeatPart == seatPart then return true end
            end
            task.wait(0.5); waited += 0.5
        end
        return false
    end

    local function isSeated(mySeat)
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return false end
        return hum.Sit and hum.SeatPart == mySeat
    end

    local function getPartnerName(tradeTable, mySeat)
        local seats = {}
        for _, part in ipairs(tradeTable:GetDescendants()) do
            if part:IsA("Seat") or part:IsA("VehicleSeat") then table.insert(seats, part) end
        end
        local otherSeat
        for _, seat in ipairs(seats) do if seat ~= mySeat then otherSeat = seat; break end end
        if not otherSeat then return nil end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                local c = plr.Character
                if c then
                    local h = c:FindFirstChild("Humanoid")
                    if h and h.Sit and h.SeatPart == otherSeat then return plr.Name end
                end
            end
        end
        return nil
    end

    local function resetSeatAndWait(mySeat, targetPos)
        while true do
            local char = player.Character
            if not char then return false end
            local hum = char:FindFirstChild("Humanoid")
            if not hum then return false end
            if isSeated(mySeat) then return true end
            pcall(function() hum.Sit = false end); task.wait(0.2)
            hum.Jump = true; task.wait(0.2)
            for i = 1, 5 do
                if isSeated(mySeat) then return true end
                local direction = math.random(1,2) == 1 and 1 or -1
                local offsetDistance = math.random(3, 6)
                local offset = Vector3.new(direction * offsetDistance, 0, 0)
                hum:MoveTo(targetPos + offset); task.wait(0.3)
                hum:MoveTo(targetPos); task.wait(0.3)
                for _ = 1, 5 do
                    if isSeated(mySeat) then return true end
                    task.wait(0.2)
                end
            end
        end
    end

    local addButtonPath     = {"Main", "Trade", "Container", "1", "Frame", "AddButton"}
    local firstContainerPath= {"Main", "Trade", "Container", "FrameAdd", "Frame"}
    local resultContainerPath={"Main", "Trade", "Container", "1", "Frame"}
    local secondContainerPath={"Main", "Trade", "Container", "2", "Frame"}
    local acceptPath        = {"Main", "Trade", "Info", "Accept"}
    local ready1Path        = {"Main", "Trade", "Info", "Ready1"}
    local bottomTitlePath   = {"Main", "Trade", "BottomTitle"}

    local RESULT_TIMEOUT          = 30
    local MAX_ATTEMPTS_PER_ITEM   = 3
    local READY_TIMEOUT           = 30
    local ACCEPT_CHECK_INTERVAL   = 0.5
    local ACCEPT_WAIT_TIMEOUT     = 30

    local function findParentButton(obj)
        local current = obj
        while current do
            if current:IsA("TextButton") or current:IsA("ImageButton") then return current end
            current = current.Parent
        end
        return nil
    end

    local function findTextElementInContainer(container, search)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then return obj end
            end
        end
        return nil
    end

    local function findResultElement(search)
        local container = findObjectByPath(playerGui, table.unpack(resultContainerPath))
        if not container then return nil end
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then
                    local parent = obj.Parent
                    if parent and parent.Name == "Title" then return obj end
                end
            end
        end
        return nil
    end

    local function waitForObject(path, timeout)
        local waited = 0
        while waited < timeout do
            local obj = findObjectByPath(playerGui, table.unpack(path))
            if obj then return obj end
            task.wait(0.5); waited += 0.5
        end
        return nil
    end

    local function getPercent()
        local bottomTitle = findObjectByPath(playerGui, table.unpack(bottomTitlePath))
        if not bottomTitle then return nil end
        local percent = bottomTitle.Text:match("(%d+)%%")
        return percent and tonumber(percent) or nil
    end

    local function checkSecondContainer(loadFruitItems)
        local secondContainer = findObjectByPath(playerGui, table.unpack(secondContainerPath))
        if not secondContainer then return false end
        for _, item in ipairs(loadFruitItems) do
            if not findTextElementInContainer(secondContainer, item) then return false end
        end
        return true
    end

    local function isTradeCompleted()
        local notifications = playerGui:FindFirstChild("Notifications")
        if not notifications then return false end
        for _, obj in ipairs(notifications:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find("trade completed", 1, true) then return true end
            end
        end
        return false
    end

    local function processItem(searchText)
        if findResultElement(searchText) then return true end
        for _ = 1, MAX_ATTEMPTS_PER_ITEM do
            local addButton = findObjectByPath(playerGui, table.unpack(addButtonPath))
            if not addButton then task.wait(2); continue end
            fireSequence(addButton)
            local firstContainer = waitForObject(firstContainerPath, 5)
            if not firstContainer then task.wait(2); continue end
            local textElement = findTextElementInContainer(firstContainer, searchText)
            if not textElement then task.wait(2); continue end
            local buttonToActivate = findParentButton(textElement)
            if not buttonToActivate then task.wait(2); continue end
            fireSequence(buttonToActivate)
            local waitTime = 0
            while waitTime < RESULT_TIMEOUT do
                task.wait(0.5); waitTime += 0.5
                if findResultElement(searchText) then return true end
            end
        end
        return false
    end

    local function checkPreAcceptConditions(loadFruitItems, mySeat)
        if not isSeated(mySeat) then return false end
        local percent = getPercent()
        if not percent or percent > 40 then return false end
        if not checkSecondContainer(loadFruitItems) then return false end
        return true
    end

    local function waitForPreAcceptConditions(loadFruitItems, mySeat)
        local waited = 0
        while waited < ACCEPT_WAIT_TIMEOUT do
            if not isSeated(mySeat) then return false end
            if checkPreAcceptConditions(loadFruitItems, mySeat) then return true end
            task.wait(ACCEPT_CHECK_INTERVAL); waited += ACCEPT_CHECK_INTERVAL
        end
        return false
    end

    local function acceptAndWaitForCompletion(loadFruitItems, mySeat)
        if not isSeated(mySeat) then return false end
        if not waitForPreAcceptConditions(loadFruitItems, mySeat) then return false end
        local acceptBtn = findObjectByPath(playerGui, table.unpack(acceptPath))
        if not acceptBtn then return false end
        fireSequence(acceptBtn)
        local waited = 0
        local ready1 = findObjectByPath(playerGui, table.unpack(ready1Path))
        while waited < READY_TIMEOUT do
            task.wait(0.5); waited += 0.5
            if not isSeated(mySeat) then return false end
            if isTradeCompleted() then return true end
            if ready1 and ready1:IsA("TextLabel") then
                if ready1.Text == "Not ready." then return false
                elseif ready1.Text ~= "Ready!" then return false end
            end
        end
        return false
    end

    print("[Orange] Старт трейд-процедуры")
    selectTeam()

    local config = nil
    local cfgAttempts = 0
    while config == nil and State.running and cfgAttempts < 50 do
        cfgAttempts += 1
        local inventory = collectInventory()
        if #inventory > 0 then
            sendInventory(inventory)
        else
            task.wait(SEND_INVENTORY_INTERVAL)
            continue
        end
        local waited = 0
        while waited < 120 do
            config = fetchConfig()
            if config then break end
            task.wait(CONFIG_POLL_INTERVAL); waited += CONFIG_POLL_INTERVAL
        end
        if not config then
            warn("[Orange] Конфиг не получен, повтор")
            task.wait(SEND_INVENTORY_INTERVAL)
        end
    end

    if not config then
        warn("[Orange] Не удалось получить конфиг — выходим из режима")
        State.beltScanPaused = false
        return
    end
    print("[Orange] Конфиг получен")

    local teleportTarget = config.teleport_to_job_id
    if teleportTarget and teleportTarget ~= "" and teleportTarget ~= game.JobId then
        print("[Teleport] Требуется JobId: " .. teleportTarget)
        local attempts = 0
        while attempts < 5 do
            attempts += 1
            local ok = teleportToJobId(teleportTarget)
            if ok and waitForTeleport(teleportTarget, 30) then
                print("[Teleport] Успешно")
                break
            end
            task.wait(2)
        end
        if game.JobId ~= teleportTarget then
            warn("[Teleport] Не удалось перейти")
            State.beltScanPaused = false
            return
        end
    end

    local loadSuccess = processLoadFruit(config.load_fruit_items or {})
    if not loadSuccess then
        warn("[Orange] Ошибка ресета")
        State.beltScanPaused = false
        return
    end

    collisionsDisabled = true
    print("[Collisions] ON")

    print("[Travel] К waypoint:", WAYPOINT_POSITION)
    local reachedWaypoint = moveToPosition(WAYPOINT_POSITION)
    if reachedWaypoint then print("[Travel] Дошли до waypoint")
    else warn("[Travel] Не дошли, продолжаем") end
    task.wait(1)

    local tradeCompleted = false
    while not tradeCompleted and State.running do
        local tradeTable, mySeat, wasFullyFree = findTradeTable(config.partner_name or "")
        if not tradeTable then
            print("Стол не найден, ждём 5 сек.")
            task.wait(5); continue
        end
        local tablePos = mySeat.Position
        print("Найден стол. Тип:", wasFullyFree and "свободный" or "частично занят")

        local arrived = moveToPosition(tablePos)
        if not arrived then print("Не дошли."); task.wait(2); continue end

        do
            local c = player.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                if h and not h.Sit then
                    pcall(function() h:MoveTo(tablePos) end)
                end
            end
        end

        if not waitForSeat(mySeat, 30) then
            if not resetSeatAndWait(mySeat, tablePos) then task.wait(2); continue end
        end

        print("Сидим. Ожидаем партнёра...")

        while not tradeCompleted and State.running do
            if not isSeated(mySeat) then
                if not resetSeatAndWait(mySeat, tablePos) then break end
            end

            local partnerNameActual = getPartnerName(tradeTable, mySeat)
            local expectedPartner = config.partner_name or ""
            print("Партнёр:", partnerNameActual or "нет", "| ожидаем:", expectedPartner)

            if partnerNameActual == nil then
                task.wait(1)
            elseif expectedPartner ~= "" and partnerNameActual ~= expectedPartner then
                if not resetSeatAndWait(mySeat, tablePos) then break end
            else
                print("Партнёр подходит, добавляем предметы.")
                local allItemsAdded = true
                for _, itemName in ipairs(config.trade_items or {}) do
                    if not isSeated(mySeat) then
                        if not resetSeatAndWait(mySeat, tablePos) then allItemsAdded = false; break end
                        allItemsAdded = false; break
                    end
                    if not processItem(itemName) then allItemsAdded = false; break end
                end
                if not allItemsAdded then
                    if not resetSeatAndWait(mySeat, tablePos) then break end
                else
                    if not isSeated(mySeat) then
                        if not resetSeatAndWait(mySeat, tablePos) then break end
                    else
                        local done = acceptAndWaitForCompletion(config.load_fruit_items or {}, mySeat)
                        if done then
                            print("Трейд завершён!")
                            pcall(function()
                                game:HttpGet(SERVER_URL .. "/trade_completed?nickname=" .. HttpService:UrlEncode(player.Name))
                            end)
                            collisionsDisabled = false
                            print("[Collisions] OFF")
                            tradeCompleted = true
                            break
                        else
                            if not resetSeatAndWait(mySeat, tablePos) then break end
                        end
                    end
                end
            end
        end
    end

    State.beltScanPaused = false
    State.currentBelt = "Unknown"
    task.wait(1)
    print("[Orange] Трейд завершён, выходим из режима")
end

-- ============================================================
-- ГЛАВНЫЙ ДИСПЕТЧЕР
-- ============================================================
task.wait(5)

do
    local bad = getBlacklistedPlayer()
    if bad then
        print("[Blacklist] На сервере найден " .. bad .. " — смена сервера")
        serverHop()
        return
    end
end

print("[Main] Ждём первый скан пояса...")
local waitStart = tick()
while State.currentBelt == "Unknown" and tick() - waitStart < 180 do task.wait(1) end
if State.currentBelt == "Unknown" then
    warn("[Main] Не удалось определить пояс за 180 сек — смена сервера")
    serverHop()
    return
end
print("[Main] Текущий режим: " .. State.currentBelt)

while State.running do
    do
        local bad = getBlacklistedPlayer()
        if bad then
            print("[Blacklist] Найден " .. bad .. " — смена сервера")
            serverHop()
            return
        end
    end

    local belt = State.currentBelt

    if belt == "Orange" then
        runOrangeMode()
    elseif belt == "Yellow" or belt == "White" then
        runYellowWhiteMode()
    elseif belt == "None" then
        runNoBeltMode()
    else
        print("[Main] Режим " .. belt .. " не обрабатывается, ждём...")
        task.wait(30)
    end

    task.wait(3)
end
