-- ===== ТРЕКЕР ДЛЯ АНАЛИЗА ФИКСАЦИИ ВЫСОТЫ В ЭТАЛОННОМ СКРИПТЕ =====
-- Запустите этот трекер, затем активируйте эталонный скрипт.
-- Трекер будет выводить в консоль все важные изменения с временем.

local player = game.Players.LocalPlayer
local function log(...) print(os.date("%H:%M:%S"), ...) end

-- Ждём, пока персонаж сядет в лодку (чтобы знать, какая лодка)
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
if not rootPart then
    error("Не найдена основная часть лодки")
end

-- Отслеживаем CFrame лодки (особенно Y)
local lastCF = rootPart.CFrame
local lastY = rootPart.Position.Y
local lastTime = os.clock()

rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newCF = rootPart.CFrame
    local newY = newCF.Position.Y
    local now = os.clock()
    local deltaY = newY - lastY
    if math.abs(deltaY) > 0.01 then
        log(string.format("[ЛОДКА] CFrame изменился: Y=%.3f (delta=%.3f)", newY, deltaY))
        lastY = newY
    end
    lastCF = newCF
end)

-- Отслеживаем все BodyVelocity, BodyPosition, BodyGyro на лодке и на персонаже
local function trackPhysicsObjects(instance, name)
    for _, obj in ipairs(instance:GetDescendants()) do
        if obj:IsA("BodyVelocity") then
            log(string.format("[%s] BodyVelocity найден на %s, Velocity=%s", name, obj.Parent and obj.Parent.Name or "nil", tostring(obj.Velocity)))
            obj:GetPropertyChangedSignal("Velocity"):Connect(function()
                log(string.format("[%s] BodyVelocity скорость изменена: %s", name, tostring(obj.Velocity)))
            end)
            obj.AncestryChanged:Connect(function()
                if not obj.Parent then log(string.format("[%s] BodyVelocity удалён", name)) end
            end)
        elseif obj:IsA("BodyPosition") then
            log(string.format("[%s] BodyPosition найден на %s, Position=%s", name, obj.Parent and obj.Parent.Name or "nil", tostring(obj.Position)))
            obj:GetPropertyChangedSignal("Position"):Connect(function()
                log(string.format("[%s] BodyPosition позиция изменена: %s", name, tostring(obj.Position)))
            end)
            obj.AncestryChanged:Connect(function()
                if not obj.Parent then log(string.format("[%s] BodyPosition удалён", name)) end
            end)
        elseif obj:IsA("BodyGyro") then
            log(string.format("[%s] BodyGyro найден на %s", name, obj.Parent and obj.Parent.Name or "nil"))
            obj.AncestryChanged:Connect(function()
                if not obj.Parent then log(string.format("[%s] BodyGyro удалён", name)) end
            end)
        end
    end
    instance.DescendantAdded:Connect(function(desc)
        if desc:IsA("BodyVelocity") then
            log(string.format("[%s] Добавлен BodyVelocity на %s, Velocity=%s", name, desc.Parent and desc.Parent.Name or "nil", tostring(desc.Velocity)))
        elseif desc:IsA("BodyPosition") then
            log(string.format("[%s] Добавлен BodyPosition на %s, Position=%s", name, desc.Parent and desc.Parent.Name or "nil", tostring(desc.Position)))
        elseif desc:IsA("BodyGyro") then
            log(string.format("[%s] Добавлен BodyGyro на %s", name, desc.Parent and desc.Parent.Name or "nil"))
        end
    end)
end

trackPhysicsObjects(boat, "ЛОДКА")
local char = player.Character
if char then
    trackPhysicsObjects(char, "ПЕРСОНАЖ")
else
    player.CharacterAdded:Connect(function(newChar) trackPhysicsObjects(newChar, "ПЕРСОНАЖ") end)
end

-- Периодический вывод состояния (каждые 5 секунд)
task.spawn(function()
    while true do
        task.wait(5)
        local pos = rootPart.Position
        log(string.format("[ПЕРИОД] Позиция лодки: (%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z))
        local char = player.Character
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

log("Трекер запущен. Теперь активируйте эталонный скрипт.")
