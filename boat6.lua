-- ===== ФИНАЛЬНЫЙ СКРИПТ (ПОСТОЯННЫЙ ГЛАВНЫЙ ЦИКЛ, МАГНИТ, ДВИЖЕНИЕ ЛОДКИ, ОСТРОВ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (ФОНОВЫЙ ПОТОК) ==========
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
-- Перемещение шагами (CFrame) – для посадки и для острова
local function moveStep(targetPos, speed, keepY)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    local oldPlatform = hum.PlatformStand
    hum.PlatformStand = true
    local step = 0.05
    local stepSize = speed * step
    while (hrp.Position - targetPos).Magnitude > 0.5 do
        local dir = (targetPos - hrp.Position).Unit
        local move = math.min(stepSize, (targetPos - hrp.Position).Magnitude)
        local newPos = hrp.Position + dir * move
        if keepY then newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z) end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = oldPlatform
    return true
end

-- Покупка лодки (простой вызов, без перемещения)
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    if not rs then return end
    local remotes = rs:FindFirstChild("Remotes")
    if not remotes then return end
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
end

-- Поиск лодки по Owner
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, b in ipairs(boats:GetChildren()) do
        if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
            if b:GetAttribute("Owner") == playerName then return b end
            local own = b:FindFirstChild("Owner")
            if own and tostring(own.Value) == playerName then return b end
        end
    end
    return nil
end

-- Детектор фруктов (Discord)
local sentFruits = {}
local function sendFruit(name)
    local msg = { content = player.Name .. " получил '" .. name .. "'!", username = "Инвентарь" }
    pcall(function()
        HttpService:RequestAsync({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(msg)
        })
    end)
    print("[DISCORD] Отправлено:", name)
end

local function checkFruit(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sentFruits[item.Name] then return end
        sentFruits[item.Name] = true
        sendFruit(item.Name)
    end
end

local function fruitTracker()
    local char = player.Character or player.CharacterAdded:Wait()
    local bp = player:WaitForChild("Backpack")
    bp.ChildAdded:Connect(function(it) task.wait(0.1); checkFruit(it) end)
    char.ChildAdded:Connect(function(it) if it:IsA("Tool") then task.wait(0.1); checkFruit(it) end end)
    for _, it in ipairs(bp:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sentFruits[it.Name] = true end end
    for _, it in ipairs(char:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sentFruits[it.Name] = true end end
    print("Детектор фруктов запущен")
end

-- Анти-idle
task.spawn(function()
    local cam = workspace.CurrentCamera
    local orig = cam.CFrame
    while true do
        task.wait(300)
        cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(1), 0)
        task.wait(0.5)
        cam.CFrame = orig
    end
end)

-- ========== 3. ОСТРОВ (ОТДЕЛЬНЫЙ ПОТОК) ==========
local islandMode = false
local islandReturn = false  -- флаг, что нужно вернуться к лодке после острова
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then return obj end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.5)
        local island = findIsland()
        if island and not islandMode then
            islandMode = true
            -- Принудительно выходим из лодки (если сидим)
            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Sit then hum.Sit = false end
            end
            -- Перемещаемся на остров (высоко)
            local target = island:GetPivot().Position + Vector3.new(0, 30, 0)
            moveStep(target, 200, true)
            -- Ожидание (10 минут или появление/исчезновение DragonEgg)
            local startTime = os.clock()
            local eggSeen = false
            while islandMode do
                if os.clock() - startTime >= 600 then
                    print("[ОСТРОВ] 10 минут истекло, выходим")
                    break
                end
                local core = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") and workspace.Map.Prehistoricisland:FindFirstChild("Core")
                local egg = core and core:FindFirstChild("SpawnedDragonEggs") and core.SpawnedDragonEggs:FindFirstChild("DragonEgg")
                if egg and not eggSeen then
                    eggSeen = true
                    print("[ОСТРОВ] DragonEgg появился, ждём исчезновения")
                end
                if eggSeen and not egg then
                    print("[ОСТРОВ] DragonEgg исчез, выходим")
                    break
                end
                task.wait(1)
            end
            islandMode = false
            islandReturn = true   -- сигнал главному циклу, что нужно вернуться к лодке
        end
    end
end)

-- ========== 4. ГЛАВНЫЙ ЦИКЛ (ПОСТОЯННАЯ ПРОВЕРКА ПОСАДКИ И ДВИЖЕНИЕ ЛОДКИ) ==========
-- Шаг 1: Выбор команды Marines
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
    local mods = rs:FindFirstChild("Modules")
    local ev = mods and mods:FindFirstChild("RE/OnEventServiceActivity")
    if ev then pcall(function() ev:FireServer() end) end
end

