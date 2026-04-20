-- ===== АБСОЛЮТНО НАДЁЖНЫЙ СКРИПТ (ПРИНУДИТЕЛЬНОЕ ЗАДАНИЕ СКОРОСТИ КАЖДЫЙ ЦИКЛ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свои координаты)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)      -- где покупать лодку
local BOAT_X_MIN = -77389.3                               -- левая граница
local BOAT_X_MAX = -47968.4                               -- правая граница
local BOAT_SPEED = 250                                    -- скорость лодки
local WALK_SPEED = 150                                    -- скорость при перемещении и посадке
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)                -- высота над сиденьем
local COLLISION_INTERVAL = 0.2                            -- частота отключения коллизий

-- Состояние
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1   -- -1 = влево, 1 = вправо
local collisionThread = nil

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
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
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
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

-- Перемещение персонажа к точке (с отключением коллизий)
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

local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- Посадка на сиденье
local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    disableAllCollisions(char)
    startCollisionFix(char)
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

-- ========== 3. ГЛАВНЫЙ ЦИКЛ (ПРИНУДИТЕЛЬНОЕ ЗАДАНИЕ СКОРОСТИ КАЖДЫЕ 0.1 СЕК) ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание персонажа (если умер)
        local char = player.Character
        if not char then
            print("Ожидание появления персонажа...")
            player.CharacterAdded:Wait()
            char = player.Character
            myBoat = nil; seat = nil; rootPart = nil
            if collisionThread then task.cancel(collisionThread) end
            task.wait(1)
        end

        -- Если лодки нет, покупаем (только после перемещения)
        if not myBoat or not myBoat.Parent then
            print("Перемещение к точке покупки...")
            moveToPoint(PURCHASE_POINT, WALK_SPEED)
            print("Покупка лодки...")
            buyBoat()
            task.wait(3)
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
                print("Ошибка: нет сиденья или основной части")
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

        -- Проверяем, сидит ли персонаж
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if not sitting then
            -- Не сидит: останавливаем и пытаемся сесть
            -- Удаляем BodyVelocity, если есть
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
                if bv then bv:Destroy() end
            end
            if humanoid and seat then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    print("Посадка...")
                    sitOnSeat(seat, hrp, humanoid)
                end
            end
        else
            -- Сидит: ПРИНУДИТЕЛЬНО ЗАДАЁМ СКОРОСТЬ (каждый цикл)
            -- Обновляем направление по X лодки
            if rootPart then
                local x = rootPart.Position.X
                if x <= BOAT_X_MIN and currentDirection == -1 then
                    currentDirection = 1
                elseif x >= BOAT_X_MAX and currentDirection == 1 then
                    currentDirection = -1
                end
            end
            local targetSpeed = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            -- Применяем скорость к персонажу
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
                if bv then
                    bv.Velocity = Vector3.new(targetSpeed, 0, 0)
                else
                    bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Parent = hrp
                    bv.Velocity = Vector3.new(targetSpeed, 0, 0)
                end
            end
            -- Поддерживаем отключение коллизий
            startCollisionFix(char)
        end

        task.wait(0.1)   -- частая проверка для мгновенного восстановления скорости
    end
end)

print("Скрипт запущен. Скорость лодки принудительно задаётся каждые 0.1 секунды, пока вы сидите.")
