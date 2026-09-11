-- ============================================================
-- ПОЛНЫЙ СКРИПТ: КОМАНДА -> ИНВЕНТАРЬ -> СЕРВЕР -> РЕСЕТ ->
-- ПЕРЕМЕЩЕНИЕ К СТОЛУ ЧЕРЕЗ ЛОДКУ (BodyVelocity) -> АВТО-ТРЕЙД
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ====================== НАСТРОЙКИ ======================
local SERVER_URL = "http://192.168.31.89:8000"
local SEND_INVENTORY_INTERVAL = 20
local CONFIG_POLL_INTERVAL = 10
local MOVE_TIMEOUT = 60
local ARRIVE_DISTANCE = 5

-- Настройки лодки (из AutoFarm)
local BOAT_TAB, BOAT_OPT, ISLAND_OPT = 5, 6, 10
local RETURN_TAB, RETURN_OPT = 3, 1
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local SPEED_X, SPEED_Y, SPEED_Z, TARGET_Y = 250, -2, -2, 100

-- ====================== УНИВЕРСАЛЬНЫЕ ФУНКЦИИ ======================
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
        task.wait(0.5)
        waited += 0.5
    end
    warn("Объект не найден за " .. timeout .. " сек: " .. (description or "unknown"))
    return nil
end

-- ====================== ШАГ 1: ВЫБОР КОМАНДЫ ======================
local function selectTeam()
    local success, err = pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then error("Remotes не найдены") end
        local commF = remotes:FindFirstChild("CommF_")
        if not commF then error("CommF_ не найден") end
        commF:InvokeServer("SetTeam", "Marines")
        print("Команда Marines выбрана")
    end)
    if not success then
        warn("Ошибка выбора команды:", err)
    end
    task.wait(3)
end

-- ====================== ШАГ 2: СБОР ИНВЕНТАРЯ ======================
local function collectInventory()
    print("Открытие инвентаря...")
    local menuButton = waitForObjectByPath({"Main", "MenuButton"}, 10, "Main.MenuButton")
    if not menuButton then return {} end
    fireSequence(menuButton)
    task.wait(1)

    local inventoryButton = waitForObjectByPath({"Main", "InventoryButton"}, 10, "Main.InventoryButton")
    if not inventoryButton then return {} end
    fireSequence(inventoryButton)
    task.wait(1)

    local category2 = waitForObjectByPath({"Inventory", "Inventory", "Main", "NavigationRail", "HoverBox", "UpperBar", "Category2"}, 15, "Category2")
    if not category2 then return {} end
    fireSequence(category2)
    task.wait(2)

    local tileGrid = waitForObjectByPath({"Inventory", "Inventory", "Main", "PageContent", "TileGrid"}, 10, "TileGrid")
    if not tileGrid then return {} end

    local fruits = {}
    for _, child in ipairs(tileGrid:GetChildren()) do
        if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
            local line1 = nil
            local details = child:FindFirstChild("Details")
            if details then line1 = details:FindFirstChild("Line-1") end
            if not line1 then
                for _, obj in ipairs(child:GetDescendants()) do
                    if obj:IsA("TextLabel") then line1 = obj; break end
                end
            end
            local text = ""
            if line1 and line1:IsA("TextLabel") then text = line1.Text end
            if text and text:find(",") then text = text:sub(1, text:find(",") - 1) end
            text = text:gsub("%s+$", "")
            if text ~= "" then table.insert(fruits, text) end
        end
    end
    print("Инвентарь собран:", fruits)
    return fruits
end

local function sendInventory(fruits)
    local fruitsStr = table.concat(fruits, ",")
    local url = SERVER_URL .. "/send_inventory?nickname=" .. HttpService:UrlEncode(player.Name)
        .. "&fruits=" .. HttpService:UrlEncode(fruitsStr)
        .. "&job_id=" .. HttpService:UrlEncode(game.JobId)
    local success, result = pcall(function() return game:HttpGet(url) end)
    if success then print("Инвентарь отправлен:", result)
    else warn("Ошибка отправки инвентаря:", result) end
end

local function fetchConfig()
    local url = SERVER_URL .. "/get_config?nickname=" .. HttpService:UrlEncode(player.Name)
    local success, response = pcall(function() return game:HttpGet(url) end)
    if not success then warn("Ошибка запроса конфигурации:", response); return nil end
    local data = HttpService:JSONDecode(response)
    if data and data.partner_name then print("Конфигурация получена:", data); return data
    elseif data and data.error then print("Сервер:", data.error); return nil
    else print("Конфигурация ещё не готова"); return nil end
