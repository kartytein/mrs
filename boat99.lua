-- ===== ПОЛНЫЙ СКРИПТ (ВЕРСИЯ 9.7-DEBUG) =====
-- Добавлена диагностика: каждый шаг логируется в консоль.
-- Ищите сообщения [DEBUG], [ERROR], [STATE] – они покажут, где скрипт застревает.

local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- ========== 0. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
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

-- ========== 1. ОЧИСТКА ФИЗИКИ ==========
local function clearCharacterPhysics()
    local char = player.Character
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyPosition") or v:IsA("BodyGyro") then
            v:Destroy()
        end
    end
end

-- ========== 2. ДВИЖОК ПЕРЕМЕЩЕНИЯ (с логом) ==========
local function goTo(targetPos, noStuckDetection)
    local STEP = 10
    local DELAY = 0.02
    clearCharacterPhysics()
    local char = player.Character
    if not char then
        warn("[DEBUG] goTo: нет персонажа")
        return false
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then
        warn("[DEBUG] goTo: нет HRP или Humanoid")
        return false
    end

    print(string.format("[DEBUG] goTo старт: (%.0f, %.0f, %.0f) -> (%.0f, %.0f, %.0f), noStuck=%s",
        hrp.Position.X, hrp.Position.Y, hrp.Position.Z,
        targetPos.X, targetPos.Y, targetPos.Z,
        tostring(noStuckDetection)))

    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp

    local lastDist = (hrp.Position - targetPos).Magnitude
    local stuckTimer = 0
    local steps = 0

    while true do
        local currentPos = hrp.Position
        local dist = (currentPos - targetPos).Magnitude
        if dist < 1 then break end

        local dir = (targetPos - currentPos).Unit
        local moveDist = math.min(STEP, dist)
        local newPos = currentPos + dir * moveDist
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)

        hrp.CFrame = CFrame.new(newPos)
        steps = steps + 1

        if not noStuckDetection then
            if dist >= lastDist - 0.1 then
                stuckTimer = stuckTimer + DELAY
                if stuckTimer >= 3 then
                    warn(string.format("[DEBUG] goTo: зависание! Рывок вверх. Шаг %d, dist=%.0f", steps, dist))
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                    stuckTimer = 0
                end
            else
                stuckTimer = 0
                lastDist = dist
            end
        end

        task.wait(DELAY)
    end

    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = false
    if bv then bv:Destroy() end
    print(string.format("[DEBUG] goTo финиш: шагов=%d, конечная позиция (%.0f, %.0f, %.0f)", steps, hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
    return true
end

local function safeGoTo(targetPos, noStuck)
    for attempt = 1, 10 do
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            warn("[DEBUG] safeGoTo: персонаж не готов, ожидание 1с")
            task.wait(1)
            continue
        end
        local success = pcall(goTo, targetPos, noStuck)
        if success then
            return true
        end
        warn("[DEBUG] safeGoTo: попытка " .. attempt .. " провалена, ожидание 2с")
        task.wait(2)
    end
    warn("[DEBUG] safeGoTo: не удалось достичь цели после 10 попыток")
    return false
end

-- ========== 3. СТАРЫЙ moveStep (посадка в лодку) ==========
local function moveStep(targetPos, speed, keepY)
    clearCharacterPhysics()
    local char = player.Character
    if not char then
        warn("[DEBUG] moveStep: нет персонажа")
        return false
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then
        warn("[DEBUG] moveStep: нет HRP или Humanoid")
        return false
    end
    print(string.format("[DEBUG] moveStep старт: к (%.0f, %.0f, %.0f)", targetPos.X, targetPos.Y, targetPos.Z))
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
    print("[DEBUG] moveStep финиш")
    return true
end

-- ========== 4. ПОКУПКА ЛОДКИ ==========
local BOAT_BUY_POS = Vector3.new(-16917.0, 9.1, 447.0)
local BUY_DISTANCE_THRESHOLD = 5

local function buyBoatOnly()
    local args = { "BuyBoat", "Guardian" }
    local rs = game:GetService("ReplicatedStorage")
    local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
    if commF then
        pcall(function() commF:InvokeServer(unpack(args)) end)
        print("[DEBUG] Покупка лодки: вызов отправлен")
    else
        warn("[DEBUG] CommF_ не найден")
    end
end

local function buyBoatAfterMove()
    print("[DEBUG] buyBoatAfterMove: начинаем перемещение к точке покупки")
    for attempt = 1, 3 do
        safeGoTo(BOAT_BUY_POS, true)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local dist = hrp and (hrp.Position - BOAT_BUY_POS).Magnitude or -1
        print(string.format("[DEBUG] buyBoatAfterMove: попытка %d, расстояние до точки: %.1f", attempt, dist))
        if hrp and dist <= BUY_DISTANCE_THRESHOLD then
            task.wait(0.5)
            buyBoatOnly()
            return true
        end
    end
    warn("[DEBUG] Не удалось добраться до точки покупки, лодка не куплена")
    return false
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
        print(string.format("[DEBUG] forceSitOnSeat: попытка %d, цель (%.0f, %.0f, %.0f)", attempt, targetPos.X, targetPos.Y, targetPos.Z))
        moveStep(targetPos, 300, true)
        hum.Sit = true
        task.wait(0.5)
        if hum.Sit and hum.SeatPart == targetSeat then
            print("[DEBUG] forceSitOnSeat: успешно сел")
            return true
        else
            print("[DEBUG] forceSitOnSeat: сел не на то сиденье, выпрыгиваем")
            hum.Sit = false
            local jump = hum:FindFirstChild("Jump")
            if jump then pcall(function() jump:Fire() end) end
            task.wait(0.5)
        end
    end
    warn("[DEBUG] forceSitOnSeat: не удалось сесть после всех попыток")
    return false
end

local function resetCharacter()
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 else char:BreakJoints() end
    end
    player.CharacterAdded:Wait()
    task.wait(1)
    print("[DEBUG] Персонаж возрождён")
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

-- ========== 5. ДВИЖЕНИЕ ЛОДКИ ==========
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
local isReseating = false

local function ensureBV()
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
    print("[DEBUG] Движение лодки остановлено")
end

local function startMove()
    if moving then return end
    moving = true
    print("[DEBUG] Запуск движения лодки")
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
        while moving do
            if not (hum and hum.Sit and hum.SeatPart == seat) then
                print("[DEBUG] Лодка: персонаж не сидит на нужном сиденье, остановка")
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

-- ========== 6. МАГНИТ ==========
local magnetBodyPos = nil
local magnetBodyPosActive = false

local function updateMagnetBodyPos(targetY)
    if not magnetBodyPosActive then return end
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

-- ========== 7. ОСТРОВ ==========
local islandModeActive = false
local waitingForDespawn = false
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
end

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

local function activateEgg(eggModel)
    if not eggModel or not eggModel.Parent then return false end
    local eggPart = eggModel:FindFirstChild("EggCrust") or eggModel:FindFirstChildWhichIsA("BasePart")
    if not eggPart then return false end

    local targetPos = eggPart.Position + Vector3.new(0, 4.5, 0)
    print(string.format("[DEBUG] Активация яйца: летим к (%.0f, %.0f, %.0f)", targetPos.X, targetPos.Y, targetPos.Z))
    safeGoTo(targetPos, false)

    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
            local lookAt = (eggPart.Position - hrp.Position).Unit
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookAt)
        end
    end
    task.wait(0.3)

    while eggModel and eggModel.Parent do
        pressE()
        task.wait(1)
    end
    print("[DEBUG] Яйцо активировано (исчезло)")
    return true
end

-- Основной поток острова с диагностикой
task.spawn(function()
    while true do
        task.wait(1)
        local island = findIsland()
        local present = island ~= nil
        -- Выводим состояние флагов при каждом цикле
        print(string.format("[STATE] Остров: present=%s, islandModeActive=%s, waitingForDespawn=%s, pendingReturn=%s, boat=%s, moving=%s",
            tostring(present), tostring(islandModeActive), tostring(waitingForDespawn), tostring(pendingReturn),
            boat and "есть" or "нет", tostring(moving)))

        if waitingForDespawn and not present then
            waitingForDespawn = false
            print("[DEBUG] Остров исчез, сброс waitingForDespawn")
        end

        if present and not islandModeActive and not waitingForDespawn then
            print("[DEBUG] Обнаружен новый остров, активируем islandMode")
            islandModeActive = true

            stopMove()
            stopMagnetBodyPos()

            local char = player.Character
            if char then
                local h = char:FindFirstChild("Humanoid")
                if h and h.Sit then
                    h.Sit = false
                    print("[DEBUG] Вышли из сиденья лодки")
                end
                if h then h.PlatformStand = true end
            end

            local target = island:GetPivot().Position + Vector3.new(0, 330, 0)
            print(string.format("[DEBUG] Летим к острову: (%.0f, %.0f, %.0f)", target.X, target.Y, target.Z))
            safeGoTo(target, true)

            local startTime = os.clock()
            local eggsList = {}
            print("[DEBUG] Ожидание яиц (до 10 минут)")
            while os.clock() - startTime < 600 do
                eggsList = getAllEggs()
                if #eggsList > 0 then break end
                task.wait(1)
            end

            if #eggsList == 0 then
                print("[DEBUG] Яйца не появились, выходим с острова")
                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
            else
                print("[DEBUG] Найдено яиц: " .. #eggsList .. ", начинаем активацию")
                local activatedCount = 0
                while #getAllEggs() > 0 do
                    local currentEggs = getAllEggs()
                    if #currentEggs == 0 then break end
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
                        print(string.format("[DEBUG] Активация яйца #%d", activatedCount+1))
                        activateEgg(eggToActivate.model)
                        activatedCount = activatedCount + 1
                        task.wait(1)
                    else
                        break
                    end
                end
                print("[DEBUG] Все яйца активированы, выходим")
                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
            end

            local char2 = player.Character
            if char2 then
                local h2 = char2:FindFirstChild("Humanoid")
                if h2 then h2.PlatformStand = false end
            end
            print("[DEBUG] Завершение обработки острова")
        end
    end
end)

-- ========== 8. ОСНОВНОЙ ЦИКЛ ==========
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
end

local isBuying = false

local function initialSetup()
    if isBuying then return end
    isBuying = true
    print("[DEBUG] Инициализация: покупка лодки и посадка")
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
                print("[DEBUG] Инициализация завершена")
            end
        else
            warn("[DEBUG] Лодка не появилась")
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

        -- Возврат с острова
        if pendingReturn then
            pendingReturn = false
            print("[DEBUG] Возврат с острова: ищем лодку")
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
                            if bv then bv:Destroy() bv = nil end
                            startMove()
                            print("[DEBUG] Возврат: сели в лодку и поехали")
                        else
                            print("[DEBUG] Возврат: не удалось сесть")
                        end
                    end
                end
            else
                print("[DEBUG] Лодка не найдена при возврате")
            end
        end

        -- Проверка пропажи лодки
        if boat and not boat.Parent then
            print("[DEBUG] Лодка исчезла, ресет")
            boat = nil; seat = nil; root = nil
            stopMove()
            stopMagnetBodyPos()
            resetCharacter()
            if not isBuying then
                task.spawn(function()
                    isBuying = true
                    print("[DEBUG] Пересоздание лодки после пропажи")
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
                            end
                        end
                    end
                    isBuying = false
                end)
            end
        end

        -- Если лодки нет и не в процессе покупки
        if (not boat or not boat.Parent) and not isBuying then
            print("[DEBUG] Лодка отсутствует, запускаем восстановление")
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
                if not moving then
                    print("[DEBUG] Сидим в лодке, но движение не запущено – запускаем")
                    startMove()
                end
            else
                if not isReseating then
                    isReseating = true
                    if seat then
                        print("[DEBUG] Сидим не на том сиденье, пересаживаемся")
                        forceSitOnSeat(seat, 3)
                    end
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

-- ========== 9. ФРУКТЫ ==========
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

-- ========== 10. АНТИ-IDLE ==========
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

print("===== СКРИПТ 9.7-DEBUG ЗАПУЩЕН =====")
