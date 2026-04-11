-- ===== ФИНАЛЬНЫЙ СКРИПТ (с проверкой наличия лодки, остановкой движения при вылезании) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local tweenService = game:GetService("TweenService")

-- Флаг для остановки скрипта при появлении острова
local stopScript = false

-- Функция проверки острова
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

-- 1. Перемещение персонажа в точку (-16917, 9.1, 447) с отключением коллизий
local function moveCharacterTo(targetPos)
    local speed = 150
    local step = 0.1
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Отключаем коллизии у всех частей персонажа
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
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

    -- Восстанавливаем коллизии (необязательно, можно оставить отключенными)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    return true
end

local targetPos = Vector3.new(-16917, 9.1, 447)
moveCharacterTo(targetPos)
if stopScript then return end
print("Перемещение завершено")

-- 2. Проверяем, есть ли уже лодка (по Owner)
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
    -- Призываем новую лодку
    local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
    remote:InvokeServer("BuyBoat", "Guardian")
    print("Лодка призвана, ожидание появления...")
    task.wait(3)

    -- Поиск своей лодки (с повторами)
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

-- Отключаем коллизии у лодки (один раз)
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
myBoat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then desc.CanCollide = false end
end)

-- Отключаем коллизии у персонажа (один раз)
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end

-- Отключаем родной скрипт лодки (если есть)
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Функция посадки на сиденье (с Tween)
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

-- Выполняем посадку
sitOnSeat()

-- Основная часть лодки для движения
local rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Основная часть не найдена") end

-- Точки маршрута
local points = {
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local boatSpeed = 420

-- Переменная для управления движением
local currentTween = nil
local movementActive = false

-- Функция остановки текущего движения
local function stopMovement()
    if currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing then
        currentTween:Cancel()
    end
    movementActive = false
    currentTween = nil
end

-- Функция запуска движения (циклическое, но с проверкой посадки)
local function startMovement()
    if movementActive then stopMovement() end
    movementActive = true
    task.spawn(function()
        local pointIndex = 1
        while movementActive and not stopScript do
            -- Ждём, пока персонаж сидит на сиденье
            while not (humanoid.Sit and humanoid.SeatPart == seat) do
                if not movementActive then break end
                task.wait(0.5)
            end
            if not movementActive then break end
            local target = points[pointIndex]
            local dist = (rootPart.Position - target).Magnitude
            local duration = dist / boatSpeed
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            currentTween.Completed:Wait()
            pointIndex = pointIndex % #points + 1
        end
        movementActive = false
        currentTween = nil
    end)
end

-- Запускаем движение
startMovement()

-- Мониторинг сброса/смерти и перепризыв при потере лодки
task.spawn(function()
    while not stopScript do
        task.wait(1)
        checkIsland()
        if stopScript then break end

        -- Проверка: существует ли лодка
        if not myBoat or not myBoat.Parent then
            print("[MONITOR] Лодка потеряна, перепризыв...")
            stopMovement()
            myBoat = nil
            -- Возвращаем персонажа в точку
            moveCharacterTo(targetPos)
            -- Призываем новую лодку
            local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
            remote:InvokeServer("BuyBoat", "Guardian")
            print("Лодка призвана, ожидание...")
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
                if seat then
                    -- Отключаем коллизии у новой лодки
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    myBoat.DescendantAdded:Connect(function(desc)
                        if desc:IsA("BasePart") then desc.CanCollide = false end
                    end)
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                    -- Посадка
                    sitOnSeat()
                    -- Перезапуск движения
                    startMovement()
                end
            else
                print("[MONITOR] Не удалось призвать новую лодку, повтор через 5 сек")
                task.wait(5)
            end
        else
            -- Проверяем, сидит ли персонаж на сиденье
            if not (humanoid.Sit and humanoid.SeatPart == seat) then
                print("[MONITOR] Сброс с сиденья, возвращаем...")
                -- Если персонаж умер, ждём новый Character
                if not player.Character or player.Character ~= char then
                    char = player.CharacterAdded:Wait()
                    hrp = char:WaitForChild("HumanoidRootPart")
                    humanoid = char:WaitForChild("Humanoid")
                    -- Отключаем коллизии у нового персонажа
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
                -- Принудительно сажаем обратно
                sitOnSeat()
                -- Движение уже запущено, но оно ждёт посадки, так что всё ок
            end
        end
    end
end)

print("Лодка управляется, движение активно только когда вы сидите, возврат при сбросе работает.")
