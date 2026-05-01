-- Простой магнит: возвращает персонажа на правильную позицию над сиденьем
local player = game.Players.LocalPlayer
local OFFSET = Vector3.new(0, 3.6, 0)  -- из лога (103.6 - 100.0)

-- Находим свою лодку
local function getMyBoat()
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

local boat = getMyBoat()
if not boat then
    warn("Лодка не найдена")
    return
end
local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then
    warn("Сиденье не найдено")
    return
end

-- Магнит (каждые 0.1 секунды)
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end
        if not (hum.Sit and hum.SeatPart == seat) then
            hrp.CFrame = seat.CFrame + OFFSET
            hum.Sit = true
            print("[МАГНИТ] Возвращён на сиденье")
        end
    end
end)

print("Магнит запущен, персонаж будет удерживаться над сиденьем")
