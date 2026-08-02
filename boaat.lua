-- ============================================================================
--  СКРИПТ-ПЕРЕХВАТЧИК КЛИКОВ ПО КНОПКАМ
--  Вставьте в консоль Delta после загрузки HUB.
--  При каждом клике на любую кнопку (TextButton/ImageButton) будет выводиться
--  её информация в консоль. Помогает идентифицировать нужные кнопки.
-- ============================================================================

-- Функция вывода информации о кнопке
local function logButton(btn)
    local info = {
        Name = btn.Name,
        Class = btn.ClassName,
        Text = btn:IsA("TextButton") and btn.Text or "—",
        Path = btn:GetFullName(),
        Visible = btn.Visible,
        Position = tostring(btn.AbsolutePosition),
        Size = tostring(btn.AbsoluteSize)
    }
    print("=== КНОПКА НАЖАТА ===")
    print("Имя: " .. info.Name)
    print("Класс: " .. info.Class)
    print("Текст: " .. info.Text)
    print("Путь: " .. info.Path)
    print("Видимость: " .. tostring(info.Visible))
    print("Позиция: " .. info.Position)
    print("Размер: " .. info.Size)
    print("=======================")
end

-- Функция добавления обработчика на кнопку
local function hookButton(btn)
    if btn:IsA("TextButton") or btn:IsA("ImageButton") then
        -- Убедимся, что обработчик не добавлен дважды (используем атрибут)
        if not btn:GetAttribute("_hooked") then
            btn:SetAttribute("_hooked", true)
            btn.MouseButton1Click:Connect(function()
                logButton(btn)
            end)
        end
    end
end

-- Обработка всех существующих объектов
local function scanAndHook(parent)
    if not parent then return end
    for _, child in ipairs(parent:GetChildren()) do
        hookButton(child)
        scanAndHook(child)  -- рекурсивно обрабатываем вложенные
    end
end

-- Отслеживание новых объектов (для динамически создаваемых кнопок)
local function setupDescendantTracking(parent)
    parent.DescendantAdded:Connect(function(desc)
        hookButton(desc)
    end)
end

-- Основная функция запуска
local function startListener()
    print("Запуск перехватчика кликов...")
    local sources = {
        game:GetService("CoreGui"),
        game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    }
    for _, src in ipairs(sources) do
        if src then
            scanAndHook(src)
            setupDescendantTracking(src)
        end
    end
    print("Перехватчик активен. Кликайте по кнопкам – информация появится в консоли.")
end

-- Запускаем
startListener()
