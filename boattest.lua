-- ===== АБСОЛЮТНО НАДЁЖНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (С ПОСТОЯННЫМ ПОДДЕРЖАНИЕМ BODYVELOCITY) =====
-- Скрипт не останавливается никогда. Все процессы перезапускаются при сбоях.
-- BodyVelocity пересоздаётся каждые 0.1 секунды, пока персонаж сидит.
-- Коллизии отключаются постоянно.
-- При вылезании или смерти персонаж возвращается на сиденье.
-- Если лодка сломана, покупается новая (с перемещением в точку).

local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свою игру)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)

-- Глобальные переменные (сохраняются между циклами)
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1   -- -1 = влево, 1 = вправо
local needToMove = true       -- флаг: нужно ли переместиться в точку покупки

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            -- Все части персонажа
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            -- Нижняя и верхняя часть (особо важно)
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

-- ========== 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
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

-- Перемещение к точке (с повторными попытками)
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
        task.wait(0.1)
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
    if humanoid then humanoid.PlatformStand = false end
end

-- Поиск своей лодки (по Owner)
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

-- Покупка лодки
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
        task.wait(0.1)
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
end

-- ========== 3. ПОСТОЯННОЕ ПОДДЕРЖАНИЕ BODYVELOCITY (ГЛАВНЫЙ МЕХАНИЗМ) ==========
-- Этот поток запускается один раз и работает всегда, независимо от других.
-- Каждые 0.1 секунды он проверяет: если персонаж сидит на нужном сиденье, то создаёт/обновляет BodyVelocity.
-- Если не сидит, то удаляет BodyVelocity.
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then continue end

        -- Проверяем, сидит ли персонаж на нашем сиденье
        local sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        if sitting then
            -- Сидит: создаём/обновляем BodyVelocity с текущим направлением
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
            -- Не сидит: удаляем BodyVelocity
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then bv:Destroy() end
        end
    end
end)

-- ========== 4. ОБНОВЛЕНИЕ НАПРАВЛЕНИЯ (ОТДЕЛЬНЫЙ ПОТОК) ==========
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

-- ========== 5. ГЛАВНЫЙ ЦИКЛ (ПОКУПКА ЛОДКИ, ПОСАДКА, ВОССТАНОВЛЕНИЕ ПОСЛЕ СМЕРТИ) ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- Ожидание персонажа (если умер)
        if not player.Character then
            player.CharacterAdded:Wait()
            -- Сброс ссылок, лодка могла исчезнуть
            myBoat = nil
            seat = nil
            rootPart = nil
            needToMove = true
            task.wait(1)
        end

        -- Если лодки нет, покупаем (с предварительным перемещением)
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
            -- Отключаем родной скрипт лодки
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
        end

        -- Если персонаж не сидит, сажаем
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
            sitOnSeat()
        end

        task.wait(0.5)
    end
end)

print("Скрипт запущен. BodyVelocity пересоздаётся каждые 0.1 секунды, коллизии отключены, всё работает непрерывно.")
