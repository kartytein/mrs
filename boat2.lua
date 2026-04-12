local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- Функция вывода в консоль и в чат
local function log(msg)
    print(msg)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {Text = msg, Color = Color3.new(1,1,0)})
end

log("=== Трекер запущен. Выполните телепортацию вручную ===")

-- Отслеживаем изменение позиции HumanoidRootPart
local lastPos = hrp.Position
hrp:GetPropertyChangedSignal("Position"):Connect(function()
    local newPos = hrp.Position
    local delta = (newPos - lastPos).Magnitude
    if delta > 5 then
        log(string.format("[POS] %s -> %s (дельта %.1f)", lastPos, newPos, delta))
        lastPos = newPos
    end
end)

-- Отслеживаем изменение CFrame
hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
    log("[CFRAME] " .. tostring(hrp.CFrame))
end)

-- Отслеживаем появление BodyVelocity (признак физического движения)
local function onDescendant(desc)
    if desc:IsA("BodyVelocity") then
        log("[BODYVELOCITY] создан у " .. desc.Parent:GetFullName())
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log("[VEL] " .. tostring(desc.Velocity))
        end)
    elseif desc:IsA("BodyPosition") then
        log("[BODYPOSITION] создан у " .. desc.Parent:GetFullName())
    elseif desc:IsA("Tween") then
        log("[TWEEN] создан для " .. desc.Parent:GetFullName())
    end
end

char.DescendantAdded:Connect(onDescendant)
for _, desc in ipairs(char:GetDescendants()) do onDescendant(desc) end

-- Перехват RemoteEvent/RemoteFunction (безопасный, только логирование)
local rs = game:GetService("ReplicatedStorage")
rs.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") then
        log("[REMOTE] RemoteEvent найден: " .. obj:GetFullName())
    elseif obj:IsA("RemoteFunction") then
        log("[REMOTE] RemoteFunction найден: " .. obj:GetFullName())
    end
end)

-- Логирование нажатий клавиш (если телепорт по клавише)
local uis = game:GetService("UserInputService")
uis.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        log("[KEY] Нажата клавиша: " .. input.KeyCode.Name)
    end
end)

log("Трекер активен. Теперь выполните телепортацию (через карту, NPC или команду).")