end

-- ====================== ШАГ 4: LOADFRUIT ======================
local function formatItemName(name)
    local lower = name:lower()
    local cap = lower:sub(1, 1):upper() .. lower:sub(2)
    return cap .. "-" .. cap
end

local function invokeLoadFruit(fruitName)
    local success, result = pcall(function()
        return ReplicatedStorage.Remotes.CommF_:InvokeServer("LoadFruit", fruitName)
    end)
    if success then print("[Успех] LoadFruit " .. fruitName .. " | " .. tostring(result))
    else warn("[Ошибка] LoadFruit " .. fruitName .. " | " .. tostring(result)) end
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
        task.wait(0.5)
        waited += 0.5
    end
    return nil
end

local function processLoadFruit(loadFruitItems)
    if #loadFruitItems == 0 then return true end
    for _, item in ipairs(loadFruitItems) do
        local formatted = formatItemName(item)
        print("Обрабатываю '" .. item .. "' -> '" .. formatted .. "'")
        invokeLoadFruit(formatted)
        respawnCharacter()
        waitForCharacterRespawn()
        task.wait(1)
    end
    return true
end

-- ====================== ИНТЕРФЕЙС ХАБА (для лодки) ======================
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
end
local function safeFind(obj, ...) for _, name in ipairs({...}) do if not obj then return nil end obj = obj:FindFirstChild(name) end return obj end
local function waitForInterface() return getRoot() and safeFind(getRoot(), "Window", "Components", "TabsScroll") end

local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            if tostring(child.BackgroundColor3) == COLOR_ON or tostring(child.BackgroundColor3) == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child) if found then return found end
    end
end

local function getOptionState(tabIndex, optIndex)
    local root = getRoot() if not root then return nil end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll") if not tabsScroll then return nil end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1; if tabCount == tabIndex then tabButton = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll) if not tabButton then return nil end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container") if not container then return nil end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1; if optCount == optIndex then optionBtn = c break end
        end
    end
    if not optionBtn then return nil end
    local ind = findIndicatorFrame(optionBtn) if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    return (col == COLOR_ON and "on") or (col == COLOR_OFF and "off") or nil
end

local function setOptionState(tabIndex, optIndex, desiredState)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot() if not root then return false end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll") if not tabsScroll then return false end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1; if tabCount == tabIndex then tabButton = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll) if not tabButton then return false end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container") if not container then return false end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1; if optCount == optIndex then optionBtn = c break end
        end
    end
    if not optionBtn then return false end
    local indicator = findIndicatorFrame(optionBtn) if not indicator then return false end
    if (tostring(indicator.BackgroundColor3) == COLOR_ON and desiredState == "on") or
       (tostring(indicator.BackgroundColor3) == COLOR_OFF and desiredState == "off") then return true end
    fireSequence(optionBtn) task.wait(0.1)
    return true
end

-- ====================== ДВИЖЕНИЕ ЛОДКИ ======================
local boat, seat, rootPart = nil, nil, nil
local dir = -1
local bv = nil
local moving = false
local moveThread = nil

local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

local function ensureBV(speedX, speedY, speedZ, targetY)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local upper = char:FindFirstChild("UpperTorso")
    if not upper then return false end
    local sx = dir * speedX
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(sx, speedY, speedZ)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(sx, speedY, speedZ)
    end
    return true
end

-- Движение к заданной точке: если персонаж в лодке, использует BodyVelocity.
-- Работает до момента, пока персонаж не окажется в пределах arriveDistance от targetPosition.
local function moveBoatToPosition(targetPosition, arriveDistance)
    arriveDistance = arriveDistance or 20
    if moving then stopMove() end
    moving = true
    moveThread = task.spawn(function()
        while moving do
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then stopMove(); break end

            -- Проверка, что мы в лодке
            local inBoat, boatModel, seatPart = isInBoat()
            if not inBoat then stopMove(); break end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then stopMove(); break end

            local cur = hrp.Position
            local dx = targetPosition.X - cur.X
            local dz = targetPosition.Z - cur.Z
            local dist = math.sqrt(dx*dx + dz*dz)

            if dist <= arriveDistance then
                stopMove()
                break
            end

            -- Задаём направление через BodyVelocity, нормализуем и умножаем на скорость
            local len = math.max(dist, 0.001)
            local nx, nz = dx / len, dz / len

            local speedX = 250
            local speedZ = 250
            local vx, vz = nx * speedX, nz * speedZ

            local upper = char:FindFirstChild("UpperTorso")
            if not upper then stopMove(); break end
            if not bv or not bv.Parent then
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = upper
            end
            bv.Velocity = Vector3.new(vx, 0, vz)

            -- Понижаем Y, чтобы не улетать
            pcall(function()
                hrp.CFrame = CFrame.new(hrp.Position.X, 100, hrp.Position.Z)
            end)

            task.wait(0.05)
        end
    end)

    -- Ожидание прибытия с таймаутом
    local waited = 0
    while waited < MOVE_TIMEOUT do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local p = hrp.Position
            local dx = targetPosition.X - p.X
            local dz = targetPosition.Z - p.Z
            if math.sqrt(dx*dx + dz*dz) <= arriveDistance then
                stopMove()
                return true
            end
        end
        task.wait(0.5)
        waited += 0.5
    end
    stopMove()
    return false
