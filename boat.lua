-- ============================================================================
--  РАСШИРЕННЫЙ ТРЕКЕР КЛИКОВ С ТАЙМАУТОМ 10 СЕКУНД (для Delta)
--  После запуска жмите на кнопки – будет показана максимальная информация.
--  Через 10 секунд вывод прекратится.
--  (Код написан без использования сложных таблиц – только примитивы и строки)
-- ============================================================================

-- Флаг активности трекера
local enabled = true

-- Запускаем таймер на 10 секунд в отдельном потоке
spawn(function()
    wait(10)
    enabled = false
    print("[Трекер] 10 секунд истекли, отслеживание остановлено.")
end)

-- Функция логирования подробной информации о кнопке
local function logButton(btn)
    if not enabled then return end

    -- Собираем всю информацию в одну строку (чтобы избежать таблиц)
    local info = "=== КНОПКА НАЖАТА ===\n"
    info = info .. "Имя: " .. btn.Name .. "\n"
    info = info .. "Класс: " .. btn.ClassName .. "\n"

    -- Свойства, зависящие от типа кнопки
    if btn:IsA("TextButton") then
        info = info .. "Текст: " .. (btn.Text or "") .. "\n"
        info = info .. "TextColor3: " .. tostring(btn.TextColor3) .. "\n"
        info = info .. "Font: " .. tostring(btn.Font) .. "\n"
        info = info .. "TextSize: " .. btn.TextSize .. "\n"
        info = info .. "TextTransparency: " .. btn.TextTransparency .. "\n"
        info = info .. "TextStrokeColor3: " .. tostring(btn.TextStrokeColor3) .. "\n"
        info = info .. "TextStrokeTransparency: " .. btn.TextStrokeTransparency .. "\n"
    elseif btn:IsA("ImageButton") then
        info = info .. "Image: " .. (btn.Image or "") .. "\n"
        info = info .. "ImageColor3: " .. tostring(btn.ImageColor3) .. "\n"
        info = info .. "ImageTransparency: " .. btn.ImageTransparency .. "\n"
    end

    -- Универсальные свойства
    info = info .. "Путь (FullName): " .. btn:GetFullName() .. "\n"
    info = info .. "Родитель: " .. (btn.Parent and btn.Parent:GetFullName() or "nil") .. "\n"
    info = info .. "AbsolutePosition: " .. tostring(btn.AbsolutePosition) .. "\n"
    info = info .. "AbsoluteSize: " .. tostring(btn.AbsoluteSize) .. "\n"
    info = info .. "Visible: " .. tostring(btn.Visible) .. "\n"
    info = info .. "Active: " .. tostring(btn.Active) .. "\n"
    info = info .. "ZIndex: " .. btn.ZIndex .. "\n"
    info = info .. "BackgroundColor3: " .. tostring(btn.BackgroundColor3) .. "\n"
    info = info .. "BackgroundTransparency: " .. btn.BackgroundTransparency .. "\n"
    info = info .. "BorderSizePixel: " .. btn.BorderSizePixel .. "\n"
    info = info .. "AutoButtonColor: " .. tostring(btn.AutoButtonColor) .. "\n"
    info = info .. "Modal: " .. tostring(btn.Modal) .. "\n"
    info = info .. "======================="

    print(info)
end

-- Навешивает обработчик клика на кнопку, если ещё не навешен
local function hookButton(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    -- Проверяем атрибут, чтобы не навесить повторно
    if btn:GetAttribute("_hooked") then return end
    btn:SetAttribute("_hooked", true)

    btn.MouseButton1Click:Connect(function()
        logButton(btn)
    end)
end

-- Рекурсивный обход всех потомков (без ipairs/таблиц, через числовой индекс)
local function scan(parent)
    if not parent then return end
    local children = parent:GetChildren()
    for i = 1, #children do
        local child = children[i]
        hookButton(child)
        scan(child)  -- заходим глубже
    end
end

-- Отслеживание динамически добавляемых кнопок
local function setupTracking(parent)
    parent.DescendantAdded:Connect(function(desc)
        hookButton(desc)
    end)
end

-- ========== ТОЧКА ВХОДА ==========
print("[Трекер] Запуск расширенного перехватчика на 10 секунд...")

-- CoreGui
local coreGui = game:GetService("CoreGui")
scan(coreGui)
setupTracking(coreGui)

-- PlayerGui
local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
if playerGui then
    scan(playerGui)
    setupTracking(playerGui)
end

print("[Трекер] Готов к работе. Кликайте по кнопкам – информация будет в консоли.")
