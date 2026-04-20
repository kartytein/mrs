-- ===== ФИНАЛЬНЫЙ СКРИПТ С ПЕРЕСОЗДАНИЕМ ПОСЛЕ СМЕРТИ =====
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
local currentDirection = -1
local isSitting = false
local needToSit = true
local needToMove = true

local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

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

-- ========== ПЕРЕМЕЩЕНИЕ К ТОЧКЕ ==========
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

-- ========== ПОКУПКА НОВОЙ ЛОДКИ ==========
local function buyNewBoat()
    log("Покупка новой лодки...")
    moveToPoint(PURCHASE_POINT, WALK_SPEED)
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
    task.wait(3)
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then return false end
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then
        myBoat = nil
        return false
    end
    -- Отключаем коллизии лодки и её скрипт
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end
    return true
end

-- ========== ПОСАДКА ==========
local function sitOnSeat()
    if not seat then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end
    disableAllCollisions(char)
    maintainCollisions(char)
    local targetCF = seat.CFrame + SEAT_OFFSET
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
    return true
end

-- ========== ДВИЖЕНИЕ ЛОДКИ ==========
local function stopBoat()
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then bv:Destroy() end
        end
    end
end

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
        log("BodyVelocity создан, скорость " .. speedX)
    end
end

-- ========== ГЛАВНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание появления персонажа
        if not player.Character then
            log("Персонаж умер, ожидание...")
            player.CharacterAdded:Wait()
            log("Персонаж появился, сброс состояния")
            -- Полный сброс: лодка, возможно, осталась, но мы пересоздадим всё заново
            myBoat = nil
            seat = nil
            rootPart = nil
            isSitting = false
            needToSit = true
            needToMove = true
            stopBoat()
            task.wait(1)
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if not humanoid then
            task.wait(0.1)
            continue
        end

        -- 1. Если лодки нет или она исчезла, покупаем новую
        if not myBoat or not myBoat.Parent then
            log("Лодка отсутствует, запуск процесса покупки")
            if not buyNewBoat() then
                log("Не удалось купить лодку, повтор через 5 сек")
                task.wait(5)
                continue
            end
            needToSit = true
            needToMove = true
        end

        -- 2. Если не сидим, садимся
        if not (humanoid.Sit and humanoid.SeatPart == seat) then
            if needToSit then
                log("Попытка сесть на сиденье")
                if sitOnSeat() then
                    isSitting = true
                    needToSit = false
                    log("Успешно сел")
                else
                    log("Посадка не удалась, повтор через 0.5 сек")
                    task.wait(0.5)
                    continue
                end
            else
                isSitting = false
                needToSit = true
                stopBoat()
            end
        end

        -- 3. Если сидим, управляем движением
        if isSitting then
            -- Обновляем направление по X лодки
            local x = rootPart.Position.X
            if x <= BOAT_X_MIN and currentDirection == -1 then
                currentDirection = 1
                log("Смена направления вправо")
            elseif x >= BOAT_X_MAX and currentDirection == 1 then
                currentDirection = -1
                log("Смена направления влево")
            end
            local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            setBoatSpeed(speedX)
        end

        task.wait(0.1)
    end
end)

log("Скрипт запущен. После смерти всё пересоздаётся.")
