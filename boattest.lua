-- ===== АБСОЛЮТНО НАДЁЖНЫЙ СКРИПТ (ПОСТОЯННЫЕ ПОВТОРНЫЕ ПОПЫТКИ ДВИЖЕНИЯ) =====
-- Все перемещения (к точке покупки, к сиденью, движение лодки) выполняются через BodyVelocity
-- с постоянной проверкой достижения цели и автоматическим пересозданием при остановке.

local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ (измените под свои координаты)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local currentDirection = -1   -- -1 = влево, 1 = вправо
local isSitting = false
local needToSit = true

-- ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- Отключение коллизий у персонажа (всех частей)
local function disableCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Выбор команды Marines
local function selectMarines()
    log("Выбор команды Marines...")
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end
    log("Команда Marines выбрана")
end

-- Поиск своей лодки
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

-- Покупка лодки (без перемещения, только вызов)
local function buyBoat()
    log("Покупка лодки...")
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- ========== УНИВЕРСАЛЬНОЕ ПЕРЕМЕЩЕНИЕ К ЦЕЛИ (С ПОВТОРНЫМИ ПОПЫТКАМИ) ==========
local function moveToTarget(targetPos, speed, stopDistance)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then humanoid.PlatformStand = true end

    disableCollisions(char)

    local bv = nil
    local lastDist = math.huge
    local stuckCount = 0

    while true do
        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= stopDistance then break end

        -- Создаём или обновляем BodyVelocity
        if not bv or bv.Parent == nil then
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
        end
        local dir = (targetPos - hrp.Position).Unit
        bv.Velocity = dir * speed

        task.wait(0.1)

        -- Проверка на застревание
        if math.abs(dist - lastDist) < 0.1 then
            stuckCount = stuckCount + 1
            if stuckCount > 10 then
                log("Застревание, пересоздаём BodyVelocity")
                bv:Destroy()
                bv = nil
                stuckCount = 0
            end
        else
            stuckCount = 0
        end
        lastDist = dist
    end

    if bv then bv:Destroy() end
    hrp.CFrame = CFrame.new(targetPos)
    if humanoid then humanoid.PlatformStand = false end
    return true
end

-- ========== ПОСАДКА НА СИДЕНЬЕ (С ПОВТОРНЫМИ ПОПЫТКАМИ) ==========
local function sitOnSeat(boatSeat, hrp, humanoid)
    log("Начинаем посадку...")
    local char = hrp.Parent
    disableCollisions(char)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local bv = nil
    local lastDist = math.huge
    local stuckCount = 0

    while true do
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if dist <= 0.5 then break end

        if not bv or bv.Parent == nil then
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
        end
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED

        task.wait(0.1)

        if math.abs(dist - lastDist) < 0.1 then
            stuckCount = stuckCount + 1
            if stuckCount > 10 then
                log("Застревание при посадке, пересоздаём")
                bv:Destroy()
                bv = nil
                stuckCount = 0
            end
        else
            stuckCount = 0
        end
        lastDist = dist
    end

    if bv then bv:Destroy() end
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    log("Посадка завершена")
    return true
end

-- ========== ПОДДЕРЖАНИЕ ДВИЖЕНИЯ ЛОДКИ (ПОСТОЯННОЕ ОБНОВЛЕНИЕ) ==========
local function ensureBoatMovement()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not isSitting then return end

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
end

local function updateDirection()
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= BOAT_X_MIN and currentDirection == -1 then
        currentDirection = 1
        ensureBoatMovement()
    elseif x >= BOAT_X_MAX and currentDirection == 1 then
        currentDirection = -1
        ensureBoatMovement()
    end
end

-- ========== ГЛАВНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while true do
        -- 1. Ожидание персонажа (если умер)
        local char = player.Character
        if not char then
            log("Персонаж отсутствует, ожидание...")
            player.CharacterAdded:Wait()
            char = player.Character
            log("Персонаж появился")
            myBoat = nil; seat = nil; rootPart = nil
            isSitting = false; needToSit = true
            disableCollisions(char)
            task.wait(1)
        end

        -- 2. Если лодки нет, покупаем новую
        if not myBoat or not myBoat.Parent then
            log("Лодка отсутствует, начинаем процесс покупки")
            moveToTarget(PURCHASE_POINT, WALK_SPEED, 2)
            buyBoat()
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                log("Не удалось призвать лодку, повтор через 5 сек")
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not rootPart then
                log("Ошибка: нет сиденья или основной части")
                myBoat = nil
                continue
            end
            -- Отключаем коллизии лодки и её скрипт
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
            log("Лодка готова")
        end

        -- 3. Проверка, сидит ли персонаж
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end

        if not sitting then
            if needToSit then
                log("Персонаж не сидит, посадка...")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and humanoid then
                    sitOnSeat(seat, hrp, humanoid)
                    if humanoid.Sit and humanoid.SeatPart == seat then
                        isSitting = true
                        needToSit = false
                        log("Успешно сел")
                    else
                        log("Посадка не удалась, повтор")
                        task.wait(0.5)
                    end
                else
                    task.wait(0.5)
                end
            else
                isSitting = false
                needToSit = true
                log("Персонаж слез")
            end
        else
            if not isSitting then
                isSitting = true
                needToSit = false
                log("Персонаж сидит, запускаем движение")
            end
            ensureBoatMovement()
            updateDirection()
        end

        task.wait(0.1)
    end
end)

log("Скрипт запущен. Все перемещения с автоматическими повторными попытками.")
