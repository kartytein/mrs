local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local targetX = hrp.Position.X + 200
local startY = hrp.Position.Y  -- запоминаем начальную высоту
local speed = 150
local step = 0.05

-- Отключаем коллизии и замораживаем
for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
humanoid.PlatformStand = true

while true do
    local currentX = hrp.Position.X
    if math.abs(currentX - targetX) < 0.5 then break end
    local direction = (targetX - currentX) > 0 and 1 or -1
    local move = math.min(speed * step, math.abs(targetX - currentX))
    local newX = currentX + direction * move
    hrp.CFrame = CFrame.new(newX, startY, hrp.Position.Z)  -- фиксируем Y
    task.wait(step)
end

hrp.CFrame = CFrame.new(targetX, startY, hrp.Position.Z)
humanoid.PlatformStand = false
print("Перемещение по X завершено")
