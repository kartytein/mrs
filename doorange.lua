-- ================================================================
-- H2O2 Tracer
-- Запускать в исполнителе ПЕРЕД Loading_UI
-- Логи → ho2_log.txt
-- ================================================================

local LOG_FILE = "ho2_log.txt"
local MAX_LINES = 500000           -- защита от переполнения
local FLUSH_EVERY = 20             -- сбрасывать буфер каждые N строк
local LOG_BYTE_MIN_LEN = 100       -- string.byte логируем только для длинных строк
local BXOR_MIN_ARG = 128           -- bxor логируем если любой аргумент >= этого
local CHAR_MIN_LEN = 4             -- string.char логируем если собрано N+ символов

-- ================================================================
-- Проверки окружения
-- ================================================================
if type(writefile) ~= "function" then
    error("[tracer] writefile недоступен в этом исполнителе — лог писать некуда")
end

local has_append = type(appendfile) == "function"
local has_read   = type(readfile)   == "function"

-- стартовая очистка файла
pcall(function() writefile(LOG_FILE, "") end)

-- ================================================================
-- Логгер с защитой от рекурсии
-- ================================================================
local BUFFER = {}
local line_count = 0
local in_log = false
local stopped = false

local function flush()
    if #BUFFER == 0 then return end
    local data = table.concat(BUFFER, "\n") .. "\n"
    BUFFER = {}
    if has_append then
        pcall(appendfile, LOG_FILE, data)
    else
        local prev = ""
        if has_read then
            pcall(function() prev = readfile(LOG_FILE) end)
        end
        pcall(writefile, LOG_FILE, prev .. data)
    end
end

local function log(...)
    if in_log or stopped then return end
    in_log = true
    local n = select("#", ...)
    local parts = table.create and table.create(n) or {}
    for i = 1, n do
        local v = select(i, ...)
        if type(v) == "string" and #v > 400 then
            parts[i] = v:sub(1, 400) .. "…[" .. #v .. "]"
        else
            parts[i] = tostring(v)
        end
    end
    BUFFER[#BUFFER + 1] = table.concat(parts, " ")
    line_count = line_count + 1
    if line_count >= MAX_LINES then
        stopped = true
        BUFFER[#BUFFER + 1] = "[tracer] лимит строк исчерпан — логирование остановлено"
    end
    if #BUFFER >= FLUSH_EVERY then flush() end
    in_log = false
end

-- фоновый flush каждые 2 сек
if task and task.spawn then
    task.spawn(function()
        while not stopped do
            task.wait(2)
            if #BUFFER > 0 then flush() end
        end
    end)
end

log("[tracer] ========================================")
log("[tracer] старт", os.date("%Y-%m-%d %H:%M:%S"))
log("[tracer] append =", has_append)
log("[tracer] ========================================")

-- логируем стартовое содержимое _G.HOHO_SERVER_ID, если задано
if _G.HOHO_SERVER_ID then
    log("[tracer] _G.HOHO_SERVER_ID =", tostring(_G.HOHO_SERVER_ID[1]),
        tostring(_G.HOHO_SERVER_ID[2]):sub(1, 200))
end

-- ================================================================
-- 1. TeleportService (главный источник пар encoded→jobId)
-- ================================================================
local TP = game:GetService("TeleportService")

local function hook_teleport_method(method_name)
    local orig = TP[method_name]
    if type(orig) ~= "function" then
        log("[tracer] " .. method_name .. " не функция, skip")
        return false
    end
    local ok, err = pcall(function()
        TP[method_name] = function(self, ...)
            log("=== [TELEPORT." .. method_name .. "] ===")
            local n = select("#", ...)
            for i = 1, n do
                local v = select(i, ...)
                log("  arg" .. i .. ":", type(v), v)
            end
            log("=== end " .. method_name .. " ===")
            flush()
            return orig(self, ...)
        end
    end)
    if ok then
        log("[tracer] hooked TeleportService." .. method_name)
        return true
    else
        log("[tracer] fail hook " .. method_name .. ":", err)
        return false
    end
end

hook_teleport_method("TeleportToPlaceInstance")
hook_teleport_method("Teleport")
hook_teleport_method("TeleportAsync")
hook_teleport_method("TeleportToPrivateServer")

-- namecall hook (для случаев когда прямой реassign не работает)
if hookmetamethod and getnamecallmethod and getrawmetatable and newcclosure then
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        if setreadonly then setreadonly(mt, false) end
        local old_nc = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "TeleportToPlaceInstance"
               or method == "Teleport"
               or method == "TeleportAsync"
               or method == "TeleportToPrivateServer" then
                log("=== [NC." .. method .. "] ===")
                local n = select("#", ...)
                for i = 1, n do
                    local v = select(i, ...)
                    log("  arg" .. i .. ":", type(v), v)
                end
                log("=== end NC." .. method .. " ===")
                flush()
            end
            return old_nc(self, ...)
        end)
        if setreadonly then setreadonly(mt, true) end
    end)
    if ok then
        log("[tracer] namecall hook установлен")
    else
        log("[tracer] namecall hook не удалось:", err)
    end
