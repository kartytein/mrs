-- ===== ИТОГОВЫЙ СКРИПТ С ГАРАНТИРОВАННОЙ ПОСАДКОЙ =====
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

local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1
local isSitting = false
local needToSit = true
local moveCompleted = false   -- флаг, что перемещение к точке выполнено

-- ========== 1. КОЛЛИЗИИ ==========
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then lower.CanCollide = false end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then upper.CanCollide = false end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

-- ========== 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
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

local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- Бесконечная попытка сесть на сиденье (цикл)
local function forceSitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    disableAllCollisions(char)
    maintainCollisions(char)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    print("[DIAG] Начинаем посадку, цель: " .. tostring(targetCF.Position))
    while true do
        -- Проверяем, не сел ли уже
        if humanoid.Sit and humanoid.SeatPart == boatSeat then
            print("[DIAG] Посадка успешна")
            return true
        end
        -- Создаём BodyVelocity
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        local startTime = tick()
        while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
            local dir = (targetCF.Position - hrp.Position).Unit
            bv.Velocity = dir * WALK_SPEED
            task.wait()
            if tick() - startTime > 10 then break end -- таймаут
        end
        bv:Destroy()
        -- Небольшая задержка перед следующей попыткой
        task.wait(0.5)
        -- Если персонаж умер, выходим из функции (главный цикл перезапустит)
        if not hrp.Parent then return false end
    end
end

-- Управление лодкой (движение)
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
        if isSitting then setBoatSpeed(BOAT_SPEED) end
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        if isSitting then setBoatSpeed(-BOAT_SPEED) end
    end
end

-- ========== 3. ГЛАВНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание персонажа
        local char = player.Character
        if not char then
            print("[MAIN] Персонаж не загружен, ждём...")
            player.CharacterAdded:Wait()
            char = player.Character
            -- Сбрасываем состояние лодки и флаг перемещения
            myBoat = nil; seat = nil; rootPart = nil
            isSitting = false
            needToSit = true
            moveCompleted = false
            stopBoat()
            task.wait(1)
        end

        -- Шаг 1: перемещение к точке покупки (если ещё не выполнено)
        if not moveCompleted then
            print("[MAIN] Перемещение к точке покупки...")
            if moveToPoint(PURCHASE_POINT, WALK_SPEED) then
                moveCompleted = true
                print("[MAIN] Перемещение завершено")
            else
                print("[MAIN] Ошибка перемещения, повтор через 1 сек")
                task.wait(1)
                continue
            end
        end

        -- Шаг 2: если нет лодки, покупаем
        if not myBoat or not myBoat.Parent then
            print("[MAIN] Покупка лодки...")
            buyBoat()
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                print("[MAIN] Лодка не появилась, повтор через 5 сек")
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not rootPart then
                print("[MAIN] Ошибка: нет сиденья/части, сброс")
                myBoat = nil
                continue
            end
            -- Отключаем коллизии лодки и её скрипт
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
        end

        -- Шаг 3: посадка (циклическая, пока не сядем)
        local humanoid = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and humanoid and seat then
            if not (humanoid.Sit and humanoid.SeatPart == seat) then
                print("[MAIN] Попытка сесть на сиденье...")
                local success = forceSitOnSeat(seat, hrp, humanoid)
                if success then
                    needToSit = false
                    isSitting = true
                    print("[MAIN] Посадка подтверждена")
                else
                    print("[MAIN] Посадка не удалась, сброс лодки")
                    myBoat = nil
                    task.wait(1)
                    continue
                end
            else
                isSitting = true
                needToSit = false
            end
        else
            task.wait(0.5)
            continue
        end

        -- Шаг 4: движение лодки (активно, пока сидим)
        while isSitting and myBoat and myBoat.Parent and char and char.Parent do
            local humanoid = char:FindFirstChild("Humanoid")
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                print("[MAIN] Персонаж перестал сидеть, остановка движения")
                isSitting = false
                needToSit = true
                stopBoat()
                break
            end
            -- Поддерживаем скорость
            local currentSpeed = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            setBoatSpeed(currentSpeed)
            updateDirection()
            task.wait(0.1)
        end

        -- Если вышли из цикла, значит, нужно снова сесть или перекупить лодку
        if not myBoat or not myBoat.Parent then
            print("[MAIN] Лодка потеряна, сброс флагов")
            myBoat = nil
            moveCompleted = false   -- чтобы снова переместиться к точке
        end
        task.wait(0.5)
    end
end)

print("Скрипт запущен. Посадка будет повторяться до успеха, движение восстанавливается после урона.")
