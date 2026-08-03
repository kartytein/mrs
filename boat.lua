-- ============================================================================
--  ДИАГНОСТИКА КНОПКИ: ПОИСК УДАЛЁННЫХ ВЫЗОВОВ
--  При клике на кнопку перехватывает следующие за этим вызовы RemoteEvent,
--  RemoteFunction, BindableEvent, BindableFunction и выводит их параметры.
--  Также выводит детальную информацию о самой кнопке.
--  Вставлять в консоль Delta. Работает только со строками.
-- ============================================================================

local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChild("PlayerGui")

-- Хранилище для корреляции клика и вызовов
local clickFlag = false
local lastClickTime = 0
local CLICK_TIMEOUT = 0.5 -- секунды

-- ===== ПЕРЕХВАТ УДАЛЁННЫХ ВЫЗОВОВ =====
local oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
    local args = {...}
    local now = tick()
    local triggeredByClick = clickFlag and (now - lastClickTime) < CLICK_TIMEOUT
    if triggeredByClick then
        clickFlag = false -- сброс, чтобы не ловить другие вызовы
    end

    -- Формируем строку с аргументами (только примитивы, таблицы заменяем "table")
    local argsStr = ""
    for i, v in ipairs(args) do
        if i > 1 then argsStr = argsStr .. ", " end
        if type(v) == "table" then
            argsStr = argsStr .. "{...}"
        elseif type(v) == "string" then
            argsStr = argsStr .. '"' .. v .. '"'
        else
            argsStr = argsStr .. tostring(v)
        end
    end

    if triggeredByClick then
        print(">>> ОБНАРУЖЕН ВЫЗОВ RemoteEvent:FireServer (СВЯЗАН С КЛИКОМ)")
    else
        print("RemoteEvent:FireServer")
    end
    print("   Объект: " .. self:GetFullName())
    print("   Аргументы: " .. argsStr)
    print("   Команда эмуляции: fireserver(" .. self:GetFullName() .. ", " .. argsStr .. ")")
    print("   (Замените таблицы {..} вручную, если они есть)")

    return oldFireServer(self, ...)
end)

local oldInvokeServer = nil
pcall(function()
    oldInvokeServer = hookfunction(Instance.new("RemoteFunction").InvokeServer, function(self, ...)
        local args = {...}
        local now = tick()
        local triggeredByClick = clickFlag and (now - lastClickTime) < CLICK_TIMEOUT
        if triggeredByClick then clickFlag = false end

        local argsStr = ""
        for i, v in ipairs(args) do
            if i > 1 then argsStr = argsStr .. ", " end
            if type(v) == "table" then argsStr = argsStr .. "{...}"
            elseif type(v) == "string" then argsStr = argsStr .. '"' .. v .. '"'
            else argsStr = argsStr .. tostring(v) end
        end

        if triggeredByClick then
            print(">>> ОБНАРУЖЕН ВЫЗОВ RemoteFunction:InvokeServer (СВЯЗАН С КЛИКОМ)")
        else
            print("RemoteFunction:InvokeServer")
        end
        print("   Объект: " .. self:GetFullName())
        print("   Аргументы: " .. argsStr)
        print("   Команда эмуляции: invokeserver(" .. self:GetFullName() .. ", " .. argsStr .. ")")
        return oldInvokeServer(self, ...)
    end)
end)

local oldFireBindable = hookfunction(Instance.new("BindableEvent").Fire, function(self, ...)
    local args = {...}
    local now = tick()
    local triggeredByClick = clickFlag and (now - lastClickTime) < CLICK_TIMEOUT
    if triggeredByClick then clickFlag = false end

    local argsStr = ""
    for i, v in ipairs(args) do
        if i > 1 then argsStr = argsStr .. ", " end
        if type(v) == "table" then argsStr = argsStr .. "{...}"
        elseif type(v) == "string" then argsStr = argsStr .. '"' .. v .. '"'
        else argsStr = argsStr .. tostring(v) end
    end

    if triggeredByClick then
        print(">>> ОБНАРУЖЕН ВЫЗОВ BindableEvent:Fire (СВЯЗАН С КЛИКОМ)")
    else
        print("BindableEvent:Fire")
    end
    print("   Объект: " .. self:GetFullName())
    print("   Аргументы: " .. argsStr)
    print("   Команда эмуляции: firesignal(" .. self:GetFullName() .. ".Event, " .. argsStr .. ") -- осторожно, может не сработать")
    return oldFireBindable(self, ...)
end)

