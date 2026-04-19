-- ===== ПРОСТОЙ РАБОЧИЙ СКРИПТ (БЕЗ ОШИБОК) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.2

local stopScript = false
local myBoat = nil
local seat = nil
local rootPart = nil
local charVelocity = nil
local isSitting = false
local needToSit = true
local currentDirection = -1
local collisionThread = nil

-- ========== ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (КАК В ЭТАЛОНЕ) ==========
local function maintainCollisions(char)
    if collisionThread then task.cancel(collisionThread) end
    collisionThread = task.spawn(function()
        while char and char.Parent and not stopScript do
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide == true then
                    part.CanCollide = false
                end
            end
            task.wait(COLLISION_INTERVAL)
        end
    end)
end

-- ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
local function selectMarines()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    local commF = remotes and remotes:FindFirstChild("CommF_")
    if commF then
        pcall(function() commF:InvokeServer("SetTeam", "Marines") end)
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end
end

local function moveTo(target, speed)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    maintainCollisions(char)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - target).Magnitude > 2 do
        if stopScript then break end
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
end

local function findBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            if boat:GetAttribute("Owner") == playerName then return boat end
            local owner = boat:FindFirstChild("Owner")
            if owner and tostring(owner.Value) == playerName then return boat end
        end
    end
    return nil
end

local function sit(boatSeat, hrp, hum)
    local char = hrp.Parent
    if not char then return end
    maintainCollisions(char)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    local target = boatSeat.CFrame + SEAT_OFFSET
    while (hrp.Position - target.Position).Magnitude > 1.5 do
        local dir = (target.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = target
    hum.Sit = true
    task.wait(0.3)
end

local function setCharVelocity(speedX)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not charVelocity then
        charVelocity = Instance.new("BodyVelocity")
        charVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        charVelocity.Parent = hrp
    end
    charVelocity.Velocity = Vector3.new(speedX, 0, 0)
end

local function stopCharVelocity()
    if charVelocity then
        charVelocity:Destroy()
        charVelocity = nil
    end
end

-- ========== МОНИТОР ПОСАДКИ ==========
task.spawn(function()
    while not stopScript do
        local char = player.Character
        if not char then
            if isSitting then
                isSitting = false
                needToSit = true
                stopCharVelocity()
            end
            player.CharacterAdded:Wait()
            char = player.Character
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            task.wait(1)
            continue
        end
        local hum = char:FindFirstChild("Humanoid")
        local sitting = hum and seat and hum.Sit and hum.SeatPart == seat
        if sitting then
            if not isSitting then
                isSitting = true
                needToSit = false
                setCharVelocity(currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED)
            end
            -- Обновляем направление по X
            if rootPart then
                local x = rootPart.Position.X
                if x <= BOAT_X_MIN and currentDirection == -1 then
                    currentDirection = 1
                    setCharVelocity(BOAT_SPEED)
                elseif x >= BOAT_X_MAX and currentDirection == 1 then
                    currentDirection = -1
                    setCharVelocity(-BOAT_SPEED)
                end
            end
        else
            if isSitting then
                isSitting = false
                needToSit = true
                stopCharVelocity()
            end
        end
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil; seat = nil; rootPart = nil
            needToSit = true
            stopCharVelocity()
        end
        task.wait(0.2)
    end
end)

-- ========== ГЛАВНЫЙ ПОТОК ==========
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        local boat = findBoat()
        if boat and not myBoat then
            myBoat = boat
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
        end

        if needToSit then
            if not myBoat or not myBoat.Parent then
                moveTo(PURCHASE_POINT, WALK_SPEED)
                local rs = game:GetService("ReplicatedStorage")
                local remotes = rs and rs:FindFirstChild("Remotes")
                local commF = remotes and remotes:FindFirstChild("CommF_")
                if commF then
                    pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end)
                end
                task.wait(3)
                for i = 1, 10 do
                    myBoat = findBoat()
                    if myBoat then break end
                    task.wait(1)
                end
                if not myBoat then
                    task.wait(5)
                    continue
                end
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if not seat or not rootPart then
                    myBoat = nil
                    continue
                end
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if hrp and hum and myBoat and seat then
                    sit(seat, hrp, hum)
                    needToSit = false
                end
            end
            task.wait(0.5)
        else
            task.wait(0.3)
        end
    end
end)

print("Скрипт запущен. Коллизии постоянно отключаются, лодка движется между X=" .. BOAT_X_MIN .. " и X=" .. BOAT_X_MAX)
