-- ===== ФИНАЛЬНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (ЧИСТЫЙ ФУНКЦИОНАЛ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ (при необходимости измените под свои координаты)
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)          -- где покупать лодку
local BOAT_THRESHOLD_X = -77389                          -- порог X для смены направления
local BOAT_POINT_FAR = Vector3.new(-77389.3, 22.8, 32606.2)   -- дальняя точка
local BOAT_POINT_NEAR = Vector3.new(-47968.4, 22.8, 6048.2)    -- ближняя точка
local WALK_SPEED = 150                                   -- скорость ходьбы / полёта к сиденью
local BOAT_SPEED = 420                                   -- скорость лодки
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)               -- высота над сиденьем
local COLLISION_INTERVAL = 0.3                           -- частота принудительного отключения коллизий

-- Глобальные переменные
local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local isSitting = false
local needToSit = true

-- ========== 1. УПРАВЛЕНИЕ КОЛЛИЗИЯМИ ==========
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
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then lower.CanCollide = false end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then upper.CanCollide = false end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

-- ========== 2. ВЫБОР КОМАНДЫ ==========
local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then eventService:FireServer() end
end

-- ========== 3. ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА В ТОЧКУ ==========
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

-- ========== 4. ПОИСК СВОЕЙ ЛОДКИ (ПО OWNER) ==========
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

-- ========== 5. ПОСАДКА НА СИДЕНЬЕ ==========
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

-- ========== 6. УПРАВЛЕНИЕ ЛОДКОЙ (TWEEN) ==========
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function updateBoatMovement()
    if not myBoat or not rootPart then return end
    if currentTween then currentTween:Cancel() end
    if isSitting then
        local x = rootPart.Position.X
        local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
        local dist = (rootPart.Position - target).Magnitude
        local duration = dist / BOAT_SPEED
        if duration > 0 then
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            currentTween.Completed:Connect(function() currentTween = nil end)
        end
    end
end

-- ========== 7. НЕПРЕРЫВНЫЙ МОНИТОР ПОСАДКИ (ОТДЕЛЬНЫЙ ПОТОК) ==========
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
        -- Если лодка пропала, сбрасываем ссылки
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil
            seat = nil
            rootPart = nil
            needToSit = true
        end
        task.wait(0.2)
    end
end)

-- ========== 8. ГЛАВНЫЙ ЦИКЛ (ПОКУПКА / ПОСАДКА / ДВИЖЕНИЕ) ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        -- 1. Всегда обновляем информацию о существующей лодке
        local found = findMyBoat()
        if found then
            if myBoat ~= found then
                myBoat = found
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
                else
                    myBoat = nil
                end
            end
        else
            if myBoat then myBoat = nil; seat = nil; rootPart = nil end
        end

        -- 2. Если нужно сесть (нет лодки или персонаж не сидит)
        if needToSit or (myBoat and not isSitting) then
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
                myBoat.DescendantAdded:Connect(function(desc)
                    if desc:IsA("BasePart") then desc.CanCollide = false end
                end)
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- Садимся на сиденье
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if hrp and humanoid then
                sitOnSeat(seat, hrp, humanoid)
                task.wait(0.5)
                if isSitting then needToSit = false end
            else
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
