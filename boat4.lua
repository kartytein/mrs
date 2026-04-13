-- ===== ФИНАЛЬНЫЙ СКРИПТ С ИНТЕРВАЛЬНОЙ ПРОВЕРКОЙ ПОСАДКИ =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_THRESHOLD_X = -77389
local BOAT_POINT_FAR = Vector3.new(-77389.3, 22.8, 32606.2)
local BOAT_POINT_NEAR = Vector3.new(-47968.4, 22.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)  -- чуть выше сиденья
local COLLISION_INTERVAL = 0.3

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local boatVelocity = nil
local collisionThread = nil
local isSitting = false  -- флаг, что персонаж сидит

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

-- Перемещение персонажа в точку (синхронное, с подтверждением)
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

    local lastDist = math.huge
    while (hrp.Position - targetPos).Magnitude > 2 do
        if stopScript then break end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * speed
        task.wait()
        local dist = (hrp.Position - targetPos).Magnitude
        if dist == lastDist then break end
        lastDist = dist
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    print("[MOVE] Перемещение завершено, позиция:", hrp.Position)
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

-- Посадка на сиденье (BodyVelocity, с запасом по высоте)
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
    print("[SIT] Посадка завершена")
    return true
end

-- Управление лодкой (BodyVelocity, остановка при вылезании)
local function startBoatControl()
    if boatVelocity then return end
    if not rootPart then return end

    boatVelocity = Instance.new("BodyVelocity")
    boatVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    boatVelocity.Parent = rootPart
    print("[BOAT] BodyVelocity создан")

    task.spawn(function()
        while boatVelocity and myBoat and myBoat.Parent and not stopScript do
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart == seat then
                isSitting = true
                -- Определяем цель по порогу X
                local x = rootPart.Position.X
                local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
                local direction = (target - rootPart.Position).Unit
                if boatVelocity then
                    boatVelocity.Velocity = direction * BOAT_SPEED
                end
            else
                isSitting = false
                -- Останавливаем лодку мгновенно
                if boatVelocity then
                    boatVelocity:Destroy()
                    boatVelocity = nil
                    print("[BOAT] Лодка остановлена (персонаж не сидит)")
                end
                break
            end
            task.wait(0.1)
        end
    end)
end

-- Принудительная остановка лодки
local function stopBoat()
    if boatVelocity then
        boatVelocity:Destroy()
        boatVelocity = nil
        print("[BOAT] Принудительная остановка лодки")
    end
end

-- Интервальная проверка: если персонаж не сидит, возвращаем его на сиденье
local function seatMonitor()
    while not stopScript do
        task.wait(0.5)
        if checkIsland() then break end
        if not myBoat or not myBoat.Parent then
            -- лодка потеряна, не проверяем
            continue
        end
        local char = player.Character
        if not char then
            -- персонаж умер, ждём появления и сажаем
            player.CharacterAdded:Wait()
            char = player.Character
            if char and seat then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                if hrp and humanoid then
                    disableAllCollisions(char)
                    maintainCollisions(char)
                    sitOnSeat(seat, hrp, humanoid)
                    -- перезапускаем управление лодкой, если оно остановлено
                    if not boatVelocity then
                        startBoatControl()
                    end
                end
            end
        else
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and not (humanoid.Sit and humanoid.SeatPart == seat) then
                print("[MONITOR] Сброс с сиденья, возвращаем...")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    sitOnSeat(seat, hrp, humanoid)
                    -- Если лодка остановлена, перезапускаем
                    if not boatVelocity then
                        startBoatControl()
                    end
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

    -- Перемещение к точке покупки (синхронное)
    print("[MAIN] Перемещение к точке покупки")
    local success = moveCharacterTo(MOVE_POINT, WALK_SPEED)
    if not success then
        error("Не удалось переместиться")
    end
    -- Дополнительная проверка точности
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.Position
        if (pos - MOVE_POINT).Magnitude > 3 then
            print("[MAIN] Перемещение не точно, повторяем")
            moveCharacterTo(MOVE_POINT, WALK_SPEED)
        end
    end
    if checkIsland() then return end

    -- Призыв лодки ТОЛЬКО после перемещения
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

    local char2 = player.Character
    if char2 then
        disableAllCollisions(char2)
        maintainCollisions(char2)
    end

    -- Отключаем родной скрипт лодки
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    local hrp = char2 and char2:FindFirstChild("HumanoidRootPart")
    local humanoid = char2 and char2:FindFirstChild("Humanoid")
    if not hrp or not humanoid then error("Нет HRP/Humanoid") end
    print("[MAIN] Посадка")
    sitOnSeat(seat, hrp, humanoid)

    print("[MAIN] Запуск управления лодкой")
    startBoatControl()
end

-- Запуск всех потоков
task.spawn(main)
task.spawn(seatMonitor)
print("Скрипт загружен. Лодка покупается после перемещения, посадка через BodyVelocity, мгновенная остановка при вылезании.")
