-- ===== МАКСИМАЛЬНО БЕЗОПАСНЫЙ ТРЕКЕР (без hookfunction, только события) =====
-- Не перехватывает методы, поэтому не должен вызывать краши.
-- Просто записывает все возможные события телепортации и создание Remote объектов.

local teleportService = game:GetService("TeleportService")
local players = game:GetService("Players")
local logService = game:GetService("LogService")
local runService = game:GetService("RunService")

-- Функция логирования в файл
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
writefile("teleport_tracker.txt", "=== Safe Teleport Tracker ===\n")
log("Трекер запущен (без хуков). Ожидание телепортации...")

-- ========== ОТСЛЕЖИВАНИЕ СОЗДАНИЯ REMOTE ОБЪЕКТОВ ==========
game.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
        log("Создан: " .. descendant.ClassName .. " " .. tostring(descendant))
    end
end)
log("Отслеживание новых RemoteEvent/RemoteFunction включено")

-- ========== ОТСЛЕЖИВАНИЕ СОБЫТИЯ ONTELEPORT ИГРОКА ==========
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
else
    log("Локальный игрок не найден")
end

-- ========== ОТСЛЕЖИВАНИЕ СООБЩЕНИЙ LOGSERVICE ==========
logService.MessageOut:Connect(function(message, messageType)
    if string.find(string.lower(message), "teleport") or string.find(string.lower(message), "jobid") then
        log("LogService: [" .. tostring(messageType) .. "] " .. message)
    end
end)
log("Отслеживание LogService.MessageOut включено")

-- ========== ПЕРИОДИЧЕСКАЯ ПРОВЕРКА JOBID (на всякий случай) ==========
spawn(function()
    while true do
        task.wait(5)
        local currentJobId = game.JobId
        log("Текущий JobId: " .. tostring(currentJobId))
    end
end)
log("Периодическая проверка game.JobId запущена")

-- ========== ОЖИДАНИЕ ==========
log("Трекер активен. Выполните телепортацию через хаб и проверьте файл.")
while true do
    task.wait(1)
end
