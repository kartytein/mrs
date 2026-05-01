-- Диагностика: изменения позиции персонажа и сиденья (без спама, с защитой)
local player = game.Players.LocalPlayer
local function log(msg) print(os.date("%H:%M:%S"), msg) end

-- Находим лодку по Owner
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

local boat = findMyBoat()
if not boat then
    log("Лодка не найдена")
    return
end

local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then
    log("Сиденье не найдено")
    return
end

log("Лодка найдена, сиденье: " .. seat:GetFullName())

local lastCharPos = nil
local lastSeatPos = nil
local lastSit = nil

while true do
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    local sitting = hum and hum.Sit and hum.SeatPart == seat
    local charPos = hrp and hrp.Position
    -- Безопасное получение позиции сиденья (даже если оно удалилось)
    local seatPos = nil
    if seat and seat.Parent then
        seatPos = seat.Position
    end

    if sitting ~= lastSit then
        log("Sit = " .. tostring(sitting))
        lastSit = sitting
    end

    if charPos and (lastCharPos == nil or (charPos - lastCharPos).Magnitude > 0.5) then
        log(string.format("Персонаж: (%.1f,%.1f,%.1f)", charPos.X, charPos.Y, charPos.Z))
        lastCharPos = charPos
    end

    if seatPos and (lastSeatPos == nil or (seatPos - lastSeatPos).Magnitude > 0.5) then
        log(string.format("Сиденье: (%.1f,%.1f,%.1f)", seatPos.X, seatPos.Y, seatPos.Z))
        lastSeatPos = seatPos
    end

    task.wait(0.5)
end
