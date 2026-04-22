-- ===== АБСОЛЮТНО НАДЁЖНЫЙ СКРИПТ: ГАРАНТИРОВАННАЯ ПОСАДКА И ДВИЖЕНИЕ =====
-- Скрипт не прекращает попытки, пока персонаж не сядет в лодку.
-- BodyVelocity пересоздаётся постоянно, чтобы лодка не останавливалась.

local player = game.Players.LocalPlayer

-- НАСТРОЙКИ (измените под свою игру)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local WALK_SPEED = 150

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower then lower.CanCollide = false end
            if upper then upper.CanCollide = false end
        end
        if myBoat then
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
        task.wait(0.2)
    end
end)

-- ========== 2. ПОИСК ЛОДКИ ПО СИДЕНЬЮ ==========
local function updateBoatFromSeat()
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end
    local currentSeat = humanoid.SeatPart
    if not currentSeat then return false end
    local boat = currentSeat:FindFirstAncestorWhichIsA("Model")
    if not boat then return false end
    if myBoat ~= boat then
        myBoat = boat
        seat = currentSeat
        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        print("[DIAG] Лодка найдена: " .. myBoat.Name)
        local native = myBoat:FindFirstChild("Script")
        if native then native.Disabled = true end
    end
    return true
end

-- ========== 3. ЦИКЛ ГАРАНТИРОВАННОЙ ПОСАДКИ (ПОКА НЕ СЯДЕТ) ==========
local function forceSitOnSeat()
    if not seat then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    -- Уже сидит?
    if humanoid.Sit and humanoid.SeatPart == seat then
        return
    end
    print("[DIAG] Начинаем принудительную посадку (цикл)...")
    -- Удаляем старый BodyVelocity, чтобы не мешал
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    local targetCF = seat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    -- Бесконечный цикл, пока не сядет
    while true do
        -- Обновляем направление к сиденью (на случай, если сиденье движется)
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
        -- Проверяем, сел ли уже
        if humanoid.Sit and humanoid.SeatPart == seat then
            break
        end
        -- Если расстояние большое, продолжаем
        if (hrp.Position - targetCF.Position).Magnitude < 1.5 then
            -- Доводим до конечной позиции
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            break
        end
    end
    bv:Destroy()
    print("[DIAG] Посадка успешно завершена")
end

-- ========== 4. ПОСТОЯННОЕ ПОДДЕРЖАНИЕ ДВИЖЕНИЯ ЛОДКИ ==========
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then continue end
        if seat and humanoid.Sit and humanoid.SeatPart == seat then
            local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then
                if bv.Velocity.X ~= speedX then
                    bv.Velocity = Vector3.new(speedX, 0, 0)
                end
            else
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp
                bv.Velocity = Vector3.new(speedX, 0, 0)
            end
        else
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then bv:Destroy() end
        end
    end
end)

-- ========== 5. ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ ==========
task.spawn(function()
    while true do
        task.wait(0.2)
        if rootPart then
            local x = rootPart.Position.X
            if x <= BOAT_X_MIN and currentDirection == -1 then
                currentDirection = 1
            elseif x >= BOAT_X_MAX and currentDirection == 1 then
                currentDirection = -1
            end
        end
    end
end)

-- ========== 6. ГЛАВНЫЙ МОНИТОРИНГ: ПОСТОЯННАЯ ПРОВЕРКА ПОСАДКИ ==========
task.spawn(function()
    while true do
        task.wait(0.5)
        -- Если персонаж умер, сбрасываем ссылки и ждём
        if not player.Character then
            myBoat = nil; seat = nil; rootPart = nil
            print("[DIAG] Персонаж отсутствует, сброс")
            player.CharacterAdded:Wait()
            print("[DIAG] Персонаж появился")
            task.wait(1)
        end
        -- Обновляем информацию о лодке (если сели)
        updateBoatFromSeat()
        -- Если лодка есть, но персонаж не сидит, вызываем принудительную посадку
        if seat then
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid and not (humanoid.Sit and humanoid.SeatPart == seat) then
                print("[DIAG] Обнаружено, что персонаж не сидит. Запуск цикла посадки.")
                forceSitOnSeat()
            end
        end
    end
end)

print("[DIAG] Скрипт запущен. ГАРАНТИРОВАННАЯ посадка и движение активны.")
