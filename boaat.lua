-- ===== ПОЛНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ С ДИАГНОСТИКОЙ BODYVELOCITY =====
-- Автоматический выбор команды Marines, покупка лодки (при необходимости),
-- посадка, постоянное движение (с частым пересозданием BodyVelocity),
-- возврат на сиденье при вылезании/смерти, смена направления по границам X.

local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свою игру)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)      -- точка покупки лодки
local BOAT_X_MIN = -77389.3                               -- левая граница
local BOAT_X_MAX = -47968.4                               -- правая граница
local BOAT_SPEED = 250                                    -- скорость лодки (по X)
local WALK_SPEED = 150                                    -- скорость при посадке
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)                -- высота над сиденьем
local COLLISION_INTERVAL = 0.2                            -- частота отключения коллизий
local BV_REFRESH_INTERVAL = 0.05                          -- частота пересоздания BodyVelocity

local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1          -- -1 = влево, 1 = вправо
local needToMove = true               -- флаг для перемещения к точке покупки
local isSitting = false

-- ========== 1. ДИАГНОСТИКА BODYVELOCITY (ЛОГГЕР) ==========
local function log(...) print("[BV]", ...) end
-- Перехват создания BodyVelocity (без ошибок)
local oldNew = Instance.new
Instance.new = function(className, parent)
    local instance = oldNew(className, parent)
    if className == "BodyVelocity" then
        log("СОЗДАН BodyVelocity, Parent =", parent and parent:GetFullName() or "nil")
        instance:GetPropertyChangedSignal("Velocity"):Connect(function()
            log("Скорость изменена у", instance.Parent and instance.Parent:GetFullName() or "nil", "->", instance.Velocity)
        end)
        instance.AncestryChanged:Connect(function()
            if not instance.Parent then
                log("BodyVelocity УДАЛЁН (Parent = nil)")
            end
        end)
    end
    return instance
end
-- Периодический поиск уже существующих BodyVelocity
task.spawn(function()
    while true do
        task.wait(1)
        for _, bv in ipairs(workspace:GetDescendants()) do
            if bv:IsA("BodyVelocity") and not bv._tracked then
                bv._tracked = true
                log("Обнаружен существующий BodyVelocity, Parent =", bv.Parent and bv.Parent:GetFullName() or "nil", "Velocity =", bv.Velocity)
                bv:GetPropertyChangedSignal("Velocity"):Connect(function()
                    log("Скорость изменена у", bv.Parent and bv.Parent:GetFullName() or "nil", "->", bv.Velocity)
                end)
                bv.AncestryChanged:Connect(function()
                    if not bv.Parent then
                        log("BodyVelocity УДАЛЁН (Parent = nil)")
                    end
                end)
            end
        end
    end
end)

-- ========== 2. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
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
        task.wait(COLLISION_INTERVAL)
    end
end)

-- ========== 3. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
local function selectMarines()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end
end

local function moveToPoint(target, speed)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
    if humanoid then humanoid.PlatformStand = false end
end

local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then return boat end
        end
    end
    return nil
end

local function buyNewBoat()
    print("[MAIN] Покупка новой лодки...")
    if needToMove then
        moveToPoint(PURCHASE_POINT, WALK_SPEED)
        needToMove = false
    end
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
    task.wait(3)
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then
        print("[MAIN] Не удалось купить лодку")
        return false
    end
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then
        myBoat = nil
        return false
    end
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end
    print("[MAIN] Новая лодка готова: " .. myBoat.Name)
    return true
end

-- ========== 4. ПОСАДКА (ЦИКЛ ДО УСПЕХА) ==========
local function forceSit()
    if not myBoat or not myBoat.Parent then
        myBoat = findMyBoat()
        if not myBoat then
            if not buyNewBoat() then return end
        end
    end
    if not seat or not seat.Parent then
        seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        if not seat then return end
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Sit and humanoid.SeatPart == seat then return end
    
    -- Удаляем старый BodyVelocity
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local targetCF = seat.CFrame + SEAT_OFFSET
    
    while true do
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if dist < 1.5 then
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            break
        end
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
    end
    bv:Destroy()
end

-- ========== 5. ПРИНУДИТЕЛЬНОЕ ПОДДЕРЖАНИЕ BODYVELOCITY (ЧАСТОЕ ПЕРЕСОЗДАНИЕ) ==========
task.spawn(function()
    while true do
        task.wait(BV_REFRESH_INTERVAL)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then continue end
        if seat and humanoid.Sit and humanoid.SeatPart == seat then
            local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then
                bv.Velocity = Vector3.new(speedX, 0, 0)
            else
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp
                bv.Velocity = Vector3.new(speedX, 0, 0)
            end
        end
    end
end)

-- ========== 6. ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ ==========
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

-- ========== 7. МОНИТОРИНГ ПОСАДКИ И ВОССТАНОВЛЕНИЯ ==========
task.spawn(function()
    while true do
        task.wait(0.5)
        if not player.Character then
            myBoat = nil; seat = nil; rootPart = nil
            needToMove = true
            player.CharacterAdded:Wait()
            task.wait(1)
        end
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local currentSeat = humanoid and humanoid.SeatPart
        local inMyBoat = false
        if currentSeat then
            local boat = currentSeat:FindFirstAncestorWhichIsA("Model")
            if boat and boat == myBoat then
                inMyBoat = true
            end
        end
        if not inMyBoat then
            forceSit()
        end
    end
end)

-- ========== 8. ЗАПУСК ==========
selectMarines()
print("[MAIN] Скрипт управления лодкой запущен. Диагностика BodyVelocity активна.")
