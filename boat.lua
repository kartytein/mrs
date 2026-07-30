loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

-- Параметры движения (можно менять)
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100
local dir = -1

-- Переменные лодки
local boat = nil      -- модель лодки
local seat = nil      -- сиденье
local root = nil      -- PrimaryPart
local bv = nil        -- BodyVelocity
local moving = false
local moveThread = nil

-- Состояние автомата
-- "MOVING" – обычное движение, "IDLE" – ожидание, "ISLAND_PROCESSING" – обработка острова,
-- "WAITING_DISAPPEAR" – ждём исчезновения острова
local state = "MOVING"

-- Блокировка сброса boat в основном цикле (используется при обработке острова)
local allowBoatReset = true

-- ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

-- Обновление/создание BodyVelocity
local function ensureBV()
    local upper = char:FindFirstChild("UpperTorso")
    if not upper then return end
    local sx = dir * SPEED_X
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    end
end

-- Остановка движения
local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

-- Запуск движения (не запускает, если уже движется)
local function startMove()
    if moving then return end
    moving = true
    moveThread = task.spawn(function()
        if not root then return end
        -- Установка высоты
        local p = root.Position
        if math.abs(p.Y - TARGET_Y) > 0.5 then
            root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
        end
        ensureBV()
        while moving do
            -- Если перестали сидеть на этом сиденье – останавливаем
            if not (hum.Sit and hum.SeatPart == seat) then
                stopMove()
                break
            end
            if root then
                local p = root.Position
                if math.abs(p.Y - TARGET_Y) > 0.5 then
                    root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
                end
                -- Смена направления у границ
                if p.X <= X_MIN and dir == -1 then
                    dir = 1
                    ensureBV()
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    ensureBV()
                end
            end
            -- Поддержание скорости
            if bv and bv.Parent then
                local v = bv.Velocity
                bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001)
            end
            task.wait(0.05)
        end
    end)
end

-- Выход из лодки (останавливает движение, но сохраняет boat для возврата)
local function leaveBoat()
    local ch = player.Character
    if ch then
        local h = ch:FindFirstChild("Humanoid")
        if h then
            h.Sit = false
            h.SeatPart = nil
        end
    end
    stopMove()
    -- boat, seat, root не обнуляем, чтобы потом сесть обратно
end

-- Посадка в лодку (телепорт на сиденье и установка сидения)
local function sitInBoat(boatModel)
    if not boatModel then return false end
    local seatPart = boatModel:FindFirstChildWhichIsA("VehicleSeat")
    if not seatPart then return false end
    local ch = player.Character
    if not ch then return false end
    local h = ch:FindFirstChild("Humanoid")
    local rootPart = ch:FindFirstChild("HumanoidRootPart")
    if not h or not rootPart then return false end

    -- Выходим из текущего сиденья, если сидим
    if h.Sit then
        h.Sit = false
        h.SeatPart = nil
        task.wait(0.1)
    end

    -- Телепортируем HRP на сиденье (с небольшим смещением вверх)
    rootPart.CFrame = seatPart.CFrame * CFrame.new(0, 1.5, 0)
    task.wait(0.1)

    -- Садимся
    h.SeatPart = seatPart
    h.Sit = true

    -- Обновляем глобальные переменные
    boat = boatModel
    seat = seatPart
    root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")

    -- Отключаем коллизии у частей лодки
    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    -- Отключаем скрипты лодки (если есть)
    local nat = boat:FindFirstChild("Script")
    if nat then nat.Disabled = true end

    return true
end

-- Эмуляция клика мыши
local vim = game:GetService("VirtualInputManager")
local function click(x, y)
    print("Клик по (" .. x .. ", " .. y .. ")")
    vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

-- ===== НОВАЯ ФУНКЦИЯ: ОЖИДАНИЕ, ПОКА ЛОКАЛЬНЫЙ ИГРОК НЕ ОКАЖЕТСЯ В ПРЕДЕЛАХ 100 ОТ ОСТРОВА =====
local function waitForLocalPlayerNearIsland(islandPos)
    print("Ожидание локального игрока около острова...")
    while true do
        local ch = player.Character
        if ch then
            local hrpPart = ch:FindFirstChild("HumanoidRootPart")
            if hrpPart then
                if (hrpPart.Position - islandPos).Magnitude <= 100 then
                    print("Локальный игрок около острова.")
                    break
                end
            end
        end
        task.wait(1)
    end
end

-- Три последовательных клика с задержкой 1 секунда
local function performThreeClicks()
    local coords = {
        {223, 244},
        {586, 347},
        {533, 484}
    }
    for i, coord in ipairs(coords) do
        click(coord[1], coord[2])
        if i < 3 then
            task.wait(1)  -- задержка между кликами
        end
    end
end

-- Ожидание появления яйца (проверка существующих + событие)
local function waitForEgg()
    print("Ожидание появления DragonEgg...")
    -- Проверяем уже существующие
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "DragonEgg" then
            print("Яйцо уже существует, продолжаем.")
            return
        end
    end
    -- Ждём событие
    local event = workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") and desc.Name == "DragonEgg" then
            print("Яйцо появилось!")
            event:Disconnect()
        end
    end)
    -- Также проверяем в цикле на случай пропуска события
    while true do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "DragonEgg" then
                print("Яйцо обнаружено в цикле.")
                event:Disconnect()
                return
            end
        end
        task.wait(0.5)
    end
end

