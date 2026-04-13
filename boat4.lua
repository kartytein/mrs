-- ===== ФИНАЛЬНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (ПОЛНАЯ АВТОМАТИЗАЦИЯ) =====
-- Постоянная проверка посадки, покупка лодки при необходимости, 
-- движение лодки только когда персонаж сидит, мгновенная остановка при вылезании.
-- Коллизии LowerTorso/UpperTorso периодически принудительно отключаются.

local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ (можно менять под свои нужды)
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)        -- где покупать лодку
local BOAT_THRESHOLD_X = -77389                         -- порог для смены направления
local BOAT_POINT_FAR = Vector3.new(-77389.3, 22.8, 32606.2)   -- дальняя точка
local BOAT_POINT_NEAR = Vector3.new(-47968.4, 22.8, 6048.2)    -- ближняя точка
local WALK_SPEED = 150                                  -- скорость ходьбы/полёта к сиденью
local BOAT_SPEED = 420                                  -- скорость лодки
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)              -- высота над сиденьем
local COLLISION_INTERVAL = 0.3                          -- частота принудительного отключения коллизий

-- Глобальные переменные
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local isSitting = false
local needToSit = true      -- изначально нужно сесть

-- ===== ФУНКЦИИ ДЛЯ КОЛЛИЗИЙ =====
-- Отключает коллизии у всех частей персонажа
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    print("[COLLISION] Все коллизии персонажа отключены")
end

-- Периодическое принудительное отключение коллизий у LowerTorso и UpperTorso
local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent and not stopScript do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then
                lower.CanCollide = false
                print("[COLLISION] LowerTorso принудительно false")
            end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then
                upper.CanCollide = false
                print("[COLLISION] UpperTorso принудительно false")
            end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

-- ===== ВЫБОР КОМАНДЫ MARINES =====
local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
    print("[TEAM] Команда Marines выбрана")
    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then
        eventService:FireServer()
        print("[TEAM] OnEventServiceActivity вызван")
    end
end

-- ===== ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА В ТОЧКУ (BODYVELOCITY) =====
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
    print("[MOVE] Начинаем движение к точке", targetPos)

    while (hrp.Position - targetPos).Magnitude > 2 do
        if stopScript then break end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    print("[MOVE] Достигнута точка", targetPos)
    return true
end

-- ===== ПОИСК СВОЕЙ ЛОДКИ ПО OWNER =====
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

-- ===== ПОСАДКА НА СИДЕНЬЕ (BODYVELOCITY, ПОСТОЯННАЯ СКОРОСТЬ) =====
local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)

    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local targetPos = targetCF.Position
    print("[SIT] Начинаем посадку, цель", targetPos)

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
    task.wait(0.3)   -- фиксация посадки
    print("[SIT] Посадка успешна")
    return true
end

-- ===== УПРАВЛЕНИЕ ЛОДКОЙ (ОСТАНОВКА И ЗАПУСК TWEEN) =====
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
        print("[BOAT] Движение остановлено")
    end
end

local function updateBoatMovement()
    if not myBoat or not rootPart then return end
    -- Останавливаем предыдущий Tween
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    -- Если сидим, запускаем новый Tween к актуальной цели
    if isSitting then
        local x = rootPart.Position.X
        local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
        local dist = (rootPart.Position - target).Magnitude
        local duration = dist / BOAT_SPEED
        if duration > 0 then
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            print("[BOAT] Движение к точке", target)
            currentTween.Completed:Connect(function()
                currentTween = nil
            end)
        end
    end
end

-- ===== НЕПРЕРЫВНЫЙ МОНИТОР ПОСАДКИ (ОТДЕЛЬНЫЙ ПОТОК) =====
task.spawn(function()
    while not stopScript do
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end
        -- Вывод статуса каждые 0.2 секунды
        print("[CHECK] Сидит в лодке:", sitting)
        if sitting ~= isSitting then
            isSitting = sitting
            if isSitting then
                needToSit = false
                print("[STATUS] needToSit = false (персонаж сел)")
                -- При посадке запускаем движение лодки
                updateBoatMovement()
            else
                needToSit = true
                stopBoat()
                print("[STATUS] needToSit = true (персонаж не сидит)")
            end
        end
        -- Если лодка пропала, сбрасываем ссылки
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil
            seat = nil
            rootPart = nil
            needToSit = true
            print("[STATUS] Лодка потеряна, needToSit = true")
        end
        task.wait(0.2)
    end
end)

-- ===== ГЛАВНЫЙ ЦИКЛ (ВЫПОЛНЯЕТ ДЕЙСТВИЯ В ЗАВИСИМОСТИ ОТ needToSit) =====
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        if needToSit then
            print("[MAIN] Начинаем процесс посадки")
            -- Если нет лодки, покупаем
            if not myBoat or not myBoat.Parent then
                print("[MAIN] Лодка не найдена, перемещаемся к точке покупки")
                moveCharacterTo(MOVE_POINT, WALK_SPEED)
                print("[MAIN] Призываем лодку через CommF_")
                local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
                remote:InvokeServer("BuyBoat", "Guardian")
                print("[MAIN] Ожидание появления лодки...")
                task.wait(3)
                -- Ищем лодку до 10 секунд
                for i = 1, 10 do
                    myBoat = findMyBoat()
                    if myBoat then break end
                    task.wait(1)
                end
                if not myBoat then
                    print("[MAIN] Не удалось найти лодку, повтор через 5 сек")
                    task.wait(5)
                    continue
                end
                print("[MAIN] Лодка найдена:", myBoat.Name)
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if not seat or not rootPart then
                    print("[MAIN] Ошибка: нет сиденья или основной части")
                    myBoat = nil
                    continue
                end
                -- Отключаем коллизии у лодки навсегда
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                myBoat.DescendantAdded:Connect(function(desc)
                    if desc:IsA("BasePart") then desc.CanCollide = false end
                end)
                -- Отключаем родной скрипт лодки (если есть)
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- Пытаемся сесть на сиденье
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if hrp and humanoid then
                print("[MAIN] Запуск посадки")
                sitOnSeat(seat, hrp, humanoid)
                -- Небольшая задержка, чтобы монитор успел обновить isSitting
                task.wait(0.5)
                if isSitting then
                    needToSit = false
                    print("[MAIN] Посадка подтверждена, needToSit = false")
                else
                    print("[MAIN] Посадка не удалась, повтор через 1 сек")
                    task.wait(1)
                end
            else
                print("[MAIN] Нет персонажа или HRP, ждём появления")
                task.wait(1)
            end
        else
            -- Если сидим, управляем лодкой (периодически обновляем направление)
            if isSitting and myBoat and rootPart then
                updateBoatMovement()
            end
            task.wait(0.3)
        end
    end
end)

print("Скрипт запущен. Постоянная проверка посадки активна. Статус выводится каждые 0.2 сек.")
