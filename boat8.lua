-- ============================================================
-- ПОЛНЫЙ АВТО-ТРЕЙД С ПРОВЕРКОЙ ПАРТНЁРА И АКТИВАЦИЕЙ ACCEPT
-- ============================================================

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Players = game:GetService("Players")

-- ====================== КОНФИГУРАЦИЯ ======================
local itemNames = {
    "sand",
    -- добавьте другие названия
}

-- Ник ожидаемого партнёра. Если пустая строка - проверка отключена.
local tradePartnerName = "WillieFrost6"  -- например: "Steve"

-- Пути к UI-элементам
local addButtonPath = {"Main", "Trade", "Container", "1", "Frame", "AddButton"}
local firstContainerPath = {"Main", "Trade", "Container", "FrameAdd", "Frame"}
local resultContainerPath = {"Main", "Trade", "Container", "1", "Frame"}
local acceptPath = {"Main", "Trade", "Info", "Accept"}
local ready1Path = {"Main", "Trade", "Info", "Ready1"}
local bottomTitlePath = {"Main", "Trade", "BottomTitle"}

-- Параметры
local RESULT_TIMEOUT = 30
local MAX_ATTEMPTS_PER_ITEM = 3
local READY_TIMEOUT = 30
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

-- Обработка одного предмета
local function processItem(searchText)
    for attempt = 1, MAX_ATTEMPTS_PER_ITEM do
        print(string.format("Обработка '%s' (попытка %d/%d)", searchText, attempt, MAX_ATTEMPTS_PER_ITEM))

        -- Активируем AddButton
        local addButton = findObjectByPath(playerGui, addButtonPath)
        if not addButton then
            warn("AddButton не найден")
            task.wait(2)
            continue
        end
        print("Активирую AddButton...")
        fireSequence(addButton)

        -- Ждём FrameAdd.Frame
        local firstContainer = waitForObject(firstContainerPath, 5)
        if not firstContainer then
            warn("FrameAdd.Frame не появился")
            task.wait(2)
            continue
        end

        -- Ищем элемент с текстом
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

        -- Ожидание результата
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

-- Финальная активация Accept
local function acceptTrade()
    local percent = getPercent()
    if not percent then
        print("Не удалось извлечь процент из BottomTitle.")
        return false
    end
    print("Текущая разница: " .. percent .. "% (Max. 40%)")
    if percent > 40 then
        print("Невозможно активировать Accept: разница " .. percent .. "% превышает допустимые 40%.")
        return false
    end

    local acceptBtn = findObjectByPath(playerGui, acceptPath)
    if not acceptBtn then
        print("Кнопка Accept не найдена")
        return false
    end

    print("Процент в норме, активирую Accept...")
    local ok = fireSequence(acceptBtn)
    if not ok then
        print("Не удалось активировать Accept.")
        return false
    end

    local ready1 = findObjectByPath(playerGui, ready1Path)
    if not ready1 or not (ready1:IsA("TextLabel") or ready1:IsA("TextButton") or ready1:IsA("TextBox")) then
        print("Ready1 не найден или не является текстовым элементом")
        return false
    end

    print("Ожидаю готовности...")
    local waited = 0
    while waited < READY_TIMEOUT do
        task.wait(0.5)
        waited += 0.5
        if ready1.Text == "Ready!" then
            print("Готово! Ready1 изменился на 'Ready!'")
            return true
        end
    end
    print("Не удалось дождаться готовности за " .. READY_TIMEOUT .. " секунд.")
    print("Текущий текст Ready1: " .. ready1.Text)
    return false
end

-- Основной цикл
print("Запуск авто-трейда...")

while true do
    -- Ждём, пока сядем за TradeTable
    local tradeTable, mySeat = waitForTradeTableSeat()
    print("Сижу за TradeTable.")

    local partnerName = getPartnerName(tradeTable, mySeat)
    if tradePartnerName ~= "" then
        if partnerName ~= tradePartnerName then
            print(string.format("Партнёр '%s' не совпадает с ожидаемым '%s'. Выпрыгиваю.", tostring(partnerName), tradePartnerName))
            doJump()
            task.wait(2)
            continue
        else
            print("Партнёр подходит: " .. partnerName)
        end
    else
        print("Проверка партнёра отключена.")
    end

    -- Активируем предметы
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

    -- Активируем Accept
    local success = acceptTrade()
    if success then
        print("Трейд завершён успешно.")
        break  -- или можно выполнить следующий трейд, если нужно
    else
        print("Трейд не завершён.")
        doJump()
        task.wait(2)
    end
end
