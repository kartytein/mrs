-- ===== ИТОГОВЫЙ СКРИПТ С ДВИЖЕНИЕМ КАК В ЭТАЛОНЕ (МАЛЕНЬКИЕ ШАГИ) =====
local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- НАСТРОЙКИ ДВИЖЕНИЯ ЛОДКИ (на основе лога)
local X_MIN = -77389.3
local X_MAX = -47968.4
local Y_FIXED = 100
local STEP_INTERVAL = 0.2          -- интервал между шагами (сек)
local STEP_MIN = -11.5              -- минимальное смещение по X (отрицательное = влево)
local STEP_MAX = -5.2               -- максимальное смещение

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
        task.wait(0.3)
    end
end)

-- ========== 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
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
        local move = math.min(150 * step, distance)
        local newPos = current + direction * move
        if keepY then newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z) end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    humanoid.PlatformStand = oldPlatform
    return true
end

local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
end

local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == player.Name then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == player.Name then return boat end
        end
    end
    return nil
end

local function sitOnSeat(boatSeat, hrp, humanoid)
    local targetCF = boatSeat.CFrame + Vector3.new(0, 2.5, 0)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * 150
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
end

-- ========== 3. ДЕТЕКТОР ФРУКТОВ ==========
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
    for _, item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") and item.Name:find("Fruit") then sentItems[item.Name] = true end end
    for _, item in ipairs(character:GetChildren()) do if item:IsA("Tool") and item.Name:find("Fruit") then sentItems[item.Name] = true end end
    print("Детектор фруктов запущен.")
end

-- ========== 4. ОСТРОВ ==========
local islandMode = false
local function findPrehistoricIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then return obj end
    end
    return nil
end

-- ========== 5. АНТИ-IDLE ==========
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

-- ========== 6. ЛОДКА: ДВИЖЕНИЕ МАЛЕНЬКИМИ ШАГАМИ ==========
local myBoat = nil
local seat = nil
local rootPart = nil
local humanoid = nil
local hrp = nil
local boatMoving = false
local boatThread = nil
local currentDirection = -1  -- начинаем движение влево (как в логах)

local function stopBoatMoving()
    boatMoving = false
end

local function startBoatMoving()
    if boatThread then return end
    boatMoving = true
    boatThread = task.spawn(function()
        local lastStepTime = tick()
        while boatMoving do
            local now = tick()
            if now - lastStepTime >= STEP_INTERVAL then
                -- Генерируем случайный шаг в диапазоне от STEP_MIN до STEP_MAX (отрицательные)
                local stepX = STEP_MIN + (STEP_MAX - STEP_MIN) * math.random()
                stepX = stepX * currentDirection  -- учитываем направление (currentDirection = -1 влево, 1 вправо)
                local newX = rootPart.Position.X + stepX
                if newX <= X_MIN then
                    newX = X_MIN
                    currentDirection = 1
                elseif newX >= X_MAX then
                    newX = X_MAX
                    currentDirection = -1
                end
                rootPart.CFrame = CFrame.new(newX, Y_FIXED, rootPart.Position.Z)
                lastStepTime = now
            end
            task.wait(0.05)
        end
        boatThread = nil
    end)
end

local function forceSit()
    if not myBoat or not myBoat.Parent then return end
    if not seat then seat = myBoat:FindFirstChildWhichIsA("VehicleSeat") end
    if not seat then return end
    local char = player.Character
    if not char then return end
    local h = char:FindFirstChild("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    if h.Sit and h.SeatPart == seat then return end
    sitOnSeat(seat, r, h)
end

-- ========== 7. ОСНОВНОЙ ПОТОК ==========
task.spawn(function()
    -- Выбор команды Marines
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end

    -- Покупка лодки
    buyBoat()
    print("Ожидание появления лодки...")
    task.wait(3)
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then error("Лодка не найдена") end
    print("Лодка найдена:", myBoat.Name)
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then error("Нет сиденья или основной части") end
    for _, part in ipairs(myBoat:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Посадка
    local char = player.Character or player.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    sitOnSeat(seat, hrp, humanoid)
    print("Посадка выполнена")

    -- Запуск движения лодки
    startBoatMoving()
end)

-- Мониторинг посадки (при вылезании)
task.spawn(function()
    while true do
        task.wait(0.5)
        if islandMode then continue end
        local char = player.Character
        if not char then
            player.CharacterAdded:Wait()
            char = player.Character
            myBoat = nil; seat = nil; rootPart = nil
            continue
        end
        if not myBoat or not myBoat.Parent then
            myBoat = findMyBoat()
            if myBoat then
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if seat and rootPart then
                    for _, part in ipairs(myBoat:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                else
                    myBoat = nil
                end
            end
        end
        if humanoid and seat and not (humanoid.Sit and humanoid.SeatPart == seat) then
            forceSit()
        end
    end
end)

-- Мониторинг острова (при появлении выходим, при исчезновении возвращаемся)
task.spawn(function()
    while true do
        local island = findPrehistoricIsland()
        if island and not islandMode then
            print("[ОСТРОВ] Появился! Выход из лодки, перемещение на остров.")
            islandMode = true
            stopBoatMoving()
            if humanoid then humanoid.Sit = false end
            task.wait(0.5)
            local targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)
            moveStepByStep(targetPos, 200, true)
            -- Ждём исчезновения острова
            while workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") do
                task.wait(1)
            end
            print("[ОСТРОВ] Исчез. Возврат к лодке.")
            islandMode = false
            forceSit()
            startBoatMoving()
        end
        task.wait(1)
    end
end)

-- Запуск детектора фруктов
task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)
    startFruitTracker()
end)

print("Скрипт запущен. Лодка движется маленькими шагами, как в эталонном скрипте.")
