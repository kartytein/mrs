-- Диагностический трекер всех изменений позиции персонажа
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local function log(msg)
    print("[TRACKER] " .. msg)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {Text = msg, Color = Color3.new(1,0,0)})
end

-- Отслеживаем изменения CFrame и Position
local lastPos = hrp.Position
hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local newPos = hrp.Position
    log("Position изменилось: " .. tostring(lastPos) .. " -> " .. tostring(newPos))
    lastPos = newPos
end)
hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
    log("CFrame изменилось: " .. tostring(hrp.CFrame))
end)

-- Отслеживаем создание BodyVelocity у персонажа
char.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log("BodyVelocity создан на персонаже, скорость = " .. tostring(desc.Velocity))
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log("BodyVelocity скорость изменена на " .. tostring(desc.Velocity))
        end)
    elseif desc:IsA("BodyPosition") then
        log("BodyPosition создан на персонаже, позиция = " .. tostring(desc.Position))
    elseif desc:IsA("Tween") then
        log("Tween создан на персонаже")
    end
end)

-- Отслеживаем изменения PlatformStand
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log("PlatformStand = " .. tostring(humanoid.PlatformStand))
end)

-- Отслеживаем изменения Sit
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    log("Sit = " .. tostring(humanoid.Sit) .. ", SeatPart = " .. tostring(humanoid.SeatPart))
end)

-- Периодическая проверка наличия BodyVelocity (на случай удаления)
task.spawn(function()
    while true do
        task.wait(1)
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        if bv then
            log("BodyVelocity существует, скорость = " .. tostring(bv.Velocity))
        else
            log("BodyVelocity отсутствует")
        end
    end
end)

log("Трекер запущен. Теперь активируйте эталонный скрипт перемещения к острову. Результаты будут в консоли и в чате.")
