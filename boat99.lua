-- ===== СТАБИЛЬНЫЙ СКРИПТ ВЕРСИИ 9.2 =====
-- Магнит + посадка + все защиты. Работает вечно.

local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
        task.wait(0.3)
    end
end)

-- ========== 2. ПЕРЕМЕЩЕНИЕ (goTo / safeGoTo) ==========
local BOAT_BUY_POS = Vector3.new(-16917.0, 9.1, 447.0)

local function goTo(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    local STEP = 10
    local lastDist = math.huge
    local stuckTimer = 0

    while true do
        if not hrp.Parent or not player.Character or player.Character ~= char then
            bv:Destroy()
            return false
        end

        local current = hrp.Position
        local diff = targetPos - current
        local dist = diff.Magnitude
        if dist < 1 then break end

        if dist >= lastDist - 0.1 then
            stuckTimer = stuckTimer + 0.02
            if stuckTimer > 3 then
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                stuckTimer = 0
            end
        else
            stuckTimer = 0
        end
        lastDist = dist

        local dir = diff.Unit
        local move = dir * math.min(STEP, dist)
        local newPos = current + move
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        hrp.CFrame = CFrame.new(newPos)
        task.wait(0.02)
    end

    bv:Destroy()
    return true
end

local function safeGoTo(targetPos)
    local attempts = 0
    while true do
        attempts = attempts + 1
        if attempts > 10 then return false end
        if goTo(targetPos) then return true end
        task.wait(1)
        if not player.Character then
            player.CharacterAdded:Wait()
            task.wait(1)
        end
    end
end

-- ========== 3. ПОКУПКА ЛОДКИ ==========
local function buyBoatOnly()
    local args = { "BuyBoat", "Guardian" }
    local rs = game:GetService("ReplicatedStorage")
    local commF = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
    if commF then
        pcall(function() commF:InvokeServer(unpack(args)) end)
        print("[ПОКУПКА] Лодка заказана")
    end
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

-- ========== 4. ПОСАДКА НА СИДЕНЬЕ ==========
local function forceSit(boatModel)
    local seat = boatModel:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return false end

    for _, p in ipairs(boatModel:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    local nat = boatModel:FindFirstChild("Script")
    if nat then nat.Disabled = true end

    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end

    local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
    safeGoTo(targetPos)

    hum.Sit = true
    task.wait(0.5)
    if hum.Sit and hum.SeatPart == seat then
        return seat, boatModel.PrimaryPart or seat
    end
    return nil, nil
end

-- ========== 5. МАГНИТ (притягивание к лодке) ==========
local magnetBodyPos = nil
local magnetActive = false

local function startMagnet(targetSeat)
    if not magnetActive then
        magnetActive = true
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                magnetBodyPos = Instance.new("BodyPosition")
                magnetBodyPos.MaxForce = Vector3.new(0, math.huge, 0)
                magnetBodyPos.Parent = hrp
            end
        end
    end
end

local function stopMagnet()
    magnetActive = false
    if magnetBodyPos then magnetBodyPos:Destroy(); magnetBodyPos = nil end
end

local function magneticPull(targetSeat)
    if not targetSeat or not targetSeat.Parent then
        stopMagnet()
        return
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum and hum.Sit and hum.SeatPart == targetSeat then
        stopMagnet()
        return
    end

    if not magnetActive then
        startMagnet(targetSeat)
    end

    local targetPos = targetSeat.Position + Vector3.new(0, 2.5, 0)
    if magnetBodyPos then
        magnetBodyPos.Position = Vector3.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
    end
    local dist = (hrp.Position - targetPos).Magnitude
    if dist > 0.3 then
        local dirVec = (targetPos - hrp.Position).Unit
        local step = math.min(10, dist)   -- шаг 10 студий
        local newPos = hrp.Position + dirVec * step
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        hrp.CFrame = CFrame.new(newPos)
    else
        hrp.CFrame = CFrame.new(targetPos)
    end
end

-- ========== 6. ДВИЖЕНИЕ ЛОДКИ ==========
local boat = nil
local seat = nil
local root = nil
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
local islandModeActive = false
local waitingForDespawn = false
local lastIsland = nil
local pendingReturn = false
local isBuying = false

local function startBoatMovement()
    if moving or islandModeActive then return end
    if not seat or not root then return end
    moving = true
    moveThread = task.spawn(function()
        local upper = player.Character and player.Character:FindFirstChild("UpperTorso")
        if not upper then moving = false; return end
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(dir * SPEED_X, SPEED_Y, SPEED_Z)
        root.CFrame = CFrame.new(root.Position.X, TARGET_Y, root.Position.Z)
        while moving and not islandModeActive do
            if not (player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Sit and player.Character.Humanoid.SeatPart == seat) then
                moving = false
                break
            end
            local p = root.Position
            if math.abs(p.Y - TARGET_Y) > 0.5 then
                root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
            end
            if p.X <= X_MIN and dir == -1 then
                dir = 1
                bv.Velocity = Vector3.new(dir * SPEED_X, SPEED_Y, SPEED_Z)
            elseif p.X >= X_MAX and dir == 1 then
                dir = -1
                bv.Velocity = Vector3.new(dir * SPEED_X, SPEED_Y, SPEED_Z)
            end
            task.wait(0.05)
        end
        if bv then bv:Destroy(); bv = nil end
        moving = false
    end)
end

local function stopBoatMovement()
    moving = false
    if moveThread then pcall(task.cancel, moveThread) end
    if bv then bv:Destroy(); bv = nil end
end

-- ========== 7. ПОЛНАЯ ИНИЦИАЛИЗАЦИЯ ==========
local function fullSetup()
    if isBuying then return end
    isBuying = true
    print("[ИНИТ] Покупаем лодку...")
    safeGoTo(BOAT_BUY_POS)
    task.wait(0.3)
    buyBoatOnly()
    task.wait(1)
    for i = 1, 30 do
        boat = findMyBoat()
        if boat then break end
        task.wait(1)
    end
    if boat then
        local s, r = forceSit(boat)
        if s and r then
            seat = s
            root = r
            stopMagnet()
            startBoatMovement()
            print("[ИНИТ] Готово")
        end
    else
        warn("[ИНИТ] Лодка не найдена")
    end
    isBuying = false
end

-- ========== 8. ОСТРОВ ==========
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function getEggs()
    local island = findIsland()
    if not island then return {} end
    local core = island:FindFirstChild("Core")
    if not core then return {} end
    local spawned = core:FindFirstChild("SpawnedDragonEggs")
    if not spawned then return {} end
    local eggs = {}
    for _, child in ipairs(spawned:GetChildren()) do
        if child:IsA("Model") and child.Name == "DragonEgg" and child:FindFirstChild("EggCrust") then
            table.insert(eggs, child)
        end
    end
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        table.sort(eggs, function(a,b)
            return (a:FindFirstChild("EggCrust").Position - hrp.Position).Magnitude < (b:FindFirstChild("EggCrust").Position - hrp.Position).Magnitude
        end)
    end
    return eggs
end

local function activateEgg(eggModel)
    local eggPart = eggModel:FindFirstChild("EggCrust")
    if not eggPart or not eggPart.Parent then return false end
    local targetPos = eggPart.Position + Vector3.new(0, 4.5, 0)
    if not goTo(targetPos) then return false end

    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local bodyPos = Instance.new("BodyPosition")
    bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
    bodyPos.P = 10000
    bodyPos.Parent = hrp

    local start = tick()
    while eggPart.Parent and tick() - start < 60 do
        if not player.Character or not hrp.Parent then break end
        bodyPos.Position = Vector3.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
        hrp.CFrame = CFrame.new(hrp.Position, eggPart.Position)
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, "E", false, game)
        task.wait(1.5)
        vim:SendKeyEvent(false, "E", false, game)
        task.wait(0.5)
    end
    bodyPos:Destroy()
    return true
end

-- ========== 9. ОСНОВНОЙ ЦИКЛ И WATCHDOG ==========
task.spawn(function()
    task.wait(1)
    local rs = game:GetService("ReplicatedStorage")
    local commF = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
    fullSetup()
end)

-- Поток поддержания движения и магнита
task.spawn(function()
    while true do
        task.wait(0.05)
        if islandModeActive then continue end

        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")

        if seat and root then
            if hum and hum.Sit and hum.SeatPart == seat then
                stopMagnet()
                if not moving then startBoatMovement() end
            else
                -- персонаж не в лодке – включаем магнит
                if boat and boat.Parent then
                    magneticPull(seat)
                end
            end
        end
    end
end)

-- Островной поток
task.spawn(function()
    while true do
        task.wait(1)
        local island = findIsland()
        local present = island ~= nil

        if waitingForDespawn and (not present or (lastIsland and not lastIsland.Parent)) then
            waitingForDespawn = false
            lastIsland = nil
        end

        if present and not islandModeActive and not waitingForDespawn then
            if lastIsland and island == lastIsland then continue end

            print("[ОСТРОВ] Захожу на остров")
            islandModeActive = true
            lastIsland = island
            local enterTime = tick()

            -- вылезаем из лодки
            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Sit then hum.Sit = false end
            end
            stopBoatMovement()
            stopMagnet()

            local target = island:GetPivot().Position + Vector3.new(0, 330, 0)
            if not safeGoTo(target) then
                print("[ОСТРОВ] Не смогли подняться")
                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
                continue
            end

            local eggs = {}
            while tick() - enterTime < 600 and #eggs == 0 and islandModeActive do
                if not findIsland() then break end
                eggs = getEggs()
                task.wait(1)
            end

            if islandModeActive and #eggs > 0 then
                print("[ОСТРОВ] Яиц: " .. #eggs)
                for _, egg in ipairs(eggs) do
                    if tick() - enterTime > 600 then break end
                    if not egg.Parent then continue end
                    activateEgg(egg)
                    task.wait(0.5)
                end
            end

            islandModeActive = false
            waitingForDespawn = true
            pendingReturn = true
        end
    end
end)

-- Возврат в лодку после острова
task.spawn(function()
    while true do
        task.wait(0.5)
        if pendingReturn and not islandModeActive then
            pendingReturn = false
            boat = nil; seat = nil; root = nil
            boat = findMyBoat()
            if boat then
                local s, r = forceSit(boat)
                if s and r then
                    seat = s; root = r
                    stopMagnet()
                    startBoatMovement()
                end
            else
                print("[ВОЗВРАТ] Лодки нет, полный ресет")
                fullSetup()
            end
        end
    end
end)

-- Глобальный Watchdog
task.spawn(function()
    while true do
        task.wait(10)
        if islandModeActive or isBuying then continue end
        if player.Character and (not boat or not boat.Parent or not seat or not root or (not moving and not pendingReturn)) then
            print("[WATCHDOG] Проблема, запускаю fullSetup")
            fullSetup()
        end
    end
end)

-- ========== 10. ФРУКТЫ (Discord + StoreFruit) ==========
local processedFruits = {}
local rs = game:GetService("ReplicatedStorage")
local commF = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")

local function sendDiscord(name)
    local msg = { content = player.Name .. " получил '" .. name .. "'!", username = "Инвентарь" }
    pcall(function()
        HttpService:RequestAsync({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(msg)
        })
    end)
end

local function sellFruit(tool)
    local fullName = tool.Name
    if processedFruits[fullName] then return end
    processedFruits[fullName] = true
    print("[ФРУКТ] " .. fullName)
    sendDiscord(fullName)
    local storeName = fullName:gsub(" Fruit", ""):gsub(" ", "-")
    task.wait(3)
    if tool.Parent ~= player.Character then
        tool.Parent = player.Character
        task.wait(3)
    end
    if tool.Parent == player.Character and commF then
        local args = { "StoreFruit", storeName, tool }
        pcall(function() commF:InvokeServer(unpack(args)) end)
        print("[ФРУКТ] Сдан " .. storeName)
    else
        processedFruits[fullName] = nil
    end
end

local function onToolAdded(tool)
    if tool:IsA("Tool") and tool.Name:find("Fruit") then
        task.wait(2)
        sellFruit(tool)
    end
end

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(onToolAdded)
player.CharacterAdded:Connect(function(char) char.ChildAdded:Connect(onToolAdded) end)
if player.Character then
    player.Character.ChildAdded:Connect(onToolAdded)
end

-- ========== 11. АНТИ-AFK ==========
task.spawn(function()
    local cam = workspace.CurrentCamera
    while true do
        task.wait(300)
        local cf = cam.CFrame
        cam.CFrame = cf * CFrame.Angles(0, math.rad(1), 0)
        task.wait(0.5)
        cam.CFrame = cf
    end
end)
task.spawn(function()
    local vim = game:GetService("VirtualInputManager")
    if vim then
        while true do
            task.wait(600)
            pcall(function()
                vim:SendKeyEvent(true, "W", false, game)
                task.wait(0.1)
                vim:SendKeyEvent(false, "W", false, game)
            end)
        end
    end
end)

print("Скрипт версии 9.2 запущен. Магнит, посадка, вечная стабильность.")
