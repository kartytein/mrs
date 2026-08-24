-- ============================================================
-- ПОЛНЫЙ СКРИПТ: ВЫБОР КОМАНДЫ -> ИНВЕНТАРЬ -> СЕРВЕР -> РЕСЕТ -> ПОИСК СТОЛА -> АВТО-ТРЕЙД
-- Приоритет столов: 1) с нужным партнёром, 2) полностью свободные, 3) с любым занятым.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ====================== НАСТРОЙКИ ======================
local SERVER_URL = "http://192.168.31.179:8000"
local SEND_INVENTORY_INTERVAL = 20
local CONFIG_POLL_INTERVAL = 10
local MOVE_TIMEOUT = 30
local ARRIVE_DISTANCE = 5

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
        if obj then
            return obj
        end
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
            if details then
                line1 = details:FindFirstChild("Line-1")
            end
            if not line1 then
                for _, obj in ipairs(child:GetDescendants()) do
                    if obj:IsA("TextLabel") then
                        line1 = obj
                        break
                    end
                end
            end
            local text = ""
            if line1 and line1:IsA("TextLabel") then
                text = line1.Text
            end
            if text and text:find(",") then
                text = text:sub(1, text:find(",") - 1)
            end
            text = text:gsub("%s+$", "")
            if text ~= "" then
                table.insert(fruits, text)
            end
        end
    end
    print("Инвентарь собран:", fruits)
    return fruits
end

-- ====================== ШАГ 2: ОТПРАВКА НА СЕРВЕР ======================
local function sendInventory(fruits)
    local fruitsStr = table.concat(fruits, ",")
    local url = SERVER_URL .. "/send_inventory?nickname=" .. HttpService:UrlEncode(player.Name)
        .. "&fruits=" .. HttpService:UrlEncode(fruitsStr)
        .. "&job_id=" .. HttpService:UrlEncode(game.JobId)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if success then
        print("Инвентарь отправлен:", result)
    else
        warn("Ошибка отправки инвентаря:", result)
    end
end

-- ====================== ШАГ 3: ПОЛУЧЕНИЕ КОНФИГУРАЦИИ ======================
local function fetchConfig()
    local url = SERVER_URL .. "/get_config?nickname=" .. HttpService:UrlEncode(player.Name)
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not success then
        warn("Ошибка запроса конфигурации:", response)
        return nil
    end

    local data = HttpService:JSONDecode(response)
    if data and data.partner_name then
        print("Конфигурация получена:", data)
        return data
    elseif data and data.error then
        print("Сервер:", data.error)
        return nil
    else
        print("Конфигурация ещё не готова")
        return nil
    end
end

-- ====================== ШАГ 4: LOADFRUIT + RESPAWN ======================
local function formatItemName(name)
    local lower = name:lower()
    local cap = lower:sub(1, 1):upper() .. lower:sub(2)
    return cap .. "-" .. cap
end

local function invokeLoadFruit(fruitName)
    local success, result = pcall(function()
        return ReplicatedStorage.Remotes.CommF_:InvokeServer("LoadFruit", fruitName)
    end)
    if success then
        print("[Успех] LoadFruit для " .. fruitName .. " | Ответ: " .. tostring(result))
    else
        warn("[Ошибка] LoadFruit для " .. fruitName .. " | Причина: " .. tostring(result))
    end
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
        if char and char ~= oldChar then
            return char
        end
        task.wait(0.5)
        waited += 0.5
    end
    return nil
end

local function processLoadFruit(loadFruitItems)
    if #loadFruitItems == 0 then
        print("Список LoadFruit пуст, пропускаем.")
        return true
    end

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

-- ====================== ШАГ 5: ПОИСК СТОЛА ======================
-- Приоритет: 1) стол с нужным партнёром, 2) полностью свободный, 3) частично занятый любым.
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
                -- ИСПРАВЛЕНО: определяем игрока через Seat.Occupant
                if occupiedSeat and occupiedSeat.Occupant then
                    local occupantHumanoid = occupiedSeat.Occupant
                    if occupantHumanoid:IsA("Humanoid") then
                        local character = occupantHumanoid.Parent
                        if character then
                            local plr = Players:GetPlayerFromCharacter(character)
                            if plr then
                                occupantName = plr.Name
                            end
                        end
                    end
                end

                local entry = {tradeTable = tradeTable, freeSeat = freeSeats[1], wasFullyFree = false, occupantName = occupantName}
                if expectedPartnerName ~= "" and occupantName and string.lower(occupantName) == string.lower(expectedPartnerName) then
                    table.insert(withPartner, entry)
                else
                    table.insert(partiallyOccupied, entry)
                end
            end
        end
    end

    -- Приоритет 1: стол с нужным партнером
    if #withPartner > 0 then
        return withPartner[1].tradeTable, withPartner[1].freeSeat, false
    end

    -- Приоритет 2: полностью свободный
    if #fullyFree > 0 then
        return fullyFree[1].tradeTable, fullyFree[1].freeSeat, true
    end

    -- Приоритет 3: частично занятый (любой)
    if #partiallyOccupied > 0 then
        return partiallyOccupied[1].tradeTable, partiallyOccupied[1].freeSeat, false
    end

    return nil, nil, nil
