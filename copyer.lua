-- ===== ПЛАВНОЕ ПЕРЕМЕЩЕНИЕ К ОСТРОВУ PREHISTORICISLAND (ПОСТОЯННОЕ ПЕРЕСОЗДАНИЕ BODYVELOCITY) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Поиск острова
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local island = findIsland()
if not island then
    warn("Остров не найден")
    return
end

-- Целевая точка (центр острова + смещение по Y, чтобы не зарываться в землю)
local targetPos = island:GetPivot().Position + Vector3.new(0, 30, 0)
local speed = 300

-- ===== ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (как в фул скрипте) =====
task.spawn(function()
    while true do
        if char and char.Parent then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        task.wait(0.2)
    end
end)

-- Замораживаем гуманоид, чтобы не падал и не двигался сам
humanoid.PlatformStand = true

-- ===== ПОТОК ПЕРЕСОЗДАНИЯ BODYVELOCITY (каждые 0.05 секунды) =====
local bv = nil
local moving = true
task.spawn(function()
    while moving do
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        local dir = (targetPos - hrp.Position).Unit
        bv.Velocity = dir * speed
        task.wait(0.05)
    end
end)

-- Ждём, пока персонаж приблизится к цели (без CFrame)
while (hrp.Position - targetPos).Magnitude > 3 do
    task.wait(0.1)
end

-- Останавливаем движение и снимаем заморозку
moving = false
if bv then bv:Destroy() end
humanoid.PlatformStand = false
print("Прибыли на остров")
