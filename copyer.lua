-- ===== ДИАГНОСТИЧЕСКИЙ ТРЕКЕР: ОТСЛЕЖИВАНИЕ BODYVELOCITY =====
-- Запустите этот скрипт, когда персонаж сидит в лодке.
-- Он будет выводить в консоль каждое событие: создание, удаление, изменение скорости
-- с временной меткой и указанием причины.

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Отключаем коллизии (как обычно)
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

-- Глобальные счётчики
local velocityCounter = 0
local lastLogTime = tick()

-- Функция логирования с временной меткой
local function logEvent(event, reason, extra)
    local now = tick()
    local timeStr = os.date("%H:%M:%S", now) .. string.format(".%03d", (now - math.floor(now)) * 1000)
    print(string.format("[%s] %s | Причина: %s %s", timeStr, event, reason, extra or ""))
end

-- Функция для перехвата удаления BodyVelocity (через подключение к AncestryChanged)
local function watchBodyVelocity(bv)
    if not bv or bv._tracked then return end
    bv._tracked = true
    bv.AncestryChanged:Connect(function()
        if not bv.Parent then
            logEvent("BodyVelocity УДАЛЁН", "игра или скрипт удалили", "скорость перед удалением: " .. tostring(bv.Velocity))
        end
    end)
    bv:GetPropertyChangedSignal("Velocity"):Connect(function()
        logEvent("BodyVelocity скорость ИЗМЕНЕНА", "свойство Velocity изменено", "новая скорость: " .. tostring(bv.Velocity))
    end)
end

-- Периодическая проверка (каждые 0.5 сек) для отслеживания появления/исчезновения
task.spawn(function()
    while true do
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv and not bv._tracked then
            watchBodyVelocity(bv)
            logEvent("BodyVelocity СОЗДАН", "обнаружен новый", "скорость: " .. tostring(bv.Velocity))
            velocityCounter = velocityCounter + 1
        end
        task.wait(0.5)
    end
end)

-- Имитация эталонного поведения: каждые 0.2 секунды попытка обновить скорость
local currentDirection = -1
local BOAT_SPEED = 250
local X_MIN = -77389.3
local X_MAX = -47968.4

-- Поток для смены направления (по позиции лодки)
task.spawn(function()
    while true do
        task.wait(0.2)
        local seat = humanoid.SeatPart
        if seat then
            local boat = seat:FindFirstAncestorWhichIsA("Model")
            if boat then
                local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if rootPart then
                    local x = rootPart.Position.X
                    if x <= X_MIN and currentDirection == -1 then
                        currentDirection = 1
                        logEvent("СМЕНА НАПРАВЛЕНИЯ", "достигнута левая граница", "новое направление: вправо")
                    elseif x >= X_MAX and currentDirection == 1 then
                        currentDirection = -1
                        logEvent("СМЕНА НАПРАВЛЕНИЯ", "достигнута правая граница", "новое направление: влево")
                    end
                end
            end
        end
    end
end)

-- Основной цикл управления BodyVelocity (каждую секунду, как в вашем скрипте)
while true do
    task.wait(1)
    local sitting = humanoid.Sit and humanoid.SeatPart
    if sitting then
        local speedX = currentDirection == -1 and -BOAT_SPEED or BOAT_SPEED
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then
            if bv.Velocity.X ~= speedX then
                logEvent("BodyVelocity ОБНОВЛЁН", "изменение скорости по таймеру", string.format("с %.1f на %.1f", bv.Velocity.X, speedX))
                bv.Velocity = Vector3.new(speedX, 0, 0)
            else
                -- можно закомментировать, чтобы не спамило
                -- logEvent("BodyVelocity ПРОВЕРЕН", "скорость не менялась", string.format("текущая %.1f", speedX))
            end
        else
            logEvent("BodyVelocity ОТСУТСТВУЕТ", "создаём новый по таймеру", "целевая скорость " .. speedX)
            local newBv = Instance.new("BodyVelocity")
            newBv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            newBv.Parent = hrp
            newBv.Velocity = Vector3.new(speedX, 0, 0)
            watchBodyVelocity(newBv)
        end
    else
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then
            logEvent("BodyVelocity УДАЛЁН", "персонаж не сидит в лодке", "удаление по таймеру")
            bv:Destroy()
        end
    end
end