end

local function isInBoat()
    local char = player.Character if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or not hum.Sit or not hum.SeatPart then return false end
    local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
    return (model and model:FindFirstChildWhichIsA("VehicleSeat") and true) or false, model, hum.SeatPart
end

-- Полный цикл: садимся в лодку -> движемся к цели -> выходим из лодки
local function travelByBoatToPosition(targetPosition)
    print("[Boat] Путешествие к позиции:", targetPosition)
    if not waitForInterface() then warn("Интерфейс не найден для управления лодкой"); return false end

    -- Активируем кнопку возврата в лодку (3,1)
    setOptionState(RETURN_TAB, RETURN_OPT, "on")
    task.wait(0.3)

    -- Ждём посадку в лодку
    local waited = 0
    while waited < 60 do
        local inBoat = isInBoat()
        if inBoat then break end
        task.wait(0.5)
        waited += 0.5
    end
    if not isInBoat() then
        warn("[Boat] Не удалось сесть в лодку")
        setOptionState(RETURN_TAB, RETURN_OPT, "off")
        return false
    end

    -- Отключаем автокнопки (мы уже в лодке)
    setOptionState(BOAT_TAB, BOAT_OPT, "off")
    setOptionState(RETURN_TAB, RETURN_OPT, "off")
    task.wait(1)

    -- Двигаемся к целевой позиции через BodyVelocity
    local arrived = moveBoatToPosition(targetPosition, 20)
    print("[Boat] Прибытие:", arrived)

    -- Выходим из лодки
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            pcall(function() hum.Sit = false end)
            task.wait(0.3)
            hum.Jump = true
        end
    end
    task.wait(1)

    return arrived
end

-- ====================== ШАГ 5: ПОИСК СТОЛА ======================
local function findTradeTable(expectedPartnerName)
    local tradeTables = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "TradeTable" then
            table.insert(tradeTables, obj)
        end
    end

    local fullyFree = {}
    local partiallyOccupied = {}
    local withPartner = {}

    for _, tradeTable in ipairs(tradeTables) do
        local seats = {}
        for _, part in ipairs(tradeTable:GetDescendants()) do
            if part:IsA("Seat") or part:IsA("VehicleSeat") then
                table.insert(seats, part)
            end
        end
        if #seats >= 2 then
            local occupiedCount = 0
            local freeSeats = {}
            local occupiedSeat = nil
            for _, seat in ipairs(seats) do
                if seat.Occupant then
                    occupiedCount += 1
                    occupiedSeat = seat
                else
                    table.insert(freeSeats, seat)
                end
            end
            if occupiedCount == 0 then
                table.insert(fullyFree, {tradeTable = tradeTable, freeSeat = freeSeats[1], wasFullyFree = true})
            elseif occupiedCount == 1 then
                local occupantName = nil
                if occupiedSeat then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        local char = plr.Character
                        if char then
                            local hum = char:FindFirstChild("Humanoid")
                            if hum and hum.SeatPart == occupiedSeat then
                                occupantName = plr.Name
                                break
                            end
                        end
                    end
                end
                local entry = {tradeTable = tradeTable, freeSeat = freeSeats[1], wasFullyFree = false, occupantName = occupantName}
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

