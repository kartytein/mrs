-- ============================================================
-- Вставка UUID в TextBox опции 2 вкладки 19, затем активация опции 3
-- Запускать при уже загруженном хабе (redz-library-v5).
-- ============================================================

local TAB = 19
local OPT_TEXTBOX = 2      -- опция с полем ввода
local OPT_ACTIVATE = 3     -- опция, которую нужно активировать
local TEXT_TO_INSERT = "a6d8c7a9-a708-49bf-b6f9-9715503f4e41"

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

local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then pcall(conn.Function) end
            end
        end
    end
end

local function findTextBox(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextBox") then
            return child
        end
        local found = findTextBox(child)
        if found then return found end
    end
    return nil
end

local root = getRoot()
if not root then
    warn("Интерфейс не найден. Загрузите хаб.")
    return
end

-- Переключаемся на вкладку 19
local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
if not tabsScroll then
    warn("TabsScroll не найден")
    return
end

local tabButton, tabCount = nil, 0
local function findTab(p)
    if tabButton then return end
    for _, c in ipairs(p:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("ImageButton") then
            tabCount += 1
            if tabCount == TAB then
                tabButton = c
                return
            end
        end
        findTab(c)
    end
end
findTab(tabsScroll)
if not tabButton then
    warn("Вкладка " .. TAB .. " не найдена")
    return
end

print("Переключаем вкладку " .. TAB .. "...")
fireSequence(tabButton)
task.wait(0.5)

-- Получаем контейнер опций
local container = safeFind(root, "Window", "Components", "Containers", "Container")
if not container then
    warn("Container не найден")
    return
end

-- Находим опцию с TextBox (номер 2)
local optionTextBox, optCount = nil, 0
for _, c in ipairs(container:GetChildren()) do
    if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
        optCount += 1
        if optCount == OPT_TEXTBOX then
            optionTextBox = c
            break
        end
    end
end

if not optionTextBox then
    warn("Опция " .. OPT_TEXTBOX .. " не найдена")
    return
end

local textBox = findTextBox(optionTextBox)
if not textBox then
    warn("TextBox не найден в опции " .. OPT_TEXTBOX)
    return
end

-- Вставляем UUID
textBox.Text = TEXT_TO_INSERT
task.wait(0.1)
pcall(function()
    textBox:CaptureFocus()
    task.wait(0.1)
    textBox:ReleaseFocus()
end)
print("Текст вставлен: " .. textBox.Text)

-- Находим опцию для активации (номер 3)
local optionActivate, optCount2 = nil, 0
for _, c in ipairs(container:GetChildren()) do
    if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
        optCount2 += 1
        if optCount2 == OPT_ACTIVATE then
            optionActivate = c
            break
        end
    end
end

if not optionActivate then
    warn("Опция " .. OPT_ACTIVATE .. " не найдена")
    return
end

print("Активируем опцию " .. OPT_ACTIVATE .. "...")
fireSequence(optionActivate)
task.wait(0.2)
print("Готово.")
