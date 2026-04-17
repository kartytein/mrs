-- Трекер для лодки (аналогично трекеру персонажа)
-- Запустите после того, как лодка появится и начнёт движение.
local player = game.Players.LocalPlayer
local playerName = player.Name

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

local boat = findMyBoat()
if not boat then
    warn("Лодка не найдена")
    return
end

print("=== Трекер для лодки: " .. boat.Name .. " ===")

local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    warn("Нет основной части")
    return
end

-- Отслеживание изменения CFrame
local lastCF = rootPart.CFrame
rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newCF = rootPart.CFrame
    local delta = (newCF.Position - lastCF.Position).Magnitude
    print(string.format("[CFRAME] delta: %.2f, new pos: %s", delta, tostring(newCF.Position)))
    lastCF = newCF
end)

-- Отслеживание изменения Position
rootPart:GetPropertyChangedSignal("Position"):Connect(function()
    print("[POSITION] " .. tostring(rootPart.Position))
end)

-- Отслеживание изменения Velocity (если есть BodyVelocity)
local function watchBodyVelocity(bv)
    if not bv then return end
    local lastVel = bv.Velocity
    bv:GetPropertyChangedSignal("Velocity"):Connect(function()
        print("[BODYVELOCITY] Velocity changed: " .. tostring(lastVel) .. " -> " .. tostring(bv.Velocity))
        lastVel = bv.Velocity
    end)
    print("[BODYVELOCITY] Created, Velocity = " .. tostring(bv.Velocity))
end

-- Поиск существующих BodyVelocity
for _, bv in ipairs(boat:GetDescendants()) do
    if bv:IsA("BodyVelocity") then
        watchBodyVelocity(bv)
    end
end
boat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        watchBodyVelocity(desc)
    end
end)

-- Отслеживание появления Tween
local function watchTween(tween)
    print("[TWEEN] Created for " .. tween.Parent:GetFullName())
    tween:GetPropertyChangedSignal("PlaybackState"):Connect(function()
        print("[TWEEN] State: " .. tostring(tween.PlaybackState))
    end)
end
for _, tween in ipairs(boat:GetDescendants()) do
    if tween:IsA("Tween") then
        watchTween(tween)
    end
end
boat.DescendantAdded:Connect(function(desc)
    if desc:IsA("Tween") then
        watchTween(desc)
    end
end)

-- Отслеживание изменения CanCollide у частей лодки (если есть)
local function trackPartCollision(part)
    part:GetPropertyChangedSignal("CanCollide"):Connect(function()
        print("[COLLIDE] " .. part.Name .. " CanCollide = " .. tostring(part.CanCollide))
    end)
end
for _, part in ipairs(boat:GetDescendants()) do
    if part:IsA("BasePart") then
        trackPartCollision(part)
    end
end
boat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then
        trackPartCollision(desc)
    end
end)

print("Трекер запущен. Наблюдаем за лодкой.")
