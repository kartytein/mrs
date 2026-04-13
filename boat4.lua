-- ===== ФИНАЛЬНЫЙ СКРИПТ (Tween для лодки, BodyVelocity для посадки, параллельная остановка) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_THRESHOLD_X = -77389
local BOAT_POINT_FAR = Vector3.new(-77389.3, 22.8, 32606.2)
local BOAT_POINT_NEAR = Vector3.new(-47968.4, 22.8, 6048.2)
local WALK_SPEED = 150        -- скорость перемещения персонажа (BodyVelocity)
local BOAT_SPEED = 420         -- скорость лодки (Tween)
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)  -- высота над сиденьем
local COLLISION_INTERVAL = 0.3

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local collisionThread = nil

-- Поддержание CanCollide для LowerTorso/UpperTorso (периодическое)
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

-- Отключение всех коллизий персонажа (один раз)
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
    if eventService then eventService:FireServer() end
end

-- Проверка острова (для остановки всего скрипта)
local function checkIsland()
    if stopScript then return true end
    local map = workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Prehistoricisland") then
        stopScript = true
        print("[STOP] Prehistoricisland найден, скрипт остановлен.")
        return true
    end
    return false
end

-- Перемещение персонажа в точку через BodyVelocity (с постоянной скоростью)
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
    print("[MOVE] Перемещение завершено")
    return true
end

-- Поиск своей лодки по Owner
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

-- Посадка на сиденье через BodyVelocity (с постоянной скоростью, без рывков)
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
    print("[SIT] Посадка успешна")
    return true
end

-- Остановка движения лодки (прерывание Tween)
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    print("[BOAT] Движение остановлено")
end

-- Запуск движения лодки (Tween к целевой точке, с проверкой посадки)
local function startBoatMovement()
    task.spawn(function()
        while not stopScript and myBoat and myBoat.Parent do
            -- Ждём, пока персонаж сидит
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                stopBoat()
                task.wait(0.2)
                continue
            end
            -- Определяем цель по порогу X
            local x = rootPart.Position.X
            local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
            local dist = (rootPart.Position - target).Magnitude
            local duration = dist / BOAT_SPEED
            if duration > 0 then
                currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
                currentTween:Play()
                currentTween.Completed:Wait()
                currentTween = nil
            end
        end
    end)
end

-- Параллельный цикл: проверка посадки и возврат на сиденье (с учётом острова)
local function seatMonitor()
    while not stopScript do
        task.wait(0.5)
        if checkIsland() then
            -- Если остров появился, отключаем возврат на сиденье
            print("[MONITOR] Остров обнаружен, возврат на сиденье отключён")
            break
        end
        if not myBoat or not myBoat.Parent then
            continue
        end
        local char = player.Character
        if not char then
            -- Персонаж умер, ждём новый
            player.CharacterAdded:Wait()
            char = player.Character
            if char and seat then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                if hrp and humanoid then
                    disableAllCollisions(char)
                    maintainCollisions(char)
                    sitOnSeat(seat, hrp, humanoid)
                    -- После посадки движение лодки перезапустится в основном цикле
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

-- Основная логика
local function main()
    selectMarines()
    task.wait(2)
    if checkIsland() then return end

    print("[MAIN] Перемещение к точке покупки")
    moveCharacterTo(MOVE_POINT, WALK_SPEED)
    if checkIsland() then return end

    print("[MAIN] Призыв лодки")
    local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
    remote:InvokeServer("BuyBoat", "Guardian")
    task.wait(3)

    -- Поиск своей лодки
    myBoat = nil
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
        if checkIsland() then return end
    end
    if not myBoat then error("Лодка не найдена") end
    print("[MAIN] Лодка найдена:", myBoat.Name)

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
        disableAllCollisions(char)
        maintainCollisions(char)
    end

    -- Отключаем родной скрипт лодки
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then error("Нет HRP/Humanoid") end

    print("[MAIN] Посадка")
    sitOnSeat(seat, hrp, humanoid)

    print("[MAIN] Запуск движения лодки")
    startBoatMovement()
end

-- Запуск всех потоков
task.spawn(main)
task.spawn(seatMonitor)
print("Скрипт загружен. Лодка движется через Tween, посадка через BodyVelocity, возврат активен до появления острова.")
