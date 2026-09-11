-- ============================================================
-- ПОЛНЫЙ СКРИПТ
-- Движение к TradeTable через BodyVelocity (как к лодке)
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ====================== ХАБ В ФОНЕ ======================
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

-- ====================== УТИЛИТЫ ХАБА ======================
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
local function waitForInterface()
    local root = getRoot()
    if not root then return false end
    return safeFind(root, "Window", "Components", "TabsScroll")
end

-- ====================== ЖДЁМ ХАБ ======================
do
    local timeout, waited = 90, 0
    while waited < timeout do
        if waitForInterface() then print("[Startup] Хаб загружен."); break end
        task.wait(0.5); waited += 0.5
    end
    if not waitForInterface() then warn("[Startup] Хаб не загрузился.") end
end

-- ====================== ЖДЁМ ПЕРСОНАЖА ======================
do
    local character = player.Character or player.CharacterAdded:Wait()
    local waited = 0
    while waited < 60 do
        character = player.Character
        if character and character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart") then break end
        task.wait(0.5); waited += 0.5
    end
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        warn("[Startup] Персонаж не загрузился"); return
    end
end

-- ====================== ЖДЁМ REMOTES ======================
do
    local remotes, commF
    local waited = 0
    while waited < 60 do
        remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            commF = remotes:FindFirstChild("CommF_")
            if commF then break end
        end
        task.wait(0.5); waited += 0.5
    end
    if not commF then warn("[Startup] CommF_ не найден"); return end
end
task.wait(2)

-- ====================== НАСТРОЙКИ ======================
local SERVER_URL = "http://192.168.31.89:8000"
local SEND_INVENTORY_INTERVAL = 20
local CONFIG_POLL_INTERVAL = 10
local MOVE_TIMEOUT = 60
local ARRIVE_DISTANCE = 6
local MOVE_SPEED = 80

local SCROLL_STEP_PIXELS = 10
local SCROLL_WAIT_TIME = 0.15
local SCROLL_INITIAL_WAIT = 0.5
local SCROLL_FINAL_WAIT = 1.0

local BOAT_TAB, BOAT_OPT, ISLAND_OPT = 5, 6, 10
local RETURN_TAB, RETURN_OPT = 3, 1
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local TELEPORT_TAB = 19
local TELEPORT_OPT_TEXT = 2
local TELEPORT_OPT_ACTIVATE = 3

-- ====================== ОБЩИЕ ======================
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
    for _, sigName in ipairs(signals) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn.Enabled and type(conn.Function) == "function" then
                        pcall(conn.Function)
                    end
                end
            end
        end
    end
    return true
end

local function findObjectByPath(root, ...)
    local current = root
    for _, segment in ipairs({...}) do
        if not current then return nil end
        current = current:FindFirstChild(segment)
    end
    return current
end

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

-- ====================== HUD КНОПКИ ======================
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

-- ====================== ВЫБОР КОМАНДЫ ======================
local function selectTeam()
    local success, err = pcall(function()
        local r = ReplicatedStorage:FindFirstChild("Remotes")
        if not r then error("Remotes исчезли") end
        local c = r:FindFirstChild("CommF_")
        if not c then error("CommF_ исчез") end
        c:InvokeServer("SetTeam", "Marines")
    end)
    if success then print("[Team] Marines выбрана") else warn("[Team]", err) end
    task.wait(3)
end

-- ====================== СБОР ИНВЕНТАРЯ ======================
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

-- ====================== LOADFRUIT ======================
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

-- ====================== ОПЦИИ ХАБА ======================
local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            if tostring(child.BackgroundColor3) == COLOR_ON or tostring(child.BackgroundColor3) == COLOR_OFF then
                return child
            end
        end
        local found = findIndicatorFrame(child) if found then return found end
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

local function setOptionState(tabIndex, optIndex, desiredState)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot() if not root then return false end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll") if not tabsScroll then return false end
    local tabButton = findNthTabButton(tabsScroll, tabIndex) if not tabButton then return false end
    fireSequence(tabButton); task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container") if not container then return false end
    local optionBtn = findNthOption(container, optIndex) if not optionBtn then return false end
    local indicator = findIndicatorFrame(optionBtn) if not indicator then return false end
    if (tostring(indicator.BackgroundColor3) == COLOR_ON and desiredState == "on") or
       (tostring(indicator.BackgroundColor3) == COLOR_OFF and desiredState == "off") then return true end
    fireSequence(optionBtn); task.wait(0.1)
    return true
end

-- ====================== ТЕЛЕПОРТ ПО JOB_ID ======================
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

-- ====================== ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (отдельный поток) ======================
task.spawn(function()
    while true do
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
        task.wait(2)
    end
end)

