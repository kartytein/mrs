-- ===== ТЕСТОВЫЙ ТРЕКЕР С ВЫБОРОМ РЕЖИМА =====
-- Меняйте MODE (1-6) и запускайте скрипт заново. После запуска выполните телепортацию через хаб.
-- Проверьте файл teleport_mode_X.txt (X - номер режима). Если краш - метод не подходит, переходите к следующему.

local MODE = 6 -- ИЗМЕНИТЕ ЭТО ЗНАЧЕНИЕ ПЕРЕД ЗАПУСКОМ (1-6)

local teleportService = game:GetService("TeleportService")
local players = game:GetService("Players")
local logService = game:GetService("LogService")
local runService = game:GetService("RunService")local MODE = 2 -- ИЗМЕНИТЕ ЭТО ЗНАЧЕНИЕ ПЕРЕД ЗАПУСКОМ (1-6)
local teleportService = game:GetService("TeleportService")
local players = game:GetService("Players")
local logService = game:GetService("LogService")
local runService = game:GetService("RunService")

local LOG_FILE = "teleport_mode_" .. MODE .. ".txt"

local function log(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = "[" .. timestamp .. "] " .. msg .. "\n"
    if appendfile then
        appendfile(LOG_FILE, line)
    else
        local old = (readfile and readfile(LOG_FILE)) or ""
        writefile(LOG_FILE, old .. line)
    end
end

writefile(LOG_FILE, "=== Mode " .. MODE .. " Started ===\n")
log("Режим " .. MODE .. " запущен.")

local isLogging = false

-- ========== РЕЖИМ 1: ТОЛЬКО ПРЯМЫЕ ХУКИ TELEPORTSERVICE ==========
if MODE == 1 then
    log("Метод: прямые хуки TeleportService")
    local methods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}
    for _, methodName in ipairs(methods) do
        local original = teleportService[methodName]
        if type(original) == "function" then
            hookfunction(original, function(...)
                if isLogging then return original(...) end
                isLogging = true
                local args = {...}
                local argStr = ""
                for i, v in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    argStr = argStr .. tostring(v)
                end
                log("TeleportService." .. methodName .. " -> " .. argStr)
                isLogging = false
                return original(...)
            end)
            log("Хук на " .. methodName .. " установлен")
        end
    end
end

-- ========== РЕЖИМ 2: ТОЛЬКО ПЕРЕХВАТ game.JobId ЧЕРЕЗ МЕТАТАБЛИЦУ ==========
if MODE == 2 then
    log("Метод: game.JobId через метатаблицу")
    local gameMT = getrawmetatable(game)
    if gameMT then
        local oldIndex = rawget(gameMT, "__index")
        local oldNewIndex = rawget(gameMT, "__newindex")
        if type(oldIndex) == "function" then
            hookfunction(oldIndex, function(self, key)
                local result = oldIndex(self, key)
                if key == "JobId" or key == "jobId" then
                    log("game.__index JobId = " .. tostring(result))
                end
                return result
            end)
            log("Хук на game.__index установлен")
        end
        if type(oldNewIndex) == "function" then
            hookfunction(oldNewIndex, function(self, key, value)
                if key == "JobId" or key == "jobId" then
                    log("game.__newindex JobId = " .. tostring(value))
                end
                return oldNewIndex(self, key, value)
            end)
            log("Хук на game.__newindex установлен")
        end
    end
end

