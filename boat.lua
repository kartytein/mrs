-- ================================================================
--  МАКСИМАЛЬНАЯ ИНФОРМАЦИЯ О КЛЮЧАХ _G (сохранение в файл)
--  Вставьте в консоль Delta после загрузки HUB.
--  Будет создан файл "G_analysis.txt" с подробным отчётом.
-- ================================================================

local function analyzeGlobal()
    local report = {
        "=== АНАЛИЗ ГЛОБАЛЬНОЙ ТАБЛИЦЫ _G ===",
        "Всего ключей: " .. #({}),
        ""
    }

    local function inspectValue(value, depth)
        depth = depth or 0
        local indent = string.rep("  ", depth)
        local valueType = type(value)
        if valueType == "number" or valueType == "string" or valueType == "boolean" then
            return indent .. tostring(value)
        elseif valueType == "function" then
            local info = {}
            -- Попытка получить информацию о функции (если доступно)
            local debugInfo = debug and debug.getinfo and debug.getinfo(value)
            if debugInfo then
                if debugInfo.nparams then
                    table.insert(info, "параметров: " .. debugInfo.nparams)
                end
                if debugInfo.isvararg then
                    table.insert(info, "vararg")
                end
                if debugInfo.name then
                    table.insert(info, "имя: " .. debugInfo.name)
                end
                if debugInfo.source then
                    table.insert(info, "исходник: " .. debugInfo.source)
                end
            else
                table.insert(info, "(информация недоступна)")
            end
            return indent .. "function [" .. table.concat(info, ", ") .. "]"
        elseif valueType == "table" then
            local count = 0
            local sample = {}
            for k, v in pairs(value) do
                count = count + 1
                if count <= 5 then
                    table.insert(sample, tostring(k) .. "=" .. type(v))
                end
            end
            if count > 5 then
                table.insert(sample, "... и ещё " .. (count-5) .. " элементов")
            end
            return indent .. "table [" .. count .. " элементов] примеры: " .. table.concat(sample, ", ")
        elseif valueType == "userdata" then
            return indent .. "userdata (объект Roblox)"
        else
            return indent .. type(value)
        end
    end

    local suspicious = {}  -- ключи с подозрительными именами

    for key, value in pairs(_G) do
        local keyStr = tostring(key)
        local info = keyStr .. " (" .. type(value) .. ")"

        -- Детальное содержимое
        local details = inspectValue(value, 1)
        table.insert(report, info)
        table.insert(report, "  " .. details)

        -- Отдельно собираем подозрительные ключи
        local lowerKey = keyStr:lower()
        if lowerKey:find("toggle") or lowerKey:find("option") or lowerKey:find("enable") or lowerKey:find("disable") or 
           lowerKey:find("switch") or lowerKey:find("state") or lowerKey:find("flag") or lowerKey:find("click") or
           lowerKey:find("activate") or lowerKey:find("redz") or lowerKey:find("hub") or lowerKey:find("library") then
            table.insert(suspicious, keyStr)
        end
    end

    -- Добавляем итоговый раздел с кандидатами
    table.insert(report, "")
    table.insert(report, "=== ВЕРОЯТНЫЕ КАНДИДАТЫ (по именам) ===")
    if #suspicious > 0 then
        for _, name in ipairs(suspicious) do
            table.insert(report, "  " .. name)
        end
    else
        table.insert(report, "  (ничего не найдено)")
    end

    -- Сохраняем в файл
    local content = table.concat(report, "\n")
    if writefile then
        writefile("G_analysis.txt", content)
        print("Полный отчёт сохранён в G_analysis.txt")
    else
        print("writefile не поддерживается. Вывод в консоль (будет длинным):")
        for _, line in ipairs(report) do
            print(line)
        end
    end

    -- Выводим краткий итог в консоль
    print("\n=== КРАТКИЙ ИТОГ ===")
    print("Всего ключей: " .. #({}))
    print("Подозрительных ключей: " .. #suspicious)
    if #suspicious > 0 then
        print("Список кандидатов:")
        for _, name in ipairs(suspicious) do
            print("  " .. name)
        end
        print("Для вызова кандидата используйте: _G['имя']()")
        print("Если это таблица, изучите её содержимое: for k,v in pairs(_G['имя']) do print(k,v) end")
    else
        print("Кандидатов не найдено. Изучите полный отчёт в файле.")
    end
end

-- Запуск анализа
analyzeGlobal()
