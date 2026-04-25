-- ===== ПОЛНЫЙ СКРИПТ С ПОДДЕРЖКОЙ ОСТРОВА PREHISTORICISLAND (ПЕРЕМЕЩЕНИЕ К ОСТРОВУ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ (измените под свои координаты)
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_POINT_A = Vector3.new(-77389.3, 22.8, 32606.2)
local BOAT_POINT_B = Vector3.new(-47968.4, 22.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.3
local SIT_CHECK_INTERVAL = 0.3
local STUCK_THRESHOLD = 30
local BOAT_SEARCH_TIMEOUT = 10
local ISLAND_TIMEOUT = 600  -- 10 минут в секундах

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
    if islandMode then return end
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
    if islandMode then return end
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

-- ========== 8. ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К ОСТРОВУ (ПОШАГОВОЕ, БЕЗ ТЕЛЕПОРТАЦИИ) ==========
local function moveToIslandSmooth(island)
    local targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)  -- высота 30 над центром
    print("[ISLAND] Начинаем плавное перемещение к острову, цель: " .. tostring(targetPos))
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    -- Отключаем коллизии (уже отключены, но на всякий случай)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    humanoid.PlatformStand = true

    local speed = 200
    local step = 0.05
    while true do
        local current = hrp.Position
        local distance = (targetPos - current).Magnitude
        if distance < 1 then break end
        local direction = (targetPos - current).Unit
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        -- Фиксируем Y на целевой высоте, чтобы не падал
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    -- Финальная доводка
    hrp.CFrame = CFrame.new(targetPos)

    humanoid.PlatformStand = false
    print("[ISLAND] Прибыли на остров")
end

-- ========== 9. МОНИТОР ОСТРОВА ==========
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
    print("[ISLAND] Остров Prehistoricisland появился! Выход из лодки, перемещение на остров.")
    islandMode = true
    stopBoat()
    -- Выход из лодки
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Sit then
            humanoid.Sit = false
            task.wait(0.5)
        end
    end
    needToSit = false  -- временно отключаем посадку
    -- Перемещение к острову
    local island = findPrehistoricIsland()
    if island then
        moveToIslandSmooth(island)
    else
        print("[ISLAND] Остров внезапно исчез перед перемещением")
    end
    -- Запускаем таймер на 10 минут
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

-- ========== 10. МОНИТОР ПОСАДКИ ==========
task.spawn(function()
    while not stopScript do
        task.wait(SIT_CHECK_INTERVAL)
        if islandMode then continue end
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

-- ========== 11. ГЛАВНЫЙ ЦИКЛ ==========
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

print("Скрипт запущен. При появлении Prehistoricisland персонаж выйдет из лодки, плавно переместится на остров и вернётся через 10 минут.")

-- ========== ДЕТЕКТОР ФРУКТОВ (DISCORD) - ИСПРАВЛЕННЫЙ ==========
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"
local sentItems = {}

local function sendToDiscord(itemName)
    local message = {
        content = player.Name .. " получил '" .. itemName .. "'!",
        username = "Инвентарь"
    }
    local json = HttpService:JSONEncode(message)
    pcall(function()
        HttpService:RequestAsync({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
    print("[DISCORD] Отправлено:", itemName)
end

local function checkItem(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sentItems[item.Name] then return end
        sentItems[item.Name] = true
        sendToDiscord(item.Name)
    end
end

local function startFruitTracker()
    -- Ждём появления персонажа, если его нет
    local character = player.Character or player.CharacterAdded:Wait()
    local backpack = player:WaitForChild("Backpack")

    backpack.ChildAdded:Connect(function(item)
        task.wait(0.1)
        checkItem(item)
    end)
    character.ChildAdded:Connect(function(item)
        if item:IsA("Tool") then
            task.wait(0.1)
            checkItem(item)
        end
    end)
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:find("Fruit") then
            sentItems[item.Name] = true
        end
    end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.Name:find("Fruit") then
            sentItems[item.Name] = true
        end
    end
    print("Детектор фруктов запущен.")
end

-- Запуск детектора с ожиданием персонажа
task.spawn(function()
    -- Убедимся, что персонаж существует
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    task.wait(2)
    startFruitTracker()
end)
