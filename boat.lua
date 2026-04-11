-- ===== ФИНАЛЬНЫЙ СКРИПТ (с возвратом, перепризывом и остановкой при острове) =====
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
local targetPos = Vector3.new(-16917, 9.1, 447)
local speed = 150
local step = 0.1

local partsChar = {}
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then
        table.insert(partsChar, part)
        part.CanCollide = false
    end
end

while not stopScript do
    local current = hrp.Position
    local direction = (targetPos - current).Unit
    local distance = (targetPos - current).Magnitude
    if distance < 0.5 then break end
    local move = math.min(speed * step, distance)
    local newPos = current + direction * move
    hrp.CFrame = CFrame.new(newPos)
    task.wait(step)
    checkIsland()
end
hrp.CFrame = CFrame.new(targetPos)
for _, part in ipairs(partsChar) do
    if part and part.Parent then part.CanCollide = true end
end
print("Перемещение завершено")
if stopScript then return end

-- 2. Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
local function summonBoat()
    remote:InvokeServer("BuyBoat", "Guardian")
    print("Лодка призвана, ожидание появления...")
end
summonBoat()

-- 3. Поиск своей лодки по атрибуту/значению Owner
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

local myBoat = nil
local startTime = os.clock()
while os.clock() - startTime < 10 and not stopScript do
    myBoat = findMyBoat()
    if myBoat then break end
    task.wait(0.3)
    checkIsland()
end
if not myBoat then error("Не найдена лодка с владельцем " .. playerName) end
print("Найдена своя лодка:", myBoat.Name)

-- 4. Управление лодкой (отключаем коллизии, садимся, циклическое движение)
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

-- Функция посадки на сиденье
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

-- Посадка
if not sitOnSeat() then return end

-- Основная часть лодки
local rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Основная часть не найдена") end

-- Точки маршрута
local points = {
    Vector3.new(-77389.3, 22.8, 32606.2),
    Vector3.new(-47968.4, 22.8, 6048.2)
}
local currentPoint = 1
local boatSpeed = 420

local function moveTo(point)
    local dist = (rootPart.Position - point).Magnitude
    local duration = dist / boatSpeed
    local tween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(point)})
    tween:Play()
    return tween
end

-- Циклическое движение (отдельный поток)
local movementThread = nil
local function startMovement()
    if movementThread then return end
    movementThread = task.spawn(function()
        while not stopScript and humanoid.Sit and humanoid.SeatPart == seat do
            local target = points[currentPoint]
            local tween = moveTo(target)
            tween.Completed:Wait()
            currentPoint = currentPoint % #points + 1
            checkIsland()
        end
        print("Движение остановлено")
    end)
end
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
            myBoat = nil
            -- Останавливаем движение
            if movementThread then task.cancel(movementThread) movementThread = nil end
            -- Возвращаем персонажа в точку
            -- Временно включаем коллизии, чтобы переместить (метод уже отключает их внутри)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
            moveCharacterTo(targetPos) -- используем ту же функцию, но нужно её определить выше
            -- Призываем новую лодку
            summonBoat()
            task.wait(3)
            -- Ищем новую лодку
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
                    -- Отключаем родной скрипт
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
                sitOnSeat()
            end
        end
    end
end)

print("Лодка управляется, возврат и перепризыв активны, движение по маршруту запущено")
