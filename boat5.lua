-- Диагностика: CFrame персонажа и позиция сиденья (с миллисекундами, вывод при изменениях)
local player = game.Players.LocalPlayer
local function log(msg) print(string.format("%s.%03d %s", os.date("%H:%M:%S"), math.floor((tick() % 1) * 1000), msg)) end

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

local boat = nil
local seat = nil
local lastCharCF = nil
local lastSeatPos = nil
local lastSit = nil

while true do
    boat = findMyBoat()
    if boat then
        seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    else
        seat = nil
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    local sitting = hum and hum.Sit and hum.SeatPart == seat

    if sitting ~= lastSit then
        log("Sit = " .. tostring(sitting))
        lastSit = sitting
    end

    -- CFrame персонажа (полный)
    if hrp then
        local charCF = hrp.CFrame
        if lastCharCF == nil then
            log("Персонаж CFrame: " .. tostring(charCF))
            lastCharCF = charCF
        else
            local posDiff = (charCF.Position - lastCharCF.Position).Magnitude
            local angDiff = (charCF.RightVector - lastCharCF.RightVector).Magnitude + (charCF.UpVector - lastCharCF.UpVector).Magnitude
            if posDiff > 0.01 or angDiff > 0.01 then
                log("Персонаж CFrame: " .. tostring(charCF))
                lastCharCF = charCF
            end
        end
    elseif lastCharCF ~= nil then
        log("Персонаж пропал")
        lastCharCF = nil
    end

    -- Позиция сиденья (только позиция)
    if seat and seat.Parent then
        local seatPos = seat.Position
        if lastSeatPos == nil or (seatPos - lastSeatPos).Magnitude > 0.01 then
            log(string.format("Сиденье позиция: (%.2f, %.2f, %.2f)", seatPos.X, seatPos.Y, seatPos.Z))
            lastSeatPos = seatPos
        end
    elseif lastSeatPos ~= nil then
        log("Сиденье пропало")
        lastSeatPos = nil
    end

    task.wait(0.2)
end
