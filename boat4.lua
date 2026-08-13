-- ===== ТРЕКЕР ТЕЛЕПОРТАЦИЙ (ИСПРАВЛЕННЫЙ, С ФИЛЬТРАЦИЕЙ REMOTE) =====
-- Исправлен OnTeleport (теперь принимает enum), добавлен перехват game.JobId,
-- и безопасный перехват Remote вызовов только для подозрительных объектов.

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
writefile("teleport_tracker.txt", "=== Teleport Tracker v2 ===\n")
log("Трекер запущен (с фильтрацией).")

-- Флаг для предотвращения рекурсии
local isLogging = false

-- ========== ПЕРЕХВАТ МЕТОДОВ TELEPORTSERVICE (без изменений) ==========
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

-- ========== ПЕРЕХВАТ ИЗМЕНЕНИЯ game.JobId ==========
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

-- ========== ПЕРЕХВАТ REMOTE ВЫЗОВОВ (С ФИЛЬТРАЦИЕЙ) ==========
-- Функция проверки, содержит ли аргумент JobId (строка с дефисами длиной > 20)
local function looksLikeJobId(arg)
    if type(arg) == "string" and string.len(arg) > 20 and string.find(arg, "%-") then
        return true
    end
    return false
end

-- Функция для хука на конкретном RemoteEvent/RemoteFunction
local function hookRemote(remote)
    if remote:IsA("RemoteEvent") then
        local fireServer = remote.FireServer
        if type(fireServer) == "function" then
            hookfunction(fireServer, function(self, ...)
                if isLogging then return fireServer(self, ...) end
                local args = {...}
                local shouldLog = false
                -- Логируем, если имя Remote подозрительное или аргументы содержат JobId
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
                return invokeServer(self, ...)
            end)
        end
    end
end

-- Хукаем существующие Remote (только те, что созданы после старта? Хукаем все, но с фильтром внутри)
for _, descendant in ipairs(game:GetDescendants()) do
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        hookRemote(descendant)
    end
end

-- Хукаем новые Remote при создании
game.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        log("Создан: " .. descendant.ClassName .. " " .. tostring(descendant))
        hookRemote(descendant)
    end
end)

-- ========== ИСПРАВЛЕННЫЙ ОБРАБОТЧИК OnTeleport ==========
local player = players.LocalPlayer
if player then
    player.OnTeleport:Connect(function(teleportState)
        -- teleportState - это Enum.TeleportState, а не таблица
        log("player.OnTeleport: " .. tostring(teleportState))
        -- Дополнительно логируем текущий JobId (вдруг уже сменился)
        log("  Текущий game.JobId: " .. tostring(game.JobId))
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
