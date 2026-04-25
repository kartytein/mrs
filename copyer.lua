-- ========== ДЕТЕКТОР ФРУКТОВ (DISCORD) ==========
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"
local sentItems = {}

local function sendToDiscord(itemName)
    local message = {
        content = player.Name .. " получил '" .. itemName .. "'!",
        username = "Инвентарь"
    }
    local json = HttpService:JSONEncode(message)
    pcall(function()
        HttpService:RequestAsync({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
    print("[DISCORD] Отправлено:", itemName)
end

local function checkItem(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sentItems[item.Name] then return end
        sentItems[item.Name] = true
        sendToDiscord(item.Name)
    end
end

local function startFruitTracker()
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
    -- Уже существующие предметы
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
    print("Детектор фруктов запущен.")
end

-- Запуск трекера (после того как персонаж загрузился)
if player.Character then
    task.wait(2)
    startFruitTracker()
else
    player.CharacterAdded:Connect(function()
        task.wait(2)
        startFruitTracker()
    end)
end
