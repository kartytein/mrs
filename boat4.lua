-- ===== АБСОЛЮТНО НАДЁЖНЫЙ СКРИПТ С НЕПРЕРЫВНОЙ ПРОВЕРКОЙ ПОСАДКИ =====
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
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)   -- высота над сиденьем
local COLLISION_INTERVAL = 0.3

-- Глобальные переменные для управления движением лодки
local myBoat = nil
local seat = nil
local rootPart = nil
local boatTween = nil
local boatMoving = false
local shouldMove = false   -- флаг, разрешающий движение лодки (управляется из главного цикла)

-- Вспомогательные функции для коллизий (как в эталоне)
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent do
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

-- Выбор команды Marines (один раз в начале)
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

-- Перемещение персонажа к точке (BodyVelocity, синхронное)
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
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    print("[MOVE] Перемещение в точку завершено")
    return true
end

-- Призыв лодки (покупка)
local function buyBoat()
    local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
    if not remote then error("CommF_ не найден") end
    remote:InvokeServer("BuyBoat", "Guardian")
    print("[BUY] Лодка призвана")
    task.wait(3)
end

-- Функция, которая заставляет персонажа сесть на сиденье (использует BodyVelocity, бесконечно пытается)
local function forceSitOnSeat(boatSeat, hrp, humanoid)
    if not boatSeat or not hrp or not humanoid then return false end
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)

    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local targetPos = targetCF.Position

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    -- Двигаемся, пока не сядем
    while (hrp.Position - targetPos).Magnitude > 1.5 do
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    print("[SIT] Посадка выполнена")
    return true
end

-- Остановка движения лодки (отмена Tween)
local function stopBoatMovement()
    if boatTween then
        boatTween:Cancel()
        boatTween = nil
    end
    boatMoving = false
    print("[BOAT] Движение остановлено")
end

-- Запуск движения лодки (Tween) – будет вызываться из главного цикла, если shouldMove = true
local function startBoatMovement()
    if not shouldMove then
        stopBoatMovement()
        return
    end
    if boatMoving then return end
    if not myBoat or not rootPart then return end
    boatMoving = true
    task.spawn(function()
        while shouldMove and myBoat and myBoat.Parent do
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                break  -- выйдем из цикла, движение остановится
            end
            local x = rootPart.Position.X
            local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
            local dist = (rootPart.Position - target).Magnitude
            local duration = dist / BOAT_SPEED
            if duration > 0 then
                boatTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
                boatTween:Play()
                boatTween.Completed:Wait()
                boatTween = nil
            end
        end
        stopBoatMovement()
    end)
end

-- ===== ГЛАВНЫЙ ЦИКЛ, КОТОРЫЙ НИКОГДА НЕ ПРЕРЫВАЕТСЯ =====
local function mainLoop()
    -- Выбираем команду один раз
    selectMarines()
    task.wait(2)

    while true do
        -- Проверка острова (для остановки всего)
        local map = workspace:FindFirstChild("Map")
        if map and map:FindFirstChild("Prehistoricisland") then
            print("[STOP] Обнаружен Prehistoricisland, скрипт завершает работу.")
            stopBoatMovement()
            break
        end

        -- Определяем, сидит ли персонаж в своей лодке
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = (humanoid and humanoid.Sit and humanoid.SeatPart == seat and myBoat and myBoat.Parent)
        
        if sitting then
            -- Сидит: разрешаем движение лодки
            if not shouldMove then
                shouldMove = true
                startBoatMovement()
            end
        else
            -- Не сидит: запрещаем движение лодки
            if shouldMove then
                shouldMove = false
                stopBoatMovement()
            end
            -- Проверяем наличие лодки
            if not myBoat or not myBoat.Parent then
                -- Лодки нет: перемещаемся в точку, покупаем
                print("[MAIN] Лодки нет, покупаем...")
                moveCharacterTo(MOVE_POINT, WALK_SPEED)
                buyBoat()
                -- Ищем лодку после покупки
                myBoat = nil
                for i = 1, 10 do
                    myBoat = findMyBoat()
                    if myBoat then break end
                    task.wait(1)
                end
                if not myBoat then
                    warn("[MAIN] Не удалось найти лодку, повтор через 5 сек")
                    task.wait(5)
                    continue
                end
                -- Инициализируем компоненты лодки
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if not seat or not rootPart then
                    warn("[MAIN] Лодка неисправна, повтор")
                    task.wait(5)
                    continue
                end
                -- Отключаем коллизии у лодки
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                myBoat.DescendantAdded:Connect(function(desc)
                    if desc:IsA("BasePart") then desc.CanCollide = false end
                end)
                -- Отключаем родной скрипт лодки
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- Теперь лодка есть, но персонаж не сидит. Принудительно сажаем.
            if myBoat and seat and rootPart then
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChild("Humanoid")
                    if hrp and hum then
                        print("[MAIN] Персонаж не сидит, сажаем...")
                        forceSitOnSeat(seat, hrp, hum)
                    else
                        -- персонаж мёртв или не загружен, ждём
                        player.CharacterAdded:Wait()
                    end
                else
                    -- персонажа нет, ждём
                    player.CharacterAdded:Wait()
                end
            end
        end
        task.wait(0.3) -- небольшая задержка, чтобы не грузить процессор
    end
end

-- Запуск главного цикла
task.spawn(mainLoop)
print("Скрипт загружен. Начинается непрерывный цикл проверки посадки.")
