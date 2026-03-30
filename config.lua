-- ========== НАСТРОЙКИ ==========
local NGROK_URL = "https://lilliana-nonformalistic-gerda.ngrok-free.dev"
local WEBHOOK_ENDPOINT = NGROK_URL .. "/create_file"   -- важно: добавляем /create_file
-- ================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Множество для запоминания уже отправленных предметов
local sentItems = {}

-- ========== ОТПРАВКА НА СЕРВЕР ==========
local function sendToServer(itemName)
    -- Проверяем, не отправляли ли этот предмет уже
    if sentItems[itemName] then
        return
    end
    sentItems[itemName] = true

    local data = {
        username = player.Name .. " получил " .. itemName
    }
    local json = HttpService:JSONEncode(data)

    local success, err = pcall(function()
        HttpService:RequestAsync({
            Url = WEBHOOK_ENDPOINT,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)

    if success then
        print("[✓] Отправлено на сервер:", itemName)
    else
        warn("[✗] Ошибка отправки:", itemName, err)
    end
end

-- ========== ДЕТЕКТОР ФРУКТОВ ==========
local function checkItem(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        print("Найден фрукт:", item.Name)
        sendToServer(item.Name)
    end
end

local function startTracking()
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()

    -- Отслеживаем появление в инвентаре
    backpack.ChildAdded:Connect(function(item)
        task.wait(0.1)
        checkItem(item)
    end)

    -- Отслеживаем появление в руках (только инструменты)
    character.ChildAdded:Connect(function(item)
        if item:IsA("Tool") then
            task.wait(0.1)
            checkItem(item)
        end
    end)

    -- Запоминаем уже существующие предметы, чтобы не отправлять их повторно
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:find("Fruit") then
            sentItems[item.Name] = true
        end
    end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.Name:find("Fruit") then
            sentItems[item.Name] = true
        end
    end

    print("Детектор фруктов запущен для", player.Name)
end

-- ========== АВТОМАТИЧЕСКИЙ ВЫБОР КОМАНДЫ ==========
local function selectPirates()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")

    commF:InvokeServer("SetTeam", "Pirates")

    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then
        eventService:FireServer()
    end

    print("Команда Pirates выбрана")
end

-- ========== ЗАГРУЗКА ХАДА ==========
local function loadHud()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Huylovemy/Bearhudz/refs/heads/main/Bearhud.lua"))()
end

-- ========== АВТОРЕЛОГ ПРИ РОСТЕ БЕЛИ ==========
local function setupAutoRelog()
    local beli = player:WaitForChild("Data", 10):WaitForChild("Beli", 10)
    local timer = nil

    local function resetTimer()
        if timer then task.cancel(timer) end
        timer = task.spawn(function()
            task.wait(30)
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end

    beli:GetPropertyChangedSignal("Value"):Connect(resetTimer)
    resetTimer()
end

-- ========== ЗАПУСК ==========
-- Ждём появления персонажа, затем запускаем детектор
if player.Character then
    task.wait(2)
    startTracking()
else
    player.CharacterAdded:Connect(function()
        task.wait(2)
        startTracking()
    end)
end

-- Выполняем остальные действия
selectPirates()
loadHud()
setupAutoRelog()

print("Скрипт полностью загружен. Отслеживаю фрукты.")
