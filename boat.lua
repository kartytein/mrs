-- ===== ФИНАЛЬНЫЙ СКРИПТ (возврат на сиденье, остановка при острове) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local tweenService = game:GetService("TweenService")

-- Глобальный флаг для остановки скрипта при появлении острова
local stopScript = false

-- Функция проверки появления острова
local function checkIsland()
    if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") then
        stopScript = true
        print("Остров Prehistoricisland обнаружен, скрипт останавливается.")
        return true
    end
    return false
end

-- 1. Перемещение персонажа в точку (только если остров ещё не появился)
if not checkIsland() then
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
        if checkIsland() then break end
    end
    hrp.CFrame = CFrame.new(targetPos)
    for _, part in ipairs(partsChar) do
        if part and part.Parent then part.CanCollide = true end
    end
    print("Перемещение завершено")
end

if stopScript then return end

-- 2. Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание появления...")
task.wait(3)

if checkIsland() then return end

-- 3. Поиск своей лодки по атрибуту Owner
local boatsFolder = workspace:FindFirstChild("Boats")
if not boatsFolder then error("Папка Boats не найдена") end

local myBoat = nil
for _ = 1, 10 do
    for _, child in ipairs(boatsFolder:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = child:GetAttribute("Owner")
            if owner and owner == player.Name then
                myBoat = child
                break
            end
        end
    end
    if myBoat then break end
    task.wait(1)
    if checkIsland() then return end
end

if not myBoat then error("Своя лодка (Owner = " .. player.Name .. ") не найдена") end
print("Найдена своя лодка:", myBoat.Name)

-- 4. Подготовка лодки и персонажа
local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then error("Сиденье не найдено") end

-- Отключаем коллизии у лодки (навсегда)
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
myBoat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then desc.CanCollide = false end
end)

-- Отключаем коллизии у персонажа (пока он в лодке)
local function setCharCollisions(val)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = val end
    end
end
setCharCollisions(false)

-- Отключаем родной скрипт лодки
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Функция посадки на сиденье (с Tween)
local function sitOnSeat()
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tween = tweenService:Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.5)
end

-- Первичная посадка
sitOnSeat()

-- Основная часть лодки для движения
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

-- Циклическое движение (работает, пока скрипт не остановлен)
task.spawn(function()
    while not stopScript and humanoid.Sit and humanoid.SeatPart == seat do
        local target = points[currentPoint]
        local tween = moveTo(target)
        tween.Completed:Wait()
        currentPoint = currentPoint % #points + 1
        if checkIsland() then break end
    end
    print("Движение остановлено")
end)

-- Задача: возврат на сиденье, если скинули или персонаж умер
task.spawn(function()
    while not stopScript do
        -- Ждём, пока персонаж не окажется вне сиденья
        if not (humanoid.Sit and humanoid.SeatPart == seat) then
            print("Персонаж сброшен или умер, возвращаем...")
            -- Если персонаж умер, дожидаемся нового
            if not player.Character or player.Character ~= char then
                char = player.CharacterAdded:Wait()
                hrp = char:WaitForChild("HumanoidRootPart")
                humanoid = char:WaitForChild("Humanoid")
                -- Снова отключаем коллизии
                setCharCollisions(false)
            end
            -- Возвращаем на сиденье
            sitOnSeat()
        end
        task.wait(1) -- проверяем каждую секунду
        if checkIsland() then break end
    end
end)

print("Лодка управляется, возврат на сиденье активен, движение по маршруту запущено")
loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
