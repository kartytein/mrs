-- ============================================================
--  АКТИВАЦИЯ КНОПКИ Option ПО ПОРЯДКОВОМУ НОМЕРУ
--  Замените TARGET_INDEX на нужный (например, 6).
--  Использует полную последовательность сигналов.
--  Работает в Delta (getconnections используется).
-- ============================================================

local TARGET_INDEX = 6  -- <-- измените на номер вашей кнопки

local coreGui = game:GetService("CoreGui")

-- Поиск контейнера с динамическим UID
local container = nil
for _, firstChild in ipairs(coreGui:GetChildren()) do
    local obj = firstChild
    obj = obj:FindFirstChild("redz-library-v5")
    if obj then obj = obj:FindFirstChild("Window") end
    if obj then obj = obj:FindFirstChild("Components") end
    if obj then obj = obj:FindFirstChild("Containers") end
    if obj then obj = obj:FindFirstChild("Container") end
    if obj then
        container = obj
        break
    end
end

if not container then
    print("[Ошибка] Контейнер не найден.")
    return
end

-- Поиск кнопки по индексу (считаем только кликабельные Option)
local btn = nil
local idx = 0
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        idx = idx + 1
        if idx == TARGET_INDEX then
            btn = child
            break
        end
    end
end

if not btn then
    print("[Ошибка] Кнопка с индексом " .. TARGET_INDEX .. " не найдена.")
    return
end

print("Активируем кнопку #" .. TARGET_INDEX .. ": " .. btn:GetFullName())

-- Функция вызова всех обработчиков сигнала
local function fireSignal(signal)
    local ok, connections = pcall(function() return getconnections(signal) end)
    if ok and connections then
        for i = 1, #connections do
            local conn = connections[i]
            if conn and conn.Enabled and type(conn.Function) == "function" then
                conn.Function()
            end
        end
    end
end

-- Полная последовательность (как при ручном клике)
fireSignal(btn.MouseEnter)
fireSignal(btn.MouseButton1Down)
fireSignal(btn.MouseButton1Click)
fireSignal(btn.MouseButton1Up)
fireSignal(btn.Activated)
fireSignal(btn.MouseLeave)

print("[Готово] Последовательность выполнена.")
