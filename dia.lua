-- ========== РАСШИРЕННЫЙ ДИАГНОСТИК ВЕРТИКАЛИ И ДВИЖЕНИЯ ==========
-- Отслеживает ВСЁ, что влияет на плавность: Y-позиция, GravityScale, PlatformStand, AutoRotate, двигатели.

local player = game.Players.LocalPlayer
local runService = game:GetService("RunService")
local userInput = game:GetService("UserInputService")

-- Хранилище замеров (последние 200)
local measurements = {}   -- каждый: { time, y, deltaY, platform, autoRotate, gravityScale, motorInfo }

local function getTimestampMS()
    return tick() * 1000
end

local function logToConsole(msg)
    print(string.format("[%.0f] %s", getTimestampMS(), msg))
end

-- Проверяет наличие двигателей на персонаже и лодке (если сидит)
local function getMotorInfo()
    local char = player.Character
    if not char then return "нет персонажа" end
    local info = {}
    local upper = char:FindFirstChild("UpperTorso")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    for _, part in ipairs({upper, hrp}) do
        if part then
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyThrust") or child:IsA("BodyGyro") then
                    local vel = child:IsA("BodyVelocity") and child.Velocity or nil
                    local pos = child:IsA("BodyPosition") and child.Position or nil
                    local yVel = vel and string.format("Y=%.3f", vel.Y) or ""
                    local yPos = pos and string.format("Y=%.2f", pos.Y) or ""
                    table.insert(info, string.format("%s on %s %s %s", child.ClassName, part.Name, yVel, yPos))
                end
            end
        end
    end
    if #info == 0 then return "нет двигателей" end
    return table.concat(info, "; ")
end

local lastY = nil
local lastTime = nil

local function recordFrame()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    local now = getTimestampMS()
    local y = hrp.Position.Y
    local platform = hum.PlatformStand
    local autoRotate = hum.AutoRotate
    local gravityScale = hum.GravityScale
    local motorInfo = getMotorInfo()

    if lastY and lastTime then
        local dt = (now - lastTime) / 1000
        if dt > 0.001 then
            local deltaY = y - lastY
            local verticalSpeed = deltaY / dt
            -- Записываем ВСЕ замеры, но в консоль выводим только при колебании >0.2 студий
            table.insert(measurements, {
                t = now,
                y = y,
                deltaY = deltaY,
                speed = verticalSpeed,
                platform = platform,
                autoRotate = autoRotate,
                gravityScale = gravityScale,
                motor = motorInfo
            })
            if #measurements > 300 then table.remove(measurements, 1) end

            if math.abs(deltaY) > 0.2 then
                logToConsole(string.format(
                    "📊 КОЛЕБАНИЕ: dY=%.3f | speed=%.1f | platform=%s | autoRotate=%s | gravity=%.2f | %s",
                    deltaY, verticalSpeed, tostring(platform), tostring(autoRotate), gravityScale, motorInfo
                ))
            end
        end
    end

    lastY = y
    lastTime = now
end

-- Запускаем частую запись (каждый рендер)
runService.RenderStepped:Connect(recordFrame)

-- Каждые 5 секунд – средняя амплитуда колебаний
task.spawn(function()
    while true do
        task.wait(5)
        if #measurements == 0 then
            logToConsole("Нет измерений (возможно, нет персонажа)")
        else
            local totalAbsDelta = 0
            local maxDelta = 0
            local count = 0
            for _, m in ipairs(measurements) do
                totalAbsDelta = totalAbsDelta + math.abs(m.deltaY)
                if math.abs(m.deltaY) > maxDelta then maxDelta = math.abs(m.deltaY) end
                count = count + 1
            end
            local avgDelta = totalAbsDelta / count
            logToConsole(string.format("📈 Статистика за 5с: среднее dY=%.4f, макс dY=%.3f (записей %d)", avgDelta, maxDelta, count))
            if maxDelta > 0.5 then
                logToConsole("⚠️ ВЫСОКИЕ ВЕРТИКАЛЬНЫЕ КОЛЕБАНИЯ! (max dY > 0.5)")
            end
        end
    end
end)

-- Отчёт по F12 (подробные все измерения)
userInput.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F12 then
        logToConsole("================ ПОДРОБНЫЙ ОТЧЁТ ================")
        for i, m in ipairs(measurements) do
            logToConsole(string.format("[%d] t=%.0f | Y=%.2f | dY=%.4f | v=%.1f | plat=%s | rot=%s | grav=%.2f | %s",
                i, m.t, m.y, m.deltaY, m.speed, tostring(m.platform), tostring(m.autoRotate), m.gravityScale, m.motor))
        end
        logToConsole("================ КОНЕЦ ОТЧЁТА ================")
    end
end)

logToConsole("🔍 Диагностик запущен. Отслеживаю вертикаль. Нажмите F12 для подробного отчёта.")
