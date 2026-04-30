-- ===== РАСШИРЕННЫЙ ТРЕКЕР: CFrame, Y, BodyVelocity, BodyPosition, BodyGyro =====
local player = game.Players.LocalPlayer

local function log(...) print(os.date("%H:%M:%S"), ...) end

-- Ждём лодку
local function waitForBoat()
    while true do
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart then
                local seat = humanoid.SeatPart
                local boat = seat:FindFirstAncestorWhichIsA("Model")
                if boat then return boat, seat end
            end
        end
        task.wait(0.5)
    end
end

log("Ожидание посадки в лодку...")
local boat, seat = waitForBoat()
log("Лодка найдена: " .. boat:GetFullName())

local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Нет основной части") end

-- Отслеживаем CFrame (особенно Y)
local lastY = rootPart.Position.Y
local lastCF = rootPart.CFrame
rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newCF = rootPart.CFrame
    local newY = newCF.Position.Y
    if math.abs(newY - lastY) > 0.005 then
        log(string.format("[ЛОДКА CFrame] Y: %.3f -> %.3f (delta=%.3f)", lastY, newY, newY - lastY))
        lastY = newY
    end
    lastCF = newCF
end)

-- Функция отслеживания физических объектов
local function trackPhysics(obj, name)
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("BodyVelocity") then
            log(string.format("[%s] BodyVelocity на %s, скорость=%s", name, child.Parent and child.Parent.Name or "nil", tostring(child.Velocity)))
            child:GetPropertyChangedSignal("Velocity"):Connect(function()
                log(string.format("[%s] BodyVelocity изменена: %s", name, tostring(child.Velocity)))
            end)
            child.AncestryChanged:Connect(function()
                if not child.Parent then log(string.format("[%s] BodyVelocity удалён", name)) end
            end)
        elseif child:IsA("BodyPosition") then
            log(string.format("[%s] BodyPosition на %s, позиция=%s", name, child.Parent and child.Parent.Name or "nil", tostring(child.Position)))
            child:GetPropertyChangedSignal("Position"):Connect(function()
                log(string.format("[%s] BodyPosition изменён: %s", name, tostring(child.Position)))
            end)
            child.AncestryChanged:Connect(function()
                if not child.Parent then log(string.format("[%s] BodyPosition удалён", name)) end
            end)
        elseif child:IsA("BodyGyro") then
            log(string.format("[%s] BodyGyro на %s", name, child.Parent and child.Parent.Name or "nil"))
            child.AncestryChanged:Connect(function()
                if not child.Parent then log(string.format("[%s] BodyGyro удалён", name)) end
            end)
        end
    end
    obj.DescendantAdded:Connect(function(desc)
        if desc:IsA("BodyVelocity") then
            log(string.format("[%s] Добавлен BodyVelocity на %s, скорость=%s", name, desc.Parent and desc.Parent.Name or "nil", tostring(desc.Velocity)))
        elseif desc:IsA("BodyPosition") then
            log(string.format("[%s] Добавлен BodyPosition на %s, позиция=%s", name, desc.Parent and desc.Parent.Name or "nil", tostring(desc.Position)))
        elseif desc:IsA("BodyGyro") then
            log(string.format("[%s] Добавлен BodyGyro на %s", name, desc.Parent and desc.Parent.Name or "nil"))
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

-- Периодический вывод (каждые 3 секунды)
task.spawn(function()
    while true do
        task.wait(3)
        if rootPart and rootPart.Parent then
            local pos = rootPart.Position
            log(string.format("[ПЕРИОД] Лодка позиция: (%.1f, %.3f, %.1f)", pos.X, pos.Y, pos.Z))
        end
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
                if bv then
                    log(string.format("[ПЕРИОД] BodyVelocity на персонаже: %s", tostring(bv.Velocity)))
                end
            end
        end
    end
end)

log("Трекер запущен. Включайте эталонный скрипт.")
