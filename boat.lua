-- ===== ПОЛНЫЙ СКРИПТ (перемещение + призыв + управление лодкой с постоянным noclip) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local tweenService = game:GetService("TweenService")

-- 1. Перемещение персонажа в точку (-16917, 9.1, 447) с отключением коллизий
local targetPos = Vector3.new(-16917, 9.1, 447)
local speed = 150
local step = 0.1

local parts = {}
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then
        table.insert(parts, part)
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

for _, part in ipairs(parts) do
    if part and part.Parent then part.CanCollide = true end
end
print("Перемещение персонажа завершено")

-- 2. Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание...")
task.wait(3)

-- 3. Управление лодкой с постоянным отключением коллизий (noclip)
local function controlBoat(boat)
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return end

    -- Отключаем коллизии у всех частей лодки (и будущих)
    local function disableAllCollisions(instance)
        for _, part in ipairs(instance:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    disableAllCollisions(boat)
    boat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            desc.CanCollide = false
        end
    end)

    -- Отключаем родной скрипт (если есть)
    local native = boat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Tween к сиденью
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tweenSeat = tweenService:Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tweenSeat:Play()
    tweenSeat.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.5)

    -- Основная часть лодки
    local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then return end

    -- Циклическое движение по точкам
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

    -- Дополнительный цикл для поддержания noclip (на случай сброса)
    task.spawn(function()
        while humanoid.Sit and humanoid.SeatPart == seat do
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide == true then
                    part.CanCollide = false
                end
            end
            task.wait(0.5)
        end
    end)

    -- Запуск циклического движения
    task.spawn(function()
        while humanoid.Sit and humanoid.SeatPart == seat do
            local target = points[currentPoint]
            local tween = moveTo(target)
            tween.Completed:Wait()
            currentPoint = currentPoint % #points + 1
        end
        print("Движение остановлено (игрок встал)")
    end)

    print("Лодка движется с постоянным noclip")
end

-- 4. Поиск своей лодки
local myBoat = nil
local startWait = os.clock()
while os.clock() - startWait < 10 do
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildWhichIsA("VehicleSeat") then
            if obj.Name == "Guardian" or obj.Name:match("Guardian%d*") then
                myBoat = obj
                break
            end
        end
    end
    if myBoat then break end
    task.wait(0.5)
end

if myBoat then
    controlBoat(myBoat)
else
    warn("Своя лодка не найдена")
end