end

-- ====================== ШАГ 6: ПЕРЕМЕЩЕНИЕ С ПРЫЖКАМИ ======================
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
                if stuckSeconds >= 2 then
                    humanoid.Jump = true
                    stuckSeconds = 0
                end
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

-- ====================== ШАГ 7: ОЖИДАНИЕ ПОСАДКИ ======================
local function waitForSeat(seatPart, timeout)
    local waited = 0
    while waited < timeout do
        local char = player.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Sit and hum.SeatPart == seatPart then
                return true
            end
        end
        task.wait(0.5)
        waited += 0.5
    end
    return false
end

-- ====================== ФУНКЦИЯ ПРОВЕРКИ, СИДИТ ЛИ ПЕРСОНАЖ НА НУЖНОМ СИДЕНЬЕ ======================
local function isSeated(mySeat)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    return hum.Sit and hum.SeatPart == mySeat
end

-- ====================== ФУНКЦИЯ ПОЛУЧЕНИЯ ПАРТНЁРА ======================
local function getPartnerName(tradeTable, mySeat)
    local seats = {}
    for _, part in ipairs(tradeTable:GetDescendants()) do
        if part:IsA("Seat") or part:IsA("VehicleSeat") then
            table.insert(seats, part)
        end
    end

    local otherSeat
    for _, seat in ipairs(seats) do
        if seat ~= mySeat then
            otherSeat = seat
            break
        end
    end
    if not otherSeat then return nil end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Sit and hum.SeatPart == otherSeat then
                    return plr.Name
                end
            end
        end
    end
    return nil
end

-- ====================== ФУНКЦИЯ ПЕРЕСАДКИ (С ЧАСТЫМИ КОЛЕБАНИЯМИ) ======================
local function resetSeatAndWait(mySeat, targetPos)
    print("Начинаю пересадку: буду повторять колебания до полной посадки.")
    local attempt = 0
    while true do
        attempt += 1
        local char = player.Character
        if not char then
            warn("Персонаж исчез, пересадка невозможна.")
            return false
        end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then
            warn("Humanoid не найден.")
            return false
        end

        if isSeated(mySeat) then
            print("Уже сидим на нужном сиденье.")
            return true
        end

        -- Встаём с сиденья (если сидели)
        pcall(function() hum.Sit = false end)
        task.wait(0.2)

        -- Прыжок
        hum.Jump = true
        task.wait(0.2)

        -- Цикл колебаний: несколько попыток сесть
        for i = 1, 5 do
            if isSeated(mySeat) then
                print("Пересадка успешна (после колебания " .. i .. ").")
                return true
            end

            -- Случайное направление и дистанция
            local direction = math.random(1,2) == 1 and 1 or -1
            local offsetDistance = math.random(3, 6)
            local offset = Vector3.new(direction * offsetDistance, 0, 0)

            -- Отходим
            hum:MoveTo(targetPos + offset)
            task.wait(0.3)

            -- Возвращаемся
            hum:MoveTo(targetPos)
            task.wait(0.3)

            -- Проверяем посадку чаще
            for check = 1, 5 do
                if isSeated(mySeat) then
                    print("Пересадка успешна (после проверки " .. check .. ").")
                    return true
                end
                task.wait(0.2)
            end
        end

        -- Если после всех колебаний не сели, повторяем внешний цикл
        print("Не сел после попытки " .. attempt .. ", повторяю колебания...")
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
        if current:IsA("TextButton") or current:IsA("ImageButton") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function findTextElementInContainer(container, search)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then
                return obj
            end
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
                if parent and parent.Name == "Title" then
                    return obj
                end
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
    if not bottomTitle or not (bottomTitle:IsA("TextLabel") or bottomTitle:IsA("TextButton") or bottomTitle:IsA("TextBox")) then
        return nil
    end
    local percent = bottomTitle.Text:match("(%d+)%%")
    return percent and tonumber(percent) or nil
end

local function checkSecondContainer(loadFruitItems)
    local secondContainer = findObjectByPath(playerGui, table.unpack(secondContainerPath))
    if not secondContainer then
        return false
    end
    for _, item in ipairs(loadFruitItems) do
        if not findTextElementInContainer(secondContainer, item) then
            return false
        end
    end
    return true
