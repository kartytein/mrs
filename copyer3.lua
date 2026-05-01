-- Диагностика: позиция сиденья и персонажа (каждые 0.2 секунды)
local player = game.Players.LocalPlayer
local function log(...) print(os.date("%H:%M:%S"), ...) end

-- Функция для получения текущей лодки (по Owner)
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
    log("Лодка не найдена. Убедитесь, что вы уже призвали лодку.")
    return
end
local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then
    log("Сиденье не найдено")
    return
end

log("Лодка найдена:", boat.Name)
log("Сиденье:", seat:GetFullName())

task.spawn(function()
    while true do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        local sitting = hum and hum.Sit and hum.SeatPart == seat
        local seatPos = seat.Position
        local charPos = hrp and hrp.Position or Vector3.new(0,0,0)
        local delta = (charPos - seatPos).Magnitude
        log(string.format("[СИДЕНЬЕ] pos=(%.2f,%.2f,%.2f) | [ПЕРСОНАЖ] pos=(%.2f,%.2f,%.2f) | дельта=%.2f | сидит=%s",
            seatPos.X, seatPos.Y, seatPos.Z,
            charPos.X, charPos.Y, charPos.Z,
            delta, tostring(sitting)))
        task.wait(0.2)
    end
end)

log("Диагностика запущена. Сядьте в лодку и попробуйте вылезти. Наблюдайте изменения.")
