-- ============================================================
-- ОБЪЕДИНЁННЫЙ СКРИПТ: LoadFruit + Respawn + AutoTrade
-- Конфигурация получается с Python-сервера каждые 10 секунд
-- Используется game:HttpGet (как в исходном примере)
-- load_fruit_items применяется и для LoadFruit, и для проверки второго контейнера
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")  -- для JSONDecode
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ====================== НАСТРОЙКИ ЗАПРОСОВ ======================
local SERVER_URL = "http://192.168.1.100:8000/get_config"  -- замените на ваш IP
local POLL_INTERVAL = 10  -- секунд между запросами

-- ====================== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ КОНФИГУРАЦИИ ======================
local loadFruitItems = {}   -- список фруктов для LoadFruit и проверки второго контейнера
local tradeItems = {}       -- предметы для первого контейнера
local tradePartnerName = "" -- ожидаемый партнёр

-- ====================== ФУНКЦИИ ДЛЯ ЗАПРОСА К СЕРВЕРУ ======================
local function fetchConfig()
    local url = SERVER_URL .. "?nickname=" .. HttpService:UrlEncode(player.Name)
    local success, response = pcall(function()
        return game:HttpGet(url)  -- используем game:HttpGet как в рабочем примере
    end)

    if not success then
        warn("Ошибка запроса конфигурации:", response)
        return nil
    end

    local data = HttpService:JSONDecode(response)
    if not data or not data.load_fruit_items then
        warn("Некорректный формат конфигурации")
        return nil
    end

    loadFruitItems = data.load_fruit_items or {}
    tradeItems = data.trade_items or {}
    tradePartnerName = data.partner_name or ""

    print("Конфигурация получена:", data)
    return data
end

-- ====================== ФУНКЦИИ ДЛЯ LOADFRUIT + RESPAWN ======================
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

    local success, err = pcall(function()
        hum.Health = 0
    end)

    if success then
        print("Респавн выполнен (Health = 0).")
        return true
    else
        warn("Ошибка при установке Health: " .. tostring(err))
        return false
    end
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

-- Выполнение LoadFruit для каждого фрукта с респавном после каждого
local function processLoadFruit()
    if #loadFruitItems == 0 then
        print("Список LoadFruit пуст, пропускаем.")
        return true
    end

    for _, item in ipairs(loadFruitItems) do
        local formatted = formatItemName(item)
        print("Обрабатываю '" .. item .. "' -> '" .. formatted .. "'")
        invokeLoadFruit(formatted)

        respawnCharacter()
        local newChar = waitForCharacterRespawn()
        if not newChar then
            warn("Не удалось дождаться респавна для " .. item)
            return false
        end
        task.wait(1)  -- пауза перед следующим фруктом
    end
    return true
end

-- ====================== ФУНКЦИИ ДЛЯ АВТО-ТРЕЙДА ======================
-- Пути и параметры из исходного скрипта
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

-- Активация кнопки через getconnections
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
    for _, sigName in ipairs(signals) do
        local success, err = pcall(function()
            local sig = btn[sigName]
            if sig then
                local conns = getconnections(sig)
                if conns and #conns > 0 then
                    for _, conn in ipairs(conns) do
                        if conn.Enabled and type(conn.Function) == "function" then
                            conn.Function()
                        end
                    end
                end
            end
        end)
        if not success then
            warn("Ошибка при вызове " .. sigName .. ": " .. tostring(err))
        end
    end
    return true
end

-- Поиск объекта по пути
local function findObjectByPath(root, path)
    local current = root
    for _, segment in ipairs(path) do
        if not current then return nil end
        current = current:FindFirstChild(segment)
    end
    return current
end

-- Поиск родительской кнопки
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

-- Поиск текстового элемента в контейнере по подстроке
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

-- Поиск элемента-результата в resultContainer
local function findResultElement(search)
    local container = findObjectByPath(playerGui, resultContainerPath)
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

-- Ожидание появления объекта
local function waitForObject(path, timeout)
    local waited = 0
    while waited < timeout do
        local obj = findObjectByPath(playerGui, path)
        if obj then return obj end
        task.wait(0.5)
        waited += 0.5
    end
    return nil
end

-- Ожидание, пока персонаж сядет на TradeTable
local function waitForTradeTableSeat()
    while true do
        local char = player.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Sit and hum.SeatPart then
                local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
                if model and model.Name == "TradeTable" then
                    return model, hum.SeatPart
                end
            end
        end
        task.wait(0.5)
    end
end

-- Получение ника партнёра на другом сиденье
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

-- Прыжок: выйти из сиденья и подпрыгнуть
local function doJump()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    pcall(function()
        hum.Sit = false
        task.wait(0.2)
        hum.Jump = true
    end)
end

-- Проверка процента в BottomTitle
local function getPercent()
    local bottomTitle = findObjectByPath(playerGui, bottomTitlePath)
    if not bottomTitle or not (bottomTitle:IsA("TextLabel") or bottomTitle:IsA("TextButton") or bottomTitle:IsA("TextBox")) then
        return nil
    end
    local percent = bottomTitle.Text:match("(%d+)%%")
    return percent and tonumber(percent) or nil
end

