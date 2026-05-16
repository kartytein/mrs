-- ===== ПОЛНЫЙ ФИНАЛЬНЫЙ СКРИПТ (РАБОЧАЯ ВЕРСИЯ С АКТИВАЦИЕЙ ЯЙЦА) =====
-- Версия 6.0
-- Все функции: лодка, магнит, остров (выбор яйца по рангу, зажатие E), возврат с движением

local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower then lower.CanCollide = false end
            if upper then upper.CanCollide = false end
        end
        task.wait(0.3)
    end
end)

-- ========== 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
local function moveStep(targetPos, speed, keepY)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    local oldPlatform = hum.PlatformStand
    hum.PlatformStand = true
    local step = 0.02
    local stepSize = speed * step
    while true do
        local current = hrp.Position
        local dx = targetPos.X - current.X
        local dz = targetPos.Z - current.Z
        local distXZ = math.sqrt(dx*dx + dz*dz)
        if distXZ < 0.5 then break end
        local dir = (targetPos - current).Unit
        local moveDist = math.min(stepSize, (targetPos - current).Magnitude)
        local newPos = current + dir * moveDist
        if keepY then newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z) end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = oldPlatform
    return true
end

local function moveWithBodyPosition(targetPos, duration)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.Parent = hrp
    bp.Position = targetPos
    task.wait(duration)
    bp:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
end

local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    if not rs then return end
    local remotes = rs:FindFirstChild("Remotes")
    if not remotes then return end
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
end

local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, b in ipairs(boats:GetChildren()) do
        if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
            if b:GetAttribute("Owner") == playerName then return b end
            local own = b:FindFirstChild("Owner")
            if own and tostring(own.Value) == playerName then return b end
        end
    end
    return nil
end

-- Детектор фруктов (Discord)
local sentFruits = {}
local function sendFruit(name)
    local msg = { content = player.Name .. " получил '" .. name .. "'!", username = "Инвентарь" }
    pcall(function()
        HttpService:RequestAsync({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(msg)
        })
    end)
    print("[DISCORD] Отправлено:", name)
end

