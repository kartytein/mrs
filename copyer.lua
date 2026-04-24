-- ===== НАДЁЖНОЕ ПЕРЕМЕЩЕНИЕ К NPC FOSSIL EXPERT (ПОСТОЯННОЕ ПЕРЕСОЗДАНИЕ BODYVELOCITY) =====
local player = game.Players.LocalPlayer
local WALK_SPEED = 150

-- Поиск NPC (расширенный)
local function findNpc()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name == "Fossil Expert" or obj.Name == "FossilExpert") then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primary then
                return primary.Position + Vector3.new(0, 2, 0)
            end
        end
    end
    return nil
end

local target = findNpc()
if not target then
    warn("NPC не найден. Запустите скрипт позже или проверьте путь.")
    return
end

print("[MOVE] Цель: " .. tostring(target))

local char = player.Character
if not char then
    warn("Персонаж не загружен")
    return
end

local hrp = char:FindFirstChild("HumanoidRootPart")
local humanoid = char:FindFirstChild("Humanoid")
if not hrp or not humanoid then
    warn("Нет HumanoidRootPart или Humanoid")
    return
end

-- Отключаем коллизии и гравитацию (PlatformStand)
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
humanoid.PlatformStand = true

-- Поток пересоздания BodyVelocity каждые 0.1 секунды
local bv = nil
task.spawn(function()
    while true do
        if not hrp or not hrp.Parent then break end
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED
        task.wait(0.1)
    end
end)

-- Основной цикл: ждём, пока расстояние не станет маленьким
while (hrp.Position - target).Magnitude > 3 do
    task.wait(0.1)
end

-- Очистка
if bv then bv:Destroy() end
humanoid.PlatformStand = false
print("[MOVE] Прибыли к NPC")
