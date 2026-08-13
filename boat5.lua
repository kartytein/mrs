-- ===== ТРЕКЕР С ИСПОЛЬЗОВАНИЕМ __NAMECALL ДЛЯ REMOTE =====
-- Не хукает каждый Remote, только метатаблицы RemoteEvent/RemoteFunction.
-- Это безопасно и не вызывает краш даже при большом количестве Remote.

local teleportService = game:GetService("TeleportService")
local players = game:GetService("Players")
local logService = game:GetService("LogService")
local runService = game:GetService("RunService")

-- Функция логирования
local function log(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = "[" .. timestamp .. "] " .. msg .. "\n"
    if appendfile then
        appendfile("teleport_tracker.txt", line)
    else
        local old = (readfile and readfile("teleport_tracker.txt")) or ""
        writefile("teleport_tracker.txt", old .. line)
    end
end

-- Инициализация файла
writefile("teleport_tracker.txt", "=== Teleport Tracker (namecall only) ===\n")
log("Трекер запущен. Используется перехват метатаблиц, не крашит.")

-- Флаг защиты от рекурсии
local isLogging = false

-- ========== 1. ПЕРЕХВАТ МЕТОДОВ TELEPORTSERVICE (прямые) ==========
local teleportMethods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync", "TeleportToSpawnByName"}

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
            log("Хук установлен на TeleportService." .. methodName)
        end
    end)
    if not ok then log("Ошибка хука на " .. methodName .. ": " .. tostring(err)) end
end

-- ========== 2. ПЕРЕХВАТ game.JobId ЧЕРЕЗ МЕТАТАБЛИЦУ ==========
local okJob, errJob = pcall(function()
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
            log("Хук установлен на game.__index (JobId)")
        end
        if type(oldNewIndex) == "function" then
            hookfunction(oldNewIndex, function(self, key, value)
                if key == "JobId" or key == "jobId" then
                    log("game.__newindex: установить " .. tostring(key) .. " = " .. tostring(value))
                end
                return oldNewIndex(self, key, value)
            end)
            log("Хук установлен на game.__newindex (JobId)")
        end
    end
end)
if not okJob then log("Ошибка перехвата game.JobId: " .. tostring(errJob)) end

-- ========== 3. ПЕРЕХВАТ REMOTE ЧЕРЕЗ __NAMECALL (ГЛАВНЫЙ МЕТОД) ==========
-- Перехватываем метатаблицы RemoteEvent и RemoteFunction, чтобы ловить FireServer/InvokeServer без хука на каждый объект.
local function hookRemoteNamecall()
    local remoteEventMT = getrawmetatable(game:GetService("RemoteEvent"))
    local remoteFuncMT = getrawmetatable(game:GetService("RemoteFunction"))
    
    -- Для RemoteEvent
    if remoteEventMT then
        local oldNamecall = rawget(remoteEventMT, "__namecall")
        if type(oldNamecall) == "function" then
            hookfunction(oldNamecall, function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" then
                    if isLogging then return oldNamecall(self, ...) end
                    isLogging = true
                    local args = {...}
                    -- Логируем только если есть подозрение на телепортацию
                    local shouldLog = false
                    local remoteName = string.lower(tostring(self))
                    if string.find(remoteName, "teleport") or string.find(remoteName, "job") or
                       string.find(remoteName, "server") or string.find(remoteName, "tp") or
                       string.find(remoteName, "hop") or string.find(remoteName, "rejoin") then
                        shouldLog = true
                    end
                    for _, v in ipairs(args) do
                        if type(v) == "string" and string.len(v) > 20 and string.find(v, "%-") then
                            shouldLog = true
                            break
                        end
                    end
                    if shouldLog then
                        local argStr = ""
                        for i, v in ipairs(args) do
                            if i > 1 then argStr = argStr .. ", " end
                            argStr = argStr .. tostring(v)
                        end
                        log("RemoteEvent.FireServer: " .. tostring(self) .. " -> " .. argStr)
                    end
                    isLogging = false
                end
                return oldNamecall(self, ...)
            end)
            log("Хук установлен на RemoteEvent.__namecall (FireServer)")
        end
    end
    
    -- Для RemoteFunction
    if remoteFuncMT then
        local oldNamecall = rawget(remoteFuncMT, "__namecall")
        if type(oldNamecall) == "function" then
            hookfunction(oldNamecall, function(self, ...)
                local method = getnamecallmethod()
                if method == "InvokeServer" then
                    if isLogging then return oldNamecall(self, ...) end
                    isLogging = true
                    local args = {...}
                    local shouldLog = false
                    local remoteName = string.lower(tostring(self))
                    if string.find(remoteName, "teleport") or string.find(remoteName, "job") or
                       string.find(remoteName, "server") or string.find(remoteName, "tp") or
                       string.find(remoteName, "hop") or string.find(remoteName, "rejoin") then
                        shouldLog = true
                    end
                    for _, v in ipairs(args) do
                        if type(v) == "string" and string.len(v) > 20 and string.find(v, "%-") then
                            shouldLog = true
                            break
                        end
                    end
                    if shouldLog then
                        local argStr = ""
                        for i, v in ipairs(args) do
                            if i > 1 then argStr = argStr .. ", " end
                            argStr = argStr .. tostring(v)
                        end
                        log("RemoteFunction.InvokeServer: " .. tostring(self) .. " -> " .. argStr)
                    end
                    isLogging = false
                end
                return oldNamecall(self, ...)
            end)
            log("Хук установлен на RemoteFunction.__namecall (InvokeServer)")
        end
    end
