-- ===== ФИНАЛЬНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ (ПОДНЯТАЯ ЛОДКА + ОСТРОВ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ (координаты лодки подняты на Y=26.8, как в эталонном скрипте)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_POINT_A = Vector3.new(-77389.3, 26.8, 32606.2)
local BOAT_POINT_B = Vector3.new(-47968.4, 26.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.3
local SIT_CHECK_INTERVAL = 0.3
local STUCK_THRESHOLD = 30
local BOAT_SEARCH_TIMEOUT = 10
local ISLAND_TIMEOUT = 600  -- 10 минут

local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local isSitting = false
local needToSit = true
local stopScript = false
local boatsFolder = workspace:FindFirstChild("Boats")
local islandMode = false
local islandTimerThread = nil

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

-- ========== 3. ПЕРЕМЕЩЕНИЕ К ТОЧКЕ ==========
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

-- ========== 4. ПОИСК ЛОДКИ ==========
local function findMyBoat()
    if not boatsFolder then
        boatsFolder = workspace:FindFirstChild("Boats")
        if not boatsFolder then return nil end
    end
    for _, boat in ipairs(boatsFolder:GetChildren()) do
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

-- ========== 6. ГАРАНТИРОВАННАЯ ПОСАДКА ==========
local function forceSit()
    if islandMode then
        return
    end
    if not myBoat or not myBoat.Parent then
        myBoat = findMyBoat()
        if not myBoat then
            moveToPoint(PURCHASE_POINT, WALK_SPEED)
            buyBoat()
            task.wait(3)
            for i = 1, BOAT_SEARCH_TIMEOUT do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                task.wait(5)
                return
            end
        end
        seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
        rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
        if not seat or not rootPart then
            myBoat = nil
            return
        end
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
    if humanoid.Sit and humanoid.SeatPart == seat then return end

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
        if dist < 1.5 then
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            break
        end
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED

        if math.abs(dist - lastDist) < 0.05 then
            stuck = stuck + 1
            if stuck > STUCK_THRESHOLD then
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
    if islandMode then
        return
    end
    if not isSitting or not myBoat or not rootPart then return end
    stopBoat()
    local points = {BOAT_POINT_A, BOAT_POINT_B}
    local index = 1
    local function moveToNext()
        if not isSitting or islandMode then
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
                if isSitting and not islandMode then
                    index = index % #points + 1
                    moveToNext()
                end
            end)
        end
    end
    moveToNext()
end

-- ========== 8. МОНИТОР ОСТРОВА (ПОИСК ПО ВСЕМУ WORKSPACE) ==========
local function findPrehistoricIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function onIslandActivated()
    if islandMode then return end
    print("[ISLAND] Остров Prehistoricisland появился! Выход из лодки, управление приостанавливается на 10 минут.")
    islandMode = true
    stopBoat()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Sit then
            humanoid.Sit = false
        end
    end
    needToSit = false
    if islandTimerThread then task.cancel(islandTimerThread) end
    islandTimerThread = task.spawn(function()
        task.wait(ISLAND_TIMEOUT)
        if islandMode then
            print("[ISLAND] 10 минут прошло, режим острова завершён. Возобновление работы.")
            islandMode = false
            needToSit = true
            myBoat = nil; seat = nil; rootPart = nil
            forceSit()
        end
    end)
end

local function onIslandDeactivated()
    if not islandMode then return end
    print("[ISLAND] Остров Prehistoricisland исчез досрочно, режим острова завершён.")
    if islandTimerThread then task.cancel(islandTimerThread) end
    islandMode = false
    needToSit = true
    myBoat = nil; seat = nil; rootPart = nil
    forceSit()
end

task.spawn(function()
    local lastIsland = false
    while not stopScript do
        local island = findPrehistoricIsland()
        local present = island ~= nil
        if present and not lastIsland then
            onIslandActivated()
        elseif not present and lastIsland then
            onIslandDeactivated()
        end
        lastIsland = present
        task.wait(1)
    end
end)

-- ========== 9. МОНИТОР ПОСАДКИ ==========
task.spawn(function()
    while not stopScript do
        task.wait(SIT_CHECK_INTERVAL)
        if islandMode then
            continue
        end
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

-- ========== 10. ГЛАВНЫЙ ЦИКЛ ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        if islandMode then
            task.wait(0.5)
            continue
        end
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

print("Скрипт запущен. Лодка поднята на высоту 26.8, поддержка острова активна.")
