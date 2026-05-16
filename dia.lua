-- ========== ЛОГГЕР ПЕРВИЧНОЙ ПОСАДКИ (РАБОТАЕТ В ФОНЕ) ==========
local player = game.Players.LocalPlayer
local startTime = tick()

local function log(msg)
    local now = (tick() - startTime) * 1000
    print(string.format("[%.1fms] %s", now, msg))
end

local function getBodyVelocityInfo()
    local char = player.Character
    if not char then return "Нет персонажа" end
    local upper = char:FindFirstChild("UpperTorso")
    if not upper then return "Нет UpperTorso" end
    for _, child in ipairs(upper:GetChildren()) do
        if child:IsA("BodyVelocity") then
            return string.format("BodyVelocity: Vel=(%.2f, %.4f, %.2f) MaxForce=(%s,%s,%s)",
                child.Velocity.X, child.Velocity.Y, child.Velocity.Z,
                tostring(child.MaxForce.X), tostring(child.MaxForce.Y), tostring(child.MaxForce.Z))
        end
    end
    return "BodyVelocity ОТСУТСТВУЕТ"
end

-- Основной цикл логирования (каждые 50 мс)
task.spawn(function()
    local lastY = nil
    while true do
        task.wait(0.05)
        local char = player.Character
        if not char then
            log("Ожидание персонажа...")
            continue
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then
            log("Нет HRP или Humanoid")
            continue
        end
        
        local y = hrp.Position.Y
        local velY = hrp.Velocity.Y
        local sit = hum.Sit
        local seatPart = hum.SeatPart and hum.SeatPart.Name or "none"
        local platform = hum.PlatformStand
        local bvInfo = getBodyVelocityInfo()
        
        -- Выводим строку каждые 50 мс
        log(string.format("Y=%.2f | VelY=%.3f | Sit=%s | Seat=%s | Platform=%s | %s",
            y, velY, tostring(sit), seatPart, tostring(platform), bvInfo))
        
        -- Фиксируем резкий скачок Y (более 0.5 студий)
        if lastY and math.abs(y - lastY) > 0.5 then
            log(string.format("⚠️ РЕЗКИЙ СКАЧОК Y: %.2f -> %.2f (dY=%.2f)", lastY, y, y - lastY))
        end
        lastY = y
    end
end)

log("Логгер запущен. Выполните первичную посадку и скопируйте вывод консоли (F9).")
