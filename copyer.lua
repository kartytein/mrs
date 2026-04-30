-- ===== ДИАГНОСТИКА ПЕРСОНАЖА (BODYVELOCITY, CFrame, POSITION, ПЛАТФОРМА) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local function log(msg) print(os.date("%H:%M:%S"), msg) end

-- Отслеживаем CFrame персонажа (особенно высоту Y)
local lastY = hrp.Position.Y
hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
    local newY = hrp.Position.Y
    if math.abs(newY - lastY) > 0.01 then
        log(string.format("[CFrame] Y: %.3f -> %.3f (delta=%.3f)", lastY, newY, newY - lastY))
        lastY = newY
    end
end)

-- Отслеживаем Position (дублируем для надёжности)
hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local pos = hrp.Position
    log(string.format("[Position] (%.1f, %.3f, %.1f)", pos.X, pos.Y, pos.Z))
end)

-- Отслеживаем создание и изменение BodyVelocity на персонаже
char.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log(string.format("[BodyVelocity] СОЗДАН на %s, скорость = %s", desc.Parent and desc.Parent.Name or "nil", tostring(desc.Velocity)))
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log(string.format("[BodyVelocity] ИЗМЕНЁН: %s", tostring(desc.Velocity)))
        end)
        desc.AncestryChanged:Connect(function()
            if not desc.Parent then
                log("[BodyVelocity] УДАЛЁН")
            end
        end)
    end
end)

-- Отслеживаем изменения PlatformStand (заморозка)
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log(string.format("[PlatformStand] = %s", tostring(humanoid.PlatformStand)))
end)

-- Отслеживаем изменения Sit и SeatPart
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    log(string.format("[Sit] = %s, SeatPart = %s", tostring(humanoid.Sit), tostring(humanoid.SeatPart)))
end)

-- Периодический вывод состояния (каждые 2 секунды)
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

log("Диагностический трекер персонажа запущен. Активируйте эталонный скрипт.")
