-- ============================================================
--  ПОЛУЧЕНИЕ И ВЫЗОВ ПРИВЯЗАННОЙ ФУНКЦИИ ЧЕРЕЗ getconnections
--  Работает, если Delta поддерживает getconnections (проверьте).
--  Если нет – выведет доступные методы для отладки.
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

-- Находим нужную кнопку по позиции
local targetBtn = nil
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and child:IsA("TextButton") then
        local pos = child.AbsolutePosition
        if math.abs(pos.X - 355.2) < 0.01 and math.abs(pos.Y - 269.6) < 0.01 then
            targetBtn = child
            break
        end
    end
end

if not targetBtn then
    print("[Ошибка] Кнопка не найдена.")
    return
end

print("Кнопка: " .. targetBtn:GetFullName())

-- Попробуем через getconnections (если доступен в Delta)
local function tryFireConnections(signal)
    local success, connections = pcall(function() return getconnections(signal) end)
    if success and connections then
        for i = 1, #connections do
            local conn = connections[i]
            -- Проверяем, что соединение активно и имеет функцию
            if conn and conn.Enabled and type(conn.Function) == "function" then
                print("[getconnections] Вызываем функцию из " .. tostring(signal))
                conn.Function()
                return true
            end
        end
    else
        print("[getconnections] Не удалось для " .. tostring(signal) .. ": " .. tostring(connections))
    end
    return false
end

local fired = false

-- Пробуем MouseButton1Click
if not fired then fired = tryFireConnections(targetBtn.MouseButton1Click) end
-- Пробуем Activated
if not fired then fired = tryFireConnections(targetBtn.Activated) end
-- Пробуем MouseButton1Down
if not fired then fired = tryFireConnections(targetBtn.MouseButton1Down) end
-- Пробуем MouseButton1Up
if not fired then fired = tryFireConnections(targetBtn.MouseButton1Up) end

if fired then
    print("[Готово] Функция хаба успешно вызвана.")
else
    print("Не удалось вызвать функцию через getconnections.")
    print("Проверяем атрибуты и дочерние скрипты кнопки:")
    -- Показываем все атрибуты
    local attrs = targetBtn:GetAttributes()
    if attrs then
        print("Атрибуты:")
        -- Перебор пар ключ-значение (упрощённо, если attrs как таблица)
        for k, v in pairs(attrs) do
            print("  " .. tostring(k) .. " = " .. tostring(v))
        end
    else
        print("  Атрибутов нет.")
    end
    -- Показываем дочерние объекты (может быть BindableEvent или скрипт)
    print("Дети кнопки:")
    for _, child in ipairs(targetBtn:GetChildren()) do
        print("  " .. child.Name .. " (" .. child.ClassName .. ")")
    end
end
