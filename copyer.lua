-- ===== УСКОРЕННОЕ ПОШАГОВОЕ ПЕРЕМЕЩЕНИЕ К ОСТРОВУ С ФИКСАЦИЕЙ Y =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local speed = 300          -- выше скорость
local step = 0.1           -- реже обновление

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

local targetPos = island:GetPivot().Position + Vector3.new(0, 50, 0)
print("Цель: " .. tostring(targetPos))

-- Отключаем коллизии
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
humanoid.PlatformStand = true  -- замораживаем, чтобы не падал

-- Дополнительно фиксируем Y через BodyPosition (если нужно)
local bodyPos = Instance.new("BodyPosition")
bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
bodyPos.Position = Vector3.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
bodyPos.Parent = hrp

-- Движение (только по X и Z, Y фиксируется BodyPosition)
while true do
    local current = hrp.Position
    local dist = (targetPos - current).Magnitude
    if dist < 3 then break end
    local dir = (targetPos - current).Unit
    local move = math.min(speed * step, dist)
    local newPos = current + dir * move
    hrp.CFrame = CFrame.new(newPos)
    task.wait(step)
end

-- Очистка
bodyPos:Destroy()
humanoid.PlatformStand = false
hrp.CFrame = CFrame.new(targetPos)
print("Прибыли на остров")
