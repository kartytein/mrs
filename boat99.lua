-- ===== ИТОГОВЫЙ РАБОЧИЙ СКРИПТ (ПОСАДКА, ДВИЖЕНИЕ, ВОЗВРАТ ПОСЛЕ СМЕРТИ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свои координаты)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)      -- где покупать лодку
local BOAT_X_MIN = -77389.3                               -- левая граница (дальняя)
local BOAT_X_MAX = -47968.4                               -- правая граница (ближняя)
local BOAT_SPEED = 250                                    -- скорость движения лодки (по X)
local WALK_SPEED = 150                                    -- скорость при посадке
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)                -- высота над сиденьем
local COLLISION_INTERVAL = 0.2                            -- частота отключения коллизий

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local charVelocity = nil          -- BodyVelocity персонажа (для движения лодки)
local isSitting = false
local needToSit = true
local currentDirection = -1       -- -1 = влево, 1 = вправо

-- ========== 1. ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
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
    if not remotes then return end
    local commF = remotes:FindFirstChild("CommF_")
    if commF then
        commF:InvokeServer("SetTeam", "Marines")
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then event:FireServer() end
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

-- ========== 4. ПОИСК СВОЕЙ ЛОДКИ ==========
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

-- ========== 5. ПОСАДКА НА СИДЕНЬЕ (РАБОЧАЯ ВЕРСИЯ) ==========
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

-- ========== 6. УПРАВЛЕНИЕ ДВИЖЕНИЕМ ЛОДКИ (BODYVELOCITY НА ПЕРСОНАЖА) ==========
local function stopCharVelocity()
    if charVelocity then
        charVelocity:Destroy()
        charVelocity = nil
    end
end

local function setCharVelocity(speedX)
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

-- ========== 7. СМЕНА НАПРАВЛЕНИЯ ПО ГРАНИЦАМ X ==========
local function updateDirection()
    if not myBoat or not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        if isSitting then setCharVelocity(BOAT_SPEED) end
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        if isSitting then setCharVelocity(-BOAT_SPEED) end
    end
end

-- ========== 8. МОНИТОР ПОСАДКИ, ДВИЖЕНИЯ И ВОЗВРАТА ПОСЛЕ СМЕРТИ ==========
task.spawn(function()
    while not stopScript do
        local char = player.Character
        -- Если персонаж умер, ждём появления нового
        if not char then
            if isSitting then
                isSitting = false
                needToSit = true
                stopCharVelocity()
            end
            player.CharacterAdded:Wait()
            char = player.Character
            -- Сброс ссылок на лодку, чтобы заново её найти и сесть
            myBoat = nil
            seat = nil
            rootPart = nil
            needToSit = true
            task.wait(1)  -- даём время на загрузку
            continue
        end

        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if sitting then
            -- Сидит: запускаем движение, если ещё не запущено
            if not isSitting then
                isSitting = true
                needToSit = false
                setCharVelocity(currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED)
            end
            updateDirection()
        else
            -- Не сидит: останавливаем движение и, если лодка есть, начинаем посадку
            if isSitting then
                isSitting = false
                needToSit = true
                stopCharVelocity()
            end
            if myBoat and myBoat.Parent and seat then
                -- Если лодка существует, попробуем сесть заново
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if hrp and hum then
                    sitOnSeat(seat, hrp, hum)
                end
            else
                -- Лодка пропала – нужно будет перепокупать
                needToSit = true
            end
        end

        -- Если лодка исчезла, сбрасываем ссылки
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil
            seat = nil
            rootPart = nil
            needToSit = true
            stopCharVelocity()
        end

        task.wait(0.2)
    end
end)

-- ========== 9. ГЛАВНЫЙ ЦИКЛ (ПОКУПКА ЛОДКИ И ПЕРВАЯ ПОСАДКА) ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        -- Обновляем ссылку на лодку, если она уже существует
        local found = findMyBoat()
        if found and not myBoat then
            myBoat = found
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if seat and rootPart then
                -- Отключаем коллизии у лодки
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            else
                myBoat = nil
            end
        end

        if needToSit then
            -- Если лодки нет, покупаем новую
            if not myBoat or not myBoat.Parent then
                print("Перемещение к точке покупки...")
                moveCharacterTo(PURCHASE_POINT, WALK_SPEED)
                print("Покупка лодки...")
                local rs = game:GetService("ReplicatedStorage")
                local remotes = rs:FindFirstChild("Remotes")
                if remotes then
                    local commF = remotes:FindFirstChild("CommF_")
                    if commF then
                        pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end)
                    end
                end
                task.wait(3)
                -- Ищем лодку
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
                -- Отключаем коллизии у новой лодки
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- Садимся на сиденье
            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                if hrp and humanoid and myBoat and seat then
                    disableAllCollisions(char)
                    maintainCollisions(char)
                    sitOnSeat(seat, hrp, humanoid)
                    needToSit = false
                end
            end
            task.wait(0.5)
        else
            task.wait(0.3)
        end
    end
end)

print("Скрипт запущен. Посадка, движение и возврат после смерти работают.")
