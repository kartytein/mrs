-- ===== ПЕРЕМЕЩЕНИЕ К NPC FOSSIL EXPERT (ПРЯМАЯ ЛИНИЯ ДО ЦЕЛИ) =====
local player = game.Players.LocalPlayer
local WALK_SPEED = 150

-- Получаем позицию NPC
local npcs = workspace:FindFirstChild("NPCs")
local npc = npcs and (npcs:FindFirstChild("Fossil Expert") or npcs:FindFirstChild("FossilExpert"))
if not npc then
    warn("NPC Fossil Expert не найден")
    return
end

local primary = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
if not primary then
    warn("У NPC нет основной части")
    return
end

local targetPos = primary.Position + Vector3.new(0, 2, 0)
print("[MOVE] Цель: " .. tostring(targetPos))

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

while (hrp.Position - targetPos).Magnitude > 3 do
    local dir = (targetPos - hrp.Position).Unit
    bv.Velocity = dir * WALK_SPEED
    task.wait(0.1)
end

bv:Destroy()
humanoid.PlatformStand = false
print("[MOVE] Прибыли к NPC Fossil Expert")
