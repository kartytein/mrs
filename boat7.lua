-- 3. Посадка в лодку
local seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then error("Нет сиденья") end
local rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Нет основной части") end

-- Отключаем коллизии у лодки
for _, part in ipairs(myBoat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end
myBoat.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then desc.CanCollide = false end
end)

-- Отключаем родной скрипт лодки (если есть)
local native = myBoat:FindFirstChild("Script")
if native then native.Disabled = true end

-- Посадка на сиденье (BodyVelocity)
local char = player.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local humanoid = char and char:FindFirstChild("Humanoid")
if not hrp or not humanoid then error("Нет HRP/Humanoid") end

local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local function sitOnSeat()
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local targetCF = seat.CFrame + SEAT_OFFSET
    local targetPos = targetCF.Position
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - targetPos).Magnitude > 1.5 do
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * 150
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = targetCF
    humanoid.Sit = true
    task.wait(0.3)
end

sitOnSeat()
print("Посадка выполнена")
