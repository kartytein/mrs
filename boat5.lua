-- Магнит: возврат на сиденье при любом сдвиге или вылезании
local player = game.Players.LocalPlayer

-- Найти свою лодку и сиденье
local function getSeat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, b in ipairs(boats:GetChildren()) do
        if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
            if b:GetAttribute("Owner") == player.Name then
                return b:FindFirstChildWhichIsA("VehicleSeat")
            end
            local own = b:FindFirstChild("Owner")
            if own and tostring(own.Value) == player.Name then
                return b:FindFirstChildWhichIsA("VehicleSeat")
            end
        end
    end
    return nil
end

local seat = getSeat()
if not seat then
    print("Сиденье не найдено. Убедитесь, что лодка призвана.")
    return
end

-- Постоянный цикл (каждые 0.02 сек)
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            if hrp and hum then
                local dist = (hrp.Position - seat.Position).Magnitude
                -- Если персонаж далеко или не сидит на этом сиденье
                if dist > 2 or not (hum.Sit and hum.SeatPart == seat) then
                    -- Возвращаем на позицию чуть выше сиденья
                    hrp.CFrame = seat.CFrame + Vector3.new(0, 2.5, 0)
                    hum.Sit = true
                end
            end
        end
        task.wait(0.02)
    end
end)

print("Магнит активирован. Персонаж будет возвращаться на сиденье при любом вылезании.")
