-- Магнит: точное копирование эталонного поведения (постоянное обновление цели)
local player = game.Players.LocalPlayer

-- Функция поиска своей лодки
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

-- Главный цикл (очень частый, чтобы успевать за движением лодки)
task.spawn(function()
    while true do
        task.wait(0.05) -- интервал как в эталонном скрипте
        local boat = findMyBoat()
        if not boat then continue end
        local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
        if not seat then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end
        
        -- Если не сидит на нужном сиденье
        if not (hum.Sit and hum.SeatPart == seat) then
            -- Актуальная цель (сиденье + 2.5 по Y, как в логах)
            local target = seat.Position + Vector3.new(0, 2.5, 0)
            local dist = (hrp.Position - target).Magnitude
            if dist > 0.5 then
                -- Маленький шаг к цели (скорость 150, шаг 0.05 сек)
                local dir = (target - hrp.Position).Unit
                local step = math.min(150 * 0.05, dist)
                local newPos = hrp.Position + dir * step
                hrp.CFrame = CFrame.new(newPos)
            else
                -- Достигли цели – садимся
                hrp.CFrame = CFrame.new(target)
                hum.Sit = true
            end
        end
    end
end)

print("Магнит запущен (плавное следование за сиденьем)")
