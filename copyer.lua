-- ===== ЛОГГЕР БЕЗ МОДИФИКАЦИИ ГЛОБАЛЬНЫХ ФУНКЦИЙ =====
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- 1. Отслеживаем появление новых объектов в workspace и ReplicatedStorage
local function trackNewObjects(container, name)
    container.ChildAdded:Connect(function(child)
        log(name .. " + " .. child:GetFullName() .. " (" .. child.ClassName .. ")")
        -- Если это лодка, начинаем следить за её частями
        if child.Name == "Guardian" and child:IsA("Model") then
            log("!!! ЛОДКА ПОЯВИЛАСЬ: " .. child:GetFullName())
            watchBoat(child)
        end
    end)
    container.ChildRemoved:Connect(function(child)
        log(name .. " - " .. child:GetFullName())
    end)
end

-- Функция наблюдения за лодкой (её частями и движителями)
function watchBoat(boat)
    local function watchPart(part)
        if part:IsA("BasePart") then
            part:GetPropertyChangedSignal("Position"):Connect(function()
                log("Boat " .. part:GetFullName() .. " Position = " .. tostring(part.Position))
            end)
            part:GetPropertyChangedSignal("CFrame"):Connect(function()
                log("Boat " .. part:GetFullName() .. " CFrame = " .. tostring(part.CFrame))
            end)
            part:GetPropertyChangedSignal("Velocity"):Connect(function()
                log("Boat " .. part:GetFullName() .. " Velocity = " .. tostring(part.Velocity))
            end)
        elseif part:IsA("BodyVelocity") then
            part:GetPropertyChangedSignal("Velocity"):Connect(function()
                log("Boat BodyVelocity Velocity = " .. tostring(part.Velocity))
            end)
        end
    end
    -- Наблюдаем за всеми существующими частями
    for _, part in ipairs(boat:GetDescendants()) do
        watchPart(part)
    end
    -- Наблюдаем за новыми частями
    boat.DescendantAdded:Connect(watchPart)
end

-- 2. Отслеживаем изменения позиции персонажа
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

-- 3. Отслеживаем состояние PlatformStand и Sit
local humanoid = char:WaitForChild("Humanoid")
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log("PLATFORMSTAND = " .. tostring(humanoid.PlatformStand))
end)
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    log("SIT = " .. tostring(humanoid.Sit) .. ", SeatPart = " .. tostring(humanoid.SeatPart))
end)

-- 4. Отслеживаем появление BodyVelocity (без перехвата Instance.new)
workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log("NEW BodyVelocity, Parent = " .. tostring(desc.Parent))
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log("BodyVelocity Velocity = " .. tostring(desc.Velocity))
        end)
    end
end)

-- Запускаем отслеживание
trackNewObjects(workspace, "WS")
trackNewObjects(game:GetService("ReplicatedStorage"), "RS")

log("Логгер запущен. Теперь активируйте эталонный скрипт. Все изменения будут в консоли.")
