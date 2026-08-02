-- =====================================================================
--  ТРЕКЕР КЛИКОВ ПО КНОПКЕ OPTION (исправленный)
--  Вставьте в консоль Delta после загрузки HUB.
--  Скрипт находит кнопку Option (которая оказалась Frame) и ищет внутри неё все дочерние кнопки,
--  вешает обработчики на их события MouseButton1Click / Activated.
--  При клике выводит стек вызовов.
-- =====================================================================

print("=== ТРЕКЕР КЛИКОВ ПО КНОПКЕ OPTION (исправленный) ===")

local path = "CoreGui.5254c01c4691269e68d25763275f564b3f6d90d88346ad2f0bba357e7d8c00c1.redz-library-v5.Window.Components.Containers.Container.Option"

local function getByPath(p)
    local parts = {}
    for part in string.gmatch(p, "[^%.]+") do table.insert(parts, part) end
    local current = game:GetService(parts[1])
    for i = 2, #parts do
        current = current:FindFirstChild(parts[i])
        if not current then return nil end
    end
    return current
end

local container = getByPath(path)  -- это Frame Option
if not container then
    print("[✗] Контейнер Option не найден по пути: " .. path)
    return
end

print("[✓] Найден контейнер: " .. container:GetFullName() .. " (класс: " .. container.ClassName .. ")")

-- Функция поиска всех кнопок (TextButton, ImageButton) внутри контейнера (рекурсивно)
local function findButtons(parent)
    local buttons = {}
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            table.insert(buttons, child)
        end
        -- Рекурсивно обходим всех потомков (на случай вложенности)
        local sub = findButtons(child)
        for _, b in ipairs(sub) do table.insert(buttons, b) end
    end
    return buttons
end

local allButtons = findButtons(container)

if #allButtons == 0 then
    print("[!] Внутри контейнера не найдено кнопок. Возможно, клик обрабатывается на самом Frame.")
    print("    Попробуем повесить обработчик на само событие родителя (если есть).")
else
    print("[✓] Найдено кнопок внутри контейнера: " .. #allButtons)
end

-- Добавляем обработчики на все найденные кнопки
for _, btn in ipairs(allButtons) do
    local name = btn:GetFullName()
    print("  Обработчик добавлен на: " .. name)

    -- MouseButton1Click
    if btn:FindFirstChild("MouseButton1Click") then
        btn.MouseButton1Click:Connect(function()
            print("===== КЛИК ПО КНОПКЕ: " .. name .. " (MouseButton1Click) =====")
            print(debug.traceback("Стек вызовов:"))
            print("===========================================================")
        end)
    else
        -- Пробуем Activated
        if btn:FindFirstChild("Activated") then
            btn.Activated:Connect(function()
                print("===== КЛИК ПО КНОПКЕ: " .. name .. " (Activated) =====")
                print(debug.traceback("Стек вызовов:"))
                print("======================================================")
            end)
        else
            print("    [!] У кнопки " .. name .. " нет событий MouseButton1Click или Activated.")
        end
    end
end

-- Если кнопок не нашлось, попробуем повесить обработчик на сам контейнер (Frame) через событие Activated или другие
if #allButtons == 0 then
    print("Пытаемся добавить обработчик на сам контейнер (Frame).")
    if container:FindFirstChild("Activated") then
        container.Activated:Connect(function()
            print("===== КЛИК ПО FRAME (Activated) =====")
            print(debug.traceback("Стек вызовов:"))
            print("====================================")
        end)
    elseif container:FindFirstChild("MouseButton1Click") then
        container.MouseButton1Click:Connect(function()
            print("===== КЛИК ПО FRAME (MouseButton1Click) =====")
            print(debug.traceback("Стек вызовов:"))
            print("============================================")
        end)
    else
        print("[✗] Не удалось найти ни одного события для отслеживания кликов.")
    end
end

print("\n=== ТРЕКЕР ЗАПУЩЕН ===")
print("Теперь нажмите на кнопку Option в интерфейсе (или на её дочернюю кнопку).")
print("В консоли появится стек вызовов при клике.")
