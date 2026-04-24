-- ===== УЛЬТРА-ЧАСТОЕ ПЕРЕСОЗДАНИЕ BODYVELOCITY + BODYPOSITION (ПОПЫТКА ОБОЙТИ УДАЛЕНИЕ) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local WALK_SPEED = 300
local TARGET_HEIGHT = 100  -- фиксированная высота

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

local targetPos = island:GetPivot().Position + Vector3.new(0, TARGET_HEIGHT, 0)
print("Цель: " .. tostring(targetPos))

-- Отключаем коллизии навсегда (фоновый поток)
task.spawn(function()
    while true do
        if char and char.Parent then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
        task.wait(0.2)
    end
end)

-- Замораживаем гуманоид
humanoid.PlatformStand = true

-- Создаём BodyPosition для фиксации высоты на TARGET_HEIGHT
local bodyPos = Instance.new("BodyPosition")
bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
bodyPos.Position = Vector3.new(hrp.Position.X, TARGET_HEIGHT, hrp.Position.Z)
bodyPos.Parent = hrp

-- Основной поток: каждые 0.02 секунды пересоздаём BodyVelocity к цели
local bv = nil
task.spawn(function()
    while true do
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        local dir = (targetPos - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.02)
    end
end)

-- Мониторинг расстояния и остановка
while true do
    task.wait(0.2)
    local dist = (hrp.Position - targetPos).Magnitude
    print(string.format("Расстояние до цели: %.1f", dist))
    if dist < 5 then break end
end

-- Очистка
if bv then bv:Destroy() end
bodyPos:Destroy()
humanoid.PlatformStand = false
hrp.CFrame = CFrame.new(targetPos)
print("Прибыли на остров")