-- ====================== ДВИЖЕНИЕ К СТОЛУ (BodyVelocity, как к лодке) ======================
-- Тот же принцип, что и движение к VehicleSeat лодки:
-- BodyVelocity на UpperTorso, только без подъёма по Y.
local function moveToTradeTableSeat(targetPosition)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local upper = character:FindFirstChild("UpperTorso")
    if not upper then return false end

    -- Чистим старый BV
    local oldBV = upper:FindFirstChildOfClass("BodyVelocity")
    if oldBV then oldBV:Destroy() end

    local mv = Instance.new("BodyVelocity")
    mv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    mv.Parent = upper

    local isMoving = true
    -- Анти-застревание
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
            local toTarget = (hrp.Position - targetPosition).Magnitude
            if toTarget < ARRIVE_DISTANCE then break end
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

        local cur = hrp.Position
        local dx = targetPosition.X - cur.X
        local dz = targetPosition.Z - cur.Z
        local dist = math.sqrt(dx*dx + dz*dz)

        if dist < ARRIVE_DISTANCE then
            isMoving = false
            if mv then mv:Destroy() end
            task.cancel(stuckThread)
            return true
        end

        local nx = dx / math.max(dist, 0.001)
        local nz = dz / math.max(dist, 0.001)
        mv.Velocity = Vector3.new(nx * MOVE_SPEED, 0, nz * MOVE_SPEED)

        task.wait(0.05)
        waited += 0.05
    end

    isMoving = false
    if mv then mv:Destroy() end
    task.cancel(stuckThread)
    return false
end

-- ====================== ПОИСК СТОЛА ======================
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

-- ====================== СИДЕНЬЕ ======================
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

-- ====================== АВТО-ТРЕЙД ======================
local addButtonPath = {"Main", "Trade", "Container", "1", "Frame", "AddButton"}
local firstContainerPath = {"Main", "Trade", "Container", "FrameAdd", "Frame"}
local resultContainerPath = {"Main", "Trade", "Container", "1", "Frame"}
local secondContainerPath = {"Main", "Trade", "Container", "2", "Frame"}
local acceptPath = {"Main", "Trade", "Info", "Accept"}
local ready1Path = {"Main", "Trade", "Info", "Ready1"}
local bottomTitlePath = {"Main", "Trade", "BottomTitle"}

local RESULT_TIMEOUT = 30
local MAX_ATTEMPTS_PER_ITEM = 3
local READY_TIMEOUT = 30
local ACCEPT_CHECK_INTERVAL = 0.5
local ACCEPT_WAIT_TIMEOUT = 30

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

-- ====================== ОСНОВНОЙ ЦИКЛ ======================
print("Скрипт запущен.")
selectTeam()

local config = nil
while config == nil do
    local inventory = collectInventory()
    if #inventory > 0 then sendInventory(inventory)
    else task.wait(SEND_INVENTORY_INTERVAL); continue end
    local waited = 0
    while waited < 120 do
        config = fetchConfig()
        if config then break end
        task.wait(CONFIG_POLL_INTERVAL); waited += CONFIG_POLL_INTERVAL
    end
    if not config then
        warn("Конфигурация не получена, повторяем.")
        task.wait(SEND_INVENTORY_INTERVAL)
    end
end

print("Конфигурация получена.")

-- Телепорт при необходимости
local teleportTarget = config.teleport_to_job_id
if teleportTarget and teleportTarget ~= "" and teleportTarget ~= game.JobId then
    print("[Teleport] Требуется JobId: " .. teleportTarget)
    local attempts = 0
    while attempts < 5 do
        attempts += 1
        print("[Teleport] Попытка " .. attempts)
        local ok = teleportToJobId(teleportTarget)
        if ok then
            if waitForTeleport(teleportTarget, 30) then
                print("[Teleport] Успешно перешли на " .. teleportTarget)
                break
            end
        end
        task.wait(2)
    end
    if game.JobId ~= teleportTarget then
        warn("[Teleport] Не удалось перейти, повторяем позже.")
        return
    end
end

-- Ресет фруктов
local loadSuccess = processLoadFruit(config.load_fruit_items or {})
if not loadSuccess then warn("Ошибка ресета"); return end

-- Трейд-цикл
local tradeCompleted = false
while not tradeCompleted do
    local tradeTable, mySeat, wasFullyFree = findTradeTable(config.partner_name or "")
    if not tradeTable then
        print("Стол не найден, ждём 5 сек.")
        task.wait(5); continue
    end
    local tablePos = mySeat.Position
    print("Найден стол. Тип:", wasFullyFree and "свободный" or "частично занят")

    -- ДВИЖЕНИЕ К СТОЛУ (BodyVelocity)
    local arrived = moveToTradeTableSeat(tablePos)
    if not arrived then print("Не дошли, пробуем другой."); task.wait(2); continue end

    if not waitForSeat(mySeat, 30) then
        if not resetSeatAndWait(mySeat, tablePos) then task.wait(2); continue end
    end

    print("Сидим. Ожидаем партнёра...")

    while not tradeCompleted do
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

print("Скрипт завершён.")
