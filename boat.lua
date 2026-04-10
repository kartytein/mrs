-- Автоматическое управление лодкой (любой, которая появляется в Boats)
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local boatsFolder = workspace:FindFirstChild("Boats")
if not boatsFolder then
    boatsFolder = Instance.new("Folder")
    boatsFolder.Name = "Boats"
    boatsFolder.Parent = workspace
end

local function controlBoat(boat)
    print("Обнаружена лодка:", boat.Name)

    -- Отключаем столкновения у всех частей лодки
    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- Отключаем родной скрипт управления, если есть
    local nativeScript = boat:FindFirstChild("Script")
    if nativeScript then nativeScript.Disabled = true end

    -- Садимся на сиденье
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return end
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    humanoid.Sit = true
    task.wait(0.5)

    -- Движение лодки (плавное, без рывков)
    local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then return end
    local speed = -420  -- скорость по оси Z
    local runService = game:GetService("RunService")
    runService.RenderStepped:Connect(function(deltaTime)
        if humanoid.Sit and humanoid.SeatPart == seat then
            local step = speed * deltaTime
            rootPart.CFrame = rootPart.CFrame * CFrame.new(0, 0, step)
        end
    end)
    print("Лодка начала движение")
end

-- Отслеживаем появление новых лодок
boatsFolder.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child:FindFirstChildWhichIsA("VehicleSeat") then
        controlBoat(child)
    end
end)

-- Проверяем уже существующие лодки
for _, child in ipairs(boatsFolder:GetChildren()) do
    if child:IsA("Model") and child:FindFirstChildWhichIsA("VehicleSeat") then
        controlBoat(child)
    end
end

print("Ожидание появления лодки в папке Boats...")
