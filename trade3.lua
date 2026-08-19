-- ============================================================
-- ОБЪЕДИНЁННЫЙ КЛИЕНТСКИЙ СКРИПТ С ПОДДЕРЖКОЙ ТЕЛЕПОРТА
-- 1. Собирает инвентарь, отправляет на сервер с JobId
-- 2. Получает конфигурацию (включая teleport_to_job_id для guest)
-- 3. Если нужно, выполняет телепорт по JobId
-- 4. Выполняет LoadFruit + AutoTrade
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local CoreGui = game:GetService("CoreGui")

-- ====================== НАСТРОЙКИ ======================
local SERVER_URL = "http://192.168.31.179:8000"
local POLL_INTERVAL = 10  -- опрос конфигурации
local SEND_INVENTORY_INTERVAL = 20  -- периодичность отправки инвентаря
local TELEPORT_TIMEOUT = 60  -- таймаут ожидания телепорта

-- ====================== ФУНКЦИИ ДЛЯ СБОРА ИНВЕНТАРЯ ======================
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local signals = {"MouseEnter", "MouseButton1Down", "MouseButton1Click", "MouseButton1Up", "Activated", "MouseLeave"}
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

local function activateButtonByPath(pathSegments, description)
    local btn = findObjectByPath(playerGui, table.unpack(pathSegments))
    if not btn then
        warn("Кнопка не найдена: " .. description)
        return false
    end
    fireSequence(btn)
    return true
end

local function collectInventory()
    print("Сбор инвентаря...")
    if not activateButtonByPath({"Main", "MenuButton"}, "Main.MenuButton") then return {} end
    task.wait(1)
    if not activateButtonByPath({"Main", "InventoryButton"}, "Main.InventoryButton") then return {} end
    task.wait(1)
    if not activateButtonByPath({"Inventory", "Inventory", "Main", "NavigationRail", "HoverBox", "UpperBar", "Category2"}, "Category2") then return {} end
    task.wait(2)

    local tileGrid = findObjectByPath(playerGui, "Inventory", "Inventory", "Main", "PageContent", "TileGrid")
    if not tileGrid then
        warn("TileGrid не найден")
        return {}
    end

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

-- ====================== ОТПРАВКА НА СЕРВЕР ======================
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

-- ====================== ПОЛУЧЕНИЕ КОНФИГУРАЦИИ ======================
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