end

local okRemote, errRemote = pcall(hookRemoteNamecall)
if not okRemote then log("Ошибка перехвата Remote: " .. tostring(errRemote)) end

-- ========== 4. ПЕРЕХВАТ TELEPORTSERVICE ЧЕРЕЗ __NAMECALL (дополнительно) ==========
local okTS, errTS = pcall(function()
    local tsMT = getrawmetatable(teleportService)
    if tsMT then
        local oldNamecall = rawget(tsMT, "__namecall")
        if type(oldNamecall) == "function" then
            hookfunction(oldNamecall, function(self, ...)
                local method = getnamecallmethod()
                if method == "Teleport" or method == "TeleportToPlaceInstance" or
                   method == "TeleportToPrivateServer" or method == "TeleportPartyAsync" then
                    if isLogging then return oldNamecall(self, ...) end
                    isLogging = true
                    local args = {...}
                    local argStr = ""
                    for i, v in ipairs(args) do
                        if i > 1 then argStr = argStr .. ", " end
                        argStr = argStr .. tostring(v)
                    end
                    log("TeleportService.__namecall." .. method .. ": " .. argStr)
                    isLogging = false
                end
                return oldNamecall(self, ...)
            end)
            log("Хук установлен на TeleportService.__namecall")
        end
    end
end)
if not okTS then log("Ошибка перехвата TeleportService namecall: " .. tostring(errTS)) end

-- ========== 5. ОТСЛЕЖИВАНИЕ СОБЫТИЙ ==========
local player = players.LocalPlayer
if player then
    player.OnTeleport:Connect(function(teleportState)
        log("player.OnTeleport: " .. tostring(teleportState))
        log("  Текущий game.JobId: " .. tostring(game.JobId))
    end)
    log("Отслеживание player.OnTeleport установлено")
end

logService.MessageOut:Connect(function(message, messageType)
    if string.find(string.lower(message), "teleport") or string.find(string.lower(message), "jobid") then
        log("LogService: [" .. tostring(messageType) .. "] " .. message)
    end
end)
log("Отслеживание LogService.MessageOut включено")

-- ========== 6. ПЕРИОДИЧЕСКАЯ ПРОВЕРКА JOBID ==========
spawn(function()
    while true do
        task.wait(5)
        log("Текущий game.JobId: " .. tostring(game.JobId))
    end
end)
log("Периодическая проверка game.JobId запущена")

-- ========== ОЖИДАНИЕ ==========
log("Трекер активен. Выполните телепортацию через хаб.")
while true do
    task.wait(1)
end
