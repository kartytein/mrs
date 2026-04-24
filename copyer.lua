-- ===== ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К ОСТРОВУ PREHISTORICISLAND ЧЕРЕЗ TWEEN =====
local player = game.Players.LocalPlayer
local tweenService = game:GetService("TweenService")
local WALK_SPEED = 150

local function findPrehistoricIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local island = findPrehistoricIsland()
if not island then
    warn("Остров не найден")
    return
end

local targetPos = island:GetPivot().Position + Vector3.new(0, 20, 0)  -- поднимаем выше
print("[MOVE] Цель: " .. tostring(targetPos))

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

-- Создаём Tween с пересозданием каждые 0.1 секунды
local currentTween = nil
local running = true
task.spawn(function()
    while running do
        if currentTween then currentTween:Cancel() end
        local dist = (hrp.Position - targetPos).Magnitude
        if dist < 3 then break end
        local duration = dist / WALK_SPEED
        currentTween = tweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = targetPos})
        currentTween:Play()
        task.wait(0.1)
    end
end)

-- Ждём прибытия
while (hrp.Position - targetPos).Magnitude > 3 do
    task.wait(0.1)
end

running = false
if currentTween then currentTween:Cancel() end
humanoid.PlatformStand = false
print("[MOVE] Прибыли к острову")
