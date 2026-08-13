-- ===== УЛУЧШЕННЫЙ ТРЕКЕР ТЕЛЕПОРТАЦИЙ (без зависаний) =====
-- Использует безопасные хуки через __namecall, защиту от рекурсии и не блокирует хаб.

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

-- Флаг для предотвращения рекурсии при логировании
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

-- ========== ПЕРЕХВАТ REMOTEEVENT / REMOTEFUNCTION через __namecall ==========
-- Функция для перехвата вызовов FireServer / InvokeServer
local function hookRemoteMethods()
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
                    log("RemoteEvent.FireServer: " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return oldNamecall(self, ...)
            end)
            log("Хук установлен на RemoteEvent.__namecall (FireServer)")
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
                    log("RemoteFunction.InvokeServer: " .. tostring(self) .. " -> " .. argStr)
                    isLogging = false
                end
                return oldNamecall(self, ...)
            end)
            log("Хук установлен на RemoteFunction.__namecall (InvokeServer)")
        end
    end
end

hookRemoteMethods()

-- ========== ОТСЛЕЖИВАНИЕ СОБЫТИЙ ТЕЛЕПОРТАЦИИ ИГРОКА ==========
local player = players.LocalPlayer
if player then
    player.OnTeleport:Connect(function(teleportData)
        log("player.OnTeleport: тип = " .. tostring(teleportData.TeleportType) .. ", место = " .. tostring(teleportData.PlaceId))
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

-- ========== ДОПОЛНИТЕЛЬНО: ОТСЛЕЖИВАНИЕ НОВЫХ REMOTE ИНСТАНСОВ ==========
local function onDescendantAdded(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        log("Создан новый инстанс: " .. descendant.ClassName .. " " .. tostring(descendant))
    end
end
game.DescendantAdded:Connect(onDescendantAdded)
log("Отслеживание новых RemoteEvent/RemoteFunction включено")

-- ========== НЕБЛОКИРУЮЩИЙ ЦИКЛ ОЖИДАНИЯ ==========
log("Трекер активен. Используйте хаб для телепортации.")
while true do
    task.wait(1)  -- ждём 1 секунду, чтобы не нагружать процессор
end
