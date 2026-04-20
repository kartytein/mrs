-- ===== ФИНАЛЬНЫЙ СКРИПТ С ДИАГНОСТИКОЙ (ПОЛНАЯ ВЕРСИЯ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свои координаты)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.2

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1
local isSitting = false
local needToSit = true
local needToMove = true

-- ========== 1. ДИАГНОСТИКА ==========
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- ========== 2. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then
                lower.CanCollide = false
                log("LowerTorso CanCollide -> false")
            end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then
                upper.CanCollide = false
                log("UpperTorso CanCollide -> false")
            end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    log("Все коллизии персонажа отключены")
end

-- ========== 3. ВЫБОР КОМАНДЫ ==========
local function selectMarines()
    log("Выбор команды Marines...")
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end
end

-- ========== 4. ПЕРЕМЕЩЕНИЕ К ТОЧКЕ ==========
local function moveToPoint(target, speed)
    log("Перемещение к точке " .. tostring(target))
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    disableAllCollisions(char)
    maintainCollisions(char)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local stuck = 0
    local lastDist = math.huge
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait(0.1)
        local dist = (hrp.Position - target).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            stuck = stuck + 1
            if stuck > 10 then
                log("Застревание, пересоздаём BodyVelocity")
                bv:Destroy()
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp
                stuck = 0
            end
        else
            stuck = 0
        end
        lastDist = dist
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
    if humanoid then humanoid.PlatformStand = false end
    log("Перемещение завершено")
    return true
end

-- ========== 5. ПОИСК ЛОДКИ ==========
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == playerName then
                log("Лодка найдена по Owner: " .. boat.Name)
                return boat
            end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then
                log("Лодка найдена по объекту Owner: " .. boat.Name)
                return boat
            end
        end
    end
    return nil
end

-- ========== 6. ПОКУПКА ЛОДКИ ==========
local function buyBoat()
    log("Покупка лодки...")
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- ========== 7. ПОСАДКА ==========
local function sitOnSeat(boatSeat, hrp, humanoid)
    log("Начинаем посадку...")
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local stuck = 0
    local lastDist = math.huge
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            stuck = stuck + 1
            if stuck > 10 then
                log("Застревание при посадке, пересоздаём")
                bv:Destroy()
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp
                stuck = 0
            end
        else
            stuck = 0
        end
        lastDist = dist
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    log("Посадка завершена, Sit = " .. tostring(humanoid.Sit))
    return true
end

-- ========== 8. УПРАВЛЕНИЕ ДВИЖЕНИЕМ ==========
local function stopBoatMovement()
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then
                bv:Destroy()
                log("BodyVelocity удалён (остановка лодки)")
            end
        end
    end
end

local function ensureBoatMovement()
    if not isSitting then
        log("ensureBoatMovement: isSitting = false, выход")
        return
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        if bv.Velocity.X ~= speedX then
            bv.Velocity = Vector3.new(speedX, 0, 0)
            log("Обновлена скорость BodyVelocity: " .. speedX)
        end
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
        log("Создан BodyVelocity, скорость " .. speedX)
    end
end

local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        log("Смена направления → вправо (X = " .. x .. ")")
        ensureBoatMovement()
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        log("Смена направления → влево (X = " .. x .. ")")
        ensureBoatMovement()
    end
end

-- ========== 9. ГЛАВНЫЙ ЦИКЛ С ДИАГНОСТИКОЙ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание персонажа
        if not player.Character then
            log("Персонаж отсутствует (смерть), ожидание...")
            player.CharacterAdded:Wait()
            log("Персонаж появился")
            myBoat = nil; seat = nil; rootPart = nil
            isSitting = false; needToSit = true; needToMove = true
            stopBoatMovement()
            task.wait(1)
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if not humanoid then task.wait(0.1) continue end

        -- Диагностика состояния
        local sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        if sitting ~= isSitting then
            log("Состояние изменилось: isSitting = " .. tostring(sitting))
            isSitting = sitting
            if not isSitting then
                needToSit = true
                stopBoatMovement()
                log("Остановка движения (вылез)")
            end
        end

        -- Если лодки нет, покупаем (с предварительным перемещением)
        if not myBoat or not myBoat.Parent then
            log("Лодка отсутствует, начинаем процесс покупки")
            if needToMove then
                moveToPoint(PURCHASE_POINT, WALK_SPEED)
                needToMove = false
            end
            buyBoat()
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                log("Не удалось призвать лодку, повтор через 5 сек")
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not rootPart then
                log("Ошибка: нет сиденья или основной части")
                myBoat = nil
                continue
            end
            -- Отключаем коллизии у лодки и её скрипт
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
            log("Лодка готова")
        end

        -- Если не сидим, пытаемся сесть
        if not isSitting then
            if needToSit then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    sitOnSeat(seat, hrp, humanoid)
                    if humanoid.Sit and humanoid.SeatPart == seat then
                        isSitting = true
                        needToSit = false
                        log("Успешно сел, запускаем движение")
                    else
                        log("Посадка не удалась")
                    end
                end
            end
        else
            -- Сидим: поддерживаем движение
            ensureBoatMovement()
            updateDirection()
        end

        task.wait(0.1)
    end
end)

log("Скрипт запущен. Диагностика активна.")
