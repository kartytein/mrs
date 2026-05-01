-- ===== ПОЛНАЯ ДИАГНОСТИКА ПЕРСОНАЖА (С ПЕРЕПОДПИСКОЙ ПОСЛЕ СМЕРТИ) =====
local player = game.Players.LocalPlayer

local function log(msg) print(os.date("%H:%M:%S"), msg) end

local function setupTracker(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    log("=== НОВЫЙ ПЕРСОНАЖ ===")

    local lastPos = hrp.Position
    hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
        local newPos = hrp.Position
        if (newPos - lastPos).Magnitude > 0.01 then
            log(string.format("[CFrame] (%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f)  delta=%.2f",
                lastPos.X, lastPos.Y, lastPos.Z,
                newPos.X, newPos.Y, newPos.Z,
                (newPos - lastPos).Magnitude))
            lastPos = newPos
        end
    end)

    local lastPos2 = hrp.Position
    hrp:GetPropertyChangedSignal("Position"):Connect(function()
        local newPos = hrp.Position
        if (newPos - lastPos2).Magnitude > 0.01 then
            log(string.format("[Position] (%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f)",
                lastPos2.X, lastPos2.Y, lastPos2.Z,
                newPos.X, newPos.Y, newPos.Z))
            lastPos2 = newPos
        end
    end)

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

    humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        log(string.format("[PlatformStand] = %s", tostring(humanoid.PlatformStand)))
    end)

    humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
        log(string.format("[Sit] = %s, SeatPart = %s", tostring(humanoid.Sit), tostring(humanoid.SeatPart)))
    end)

    -- Периодический вывод
    task.spawn(function()
        while char and char.Parent do
            task.wait(2)
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            local pos = hrp.Position
            log(string.format("[ПЕРИОД] Позиция: (%.2f, %.2f, %.2f), BodyVelocity: %s, PlatformStand: %s, Sit: %s",
                pos.X, pos.Y, pos.Z,
                bv and tostring(bv.Velocity) or "nil",
                tostring(humanoid.PlatformStand),
                tostring(humanoid.Sit)))
        end
    end)
end

-- Отслеживаем появление персонажа (первый раз и после смерти)
if player.Character then
    setupTracker(player.Character)
end
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5) -- даём время загрузиться
    setupTracker(newChar)
end)

log("Полная диагностика запущена (с переподпиской после смерти). Активируйте эталонный скрипт.")
