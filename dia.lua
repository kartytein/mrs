-- ========== ДИАГНОСТИК УДЕРЖАНИЯ ВЫСОТЫ (ПАССИВНЫЙ) ==========
local player = game.Players.LocalPlayer
local runService = game:GetService("RunService")

-- GUI
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 450, 0, 320)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundTransparency = 0.5
frame.BackgroundColor3 = Color3.new(0,0,0)
frame.BorderSizePixel = 0

local text = Instance.new("TextLabel", frame)
text.Size = UDim2.new(1,0,1,0)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.new(1,1,0)
text.TextSize = 14
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Text = "Сбор данных..."

local function getMotorsInfo()
    local char = player.Character
    if not char then return "нет персонажа" end
    local info = {}
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local upper = char:FindFirstChild("UpperTorso")
    for _, part in ipairs({hrp, upper}) do
        if part then
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("BodyVelocity") then
                    table.insert(info, string.format("BodyVelocity Y=%.4f (Force Y=%s)", child.Velocity.Y, tostring(child.MaxForce.Y)))
                elseif child:IsA("BodyPosition") then
                    table.insert(info, string.format("BodyPosition Y=%.2f (Force Y=%s)", child.Position.Y, tostring(child.MaxForce.Y)))
                elseif child:IsA("BodyGyro") then
                    table.insert(info, "BodyGyro present")
                elseif child:IsA("BodyThrust") then
                    table.insert(info, "BodyThrust")
                end
            end
        end
    end
    if #info == 0 then return "нет двигателей" end
    return table.concat(info, "; ")
end

local function update()
    local char = player.Character
    if not char then
        text.Text = "Нет персонажа"
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then
        text.Text = "Нет HRP/Humanoid"
        return
    end
    
    local y = hrp.Position.Y
    local velY = hrp.Velocity.Y
    local platform = hum.PlatformStand
    local autoRotate = hum.AutoRotate
    local gravityScale = hum.GravityScale
    local sit = hum.Sit
    local motors = getMotorsInfo()
    
    text.Text = string.format(
        [[Y = %.2f
Верт. скорость = %.3f ст/с
PlatformStand = %s
AutoRotate = %s
GravityScale = %.2f
Sit = %s
Двигатели: %s]],
        y, velY, tostring(platform), tostring(autoRotate), gravityScale, tostring(sit), motors
    )
end

task.spawn(function()
    while true do
        update()
        task.wait(0.1)
    end
end)

print("Диагност удержания высоты запущен. Зафиксируйте параметры.")
