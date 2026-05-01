-- Трекер CFrame персонажа и позиции сиденья (только изменения)
local player = game.Players.LocalPlayer
local function log(msg) print(string.format("%s.%03d %s", os.date("%H:%M:%S"), (tick() % 1) * 1000, msg)) end

-- Функция для поиска своей лодки
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

-- Переменные для отслеживания
local lastCharCF = nil
local lastSeatPos = nil
local lastSit = nil

while true do
    -- Обновляем ссылки на лодку и персонажа
    local boat = getMyBoat()
    local seat = boat and boat:FindFirstChildWhichIsA("VehicleSeat")
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    -- CFrame персонажа (если есть)
    if hrp then
        local charCF = hrp.CFrame
        if lastCharCF == nil or (charCF.Position - lastCharCF.Position).Magnitude > 0.01 or (charCF.Rotation - lastCharCF.Rotation).Magnitude > 0.1 then
            log(string.format("Персонаж CFrame: %s", tostring(charCF)))
            lastCharCF = charCF
        end
    end

    -- Позиция сиденья (если есть)
    if seat then
        local seatPos = seat.Position
        if lastSeatPos == nil or (seatPos - lastSeatPos).Magnitude > 0.01 then
            log(string.format("Сиденье позиция: (%.2f, %.2f, %.2f)", seatPos.X, seatPos.Y, seatPos.Z))
            lastSeatPos = seatPos
        end
    end

    -- Статус сидения
    local sitting = hum and hum.Sit and hum.SeatPart == seat
    if sitting ~= lastSit then
        log("Sit = " .. tostring(sitting))
        lastSit = sitting
    end

    task.wait(0.1)
end
