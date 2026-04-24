-- ===== ПЕРЕМЕЩЕНИЕ К ОСТРОВУ С ДИАГНОСТИКОЙ BODYVELOCITY =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local speed = 300
local targetPos = nil

-- Поиск острова
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local island = findIsland()
if not island then
    warn("Остров не найден")
    return
end
targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)
print("[DIAG] Цель: " .. tostring(targetPos))

-- Постоянное отключение коллизий
task.spawn(function()
    while char and char.Parent do
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        task.wait(0.2)
    end
end)

humanoid.PlatformStand = true

-- Фиксация высоты (BodyPosition постоянно пересоздаётся)
local heightPos = nil
task.spawn(function()
    while char and char.Parent do
        if heightPos then heightPos:Destroy() end
        heightPos = Instance.new("BodyPosition")
        heightPos.MaxForce = Vector3.new(0, math.huge, 0)
        heightPos.Parent = hrp
        heightPos.Position = Vector3.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
        task.wait(0.05)
    end
end)

-- Основной поток пересоздания BodyVelocity (каждые 0.02 секунды)
local bv = nil
local moving = true
task.spawn(function()
    while moving do
        if bv then
            bv:Destroy()
            print("[DIAG] BodyVelocity уничтожен")
        end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        local dir = (targetPos - hrp.Position).Unit
        bv.Velocity = dir * speed
        print("[DIAG] BodyVelocity создан, скорость " .. tostring(bv.Velocity))
        task.wait(0.02)
    end
end)

-- Мониторинг расстояния
while (hrp.Position - targetPos).Magnitude > 3 do
    task.wait(0.1)
    print(string.format("[DIAG] Расстояние: %.2f", (hrp.Position - targetPos).Magnitude))
end

moving = false
if bv then bv:Destroy() end
if heightPos then heightPos:Destroy() end
humanoid.PlatformStand = false
print("[SUCCESS] Прибыли на остров")
