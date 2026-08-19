-- ============================================================
-- ПОЛНЫЙ АВТО-ТРЕЙД С ПРОВЕРКОЙ ПАРТНЁРА, ВТОРОГО КОНТЕЙНЕРА И ЗАВЕРШЕНИЕМ
-- ============================================================

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Players = game:GetService("Players")

-- ====================== КОНФИГУРАЦИЯ ======================
-- Предметы для первого контейнера (мы добавляем)
local itemNames = {
    "NAME1",
    "NAME2",
    -- добавьте другие названия
}

-- Предметы, которые должны быть во втором контейнере (проверка перед accept)
local itemNames2 = {
    "NAME1",
    "NAME2",
    -- список того, что должно быть у партнёра
}

-- Ник ожидаемого партнёра. Если пустая строка - проверка отключена.
local tradePartnerName = ""  -- например: "Steve"

-- Пути
local addButtonPath = {"Main", "Trade", "Container", "1", "Frame", "AddButton"}
local firstContainerPath = {"Main", "Trade", "Container", "FrameAdd", "Frame"}
local resultContainerPath = {"Main", "Trade", "Container", "1", "Frame"}
local secondContainerPath = {"Main", "Trade", "Container", "2", "Frame"}
local acceptPath = {"Main", "Trade", "Info", "Accept"}
local ready1Path = {"Main", "Trade", "Info", "Ready1"}
local bottomTitlePath = {"Main", "Trade", "BottomTitle"}

-- Параметры
local RESULT_TIMEOUT = 30
local MAX_ATTEMPTS_PER_ITEM = 3
local READY_TIMEOUT = 30
local ACCEPT_CHECK_INTERVAL = 0.5 -- интервал проверки перед accept (после неудачи)
local ACCEPT_WAIT_TIMEOUT = 30    -- сколько ждать, если условия не выполнены
-- ============================================================

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

-- Получение ника партнёра на другом сиденье (может вернуть nil)
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

-- Проверка, что все предметы из itemNames2 есть во втором контейнере
local function checkSecondContainer()
    local secondContainer = findObjectByPath(playerGui, secondContainerPath)
    if not secondContainer then
        return false
    end
    for _, item in ipairs(itemNames2) do
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

-- Обработка одного предмета
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

-- Функция проверки условий перед accept (value и второй контейнер)
-- Возвращает true, если условия выполнены
local function checkPreAcceptConditions()
    local percent = getPercent()
    if not percent or percent > 40 then
        print("Процент разницы > 40% (" .. tostring(percent) .. "%), ждём...")
        return false
    end
    if not checkSecondContainer() then
        print("Второй контейнер не содержит нужные предметы, ждём...")
        return false
    end
    return true
end

-- Функция ожидания выполнения условий с таймаутом 30 сек
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
-- Возвращает true только если появилось уведомление "Trade completed"
local function acceptAndWaitForCompletion()
    while true do
        -- проверяем условия перед accept
        if not waitForPreAcceptConditions() then
            print("Условия не выполнены за " .. ACCEPT_WAIT_TIMEOUT .. " сек, выпрыгиваем.")
            return false
        end

        -- активируем accept
        local acceptBtn = findObjectByPath(playerGui, acceptPath)
        if not acceptBtn then
            print("Кнопка Accept не найдена")
            return false
        end
        print("Активирую Accept...")
        fireSequence(acceptBtn)

        -- ждём либо уведомления о завершении, либо сброса Ready1
        local waited = 0
        local ready1 = findObjectByPath(playerGui, ready1Path)
        while waited < READY_TIMEOUT do
            task.wait(0.5)
            waited += 0.5

            -- проверяем уведомление о завершении
            if isTradeCompleted() then
                print("Трейд завершён (уведомление Trade completed).")
                return true
            end

            -- если Ready1 существует, проверяем его текст
            if ready1 and ready1:IsA("TextLabel") then
                if ready1.Text == "Ready!" then
                    -- готовность есть, но уведомление не появилось, продолжаем ждать
                elseif ready1.Text == "Not ready." then
                    -- сброс, выходим из ожидания, чтобы повторить цикл accept
                    print("Ready1 снова Not ready, повторяем проверку и accept...")
                    break
                else
                    -- любое другое изменение, тоже повторим
                    print("Ready1 изменился на '" .. ready1.Text .. "', повторяем.")
                    break
                end
            end
        end

        -- если вышли из-за таймаута, то продолжаем цикл accept (бесконечно)
        print("Повторяем попытку accept...")
    end
end

-- ====================== ОСНОВНОЙ ЦИКЛ ======================
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
    for _, name in ipairs(itemNames) do
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
        break  -- выходим из основного цикла (можно не выходить, а начать заново)
    else
        print("Трейд не завершён, прыгаем и пробуем снова.")
        doJump()
        task.wait(2)
    end
end
