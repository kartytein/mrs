-- ===== ПЕРЕМЕЩЕНИЕ К ОСТРОВУ С ЧАСТЫМ ПЕРЕСОЗДАНИЕМ BODYVELOCITY (БЕЗ CFrame) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

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

local targetPos = island:GetPivot().Position + Vector3.new(0, 50, 0)
local speed = 300

-- Постоянное отключение коллизий
task.spawn(function()
    while true do
        if char and char.Parent then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        task.wait(0.2)
    end
end)

humanoid.PlatformStand = true

-- Поток пересоздания BodyVelocity
local bv = nil
local moving = true
task.spawn(function()
    while moving do
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        local dir = (targetPos - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait(0.05)
    end
end)

-- Ждём достижения цели
while (hrp.Position - targetPos).Magnitude > 5 do
    task.wait(0.1)
end

-- Остановка
moving = false
if bv then bv:Destroy() end
humanoid.PlatformStand = false
print("Прибыли на остров")
