-- ============================================================================
--  СКРИПТ-ПЕРЕХВАТЧИК КЛИКОВ ПО КНОПКАМ (с записью в файл)
--  Вставьте в консоль Delta после загрузки HUB.
-- ============================================================================

-- Путь и инициализация файла лога
local LOG_FILE = "button_clicks_log.txt"

-- Безопасная запись: если функции нет — предупреждаем один раз
local hasFileAPI = (type(writefile) == "function") and (type(appendfile) == "function")
if not hasFileAPI then
    warn("[LOG] writefile/appendfile недоступны — запись в файл отключена.")
else
    -- Создаём/перезаписываем файл с заголовком сессии
    pcall(function()
        writefile(LOG_FILE, string.format("=== СЕССИЯ %s ===\n", os.date("%Y-%m-%d %H:%M:%S")))
    end)
end

-- Запись строки в файл + консоль
local function emit(line)
    print(line)
    if hasFileAPI then
        pcall(appendfile, LOG_FILE, line .. "\n")
    end
end

-- Формирование информации о кнопке
local function logButton(btn)
    local isText = btn:IsA("TextButton")
    local lines = {
        "=== КНОПКА НАЖАТА ===",
        "Имя: " .. btn.Name,
        "Класс: " .. btn.ClassName,
        "Текст: " .. (isText and btn.Text or "—"),
        "Путь: " .. btn:GetFullName(),
        "Видимость: " .. tostring(btn.Visible),
        "Позиция: " .. tostring(btn.AbsolutePosition),
        "Размер: " .. tostring(btn.AbsoluteSize),
        "Время: " .. os.date("%H:%M:%S"),
        "======================="
    }
    for _, l in ipairs(lines) do emit(l) end
    if hasFileAPI then pcall(appendfile, LOG_FILE, "\n") end
end

-- Навешиваем обработчик (без дублей, через атрибут)
local function hookButton(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    if btn:GetAttribute("_hooked") then return end
    btn:SetAttribute("_hooked", true)
    btn.MouseButton1Click:Connect(function()
        logButton(btn)
    end)
end

-- Рекурсивный обход
local function scanAndHook(parent)
    if not parent then return end
    for _, child in ipairs(parent:GetChildren()) do
        hookButton(child)
        scanAndHook(child)
    end
end

-- Отслеживание новых объектов
local function setupDescendantTracking(parent)
    parent.DescendantAdded:Connect(hookButton)
end

-- Запуск
local function startListener()
    emit("[INIT] Запуск перехватчика кликов...")
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
    emit("[INIT] Перехватчик активен. Лог: " .. LOG_FILE)
end

startListener()
