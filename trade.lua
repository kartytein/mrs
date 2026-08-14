-- Поиск ImageButton, внутри которого есть TextLabel с нужным текстом
local function findButtonByItemName(gui, targetText)
    for _, child in ipairs(gui:GetDescendants()) do
        -- Ищем только ImageButton (можно добавить TextButton, если нужно)
        if child:IsA("ImageButton") then
            -- Проверяем всех потомков этой кнопки на наличие TextLabel с нужным текстом
            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text == targetText then
                    return child
                end
            end
        end
    end
    return nil
end

print("Поиск кнопки с предметом: " .. TARGET_TEXT)
local targetButton = findButtonByItemName(playerGui, TARGET_TEXT)

if not targetButton then
    warn("Кнопка с предметом '" .. TARGET_TEXT .. "' не найдена.")
    return
end

print("Найдена кнопка: " .. targetButton:GetFullName())
print("Активирую...")

local activated = fireButton(targetButton)
if activated then
    print("Активация выполнена.")
else
    warn("Не удалось активировать кнопку.")
end
