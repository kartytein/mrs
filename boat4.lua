-- ===== ИТОГОВЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (ИСПРАВЛЕННЫЙ) =====
-- Выбор команды Marines, перемещение в точку, призыв лодки (один раз), посадка,
-- циклическое движение лодки, мгновенная остановка при вылезании,
-- возврат на сиденье при сбросе/смерти, перепризыв при потере лодки,
-- остановка при появлении Prehistoricisland.

local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- ===== НАСТРОЙКИ =====
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)          -- точка покупки
local BOAT_POINTS = {                                     -- маршрут лодки
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local WALK_SPEED = 150        -- скорость персонажа
local BOAT_SPEED = 420         -- скорость лодки
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)  -- высота над сиденьем
local COLLISION_INTERVAL = 0.3 -- частота принудительного отключения коллизий (для нижней/верхней части)

-- ===== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ =====
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentPoint = 1
local movementActive = false
local movementThread = nil
local collisionThread = nil

-- ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

-- Поддержание CanCollide = false для LowerTorso/UpperTorso (периодически)
local function maintainCollisions(char)
    if collisionThread then task.cancel(collisionThread) end
    collisionThread = task.spawn(function()
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

-- Отключение коллизий у всех частей персонажа (один раз)
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Выбор команды Marines
local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
    print("[TEAM] Marines выбрана")
    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then
        eventService:FireServer()
        print("[TEAM] OnEventServiceActivity вызван")
    end
end

-- Проверка появления острова (для остановки)
local function checkIsland()
    if stopScript then return true end
    local map = workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Prehistoricisland") then
        stopScript = true
        print("[STOP] Обнаружен Prehistoricisland, скрипт остановлен.")
        return true
    end
    return false
end

-- ===== ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА ЧЕРЕЗ BODYVELOCITY =====
local function moveCharacterTo(targetPos, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    -- Отключаем коллизии у всех частей и запускаем периодическое поддержание
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
    print("[MOVE] Перемещение в точку завершено")
    return true
end

-- ===== ПОИСК ЛОДКИ ПО ВЛАДЕЛЬЦУ =====
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

-- ===== ПОСАДКА НА СИДЕНЬЕ ЧЕРЕЗ BODYVELOCITY (БЕЗ ПАДЕНИЙ) =====
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

    -- Двигаемся к сиденью
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

-- ===== УПРАВЛЕНИЕ ЛОДКОЙ (ЦИКЛИЧЕСКОЕ ДВИЖЕНИЕ) =====
local function startBoatMovement()
    if movementActive then return end
    movementActive = true
    movementThread = task.spawn(function()
        while not stopScript and myBoat and myBoat.Parent do
            -- Ждём, пока персонаж сидит на этом сиденье
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                task.wait(0.5)
                continue
            end
            local target = BOAT_POINTS[currentPoint]
            local dist = (rootPart.Position - target).Magnitude
            local duration = dist / BOAT_SPEED
            if duration > 0 then
                local tween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
                tween:Play()
                tween.Completed:Wait()
            end
            currentPoint = currentPoint % #BOAT_POINTS + 1
        end
        movementActive = false
        movementThread = nil
    end)
end

local function stopBoatMovement()
    if movementThread then
        task.cancel(movementThread)
        movementThread = nil
    end
    movementActive = false
end

-- ===== ОСНОВНАЯ ЛОГИКА =====
local function main()
    -- Выбор команды
    selectMarines()
    task.wait(2)
    if checkIsland() then return end

    -- Перемещение в точку покупки
    print("[MAIN] Перемещение к точке покупки")
    moveCharacterTo(MOVE_POINT, WALK_SPEED)
    if checkIsland() then return end

    -- Поиск или призыв лодки (только один раз)
    myBoat = findMyBoat()
    if not myBoat then
        print("[MAIN] Призыв лодки")
        local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
        remote:InvokeServer("BuyBoat", "Guardian")
        task.wait(3)
        for i = 1, 10 do
            myBoat = findMyBoat()
            if myBoat then break end
            task.wait(1)
            if checkIsland() then return end
        end
        if not myBoat then error("Лодка не появилась") end
        print("[MAIN] Лодка призвана:", myBoat.Name)
    else
        print("[MAIN] Лодка уже существует:", myBoat.Name)
    end

    -- Получение компонентов лодки
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then error("Сиденье не найдено") end
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then error("Основная часть не найдена") end

    -- Отключаем коллизии у лодки навсегда
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    myBoat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end)

    -- Отключаем коллизии у персонажа и запускаем поддержание
    local char = player.Character
    if char then
        disableAllCollisions(char)
        maintainCollisions(char)
    end

    -- Отключаем родной скрипт лодки
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Посадка
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then error("Нет HRP или Humanoid") end
    print("[MAIN] Посадка на сиденье")
    sitOnSeat(seat, hrp, humanoid)

    -- Запуск движения
    startBoatMovement()
    print("[MAIN] Движение запущено")
end

-- ===== МОНИТОРИНГ СОСТОЯНИЯ (СБРОС, СМЕРТЬ, ПОТЕРЯ ЛОДКИ) =====
local function monitor()
    while not stopScript do
        task.wait(0.5)
        if checkIsland() then break end

        -- Если лодка исчезла
        if not myBoat or not myBoat.Parent then
            print("[MONITOR] Лодка потеряна, перезапуск...")
            stopBoatMovement()
            moveCharacterTo(MOVE_POINT, WALK_SPEED)
            local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
            remote:InvokeServer("BuyBoat", "Guardian")
            task.wait(3)
            local newBoat = nil
            for i = 1, 10 do
                newBoat = findMyBoat()
                if newBoat then break end
                task.wait(1)
                if checkIsland() then break end
            end
            if newBoat then
                myBoat = newBoat
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if seat and rootPart then
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    myBoat.DescendantAdded:Connect(function(desc)
                        if desc:IsA("BasePart") then desc.CanCollide = false end
                    end)
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                    local char = player.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        local humanoid = char:FindFirstChild("Humanoid")
                        if hrp and humanoid then
                            sitOnSeat(seat, hrp, humanoid)
                            startBoatMovement()
                        end
                    end
                end
            else
                print("[MONITOR] Не удалось призвать новую лодку, повтор через 5 сек")
                task.wait(5)
            end
        else
            -- Проверка, сидит ли персонаж
            local char = player.Character
            if not char then
                print("[MONITOR] Персонаж умер, ожидание...")
                player.CharacterAdded:Wait()
                char = player.Character
                if char then
                    disableAllCollisions(char)
                    maintainCollisions(char)
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChild("Humanoid")
                    if hrp and humanoid then
                        sitOnSeat(seat, hrp, humanoid)
                    end
                end
            else
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and not (humanoid.Sit and humanoid.SeatPart == seat) then
                    print("[MONITOR] Сброс с сиденья, возврат...")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        sitOnSeat(seat, hrp, humanoid)
                    end
                end
            end
        end
    end
end

-- ===== ЗАПУСК =====
task.spawn(main)
task.spawn(monitor)
print("Скрипт успешно загружен. Ожидание...")
