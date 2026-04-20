-- ===== МАКСИМАЛЬНО ПРОСТОЙ И НАДЁЖНЫЙ СКРИПТ =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local PURCHASE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_X_MIN = -77389.3
local BOAT_X_MAX = -47968.4
local BOAT_SPEED = 250
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)

local stopScript = false
local myBoat = nil
local seat = nil
local boatRoot = nil
local currentDirection = -1

-- Вспомогательные функции
local function disableCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

local function selectMarines()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
    end
end

local function moveTo(target, speed)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    disableCollisions(char)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
end

local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            if boat:GetAttribute("Owner") == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then return boat end
        end
    end
    return nil
end

local function sitOnSeat(boatSeat, hrp, hum)
    local char = hrp.Parent
    if not char then return end
    disableCollisions(char)
    local targetCF = boatSeat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    hum.Sit = true
    task.wait(0.3)
end

local function ensureBoatVelocity(speedX)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        if bv.Velocity.X ~= speedX then
            bv.Velocity = Vector3.new(speedX, 0, 0)
        end
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
    end
end

local function stopBoat()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy() end
    end
end

-- Главный цикл
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        -- 1. Обновляем ссылки на лодку
        if not myBoat or not myBoat.Parent then
            myBoat = findMyBoat()
            if myBoat then
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                boatRoot = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if seat and boatRoot then
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                else
                    myBoat = nil
                end
            end
        end

        -- 2. Если лодки нет, покупаем
        if not myBoat or not myBoat.Parent then
            print("Покупка лодки...")
            moveTo(PURCHASE_POINT, WALK_SPEED)
            local rs = game:GetService("ReplicatedStorage")
            local remotes = rs and rs:FindFirstChild("Remotes")
            local commF = remotes and remotes:FindFirstChild("CommF_")
            if commF then pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end) end
            task.wait(3)
            for i = 1, 10 do
                myBoat = findMyBoat()
                if myBoat then break end
                task.wait(1)
            end
            if not myBoat then
                task.wait(5)
                continue
            end
            seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
            boatRoot = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
            if not seat or not boatRoot then
                myBoat = nil
                continue
            end
            for _, part in ipairs(myBoat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local native = myBoat:FindFirstChild("Script")
            if native then native.Disabled = true end
        end

        -- 3. Проверяем, сидит ли персонаж
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local sitting = hum and seat and hum.Sit and hum.SeatPart == seat

        if not sitting then
            -- Останавливаем движение лодки
            stopBoat()
            -- Если персонаж существует, пытаемся сесть
            if char and hum and seat then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    print("Посадка...")
                    sitOnSeat(seat, hrp, hum)
                end
            elseif not char then
                -- Персонаж мёртв, ждём
                print("Ожидание появления персонажа...")
                player.CharacterAdded:Wait()
            end
        else
            -- Сидит: обеспечиваем движение лодки
            -- Обновляем направление по X лодки
            if boatRoot then
                local x = boatRoot.Position.X
                if x <= BOAT_X_MIN and currentDirection == -1 then
                    currentDirection = 1
                elseif x >= BOAT_X_MAX and currentDirection == 1 then
                    currentDirection = -1
                end
            end
            local requiredSpeed = (currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED)
            ensureBoatVelocity(requiredSpeed)
        end

        task.wait(0.2)
    end
end)

print("Скрипт запущен. Лодка будет двигаться, а при любом сбое — пересаживать персонажа.")
