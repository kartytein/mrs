-- ===== ПОЛНЫЙ СКРИПТ (ВЕРСИЯ 9.4) =====
-- goTo для перемещений. Покупка, посадка, движение и магнит – как в 8.3, но улучшена надёжность посадки.
-- Гарантируется: персонаж либо в лодке и она движется, либо запускается восстановление.

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

-- ========== 1. НОВЫЙ ДВИЖОК ПЕРЕМЕЩЕНИЯ (goTo / safeGoTo) ==========
local STEP = 10
local DELAY = 0.02

local function goTo(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end

    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp

    local lastDist = (hrp.Position - targetPos).Magnitude
    local stuckTimer = 0

    while true do
        local currentPos = hrp.Position
        local dist = (currentPos - targetPos).Magnitude
        if dist < 1 then break end

        local dir = (targetPos - currentPos).Unit
        local moveDist = math.min(STEP, dist)
        local newPos = currentPos + dir * moveDist
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)

        hrp.CFrame = CFrame.new(newPos)

        if dist >= lastDist - 0.1 then
            stuckTimer = stuckTimer + DELAY
            if stuckTimer >= 3 then
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                stuckTimer = 0
            end
        else
            stuckTimer = 0
            lastDist = dist
        end

        task.wait(DELAY)
    end

    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = false
    if bv then bv:Destroy() end
    return true
end

local function safeGoTo(targetPos)
    for attempt = 1, 10 do
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(1)
            continue
        end
        local success = pcall(goTo, targetPos)
        if success then
            return true
        end
        task.wait(2)
    end
    warn("[SafeGoTo] Не удалось достичь цели после 10 попыток")
    return false
end

-- ========== 2. ПОКУПКА, ПОСАДКА, ДВИЖЕНИЕ ЛОДКИ ==========
local BOAT_BUY_POS = Vector3.new(-16917.0, 9.1, 447.0)
local BUY_DISTANCE_THRESHOLD = 5

local function buyBoatOnly()
    local args = { "BuyBoat", "Guardian" }
    local rs = game:GetService("ReplicatedStorage")
    local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
    if commF then
        pcall(function() commF:InvokeServer(unpack(args)) end)
        print("[ПОКУПКА] Лодка заказана")
    else
        warn("[ПОКУПКА] CommF_ не найден")
    end
end

local function buyBoatAfterMove()
    for attempt = 1, 3 do
        safeGoTo(BOAT_BUY_POS)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - BOAT_BUY_POS).Magnitude <= BUY_DISTANCE_THRESHOLD then
            task.wait(0.5)
            buyBoatOnly()
            return true
        end
        warn(string.format("[ПОКУПКА] Не достигли точки покупки (попытка %d), расстояние: %.1f", attempt, hrp and (hrp.Position - BOAT_BUY_POS).Magnitude or -1))
    end
    warn("[ПОКУПКА] Не удалось добраться до точки покупки, лодка не куплена")
    return false
end

-- Улучшенная посадка: возвращает true только если персонаж точно сидит на нужном сиденье
local function forceSitOnSeat(targetSeat, maxAttempts)
    maxAttempts = maxAttempts or 5
    for attempt = 1, maxAttempts do
        local char = player.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return false end

        -- Подлетаем прямо над сиденьем
        local targetPos = targetSeat.Position + Vector3.new(0, 2.5, 0)
        safeGoTo(targetPos)

        hum.Sit = true
        task.wait(0.7)
        if hum.Sit and hum.SeatPart == targetSeat then
            print("[ПОСАДКА] Успешно сел на целевое сиденье")
            return true
        else
            print("[ПОСАДКА] Попытка " .. attempt .. ": сел не на то сиденье, выпрыгиваем")
            hum.Sit = false
            pcall(function() hum.Jump:Fire() end)
            task.wait(0.5)
        end
    end
    warn("[ПОСАДКА] Не удалось сесть на целевое сиденье после " .. maxAttempts .. " попыток")
    return false
end

local function resetCharacter()
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 else char:BreakJoints() end
    end
    player.CharacterAdded:Wait()
    task.wait(1)
    print("[РЕСЕТ] Персонаж возрождён")
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

-- ========== 3. ДВИЖЕНИЕ ЛОДКИ ==========
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

