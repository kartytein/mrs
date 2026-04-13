-- ===== ФИНАЛЬНЫЙ ИСПРАВЛЕННЫЙ СКРИПТ (ПОЛНАЯ АВТОМАТИЗАЦИЯ) =====
-- Постоянная проверка посадки, автоматическая покупка/поиск лодки, 
-- движение только когда сидишь, мгновенная остановка при вылезании.
-- Коллизии LowerTorso/UpperTorso периодически отключаются.

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

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local isSitting = false
local needToSit = true   -- изначально нужно сесть

-- ===== КОЛЛИЗИИ =====
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    print("[COLLISION] Все коллизии отключены")
end

local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent and not stopScript do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then
                lower.CanCollide = false
                print("[COLLISION] LowerTorso -> false")
            end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then
                upper.CanCollide = false
                print("[COLLISION] UpperTorso -> false")
            end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

-- ===== ВЫБОР КОМАНДЫ =====
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

-- ===== ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА =====
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
    print("[MOVE] Движение к", targetPos)

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

-- ===== ПОИСК СВОЕЙ ЛОДКИ =====
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

-- ===== ПОСАДКА НА СИДЕНЬЕ =====
local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)

    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local targetPos = targetCF.Position
    print("[SIT] Посадка к", targetPos)

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
    print("[SIT] Посадка успешна")
    return true
end

-- ===== УПРАВЛЕНИЕ ЛОДКОЙ =====
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
        print("[BOAT] Остановлена")
    end
end

local function updateBoatMovement()
    if not myBoat or not rootPart then return end
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    if isSitting then
        local x = rootPart.Position.X
        local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
        local dist = (rootPart.Position - target).Magnitude
        local duration = dist / BOAT_SPEED
        if duration > 0 then
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            print("[BOAT] Движение к", target)
            currentTween.Completed:Connect(function() currentTween = nil end)
        end
    end
end

-- ===== МОНИТОР ПОСАДКИ (ВЫВОДИТ СТАТУС КАЖДЫЕ 0.2 СЕК) =====
task.spawn(function()
    while not stopScript do
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end
        print("[CHECK] Сидит в лодке:", sitting)
        if sitting ~= isSitting then
            isSitting = sitting
            if isSitting then
                needToSit = false
                print("[STATUS] needToSit = false (сел)")
                updateBoatMovement()
            else
                needToSit = true
                stopBoat()
                print("[STATUS] needToSit = true (не сидит)")
            end
        end
        -- Если лодка пропала, сбрасываем
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil
            seat = nil
            rootPart = nil
            needToSit = true
            print("[STATUS] Лодка потеряна")
        end
        task.wait(0.2)
    end
end)

-- ===== ГЛАВНЫЙ ЦИКЛ =====
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        if needToSit then
            print("[MAIN] needToSit активен, начинаем посадку")

            -- 1. Проверяем, есть ли уже лодка (даже если myBoat == nil)
            local existingBoat = findMyBoat()
            if existingBoat then
                myBoat = existingBoat
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if seat and rootPart then
                    print("[MAIN] Найдена существующая лодка, используем её")
                    -- Убедимся, что коллизии лодки отключены
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    myBoat.DescendantAdded:Connect(function(desc)
                        if desc:IsA("BasePart") then desc.CanCollide = false end
                    end)
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                else
                    print("[MAIN] Найдена лодка, но нет сиденья или основной части")
                    myBoat = nil
                end
            end

            -- 2. Если лодки нет, покупаем
            if not myBoat or not myBoat.Parent then
                print("[MAIN] Лодки нет, перемещаемся к точке покупки")
                moveCharacterTo(MOVE_POINT, WALK_SPEED)
                print("[MAIN] Призыв лодки")
                local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
                remote:InvokeServer("BuyBoat", "Guardian")
                task.wait(3)
                for i = 1, 10 do
                    myBoat = findMyBoat()
                    if myBoat then break end
                    task.wait(1)
                end
                if not myBoat then
                    print("[MAIN] Не удалось призвать лодку, повтор через 5 сек")
                    task.wait(5)
                    continue
                end
                print("[MAIN] Лодка призвана:", myBoat.Name)
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if not seat or not rootPart then
                    print("[MAIN] Ошибка: нет сиденья/части")
                    myBoat = nil
                    continue
                end
                -- Отключаем коллизии лодки
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                myBoat.DescendantAdded:Connect(function(desc)
                    if desc:IsA("BasePart") then desc.CanCollide = false end
                end)
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- 3. Садимся на сиденье
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if hrp and humanoid then
                print("[MAIN] Запуск посадки")
                sitOnSeat(seat, hrp, humanoid)
                task.wait(0.5)
                if isSitting then
                    needToSit = false
                    print("[MAIN] Посадка подтверждена")
                else
                    print("[MAIN] Посадка не удалась, повтор")
                    task.wait(1)
                end
            else
                print("[MAIN] Нет персонажа, ждём")
                task.wait(1)
            end
        else
            -- Если сидим, управляем лодкой
            if isSitting and myBoat and rootPart then
                updateBoatMovement()
            end
            task.wait(0.3)
        end
    end
end)

print("Скрипт запущен. Каждые 0.2 секунды выводится [CHECK] Сидит в лодке: true/false.")
