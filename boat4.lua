-- ===== ПРОСТОЙ РАБОЧИЙ СКРИПТ (ОДИН ЦИКЛ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_THRESHOLD_X = -77389
local BOAT_POINT_FAR = Vector3.new(-77389.3, 22.8, 32606.2)
local BOAT_POINT_NEAR = Vector3.new(-47968.4, 22.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.3

local stopScript = false

-- Вспомогательные функции (коллизии, перемещение, посадка)
local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

local function maintainCollisions(char)
    task.spawn(function()
        while char and char.Parent and not stopScript do
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower and lower:IsA("BasePart") and lower.CanCollide == true then
                lower.CanCollide = false
            end
            if upper and upper:IsA("BasePart") and upper.CanCollide == true then
                upper.CanCollide = false
            end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
    print("[TEAM] Marines выбрана")
    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then eventService:FireServer() end
end

local function moveCharacterTo(targetPos, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    disableAllCollisions(char)
    maintainCollisions(char)

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    while (hrp.Position - targetPos).Magnitude > 2 do
        if stopScript then break end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    print("[MOVE] Перемещение завершено")
    return true
end

local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local ownerAttr = boat:GetAttribute("Owner")
            if ownerAttr == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and (ownerObj:IsA("StringValue") or ownerObj:IsA("ObjectValue")) then
                if tostring(ownerObj.Value) == playerName then return boat end
            end
        end
    end
    return nil
end

local function sitOnSeat(boatSeat, hrp, humanoid)
    local char = hrp.Parent
    if not char then return false end
    disableAllCollisions(char)
    maintainCollisions(char)

    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local targetPos = targetCF.Position

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    while (hrp.Position - targetPos).Magnitude > 1.5 do
        if stopScript then break end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    return true
end

-- Основной поток
task.spawn(function()
    selectMarines()
    task.wait(2)

    -- Перемещение к точке покупки
    print("[MAIN] Перемещение к точке покупки")
    moveCharacterTo(MOVE_POINT, WALK_SPEED)
    if stopScript then return end

    -- Призыв лодки
    print("[MAIN] Призыв лодки")
    local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
    remote:InvokeServer("BuyBoat", "Guardian")
    print("[MAIN] Ожидание появления лодки...")
    local myBoat = nil
    for i = 1, 15 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
        if stopScript then return end
    end
    if not myBoat then error("Лодка не появилась") end
    print("[MAIN] Лодка найдена:", myBoat.Name)

    local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then error("Нет сиденья") end
    local rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then error("Нет основной части") end

    -- Отключаем коллизии у лодки
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    myBoat.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end)

    -- Отключаем коллизии у персонажа
    local char = player.Character
    if char then
        disableAllCollisions(char)
        maintainCollisions(char)
    end

    -- Отключаем родной скрипт лодки
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Посадка
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then error("Нет HRP/Humanoid") end
    print("[MAIN] Посадка")
    sitOnSeat(seat, hrp, humanoid)

    -- Основной цикл управления лодкой и возврата на сиденье
    local boatVelocity = nil
    while not stopScript do
        -- Проверяем, сидит ли персонаж на этом сиденье
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = humanoid and humanoid.Sit and humanoid.SeatPart == seat

        if sitting then
            -- Если лодка не движется, создаём BodyVelocity
            if not boatVelocity and rootPart and rootPart.Parent then
                boatVelocity = Instance.new("BodyVelocity")
                boatVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                boatVelocity.Parent = rootPart
                print("[BOAT] Движение активировано")
            end
            -- Обновляем направление
            if boatVelocity then
                local x = rootPart.Position.X
                local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
                local direction = (target - rootPart.Position).Unit
                boatVelocity.Velocity = direction * BOAT_SPEED
            end
        else
            -- Останавливаем лодку
            if boatVelocity then
                boatVelocity:Destroy()
                boatVelocity = nil
                print("[BOAT] Лодка остановлена (не сидит)")
            end
            -- Если персонаж существует, но не сидит, пытаемся снова сесть
            if char and humanoid then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    print("[BOAT] Попытка возврата на сиденье")
                    sitOnSeat(seat, hrp, humanoid)
                end
            elseif not char then
                -- Персонаж умер, ждём появления нового
                print("[BOAT] Персонаж умер, ожидание...")
                player.CharacterAdded:Wait()
                char = player.Character
                if char then
                    hrp = char:FindFirstChild("HumanoidRootPart")
                    humanoid = char:FindFirstChild("Humanoid")
                    if hrp and humanoid then
                        disableAllCollisions(char)
                        maintainCollisions(char)
                        sitOnSeat(seat, hrp, humanoid)
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)
