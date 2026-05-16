-- ===== ФИНАЛЬНЫЙ СКРИПТ 10.0 (ПЛАВНОЕ ДВИЖЕНИЕ + ИСХОДНАЯ ПОСАДКА) =====
-- Движение: BodyVelocity на UpperTorso, SPEED_Y = -0.0002, без искусственных изменений скорости.
-- Посадка: как в вашем первом скрипте (moveStep + hum.Sit).
-- Магнит: возвращает в лодку без дёрганий.

local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- ========== 1. ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
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
        local boats = workspace:FindFirstChild("Boats")
        if boats then
            for _, boat in ipairs(boats:GetChildren()) do
                if boat:IsA("Model") and (boat:GetAttribute("Owner") == playerName or (boat:FindFirstChild("Owner") and boat.Owner.Value == playerName)) then
                    for _, part in ipairs(boat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- ========== 2. ПЕРЕМЕЩЕНИЕ (moveStep из вашего скрипта) ==========
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
        local moveDist = math.min(stepSize, (targetPos - hrp.Position).Magnitude)
        local newPos = hrp.Position + dir * moveDist
        if keepY then newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z) end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = oldPlatform
    return true
end

-- ========== 3. ПОКУПКА / ПОИСК ЛОДКИ ==========
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    if not rs then return end
    local remotes = rs:FindFirstChild("Remotes")
    if not remotes then return end
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
end

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

-- ========== 4. ДВИЖЕНИЕ ЛОДКИ (ПЛАВНОЕ, БЕЗ ЛИШНИХ ПОДСТРОЕК) ==========
local boat = nil
local seat = nil
local root = nil
local hum = nil
local bv = nil
local dir = -1
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -0.0002
local TARGET_Y = 100
local moving = false
local moveThread = nil

local function ensureBV()
    local ch = player.Character
    if not ch then return end
    local upper = ch:FindFirstChild("UpperTorso")
    if not upper then return end
    local sx = dir * SPEED_X
    if bv and bv.Parent == upper then
        bv.Velocity = Vector3.new(sx, SPEED_Y, 0)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(sx, SPEED_Y, 0)
    end
end

local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

local function startMove()
    if moving then return end
    if not (hum and hum.Sit and hum.SeatPart == seat) then return end
    moving = true
    moveThread = task.spawn(function()
        ensureBV()
        while moving do
            if not (hum and hum.Sit and hum.SeatPart == seat) then
                stopMove()
                break
            end
            if not root or not root.Parent then
                stopMove()
                break
            end
            -- Коррекция высоты лодки (только при сильном уходе)
            local p = root.Position
            if math.abs(p.Y - TARGET_Y) > 15 then
                root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
            end
            -- Смена направления
            if p.X <= X_MIN and dir == -1 then
                dir = 1
                ensureBV()
            elseif p.X >= X_MAX and dir == 1 then
                dir = -1
                ensureBV()
            end
            task.wait(0.1)
        end
    end)
end

-- ========== 5. МАГНИТ (ВОЗВРАТ В ЛОДКУ) ==========
local magnetEnabled = true
local magnetBodyPos = nil
local magnetActive = false

local function stopMagnet()
    magnetActive = false
    if magnetBodyPos then magnetBodyPos:Destroy(); magnetBodyPos = nil end
end

local function updateMagnet(targetY)
    if not magnetActive then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not magnetBodyPos then
        magnetBodyPos = Instance.new("BodyPosition")
        magnetBodyPos.MaxForce = Vector3.new(0, math.huge, 0)
        magnetBodyPos.Parent = hrp
    end
    magnetBodyPos.Position = Vector3.new(hrp.Position.X, targetY, hrp.Position.Z)
end

local function fastMagnet()
    if not magnetEnabled then return end
    if not seat then return end
    local char = player.Character
    if not char then return end
    local h = char:FindFirstChild("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    if h.Sit and h.SeatPart == seat then
        stopMagnet()
        return
    end
    if not magnetActive then magnetActive = true end
    local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
    updateMagnet(targetPos.Y)
    local dist = (r.Position - targetPos).Magnitude
    if dist > 0.5 then
        local step = math.min(300 * 0.05, dist)
        local newPos = r.Position + (targetPos - r.Position).Unit * step
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        r.CFrame = CFrame.new(newPos)
    else
        r.CFrame = CFrame.new(targetPos)
    end
end

-- ========== 6. ДЕТЕКТОР ФРУКТОВ ==========
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

-- ========== 7. АНТИ-IDLE ==========
task.spawn(function()
    local cam = workspace.CurrentCamera
    local orig = cam.CFrame
    local vim = game:GetService("VirtualInputManager")
    while true do
        task.wait(600)
        cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(1), 0)
        task.wait(0.5)
        cam.CFrame = orig
        if vim then
            vim:SendKeyEvent(true, "W", false, game)
            task.wait(0.1)
            vim:SendKeyEvent(false, "W", false, game)
        end
    end
end)

