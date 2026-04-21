-- ===== МИНИМАЛЬНЫЙ СКРИПТ ДЛЯ УПРАВЛЕНИЯ ЛОДКОЙ (БЕЗ ПОКУПКИ И ПЕРЕМЕЩЕНИЯ) =====
-- Скрипт предполагает, что лодка уже существует, и вы уже сидите в ней или сядете вручную.
-- Он будет поддерживать движение лодки и возвращать вас на сиденье, если вы слезете.

local player = game.Players.LocalPlayer

-- НАСТРОЙКИ (измените под свою игру)
local BOAT_X_MIN = -77389.3      -- левая граница (дальняя)
local BOAT_X_MAX = -47968.4      -- правая граница (ближняя)
local BOAT_SPEED = 250           -- скорость лодки (по модулю)
local WALK_SPEED = 150           -- скорость при полёте к сиденью
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)   -- высота над сиденьем

-- Глобальные переменные
local myBoat = nil      -- модель лодки (будет определена, когда вы сядете)
local seat = nil        -- VehicleSeat
local rootPart = nil    -- основная часть лодки для определения X
local currentDirection = -1   -- -1 = влево, 1 = вправо

-- ===== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (для персонажа) =====
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
        task.wait(0.2)
    end
end)

-- ===== 2. ФУНКЦИЯ ПОСАДКИ НА СИДЕНЬЕ =====
local function sitOnSeat(boatSeat, hrp, humanoid)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
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
end

-- ===== 3. ПОСТОЯННОЕ ПОДДЕРЖАНИЕ BODYVELOCITY ДЛЯ ДВИЖЕНИЯ =====
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then continue end

        -- Определяем лодку и сиденье по SeatPart (если персонаж сидит)
        local currentSeat = humanoid.SeatPart
        if currentSeat and currentSeat:IsA("VehicleSeat") then
            -- Если лодка изменилась, обновляем ссылки
            local boat = currentSeat:FindFirstAncestorWhichIsA("Model")
            if boat ~= myBoat then
                myBoat = boat
                seat = currentSeat
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                -- Отключаем коллизии у лодки
                if myBoat then
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end

        -- Если персонаж сидит на нужном сиденье
        if seat and humanoid.Sit and humanoid.SeatPart == seat then
            -- Обновляем направление по X лодки
            if rootPart then
                local x = rootPart.Position.X
                if x <= BOAT_X_MIN and currentDirection == -1 then
                    currentDirection = 1
                elseif x >= BOAT_X_MAX and currentDirection == 1 then
                    currentDirection = -1
                end
            end
            -- Устанавливаем скорость
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
            -- Если не сидит, удаляем BodyVelocity и, если есть лодка, пытаемся сесть
            local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
            if bv then bv:Destroy() end
            if seat and myBoat and myBoat.Parent then
                sitOnSeat(seat, hrp, humanoid)
            end
        end
    end
end)

print("Скрипт запущен. Сядьте в лодку вручную, и скрипт начнёт управлять движением и возвращать вас на сиденье.")
