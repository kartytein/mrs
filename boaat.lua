-- ===== СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (НА ОСНОВЕ РАБОЧЕГО МЕХАНИЗМА) =====
-- Механизм посадки и движения взят из вашего полного скрипта (с поддержкой острова).
-- Скрипт сам находит лодку по Owner, садится и поддерживает движение.
-- При вылезании автоматически возвращает на сиденье.

local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свою игру)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local WALK_SPEED = 150
local COLLISION_INTERVAL = 0.3

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local isSitting = false
local needToSit = true
local currentDirection = -1

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent and not stopScript do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then lower.CanCollide = false end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then upper.CanCollide = false end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

-- ========== 2. ПОИСК СВОЕЙ ЛОДКИ ПО OWNER ==========
local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local ownerAttr = boat:GetAttribute("Owner")
            if ownerAttr == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and (ownerObj:IsA("StringValue") or ownerObj:IsA("ObjectValue")) then
                if tostring(ownerObj.Value) == playerName then return boat end
            end
        end
    end
    return nil
end

-- ========== 3. ПОСАДКА (РАБОЧИЙ МЕХАНИЗМ ИЗ ВАШЕГО СКРИПТА) ==========
local function sitOnSeat()
    if not seat then
        print("[DIAG] Нет сиденья, поиск лодки...")
        myBoat = findMyBoat()
        if not myBoat then
            print("[DIAG] Лодка не найдена, посадка невозможна")
            return false
        end
        seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        if not seat then
            print("[DIAG] Сиденье не найдено")
            return false
        end
        -- Отключаем коллизии лодки и её родной скрипт
        for _, part in ipairs(myBoat:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        local native = myBoat:FindFirstChild("Script")
        if native then native.Disabled = true end
        print("[DIAG] Лодка найдена: " .. myBoat.Name)
    end

    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    disableAllCollisions(char)
    maintainCollisions(char)

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    local targetCF = seat.CFrame + SEAT_OFFSET
    print("[DIAG] Начинаем посадку, цель: " .. tostring(targetCF.Position))

    while needToSit and myBoat and myBoat.Parent and seat and hrp and hrp.Parent do
        local direction = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = direction * WALK_SPEED
        task.wait()
        local hum = hrp.Parent and hrp.Parent:FindFirstChild("Humanoid")
        if hum and hum.Sit and hum.SeatPart == seat then
            break
        end
        -- Обновляем цель, если сиденье сместилось
        targetCF = seat.CFrame + SEAT_OFFSET
    end
    bv:Destroy()
    if hrp and hrp.Parent then
        hrp.CFrame = targetCF
        if humanoid then humanoid.Sit = true end
    end
    print("[DIAG] Посадка завершена")
    return true
end

-- ========== 4. УПРАВЛЕНИЕ ДВИЖЕНИЕМ ЛОДКИ (BODYVELOCITY НА ПЕРСОНАЖЕ) ==========
local function stopBoatMovement()
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then bv:Destroy() end
        end
    end
end

local function updateBoatMovement()
    if not isSitting then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
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

-- ========== 5. ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ ==========
local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        print("[DIAG] Смена направления → вправо")
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        print("[DIAG] Смена направления → влево")
    end
end

-- ========== 6. МОНИТОР ПОСАДКИ И ДВИЖЕНИЯ ==========
task.spawn(function()
    while not stopScript do
        local char = player.Character
        if not char then
            if isSitting then
                isSitting = false
                needToSit = true
                stopBoatMovement()
            end
            player.CharacterAdded:Wait()
            char = player.Character
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            task.wait(1)
            continue
        end

        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if sitting ~= isSitting then
            isSitting = sitting
            if isSitting then
                needToSit = false
                updateBoatMovement()
            else
                needToSit = true
                stopBoatMovement()
            end
        end

        -- Если лодка пропала, сбрасываем ссылки
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            stopBoatMovement()
        end

        -- Если нужно сесть, вызываем посадку
        if needToSit then
            sitOnSeat()
        else
            -- Если сидим, поддерживаем движение
            if isSitting and myBoat and rootPart then
                updateDirection()
                updateBoatMovement()
            end
        end

        task.wait(0.2)
    end
end)

print("[DIAG] Скрипт управления лодкой запущен. Ожидание посадки...")