-- ========== 4. МАГНИТ + АКТИВНАЯ ПОСАДКА (улучшено) ==========
local magnetBodyPos = nil
local magnetBodyPosActive = false

local function updateMagnetBodyPos(targetY)
    if not magnetBodyPosActive then return end
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

local function stopMagnetBodyPos()
    magnetBodyPosActive = false
    if magnetBodyPos then magnetBodyPos:Destroy(); magnetBodyPos = nil end
end

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
    end
    local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
    updateMagnetBodyPos(targetPos.Y)
    local dist = (r.Position - targetPos).Magnitude
    if dist > 0.3 then
        local dirVec = (targetPos - r.Position).Unit
        local step = math.min(300 * 0.02, dist)
        local newPos = r.Position + dirVec * step
        newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        r.CFrame = CFrame.new(newPos)
    else
        r.CFrame = CFrame.new(targetPos)
        -- Рядом с сиденьем – принудительно пробуем сесть
        if not isReseating then
            isReseating = true
            if forceSitOnSeat(seat, 1) then
                print("[МАГНИТ] Удалось сесть рядом с лодкой")
                if not moving then startMove() end
            end
            isReseating = false
        end
    end
end

-- ========== 5. ОСТРОВ (как в 8.3) ==========
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
    task.wait(0.3)
    print("[ЯЙЦО] Клавиша E зажата")
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
        if hrp and math.abs(hrp.Position.Y - targetPos.Y) > 0.5 then
            hrp.CFrame = CFrame.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
        end
        if hrp then
            local lookAt = (eggPart.Position - hrp.Position).Unit
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookAt)
        end
    end
    task.wait(0.3)

    while eggModel and eggModel.Parent do
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
            print("[ОСТРОВ] Остров исчез, готов к новой активации")
        end

        if present and not islandModeActive and not waitingForDespawn then
            print("[ОСТРОВ] Обнаружен, входим в режим")
            islandModeActive = true

            stopMove()
            stopMagnetBodyPos()

            local char = player.Character
            if char then
                local h = char:FindFirstChild("Humanoid")
                if h and h.Sit then h.Sit = false end
            end

            local target = island:GetPivot().Position + Vector3.new(0, 330, 0)
            safeGoTo(target)

            local startTime = os.clock()
            local eggsList = {}
            print("[ОСТРОВ] Ожидание появления яиц...")
            while os.clock() - startTime < 600 do
                eggsList = getAllEggs()
                if #eggsList > 0 then break end
                task.wait(1)
            end

            if #eggsList == 0 then
                print("[ОСТРОВ] Яйца не появились за 10 минут, выход")
                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
            else
                print("[ОСТРОВ] Найдено яиц:", #eggsList)
                local activatedCount = 0
                while #getAllEggs() > 0 do
                    local currentEggs = getAllEggs()
                    if #currentEggs == 0 then break end
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
                        print("[ОСТРОВ] Активация яйца", activatedCount+1)
                        activateEgg(eggToActivate.model)
                        activatedCount = activatedCount + 1
                        task.wait(1)
                    else
                        break
                    end
                end
                print("[ОСТРОВ] Все яйца активированы. Всего активировано:", activatedCount)
                islandModeActive = false
                waitingForDespawn = true
                pendingReturn = true
            end
        end
    end
end)

-- ========== 6. ОСНОВНОЙ ЦИКЛ ==========
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
    print("[ИНИЦИАЛИЗАЦИЯ] Начинаем процедуру покупки лодки...")
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
                if forceSitOnSeat(seat, 3) then
                    startMove()
                    print("[ИНИЦИАЛИЗАЦИЯ] Лодка готова, движение запущено")
                else
                    warn("[ИНИЦИАЛИЗАЦИЯ] Не удалось сесть после покупки, запускаем восстановление")
                    -- Принудительно всё заново
                    isBuying = false
                    task.spawn(initialSetup)
                end
            end
        else
            warn("[ИНИЦИАЛИЗАЦИЯ] Лодка не появилась")
        end
    end
    isBuying = false
end

task.spawn(function()
    task.wait(1)
    initialSetup()
end)

