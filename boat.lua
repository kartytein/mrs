-- ===== ПОЛНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (финальная версия) =====
-- Автоматическое перемещение в точку, призыв/поиск лодки, посадка, циклическое движение,
-- возврат при сбросе/смерти, перепризыв при потере лодки, остановка при появлении острова.

local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- ===== НАСТРОЙКИ =====
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)          -- куда идти перед призывом
local BOAT_POINTS = {                                     -- маршрут лодки
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local WALK_SPEED = 150      -- скорость перемещения персонажа (студий/сек)
local BOAT_SPEED = 420       -- скорость лодки
local SUMMON_DELAY = 3       -- ждать после призыва
local STEP = 0.1             -- шаг обновления при перемещении

-- ===== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ =====
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentPoint = 1
local movementActive = false
local movementThread = nil

-- ===== ФУНКЦИЯ ПРОВЕРКИ ОСТРОВА =====
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

-- ===== ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА (ПЛАВНО, С ПОСТОЯННОЙ СКОРОСТЬЮ) =====
local function moveCharacterTo(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end

    -- Отключаем коллизии на время пути
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    while true do
        if checkIsland() then break end
        local current = hrp.Position
        local direction = (targetPos - current).Unit
        local distance = (targetPos - current).Magnitude
        if distance < 0.5 then break end
        local move = math.min(WALK_SPEED * STEP, distance)
        local newPos = current + direction * move
        hrp.CFrame = CFrame.new(newPos)
        task.wait(STEP)
    end
    hrp.CFrame = CFrame.new(targetPos)

    -- Восстанавливаем коллизии (необязательно, но оставим)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    return true
end

-- ===== ПОИСК ЛОДКИ ПО ВЛАДЕЛЬЦУ =====
local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            -- Атрибут Owner
            local ownerAttr = boat:GetAttribute("Owner")
            if ownerAttr == playerName then return boat end
            -- Объект Owner (StringValue / ObjectValue)
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and (ownerObj:IsA("StringValue") or ownerObj:IsA("ObjectValue")) then
                if tostring(ownerObj.Value) == playerName then return boat end
            end
        end
    end
    return nil
end

-- ===== ПОСАДКА НА СИДЕНЬЕ (ПЛАВНО, С ПОСТОЯННОЙ СКОРОСТЬЮ) =====
local function sitOnSeat()
    if not seat then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end

    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local targetPos = targetCF.Position
    local startPos = hrp.Position
    local distance = (startPos - targetPos).Magnitude
    if distance < 0.1 then
        humanoid.Sit = true
        return true
    end

    local speed = WALK_SPEED   -- та же скорость, что и при ходьбе
    local duration = distance / speed
    if duration <= 0 then duration = 0.1 end

    -- Отключаем коллизии персонажа
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.3)
    return true
end

-- ===== ЗАПУСК ЦИКЛИЧЕСКОГО ДВИЖЕНИЯ ЛОДКИ =====
local function startBoatMovement()
    if movementActive then return end
    movementActive = true
    movementThread = task.spawn(function()
        while not stopScript do
            -- Ждём, пока персонаж сидит на сиденье
            while not (player.Character and player.Character:FindFirstChild("Humanoid") and
                       player.Character.Humanoid.Sit and player.Character.Humanoid.SeatPart == seat) do
                if stopScript then break end
                task.wait(0.5)
            end
            if stopScript then break end
            if not myBoat or not myBoat.Parent then break end

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

-- ===== ОСТАНОВКА ДВИЖЕНИЯ =====
local function stopBoatMovement()
    if movementThread then
        task.cancel(movementThread)
        movementThread = nil
    end
    movementActive = false
end

-- ===== ОСНОВНАЯ ЛОГИКА =====
local function main()
    -- 1. Перемещение в точку
    print("[MAIN] Перемещение в точку", MOVE_POINT)
    moveCharacterTo(MOVE_POINT)
    if checkIsland() then return end

    -- 2. Проверяем, есть ли уже лодка
    myBoat = findMyBoat()
    if not myBoat then
        print("[MAIN] Лодки нет, призываем...")
        local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
        remote:InvokeServer("BuyBoat", "Guardian")
        task.wait(SUMMON_DELAY)
        for i = 1, 10 do
            myBoat = findMyBoat()
            if myBoat then break end
            task.wait(1)
            if checkIsland() then return end
        end
        if not myBoat then error("Не удалось призвать лодку") end
        print("[MAIN] Лодка призвана:", myBoat.Name)
    else
        print("[MAIN] Лодка уже существует:", myBoat.Name)
    end

    -- 3. Подготовка лодки и персонажа
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then error("Сиденье не найдено") end
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then error("Нет основной части") end

    -- Отключаем коллизии у лодки (навсегда)
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    myBoat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end)

    -- Отключаем коллизии у персонажа (пока в лодке)
    local char = player.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    -- Отключаем родной скрипт лодки
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- 4. Посадка
    print("[MAIN] Посадка на сиденье...")
    sitOnSeat()

    -- 5. Запуск движения
    startBoatMovement()
    print("[MAIN] Движение запущено")
end

-- ===== МОНИТОРИНГ СОСТОЯНИЯ (СБРОС, СМЕРТЬ, ПОТЕРЯ ЛОДКИ) =====
local function monitor()
    while not stopScript do
        task.wait(1)
        if checkIsland() then break end

        -- Проверка существования лодки
        if not myBoat or not myBoat.Parent then
            print("[MONITOR] Лодка потеряна, перезапуск...")
            stopBoatMovement()
            -- Возврат в начальную точку
            moveCharacterTo(MOVE_POINT)
            -- Призыв новой лодки
            local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
            remote:InvokeServer("BuyBoat", "Guardian")
            task.wait(SUMMON_DELAY)
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
                    sitOnSeat()
                    startBoatMovement()
                end
            else
                print("[MONITOR] Не удалось призвать новую лодку, повтор через 5 сек")
                task.wait(5)
            end
        else
            -- Проверка посадки
            local char = player.Character
            if not char then
                -- Персонаж умер
                print("[MONITOR] Персонаж умер, ожидание нового...")
                player.CharacterAdded:Wait()
                char = player.Character
                if char then
                    -- Обновляем ссылки
                    hrp = char:WaitForChild("HumanoidRootPart")
                    humanoid = char:WaitForChild("Humanoid")
                    -- Отключаем коллизии нового персонажа
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    sitOnSeat()
                end
            else
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and not (humanoid.Sit and humanoid.SeatPart == seat) then
                    print("[MONITOR] Сброс с сиденья, возвращаем...")
                    sitOnSeat()
                end
            end
        end
    end
end

-- ===== ЗАПУСК =====
task.spawn(main)
task.spawn(monitor)
print("Скрипт полностью загружен. Ожидание действий...")
