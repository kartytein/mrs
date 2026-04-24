-- ===== ДВИЖЕНИЕ ЛОДКИ НА ФИКСИРОВАННОЙ ВЫСОТЕ (Y = 50) БЕЗ КОЛЛИЗИЙ =====
local player = game.Players.LocalPlayer
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local BOAT_POINT_A = Vector3.new(-77389.3, 50, 32606.2)
local BOAT_POINT_B = Vector3.new(-47968.4, 50, 6048.2)
local BOAT_SPEED = 420

-- Ждём посадки
local function waitForSeat()
    local char = player.Character
    if not char then return nil end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return nil end
    repeat
        task.wait(0.5)
    until humanoid.Sit and humanoid.SeatPart
    return humanoid.SeatPart
end

print("Ожидание посадки в лодку...")
local seat = waitForSeat()
if not seat then
    warn("Не удалось обнаружить сиденье")
    return
end

local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then
    warn("Лодка не найдена")
    return
end

local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    warn("Основная часть лодки не найдена")
    return
end

-- Отключаем гравитацию и поднимаем лодку один раз
local bodyGyro = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
bodyGyro.CFrame = rootPart.CFrame
bodyGyro.Parent = rootPart

local bodyPosition = Instance.new("BodyPosition")
bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bodyPosition.Parent = rootPart
bodyPosition.Position = Vector3.new(rootPart.Position.X, 50, rootPart.Position.Z)

-- Поднимаем
rootPart.CFrame = CFrame.new(rootPart.Position.X, 50, rootPart.Position.Z)
print("Лодка поднята на высоту 50 и удерживается")

-- Циклическое движение через Tween (не затрагивает Y, так как Y фиксирован BodyPosition)
local points = {BOAT_POINT_A, BOAT_POINT_B}
local index = 1
local currentTween = nil

local function moveToNext()
    local target = points[index]
    -- Сохраняем текущую Y (она должна быть 50), но Tween будет менять X и Z
    local currentPos = rootPart.Position
    local targetCF = CFrame.new(target.X, currentPos.Y, target.Z)
    local dist = (rootPart.Position - targetCF.Position).Magnitude
    local duration = dist / BOAT_SPEED
    if duration > 0 then
        currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCF})
        currentTween:Play()
        currentTween.Completed:Connect(function()
            currentTween = nil
            index = index % #points + 1
            moveToNext()
        end)
    end
end

moveToNext()
