-- ===== ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К FOSSIL EXPERT (КАК ПОСАДКА В ЛОДКУ) =====
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

local function getFossilTarget()
    local npc = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Fossil Expert")
    if npc and npc:IsA("Model") then
        local primary = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
        if primary then
            return primary.Position + Vector3.new(0, 3, 0)
        end
    end
    local map = workspace:FindFirstChild("Map")
    if map then
        local island = map:FindFirstChild("Prehistoricisland")
        if island then
            local core = island:FindFirstChild("Core")
            if core then
                local spawn = core:FindFirstChild("Fossil ExpertSpawn")
                if spawn and spawn:IsA("Part") then
                    return spawn.Position + Vector3.new(0, 2, 0)
                end
            end
        end
    end
    local island = findPrehistoricIsland()
    if island then
        return island:GetPivot().Position + Vector3.new(0, 10, 0)
    end
    return nil
end

local function moveToIsland(targetPos)
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
        if dist < 1.5 then
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
            local target = getFossilTarget()
            if target then
                print("[MOVE] Перемещение к Fossil Expert, цель: " .. tostring(target))
                moveToIsland(target)
                print("[MOVE] Перемещение завершено")
            else
                print("[MOVE] Цель не найдена")
            end
        end
        task.wait(1)
    end
end)

print("Скрипт перемещения к Fossil Expert запущен (метод как при посадке в лодку).")
