-- 2. Перемещение к точке и призыв лодки
local player = game.Players.LocalPlayer
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local WALK_SPEED = 150

local function moveToPoint(targetPos, speed)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end
    -- Отключаем коллизии
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    while (hrp.Position - targetPos).Magnitude > 2 do
        local direction = (targetPos - hrp.Position).Unit
        bv.Velocity = direction * speed
        task.wait()
    end
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    return true
end

moveToPoint(MOVE_POINT, WALK_SPEED)

-- Призыв лодки
local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
remote:InvokeServer("BuyBoat", "Guardian")
task.wait(3)

-- Поиск своей лодки (по Owner)
local function findMyBoat()
    local boatsFolder = workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        if boat:IsA("Model") and boat:FindFirstChildWhichIsA("VehicleSeat") then
            local ownerAttr = boat:GetAttribute("Owner")
            if ownerAttr == player.Name then return boat end
            local ownerObj = boat:FindFirstChild("Owner")
            if ownerObj and (ownerObj:IsA("StringValue") or ownerObj:IsA("ObjectValue")) then
                if tostring(ownerObj.Value) == player.Name then return boat end
            end
        end
    end
    return nil
end

local myBoat = nil
for i = 1, 10 do
    myBoat = findMyBoat()
    if myBoat then break end
    task.wait(1)
end
if not myBoat then error("Лодка не найдена") end
print("Лодка найдена:", myBoat.Name)
