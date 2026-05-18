loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
-- ===== АВТОМАТИЧЕСКАЯ ФИКСАЦИЯ ПРИ ПОЯВЛЕНИИ ЯЙЦА НА 30 СЕК =====
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer

local isBlocking = false        -- заблокировано ли сейчас
local fixedPosition = nil       -- сохранённая позиция
local blockThread = nil         -- поток блокировки
local searchInterval = 0.2      -- частота поиска яйца (5 раз в секунду)

-- Функция поиска любого яйца (DragonEgg)
local function findAnyEgg()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "DragonEgg" then
            return true
        end
        if obj:IsA("BasePart") and obj.Name == "DragonEgg" then
            return true
        end
    end
    return false
end

-- Функция блокировки (активный возврат позиции)
local function startBlocking(pos)
    if isBlocking then return end
    isBlocking = true
    fixedPosition = pos
    print("[БЛОК] Яйцо появилось! Фиксирую позицию:", fixedPosition, "на 30 секунд")

    local startTime = os.clock()
    local connection = nil
    connection = RunService.RenderStepped:Connect(function()
        if not isBlocking then
            if connection then connection:Disconnect() end
            return
        end
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(fixedPosition)
            end
            -- Доп. отключение коллизий (чтобы не упираться)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)

    -- Ждём 30 секунд
    task.wait(30)
    isBlocking = false
    fixedPosition = nil
    if connection then connection:Disconnect() end
    print("[БЛОК] 30 секунд прошло, блокировка снята")
end

-- Основной цикл: быстрый поиск яйца
task.spawn(function()
    while true do
        if not isBlocking then
            local eggPresent = findAnyEgg()
            if eggPresent then
                -- Яйцо появилось: запоминаем текущую позицию персонажа
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        startBlocking(hrp.Position)
                    else
                        print("[БЛОК] HRP не найден, не могу заблокировать")
                    end
                else
                    print("[БЛОК] Персонаж отсутствует")
                end
                -- Небольшая пауза, чтобы не запускать повторно при том же яйце
                task.wait(0.5)
            end
        end
        task.wait(searchInterval)
    end
end)

print("[БЛОК] Скрипт запущен. Ожидание появления DragonEgg...")
