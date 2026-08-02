-- =============================================================================
--  ПОЛНЫЙ ДАМП ВСЕХ ДОСТУПНЫХ ФУНКЦИЙ (без ограничений, с большими паузами)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  Скрипт собирает функции из всех возможных источников, сохраняет в файл.
--  Для стабильности добавлены паузы после каждых 100 функций из getgc.
--  Ошибки перехватываются, сбор продолжается.
-- =============================================================================

print("=== ПОЛНЫЙ СБОР ВСЕХ ФУНКЦИЙ (без лимита) ===")
print("ВНИМАНИЕ: процесс может занять много времени и использовать много памяти.")

local allFunctions = {}
local totalCount = 0

-- Безопасное добавление функции
local function addFunc(name, func)
    table.insert(allFunctions, {name = name, func = func})
    totalCount = totalCount + 1
    -- Каждые 1000 функций выводим прогресс
    if totalCount % 1000 == 0 then
        print("  Собрано функций: " .. totalCount)
        wait(0.2)
    end
end

-- Рекурсивный сбор из таблицы (глубина 1, чтобы не зациклиться)
local function collectFromTable(tbl, prefix, depth)
    depth = depth or 0
    if depth > 2 then return end  -- разрешаем два уровня вложенности
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if type(v) == "function" then
            addFunc(prefix .. tostring(k), v)
        elseif type(v) == "table" and depth < 2 then
            collectFromTable(v, prefix .. tostring(k) .. ".", depth + 1)
        end
    end
end

-- ---- ЭТАП 1: _G ----
print("Сбор _G...")
pcall(function() collectFromTable(_G, "_G.") end)
wait(1)

-- ---- ЭТАП 2: shared ----
if shared then
    print("Сбор shared...")
    pcall(function() collectFromTable(shared, "shared.") end)
end
wait(1)

-- ---- ЭТАП 3: getreg() ----
if getreg then
    print("Сбор getreg...")
    pcall(function()
        local reg = getreg()
        if type(reg) == "table" then
            for i, v in ipairs(reg) do
                if type(v) == "function" then
                    addFunc("reg[" .. i .. "]", v)
                end
            end
        end
    end)
end
wait(1)

-- ---- ЭТАП 4: getgc() (все объекты, с паузами каждые 100) ----
if getgc then
    print("Сбор getgc (все объекты, с паузами каждые 100 функций)...")
    pcall(function()
        local gc = getgc()
        local funcCount = 0
        for i, obj in ipairs(gc) do
            if type(obj) == "function" then
                addFunc("gc[" .. i .. "]", obj)
                funcCount = funcCount + 1
                if funcCount % 100 == 0 then
                    wait(0.2)  -- пауза для стабильности
                    print("  getgc прогресс: " .. funcCount .. " функций собрано")
                end
            end
        end
        print("  Всего функций из getgc: " .. funcCount)
    end)
end
wait(1)

-- ---- ЭТАП 5: getrenv() ----
if getrenv then
    print("Сбор getrenv...")
    pcall(function()
        local renv = getrenv()
        if type(renv) == "table" then
            collectFromTable(renv, "renv.")
        end
    end)
end
wait(1)

-- ---- ЭТАП 6: debug.getregistry() ----
if debug and debug.getregistry then
    print("Сбор debug.getregistry...")
    pcall(function()
        local reg = debug.getregistry()
        if type(reg) == "table" then
            collectFromTable(reg, "debug_registry.")
        end
    end)
end

print("Итого собрано функций: " .. totalCount)

-- ---- СОХРАНЕНИЕ В ФАЙЛ ----
print("Формирование содержимого файла...")
local fileContent = "===== ПОЛНЫЙ ДАМП ВСЕХ ФУНКЦИЙ =====\n"
fileContent = fileContent .. "Всего функций: " .. totalCount .. "\n\n"

local function writeProgress(i)
    if i % 5000 == 0 then
        print("  Записано в файл: " .. i .. " функций")
    end
end

-- Построчное добавление (чтобы не держать огромную строку в памяти)
-- Но writefile требует полную строку, поэтому собираем частями
local chunks = {}
local chunkSize = 10000
for i = 1, #allFunctions, chunkSize do
    local chunk = ""
    for j = i, math.min(i + chunkSize - 1, #allFunctions) do
        local item = allFunctions[j]
        chunk = chunk .. "[" .. j .. "] " .. item.name .. "\n"
        chunk = chunk .. "    Адрес: " .. tostring(item.func) .. "\n\n"
    end
    table.insert(chunks, chunk)
    if i % 50000 == 0 then
        print("  Подготовлено " .. i .. " записей")
    end
end

local fullContent = table.concat(chunks)
fullContent = fileContent .. fullContent

if writefile then
    local success, err = pcall(function()
        writefile("functions_full_dump.txt", fullContent)
        print("Файл 'functions_full_dump.txt' сохранён.")
        print("Размер файла: " .. #fullContent .. " байт")
    end)
    if not success then
        print("Ошибка записи файла: " .. tostring(err))
        print("Попытка записать частями...")
        -- Если файл слишком большой, попробуем записать в несколько файлов
        for i = 1, #chunks do
            local filename = "functions_dump_part" .. i .. ".txt"
            local partContent = fileContent .. chunks[i]
            pcall(function()
                writefile(filename, partContent)
                print("Сохранён файл: " .. filename)
            end)
        end
    end
else
    print("writefile недоступен. Вывод первых 1000 функций в консоль:")
    for i = 1, math.min(1000, #allFunctions) do
        print("[" .. i .. "] " .. allFunctions[i].name)
    end
end

print("=== ДАМП ЗАВЕРШЁН ===")
print("Всего собрано: " .. totalCount .. " функций.")
