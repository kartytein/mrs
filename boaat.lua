-- ============================================================
--  ДИАГНОСТИКА СОБЫТИЙ КНОПКИ (по позиции 355.199951, 269.599976)
--  Подключается к ВСЕМ возможным событиям кнопки.
--  Кликните вручную по нужной Option – в консоли появится
--  название сработавшего события.
--  После этого можно будет эмулировать именно это событие.
-- ============================================================

local coreGui = game:GetService("CoreGui")

-- Поиск контейнера (динамический UID)
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

-- Ищем Option с позицией 355.199951, 269.599976
local targetOption = nil
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        local pos = child.AbsolutePosition
        -- Сравниваем с погрешностью 0.01
        if math.abs(pos.X - 355.2) < 0.01 and math.abs(pos.Y - 269.6) < 0.01 then
            targetOption = child
            break
        end
    end
end

if not targetOption then
    print("[Ошибка] Кнопка Option с позицией 355.2, 269.6 не найдена.")
    return
end

print("Диагностическая кнопка: " .. targetOption:GetFullName())

-- Подключаемся к стандартным событиям (без таблиц)
targetOption.MouseButton1Click:Connect(function()
    print(">>> Сработало событие: MouseButton1Click")
end)
targetOption.MouseButton1Down:Connect(function()
    print(">>> Сработало событие: MouseButton1Down")
end)
targetOption.MouseButton1Up:Connect(function()
    print(">>> Сработало событие: MouseButton1Up")
end)
targetOption.MouseButton2Click:Connect(function()
    print(">>> Сработало событие: MouseButton2Click")
end)
targetOption.MouseButton2Down:Connect(function()
    print(">>> Сработало событие: MouseButton2Down")
end)
targetOption.MouseButton2Up:Connect(function()
    print(">>> Сработало событие: MouseButton2Up")
end)
targetOption.Activated:Connect(function()
    print(">>> Сработало событие: Activated")
end)
targetOption.MouseEnter:Connect(function()
    print(">>> Сработало событие: MouseEnter")
end)
targetOption.MouseLeave:Connect(function()
    print(">>> Сработало событие: MouseLeave")
end)
-- Если есть Touch-события (для мобильных)
if targetOption:IsA("GuiButton") then -- TextButton и ImageButton наследуют GuiButton
    pcall(function() -- на случай отсутствия события
        targetOption.TouchTap:Connect(function()
            print(">>> Сработало событие: TouchTap")
        end)
    end)
end

print("Диагностика готова. Нажмите ВРУЧНУЮ на кнопку в игре и посмотрите, что выведется.")
print("============================================")
