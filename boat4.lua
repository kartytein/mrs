-- ===== ИСПРАВЛЕННЫЙ СКРИПТ (постоянная попытка сесть, лодка останавливается) =====
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
local currentTween = nil          -- Tween лодки
local boatControlActive = false   -- флаг, что лодка под управлением

-- Коллизии
local function maintainCollisions(char)
    task.spawn(function()
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

-- Перемещение персонажа к точке (BodyVelocity)
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

-- Посадка на сиденье (BodyVelocity, с постоянной скоростью, бесконечная попытка)
local function sitOnSeatLoop()
    while not stopScript do
        -- Ждём, пока лодка и сиденье существуют
        if not myBoat or not seat then
            task.wait(0.5)
            continue
        end
        local char = player.Character
        if not char then
            player.CharacterAdded:Wait()
            char = player.Character
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then
            task.wait(0.5)
            continue
        end

        -- Если уже сидит на этом сиденье, выходим из цикла
        if humanoid.Sit and humanoid.SeatPart == seat then
            print("[SIT] Уже сидим, выход из цикла посадки")
            break
        end

        -- Пытаемся сесть
        disableAllCollisions(char)
        maintainCollisions(char)

        local targetCF = seat.CFrame + SEAT_OFFSET
        local targetPos = targetCF.Position

        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp

        local startTime = tick()
        while (hrp.Position - targetPos).Magnitude > 1.5 do
            if stopScript then break end
            -- Если персонаж умер или пропал, прерываем эту попытку и начнём новую
            if not player.Character or not hrp.Parent then
                break
            end
            local direction = (targetPos - hrp.Position).Unit
            bv.Velocity = direction * WALK_SPEED
            task.wait()
            -- Защита от бесконечного цикла (30 секунд максимум на одну попытку)
            if tick() - startTime > 30 then break
        end
        bv:Destroy()

        -- Проверяем, сел ли
        if humanoid.Sit and humanoid.SeatPart == seat then
            print("[SIT] Посадка успешна")
            break
        else
            print("[SIT] Не удалось сесть, повторяем...")
            task.wait(1)
        end
    end
end

-- Управление лодкой (запуск/остановка Tween)
local function updateBoatMovement()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid and humanoid.Sit and humanoid.SeatPart == seat and myBoat and rootPart then
        local x = rootPart.Position.X
        local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
        local dist = (rootPart.Position - target).Magnitude
        local duration = dist / BOAT_SPEED
        if duration > 0 then
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            currentTween.Completed:Connect(function()
                currentTween = nil
            end)
        end
    end
end

-- Мониторинг состояния (остров, посадка, движение лодки)
local function monitor()
    while not stopScript do
        task.wait(0.3)
        if stopScript then break end

        -- Проверка острова
        local map = workspace:FindFirstChild("Map")
        if map and map:FindFirstChild("Prehistoricisland") then
            stopScript = true
            if currentTween then currentTween:Cancel() end
            print("[STOP] Prehistoricisland найден, скрипт остановлен.")
            break
        end

        -- Если лодка потеряна, перезапускаем процесс
        if not myBoat or not myBoat.Parent then
            print("[MONITOR] Лодка потеряна, перезапуск...")
            if currentTween then currentTween:Cancel() end
            moveCharacterTo(MOVE_POINT, WALK_SPEED)
            local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
            remote:InvokeServer("BuyBoat", "Guardian")
            task.wait(3)
            myBoat = findMyBoat()
            if myBoat then
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
                    -- Запускаем цикл посадки заново
                    task.spawn(sitOnSeatLoop)
                end
            else
                task.wait(5)
            end
        else
            -- Управление лодкой: если сидим, запускаем движение; если нет – останавливаем
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart == seat then
                updateBoatMovement()
            else
                if currentTween then
                    currentTween:Cancel()
                    currentTween = nil
                    print("[BOAT] Остановлена (не сидит)")
                end
            end
        end
    end
end

-- Основной запуск
local function start()
    selectMarines()
    task.wait(2)

    moveCharacterTo(MOVE_POINT, WALK_SPEED)

    local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
    remote:InvokeServer("BuyBoat", "Guardian")
    print("[MAIN] Лодка призвана, ждём...")
    task.wait(3)

    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then error("Лодка не появилась") end
    print("[MAIN] Лодка найдена:", myBoat.Name)

    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then error("Нет сиденья") end
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then error("Нет основной части") end

    -- Отключаем коллизии у лодки
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    myBoat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end)

    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Запускаем цикл посадки (будет пытаться сесть, пока не сядет)
    task.spawn(sitOnSeatLoop)

    -- Запускаем монитор (остров, потеря лодки, движение)
    task.spawn(monitor)
end

start()