-- Проверка, что все фрукты из loadFruitItems есть во втором контейнере
local function checkSecondContainer()
    local secondContainer = findObjectByPath(playerGui, secondContainerPath)
    if not secondContainer then
        return false
    end
    for _, item in ipairs(loadFruitItems) do  -- используем loadFruitItems
        if not findTextElementInContainer(secondContainer, item) then
            return false
        end
    end
    return true
end

-- Проверка уведомления о завершении трейда
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

-- Обработка одного предмета (первый контейнер)
local function processItem(searchText)
    for attempt = 1, MAX_ATTEMPTS_PER_ITEM do
        print(string.format("Обработка '%s' (попытка %d/%d)", searchText, attempt, MAX_ATTEMPTS_PER_ITEM))

        local addButton = findObjectByPath(playerGui, addButtonPath)
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

-- Проверка условий перед accept
local function checkPreAcceptConditions()
    local percent = getPercent()
    if not percent or percent > 40 then
        print("Процент разницы > 40% (" .. tostring(percent) .. "%), ждём...")
        return false
    end
    if not checkSecondContainer() then
        print("Второй контейнер не содержит нужные фрукты, ждём...")
        return false
    end
    return true
end

-- Ожидание выполнения условий с таймаутом
local function waitForPreAcceptConditions()
    local waited = 0
    while waited < ACCEPT_WAIT_TIMEOUT do
        if checkPreAcceptConditions() then
            return true
        end
        task.wait(ACCEPT_CHECK_INTERVAL)
        waited += ACCEPT_CHECK_INTERVAL
    end
    return false
end

-- Финальная активация Accept и ожидание завершения трейда
local function acceptAndWaitForCompletion()
    while true do
        if not waitForPreAcceptConditions() then
            print("Условия не выполнены за " .. ACCEPT_WAIT_TIMEOUT .. " сек, выпрыгиваем.")
            return false
        end

        local acceptBtn = findObjectByPath(playerGui, acceptPath)
        if not acceptBtn then
            print("Кнопка Accept не найдена")
            return false
        end
        print("Активирую Accept...")
        fireSequence(acceptBtn)

        local waited = 0
        local ready1 = findObjectByPath(playerGui, ready1Path)
        while waited < READY_TIMEOUT do
            task.wait(0.5)
            waited += 0.5

            if isTradeCompleted() then
                print("Трейд завершён (уведомление Trade completed).")
                return true
            end

            if ready1 and ready1:IsA("TextLabel") then
                if ready1.Text == "Ready!" then
                    -- готовность есть, но уведомление не появилось, продолжаем ждать
                elseif ready1.Text == "Not ready." then
                    print("Ready1 снова Not ready, повторяем проверку и accept...")
                    break
                else
                    print("Ready1 изменился на '" .. ready1.Text .. "', повторяем.")
                    break
                end
            end
        end

        print("Повторяем попытку accept...")
    end
end

-- Основная логика авто-трейда
local function processAutoTrade()
    if #tradeItems == 0 then
        print("Список предметов для трейда пуст, пропускаем.")
        return
    end

    print("Запуск авто-трейда...")
    while true do
        -- 1. Ждём, пока сядем за TradeTable
        local tradeTable, mySeat = waitForTradeTableSeat()
        print("Сижу за TradeTable.")

        -- 2. Ожидание партнёра
        local partnerName = nil
        while partnerName == nil do
            partnerName = getPartnerName(tradeTable, mySeat)
            if partnerName == nil then
                print("Второе сиденье пусто, жду партнёра...")
                task.wait(1)
            end
        end
        print("Партнёр найден: " .. partnerName)

        -- 3. Проверка ника (если задано)
        if tradePartnerName ~= "" and partnerName ~= tradePartnerName then
            print(string.format("Партнёр '%s' не совпадает с ожидаемым '%s'. Выпрыгиваю.", partnerName, tradePartnerName))
            doJump()
            task.wait(2)
            continue
        elseif tradePartnerName == "" then
            print("Проверка партнёра отключена.")
        else
            print("Партнёр подходит: " .. partnerName)
        end

        -- 4. Активация предметов первого контейнера
        local allSuccess = true
        for _, name in ipairs(tradeItems) do
            if not processItem(name) then
                allSuccess = false
                break
            end
        end
        if not allSuccess then
            print("Не удалось активировать все предметы.")
            doJump()
            task.wait(2)
            continue
        end

        -- 5. Проверка второго контейнера и value, затем accept и ожидание завершения
        local tradeDone = acceptAndWaitForCompletion()
        if tradeDone then
            print("Трейд успешно завершён.")
            break  -- выходим из цикла авто-трейда
        else
            print("Трейд не завершён, прыгаем и пробуем снова.")
            doJump()
            task.wait(2)
        end
    end
end

-- ====================== ОСНОВНОЙ ЦИКЛ ОПРОСА СЕРВЕРА ======================
print("Скрипт запущен. Ожидание конфигурации с сервера...")

while true do
    local config = fetchConfig()
    if config then
        -- Выполняем LoadFruit + Respawn
        local success = processLoadFruit()
        if success then
            -- Переходим к авто-трейду
            processAutoTrade()
        else
            warn("Ошибка в процессе LoadFruit, пропускаем авто-трейд.")
        end
        -- После успешного трейда выходим из цикла опроса (можно изменить)
        break
    else
        print("Конфигурация не получена, повтор через " .. POLL_INTERVAL .. " секунд.")
    end
    task.wait(POLL_INTERVAL)
end
