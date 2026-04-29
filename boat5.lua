-- ===== ФИНАЛЬНЫЙ СТАБИЛЬНЫЙ СКРИПТ (ИСПРАВЛЕННЫЙ СИНТАКСИС) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_Y_FIXED = 100
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.3
local SIT_CHECK_INTERVAL = 0.3
local STUCK_THRESHOLD = 30
local BOAT_SEARCH_TIMEOUT = 10
local ISLAND_TIMEOUT = 600
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

local myBoat = nil
local seat = nil
local rootPart = nil
local isSitting = false
local needToSit = true
local stopScript = false
local boatsFolder = workspace:FindFirstChild("Boats")
local islandMode = false
local boatMoving = false
local currentDirection = -1

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

-- ========== 3. ПОШАГОВОЕ ПЕРЕМЕЩЕНИЕ ==========
local function moveStepByStep(targetPos, speed, keepY)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end
    local oldPlatform = humanoid.PlatformStand
    humanoid.PlatformStand = true
    local step = 0.05
    while true do
        local current = hrp.Position
        local distance = (targetPos - current).Magnitude
        if distance < 0.5 then break end
        local direction = (targetPos - current).Unit
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        if keepY then newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z) end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    humanoid.PlatformStand = oldPlatform
    return true
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

-- ========== 5. ПОКУПКА ==========
local function buyBoatAndMove()
    print("[MAIN] Перемещение к точке покупки...")
    moveStepByStep(PURCHASE_POINT, WALK_SPEED, true)
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
    task.wait(3)
    for i = 1, BOAT_SEARCH_TIMEOUT do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then return false end
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
    print("[MAIN] Лодка готова: " .. myBoat.Name)
    return true
end

-- ========== 6. ПОСАДКА ==========
local function forceSit()
    if islandMode then return end
    if not myBoat or not myBoat.Parent then
        if not buyBoatAndMove() then return end
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
        task.wait(0.1)
    end
    bv:Destroy()
end

-- ========== 7. ДВИЖЕНИЕ ЛОДКИ ==========
local function startBoatMoving()
    if boatMoving then return end
    boatMoving = true
    task.spawn(function()
        while boatMoving and isSitting and not islandMode and myBoat and rootPart do
            local step = 0.05
            local delta = currentDirection * BOAT_SPEED * step
            local newX = rootPart.Position.X + delta
            if newX <= BOAT_X_MIN then
                newX = BOAT_X_MIN
                currentDirection = 1
            elseif newX >= BOAT_X_MAX then
                newX = BOAT_X_MAX
                currentDirection = -1
            end
            rootPart.CFrame = CFrame.new(newX, BOAT_Y_FIXED, rootPart.Position.Z)
            task.wait(step)
        end
        boatMoving = false
    end)
end

local function stopBoatMoving()
    boatMoving = false
end

-- ========== 8. ДЕТЕКТОР ФРУКТОВ ==========
local HttpService = game:GetService("HttpService")
local sentItems = {}
local function sendToDiscord(itemName)
    local message = { content = player.Name .. " получил '" .. itemName .. "'!", username = "Инвентарь" }
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
    local character = player.Character or player.CharacterAdded:Wait()
    local backpack = player:WaitForChild("Backpack")
    backpack.ChildAdded:Connect(function(item) task.wait(0.1); checkItem(item) end)
    character.ChildAdded:Connect(function(item) if item:IsA("Tool") then task.wait(0.1); checkItem(item) end end)
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:find("Fruit") then sentItems[item.Name] = true end
    end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.Name:find("Fruit") then sentItems[item.Name] = true end
    end
    print("Детектор фруктов запущен.")
end

-- ========== 9. ОСТРОВ ==========
local function findPrehistoricIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function moveToIslandSmooth(island)
    local targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)
    print("[ISLAND] Плавное перемещение на остров...")
    moveStepByStep(targetPos, 200, true)
    print("[ISLAND] Прибыли на остров")
end

local function onIslandActivated()
    if islandMode then return end
    islandMode = true
    stopBoatMoving()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Sit then
            humanoid.Sit = false
            task.wait(0.5)
        end
    end
    needToSit = false
    local island = findPrehistoricIsland()
    if island then moveToIslandSmooth(island) end
    task.spawn(function()
        for _ = 1, ISLAND_TIMEOUT * 2 do
            task.wait(0.5)
            if not islandMode then return end
        end
        if islandMode then
            print("[ISLAND] 10 минут прошло, возврат к лодке.")
            islandMode = false
            needToSit = true
            myBoat = nil; seat = nil; rootPart = nil
            forceSit()
        end
    end)
end

local function onIslandDeactivated()
    if not islandMode then return end
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
        if present and not lastIsland then onIslandActivated()
        elseif not present and lastIsland then onIslandDeactivated()
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
                stopBoatMoving()
            end
            player.CharacterAdded:Wait()
            char = player.Character
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            continue
        end
        local humanoid = char:FindFirstChild("Humanoid")
        local sitting = false
        if humanoid and seat then sitting = (humanoid.Sit and humanoid.SeatPart == seat) end
        if sitting ~= isSitting then
            isSitting = sitting
            if isSitting then
                needToSit = false
                startBoatMoving()
            else
                needToSit = true
                stopBoatMoving()
            end
        end
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil; seat = nil; rootPart = nil; needToSit = true; stopBoatMoving()
        end
        if needToSit then forceSit()
    end
end)

-- ========== 11. АНТИ-IDLE ==========
task.spawn(function()
    local camera = workspace.CurrentCamera
    local originalCF = camera.CFrame
    while true do
        task.wait(300)
        camera.CFrame = camera.CFrame * CFrame.Angles(0, math.rad(1), 0)
        task.wait(0.5)
        camera.CFrame = originalCF
    end
end)

-- ========== 12. ГЛАВНЫЙ ПОТОК ==========
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
            myBoat = nil; seat = nil; rootPart = nil; needToSit = true
            task.wait(1)
        end
        if needToSit then forceSit()
        task.wait(0.5)
    end
end)

-- Запуск детектора
task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)
    startFruitTracker()
end)

print("Скрипт успешно загружен. Все функции активны.")
