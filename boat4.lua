-- ===== ИСПРАВЛЕННЫЙ СКРИПТ (без ошибок) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

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
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil

-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (определены ДО использования)

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

local function disableAllCollisions(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

local function selectMarines()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end
    local commF = remotes:FindFirstChild("CommF_")
    if not commF then return end
    commF:InvokeServer("SetTeam", "Marines")
    print("[TEAM] Marines выбрана")
    local modules = replicatedStorage:FindFirstChild("Modules")
    if modules then
        local eventService = modules:FindFirstChild("RE/OnEventServiceActivity")
        if eventService then eventService:FireServer() end
    end
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
    print("[SIT] Посадка успешна")
    return true
end

local function stopBoat()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
        print("[BOAT] Остановлена")
    end
end

local function updateBoatMovement()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid and humanoid.Sit and humanoid.SeatPart == seat and myBoat and rootPart then
        local x = rootPart.Position.X
        local target = (x < BOAT_THRESHOLD_X) and BOAT_POINT_NEAR or BOAT_POINT_FAR
        local dist = (rootPart.Position - target).Magnitude
        local duration = dist / BOAT_SPEED
        if duration > 0 then
            currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
            currentTween:Play()
            currentTween.Completed:Connect(function()
                currentTween = nil
            end)
        end
    end
end

-- ОСНОВНОЙ МОНИТОРИНГ (бесконечный цикл)
task.spawn(function()
    while not stopScript do
        task.wait(0.3)
        -- Проверка острова
        local map = workspace:FindFirstChild("Map")
        if map and map:FindFirstChild("Prehistoricisland") then
            stopScript = true
            stopBoat()
            print("[STOP] Остров найден")
            break
        end
        -- Если лодка потеряна, перезапускаем процесс
        if not myBoat or not myBoat.Parent then
            print("[MONITOR] Лодка потеряна, перезапуск...")
            stopBoat()
            moveCharacterTo(MOVE_POINT, WALK_SPEED)
            local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
            if remote then remote:InvokeServer("BuyBoat", "Guardian") end
            task.wait(3)
            myBoat = findMyBoat()
            if myBoat then
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if seat and rootPart then
                    for _, part in ipairs(myBoat:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                    myBoat.DescendantAdded:Connect(function(desc)
                        if desc:IsA("BasePart") then desc.CanCollide = false end
                    end)
                    local native = myBoat:FindFirstChild("Script")
                    if native then native.Disabled = true end
                    local char = player.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        local hum = char:FindFirstChild("Humanoid")
                        if hrp and hum then
                            sitOnSeat(seat, hrp, hum)
                        end
                    end
                end
            else
                task.wait(5)
            end
        else
            -- Проверка сидения
            local char = player.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart == seat then
                updateBoatMovement()
            else
                stopBoat()
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChild("Humanoid")
                    if hrp and hum and not (hum.Sit and hum.SeatPart == seat) then
                        print("[MONITOR] Сброс, возврат на сиденье")
                        sitOnSeat(seat, hrp, hum)
                    end
                end
            end
        end
    end
end)

-- ЗАПУСК
selectMarines()
task.wait(2)
moveCharacterTo(MOVE_POINT, WALK_SPEED)
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
if remote then remote:InvokeServer("BuyBoat", "Guardian") end
print("[MAIN] Лодка призвана, ждём...")
task.wait(3)
for i = 1, 10 do
    myBoat = findMyBoat()
    if myBoat then break end
    task.wait(1)
end
if not myBoat then error("Лодка не появилась") end
print("[MAIN] Лодка найдена:", myBoat.Name)
seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
if not seat or not rootPart then error("Нет сиденья или основной части") end
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
myBoat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then desc.CanCollide = false end
end)
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end
local char = player.Character
if char then
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if hrp and hum then
        sitOnSeat(seat, hrp, hum)
    end
end
print("Скрипт запущен, лодка остановится если вы слезете.")
