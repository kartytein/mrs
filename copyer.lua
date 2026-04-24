-- ===== ПЕРЕМЕЩЕНИЕ К ОСТРОВУ PREHISTORICISLAND С ПОСТОЯННЫМ ОТКЛЮЧЕНИЕМ COLLIDE =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local speed = 300
local step = 0.1

-- ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (как в фул скрипте)
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

local targetPos = island:GetPivot().Position + Vector3.new(0, 100, 0)  -- поднимаем на 100
print("Цель: " .. tostring(targetPos))

-- Замораживаем анимации и отключаем гравитацию
humanoid.PlatformStand = true

-- Фиксация высоты через BodyPosition (чтобы не падать)
local bodyPos = Instance.new("BodyPosition")
bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
bodyPos.Position = Vector3.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
bodyPos.Parent = hrp

-- Основной цикл перемещения
while true do
    local current = hrp.Position
    local distance = (targetPos - current).Magnitude
    if distance < 3 then break end
    local direction = (targetPos - current).Unit
    local move = math.min(speed * step, distance)
    local newPos = current + direction * move
    hrp.CFrame = CFrame.new(newPos)
    task.wait(step)
end

-- Очистка
bodyPos:Destroy()
humanoid.PlatformStand = false
hrp.CFrame = CFrame.new(targetPos)
print("Прибыли на остров")
