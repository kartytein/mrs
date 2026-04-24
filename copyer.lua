-- ===== ПЕРЕМЕЩЕНИЕ К NPC FOSSIL EXPERT ПОСЛЕ ПОЯВЛЕНИЯ ОСТРОВА =====
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
    print("[WAIT] Ожидание появления NPC Fossil Expert...")
    for i = 1, 30 do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name == "Fossil Expert" or obj.Name == "FossilExpert") then
                local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if primary then
                    print("[WAIT] NPC найден: " .. obj:GetFullName())
                    return primary.Position + Vector3.new(0, 2, 0)
                end
            end
        end
        task.wait(1)
    end
    return nil
end

local function moveToPoint(targetPos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

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
    print("[MOVE] Прибыли к NPC")
end

local function onIslandDetected()
    if hasMoved then return end
    local target = waitForNpc()
    if target then
        hasMoved = true
        moveToPoint(target)
    else
        print("[ERROR] NPC не появился за 30 секунд")
    end
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

print("Скрипт запущен. При появлении острова будет выполнен поиск NPC и перемещение.")
