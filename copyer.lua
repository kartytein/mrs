-- ===== ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К NPC FOSSIL EXPERT (BODYVELOCITY, БЕЗ CFrame) =====
local player = game.Players.LocalPlayer
local WALK_SPEED = 150

local function getFossilPosition()
    local npcs = workspace:FindFirstChild("NPCs")
    if npcs then
        local npc = npcs:FindFirstChild("Fossil Expert") or npcs:FindFirstChild("FossilExpert")
        if npc and npc:IsA("Model") then
            local primary = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
            if primary then
                return primary.Position + Vector3.new(0, 2, 0)
            end
        end
    end
    return nil
end

local function moveToNPC(targetPos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    -- Отключаем коллизии и замораживаем анимации
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    humanoid.PlatformStand = true

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    while true do
        local dist = (hrp.Position - targetPos).Magnitude
        if dist < 2 then
            break
        end
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * WALK_SPEED
        task.wait(0.1)
    end

    bv:Destroy()
    humanoid.PlatformStand = false
    print("[MOVE] Прибыли к NPC Fossil Expert")
end

local target = getFossilPosition()
if target then
    moveToNPC(target)
else
    warn("[MOVE] NPC Fossil Expert не найден")
end
