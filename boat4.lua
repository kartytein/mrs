-- ===== ПОЭТАПНЫЙ ТРЕКЕР ДЛЯ ВЫЯВЛЕНИЯ ПРИЧИНЫ КРАША =====
-- Каждый метод включается с интервалом 5 секунд, результат логируется.
-- Если краш происходит, вы увидите, какой этап был включён последним.

local teleportService = game:GetService("TeleportService")
local players = game:GetService("Players")
local logService = game:GetService("LogService")
local runService = game:GetService("RunService")

-- Функция логирования
local function log(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = "[" .. timestamp .. "] " .. msg .. "\n"
    if appendfile then
        appendfile("teleport_tracker_stages.txt", line)
    else
        local old = (readfile and readfile("teleport_tracker_stages.txt")) or ""
        writefile("teleport_tracker_stages.txt", old .. line)
    end
end

-- Инициализация
writefile("teleport_tracker_stages.txt", "=== Stage Tracker ===\n")
log("Старт. Ожидание 5 секунд до первого этапа...")

-- Флаг защиты от рекурсии
local isLogging = false

-- ========== ЭТАП 1: ПЕРЕХВАТ TELEPORTSERVICE (ждём 5 сек) ==========
task.wait(5)
log("Этап 1: включение TeleportService hooks")
local teleportMethods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}
for _, methodName in ipairs(teleportMethods) do
    local ok, err = pcall(function()
        local original = teleportService[methodName]
        if type(original) == "function" then
            hookfunction(original, function(...)
                if isLogging then return original(...) end
                isLogging = true
                local args = {...}
                local argStr = ""
                for i, v in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    if typeof(v) == "Instance" then
                        argStr = argStr .. tostring(v) .. " [" .. v.ClassName .. "]"
                    elseif typeof(v) == "table" then
                        argStr = argStr .. "table:" .. tostring(v)
                    else
                        argStr = argStr .. tostring(v)
                    end
                end
                log("TeleportService." .. methodName .. " вызван: " .. argStr)
                isLogging = false
                return original(...)
            end)
            log("  Хук установлен на TeleportService." .. methodName)
        else
            log("  Не найден метод TeleportService." .. methodName)
        end
    end)
    if not ok then
        log("  Ошибка при установке хука на " .. methodName .. ": " .. tostring(err))
    end
end
log("Этап 1 завершён.")

-- ========== ЭТАП 2: ПЕРЕХВАТ GAME.JOBID (ждём 5 сек) ==========
task.wait(5)
log("Этап 2: включение game.JobId hook")
local ok, err = pcall(function()
    local gameMT = getrawmetatable(game)
    if gameMT then
        local oldIndex = rawget(gameMT, "__index")
        local oldNewIndex = rawget(gameMT, "__newindex")
        if type(oldIndex) == "function" then
            hookfunction(oldIndex, function(self, key)
                local result = oldIndex(self, key)
                if key == "JobId" or key == "jobId" then
                    log("game.__index: JobId = " .. tostring(result))
                end
                return result
            end)
            log("  Хук установлен на game.__index (JobId)")
        end
        if type(oldNewIndex) == "function" then
            hookfunction(oldNewIndex, function(self, key, value)
                if key == "JobId" or key == "jobId" then
                    log("game.__newindex: установить " .. tostring(key) .. " = " .. tostring(value))
                end
                return oldNewIndex(self, key, value)
            end)
            log("  Хук установлен на game.__newindex (JobId)")
        end
    else
        log("  Не удалось получить метатаблицу game")
    end
end)
if not ok then
    log("  Ошибка на этапе 2: " .. tostring(err))
end
log("Этап 2 завершён.")

-- ========== ЭТАП 3: ПЕРЕХВАТ REMOTE ПО ИМЕНИ (ждём 5 сек) ==========
task.wait(5)
log("Этап 3: включение Remote hooks (фильтр по имени)")
local function looksLikeJobId(arg)
    return type(arg) == "string" and string.len(arg) > 20 and string.find(arg, "%-")
