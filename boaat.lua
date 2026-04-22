-- ===== ДИАГНОСТИЧЕСКИЙ СКРИПТ: ПРОВЕРКА СОСТОЯНИЯ ЛОДКИ И ПОСАДКИ =====
-- Запустите этот скрипт после того, как вы сели в лодку (или после того, как проблема проявилась).
-- Он будет каждые 2 секунды выводить в консоль ключевые переменные и их изменения.
-- Также он попытается определить, почему посадка не выполняется.

local player = game.Players.LocalPlayer
local lastState = {}

local function logState()
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    -- Определяем текущую лодку и сиденье через SeatPart
    local currentSeat = humanoid and humanoid.SeatPart
    local currentBoat = currentSeat and currentSeat:FindFirstAncestorWhichIsA("Model")
    
    -- Поиск лодки по Owner (для сравнения)
    local ownerBoat = nil
    local boats = workspace:FindFirstChild("Boats")
    if boats then
        for _, boat in ipairs(boats:GetChildren()) do
            if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
                local owner = boat:GetAttribute("Owner")
                if owner == player.Name then
                    ownerBoat = boat
                    break
                end
                local ownerObj = boat:FindFirstChild("Owner")
                if ownerObj and tostring(ownerObj.Value) == player.Name then
                    ownerBoat = boat
                    break
                end
            end
        end
    end
    
    -- Собираем текущее состояние
    local state = {
        charExists = char ~= nil,
        humanoidExists = humanoid ~= nil,
        hrpExists = hrp ~= nil,
        sit = humanoid and humanoid.Sit or false,
        seatPart = currentSeat and currentSeat:GetFullName() or "nil",
        currentBoat = currentBoat and currentBoat:GetFullName() or "nil",
        ownerBoat = ownerBoat and ownerBoat:GetFullName() or "nil",
        myBoat = (ownerBoat and ownerBoat == currentBoat) or false,
        hasBodyVelocity = hrp and hrp:FindFirstChildWhichIsA("BodyVelocity") ~= nil,
        bodyVelocitySpeed = (hrp and hrp:FindFirstChildWhichIsA("BodyVelocity")) and hrp:FindFirstChildWhichIsA("BodyVelocity").Velocity or nil,
    }
    
    -- Сравниваем с предыдущим состоянием и выводим изменения
    local changes = {}
    for k, v in pairs(state) do
        if lastState[k] ~= v then
            table.insert(changes, k .. " : " .. tostring(lastState[k]) .. " -> " .. tostring(v))
        end
    end
    
    if #changes > 0 then
        print("=== ИЗМЕНЕНИЯ ===")
        for _, change in ipairs(changes) do
            print(change)
        end
    end
    
    print("=== ТЕКУЩЕЕ СОСТОЯНИЕ ===")
    for k, v in pairs(state) do
        if type(v) == "table" then
            print(k .. " : (таблица)")
        else
            print(k .. " : " .. tostring(v))
        end
    end
    
    -- Анализ проблем
    if humanoid and not humanoid.Sit and currentSeat then
        print("[DIAG] ВНИМАНИЕ: персонаж не сидит, но SeatPart не nil. Возможно, он только что сел, но Sit ещё false.")
    end
    if humanoid and humanoid.Sit and not currentSeat then
        print("[DIAG] ВНИМАНИЕ: персонаж сидит, но SeatPart = nil. Странно, возможно, ошибка игры.")
    end
    if not humanoid then
        print("[DIAG] ВНИМАНИЕ: Humanoid не найден. Персонаж, возможно, мёртв или не загружен.")
    end
    if not currentBoat and ownerBoat then
        print("[DIAG] ВНИМАНИЕ: ваша лодка существует (Owner), но вы не сидите в ней. Возможно, вы выпали.")
        print("     Рекомендуется вызвать посадку: forceSitOnSeat()")
    end
    if currentBoat and not ownerBoat then
        print("[DIAG] ВНИМАНИЕ: вы сидите в лодке, но эта лодка не принадлежит вам (Owner не совпадает). Возможно, скрипт управляет чужой лодкой.")
    end
    if hrp and not state.hasBodyVelocity and humanoid and humanoid.Sit then
        print("[DIAG] ВНИМАНИЕ: вы сидите, но BodyVelocity отсутствует. Лодка не будет двигаться.")
    end
    
    print("=====================================")
    lastState = state
end

-- Запускаем периодический вывод каждые 2 секунды
task.spawn(function()
    while true do
        task.wait(2)
        logState()
    end
end)

print("[DIAG] Диагностический скрипт запущен. Каждые 2 секунды будет выводиться состояние.")
