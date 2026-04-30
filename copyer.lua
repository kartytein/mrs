-- Трекер: CFrame, BodyVelocity, BodyPosition, BodyGyro, изменения позиции
local player = game.Players.LocalPlayer
local logFile = ""  -- накопим вывод

local function log(msg)
    local timestamp = os.date("%H:%M:%S")
    local line = "[" .. timestamp .. "] " .. msg
    print(line)
    logFile = logFile .. line .. "\n"
end

-- Ждём, пока персонаж сядет в лодку
local function waitForSeat()
    while true do
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart then
                return humanoid.SeatPart
            end
        end
        task.wait(0.5)
    end
end

log("Ожидание посадки в лодку...")
local seat = waitForSeat()
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then
    log("Ошибка: лодка не найдена")
    return
end
log("Лодка найдена: " .. boat:GetFullName())

local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    log("Ошибка: основная часть не найдена")
    return
end

-- Функция отслеживания физических объектов
local function trackPhysics(obj, name)
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("BodyVelocity") then
            log(string.format("ОБНАРУЖЕН %s BodyVelocity на %s, скорость = %s", name, tostring(child.Parent and child.Parent.Name or "nil"), tostring(child.Velocity)))
            child:GetPropertyChangedSignal("Velocity"):Connect(function()
                log(string.format("%s BodyVelocity скорость изменена: %s", name, tostring(child.Velocity)))
            end)
            child.AncestryChanged:Connect(function()
                if not child.Parent then log(string.format("%s BodyVelocity УДАЛЁН", name)) end
            end)
        elseif child:IsA("BodyPosition") then
            log(string.format("ОБНАРУЖЕН %s BodyPosition на %s, позиция = %s", name, tostring(child.Parent and child.Parent.Name or "nil"), tostring(child.Position)))
            child:GetPropertyChangedSignal("Position"):Connect(function()
                log(string.format("%s BodyPosition позиция изменена: %s", name, tostring(child.Position)))
            end)
            child.AncestryChanged:Connect(function()
                if not child.Parent then log(string.format("%s BodyPosition УДАЛЁН", name)) end
            end)
        elseif child:IsA("BodyGyro") then
            log(string.format("ОБНАРУЖЕН %s BodyGyro на %s", name, tostring(child.Parent and child.Parent.Name or "nil")))
            child.AncestryChanged:Connect(function()
                if not child.Parent then log(string.format("%s BodyGyro УДАЛЁН", name)) end
            end)
        end
    end
    obj.DescendantAdded:Connect(function(desc)
        if desc:IsA("BodyVelocity") then
            log(string.format("ДОБАВЛЕН %s BodyVelocity на %s, скорость = %s", name, tostring(desc.Parent and desc.Parent.Name or "nil"), tostring(desc.Velocity)))
        elseif desc:IsA("BodyPosition") then
            log(string.format("ДОБАВЛЕН %s BodyPosition на %s, позиция = %s", name, tostring(desc.Parent and desc.Parent.Name or "nil"), tostring(desc.Position)))
        elseif desc:IsA("BodyGyro") then
            log(string.format("ДОБАВЛЕН %s BodyGyro на %s", name, tostring(desc.Parent and desc.Parent.Name or "nil")))
        end
    end)
end

trackPhysics(boat, "ЛОДКА")
local char = player.Character
if char then
    trackPhysics(char, "ПЕРСОНАЖ")
else
    player.CharacterAdded:Connect(function(c) trackPhysics(c, "ПЕРСОНАЖ") end)
end

-- Отслеживаем CFrame лодки (особенно Y)
local lastY = rootPart.Position.Y
local lastCF = rootPart.CFrame
rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newCF = rootPart.CFrame
    local newY = newCF.Position.Y
    if math.abs(newY - lastY) > 0.01 then
        log(string.format("ЛОДКА CFrame изменился: Y %.3f -> %.3f (delta=%.3f)", lastY, newY, newY - lastY))
        lastY = newY
    end
    lastCF = newCF
end)

-- Периодический вывод позиции лодки каждые 2 секунды
task.spawn(function()
    while true do
        task.wait(2)
        local pos = rootPart.Position
        log(string.format("ПЕРИОД: позиция лодки = (%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z))
    end
end)

log("Трекер запущен. Теперь активируйте эталонный скрипт управления лодкой. Через 60-90 секунд скопируйте лог.")
