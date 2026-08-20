-- ============================================================
-- Вставка текста в опцию 2 (клик + Text) и активация опции 3
-- Вкладка 19 уже открыта. Хаб загружен.
-- ============================================================

local CoreGui = game:GetService("CoreGui")

local OPT_TEXT = 2
local OPT_ACTIVATE = 3
local TEXT = "08943515-b3b8-4e53-8a14-fc0f866504b4"

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

local container = safeFind(root, "Window", "Components", "Containers", "Container")
if not container then return end

-- 1. Активируем опцию 2 (клик по ней, чтобы поле стало активным)
local optionText, optCount = nil, 0
for _, c in ipairs(container:GetChildren()) do
    if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
        optCount += 1
        if optCount == OPT_TEXT then
            optionText = c
            break
        end
    end
end
if not optionText then return end

fireSequence(optionText)
print("Клик по опции 2 выполнен")

-- 2. Вставляем текст в TextBox
local textBox = findTextBox(optionText)
if not textBox then return end
textBox.Text = TEXT
print("Текст вставлен:", TEXT)

-- Небольшая пауза для обновления
task.wait(0.3)

-- 3. Находим опцию 3 и активируем
local optionActivate, optCount3 = nil, 0
for _, c in ipairs(container:GetChildren()) do
    if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
        optCount3 += 1
        if optCount3 == OPT_ACTIVATE then
            optionActivate = c
            break
        end
    end
end
if not optionActivate then return end

fireSequence(optionActivate)
print("Опция 3 активирована")