-- ========== 8. ОСТРОВ ==========
local islandActive = false
local pendingReturn = false
local waitingForDespawn = false
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then return obj end
    end
    return nil
end
local PLAYER_EGG_RANK = {
    ["Willow_hspt2015"] = 1,
    ["MichaelJohnson84562"] = 2,
    ["GigaGrimShade74"] = 3,
}
local myRank = PLAYER_EGG_RANK[playerName]
local function pressE()
    local vim = game:GetService("VirtualInputManager")
    if vim then
        vim:SendKeyEvent(true, "E", false, game)
        task.wait(1.5)
        vim:SendKeyEvent(false, "E", false, game)
    end
end
local function getEggsSortedByDistance()
    local island = findIsland()
    if not island then return {} end
    local core = island:FindFirstChild("Core")
    if not core then return {} end
    local spawned = core:FindFirstChild("SpawnedDragonEggs")
    if not spawned then return {} end
    local char = player.Character
    if not char then return {} end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local eggs = {}
    for _, child in ipairs(spawned:GetChildren()) do
        if child:IsA("Model") and child.Name == "DragonEgg" then
            local eggPart = child:FindFirstChild("EggCrust") or child:FindFirstChildWhichIsA("BasePart")
            if eggPart and eggPart.Parent then
                table.insert(eggs, {part = eggPart, model = child, dist = (hrp.Position - eggPart.Position).Magnitude})
            end
        end
    end
    table.sort(eggs, function(a,b) return a.dist < b.dist end)
    return eggs
end
task.spawn(function()
    while true do
        task.wait(1)
        local island = findIsland()
        if island and not islandActive and not waitingForDespawn then
            islandActive = true
            magnetEnabled = false
            stopMove()
            if hum then hum.Sit = false end
            task.wait(0.5)
            local liftTarget = island:GetPivot().Position + Vector3.new(0, 330, 0)
            moveStep(liftTarget, 200, true)
            local eggTargetPos, myEggModel, startTime = nil, nil, os.clock()
            while true do
                if os.clock()-startTime >= 600 then break end
                if not findIsland() then break end
                local eggs = getEggsSortedByDistance()
                if #eggs >= myRank and myRank then
                    local cand = eggs[myRank]
                    if cand and cand.part and cand.part.Parent then
                        myEggModel = cand.model
                        eggTargetPos = cand.part.Position + Vector3.new(0,2,0)
                        break
                    end
                end
                task.wait(0.5)
            end
            if eggTargetPos and myEggModel and myEggModel.Parent then
                moveStep(eggTargetPos, 200, true)
                pressE()
            end
            islandActive = false
            pendingReturn = true
            waitingForDespawn = true
        end
        if waitingForDespawn and not findIsland() then waitingForDespawn = false end
    end
end)

-- ========== 9. ОСНОВНОЙ ЦИКЛ ==========
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
    local ev = rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("RE/OnEventServiceActivity")
    if ev then pcall(function() ev:FireServer() end) end
end

task.spawn(function()
    while true do
        task.wait(0.05)
        if islandActive then continue end
        if pendingReturn then
            pendingReturn = false
            print("[ГЛАВНЫЙ] Возврат с острова")
            boat = nil; seat = nil; root = nil
        end
        if not boat or not boat.Parent then
            boat = findMyBoat()
            if not boat then
                buyBoat()
                for i=1,20 do
                    boat = findMyBoat()
                    if boat then break end
                    task.wait(0.5)
                end
                if not boat then task.wait(5) continue end
            end
            seat = boat:FindFirstChildWhichIsA("VehicleSeat")
            root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            if not seat or not root then boat = nil continue end
            for _, p in ipairs(boat:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            local nat = boat:FindFirstChild("Script")
            if nat then nat.Disabled = true end
            print("[ЛОДКА] Найдена:", boat.Name)
        end
        local char = player.Character
        if char then hum = char:FindFirstChild("Humanoid") end
        if hum and hum.Sit and hum.SeatPart == seat then
            if not moving then startMove() end
        else
            if moving then stopMove() end
            if seat then fastMagnet() else stopMagnet() end
        end
    end
end)

-- ========== 10. ПЕРВИЧНАЯ ПОСАДКА (ИЗ ИСХОДНОГО СКРИПТА) ==========
task.spawn(function()
    while true do
        task.wait(0.5)
        if islandActive then continue end
        if boat and seat and hum and not (hum.Sit and hum.SeatPart == seat) then
            local target = seat.Position + Vector3.new(0, 2.5, 0)
            moveStep(target, 300, true)
            hum.Sit = true
            print("[ПЕРВИЧНАЯ ПОСАДКА] Выполнена")
            -- Небольшая пауза для фиксации
            task.wait(0.2)
            if not moving then startMove() end
        end
        break
    end
end)

-- Запуск детектора фруктов
task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)
    fruitTracker()
end)

print("Скрипт 10.0 запущен. Движение плавное, посадка надёжная.")
