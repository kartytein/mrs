-- ===== ФИНАЛЬНЫЙ ПОЛНЫЙ СКРИПТ С ДИАГНОСТИКОЙ (ВСЕ МЕХАНИЗМЫ ВКЛЮЧЕНЫ) =====
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
local needToMove = true

-- ========== ДИАГНОСТИКА ==========
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (ПЕРСОНАЖ + ЛОДКА) ==========
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            -- Отключаем у всех частей персонажа
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            -- Особо важно для LowerTorso и UpperTorso (как в эталоне)
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
        task.wait(COLLISION_INTERVAL)
    end
end)

-- ========== 2. ВЫБОР КОМАНДЫ ==========
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

-- ========== 3. ПЕРЕМЕЩЕНИЕ К ТОЧКЕ (С ПОВТОРНЫМИ ПОПЫТКАМИ) ==========
local function moveToPoint(target, speed)
    log("Перемещение к точке " .. tostring(target))
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local lastDist = math.huge
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait(0.1)
        local dist = (hrp.Position - target).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            log("Застревание при перемещении, пересоздаём BodyVelocity")
            bv:Destroy()
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
        end
        lastDist = dist
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
    if humanoid then humanoid.PlatformStand = false end
    log("Перемещение завершено")
    return true
end

-- ========== 4. ПОИСК ЛОДКИ ==========
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

-- ========== 5. ПОКУПКА ЛОДКИ ==========
local function buyBoat()
    log("Покупка лодки...")
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- ========== 6. ПОСАДКА НА СИДЕНЬЕ ==========
local function sitOnSeat()
    if not seat then return end
    log("Посадка на сиденье...")
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    local targetCF = seat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local lastDist = math.huge
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            log("Застревание при посадке, пересоздаём BodyVelocity")
            bv:Destroy()
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
        end
        lastDist = dist
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    log("Посадка завершена")
end

-- ========== 7. ПОДДЕРЖАНИЕ ДВИЖЕНИЯ ЛОДКИ (BODYVELOCITY НА ПЕРСОНАЖЕ) ==========
local function ensureBoatVelocity()
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
        -- Если не сидит, удаляем BodyVelocity
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy() end
        return false
    end
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
    return true
end

local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        log("Смена направления → вправо (X = " .. x .. ")")
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        log("Смена направления → влево (X = " .. x .. ")")
    end
end

-- ========== 8. ПРОВЕРКА ДВИЖЕНИЯ ЛОДКИ (ПЕРЕСАДКА ПРИ ЗАСТОЕ) ==========
local function checkBoatMovement()
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

-- ========== 9. ГЛАВНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание появления персонажа
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

        -- Если лодки нет, покупаем (только после перемещения)
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
            -- Отключаем родной скрипт лодки
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
            log("Лодка готова")
        end

        -- Если не сидит, садимся
        local sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        if not sitting then
            log("Персонаж не сидит, выполняем посадку")
            sitOnSeat()
        else
            -- Обновляем направление и поддерживаем скорость
            updateDirection()
            ensureBoatVelocity()
            -- Раз в 2 секунды проверяем, движется ли лодка
            if tick() % 2 < 0.1 then
                task.spawn(checkBoatMovement)
            end
        end

        -- Диагностика состояния каждые 3 секунды
        if tick() % 3 < 0.1 then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local bv = hrp and hrp:FindFirstChildWhichIsA("BodyVelocity")
            log("=== СОСТОЯНИЕ ===")
            log("Сидит: " .. tostring(sitting))
            log("BodyVelocity есть: " .. tostring(bv ~= nil))
            if bv then log("Скорость BV: " .. tostring(bv.Velocity)) end
            log("Направление: " .. (currentDirection == -1 and "влево" or "вправо"))
            if rootPart then log("X лодки: " .. rootPart.Position.X) end
            log("================")
        end

        task.wait(0.1)
    end
end)

log("Скрипт запущен. Полная диагностика включена. Коллизии отключены постоянно.")
