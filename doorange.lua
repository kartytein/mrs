-- ================================================================
-- H2O2 Tracer v2
-- Пишет в консоль + ho2_log.txt
-- Запускать ПЕРЕД Loading_UI
-- ================================================================

local CFG = {
    LOG_FILE           = "ho2_log.txt",
    PRINT_TO_CONSOLE   = true,     -- дублировать в консоль
    FLUSH_EVERY_LINE   = true,     -- писать файл на каждой строке (медленно, но надёжно)

    HOOK_TELEPORT      = true,     -- главный источник пар encoded→jobId
    HOOK_NAMECALL      = true,     -- тот же телепорт через __namecall
    HOOK_BXOR          = true,     -- XOR-примитив
    HOOK_STRING_BYTE   = true,     -- байты длинных строк
    HOOK_STRING_CHAR   = true,     -- сборка результата из байтов

    HOOK_DEBUG_SETHOOK = false,    -- ТЯЖЁЛЫЙ, включать только если не поможет всё остальное

    BXOR_MIN_ARG       = 128,
    SBYTE_MIN_LEN      = 100,
    SCHAR_MIN_N        = 4,
    SCHAR_MAX_N        = 16,
}

-- ================================================================
-- Инициализация лога
-- ================================================================
local has_write  = type(writefile)  == "function"
local has_append = type(appendfile) == "function"
local has_read   = type(readfile)   == "function"

local LOG_LINES = {}

local function flush()
    if not has_write then return end
    local data = table.concat(LOG_LINES, "\n")
    if #data > 0 then data = data .. "\n" end
    pcall(writefile, CFG.LOG_FILE, data)
end

local function log(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        local v = select(i, ...)
        if type(v) == "string" and #v > 400 then
            parts[i] = v:sub(1, 400) .. "…[" .. #v .. "]"
        else
            parts[i] = tostring(v)
        end
    end
    local line = table.concat(parts, " ")
    LOG_LINES[#LOG_LINES + 1] = line

    if CFG.PRINT_TO_CONSOLE then
        print("[ho2] " .. line)
    end

    if CFG.FLUSH_EVERY_LINE then
        flush()
    end
end

-- очищаем файл в начале
if has_write then
    pcall(writefile, CFG.LOG_FILE, "")
end

log("=================================================")
log("H2O2 Tracer v2 запущен")
log("writefile:", has_write, "appendfile:", has_append, "readfile:", has_read)
log("=================================================")

-- ================================================================
-- 1. TeleportService — прямой hook
-- ================================================================
if CFG.HOOK_TELEPORT then
    local TP = game:GetService("TeleportService")

    local function hook_method(name)
        local orig = TP[name]
        if type(orig) ~= "function" then
            log("TeleportService." .. name .. " — не функция, skip")
            return
        end
        local ok, err = pcall(function()
            TP[name] = function(self, ...)
                log("=== [TELEPORT." .. name .. "] ===")
                local cnt = select("#", ...)
                for i = 1, cnt do
                    local v = select(i, ...)
                    log("  arg" .. i .. " (" .. type(v) .. "):", v)
                end
                log("=== end " .. name .. " ===")
                return orig(self, ...)
            end
        end)
        if ok then
            log("hooked TeleportService." .. name)
        else
            log("FAIL hook TeleportService." .. name .. ":", err)
        end
    end

    hook_method("TeleportToPlaceInstance")
    hook_method("Teleport")
    hook_method("TeleportAsync")
    hook_method("TeleportToPrivateServer")
end

-- ================================================================
-- 2. __namecall — тот же телепорт, но через metamethod
-- ================================================================
if CFG.HOOK_NAMECALL then
    local have_api = hookmetamethod and getnamecallmethod and getrawmetatable
                     and newcclosure
    if have_api then
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
                    local cnt = select("#", ...)
                    for i = 1, cnt do
                        local v = select(i, ...)
                        log("  arg" .. i .. " (" .. type(v) .. "):", v)
                    end
                    log("=== end NC." .. method .. " ===")
                end
                return old_nc(self, ...)
            end)
            if setreadonly then setreadonly(mt, true) end
        end)
        if ok then
            log("namecall hook установлен")
        else
            log("FAIL namecall hook:", err)
        end
    else
        log("hookmetamethod недоступен — namecall пропущен")
    end
end

-- ================================================================
-- 3. bit32.bxor
-- ================================================================
if CFG.HOOK_BXOR and bit32 and bit32.bxor then
    local old = bit32.bxor
    bit32.bxor = function(a, b)
        local r = old(a, b)
        if type(a) == "number" and type(b) == "number"
           and (a >= CFG.BXOR_MIN_ARG or b >= CFG.BXOR_MIN_ARG
                or r >= CFG.BXOR_MIN_ARG) then
            log("[bxor]", a, b, "->", r)
        end
        return r
    end
    log("bit32.bxor hooked")
end

-- ================================================================
-- 4. string.byte
-- ================================================================
if CFG.HOOK_STRING_BYTE then
    local old = string.byte
    string.byte = function(s, ...)
        local r = old(s, ...)
        if type(s) == "string" and #s >= CFG.SBYTE_MIN_LEN then
            log("[sbyte] len=" .. #s .. " idx=" .. tostring(...)
                .. " -> " .. tostring(r))
        end
        return r
    end
    log("string.byte hooked")
end

-- ================================================================
-- 5. string.char
-- ================================================================
if CFG.HOOK_STRING_CHAR then
    local old = string.char
    string.char = function(...)
        local r = old(...)
        local n = select("#", ...)
        if n >= CFG.SCHAR_MIN_N and n <= CFG.SCHAR_MAX_N then
            local printable = true
            for i = 1, n do
                local c = select(i, ...)
                if type(c) ~= "number" or c < 32 or c > 126 then
                    printable = false
                    break
                end
            end
            if printable then
                log("[char] n=" .. n .. " -> " .. r)
            end
        end
        return r
    end
    log("string.char hooked")
end

-- ================================================================
-- 6. debug.sethook — ОПЦИОНАЛЬНО, тяжёлый
-- ================================================================
if CFG.HOOK_DEBUG_SETHOOK then
    if debug and debug.sethook and debug.getinfo and debug.getlocal then
        local calls = 0
        local ok, err = pcall(function()
            debug.sethook(function(event, _line)
                if event ~= "call" then return end
                calls = calls + 1
                if calls > 300000 then return end

                local info = debug.getinfo(2, "Sl")
                if not info then return end

                for i = 1, 12 do
                    local name, val = debug.getlocal(2, i)
                    if not name then break end
                    if type(val) == "string" and #val >= 20
                       and string.find(val, "H2O2SERVER", 1, true) then
                        log("=== [CALL with H2O2SERVER] ===")
                        log("  func:", tostring(info.short_src))
                        log("  line:", tostring(info.currentline))
                        log("  arg #" .. i .. " (" .. name .. "):",
                            val:sub(1, 200))
                        log("=== end ===")
                        break
                    end
                end
            end, "c")
        end)
        if ok then
            log("debug.sethook установлен (тяжёлый режим)")
        else
            log("FAIL debug.sethook:", err)
        end
    else
        log("debug.sethook недоступен")
    end
end

-- ================================================================
-- Готово
-- ================================================================
log("=================================================")
log("Все хуки установлены. Лог:", CFG.LOG_FILE)
log("Дальше запускай Loading_UI")
log("=================================================")
flush()

-- ================================================================
-- Опциональный автозапуск
-- ================================================================
-- _G.HOHO_SERVER_ID = {994732206, "H2O2SERVER|iNwbpopSpb7bpKpFp..."}
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"))()
