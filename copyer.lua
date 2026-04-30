-- ===== ПОЛНАЯ ДИАГНОСТИКА ПЕРСОНАЖА =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local function log(msg) print(os.date("%H:%M:%S"), msg) end

-- Сохраняем последнюю позицию для сравнения
local lastPos = hrp.Position

-- Отслеживаем CFrame (полностью)
hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newPos = hrp.Position
    if (newPos - lastPos).Magnitude > 0.01 then
        log(string.format("[CFrame] Позиция: (%.3f, %.3f, %.3f) | Изменение: (%.3f, %.3f, %.3f)", 
            newPos.X, newPos.Y, newPos.Z,
            newPos.X - lastPos.X, newPos.Y - lastPos.Y, newPos.Z - lastPos.Z))
        lastPos = newPos
    end
end)

-- Отслеживаем Position (дублируем для надёжности)
hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local pos = hrp.Position
    log(string.format("[Position] (%.3f, %.3f, %.3f)", pos.X, pos.Y, pos.Z))
end)

-- Отслеживаем создание и изменение BodyVelocity
char.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log(string.format("[BodyVelocity] СОЗДАН на %s, скорость = %s", desc.Parent and desc.Parent.Name or "nil", tostring(desc.Velocity)))
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log(string.format("[BodyVelocity] ИЗМЕНЁН: %s", tostring(desc.Velocity)))
        end)
        desc.AncestryChanged:Connect(function()
            if not desc.Parent then log("[BodyVelocity] УДАЛЁН") end
        end)
    end
end)

-- Отслеживаем PlatformStand
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log(string.format("[PlatformStand] = %s", tostring(humanoid.PlatformStand)))
end)

-- Отслеживаем Sit и SeatPart
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    log(string.format("[Sit] = %s, SeatPart = %s", tostring(humanoid.Sit), tostring(humanoid.SeatPart)))
end)

-- Периодический вывод состояния (раз в 2 секунды)
task.spawn(function()
    while true do
        task.wait(2)
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        local pos = hrp.Position
        log(string.format("[ПЕРИОД] Позиция: (%.1f, %.3f, %.1f), BodyVelocity: %s, PlatformStand: %s, Sit: %s",
            pos.X, pos.Y, pos.Z,
            bv and tostring(bv.Velocity) or "nil",
            tostring(humanoid.PlatformStand),
            tostring(humanoid.Sit)))
    end
end)

log("Полная диагностика персонажа запущена. Активируйте эталонный скрипт.")
