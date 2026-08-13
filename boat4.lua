-- ===== БЕЗОПАСНЫЙ ТРЕКЕР ТЕЛЕПОРТАЦИЙ (без крашей) =====
-- Перехватываем только TeleportService и события, не трогаем RemoteEvent/RemoteFunction вызовы,
-- чтобы избежать конфликтов и крашей.

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
writefile("teleport_tracker.txt", "=== Teleport Tracker Started ===\n")
log("Трекер запущен. Ожидание телепортации...")

-- Флаг для предотвращения рекурсии
local isLogging = false

-- ========== ПЕРЕХВАТ МЕТОДОВ TELEPORTSERVICE ==========
local teleportMethods = {"Teleport", "TeleportToPlaceInstance", "TeleportToPrivateServer", "TeleportPartyAsync"}

for _, methodName in ipairs(teleportMethods) do
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
end

-- ========== ПЕРЕХВАТ ИЗМЕНЕНИЯ JOBID ЧЕРЕЗ МЕТАТАБЛИЦУ ==========
-- Безопасный перехват __index и __newindex для TeleportService
local teleportMT = getrawmetatable(teleportService)
if teleportMT then
    local oldIndex = rawget(teleportMT, "__index")
    local oldNewIndex = rawget(teleportMT, "__newindex")
    
    if type(oldIndex) == "function" then
        hookfunction(oldIndex, function(self, key)
            local result = oldIndex(self, key)
            if key == "JobId" or key == "jobId" then
                log("TeleportService.__index: JobId = " .. tostring(result))
            end
            return result
        end)
        log("Хук установлен на TeleportService.__index")
    end
    
    if type(oldNewIndex) == "function" then
        hookfunction(oldNewIndex, function(self, key, value)
            if key == "JobId" or key == "jobId" then
                log("TeleportService.__newindex: установить " .. tostring(key) .. " = " .. tostring(value))
            end
            return oldNewIndex(self, key, value)
        end)
        log("Хук установлен на TeleportService.__newindex")
    end
end

-- ========== ОТСЛЕЖИВАНИЕ СОЗДАНИЯ REMOTE ОБЪЕКТОВ (без перехвата вызовов) ==========
game.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        log("Создан новый инстанс: " .. descendant.ClassName .. " " .. tostring(descendant))
    end
end)
log("Отслеживание новых RemoteEvent/RemoteFunction включено")

-- ========== ОТСЛЕЖИВАНИЕ СОБЫТИЯ ONTELEPORT (правильное поле TeleportState) ==========
local player = players.LocalPlayer
if player then
    player.OnTeleport:Connect(function(teleportData)
        log("player.OnTeleport:")
        log("  PlaceId: " .. tostring(teleportData.PlaceId))
        log("  TeleportState: " .. tostring(teleportData.TeleportState))
        if teleportData.JobId then
            log("  JobId: " .. tostring(teleportData.JobId))
        end
        if teleportData.PrivateServer then
            log("  PrivateServer: " .. tostring(teleportData.PrivateServer))
        end
    end)
    log("Отслеживание player.OnTeleport установлено")
end

-- ========== ОТСЛЕЖИВАНИЕ СООБЩЕНИЙ LOGSERVICE ==========
logService.MessageOut:Connect(function(message, messageType)
    if string.find(string.lower(message), "teleport") or string.find(string.lower(message), "jobid") then
        log("LogService: [" .. tostring(messageType) .. "] " .. message)
    end
end)
log("Отслеживание LogService.MessageOut включено")

-- ========== НЕБЛОКИРУЮЩИЙ ЦИКЛ ОЖИДАНИЯ ==========
log("Трекер активен. Используйте хаб для телепортации.")
while true do
    task.wait(1)
end
