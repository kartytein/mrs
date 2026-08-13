-- ===== ТРЕКЕР ТЕЛЕПОРТАЦИЙ (ИСПРАВЛЕННАЯ ВЕРСИЯ) =====
-- Исправлено: заменены несуществующие свойства Teleporting/Teleported на событие OnTeleport.

local teleportService = game:GetService("TeleportService")
local players = game:GetService("Players")
local logService = game:GetService("LogService")
local runService = game:GetService("RunService")

-- Функция логирования: добавляет строку в файл
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
writefile("teleport_tracker.txt", "=== Teleport Tracker Started ===\n")
log("Трекер запущен. Ожидание телепортации...")

-- ========== ПЕРЕХВАТ МЕТОДОВ TELEPORTSERVICE ==========
local teleportMethods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}

for _, methodName in ipairs(teleportMethods) do
    local original = teleportService[methodName]
    if type(original) == "function" then
        local hooked
        hooked = hookfunction(original, function(...)
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
            log("TeleportService." .. methodName .. " вызван с аргументами: " .. argStr)
            return hooked(...)
        end)
        log("Хук установлен на TeleportService." .. methodName)
    else
        log("Не удалось найти метод TeleportService." .. methodName)
    end
end

-- ========== ПЕРЕХВАТ REMOTEEVENT / REMOTEFUNCTION ==========
local remoteEventMT = getrawmetatable(game:GetService("RemoteEvent"))
local remoteFuncMT = getrawmetatable(game:GetService("RemoteFunction"))

if remoteEventMT then
    local origFireServer = rawget(remoteEventMT, "FireServer")
    if type(origFireServer) == "function" then
        local hookedFire = hookfunction(origFireServer, function(self, ...)
            local args = {...}
            local argStr = ""
            for i, v in ipairs(args) do
                if i > 1 then argStr = argStr .. ", " end
                argStr = argStr .. tostring(v)
            end
            log("RemoteEvent.FireServer: " .. tostring(self) .. " -> " .. argStr)
            return hookedFire(self, ...)
        end)
        log("Хук установлен на RemoteEvent.FireServer")
    end
end

if remoteFuncMT then
    local invokeServer = rawget(remoteFuncMT, "InvokeServer")
    if type(invokeServer) == "function" then
        local hookedInvoke = hookfunction(invokeServer, function(self, ...)
            local args = {...}
            local argStr = ""
            for i, v in ipairs(args) do
                if i > 1 then argStr = argStr .. ", " end
                argStr = argStr .. tostring(v)
            end
            log("RemoteFunction.InvokeServer: " .. tostring(self) .. " -> " .. argStr)
            return hookedInvoke(self, ...)
        end)
        log("Хук установлен на RemoteFunction.InvokeServer")
    end
end

-- ========== ОТСЛЕЖИВАНИЕ СОБЫТИЙ ТЕЛЕПОРТАЦИИ ИГРОКА ==========
local player = players.LocalPlayer
if player then
    -- Используем событие OnTeleport (клиентское), а не несуществующие свойства
    player.OnTeleport:Connect(function(teleportData)
        log("Событие player.OnTeleport: тип = " .. tostring(teleportData.TeleportType) .. ", место = " .. tostring(teleportData.PlaceId))
        if teleportData.JobId then
            log("  JobId из события: " .. tostring(teleportData.JobId))
        end
        if teleportData.PrivateServer then
            log("  PrivateServer из события: " .. tostring(teleportData.PrivateServer))
        end
    end)
    log("Отслеживание player.OnTeleport установлено")
else
    log("Локальный игрок не найден")
end

-- ========== ОТСЛЕЖИВАНИЕ СООБЩЕНИЙ LOGSERVICE ==========
logService.MessageOut:Connect(function(message, messageType)
    if string.find(string.lower(message), "teleport") or string.find(string.lower(message), "jobid") then
        log("LogService сообщение: [" .. tostring(messageType) .. "] " .. message)
    end
end)
log("Отслеживание LogService.MessageOut включено")

-- ========== ПЕРЕХВАТ ИЗМЕНЕНИЯ JOBID ЧЕРЕЗ МЕТАТАБЛИЦУ ==========
local teleportMT = getrawmetatable(teleportService)
if teleportMT then
    local oldIndex = rawget(teleportMT, "__index")
    local oldNewIndex = rawget(teleportMT, "__newindex")
    
    if type(oldIndex) == "function" then
        local newIndex = hookfunction(oldIndex, function(self, key)
            local result = newIndex(self, key)
            if key == "JobId" or key == "jobId" then
                log("TeleportService.__index вызван для ключа: " .. tostring(key) .. " -> " .. tostring(result))
            end
            return result
        end)
        log("Хук установлен на TeleportService.__index")
    end
    
    if type(oldNewIndex) == "function" then
        local newNewIndex = hookfunction(oldNewIndex, function(self, key, value)
            if key == "JobId" or key == "jobId" then
                log("TeleportService.__newindex: попытка установить " .. tostring(key) .. " = " .. tostring(value))
            end
            return newNewIndex(self, key, value)
        end)
        log("Хук установлен на TeleportService.__newindex")
    end
end

-- ========== ДОПОЛНИТЕЛЬНО: ОТСЛЕЖИВАНИЕ НОВЫХ ИНСТАНСОВ ==========
local function onDescendantAdded(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        log("Создан новый инстанс: " .. descendant.ClassName .. " " .. tostring(descendant))
    end
end
game.DescendantAdded:Connect(onDescendantAdded)
log("Отслеживание новых RemoteEvent/RemoteFunction включено")

-- ========== БЕСКОНЕЧНЫЙ ЦИКЛ ОЖИДАНИЯ ==========
log("Трекер активен. Используйте хаб для телепортации.")
while true do
    runService.Heartbeat:Wait()
end
