-- Тестер разных способов управления лодкой
local player = game.Players.LocalPlayer
local boat = workspace:FindFirstChild("Boats") and workspace.Boats:FindFirstChild("Guardian")
if not boat then
    warn("Лодка не найдена. Убедитесь, что вы сидите в лодке Guardian.")
    return
end

local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    warn("Не найдена основная часть лодки")
    return
end

local function log(msg)
    print("[TEST] " .. msg)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {Text = msg, Color = Color3.new(1,1,0)})
end

local function waitForMovement(duration)
    local startPos = rootPart.Position
    for i = 1, duration * 2 do
        task.wait(0.5)
        if (rootPart.Position - startPos).Magnitude > 1 then
            return true
        end
    end
    return false
end

-- Список методов для тестирования
local methods = {
    -- Метод 1: BodyVelocity с постоянной скоростью по X
    function()
        log("Метод 1: BodyVelocity по X (скорость 420)")
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(420, 0, 0)
        bv.Parent = rootPart
        task.wait(3)
        bv:Destroy()
        return waitForMovement(3)
    end,
    -- Метод 2: BodyVelocity по Z
    function()
        log("Метод 2: BodyVelocity по Z (скорость 420)")
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 420)
        bv.Parent = rootPart
        task.wait(3)
        bv:Destroy()
        return waitForMovement(3)
    end,
    -- Метод 3: Tween к точке
    function()
        log("Метод 3: Tween к точке (500 столов по X)")
        local target = rootPart.Position + Vector3.new(500, 0, 0)
        local tween = game:GetService("TweenService"):Create(rootPart, TweenInfo.new(5, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
        tween:Play()
        tween.Completed:Wait()
        return waitForMovement(5)
    end,
    -- Метод 4: Применение силы к сиденью (если сиденье есть)
    function()
        log("Метод 4: BodyVelocity к VehicleSeat")
        local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
        if not seat then
            log("Сиденье не найдено, пропуск")
            return false
        end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(420, 0, 0)
        bv.Parent = seat
        task.wait(3)
        bv:Destroy()
        return waitForMovement(3)
    end,
    -- Метод 5: Изменение CFrame через цикл
    function()
        log("Метод 5: Прямое изменение CFrame (пошагово)")
        for i = 1, 50 do
            rootPart.CFrame = rootPart.CFrame * CFrame.new(10, 0, 0)
            task.wait(0.1)
        end
        return waitForMovement(5)
    end,
}

for i, method in ipairs(methods) do
    if method() then
        log("УСПЕХ! Лодка сдвинулась при использовании метода " .. i)
        break
    else
        log("Метод " .. i .. " не сдвинул лодку")
    end
end

log("Тестирование завершено. Если лодка не сдвинулась, возможно, она заблокирована физикой или якорь.")
