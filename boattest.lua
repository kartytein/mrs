-- ===== МАКСИМАЛЬНО ПОЛНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (ВСЕ МЕХАНИЗМЫ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (ИЗМЕНИТЕ ПОД СВОЮ ИГРУ)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)      -- точка, где покупать лодку
local BOAT_X_MIN = -77389.3                               -- левая граница (дальняя)
local BOAT_X_MAX = -47968.4                               -- правая граница (ближняя)
local BOAT_SPEED = 250                                    -- скорость лодки (по модулю)
local WALK_SPEED = 150                                    -- скорость перемещения персонажа
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)                -- высота над сиденьем
local COLLISION_INTERVAL = 0.2                            -- частота отключения коллизий

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1          -- -1 = влево, 1 = вправо
local needToMove = true               -- нужно ли сначала переместиться в точку покупки
local isSitting = false

-- ========== 1. ДИАГНОСТИКА (опционально, можно закомментировать) ==========
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- ========== 2. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (ПЕРСОНАЖ + ЛОДКА) ==========
local function disableAllCollisions()
    local char = player.Character
    if char then
        -- Все части персонажа
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        -- Особый упор на LowerTorso и UpperTorso (как в эталонном скрипте)
        local lower = char:FindFirstChild("LowerTorso")
        local upper = char:FindFirstChild("UpperTorso")
        if lower then lower.CanCollide = false end
        if upper then upper.CanCollide = false end
    end
    if myBoat then
        for _, part in ipairs(myBoat:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

-- Запускаем фоновый поток для постоянного отключения коллизий
task.spawn(function()
    while true do
        disableAllCollisions()
        task.wait(COLLISION_INTERVAL)
    end
end)

-- ========== 3. ВЫБОР КОМАНДЫ ==========
local function selectMarines()
    log("Выбор команды Marines...")
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end
end

-- ========== 4. ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА К ТОЧКЕ (С ПОВТОРНЫМИ ПОПЫТКАМИ) ==========
local function moveToPoint(target, speed)
    log("Перемещение к точке покупки...")
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    disableAllCollisions()
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local lastDist = math.huge
    local stuck = 0
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait(0.1)
        local dist = (hrp.Position - target).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            stuck = stuck + 1
            if stuck > 10 then
                log("Застревание при перемещении, пересоздаём BodyVelocity")
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

-- ========== 5. ПОИСК СВОЕЙ ЛОДКИ ==========
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then return boat end
        end
    end
    return nil
end

-- ========== 6. ПОКУПКА НОВОЙ ЛОДКИ ==========
local function buyBoat()
    log("Покупка лодки...")
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
    task.wait(3)
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then
        log("Не удалось призвать лодку")
        return false
    end
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then
        log("Ошибка: нет сиденья или основной части")
        myBoat = nil
        return false
    end
    -- Отключаем коллизии лодки и её родной скрипт
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end
    log("Лодка готова: " .. myBoat.Name)
    return true
end

-- ========== 7. ПОСАДКА НА СИДЕНЬЕ (С ПОВТОРНЫМИ ПОПЫТКАМИ, ПОКА НЕ СЯДЕТ) ==========
local function sitOnSeat()
    if not seat then return end
    log("Начинаем посадку...")
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    -- Удаляем старый BodyVelocity, чтобы не мешал
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    local targetCF = seat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local lastDist = math.huge
    local stuck = 0
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            stuck = stuck + 1
            if stuck > 10 then
                log("Застревание при посадке, пересоздаём BodyVelocity")
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
    log("Посадка завершена")
end

-- ========== 8. ПОДДЕРЖАНИЕ ДВИЖЕНИЯ ЛОДКИ (BODYVELOCITY НА ПЕРСОНАЖЕ) ==========
local function ensureBoatMovement()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local sitting = (humanoid.Sit and humanoid.SeatPart == seat)
    if not sitting then
        -- Если не сидит, удаляем BodyVelocity
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy() end
        return
    end

    -- Сидит: создаём/обновляем BodyVelocity
    local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        if bv.Velocity.X ~= speedX then
            bv.Velocity = Vector3.new(speedX, 0, 0)
        end
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
    end
end

-- Обновление направления движения по X лодки (достижение границ)
local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        log("Смена направления → вправо")
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        log("Смена направления → влево")
    end
end

-- ========== 9. ПРОВЕРКА ДВИЖЕНИЯ ЛОДКИ (ЕСЛИ ЗАСТРЯЛА, ПЕРЕСАЖИВАЕМ) ==========
local function checkIfStuck()
    if not rootPart or not seat then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then return end
    local pos1 = rootPart.Position
    task.wait(0.5)
    local pos2 = rootPart.Position
    if (pos2 - pos1).Magnitude < 1 then
        log("Лодка не двигается! Принудительное пересаживание...")
        humanoid.Sit = false
        task.wait(0.2)
        sitOnSeat()
    end
end

-- ========== 10. ГЛАВНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание появления персонажа (если умер)
        if not player.Character then
            log("Персонаж отсутствует (смерть), ожидание...")
            player.CharacterAdded:Wait()
            log("Персонаж появился")
            myBoat = nil; seat = nil; rootPart = nil
            needToMove = true
            task.wait(1)
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if not humanoid then task.wait(0.1) continue end

        -- Если лодки нет, покупаем новую (с предварительным перемещением)
        if not myBoat or not myBoat.Parent then
            log("Лодка отсутствует, начинаем процесс покупки")
            if needToMove then
                moveToPoint(PURCHASE_POINT, WALK_SPEED)
                needToMove = false
            end
            local success = buyBoat()
            if not success then
                task.wait(5)
                continue
            end
        end

        -- Проверяем, сидит ли персонаж
        local sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        if not sitting then
            log("Персонаж не сидит, выполняем посадку")
            sitOnSeat()
        else
            -- Сидит: обновляем направление и поддерживаем скорость
            updateDirection()
            ensureBoatMovement()
            -- Периодически проверяем, движется ли лодка
            if tick() % 2 < 0.1 then
                task.spawn(checkIfStuck)
            end
        end

        task.wait(0.1)
    end
end)

log("Скрипт запущен. Все механизмы активны.")