-- ===== ОБРАБОТКА ПОЯВЛЕНИЯ ОСТРОВА =====
local function processIsland()
    -- Если уже обрабатываем, выходим
    if state == "ISLAND_PROCESSING" then return end
    state = "ISLAND_PROCESSING"
    allowBoatReset = false

    print("Остров появился, начинаем обработку.")

    -- 1. Останавливаем лодку и выходим
    stopMove()
    leaveBoat()

    -- 2. Находим остров
    local island = workspace:FindFirstChild("PrehistoricIsland")
    if not island then
        print("Остров исчез до начала обработки.")
        state = "MOVING"
        allowBoatReset = true
        return
    end

    -- Определяем позицию острова
    local islandPos
    if island:IsA("Model") and island.PrimaryPart then
        islandPos = island.PrimaryPart.Position
    else
        local part = island:FindFirstChildWhichIsA("BasePart")
        if part then
            islandPos = part.Position
        else
            print("Не удалось определить позицию острова, пропускаем.")
            state = "MOVING"
            allowBoatReset = true
            return
        end
    end

    -- 3. Ждём локального игрока у острова (вместо всех игроков)
    waitForLocalPlayerNearIsland(islandPos)

    -- 4. Три клика
    performThreeClicks()

    -- 5. Ждём появления яйца
    waitForEgg()

    -- 6. Клик по координатам 586, 347 (яйцо)
    click(586, 347)

    -- 7. Возвращаемся в лодку
    if boat then
        local success = sitInBoat(boat)
        if success then
            print("Сел обратно в лодку.")
            startMove()
            -- Переходим в состояние ожидания исчезновения острова
            state = "WAITING_DISAPPEAR"
            allowBoatReset = true  -- разрешаем сброс, но пока остров не исчез, цикл не сбросит boat, т.к. мы сидим
        else
            print("Не удалось сесть в лодку, продолжаем движение без посадки?")
            state = "MOVING"
            allowBoatReset = true
        end
    else
        print("Лодка потеряна, ищем другую...")
        -- Можно попытаться найти лодку по имени или по VehicleSeat
        -- Для простоты переходим в MOVING, но без лодки
        state = "MOVING"
        allowBoatReset = true
    end
end

-- ===== СОБЫТИЯ ПОЯВЛЕНИЯ / ИСЧЕЗНОВЕНИЯ ОСТРОВА =====

workspace.ChildAdded:Connect(function(child)
    if child.Name == "PrehistoricIsland" then
        -- Если мы в движении или ожидании, запускаем обработку
        if state == "MOVING" or state == "IDLE" then
            task.spawn(processIsland)
        end
    end
end)

workspace.ChildRemoved:Connect(function(child)
    if child.Name == "PrehistoricIsland" then
        print("Остров исчез.")
        if state == "WAITING_DISAPPEAR" then
            -- Мы уже в лодке и движемся, делаем клик по 533,484
            click(533, 484)
            state = "MOVING"
            allowBoatReset = true
        elseif state == "ISLAND_PROCESSING" then
            -- Остров исчез во время обработки – прерываем, делаем клик и возвращаемся в MOVING
            print("Остров исчез во время обработки, прерываем.")
            state = "MOVING"
            allowBoatReset = true
            -- Если нужно кликнуть, можно здесь, но по условию клик делается только после возврата в лодку
            -- Поэтому пропускаем, чтобы не нарушить порядок
        end
    end
end)

-- ===== ОСНОВНОЙ ЦИКЛ УПРАВЛЕНИЯ ЛОДКОЙ (с изменением) =====
task.spawn(function()
    while true do
        task.wait(0.1)
        char = player.Character
        if not char then
            player.CharacterAdded:Wait()
            char = player.Character
            hum = char:WaitForChild("Humanoid")
            hrp = char:WaitForChild("HumanoidRootPart")
            -- Сброс лодки при перезагрузке
            stopMove()
            boat = nil; seat = nil; root = nil
            state = "MOVING"
            allowBoatReset = true
            continue
        end

        -- Если мы в режиме обработки острова, не трогаем управление лодкой
        if state == "ISLAND_PROCESSING" then
            -- Пропускаем обновление, чтобы не сбросить boat
            continue
        end

        -- Если мы сидим на сиденье
        if hum.Sit and hum.SeatPart then
            local currentSeat = hum.SeatPart
            local currentBoat = currentSeat:FindFirstAncestorOfClass("Model")
            if currentBoat and currentBoat:IsA("Model") and currentBoat:FindFirstChildWhichIsA("VehicleSeat") then
                if boat ~= currentBoat then
                    -- Пересели в другую лодку
                    stopMove()
                    -- Отключаем коллизии у новой лодки
                    for _, part in ipairs(currentBoat:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                    local nat = currentBoat:FindFirstChild("Script")
                    if nat then nat.Disabled = true end

                    boat = currentBoat
                    seat = currentSeat
                    root = currentBoat.PrimaryPart or currentBoat:FindFirstChildWhichIsA("BasePart")
                    print("Сел в лодку:", boat.Name)
                end
                -- Запускаем движение, если сидим именно на этом сиденье
                if hum.SeatPart == seat then
                    startMove()
                else
                    stopMove()
                end
            else
                -- Сидим не на лодке – останавливаем и сбрасываем
                if boat then
                    stopMove()
                    boat = nil; seat = nil; root = nil
                end
            end
        else
            -- Не сидим – сбрасываем, но только если разрешено
            if boat and allowBoatReset then
                stopMove()
                boat = nil; seat = nil; root = nil
            end
        end
    end
end)

print("Скрипт движения и обработки острова запущен (тестовый режим: только локальный игрок).")
