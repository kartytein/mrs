-- ===== ФИНАЛЬНЫЙ СКРИПТ (идентификация по владельцу) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
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
print("Перемещение завершено")

-- 2. Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание появления...")

-- 3. Поиск своей лодки по атрибуту/значению Owner
local boatsFolder = workspace:FindFirstChild("Boats")
if not boatsFolder then
    error("Папка Boats не найдена")
end

local myBoat = nil
local startTime = os.clock()
while os.clock() - startTime < 10 do
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            -- Проверяем атрибут Owner
            local ownerAttr = boat:GetAttribute("Owner")
            if ownerAttr == playerName then
                myBoat = boat
                break
            end
            -- Проверяем объект Owner (StringValue, ObjectValue и т.д.)
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and (ownerObj:IsA("StringValue") or ownerObj:IsA("ObjectValue")) then
                if tostring(ownerObj.Value) == playerName then
                    myBoat = boat
                    break
                end
            end
        end
    end
    if myBoat then break end
    task.wait(0.3)
end

if not myBoat then
    error("Не найдена лодка с владельцем " .. playerName)
end
print("Найдена своя лодка:", myBoat.Name)

-- 4. Управление лодкой (отключаем коллизии, садимся, циклическое движение)
local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then error("Сиденье не найдено") end

-- Отключаем коллизии у лодки
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
myBoat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then desc.CanCollide = false end
end)

-- Отключаем родной скрипт лодки (если есть)
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Tween к сиденью
local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
local tweenSeat = tweenService:Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
tweenSeat:Play()
tweenSeat.Completed:Wait()
humanoid.Sit = true
task.wait(0.5)

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

-- Поддержание отключённых коллизий у лодки и персонажа (на случай сброса)
task.spawn(function()
    while humanoid.Sit and humanoid.SeatPart == seat do
        for _, part in ipairs(myBoat:GetDescendants()) do
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

-- Циклическое движение
task.spawn(function()
    while humanoid.Sit and humanoid.SeatPart == seat do
        local target = points[currentPoint]
        local tween = moveTo(target)
        tween.Completed:Wait()
        currentPoint = currentPoint % #points + 1
    end
    print("Движение остановлено (игрок встал)")
end)

print("Лодка управляется, коллизии отключены, движение по маршруту запущено")
