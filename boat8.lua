-- ===== ИТОГОВЫЙ СКРИПТ: ДВИЖЕНИЕ ЛОДКИ С ВЫВОДОМ CFrame =====
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

print("Ожидание посадки в лодку...")
local seat = waitForSeat()
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then error("Лодка не найдена") end
local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Нет основной части") end

-- НАСТРОЙКИ
local X_MIN = -77389.3
local X_MAX = -47968.4
local Y_FIXED = 100                     -- фиксированная высота
local currentDirection = -1             -- начинаем влево
local STEP_INTERVAL = 0.2               -- интервал между шагами (сек)

-- Дельта шагов из эталонного лога (зацикливаем)
local deltaHistory = {-11.5, -6.3, -7.3, -9.4, -7.3, -9.4, -9.4, -8.3, -9.4, -10.4, -9.4, -7.3, -6.3, -5.2, -9.4, -8.3}
local deltaIndex = 1
local function getNextDelta()
    local d = deltaHistory[deltaIndex]
    deltaIndex = deltaIndex % #deltaHistory + 1
    return d
end

print("Движение лодки запущено. Будет выводиться CFrame каждые 5 шагов.")
local stepCounter = 0

while true do
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
        print("Движение остановлено (персонаж не сидит)")
        break
    end

    local delta = currentDirection * getNextDelta()
    local newX = rootPart.Position.X + delta
    if newX <= X_MIN then
        newX = X_MIN
        currentDirection = 1
        print("[СМЕНА] Направление → вправо")
    elseif newX >= X_MAX then
        newX = X_MAX
        currentDirection = -1
        print("[СМЕНА] Направление → влево")
    end

    rootPart.CFrame = CFrame.new(newX, Y_FIXED, rootPart.Position.Z)

    stepCounter = stepCounter + 1
    if stepCounter % 5 == 0 then
        local pos = rootPart.Position
        print(string.format("[Шаг %d] CFrame: (%s) | Позиция: (%.1f, %.1f, %.1f)", 
              stepCounter, tostring(rootPart.CFrame), pos.X, pos.Y, pos.Z))
    end

    task.wait(STEP_INTERVAL)
end
