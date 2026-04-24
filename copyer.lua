-- ===== ПЕРЕМЕЩЕНИЕ К ОСТРОВУ PREHISTORICISLAND (МЕХАНИЗМ ПОСАДКИ В ЛОДКУ) =====
local player = game.Players.LocalPlayer

local function findPrehistoricIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
            return obj
        end
    end
    return nil
end

local function moveToIsland()
    local island = findPrehistoricIsland()
    if not island then
        warn("Остров не найден")
        return
    end
    local targetPos = island:GetPivot().Position + Vector3.new(0, 20, 0)  -- точка на острове
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    -- ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ (как в основном скрипте)
    task.spawn(function()
        while char and char.Parent do
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            task.wait(0.2)
        end
    end)

    -- Замораживаем анимации, чтобы не падать
    humanoid.PlatformStand = true

    -- Переменные для циклического пересоздания BodyVelocity
    local bv = nil
    local moving = true
    local speed = 300  -- скорость полёта

    -- Поток пересоздания (как в forceSit)
    task.spawn(function()
        while moving do
            if bv then bv:Destroy() end
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            local dir = (targetPos - hrp.Position).Unit
            bv.Velocity = dir * speed
            task.wait(0.05)  -- частое обновление
        end
    end)

    -- Ждём достижения цели
    while (hrp.Position - targetPos).Magnitude > 3 do
        task.wait(0.1)
    end

    moving = false
    if bv then bv:Destroy() end
    humanoid.PlatformStand = false
    print("[MOVE] Прибыли на остров")
end

-- Запуск
moveToIsland()
