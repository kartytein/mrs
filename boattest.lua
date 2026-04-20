-- ===== ДИАГНОСТИЧЕСКАЯ ВЕРСИЯ СКРИПТА =====
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

local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1
local collisionThread = nil

-- Функция для вывода в консоль с меткой времени
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- ========== ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
local function startCollisionFix(char)
    if collisionThread then task.cancel(collisionThread) end
    collisionThread = task.spawn(function()
        while char and char.Parent do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then
                lower.CanCollide = false
                log("LowerTorso CanCollide принудительно false")
            end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then
                upper.CanCollide = false
                log("UpperTorso CanCollide принудительно false")
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

-- ========== ОСНОВНЫЕ ФУНКЦИИ ==========
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
    log("Команда Marines выбрана")
end

local function moveToPoint(target, speed)
    local char = player.Character
    if not char then log("moveToPoint: персонаж отсутствует"); return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then log("moveToPoint: нет HumanoidRootPart"); return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    disableAllCollisions(char)
    startCollisionFix(char)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    log("Начинаем перемещение к точке " .. tostring(target))
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

local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then log("Папка Boats не найдена"); return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == playerName then log("Найдена лодка по атрибуту Owner: " .. boat.Name); return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then log("Найдена лодка по объекту Owner: " .. boat.Name); return boat end
        end
    end
    log("Лодка не найдена")
    return nil
end

local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
        log("Команда на покупку лодки отправлена")
    else
        log("Remotes не найдены, покупка невозможна")
    end
end

local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    disableAllCollisions(char)
    startCollisionFix(char)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    log("Начинаем посадку, цель CFrame: " .. tostring(targetCF))
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    log("Посадка завершена")
end

local function setBoatSpeed(speedX)
    local char = player.Character
    if not char then log("setBoatSpeed: персонаж отсутствует"); return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then log("setBoatSpeed: нет HumanoidRootPart"); return end
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        bv.Velocity = Vector3.new(speedX, 0, 0)
        log("Обновлена скорость BodyVelocity: " .. speedX)
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
        log("Создан новый BodyVelocity со скоростью " .. speedX)
    end
end

local function stopBoat()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy(); log("BodyVelocity уничтожен (лодка остановлена)") end
    end
end

local function updateDirection()
    if not rootPart then log("updateDirection: rootPart отсутствует"); return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        log("Достигнута левая граница, смена направления на вправо")
        setBoatSpeed(BOAT_SPEED)
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        log("Достигнута правая граница, смена направления на влево")
        setBoatSpeed(-BOAT_SPEED)
    end
end

-- ========== ГЛАВНЫЙ ЦИКЛ С ДИАГНОСТИКОЙ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        local char = player.Character
        if not char then
            log("Персонаж умер, ожидание возрождения...")
            if collisionThread then task.cancel(collisionThread); collisionThread = nil end
            stopBoat()
            myBoat = nil; seat = nil; rootPart = nil
            player.CharacterAdded:Wait()
            char = player.Character
            log("Персонаж возродился")
            task.wait(1)
        end

        -- Поиск/покупка лодки
        if not myBoat or not myBoat.Parent then
            log("Лодка отсутствует, начинаем процесс получения")
            moveToPoint(PURCHASE_POINT, WALK_SPEED)
            buyBoat()
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                log("Не удалось получить лодку, повтор через 5 секунд")
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not rootPart then
                log("Ошибка: у лодки нет сиденья или основной части")
                myBoat = nil
                continue
            end
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
            log("Лодка получена и подготовлена: " .. myBoat.Name)
        end

        -- Проверка посадки
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if not sitting then
            log("Персонаж не сидит в лодке, начинаем посадку")
            stopBoat()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and humanoid then
                sitOnSeat(seat, hrp, humanoid)
            else
                log("Не удалось получить HumanoidRootPart или Humanoid для посадки")
                task.wait(0.5)
            end
        else
            -- Поддерживаем движение и коллизии
            startCollisionFix(char)
            local currentSpeed = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            setBoatSpeed(currentSpeed)
            updateDirection()
        end

        task.wait(0.2)
    end
end)

log("Диагностическая версия скрипта запущена. Следите за выводом в консоль.")
