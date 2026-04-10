-- ===== ПОЛНЫЙ СКРИПТ (перемещение + призыв + управление своей лодкой) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- 1. Плавное перемещение в точку (-16917, 9.1, 447) с отключением коллизий
local targetPos = Vector3.new(-16917, 9.1, 447)
local speed = 150          -- скорость перемещения (студий/сек)
local step = 0.1           -- интервал обновления

-- Отключаем коллизии у всех частей персонажа
local parts = {}
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then
        table.insert(parts, part)
        part.CanCollide = false
    end
end

-- Перемещение
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

-- Восстанавливаем коллизии
for _, part in ipairs(parts) do
    if part and part.Parent then
        part.CanCollide = true
    end
end
print("Перемещение завершено")

-- 2. Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание...")
task.wait(3)

-- 3. Функция управления лодкой
local function controlBoat(boat)
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return end

    -- Отключаем коллизии у лодки и её родной скрипт
    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = boat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Tween к сиденью
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()

    -- Садимся
    humanoid.Sit = true
    task.wait(0.5)

    -- Движение лодки
    local root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    local boatSpeed = -420
    local runService = game:GetService("RunService")
    runService.RenderStepped:Connect(function(dt)
        if humanoid.Sit and humanoid.SeatPart == seat then
            root.CFrame = root.CFrame * CFrame.new(0, 0, boatSpeed * dt)
        end
    end)
    print("Лодка движется")
end

-- 4. Поиск своей лодки (имя начинается с "Guardian")
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
