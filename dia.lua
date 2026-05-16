-- ========== ЛОГГЕР ПАРАМЕТРОВ УДЕРЖАНИЯ ==========
local player = game.Players.LocalPlayer

-- Ждём появления персонажа
local function waitForCharacter()
    if player.Character then return player.Character end
    return player.CharacterAdded:Wait()
end

local char = waitForCharacter()
print("[ЛОГГЕР] Персонаж появился, начинаем сбор данных")

-- Основной цикл
while true do
    task.wait(1) -- раз в секунду
    
    local char = player.Character
    if not char then 
        print("[ЛОГГЕР] Нет персонажа")
        continue
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then
        print("[ЛОГГЕР] Нет HRP или Humanoid")
        continue
    end
    
    -- Собираем информацию о двигателях на персонаже
    local motors = {}
    local upper = char:FindFirstChild("UpperTorso")
    for _, part in ipairs({hrp, upper}) do
        if part then
            for _, child in ipairs(part:GetChildren()) do
                local c = child.ClassName
                if c == "BodyVelocity" or c == "BodyPosition" or c == "BodyGyro" or c == "BodyThrust" or c == "LinearVelocity" or c == "AlignPosition" then
                    local info = c
                    if c == "BodyVelocity" then
                        info = info .. string.format(" VelY=%.4f", child.Velocity.Y)
                    elseif c == "BodyPosition" then
                        info = info .. string.format(" PosY=%.2f", child.Position.Y)
                    end
                    table.insert(motors, info .. " on " .. part.Name)
                end
            end
        end
    end
    local motorStr = (#motors > 0) and table.concat(motors, "; ") or "нет"
    
    -- Выводим всё в консоль
    print(string.format(
        "[%.1f] Y=%.2f | VelY=%.3f | Platform=%s | AutoRotate=%s | Gravity=%.2f | Sit=%s | Motors: %s",
        tick(),
        hrp.Position.Y,
        hrp.Velocity.Y,
        tostring(hum.PlatformStand),
        tostring(hum.AutoRotate),
        hum.GravityScale,
        tostring(hum.Sit),
        motorStr
    ))
end
