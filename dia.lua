-- ============================================================
-- ОБЪЕДИНЁННЫЙ СКРИПТ: LoadFruit + Respawn + AutoTrade
-- Конфигурация получается с Python-сервера каждые 10 секунд
-- load_fruit_items используется и для LoadFruit, и для проверки второго контейнера
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ====================== НАСТРОЙКИ ЗАПРОСОВ ======================
local SERVER_URL = "http://192.168.31.179:8000/get_config"
local POLL_INTERVAL = 10

-- ====================== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ КОНФИГУРАЦИИ ======================
local loadFruitItems = {}   -- список для LoadFruit и проверки второго контейнера
local tradeItems = {}       -- предметы для первого контейнера
local tradePartnerName = "" -- ожидаемый партнёр

-- ====================== ФУНКЦИИ ДЛЯ ЗАПРОСА К СЕРВЕРУ ======================
local function fetchConfig()
    local url = SERVER_URL .. "?nickname=" .. HttpService:UrlEncode(player.Name)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "GET"
        })
    end)

    if not success then
        warn("Ошибка запроса конфигурации:", response)
        return nil
    end

    if response.StatusCode ~= 200 then
        warn("Сервер вернул код:", response.StatusCode, response.Body)
        return nil
    end

    local data = HttpService:JSONDecode(response.Body)
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
        task.wait(1)
    end
    return true
end

-- ====================== ФУНКЦИИ ДЛЯ АВТО-ТРЕЙДА ======================
-- (пути и параметры, как в исходном скрипте)
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

local function fireSequence(btn)
    -- (реализация как ранее, без изменений)
end

local function findObjectByPath(root, path)
    -- (реализация как ранее)
end

local function findParentButton(obj)
    -- (реализация как ранее)
end

local function findTextElementInContainer(container, search)
    -- (реализация как ранее)
end

local function findResultElement(search)
    -- (реализация как ранее)
end

local function waitForObject(path, timeout)
    -- (реализация как ранее)
end

local function waitForTradeTableSeat()
    -- (реализация как ранее)
end

local function getPartnerName(tradeTable, mySeat)
    -- (реализация как ранее)
end

local function doJump()
    -- (реализация как ранее)
end

local function getPercent()
    -- (реализация как ранее)
end

local function checkSecondContainer()
    local secondContainer = findObjectByPath(playerGui, secondContainerPath)
    if not secondContainer then
        return false
    end
    -- Используем loadFruitItems для проверки второго контейнера
    for _, item in ipairs(loadFruitItems) do
        if not findTextElementInContainer(secondContainer, item) then
            return false
        end
    end
    return true
end

local function isTradeCompleted()
    -- (реализация как ранее)
end

local function processItem(searchText)
    -- (реализация как ранее)
end

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

local function waitForPreAcceptConditions()
    -- (реализация как ранее)
end

local function acceptAndWaitForCompletion()
    -- (реализация как ранее)
end

local function processAutoTrade()
    if #tradeItems == 0 then
        print("Список предметов для трейда пуст, пропускаем.")
        return
    end

    print("Запуск авто-трейда...")
    while true do
        local tradeTable, mySeat = waitForTradeTableSeat()
        print("Сижу за TradeTable.")

        local partnerName = nil
        while partnerName == nil do
            partnerName = getPartnerName(tradeTable, mySeat)
            if partnerName == nil then
                print("Второе сиденье пусто, жду партнёра...")
                task.wait(1)
            end
        end
        print("Партнёр найден: " .. partnerName)

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

        local tradeDone = acceptAndWaitForCompletion()
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

-- ====================== ОСНОВНОЙ ЦИКЛ ОПРОСА СЕРВЕРА ======================
print("Скрипт запущен. Ожидание конфигурации с сервера...")

while true do
    local config = fetchConfig()
    if config then
        local success = processLoadFruit()
        if success then
            processAutoTrade()
        else
            warn("Ошибка в процессе LoadFruit, пропускаем авто-трейд.")
        end
        -- для однократного выполнения раскомментируйте break
        -- break
    else
        print("Конфигурация не получена, повтор через " .. POLL_INTERVAL .. " секунд.")
    end
    task.wait(POLL_INTERVAL)
end
