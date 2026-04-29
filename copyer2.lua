-- ===== ИМИТАЦИЯ ЭТАЛОННОГО СКРИПТА: ПЕРИОДИЧЕСКОЕ ПЕРЕСОЗДАНИЕ BODYVELOCITY =====
local player = game.Players.LocalPlayer
local HRP = nil
local seat = nil
local boat = nil
local rootPart = nil

-- Ждём посадки и получаем HRP
local function waitForSeat()
    while true do
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart then
                seat = humanoid.SeatPart
                boat = seat:FindFirstAncestorWhichIsA("Model")
                rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                HRP = char:FindFirstChild("HumanoidRootPart")
                return
            end
        end
        task.wait(0.5)
    end
end

waitForSeat()
print("Персонаж в лодке")

-- Настройки движения
local X_MIN = -77389.3
local X_MAX = -47968.4
local currentDirection = -1
local SPEED_X = -250  -- как в эталоне (отрицательное - влево)

-- Поток: пересоздаём BodyVelocity каждые 0.2 секунды (если персонаж сидит)
task.spawn(function()
    while true do
        task.wait(0.2)
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Sit and humanoid.SeatPart == seat then
            -- Удаляем старый BodyVelocity, если есть
            local old = HRP:FindFirstChildWhichIsA("BodyVelocity")
            if old then old:Destroy() end
            -- Создаём новый с нужной скоростью
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = HRP
            bv.Velocity = Vector3.new(currentDirection * math.abs(SPEED_X), 0, 0)
            -- Добавляем небольшой случайный шум (как в эталоне)
            bv.Velocity = bv.Velocity + Vector3.new(0, math.random(-3,3)*0.01, math.random(-3,3)*0.01)
        end
    end
end)

-- Поток смены направления (по достижении границ)
task.spawn(function()
    while true do
        task.wait(0.1)
        if rootPart then
            local x = rootPart.Position.X
            if x <= X_MIN and currentDirection == -1 then
                currentDirection = 1
                print("Смена направления → вправо")
            elseif x >= X_MAX and currentDirection == 1 then
                currentDirection = -1
                print("Смена направления → влево")
            end
        end
    end
end)

print("Скрипт запущен. Лодка должна двигаться плавно, как в эталоне.")
