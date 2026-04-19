-- ===== ФИНАЛЬНЫЙ СКРИПТ С НЕПРЕРЫВНЫМ МОНИТОРИНГОМ ПОСАДКИ И ДВИЖЕНИЯ =====
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

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local charVelocity = nil
local currentDirection = -1   -- -1 = влево, 1 = вправо

-- ========== 1. КОЛЛИЗИИ ==========
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

-- ========== 2. ВЫБОР КОМАНДЫ ==========
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

-- ========== 3. ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА К ТОЧКЕ ==========
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

-- ========== 4. ПОИСК СВОЕЙ ЛОДКИ (ПО OWNER) ==========
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

-- ========== 5. ПОСАДКА НА СИДЕНЬЕ ==========
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

-- ========== 6. УПРАВЛЕНИЕ ДВИЖЕНИЕМ ЛОДКИ ==========
local function stopBoatMovement()
    if charVelocity then
        charVelocity:Destroy()
        charVelocity = nil
    end
end

local function setBoatSpeed(speedX)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not charVelocity then
        charVelocity = Instance.new("BodyVelocity")
        charVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        charVelocity.Parent = hrp
    end
    charVelocity.Velocity = Vector3.new(speedX, 0, 0)
end

-- ========== 7. ГЛАВНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ (МОНИТОРИНГ ПОСАДКИ И ДВИЖЕНИЯ) ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        -- 1. Обновляем ссылки на лодку
        local found = findMyBoat()
        if found then
            if myBoat ~= found then
                myBoat = found
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if seat and rootPart then
                    -- Отключаем коллизии лодки
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                else
                    myBoat = nil
                end
            end
        else
            if myBoat then
                myBoat = nil
                seat = nil
                rootPart = nil
                stopBoatMovement()
            end
        end

        -- 2. Если лодки нет, покупаем
        if not myBoat or not myBoat.Parent then
            print("Лодка не найдена, перемещаемся к точке покупки...")
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
                print("Не удалось призвать лодку, повтор через 5 сек")
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

        -- 3. Проверяем, сидит ли персонаж на сиденье
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if sitting then
            -- Сидит: обеспечиваем движение
            if not charVelocity then
                setBoatSpeed(currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED)
            end
            -- Обновляем направление по X лодки
            if rootPart then
                local x = rootPart.Position.X
                if x <= BOAT_X_MIN and currentDirection == -1 then
                    currentDirection = 1
                    setBoatSpeed(BOAT_SPEED)
                elseif x >= BOAT_X_MAX and currentDirection == 1 then
                    currentDirection = -1
                    setBoatSpeed(-BOAT_SPEED)
                end
            end
        else
            -- Не сидит: останавливаем движение и пытаемся сесть
            stopBoatMovement()
            if myBoat and seat and char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if hrp and hum then
                    print("Попытка сесть на сиденье...")
                    sitOnSeat(seat, hrp, hum)
                end
            elseif not char then
                -- Персонаж мёртв, ждём появления
                print("Персонаж мёртв, ожидание...")
                player.CharacterAdded:Wait()
                print("Персонаж появился, продолжаем")
            end
        end

        task.wait(0.2)
    end
end)

print("Скрипт запущен. Лодка будет двигаться непрерывно между X=" .. BOAT_X_MIN .. " и X=" .. BOAT_X_MAX)
