loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
-- ===== СКРИПТ ЗАХВАТА ЯЙЦА (РАБОТАЕТ ПАРАЛЛЕЛЬНО С БЛОКИРОВКОЙ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- Таблица рангов (укажите свои аккаунты)
local PLAYER_EGG_RANK = {
    ["Willow_hspt2015"] = 1,
    ["MichaelJohnson84562"] = 2,
    ["GigaGrimShade74"] = 3,
}
local myRank = PLAYER_EGG_RANK[playerName]

if not myRank then
    warn("[ЯЙЦО] Нет ранга для игрока", playerName)
    return
end

-- Функция поиска острова
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

-- Функция получения отсортированных яиц
local function getEggsSorted()
    local island = findIsland()
    if not island then return {} end
    local core = island:FindFirstChild("Core")
    if not core then return {} end
    local spawned = core:FindFirstChild("SpawnedDragonEggs")
    if not spawned then return {} end
    
    local char = player.Character
    if not char then return {} end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    
    local eggs = {}
    for _, child in ipairs(spawned:GetChildren()) do
        if child:IsA("Model") and child.Name == "DragonEgg" then
            local eggPart = child:FindFirstChild("EggCrust") or child:FindFirstChildWhichIsA("BasePart")
            if eggPart and eggPart.Parent then
                local dist = (hrp.Position - eggPart.Position).Magnitude
                table.insert(eggs, {part = eggPart, model = child, dist = dist})
            end
        end
    end
    table.sort(eggs, function(a, b) return a.dist < b.dist end)
    return eggs
end

-- Функция перемещения к яйцу через BodyPosition
local function moveToEgg(targetPos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    local oldPlatform = hum.PlatformStand
    hum.PlatformStand = true
    
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.Parent = hrp
    bp.Position = targetPos
    task.wait(3)  -- ждём 3 секунды
    bp:Destroy()
    
    hum.PlatformStand = oldPlatform
end

-- Функция зажатия E
local function pressE()
    local vim = game:GetService("VirtualInputManager")
    if not vim then
        warn("[ЯЙЦО] VirtualInputManager недоступен")
        return
    end
    vim:SendKeyEvent(true, "E", false, game)
    task.wait(1.5)
    vim:SendKeyEvent(false, "E", false, game)
    print("[ЯЙЦО] Клавиша E зажата")
end

-- Глобальный флаг блокировки (основной скрипт должен его проверять)
_G.blockMovement = false

-- Основной цикл
task.spawn(function()
    while true do
        task.wait(1)
        
        local island = findIsland()
        if not island then
            _G.blockMovement = false
            continue
        end
        
        local eggs = getEggsSorted()
        if #eggs >= myRank then
            local myEgg = eggs[myRank]
            if myEgg and myEgg.part and myEgg.part.Parent then
                print(string.format("[ЯЙЦО] Найдено яйцо ранга %d (дист. %.1f), начинаем захват", myRank, myEgg.dist))
                
                -- Блокируем основной скрипт
                _G.blockMovement = true
                
                -- Перемещаемся к яйцу
                local targetPos = myEgg.part.Position + Vector3.new(0, 2, 0)
                moveToEgg(targetPos)
                
                -- Поворачиваем персонажа лицом к яйцу
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp and myEgg.part.Parent then
                        local lookAt = (myEgg.part.Position - hrp.Position).Unit
                        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookAt)
                        task.wait(0.3)
                    end
                end
                
                -- Активируем яйцо
                if myEgg.model and myEgg.model.Parent then
                    pressE()
                    -- Ждём исчезновения яйца (до 4 секунд)
                    for _ = 1, 20 do
                        if not myEgg.model.Parent then break end
                        task.wait(0.2)
                    end
                    print("[ЯЙЦО] Захват яйца завершён")
                else
                    print("[ЯЙЦО] Яйцо исчезло до активации")
                end
                
                -- Снимаем блокировку
                _G.blockMovement = false
                
                -- Ждём некоторое время перед следующим поиском
                task.wait(5)
            end
        end
    end
end)

print("[ЯЙЦО] Скрипт захвата запущен. Ранг игрока:", myRank)
