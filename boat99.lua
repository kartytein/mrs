-- ===== ИСПРАВЛЕННЫЙ ФИНАЛЬНЫЙ СКРИПТ (ПОСТОЯННАЯ ПРОВЕРКА ПОСАДКИ, БЕЗ ОСТАНОВОК) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"  -- замените на свой

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
            if owner == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then return boat end
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

-- ========== 3. ДЕТЕКТОР ФРУКТОВ (DISCORD) ==========
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

-- ========== 6. ДВИЖЕНИЕ ЛОДКИ (ТОЛЬКО ПО X, ФИКСАЦИЯ ВЫСОТЫ) ==========
local myBoat = nil
local seat = nil
local rootPart = nil
local humanoid = nil
local hrp = nil
local bv = nil
local bodyPos = nil
local currentDirection = -1
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local Y_FIXED = 100
local movementActive = false
local movementThread = nil

local function fixBoatHeight()
    if not rootPart then return end
    if bodyPos and bodyPos.Parent then
        bodyPos.Position = Vector3.new(rootPart.Position.X, Y_FIXED, rootPart.Position.Z)
    else
        if bodyPos then bodyPos:Destroy() end
        bodyPos = Instance.new("BodyPosition")
        bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
        bodyPos.Parent = rootPart
        bodyPos.Position = Vector3.new(rootPart.Position.X, Y_FIXED, rootPart.Position.Z)
    end
end

local function ensureBodyVelocity()
    local char = player.Character
    if not char then return end
    local upperTorso = char:FindFirstChild("UpperTorso")
    if not upperTorso then return end
    local speedX = currentDirection * SPEED_X
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(speedX, 0, 0)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upperTorso
        bv.Velocity = Vector3.new(speedX, 0, 0)
    end
end

local function stopBoatMovement()
    movementActive = false
    if movementThread then
        movementThread = nil
    end
    if bv then bv:Destroy(); bv = nil end
    if bodyPos then bodyPos:Destroy(); bodyPos = nil end
end

local function startBoatMovement()
    if movementActive then return end
    movementActive = true
    movementThread = task.spawn(function()
        local char = player.Character
        if char then
            local upperTorso = char:FindFirstChild("UpperTorso")
            if upperTorso then
                if bv then bv:Destroy() end
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = upperTorso
                bv.Velocity = Vector3.new(0, 2, 0)
                task.wait(0.05)
                local speedX = currentDirection * SPEED_X
                bv.Velocity = Vector3.new(speedX, 0, 0)
            end
        end
        fixBoatHeight()
        while movementActive do
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                stopBoatMovement()
                break
            end
            if rootPart then
                local x = rootPart.Position.X
                if x <= X_MIN and currentDirection == -1 then
                    currentDirection = 1
                    ensureBodyVelocity()
                elseif x >= X_MAX and currentDirection == 1 then
                    currentDirection = -1
                    ensureBodyVelocity()
                end
                if bodyPos then
                    bodyPos.Position = Vector3.new(rootPart.Position.X, Y_FIXED, rootPart.Position.Z)
                end
            end
            task.wait(0.05)
        end
    end)
end

-- ПРИНУДИТЕЛЬНАЯ ПОСАДКА (БУДЕТ ВЫЗЫВАТЬСЯ ПОВТОРНО, ПОКА НЕ СЯДЕТ)
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
    -- Не запускаем движение здесь, оно запустится в мониторе после успешной посадки
end

-- ========== 7. ГЛАВНЫЙ БЕСКОНЕЧНЫЙ МОНИТОР ПОСАДКИ И ДВИЖЕНИЯ ==========
task.spawn(function()
    while true do
        -- Если режим острова активен, пропускаем всё, кроме проверки персонажа
        if not islandMode then
            -- 1. Проверяем существование лодки
            if not myBoat or not myBoat.Parent then
                myBoat = findMyBoat()
                if myBoat then
                    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                    if seat and rootPart then
                        for _, part in ipairs(myBoat:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                        local native = myBoat:FindFirstChild("Script")
                        if native then native.Disabled = true end
                    else
                        myBoat = nil
                    end
                end
            end

            -- 2. Если лодки нет, покупаем (предварительно переместившись)
            if not myBoat or not myBoat.Parent then
                local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
                moveStepByStep(PURCHASE_POINT, 150, true)
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
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
                -- Первая посадка после покупки
                local char = player.Character or player.CharacterAdded:Wait()
                hrp = char:WaitForChild("HumanoidRootPart")
                humanoid = char:WaitForChild("Humanoid")
                sitOnSeat(seat, hrp, humanoid)
                startBoatMovement()
            end

            -- 3. Проверяем, сидит ли персонаж на сиденье
            local char = player.Character
            local h = char and char:FindFirstChild("Humanoid")
            if h and seat then
                if not (h.Sit and h.SeatPart == seat) then
                    -- Не сидит: останавливаем движение и пытаемся сесть
                    if movementActive then stopBoatMovement() end
                    forceSit()
                    -- Если после посадки движение остановлено, запускаем заново
                    if not movementActive and h.Sit and h.SeatPart == seat then
                        startBoatMovement()
                    end
                else
                    -- Сидит: проверяем, работает ли движение
                    if not movementActive then
                        startBoatMovement()
                    end
                end
            end
        end

        -- Даже в режиме острова нужно следить за персонажем (чтобы после острова он был в лодке)
        if not player.Character then
            player.CharacterAdded:Wait()
            -- Сброс состояния лодки, чтобы перепокупать
            myBoat = nil
            seat = nil
            rootPart = nil
            if movementActive then stopBoatMovement() end
        end

        task.wait(0.5)
    end
end)

-- ========== 8. МОНИТОР ОСТРОВА ==========
task.spawn(function()
    while true do
        local island = findPrehistoricIsland()
        if island and not islandMode then
            print("[ОСТРОВ] Появился! Выход из лодки, перемещение на остров.")
            islandMode = true
            if movementActive then stopBoatMovement() end
            if humanoid then humanoid.Sit = false end
            task.wait(0.5)
            local targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)
            moveStepByStep(targetPos, 200, true)
            local startTime = os.clock()
            local function checkEgg()
                local core = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") and workspace.Map.Prehistoricisland:FindFirstChild("Core")
                if core then
                    local eggs = core:FindFirstChild("SpawnedDragonEggs")
                    if eggs then return eggs:FindFirstChild("DragonEgg") ~= nil end
                end
                return false
            end
            local eggSeen = false
            while islandMode do
                if os.clock() - startTime >= 600 then break end
                local hasEgg = checkEgg()
                if hasEgg and not eggSeen then
                    eggSeen = true
                    print("[ОСТРОВ] DragonEgg появился, ожидаем исчезновения")
                end
                if eggSeen and not hasEgg then
                    print("[ОСТРОВ] DragonEgg исчез")
                    break
                end
                task.wait(1)
            end
            print("[ОСТРОВ] Режим острова завершён. Возврат к лодке.")
            islandMode = false
            -- Принудительно вызовем посадку в следующем цикле
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

print("Финальный скрипт запущен. Постоянная проверка посадки, лодка будет возвращаться после смерти/вылезания.")
