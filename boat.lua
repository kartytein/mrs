-- Универсальный скрипт управления лодкой (работает с любой моделью, имеющей VehicleSeat)
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local function controlBoat(boat)
    print("Обнаружена лодка:", boat.Name)

    -- Ждём появления сиденья (на случай, если модель загружается не мгновенно)
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then
        seat = boat.ChildAdded:Wait()
        while not seat:IsA("VehicleSeat") do
            seat = boat.ChildAdded:Wait()
        end
    end
    print("Сиденье найдено")

    -- Отключаем столкновения у всех частей лодки
    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- Отключаем родной скрипт управления (если есть)
    local nativeScript = boat:FindFirstChild("Script")
    if nativeScript then
        nativeScript.Disabled = true
    end

    -- Плавное перемещение к сиденью (Tween)
    local targetCF = seat.CFrame + Vector3.new(0, 2, 0)
    local tweenService = game:GetService("TweenService")
    local tween = tweenService:Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()

    -- Садимся
    humanoid.Sit = true
    task.wait(0.5) -- небольшая пауза для стабилизации

    -- Основная часть для движения
    local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then
        warn("Не найдена основная часть лодки")
        return
    end

    -- Движение с постоянной скоростью (плавно, через RenderStepped)
    local speed = -420  -- единиц в секунду (отрицательное = движение назад по Z)
    local runService = game:GetService("RunService")
    runService.RenderStepped:Connect(function(deltaTime)
        -- Проверяем, сидит ли игрок на этом же сиденье
        if humanoid.Sit and humanoid.SeatPart == seat then
            local step = speed * deltaTime
            rootPart.CFrame = rootPart.CFrame * CFrame.new(0, 0, step)
        end
    end)

    print("Лодка", boat.Name, "начала движение со скоростью", math.abs(speed), "в секунду")
end

-- Поиск лодки (сканируем workspace раз в секунду, пока не найдём)
task.spawn(function()
    while true do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildWhichIsA("VehicleSeat") then
                -- Избегаем повторного управления одной и той же лодкой
                if not obj:GetAttribute("UnderControl") then
                    obj:SetAttribute("UnderControl", true)
                    controlBoat(obj)
                    return -- останавливаем поиск после успеха
                end
            end
        end
        task.wait(1)
    end
end)

print("Ожидание появления лодки... (активируйте создание лодки)")
