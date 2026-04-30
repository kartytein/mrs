-- ===== ФИНАЛЬНЫЙ ПОЛНЫЙ СКРИПТ (ИСПРАВЛЕН ВОЗВРАТ ПОСЛЕ ОСТРОВА) =====
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

-- ========== 6. ДВИЖЕНИЕ ЛОДКИ (С ПОДДЕРЖАНИЕМ ВЫСОТЫ) ==========
local myBoat = nil
local seat = nil
local rootPart = nil
local humanoid = nil
local hrp = nil
local bv = nil
local currentDirection = -1
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100
local movementActive = false
local movementThread = nil

local function ensureBodyVelocity()
    local char = player.Character
    if not char then return end
    local upperTorso = char:FindFirstChild("UpperTorso")
    if not upperTorso then return end
    local speedX = currentDirection * SPEED_X
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(speedX, SPEED_Y, SPEED_Z)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upperTorso
        bv.Velocity = Vector3.new(speedX, SPEED_Y, SPEED_Z)
    end
end

local function stopBoatMovement()
    movementActive = false
    if movementThread then
        pcall(task.cancel, movementThread)
        movementThread = nil
    end
    if bv then bv:Destroy() end
    bv = nil
end

local function startBoatMovement()
    if movementActive then return end
    movementActive = true
    movementThread = task.spawn(function()
        local char = player.Character
        if not char then return end
        local upperTorso = char:FindFirstChild("UpperTorso")
        if not upperTorso then return end
        
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upperTorso
        bv.Velocity = Vector3.new(0, 0, 0)
        task.wait(0.05)
        local speedX = currentDirection * SPEED_X
        bv.Velocity = Vector3.new(speedX, SPEED_Y, SPEED_Z)
        
        while movementActive do
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                stopBoatMovement()
                break
            end
            if rootPart then
                local pos = rootPart.Position
                if math.abs(pos.Y - TARGET_Y) > 0.5 then
                    rootPart.CFrame = CFrame.new(pos.X, TARGET_Y, pos.Z)
                end
                if pos.X <= X_MIN and currentDirection == -1 then
                    currentDirection = 1
                    ensureBodyVelocity()
                elseif pos.X >= X_MAX and currentDirection == 1 then
                    currentDirection = -1
                    ensureBodyVelocity()
                end
            end
            if bv and bv.Parent then
                local v = bv.Velocity
                bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001)
            end
            task.wait(0.05)
        end
    end)
end

-- ========== 7. УСИЛЕННАЯ ПОСАДКА (С ПОВТОРНЫМИ ПОПЫТКАМИ) ==========
local function forceSit()
    if not myBoat or not myBoat.Parent then
        myBoat = findMyBoat()
        if not myBoat then
            print("[FORCESIT] Лодка не найдена, покупка новой...")
            local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
            moveStepByStep(PURCHASE_POINT, 150, true)
            buyBoat()
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then return end
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
        print("[FORCESIT] Лодка найдена: " .. myBoat.Name)
    end
    if not seat then
        seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
        if not seat then return end
    end
    local char = player.Character
    if not char then return end
    local h = char:FindFirstChild("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    if h.Sit and h.SeatPart == seat then return end
    
    for attempt = 1, 10 do
        sitOnSeat(seat, r, h)
        task.wait(1)
        if h.Sit and h.SeatPart == seat then
            print("[FORCESIT] Посадка успешна с " .. attempt .. " попытки")
            break
        end
        print("[FORCESIT] Попытка " .. attempt .. " не удалась, повторяем...")
    end
    if not (h.Sit and h.SeatPart == seat) then
        r.CFrame = seat.CFrame + Vector3.new(0, 2.5, 0)
        h.Sit = true
        print("[FORCESIT] Телепортация на сиденье")
    end
    if not movementActive then
        startBoatMovement()
    end
end

-- ========== 8. МОНИТОР ПОСАДКИ ==========
task.spawn(function()
    while true do
        task.wait(0.5)
        if islandMode then continue end
        local char = player.Character
        if not char then
            if movementActive then stopBoatMovement() end
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

-- ========== 9. МОНИТОР ОСТРОВА (С ГАРАНТИРОВАННЫМ ВОЗВРАТОМ) ==========
task.spawn(function()
    local islandCoolDown = false
    local cooldownTimer = 0
    while true do
        task.wait(0.5)
        local island = findPrehistoricIsland()
        if island and not islandMode then
            if islandCoolDown and tick() - cooldownTimer < 10 then
                continue
            else
                islandCoolDown = false
            end
        end
        if island and not islandMode then
            print("[ОСТРОВ] Появился! Выход из лодки, перемещение на остров.")
            islandMode = true
            stopBoatMovement()
            if humanoid then humanoid.Sit = false end
            task.wait(0.5)
            local targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)
            moveStepByStep(targetPos, 200, true)
            local startTime = os.clock()
            local eggSeen = false
            local function checkEgg()
                local core = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") and workspace.Map.Prehistoricisland:FindFirstChild("Core")
                if core then
                    local eggs = core:FindFirstChild("SpawnedDragonEggs")
                    if eggs then return eggs:FindFirstChild("DragonEgg") end
                end
                return nil
            end
            while islandMode do
                if os.clock() - startTime >= 600 then
                    print("[ОСТРОВ] Таймер 10 минут истёк, выходим из режима острова.")
                    break
                end
                local egg = checkEgg()
                if egg and not eggSeen then
                    eggSeen = true
                    print("[ОСТРОВ] DragonEgg появился, ожидаем исчезновения...")
                end
                if eggSeen and not egg then
                    print("[ОСТРОВ] DragonEgg исчез, выходим из режима острова.")
                    break
                end
                task.wait(1)
            end
            islandMode = false
            print("[ОСТРОВ] Режим острова завершён. Возврат к лодке.")
            islandCoolDown = true
            cooldownTimer = tick()
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
            else
                print("[ОСТРОВ] Лодка не найдена, покупка новой...")
            end
            forceSit()
            if rootPart and rootPart.Parent and humanoid and humanoid.Sit then
                local pos = rootPart.Position
                rootPart.CFrame = CFrame.new(pos.X, 100, pos.Z)
                print("[ОСТРОВ] Лодка поднята на высоту 100")
            end
            startBoatMovement()
            task.wait(2)
            islandCoolDown = false
        end
    end
end)

-- ========== 10. ГЛАВНЫЙ ПОТОК (ПОКУПКА, ПОСАДКА) ==========
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end

    local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
    moveStepByStep(PURCHASE_POINT, 150, true)
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
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    local char = player.Character or player.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    sitOnSeat(seat, hrp, humanoid)
    print("Посадка выполнена")
    startBoatMovement()
end)

task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)
    startFruitTracker()
end)

print("Скрипт запущен. Лодка удерживается на высоте 100, остров обрабатывается, возврат гарантирован.")
