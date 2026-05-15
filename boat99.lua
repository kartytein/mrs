-- ===== ФИНАЛЬНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ + ОСТРОВ + ЯЙЦА (С ПРИВЯЗКОЙ ПО БЛИЗОСТИ) =====
-- Версия 4.0
-- Автоматическая покупка лодки, посадка, движение, магнит,
-- при появлении острова подъём, ожидание яиц, сортировка по расстоянию,
-- каждый игрок идёт к своему яйцу (1-е ближайшее, 2-е, 3-е),
-- активация E, возврат в лодку, перезапуск движения.
-- Детектор фруктов (Discord), анти-idle (камера + W).

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
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower then lower.CanCollide = false end
            if upper then upper.CanCollide = false end
        end
        task.wait(0.3)
    end
end)

-- ========== 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
-- Подъём с фиксацией Y (moveStep)
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
    if not keepY then
        -- Доводка (опускание на землю)
        local finalPos = hrp.Position
        local ray = Ray.new(finalPos + Vector3.new(0, 1, 0), Vector3.new(0, -10, 0))
        local hit, hitPos = workspace:FindPartOnRay(ray, char)
        if hit then
            hrp.CFrame = CFrame.new(finalPos.X, hitPos.Y + 2, finalPos.Z)
        end
    end
    hum.PlatformStand = oldPlatform
    return true
end

-- Горизонтальное перемещение (только X/Z)
local function moveStepHorizontal(targetPos, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    local oldPlatform = hum.PlatformStand
    hum.PlatformStand = true
    local step = 0.05
    local stepSize = speed * step
    local targetXZ = Vector3.new(targetPos.X, 0, targetPos.Z)
    while true do
        local currentXZ = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
        local distXZ = (targetXZ - currentXZ).Magnitude
        if distXZ < 0.5 then break end
        local dirXZ = (targetXZ - currentXZ).Unit
        local moveDist = math.min(stepSize, distXZ)
        local newPos = hrp.Position + Vector3.new(dirXZ.X * moveDist, 0, dirXZ.Z * moveDist)
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
    end
    hum.PlatformStand = oldPlatform
    return true
end

-- Перемещение через BodyPosition (фиксированное время)
local function moveWithBodyPosition(targetPos, duration)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.Parent = hrp
    bp.Position = targetPos
    task.wait(duration)
    bp:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
end

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

local function sitOnSeat(seat, hrp, hum)
    local target = seat.Position + Vector3.new(0, 2.5, 0)
    moveStep(target, 300, true)
    hum.Sit = true
    task.wait(0.3)
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

-- Анти-idle (камера + клавиша W)
task.spawn(function()
    local cam = workspace.CurrentCamera
    local orig = cam.CFrame
    local vim = game:GetService("VirtualInputManager")
    while true do
        task.wait(600)
        -- движение камеры
        cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(1), 0)
        task.wait(0.5)
        cam.CFrame = orig
        -- нажатие W (если доступно)
        if vim then
            vim:SendKeyEvent(true, "W", false, game)
            task.wait(0.1)
            vim:SendKeyEvent(false, "W", false, game)
        end
    end
end)

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

-- ========== 4. БЫСТРЫЙ МАГНИТ (ДЛЯ ПОСАДКИ) ==========
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
    end
end

