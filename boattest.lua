-- ============================================================================
-- АБСОЛЮТНО НАДЁЖНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (ВЕРСИЯ 2.0)
-- Включены все проверки, постоянное отключение коллизий, принудительное пересоздание BodyVelocity,
-- возврат на сиденье при вылезании/смерти, перепокупка лодки при её потере.
-- Скрипт работает непрерывно, 24/7.
-- ============================================================================

local player = game.Players.LocalPlayer
local playerName = player.Name

-- ===== НАСТРОЙКИ (ИЗМЕНИТЕ ПОД СВОЮ ИГРУ) =====
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)      -- координаты, где покупать лодку
local BOAT_X_MIN = -77389.3                               -- левая граница (дальняя)
local BOAT_X_MAX = -47968.4                               -- правая граница (ближняя)
local BOAT_SPEED = 250                                    -- скорость движения лодки (по оси X)
local WALK_SPEED = 150                                    -- скорость при перемещении к сиденью
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)                -- высота над сиденьем
local COLLISION_INTERVAL = 0.2                            -- частота отключения коллизий

-- ===== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ =====
local myBoat = nil            -- модель лодки
local seat = nil              -- VehicleSeat в лодке
local rootPart = nil          -- основная часть лодки (для определения X)
local currentDirection = -1   -- -1 = движение влево, 1 = движение вправо
local needToMove = true       -- флаг: нужно ли переместиться в точку покупки

-- ===== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (ПЕРСОНАЖ + ЛОДКА) =====
-- Этот поток работает всегда, каждые 0.2 секунды принудительно отключает CanCollide.
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            -- Все части персонажа
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            -- Особенно важно для LowerTorso и UpperTorso (как в эталонном скрипте)
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

-- ===== 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====
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

-- Перемещение к точке (BodyVelocity) с автоматическим пересозданием при застревании
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
    local lastDist = math.huge
    local stuckCount = 0
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait(0.1)
        local dist = (hrp.Position - target).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            stuckCount = stuckCount + 1
            if stuckCount > 10 then
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
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
    if humanoid then humanoid.PlatformStand = false end
end

-- Поиск своей лодки (по атрибуту Owner или объекту Owner)
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

-- Покупка лодки (вызов удалённой функции)
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- Посадка на сиденье (с повторными попытками, пока не сядет)
local function sitOnSeat()
    if not seat then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    -- Удаляем предыдущий BodyVelocity, чтобы не мешал
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    local targetCF = seat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local lastDist = math.huge
    local stuckCount = 0
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if math.abs(dist - lastDist) < 0.1 then
            stuckCount = stuckCount + 1
            if stuckCount > 10 then
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
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
end

-- ===== 3. ПОСТОЯННОЕ ПОДДЕРЖАНИЕ BODYVELOCITY ДЛЯ ДВИЖЕНИЯ ЛОДКИ =====
-- Этот поток работает независимо от остальных. Каждые 0.1 секунды он проверяет,
-- сидит ли персонаж на нужном сиденье. Если да – создаёт/обновляет BodyVelocity.
-- Если нет – удаляет BodyVelocity. Это гарантирует, что скорость всегда будет,
-- даже если игра её сбросила (например, при получении урона).
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then continue end

        local sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        if sitting then
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

-- ===== 4. ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ ДВИЖЕНИЯ ЛОДКИ =====
-- Этот поток каждые 0.2 секунды проверяет X-координату лодки и меняет направление.
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

-- ===== 5. ГЛАВНЫЙ ЦИКЛ (ПОКУПКА ЛОДКИ, ПОСАДКА, ВОССТАНОВЛЕНИЕ ПОСЛЕ СМЕРТИ) =====
-- Этот цикл отвечает за то, чтобы лодка всегда существовала и персонаж всегда сидел.
-- Он также обрабатывает смерть персонажа.
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание появления персонажа (если умер)
        if not player.Character then
            player.CharacterAdded:Wait()
            -- После смерти лодка может исчезнуть, поэтому сбрасываем ссылки
            myBoat = nil
            seat = nil
            rootPart = nil
            needToMove = true
            task.wait(1)
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if not humanoid then
            task.wait(0.5)
            continue
        end

        -- Если лодки нет, покупаем новую (с предварительным перемещением)
        if not myBoat or not myBoat.Parent then
            if needToMove then
                moveToPoint(PURCHASE_POINT, WALK_SPEED)
                needToMove = false
            end
            buyBoat()
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not rootPart then
                myBoat = nil
                continue
            end
            -- Отключаем родной скрипт лодки, чтобы он не мешал
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
        end

        -- Если персонаж не сидит, сажаем его
        local sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        if not sitting then
            sitOnSeat()
        end

        task.wait(0.5)
    end
end)

print("Скрипт успешно загружен. Все механизмы активны. Лодка будет двигаться непрерывно.")
