-- ===== ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К FOSSIL EXPERT (С ОЖИДАНИЕМ NPC) =====
local player = game.Players.LocalPlayer
local WALK_SPEED = 150
local hasMoved = false

local function findPrehistoricIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function waitForNpc()
    -- Ждём появления модели Fossil Expert
    for _ = 1, 30 do
        local npc = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Fossil Expert")
        if npc and npc:IsA("Model") then
            local primary = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
            if primary then
                return primary.Position + Vector3.new(0, 2, 0)
            end
        end
        task.wait(1)
    end
    -- Если NPC не появился, ищем спавн-часть
    local island = findPrehistoricIsland()
    if island then
        local core = island:FindFirstChild("Core")
        if core then
            local spawn = core:FindFirstChild("Fossil ExpertSpawn")
            if spawn and spawn:IsA("Part") then
                return spawn.Position + Vector3.new(0, 2, 0)
            end
        end
        return island:GetPivot().Position + Vector3.new(0, 10, 0)
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
    while true do
        local island = findPrehistoricIsland()
        if island and not hasMoved then
            hasMoved = true
            local target = waitForNpc()
            if target then
                moveToPoint(target)
            end
        end
        task.wait(1)
    end
end)
