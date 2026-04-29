-- ===== ФИНАЛЬНЫЙ СКРИПТ ДВИЖЕНИЯ ЛОДКИ (ПО ЭТАЛОНУ) =====
-- Создаёт BodyVelocity на UpperTorso персонажа с постоянным обновлением скорости,
-- меняет направление при достижении границ X, не пересоздаёт BodyVelocity.
-- Лодка движется только когда персонаж сидит.

local player = game.Players.LocalPlayer

-- Ждём, пока персонаж сядет в лодку (вручную или автоматически)
local function waitForSeat()
    while true do
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart then
                return humanoid.SeatPart, humanoid
            end
        end
        task.wait(0.5)
    end
end

print("Ожидание посадки в лодку...")
local seat, humanoid = waitForSeat()
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then error("Лодка не найдена") end
local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Нет основной части лодки") end

-- Получаем UpperTorso персонажа (важно! эталон создаёт BodyVelocity именно на нём)
local char = player.Character
local upperTorso = char:FindFirstChild("UpperTorso")
if not upperTorso then
    error("UpperTorso не найден (возможно, персонаж ещё не загружен полностью)")
end

-- Настройки движения
local X_MIN = -77389.3
local X_MAX = -47968.4
local currentDirection = -1   -- начинаем влево
local SPEED_X = 250            -- абсолютная скорость по X
local SPEED_Y = -2.0           -- небольшое смещение вниз (как в эталоне)
local SPEED_Z = -2.0           -- небольшое смещение по Z

-- Создаём BodyVelocity на UpperTorso (один раз)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bv.Parent = upperTorso
bv.Velocity = Vector3.new(currentDirection * SPEED_X, SPEED_Y, SPEED_Z)
print("BodyVelocity создан на UpperTorso, начальная скорость: " .. tostring(bv.Velocity))

-- Отключаем коллизии у лодки и персонажа (как в эталоне, но для надёжности)
for _, part in ipairs(boat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end

-- Основной цикл: следим за позицией лодки и меняем направление при достижении границ
task.spawn(function()
    while true do
        -- Если персонаж перестал сидеть, останавливаем движение (удаляем BodyVelocity)
        if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
            bv:Destroy()
            print("Движение остановлено (персонаж вышел)")
            break
        end
        local x = rootPart.Position.X
        local newDir = currentDirection
        if x <= X_MIN and currentDirection == -1 then
            newDir = 1
        elseif x >= X_MAX and currentDirection == 1 then
            newDir = -1
        end
        if newDir ~= currentDirection then
            currentDirection = newDir
            bv.Velocity = Vector3.new(currentDirection * SPEED_X, SPEED_Y, SPEED_Z)
            print("Смена направления, новая скорость: " .. tostring(bv.Velocity))
        end
        task.wait(0.2)  -- проверяем каждые 0.2 секунды (как в логах)
    end
end)

print("Скрипт движения лодки запущен. Лодка будет двигаться, пока вы сидите.")
