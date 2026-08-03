-- ============================================================
--  ПОЛНАЯ ЭМУЛЯЦИЯ ПОСЛЕДОВАТЕЛЬНОСТИ СОБЫТИЙ КЛИКА
--  Вызывает функции из всех сигналов в том же порядке,
--  что и при ручном нажатии.
--  Использует getconnections (доступен в Delta).
-- ============================================================

local coreGui = game:GetService("CoreGui")

-- Поиск контейнера
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

-- Ищем нужную Option (по позиции)
local btn = nil
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and child:IsA("TextButton") then
        local pos = child.AbsolutePosition
        if math.abs(pos.X - 355.2) < 0.01 and math.abs(pos.Y - 269.6) < 0.01 then
            btn = child
            break
        end
    end
end

if not btn then
    print("[Ошибка] Кнопка не найдена.")
    return
end

print("Кнопка: " .. btn:GetFullName())

-- Вспомогательная функция вызова всех обработчиков для заданного сигнала
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

-- Последовательность, идентичная ручному клику
print("Эмуляция последовательности...")
fireSignal(btn.MouseEnter)             -- >>> MouseEnter
fireSignal(btn.MouseButton1Down)       -- >>> MouseButton1Down
fireSignal(btn.MouseButton1Click)      -- >>> MouseButton1Click
fireSignal(btn.MouseButton1Up)         -- >>> MouseButton1Up
fireSignal(btn.Activated)              -- >>> Activated
fireSignal(btn.MouseLeave)             -- >>> MouseLeave

print("[Готово] Полная последовательность выполнена.")