task.spawn(function()
    while true do
        task.wait(0.05)
        if islandModeActive then continue end

        -- Возврат с острова
        if pendingReturn then
            pendingReturn = false
            print("[ГЛАВНЫЙ] Возврат с острова")
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
                    stopMagnetBodyPos()
                    if forceSitOnSeat(seat, 5) then
                        stopMove()
                        moving = false
                        if bv then bv:Destroy() bv = nil end
                        startMove()
                        print("[ГЛАВНЫЙ] Посадка после острова выполнена")
                    else
                        print("[ГЛАВНЫЙ] Не удалось сесть, пробуем купить новую лодку")
                        boat = nil; seat = nil; root = nil
                        task.spawn(initialSetup)
                    end
                end
            else
                print("[ГЛАВНЫЙ] Лодка не найдена после острова, покупаем")
                task.spawn(initialSetup)
            end
        end

        -- Проверка пропажи лодки
        if boat and not boat.Parent then
            print("[ГЛАВНЫЙ] Лодка исчезла, выполняем ресет")
            boat = nil; seat = nil; root = nil
            stopMove()
            stopMagnetBodyPos()
            resetCharacter()
            if not isBuying then
                task.spawn(initialSetup)
            end
        end

        -- Если лодки нет вообще, а мы не в процессе восстановления
        if (not boat or not boat.Parent) and not isBuying and not isReseating then
            print("[ГЛАВНЫЙ] Лодка отсутствует, запускаем восстановление")
            task.spawn(initialSetup)
        end

        local char = player.Character
        if char then
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        end

        -- Если персонаж сидит и это правильное сиденье
        if hum and hum.Sit and seat and hum.SeatPart == seat then
            if not moving then
                startMove()
            end
            stopMagnetBodyPos()
        else
            -- Не сидим на нужном сиденье
            if moving then stopMove() end
            if seat and hrp then
                local distToSeat = (hrp.Position - seat.Position).Magnitude
                if distToSeat > 200 then
                    -- Далеко – летим к лодке и садимся
                    stopMagnetBodyPos()
                    if not isReseating then
                        isReseating = true
                        safeGoTo(seat.Position + Vector3.new(0, 2.5, 0))
                        forceSitOnSeat(seat, 3)
                        isReseating = false
                    end
                else
                    -- Близко – включаем магнит (он также попытается сесть при приближении)
                    fastMagnet()
                end
            else
                -- Нет сиденья, но лодка может быть – попробуем найти
                boat = findMyBoat()
                if boat then
                    seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                    root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                end
            end
        end
    end
end)

-- ========== 7. ФРУКТЫ (DISCORD + StoreFruit) ==========
local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
local processedFruits = {}

local function sendDiscordFruit(name)
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

local function sellFruit(tool)
    local fullName = tool.Name
    if processedFruits[fullName] then return end
    processedFruits[fullName] = true

    print("[ФРУКТ] Найден:", fullName)
    sendDiscordFruit(fullName)

    local storeName = fullName:gsub(" Fruit", ""):gsub(" ", "-")
    print("[ФРУКТ] Сдаём как:", storeName)

    task.wait(3)
    if tool.Parent ~= player.Character then
        tool.Parent = player.Character
        task.wait(3)
    end

    if tool.Parent ~= player.Character then
        warn("[ФРУКТ] Не удалось экипировать", fullName)
        processedFruits[fullName] = nil
        return
    end

    local args = { "StoreFruit", storeName, tool }
    local success, err = pcall(function()
        commF:InvokeServer(unpack(args))
    end)
    if success then
        print("[ФРУКТ] Сдан успешно:", storeName)
    else
        warn("[ФРУКТ] Ошибка сдачи:", err)
        processedFruits[fullName] = nil
    end
end

local function onToolAdded(tool)
    if tool:IsA("Tool") and tool.Name:find("Fruit") then
        task.wait(3)
        sellFruit(tool)
    end
end

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(onToolAdded)

local function onCharAdded(char)
    char.ChildAdded:Connect(onToolAdded)
end
if player.Character then
    onCharAdded(player.Character)
end
player.CharacterAdded:Connect(onCharAdded)

task.wait(3)
for _, tool in ipairs(backpack:GetChildren()) do
    if tool:IsA("Tool") and tool.Name:find("Fruit") then
        sellFruit(tool)
        break
    end
end
if player.Character then
    for _, tool in ipairs(player.Character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:find("Fruit") then
            sellFruit(tool)
            break
        end
    end
end

print("[ФРУКТ] Монитор запущен")

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

print("Скрипт версии 9.4 запущен. Надёжная посадка и автоматическое восстановление движения.")
