-- Трекер для анализа эталонного скрипта (вывод всего, что касается лодки и персонажа)
local player = game.Players.LocalPlayer
local function log(...) print(os.date("%H:%M:%S"), ...) end

-- Ожидание посадки в лодку
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
        task.wait(0.2)
    end
end

log("Ожидание посадки в лодку...")
local boat, seat = waitForBoat()
log("Лодка: " .. boat:GetFullName())
local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Нет основной части") end
log("Основная часть: " .. rootPart:GetFullName())

-- Отслеживаем CFrame лодки (особенно Y, чтобы видеть изменения высоты)
local lastY = rootPart.Position.Y
rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newY = rootPart.Position.Y
    if math.abs(newY - lastY) > 0.001 then
        log(string.format("[ЛОДКА] Y = %.3f (изменение на %.3f)", newY, newY - lastY))
        lastY = newY
    end
end)

-- Поиск BodyVelocity, BodyPosition, BodyGyro на лодке и на персонаже
local function track(instance, name)
    for _, obj in ipairs(instance:GetDescendants()) do
        if obj:IsA("BodyVelocity") then
            log(string.format("[%s] BodyVelocity создан на %s, Velocity=%s", name, obj.Parent and obj.Parent.Name or "nil", tostring(obj.Velocity)))
            obj:GetPropertyChangedSignal("Velocity"):Connect(function() 
                log(string.format("[%s] BodyVelocity скорость изменена: %s", name, tostring(obj.Velocity))) 
            end)
            obj.AncestryChanged:Connect(function() 
                if not obj.Parent then log(string.format("[%s] BodyVelocity удалён", name)) end 
            end)
        elseif obj:IsA("BodyPosition") then
            log(string.format("[%s] BodyPosition создан на %s, Position=%s", name, obj.Parent and obj.Parent.Name or "nil", tostring(obj.Position)))
            obj:GetPropertyChangedSignal("Position"):Connect(function() 
                log(string.format("[%s] BodyPosition позиция изменена: %s", name, tostring(obj.Position))) 
            end)
            obj.AncestryChanged:Connect(function() 
                if not obj.Parent then log(string.format("[%s] BodyPosition удалён", name)) end 
            end)
        elseif obj:IsA("BodyGyro") then
            log(string.format("[%s] BodyGyro создан на %s", name, obj.Parent and obj.Parent.Name or "nil"))
        end
    end
    instance.DescendantAdded:Connect(function(desc)
        if desc:IsA("BodyVelocity") then
            log(string.format("[%s] BodyVelocity добавлен на %s, Velocity=%s", name, desc.Parent and desc.Parent.Name or "nil", tostring(desc.Velocity)))
        elseif desc:IsA("BodyPosition") then
            log(string.format("[%s] BodyPosition добавлен на %s, Position=%s", name, desc.Parent and desc.Parent.Name or "nil", tostring(desc.Position)))
        elseif desc:IsA("BodyGyro") then
            log(string.format("[%s] BodyGyro добавлен на %s", name, desc.Parent and desc.Parent.Name or "nil"))
        end
    end)
end
track(boat, "ЛОДКА")
local char = player.Character
if char then track(char, "ПЕРСОНАЖ") end
player.CharacterAdded:Connect(function(c) track(c, "ПЕРСОНАЖ") end)

-- Также отслеживаем изменение SeatPart у персонажа (может влиять на выход из лодки)
local function seatTracker()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
                log(string.format("[ПЕРСОНАЖ] SeatPart = %s", tostring(humanoid.SeatPart)))
            end)
        end
    end
end
seatTracker()
player.CharacterAdded:Connect(seatTracker)

log("Трекер запущен. Теперь активируйте эталонный скрипт.")
