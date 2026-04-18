-- ===== УНИВЕРСАЛЬНЫЙ ЛОГГЕР ДЕЙСТВИЙ (без модификации метатаблиц) =====
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- 1. Отслеживаем появление/удаление объектов в workspace и ReplicatedStorage
local function trackDescendants(container, name)
    container.ChildAdded:Connect(function(child)
        log(name .. " + " .. child:GetFullName() .. " (" .. child.ClassName .. ")")
    end)
    container.ChildRemoved:Connect(function(child)
        log(name .. " - " .. child:GetFullName())
    end)
end
trackDescendants(workspace, "WS")
trackDescendants(game:GetService("ReplicatedStorage"), "RS")

-- 2. Отслеживаем изменения свойств у всех частей лодки (если она появится)
local function watchBoat(boat)
    if not boat then return end
    local function logChange(part, prop)
        part:GetPropertyChangedSignal(prop):Connect(function()
            log("Boat " .. part:GetFullName() .. " " .. prop .. " = " .. tostring(part[prop]))
        end)
    end
    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then
            logChange(part, "Position")
            logChange(part, "CFrame")
            logChange(part, "Velocity")
            logChange(part, "CanCollide")
        elseif part:IsA("BodyVelocity") or part:IsA("BodyPosition") then
            logChange(part, "Velocity")
            logChange(part, "Position")
        end
    end
end

-- 3. Следим за появлением лодки (по имени Guardian)
workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "Guardian" and desc:IsA("Model") then
        log("!!! ЛОДКА ПОЯВИЛАСЬ: " .. desc:GetFullName())
        watchBoat(desc)
    end
end)

-- 4. Отслеживаем изменения позиции персонажа (для сравнения)
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local lastPos = hrp.Position
hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local newPos = hrp.Position
    if (newPos - lastPos).Magnitude > 0.5 then
        log("CHAR POS: " .. tostring(newPos))
        lastPos = newPos
    end
end)

-- 5. Отслеживаем изменения PlatformStand и Sit
local humanoid = char:WaitForChild("Humanoid")
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log("PLATFORMSTAND = " .. tostring(humanoid.PlatformStand))
end)
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    log("SIT = " .. tostring(humanoid.Sit) .. ", SeatPart = " .. tostring(humanoid.SeatPart))
end)

-- 6. Перехват создания BodyVelocity (глобально, но безопасно)
local oldNew = Instance.new
Instance.new = function(className, parent)
    local instance = oldNew(className, parent)
    if className == "BodyVelocity" then
        log("NEW BodyVelocity, Parent = " .. tostring(parent))
        instance:GetPropertyChangedSignal("Velocity"):Connect(function()
            log("BodyVelocity Velocity = " .. tostring(instance.Velocity))
        end)
    end
    return instance
end

log("Логгер запущен. Теперь активируйте эталонный скрипт. Все изменения будут в консоли.")
