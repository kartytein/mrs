-- ===== ПОЛНЫЙ СКРИПТ (ВЕРСИЯ 9.18) =====
-- Исправлен вывод [STATE] – теперь читаемая строка.
-- Движок goTo без таймаутов (всегда достигает цели).
-- Максимум 10 минут на острове, после чего возврат в лодку.
-- Фрукты: надёжная отправка в Discord.

local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- ========== 0. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
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

-- ========== 1. АБСОЛЮТНО НАДЁЖНЫЙ ДВИЖОК ==========
local STEP = 10
local DELAY = 0.02

local function goTo(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyPosition") or v:IsA("BodyGyro") then
            v:Destroy()
        end
    end

    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp

    while true do
        char = player.Character
        if not char then break end
        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then break end

        local currentPos = hrp.Position
        local dist = (currentPos - targetPos).Magnitude
        if dist < 1 then break end

        if currentPos.Y < targetPos.Y - 10 then
            hrp.CFrame = CFrame.new(currentPos.X, targetPos.Y, currentPos.Z)
            currentPos = hrp.Position
        end

        local dir = (targetPos - currentPos).Unit
        local moveDist = math.min(STEP, dist)
        local newPos = currentPos + dir * moveDist
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)

        hrp.CFrame = CFrame.new(newPos)
        task.wait(DELAY)
    end

    if char and hrp and hum then
        hrp.CFrame = CFrame.new(targetPos)
        hum.PlatformStand = false
    end
    if bv then bv:Destroy() end
    return true
end

local function safeGoTo(targetPos)
    while true do
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(1)
            continue
        end
        local success = pcall(goTo, targetPos)
        if success then return true end
        warn("[SafeGoTo] Попытка провалена, повтор через 2 с")
        task.wait(2)
    end
end

-- ========== 2. СТАРЫЙ moveStep ==========
local function moveStep(targetPos, speed, keepY)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyPosition") or v:IsA("BodyGyro") then
            v:Destroy()
        end
    end
    local oldPlatform = hum.PlatformStand
    hum.PlatformStand = true
    local step = 0.02
    local stepSize = speed * step
    while true do
        local current = hrp.Position
        local dx = targetPos.X - current.X
        local dz = targetPos.Z - current.Z
        local distXZ = math.sqrt(dx*dx + dz*dz)
        if distXZ < 0.5 then break end
        local dir = (targetPos - current).Unit
        local moveDist = math.min(stepSize, (targetPos - current).Magnitude)
        local newPos = current + dir * moveDist
        if keepY then newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z) end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = oldPlatform
    return true
end

-- ========== 3. ПОКУПКА / ПОСАДКА / ЛОДКА ==========
local BOAT_BUY_POS = Vector3.new(-16917.0, 9.1, 447.0)

local function buyBoatOnly()
    local args = { "BuyBoat", "Guardian" }
    local rs = game:GetService("ReplicatedStorage")
    local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
    if commF then
        pcall(function() commF:InvokeServer(unpack(args)) end)
    end
end

local function buyBoatAfterMove()
    for attempt = 1, 3 do
        safeGoTo(BOAT_BUY_POS)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - BOAT_BUY_POS).Magnitude <= 5 then
            task.wait(0.5)
            buyBoatOnly()
            return true
        end
    end
    return false
end

local function forceSitOnSeat(targetSeat, maxAttempts)
    maxAttempts = maxAttempts or 3
    for attempt = 1, maxAttempts do
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return false end
        local targetPos = targetSeat.Position + Vector3.new(0, 2.5, 0)
        moveStep(targetPos, 300, true)
        hum.Sit = true
        task.wait(0.5)
        if hum.Sit and hum.SeatPart == targetSeat then
            return true
        else
            hum.Sit = false
            pcall(function() hum.Jump:Fire() end)
            task.wait(0.5)
        end
    end
    return false
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

