-- ===== АБСОЛЮТНО НАДЁЖНЫЙ СКРИПТ (МНОГОУРОВНЕВЫЕ ПРОВЕРКИ) =====
-- 1. Постоянная проверка: если персонаж не сидит в лодке → сажаем (при необходимости покупаем лодку)
-- 2. Движение лодки пересоздаётся при любом сбое (урон, смерть, разрушение лодки)
-- 3. Если лодка сломалась → автоматическая покупка новой
-- 4. Если персонаж застрял (30 сек без изменения позиции) → перезапуск процесса

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
local STUCK_TIMEOUT = 30   -- секунд без изменения позиции для перезапуска

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1   -- -1 = влево, 1 = вправо
local lastPosition = nil
local stuckTimer = 0

-- ========== КОЛЛИЗИИ ==========
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
local function moveCharacterTo(targetPos, speed)
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

    while (hrp.Position - targetPos).Magnitude > 2 do
        if stopScript then break end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    return true
end

-- ========== ПОИСК СВОЕЙ ЛОДКИ ==========
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and (ownerObj:IsA("StringValue") or ownerObj:IsA("ObjectValue")) then
                if tostring(ownerObj.Value) == playerName then return boat end
            end
        end
    end
    return nil
end

-- ========== ПОСАДКА НА СИДЕНЬЕ ==========
local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)

    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local targetPos = targetCF.Position

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    while (hrp.Position - targetPos).Magnitude > 1.5 do
        if stopScript then break end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    return true
end

-- ========== УПРАВЛЕНИЕ ДВИЖЕНИЕМ ЛОДКИ (С ПЕРЕСОЗДАНИЕМ) ==========
local function ensureBodyVelocity(speedX)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        if bv.Velocity.X ~= speedX then
            bv.Velocity = Vector3.new(speedX, 0, 0)
        end
        return true
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
        return true
    end
end

local function stopBoatMovement()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy() end
    end
end

-- ========== ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ ==========
local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Sit and player.Character.Humanoid.SeatPart == seat then
            ensureBodyVelocity(BOAT_SPEED)
        end
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Sit and player.Character.Humanoid.SeatPart == seat then
            ensureBodyVelocity(-BOAT_SPEED)
        end
    end
end

-- ========== ПРОВЕРКА НА ЗАСТРЕВАНИЕ ==========
local function checkStuck()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local currentPos = hrp.Position
    if lastPosition then
        if (currentPos - lastPosition).Magnitude < 0.5 then
            stuckTimer = stuckTimer + 0.2
            if stuckTimer >= STUCK_TIMEOUT then
                print("Застревание: персонаж не двигается более " .. STUCK_TIMEOUT .. " секунд. Перезапуск процесса...")
                -- Сбрасываем лодку и заставляем перепокупать
                myBoat = nil
                seat = nil
                rootPart = nil
                stopBoatMovement()
                stuckTimer = 0
            end
        else
            stuckTimer = 0
        end
    end
    lastPosition = currentPos
end

-- ========== ГЛАВНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        -- 1. Обновляем ссылки на лодку (если она существует)
        if not myBoat or not myBoat.Parent then
            myBoat = findMyBoat()
            if myBoat then
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if seat and rootPart then
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                else
                    myBoat = nil
                end
            end
        end

        -- 2. Если лодки нет, покупаем новую
        if not myBoat or not myBoat.Parent then
            print("Лодка отсутствует, перемещение к точке покупки...")
            moveCharacterTo(PURCHASE_POINT, WALK_SPEED)
            print("Покупка лодки...")
            local rs = game:GetService("ReplicatedStorage")
            local remotes = rs and rs:FindFirstChild("Remotes")
            local commF = remotes and remotes:FindFirstChild("CommF_")
            if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                print("Не удалось получить лодку, повтор через 5 сек")
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not rootPart then
                myBoat = nil
                continue
            end
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
        end

        -- 3. Проверка, сидит ли персонаж
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if not sitting then
            -- Не сидит: останавливаем движение и пытаемся сесть
            stopBoatMovement()
            if char and humanoid and seat then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    print("Посадка...")
                    sitOnSeat(seat, hrp, humanoid)
                end
            elseif not char then
                -- Персонаж мёртв, ждём появления
                print("Ожидание появления персонажа...")
                player.CharacterAdded:Wait()
            end
        else
            -- Сидит: обеспечиваем движение и обновляем направление
            local currentSpeed = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            ensureBodyVelocity(currentSpeed)
            updateDirection()
        end

        -- 4. Проверка на застревание
        checkStuck()

        task.wait(0.2)
    end
end)

print("Скрипт запущен. Многоуровневые проверки активны. Лодка будет восстанавливаться после любых сбоев.")
