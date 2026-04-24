-- Диагностика: поиск всех объектов с "Fossil" в имени
print("=== ДИАГНОСТИКА ПОИСКА NPC ===")
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name and string.find(obj.Name, "Fossil") then
        print("Найден:", obj:GetFullName(), "(", obj.ClassName, ")")
    end
end
print("=== КОНЕЦ ДИАГНОСТИКИ ===")

local player = game.Players.LocalPlayer
local WALK_SPEED = 150

-- Расширенный поиск NPC
local function getFossilPosition()
    -- Ищем везде, не только в NPCs
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

local target = getFossilPosition()
if not target then
    warn("NPC Fossil Expert не найден даже после расширенного поиска")
    return
end

print("[MOVE] Цель найдена: " .. tostring(target))

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

-- Отключаем коллизии и замораживаем
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
humanoid.PlatformStand = true

local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bv.Parent = hrp

while (hrp.Position - target).Magnitude > 3 do
    local dir = (target - hrp.Position).Unit
    bv.Velocity = dir * WALK_SPEED
    task.wait(0.1)
end

bv:Destroy()
humanoid.PlatformStand = false
print("[MOVE] Прибыли к NPC Fossil Expert")