local function checkFruit(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sentFruits[item.Name] then return end
        sentFruits[item.Name] = true
        sendFruit(item.Name)
    end
end

local function fruitTracker()
    local char = player.Character or player.CharacterAdded:Wait()
    local bp = player:WaitForChild("Backpack")
    bp.ChildAdded:Connect(function(it) task.wait(0.1); checkFruit(it) end)
    char.ChildAdded:Connect(function(it) if it:IsA("Tool") then task.wait(0.1); checkFruit(it) end end)
    for _, it in ipairs(bp:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sentFruits[it.Name] = true end end
    for _, it in ipairs(char:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sentFruits[it.Name] = true end end
    print("Детектор фруктов запущен")
end

-- Анти-idle (камера + клавиша W)
task.spawn(function()
    local cam = workspace.CurrentCamera
    local orig = cam.CFrame
    while true do
        task.wait(300)
        cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(1), 0)
        task.wait(0.5)
        cam.CFrame = orig
    end
end)
task.spawn(function()
    local vim = game:GetService("VirtualInputManager")
    if vim then
        while true do
            task.wait(600)
            pcall(function()
                vim:SendKeyEvent(true, "W", false, game)
                task.wait(0.1)
                vim:SendKeyEvent(false, "W", false, game)
            end)
        end
    end
end)

-- ========== 3. ДВИЖЕНИЕ ЛОДКИ (BodyVelocity на UpperTorso) ==========
local boat = nil
local seat = nil
local root = nil
local hum = nil
local hrp = nil
local bv = nil
local dir = -1
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100
local moving = false
local moveThread = nil
local islandModeActive = false      -- режим острова активен
local waitingForDespawn = false

local function ensureBV()
    if islandModeActive then return end
    local ch = player.Character
    if not ch then return end
    local upper = ch:FindFirstChild("UpperTorso")
    if not upper then return end
    local sx = dir * SPEED_X
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    end
end

local function stopMove()
    moving = false
    if moveThread then pcall(task.cancel, moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

local function startMove()
    if moving or islandModeActive then return end
    moving = true
    moveThread = task.spawn(function()
        local ch = player.Character
        if not ch then moving = false; return end
        local upper = ch:FindFirstChild("UpperTorso")
        if not upper then moving = false; return end
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(0, 0, 0)
        if root then
            local p = root.Position
            if math.abs(p.Y - TARGET_Y) > 0.5 then
                root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
            end
        end
        local sx = dir * SPEED_X
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
        while moving and not islandModeActive do
            if not (hum and hum.Sit and hum.SeatPart == seat) then
                stopMove()
                break
            end
            if root then
                local p = root.Position
                if math.abs(p.Y - TARGET_Y) > 0.5 then
                    root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
                end
                if p.X <= X_MIN and dir == -1 then
                    dir = 1
                    ensureBV()
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    ensureBV()
                end
            end
            if bv and bv.Parent then
                local v = bv.Velocity
                bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001)
            end
            task.wait(0.05)
        end
    end)
end

-- ========== 4. БЫСТРЫЙ МАГНИТ (ОТКЛЮЧАЕТСЯ ПРИ ОСТРОВЕ) ==========
local magnetBodyPos = nil
local magnetBodyPosActive = false

local function updateMagnetBodyPos(targetY)
    if not magnetBodyPosActive or islandModeActive then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not magnetBodyPos then
        magnetBodyPos = Instance.new("BodyPosition")
        magnetBodyPos.MaxForce = Vector3.new(0, math.huge, 0)
        magnetBodyPos.Parent = hrp
    end
    magnetBodyPos.Position = Vector3.new(hrp.Position.X, targetY, hrp.Position.Z)
end

local function stopMagnetBodyPos()
    magnetBodyPosActive = false
    if magnetBodyPos then magnetBodyPos:Destroy(); magnetBodyPos = nil end
end

local function fastMagnet()
    if islandModeActive then return end
    if not seat then return end
    local char = player.Character
    if not char then return end
    local h = char:FindFirstChild("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    if h.Sit and h.SeatPart == seat then
        stopMagnetBodyPos()
        return
    end
    if not magnetBodyPosActive then
        magnetBodyPosActive = true
    end
    local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
    updateMagnetBodyPos(targetPos.Y)
    local dist = (r.Position - targetPos).Magnitude
    if dist > 0.3 then
        local dirVec = (targetPos - r.Position).Unit
        local step = math.min(300 * 0.02, dist)
        local newPos = r.Position + dirVec * step
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        r.CFrame = CFrame.new(newPos)
    else
        r.CFrame = CFrame.new(targetPos)
    end
end

-- ========== 5. МОНИТОР ОСТРОВА (АКТИВАЦИЯ ЯЙЦА С ЗАЖАТИЕМ E) ==========
local pendingReturn = false

local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

-- Таблица рангов (уникальный номер для каждого аккаунта)
local PLAYER_EGG_RANK = {
    ["Willow_hspt2015"] = 1,
    ["MichaelJohnson84562"] = 2,
    ["GigaGrimShade74"] = 3,
}
local myRank = PLAYER_EGG_RANK[playerName]

-- Функция зажатия E
local function pressE()
    local vim = game:GetService("VirtualInputManager")
    if not vim then return end
    vim:SendKeyEvent(true, "E", false, game)
    task.wait(1.5)      -- Удерживаем 1.5 секунды
    vim:SendKeyEvent(false, "E", false, game)
    task.wait(0.3)
    print("[ЯЙЦО] Клавиша E зажата")
end

-- Получить яйца, отсортированные по расстоянию
local function getEggsSortedByDistance()
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
    table.sort(eggs, function(a,b) return a.dist < b.dist end)
    return eggs
end

task.spawn(function()
    while true do
        task.wait(1)
        local island = findIsland()
        local present = island ~= nil

        if waitingForDespawn and not present then
            waitingForDespawn = false
            print("[ОСТРОВ] Остров исчез, готов к новой активации")
        end

        if present and not islandModeActive and not waitingForDespawn then
            print("[ОСТРОВ] Обнаружен, входим в режим")
            islandModeActive = true
            
            -- Останавливаем лодку и магнит
            stopMove()
            stopMagnetBodyPos()
            
            -- Выходим из сиденья
            local char = player.Character
            if char then
                local h = char:FindFirstChild("Humanoid")
                if h and h.Sit then h.Sit = false end
            end
            
            -- Поднимаемся над островом
            local target = island:GetPivot().Position + Vector3.new(0, 330, 0)
            moveStep(target, 200, true)
            
            -- Ожидание яиц (до 10 минут) и выбор по рангу
            local eggTargetPos = nil
            local myEggModel = nil
            local startTime = os.clock()
            
            while islandModeActive do
                if os.clock() - startTime >= 600 then
                    print("[ОСТРОВ] 10 минут истекло, яйца не появились")
                    break
                end
                if not findIsland() then
                    print("[ОСТРОВ] Остров исчез во время ожидания")
                    break
                end
                local eggsSorted = getEggsSortedByDistance()
                if #eggsSorted >= myRank and myRank then
                    local candidate = eggsSorted[myRank]
                    if candidate and candidate.part and candidate.part.Parent then
                        myEggModel = candidate.model
                        eggTargetPos = candidate.part.Position + Vector3.new(0, 2, 0)
                        print(string.format("[ОСТРОВ] Выбрано яйцо ранга %d (расст. %.1f)", myRank, candidate.dist))
                        break
                    end
                end
                task.wait(0.5)
            end
            
            -- Перемещение к яйцу и активация
            if eggTargetPos and myEggModel and myEggModel.Parent then
                print("[ОСТРОВ] Перемещение к яйцу")
                moveWithBodyPosition(eggTargetPos, 3)
                
                -- Поворачиваем персонажа лицом к яйцу
                local char = player.Character
                if char and myEggModel.Parent then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local eggPart = myEggModel:FindFirstChild("EggCrust") or myEggModel:FindFirstChildWhichIsA("BasePart")
                    if hrp and eggPart then
                        local lookAt = (eggPart.Position - hrp.Position).Unit
                        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookAt)
                        task.wait(0.3)
                    end
                end
                
                if not myEggModel.Parent then
                    print("[ОСТРОВ] Яйцо исчезло до активации")
                else
                    pressE()
                    -- Ждём исчезновения яйца
                    for _ = 1, 20 do
                        if not myEggModel.Parent then break end
                        task.wait(0.2)
                    end
                    print("[ОСТРОВ] Активация яйца завершена")
                end
            elseif not myRank then
                print("[ОСТРОВ] Нет ранга для игрока", playerName)
            else
                print("[ОСТРОВ] Не найдено яйцо для ранга", myRank)
            end
            
            islandModeActive = false
            waitingForDespawn = true
            pendingReturn = true
            print("[ОСТРОВ] Режим завершён, ждём исчезновения острова")
        end
    end
end)

-- ========== 6. ОСНОВНОЙ ЦИКЛ (ВОЗВРАТ В ЛОДКУ С ЗАПУСКОМ ДВИЖЕНИЯ) ==========
-- Выбор команды Marines (если нужно)
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
    local mods = rs:FindFirstChild("Modules")
    local ev = mods and mods:FindFirstChild("RE/OnEventServiceActivity")
    if ev then pcall(function() ev:FireServer() end) end
end

task.spawn(function()
    while true do
        task.wait(0.05)
        if islandModeActive then continue end
        
        -- Возврат после острова
        if pendingReturn then
            pendingReturn = false
            print("[ГЛАВНЫЙ] Возврат с острова, поиск лодки и посадка")
            boat = nil; seat = nil; root = nil
            boat = findMyBoat()
            if boat then
                seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if seat and root then
                    for _, p in ipairs(boat:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                    local nat = boat:FindFirstChild("Script")
                    if nat then nat.Disabled = true end
                    local char = player.Character
                    if char then
                        local h = char:FindFirstChild("Humanoid")
                        local r = char:FindFirstChild("HumanoidRootPart")
                        if h and r then
                            local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
                            moveStep(targetPos, 300, true)
                            h.Sit = true
                            task.wait(0.5)      -- Фиксация на сиденье
                            -- Обновляем ссылки (лодка могла пересоздаться)
                            boat = findMyBoat()
                            if boat then
                                seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                                root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                            end
                            -- Полностью останавливаем и запускаем движение заново
                            stopMove()
                            moving = false
                            if bv then bv:Destroy() bv = nil end
                            startMove()
                            print("[ГЛАВНЫЙ] Посадка после острова выполнена, движение запущено")
                        end
                    end
                else
                    print("[ГЛАВНЫЙ] Лодка найдена, но нет сиденья/части")
                end
            else
                print("[ГЛАВНЫЙ] Лодка не найдена, будет куплена позже")
            end
        end
        
        -- Обычный цикл: поиск/покупка лодки, управление движением и магнитом
        if not boat or not boat.Parent then
            boat = findMyBoat()
            if not boat then
                buyBoat()
                for i = 1, 20 do
                    boat = findMyBoat()
                    if boat then break end
                    task.wait(0.5)
                end
                if not boat then
                    task.wait(5)
                    continue
                end
            end
            seat = boat:FindFirstChildWhichIsA("VehicleSeat")
            root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            if not seat or not root then
                boat = nil
                continue
            end
            for _, p in ipairs(boat:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            local nat = boat:FindFirstChild("Script")
            if nat then nat.Disabled = true end
            print("[ГЛАВНЫЙ] Лодка найдена: " .. boat.Name)
        end
        
        local char = player.Character
        if char then
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        end
        
        if hum and hum.Sit and hum.SeatPart == seat then
            if not moving then startMove() end
        else
            if moving then stopMove() end
            fastMagnet()
        end
    end
end)

-- Первичная посадка (один раз при старте)
task.spawn(function()
    while true do
        task.wait(0.5)
        if islandModeActive then continue end
        if boat and seat and hum and not (hum.Sit and hum.SeatPart == seat) then
            local target = seat.Position + Vector3.new(0, 2.5, 0)
            moveStep(target, 300, true)
            hum.Sit = true
            print("[ПЕРВИЧНАЯ ПОСАДКА] Выполнена")
        end
        break
    end
end)

-- Запуск детектора фруктов
task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)
    fruitTracker()
end)

print("Скрипт полностью запущен. Остров обрабатывается с активацией яйца (зажатие E).")
