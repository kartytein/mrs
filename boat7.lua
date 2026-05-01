-- Магнит: возврат на сиденье (как в эталоне, без принудительной посадки)
local player = game.Players.LocalPlayer

local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, b in ipairs(boats:GetChildren()) do
        if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
            if b:GetAttribute("Owner") == player.Name then return b end
            local own = b:FindFirstChild("Owner")
            if own and tostring(own.Value) == player.Name then return b end
        end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.05) -- интервал как в логах эталонного скрипта
        local boat = findMyBoat()
        if not boat then continue end
        local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
        if not seat then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end
        
        -- Если уже сидит на этом сиденье, ничего не делаем
        if hum.Sit and hum.SeatPart == seat then
            continue
        end
        
        -- Цель: чуть выше сиденья (как в эталоне)
        local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
        local dist = (hrp.Position - targetPos).Magnitude
        if dist > 0.3 then
            local dir = (targetPos - hrp.Position).Unit
            local step = math.min(150 * 0.05, dist)  -- скорость 150, шаг 0.05 сек
            local newPos = hrp.Position + dir * step
            hrp.CFrame = CFrame.new(newPos)
        else
            -- Когда достаточно близко, фиксируем позицию и даём игре самой посадить
            hrp.CFrame = CFrame.new(targetPos)
            -- Не вызываем hum.Sit = true, ждём автоматической посадки
        end
    end
end)

print("Магнит запущен (плавное следование за сиденьем, без принудительного Sit)")
