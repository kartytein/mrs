-- ===== ФИНАЛЬНЫЙ СКРИПТ (движение через BodyVelocity персонажа) =====
local player = game.Players.LocalPlayer
local playerName = player.Name

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local WALK_SPEED = 150
local BOAT_SPEED = -250   -- скорость лодки (отрицательная по X)
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)

-- Выбор команды
local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")
    commF:InvokeServer("SetTeam", "Marines")
    local modules = replicatedStorage:WaitForChild("Modules")
    local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
    if eventService then eventService:FireServer() end
end

-- Перемещение к точке (BodyVelocity)
local function moveTo(target, speed)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
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

-- Поиск своей лодки
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            if boat:GetAttribute("Owner") == playerName then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == playerName then return boat end
        end
    end
end

-- Посадка на сиденье
local function sitOnSeat(seat, hrp, humanoid)
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

-- Отключение коллизий у модели
local function disableCollisions(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

-- ===== ОСНОВНАЯ ЛОГИКА =====
selectMarines()
task.wait(2)

-- Перемещение к точке покупки
moveTo(MOVE_POINT, WALK_SPEED)

-- Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
task.wait(3)

-- Поиск лодки
local myBoat = nil
for i = 1, 10 do
    myBoat = findMyBoat()
    if myBoat then break end
    task.wait(1)
end
if not myBoat then error("Лодка не найдена") end

local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then error("Нет сиденья") end

-- Отключаем коллизии у лодки и персонажа
disableCollisions(myBoat)
local char = player.Character
if char then disableCollisions(char) end

-- Отключаем родной скрипт лодки
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Садимся
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local humanoid = char and char:FindFirstChild("Humanoid")
if not hrp or not humanoid then error("Нет HRP") end
sitOnSeat(seat, hrp, humanoid)

-- Запускаем движение лодки через BodyVelocity персонажа (как в эталоне)
local moveBV = Instance.new("BodyVelocity")
moveBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
moveBV.Parent = hrp
moveBV.Velocity = Vector3.new(BOAT_SPEED, 0, 0)

-- Постоянный мониторинг: если слезли, сажаем обратно
task.spawn(function()
    while true do
        task.wait(0.2)
        local charNow = player.Character
        local hum = charNow and charNow:FindFirstChild("Humanoid")
        if not (hum and hum.Sit and hum.SeatPart == seat) then
            -- Если лодка ещё существует, сажаем
            if myBoat and myBoat.Parent then
                local newHrp = charNow and charNow:FindFirstChild("HumanoidRootPart")
                if newHrp then
                    sitOnSeat(seat, newHrp, hum)
                end
            end
        end
    end
end)

print("Скрипт запущен. Лодка движется со скоростью " .. BOAT_SPEED .. " по оси X.")
