-- ============================================================
-- ПОИСК ОБЪЕКТОВ С ТЕКСТОМ "sand"
-- Ищет в PlayerGui (интерфейс) и в workspace (мир).
-- Выводит путь, класс, текст и тип объекта.
-- ============================================================

local target = "Ready" -- искомый текст (регистронезависимо)

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local workspace = game:GetService("Workspace")

local results = {}

-- Функция проверки: содержит ли текст подстроку target (регистронезависимо)
local function matchesText(text)
    if not text then return false end
    return text:lower():find(target, 1, true) ~= nil
end

-- Рекурсивный обход GuiObject и сбор совпадений
local function scanGui(parent)
    for _, child in ipairs(parent:GetChildren()) do
        local text = nil
        if child:IsA("TextButton") or child:IsA("TextBox") or child:IsA("TextLabel") then
            text = child.Text
        elseif child:IsA("ImageButton") or child:IsA("ImageLabel") then
            text = nil -- у них нет текста, но проверяем имя
        end

        -- Проверяем текст или имя
        if matchesText(text) or matchesText(child.Name) then
            table.insert(results, {
                Path = child:GetFullName(),
                Class = child.ClassName,
                Text = text or "-",
                Name = child.Name,
                Type = "GUI"
            })
        end
        scanGui(child)
    end
end

-- Рекурсивный обход workspace
local function scanWorld(parent)
    for _, child in ipairs(parent:GetChildren()) do
        local text = nil
        if child:IsA("Part") or child:IsA("MeshPart") then
            -- Проверяем имя, возможно есть SurfaceGui или ProximityPrompt с текстом?
            text = child.Name
        elseif child:IsA("Model") then
            text = child.Name
        elseif child:IsA("ProximityPrompt") then
            text = child.ActionText
        elseif child:IsA("SurfaceGui") then
            -- внутри могут быть TextLabel
            for _, guiChild in ipairs(child:GetDescendants()) do
                if guiChild:IsA("TextLabel") or guiChild:IsA("TextButton") or guiChild:IsA("TextBox") then
                    if matchesText(guiChild.Text) then
                        table.insert(results, {
                            Path = guiChild:GetFullName(),
                            Class = guiChild.ClassName,
                            Text = guiChild.Text,
                            Name = guiChild.Name,
                            Type = "WorldGUI"
                        })
                    end
                end
            end
        end

        if matchesText(text) or matchesText(child.Name) then
            table.insert(results, {
                Path = child:GetFullName(),
                Class = child.ClassName,
                Text = text or "-",
                Name = child.Name,
                Type = "World"
            })
        end

        scanWorld(child)
    end
end

-- Запуск сканирования
scanGui(playerGui)
scanWorld(workspace)

-- Вывод результатов
print("=== РЕЗУЛЬТАТЫ ПОИСКА: '" .. target .. "' ===")
if #results == 0 then
    print("Ничего не найдено.")
else
    for i, res in ipairs(results) do
        print(string.format(
            "[%d] %s | Path: %s | Class: %s | Name: %s | Text: %s",
            i, res.Type, res.Path, res.Class, res.Name, res.Text
        ))
    end
    print("Всего найдено:", #results)
end
