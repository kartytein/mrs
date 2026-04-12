-- Простой скрипт для посадки на лодку (по владельцу)
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
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

local function sitOnBoat()
    local boat = findMyBoat()
    if not boat then
        warn("Лодка не найдена")
        return
    end
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then
        warn("Сиденье не найдено")
        return
    end
    
    local char = player.Character
    if not char then
        warn("Персонаж не загружен")
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        warn("Нет HumanoidRootPart или Humanoid")
        return
    end
    
    -- Отключаем коллизии и замораживаем
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    humanoid.PlatformStand = true
    
    -- Цель: чуть выше сиденья
    local targetCF = seat.CFrame + Vector3.new(0, 2.5, 0)
    local distance = (hrp.Position - targetCF.Position).Magnitude
    local duration = math.min(distance / 150, 2) -- максимум 2 секунды
    if duration < 0.2 then duration = 0.2 end
    
    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
    task.wait(0.2)
    humanoid.Sit = true
    humanoid.PlatformStand = false
    print("Посадка выполнена")
end

sitOnBoat()
