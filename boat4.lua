-- ===== ФИНАЛЬНЫЙ СКРИПТ С ПОСТОЯННЫМ ПЕРИОДИЧЕСКИМ ОТКЛЮЧЕНИЕМ КОЛЛИЗИЙ =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)          -- где покупать лодку
local BOAT_POINTS = {                                     -- маршрут лодки
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local WALK_SPEED = 150        -- скорость ходьбы
local BOAT_SPEED = 420         -- скорость лодки
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)  -- высота над сиденьем
local COLLISION_INTERVAL = 0.3 -- интервал принудительного отключения коллизий (сек)

-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentPoint = 1
local movementThread = nil
local isMoving = false
local collisionThread = nil

-- ФУНКЦИЯ ПОДДЕРЖАНИЯ КОЛЛИЗИЙ ДЛЯ ПЕРСОНАЖА (периодическое отключение LowerTorso/UpperTorso)
local function maintainCollisions(char)
    if collisionThread then task.cancel(collisionThread) end
    collisionThread = task.spawn(function()
        while char and char.Parent and not stopScript do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") then
                lower.CanCollide = false
            end
            if upper and upper:IsA("BasePart") then
                upper.CanCollide = false
            end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

-- ФУНКЦИЯ ВЫБОРА КОМАНДЫ
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

-- ПРОВЕРКА ОСТРОВА
local function checkIsland()
    if stopScript then return true end
    local map = workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Prehistoricisland") then
        stopScript = true
        print("[STOP] Остров обнаружен, скрипт остановлен.")
        return true
    end
    return false
end

-- ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА ЧЕРЕЗ BODYVELOCITY (С ПОДДЕРЖАНИЕМ КОЛЛИЗИЙ)
local function moveCharacterTo(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    -- Отключаем коллизии у всех частей (один раз)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    -- Запускаем периодическое поддержание для LowerTorso/UpperTorso
    maintainCollisions(char)

    -- Создаём BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    while (hrp.Position - targetPos).Magnitude > 2 do
        if stopScript then break end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    print("[MOVE] Перемещение завершено")
    return true
end

-- ПОИСК ЛОДКИ ПО ВЛАДЕЛЬЦУ
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

-- ПОСАДКА НА СИДЕНЬЕ ЧЕРЕЗ BODYVELOCITY
local function sitOnSeat(seat, hrp, humanoid)
    local char = hrp.Parent
    if not char then return false end
    -- Отключаем коллизии у персонажа (уже отключены, но на всякий случай)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    maintainCollisions(char)

    local targetCF = seat.CFrame + SEAT_OFFSET
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

-- ЗАПУСК ДВИЖЕНИЯ ЛОДКИ (ТОЛЬКО КОГДА ПЕРСОНАЖ СИДИТ)
local function startBoatMovement()
    if isMoving then return end
    isMoving = true
    movementThread = task.spawn(function()
        while not stopScript and myBoat and myBoat.Parent do
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
        isMoving = false
        movementThread = nil
    end)
end

local function stopBoatMovement()
    if movementThread then task.cancel(movementThread); movementThread = nil end
    isMoving = false
end

-- ОСНОВНАЯ ЛОГИКА
local function main()
    selectMarines()
    task.wait(2)
    if checkIsland() then return end

    print("[MAIN] Перемещение к точке покупки")
    moveCharacterTo(MOVE_POINT)
    if checkIsland() then return end

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
        if not myBoat then error("Лодка не найдена") end
    end
    print("[MAIN] Лодка:", myBoat.Name)

    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then error("Нет сиденья") end
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then error("Нет основной части") end

    -- Отключаем коллизии у лодки навсегда
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    myBoat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end)

    local char = player.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        maintainCollisions(char)
    end

    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then error("Нет HRP/Humanoid") end
    print("[MAIN] Посадка")
    sitOnSeat(seat, hrp, humanoid)

    startBoatMovement()
    print("[MAIN] Движение запущено")
end

-- МОНИТОРИНГ СБРОСА, СМЕРТИ, ПОТЕРИ ЛОДКИ
local function monitor()
    while not stopScript do
        task.wait(0.5)
        if checkIsland() then break end

        if not myBoat or not myBoat.Parent then
            print("[MONITOR] Лодка потеряна, перезапуск...")
            stopBoatMovement()
            moveCharacterTo(MOVE_POINT)
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
                task.wait(5)
            end
        else
            local char = player.Character
            if not char then
                print("[MONITOR] Персонаж умер, ожидание...")
                player.CharacterAdded:Wait()
                char = player.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
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
                    print("[MONITOR] Сброс, возврат")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        sitOnSeat(seat, hrp, humanoid)
                    end
                end
            end
        end
    end
end

task.spawn(main)
task.spawn(monitor)
print("Скрипт запущен. Поддержание коллизий активно.")