-- Движение лодки
local boat, seat, root, hum, hrp, bv = nil, nil, nil, nil, nil, nil
local dir = -1
local X_MIN, X_MAX = -77389.3, -47968.4
local SPEED_X, SPEED_Y, SPEED_Z = 250, -2, -2
local TARGET_Y = 100
local moving = false
local moveThread = nil
local isReseating = false

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
        if not ch then return end
        local upper = ch:FindFirstChild("UpperTorso")
        if not upper then return end
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(0,0,0)
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
                bv.Velocity = Vector3.new(v.X, v.Y-0.0001, v.Z-0.0001)
            end
            task.wait(0.05)
        end
    end)
end

-- ========== 4. МАГНИТ ==========
local magnetBodyPos = nil
local magnetBodyPosActive = false

local function fastMagnet()
    if not seat then return end
    local char = player.Character
    if not char then return end
    local h = char:FindFirstChild("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    if h.Sit and h.SeatPart == seat then
        stopMagnetBodyPos()
        return
    end
    if not magnetBodyPosActive then
        magnetBodyPosActive = true
        if magnetBodyPos then magnetBodyPos:Destroy() end
        magnetBodyPos = Instance.new("BodyPosition")
        magnetBodyPos.MaxForce = Vector3.new(0, math.huge, 0)
        magnetBodyPos.Parent = r
    end
    local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
    magnetBodyPos.Position = Vector3.new(r.Position.X, targetPos.Y, r.Position.Z)
    local dist = (r.Position - targetPos).Magnitude
    if dist > 0.3 then
        local dirVec = (targetPos - r.Position).Unit
        local step = math.min(300*0.02, dist)
        local newPos = r.Position + dirVec * step
        r.CFrame = CFrame.new(newPos.X, targetPos.Y, newPos.Z)
    else
        r.CFrame = CFrame.new(targetPos)
    end
end

local function stopMagnetBodyPos()
    magnetBodyPosActive = false
    if magnetBodyPos then magnetBodyPos:Destroy(); magnetBodyPos = nil end
end

-- ========== 5. ОСТРОВ (с общим таймаутом 10 минут) ==========
local islandModeActive = false
local waitingForDespawn = false
local pendingReturn = false

local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function pressE()
    local vim = game:GetService("VirtualInputManager")
    if not vim then return end
    vim:SendKeyEvent(true, "E", false, game)
    task.wait(1.5)
    vim:SendKeyEvent(false, "E", false, game)
end

local function getAllEggs()
    local island = findIsland()
    if not island then return {} end
    local core = island:FindFirstChild("Core")
    if not core then return {} end
    local spawned = core:FindFirstChild("SpawnedDragonEggs")
    if not spawned then return {} end
    local eggs = {}
    for _, child in ipairs(spawned:GetChildren()) do
        if child:IsA("Model") and child.Name == "DragonEgg" then
            local eggPart = child:FindFirstChild("EggCrust") or child:FindFirstChildWhichIsA("BasePart")
            if eggPart and eggPart.Parent then
                table.insert(eggs, {part = eggPart, model = child})
            end
        end
    end
    return eggs
end

local function activateEgg(eggModel)
    if not eggModel or not eggModel.Parent then return false end
    local eggPart = eggModel:FindFirstChild("EggCrust") or eggModel:FindFirstChildWhichIsA("BasePart")
    if not eggPart then return false end
    local targetPos = eggPart.Position + Vector3.new(0, 4.5, 0)
    safeGoTo(targetPos)

    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
            local lookAt = (eggPart.Position - hrp.Position).Unit
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookAt)
        end
    end
    task.wait(0.3)

    local startTime = os.clock()
    while eggModel and eggModel.Parent do
        if os.clock() - startTime > 30 then
            warn("[ЯЙЦО] Таймаут 30 секунд, переходим дальше")
            break
        end
        pressE()
        task.wait(1)
    end
    return true
end

