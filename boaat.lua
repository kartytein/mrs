-- ===== ФИНАЛЬНЫЙ СКРИПТ (ПОКУПКА ЛОДКИ, ПОСАДКА, УДЕРЖАНИЕ, КОЛЛИЗИИ ОТКЛЮЧЕНЫ) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local WALK_SPEED = 150
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)

-- ===== ВЫБОР КОМАНДЫ =====
local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then eventService:FireServer() end
end

-- ===== ПЕРЕМЕЩЕНИЕ ПЕРСОНАЖА (BODYVELOCITY) =====
local function moveTo(target, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    -- Отключаем коллизии у всех частей персонажа
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
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
    return true
end

-- ===== ПОИСК СВОЕЙ ЛОДКИ =====
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

-- ===== ПОСАДКА НА СИДЕНЬЕ =====
local function sitOnSeat(seat, hrp, humanoid)
    -- Отключаем коллизии персонажа
    local char = hrp.Parent
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local targetCF = seat.CFrame + SEAT_OFFSET
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local dir = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = dir * 150
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
end

-- ===== ОСНОВНАЯ ЛОГИКА =====
selectMarines()
task.wait(2)

-- Перемещение к точке покупки
moveTo(MOVE_POINT, WALK_SPEED)

-- Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
print("Лодка призвана, ожидание...")
task.wait(3)

-- Поиск лодки
local myBoat = nil
for i = 1, 10 do
    myBoat = findMyBoat()
    if myBoat then break end
    task.wait(1)
end
if not myBoat then error("Лодка не найдена") end
print("Лодка найдена:", myBoat.Name)

local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then error("Сиденье не найдено") end

-- Отключаем коллизии у лодки
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Посадка
local char = player.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local humanoid = char and char:FindFirstChild("Humanoid")
if not hrp or not humanoid then error("Нет HRP/Humanoid") end
sitOnSeat(seat, hrp, humanoid)

-- ===== УДЕРЖАНИЕ НА СИДЕНЬЕ (ПРОВЕРКА КАЖДЫЕ 0.2 СЕК) =====
task.spawn(function()
    while true do
        task.wait(0.2)
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
            -- Если слезли, сажаем обратно
            if char and hrp then
                sitOnSeat(seat, hrp, humanoid)
            end
        end
    end
end)

print("Скрипт запущен. Коллизии отключены, персонаж всегда будет на сиденье.")