-- ========== 5. МОНИТОР ОСТРОВА (С ОЖИДАНИЕМ ИСЧЕЗНОВЕНИЯ) ==========
local islandModeActive = false      -- мы в режиме острова
local waitingForDespawn = false     -- ждём, пока остров исчезнет после выхода
local pendingReturn = false
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then return obj end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(1)
        local island = findIsland()
        local present = island ~= nil

        -- Если мы ждём исчезновения и острова больше нет, сбрасываем флаг
        if waitingForDespawn and not present then
            waitingForDespawn = false
            print("[ОСТРОВ] Остров исчез, готов к повторной активации")
        end

        -- Если остров есть, мы не в режиме и не ждём исчезновения → входим в режим
        if present and not islandModeActive and not waitingForDespawn then
            islandModeActive = true
            print("[ОСТРОВ] Обнаружен остров, входим в режим")
            stopMove()
            if hum then hum.Sit = false end
            task.wait(0.5)

            -- Шаг 1: Подъём на высоту
            local liftTarget = island:GetPivot().Position + Vector3.new(0, 330, 0)
            print("[ОСТРОВ] Подъём на высоту")
            moveStep(liftTarget, 200, true)

            -- Шаг 2: Ожидание появления яиц и выбор нужного по рангу
            local eggTargetPos = nil
            local startTime = os.clock()
            while true do
                if os.clock() - startTime >= 600 then
                    print("[ОСТРОВ] Таймер 10 минут истёк, яйца не появились")
                    break
                end
                if not findIsland() then
                    print("[ОСТРОВ] Остров исчез")
                    break
                end
                local eggsSorted = getEggsSortedByDistance()
                if #eggsSorted >= 3 and myRank then
                    local myEgg = eggsSorted[myRank]
                    if myEgg then
                        eggTargetPos = myEgg.part.Position + Vector3.new(0, 2, 0)
                        print(string.format("[ОСТРОВ] Найдено яйцо ранга %d, перемещаемся", myRank))
                        break
                    end
                end
                task.wait(0.5)
            end

            if eggTargetPos then
                print("[ОСТРОВ] Перемещение к яйцу через BodyPosition")
                moveWithBodyPosition(eggTargetPos, 3)
                pressE()
                task.wait(1)
            end

            -- Выход из режима
            islandModeActive = false
            waitingForDespawn = true   -- теперь ждём, пока остров исчезнет
            pendingReturn = true
            print("[ОСТРОВ] Режим завершён, ждём исчезновения острова для новой активации")
        end
    end
end)

-- ========== 6. ОСНОВНОЙ ЦИКЛ (ВОЗВРАТ В ЛОДКУ С ПЕРЕЗАПУСКОМ ДВИЖЕНИЯ) ==========
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
    local commF = remotes:FindFirstChild("CommF_")
    if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
    local mods = rs:FindFirstChild("Modules")
    local ev = mods and mods:FindFirstChild("RE/OnEventServiceActivity")
    if ev then pcall(function() ev:FireServer() end) end
end

task.spawn(function()
    while true do
        task.wait(0.05)
        if islandActive then continue end
        if pendingReturn then
            pendingReturn = false
            print("[ГЛАВНЫЙ] Возврат с острова, поиск лодки и посадка")
            boat = nil; seat = nil; root = nil
            boat = findMyBoat()
            if boat then
                seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if seat and root then
                    for _, p in ipairs(boat:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
                    local nat = boat:FindFirstChild("Script")
                    if nat then nat.Disabled = true end
                    local char = player.Character
                    if char then
                        local h = char:FindFirstChild("Humanoid")
                        local r = char:FindFirstChild("HumanoidRootPart")
                        if h and r then
                            local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
                            moveStep(targetPos, 300, true)
                            h.Sit = true
                            print("[ГЛАВНЫЙ] Посадка выполнена")
                            -- Перезапуск движения лодки
                            stopMove()
                            moving = false
                            startMove()
                        end
                    end
                else
                    print("[ГЛАВНЫЙ] Лодка найдена, но нет сиденья/части")
                end
            else
                print("[ГЛАВНЫЙ] Лодка не найдена, будет куплена позже")
            end
        end
        if not boat or not boat.Parent then
            boat = findMyBoat()
            if not boat then
                buyBoat()
                for i = 1, 20 do
                    boat = findMyBoat()
                    if boat then break end
                    task.wait(0.5)
                end
                if not boat then
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
        local char = player.Character
        if char then
            hum = char:FindFirstChild("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        end
        if hum and hum.Sit and hum.SeatPart == seat then
            if not moving then
                startMove()
            end
        else
            if moving then stopMove() end
            fastMagnet()
        end
    end
end)

-- Первичная посадка
task.spawn(function()
    while true do
        task.wait(0.5)
        if islandActive then continue end
        if boat and seat and hum and not (hum.Sit and hum.SeatPart == seat) then
            local target = seat.Position + Vector3.new(0, 2.5, 0)
            moveStep(target, 300, true)
            hum.Sit = true
            print("[ПЕРВИЧНАЯ ПОСАДКА] Выполнена")
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

print("Финальный скрипт запущен. Остров обрабатывается, привязка яиц по близости к игрокам.")
