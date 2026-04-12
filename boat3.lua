-- ===== ПОЛНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (С РАБОЧЕЙ ПОСАДКОЙ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)          -- точка перед призывом
local BOAT_POINTS = {                                     -- маршрут лодки
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local WALK_SPEED = 150        -- скорость ходьбы
local BOAT_SPEED = 420         -- скорость лодки
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)  -- высота над сиденьем
local SIT_DURATION = 1.5       -- максимум секунд на посадку

-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentPoint = 1
local movementThread = nil
local isMoving = false

-- ФУНКЦИЯ ПРОВЕРКИ ОСТРОВА (опционально)
local function checkIsland()
    if stopScript then return true end
    local map = workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Prehistoricisland") then
        stopScript = true
        print("[ОСТРОВ] Обнаружен Prehistoricisland, скрипт остановлен.")
        return true
    end
    return false
end

-- ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА (TWEEN)
local function moveCharacterTo(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    humanoid.PlatformStand = true

    local distance = (hrp.Position - targetPos).Magnitude
    local duration = distance / WALK_SPEED
    if duration < 0.1 then duration = 0.1 end

    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = targetPos})
    tween:Play()
    tween.Completed:Wait()
    hrp.CFrame = CFrame.new(targetPos)
    humanoid.PlatformStand = false
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

-- ПОСАДКА НА СИДЕНЬЕ (РАБОЧИЙ TWEEN)
local function sitOnSeat(seat, hrp, humanoid)
    local char = hrp.Parent
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    humanoid.PlatformStand = true

    local targetCF = seat.CFrame + SEAT_OFFSET
    local distance = (hrp.Position - targetCF.Position).Magnitude
    local duration = math.min(distance / WALK_SPEED, SIT_DURATION)
    if duration < 0.2 then duration = 0.2 end

    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    task.wait(0.2)
    humanoid.Sit = true
    humanoid.PlatformStand = false
end

-- ЗАПУСК ЦИКЛИЧЕСКОГО ДВИЖЕНИЯ ЛОДКИ
local function startBoatMovement()
    if isMoving then return end
    isMoving = true
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
        isMoving = false
        movementThread = nil
    end)
end

-- ОСТАНОВКА ДВИЖЕНИЯ
local function stopBoatMovement()
    if movementThread then
        task.cancel(movementThread)
        movementThread = nil
    end
    isMoving = false
end

-- ОСНОВНАЯ ЛОГИКА
local function main()
    -- Перемещение в точку (если нужно)
    print("[MAIN] Перемещение в точку", MOVE_POINT)
    moveCharacterTo(MOVE_POINT)
    if checkIsland() then return end

    -- Поиск или призыв лодки
    myBoat = findMyBoat()
    if not myBoat then
        print("[MAIN] Лодки нет, призываем...")
        local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
        remote:InvokeServer("BuyBoat", "Guardian")
        task.wait(3)
        for i = 1, 10 do
            myBoat = findMyBoat()
            if myBoat then break end
            task.wait(1)
            if checkIsland() then return end
        end
        if not myBoat then error("[MAIN] Не удалось призвать лодку") end
        print("[MAIN] Лодка призвана:", myBoat.Name)
    else
        print("[MAIN] Лодка уже существует:", myBoat.Name)
    end

    -- Получаем компоненты
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then error("[MAIN] Нет сиденья") end
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then error("[MAIN] Нет основной части") end

    -- Отключаем коллизии у лодки (навсегда)
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    myBoat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end)

    -- Отключаем коллизии у персонажа (навсегда)
    local char = player.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    -- Отключаем родной скрипт лодки
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Посадка
    print("[MAIN] Посадка на сиденье...")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then error("[MAIN] Нет HRP или Humanoid") end
    sitOnSeat(seat, hrp, humanoid)
    print("[MAIN] Посадка выполнена")

    -- Запуск движения
    startBoatMovement()
    print("[MAIN] Движение запущено")
end

-- МОНИТОРИНГ СБРОСА, СМЕРТИ, ПОТЕРИ ЛОДКИ
local function monitor()
    while not stopScript do
        task.wait(0.5)
        if checkIsland() then break end

        -- Лодка исчезла?
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
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChild("Humanoid")
                    if hrp and humanoid then
                        sitOnSeat(seat, hrp, humanoid)
                    end
                end
            else
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and not (humanoid.Sit and humanoid.SeatPart == seat) then
                    print("[MONITOR] Сброс с сиденья, возвращаем...")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        sitOnSeat(seat, hrp, humanoid)
                    end
                end
            end
        end
    end
end

-- ЗАПУСК
task.spawn(main)
task.spawn(monitor)
print("Скрипт полностью загружен. Ожидание действий...")
