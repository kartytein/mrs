-- Минимальный скрипт движения лодки с постоянным отключением коллизий.
-- Садитесь в лодку – она поедет, при выходе остановится.
-- Коллизии персонажа и лодки отключаются непрерывно в фоне.

local player = game.Players.LocalPlayer
local X_MIN, X_MAX = -77389.3, -47968.4
local SPEED_X, TARGET_Y = 250, 100
local SPEED_Y, SPEED_Z = -2, -2

-- Отключаем коллизии персонажа постоянно
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local lower, upper = char:FindFirstChild("LowerTorso"), char:FindFirstChild("UpperTorso")
            if lower then lower.CanCollide = false end
            if upper then upper.CanCollide = false end
        end
        task.wait(0.1)
    end
end)

-- Переменные движения
local boat, seat, root = nil, nil, nil
local dir = -1
local bv = nil
local moving = false
local moveThread = nil

-- Поток отключения коллизий лодки (работает пока boat не nil)
local function startBoatCollisionLoop()
    local thread = task.spawn(function()
        while boat do
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local nat = boat:FindFirstChild("Script")
            if nat then nat.Disabled = true end
            task.wait(0.1)
        end
    end)
    return thread
end

local collisionThread = nil

local function stopBoatCollisionLoop()
    if collisionThread then task.cancel(collisionThread); collisionThread = nil end
end

local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
    stopBoatCollisionLoop()
end

local function ensureBV()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local upper = char:FindFirstChild("UpperTorso")
    if not upper then return false end
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
    return true
end

local function startMove()
    if moving or not root then return end
    moving = true
    collisionThread = startBoatCollisionLoop()
    moveThread = task.spawn(function()
        -- выравнивание высоты
        local p = root.Position
        if math.abs(p.Y - TARGET_Y) > 0.5 then
            root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
        end
        if not ensureBV() then stopMove(); return end
        while moving do
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 or not (hum.Sit and hum.SeatPart == seat) then
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
                    if not ensureBV() then stopMove(); break end
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    if not ensureBV() then stopMove(); break end
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

-- Основной цикл обнаружения лодки
while true do
    task.wait(0.2)
    local char = player.Character
    if not char then continue end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or not hum.Sit or not hum.SeatPart then
        if boat then stopMove(); boat, seat, root = nil, nil, nil end
        continue
    end

    local seatPart = hum.SeatPart
    local currentBoat = seatPart:FindFirstAncestorOfClass("Model")
    if not currentBoat or not currentBoat:FindFirstChildWhichIsA("VehicleSeat") then
        if boat then stopMove(); boat, seat, root = nil, nil, nil end
        continue
    end

    -- Новая лодка
    if currentBoat ~= boat then
        stopMove()
        boat = currentBoat
        seat = seatPart
        root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
        dir = -1 -- сброс направления
        startMove()
    elseif not moving and hum.SeatPart == seat then
        -- если движение почему-то остановилось, но всё ещё сидим – перезапуск
        startMove()
    end
end
