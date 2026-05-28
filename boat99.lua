-- ===== ПОЛНЫЙ СКРИПТ (ВЕРСИЯ 8.3) =====
-- Исправлено: активация яиц на высоте 4.5 над яйцом, принудительная фиксация CFrame, без проваливания под карту.
-- Активируются ВСЕ яйца на острове (по очереди, ближайшее первым).
-- Остальные механики: лодка, магнит, покупка с перемещением, ресет, пересадка, фрукты (Discord+StoreFruit), анти-idle.

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
local BOAT_BUY_POS = Vector3.new(-16917.0, 9.1, 447.0)

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

local function forceSitOnSeat(targetSeat, maxAttempts)
    maxAttempts = maxAttempts or 3
    for attempt = 1, maxAttempts do
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return false end
        local targetPos = targetSeat.Position + Vector3.new(0, 2.5, 0)
        moveStep(targetPos, 300, true)
        hum.Sit = true
        task.wait(0.5)
        if hum.Sit and hum.SeatPart == targetSeat then
            print("[ПОСАДКА] Успешно сел на целевое сиденье")
            return true
        else
            print("[ПОСАДКА] Попытка " .. attempt .. ": сел не на то сиденье, выпрыгиваем")
            hum.Sit = false
            local jump = hum:FindFirstChild("Jump")
            if jump then pcall(function() jump:Fire() end) end
            task.wait(0.5)
        end
    end
    warn("[ПОСАДКА] Не удалось сесть на целевое сиденье")
    return false
end

local function moveToBuyPoint()
    return moveStep(BOAT_BUY_POS, 200, true)
end

local function buyBoatOnly()
    local args = { "BuyBoat", "Guardian" }
    local rs = game:GetService("ReplicatedStorage")
    local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
    if commF then
        pcall(function() commF:InvokeServer(unpack(args)) end)
        print("[ПОКУПКА] Лодка заказана")
    else
        warn("[ПОКУПКА] CommF_ не найден")
    end
end

local function buyBoatAfterMove()
    if moveToBuyPoint() then
        task.wait(0.5)
        buyBoatOnly()
        return true
    else
        warn("[ПОКУПКА] Не удалось достичь точки")
        return false
    end
end

local function resetCharacter()
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 else char:BreakJoints() end
    end
    player.CharacterAdded:Wait()
    task.wait(1)
    print("[РЕСЕТ] Персонаж возрождён")
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

-- ========== 3. ДВИЖЕНИЕ ЛОДКИ ==========
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
local islandModeActive = false
local waitingForDespawn = false
local isReseating = false
local isBuying = false

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

-- ========== 4. МАГНИТ ==========
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

-- ========== 5. ОСТРОВ (АКТИВАЦИЯ ВСЕХ ЯИЦ, БЕЗ ПРОВАЛИВАНИЯ) ==========
local pendingReturn = false

local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function pressE()
    local vim = game:GetService("VirtualInputManager")
    if not vim then return end
    vim:SendKeyEvent(true, "E", false, game)
    task.wait(1.5)
    vim:SendKeyEvent(false, "E", false, game)
    task.wait(0.3)
    print("[ЯЙЦО] Клавиша E зажата")
end

-- Получить список всех яиц (без сортировки)
local function getAllEggs()
    local island = findIsland()
    if not island then return {} end
    local core = island:FindFirstChild("Core")
    if not core then return {} end
    local spawned = core:FindFirstChild("SpawnedDragonEggs")
    if not spawned then return {} end
    local eggs = {}
    for _, child in ipairs(spawned:GetChildren()) do
        if child:IsA("Model") and child.Name == "DragonEgg" then
            local eggPart = child:FindFirstChild("EggCrust") or child:FindFirstChildWhichIsA("BasePart")
            if eggPart and eggPart.Parent then
                table.insert(eggs, {part = eggPart, model = child})
            end
        end
    end
    return eggs
end

