-- ============================================================================
--  РАСШИРЕННЫЙ ПЕРЕХВАТЧИК КЛИКОВ (выводит полные данные о кнопке)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  При каждом клике на ЛЮБУЮ кнопку будет выведена максимальная информация.
-- ============================================================================

-- Вспомогательная функция: рекурсивный вывод дочерних объектов (ограничим 2 уровня)
local function printChildren(obj, level)
    level = level or 0
    local prefix = string.rep("  ", level)
    for _, child in ipairs(obj:GetChildren()) do
        print(prefix .. "├─ " .. child.Name .. " [" .. child.ClassName .. "]")
        if level < 2 then -- покажем только 2 уровня вложенности
            printChildren(child, level + 1)
        end
    end
end

-- Функция вывода свойств (наиболее важные)
local function printProperties(btn)
    local props = {
        "Name", "ClassName", "Visible", "Position", "Size", "AnchorPoint",
        "BackgroundColor3", "BackgroundTransparency", "TextColor3", "Text",
        "TextSize", "Font", "TextXAlignment", "TextYAlignment", "Active",
        "Selectable", "AutoButtonColor", "Image", "ImageColor3", "ImageTransparency"
    }
    print("  --- Свойства ---")
    for _, prop in ipairs(props) do
        local success, val = pcall(function() return btn[prop] end)
        if success and val ~= nil then
            print("    " .. prop .. " = " .. tostring(val))
        end
    end
    -- Дополнительно атрибуты (если есть)
    local attrs = btn:GetAttributes()
    if next(attrs) then
        print("  --- Атрибуты ---")
        for k, v in pairs(attrs) do
            print("    " .. k .. " = " .. tostring(v))
        end
    else
        print("  (атрибутов нет)")
    end
end

-- Главная функция логирования
local function logButtonFull(btn)
    print("\n========== КНОПКА НАЖАТА ==========")
    print("Имя: " .. btn.Name)
    print("Класс: " .. btn.ClassName)
    print("Полный путь: " .. btn:GetFullName())
    print("Видимость: " .. tostring(btn.Visible))
    print("Абсолютная позиция: " .. tostring(btn.AbsolutePosition))
    print("Абсолютный размер: " .. tostring(btn.AbsoluteSize))
    printProperties(btn)
    print("  --- Дочерние объекты (до 2 уровней) ---")
    local children = btn:GetChildren()
    if #children == 0 then
        print("    (нет)")
    else
        printChildren(btn, 1)
    end
    print("=======================================\n")
end

-- Функция добавления обработчика на кнопку
local function hookButton(btn)
    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and not btn:GetAttribute("_hooked_full") then
        btn:SetAttribute("_hooked_full", true)
        btn.MouseButton1Click:Connect(function()
            logButtonFull(btn)
        end)
    end
end

-- Сканирование всех существующих GUI
local function scanAndHook(parent)
    if not parent then return end
    for _, child in ipairs(parent:GetChildren()) do
        hookButton(child)
        scanAndHook(child)
    end
end

-- Отслеживание новых объектов
local function setupDescendantTracking(parent)
    parent.DescendantAdded:Connect(function(desc)
        hookButton(desc)
    end)
end

-- Запуск
local function startFullListener()
    print("Запуск расширенного перехватчика...")
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
    print("Готово. Теперь кликайте по любым кнопкам – получите подробный отчёт.")
end

startFullListener()
