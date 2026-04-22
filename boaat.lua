-- ===== УПРАВЛЕНИЕ ЛОДКОЙ (ТОЛЬКО ПОСАДКА И ДВИЖЕНИЕ) =====
-- Вы садитесь в лодку вручную. Скрипт находит её, отключает коллизии,
-- поддерживает движение и возвращает на сиденье при вылезании.
-- Покупка и перемещение к точке не включены.

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
        local native = myBoat:FindFirstChild("Script")
        if native then native.Disabled = true end
    end
end

-- ========== 3. ПОСАДКА (ЦИКЛ ДО УСПЕХА) ==========
local function forceSitOnSeat()
    if not seat then
        print("[DIAG] Посадка: нет сиденья, обновляем из myBoat")
        if myBoat and myBoat.Parent then
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        end
        if not seat then
            print("[DIAG] Посадка: сиденье не найдено, выход")
            return
        end
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Sit and humanoid.SeatPart == seat then
        return
    end
    print("[DIAG] Начинаем посадку...")
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

-- ========== 6. МОНИТОРИНГ ПОСАДКИ ==========
task.spawn(function()
    while true do
        task.wait(0.5)
        if not player.Character then
            myBoat = nil; seat = nil; rootPart = nil
            player.CharacterAdded:Wait()
            task.wait(1)
        end
        updateBoatFromSeat()
        if seat then
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid and not (humanoid.Sit and humanoid.SeatPart == seat) then
                forceSitOnSeat()
            end
        end
    end
end)

print("[DIAG] Скрипт управления лодкой запущен. Сядьте в лодку вручную.")
