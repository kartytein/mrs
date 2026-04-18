-- ===== БЕЗОПАСНЫЙ ЛОГГЕР (без модификации Instance.new) =====
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

-- Отслеживаем появление объектов в workspace
workspace.ChildAdded:Connect(function(child)
    log("WS + " .. child:GetFullName() .. " (" .. child.ClassName .. ")")
end)
workspace.ChildRemoved:Connect(function(child)
    log("WS - " .. child:GetFullName())
end)

-- Отслеживаем появление любых объектов в игре (для поиска лодки)
local function watchForBoat(desc)
    if desc.Name == "Guardian" and desc:IsA("Model") then
        log("!!! ЛОДКА НАЙДЕНА: " .. desc:GetFullName())
        -- Отслеживаем изменения её частей
        local function watchPart(part)
            if part:IsA("BasePart") then
                part:GetPropertyChangedSignal("Position"):Connect(function()
                    log("Boat " .. part:GetFullName() .. " Position = " .. tostring(part.Position))
                end)
                part:GetPropertyChangedSignal("CFrame"):Connect(function()
                    log("Boat " .. part:GetFullName() .. " CFrame changed")
                end)
                part:GetPropertyChangedSignal("CanCollide"):Connect(function()
                    log("Boat " .. part:GetFullName() .. " CanCollide = " .. tostring(part.CanCollide))
                end)
            end
            if part:IsA("BodyVelocity") then
                part:GetPropertyChangedSignal("Velocity"):Connect(function()
                    log("Boat BodyVelocity Velocity = " .. tostring(part.Velocity))
                end)
            end
        end
        for _, part in ipairs(desc:GetDescendants()) do
            watchPart(part)
        end
        desc.DescendantAdded:Connect(watchPart)
    end
end

game:GetService("Workspace").DescendantAdded:Connect(watchForBoat)
-- Проверяем уже существующие объекты
for _, desc in ipairs(workspace:GetDescendants()) do
    watchForBoat(desc)
end

-- Отслеживаем изменения персонажа
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local lastPos = hrp.Position

hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local newPos = hrp.Position
    if (newPos - lastPos).Magnitude > 0.5 then
        log("CHAR POS: " .. tostring(newPos))
        lastPos = newPos
    end
end)

humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
    log("PLATFORMSTAND = " .. tostring(humanoid.PlatformStand))
end)
humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
    log("SIT = " .. tostring(humanoid.Sit) .. ", SeatPart = " .. tostring(humanoid.SeatPart))
end)

-- Отслеживаем изменения коллизий у персонажа (LowerTorso, UpperTorso)
local function watchCharPart(part)
    if part:IsA("BasePart") then
        part:GetPropertyChangedSignal("CanCollide"):Connect(function()
            log("CHAR " .. part.Name .. " CanCollide = " .. tostring(part.CanCollide))
        end)
    end
end
for _, part in ipairs(char:GetDescendants()) do
    watchCharPart(part)
end
char.DescendantAdded:Connect(watchCharPart)

log("Безопасный логгер запущен. Теперь активируйте эталонный скрипт.")
