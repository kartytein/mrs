-- ========== ДИАГНОСТИК ДВИЖЕНИЯ ==========
-- Версия 1.0
-- Запустите этот скрипт ОДНОВРЕМЕННО с эталонным скриптом
-- Он будет каждые 0.05 сек записывать позицию персонажа
-- и выводить сводку каждые 2 секунды, а также отмечать резкие ускорения.

local player = game.Players.LocalPlayer
local runService = game:GetService("RunService")
local logEnabled = true   -- Вывод в консоль
local guiEnabled = true   -- Создать небольшое окошко на экране

-- Хранилище замеров (последние 100)
local measurements = {}   -- каждый элемент: {time, pos, deltaTime, deltaDist, speed, smooth}

-- Создаём простой GUI для отображения текущей скорости
local screenGui = nil
local textLabel = nil
if guiEnabled then
    screenGui = Instance.new("ScreenGui")
    screenGui.Parent = player:WaitForChild("PlayerGui")
    textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 300, 0, 60)
    textLabel.Position = UDim2.new(0, 10, 0, 10)
    textLabel.BackgroundTransparency = 0.5
    textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.Text = "Диагност: ожидание персонажа..."
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 14
    textLabel.Parent = screenGui
end

local function logToConsole(msg)
    if logEnabled then
        print(os.date("%X"), msg)
    end
end

-- Получить время в миллисекундах (от запуска игры)
local function getMillis()
    return tick() * 1000
end

local lastPos = nil
local lastTime = nil
local lastSmooth = nil
local jerkCount = 0   -- счётчик рывков

local function recordMeasurement()
    local char = player.Character
    if not char then
        if textLabel then textLabel.Text = "Нет персонажа" end
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    local now = getMillis()
    local pos = hrp.Position
    local sit = hum.Sit and hum.SeatPart ~= nil
    
    if lastPos and lastTime then
        local deltaTime = (now - lastTime) / 1000   -- секунды
        if deltaTime > 0 then
            local deltaDist = (pos - lastPos).Magnitude
            local speed = deltaDist / deltaTime    -- скорость в студиях/сек
            -- Вычисляем "гладкость": изменение скорости за последние 2 замера
            local smooth = 0
            if lastSmooth then
                smooth = math.abs(speed - lastSmooth) / deltaTime
            end
            lastSmooth = speed
            
            -- Добавляем замер
            table.insert(measurements, {
                t = now,
                pos = pos,
                dt = deltaTime * 1000, -- миллисекунды
                dist = deltaDist,
                speed = speed,
                smooth = smooth,
                sit = sit
            })
            if #measurements > 200 then table.remove(measurements, 1) end
            
            -- Определяем рывок: резкое изменение скорости > 50 студий/сек^2 ИЛИ ускорение > 100
            if smooth > 80 and deltaDist > 0.5 then
                jerkCount = jerkCount + 1
                logToConsole(string.format("[РЫВОК] %.1f мс: ускорение %.1f, скорость %.1f -> %.1f", 
                    now, smooth, lastSmooth or 0, speed))
                if textLabel then
                    textLabel.TextColor3 = Color3.new(1, 0, 0)
                    task.wait(0.2)
                    textLabel.TextColor3 = Color3.new(1, 1, 1)
                end
            end
            
            -- Обновляем GUI каждые ~0.1 сек
            if textLabel and now % 100 < 20 then
                textLabel.Text = string.format(
                    "Скорость: %.1f ст/с\nУскорение: %.1f\nРывков: %d | Сидит: %s",
                    speed, smooth, jerkCount, tostring(sit))
            end
        end
    end
    
    lastPos = pos
    lastTime = now
end

-- Запускаем измерение каждый кадр (или через 0.05 сек)
local connection
connection = runService.RenderStepped:Connect(function(deltaTime)
    -- Используем RenderStepped для синхронизации с отрисовкой (высокая точность)
    recordMeasurement()
end)

-- Каждые 5 секунд выводим статистику в консоль
task.spawn(function()
    while true do
        task.wait(5)
        if #measurements == 0 then continue end
        
        local totalDist = 0
        local maxSpeed = 0
        local avgSpeed = 0
        local maxSmooth = 0
        for i = 2, #measurements do
            local m = measurements[i]
            totalDist = totalDist + m.dist
            if m.speed > maxSpeed then maxSpeed = m.speed end
            if m.smooth > maxSmooth then maxSmooth = m.smooth end
            avgSpeed = avgSpeed + m.speed
        end
        avgSpeed = avgSpeed / (#measurements - 1)
        
        logToConsole("=== СТАТИСТИКА за 5 сек ===")
        logToConsole(string.format("Пройдено: %.1f ст | Средняя скор.: %.1f | Макс скор.: %.1f | Макс ускор.: %.1f | Рывков: %d",
            totalDist, avgSpeed, maxSpeed, maxSmooth, jerkCount))
        logToConsole("Тип движения (предположительно): " ..
            (maxSmooth < 20 and "Tween/плавное" or (maxSmooth < 80 and "BodyVelocity" or "BodyPosition/рывки")))
        logToConsole("============================")
    end
end)

-- Вывод начальной инструкции
logToConsole("Диагност запущен. Наблюдаю за движением персонажа...")
if textLabel then
    textLabel.Text = "Диагност активен. Ожидание движения..."
end

-- При пересоздании персонажа сбрасываем историю
player.CharacterAdded:Connect(function()
    lastPos = nil
    lastTime = nil
    lastSmooth = nil
    jerkCount = 0
    measurements = {}
    logToConsole("Персонаж пересоздан, история сброшена")
end)

-- Опционально: горячая клавиша для вывода подробного отчёта
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F12 then
        logToConsole("=== ПОДРОБНЫЙ ОТЧЁТ (последние " .. #measurements .. " замеров) ===")
        for i, m in ipairs(measurements) do
            logToConsole(string.format("[%d] %.0f мс: Δt=%.1f мс, Δd=%.2f, v=%.1f, a=%.1f, sit=%s",
                i, m.t, m.dt, m.dist, m.speed, m.smooth, tostring(m.sit)))
        end
        logToConsole("=== КОНЕЦ ОТЧЁТА ===")
    end
end)
