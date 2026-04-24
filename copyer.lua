-- ===== ПЕРЕМЕЩЕНИЕ К ОСТРОВУ PREHISTORICISLAND ЧЕРЕЗ TWEEN =====
local player = game.Players.LocalPlayer
local tweenService = game:GetService("TweenService")
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

local function getIslandTargetPosition(island)
    -- Пытаемся взять PrimaryPart
    if island.PrimaryPart then
        return island.PrimaryPart.Position + Vector3.new(0, 2, 0)
    end
    -- Иначе ищем любую BasePart
    for _, part in ipairs(island:GetDescendants()) do
        if part:IsA("BasePart") then
            return part.Position + Vector3.new(0, 2, 0)
        end
    end
    -- Если ничего нет, возвращаем центр модели
    return island:GetPivot().Position + Vector3.new(0, 10, 0)
end

local function moveToIsland(targetPos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    -- Отключаем коллизии и замораживаем
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    humanoid.PlatformStand = true

    local distance = (hrp.Position - targetPos).Magnitude
    local duration = distance / WALK_SPEED
    if duration < 0.1 then duration = 0.1 end

    local tween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = targetPos})
    tween:Play()
    tween.Completed:Wait()

    humanoid.PlatformStand = false
    print("[MOVE] Перемещение к острову завершено")
end

task.spawn(function()
    while true do
        local island = findPrehistoricIsland()
        if island and not hasMoved then
            hasMoved = true
            local target = getIslandTargetPosition(island)
            print("[MOVE] Остров найден, перемещаемся к точке: " .. tostring(target))
            moveToIsland(target)
        end
        task.wait(1)
    end
end)

print("Скрипт запущен. При появлении острова персонаж переместится к нему (Tween).")
