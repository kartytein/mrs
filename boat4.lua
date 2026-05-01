-- ===== ФИНАЛЬНЫЙ СКРИПТ (ИСПРАВЛЕНЫ ВСЕ ОТСУТСТВУЮЩИЕ END) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- Постоянное отключение коллизий
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

-- Перемещение шагами (CFrame)
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

-- Посадка на сиденье (шагами)
local function sitOnSeat(seat, hrp, hum)
    local target = seat.Position + Vector3.new(0, 2.5, 0)
    moveStep(target, 150, true)
    hum.Sit = true
    task.wait(0.3)
end

-- Покупка лодки
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    if not rs then return end
    local remotes = rs:FindFirstChild("Remotes")
    if not remotes then return end
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
end

-- Детектор фруктов (Discord)
local sentFruits = {}
local function sendFruit(itemName)
    local msg = { content = player.Name .. " получил '" .. itemName .. "'!", username = "Инвентарь" }
    pcall(function()
        HttpService:RequestAsync({ Url = DISCORD_WEBHOOK, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode(msg) })
    end)
    print("[DISCORD] Отправлено:", itemName)
end

local function checkFruit(item)
    if item:IsA("Tool") and item.Name:find("Fruit") then
        if sentFruits[item.Name] then return end
        sentFruits[item.Name] = true
        sendFruit(item.Name)
    end
end

local function startFruitTracker()
    local char = player.Character or player.CharacterAdded:Wait()
    local bp = player:WaitForChild("Backpack")
    bp.ChildAdded:Connect(function(it) task.wait(0.1); checkFruit(it) end)
    char.ChildAdded:Connect(function(it) if it:IsA("Tool") then task.wait(0.1); checkFruit(it) end end)
    for _, it in ipairs(bp:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sentFruits[it.Name] = true end end
    for _, it in ipairs(char:GetChildren()) do if it:IsA("Tool") and it.Name:find("Fruit") then sentFruits[it.Name] = true end end
    print("Детектор фруктов запущен")
end

-- Остров
local islandMode = false
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then return obj end
    end
    return nil
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

-- Движение лодки (BodyVelocity)
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
        if root then
            local p = root.Position
            if math.abs(p.Y - TARGET_Y) > 0.5 then
                root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
            end
        end
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

-- Магнит (мгновенная посадка)
local function forceSit()
    if not boat or not boat.Parent then
        boat = findMyBoat()
        if not boat then
            moveStep(Vector3.new(-16917,9.1,447), 150, true)
            buyBoat()
            task.wait(3)
            for i=1,10 do
                boat = findMyBoat()
                if boat then break end
                task.wait(1)
            end
            if not boat then return end
        end
        seat = boat:FindFirstChildWhichIsA("VehicleSeat")
        root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
        if not seat or not root then
            boat = nil
            return
        end
        for _, p in ipairs(boat:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
        local native = boat:FindFirstChild("Script")
        if native then native.Disabled = true end
    end
    if not seat then return end
    local char = player.Character
    if not char then return end
    if not hum or not hrp then
        hum = char:FindFirstChild("Humanoid")
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
    end
    if hum.Sit and hum.SeatPart == seat then return end
    hrp.CFrame = seat.CFrame + Vector3.new(0, 2.5, 0)
    hum.Sit = true
    if root then
        local pos = root.Position
        root.CFrame = CFrame.new(pos.X, TARGET_Y, pos.Z)
    end
    if not moving then startMove() end
end

-- Постоянный магнит (цикл)
task.spawn(function()
    while true do
        task.wait(0.05)
        if islandMode then continue end
        if not boat or not seat then continue
        local char = player.Character
        if not char then continue
        if not hum or not hrp then
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp then continue
        end
        if not (hum.Sit and hum.SeatPart == seat) then
            pcall(forceSit)
        end
    end
end)

-- Монитор острова
task.spawn(function()
    local cooldown = false
    local cooldownTimer = 0
    while true do
        task.wait(0.5)
        local island = findIsland()
        if island and not islandMode then
            if not (cooldown and tick() - cooldownTimer < 10) then
                cooldown = false
            end
        end
        if island and not islandMode then
            islandMode = true
            stopMove()
            if hum then hum.Sit = false end
            task.wait(0.5)
            local target = island:GetPivot().Position + Vector3.new(0, 30, 0)
            moveStep(target, 200, true)
            local start = os.clock()
            local eggSeen = false
            while islandMode do
                if os.clock() - start >= 600 then break end
                local core = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") and workspace.Map.Prehistoricisland:FindFirstChild("Core")
                local egg = core and core:FindFirstChild("SpawnedDragonEggs") and core.SpawnedDragonEggs:FindFirstChild("DragonEgg")
                if egg and not eggSeen then
                    eggSeen = true
                    print("[ОСТРОВ] DragonEgg появился, ждём исчезновения")
                end
                if eggSeen and not egg then
                    print("[ОСТРОВ] DragonEgg исчез")
                    break
                end
                task.wait(1)
            end
            islandMode = false
            cooldown = true
            cooldownTimer = tick()
            boat = findMyBoat()
            if boat then
                seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if seat and root then
                    for _, p in ipairs(boat:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                    local native = boat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                else
                    boat = nil
                end
            else
                moveStep(Vector3.new(-16917,9.1,447), 150, true)
                buyBoat()
                task.wait(3)
                for i=1,10 do
                    boat = findMyBoat()
                    if boat then break end
                    task.wait(1)
                end
                if boat then
                    seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                    root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                    if seat and root then
                        for _, p in ipairs(boat:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = false end
                        end
                        local native = boat:FindFirstChild("Script")
                        if native then native.Disabled = true end
                    end
                end
            end
            forceSit()
            startMove()
            task.wait(2)
            cooldown = false
        end
    end
end)

-- Главный монитор (обновление после смерти)
task.spawn(function()
    while true do
        task.wait(0.5)
        if islandMode then continue end
        local char = player.Character
        if not char then
            if moving then stopMove() end
            boat = nil; seat = nil; root = nil
            player.CharacterAdded:Wait()
            char = player.Character
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
            task.wait(1)
            continue
        end
        if not hum or not hrp then
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        end
        if not boat or not boat.Parent then
            boat = findMyBoat()
            if boat then
                seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if seat and root then
                    for _, p in ipairs(boat:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                    local native = boat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                else
                    boat = nil
                end
            end
        end
    end
end)

-- Первичный запуск
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

    boat = findMyBoat()
    if not boat then
        moveStep(Vector3.new(-16917,9.1,447), 150, true)
        buyBoat()
        print("Ожидание лодки...")
        task.wait(3)
        for i=1,10 do
            boat = findMyBoat()
            if boat then break end
            task.wait(1)
        end
        if not boat then error("Лодка не найдена") end
        seat = boat:FindFirstChildWhichIsA("VehicleSeat")
        root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
        if not seat or not root then error("Нет сиденья/части") end
        for _, p in ipairs(boat:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
        local native = boat:FindFirstChild("Script")
        if native then native.Disabled = true end
    end

    local char = player.Character or player.CharacterAdded:Wait()
    hrp = char:FindFirstChild("HumanoidRootPart")
    hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return
    sitOnSeat(seat, hrp, hum)
    if root then
        local pos = root.Position
        root.CFrame = CFrame.new(pos.X, TARGET_Y, pos.Z)
    end
    startMove()
end)

task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)
    startFruitTracker()
end)

print("Скрипт запущен. Все синтаксические ошибки исправлены.")
