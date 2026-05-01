-- ===== МАГНИТ: ВОЗВРАТ НА СИДЕНЬЕ (ПЛАВНО, КАК В ЭТАЛОНЕ) =====
local player = game.Players.LocalPlayer
local stepDuration = 0.05
local walkSpeed = 150
local stepSize = walkSpeed * stepDuration

-- Функция плавного перемещения к цели (CFrame маленькими шагами)
local function moveSmooth(targetPos, keepY)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    local oldPlatform = hum.PlatformStand
    hum.PlatformStand = true
    while (hrp.Position - targetPos).Magnitude > 0.5 do
        local dir = (targetPos - hrp.Position).Unit
        local move = math.min(stepSize, (targetPos - hrp.Position).Magnitude)
        local newPos = hrp.Position + dir * move
        if keepY then newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z) end
        hrp.CFrame = CFrame.new(newPos)
        task.wait(stepDuration)
    end
    hrp.CFrame = CFrame.new(targetPos)
    hum.PlatformStand = oldPlatform
    return true
end

-- Поиск своей лодки по Owner
local function findMyBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, b in ipairs(boats:GetChildren()) do
        if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
            if b:GetAttribute("Owner") == player.Name then return b end
            local own = b:FindFirstChild("Owner")
            if own and tostring(own.Value) == player.Name then return b end
        end
    end
    return nil
end

-- Глобальные переменные для лодки и сиденья
local boat = nil
local seat = nil

-- Функция обновления ссылок на лодку и сиденье
local function updateReferences()
    boat = findMyBoat()
    if boat then seat = boat:FindFirstChildWhichIsA("VehicleSeat") else seat = nil end
end

-- Основной цикл магнита
task.spawn(function()
    while true do
        task.wait(0.2) -- частота проверки
        updateReferences()
        if not boat or not seat then continue end
        local char = player.Character
        if not char then continue
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue
        -- Если не сидит на нужном сиденье
        if not (hum.Sit and hum.SeatPart == seat) then
            -- Цель: чуть выше сиденья (как в логах, с запасом)
            local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
            moveSmooth(targetPos, true)
            -- После перемещения садимся
            hum.Sit = true
            task.wait(0.3) -- даём время стабилизироваться
        end
    end
end)

print("Магнит запущен, будет возвращать на сиденье при вылезании.")