local oldInvokeBindable = nil
pcall(function()
    oldInvokeBindable = hookfunction(Instance.new("BindableFunction").Invoke, function(self, ...)
        local args = {...}
        local now = tick()
        local triggeredByClick = clickFlag and (now - lastClickTime) < CLICK_TIMEOUT
        if triggeredByClick then clickFlag = false end

        local argsStr = ""
        for i, v in ipairs(args) do
            if i > 1 then argsStr = argsStr .. ", " end
            if type(v) == "table" then argsStr = argsStr .. "{...}"
            elseif type(v) == "string" then argsStr = argsStr .. '"' .. v .. '"'
            else argsStr = argsStr .. tostring(v) end
        end

        if triggeredByClick then
            print(">>> ОБНАРУЖЕН ВЫЗОВ BindableFunction:Invoke (СВЯЗАН С КЛИКОМ)")
        else
            print("BindableFunction:Invoke")
        end
        print("   Объект: " .. self:GetFullName())
        print("   Аргументы: " .. argsStr)
        return oldInvokeBindable(self, ...)
    end)
end)

print("Перехват удалённых вызовов активирован.")

-- ===== ДЕТЕКТОР КЛИКА И ВЫВОД ИНФОРМАЦИИ =====
local function logButtonDeep(btn)
    print("=== КНОПКА НАЖАТА ===")
    local info = {
        Name = btn.Name,
        Class = btn.ClassName,
        Path = btn:GetFullName(),
        Visible = btn.Visible,
        AbsPos = btn.AbsolutePosition,
        AbsSize = btn.AbsoluteSize,
        Text = (btn:IsA("TextButton") and btn.Text) or "—",
        Attributes = ""
    }
    -- Считываем атрибуты в строку
    local attrList = btn:GetAttributes()
    for k, v in pairs(attrList) do
        info.Attributes = info.Attributes .. k .. "=" .. tostring(v) .. "; "
    end

    print("Имя: " .. info.Name)
    print("Класс: " .. info.Class)
    print("Текст: " .. info.Text)
    print("Путь: " .. info.Path)
    print("Видимость: " .. tostring(info.Visible))
    print("Позиция: " .. tostring(info.AbsPos))
    print("Размер: " .. tostring(info.AbsSize))
    print("Атрибуты: " .. (info.Attributes ~= "" and info.Attributes or "нет"))

    -- Ищем скрипты внутри кнопки
    local scriptsInside = ""
    for _, child in ipairs(btn:GetChildren()) do
        if child:IsA("LuaSourceContainer") then
            scriptsInside = scriptsInside .. child.Name .. " (" .. child.ClassName .. "); "
        end
    end
    print("Скрипты внутри: " .. (scriptsInside ~= "" and scriptsInside or "нет"))

    -- Поднимаемся вверх, ищем локальные скрипты/модули в родителях до корня
    local ancestor = btn.Parent
    local scriptHierarchy = ""
    while ancestor do
        for _, child in ipairs(ancestor:GetChildren()) do
            if child:IsA("LocalScript") or child:IsA("ModuleScript") then
                scriptHierarchy = scriptHierarchy .. ancestor:GetFullName() .. "/" .. child.Name .. " (" .. child.ClassName .. "); "
            end
        end
        ancestor = ancestor.Parent
    end
    print("Скрипты в иерархии: " .. (scriptHierarchy ~= "" and scriptHierarchy or "не найдены"))

    -- Установка флага для корреляции
    clickFlag = true
    lastClickTime = tick()
    print("Ожидайте перехвата удалённого вызова в течение " .. CLICK_TIMEOUT .. " сек...")
    print("=================================")
end

-- Хук на кнопки
local function hookButton(btn)
    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and not btn:GetAttribute("_diagHooked") then
        btn:SetAttribute("_diagHooked", true)
        btn.MouseButton1Click:Connect(function()
            logButtonDeep(btn)
        end)
    end
end

-- Рекурсивный обход
local function scanRecursive(parent)
    for _, child in ipairs(parent:GetChildren()) do
        hookButton(child)
        scanRecursive(child)
    end
end

-- Запуск сканирования в CoreGui и PlayerGui
local targets = {CoreGui}
if playerGui then table.insert(targets, playerGui) end
for _, target in ipairs(targets) do
    if target then
        scanRecursive(target)
        target.DescendantAdded:Connect(function(desc)
            hookButton(desc)
        end)
    end
end

print("Диагностика кнопок запущена. Нажмите нужную кнопку.")
print("В консоли появится детальная информация и, возможно, перехваченный удалённый вызов.")
