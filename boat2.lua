-- ============================================================
--  ПОИСК И АКТИВАЦИЯ КАСТОМНОГО СОБЫТИЯ КНОПКИ Option
--  Диагностика показала события: Button1Down, Button1Click, Button1Up
--  Вероятно, это BindableEvents внутри кнопки. Ищем и вызываем.
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

-- Ищем Option по координатам (можно также задать индекс)
local targetOption = nil
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        local pos = child.AbsolutePosition
        if math.abs(pos.X - 355.2) < 0.01 and math.abs(pos.Y - 269.6) < 0.01 then
            targetOption = child
            break
        end
    end
end

if not targetOption then
    print("[Ошибка] Кнопка не найдена по позиции.")
    return
end

print("Кнопка найдена: " .. targetOption:GetFullName())

-- Поиск дочерних BindableEvent с нужными именами
local function findBindable(parent, name)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("BindableEvent") and child.Name == name then
            return child
        end
    end
    return nil
end

local eventToFire = nil
-- Ищем в самой кнопке
eventToFire = findBindable(targetOption, "Button1Click")
if not eventToFire then
    -- Может, события лежат в родителе или где-то ещё
    eventToFire = findBindable(targetOption.Parent, "Button1Click")
end

if eventToFire then
    eventToFire:Fire()
    print("[Эмуляция] BindableEvent 'Button1Click' вызван.")
else
    -- Выводим всех детей кнопки и родителя для ручного анализа
    print("=== Дети кнопки (возможные события) ===")
    for _, child in ipairs(targetOption:GetChildren()) do
        print("  " .. child.Name .. " (" .. child.ClassName .. ")")
    end
    print("=== Дети родителя ===")
    for _, child in ipairs(targetOption.Parent:GetChildren()) do
        print("  " .. child.Name .. " (" .. child.ClassName .. ")")
    end
    print("Не удалось найти BindableEvent 'Button1Click'. Проверьте вывод выше.")
end
