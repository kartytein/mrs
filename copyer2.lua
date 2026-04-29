-- ===== ИМИТАЦИЯ ЭТАЛОННОГО ДВИЖЕНИЯ (BODYVELOCITY НА ПЕРСОНАЖЕ) =====
local player = game.Players.LocalPlayer

-- Ждём, пока персонаж сядет в лодку (вручную)
local function waitForSeat()
    while true do
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart then
                return humanoid.SeatPart
            end
        end
        task.wait(0.5)
    end
end

print("Сядьте в лодку вручную...")
local seat = waitForSeat()
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then error("Лодка не найдена") end

-- Находим персонажа
local char = player.Character
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Настройки движения
local X_MIN = -77389.3
local X_MAX = -47968.4
local currentDirection = -1   -- начинаем влево
local VELOCITY_SPEED = 250    -- абсолютная скорость
local VELOCITY_UPDATE_INTERVAL = 0.05  -- частота обновления

-- Функция для поддержания BodyVelocity
local function maintainBodyVelocity()
    local speedX = currentDirection * VELOCITY_SPEED
    local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
    if bv then
        bv.Velocity = Vector3.new(speedX, 0, 0)
    else
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        bv.Velocity = Vector3.new(speedX, 0, 0)
    end
end

-- Функция проверки границ (меняем направление, если лодка достигла края)
local function checkBoundaries()
    local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not rootPart then return end
    local x = rootPart.Position.X
    if x <= X_MIN and currentDirection == -1 then
        currentDirection = 1
        print("-> Смена направления вправо")
    elseif x >= X_MAX and currentDirection == 1 then
        currentDirection = -1
        print("-> Смена направления влево")
    end
end

-- Отключаем коллизии у лодки и персонажа (как в основном скрипте)
-- (это можно делать раз в 0.3 сек, но для простоты сделаем один раз)
for _, part in ipairs(boat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end

-- Основной цикл: постоянно обновляем BodyVelocity и проверяем границы
task.spawn(function()
    while true do
        if not (humanoid.Sit and humanoid.SeatPart == seat) then
            print("Движение остановлено (персонаж не сидит)")
            break
        end
        maintainBodyVelocity()
        checkBoundaries()
        task.wait(VELOCITY_UPDATE_INTERVAL)
    end
end)

print("Движение активировано (BodyVelocity на персонаже). Лодка должна поехать.")
