-- Телепортация к острову Prehistoricisland (мгновенно, без поломок)
local player = game.Players.LocalPlayer

local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function teleportToIsland()
    local island = findIsland()
    if not island then return end
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
    -- Вычисляем целевую позицию (центр острова + смещение)
    local islandPos = island:GetPivot().Position
    local targetPos = islandPos + Vector3.new(0, 50, 0) -- поднимаем выше
    hrp.CFrame = CFrame.new(targetPos)
    -- Даём время на стабилизацию
    task.wait(0.5)
    humanoid.PlatformStand = false
    print("[TELEPORT] Телепортирован на остров")
end

teleportToIsland()
