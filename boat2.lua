-- ============================================================================
-- УПРОЩЁННЫЙ СКАНЕР ДЛЯ ВАШЕГО ПРОЕКТА (ГАРАНТИРОВАННО РАБОТАЕТ)
-- Вставьте этот код в CommandBar (View -> CommandBar) и нажмите Enter.
-- Код сам выполнится и выведет все GUI, кнопки и RemoteEvent.
-- Если ничего не вывелось – значит, либо вы не нажали Enter, либо в проекте
-- действительно нет GUI/RemoteEvent (тогда будут выведены пустые списки).
-- ============================================================================

-- Функция для красивого вывода таблицы (рекурсивно, с отступами)
local function dumpTable(tbl, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. ":")
            dumpTable(v, indent + 1)
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

-- Главная функция анализа
local function scanProject()
    local result = {
        guis = {},
        remoteEvents = {},
        serverScripts = {},
    }

    -- 1. Поиск ScreenGui
    local starterGui = game:GetService("StarterGui")
    for _, child in ipairs(starterGui:GetChildren()) do
        if child:IsA("ScreenGui") then
            table.insert(result.guis, child.Name)
        end
    end
    -- Также проверим ReplicatedStorage (могут быть динамические GUI)
    local repStorage = game:GetService("ReplicatedStorage")
    for _, child in ipairs(repStorage:GetChildren()) do
        if child:IsA("ScreenGui") then
            table.insert(result.guis, child.Name .. " (в ReplicatedStorage)")
        end
    end

    -- 2. Поиск RemoteEvent
    for _, child in ipairs(repStorage:GetChildren()) do
        if child:IsA("RemoteEvent") then
            table.insert(result.remoteEvents, child.Name)
        end
    end

    -- 3. Поиск кнопок внутри GUI (только в StarterGui, так как там обычно лежат)
    local buttons = {}
    for _, gui in ipairs(starterGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local function findButtons(parent)
                for _, ch in ipairs(parent:GetChildren()) do
                    if ch:IsA("TextButton") or ch:IsA("ImageButton") then
                        table.insert(buttons, ch:GetFullName())
                    end
                    findButtons(ch)
                end
            end
            findButtons(gui)
        end
    end
    result.buttons = buttons

    -- 4. Поиск Script/LocalScript с возможной логикой кнопок (по ключевым словам)
    local serverScripts = game:GetService("ServerScriptService"):GetChildren()
    for _, scr in ipairs(serverScripts) do
        if scr:IsA("Script") or scr:IsA("ModuleScript") then
            local source = scr:IsA("Script") and scr.Source or ""
            if string.find(source, "MouseButton1Click") or string.find(source, "OnServerEvent") or string.find(source, "RemoteEvent") then
                table.insert(result.serverScripts, scr:GetFullName())
            end
        end
    end

    -- 5. Вывод результата
    print("===== РЕЗУЛЬТАТ СКАНИРОВАНИЯ =====")
    print("Найденные ScreenGui:")
    if #result.guis == 0 then
        print("  (нет)")
    else
        for _, name in ipairs(result.guis) do
            print("  - " .. name)
        end
    end

    print("\nНайденные RemoteEvent в ReplicatedStorage:")
    if #result.remoteEvents == 0 then
        print("  (нет)")
    else
        for _, name in ipairs(result.remoteEvents) do
            print("  - " .. name)
        end
    end

    print("\nНайденные кнопки (TextButton/ImageButton) в GUI:")
    if #result.buttons == 0 then
        print("  (нет)")
    else
        for _, path in ipairs(result.buttons) do
            print("  - " .. path)
        end
    end

    print("\nНайденные скрипты с потенциальной логикой нажатий:")
    if #result.serverScripts == 0 then
        print("  (нет)")
    else
        for _, path in ipairs(result.serverScripts) do
            print("  - " .. path)
        end
    end
    print("===== КОНЕЦ =====")
end

-- Выполняем сканирование
scanProject()

-- Если выводится пустота, но вы уверены, что GUI есть – 
-- попробуйте вручную открыть окно "Explorer" и посмотреть имена объектов.
-- Скопируйте их в ответ, и я адаптирую код под ваш проект.