-- ====================== ШАГ 6: ПЕРЕМЕЩЕНИЕ ПЕШКОМ ======================
local function moveToPositionWithJump(targetPosition)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    humanoid:MoveTo(targetPosition)

    local isMoving = true
    local stuckCheckCoroutine = task.spawn(function()
        local lastPosition = rootPart.Position
        local stuckSeconds = 0
        while isMoving do
            task.wait(1)
            local currentPosition = rootPart.Position
            local distanceMoved = (currentPosition - lastPosition).Magnitude
            local distanceToTarget = (currentPosition - targetPosition).Magnitude
            if distanceToTarget < ARRIVE_DISTANCE then break end
            if distanceMoved < 1 then
                stuckSeconds += 1
                if stuckSeconds >= 2 then humanoid.Jump = true; stuckSeconds = 0 end
            else
                stuckSeconds = 0
            end
            lastPosition = currentPosition
        end
    end)

    local waited = 0
    while waited < MOVE_TIMEOUT do
        local distance = (rootPart.Position - targetPosition).Magnitude
        if distance < ARRIVE_DISTANCE then
            isMoving = false
            task.cancel(stuckCheckCoroutine)
            return true
        end
        task.wait(0.5)
        waited += 0.5
    end
    isMoving = false
    task.cancel(stuckCheckCoroutine)
    return false
end

local function waitForSeat(seatPart, timeout)
    local waited = 0
    while waited < timeout do
        local char = player.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Sit and hum.SeatPart == seatPart then return true end
        end
        task.wait(0.5)
        waited += 0.5
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
    for _, seat in ipairs(seats) do
        if seat ~= mySeat then otherSeat = seat; break end
    end
    if not otherSeat then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Sit and hum.SeatPart == otherSeat then return plr.Name end
            end
        end
    end
    return nil
end

local function resetSeatAndWait(mySeat, targetPos)
    local attempt = 0
    while true do
        attempt += 1
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return false end
        if isSeated(mySeat) then return true end
        pcall(function() hum.Sit = false end)
        task.wait(0.2)
        hum.Jump = true
        task.wait(0.2)
        for i = 1, 5 do
            if isSeated(mySeat) then return true end
            local direction = math.random(1,2) == 1 and 1 or -1
            local offsetDistance = math.random(3, 6)
            local offset = Vector3.new(direction * offsetDistance, 0, 0)
            hum:MoveTo(targetPos + offset)
            task.wait(0.3)
            hum:MoveTo(targetPos)
            task.wait(0.3)
            for check = 1, 5 do
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
        task.wait(0.5)
        waited += 0.5
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
    for attempt = 1, MAX_ATTEMPTS_PER_ITEM do
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
            task.wait(0.5)
            waitTime += 0.5
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
        task.wait(ACCEPT_CHECK_INTERVAL)
        waited += ACCEPT_CHECK_INTERVAL
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
        task.wait(0.5)
        waited += 0.5
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
        task.wait(CONFIG_POLL_INTERVAL)
        waited += CONFIG_POLL_INTERVAL
    end
    if not config then
        warn("Конфигурация не получена, повторяем.")
        task.wait(SEND_INVENTORY_INTERVAL)
    end
end

print("Конфигурация получена, начинаем выполнение.")

local loadSuccess = processLoadFruit(config.load_fruit_items or {})
if not loadSuccess then
    warn("Ошибка ресета фруктов.")
    return
end

-- Определяем целевую зону (где находятся TradeTable) - берём первую найденную модель TradeTable
local targetPos = nil
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Model") and obj.Name == "TradeTable" then
        local base = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if base then targetPos = base.Position; break end
    end
end

if targetPos then
    print("[Travel] Едем к первой найденной TradeTable:", targetPos)
    travelByBoatToPosition(targetPos)
else
    warn("TradeTable не найден в мире, пропускаем движение на лодке.")
end

-- ====================== ОСНОВНОЙ ТРЕЙД-ЦИКЛ ======================
local tradeCompleted = false
while not tradeCompleted do
    local tradeTable, mySeat, wasFullyFree = findTradeTable(config.partner_name or "")
    if not tradeTable then
        print("Стол не найден, ждём 5 сек.")
        task.wait(5)
        continue
    end

    local tablePos = mySeat.Position
    print("Найден стол. Тип:", wasFullyFree and "полностью свободный" or "частично занят")

    local arrived = moveToPositionWithJump(tablePos)
    if not arrived then
        print("Не дошли пешком, пробуем другой стол.")
        task.wait(2)
        continue
    end

    local seated = waitForSeat(mySeat, 30)
    if not seated then
        if not resetSeatAndWait(mySeat, tablePos) then
            task.wait(2); continue
        end
    end

    print("Сидим за столом. Ожидаем партнёра...")

    while not tradeCompleted do
        if not isSeated(mySeat) then
            print("Не сидим, пересадка.")
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
                    allItemsAdded = false
                    break
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
