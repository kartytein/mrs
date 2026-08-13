-- ===== ПРИЧИНА КРАША =====
-- В предыдущей версии краш возникал из-за неправильного использования hookfunction:
--   local original = teleportService[methodName]
--   hookfunction(original, function(...) ... return original(...) end)
-- После hookfunction переменная original указывает на НОВУЮ (перехваченную) функцию,
-- поэтому вызов original(...) внутри хука вызывал сам себя бесконечно -> краш.
-- Аналогично для game.__index/__newindex и Remote.FireServer/InvokeServer.
-- Исправление: сохранить СТАРУЮ функцию в отдельную переменную ДО перехвата.

-- ===== БЕЗОПАСНЫЙ ТРЕКЕР (исправленный, без рекурсии) =====
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

writefile("teleport_tracker.txt", "=== Teleport Tracker v3 (без рекурсии) ===\n")
log("Трекер запущен.")

-- Флаг для предотвращения рекурсии
local isLogging = false

-- ========== ПЕРЕХВАТ TELEPORTSERVICE (корректно) ==========
local teleportMethods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}

for _, methodName in ipairs(teleportMethods) do
    local original = teleportService[methodName]
    if type(original) == "function" then
        -- Сохраняем СТАРУЮ функцию
        local oldFunction = original
        -- Перехватываем
        hookfunction(original, function(...)
            if isLogging then return oldFunction(...) end
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
            -- Вызываем старую функцию
            return oldFunction(...)
        end)
        log("Хук установлен на TeleportService." .. methodName)
    end
end

-- ========== ПЕРЕХВАТ REMOTE (корректно, только подозрительные) ==========
local function looksLikeJobId(arg)
    return type(arg) == "string" and string.len(arg) > 20 and string.find(arg, "%-") ~= nil
end

local function hookRemote(remote)
    if remote:IsA("RemoteEvent") then
        local oldFire = remote.FireServer
        if type(oldFire) == "function" then
            hookfunction(oldFire, function(self, ...)
                if isLogging then return oldFire(self, ...) end
                local args = {...}
                local shouldLog = false
                if string.find(string.lower(remote.Name), "teleport") or
                   string.find(string.lower(remote.Name), "job") or
                   string.find(string.lower(remote.Name), "server") or
                   string.find(string.lower(remote.Name), "tp") then
                    shouldLog = true
                end
                for _, v in ipairs(args) do
                    if looksLikeJobId(v) then
                        shouldLog = true
                        break
                    end
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
                return oldFire(self, ...)
            end)
        end
    elseif remote:IsA("RemoteFunction") then
        local oldInvoke = remote.InvokeServer
        if type(oldInvoke) == "function" then
            hookfunction(oldInvoke, function(self, ...)
                if isLogging then return oldInvoke(self, ...) end
                local args = {...}
                local shouldLog = false
                if string.find(string.lower(remote.Name), "teleport") or
                   string.find(string.lower(remote.Name), "job") or
                   string.find(string.lower(remote.Name), "server") or
                   string.find(string.lower(remote.Name), "tp") then
                    shouldLog = true
                end
                for _, v in ipairs(args) do
                    if looksLikeJobId(v) then
                        shouldLog = true
                        break
                    end
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
                return oldInvoke(self, ...)
            end)
        end
    end
end

-- Хукаем существующие Remote
for _, descendant in ipairs(game:GetDescendants()) do
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        hookRemote(descendant)
    end
end

-- Хукаем новые Remote
game.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        log("Создан: " .. descendant.ClassName .. " " .. tostring(descendant))
        hookRemote(descendant)
    end
end)

-- ========== ПЕРЕХВАТ game.JobId (корректно) ==========
local gameMT = getrawmetatable(game)
if gameMT then
    local oldIndex = rawget(gameMT, "__index")
    local oldNewIndex = rawget(gameMT, "__newindex")
    
    if type(oldIndex) == "function" then
        hookfunction(oldIndex, function(self, key)
            local result = oldIndex(self, key)  -- вызываем старую функцию
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
            return oldNewIndex(self, key, value)  -- вызываем старую функцию
        end)
        log("Хук установлен на game.__newindex (JobId)")
    end
end

-- ========== ПРАВИЛЬНЫЙ ОБРАБОТЧИК ONTELEPORT ==========
local player = players.LocalPlayer
if player then
    player.OnTeleport:Connect(function(teleportState)
        log("player.OnTeleport: " .. tostring(teleportState))
        log("  Текущий game.JobId: " .. tostring(game.JobId))
    end)
    log("Отслеживание player.OnTeleport установлено")
end

-- ========== ОТСЛЕЖИВАНИЕ LOGSERVICE ==========
logService.MessageOut:Connect(function(message, messageType)
    if string.find(string.lower(message), "teleport") or string.find(string.lower(message), "jobid") then
        log("LogService: [" .. tostring(messageType) .. "] " .. message)
    end
end)
log("Отслеживание LogService.MessageOut включено")

-- ========== ПЕРИОДИЧЕСКАЯ ПРОВЕРКА JOBID ==========
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