end

local function isTradeCompleted()
    local notifications = playerGui:FindFirstChild("Notifications")
    if not notifications then return false end
    for _, obj in ipairs(notifications:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            if obj.Text and obj.Text:lower():find("trade completed", 1, true) then
                return true
            end
        end
    end
    return false
end

local function processItem(searchText)
    -- Проверяем, добавлен ли уже предмет
    if findResultElement(searchText) then
        print("Предмет '" .. searchText .. "' уже добавлен.")
        return true
    end

    for attempt = 1, MAX_ATTEMPTS_PER_ITEM do
        print(string.format("Обработка '%s' (попытка %d/%d)", searchText, attempt, MAX_ATTEMPTS_PER_ITEM))

        local addButton = findObjectByPath(playerGui, table.unpack(addButtonPath))
        if not addButton then
            warn("AddButton не найден")
            task.wait(2)
            continue
        end
        fireSequence(addButton)

        local firstContainer = waitForObject(firstContainerPath, 5)
        if not firstContainer then
            warn("FrameAdd.Frame не появился")
            task.wait(2)
            continue
        end

        local textElement = findTextElementInContainer(firstContainer, searchText)
        if not textElement then
            warn("Элемент с текстом '" .. searchText .. "' не найден")
            task.wait(2)
            continue
        end

        local buttonToActivate = findParentButton(textElement)
        if not buttonToActivate then
            warn("Родительская кнопка не найдена")
            task.wait(2)
            continue
        end

        print("Активирую кнопку: " .. buttonToActivate:GetFullName())
        fireSequence(buttonToActivate)

        print("Ожидание результата...")
        local waitTime = 0
        while waitTime < RESULT_TIMEOUT do
            task.wait(0.5)
            waitTime += 0.5
            if findResultElement(searchText) then
                print("Результат для '" .. searchText .. "' появился.")
                return true
            end
        end
        warn("Результат не появился за " .. RESULT_TIMEOUT .. " сек.")
    end
    return false
end

-- ====================== ДОБАВЛЯЕМ ПРОВЕРКУ isSeated ВНУТРИ ВСЕХ ОЖИДАНИЙ ======================
local function checkPreAcceptConditions(loadFruitItems, mySeat)
    if not isSeated(mySeat) then
        print("Мы не сидим! Прерываем проверку условий.")
        return false
    end

    local percent = getPercent()
    if not percent or percent > 40 then
        print("Процент разницы > 40% (" .. tostring(percent) .. "%), ждём...")
        return false
    end
    if not checkSecondContainer(loadFruitItems) then
        print("Второй контейнер не содержит нужные фрукты, ждём...")
        return false
    end
    return true
end

local function waitForPreAcceptConditions(loadFruitItems, mySeat)
    local waited = 0
    while waited < ACCEPT_WAIT_TIMEOUT do
        if not isSeated(mySeat) then
            print("Встали во время ожидания условий. Возвращаем false.")
            return false
        end
        if checkPreAcceptConditions(loadFruitItems, mySeat) then
            return true
        end
        task.wait(ACCEPT_CHECK_INTERVAL)
        waited += ACCEPT_CHECK_INTERVAL
    end
    return false
end

local function acceptAndWaitForCompletion(loadFruitItems, mySeat)
    if not isSeated(mySeat) then
        print("Не сидим перед Accept. Возвращаем false.")
        return false
    end

    if not waitForPreAcceptConditions(loadFruitItems, mySeat) then
        print("Условия не выполнены (или встали).")
        return false
    end

    local acceptBtn = findObjectByPath(playerGui, table.unpack(acceptPath))
    if not acceptBtn then
        print("Кнопка Accept не найдена")
        return false
    end
    print("Активирую Accept...")
    fireSequence(acceptBtn)

    local waited = 0
    local ready1 = findObjectByPath(playerGui, table.unpack(ready1Path))
    while waited < READY_TIMEOUT do
        task.wait(0.5)
        waited += 0.5

        if not isSeated(mySeat) then
            print("Встали во время ожидания завершения трейда.")
            return false
        end

        if isTradeCompleted() then
            print("Трейд завершён (уведомление Trade completed).")
            return true
        end

        if ready1 and ready1:IsA("TextLabel") then
            if ready1.Text == "Ready!" then
                -- continue
            elseif ready1.Text == "Not ready." then
                print("Ready1 снова Not ready, требуется пересадка.")
                return false
            else
                print("Ready1 изменился на '" .. ready1.Text .. "', требуется пересадка.")
                return false
            end
        end
    end

    print("Таймаут ожидания завершения трейда, требуется пересадка.")
    return false
end

-- ====================== ОСНОВНОЙ ЦИКЛ ======================
print("Скрипт запущен.")

-- Шаг 1: выбор команды
selectTeam()

-- Шаг 2-3: сбор и отправка инвентаря, ожидание конфига
local config = nil
while config == nil do
    local inventory = collectInventory()
    if #inventory > 0 then
        sendInventory(inventory)
    else
        warn("Инвентарь пуст, пробуем ещё раз через " .. SEND_INVENTORY_INTERVAL .. " сек.")
        task.wait(SEND_INVENTORY_INTERVAL)
        continue
    end

    local waited = 0
    while waited < 120 do
        config = fetchConfig()
        if config then break end
        task.wait(CONFIG_POLL_INTERVAL)
        waited += CONFIG_POLL_INTERVAL
    end

    if not config then
        warn("Конфигурация не получена за 120 сек, повторяем цикл.")
        task.wait(SEND_INVENTORY_INTERVAL)
    end
end

print("Конфигурация получена, начинаем выполнение.")

-- Шаг 4: ресет фруктов
local loadSuccess = processLoadFruit(config.load_fruit_items or {})
if not loadSuccess then
    warn("Ошибка во время ресета фруктов, завершаем.")
    return
end

-- Шаг 5: основной цикл поиска стола и трейда
local tradeCompleted = false
while not tradeCompleted do
    local tradeTable, mySeat, wasFullyFree = findTradeTable(config.partner_name or "")
    if not tradeTable then
        print("Стол не найден, ждём 5 секунд.")
        task.wait(5)
        continue
    end

    local targetPos = mySeat.Position
    print("Найден стол. Тип:", wasFullyFree and "полностью свободный" or "частично занят (возможно нужный партнёр)")

    local arrived = moveToPositionWithJump(targetPos)
    if not arrived then
        print("Не удалось добраться, пробуем другой стол.")
        task.wait(2)
        continue
    end

    local seated = waitForSeat(mySeat, 30)
    if not seated then
        print("Не сел сразу, пробуем пересадку.")
        if not resetSeatAndWait(mySeat, targetPos) then
            print("Пересадка не удалась, ищем новый стол.")
            task.wait(2)
            continue
        end
        seated = true
    end

    print("Сидим за столом. Ожидание партнёра...")

    while not tradeCompleted do
        if not isSeated(mySeat) then
            print("Обнаружено, что не сидим. Выполняем пересадку.")
            if not resetSeatAndWait(mySeat, targetPos) then
                print("Не удалось пересадиться, выходим из этого стола.")
                break
            end
        end

        local partnerNameActual = getPartnerName(tradeTable, mySeat)
        local expectedPartner = config.partner_name or ""

        print("Текущий партнёр:", partnerNameActual or "никого нет", "| ожидаемый:", expectedPartner)

        if partnerNameActual == nil then
            task.wait(1)
        elseif expectedPartner ~= "" and partnerNameActual ~= expectedPartner then
            print("Партнёр не совпадает, пересаживаемся.")
            if not resetSeatAndWait(mySeat, targetPos) then
                print("Не удалось пересадиться, выходим из этого стола.")
                break
            end
        else
            print("Партнёр подходит. Добавляем предметы в первый контейнер.")
            local allItemsAdded = true
            for _, itemName in ipairs(config.trade_items or {}) do
                if not isSeated(mySeat) then
                    print("Встали во время добавления предметов. Пересаживаемся и начинаем заново.")
                    if not resetSeatAndWait(mySeat, targetPos) then
                        print("Пересадка не удалась, выходим из стола.")
                        allItemsAdded = false
                        break
                    end
                    allItemsAdded = false
                    break
                end
                if not processItem(itemName) then
                    allItemsAdded = false
                    break
                end
            end

            if not allItemsAdded then
                print("Не удалось добавить все предметы. Пересаживаемся.")
                if not resetSeatAndWait(mySeat, targetPos) then
                    print("Не удалось пересадиться после ошибки добавления.")
                    break
                end
            else
                print("Все предметы добавлены, запускаем Accept.")
                if not isSeated(mySeat) then
                    print("Встали перед Accept. Пересаживаемся и повторяем.")
                    if not resetSeatAndWait(mySeat, targetPos) then
                        print("Пересадка не удалась, выходим.")
                        break
                    end
                else
                    local tradeDone = acceptAndWaitForCompletion(config.load_fruit_items or {}, mySeat)
                    if tradeDone then
                        print("Трейд успешно завершён!")
                        tradeCompleted = true
                        break
                    else
                        print("Трейд не удался или встали. Пересаживаемся и пробуем снова.")
                        if not resetSeatAndWait(mySeat, targetPos) then
                            print("Не удалось пересадиться после неудачного трейда.")
                            break
                        end
                    end
                end
            end
        end
    end
end

print("Скрипт завершён.")
