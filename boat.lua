-- ===== ФИНАЛЬНЫЙ СКРИПТ (полная автоматизация: перемещение, призыв, посадка, возврат, перепризыв) =====
local player = game.Players.LocalPlayer
local tweenService = game:GetService("TweenService")

-- Константы
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)   -- точка для перемещения перед призывом
local BOAT_POINTS = {                              -- маршрут лодки
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local BOAT_SPEED = 420                             -- скорость лодки
local SUMMON_DELAY = 3                             -- задержка после призыва

-- Глобальные переменные
local myBoat = nil          -- текущая лодка
local seat = nil            -- сиденье лодки
local isMoving = false      -- флаг, что лодка движется (чтобы не запускать несколько раз)
local stopAll = false       -- флаг для остановки всего (если остров появится, но пока не используем)

-- Вспомогательная функция для отключения коллизий у модели
local function disableCollisions(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Функция плавного перемещения персонажа в точку (рабочий метод с частым переключением CanCollide)
local function moveCharacterTo(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end

    local speed = 150
    local step = 0.1

    -- Отключаем коллизии у персонажа
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    while true do
        local current = hrp.Position
        local direction = (targetPos - current).Unit
        local distance = (targetPos - current).Magnitude
        if distance < 0.5 then break end
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)

    -- Восстанавливаем коллизии (необязательно, можно оставить отключенными)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    return true
end

-- Функция призыва лодки
local function summonBoat()
    local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
    remote:InvokeServer("BuyBoat", "Guardian")
    print("[SUMMON] Лодка призвана")
end

-- Функция поиска своей лодки (по атрибуту Owner)
local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, model in ipairs(boatsFolder:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = model:GetAttribute("Owner")
            if owner and owner == player.Name then
                return model
            end
        end
    end
    return nil
end

-- Функция посадки на сиденье (с Tween)
local function sitOnSeat(boat)
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end

    -- Отключаем коллизии у персонажа (чтобы не застревать)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tween = tweenService:Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.5)
    return true
end

-- Функция запуска движения лодки по маршруту (циклически)
local function startBoatMovement(boat)
    if isMoving then return end
    isMoving = true
    local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then isMoving = false; return end
    local currentPoint = 1
    task.spawn(function()
        while myBoat and myBoat == boat and not stopAll do
            local target = BOAT_POINTS[currentPoint]
            local dist = (rootPart.Position - target).Magnitude
            local duration = dist / BOAT_SPEED
            local tween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            tween:Play()
            tween.Completed:Wait()
            currentPoint = currentPoint % #BOAT_POINTS + 1
        end
        isMoving = false
    end)
end

-- Основная логика: перемещение, призыв, поиск, посадка, движение
local function main()
    -- 1. Перемещение в точку
    print("[MAIN] Перемещение в точку", MOVE_POINT)
    moveCharacterTo(MOVE_POINT)
    task.wait(1)

    -- 2. Призыв лодки
    summonBoat()
    task.wait(SUMMON_DELAY)

    -- 3. Поиск своей лодки (с повторами)
    local boat = nil
    for i = 1, 10 do
        boat = findMyBoat()
        if boat then break end
        print("[MAIN] Ожидание лодки...", i)
        task.wait(1)
    end
    if not boat then
        warn("[MAIN] Лодка не найдена")
        return
    end
    myBoat = boat
    print("[MAIN] Лодка найдена:", myBoat.Name)

    -- Отключаем коллизии у лодки (навсегда)
    disableCollisions(myBoat)

    -- Отключаем родной скрипт лодки (если есть)
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- 4. Посадка
    local success = sitOnSeat(myBoat)
    if not success then
        warn("[MAIN] Не удалось сесть")
        return
    end
    print("[MAIN] Посадка выполнена")

    -- 5. Запуск движения лодки
    startBoatMovement(myBoat)
    print("[MAIN] Движение запущено")
end

-- Мониторинг состояния: если персонаж сброшен с сиденья или умер, сажаем обратно
local function monitorAndReseat()
    while not stopAll do
        task.wait(1)
        -- Если нет лодки, не пытаемся
        if not myBoat or not myBoat.Parent then
            -- Лодка удалена, нужно вернуться в точку и призвать новую
            print("[MONITOR] Лодка потеряна, перезапуск...")
            myBoat = nil
            isMoving = false
            -- Возвращаем персонажа в точку призыва
            moveCharacterTo(MOVE_POINT)
            -- Призываем новую лодку
            summonBoat()
            task.wait(SUMMON_DELAY)
            -- Ищем новую лодку
            local newBoat = nil
            for i = 1, 10 do
                newBoat = findMyBoat()
                if newBoat then break end
                task.wait(1)
            end
            if newBoat then
                myBoat = newBoat
                disableCollisions(myBoat)
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
                sitOnSeat(myBoat)
                startBoatMovement(myBoat)
            end
        else
            -- Проверяем, сидит ли персонаж на сиденье
            local char = player.Character
            if not char then
                -- Персонаж умер, ждём появления нового
                player.CharacterAdded:Wait()
                char = player.Character
                -- Обновляем ссылки и сажаем заново
                if myBoat and myBoat.Parent then
                    sitOnSeat(myBoat)
                end
            else
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and (not humanoid.Sit or humanoid.SeatPart ~= seat) then
                    print("[MONITOR] Сброс с сиденья, возвращаем...")
                    sitOnSeat(myBoat)
                end
            end
        end
    end
end

-- Запуск
task.spawn(main)
task.spawn(monitorAndReseat)
