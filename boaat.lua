-- ===== ФИНАЛЬНЫЙ СКРИПТ (ГАРАНТИРОВАННАЯ ПОСАДКА + TWEEN + ПЕРЕПОКУПКА ЛОДКИ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ (измените под свои координаты)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_POINT_A = Vector3.new(-77389.3, 26.8, 32606.2)  -- поднята Y
local BOAT_POINT_B = Vector3.new(-47968.4, 26.8, 6048.2)   -- поднята Y
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.2

local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local isSitting = false
local needToSit = true
local stopScript = false

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
task.spawn(function()
    while not stopScript do
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

-- ========== 2. ВЫБОР КОМАНДЫ ==========
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

-- ========== 3. ПЕРЕМЕЩЕНИЕ К ТОЧКЕ (BODYVELOCITY) ==========
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

-- ========== 4. ПОИСК ЛОДКИ ПО OWNER ==========
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

-- ========== 5. ПОКУПКА ЛОДКИ ==========
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

-- ========== 6. ГАРАНТИРОВАННАЯ ПОСАДКА (С ПЕРЕПОКУПКОЙ ПРИ ПОТЕРЕ ЛОДКИ) ==========
local function forceSit()
    print("[SIT] Начинаем посадку...")
    -- Если лодки нет, покупаем новую
    if not myBoat or not myBoat.Parent then
        print("[SIT] Лодка отсутствует, покупаем новую")
        moveToPoint(PURCHASE_POINT, WALK_SPEED)
        buyBoat()
        task.wait(3)
        for i = 1, 10 do
            myBoat = findMyBoat()
            if myBoat then break end
            task.wait(1)
        end
        if not myBoat then
            print("[SIT] Не удалось получить лодку, повтор через 5 сек")
            return
        end
        seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        if not seat or not rootPart then
            print("[SIT] Ошибка: нет сиденья или основной части")
            myBoat = nil
            return
        end
        -- Отключаем коллизии лодки и её скрипт
        for _, part in ipairs(myBoat:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        local native = myBoat:FindFirstChild("Script")
        if native then native.Disabled = true end
    end

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Sit and humanoid.SeatPart == seat then
        print("[SIT] Уже сидим")
        return
    end

    -- Удаляем старый BodyVelocity
    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    local lastDist = math.huge
    local stuck = 0
    while true do
        local targetCF = seat.CFrame + SEAT_OFFSET
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if dist < 1.0 then
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            print("[SIT] Посадка успешна")
            break
        end
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED

        if math.abs(dist - lastDist) < 0.05 then
            stuck = stuck + 1
            if stuck > 30 then
                print("[SIT] Застревание, принудительная телепортация")
                bv:Destroy()
                hrp.CFrame = targetCF
                humanoid.Sit = true
                break
            end
        else
            stuck = 0
        end
        lastDist = dist
        task.wait(0.1)
    end
    bv:Destroy()
end

-- ========== 7. ДВИЖЕНИЕ ЛОДКИ (TWEEN) ==========
local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function startBoatMovement()
    if not isSitting or not myBoat or not rootPart then return end
    stopBoat()
    local points = {BOAT_POINT_A, BOAT_POINT_B}
    local index = 1
    local function moveToNext()
        if not isSitting then
            stopBoat()
            return
        end
        local target = points[index]
        local dist = (rootPart.Position - target).Magnitude
        local duration = dist / BOAT_SPEED
        if duration > 0 then
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            currentTween.Completed:Connect(function()
                currentTween = nil
                if isSitting then
                    index = index % #points + 1
                    moveToNext()
                end
            end)
        end
    end
    moveToNext()
end

-- ========== 8. МОНИТОР ПОСАДКИ И ВОЗВРАТА ==========
task.spawn(function()
    while not stopScript do
        task.wait(0.2)
        local char = player.Character
        if not char then
            if isSitting then
                isSitting = false
                needToSit = true
                stopBoat()
            end
            player.CharacterAdded:Wait()
            char = player.Character
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            continue
        end
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then
            sitting = (humanoid.Sit and humanoid.SeatPart == seat)
        end
        if sitting ~= isSitting then
            isSitting = sitting
            if isSitting then
                needToSit = false
                startBoatMovement()
            else
                needToSit = true
                stopBoat()
            end
        end
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            stopBoat()
        end
        if needToSit then
            forceSit()
        end
    end
end)

-- ========== 9. ГЛАВНЫЙ ЦИКЛ (ПЕРВИЧНАЯ ПОКУПКА) ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        if not player.Character then
            player.CharacterAdded:Wait()
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            task.wait(1)
        end
        if needToSit then
            forceSit()
        end
        task.wait(0.5)
    end
end)

print("Скрипт запущен. Лодка движется на высоте Y=26.8. При потере лодки происходит перепокупка.")
