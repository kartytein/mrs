-- 3. Посадка в лодку (исправленная)
local function sitOnBoat(boat, boatSeat)
    if not boat or not boatSeat then
        warn("Лодка или сиденье не найдены")
        return false
    end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    -- Отключаем коллизии
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    local targetCF = boatSeat.CFrame + Vector3.new(0, 2.5, 0)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    while (hrp.Position - targetCF.Position).Magnitude > 1.5 do
        local direction = (targetCF.Position - hrp.Position).Unit
        bv.Velocity = direction * 150
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
    return true
end

-- Использование:
if myBoat and seat then
    sitOnBoat(myBoat, seat)
end
