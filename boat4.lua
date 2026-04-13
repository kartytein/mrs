-- ===== ФИНАЛЬНЫЙ СКРИПТ С РАБОЧИМ TWEEN ДВИЖЕНИЕМ И ПОСАДКОЙ =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_THRESHOLD_X = -77389   -- порог
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
local currentBoatTween = nil
local movementActive = false
local movementThread = nil
local collisionThread = nil

-- Поддержание CanCollide для LowerTorso/UpperTorso
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

local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

-- Выбор команды
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

-- Проверка острова
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

-- Перемещение персонажа через BodyVelocity (старый рабочий метод)
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

-- Посадка на сиденье (старый рабочий Tween, который нормально садился)
local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)

    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local distance = (hrp.Position - targetCF.Position).Magnitude
    local duration = math.min(distance / WALK_SPEED, 1.5)
    if duration < 0.2 then duration = 0.2 end

    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.3)
    return true
end

-- Остановка движения лодки (мгновенно)
local function stopBoatMovement()
    if currentBoatTween then
        currentBoatTween:Cancel()
        currentBoatTween = nil
    end
    if movementThread then
        task.cancel(movementThread)
        movementThread = nil
    end
    movementActive = false
    print("[BOAT] Движение остановлено")
end

-- Запуск движения лодки (цикл с Tween, с проверкой посадки и логикой по X)
local function startBoatMovement()
    if movementActive then return end
    movementActive = true
    movementThread = task.spawn(function()
        while not stopScript and myBoat and myBoat.Parent do
            -- Ждём, пока персонаж сидит
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                -- Если не сидит, останавливаем текущий Tween
                if currentBoatTween then
                    currentBoatTween:Cancel()
                    currentBoatTween = nil
                end
                task.wait(0.5)
                continue
            end
            -- Определяем цель по порогу X
            local x = rootPart.Position.X
            local targetPoint
            if x < BOAT_THRESHOLD_X then
                targetPoint = BOAT_POINT_NEAR
            else
                targetPoint = BOAT_POINT_FAR
            end
            local dist = (rootPart.Position - targetPoint).Magnitude
            if dist < 10 then
                -- Уже рядом, ждём немного
                task.wait(1)
                continue
            end
            local duration = dist / BOAT_SPEED
            if duration > 0 then
                currentBoatTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPoint)})
                currentBoatTween:Play()
                currentBoatTween.Completed:Wait()
                currentBoatTween = nil
            end
        end
        movementActive = false
        movementThread = nil
    end)
end

-- Основная логика
local function main()
    selectMarines()
    task.wait(2)
    if checkIsland() then return end

    print("[MAIN] Перемещение к точке покупки")
    moveCharacterTo(MOVE_POINT, WALK_SPEED)
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
        if not myBoat then error("Лодка не появилась") end
        print("[MAIN] Лодка призвана:", myBoat.Name)
    else
        print("[MAIN] Лодка уже существует:", myBoat.Name)
    end

    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then error("Сиденье не найдено") end
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then error("Основная часть не найдена") end

    -- Отключаем коллизии у лодки
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

    startBoatMovement()
    print("[MAIN] Движение запущено")
end

-- Мониторинг сброса, смерти, потери лодки
local function monitor()
    while not stopScript do
        task.wait(0.5)
        if checkIsland() then break end

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
                task.wait(5)
            end
        else
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

task.spawn(main)
task.spawn(monitor)
print("Скрипт загружен. Движение лодки через Tween, посадка через Tween, логика по X.")
