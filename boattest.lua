-- Тестовый скрипт: перебор способов движения лодки (вывод в чат)
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Ждём, пока игрок сядет в лодку (чтобы лодка была известна)
local seat = nil
repeat
    task.wait(0.5)
    seat = humanoid.SeatPart
until seat
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then
    error("Лодка не найдена")
end
print("Игрок сидит в лодке:", boat.Name)

-- Функция для вывода сообщения в чат
local function chat(msg)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {Text = msg, Color = Color3.new(0,1,0)})
end

-- Функция для проверки начала движения лодки
local function waitForBoatMove(initialPos)
    local timeout = 5
    local start = tick()
    while tick() - start < timeout do
        local currentPos = boat:GetPivot().Position
        if (currentPos - initialPos).Magnitude > 0.5 then
            return true
        end
        task.wait(0.2)
    end
    return false
end

-- Сохраняем начальную позицию лодки
local startPos = boat:GetPivot().Position

-- Список способов для тестирования
local methods = {
    {
        name = "BodyVelocity на персонажа, скорость -250 по X (как в эталоне)",
        func = function()
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            bv.Velocity = Vector3.new(-250, 0, 0)
            return bv
        end
    },
    {
        name = "BodyVelocity на персонажа, скорость -420 по X (как у нас)",
        func = function()
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            bv.Velocity = Vector3.new(-420, 0, 0)
            return bv
        end
    },
    {
        name = "BodyVelocity на лодку (HumanoidRootPart), скорость -420 по X",
        func = function()
            local root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            if not root then return nil end
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = root
            bv.Velocity = Vector3.new(-420, 0, 0)
            return bv
        end
    },
    {
        name = "BodyVelocity на персонажа, скорость -250 по X, но с отключением коллизий (как в эталоне)",
        func = function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            bv.Velocity = Vector3.new(-250, 0, 0)
            return bv
        end
    },
}

-- Перебираем способы
for i, method in ipairs(methods) do
    chat("Тест " .. i .. ": " .. method.name)
    print("Тест " .. i .. ": " .. method.name)
    local bv = method.func()
    if bv then
        local moved = waitForBoatMove(startPos)
        if moved then
            chat("УСПЕХ! Лодка начала двигаться при способе: " .. method.name)
            print("Успех, лодка движется")
            break
        else
            chat("Не удалось: лодка не двигается при способе " .. i)
            if bv then bv:Destroy() end
        end
    else
        chat("Ошибка: способ " .. i .. " не применим")
    end
    task.wait(1)
end

chat("Тестирование завершено. Если ни один способ не сработал, проверьте, что вы сидите в лодке и эталонный скрипт не активен.")