task.spawn(function()
    while true do
        task.wait(1)
        local island = findIsland()
        local present = island ~= nil

        if waitingForDespawn and not present then
            waitingForDespawn = false
        end

        if present and not islandModeActive and not waitingForDespawn then
            islandModeActive = true
            stopMove()
            stopMagnetBodyPos()

            local char = player.Character
            if char then
                local h = char:FindFirstChild("Humanoid")
                if h and h.Sit then h.Sit = false end
                if h then h.PlatformStand = true end
            end

            local islandStart = os.clock()
            local target = island:GetPivot().Position + Vector3.new(0, 330, 0)
            safeGoTo(target)

            local waitStart = os.clock()
            local eggsList = {}
            while os.clock() - islandStart < 600 do
                eggsList = getAllEggs()
                if #eggsList > 0 then break end
                task.wait(1)
            end

            if #eggsList == 0 then
                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
            else
                local activationStart = os.clock()
                while islandModeActive and findIsland() do
                    local currentEggs = getAllEggs()
                    if #currentEggs == 0 then break end

                    if os.clock() - activationStart > 120 then
                        print("[ОСТРОВ] 2 минуты на активацию истекли, возвращаемся")
                        break
                    end
                    if os.clock() - islandStart > 600 then
                        print("[ОСТРОВ] 10 минут на острове истекли, возвращаемся")
                        break
                    end

                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local hrp = char.HumanoidRootPart
                        for _, egg in ipairs(currentEggs) do
                            if egg.part then
                                egg.dist = (hrp.Position - egg.part.Position).Magnitude
                            else
                                egg.dist = math.huge
                            end
                        end
                        table.sort(currentEggs, function(a,b) return a.dist < b.dist end)
                    end

                    local eggToActivate = currentEggs[1]
                    if eggToActivate and eggToActivate.model and eggToActivate.model.Parent then
                        activateEgg(eggToActivate.model)
                        task.wait(1)
                    else
                        break
                    end
                end

                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
            end

            local char2 = player.Character
            if char2 then
                local h2 = char2:FindFirstChild("Humanoid")
                if h2 then h2.PlatformStand = false end
            end
        end
    end
end)

-- ========== 6. ОСНОВНОЙ ЦИКЛ + WATCHDOG (только вне острова) ==========
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
end

local isBuying = false

local function initialSetup()
    if isBuying then return end
    isBuying = true
    if buyBoatAfterMove() then
        for i = 1, 30 do
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
                local nat = boat:FindFirstChild("Script")
                if nat then nat.Disabled = true end
                forceSitOnSeat(seat, 3)
                startMove()
            end
        end
    end
    isBuying = false
end

task.spawn(function()
    task.wait(1)
    initialSetup()
end)

-- Watchdog-переменные
local lastWatchdogPos = nil
local lastWatchdogTime = os.clock()

