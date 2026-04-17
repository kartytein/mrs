-- ===== ФИНАЛЬНЫЙ СКРИПТ С НЕПРЕРЫВНЫМ ДВИЖЕНИЕМ ЛОДКИ (BODYVELOCITY) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (при необходимости измените)
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_POINT_A = Vector3.new(-77389.3, 26.8, 32606.2)
local BOAT_POINT_B = Vector3.new(-47968.4, 26.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.2

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local boatVelocity = nil
local isSitting = false
local needToSit = true
local boatPoints = {BOAT_POINT_A, BOAT_POINT_B}
local currentPointIndex = 1

-- ===== ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (один раз) =====
local function disableCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

-- ===== ВЫБОР КОМАНДЫ =====
local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
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

    disableCollisions(char)

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

-- ===== НЕПРЕРЫВНОЕ УПРАВЛЕНИЕ ЛОДКОЙ (ОТДЕЛЬНЫЙ ПОТОК) =====
local function startBoatController()
    task.spawn(function()
        while not stopScript do
            if myBoat and rootPart and isSitting then
                -- Создаём BodyVelocity, если его нет
                if not boatVelocity then
                    boatVelocity = Instance.new("BodyVelocity")
                    boatVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    boatVelocity.Parent = rootPart
                end
                -- Определяем текущую цель
                local target = boatPoints[currentPointIndex]
                local dist = (rootPart.Position - target).Magnitude
                if dist < 50 then
                    currentPointIndex = currentPointIndex % #boatPoints + 1
                    target = boatPoints[currentPointIndex]
                end
                local direction = (target - rootPart.Position).Unit
                boatVelocity.Velocity = direction * BOAT_SPEED
            else
                -- Если не сидим, удаляем BodyVelocity
                if boatVelocity then
                    boatVelocity:Destroy()
                    boatVelocity = nil
                end
            end
            task.wait(0.1) -- частая проверка
        end
    end)
end

-- ===== МОНИТОР ПОСАДКИ =====
task.spawn(function()
    while not stopScript do
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end
        if sitting ~= isSitting then
            isSitting = sitting
            if isSitting then
                needToSit = false
            else
                needToSit = true
            end
        end
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat, seat, rootPart = nil, nil, nil
            needToSit = true
        end
        task.wait(0.3)
    end
end)

-- ===== ГЛАВНЫЙ ЦИКЛ (ПОКУПКА И ПОСАДКА) =====
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        -- Обновляем ссылку на лодку
        local found = findMyBoat()
        if found and not myBoat then
            myBoat = found
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if seat and rootPart then
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            else
                myBoat = nil
            end
        end

        if needToSit then
            -- Если лодки нет, покупаем
            if not myBoat or not myBoat.Parent then
                moveCharacterTo(MOVE_POINT, WALK_SPEED)
                local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
                remote:InvokeServer("BuyBoat", "Guardian")
                task.wait(3)
                for i = 1, 10 do
                    myBoat = findMyBoat()
                    if myBoat then break end
                    task.wait(1)
                end
                if not myBoat then
                    task.wait(5)
                    continue
                end
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if not seat or not rootPart then
                    myBoat = nil
                    continue
                end
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- Посадка
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if myBoat and seat and hrp and humanoid then
                disableCollisions(char)

                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp

                local targetCF = seat.CFrame + SEAT_OFFSET
                while needToSit and myBoat and myBoat.Parent and seat and hrp and hrp.Parent do
                    local direction = (targetCF.Position - hrp.Position).Unit
                    bv.Velocity = direction * WALK_SPEED
                    task.wait()
                    local hum = hrp.Parent and hrp.Parent:FindFirstChild("Humanoid")
                    if hum and hum.Sit and hum.SeatPart == seat then
                        break
                    end
                    targetCF = seat.CFrame + SEAT_OFFSET
                end
                bv:Destroy()
                if hrp and hrp.Parent then
                    hrp.CFrame = seat.CFrame + SEAT_OFFSET
                    if humanoid then humanoid.Sit = true end
                end
                needToSit = false
                isSitting = true
            else
                task.wait(0.5)
            end
        else
            task.wait(0.3)
        end
    end
end)

-- Запуск контроллера лодки
startBoatController()

print("Скрипт запущен. Лодка движется непрерывно через BodyVelocity, цель переключается при приближении.")
