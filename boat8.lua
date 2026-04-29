-- ===== ТЕСТ: ДВИЖЕНИЕ ЛОДКИ МАЛЕНЬКИМИ ШАГАМИ (CFrame) =====
local player = game.Players.LocalPlayer
local char = player.Character
if not char then return end
local humanoid = char:FindFirstChild("Humanoid")
local seat = humanoid and humanoid.SeatPart
if not seat then
    warn("Вы не сидите в лодке")
    return
end
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then
    warn("Лодка не найдена")
    return
end
local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    warn("Основная часть лодки не найдена")
    return
end

-- НАСТРОЙКИ (подберите свои границы по X)
local X_MIN = -77389.3
local X_MAX = -47968.4
local Y_FIXED = 100
local currentDirection = -1   -- начинаем движение влево
local STEP_SIZE = 8.5         -- средний шаг (можно уменьшить до 1 для плавности)
local STEP_INTERVAL = 0.2     -- интервал между шагами

print("Движение лодки запущено. Шаг:", STEP_SIZE, "интервал:", STEP_INTERVAL)

while true do
    -- Проверка: сидит ли персонаж на этом же сиденье
    if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
        print("Персонаж вышел, движение остановлено")
        break
    end
    local newX = rootPart.Position.X + currentDirection * STEP_SIZE
    if newX <= X_MIN then
        newX = X_MIN
        currentDirection = 1   -- разворот вправо
    elseif newX >= X_MAX then
        newX = X_MAX
        currentDirection = -1  -- разворот влево
    end
    rootPart.CFrame = CFrame.new(newX, Y_FIXED, rootPart.Position.Z)
    task.wait(STEP_INTERVAL)
end
