loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
-- ===== БЛОКИРАТОР ПЕРЕМЕЩЕНИЙ ПРИ ПОЯВЛЕНИИ ЯЙЦА =====
local player = game.Players.LocalPlayer
local isBlocking = false
local blockThread = nil

-- Функция поиска яйца (любого)
local function findAnyEgg()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "DragonEgg" then
            return obj
        end
        -- Некоторые игры используют Part вместо Model
        if obj:IsA("BasePart") and obj.Name == "DragonEgg" then
            return obj
        end
    end
    return nil
end

-- Функция блокировки позиции на 30 секунд
local function blockMovementFor30Seconds(fixedPosition)
    if blockThread then return end
    blockThread = task.spawn(function()
        print("[БЛОКИРАТОР] Яйцо обнаружено! Фиксирую позицию на 30 секунд...")
        local startTime = os.clock()
        while os.clock() - startTime < 30 do
            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- Возвращаем персонажа на зафиксированную позицию
                    hrp.CFrame = CFrame.new(fixedPosition)
                end
                -- Также можно отключить коллизии, чтобы не застревать
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
            task.wait(0.05) -- частота проверки (20 раз в секунду)
        end
        print("[БЛОКИРАТОР] 30 секунд прошло, блокировка снята")
        blockThread = nil
    end)
end

-- Основной цикл: ждём появления яйца
task.spawn(function()
    while true do
        task.wait(0.5) -- проверяем каждые 0.5 секунды
        local egg = findAnyEgg()
        if egg and not isBlocking then
            isBlocking = true
            local char = player.Character
            local fixedPos = nil
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    fixedPos = hrp.Position
                    print("[БЛОКИРАТОР] Зафиксирована позиция:", fixedPos)
                else
                    fixedPos = Vector3.new(0, 100, 0) -- запасная позиция
                end
            else
                fixedPos = Vector3.new(0, 100, 0)
            end
            blockMovementFor30Seconds(fixedPos)
            -- Ждём, пока яйцо исчезнет или пока не пройдёт 30 секунд
            while egg and egg.Parent do
                task.wait(0.5)
                egg = findAnyEgg()
            end
            isBlocking = false
            print("[БЛОКИРАТОР] Яйцо исчезло, готов к следующему")
        end
    end
end)

print("[БЛОКИРАТОР] Запущен. Ожидание появления DragonEgg...")
