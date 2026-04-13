-- ===== ФИНАЛЬНЫЙ СКРИПТ С НЕЗАВИСИМЫМ МОНИТОРОМ ПОСАДКИ =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_THRESHOLD_X = -77389
local BOAT_POINT_FAR = Vector3.new(-77389.3, 22.8, 32606.2)
local BOAT_POINT_NEAR = Vector3.new(-47968.4, 22.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.3

-- Глобальные флаги и данные
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local needToSit = false          -- флаг, что нужно выполнить посадку
local isSitting = false          -- флаг, что персонаж сидит (устанавливается монитором)
local boatExists = false

-- Вспомогательные функции
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

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

local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
    print("[TEAM] Marines выбрана")
    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then eventService:FireServer() end
end

-- Поиск своей лодки
local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local ownerAttr = boat:GetAttribute("Owner")
            if ownerAttr == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and (ownerObj:IsA("StringValue") or ownerObj:IsA("ObjectValue")) then
                if tostring(ownerObj.Value) == playerName then return boat end
            end
        end
    end
    return nil
end

-- Перемещение персонажа к точке (BodyVelocity)
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

-- Посадка на сиденье (BodyVelocity)
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

-- Остановка лодки (отмена Tween)
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

-- Запуск движения лодки (Tween к цели)
local function startBoatMovement()
    if not myBoat or not rootPart then return end
    stopBoat()
    local x = rootPart.Position.X
    local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
    local dist = (rootPart.Position - target).Magnitude
    local duration = dist / BOAT_SPEED
    if duration > 0 then
        currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
        currentTween:Play()
        currentTween.Completed:Connect(function()
            currentTween = nil
            -- Не запускаем следующий автоматически, монитор сам вызовет startBoatMovement при необходимости
        end)
    end
end

-- ===== НЕЗАВИСИМЫЙ МОНИТОР ПОСАДКИ (работает в фоне постоянно) =====
task.spawn(function()
    while not stopScript do
        -- Проверка острова
        local map = workspace:FindFirstChild("Map")
        if map and map:FindFirstChild("Prehistoricisland") then
            stopScript = true
            stopBoat()
            print("[ISLAND] Prehistoricisland найден, скрипт остановлен.")
            break
        end

        -- Определяем, сидит ли персонаж в своей лодке
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = humanoid and humanoid.Sit and humanoid.SeatPart == seat and seat and seat.Parent == myBoat
        isSitting = sitting

        if not sitting then
            -- Если не сидит, останавливаем лодку
            stopBoat()
            -- Устанавливаем флаг, что нужно сесть (главный цикл обработает)
            needToSit = true
        else
            -- Сидит – сбрасываем флаг необходимости посадки
            needToSit = false
        end

        -- Проверка существования лодки (обновляем myBoat, seat, rootPart)
        local currentBoat = findMyBoat()
        if currentBoat then
            if currentBoat ~= myBoat then
                myBoat = currentBoat
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                -- Отключаем коллизии у новой лодки
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                myBoat.DescendantAdded:Connect(function(desc)
                    if desc:IsA("BasePart") then desc.CanCollide = false end
                end)
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
                boatExists = true
            else
                boatExists = true
            end
        else
            boatExists = false
            myBoat = nil
            seat = nil
            rootPart = nil
        end

        task.wait(0.2) -- частота проверки
    end
end)

-- ===== ГЛАВНЫЙ ЦИКЛ (обрабатывает посадку и движение) =====
task.spawn(function()
    -- Первоначальная инициализация: выбор команды и перемещение к точке покупки
    selectMarines()
    task.wait(2)
    moveCharacterTo(MOVE_POINT, WALK_SPEED)

    while not stopScript do
        if needToSit then
            -- Нужно сесть в лодку
            if not boatExists then
                -- Лодки нет – покупаем
                print("[MAIN] Лодки нет, покупаем...")
                -- Перемещаемся к точке покупки (на случай, если мы отошли)
                moveCharacterTo(MOVE_POINT, WALK_SPEED)
                local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
                remote:InvokeServer("BuyBoat", "Guardian")
                task.wait(3)
                -- После покупки монитор сам обновит myBoat, seat, rootPart
                -- Дадим время монитору обновиться
                task.wait(1)
                -- Если лодка не появилась, продолжаем цикл (повторим покупку)
                if not boatExists then
                    task.wait(2)
                    continue
                end
            end

            -- Лодка есть, пытаемся сесть
            if seat and rootPart then
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChild("Humanoid")
                    if hrp and humanoid then
                        print("[MAIN] Пытаемся сесть на сиденье...")
                        sitOnSeat(seat, hrp, humanoid)
                        -- После посадки монитор установит isSitting = true, needToSit = false
                    end
                end
            end
        else
            -- Сидим в лодке – управляем движением
            if isSitting and boatExists and rootPart then
                startBoatMovement()
            else
                -- Если по какой-то причине не сидим, но флаг needToSit не установлен – принудительно установим
                if not isSitting then
                    needToSit = true
                end
            end
        end
        task.wait(0.3) -- частота проверки главного цикла
    end
end)

print("Скрипт запущен. Независимый монитор посадки активен.")