-- Глобальные переменные для лодки
local boat = nil
local seat = nil
local root = nil
local hum = nil
local hrp = nil
local bv = nil
local dir = -1
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100
local moving = false
local moveThread = nil

-- Функция для обновления ссылок на персонажа
local function updateCharacter()
    local char = player.Character
    if char then
        hum = char:FindFirstChild("Humanoid")
        hrp = char:FindFirstChild("HumanoidRootPart")
    else
        hum = nil
        hrp = nil
    end
end

-- Функция для подъёма лодки на нужную высоту (один раз)
local function liftBoat()
    if root then
        local pos = root.Position
        if math.abs(pos.Y - TARGET_Y) > 0.5 then
            root.CFrame = CFrame.new(pos.X, TARGET_Y, pos.Z)
            print("[ЛОДКА] Поднята на высоту 100")
        end
    end
end

-- Функция поддержания BodyVelocity на персонаже (движение лодки)
local function ensureBV()
    local ch = player.Character
    if not ch then return end
    local upper = ch:FindFirstChild("UpperTorso")
    if not upper then return end
    local sx = dir * SPEED_X
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    end
end

local function stopMove()
    moving = false
    if moveThread then pcall(task.cancel, moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

local function startMove()
    if moving then return end
    moving = true
    moveThread = task.spawn(function()
        local ch = player.Character
        if not ch then moving = false; return end
        local upper = ch:FindFirstChild("UpperTorso")
        if not upper then moving = false; return end
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(0, 0, 0)
        liftBoat()
        local sx = dir * SPEED_X
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
        while moving do
            if not (hum and hum.Sit and hum.SeatPart == seat) then
                stopMove()
                break
            end
            if root then
                local p = root.Position
                if math.abs(p.Y - TARGET_Y) > 0.5 then
                    root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
                end
                if p.X <= X_MIN and dir == -1 then
                    dir = 1
                    ensureBV()
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    ensureBV()
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

-- Магнит: плавное возвращение на сиденье (без принудительного Sit)
local function magnet()
    if not boat or not seat then return end
    local char = player.Character
    if not char then return end
    local humCur = char:FindFirstChild("Humanoid")
    local hrpCur = char:FindFirstChild("HumanoidRootPart")
    if not humCur or not hrpCur then return end
    if humCur.Sit and humCur.SeatPart == seat then return end
    local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
    local dist = (hrpCur.Position - targetPos).Magnitude
    if dist > 0.3 then
        local dirVec = (targetPos - hrpCur.Position).Unit
        local step = math.min(150 * 0.05, dist)
        local newPos = hrpCur.Position + dirVec * step
        hrpCur.CFrame = CFrame.new(newPos)
    else
        hrpCur.CFrame = CFrame.new(targetPos)
    end
end

-- ГЛАВНЫЙ ЦИКЛ (постоянная проверка, выполняется всегда)
task.spawn(function()
    while true do
        task.wait(0.5)
        updateCharacter()
        if islandMode then
            -- Если остров активен, не выполняем никаких действий с лодкой
            continue
        end
        -- Если флаг возврата с острова установлен, сбрасываем ссылки на лодку и принудительно возвращаемся к посадке
        if islandReturn then
            islandReturn = false
            boat = nil
            seat = nil
            root = nil
            print("[ГЛАВНЫЙ] Возврат с острова, сброс лодки")
        end
        -- Если нет лодки, ищем или покупаем
        if not boat or not boat.Parent then
            boat = findMyBoat()
            if not boat then
                print("[ГЛАВНЫЙ] Лодки нет, покупаем...")
                buyBoat()
                for i = 1, 20 do
                    boat = findMyBoat()
                    if boat then break end
                    task.wait(0.5)
                end
                if not boat then
                    print("[ГЛАВНЫЙ] Лодка не появилась, повтор через 5 сек")
                    task.wait(5)
                    continue
                end
            end
            seat = boat:FindFirstChildWhichIsA("VehicleSeat")
            root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            if not seat or not root then
                boat = nil
                continue
            end
            for _, p in ipairs(boat:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            local nat = boat:FindFirstChild("Script")
            if nat then nat.Disabled = true end
            print("[ГЛАВНЫЙ] Лодка найдена: " .. boat.Name)
        end
        -- Проверка, сидит ли персонаж на этом сиденье
        if hum and hum.Sit and hum.SeatPart == seat then
            -- Сидит: запускаем движение лодки, если ещё не запущено
            if not moving then
                startMove()
            end
        else
            -- Не сидит: останавливаем движение и пытаемся сесть через магнит
            if moving then stopMove() end
            magnet()
        end
    end
end)

-- Запуск детектора фруктов
task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)
    fruitTracker()
end)

print("Скрипт успешно запущен. Главный цикл активен, остров обрабатывается, магнит работает.")
