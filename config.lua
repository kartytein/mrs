-- ========== НАСТРОЙКИ ==========
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"
-- ================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Множество для запоминания уже отправленных предметов
local sentItems = {}

-- ========== ПРОВЕРКА И ИСПОЛЬЗОВАНИЕ writefile ==========
local function saveToFile(username)
    if type(writefile) == "function" then
        local fileName = username .. ".txt"
        local content = "Yummytool"
        local success, err = pcall(function()
            writefile(fileName, content)
        end)
        if success then
            print("[✓] Файл сохранён:", fileName)
        else
            warn("[✗] Ошибка writefile:", err)
        end
    else
        warn("[✗] writefile недоступна. Файл не создан.")
    end
end

-- ========== ОТПРАВКА В DISCORD ==========
local function sendToDiscord(itemName)
    local message = {
        content = player.Name .. " получил '" .. itemName .. "'!",
        username = "Инвентарь"
    }
    local json = HttpService:JSONEncode(message)

    local success, err = pcall(function()
        HttpService:RequestAsync({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)

    if success then
        print("[✓] Discord отправлено:", itemName)
    else
        warn("[✗] Ошибка Discord:", err)
    end
end

-- ========== ДЕТЕКТОР ФРУКТОВ ==========
local function checkItem(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sentItems[item.Name] then return end
        sentItems[item.Name] = true

        print("Найден фрукт:", item.Name)

        -- Отправка в Discord
        sendToDiscord(item.Name)

        -- Сохранение файла через writefile (только ник)
        saveToFile(player.Name)
    end
end

local function startTracking()
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()

    backpack.ChildAdded:Connect(function(item)
        task.wait(0.1)
        checkItem(item)
    end)

    character.ChildAdded:Connect(function(item)
        if item:IsA("Tool") then
            task.wait(0.1)
            checkItem(item)
        end
    end)

    -- Запоминаем уже существующие предметы
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
if player.Character then
    task.wait(2)
    startTracking()
else
    player.CharacterAdded:Connect(function()
        task.wait(2)
        startTracking()
    end)
end

selectPirates()
loadHud()
setupAutoRelog()

print("Скрипт запущен. Отслеживаю фрукты. Файлы сохраняются в папку экзекутора.")
