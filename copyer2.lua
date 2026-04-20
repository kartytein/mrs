-- ===== ДИАГНОСТИКА ПРОБЛЕМЫ С BODYVELOCITY =====
local player = game.Players.LocalPlayer
local char = player.Character
if not char then
    warn("Персонаж не загружен")
    return
end
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hrp then
    warn("Нет HumanoidRootPart")
    return
end
local humanoid = char:FindFirstChild("Humanoid")
if not humanoid then
    warn("Нет Humanoid")
    return
end
local seat = humanoid.SeatPart
if not seat then
    warn("Вы не сидите на сиденье")
    return
end
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then
    warn("Сиденье не принадлежит лодке")
    return
end
local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    warn("У лодки нет основной части")
    return
end

print("========== ДИАГНОСТИКА ==========")
print("1. Персонаж сидит на сиденье:", humanoid.Sit, "SeatPart =", seat:GetFullName())
print("2. Лодка:", boat.Name)
print("3. HumanoidRootPart существует:", hrp ~= nil)
print("4. Текущая позиция персонажа:", hrp.Position)
print("5. Текущая позиция лодки (rootPart):", rootPart.Position)

-- Проверка BodyVelocity на персонаже
local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
if bv then
    print("6. BodyVelocity найден на персонаже, Velocity =", bv.Velocity)
    print("   MaxForce =", bv.MaxForce)
    print("   Parent =", bv.Parent:GetFullName())
else
    print("6. BodyVelocity на персонаже ОТСУТСТВУЕТ")
end

-- Проверка, есть ли другие силы, мешающие движению (BodyVelocity на лодке, Anchored и т.д.)
local boatBv = rootPart:FindFirstChildWhichIsA("BodyVelocity")
if boatBv then
    print("7. BodyVelocity найден на лодке, Velocity =", boatBv.Velocity)
end

local boatBp = rootPart:FindFirstChildWhichIsA("BodyPosition")
if boatBp then
    print("8. BodyPosition найден на лодке, Position =", boatBp.Position)
end

print("9. Anchored лодки (rootPart):", rootPart.Anchored)
print("10. CanCollide лодки (rootPart):", rootPart.CanCollide)

-- Проверка коллизий персонажа
local lower = char:FindFirstChild("LowerTorso")
local upper = char:FindFirstChild("UpperTorso")
if lower then print("11. LowerTorso CanCollide =", lower.CanCollide) end
if upper then print("12. UpperTorso CanCollide =", upper.CanCollide) end

-- Проверка, не заблокировано ли движение другими объектами (например, лодка стоит на месте)
print("13. Свободное пространство вокруг лодки (примерно):")
local rayOrigin = rootPart.Position + Vector3.new(0, 2, 0)
local rayDirection = Vector3.new(1, 0, 0)  -- вправо
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = {boat, char}
local rayResult = workspace:Raycast(rayOrigin, rayDirection * 10, rayParams)
if rayResult then
    print("   Справа препятствие на расстоянии", rayResult.Distance)
else
    print("   Справа свободно")
end

rayDirection = Vector3.new(-1, 0, 0) -- влево
rayResult = workspace:Raycast(rayOrigin, rayDirection * 10, rayParams)
if rayResult then
    print("   Слева препятствие на расстоянии", rayResult.Distance)
else
    print("   Слева свободно")
end

-- Проверка, не отключена ли физика у персонажа
print("14. Humanoid.PlatformStand =", humanoid.PlatformStand)
print("15. Humanoid.Sit =", humanoid.Sit)

-- Проверка, не заблокирована ли скорость (например, из-за оглушения)
print("16. Humanoid.WalkSpeed =", humanoid.WalkSpeed)
print("17. Humanoid.JumpPower =", humanoid.JumpPower)

-- Проверка, не является ли лодка частью другого механизма (например, привязана к другому объекту)
local weldConstraints = rootPart:FindFirstChildWhichIsA("WeldConstraint")
if weldConstraints then
    print("18. Есть WeldConstraint, привязывающий лодку к", weldConstraints.Part1 and weldConstraints.Part1.Name or "nil")
end

print("========== КОНЕЦ ДИАГНОСТИКИ ==========")
