-- ===== ФИНАЛЬНЫЙ СКРИПТ С ИСПРАВЛЕНИЕМ ПОСЛЕ СМЕРТИ =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
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
local boatAvailable = false   -- флаг, что лодка существует и готова

local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- ========== КОЛЛИЗИИ ==========
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

-- ========== ВЫБОР КОМАНДЫ ==========
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
    log("Команда Marines выбрана")
end

-- ========== ПЕРЕМЕЩЕНИЕ К ТОЧКЕ (только для покупки) ==========
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
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
    if humanoid then humanoid.PlatformStand = false end
    log("Перемещение завершено")
    return true
end

-- ========== ПОИСК ЛОДКИ ==========
local function findMyBoat()
    log("Поиск своей лодки...")
    local boats = workspace:FindFirstChild("Boats")
    if not boats then
        log("Папка Boats не найдена")
        return nil
    end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == playerName then
                log("Лодка найдена по атрибуту Owner: " .. boat.Name)
                return boat
            end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then
                log("Лодка найдена по объекту Owner: " .. boat.Name)
                return boat
            end
        end
    end
    log("Лодка не найдена")
    return nil
end

-- ========== ПОКУПКА НОВОЙ ЛОДКИ ==========
local function buyNewBoat()
    log("Покупка новой лодки...")
    moveToPoint(PURCHASE_POINT, WALK_SPEED)
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
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
    -- Отключаем коллизии лодки и её скрипт
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end
    log("Новая лодка готова: " .. myBoat.Name)
    return true
end

-- ========== ПОСАДКА (ПЛАВНЫЙ ПОЛЁТ) ==========
local function sitOnSeat(boatSeat, hrp, humanoid)
    log("Начинаем посадку...")
    local char = hrp.Parent
    disableAllCollisions(char)
    maintainCollisions(char)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local startDist = (hrp.Position - targetCF.Position).Magnitude
    log("Расстояние до сиденья: " .. startDist)
    -- Двигаемся, пока расстояние > 0.5
    while (hrp.Position - targetCF.Position).Magnitude > 0.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    log("Посадка завершена, Sit = " .. tostring(humanoid.Sit))
    return true
end

-- ========== УПРАВЛЕНИЕ ДВИЖЕНИЕМ ЛОДКИ ==========
local function ensureBoatMovement()
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
            log("Обновлена скорость: " .. speedX)
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
        log("Смена направления → вправо")
        ensureBoatMovement()
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        log("Смена направления → влево")
        ensureBoatMovement()
    end
end

-- ========== ГЛАВНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- 1. Ожидание персонажа
        local char = player.Character
        if not char then
            log("Персонаж отсутствует (смерть), ожидание...")
            player.CharacterAdded:Wait()
            char = player.Character
            log("Персонаж появился")
            -- Не сбрасываем myBoat! Лодка должна остаться.
            -- Сбрасываем только флаги посадки
            isSitting = false
            needToSit = true
            if char then
                disableAllCollisions(char)
                maintainCollisions(char)
            end
            task.wait(1)
        end

        -- 2. Проверяем существование лодки
        if not myBoat or not myBoat.Parent then
            log("Лодка отсутствует, пытаемся купить новую...")
            if buyNewBoat() then
                boatAvailable = true
            else
                log("Не удалось купить лодку, повтор через 5 сек")
                task.wait(5)
                continue
            end
        else
            boatAvailable = true
        end

        -- 3. Проверка, сидит ли персонаж
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if not sitting then
            if needToSit then
                log("Персонаж не сидит, начинаем посадку...")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and humanoid then
                    sitOnSeat(seat, hrp, humanoid)
                    if humanoid.Sit and humanoid.SeatPart == seat then
                        isSitting = true
                        needToSit = false
                        log("Посадка успешна")
                    else
                        log("Посадка не удалась, повтор через 0.5 сек")
                        task.wait(0.5)
                    end
                else
                    task.wait(0.5)
                end
            else
                isSitting = false
                needToSit = true
                log("Персонаж слез с сиденья")
            end
        else
            if not isSitting then
                isSitting = true
                needToSit = false
                log("Персонаж сидит, запускаем движение")
            end
            ensureBoatMovement()
            updateDirection()
        end

        task.wait(0.1)
    end
end)

log("Скрипт запущен. После смерти персонаж вернётся к существующей лодке без её повторной покупки.")
