-- ===== ИТОГОВЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ С ДИАГНОСТИКОЙ =====
-- Скрипт сам находит лодку по Owner, отключает коллизии, поддерживает движение,
-- и при вылезании/смерти возвращает на сиденье. Диагностика выводит ключевые события.

local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свою игру)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)

local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1   -- -1 = влево, 1 = вправо

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
            local ownerAttr = boat:GetAttribute("Owner")
            if ownerAttr == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then return boat end
        end
    end
    return nil
end

-- ========== 3. ПОДДЕРЖАНИЕ BODYVELOCITY НА ПЕРСОНАЖЕ ==========
local function ensureBodyVelocity()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    
    -- Проверяем, сидит ли на нужном сиденье
    local sitting = (seat and humanoid.Sit and humanoid.SeatPart == seat)
    if not sitting then
        -- Удаляем BodyVelocity, если не сидит
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy() end
        return
    end
    
    -- Сидит: создаём/обновляем BodyVelocity
    local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        if bv.Velocity.X ~= speedX then
            bv.Velocity = Vector3.new(speedX, 0, 0)
            print("[DIAG] Скорость BodyVelocity обновлена: " .. speedX)
        end
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
        print("[DIAG] BodyVelocity создан, скорость: " .. speedX)
    end
end

-- ========== 4. ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ ==========
local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        print("[DIAG] Смена направления → вправо (X=" .. x .. ")")
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        print("[DIAG] Смена направления → влево (X=" .. x .. ")")
    end
end

-- ========== 5. ЦИКЛ ГАРАНТИРОВАННОЙ ПОСАДКИ ==========
local function forceSitOnSeat()
    -- Если лодка потеряна, ищем заново
    if not myBoat or not myBoat.Parent then
        myBoat = findMyBoat()
        if not myBoat then
            print("[DIAG] Лодка не найдена, посадка невозможна")
            return
        end
        seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        if not seat then
            print("[DIAG] Сиденье не найдено")
            myBoat = nil
            return
        end
        -- Отключаем коллизии лодки и родной скрипт
        for _, part in ipairs(myBoat:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        local native = myBoat:FindFirstChild("Script")
        if native then native.Disabled = true end
        print("[DIAG] Лодка найдена: " .. myBoat.Name)
    end
    
    if not seat then return end
    
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    
    if humanoid.Sit and humanoid.SeatPart == seat then return end
    
    print("[DIAG] Начинаем посадку...")
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local targetCF = seat.CFrame + SEAT_OFFSET
    local iter = 0
    
    while true do
        iter = iter + 1
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if iter % 10 == 0 then
            print(string.format("[DIAG] Расстояние до сиденья: %.2f", dist))
        end
        if dist < 1.5 then
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            print("[DIAG] Посадка успешна")
            break
        end
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
        if humanoid.Sit and humanoid.SeatPart == seat then
            print("[DIAG] Уже сидим, выход")
            break
        end
        targetCF = seat.CFrame + SEAT_OFFSET -- обновляем цель
    end
    bv:Destroy()
end

-- ========== 6. МОНИТОРИНГ ПОСАДКИ И ДВИЖЕНИЯ ==========
task.spawn(function()
    while true do
        task.wait(0.2)
        local char = player.Character
        if not char then
            -- Персонаж умер, сбрасываем ссылки
            myBoat = nil; seat = nil; rootPart = nil
            player.CharacterAdded:Wait()
            print("[DIAG] Персонаж появился")
            task.wait(1)
            continue
        end
        
        -- Если лодка не известна, пробуем найти через сиденье (если уже сидим)
        if not myBoat then
            local humanoid = char:FindFirstChild("Humanoid")
            local currentSeat = humanoid and humanoid.SeatPart
            if currentSeat then
                local boat = currentSeat:FindFirstAncestorWhichIsA("Model")
                if boat then
                    myBoat = boat
                    seat = currentSeat
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                    print("[DIAG] Лодка найдена через сиденье: " .. myBoat.Name)
                    -- Отключаем родной скрипт лодки
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                end
            end
        end
        
        -- Если сидим в своей лодке, поддерживаем движение
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = (seat and humanoid and humanoid.Sit and humanoid.SeatPart == seat)
        if sitting then
            updateDirection()
            ensureBodyVelocity()
        else
            -- Не сидим: если лодка есть, пытаемся сесть
            if myBoat and myBoat.Parent then
                forceSitOnSeat()
            else
                -- Лодки нет, ищем
                myBoat = findMyBoat()
                if myBoat then
                    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                    if seat then
                        forceSitOnSeat()
                    end
                end
            end
        end
    end
end)

print("[OK] Скрипт управления лодкой запущен. Диагностика активна.")
