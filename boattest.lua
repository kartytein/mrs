-- ===== СКРИПТ С НЕПРЕРЫВНОЙ ПОПЫТКОЙ ПОСАДКИ (ПОСЛЕ СМЕРТИ ТОЖЕ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)

local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1
local collisionThread = nil

-- Функция для вывода диагностики
local function log(msg)
    print("[LOG] " .. msg)
end

-- Отключение коллизий у персонажа (постоянное)
local function disableAllCollisions(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Фоновое отключение коллизий у LowerTorso/UpperTorso
local function startCollisionFix(char)
    if collisionThread then task.cancel(collisionThread) end
    collisionThread = task.spawn(function()
        while char and char.Parent do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then
                lower.CanCollide = false
            end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then
                upper.CanCollide = false
            end
            task.wait(0.2)
        end
    end)
end

-- Выбор команды Marines
local function selectMarines()
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

-- Перемещение к точке (синхронное)
local function moveToPoint(target, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    disableAllCollisions(char)
    startCollisionFix(char)
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
    return true
end

-- Поиск своей лодки
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

-- Покупка лодки
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- Функция посадки (будет вызываться в цикле, пока не сядет)
local function trySitOnSeat()
    if not myBoat or not seat then
        log("Нет лодки или сиденья для посадки")
        return false
    end
    local char = player.Character
    if not char then
        log("Персонаж не загружен, ждём...")
        return false
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        log("Нет HumanoidRootPart или Humanoid")
        return false
    end
    -- Если уже сидит, выходим
    if humanoid.Sit and humanoid.SeatPart == seat then
        log("Уже сидит в лодке")
        return true
    end
    -- Отключаем коллизии
    disableAllCollisions(char)
    startCollisionFix(char)
    local targetCF = seat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local startTime = os.clock()
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait()
        if os.clock() - startTime > 10 then
            log("Посадка не удалась за 10 секунд, повтор")
            break
        end
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    if humanoid.Sit and humanoid.SeatPart == seat then
        log("Посадка успешна")
        return true
    else
        log("Посадка не удалась")
        return false
    end
end

-- Управление движением лодки
local function setBoatSpeed(speedX)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        bv.Velocity = Vector3.new(speedX, 0, 0)
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
    end
end

local function stopBoat()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy() end
    end
end

local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        setBoatSpeed(BOAT_SPEED)
        log("Смена направления: вправо")
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        setBoatSpeed(-BOAT_SPEED)
        log("Смена направления: влево")
    end
end

-- ========== ОСНОВНОЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- 1. Ожидание загрузки персонажа
        local char = player.Character
        if not char then
            log("Персонаж не загружен, ожидание...")
            player.CharacterAdded:Wait()
            char = player.Character
            log("Персонаж появился")
            -- Сбрасываем состояние лодки, так как она могла исчезнуть
            myBoat = nil
            seat = nil
            rootPart = nil
            stopBoat()
            task.wait(1)
        end

        -- 2. Если лодки нет, покупаем
        if not myBoat or not myBoat.Parent then
            log("Лодка отсутствует, перемещение к точке покупки...")
            moveToPoint(PURCHASE_POINT, WALK_SPEED)
            log("Покупка лодки...")
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
            log("Лодка подготовлена")
        end

        -- 3. Бесконечная попытка сесть, пока не сядет
        local seated = false
        while not seated do
            seated = trySitOnSeat()
            if not seated then
                log("Повторная попытка посадки через 0.5 сек...")
                task.wait(0.5)
            end
        end

        -- 4. Теперь персонаж сидит, запускаем движение и поддерживаем его
        log("Персонаж сидит, запускаем движение")
        while true do
            -- Проверяем, сидит ли до сих пор
            local char = player.Character
            if not char then break end -- персонаж умер, выйдем из цикла движения
            local humanoid = char:FindFirstChild("Humanoid")
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                log("Персонаж перестал сидеть, выходим из цикла движения")
                break
            end
            -- Поддерживаем движение
            local currentSpeed = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            setBoatSpeed(currentSpeed)
            updateDirection()
            -- Поддерживаем коллизии
            startCollisionFix(char)
            task.wait(0.1)
        end
        -- Если вышли из цикла, значит персонаж слез или умер, идём на новый круг (попытка посадки)
        stopBoat()
        log("Цикл движения завершён, переходим к посадке")
    end
end)

print("Скрипт запущен. Будет непрерывно пытаться сесть в лодку, даже после смерти.")
