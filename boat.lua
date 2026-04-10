-- 1. Плавная посадка на сиденье
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local boat = workspace.Boats.Guardian
if not boat then warn("Лодка не найдена") return end

local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
if not seat then warn("Сиденье не найдено") return end

-- Отключаем коллизии у лодки (чтобы не мешали при посадке)
for _, part in ipairs(boat:GetDescendants()) do
    if part:IsA("BasePart") then part.CanCollide = false end
end

-- Tween к сиденью (чуть выше)
local targetPos = seat.CFrame + Vector3.new(0, 2, 0)
local tween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = targetPos})
tween:Play()
tween.Completed:Wait()

-- Садимся (без присвоения SeatPart)
humanoid.Sit = true
task.wait(0.5) -- даём время сесть

-- 2. Ваш рабочий код движения лодки (проверен)
local boatName = "Guardian"      
local boatsFolder = workspace:FindFirstChild("Boats")
local boat2 = boatsFolder and boatsFolder:FindFirstChild(boatName) or workspace:FindFirstChild(boatName)

if not boat2 then
    warn("Лодка не найдена")
    return
end

local nativeScript = boat2:FindFirstChild("Script")
if nativeScript then
    nativeScript.Disabled = true
    print("Родной скрипт отключён")
end

for _, part in ipairs(boat2:GetDescendants()) do
    if part:IsA("BasePart") then
        part.CanCollide = false
    end
end

local rootPart = boat2.PrimaryPart or boat2:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    warn("Не найдена основная часть лодки")
    return
end

local speed = -420
local runService = game:GetService("RunService")

runService.RenderStepped:Connect(function(deltaTime)
    local step = speed * deltaTime
    rootPart.CFrame = rootPart.CFrame * CFrame.new(0, 0, step)
end)

print("Лодка движется плавно со скоростью", math.abs(speed), "в секунду в сторону -Z")
