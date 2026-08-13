-- ===== ТРЕКЕР ТЕЛЕПОРТАЦИЙ (ИСПРАВЛЕННЫЙ ДЛЯ ПЕРЕХВАТА REMOTE) =====
-- Теперь перехватываем FireServer/InvokeServer на конкретных RemoteEvent/RemoteFunction,
-- а также автоматически вешаем хуки на новые создаваемые объекты.
-- Исправлена ошибка с TeleportType -> используется TeleportState.

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

-- ========== ФУНКЦИЯ ПЕРЕХВАТА REMOTE ДЛЯ ОДНОГО ОБЪЕКТА ==========
local function hookRemoteObject(remote)
    if remote:IsA("RemoteEvent") then
        local fireServer = remote.FireServer
        if type(fireServer) == "function" then
            hookfunction(fireServer, function(self, ...)
                if isLogging then return fireServer(self, ...) end
                isLogging = true
                local args = {...}
                local argStr = ""
                for i, v in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    argStr = argStr .. tostring(v)
                end
                log("RemoteEvent.FireServer: " .. tostring(remote) .. " -> " .. argStr)
                isLogging = false
                return fireServer(self, ...)
            end)
            log("Хук установлен на RemoteEvent: " .. tostring(remote))
        end
    elseif remote:IsA("RemoteFunction") then
        local invokeServer = remote.InvokeServer
        if type(invokeServer) == "function" then
            hookfunction(invokeServer, function(self, ...)
                if isLogging then return invokeServer(self, ...) end
                isLogging = true
                local args = {...}
                local argStr = ""
                for i, v in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    argStr = argStr .. tostring(v)
                end
                log("RemoteFunction.InvokeServer: " .. tostring(remote) .. " -> " .. argStr)
                isLogging = false
                return invokeServer(self, ...)
            end)
            log("Хук установлен на RemoteFunction: " .. tostring(remote))
        end
    end
end

-- Перехватываем все существующие RemoteEvent/RemoteFunction
for _, descendant in ipairs(game:GetDescendants()) do
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        hookRemoteObject(descendant)
    end
end

-- Перехватываем новые RemoteEvent/RemoteFunction при их создании
game.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        log("Создан новый инстанс: " .. descendant.ClassName .. " " .. tostring(descendant))
        hookRemoteObject(descendant)
    end
end)

-- ========== ОТСЛЕЖИВАНИЕ СОБЫТИЙ ТЕЛЕПОРТАЦИИ ИГРОКА ==========
local player = players.LocalPlayer
if player then
    player.OnTeleport:Connect(function(teleportData)
        log("player.OnTeleport: ")
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