else
    log("[tracer] hookmetamethod недоступен — только прямые хуки")
end

-- ================================================================
-- 2. bit32.bxor — частый примитив XOR-шифров
-- ================================================================
if bit32 and bit32.bxor then
    local old_bxor = bit32.bxor
    bit32.bxor = function(a, b)
        local r = old_bxor(a, b)
        if not in_log and not stopped
           and type(a) == "number" and type(b) == "number" then
            if a >= BXOR_MIN_ARG or b >= BXOR_MIN_ARG or r >= BXOR_MIN_ARG then
                log("[bxor]", a, b, "->", r)
            end
        end
        return r
    end
    log("[tracer] bit32.bxor hooked")
end

-- ================================================================
-- 3. string.byte — байты длинных строк
-- ================================================================
do
    local old_byte = string.byte
    string.byte = function(s, ...)
        local r = old_byte(s, ...)
        if not in_log and not stopped
           and type(s) == "string" and #s >= LOG_BYTE_MIN_LEN then
            log("[sbyte] len=", #s, "i=", ..., "->", r)
        end
        return r
    end
    log("[tracer] string.byte hooked")
end

-- ================================================================
-- 4. string.char — сборка результата из байтов
-- ================================================================
do
    local old_char = string.char
    string.char = function(...)
        local r = old_char(...)
        if not in_log and not stopped then
            local n = select("#", ...)
            if n >= CHAR_MIN_LEN and n <= 16 then
                local all_print = true
                for i = 1, n do
                    local c = select(i, ...)
                    if type(c) ~= "number" or c < 32 or c > 126 then
                        all_print = false
                        break
                    end
                end
                if all_print then
                    log("[char] n=", n, "->", r)
                end
            end
        end
        return r
    end
    log("[tracer] string.char hooked")
end

-- ================================================================
-- 5. debug.sethook — перехват вызовов функций с H2O2SERVER в аргументах
-- ================================================================
do
    local ok = false
    if debug and debug.sethook and debug.getinfo and debug.getlocal then
        ok = pcall(function()
            local calls = 0
            debug.sethook(function(event, _line)
                if event ~= "call" then return end
                calls = calls + 1
                if calls > 200000 then return end  -- вырубаем если слишком много

                local info = debug.getinfo(2, "Sl")
                if not info then return end

                for i = 1, 12 do
                    local name, val = debug.getlocal(2, i)
                    if not name then break end
                    if type(val) == "string" and #val >= 20 then
                        if string.find(val, "H2O2SERVER", 1, true) then
                            log("=== [CALL with H2O2SERVER] ===")
                            log("  func :", tostring(info.short_src))
                            log("  line :", tostring(info.currentline))
                            log("  arg# :", i, "name:", name)
                            log("  val  :", val:sub(1, 200))
                            log("=== end ===")
                            flush()
                            break
                        end
                    end
                end
            end, "c")
        end)
    end
    if ok then
        log("[tracer] debug.sethook установлен")
    else
        log("[tracer] debug.sethook недоступен или упал")
    end
end

-- ================================================================
-- 6. Готово — можно запускать Loading_UI
-- ================================================================
log("[tracer] все хуки установлены, можно запускать Loading_UI")
flush()

-- ================================================================
-- АВТОЗАПУСК (опционально)
-- Раскомментируй и подставь свой тестовый H2O2 + placeId,
-- чтобы трейсер сразу отработал.
-- ================================================================
-- _G.HOHO_SERVER_ID = {
--     994732206,
--     "H2O2SERVER|iNwbpopSpb7bpKpFpbDbpKpRp...ЗДЕСЬ_ТВОЯ_СТРОКА..."
-- }
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"))()
