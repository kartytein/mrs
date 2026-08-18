-- ============================================================
-- МУЛЬТИ-АКТИВАТОР С ПРОВЕРКОЙ ТРЕЙД-ПАРТНЁРА
-- Конфигурация:
--   itemNames         - список названий предметов для активации
--   tradePartnerName  - ожидаемый ник партнёра ("" = не проверять)
-- Перед активацией предметов скрипт ожидает, пока персонаж сядет
-- за TradeTable, проверяет партнёра на втором сиденье.
-- Если партнёр не совпадает с ожидаемым, персонаж выпрыгивает из
-- сиденья и скрипт повторяет ожидание.
-- ============================================================

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Players = game:GetService("Players")

-- ====================== КОНФИГУРАЦИЯ ======================
local itemNames = {
    "sand",
    "shadow",
    -- добавьте другие названия
}

-- Ник ожидаемого партнёра. Если пустая строка - проверка отключена.
local tradePartnerName = "WillieFrost6"  -- пример: "Steve"

-- Пути к UI-элементам
local addButtonPath = {"Main", "Trade", "Container", "1", "Frame", "AddButton"}
local firstContainerPath = {"Main", "Trade", "Container", "FrameAdd", "Frame"}
local resultContainerPath = {"Main", "Trade", "Container", "1", "Frame"}

local RESULT_TIMEOUT = 30
local MAX_ATTEMPTS_PER_ITEM = 3
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

-- Основной цикл: ожидание подходящего партнёра и активация предметов
print("Запуск с проверкой партнёра...")

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

    -- Выполняем активацию предметов
    local allSuccess = true
    for _, name in ipairs(itemNames) do
        if not processItem(name) then
            allSuccess = false
            break
        end
    end

    if allSuccess then
        print("Все предметы успешно активированы.")
    else
        print("Не удалось активировать все предметы.")
    end

    -- Завершаем скрипт (если нужно, можно зациклить)
    break
end
