--!nocheck
-- ============================================================
-- КОНФИГ
-- ============================================================
local BLACKLIST = {
    "ТвойНикЗдесь",
    "НикВрага1",
    "НикВрага2",
}
local BELT_SCAN_INTERVAL   = 30
local YELLOW_WHITE_TIMEOUT = 30 * 60
local SERVER_URL           = "http://192.168.1.100:8000"
local BELT_ORDER           = {"White","Yellow","Orange","Green","Blue","Purple","Red","Black"}

-- ============================================================
-- СЕРВИСЫ
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[Script] загружен, LocalPlayer = " .. player.Name)

local State = {
    currentBelt     = "Unknown",
    beltChangedAt   = tick(),
    beltScanPaused  = false,
    running         = true,
}

-- ============================================================
-- УТИЛИТЫ
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
                        if pcall(conn.Function) then fired = true end
                    end
                end
            end
        end
    end
    if not fired then
        pcall(function() btn:Activate() end)
        fired = true
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

local function findDescendantByName(root, name, class)
    if not root then return nil end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == name and (not class or obj:IsA(class)) then return obj end
    end
    return nil
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
local function isInventoryOpen()
    local invScreen = playerGui:FindFirstChild("Inventory")
    if not invScreen then return false end
    if invScreen:IsA("ScreenGui") and not invScreen.Enabled then return false end
    if invScreen:IsA("GuiObject") and not invScreen.Visible then return false end
    local inner = invScreen:FindFirstChild("Inventory")
    if not inner then return false end
    if inner:IsA("GuiObject") and not inner.Visible then return false end
    return true
end

local function getMenuButton()
    local b = findObjectByPath(playerGui, "Main", "MenuButton")
    if b then return b end
    local mainGui = playerGui:FindFirstChild("Main")
    return findDescendantByName(mainGui, "MenuButton", "TextButton")
end

local function getInventoryButton()
    local b = findObjectByPath(playerGui, "Main", "InventoryButton")
    if b then return b end
    local mainGui = playerGui:FindFirstChild("Main")
    return findDescendantByName(mainGui, "InventoryButton", "TextButton")
end

local function ensureInventoryOpen()
    if isInventoryOpen() then
        print("[BeltScan] инвентарь уже открыт")
        return true
    end
    local menuBtn = getMenuButton()
    if not menuBtn then
        warn("[BeltScan] MenuButton не найден")
        return false
    end
    print("[BeltScan] клик MenuButton (" .. menuBtn:GetFullName() .. ")")
    fireSequence(menuBtn); task.wait(1.5)

    local invBtn = getInventoryButton()
    if not invBtn then
        warn("[BeltScan] InventoryButton не найден")
        return false
    end
    print("[BeltScan] клик InventoryButton (" .. invBtn:GetFullName() .. ")")
    fireSequence(invBtn); task.wait(1.5)

    if isInventoryOpen() then return true end
    local invGui = playerGui:FindFirstChild("Inventory")
    if invGui and invGui:FindFirstChild("Inventory") then return true end
    return false
end

