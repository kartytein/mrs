-- =============================================================================
--  ПОЛНЫЙ ДАМП ВСЕХ ФУНКЦИЙ (БЕЗ ОГРАНИЧЕНИЙ) С ПАУЗАМИ
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  Будет создан файл "functions_full_dump.txt" со ВСЕМИ найденными функциями.
--  ВНИМАНИЕ: файл может быть очень большим (сотни тысяч строк).
-- =============================================================================

print("=== ПОЛНЫЙ СБОР ВСЕХ ФУНКЦИЙ (без лимита) ===")
print("Это может занять несколько минут...")

local allFunctions = {}
local function addFunction(name, func)
    table.insert(allFunctions, {name = name, func = func})
end

-- Вспомогательная функция для обхода таблицы с паузами
local function scanTable(tbl, prefix, maxDepth)
    maxDepth = maxDepth or 2  -- глубина вложенности, чтобы не зациклиться
    local function recursiveScan(current, path, depth)
        if depth > maxDepth then return end
        if type(current) ~= "table" then return end
        for k, v in pairs(current) do
            if type(v) == "function" then
                addFunction(path .. "." .. tostring(k), v)
            elseif type(v) == "table" and depth < maxDepth then
                recursiveScan(v, path .. "." .. tostring(k), depth + 1)
            end
        end
    end
    recursiveScan(tbl, prefix, 0)
end

-- 1. _G
print("Сбор _G...")
scanTable(_G, "_G")
wait(0.5)
print("  Найдено функций: " .. #allFunctions)

-- 2. shared
if shared then
    print("Сбор shared...")
    scanTable(shared, "shared")
    wait(0.5)
    print("  Найдено функций: " .. #allFunctions)
end

-- 3. getreg()
if getreg then
    print("Сбор getreg...")
    local reg = getreg()
    if type(reg) == "table" then
        for i, v in ipairs(reg) do
            if type(v) == "function" then
                addFunction("reg[" .. i .. "]", v)
            end
            if i % 100 == 0 then wait(0.05) end
        end
    end
    wait(0.5)
    print("  Найдено функций: " .. #allFunctions)
end

-- 4. getgc() – все объекты (может быть очень много)
if getgc then
    print("Сбор getgc (все объекты, может занять время)...")
    local gc = getgc()
    local count = 0
    for i, obj in ipairs(gc) do
        if type(obj) == "function" then
            addFunction("gc[" .. i .. "]", obj)
            count = count + 1
        end
        if i % 100 == 0 then wait(0.05) end
    end
    wait(0.5)
    print("  Найдено функций в gc: " .. count)
    print("  Всего собрано: " .. #allFunctions)
end

-- 5. getrenv()
if getrenv then
    print("Сбор getrenv...")
    local renv = getrenv()
    if type(renv) == "table" then
        scanTable(renv, "renv")
    end
    wait(0.5)
    print("  Найдено функций: " .. #allFunctions)
end

-- 6. debug.getregistry()
if debug and debug.getregistry then
    print("Сбор debug.getregistry...")
    local reg = debug.getregistry()
    if type(reg) == "table" then
        scanTable(reg, "debug_registry")
    end
    wait(0.5)
    print("  Найдено функций: " .. #allFunctions)
end

-- 7. Дополнительно: окружения всех скриптов (если доступно)
if getfenv and debug and debug.getinfo then
    print("Сбор окружений скриптов (может быть медленно)...")
    for level = 0, 100 do
        local info = debug.getinfo(level)
        if not info then break end
        local env = getfenv(level)
        if env and type(env) == "table" and env ~= _G and env ~= shared then
            -- Не полный обход, чтобы не повторяться, но добавим функции
            for k, v in pairs(env) do
                if type(v) == "function" then
                    addFunction("env_level" .. level .. "." .. tostring(k), v)
                end
            end
        end
        if level % 10 == 0 then wait(0.1) end
    end
    print("  Найдено функций: " .. #allFunctions)
end

print("=== СБОР ЗАВЕРШЁН ===")
print("Всего собрано функций: " .. #allFunctions)

-- Формируем содержимое файла
local fileContent = "===== ПОЛНЫЙ ДАМП ВСЕХ ФУНКЦИЙ =====\n"
fileContent = fileContent .. "Всего функций: " .. #allFunctions .. "\n\n"

-- Создаём содержимое по частям, чтобы не перегружать память
local CHUNK_SIZE = 5000
local function writeChunk(startIdx)
    local chunk = {}
    for i = startIdx, math.min(startIdx + CHUNK_SIZE - 1, #allFunctions) do
        local item = allFunctions[i]
        table.insert(chunk, "[" .. i .. "] " .. item.name .. "\n    Адрес: " .. tostring(item.func) .. "\n\n")
    end
    return table.concat(chunk)
end

if writefile then
    local fileName = "functions_full_dump.txt"
    -- Записываем заголовок
    writefile(fileName, fileContent)
    -- Дописываем по частям
    for i = 1, #allFunctions, CHUNK_SIZE do
        local chunkText = writeChunk(i)
        writefile(fileName, chunkText, true)  -- append
        if i % CHUNK_SIZE == 0 then
            print("Записано " .. i .. " из " .. #allFunctions)
            wait(0.2)
        end
    end
    print("Файл сохранён: " .. fileName)
    print("Путь: " .. (getcwd and getcwd() or "рабочая папка Delta"))
else
    print("writefile недоступен. Вывод в консоль (первые 100 записей):")
    for i = 1, math.min(100, #allFunctions) do
        print("[" .. i .. "] " .. allFunctions[i].name)
    end
    print("Остальные функции не отображены из-за отсутствия writefile.")
end

print("=== ДАМП ЗАВЕРШЁН ===")
