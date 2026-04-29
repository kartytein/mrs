-- ЧАСТЬ 2: Покупка лодки и посадка (без движения лодки)
local player = game.Players.LocalPlayer
local playerName = player.Name
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local STUCK_THRESHOLD = 30

local myBoat = nil
local seat = nil
local rootPart = nil

-- Пошаговое перемещение (копируем из основного скрипта)
local function moveStepByStep(targetPos, speed, keepY)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end
    local oldPlatform = humanoid.PlatformStand
    humanoid.PlatformStand = true
    local step = 0.05
    local lastDist = math.huge
    local stuck = 0
    while true do
        local current = hrp.Position
        local distance = (targetPos - current).Magnitude
        if distance < 0.5 then break end
        local direction = (targetPos - current).Unit
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        if keepY then
            newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
        end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(step)
        if math.abs(distance - lastDist) < 0.01 then
            stuck = stuck + 1
            if stuck > 50 then break
        else
            stuck = 0
        end
        lastDist = distance
    end
    hrp.CFrame = CFrame.new(targetPos)
    humanoid.PlatformStand = oldPlatform
    return true
end

-- Поиск лодки
local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then return boat end
        end
    end
    return nil
end

-- Покупка
local function buyBoatAndMove()
    print("[PART2] Перемещение к точке покупки...")
    moveStepByStep(PURCHASE_POINT, WALK_SPEED, true)
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
    end
    task.wait(3)
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then return false end
    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then
        myBoat = nil
        return false
    end
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end
    print("[PART2] Лодка готова: " .. myBoat.Name)
    return true
end

-- Посадка
local function forceSit()
    if not myBoat or not myBoat.Parent then
        if not buyBoatAndMove() then return end
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Sit and humanoid.SeatPart == seat then return end

    local old = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if old then old:Destroy() end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local lastDist = math.huge
    local stuck = 0
    while true do
        local targetCF = seat.CFrame + SEAT_OFFSET
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if dist < 1.5 then
            bv:Destroy()
            hrp.CFrame = targetCF
            humanoid.Sit = true
            break
        end
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        if math.abs(dist - lastDist) < 0.05 then
            stuck = stuck + 1
            if stuck > STUCK_THRESHOLD then
                bv:Destroy()
                hrp.CFrame = targetCF
                humanoid.Sit = true
                break
            end
        else
            stuck = 0
        end
        lastDist = dist
        task.wait(0.1)
    end
    bv:Destroy()
end

-- Запуск
forceSit()
print("[PART2] Посадка выполнена (если ошибок нет)")