-- Вывод состояния каждые 5 секунд (читаемая строка)
task.spawn(function()
    while true do
        task.wait(5)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local posStr = "нет"
        if hrp then
            posStr = string.format("%.0f, %.0f, %.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        end
        print(string.format(
            "[STATE] time=%d | islandActive=%s | waitDespawn=%s | pendReturn=%s | boat=%s | moving=%s | reseating=%s | pos=%s | islandPresent=%s",
            math.floor(os.clock()),
            tostring(islandModeActive),
            tostring(waitingForDespawn),
            tostring(pendingReturn),
            tostring(boat and boat.Parent),
            tostring(moving),
            tostring(isReseating),
            posStr,
            tostring(findIsland() ~= nil)
        ))
    end
end)

-- Главный цикл
task.spawn(function()
    while true do
        task.wait(0.05)
        if islandModeActive then
            local char = player.Character
            if char then
                hum = char:FindFirstChild("Humanoid")
                hrp = char:FindFirstChild("HumanoidRootPart")
            end
            continue
        end

        if pendingReturn then
            pendingReturn = false
            boat = nil; seat = nil; root = nil
            boat = findMyBoat()
            if boat then
                seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if seat and root then
                    for _, p in ipairs(boat:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                    local nat = boat:FindFirstChild("Script")
                    if nat then nat.Disabled = true end
                    local char = player.Character
                    if char then
                        local h = char:FindFirstChild("Humanoid")
                        if h and forceSitOnSeat(seat, 3) then
                            stopMove()
                            if bv then bv:Destroy() end
                            startMove()
                        end
                    end
                end
            end
        end

        if boat and not boat.Parent then
            boat = nil; seat = nil; root = nil
            stopMove()
            stopMagnetBodyPos()
            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then hum.Health = 0 end
            end
            player.CharacterAdded:Wait()
            task.wait(1)
            if not isBuying then task.spawn(initialSetup) end
        end

        if (not boat or not boat.Parent) and not isBuying then
            task.spawn(initialSetup)
        end

        local char = player.Character
        if char then
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        end

        -- Общий watchdog (вне острова)
        if hrp and not islandModeActive then
            local currentPos = hrp.Position
            if lastWatchdogPos and (currentPos - lastWatchdogPos).Magnitude < 10 then
                if os.clock() - lastWatchdogTime > 45 and not isReseating and not moving then
                    warn("[WATCHDOG] Зависание в воздухе/море! Принудительный возврат к лодке.")
                    stopMove()
                    stopMagnetBodyPos()
                    pendingReturn = true
                    lastWatchdogTime = os.clock()
                end
            else
                lastWatchdogPos = currentPos
                lastWatchdogTime = os.clock()
            end
        else
            lastWatchdogPos = nil
            lastWatchdogTime = os.clock()
        end

        if hum and hum.Sit then
            if hum.SeatPart == seat then
                if not moving then startMove() end
            else
                if not isReseating then
                    isReseating = true
                    if seat then forceSitOnSeat(seat, 3) end
                    isReseating = false
                end
                if moving then stopMove() end
            end
        else
            if moving then stopMove() end
            fastMagnet()
        end
    end
end)

-- ========== 7. ФРУКТЫ – НАДЁЖНЫЙ ИЗОЛИРОВАННЫЙ ДЕТЕКТОР ==========
task.spawn(function()
    local sentFruits = {}

    local function sendToDiscord(name)
        local msg = {
            content = playerName .. " получил '" .. name .. "'!",
            username = "Инвентарь"
        }
        local body = HttpService:JSONEncode(msg)
        pcall(function()
            HttpService:RequestAsync({
                Url = DISCORD_WEBHOOK,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
        end)
        print("[DISCORD] Отправлено: " .. name)
    end

    local function checkItem(item)
        if not item:IsA("Tool") then return end
        task.wait(0.3)
        if not item.Name or not item.Name:find("Fruit") then return end
        if sentFruits[item.Name] then return end
        sentFruits[item.Name] = true
        sendToDiscord(item.Name)
    end

    task.wait(2)
    local backpack = player:WaitForChild("Backpack")
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:find("Fruit") then
            sentFruits[item.Name] = true
        end
    end
    if player.Character then
        for _, item in ipairs(player.Character:GetChildren()) do
            if item:IsA("Tool") and item.Name:find("Fruit") then
                sentFruits[item.Name] = true
            end
        end
    end
    backpack.ChildAdded:Connect(checkItem)
    player.CharacterAdded:Connect(function(char)
        for _, existing in ipairs(char:GetChildren()) do
            checkItem(existing)
        end
        char.ChildAdded:Connect(checkItem)
    end)
    print("[ФРУКТ] Детектор запущен")
end)

-- ========== 8. АНТИ-IDLE ==========
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

print("===== СКРИПТ 9.18 ЗАПУЩЕН =====")
print("Читаемый [STATE] каждые 5 сек. Макс. 10 мин. на острове.")
