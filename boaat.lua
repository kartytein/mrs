-- ===== ФИНАЛЬНЫЙ РАБОЧИЙ СКРИПТ (ГАРАНТИРОВАННАЯ ПОСАДКА) =====
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

-- ========== 3. ГАРАНТИРОВАННАЯ ПОСАДКА (С ПОСТОЯННЫМ ОБНОВЛЕНИЕМ) ==========
local function forceSitOnSeat()
    -- Если лодка не известна, ищем
    if not myBoat or not myBoat.Parent then
        myBoat = findMyBoat()
        if not myBoat then
            print("[DIAG] Лодка не найдена, посадка отложена")
            return
        end
    end
    -- Обновляем сиденье и rootPart
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then
        print("[DIAG] Сиденье или rootPart не найдены")
        return
    end
    
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    
    if humanoid.Sit and humanoid.SeatPart == seat then
        print("[DIAG] Уже сидим")
        return
    end
    
    print("[DIAG] Начинаем посадку...")
    -- Удаляем старый BodyVelocity
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    
    local startTime = tick()
    local lastDist = math.huge
    local stuckCount = 0
    
    while true do
        -- Обновляем цель (сиденье может двигаться)
        local targetCF = seat.CFrame + SEAT_OFFSET
        local dist = (hrp.Position - targetCF.Position).Magnitude
        
        if dist < 1.5 then
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            print("[DIAG] Посадка успешна")
            break
        end
        
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        
        -- Проверка застревания
        if math.abs(dist - lastDist) < 0.05 then
            stuckCount = stuckCount + 1
            if stuckCount > 30 then
                print("[DIAG] Застревание, пересоздаём BodyVelocity")
                bv:Destroy()
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp
                stuckCount = 0
            end
        else
            stuckCount = 0
        end
        lastDist = dist
        
        -- Таймаут 10 секунд: принудительная телепортация
        if tick() - startTime > 10 then
            print("[DIAG] Таймаут посадки, принудительная телепортация")
            bv:Destroy()
            hrp.CFrame = seat.CFrame + SEAT_OFFSET
            humanoid.Sit = true
            break
        end
        
        if humanoid.Sit and humanoid.SeatPart == seat then
            print("[DIAG] Уже сидим во время цикла")
            break
        end
        
        task.wait(0.1)
    end
    if bv then bv:Destroy() end
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
        -- Ожидание появления персонажа после смерти
        if not player.Character then
            myBoat = nil; seat = nil; rootPart = nil
            player.CharacterAdded:Wait()
            task.wait(1)
        end
        
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local currentSeat = humanoid and humanoid.SeatPart
        local isSittingInMyBoat = false
        if currentSeat then
            local boat = currentSeat:FindFirstAncestorWhichIsA("Model")
            if boat and boat == myBoat then
                isSittingInMyBoat = true
            end
        end
        
        if not isSittingInMyBoat then
            print("[DIAG] Не сидим в своей лодке, запуск посадки")
            forceSitOnSeat()
        end
    end
end)

print("[DIAG] Скрипт запущен. Гарантированная посадка с телепортацией при застревании.")
