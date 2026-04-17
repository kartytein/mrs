-- ===== ОПТИМИЗИРОВАННЫЙ СКРИПТ С ПОДНЯТОЙ ЛОДКОЙ =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_POINT_A = Vector3.new(-77389.3, 24.8, 32606.2)   -- подняты на 2 студия
local BOAT_POINT_B = Vector3.new(-47968.4, 24.8, 6048.2)    -- подняты на 2 студия
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 1   -- реже

-- Глобальные переменные
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local isSitting = false
local needToSit = true
local boatPoints = {BOAT_POINT_A, BOAT_POINT_B}
local currentPointIndex = 1
local islandMode = false

-- ===== УПРОЩЁННЫЕ КОЛЛИЗИИ =====
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

-- ===== ПОИСК ЛОДКИ =====
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

-- ===== УПРАВЛЕНИЕ ЛОДКОЙ =====
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function updateBoatMovement()
    if not myBoat or not rootPart or islandMode then return end
    if currentTween then currentTween:Cancel() end
    if not isSitting then return end

    local target = boatPoints[currentPointIndex]
    if (rootPart.Position - target).Magnitude < 50 then
        currentPointIndex = currentPointIndex % #boatPoints + 1
        target = boatPoints[currentPointIndex]
    end

    local duration = (rootPart.Position - target).Magnitude / BOAT_SPEED
    if duration > 0 then
        currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
        currentTween:Play()
        currentTween.Completed:Connect(function()
            currentTween = nil
            updateBoatMovement()
        end)
    end
end

-- ===== ВЫХОД ИЗ ЛОДКИ =====
local function exitBoat()
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid and humanoid.Sit then
        humanoid.Sit = false
        task.wait(0.5)
    end
end

-- ===== ОЖИДАНИЕ DRAGON EGG =====
local function waitForDragonEgg()
    local egg = nil
    for _ = 1, 60 do
        egg = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") and workspace.Map.Prehistoricisland:FindFirstChild("Core") and workspace.Map.Prehistoricisland.Core:FindFirstChild("SpawnedDragonEggs") and workspace.Map.Prehistoricisland.Core.SpawnedDragonEggs:FindFirstChild("DragonEgg")
        if egg then break end
        task.wait(1)
    end
    if not egg then return end
    while egg and egg.Parent do
        task.wait(0.5)
    end
end

-- ===== МОНИТОР ОСТРОВА =====
task.spawn(function()
    while not stopScript do
        local island = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland")
        if island and not islandMode then
            islandMode = true
            stopBoat()
            exitBoat()
            task.wait(1)

            local islandPos = island:GetPivot().Position + Vector3.new(0, 20, 0)
            moveCharacterTo(islandPos, WALK_SPEED)

            waitForDragonEgg()

            -- Возврат к лодке
            myBoat = findMyBoat()
            if myBoat then
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
            islandMode = false
            needToSit = true
        end
        task.wait(2)  -- реже проверяем остров
    end
end)

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
                updateBoatMovement()
            else
                needToSit = true
                stopBoat()
            end
        end
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat, seat, rootPart = nil, nil, nil
            needToSit = true
        end
        task.wait(0.5)  -- реже проверяем
    end
end)

-- ===== ГЛАВНЫЙ ЦИКЛ =====
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        if islandMode then
            task.wait(1)
            continue
        end

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

            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if myBoat and seat and hrp and humanoid then
                disableCollisions(char)

                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp

                local targetCF = seat.CFrame + SEAT_OFFSET
                while needToSit and not islandMode and myBoat and myBoat.Parent and seat and hrp and hrp.Parent do
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
                if hrp and hrp.Parent and not islandMode then
                    hrp.CFrame = seat.CFrame + SEAT_OFFSET
                    if humanoid then humanoid.Sit = true end
                end
                needToSit = false
                isSitting = true
                updateBoatMovement()
            else
                task.wait(0.5)
            end
        else
            if isSitting and myBoat and rootPart and not islandMode then
                updateBoatMovement()
            end
            task.wait(0.3)
        end
    end
end)

print("Оптимизированный скрипт запущен. Лодка поднята в воздух.")
