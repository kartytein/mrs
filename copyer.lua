-- ===== ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К FOSSIL EXPERT С ФИКСАЦИЕЙ =====
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

local function moveToAndStay(target, speed)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    -- Отключаем гравитацию и замораживаем анимации
    humanoid.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - target).Magnitude > 2 do
        local dir = (target - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(target)
    -- Оставляем PlatformStand = true, чтобы персонаж не падал
    print("[MOVE] Перемещение завершено, позиция зафиксирована")
end

local function onIslandDetected()
    if hasMoved then return end
    local target = getFossilTarget()
    if not target then
        print("[MOVE] Не удалось найти цель")
        return
    end
    hasMoved = true
    print("[MOVE] Перемещение к Fossil Expert, координаты: " .. tostring(target))
    moveToAndStay(target, WALK_SPEED)
end

task.spawn(function()
    while true do
        local island = findPrehistoricIsland()
        if island and not hasMoved then
            onIslandDetected()
        end
        task.wait(1)
    end
end)

print("Скрипт запущен. При появлении острова персонаж переместится к Fossil Expert и зависнет в воздухе (PlatformStand).")
