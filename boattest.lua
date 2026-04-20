-- ===== ФИНАЛЬНЫЙ НАДЁЖНЫЙ СКРИПТ (ПОСТОЯННОЕ ОБНОВЛЕНИЕ ДВИЖЕНИЯ) =====
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
local currentDirection = -1   -- -1 = влево, 1 = вправо
local isSitting = false
local needToSit = true
local moveCompleted = false   -- флаг, что перемещение к точке покупки выполнено

-- ========== КОЛЛИЗИИ ==========
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

local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

-- ========== ВЫБОР КОМАНДЫ ==========
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

-- ========== ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА ==========
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

-- ========== ПОИСК ЛОДКИ ==========
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

-- ========== ПОКУПКА ЛОДКИ ==========
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- ========== ПОСАДКА (С ПОВТОРНЫМИ ПОПЫТКАМИ) ==========
local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local startTime = tick()
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        if tick() - startTime > 10 then break end -- защита от бесконечного цикла
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    return true
end

-- ========== УПРАВЛЕНИЕ ДВИЖЕНИЕМ ЛОДКИ (ПОСТОЯННОЕ ОБНОВЛЕНИЕ) ==========
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
        end
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
    end
end

local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        ensureBoatMovement()
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        ensureBoatMovement()
    end
end

-- ========== ГЛАВНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)
    moveCompleted = false

    while true do
        -- 1. Ожидание появления персонажа
        local char = player.Character
        if not char then
            print("Ожидание появления персонажа...")
            player.CharacterAdded:Wait()
            char = player.Character
            -- Сброс состояния
            myBoat = nil; seat = nil; rootPart = nil
            isSitting = false; needToSit = true; moveCompleted = false
            if char then
                disableAllCollisions(char)
                maintainCollisions(char)
            end
            task.wait(1)
        end

        -- 2. Если лодки нет, выполняем перемещение и покупку (только если moveCompleted == false)
        if (not myBoat or not myBoat.Parent) and not moveCompleted then
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
            moveCompleted = true
        end

        -- 3. Проверка, сидит ли персонаж
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if not sitting then
            if needToSit then
                print("Попытка сесть на сиденье...")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and humanoid then
                    sitOnSeat(seat, hrp, humanoid)
                    -- Проверяем, сел ли
                    if humanoid.Sit and humanoid.SeatPart == seat then
                        isSitting = true
                        needToSit = false
                        print("Успешно сел")
                    else
                        print("Не удалось сесть, повтор через 0.5 сек")
                        task.wait(0.5)
                    end
                else
                    task.wait(0.5)
                end
            else
                -- Если не сидит, но needToSit = false, возможно, слезли
                isSitting = false
                needToSit = true
                print("Персонаж слез с сиденья")
            end
        else
            -- Сидит: обновляем движение и направление
            if not isSitting then
                isSitting = true
                needToSit = false
                print("Персонаж сидит, запускаем движение")
            end
            ensureBoatMovement()
            updateDirection()
        end

        task.wait(0.1) -- частая проверка для мгновенной реакции
    end
end)

print("Скрипт запущен. Движение лодки будет постоянно поддерживаться, посадка повторяется до успеха.")
