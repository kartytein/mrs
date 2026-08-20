-- ============================================================
-- ТРЕКЕР СОБЫТИЙ TextBox (вкладка 19, опция 2)
-- Показывает все события, происходящие при ручном вводе текста.
-- Запускать при уже открытой вкладке 19 и загруженном хабе.
-- ============================================================

local CoreGui = game:GetService("CoreGui")
local OPT_TEXT = 2

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

local function findTextBox(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextBox") then return child end
        local found = findTextBox(child)
        if found then return found end
    end
end

local root = getRoot()
if not root then print("root не найден") return end

local container = safeFind(root, "Window", "Components", "Containers", "Container")
if not container then print("container не найден") return end

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
if not optionText then print("опция не найдена") return end

local textBox = findTextBox(optionText)
if not textBox then print("TextBox не найден") return end

print("Диагностика событий TextBox:", textBox:GetFullName())

-- Подключаемся ко всем возможным событиям
textBox.Changed:Connect(function(prop)
    print(">>> Changed:", prop, " = ", tostring(textBox[prop]))
end)

textBox.Focused:Connect(function()
    print(">>> Focused (получил фокус)")
end)

textBox.FocusLost:Connect(function(enterPressed)
    print(">>> FocusLost (потерял фокус), enterPressed =", tostring(enterPressed))
end)

textBox.MouseButton1Down:Connect(function(x, y)
    print(">>> MouseButton1Down:", x, y)
end)

textBox.MouseButton1Up:Connect(function(x, y)
    print(">>> MouseButton1Up:", x, y)
end)

textBox.MouseEnter:Connect(function()
    print(">>> MouseEnter")
end)

textBox.MouseLeave:Connect(function()
    print(">>> MouseLeave")
end)

-- Если есть событие TextChanged (в некоторых версиях)
pcall(function()
    textBox.TextChanged:Connect(function()
        print(">>> TextChanged (событие текста)")
    end)
end)

-- Если есть событие ReturnPressedFromOnScreenKeyboard
pcall(function()
    textBox.ReturnPressedFromOnScreenKeyboard:Connect(function()
        print(">>> ReturnPressedFromOnScreenKeyboard")
    end)
end)

-- Также подключим KeyPressed (может быть у TextBox? зависит от версии)
pcall(function()
    textBox.KeyPressed:Connect(function(key)
        print(">>> KeyPressed:", key)
    end)
end)

print("Трекер готов. Сфокусируйтесь на TextBox и введите текст вручную (Ctrl+V или печатайте). Наблюдайте за событиями.")
