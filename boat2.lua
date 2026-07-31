-- =============================================================================
-- АНАЛИЗАТОР ПРОЕКТА ДЛЯ ПОИСКА ДАННЫХ О КНОПКАХ, REMOTEEVENT И ФУНКЦИЯХ
-- Скопируйте этот код в Roblox Studio (в CommandBar или в отдельный ModuleScript)
-- и выполните его. В консоль (Output) будет выведена структура вашего HUB.
-- =============================================================================

local function analyzeProject()
    print("========== АНАЛИЗ ПРОЕКТА ==========")

    -- 1. Ищем все ScreenGui в StarterGui и в PlayerGui (если есть)
    local guis = {}
    local starterGui = game:GetService("StarterGui")
    for _, child in ipairs(starterGui:GetChildren()) do
        if child:IsA("ScreenGui") then
            table.insert(guis, child)
        end
    end
    -- Также проверяем, есть ли GUI, создаваемые динамически (например, в ReplicatedStorage)
    local replicatedStorage = game:GetService("ReplicatedStorage")
    for _, child in ipairs(replicatedStorage:GetChildren()) do
        if child:IsA("ScreenGui") then
            table.insert(guis, child)
        end
    end

    if #guis == 0 then
        print("Не найдено ни одного ScreenGui в StarterGui или ReplicatedStorage.")
        print("Возможно, GUI создаётся динамически через скрипты. Проверьте код.")
    else
        print("Найдено GUI:")
        for _, gui in ipairs(guis) do
            print("  - " .. gui:GetFullName())
            -- Ищем все кнопки (TextButton, ImageButton) внутри GUI
            local buttons = {}
            local function findButtons(parent)
                for _, child in ipairs(parent:GetChildren()) do
                    if child:IsA("TextButton") or child:IsA("ImageButton") then
                        table.insert(buttons, child)
                    end
                    -- Рекурсивный обход
                    findButtons(child)
                end
            end
            findButtons(gui)
            if #buttons > 0 then
                print("    Кнопки:")
                for _, btn in ipairs(buttons) do
                    print("      - " .. btn.Name .. " (путь: " .. btn:GetFullName() .. ")")
                    -- Проверяем, есть ли у кнопки событие MouseButton1Click или Server/Client скрипт
                    local hasClick = false
                    local connections = btn:GetPropertyChangedSignal("MouseButton1Click") -- так нельзя, лучше проверить наличие скриптов
                    -- Вместо этого проверим дочерние скрипты и локальные скрипты
                    for _, script in ipairs(btn:GetChildren()) do
                        if script:IsA("Script") or script:IsA("LocalScript") then
                            print("        - Содержит скрипт: " .. script.Name)
                        end
                    end
                    -- Также проверим события в родительских скриптах (сложно, но оставим как есть)
                end
            else
                print("    Кнопок не найдено.")
            end
        end
    end

    -- 2. Ищем RemoteEvent в ReplicatedStorage (обычно используется для связи)
    print("\nИщем RemoteEvent в ReplicatedStorage:")
    local remoteEvents = {}
    for _, child in ipairs(replicatedStorage:GetChildren()) do
        if child:IsA("RemoteEvent") then
            table.insert(remoteEvents, child)
        end
    end
    if #remoteEvents == 0 then
        print("  Не найдено RemoteEvent в ReplicatedStorage.")
        print("  Возможно, используется BindableEvent или другой способ.")
    else
        print("  Найдены RemoteEvent:")
        for _, ev in ipairs(remoteEvents) do
            print("    - " .. ev.Name .. " (путь: " .. ev:GetFullName() .. ")")
            -- Попробуем найти, где этот RemoteEvent используется (поиск по скриптам)
            -- Это сложно, просто выведем имя.
        end
    end

    -- 3. Ищем скрипты, которые обрабатывают нажатие кнопок (обычно в ServerScriptService или внутри GUI)
    print("\nИщем скрипты, которые могут содержать логику кнопок (поиск по ключевым словам):")
    local serverScripts = game:GetService("ServerScriptService"):GetChildren()
    local foundScripts = {}
    for _, script in ipairs(serverScripts) do
        if script:IsA("Script") or script:IsA("ModuleScript") then
            -- Проверим содержимое на наличие ключевых слов (только если это не бинарный код)
            local content = script:IsA("Script") and script.Source or ""
            if content and string.find(content, "MouseButton1Click") or string.find(content, ".OnServerEvent") or string.find(content, "RemoteEvent") then
                table.insert(foundScripts, script)
            end
        end
    end
    if #foundScripts > 0 then
        print("  Найдены скрипты с возможной логикой кнопок:")
        for _, scr in ipairs(foundScripts) do
            print("    - " .. scr:GetFullName())
        end
    else
        print("  Не найдено скриптов с ключевыми словами (возможно, логика в LocalScript).")
    end

    -- 4. Поиск LocalScript в StarterPlayerScripts и StarterCharacterScripts
    print("\nИщем LocalScript в StarterPlayerScripts:")
    local starterPlayer = game:GetService("StarterPlayer")
    local playerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
    if playerScripts then
        for _, child in ipairs(playerScripts:GetChildren()) do
            if child:IsA("LocalScript") then
                print("  - " .. child:GetFullName())
            end
        end
    else
        print("  StarterPlayerScripts не найдены.")
    end

    print("\n========== КОНЕЦ АНАЛИЗА ==========")
    print("Скопируйте вывод и предоставьте его мне для дальнейшей интеграции команд.")
end

-- Запускаем анализ (можно раскомментировать, если запускаете в CommandBar)
-- analyzeProject()

-- Если вы хотите выполнить этот код в CommandBar, просто вызовите analyzeProject()
-- или вставьте его и выполните.
