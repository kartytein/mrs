-- ===== ФИНАЛЬНЫЙ СКРИПТ: TWEEN ДЛЯ ПЕРСОНАЖА, BODYVELOCITY ДЛЯ ЛОДКИ =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_POINT_A = Vector3.new(-77389.3, 26.8, 32606.2)
local BOAT_POINT_B = Vector3.new(-47968.4, 26.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.2

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local boatVelocity = nil
local isSitting = false
local needToSit = true
local boatPoints = {BOAT_POINT_A, BOAT_POINT_B}
local currentPointIndex = 1
local collisionThread = nil

-- ===== ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (LowerTorso/UpperTorso) =====
local function maintainCollisions(char)
    if collisionThread then task.cancel(collisionThread) end
    collisionThread = task.spawn(function()
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

-- Временное отключение всех коллизий (для Tween)
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
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

-- ===== ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА (TWEEN) =====
local function tweenToPoint(targetPos, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    disableAllCollisions(char)
    humanoid.PlatformStand = true

    local distance = (hrp.Position - targetPos).Magnitude
    local duration = distance / speed
    if duration < 0.1 then duration = 0.1 end

    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = targetPos})
    tween:Play()
    tween.Completed:Wait()
    hrp.CFrame = CFrame.new(targetPos)

    humanoid.PlatformStand = false
    return true
end

-- ===== ПОСАДКА НА СИДЕНЬЕ (TWEEN) =====
local function tweenToSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    disableAllCollisions(char)
    humanoid.PlatformStand = true

    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local distance = (hrp.Position - targetCF.Position).Magnitude
    local duration = math.min(distance / WALK_SPEED, 2)
    if duration < 0.2 then duration = 0.2 end

    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    humanoid.PlatformStand = false
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

-- ===== УПРАВЛЕНИЕ ЛОДКОЙ (BODYVELOCITY) =====
local function stopBoat()
    if boatVelocity then
        boatVelocity:Destroy()
        boatVelocity = nil
    end
end

local function updateBoatMovement()
    if not myBoat or not rootPart or not isSitting then
        stopBoat()
        return
    end
    if not boatVelocity then
        boatVelocity = Instance.new("BodyVelocity")
        boatVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        boatVelocity.Parent = rootPart
    end
    local target = boatPoints[currentPointIndex]
    local dist = (rootPart.Position - target).Magnitude
    if dist < 50 then
        currentPointIndex = currentPointIndex % #boatPoints + 1
        target = boatPoints[currentPointIndex]
    end
    local direction = (target - rootPart.Position).Unit
    boatVelocity.Velocity = direction * BOAT_SPEED
end

-- ===== МОНИТОР ПОСАДКИ =====
task.spawn(function()
    while true do
        task.wait(0.3)
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
    end
end)

-- ===== ОСНОВНАЯ ЛОГИКА =====
selectMarines()
task.wait(2)

-- Перемещение к точке покупки
tweenToPoint(MOVE_POINT, WALK_SPEED)

-- Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание...")
task.wait(3)

-- Поиск лодки
for i = 1, 10 do
    myBoat = findMyBoat()
    if myBoat then break end
    task.wait(1)
end
if not myBoat then error("Лодка не найдена") end
print("Лодка найдена:", myBoat.Name)

seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then error("Сиденье не найдено") end
rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Основная часть не найдена") end

-- Отключаем коллизии у лодки навсегда
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
myBoat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then desc.CanCollide = false end
end)

-- Отключаем родной скрипт лодки
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Посадка
local char = player.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local humanoid = char and char:FindFirstChild("Humanoid")
if not hrp or not humanoid then error("Нет HRP") end
tweenToSeat(seat, hrp, humanoid)

-- Запускаем постоянное поддержание коллизий (LowerTorso/UpperTorso)
maintainCollisions(char)

print("Скрипт запущен. Лодка движется через BodyVelocity, коллизии постоянно отключены.")
