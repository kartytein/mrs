-- ========== ДИАГНОСТИК ВЕРТИКАЛЬНОЙ СТАБИЛИЗАЦИИ ==========
local player = game.Players.LocalPlayer
local runService = game:GetService("RunService")

-- Создаём GUI
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 420, 0, 280)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundTransparency = 0.6
frame.BackgroundColor3 = Color3.new(0,0,0)
frame.BorderSizePixel = 0

local text = Instance.new("TextLabel", frame)
text.Size = UDim2.new(1,0,1,0)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.new(1,1,1)
text.TextSize = 14
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Text = "Ожидание персонажа..."

local function updateDisplay()
    local char = player.Character
    if not char then 
        text.Text = "Нет персонажа"
        return 
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then 
        text.Text = "Нет HRP или Humanoid"
        return 
    end
    
    local y = hrp.Position.Y
    local velY = hrp.Velocity.Y
    local platform = hum.PlatformStand
    local autoRotate = hum.AutoRotate
    local gravity = hum.GravityScale
    local sit = hum.Sit
    local seatPart = hum.SeatPart and hum.SeatPart.Name or "none"
    
    -- Поиск двигателей на персонаже
    local motors = {}
    for _, part in ipairs({hrp, char:FindFirstChild("UpperTorso")}) do
        if part then
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyThrust") then
                    table.insert(motors, string.format("%s (%s)", child.ClassName, child.Parent.Name))
                end
            end
        end
    end
    local motorStr = (#motors > 0) and table.concat(motors, ", ") or "нет"
    
    text.Text = string.format(
        "Y = %.2f\nVelY = %.3f\nPlatformStand = %s\nAutoRotate = %s\nGravityScale = %.2f\nSit = %s\nSeatPart = %s\nДвигатели: %s",
        y, velY, tostring(platform), tostring(autoRotate), gravity, tostring(sit), seatPart, motorStr
    )
end

task.spawn(function()
    while true do
        updateDisplay()
        task.wait(0.1)
    end
end)

print("🔍 Диагностик запущен. Наблюдаю за вертикалью.")
