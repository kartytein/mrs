-- ===== ПОЛНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ + ДЕТЕКТОР ФРУКТОВ (БЕЗ task.cancel) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- НАСТРОЙКИ
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
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local isSitting = false
local needToSit = true
local stopScript = false
local boatsFolder = workspace:FindFirstChild("Boats")
local islandMode = false
local islandTimerThread = nil
local boatMovementActive = false  -- флаг вместо task.cancel

-- ========== ДЕТЕКТОР ФРУКТОВ ==========
local sentItems = {}

local function saveToFile(username)
    if type(writefile) == "function" then
        local fileName = username .. ".txt"
        local content = "Yummytool"
        local success, err = pcall(function()
            writefile(fileName, content)
        end)
        if success then
            print("[✓] Файл сохранён:", fileName)
        else
            warn("[✗] Ошибка writefile:", err)
        end
    else
        warn("[✗] writefile недоступна. Файл не создан.")
    end
end

local function sendToDiscord(itemName)
    local message = {
        content = player.Name .. " получил '" .. itemName .. "'!",
        username = "Инвентарь"
    }
    local json = HttpService:JSONEncode(message)
    local success, err = pcall(function()
        HttpService:RequestAsync({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
    if success then
        print("[✓] Discord отправлено:", itemName)
    else
        warn("[✗] Ошибка Discord:", err)
    end
end

local function checkItem(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sentItems[item.Name] then return end
        sentItems[item.Name] = true
        print("Найден фрукт:", item.Name)
        sendToDiscord(item.Name)
        saveToFile(player.Name)
    end
end

local function startTracking()
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()
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
    print("Детектор фруктов запущен для", player.Name)
end

-- ========== ОБЩИЕ ФУНКЦИИ ==========
local function selectPirates()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Pirates") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end
end

-- Загрузка хада (безопасно)
local function loadHud()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Huylovemy/Bearhudz/refs/heads/main/Bearhud.lua"))()
    end)
end

-- ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ
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

-- УНИВЕРСАЛЬНОЕ ПОШАГОВОЕ ПЕРЕМЕЩЕНИЕ (CFrame)
local function moveStepByStep(targetPos, speed, keepY)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end
    local oldPlatform = humanoid.PlatformStand
    humanoid.PlatformStand = true
    local step = 0.05
    local lastDist = math.huge
    local stuck = 0
    while true do
        local current = hrp.Position
        local distance = (targetPos - current).Magnitude
        if distance < 0.5 then break end
        local direction = (targetPos - current).Unit
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        if keepY then
            newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
        if math.abs(distance - lastDist) < 0.01 then
            stuck = stuck + 1
            if stuck > 50 then break
        else
            stuck = 0
        end
        lastDist = distance
    end
    hrp.CFrame = CFrame.new(targetPos)
    humanoid.PlatformStand = oldPlatform
    return true
end

-- ПОИСК ЛОДКИ ПО OWNER
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

-- ПОКУПКА ЛОДКИ (с перемещением к точке)
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

-- ПОСАДКА НА СИДЕНЬЕ (BodyVelocity)
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

-- ДВИЖЕНИЕ ЛОДКИ (пошаговое CFrame)
local function moveBoatToPoint(targetPos, speed)
    if not rootPart then return end
    local step = 0.05
    while true do
        local current = rootPart.Position
        local distance = (targetPos - current).Magnitude
        if distance < 0.5 then break end
        local direction = (targetPos - current).Unit
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        rootPart.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    rootPart.CFrame = CFrame.new(targetPos)
end

local boatMovementThread = nil
local function startBoatMovement()
    if islandMode then return end
    if not isSitting or not myBoat or not rootPart then return end
    if boatMovementThread then return end -- уже работает
    local points = {BOAT_POINT_A, BOAT_POINT_B}
    local index = 1
    boatMovementActive = true
    boatMovementThread = task.spawn(function()
        while boatMovementActive and isSitting and not islandMode and myBoat and myBoat.Parent do
            moveBoatToPoint(points[index], BOAT_SPEED)
            index = index % #points + 1
        end
        boatMovementThread = nil
        boatMovementActive = false
    end)
end

local function stopBoat()
    boatMovementActive = false
    if boatMovementThread then
        -- ждём завершения потока (не используем task.cancel)
        while boatMovementThread do task.wait(0.1) end
    end
end

-- ПЕРЕМЕЩЕНИЕ К ОСТРОВУ (пошаговое)
local function moveToIslandSmooth(island)
    local targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)
    print("[ISLAND] Перемещение на остров...")
    moveStepByStep(targetPos, 200, true)
    print("[ISLAND] Прибыли на остров")
end

-- МОНИТОР ОСТРОВА
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
    print("[ISLAND] Остров появился. Выход из лодки, перемещение на остров.")
    islandMode = true
    stopBoat()
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
    if island then
        moveToIslandSmooth(island)
    end
    if islandTimerThread then return end
    islandTimerThread = task.spawn(function()
        task.wait(ISLAND_TIMEOUT)
        if islandMode then
            print("[ISLAND] 10 минут прошло, возврат к лодке.")
            islandMode = false
            needToSit = true
            myBoat = nil; seat = nil; rootPart = nil
            forceSit()
        end
        islandTimerThread = nil
    end)
end

local function onIslandDeactivated()
    if not islandMode then return end
    print("[ISLAND] Остров исчез досрочно.")
    if islandTimerThread then
        islandTimerThread = nil -- просто забываем поток, он сам завершится
    end
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

-- МОНИТОР ПОСАДКИ
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

-- ГЛАВНЫЙ ЦИКЛ
task.spawn(function()
    selectPirates()
    loadHud()
    task.wait(2)

    -- Мониторинг Beli для авторелог
    local beli = player:WaitForChild("Data", 10):WaitForChild("Beli", 10)
    local timer = nil
    local function resetTimerOnBeliChange()
        if timer then task.cancel(timer) end
        timer = task.spawn(function()
            task.wait(30)
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end
    beli:GetPropertyChangedSignal("Value"):Connect(resetTimerOnBeliChange)
    resetTimerOnBeliChange()

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

-- Запуск детектора фруктов
if player.Character then
    task.wait(2)
    startTracking()
else
    player.CharacterAdded:Connect(function()
        task.wait(2)
        startTracking()
    end)
end

print("Скрипт полностью запущен. Управление лодкой, остров, детектор фруктов, авторелог по Beli.")