-- Активировать конкретное яйцо (исправленная версия, без проваливания)
local function activateEgg(eggModel)
    if not eggModel or not eggModel.Parent then return false end
    local eggPart = eggModel:FindFirstChild("EggCrust") or eggModel:FindFirstChildWhichIsA("BasePart")
    if not eggPart then return false end
    
    -- Высокая точка над яйцом (4.5 юнитов)
    local targetPos = eggPart.Position + Vector3.new(0, 4.5, 0)
    print("[ЯЙЦО] Перемещение к яйцу на высоту", targetPos.Y)
    
    -- Используем moveStep (плавное перемещение с фиксацией Y)
    moveStep(targetPos, 500, true)
    
    -- Принудительная фиксация положения (подстраховка)
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and math.abs(hrp.Position.Y - targetPos.Y) > 0.5 then
            hrp.CFrame = CFrame.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
            print("[ЯЙЦО] Фиксация высоты:", hrp.Position.Y)
        end
        -- Поворот к яйцу
        if hrp then
            local lookAt = (eggPart.Position - hrp.Position).Unit
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookAt)
        end
    end
    task.wait(0.3)
    
    -- Бесконечные попытки нажатия E, пока яйцо не исчезнет
    while eggModel and eggModel.Parent do
        pressE()
        task.wait(1)
    end
    return true
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
            
            -- Ожидание появления яиц (до 10 минут)
            local startTime = os.clock()
            local eggsList = {}
            print("[ОСТРОВ] Ожидание появления яиц...")
            while os.clock() - startTime < 600 do
                eggsList = getAllEggs()
                if #eggsList > 0 then break end
                task.wait(1)
            end
            
            if #eggsList == 0 then
                print("[ОСТРОВ] Яйца не появились за 10 минут, выход")
                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
            else
                print("[ОСТРОВ] Найдено яиц:", #eggsList)
                -- Активируем ВСЕ яйца, пока они не исчезнут
                local activatedCount = 0
                while #getAllEggs() > 0 do
                    local currentEggs = getAllEggs()
                    if #currentEggs == 0 then break end
                    -- Сортируем по расстоянию (ближайшее первым)
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local hrp = char.HumanoidRootPart
                        for _, egg in ipairs(currentEggs) do
                            if egg.part then
                                egg.dist = (hrp.Position - egg.part.Position).Magnitude
                            else
                                egg.dist = math.huge
                            end
                        end
                        table.sort(currentEggs, function(a,b) return a.dist < b.dist end)
                    end
                    local eggToActivate = currentEggs[1]
                    if eggToActivate and eggToActivate.model and eggToActivate.model.Parent then
                        print("[ОСТРОВ] Активация яйца", activatedCount+1)
                        activateEgg(eggToActivate.model)
                        activatedCount = activatedCount + 1
                        task.wait(1)
                    else
                        break
                    end
                end
                print("[ОСТРОВ] Все яйца активированы. Всего активировано:", activatedCount)
            end
            
            islandModeActive = false
            waitingForDespawn = true
            pendingReturn = true
            print("[ОСТРОВ] Режим завершён, ждём исчезновения острова")
        end
    end
end)

-- ========== 6. ОСНОВНОЙ ЦИКЛ (ЛОДКА) ==========
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
end

