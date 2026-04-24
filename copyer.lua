-- ===== ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К FOSSIL EXPERT (NPC УЖЕ СУЩЕСТВУЕТ) =====
local player = game.Players.LocalPlayer
local WALK_SPEED = 150
local hasMoved = false

local function getFossilPosition()
    local npc = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Fossil Expert")
    if npc and npc:IsA("Model") then
        local primary = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
        if primary then
            return primary.Position + Vector3.new(0, 2, 0)
        end
    end
    return nil
end

local function moveToPoint(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    humanoid.PlatformStand = true

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    local lastDist = math.huge
    local stuck = 0
    while true do
        local dist = (hrp.Position - targetPos).Magnitude
        if dist < 2 then
            bv:Destroy()
            hrp.CFrame = CFrame.new(targetPos)
            break
        end
        local dir = (targetPos - hrp.Position).Unit
        bv.Velocity = dir * WALK_SPEED

        if math.abs(dist - lastDist) < 0.05 then
            stuck = stuck + 1
            if stuck > 30 then
                bv:Destroy()
                hrp.CFrame = CFrame.new(targetPos)
                break
            end
        else
            stuck = 0
        end
        lastDist = dist
        task.wait(0.1)
    end
    bv:Destroy()
    humanoid.PlatformStand = false
    return true
end

task.spawn(function()
    local target = getFossilPosition()
    if target then
        moveToPoint(target)
        print("[MOVE] Перемещение к NPC Fossil Expert выполнено")
    else
        print("[MOVE] NPC Fossil Expert не найден")
    end
end)

print("Скрипт перемещения к Fossil Expert запущен.")
