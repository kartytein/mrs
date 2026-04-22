-- ===== ВАШ РАБОЧИЙ СКРИПТ С ДОБАВЛЕННОЙ ДИАГНОСТИКОЙ (ЛОДКА ДОЛЖНА ДВИГАТЬСЯ) =====
-- Я добавил подробные выводы в консоль, чтобы выяснить, почему лодка не двигается.
-- Основная логика не изменена.

local player = game.Players.LocalPlayer

-- НАСТРОЙКИ (измените под свою игру)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local WALK_SPEED = 150

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

-- ========== 2. ПОИСК СВОЕЙ ЛОДКИ ПО OWNER ==========
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == player.Name then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == player.Name then return boat end
        end
    end
    return nil
end

-- ========== 3. ЦИКЛ ГАРАНТИРОВАННОЙ ПОСАДКИ ==========
local function forceSitOnSeat()
    if not seat then
        print("[DIAG] Посадка: нет сиденья")
        return
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Sit and humanoid.SeatPart == seat then
        return
    end
    print("[DIAG] Начинаем принудительную посадку...")
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while true do
        local targetCF = seat.CFrame + SEAT_OFFSET
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
        if humanoid.Sit and humanoid.SeatPart == seat then
            break
        end
        if (hrp.Position - targetCF.Position).Magnitude < 1.5 then
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            break
        end
    end
    bv:Destroy()
    print("[DIAG] Посадка завершена")
end

-- ========== 4. ПОДДЕРЖАНИЕ ДВИЖЕНИЯ ЛОДКИ (С ДИАГНОСТИКОЙ) ==========
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then continue end
        
        -- Диагностика: выводим состояние каждые 2 секунды (но не слишком часто)
        if tick() % 2 < 0.1 then
            print(string.format("[DIAG] Сидит: %s, SeatPart: %s, seat: %s", 
                tostring(humanoid.Sit), 
                tostring(humanoid.SeatPart), 
                tostring(seat)))
        end
        
        if seat and humanoid.Sit and humanoid.SeatPart == seat then
            local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then
                if bv.Velocity.X ~= speedX then
                    bv.Velocity = Vector3.new(speedX, 0, 0)
                    print("[DIAG] Обновлена скорость BodyVelocity: " .. speedX)
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

-- ========== 5. ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ (С ДИАГНОСТИКОЙ) ==========
task.spawn(function()
    while true do
        task.wait(0.2)
        if rootPart then
            local x = rootPart.Position.X
            if x <= BOAT_X_MIN and currentDirection == -1 then
                currentDirection = 1
                print("[DIAG] Смена направления → вправо (X=" .. x .. ")")
            elseif x >= BOAT_X_MAX and currentDirection == 1 then
                currentDirection = -1
                print("[DIAG] Смена направления → влево (X=" .. x .. ")")
            end
        else
            -- Диагностика: если rootPart нет, выводим предупреждение
            if tick() % 2 < 0.1 then
                print("[DIAG] rootPart = nil, направление не обновляется")
            end
        end
    end
end)

-- ========== 6. ГЛАВНЫЙ МОНИТОРИНГ (С ДИАГНОСТИКОЙ) ==========
task.spawn(function()
    while true do
        task.wait(0.5)
        -- Ожидание появления персонажа после смерти
        if not player.Character then
            myBoat = nil; seat = nil; rootPart = nil
            print("[DIAG] Персонаж отсутствует, сброс лодки")
            player.CharacterAdded:Wait()
            print("[DIAG] Персонаж появился")
            task.wait(1)
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local currentSeat = humanoid and humanoid.SeatPart

        if currentSeat then
            -- Сидит на каком-то сиденье: обновляем лодку
            local boat = currentSeat:FindFirstAncestorWhichIsA("Model")
            if boat then
                if myBoat ~= boat then
                    myBoat = boat
                    seat = currentSeat
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                    print("[DIAG] Лодка обновлена (сидим): " .. myBoat.Name)
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                end
            end
        else
            -- Не сидит: пытаемся сесть в известную лодку или найти новую
            if myBoat and myBoat.Parent then
                -- Проверяем, актуальны ли seat и rootPart
                if not seat or not seat.Parent then
                    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                end
                if seat then
                    print("[DIAG] Персонаж не сидит, запуск посадки")
                    forceSitOnSeat()
                else
                    print("[DIAG] Лодка есть, но сиденье не найдено, сброс")
                    myBoat = nil; seat = nil; rootPart = nil
                end
            else
                -- Лодки нет, ищем
                myBoat = findMyBoat()
                if myBoat then
                    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                    if seat and rootPart then
                        local native = myBoat:FindFirstChild("Script")
                        if native then native.Disabled = true end
                        print("[DIAG] Лодка найдена: " .. myBoat.Name)
                        forceSitOnSeat()
                    else
                        myBoat = nil
                    end
                end
            end
        end
    end
end)

print("[DIAG] Скрипт запущен. Постоянный поиск лодки и гарантированная посадка. Диагностика активна.")
