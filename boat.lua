-- ========== ПОЛНЫЙ СКРИПТ (рабочий) ==========
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- 1. Плавное перемещение в точку (-16917, 9.1, 447)
local targetPos = Vector3.new(-16917, 9.1, 447)
local distance = (hrp.Position - targetPos).Magnitude
local speed = 420                 -- скорость перемещения (как у лодки)
local duration = distance / speed

-- Отключаем коллизии у всех частей персонажа (чтобы не застревать)
local partsCollision = {}
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then
        partsCollision[part] = part.CanCollide
        part.CanCollide = false
    end
end

-- Замораживаем анимации и физику
local oldPlatform = humanoid.PlatformStand
humanoid.PlatformStand = true

-- Tween
local tween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = targetPos})
tween:Play()
tween.Completed:Wait()

-- Восстанавливаем
humanoid.PlatformStand = oldPlatform
for part, val in pairs(partsCollision) do
    if part and part.Parent then
        part.CanCollide = val
    end
end
print("Перемещение завершено")

-- 2. Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание...")
task.wait(3)

-- 3. Управление лодкой (посадка + движение)
local function controlBoat(boat)
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return end

    -- Отключаем коллизии у лодки
    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- Отключаем родной скрипт лодки (если есть)
    local nativeScript = boat:FindFirstChild("Script")
    if nativeScript then
        nativeScript.Disabled = true
    end

    -- Tween к сиденью
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tweenSeat = game:GetService("TweenService"):Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tweenSeat:Play()
    tweenSeat.Completed:Wait()

    -- Садимся
    humanoid.Sit = true
    task.wait(0.5)

    -- Движение лодки
    local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then return end
    local boatSpeed = -420
    local runService = game:GetService("RunService")
    runService.RenderStepped:Connect(function(deltaTime)
        if humanoid.Sit and humanoid.SeatPart == seat then
            local step = boatSpeed * deltaTime
            rootPart.CFrame = rootPart.CFrame * CFrame.new(0, 0, step)
        end
    end)
    print("Лодка движется")
end

-- Поиск появившейся лодки
task.spawn(function()
    while true do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildWhichIsA("VehicleSeat") and not obj:GetAttribute("UnderControl") then
                obj:SetAttribute("UnderControl", true)
                controlBoat(obj)
                return
            end
        end
        task.wait(1)
    end
end)
