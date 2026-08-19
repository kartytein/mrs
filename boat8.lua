-- ============================================================
-- ПОЛНЫЙ АВТО-ТРЕЙД БЕЗ ТАЙМАУТОВ ОЖИДАНИЯ
-- Ожидание партнёра и условий теперь бесконечное
-- (прерывается только если персонаж покинул сиденье)
-- ============================================================

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Players = game:GetService("Players")

-- ====================== КОНФИГУРАЦИЯ ======================
local itemNames = {
    "sand",
    -- добавьте другие названия
}

local tradePartnerName = "WillieFrost6"  -- если пусто, проверка партнёра отключена

local expectedItemsInContainer2 = {
    "flame",
    -- названия, которые должны быть в контейнере 2 перед Accept
}

-- Пути к UI-элементам
local addButtonPath = {"Main", "Trade", "Container", "1", "Frame", "AddButton"}
local firstContainerPath = {"Main", "Trade", "Container", "FrameAdd", "Frame"}
local resultContainerPath = {"Main", "Trade", "Container", "1", "Frame"}
local secondContainerPath = {"Main", "Trade", "Container", "2", "Frame"}
local acceptPath = {"Main", "Trade", "Info", "Accept"}
local ready1Path = {"Main", "Trade", "Info", "Ready1"}
local bottomTitlePath = {"Main", "Trade", "BottomTitle"}

-- Параметры (таймауты оставлены только для отдельных ожиданий UI)
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

-- Поиск текстового элемента в контейнере по подстроке (регистронезависимо)
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

-- Проверка содержимого контейнера 2
local function checkContainer2Contents()
    local container2 = findObjectByPath(playerGui, secondContainerPath)
    if not container2 then
        print("Контейнер 2 не найден")
        return false
    end

    local foundTexts = {}
    local function collectTexts(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                table.insert(foundTexts, child.Text)
            end
        end
    end
    collectTexts(container2)

    print("Содержимое контейнера 2:")
    for i, t in ipairs(foundTexts) do
        print("  [" .. i .. "] " .. t)
    end

    local missing = {}
    for _, expected in ipairs(expectedItemsInContainer2) do
        local found = false
        for _, t in ipairs(foundTexts) do
            if t and t:lower():find(expected:lower(), 1, true) then
                found = true
                break
            end
        end
        if not found then
            table.insert(missing, expected)
        end
    end

    if #missing > 0 then
        print("В контейнере 2 отсутствуют:")
        for _, m in ipairs(missing) do
            print("  - " .. m)
        end
        return false
    else
        print("Контейнер 2 содержит все ожидаемые предметы.")
        return true
    end
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
        print("Активирую AddButton...")
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

-- Финальная активация Accept с бесконечным ожиданием условий
local function acceptTrade()
    print("Ожидание выполнения условий для Accept...")
    while true do
        local container2Ok = checkContainer2Contents()
        local percent = getPercent()

        if container2Ok and percent and percent <= 40 then
            break
        end

        -- Проверяем, всё ещё сидим
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if not hum or not hum.Sit or hum.SeatPart == nil then
            return false
        end

        task.wait(0.5)
    end

    local acceptBtn = findObjectByPath(playerGui, acceptPath)
    if not acceptBtn then
        print("Кнопка Accept не найдена")
        return false
    end

    print("Активирую Accept...")
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
    local tradeTable, mySeat = waitForTradeTableSeat()
    print("Сижу за TradeTable.")

    local partnerName = getPartnerName(tradeTable, mySeat)

    -- Ожидание подходящего партнёра (бесконечно)
    if tradePartnerName ~= "" then
        while partnerName ~= tradePartnerName do
            print(string.format("Партнёр '%s' не совпадает с ожидаемым '%s'. Ожидание...", tostring(partnerName), tradePartnerName))

            -- Если персонаж больше не сидит, выходим из ожидания
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if not hum or not hum.Sit or hum.SeatPart ~= mySeat then
                break
            end

            task.wait(0.5)
            partnerName = getPartnerName(tradeTable, mySeat)
        end

        -- Проверяем, остались ли мы на сиденье и совпадает ли партнёр
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if not hum or not hum.Sit or hum.SeatPart ~= mySeat then
            continue  -- персонаж покинул сиденье, начинаем заново
        end

        if partnerName ~= tradePartnerName then
            -- вышли из цикла из-за пропажи партнёра (но мы всё ещё сидим?)
            -- значит, ждём появления нового партнёра (вернёмся в начало)
            continue
        end

        print("Партнёр подходит: " .. partnerName)
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
        break
    else
        print("Трейд не завершён.")
        doJump()
        task.wait(2)
    end
end
