-- ===== РАСШИРЕННЫЙ ДИАГНОСТИЧЕСКИЙ СКРИПТ (ЗАПУСКАЕТСЯ ОТДЕЛЬНО) =====
-- Выводит все ключевые переменные и их изменения каждые 0.5 секунды.
-- Помогает понять, почему посадка не удаётся.

local player = game.Players.LocalPlayer
local lastState = {}

local function dumpTable(t, name)
    if type(t) ~= "table" then return tostring(t) end
    local s = name .. " = {"
    for k, v in pairs(t) do
        s = s .. tostring(k) .. "=" .. tostring(v) .. ","
    end
    s = s .. "}"
    return s
end

local function logState()
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    -- Поиск лодки по Owner (своя)
    local myBoatByOwner = nil
    local boats = workspace:FindFirstChild("Boats")
    if boats then
        for _, boat in ipairs(boats:GetChildren()) do
            if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
                local owner = boat:GetAttribute("Owner")
                if owner == player.Name then myBoatByOwner = boat end
                local ownerObj = boat:FindFirstChild("Owner")
                if ownerObj and tostring(ownerObj.Value) == player.Name then myBoatByOwner = boat end
            end
        end
    end
    
    -- Текущее сиденье и лодка
    local currentSeat = humanoid and humanoid.SeatPart
    local currentBoat = currentSeat and currentSeat:FindFirstAncestorWhichIsA("Model")
    
    -- Глобальные переменные из основного скрипта (если они доступны)
    local globalSeat = _G.__seat or nil
    local globalMyBoat = _G.__myBoat or nil
    local globalRootPart = _G.__rootPart or nil
    local globalDirection = _G.__currentDirection or nil
    
    local state = {
        timestamp = os.date("%H:%M:%S"),
        charExists = char ~= nil,
        hrpExists = hrp ~= nil,
        humanoidExists = humanoid ~= nil,
        sit = humanoid and humanoid.Sit or false,
        seatPart = currentSeat and currentSeat:GetFullName() or "nil",
        currentBoat = currentBoat and currentBoat:GetFullName() or "nil",
        myBoatByOwner = myBoatByOwner and myBoatByOwner:GetFullName() or "nil",
        isOwnerBoat = (myBoatByOwner and currentBoat and myBoatByOwner == currentBoat) or false,
        hasBodyVelocity = hrp and hrp:FindFirstChildWhichIsA("BodyVelocity") ~= nil,
        bodyVelocitySpeed = (hrp and hrp:FindFirstChildWhichIsA("BodyVelocity")) and hrp:FindFirstChildWhichIsA("BodyVelocity").Velocity or nil,
        hrpPosition = hrp and hrp.Position or nil,
        seatPosition = currentSeat and currentSeat.Position or nil,
        distanceToSeat = (hrp and currentSeat) and (hrp.Position - currentSeat.Position).Magnitude or nil,
        -- Глобальные переменные (если доступны)
        globalSeat = globalSeat and globalSeat:GetFullName() or "nil",
        globalMyBoat = globalMyBoat and globalMyBoat:GetFullName() or "nil",
        globalRootPart = globalRootPart and "exists" or "nil",
        globalDirection = globalDirection or "nil",
    }
    
    -- Вывод изменений
    local changes = {}
    for k, v in pairs(state) do
        if lastState[k] ~= v then
            changes[k] = {old = lastState[k], new = v}
        end
    end
    
    if next(changes) then
        print("=== ИЗМЕНЕНИЯ ===")
        for k, change in pairs(changes) do
            print(string.format("%s: %s -> %s", k, tostring(change.old), tostring(change.new)))
        end
    end
    
    print("=== ПОЛНОЕ СОСТОЯНИЕ ===")
    for k, v in pairs(state) do
        if type(v) == "table" then
            print(k .. " : (таблица)")
        elseif type(v) == "Vector3" then
            print(string.format("%s : (%.1f, %.1f, %.1f)", k, v.X, v.Y, v.Z))
        else
            print(k .. " : " .. tostring(v))
        end
    end
    print("==================")
    
    -- Анализ проблем
    if state.sit and not state.seatPart then
        print("[ПРОБЛЕМА] Персонаж сидит, но SeatPart = nil")
    end
    if not state.sit and state.seatPart then
        print("[ПРОБЛЕМА] Персонаж не сидит, но SeatPart не nil. Возможно, только что сел?")
    end
    if state.sit and state.seatPart and not state.isOwnerBoat and state.myBoatByOwner ~= "nil" then
        print("[ПРОБЛЕМА] Вы сидите в чужой лодке! Своя лодка: " .. state.myBoatByOwner)
    end
    if state.sit and state.hasBodyVelocity == false then
        print("[ПРОБЛЕМА] Вы сидите, но BodyVelocity отсутствует. Лодка не движется.")
    end
    if state.sit and state.bodyVelocitySpeed and math.abs(state.bodyVelocitySpeed.X) < 1 then
        print("[ПРОБЛЕМА] BodyVelocity скорость близка к нулю, лодка стоит.")
    end
    if state.distanceToSeat and state.distanceToSeat > 5 and not state.sit then
        print("[ПРОБЛЕМА] Вы далеко от сиденья, возможно, не пытаетесь сесть.")
    end
    if state.globalSeat ~= "nil" and state.globalSeat ~= state.seatPart then
        print("[ПРОБЛЕМА] Глобальная переменная seat не совпадает с текущим SeatPart. Возможно, устарела.")
    end
    
    lastState = state
end

-- Запускаем каждые 0.5 секунды
task.spawn(function()
    while true do
        logState()
        task.wait(0.5)
    end
end)

print("[DIAG] Расширенный диагностический скрипт запущен. Вывод каждые 0.5 сек.")
print("[DIAG] Чтобы остановить, перезапустите игру или отключите скрипт.")
