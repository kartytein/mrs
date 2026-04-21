-- ===== МИНИМАЛЬНЫЙ СКРИПТ С ДИАГНОСТИКОЙ (ТОЛЬКО ЛОДКА) - БЕЗ ОШИБОК =====
-- Вы садитесь в лодку вручную, скрипт её находит, отключает коллизии,
-- поддерживает движение и возвращает вас на сиденье, если вы вылезли.

local player = game.Players.LocalPlayer

-- НАСТРОЙКИ (измените под свои координаты)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250           -- скорость лодки (по X)
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)  -- высота над сиденьем
local WALK_SPEED = 150           -- скорость полёта к сиденью

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1      -- -1 = влево, 1 = вправо

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower then lower.CanCollide = false end
            if upper then upper.CanCollide = false end
        end
        if myBoat then
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        task.wait(0.2)
    end
end)

-- ========== 2. ПОИСК ЛОДКИ ПО СИДЕНЬЮ ==========
local function updateBoatFromSeat()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    local currentSeat = humanoid.SeatPart
    if not currentSeat then return end
    local boat = currentSeat:FindFirstAncestorWhichIsA("Model")
    if not boat then return end
    if myBoat ~= boat then
        myBoat = boat
        seat = currentSeat
        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        print("[DIAG] Лодка найдена: " .. myBoat.Name)
        -- Отключаем родной скрипт лодки, если есть
        local native = myBoat:FindFirstChild("Script")
        if native then
            native.Disabled = true
        end
    end
end

-- ========== 3. ПОСАДКА НА СИДЕНЬЕ ==========
local function sitOnSeat()
    if not seat then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Sit and humanoid.SeatPart == seat then
        return
    end
    print("[DIAG] Попытка сесть на сиденье...")
    -- Удаляем старый BodyVelocity
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    local targetCF = seat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    print("[DIAG] Посадка завершена")
end

-- ========== 4. ПОДДЕРЖАНИЕ ДВИЖЕНИЯ ЛОДКИ ==========
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
                print("[DIAG] Создан BodyVelocity, скорость " .. speedX)
            end
        else
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then
                bv:Destroy()
                print("[DIAG] BodyVelocity удалён (не сидим)")
            end
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
                print("[DIAG] Смена направления → вправо")
            elseif x >= BOAT_X_MAX and currentDirection == 1 then
                currentDirection = -1
                print("[DIAG] Смена направления → влево")
            end
        end
    end
end)

-- ========== 6. МОНИТОРИНГ ПОСАДКИ И ПОИСК ЛОДКИ ==========
task.spawn(function()
    while true do
        task.wait(0.5)
        if not player.Character then
            myBoat = nil
            seat = nil
            rootPart = nil
            print("[DIAG] Персонаж отсутствует, сброс лодки")
            player.CharacterAdded:Wait()
            print("[DIAG] Персонаж появился")
            task.wait(1)
        end
        updateBoatFromSeat()
        if seat then
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid and not (humanoid.Sit and humanoid.SeatPart == seat) then
                print("[DIAG] Персонаж не сидит, выполняем посадку")
                sitOnSeat()
            end
        end
    end
end)

print("[DIAG] Скрипт запущен. Сядьте в лодку вручную. Скрипт подхватит её и начнёт управление.")
