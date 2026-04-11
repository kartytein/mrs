-- ===== ПОЛНЫЙ СКРИПТ (работает с лодкой в _WorldOrigin) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local tweenService = game:GetService("TweenService")

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

while true do
    local current = hrp.Position
    local direction = (targetPos - current).Unit
    local distance = (targetPos - current).Magnitude
    if distance < 0.5 then break end
    local move = math.min(speed * step, distance)
    local newPos = current + direction * move
    hrp.CFrame = CFrame.new(newPos)
    task.wait(step)
end
hrp.CFrame = CFrame.new(targetPos)

for _, part in ipairs(partsChar) do
    if part and part.Parent then part.CanCollide = true end
end
print("Перемещение персонажа завершено")

-- 2. Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание появления...")

-- 3. Поиск своей лодки в _WorldOrigin
local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
if not worldOrigin then
    warn("_WorldOrigin не найдена")
    return
end

-- Запоминаем лодки, которые уже были до вызова
local existingBoats = {}
for _, child in ipairs(worldOrigin:GetChildren()) do
    if child:IsA("Model") and child:FindFirstChildWhichIsA("VehicleSeat") then
        existingBoats[child] = true
    end
end

local myBoat = nil
local connection
connection = worldOrigin.ChildAdded:Connect(function(child)
    if myBoat then return end
    if child:IsA("Model") and child:FindFirstChildWhichIsA("VehicleSeat") and not existingBoats[child] then
        myBoat = child
        connection:Disconnect()
        print("Найдена новая лодка:", myBoat.Name, "путь:", myBoat:GetFullName())
    end
end)

-- Ждём до 10 секунд
task.wait(10)
if not myBoat then
    connection:Disconnect()
    warn("Лодка не появилась в течение 10 секунд")
    return
end

-- 4. Управление лодкой (отключаем коллизии у лодки и персонажа, циклическое движение)
local function controlBoat(boat)
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then
        warn("Сиденье не найдено")
        return
    end

    -- Отключаем коллизии у всех частей лодки (включая будущие)
    local function disableCollisions(instance)
        for _, part in ipairs(instance:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    disableCollisions(boat)
    boat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end)

    -- Отключаем коллизии у персонажа (пока он в лодке)
    disableCollisions(char)
    char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") and humanoid.Sit and humanoid.SeatPart == seat then
            desc.CanCollide = false
        end
    end)

    -- Отключаем родной скрипт управления лодкой, если есть
    local nativeScript = boat:FindFirstChild("Script")
    if nativeScript then nativeScript.Disabled = true end

    -- Tween к сиденью
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tweenSeat = tweenService:Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tweenSeat:Play()
    tweenSeat.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.5)

    -- Основная часть лодки для перемещения
    local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then
        warn("Не найдена основная часть лодки")
        return
    end

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

    -- Фоновый поток для поддержания отключённых коллизий (на случай сброса)
    task.spawn(function()
        while humanoid.Sit and humanoid.SeatPart == seat do
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide == true then
                    part.CanCollide = false
                end
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide == true then
                    part.CanCollide = false
                end
            end
            task.wait(0.5)
        end
        -- Восстанавливаем коллизии персонажа после выхода
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end)

    -- Циклическое движение между точками
    task.spawn(function()
        while humanoid.Sit and humanoid.SeatPart == seat do
            local target = points[currentPoint]
            local tween = moveTo(target)
            tween.Completed:Wait()
            currentPoint = currentPoint % #points + 1
        end
        print("Движение остановлено (игрок встал)")
    end)

    print("Лодка управляется, коллизии отключены, начато циклическое движение")
end

controlBoat(myBoat)
