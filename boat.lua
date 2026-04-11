-- ===== ФИНАЛЬНЫЙ СКРИПТ (с остановкой движения при сбросе и корректным возвратом) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local tweenService = game:GetService("TweenService")

-- Флаг для остановки скрипта при появлении острова
local stopScript = false

local function checkIsland()
    if stopScript then return true end
    local map = workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Prehistoricisland") then
        stopScript = true
        print("[STOP] Обнаружен остров Prehistoricisland, скрипт останавливается.")
        return true
    end
    return false
end

-- 1. Перемещение персонажа в точку
local function moveCharacterTo(targetPos)
    local speed = 150
    local step = 0.1
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    while true do
        local current = hrp.Position
        local direction = (targetPos - current).Unit
        local distance = (targetPos - current).Magnitude
        if distance < 0.5 then break end
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
        if checkIsland() then break end
    end
    hrp.CFrame = CFrame.new(targetPos)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
    return true
end

local targetPos = Vector3.new(-16917, 9.1, 447)
moveCharacterTo(targetPos)
if stopScript then return end
print("Перемещение завершено")

-- 2. Поиск своей лодки и призыв при необходимости
local boatsFolder = workspace:FindFirstChild("Boats")
if not boatsFolder then error("Папка Boats не найдена") end

local function findMyBoat()
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

local myBoat = findMyBoat()
if myBoat then
    print("Лодка уже существует, пропускаем призыв.")
else
    local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
    remote:InvokeServer("BuyBoat", "Guardian")
    print("Лодка призвана, ожидание появления...")
    task.wait(3)
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
        if checkIsland() then return end
    end
    if not myBoat then error("Не найдена лодка с владельцем " .. playerName) end
    print("Найдена своя лодка:", myBoat.Name)
end

-- 3. Подготовка лодки и посадка
local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then error("Сиденье не найдено") end

-- Отключаем коллизии у лодки
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
myBoat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then desc.CanCollide = false end
end)

-- Отключаем коллизии у персонажа
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end

-- Отключаем родной скрипт лодки
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Функция посадки
local function sitOnSeat()
    if stopScript then return false end
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tweenSeat = tweenService:Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tweenSeat:Play()
    tweenSeat.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.5)
    return true
end

sitOnSeat()

-- Основная часть лодки
local rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Основная часть не найдена") end

-- Точки маршрута
local points = {
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local boatSpeed = 420

-- Переменные управления движением
local currentTween = nil
local movementActive = false
local movementThread = nil
local currentPointIndex = 1

local function stopMovement()
    if currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing then
        currentTween:Cancel()
    end
    movementActive = false
    if movementThread then
        task.cancel(movementThread)
        movementThread = nil
    end
    currentTween = nil
    print("[MOVEMENT] Движение остановлено")
end

local function startMovement()
    if movementActive then stopMovement() end
    movementActive = true
    movementThread = task.spawn(function()
        while movementActive and not stopScript do
            -- Ждём, пока персонаж сидит
            while not (humanoid.Sit and humanoid.SeatPart == seat) do
                if not movementActive then break end
                task.wait(0.5)
            end
            if not movementActive then break end
            local target = points[currentPointIndex]
            local dist = (rootPart.Position - target).Magnitude
            local duration = dist / boatSpeed
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            currentTween.Completed:Wait()
            currentPointIndex = currentPointIndex % #points + 1
        end
        movementActive = false
        movementThread = nil
    end)
end

-- Запускаем движение после посадки
startMovement()

-- Мониторинг сброса и перепризыв
task.spawn(function()
    while not stopScript do
        task.wait(0.5)
        if not (humanoid.Sit and humanoid.SeatPart == seat) then
            if movementActive then
                print("[MONITOR] Сброс с сиденья, останавливаем движение")
                stopMovement()
            end
            -- Если персонаж умер, ждём новый
            if not player.Character or player.Character ~= char then
                char = player.CharacterAdded:Wait()
                hrp = char:WaitForChild("HumanoidRootPart")
                humanoid = char:WaitForChild("Humanoid")
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
            -- Садимся обратно
            sitOnSeat()
            -- Запускаем движение заново (с текущей позиции лодки)
            if not movementActive then
                startMovement()
            end
        end
    end
end)

-- Перепризыв при потере лодки (упрощённо, можно оставить как ранее)
task.spawn(function()
    while not stopScript do
        task.wait(2)
        if not myBoat or not myBoat.Parent then
            print("[MONITOR] Лодка потеряна, перепризыв...")
            stopMovement()
            moveCharacterTo(targetPos)
            local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
            remote:InvokeServer("BuyBoat", "Guardian")
            task.wait(3)
            local newBoat = nil
            for i = 1, 10 do
                newBoat = findMyBoat()
                if newBoat then break end
                task.wait(1)
            end
            if newBoat then
                myBoat = newBoat
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                if seat then
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    myBoat.DescendantAdded:Connect(function(desc)
                        if desc:IsA("BasePart") then desc.CanCollide = false end
                    end)
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                    sitOnSeat()
                    startMovement()
                end
            end
        end
    end
end)

print("Скрипт запущен: движение останавливается при сбросе, возврат на сиденье и продолжение маршрута.")