local function initialSetup()
    if isBuying then return end
    isBuying = true
    print("[ИНИЦИАЛИЗАЦИЯ] Начинаем процедуру покупки лодки...")
    if buyBoatAfterMove() then
        for i = 1, 30 do
            boat = findMyBoat()
            if boat then break end
            task.wait(1)
        end
        if boat then
            seat = boat:FindFirstChildWhichIsA("VehicleSeat")
            root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            if seat and root then
                for _, p in ipairs(boat:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
                local nat = boat:FindFirstChild("Script")
                if nat then nat.Disabled = true end
                forceSitOnSeat(seat, 3)
                startMove()
                print("[ИНИЦИАЛИЗАЦИЯ] Лодка готова, движение запущено")
            end
        else
            warn("[ИНИЦИАЛИЗАЦИЯ] Лодка не появилась")
        end
    end
    isBuying = false
end

task.spawn(function()
    task.wait(1)
    initialSetup()
end)

task.spawn(function()
    while true do
        task.wait(0.05)
        if islandModeActive then continue end

        if pendingReturn then
            pendingReturn = false
            print("[ГЛАВНЫЙ] Возврат с острова")
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
                        if h and forceSitOnSeat(seat, 3) then
                            stopMove()
                            moving = false
                            if bv then bv:Destroy() bv = nil end
                            startMove()
                            print("[ГЛАВНЫЙ] Посадка после острова выполнена")
                        end
                    end
                end
            else
                print("[ГЛАВНЫЙ] Лодка не найдена после острова")
            end
        end

        if boat and not boat.Parent then
            print("[ГЛАВНЫЙ] Лодка исчезла, выполняем ресет")
            boat = nil; seat = nil; root = nil
            stopMove()
            stopMagnetBodyPos()
            resetCharacter()
            if not isBuying then
                task.spawn(function()
                    isBuying = true
                    if buyBoatAfterMove() then
                        for i = 1, 30 do
                            boat = findMyBoat()
                            if boat then break end
                            task.wait(1)
                        end
                        if boat then
                            seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                            root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                            if seat and root then
                                for _, p in ipairs(boat:GetDescendants()) do
                                    if p:IsA("BasePart") then p.CanCollide = false end
                                end
                                local nat = boat:FindFirstChild("Script")
                                if nat then nat.Disabled = true end
                                forceSitOnSeat(seat, 3)
                                startMove()
                                print("[ГЛАВНЫЙ] Лодка восстановлена после ресета")
                            end
                        end
                    end
                    isBuying = false
                end)
            end
        end

        if (not boat or not boat.Parent) and not isBuying then
            task.spawn(function()
                isBuying = true
                if buyBoatAfterMove() then
                    for i = 1, 30 do
                        boat = findMyBoat()
                        if boat then break end
                        task.wait(1)
                    end
                    if boat then
                        seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                        root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                        if seat and root then
                            for _, p in ipairs(boat:GetDescendants()) do
                                if p:IsA("BasePart") then p.CanCollide = false end
                            end
                            local nat = boat:FindFirstChild("Script")
                            if nat then nat.Disabled = true end
                            forceSitOnSeat(seat, 3)
                            startMove()
                            print("[ГЛАВНЫЙ] Лодка найдена и посажены")
                        end
                    end
                end
                isBuying = false
            end)
        end

        local char = player.Character
        if char then
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        end

        if hum and hum.Sit then
            if hum.SeatPart == seat then
                if not moving and not islandModeActive then
                    startMove()
                end
            else
                if not isReseating then
                    isReseating = true
                    if seat then forceSitOnSeat(seat, 3) end
                    isReseating = false
                end
                if moving then stopMove() end
            end
        else
            if moving then stopMove() end
            fastMagnet()
        end
    end
end)

-- ========== 7. ФРУКТЫ (DISCORD + StoreFruit) ==========
local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
local processedFruits = {}

local function sendDiscordFruit(name)
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

local function sellFruit(tool)
    local fullName = tool.Name
    if processedFruits[fullName] then return end
    processedFruits[fullName] = true

    print("[ФРУКТ] Найден:", fullName)
    sendDiscordFruit(fullName)

    local storeName = fullName:gsub(" Fruit", ""):gsub(" ", "-")
    print("[ФРУКТ] Сдаём как:", storeName)

    task.wait(3)
    if tool.Parent ~= player.Character then
        tool.Parent = player.Character
        task.wait(3)
    end

    if tool.Parent ~= player.Character then
        warn("[ФРУКТ] Не удалось экипировать", fullName)
        processedFruits[fullName] = nil
        return
    end

    local args = { "StoreFruit", storeName, tool }
    local success, err = pcall(function()
        commF:InvokeServer(unpack(args))
    end)
    if success then
        print("[ФРУКТ] Сдан успешно:", storeName)
    else
        warn("[ФРУКТ] Ошибка сдачи:", err)
        processedFruits[fullName] = nil
    end
end

local function onToolAdded(tool)
    if tool:IsA("Tool") and tool.Name:find("Fruit") then
        task.wait(3)
        sellFruit(tool)
    end
end

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(onToolAdded)

local function onCharAdded(char)
    char.ChildAdded:Connect(onToolAdded)
end
if player.Character then
    onCharAdded(player.Character)
end
player.CharacterAdded:Connect(onCharAdded)

task.wait(3)
for _, tool in ipairs(backpack:GetChildren()) do
    if tool:IsA("Tool") and tool.Name:find("Fruit") then
        sellFruit(tool)
        break
    end
end
if player.Character then
    for _, tool in ipairs(player.Character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:find("Fruit") then
            sellFruit(tool)
            break
        end
    end
end

print("[ФРУКТ] Монитор запущен")

-- ========== 8. АНТИ-IDLE ==========
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

print("Скрипт версии 8.3 запущен. Активация яиц на высоте 4.5, принудительная фиксация позиции.")
