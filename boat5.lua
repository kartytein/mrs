-- ============================================================
--  ДИАГНОСТИКА СОСТОЯНИЯ КНОПКИ (ВКЛ/ВЫКЛ)
--  После ручного переключения вкладки и нажатия на Option
--  выполните этот скрипт. Он покажет все визуальные свойства,
--  которые могут меняться при включении/выключении.
--  Сравните вывод для включённой и выключенной кнопки.
-- ============================================================

-- Задайте номер вкладки и кнопки (как в активаторе)
local TAB_INDEX = 5
local OPTION_INDEX = 6

local coreGui = game:GetService("CoreGui")

-- Поиск корня
local root
for _, child in ipairs(coreGui:GetChildren()) do
    root = child:FindFirstChild("redz-library-v5")
    if root then break end
end
if not root then print("Не найден redz-library-v5") return end

-- Получаем контейнер (сначала переключаем вкладку через активатор или руками)
-- Предполагаем, что вкладка уже активна. Если нет – запустите активатор без Option.
local container = root:FindFirstChild("Window")
container = container and container:FindFirstChild("Components")
container = container and container:FindFirstChild("Containers")
container = container and container:FindFirstChild("Container")
if not container then print("Контейнер не найден") return end

-- Ищем видимую Option по индексу
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

if not optionBtn then print("Option #" .. OPTION_INDEX .. " не найдена") return end

print("=== СВОЙСТВА КНОПКИ (состояние) ===")
print("Путь: " .. optionBtn:GetFullName())
if optionBtn:IsA("TextButton") then
    print("Текст: '" .. optionBtn.Text .. "'")
    print("Цвет текста: " .. tostring(optionBtn.TextColor3))
    print("Прозрачность текста: " .. optionBtn.TextTransparency)
end
if optionBtn:IsA("ImageButton") then
    print("Изображение: " .. optionBtn.Image)
    print("Цвет изображения: " .. tostring(optionBtn.ImageColor3))
    print("Прозрачность изобр.: " .. optionBtn.ImageTransparency)
end
print("Цвет фона: " .. tostring(optionBtn.BackgroundColor3))
print("Прозрачность фона: " .. optionBtn.BackgroundTransparency)
print("Цвет рамки: " .. tostring(optionBtn.BorderColor3))
print("Размер рамки: " .. optionBtn.BorderSizePixel)
print("Активна (Active): " .. tostring(optionBtn.Active))
print("Автоцвет (AutoButtonColor): " .. tostring(optionBtn.AutoButtonColor))

-- Проверяем наличие дополнительных индикаторов в дочерних элементах
print("Дочерние элементы:")
for _, child in ipairs(optionBtn:GetChildren()) do
    local desc = "  " .. child.Name .. " (" .. child.ClassName .. ")"
    if child:IsA("Frame") then
        desc = desc .. " BG: " .. tostring(child.BackgroundColor3) .. " Visible: " .. tostring(child.Visible)
    elseif child:IsA("TextLabel") then
        desc = desc .. " Text: '" .. child.Text .. "'"
    elseif child:IsA("ImageLabel") then
        desc = desc .. " Image: " .. child.Image
    end
    print(desc)
end

print("====================================")
print("Включите/выключите функцию вручную и запустите снова. Сравните различия.")
print("Обычно индикатором служат: цвет фона, текст, наличие дочернего Frame и т.п.")
