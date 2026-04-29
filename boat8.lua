-- ===== МИНИМАЛЬНЫЙ СКРИПТ ДВИЖЕНИЯ ЛОДКИ (ПО ДЕЛЬТАМ ИЗ ЭТАЛОНА) =====
local player = game.Players.LocalPlayer

-- Постоянное отключение коллизий
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
        task.wait(0.3)
    end
end)

-- Функция посадки (BodyVelocity)
local function sitOnSeat(seat, hrp, humanoid)
    local targetCF = seat.CFrame + Vector3.new(0, 2.5, 0)
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
end

-- Поиск своей лодки
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, boat in ipairs(boats:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local owner = boat:GetAttribute("Owner")
            if owner == player.Name then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and tostring(ownerObj.Value) == player.Name then return boat end
        end
    end
    return nil
end

-- Глобальные переменные
local myBoat = nil
local seat = nil
local rootPart = nil
local humanoid = nil
local hrp = nil
local boatMoving = false
local boatThread = nil
local currentDirection = -1
local STEP_INTERVAL = 0.2
local X_MIN = -77389.3
local X_MAX = -47968.4
local Y_FIXED = 100
local deltaHistory = {-11.5, -6.3, -7.3, -9.4, -7.3, -9.4, -9.4, -8.3, -9.4, -10.4, -9.4, -7.3, -6.3, -5.2, -9.4, -8.3}
local deltaIndex = 1
local function getNextDelta()
    local d = deltaHistory[deltaIndex]
    deltaIndex = deltaIndex % #deltaHistory + 1
    return d
end

local function stopBoatMoving()
    boatMoving = false
end

local function startBoatMoving()
    if boatThread then return end
    boatMoving = true
    boatThread = task.spawn(function()
        while boatMoving do
            -- Критическая проверка: если персонаж не сидит, останавливаем
            if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
                stopBoatMoving()
                print("[ЛОДКА] Остановлена (персонаж не сидит)")
                break
            end
            local delta = currentDirection * getNextDelta()
            local newX = rootPart.Position.X + delta
            if newX <= X_MIN then
                newX = X_MIN
                currentDirection = 1
            elseif newX >= X_MAX then
                newX = X_MAX
                currentDirection = -1
            end
            rootPart.CFrame = CFrame.new(newX, Y_FIXED, rootPart.Position.Z)
            task.wait(STEP_INTERVAL)
        end
        boatThread = nil
    end)
end

-- Основной поток: покупка, посадка, запуск
task.spawn(function()
    -- Выбор команды Marines
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local modules = rs:FindFirstChild("Modules")
        local event = modules and modules:FindFirstChild("RE/OnEventServiceActivity")
        if event then pcall(function() event:FireServer() end) end
    end

    -- Покупка лодки
    buyBoat()
    print("Ожидание лодки...")
    task.wait(3)
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then error("Лодка не найдена") end
    print("Лодка найдена:", myBoat.Name)

    seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then error("Нет сиденья/части") end

    -- Отключаем коллизии лодки
    for _, part in ipairs(myBoat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local native = myBoat:FindFirstChild("Script")
    if native then native.Disabled = true end

    -- Посадка
    local char = player.Character or player.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    sitOnSeat(seat, hrp, humanoid)
    print("Посадка выполнена")

    -- Запуск движения
    startBoatMoving()
end)

print("Скрипт запущен. Лодка движется как в эталонном логе, останавливается при вылезании.")
