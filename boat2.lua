local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local function log(msg)
    print(msg)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {Text = msg, Color = Color3.new(1,1,0)})
end

log("=== Трекер запущен. Активируйте эталонный скрипт перемещения ===")

-- Отслеживаем изменения позиции
local lastPos = hrp.Position
hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local newPos = hrp.Position
    if (newPos - lastPos).Magnitude > 0.1 then
        log("[POS] " .. lastPos .. " -> " .. newPos)
        lastPos = newPos
    end
end)

-- Отслеживаем изменения PlatformStand
humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log("[PLATFORMSTAND] = " .. tostring(humanoid.PlatformStand))
end)

-- Отслеживаем изменения CanCollide у частей персонажа
local function trackCollisions(part)
    if part:IsA("BasePart") then
        local old = part.CanCollide
        part:GetPropertyChangedSignal("CanCollide"):Connect(function()
            log("[COLLIDE] " .. part.Name .. " -> " .. tostring(part.CanCollide))
        end)
    end
end
for _, part in ipairs(char:GetDescendants()) do
    trackCollisions(part)
end
char.DescendantAdded:Connect(trackCollisions)

-- Отслеживаем появление BodyVelocity и BodyPosition
char.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log("[BODYVELOCITY] создан, Velocity = " .. tostring(desc.Velocity))
    elseif desc:IsA("BodyPosition") then
        log("[BODYPOSITION] создан, Position = " .. tostring(desc.Position))
    elseif desc:IsA("Tween") then
        log("[TWEEN] найден")
    end
end)

-- Отслеживаем изменения WalkSpeed (возможно, отключается)
humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
    log("[WALKSPEED] = " .. tostring(humanoid.WalkSpeed))
end)

log("Трекер активен, запустите эталонный скрипт")