-- ====================== ТЕЛЕПОРТ ПО JOB_ID ======================
local function teleportToJobId(targetJobId)
    print("Телепорт на JobId:", targetJobId)
    local TAB = 19
    local OPT_TEXTBOX = 2
    local OPT_ACTIVATE = 3
    local TEXT_TO_INSERT = targetJobId

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

    local function findTextBox(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextBox") then
                return child
            end
            local found = findTextBox(child)
            if found then return found end
        end
        return nil
    end

    local root = getRoot()
    if not root then
        warn("Интерфейс redz-library-v5 не найден, телепорт невозможен")
        return false
    end

    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then warn("TabsScroll не найден") return false end

    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == TAB then
                    tabButton = c
                    return
                end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not tabButton then warn("Вкладка "..TAB.." не найдена") return false end

    fireSequence(tabButton)
    task.wait(0.5)

    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then warn("Container не найден") return false end

    local optionTextBox = nil
    local optCount = 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == OPT_TEXTBOX then
                optionTextBox = c
                break
            end
        end
    end
    if not optionTextBox then warn("Опция "..OPT_TEXTBOX.." не найдена") return false end

    local textBox = findTextBox(optionTextBox)
    if not textBox then warn("TextBox не найден") return false end

    textBox.Text = TEXT_TO_INSERT
    task.wait(0.1)
    pcall(function()
        textBox:CaptureFocus()
        task.wait(0.1)
        textBox:ReleaseFocus()
    end)

    local optionActivate = nil
    local optCount2 = 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount2 += 1
            if optCount2 == OPT_ACTIVATE then
                optionActivate = c
                break
            end
        end
    end
    if not optionActivate then warn("Опция "..OPT_ACTIVATE.." не найдена") return false end

    fireSequence(optionActivate)
    task.wait(0.2)
    print("Телепорт активирован.")
    return true
end

-- Ожидание, пока game.JobId станет целевым
local function waitForTeleport(targetJobId, timeout)
    local waited = 0
    while waited < timeout do
        if game.JobId == targetJobId then
            return true
        end
        task.wait(1)
        waited += 1
    end
    return false
end

-- ====================== LOADFRUIT + RESPAWN ======================
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

-- ====================== АВТО-ТРЕЙД (полные функции) ======================
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

local function checkPreAcceptConditions(loadFruitItems)
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

local function waitForPreAcceptConditions(loadFruitItems)
    local waited = 0
    while waited < ACCEPT_WAIT_TIMEOUT do
        if checkPreAcceptConditions(loadFruitItems) then
            return true
        end
        task.wait(ACCEPT_CHECK_INTERVAL)
        waited += ACCEPT_CHECK_INTERVAL
    end
    return false
end

local function acceptAndWaitForCompletion(loadFruitItems)
    while true do
        if not waitForPreAcceptConditions(loadFruitItems) then
            print("Условия не выполнены за " .. ACCEPT_WAIT_TIMEOUT .. " сек, выпрыгиваем.")
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

            if isTradeCompleted() then
                print("Трейд завершён (уведомление Trade completed).")
                return true
            end

            if ready1 and ready1:IsA("TextLabel") then
                if ready1.Text == "Ready!" then
                    -- continue
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

local function processAutoTrade(tradeItems, partnerName, loadFruitItems)
    if #tradeItems == 0 then
        print("Список предметов для трейда пуст, пропускаем.")
        return
    end

    print("Запуск авто-трейда...")
    while true do
        local tradeTable, mySeat = waitForTradeTableSeat()
        print("Сижу за TradeTable.")

        local partner = nil
        while partner == nil do
            partner = getPartnerName(tradeTable, mySeat)
            if partner == nil then
                print("Второе сиденье пусто, жду партнёра...")
                task.wait(1)
            end
        end
        print("Партнёр найден: " .. partner)

        if partnerName ~= "" and partner ~= partnerName then
            print(string.format("Партнёр '%s' не совпадает с ожидаемым '%s'. Выпрыгиваю.", partner, partnerName))
            doJump()
            task.wait(2)
            continue
        elseif partnerName == "" then
            print("Проверка партнёра отключена.")
        else
            print("Партнёр подходит: " .. partner)
        end

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

        local tradeDone = acceptAndWaitForCompletion(loadFruitItems)
        if tradeDone then
            print("Трейд успешно завершён.")
            break
        else
            print("Трейд не завершён, прыгаем и пробуем снова.")
            doJump()
            task.wait(2)
        end
    end
end

-- ====================== ОСНОВНОЙ ЦИКЛ ======================
print("Скрипт запущен. Начинаем сбор и отправку инвентаря...")

while true do
    -- 1. Сбор инвентаря
    local inventory = collectInventory()
    if #inventory > 0 then
        sendInventory(inventory)
    else
        warn("Инвентарь пуст, не отправляем.")
    end

    -- 2. Ожидание конфигурации
    local config = nil
    local waited = 0
    while config == nil and waited < 120 do  -- ждём до 2 минут
        config = fetchConfig()
        if config == nil then
            task.wait(POLL_INTERVAL)
            waited += POLL_INTERVAL
        end
    end

    if config then
        print("Найдена конфигурация, начинаем выполнение...")

        -- 3. Телепорт, если требуется
        local teleportTo = config.teleport_to_job_id
        if teleportTo and teleportTo ~= game.JobId then
            print("Требуется телепорт на JobId: " .. teleportTo)
            local teleportOk = teleportToJobId(teleportTo)
            if teleportOk then
                local successTeleport = waitForTeleport(teleportTo, TELEPORT_TIMEOUT)
                if not successTeleport then
                    warn("Телепорт не удался, повторяем цикл.")
                    task.wait(SEND_INVENTORY_INTERVAL)
                    continue
                end
            else
                warn("Не удалось выполнить телепорт, повторяем цикл.")
                task.wait(SEND_INVENTORY_INTERVAL)
                continue
            end
        end

        -- 4. LoadFruit + Respawn
        local loadSuccess = processLoadFruit(config.load_fruit_items or {})
        if loadSuccess then
            -- 5. Авто-трейд
            processAutoTrade(config.trade_items or {}, config.partner_name or "", config.load_fruit_items or {})
        else
            warn("Ошибка в процессе LoadFruit.")
        end
    else
        warn("Конфигурация не получена за 2 минуты.")
    end

    task.wait(SEND_INVENTORY_INTERVAL)  -- пауза перед новым циклом
end
