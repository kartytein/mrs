-- =============================================================================
--  ПОЛНЫЙ ДАМП ВСЕХ ФУНКЦИЙ (без ограничений, с увеличенными паузами)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  Будет создан файл "functions_full_dump.txt" со ВСЕМИ найденными функциями.
--  Добавлены паузы между этапами и внутри больших циклов для стабильности.
-- =============================================================================

print("=== ПОЛНЫЙ СБОР ВСЕХ ФУНКЦИЙ (с большими паузами) ===")

local allFunctions = {}
local MAX = 15000 -- увеличили лимит (можно убрать или поднять)

-- Функция добавления с проверкой лимита
local function addFunc(name, func)
    if #allFunctions >= MAX then 
        print("Достигнут лимит функций (" .. MAX .. "), остановка.")
        return false 
    end
    table.insert(allFunctions, {name = name, func = func})
    return true
end

-- Рекурсивный сбор функций из таблицы (глубина 1)
local function collectFromTable(tbl, prefix, depth)
    depth = depth or 0
    if depth > 1 then return end
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if #allFunctions >= MAX then break end
        if type(v) == "function" then
            local key = tostring(k)
            addFunc(prefix .. key, v)
        elseif type(v) == "table" and depth == 0 then
            collectFromTable(v, prefix .. tostring(k) .. ".", depth + 1)
        end
    end
end

-- ---- ЭТАП 1: _G ----
print("Сбор _G...")
pcall(function()
    collectFromTable(_G, "_G.")
end)
wait(1)  -- большая пауза

-- ---- ЭТАП 2: shared ----
if shared then
    print("Сбор shared...")
    pcall(function()
        collectFromTable(shared, "shared.")
    end)
end
wait(1)

-- ---- ЭТАП 3: getreg() ----
if getreg then
    print("Сбор getreg...")
    pcall(function()
        local reg = getreg()
        if type(reg) == "table" then
            for i, v in ipairs(reg) do
                if #allFunctions >= MAX then break end
                if type(v) == "function" then
                    addFunc("reg[" .. i .. "]", v)
                end
            end
        end
    end)
end
wait(1)

-- ---- ЭТАП 4: getgc() - БЕЗ ОГРАНИЧЕНИЙ, с паузами ----
if getgc then
    print("Сбор getgc (все объекты, с паузами каждые 50 функций)...")
    pcall(function()
        local gc = getgc()
        local count = 0
        for i, obj in ipairs(gc) do
            if #allFunctions >= MAX then break end
            if type(obj) == "function" then
                addFunc("gc[" .. i .. "]", obj)
                count = count + 1
                if count % 50 == 0 then
                    wait(0.1)  -- пауза после каждых 50 функций
                    print("  Прогресс getgc: собрано " .. count .. " функций")
                end
            end
        end
        print("  Всего функций из getgc: " .. count)
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

print("Итого собрано функций: " .. #allFunctions)

-- ---- СОХРАНЕНИЕ В ФАЙЛ ----
local fileContent = "===== ПОЛНЫЙ ДАМП ФУНКЦИЙ =====\n"
fileContent = fileContent .. "Всего функций: " .. #allFunctions .. "\n\n"

for i, item in ipairs(allFunctions) do
    fileContent = fileContent .. "[" .. i .. "] " .. item.name .. "\n"
    fileContent = fileContent .. "    Адрес: " .. tostring(item.func) .. "\n\n"
end

local saved = false
if writefile then
    local success, err = pcall(function()
        writefile("functions_full_dump.txt", fileContent)
        saved = true
        print("Файл 'functions_full_dump.txt' сохранён.")
    end)
    if not success then
        print("Ошибка записи файла: " .. tostring(err))
    end
end

if not saved then
    print("writefile недоступен. Вывод первых 500 функций в консоль:")
    for i = 1, math.min(500, #allFunctions) do
        print("[" .. i .. "] " .. allFunctions[i].name)
    end
end

print("=== ДАМП ЗАВЕРШЁН ===")
