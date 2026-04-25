-- ===== ПЕРЕМЕЩЕНИЕ К ОСТРОВУ С ФИКСАЦИЕЙ Y (ПОШАГОВО, БЕЗ ТЕЛЕПОРТАЦИИ) =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Функция поиска острова
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
    warn("Остров Prehistoricisland не найден")
    return
end

-- Вычисляем целевую позицию: центр острова + смещение по Y (чтобы быть над поверхностью)
local islandPos = island:GetPivot().Position
local targetHeight = islandPos.Y + 30   -- подняться на 30 студий выше центра
local targetPos = Vector3.new(islandPos.X, targetHeight, islandPos.Z)

print("[MOVE] Цель: " .. tostring(targetPos))

-- Отключаем коллизии у всех частей персонажа
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end

-- Замораживаем анимации, чтобы персонаж не падал и не дёргался
humanoid.PlatformStand = true

-- Параметры движения
local speed = 200        -- скорость (студий/сек)
local step = 0.05        -- интервал обновления

-- Основной цикл перемещения
while true do
    local currentPos = hrp.Position
    local distance = (targetPos - currentPos).Magnitude
    if distance < 1 then break end

    local direction = (targetPos - currentPos).Unit
    local move = math.min(speed * step, distance)
    local newPos = currentPos + direction * move

    -- Фиксируем Y на желаемой высоте, чтобы не падать вниз
    newPos = Vector3.new(newPos.X, targetHeight, newPos.Z)

    hrp.CFrame = CFrame.new(newPos)
    task.wait(step)
end

-- Финальная доводка (при необходимости)
hrp.CFrame = CFrame.new(targetPos)

-- Восстанавливаем коллизии и снимаем заморозку
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = true end
end
humanoid.PlatformStand = false

print("[MOVE] Прибыли на остров")
