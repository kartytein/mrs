-- ============================================================
-- Трекер нажатий кнопок в интерфейсе redz-library-v5
-- Показывает номер вкладки/опции и доп. информацию при клике.
-- Запускать при уже загруженном хабе.
-- ============================================================

local TAB = 17 -- целевая вкладка, но трекер работает по всем
local CoreGui = game:GetService("CoreGui")

local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end

local root = getRoot()
if not root then
    warn("Интерфейс не найден. Загрузите хаб.")
    return
end

local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
local container = safeFind(root, "Window", "Components", "Containers", "Container")
if not tabsScroll then
    warn("TabsScroll не найден")
    return
end
if not container then
    warn("Container не найден")
    return
end

-- Функция для получения номера опции среди видимых
local function getVisibleOptionNumber(optionBtn)
    local count = 0
    for _, child in ipairs(container:GetChildren()) do
        if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
            count += 1
            if child == optionBtn then
                return count
            end
        end
    end
    return nil
end

-- Функция для получения номера вкладки
local function getTabNumber(tabBtn)
    local count = 0
    local function countTabs(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("ImageButton") then
                count += 1
                if child == tabBtn then
                    return count
                end
            end
            local res = countTabs(child)
            if res then return res end
        end
        return nil
    end
    return countTabs(tabsScroll)
end

-- Функция для подключения слушателя к кнопке
local function attachListener(btn, btnType)
    -- Подключаемся к Activated и MouseButton1Click, выводим инфо
    local function showInfo()
        if btnType == "tab" then
            local num = getTabNumber(btn)
            print(string.format("[TAB] Номер: %d | Имя: %s | Класс: %s", num, btn.Name, btn.ClassName))
        elseif btnType == "option" then
            if not btn.Visible then return end -- игнорируем невидимые
            local num = getVisibleOptionNumber(btn)
            -- Собираем доп. информацию
            local hasTextBox = false
            local extraInfo = ""
            for _, desc in ipairs(btn:GetDescendants()) do
                if desc:IsA("TextBox") then
                    hasTextBox = true
                    extraInfo = string.format("TextBox(Text='%s', Placeholder='%s')", desc.Text, desc.PlaceholderText)
                    break
                end
            end
            print(string.format("[OPTION] Номер: %s | Имя: %s | Класс: %s | Поле ввода: %s%s",
                tostring(num), btn.Name, btn.ClassName, hasTextBox and "Да" or "Нет",
                hasTextBox and (" | " .. extraInfo) or ""))
        end
    end

    -- Слушаем сигналы
    for _, sigName in ipairs({"Activated", "MouseButton1Click"}) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn and conn.Enabled then
                        -- Добавляем свой обработчик, но pcall для безопасности
                        local origFunc = conn.Function
                        -- Мы не можем просто заменить функцию, но можем подключить свою через ту же систему?
                        -- Поскольку getconnections только для чтения, мы не можем подключиться.
                        -- Альтернатива: использовать сигнал напрямую? Но сигнал - это RBXScriptSignal, 
                        -- на который можно Connect.
                        -- Однако мы не хотим влиять на существующие. Просто добавим Connect.
                        -- Так как это Script (LocalScript), можем использовать Connect на сигнале.
                        -- Но мы перебираем getconnections, чтобы не потерять оригинал.
                    end
                end
                -- Правильнее: подключиться напрямую к сигналу
                -- Но мы должны проверить, что сигнал существует.
            end
        end
    end

    -- Более простой и надёжный способ: Connect к сигналу (создаёт новый обработчик)
    -- Проверяем, есть ли сигнал, и подключаем
    local activatedSig = btn:FindFirstChild("Activated") or btn["Activated"]
    if activatedSig then
        activatedSig:Connect(function()
            showInfo()
        end)
    end
    local clickSig = btn:FindFirstChild("MouseButton1Click") or btn["MouseButton1Click"]
    if clickSig then
        clickSig:Connect(function()
            -- MouseButton1Click не имеет аргументов, просто вызываем
            showInfo()
        end)
    end
end

-- Подключаем слушатели к вкладкам
print("Подключаю трекер к вкладкам...")
local function processTabs(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            attachListener(child, "tab")
        end
        processTabs(child)
    end
end
processTabs(tabsScroll)

-- Подключаем слушатели к опциям (все, даже невидимые)
print("Подключаю трекер к опциям...")
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        attachListener(child, "option")
    end
end

print("Трекер готов. Кликайте по кнопкам, информация появится в консоли.")