local function doBeltScan()
    print("[BeltScan] >>> старт скана")
    if not ensureInventoryOpen() then
        warn("[BeltScan] не удалось открыть инвентарь")
        return nil
    end

    -- Ждём Category3 и TileGrid
    local waited, cat3, tileGrid = 0, nil, nil
    while waited < 12 do
        cat3 = findObjectByPath(playerGui, "Inventory", "Inventory", "Main", "NavigationRail", "HoverBox", "UpperBar", "Category3")
        tileGrid = findObjectByPath(playerGui, "Inventory", "Inventory", "Main", "PageContent", "TileGrid")
        if cat3 and tileGrid then break end
        task.wait(0.5); waited += 0.5
    end
    if not cat3 then
        warn("[BeltScan] Category3 не найдена")
        local invGui = playerGui:FindFirstChild("Inventory")
        if invGui then
            print("[BeltScan] дамп Inventory:")
            for _, c in ipairs(invGui:GetDescendants()) do
                if c:IsA("TextButton") or c:IsA("ImageButton") then
                    print("  BTN " .. c:GetFullName())
                end
            end
        end
        return nil
    end
    if not tileGrid then warn("[BeltScan] TileGrid не найден"); return nil end

    fireSequence(cat3); task.wait(0.6)

    local scrollingFrame = nil
    local obj = tileGrid
    while obj do
        if obj:IsA("ScrollingFrame") then scrollingFrame = obj; break end
        obj = obj.Parent
    end
    if not scrollingFrame then warn("[BeltScan] ScrollingFrame не найден"); return nil end

    local collected, collectedList = {}, {}
    local function extract(tileObject)
        local details = tileObject:FindFirstChild("Details")
        local text = nil
        if details then
            local l1 = details:FindFirstChild("Line-1")
            if l1 and l1:IsA("TextLabel") and l1.Text ~= "" then text = l1.Text end
            if not text then
                local l2 = details:FindFirstChild("Line-2")
                if l2 and l2:IsA("TextLabel") and l2.Text ~= "" then text = l2.Text end
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
    local function collect()
        for _, ch in ipairs(tileGrid:GetDescendants()) do
            if ch:IsA("ImageButton") and ch.Name:sub(1,5) == "Tile-" then
                local info = extract(ch)
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
    task.wait(0.4); collect()
    local step, curY, safety = 300, 0, 0
    while curY < maxY and safety < 1000 do
        curY = math.min(curY + step, maxY)
        scrollingFrame.CanvasPosition = Vector2.new(0, curY)
        task.wait(0.15); collect(); safety += 1
    end
    scrollingFrame.CanvasPosition = Vector2.new(0, maxY)
    task.wait(0.8); collect()

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
                        highestIdx = i; highestBelt = color; break
                    end
                end
            end
        end
    end
    local result = highestBelt or "None"
    print("[BeltScan] <<< результат: " .. result .. " (тайлов: " .. #collectedList .. ")")
    return result
end

task.spawn(function()
    local ok, err = pcall(function()
        print("[BeltScan] поток запущен, ждём Main.MenuButton...")
        local t0 = tick()
        local found = false
        while tick() - t0 < 120 do
            if getMenuButton() then found = true; break end
            task.wait(1)
        end
        print("[BeltScan] MenuButton найден: " .. tostring(found))
        if not found then
            print("[BeltScan] ДАМП PlayerGui:")
            for _, ch in ipairs(playerGui:GetChildren()) do
                print("  - " .. ch.Name .. " (" .. ch.ClassName .. ")")
            end
            local mainGui = playerGui:FindFirstChild("Main")
            if mainGui then
                print("[BeltScan] ДАМП Main:")
                for _, ch in ipairs(mainGui:GetChildren()) do
                    print("  - " .. ch.Name .. " (" .. ch.ClassName .. ")")
                end
            end
        end
        task.wait(5)
        while State.running do
            if not State.beltScanPaused then
                print("[BeltScan] >>> цикл, скан")
                local scanOk, belt = pcall(doBeltScan)
                if not scanOk then
                    warn("[BeltScan] ошибка: " .. tostring(belt))
                elseif belt then
                    if belt ~= State.currentBelt then
                        State.currentBelt = belt
                        State.beltChangedAt = tick()
                        print("[BeltScan] НОВЫЙ РЕЖИМ: " .. belt)
                    else
                        State.beltChangedAt = tick()
                    end
                else
                    warn("[BeltScan] сканер вернул nil")
                end
            end
            task.wait(BELT_SCAN_INTERVAL)
        end
    end)
    if not ok then warn("[BeltScan] поток упал: " .. tostring(err)) end
end)

-- ============================================================
-- СЕРВЕР-ХОП
-- ============================================================
local function serverHop()
    local function findSB()
        local topbar = playerGui:FindFirstChild("Topbar")
        if topbar then
            local frame = topbar:FindFirstChild("Frame")
            if frame then return frame:FindFirstChild("ServerBrowserButton") end
        end
        return nil
    end
    print("[Hop] Ждём ServerBrowserButton...")
    local waited = 0
    while not findSB() and waited < 30 do task.wait(0.5); waited += 0.5 end
    local sb = findSB()
    if not sb then warn("[Hop] кнопка не найдена"); return false end
    fireSequence(sb)

    local function findJoin()
        for _, v in ipairs(playerGui:GetDescendants()) do
            if (v:IsA("TextButton") or v:IsA("TextBox")) and v.Text == "Join" and v.Visible then return v end
        end
        return nil
    end
    waited = 0
    while not findJoin() and waited < 30 do task.wait(0.5); waited += 0.5 end
    if not findJoin() then warn("[Hop] Join не найдена"); return false end

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
    local curY, start = 0, tick()
    sf.CanvasPosition = Vector2.new(0, 0); task.wait(0.2)
    while (tick() - start) < scrollDuration and curY < maxY do
        curY = math.min(curY + STEP, maxY)
        sf.CanvasPosition = Vector2.new(0, curY); task.wait(DELAY)
    end
    local joins = {}
    local function collect(p)
        for _, c in ipairs(p:GetChildren()) do
            if (c:IsA("TextButton") or c:IsA("TextBox")) and c.Text == "Join" and c.Visible then
                table.insert(joins, c)
            end
            collect(c)
        end
    end
    collect(serverBrowser)
    if #joins == 0 then warn("[Hop] нет Join"); return false end
    fireSequence(joins[math.random(1, #joins)])
    print("[Hop] уходим")
    return true
end

-- ============================================================
-- ХАБ: опции
-- ============================================================
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local TAB_MAIN, OPT_MAIN = 6, 1

local function getRoot()
    local ok, children = pcall(function() return CoreGui:GetChildren() end)
    if not ok or not children then return nil end
    for _, child in ipairs(children) do
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
        fireSequence(optionBtn); task.wait(0.25)
    end
    return false
end

-- ============================================================
-- РЕЖИМ "NO BELT"
-- ============================================================
local function hasDragonTalon()
    local pg = player:FindFirstChild("PlayerGui"); if not pg then return false end
    local wac = pg:FindFirstChild("WeaponAssetCache"); if not wac then return false end
    return wac:FindFirstChild("dragontalon") ~= nil
end
local function isOnIsland()
    local world = Workspace:FindFirstChild("_WorldOrigin"); if not world then return false end
    local sounds = world:FindFirstChild("Sounds"); if not sounds then return false end
    local locs = sounds:FindFirstChild("Locations"); if not locs then return false end
    return locs:FindFirstChild("Submerged Island") ~= nil
end
local function getMastery()
    local pg = player:FindFirstChild("PlayerGui"); if not pg then return nil end
    local main = pg:FindFirstChild("Main"); if not main then return nil end
    local lbl = main:FindFirstChild("MobileMasteryLevel"); if not lbl then return nil end
    return tonumber(string.match(lbl.Text or "", "%d+"))
end

local function runNoBeltMode()
    print("[Mode:NoBelt] start")
    local guard, guardT = 0, tick()
    while not hasDragonTalon() and State.running and State.currentBelt == "None" do
        setOption(TAB_MAIN, OPT_MAIN, true); task.wait(2)
        guard += 1
        if guard % 15 == 0 and tick() - guardT > 120 then
            warn("[Mode:NoBelt] dragon talon долго нет"); guardT = tick()
        end
    end
    if State.currentBelt ~= "None" then return end
    print("[Mode:NoBelt] dragon talon есть")
    while not isOnIsland() and State.running and State.currentBelt == "None" do
        setOption(TAB_MAIN, OPT_MAIN, true); task.wait(2)
    end
    if State.currentBelt ~= "None" then return end
    print("[Mode:NoBelt] на острове")
    setOption(TAB_MAIN, OPT_MAIN, false); task.wait(0.5)
    setOption(2, 4, true)
    local mastery = 0
    while State.running and State.currentBelt == "None" do
        task.wait(2); mastery = getMastery() or 0
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
    print("[Mode:YellowWhite] 6,1 on, ждём пояс")
    pcall(function() setOption(TAB_MAIN, OPT_MAIN, true) end)
    local modeAtStart = State.currentBelt
    while State.running do
        if State.currentBelt ~= modeAtStart then
            print("[Mode:YellowWhite] пояс изменился на " .. State.currentBelt); return
        end
        if tick() - State.beltChangedAt > YELLOW_WHITE_TIMEOUT then
            print("[Mode:YellowWhite] таймаут — хоп"); serverHop(); State.running = false; return
        end
        pcall(function() setOption(TAB_MAIN, OPT_MAIN, true) end)
        task.wait(60)
    end
end

-- ============================================================
-- РЕЖИМ "ORANGE"
-- ============================================================
local function runOrangeMode()
    print("[Mode:Orange] start")
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

    local function waitPath(pathTable, timeout, desc)
        local waited = 0
        while waited < timeout do
            local obj = findObjectByPath(playerGui, table.unpack(pathTable))
            if obj then return obj end
            task.wait(0.5); waited += 0.5
        end
        warn("Объект не найден: " .. (desc or "?")); return nil
    end
    local function findHudBtn(name)
        local hudRoot = playerGui:FindFirstChild("HUDRoot"); if not hudRoot then return nil end
        local frame = hudRoot:FindFirstChild("Frame"); if not frame then return nil end
        local hud = frame:FindFirstChild("HUD"); if not hud then return nil end
        local function search(node)
            for _, child in ipairs(node:GetChildren()) do
                if (child:IsA("TextButton") or child:IsA("ImageButton")) and child.Name == name then return child end
                local f = search(child); if f then return f end
            end
        end
        return search(hud)
    end
    local function waitHudBtn(name, timeout)
        local waited = 0
        while waited < timeout do
            local b = findHudBtn(name); if b then return b end
            task.wait(0.5); waited += 0.5
        end
        warn("HUD кнопка не найдена: " .. name); return nil
    end
    local function selectTeam()
        local ok, err = pcall(function()
            local r = ReplicatedStorage:FindFirstChild("Remotes"); if not r then error("Remotes") end
            local c = r:FindFirstChild("CommF_"); if not c then error("CommF_") end
            c:InvokeServer("SetTeam", "Marines")
        end)
        if ok then print("[Team] Marines") else warn("[Team]", err) end
        task.wait(3)
    end
    local function extractTileInfo(t)
        local details = t:FindFirstChild("Details")
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
            for _, o in ipairs(t:GetDescendants()) do
                if o:IsA("TextLabel") and o.Text ~= "" then text = o.Text; break end
            end
        end
        if not text then return nil end
        local clean = text
        if clean:find(",") then clean = clean:sub(1, clean:find(",") - 1) end
        clean = clean:gsub("%s+$", "")
        return {Name = t.Name, Number = tonumber(t.Name:sub(6)) or 0, Text = clean}
    end
    local function findInvBtnByName(name)
        local inv = playerGui:FindFirstChild("Inventory"); if not inv then return nil end
        for _, obj in ipairs(inv:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == name then return obj end
        end
        return nil
    end
    local function collectInventory()
        print("[Inventory] open")
        local mb = waitHudBtn("Menu", 10); if not mb then return {} end
        fireSequence(mb); task.wait(1.5)
        local ib = waitHudBtn("Items", 10); if not ib then return {} end
        fireSequence(ib); task.wait(1.5)
        local c2 = waitPath({"Inventory","Inventory","Main","NavigationRail","Category2"}, 5, "Category2")
        if not c2 then c2 = findInvBtnByName("Category2") end
        if not c2 then warn("[Inventory] Category2 нет"); return {} end
        fireSequence(c2); task.wait(SCROLL_INITIAL_WAIT)
        local tg = waitPath({"Inventory","Inventory","Main","PageContent","TileGrid"}, 5, "TileGrid")
        if not tg then
            local inv = playerGui:FindFirstChild("Inventory")
            if inv then tg = inv:FindFirstChild("TileGrid", true) end
        end
        if not tg then warn("[Inventory] TileGrid нет"); return {} end
        local sf = nil; local o = tg
        while o do if o:IsA("ScrollingFrame") then sf = o; break end o = o.Parent end
        local coll, list = {}, {}
        local function cvt()
            for _, ch in ipairs(tg:GetDescendants()) do
                if ch:IsA("ImageButton") and ch.Name:sub(1,5) == "Tile-" then
                    local info = extractTileInfo(ch)
                    if info and not coll[info.Name] then coll[info.Name] = true; table.insert(list, info) end
                end
            end
        end
        if sf then
            local canvasY = sf.AbsoluteCanvasSize.Y; local winY = sf.AbsoluteSize.Y
            sf.CanvasPosition = Vector2.new(0, 0); task.wait(SCROLL_INITIAL_WAIT); cvt()
            local maxY = math.max(0, canvasY - winY)
            local curY, sc, mi = 0, 0, 1000
            while curY < maxY and sc < mi do
                curY = math.min(curY + SCROLL_STEP_PIXELS, maxY)
                sf.CanvasPosition = Vector2.new(0, curY); task.wait(SCROLL_WAIT_TIME); cvt(); sc += 1
            end
            sf.CanvasPosition = Vector2.new(0, maxY); task.wait(SCROLL_FINAL_WAIT); cvt()
        else cvt() end
        table.sort(list, function(a,b) return a.Number < b.Number end)
        local fruits = {}
        for _, t in ipairs(list) do if t.Text ~= "" then table.insert(fruits, t.Text) end end
        print("[Inventory] собрано: " .. #fruits)
        return fruits
    end
    local function sendInventory(fruits)
        local fstr = table.concat(fruits, ",")
        local url = SERVER_URL .. "/send_inventory?nickname=" .. HttpService:UrlEncode(player.Name)
            .. "&fruits=" .. HttpService:UrlEncode(fstr)
            .. "&job_id=" .. HttpService:UrlEncode(game.JobId)
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok then print("Инвентарь отправлен:", res) else warn("Ошибка:", res) end
    end
    local function fetchConfig()
        local url = SERVER_URL .. "/get_config?nickname=" .. HttpService:UrlEncode(player.Name)
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if not ok then warn("Ошибка конфига:", res); return nil end
        local data = HttpService:JSONDecode(res)
        if data and data.partner_name then print("Конфиг:", data); return data
        elseif data and data.error then print("Сервер:", data.error); return nil
        else print("Конфиг не готов"); return nil end
    end
    local function fmtItem(name)
        local lower = name:lower()
        return lower:sub(1,1):upper() .. lower:sub(2) .. "-" .. lower:sub(1,1):upper() .. lower:sub(2)
    end
    local function invokeLoadFruit(fn)
        local ok, res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("LoadFruit", fn) end)
        if ok then print("[OK] LoadFruit " .. fn .. " | " .. tostring(res))
        else warn("[ERR] LoadFruit " .. fn .. " | " .. tostring(res)) end
    end
    local function respawn()
        local char = player.Character; if not char then return false end
        local hum = char:FindFirstChild("Humanoid"); if not hum then return false end
        pcall(function() hum.Health = 0 end); return true
    end
    local function waitRespawn()
        local old = player.Character; local w = 0
        while w < 30 do
            local c = player.Character
            if c and c ~= old then return c end
            task.wait(0.5); w += 0.5
        end
    end
    local function processLoadFruit(items)
        if #items == 0 then return true end
        for _, it in ipairs(items) do
            local f = fmtItem(it); print("LoadFruit " .. it .. " -> " .. f)
            invokeLoadFruit(f); respawn(); waitRespawn(); task.wait(1)
        end
        return true
    end
    local function findNthTab(ts, idx)
        local b, c = nil, 0
        local function rec(p)
            if b then return end
            for _, ch in ipairs(p:GetChildren()) do
                if ch:IsA("TextButton") or ch:IsA("ImageButton") then
                    c += 1; if c == idx then b = ch; return end
                end
                rec(ch)
            end
        end
        rec(ts); return b
    end
    local function findNthOpt(container, idx)
        local b, c = nil, 0
        for _, ch in ipairs(container:GetChildren()) do
            if ch.Name == "Option" and ch.Visible and (ch:IsA("TextButton") or ch:IsA("ImageButton")) then
                c += 1; if c == idx then b = ch; break end
            end
        end
        return b
    end
    local function teleportToJobId(target)
        print("[Teleport] JobId:", target)
        local root = getRoot(); if not root then warn("[Teleport] нет хаба"); return false end
        local ts = safeFind(root, "Window", "Components", "TabsScroll")
        if not ts then return false end
        local tb = findNthTab(ts, TELEPORT_TAB)
        if not tb then return false end
        fireSequence(tb); task.wait(0.5)
        local container = safeFind(root, "Window", "Components", "Containers", "Container")
        if not container then return false end
        local optText = findNthOpt(container, TELEPORT_OPT_TEXT)
        if not optText then return false end
        local function findTB(p)
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("TextBox") then return c end
                local f = findTB(c); if f then return f end
            end
        end
        local textBox = findTB(optText); if not textBox then return false end
        textBox:CaptureFocus(); task.wait(0.2)
        textBox.Text = target; task.wait(0.2)
        textBox:ReleaseFocus(true); task.wait(0.3)
        local optAct = findNthOpt(container, TELEPORT_OPT_ACTIVATE); if not optAct then return false end
        fireSequence(optAct); return true
    end
    local function waitTeleport(target, timeout)
        local w = 0
        while w < timeout do
            if game.JobId == target then return true end
            task.wait(1); w += 1
        end
        return false
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

    local function moveTo(target)
        local tx, tz, ty = target.X, target.Z, target.Y + 3
        local char = player.Character or player.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")
        local root = char:WaitForChild("HumanoidRootPart")
        local upper = char:FindFirstChild("UpperTorso"); if not upper then return false end
        local oldBV = upper:FindFirstChildOfClass("BodyVelocity"); if oldBV then oldBV:Destroy() end
        local mv = Instance.new("BodyVelocity")
        mv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        mv.Parent = upper
        do
            local p = root.Position
            if math.abs(p.Y - ty) > 0.5 then root.CFrame = CFrame.new(p.X, ty, p.Z) end
        end
        local moving = true
        local st = task.spawn(function()
            local lp = root.Position; local sc = 0
            while moving do
                task.wait(1)
                local c = player.Character; if not c then break end
                local hrp = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChild("Humanoid")
                if not hrp or not h then break end
                local moved = (hrp.Position - lp).Magnitude
                local toT = (Vector3.new(tx, ty, tz) - hrp.Position).Magnitude
                if toT < ARRIVE_DISTANCE or h.Sit then break end
                if moved < 1 then
                    sc += 1
                    if sc >= 2 then pcall(function() h.Jump = true end); sc = 0 end
                else sc = 0 end
                lp = hrp.Position
            end
        end)
        local w = 0
        while w < MOVE_TIMEOUT do
            local c = player.Character; if not c then break end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local h = c:FindFirstChild("Humanoid")
            if not hrp or not h or h.Health <= 0 then break end
            if h.Sit then moving = false; if mv then mv:Destroy() end; task.cancel(st); return true end
            local cur = hrp.Position
            local dx, dz = tx - cur.X, tz - cur.Z
            local d = math.sqrt(dx*dx + dz*dz)
            if d < ARRIVE_DISTANCE then
                moving = false; if mv then mv:Destroy() end; task.cancel(st)
                pcall(function() h:MoveTo(Vector3.new(tx, cur.Y, tz)) end)
                return true
            end
            local nx, nz = dx/math.max(d, 0.001), dz/math.max(d, 0.001)
            mv.Velocity = Vector3.new(nx*MOVE_SPEED, SPEED_Y, nz*MOVE_SPEED)
            local p = hrp.Position
            if math.abs(p.Y - ty) > 0.5 then hrp.CFrame = CFrame.new(p.X, ty, p.Z) end
            task.wait(0.05); w += 0.05
        end
        moving = false; if mv then mv:Destroy() end; task.cancel(st)
        return false
    end

    local function findTradeTable(expP)
        local tables = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "TradeTable" then table.insert(tables, obj) end
        end
        local free, part, withP = {}, {}, {}
        for _, tt in ipairs(tables) do
            local seats = {}
            for _, p in ipairs(tt:GetDescendants()) do
                if p:IsA("Seat") or p:IsA("VehicleSeat") then table.insert(seats, p) end
            end
            if #seats >= 2 then
                local occ, fseats, oseat = 0, {}, nil
                for _, s in ipairs(seats) do
                    if s.Occupant then occ += 1; oseat = s else table.insert(fseats, s) end
                end
                if occ == 0 then table.insert(free, {tt = tt, fs = fseats[1]})
                elseif occ == 1 then
                    local name = nil
                    if oseat then
                        for _, plr in ipairs(Players:GetPlayers()) do
                            local c = plr.Character
                            if c then
                                local h = c:FindFirstChild("Humanoid")
                                if h and h.SeatPart == oseat then name = plr.Name; break end
                            end
                        end
                    end
                    local e = {tt = tt, fs = fseats[1], on = name}
                    if expP ~= "" and name == expP then table.insert(withP, e)
                    else table.insert(part, e) end
                end
            end
        end
        if #withP > 0 then return withP[1].tt, withP[1].fs, false end
        if #free > 0 then return free[1].tt, free[1].fs, true end
        if #part > 0 then return part[1].tt, part[1].fs, false end
        return nil, nil, nil
    end
    local function waitSeat(seat, timeout)
        local w = 0
        while w < timeout do
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
        local c = player.Character; if not c then return false end
        local h = c:FindFirstChild("Humanoid"); if not h then return false end
        return h.Sit and h.SeatPart == seat
    end
    local function getPartner(tt, mySeat)
        local seats = {}
        for _, p in ipairs(tt:GetDescendants()) do
            if p:IsA("Seat") or p:IsA("VehicleSeat") then table.insert(seats, p) end
        end
        local other
        for _, s in ipairs(seats) do if s ~= mySeat then other = s; break end end
        if not other then return nil end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                local c = plr.Character
                if c then
                    local h = c:FindFirstChild("Humanoid")
                    if h and h.Sit and h.SeatPart == other then return plr.Name end
                end
            end
        end
        return nil
    end
    local function resetSeat(seat, pos)
        while true do
            local c = player.Character; if not c then return false end
            local h = c:FindFirstChild("Humanoid"); if not h then return false end
            if isSeated(seat) then return true end
            pcall(function() h.Sit = false end); task.wait(0.2)
            h.Jump = true; task.wait(0.2)
            for i = 1, 5 do
                if isSeated(seat) then return true end
                local d = math.random(1,2) == 1 and 1 or -1
                local off = Vector3.new(d * math.random(3,6), 0, 0)
                h:MoveTo(pos + off); task.wait(0.3)
                h:MoveTo(pos); task.wait(0.3)
                for _ = 1, 5 do if isSeated(seat) then return true end; task.wait(0.2) end
            end
        end
    end

    local addBtnPath = {"Main","Trade","Container","1","Frame","AddButton"}
    local firstCPath = {"Main","Trade","Container","FrameAdd","Frame"}
    local resCPath   = {"Main","Trade","Container","1","Frame"}
    local secCPath   = {"Main","Trade","Container","2","Frame"}
    local acceptPath = {"Main","Trade","Info","Accept"}
    local ready1Path = {"Main","Trade","Info","Ready1"}
    local botPath    = {"Main","Trade","BottomTitle"}

    local RESULT_TIMEOUT, MAX_ATT, READY_TIMEOUT = 30, 3, 30
    local ACC_INT, ACC_WAIT = 0.5, 30

    local function findParentBtn(o)
        local cur = o
        while cur do
            if cur:IsA("TextButton") or cur:IsA("ImageButton") then return cur end
            cur = cur.Parent
        end
    end
    local function findTxtInCont(cont, s)
        for _, o in ipairs(cont:GetDescendants()) do
            if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
                if o.Text and o.Text:lower():find(s:lower(), 1, true) then return o end
            end
        end
    end
    local function findRes(s)
        local cont = findObjectByPath(playerGui, table.unpack(resCPath)); if not cont then return nil end
        for _, o in ipairs(cont:GetDescendants()) do
            if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
                if o.Text and o.Text:lower():find(s:lower(), 1, true) then
                    if o.Parent and o.Parent.Name == "Title" then return o end
                end
            end
        end
    end
    local function waitObj(path, timeout)
        local w = 0
        while w < timeout do
            local o = findObjectByPath(playerGui, table.unpack(path))
            if o then return o end
            task.wait(0.5); w += 0.5
        end
    end
    local function getPct()
        local bt = findObjectByPath(playerGui, table.unpack(botPath)); if not bt then return nil end
        local p = bt.Text:match("(%d+)%%")
        return p and tonumber(p) or nil
    end
    local function checkSec(items)
        local sc = findObjectByPath(playerGui, table.unpack(secCPath)); if not sc then return false end
        for _, it in ipairs(items) do
            if not findTxtInCont(sc, it) then return false end
        end
        return true
    end
    local function tradeDone()
        local n = playerGui:FindFirstChild("Notifications"); if not n then return false end
        for _, o in ipairs(n:GetDescendants()) do
            if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
                if o.Text and o.Text:lower():find("trade completed", 1, true) then return true end
            end
        end
        return false
    end
    local function processItem(s)
        if findRes(s) then return true end
        for _ = 1, MAX_ATT do
            local ab = findObjectByPath(playerGui, table.unpack(addBtnPath))
            if not ab then task.wait(2); continue end
            fireSequence(ab)
            local fc = waitObj(firstCPath, 5); if not fc then task.wait(2); continue end
            local te = findTxtInCont(fc, s); if not te then task.wait(2); continue end
            local bt = findParentBtn(te); if not bt then task.wait(2); continue end
            fireSequence(bt)
            local w = 0
            while w < RESULT_TIMEOUT do
                task.wait(0.5); w += 0.5
                if findRes(s) then return true end
            end
        end
        return false
    end
    local function checkPre(items, seat)
        if not isSeated(seat) then return false end
        local p = getPct()
        if not p or p > 40 then return false end
        if not checkSec(items) then return false end
        return true
    end
    local function waitPre(items, seat)
        local w = 0
        while w < ACC_WAIT do
            if not isSeated(seat) then return false end
            if checkPre(items, seat) then return true end
            task.wait(ACC_INT); w += ACC_INT
        end
        return false
    end
    local function acceptAndWait(items, seat)
        if not isSeated(seat) then return false end
        if not waitPre(items, seat) then return false end
        local ab = findObjectByPath(playerGui, table.unpack(acceptPath)); if not ab then return false end
        fireSequence(ab)
        local w = 0
        local r1 = findObjectByPath(playerGui, table.unpack(ready1Path))
        while w < READY_TIMEOUT do
            task.wait(0.5); w += 0.5
            if not isSeated(seat) then return false end
            if tradeDone() then return true end
            if r1 and r1:IsA("TextLabel") then
                if r1.Text == "Not ready." then return false
                elseif r1.Text ~= "Ready!" then return false end
            end
        end
        return false
    end

    print("[Orange] start")
    selectTeam()

    local config = nil; local ca = 0
    while config == nil and State.running and ca < 50 do
        ca += 1
        local inv = collectInventory()
        if #inv > 0 then sendInventory(inv)
        else task.wait(SEND_INVENTORY_INTERVAL); continue end
        local w = 0
        while w < 120 do
            config = fetchConfig()
            if config then break end
            task.wait(CONFIG_POLL_INTERVAL); w += CONFIG_POLL_INTERVAL
        end
        if not config then warn("[Orange] конфиг не получен, повтор"); task.wait(SEND_INVENTORY_INTERVAL) end
    end
    if not config then warn("[Orange] без конфига выходим"); State.beltScanPaused = false; return end
    print("[Orange] конфиг получен")

    local tgt = config.teleport_to_job_id
    if tgt and tgt ~= "" and tgt ~= game.JobId then
        local att = 0
        while att < 5 do
            att += 1
            local ok = teleportToJobId(tgt)
            if ok and waitTeleport(tgt, 30) then break end
            task.wait(2)
        end
        if game.JobId ~= tgt then
            warn("[Orange] не телепортнулись")
            State.beltScanPaused = false; return
        end
    end

    if not processLoadFruit(config.load_fruit_items or {}) then
        warn("[Orange] ошибка ресета"); State.beltScanPaused = false; return
    end

    collisionsDisabled = true; print("[Collisions] ON")
    print("[Travel] к waypoint")
    moveTo(WAYPOINT_POSITION)
    task.wait(1)

    local done = false
    while not done and State.running do
        local tt, seat, ffree = findTradeTable(config.partner_name or "")
        if not tt then print("Стол не найден"); task.wait(5); continue end
        local tpos = seat.Position
        print("Стол: " .. (ffree and "свободный" or "частично"))
        if not moveTo(tpos) then task.wait(2); continue end
        do
            local c = player.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                if h and not h.Sit then pcall(function() h:MoveTo(tpos) end) end
            end
        end
        if not waitSeat(seat, 30) then
            if not resetSeat(seat, tpos) then task.wait(2); continue end
        end
        print("Сидим")
        while not done and State.running do
            if not isSeated(seat) then
                if not resetSeat(seat, tpos) then break end
            end
            local pn = getPartner(tt, seat)
            local ep = config.partner_name or ""
            print("Партнёр:", pn or "нет", "| ожид:", ep)
            if pn == nil then task.wait(1)
            elseif ep ~= "" and pn ~= ep then
                if not resetSeat(seat, tpos) then break end
            else
                print("Партнёр ок, добавляем")
                local all = true
                for _, it in ipairs(config.trade_items or {}) do
                    if not isSeated(seat) then
                        if not resetSeat(seat, tpos) then all = false; break end
                        all = false; break
                    end
                    if not processItem(it) then all = false; break end
                end
                if not all then
                    if not resetSeat(seat, tpos) then break end
                else
                    if not isSeated(seat) then
                        if not resetSeat(seat, tpos) then break end
                    else
                        if acceptAndWait(config.load_fruit_items or {}, seat) then
                            print("Трейд завершён!")
                            pcall(function()
                                game:HttpGet(SERVER_URL .. "/trade_completed?nickname=" .. HttpService:UrlEncode(player.Name))
                            end)
                            collisionsDisabled = false
                            done = true; break
                        else
                            if not resetSeat(seat, tpos) then break end
                        end
                    end
                end
            end
        end
    end
    State.beltScanPaused = false
    State.currentBelt = "Unknown"
    task.wait(1)
    print("[Orange] выход")
end

-- ============================================================
-- ГЛАВНЫЙ ДИСПЕТЧЕР
-- ============================================================
task.wait(5)

do
    local bad = getBlacklistedPlayer()
    if bad then
        print("[Blacklist] найден " .. bad .. " — хоп"); serverHop(); return
    end
end

print("[Main] ждём первый скан пояса (до 240 сек)...")
local ws = tick()
while State.currentBelt == "Unknown" and tick() - ws < 240 do task.wait(1) end
if State.currentBelt == "Unknown" then
    warn("[Main] пояс не определён за 240 сек — хоп"); serverHop(); return
end
print("[Main] режим: " .. State.currentBelt)

while State.running do
    do
        local bad = getBlacklistedPlayer()
        if bad then print("[Blacklist] найден " .. bad .. " — хоп"); serverHop(); return end
    end
    local belt = State.currentBelt
    if belt == "Orange" then runOrangeMode()
    elseif belt == "Yellow" or belt == "White" then runYellowWhiteMode()
    elseif belt == "None" then runNoBeltMode()
    else print("[Main] режим " .. belt .. " не обрабатывается"); task.wait(30) end
    task.wait(3)
end
