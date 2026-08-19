-- Совмещённый скрипт: вставка текста в опцию 2, активация опции 3 (вкладка 19)
-- Хаб уже загружен.

local CoreGui = game:GetService("CoreGui")
local TAB = 19
local OPT_TEXT = 2
local OPT_ACTIVATE = 3
local TEXT = "49f34f12-d803-44f9-a50d-a9b49bcf8229"

local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
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
        if child:IsA("TextBox") then return child end
        local found = findTextBox(child)
        if found then return found end
    end
end

local root = getRoot()
if not root then return end

-- Переключаем вкладку
local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
if not tabsScroll then return end
local tabButton, tabCount = nil, 0
local function findTab(p)
    if tabButton then return end
    for _, c in ipairs(p:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("ImageButton") then
            tabCount += 1
            if tabCount == TAB then tabButton = c return end
        end
        findTab(c)
    end
end
findTab(tabsScroll)
if not tabButton then return end
fireSequence(tabButton)
task.wait(0.5)

-- Контейнер опций
local container = safeFind(root, "Window", "Components", "Containers", "Container")
if not container then return end

-- Находим опцию 2 и вставляем текст
local optionText, optCount2 = nil, 0
for _, c in ipairs(container:GetChildren()) do
    if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
        optCount2 += 1
        if optCount2 == OPT_TEXT then optionText = c break end
    end
end
if not optionText then return end
local textBox = findTextBox(optionText)
if textBox then
    textBox.Text = TEXT
end

-- Пауза после вставки
task.wait(0.3)

-- Находим опцию 3 и активируем
local optionActivate, optCount3 = nil, 0
for _, c in ipairs(container:GetChildren()) do
    if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
        optCount3 += 1
        if optCount3 == OPT_ACTIVATE then optionActivate = c break end
    end
end
if not optionActivate then return end
fireSequence(optionActivate)
