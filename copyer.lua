-- ===== БЕЗОПАСНЫЙ ЛОГГЕР (без модификации глобальных таблиц) =====
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- 1. Отслеживаем появление объектов в workspace и ReplicatedStorage
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

-- 2. Следим за появлением лодки (Guardian) и подписываемся на её изменения
workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "Guardian" and desc:IsA("Model") then
        log("!!! ЛОДКА ПОЯВИЛАСЬ: " .. desc:GetFullName())
        -- Отслеживаем изменения свойств частей лодки
        for _, part in ipairs(desc:GetDescendants()) do
            if part:IsA("BasePart") then
                part:GetPropertyChangedSignal("Position"):Connect(function()
                    log("Boat " .. part:GetFullName() .. " Position = " .. tostring(part.Position))
                end)
                part:GetPropertyChangedSignal("CFrame"):Connect(function()
                    log("Boat " .. part:GetFullName() .. " CFrame = " .. tostring(part.CFrame))
                end)
                part:GetPropertyChangedSignal("CanCollide"):Connect(function()
                    log("Boat " .. part:GetFullName() .. " CanCollide = " .. tostring(part.CanCollide))
                end)
            elseif part:IsA("BodyVelocity") then
                part:GetPropertyChangedSignal("Velocity"):Connect(function()
                    log("BodyVelocity " .. part:GetFullName() .. " Velocity = " .. tostring(part.Velocity))
                end)
            end
        end
    end
end)

-- 3. Отслеживаем изменения позиции персонажа
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

-- 4. Отслеживаем изменения PlatformStand и Sit
local humanoid = char:WaitForChild("Humanoid")
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log("PLATFORMSTAND = " .. tostring(humanoid.PlatformStand))
end)
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    log("SIT = " .. tostring(humanoid.Sit) .. ", SeatPart = " .. tostring(humanoid.SeatPart))
end)

-- 5. Отслеживаем появление BodyVelocity у персонажа
char.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log("CHAR BodyVelocity added, Velocity = " .. tostring(desc.Velocity))
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log("CHAR BodyVelocity Velocity = " .. tostring(desc.Velocity))
        end)
    end
end)

log("Логгер запущен. Теперь активируйте эталонный скрипт. Все изменения будут в консоли.")
