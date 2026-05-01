-- Диагностика: CFrame персонажа и CFrame сиденья (с миллисекундами, вывод только при изменениях)
local player = game.Players.LocalPlayer
local function log(msg) print(string.format("%s.%03d %s", os.date("%H:%M:%S"), (tick() % 1) * 1000, msg)) end

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

local lastCharCF = nil
local lastSeatCF = nil
local lastSit = nil

while true do
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    local sitting = hum and hum.Sit and hum.SeatPart == seat
    local charCF = hrp and hrp.CFrame
    local seatCF = seat and seat.Parent and seat.CFrame

    if sitting ~= lastSit then
        log("Sit = " .. tostring(sitting))
        lastSit = sitting
    end

    if charCF then
        local charPos = charCF.Position
        local charRot = charCF.Rotation
        if lastCharCF == nil or (charCF.Position - lastCharCF.Position).Magnitude > 0.05 then
            log(string.format("Персонаж CFrame: pos(%.2f,%.2f,%.2f) rot(%.1f,%.1f,%.1f)", 
                charPos.X, charPos.Y, charPos.Z, charRot.X, charRot.Y, charRot.Z))
            lastCharCF = charCF
        end
    end

    if seatCF then
        local seatPos = seatCF.Position
        local seatRot = seatCF.Rotation
        if lastSeatCF == nil or (seatCF.Position - lastSeatCF.Position).Magnitude > 0.05 then
            log(string.format("Сиденье CFrame: pos(%.2f,%.2f,%.2f) rot(%.1f,%.1f,%.1f)", 
                seatPos.X, seatPos.Y, seatPos.Z, seatRot.X, seatRot.Y, seatRot.Z))
            lastSeatCF = seatCF
        end
    end

    task.wait(0.2)
end
