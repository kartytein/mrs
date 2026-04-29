-- ===== МИНИМАЛЬНЫЙ РАБОЧИЙ СКРИПТ (ТЕСТ) =====
local player = game.Players.LocalPlayer

-- Постоянное отключение коллизий (без лишнего)
task.spawn(function()
    while true do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            local lower = char:FindFirstChild("LowerTorso")
            local upper = char:FindFirstChild("UpperTorso")
            if lower then lower.CanCollide = false end
            if upper then upper.CanCollide = false end
        end
        task.wait(0.3)
    end
end)

-- Функция покупки лодки (без перемещения к точке)
local function buyBoat()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then
            pcall(function() commF:InvokeServer("BuyBoat", "Guardian") end)
        end
    end
end

-- Функция посадки на сиденье (BodyVelocity)
local function sitOnSeat(boatSeat, hrp, humanoid)
    local targetCF = boatSeat.CFrame + Vector3.new(0, 2.5, 0)
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

-- Поиск своей лодки (по Owner)
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

-- Основной поток
task.spawn(function()
    -- 1. Выбор команды Marines
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then
            pcall(function() commF:InvokeServer("SetTeam", "Marines") end)
        end
    end

    -- 2. Покупка лодки (без перемещения, просто вызов)
    buyBoat()
    print("Ожидание появления лодки...")
    task.wait(3)

    -- 3. Поиск лодки
    local myBoat = nil
    for i = 1, 10 do
        myBoat = findMyBoat()
        if myBoat then break end
        task.wait(1)
    end
    if not myBoat then
        warn("Лодка не найдена")
        return
    end
    print("Лодка найдена:", myBoat.Name)

    local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
    local rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
    if not seat or not rootPart then
        warn("Нет сиденья или основной части")
        return
    end

    -- 4. Посадка
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local humanoid = char:WaitForChild("Humanoid")
    sitOnSeat(seat, hrp, humanoid)
    print("Посадка выполнена")

    -- 5. Движение лодки (ступенчатое, по X, высота 100)
    local currentDirection = -1
    local X_MIN = -77389.3
    local X_MAX = -47968.4
    local Y_FIXED = 100
    local SPEED = 420
    while true do
        local step = 0.05
        local delta = currentDirection * SPEED * step
        local newX = rootPart.Position.X + delta
        if newX <= X_MIN then
            newX = X_MIN
            currentDirection = 1
        elseif newX >= X_MAX then
            newX = X_MAX
            currentDirection = -1
        end
        rootPart.CFrame = CFrame.new(newX, Y_FIXED, rootPart.Position.Z)
        task.wait(step)
    end
end)

print("Минимальный скрипт запущен. Лодка должна поехать.")
