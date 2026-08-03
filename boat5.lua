-- ============================================================
--  УГЛУБЛЁННАЯ ДИАГНОСТИКА: ИЩЕМ ИНДИКАТОР СОСТОЯНИЯ (ВКЛ/ВЫКЛ)
--  Сравнивает все свойства Holder и дочерних элементов.
--  Также проверяет атрибуты и скрытые различия.
--  Запустите для включённого и выключенного состояния, сравните вывод.
-- ============================================================

local TAB_INDEX = 1      -- Номер вкладки
local OPTION_INDEX = 6   -- Номер Option

local coreGui = game:GetService("CoreGui")

-- Поиск корня
local root
for _, child in ipairs(coreGui:GetChildren()) do
    root = child:FindFirstChild("redz-library-v5")
    if root then break end
end
if not root then print("[Ошибка] redz-library-v5 не найден") return end

-- Получаем контейнер
local container = root:FindFirstChild("Window")
container = container and container:FindFirstChild("Components")
container = container and container:FindFirstChild("Containers")
container = container and container:FindFirstChild("Container")
if not container then print("[Ошибка] Container не найден") return end

-- Ищем нужную Option (только видимые)
local optionBtn
local idx = 0
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        idx = idx + 1
        if idx == OPTION_INDEX then
            optionBtn = child
            break
        end
    end
end

if not optionBtn then print("[Ошибка] Option #" .. OPTION_INDEX .. " не найдена") return end

print("=== ГЛУБОКАЯ ДИАГНОСТИКА КНОПКИ ===")
print("Путь: " .. optionBtn:GetFullName())

-- 1. Основные свойства кнопки
print("--- Основные свойства ---")
print("Text: '" .. (optionBtn:IsA("TextButton") and optionBtn.Text or "") .. "'")
print("TextColor3: " .. tostring(optionBtn.TextColor3))
print("TextTransparency: " .. optionBtn.TextTransparency)
print("BackgroundColor3: " .. tostring(optionBtn.BackgroundColor3))
print("BackgroundTransparency: " .. optionBtn.BackgroundTransparency)
print("BorderColor3: " .. tostring(optionBtn.BorderColor3))
print("BorderSizePixel: " .. optionBtn.BorderSizePixel)
print("Active: " .. tostring(optionBtn.Active))
print("AutoButtonColor: " .. tostring(optionBtn.AutoButtonColor))

-- 2. Атрибуты
print("--- Атрибуты ---")
local attrs = optionBtn:GetAttributes()
if attrs then
    for k, v in pairs(attrs) do
        print("  " .. tostring(k) .. " = " .. tostring(v))
    end
else
    print("  нет")
end

-- 3. Глубокая проверка всех дочерних элементов (включая Holder)
print("--- Дочерние элементы ---")
local function printDeep(parent, indent)
    local children = parent:GetChildren()
    for i = 1, #children do
        local child = children[i]
        local prefix = string.rep("  ", indent) .. "- " .. child.Name .. " (" .. child.ClassName .. ")"
        local extra = ""
        if child:IsA("Frame") or child:IsA("ScrollingFrame") then
            extra = " BG: " .. tostring(child.BackgroundColor3)
                .. " BGTrans: " .. child.BackgroundTransparency
                .. " Visible: " .. tostring(child.Visible)
        elseif child:IsA("TextLabel") then
            extra = " Text: '" .. child.Text .. "'"
                .. " TextColor3: " .. tostring(child.TextColor3)
                .. " Visible: " .. tostring(child.Visible)
        elseif child:IsA("ImageLabel") then
            extra = " Image: " .. child.Image
                .. " ImageTrans: " .. child.ImageTransparency
                .. " Visible: " .. tostring(child.Visible)
        elseif child:IsA("UIAnchor") then
            extra = " (якорь)"
        elseif child:IsA("UIInner") then  -- возможно кастомный класс
            extra = " (UIInner)"
        else
            extra = " Visible: " .. tostring(child.Visible)
        end
        print(prefix .. extra)
        -- Рекурсия вглубь
        printDeep(child, indent + 1)
    end
end
printDeep(optionBtn, 0)

print("======================================")
print("Сравните вывод для вкл и выкл состояния (особенно Holder и его потомков).")
