-- ===== ФИНАЛЬНЫЙ СКРИПТ (непрерывные проверки) =====
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

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil

-- Вспомогательные функции для коллизий (как в эталоне)
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

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
            task.wait(0.3)
        end
    end)
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

-- Посадка на сиденье (BodyVelocity, постоянная скорость)
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
    return true
end

-- Остановка движения лодки
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

-- Запуск движения лодки (Tween)
local function startBoatMovement()
    if not myBoat or not rootPart then return end
    stopBoat()
    local x = rootPart.Position.X
    local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
    local dist = (rootPart.Position - target).Magnitude
    local duration = dist / BOAT_SPEED
    if duration > 0 then
        currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
        currentTween:Play()
        currentTween.Completed:Connect(function()
            currentTween = nil
            if myBoat and rootPart then
                startBoatMovement() -- цикл
            end
        end)
    end
end

-- ===== ОСНОВНОЙ ЦИКЛ ПОСАДКИ (работает всегда) =====
local function seatingLoop()
    while not stopScript do
        -- Проверка острова
        local map = workspace:FindFirstChild("Map")
        if map and map:FindFirstChild("Prehistoricisland") then
            stopScript = true
            stopBoat()
            print("[STOP] Prehistoricisland найден, скрипт остановлен.")
            break
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = humanoid and humanoid.Sit and humanoid.SeatPart == seat

        if not sitting then
            -- Если не сидим, останавливаем лодку
            stopBoat()
            -- Проверяем, существует ли лодка (моя)
            if not myBoat or not myBoat.Parent then
                -- Лодки нет: перемещаемся в точку покупки и покупаем
                moveCharacterTo(MOVE_POINT, WALK_SPEED)
                local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
                if remote then
                    remote:InvokeServer("BuyBoat", "Guardian")
                    print("[LOOP] Лодка призвана, ждём...")
                    task.wait(3)
                    -- Ищем свою лодку
                    for i = 1, 10 do
                        myBoat = findMyBoat()
                        if myBoat then break end
                        task.wait(1)
                    end
                    if myBoat then
                        seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                        if seat and rootPart then
                            -- Отключаем коллизии у лодки
                            for _, part in ipairs(myBoat:GetDescendants()) do
                                if part:IsA("BasePart") then part.CanCollide = false end
                            end
                            myBoat.DescendantAdded:Connect(function(desc)
                                if desc:IsA("BasePart") then desc.CanCollide = false end
                            end)
                            local native = myBoat:FindFirstChild("Script")
                            if native then native.Disabled = true end
                        end
                    else
                        print("[LOOP] Не удалось призвать лодку, повтор через 5 сек")
                        task.wait(5)
                        continue
                    end
                end
            end
            -- Теперь лодка есть, пытаемся сесть
            if myBoat and seat then
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if hrp and hum then
                    print("[LOOP] Пытаемся сесть...")
                    sitOnSeat(seat, hrp, hum)
                else
                    -- Если персонаж мёртв, ждём его появления
                    player.CharacterAdded:Wait()
                end
            end
        else
            -- Сидим на лодке
            if myBoat and rootPart then
                -- Запускаем движение, если оно не активно
                if not currentTween then
                    startBoatMovement()
                end
            end
        end
        task.wait(0.3) -- частота проверок
    end
end

-- Запуск
selectMarines()
task.wait(2)
task.spawn(seatingLoop)
print("[START] Скрипт запущен, бесконечный цикл посадки и движения.")
