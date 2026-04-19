-- ===== ФИНАЛЬНЫЙ СКРИПТ С ОБРАБОТКОЙ СМЕРТИ =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (при необходимости измените)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)      -- где покупать лодку
local BOAT_X_MIN = -77389.3                               -- левая граница (дальняя)
local BOAT_X_MAX = -47968.4                               -- правая граница (ближняя)
local BOAT_SPEED = 250                                    -- скорость лодки по X (положительная = вправо)
local WALK_SPEED = 150                                    -- скорость ходьбы/полёта
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)                -- высота над сиденьем
local COLLISION_INTERVAL = 0.2                            -- частота отключения коллизий

local stopScript = false
local myBoat = nil
local seat = nil
local charVelocity = nil          -- BodyVelocity персонажа
local isSitting = false
local needToSit = true
local currentDirection = -1       -- -1 = влево, 1 = вправо

-- ========== УПРАВЛЕНИЕ КОЛЛИЗИЯМИ ==========
local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent and not stopScript do
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
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- ========== ВЫБОР КОМАНДЫ ==========
local function selectMarines()
    local rs = game:GetService("ReplicatedStorage")
    local remote = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
    if remote then
        remote:InvokeServer("SetTeam", "Marines")
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then event:FireServer() end
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

-- ========== ПОИСК СВОЕЙ ЛОДКИ (ПО OWNER) ==========
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

-- ========== УПРАВЛЕНИЕ BODYVELOCITY ПЕРСОНАЖА ==========
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

-- ========== ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ ПО ГРАНИЦАМ ==========
local function updateDirection()
    if not myBoat then return end
    local root = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    local x = root.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        if isSitting then setCharVelocity(BOAT_SPEED) end
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        if isSitting then setCharVelocity(-BOAT_SPEED) end
    end
end

-- ========== МОНИТОР ПОСАДКИ И ДВИЖЕНИЯ (С ОБРАБОТКОЙ СМЕРТИ) ==========
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
            -- Обновляем ссылки на HRP и Humanoid
            local hrp = char:WaitForChild("HumanoidRootPart")
            local humanoid = char:WaitForChild("Humanoid")
            -- После смерти лодка может быть потеряна, сбросим флаги
            myBoat = nil
            seat = nil
            needToSit = true
            task.wait(1) -- небольшая задержка
            continue
        end

        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if sitting then
            if not isSitting then
                isSitting = true
                needToSit = false
                setCharVelocity(currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED)
            end
            updateDirection()
        else
            if isSitting then
                isSitting = false
                needToSit = true
                stopCharVelocity()
            end
            if not myBoat or not myBoat.Parent then
                stopCharVelocity()
            end
        end

        if myBoat and (not myBoat.Parent or not seat) then
            myBoat = nil
            seat = nil
            needToSit = true
            stopCharVelocity()
        end

        task.wait(0.2)
    end
end)

-- ========== ГЛАВНЫЙ ЦИКЛ (ПОКУПКА И ПОСАДКА) ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        -- Обновляем ссылку на лодку
        local found = findMyBoat()
        if found and not myBoat then
            myBoat = found
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            if seat then
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
            -- Если лодки нет, перемещаемся в точку покупки и покупаем
            if not myBoat or not myBoat.Parent then
                print("Перемещение к точке покупки...")
                moveCharacterTo(PURCHASE_POINT, WALK_SPEED)
                print("Покупка лодки...")
                local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
                remote:InvokeServer("BuyBoat", "Guardian")
                task.wait(3)
                for i = 1, 10 do
                    myBoat = findMyBoat()
                    if myBoat then break end
                    task.wait(1)
                end
                if not myBoat then
                    task.wait(5)
                    continue
                end
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                if not seat then
                    myBoat = nil
                    continue
                end
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- Посадка
            local char = player.Character
            if not char then
                task.wait(0.5)
                continue
            end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChild("Humanoid")
            if myBoat and seat and hrp and humanoid then
                disableAllCollisions(char)
                maintainCollisions(char)

                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp

                local targetCF = seat.CFrame + SEAT_OFFSET
                while needToSit and myBoat and myBoat.Parent and seat and hrp and hrp.Parent do
                    local direction = (targetCF.Position - hrp.Position).Unit
                    bv.Velocity = direction * WALK_SPEED
                    task.wait()
                    local hum = hrp.Parent and hrp.Parent:FindFirstChild("Humanoid")
                    if hum and hum.Sit and hum.SeatPart == seat then
                        break
                    end
                    targetCF = seat.CFrame + SEAT_OFFSET
                end
                bv:Destroy()
                if hrp and hrp.Parent then
                    hrp.CFrame = seat.CFrame + SEAT_OFFSET
                    if humanoid then humanoid.Sit = true end
                end
                needToSit = false
            else
                task.wait(0.5)
            end
        else
            task.wait(0.3)
        end
    end
end)

print("Скрипт запущен. Лодка движется между X=" .. BOAT_X_MIN .. " и X=" .. BOAT_X_MAX .. ". При смерти персонаж автоматически вернётся в лодку.")
