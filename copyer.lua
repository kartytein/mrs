-- ===== ПЕРЕМЕЩЕНИЕ К ОСТРОВУ (НА ОСНОВЕ ВАШЕГО РАБОЧЕГО МЕТОДА) =====
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

-- Целевая точка: центр острова + смещение по Y (можно подобрать)
local islandPos = island:GetPivot().Position
local targetPos = islandPos + Vector3.new(0, 50, 0)  -- высоко, чтобы пролететь над препятствиями
print("Цель: " .. tostring(targetPos))

local speed = 150        -- скорость
local step = 0.05        -- интервал
local function moveSmooth()
    while true do
        local current = hrp.Position
        local direction = (targetPos - current).Unit
        local distance = (targetPos - current).Magnitude
        if distance < 3 then break end
        local move = math.min(speed * step, distance)
        local newPos = current + direction * move
        
        -- Отключаем коллизии
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        
        hrp.CFrame = CFrame.new(newPos)
        
        -- Включаем коллизии
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        
        task.wait(step)
    end
    hrp.CFrame = CFrame.new(targetPos)
    print("Перемещение завершено, позиция:", hrp.Position)
end

moveSmooth()