end
local function hookRemoteByName(remote)
    if remote:IsA("RemoteEvent") then
        local fireServer = remote.FireServer
        if type(fireServer) == "function" then
            hookfunction(fireServer, function(self, ...)
                if isLogging then return fireServer(self, ...) end
                local args = {...}
                local shouldLog = false
                local name = string.lower(remote.Name)
                if string.find(name, "teleport") or string.find(name, "job") or
                   string.find(name, "server") or string.find(name, "tp") then
                    shouldLog = true
                end
                for _, v in ipairs(args) do
                    if looksLikeJobId(v) then shouldLog = true break end
                end
                if shouldLog then
                    isLogging = true
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteEvent.FireServer: " .. tostring(remote) .. " -> " .. argStr)
                    isLogging = false
                end
                return fireServer(self, ...)
            end)
        end
    elseif remote:IsA("RemoteFunction") then
        local invokeServer = remote.InvokeServer
        if type(invokeServer) == "function" then
            hookfunction(invokeServer, function(self, ...)
                if isLogging then return invokeServer(self, ...) end
                local args = {...}
                local shouldLog = false
                local name = string.lower(remote.Name)
                if string.find(name, "teleport") or string.find(name, "job") or
                   string.find(name, "server") or string.find(name, "tp") then
                    shouldLog = true
                end
                for _, v in ipairs(args) do
                    if looksLikeJobId(v) then shouldLog = true break end
                end
                if shouldLog then
                    isLogging = true
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteFunction.InvokeServer: " .. tostring(remote) .. " -> " .. argStr)
                    isLogging = false
                end
                return invokeServer(self, ...)
            end)
        end
    end
end

-- Хукаем существующие Remote с подозрительными именами
for _, descendant in ipairs(game:GetDescendants()) do
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        local name = string.lower(descendant.Name)
        if string.find(name, "teleport") or string.find(name, "job") or
           string.find(name, "server") or string.find(name, "tp") then
            hookRemoteByName(descendant)
            log("  Захучен Remote: " .. tostring(descendant))
        end
    end
end

-- Ловим новые подозрительные Remote
game.DescendantAdded:Connect(function(desc)
    if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
        local name = string.lower(desc.Name)
        if string.find(name, "teleport") or string.find(name, "job") or
           string.find(name, "server") or string.find(name, "tp") then
            hookRemoteByName(desc)
            log("  Захучен новый Remote: " .. tostring(desc))
        end
    end
end)
log("Этап 3 завершён.")

-- ========== ЭТАП 4: ПЕРЕХВАТ ВСЕХ REMOTE С ФИЛЬТРОМ ПО АРГУМЕНТАМ (ждём 5 сек) ==========
task.wait(5)
log("Этап 4: включение Remote hooks (фильтр по аргументу JobId)")
-- Этот этап может вызвать краш, поэтому оборачиваем в pcall и логируем ошибку
local ok4, err4 = pcall(function()
    -- Хукаем все существующие Remote
    for _, descendant in ipairs(game:GetDescendants()) do
        if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
            hookRemoteByName(descendant)  -- переиспользуем функцию, внутри фильтр по имени и аргументам
        end
    end
    -- Хукаем новые
    game.DescendantAdded:Connect(function(desc)
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            hookRemoteByName(desc)
        end
    end)
end)
if not ok4 then
    log("  Ошибка на этапе 4: " .. tostring(err4))
else
    log("  Все Remote захучены (с фильтром по аргументам)")
end
log("Этап 4 завершён.")

-- ========== ЭТАП 5: ПЕРЕХВАТ ЧЕРЕЗ __NAMECALL МЕТАТАБЛИЦ (ждём 5 сек) ==========
task.wait(5)
log("Этап 5: включение namecall hooks")
local ok5, err5 = pcall(function()
    local remoteEventMT = getrawmetatable(game:GetService("RemoteEvent"))
    local remoteFuncMT = getrawmetatable(game:GetService("RemoteFunction"))
    if remoteEventMT then
        local oldNamecall = rawget(remoteEventMT, "__namecall")
        if type(oldNamecall) == "function" then
            hookfunction(oldNamecall, function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" then
                    if isLogging then return oldNamecall(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteEvent.FireServer (namecall): " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return oldNamecall(self, ...)
            end)
            log("  Хук установлен на RemoteEvent.__namecall")
        end
    end
    if remoteFuncMT then
        local oldNamecall = rawget(remoteFuncMT, "__namecall")
        if type(oldNamecall) == "function" then
            hookfunction(oldNamecall, function(self, ...)
                local method = getnamecallmethod()
                if method == "InvokeServer" then
                    if isLogging then return oldNamecall(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteFunction.InvokeServer (namecall): " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return oldNamecall(self, ...)
            end)
            log("  Хук установлен на RemoteFunction.__namecall")
        end
    end
end)
if not ok5 then
    log("  Ошибка на этапе 5: " .. tostring(err5))
end
log("Этап 5 завершён.")

-- ========== ЗАВЕРШАЮЩЕЕ СООБЩЕНИЕ ==========
log("Все этапы включены. Если краш не произошёл, используйте хаб для телепортации.")
log("Проверьте лог после краша: последний включённый этап указывает на проблемный метод.")

-- Блокирующий цикл, чтобы скрипт не завершался
while true do
    task.wait(1)
end
