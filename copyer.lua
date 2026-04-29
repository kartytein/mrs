-- Движение лодки через BodyVelocity на персонаже (как в эталоне)
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Параметры
local X_MIN = -77389.3
local X_MAX = -47968.4
local BOAT_SPEED = 250
local currentDirection = -1   -- -1 = влево, 1 = вправо

-- Отключаем коллизии
task.spawn(function()
    while true do
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
        task.wait(0.3)
    end
end)

-- Функция обновления скорости (пересоздаёт BodyVelocity, если его нет)
local function ensureVelocity()
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
    if bv then
        bv.Velocity = Vector3.new(speedX, 0, 0)
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
    end
end

-- Отдельный поток для проверки границ и смены направления (по позиции лодки)
task.spawn(function()
    while true do
        task.wait(0.2)
        -- Находим лодку по сиденью
        local seat = humanoid.SeatPart
        if seat then
            local boat = seat:FindFirstAncestorWhichIsA("Model")
            if boat then
                local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if rootPart then
                    local x = rootPart.Position.X
                    if x <= X_MIN and currentDirection == -1 then
                        currentDirection = 1
                        ensureVelocity()
                    elseif x >= X_MAX and currentDirection == 1 then
                        currentDirection = -1
                        ensureVelocity()
                    end
                end
            end
        end
    end
end)

-- Главный цикл: каждую секунду проверяем, сидит ли персонаж, и создаём/обновляем BodyVelocity
while true do
    task.wait(1)
    if humanoid.Sit and humanoid.SeatPart then
        ensureVelocity()
    else
        -- Если не сидит, удаляем BodyVelocity
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then bv:Destroy() end
    end
end
