-- Диагностика изменений (без спама)
local player = game.Players.LocalPlayer
local function log(msg) print(os.date("%H:%M:%S"), msg) end

-- Получаем лодку
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
    log("Лодка не найдена")
    return
end
local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then
    log("Сиденье не найдено")
    return
end

-- Сохраняем предыдущие состояния
local lastSeatPos = seat.Position
local lastCharPos = nil
local lastCharCF = nil
local lastSit = nil

-- Функция для получения текущего персонажа
local function getChar()
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if hrp and hum then
            return hrp, hum
        end
    end
    return nil, nil
end

-- Отслеживаем изменения сиденья
seat:GetPropertyChangedSignal("Position"):Connect(function()
    local newPos = seat.Position
    if (newPos - lastSeatPos).Magnitude > 0.01 then
        log(string.format("[СИДЕНЬЕ] переместилось: (%.2f,%.2f,%.2f) -> (%.2f,%.2f,%.2f)",
            lastSeatPos.X, lastSeatPos.Y, lastSeatPos.Z,
            newPos.X, newPos.Y, newPos.Z))
        lastSeatPos = newPos
    end
end)

-- Отслеживаем изменения персонажа (через событие CFrame)
task.spawn(function()
    while true do
        task.wait(0.05)  -- частая проверка
        local hrp, hum = getChar()
        if not hrp then
            if lastCharPos ~= nil then
                log("[ПЕРСОНАЖ] исчез (смерть)")
                lastCharPos = nil
                lastCharCF = nil
            end
            continue
        end
        local newPos = hrp.Position
        local newCF = hrp.CFrame
        local newSit = hum and hum.Sit and hum.SeatPart == seat
        if lastCharPos and (newPos - lastCharPos).Magnitude > 0.1 then
            log(string.format("[ПЕРСОНАЖ] позиция изменилась: (%.2f,%.2f,%.2f) -> (%.2f,%.2f,%.2f)",
                lastCharPos.X, lastCharPos.Y, lastCharPos.Z,
                newPos.X, newPos.Y, newPos.Z))
        end
        if lastCharCF and (newCF.Position - lastCharCF.Position).Magnitude > 0.01 then
            -- можно вывести CFrame только при большом изменении
            -- но для краткости выводим позицию уже выше
        end
        if lastSit ~= newSit then
            log(string.format("[СИДИТ] = %s", tostring(newSit)))
            lastSit = newSit
        end
        lastCharPos = newPos
        lastCharCF = newCF
    end
end)

log("Диагностика изменений запущена. Сядьте в лодку, затем вылезьте. Будет видно, как движется сиденье и персонаж.")
