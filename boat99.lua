-- ===== МАКСИМАЛЬНО ПРОСТОЙ И НАДЁЖНЫЙ СКРИПТ (ОДИН ГЛАВНЫЙ ЦИКЛ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свои координаты)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)      -- где покупать лодку
local BOAT_X_MIN = -77389.3                               -- левая граница
local BOAT_X_MAX = -47968.4                               -- правая граница
local BOAT_SPEED = 250                                    -- скорость лодки
local WALK_SPEED = 150                                    -- скорость при перемещении и посадке
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)                -- высота над сиденьем

-- Глобальные переменные для состояния
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1   -- -1 = влево, 1 = вправо

-- ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========

-- Отключение коллизий у персонажа (только для LowerTorso/UpperTorso, как в эталоне)
local function disableCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
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

-- Перемещение персонажа к точке (BodyVelocity)
local function moveToPoint(target, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    disableCollisions(char)
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

-- Поиск своей лодки (по атрибуту Owner или объекту Owner)
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

-- Покупка лодки (вызов удалённой функции)
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- Посадка на сиденье (BodyVelocity, постоянная скорость)
local function sitOnSeat(boatSeat, hrp, humanoid)
    disableCollisions(hrp.Parent)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
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
end

-- Управление движением лодки (BodyVelocity на персонаже)
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

-- Обновление направления движения по X лодки
local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        setBoatSpeed(BOAT_SPEED)
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        setBoatSpeed(-BOAT_SPEED)
    end
end

-- ========== ГЛАВНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- 1. Ожидание появления персонажа (если умер)
        local char = player.Character
        if not char then
            print("Ожидание появления персонажа...")
            player.CharacterAdded:Wait()
            char = player.Character
            -- Сброс состояния лодки (она могла исчезнуть)
            myBoat = nil
            seat = nil
            rootPart = nil
            stopBoat()
            task.wait(1)
        end

        -- 2. Если лодки нет, покупаем новую
        if not myBoat or not myBoat.Parent then
            print("Перемещение к точке покупки...")
            moveToPoint(PURCHASE_POINT, WALK_SPEED)
            print("Покупка лодки...")
            buyBoat()
            task.wait(3)
            -- Ищем лодку
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                print("Не удалось призвать лодку, повтор через 5 секунд")
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not rootPart then
                print("Ошибка: нет сиденья или основной части, повтор")
                myBoat = nil
                continue
            end
            -- Отключаем коллизии у лодки и её скрипт
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
        end

        -- 3. Проверяем, сидит ли персонаж на сиденье
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if not sitting then
            -- Не сидит: останавливаем движение и садимся
            stopBoat()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and humanoid then
                print("Посадка на сиденье...")
                sitOnSeat(seat, hrp, humanoid)
            else
                task.wait(0.5)
            end
        else
            -- Сидит: поддерживаем движение
            local currentSpeed = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            setBoatSpeed(currentSpeed)
            updateDirection()
        end

        task.wait(0.2)
    end
end)

print("Скрипт запущен. Лодка будет покупаться только после перемещения в точку. Движение устойчиво к урону и смерти.")