-- ========== РЕЖИМ 3: ТОЛЬКО __NAMECALL ДЛЯ REMOTE ==========
if MODE == 3 then
    log("Метод: __namecall для RemoteEvent/RemoteFunction")
    local remoteEventMT = getrawmetatable(game:GetService("RemoteEvent"))
    local remoteFuncMT = getrawmetatable(game:GetService("RemoteFunction"))
    if remoteEventMT then
        local old = rawget(remoteEventMT, "__namecall")
        if type(old) == "function" then
            hookfunction(old, function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" then
                    if isLogging then return old(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteEvent.FireServer: " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return old(self, ...)
            end)
            log("Хук на RemoteEvent.__namecall установлен")
        end
    end
    if remoteFuncMT then
        local old = rawget(remoteFuncMT, "__namecall")
        if type(old) == "function" then
            hookfunction(old, function(self, ...)
                local method = getnamecallmethod()
                if method == "InvokeServer" then
                    if isLogging then return old(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteFunction.InvokeServer: " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return old(self, ...)
            end)
            log("Хук на RemoteFunction.__namecall установлен")
        end
    end
end

-- ========== РЕЖИМ 4: ПЕРЕХВАТ REMOTE С ФИЛЬТРОМ ПО ИМЕНИ (ОГРАНИЧЕННЫЙ) ==========
if MODE == 4 then
    log("Метод: перехват Remote с фильтром по имени (максимум 50 объектов)")
    local count = 0
    local function shouldHook(remote)
        local n = string.lower(remote.Name)
        return string.find(n, "teleport") or string.find(n, "job") or
               string.find(n, "server") or string.find(n, "tp") or
               string.find(n, "hop") or string.find(n, "rejoin")
    end
    local function hookOne(remote)
        if count >= 50 then return end
        if shouldHook(remote) then
            count = count + 1
            if remote:IsA("RemoteEvent") then
                local fire = remote.FireServer
                hookfunction(fire, function(self, ...)
                    if isLogging then return fire(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteEvent.FireServer (подозрительный): " .. tostring(remote) .. " -> " .. argStr)
                    isLogging = false
                    return fire(self, ...)
                end)
            elseif remote:IsA("RemoteFunction") then
                local inv = remote.InvokeServer
                hookfunction(inv, function(self, ...)
                    if isLogging then return inv(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteFunction.InvokeServer (подозрительный): " .. tostring(remote) .. " -> " .. argStr)
                    isLogging = false
                    return inv(self, ...)
                end)
            end
        end
    end
    for _, desc in ipairs(game:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            hookOne(desc)
        end
    end
    game.DescendantAdded:Connect(function(desc)
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            hookOne(desc)
        end
    end)
    log("Захвачено подозрительных Remote: " .. count)
end

-- ========== РЕЖИМ 5: ТОЛЬКО СОБЫТИЯ (OnTeleport, LogService) ==========
if MODE == 5 then
    log("Метод: только события OnTeleport и LogService")
    local player = players.LocalPlayer
    if player then
        player.OnTeleport:Connect(function(state)
            log("player.OnTeleport: " .. tostring(state) .. ", JobId=" .. tostring(game.JobId))
        end)
        log("OnTeleport отслеживается")
    end
    logService.MessageOut:Connect(function(msg, msgType)
        if string.find(string.lower(msg), "teleport") or string.find(string.lower(msg), "jobid") then
            log("LogService: [" .. tostring(msgType) .. "] " .. msg)
        end
    end)
    log("LogService отслеживается")
end

-- ========== РЕЖИМ 6: БЕЗОПАСНАЯ КОМБИНАЦИЯ (1+2+5) ==========
if MODE == 6 then
    log("Метод: комбинация TeleportService хуков + game.JobId + события")
    -- 1: TeleportService
    local methods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}
    for _, methodName in ipairs(methods) do
        local original = teleportService[methodName]
        if type(original) == "function" then
            hookfunction(original, function(...)
                if isLogging then return original(...) end
                isLogging = true
                local args = {...}
                local argStr = ""
                for i, v in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    argStr = argStr .. tostring(v)
                end
                log("TeleportService." .. methodName .. " -> " .. argStr)
                isLogging = false
                return original(...)
            end)
        end
    end
    -- 2: game.JobId
    local gameMT = getrawmetatable(game)
    if gameMT then
        local oldIndex = rawget(gameMT, "__index")
        local oldNewIndex = rawget(gameMT, "__newindex")
        if type(oldIndex) == "function" then
            hookfunction(oldIndex, function(self, key)
                local result = oldIndex(self, key)
                if key == "JobId" or key == "jobId" then
                    log("game.__index JobId = " .. tostring(result))
                end
                return result
            end)
        end
        if type(oldNewIndex) == "function" then
            hookfunction(oldNewIndex, function(self, key, value)
                if key == "JobId" or key == "jobId" then
                    log("game.__newindex JobId = " .. tostring(value))
                end
                return oldNewIndex(self, key, value)
            end)
        end
    end
    -- 5: события
    local player = players.LocalPlayer
    if player then
        player.OnTeleport:Connect(function(state)
            log("player.OnTeleport: " .. tostring(state) .. ", JobId=" .. tostring(game.JobId))
        end)
    end
    logService.MessageOut:Connect(function(msg, msgType)
        if string.find(string.lower(msg), "teleport") or string.find(string.lower(msg), "jobid") then
            log("LogService: [" .. tostring(msgType) .. "] " .. msg)
        end
    end)
end

-- Периодическая проверка JobId во всех режимах (кроме 5? оставим)
spawn(function()
    while true do
        task.wait(10)
        log("Проверка JobId: " .. tostring(game.JobId))
    end
end)

log("Скрипт запущен. Выполните телепортацию через хаб.")

while true do
    task.wait(1)
end

local LOG_FILE = "teleport_mode_" .. MODE .. ".txt"

local function log(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = "[" .. timestamp .. "] " .. msg .. "\n"
    if appendfile then
        appendfile(LOG_FILE, line)
    else
        local old = (readfile and readfile(LOG_FILE)) or ""
        writefile(LOG_FILE, old .. line)
    end
end

writefile(LOG_FILE, "=== Mode " .. MODE .. " Started ===\n")
log("Режим " .. MODE .. " запущен.")

local isLogging = false

-- ========== РЕЖИМ 1: ТОЛЬКО ПРЯМЫЕ ХУКИ TELEPORTSERVICE ==========
if MODE == 1 then
    log("Метод: прямые хуки TeleportService")
    local methods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}
    for _, methodName in ipairs(methods) do
        local original = teleportService[methodName]
        if type(original) == "function" then
            hookfunction(original, function(...)
                if isLogging then return original(...) end
                isLogging = true
                local args = {...}
                local argStr = ""
                for i, v in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    argStr = argStr .. tostring(v)
                end
                log("TeleportService." .. methodName .. " -> " .. argStr)
                isLogging = false
                return original(...)
            end)
            log("Хук на " .. methodName .. " установлен")
        end
    end
end

-- ========== РЕЖИМ 2: ТОЛЬКО ПЕРЕХВАТ game.JobId ЧЕРЕЗ МЕТАТАБЛИЦУ ==========
if MODE == 2 then
    log("Метод: game.JobId через метатаблицу")
    local gameMT = getrawmetatable(game)
    if gameMT then
        local oldIndex = rawget(gameMT, "__index")
        local oldNewIndex = rawget(gameMT, "__newindex")
        if type(oldIndex) == "function" then
            hookfunction(oldIndex, function(self, key)
                local result = oldIndex(self, key)
                if key == "JobId" or key == "jobId" then
                    log("game.__index JobId = " .. tostring(result))
                end
                return result
            end)
            log("Хук на game.__index установлен")
        end
        if type(oldNewIndex) == "function" then
            hookfunction(oldNewIndex, function(self, key, value)
                if key == "JobId" or key == "jobId" then
                    log("game.__newindex JobId = " .. tostring(value))
                end
                return oldNewIndex(self, key, value)
            end)
            log("Хук на game.__newindex установлен")
        end
    end
end

-- ========== РЕЖИМ 3: ТОЛЬКО __NAMECALL ДЛЯ REMOTE ==========
if MODE == 3 then
    log("Метод: __namecall для RemoteEvent/RemoteFunction")
    local remoteEventMT = getrawmetatable(game:GetService("RemoteEvent"))
    local remoteFuncMT = getrawmetatable(game:GetService("RemoteFunction"))
    if remoteEventMT then
        local old = rawget(remoteEventMT, "__namecall")
        if type(old) == "function" then
            hookfunction(old, function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" then
                    if isLogging then return old(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteEvent.FireServer: " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return old(self, ...)
            end)
            log("Хук на RemoteEvent.__namecall установлен")
        end
    end
    if remoteFuncMT then
        local old = rawget(remoteFuncMT, "__namecall")
        if type(old) == "function" then
            hookfunction(old, function(self, ...)
                local method = getnamecallmethod()
                if method == "InvokeServer" then
                    if isLogging then return old(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteFunction.InvokeServer: " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return old(self, ...)
            end)
            log("Хук на RemoteFunction.__namecall установлен")
        end
    end
end

-- ========== РЕЖИМ 4: ПЕРЕХВАТ REMOTE С ФИЛЬТРОМ ПО ИМЕНИ (ОГРАНИЧЕННЫЙ) ==========
if MODE == 4 then
    log("Метод: перехват Remote с фильтром по имени (максимум 50 объектов)")
    local count = 0
    local function shouldHook(remote)
        local n = string.lower(remote.Name)
        return string.find(n, "teleport") or string.find(n, "job") or
               string.find(n, "server") or string.find(n, "tp") or
               string.find(n, "hop") or string.find(n, "rejoin")
    end
    local function hookOne(remote)
        if count >= 50 then return end
        if shouldHook(remote) then
            count = count + 1
            if remote:IsA("RemoteEvent") then
                local fire = remote.FireServer
                hookfunction(fire, function(self, ...)
                    if isLogging then return fire(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteEvent.FireServer (подозрительный): " .. tostring(remote) .. " -> " .. argStr)
                    isLogging = false
                    return fire(self, ...)
                end)
            elseif remote:IsA("RemoteFunction") then
                local inv = remote.InvokeServer
                hookfunction(inv, function(self, ...)
                    if isLogging then return inv(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("RemoteFunction.InvokeServer (подозрительный): " .. tostring(remote) .. " -> " .. argStr)
                    isLogging = false
                    return inv(self, ...)
                end)
            end
        end
    end
    for _, desc in ipairs(game:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            hookOne(desc)
        end
    end
    game.DescendantAdded:Connect(function(desc)
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            hookOne(desc)
        end
    end)
    log("Захвачено подозрительных Remote: " .. count)
end

-- ========== РЕЖИМ 5: ТОЛЬКО СОБЫТИЯ (OnTeleport, LogService) ==========
if MODE == 5 then
    log("Метод: только события OnTeleport и LogService")
    local player = players.LocalPlayer
    if player then
        player.OnTeleport:Connect(function(state)
            log("player.OnTeleport: " .. tostring(state) .. ", JobId=" .. tostring(game.JobId))
        end)
        log("OnTeleport отслеживается")
    end
    logService.MessageOut:Connect(function(msg, msgType)
        if string.find(string.lower(msg), "teleport") or string.find(string.lower(msg), "jobid") then
            log("LogService: [" .. tostring(msgType) .. "] " .. msg)
        end
    end)
    log("LogService отслеживается")
end

-- ========== РЕЖИМ 6: БЕЗОПАСНАЯ КОМБИНАЦИЯ (1+2+5) ==========
if MODE == 6 then
    log("Метод: комбинация TeleportService хуков + game.JobId + события")
    -- 1: TeleportService
    local methods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}
    for _, methodName in ipairs(methods) do
        local original = teleportService[methodName]
        if type(original) == "function" then
            hookfunction(original, function(...)
                if isLogging then return original(...) end
                isLogging = true
                local args = {...}
                local argStr = ""
                for i, v in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    argStr = argStr .. tostring(v)
                end
                log("TeleportService." .. methodName .. " -> " .. argStr)
                isLogging = false
                return original(...)
            end)
        end
    end
    -- 2: game.JobId
    local gameMT = getrawmetatable(game)
    if gameMT then
        local oldIndex = rawget(gameMT, "__index")
        local oldNewIndex = rawget(gameMT, "__newindex")
        if type(oldIndex) == "function" then
            hookfunction(oldIndex, function(self, key)
                local result = oldIndex(self, key)
                if key == "JobId" or key == "jobId" then
                    log("game.__index JobId = " .. tostring(result))
                end
                return result
            end)
        end
        if type(oldNewIndex) == "function" then
            hookfunction(oldNewIndex, function(self, key, value)
                if key == "JobId" or key == "jobId" then
                    log("game.__newindex JobId = " .. tostring(value))
                end
                return oldNewIndex(self, key, value)
            end)
        end
    end
    -- 5: события
    local player = players.LocalPlayer
    if player then
        player.OnTeleport:Connect(function(state)
            log("player.OnTeleport: " .. tostring(state) .. ", JobId=" .. tostring(game.JobId))
        end)
    end
    logService.MessageOut:Connect(function(msg, msgType)
        if string.find(string.lower(msg), "teleport") or string.find(string.lower(msg), "jobid") then
            log("LogService: [" .. tostring(msgType) .. "] " .. msg)
        end
    end)
end

-- Периодическая проверка JobId во всех режимах (кроме 5? оставим)
spawn(function()
    while true do
        task.wait(10)
        log("Проверка JobId: " .. tostring(game.JobId))
    end
end)

log("Скрипт запущен. Выполните телепортацию через хаб.")

while true do
    task.wait(1)
end
