-- ========== ДИАГНОСТИКА ПЕРВОЙ ПОСАДКИ vs ПОВТОРНОЙ ==========
local player = game.Players.LocalPlayer
local startTime = tick()
local phase = "waiting"

local function log(msg)
    local now = (tick() - startTime) * 1000
    print(string.format("[%.0fms] %s", now, msg))
end

-- Отслеживаем покупку/появление лодки
local boatsFolder = workspace:FindFirstChild("Boats")
if boatsFolder then
    boatsFolder.ChildAdded:Connect(function(boat)
        if boat:IsA("Model") then
            task.wait(0.5)
            local owner = boat:GetAttribute("Owner") or (boat:FindFirstChild("Owner") and boat.Owner.Value)
            if owner == player.Name then
                log("!!! НОВАЯ ЛОДКА ПОЯВИЛАСЬ: " .. boat.Name)
                phase = "new_boat"
            end
        end
    end)
end

-- Фиксируем параметры каждые 0.1 сек
while true do
    task.wait(0.1)
    local char = player.Character
    if not char then continue end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then continue end
    
    local sit = hum.Sit
    local seat = hum.SeatPart
    local platform = hum.PlatformStand
    local hrpVelY = hrp.Velocity.Y
    local y = hrp.Position.Y
    
    -- Информация о BodyVelocity на UpperTorso
    local upper = char:FindFirstChild("UpperTorso")
    local bvVelY = nil
    if upper then
        for _, child in ipairs(upper:GetChildren()) do
            if child:IsA("BodyVelocity") then
                bvVelY = child.Velocity.Y
                break
            end
        end
    end
    
    -- Информация о лодке (если сидит)
    local boatY = nil
    if seat then
        local boatModel = seat.Parent
        local rootPart = boatModel.PrimaryPart or boatModel:FindFirstChildWhichIsA("BasePart")
        if rootPart then boatY = rootPart.Position.Y end
    end
    
    log(string.format("Y=%.2f | VelY=%.3f | Sit=%s | BV_Y=%s | Plat=%s | BoatY=%s",
        y, hrpVelY, tostring(sit), bvVelY and string.format("%.4f", bvVelY) or "none", tostring(platform), boatY or "none"))
    
    -- Фиксируем резкий подъём лодки (по Y персонажа, т.к. сидит)
    if sit and lastY and y - lastY > 0.5 then
        log("🚀 РЕЗКИЙ ПОДЪЁМ! dY=" .. string.format("%.2f", y - lastY))
    end
    lastY = y
end
