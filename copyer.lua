-- ===== ДИАГНОСТИЧЕСКИЙ ТРЕКЕР С ВРЕМЕНЕМ И ПРИЧИНОЙ =====
-- Запустите этот скрипт ДО активации эталонного скрипта.
-- Он будет фиксировать все изменения позиции, CFrame, BodyVelocity, PlatformStand, Sit.
-- Вывод в консоль и в чат (системное сообщение).

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local function log(msg, reason)
    local timeStr = os.date("%H:%M:%S")
    local fullMsg = string.format("[%s] %s%s", timeStr, msg, reason and (" (причина: " .. reason .. ")") or "")
    print(fullMsg)
    -- Вывод в чат (как системное сообщение)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
        Text = fullMsg,
        Color = Color3.new(1, 0, 0)
    })
end

-- Сохраняем предыдущее состояние для отслеживания изменений
local lastPos = hrp.Position
local lastCF = hrp.CFrame
local lastPlatform = humanoid.PlatformStand
local lastSit = humanoid.Sit
local lastSeatPart = humanoid.SeatPart

-- Отслеживаем Position
hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local newPos = hrp.Position
    local delta = (newPos - lastPos).Magnitude
    log(string.format("Position изменилось: (%.1f, %.1f, %.1f) -> (%.1f, %.1f, %.1f), дельта = %.2f",
        lastPos.X, lastPos.Y, lastPos.Z,
        newPos.X, newPos.Y, newPos.Z, delta), "Position changed")
    lastPos = newPos
end)

-- Отслеживаем CFrame
hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newCF = hrp.CFrame
    if (newCF.Position - lastCF.Position).Magnitude > 0.01 then
        log(string.format("CFrame изменилось: %s", tostring(newCF)), "CFrame changed")
        lastCF = newCF
    end
end)

-- Отслеживаем PlatformStand
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    local newPlatform = humanoid.PlatformStand
    if newPlatform ~= lastPlatform then
        log(string.format("PlatformStand = %s", tostring(newPlatform)), "PlatformStand changed")
        lastPlatform = newPlatform
    end
end)

-- Отслеживаем Sit и SeatPart
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    local newSit = humanoid.Sit
    if newSit ~= lastSit then
        log(string.format("Sit = %s, SeatPart = %s", tostring(newSit), tostring(humanoid.SeatPart)), "Sit changed")
        lastSit = newSit
        lastSeatPart = humanoid.SeatPart
    end
end)

-- Отслеживаем создание и удаление BodyVelocity
char.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log(string.format("BodyVelocity СОЗДАН, скорость = %s, Parent = %s", tostring(desc.Velocity), desc.Parent and desc.Parent.Name or "nil"), "BodyVelocity added")
        -- Отслеживаем изменение скорости
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log(string.format("BodyVelocity скорость ИЗМЕНЕНА на %s", tostring(desc.Velocity)), "Velocity changed")
        end)
        -- Отслеживаем удаление (через AncestryChanged)
        desc.AncestryChanged:Connect(function()
            if not desc.Parent then
                log("BodyVelocity УДАЛЁН (Parent = nil)", "BodyVelocity removed")
            end
        end)
    elseif desc:IsA("BodyPosition") then
        log(string.format("BodyPosition СОЗДАН, позиция = %s", tostring(desc.Position)), "BodyPosition added")
    elseif desc:IsA("Tween") then
        log("Tween СОЗДАН", "Tween added")
    end
end)

-- Периодическая проверка существования BodyVelocity (раз в секунду)
task.spawn(function()
    local lastBv = nil
    while true do
        task.wait(1)
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv and not lastBv then
            log("BodyVelocity присутствует на персонаже", "Periodic check")
            lastBv = bv
        elseif not bv and lastBv then
            log("BodyVelocity ОТСУТСТВУЕТ на персонаже", "Periodic check")
            lastBv = nil
        end
    end
end)

log("Диагностический трекер запущен. Активируйте эталонный скрипт. Все изменения будут зафиксированы с временем и причиной.", "Tracker start")
