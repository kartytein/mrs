-- ============================================================
-- HOHO Hub + Flask Parser Client (с server hop каждые 20 мин)
--   • Аптайм через моду
--   • Watcher shrine + blue moon (скан 0.5с)
--   • OUT → перебор hoho из кэша (30с)
--   • Каждые 20 минут → server hop
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local TeleportService   = game:GetService("TeleportService")
local player            = Players.LocalPlayer

local FLASK_URL = "http://192.168.31.179:8000"
local HUB_URL   = "https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"

local UPTIME_WINDOWS_SEC = {
    { 0*3600 + 46*60,   0*3600 + 56*60 },
    { 3*3600 + 58*60,   4*3600 +  8*60 },
    { 7*3600 + 12*60,   7*3600 + 22*60 },
    {10*3600 + 28*60,  10*3600 + 38*60 },
    {13*3600 + 40*60,  13*3600 + 51*60 },
    {16*3600 + 55*60,  17*3600 +  5*60 },
    {20*3600 + 11*60,  20*3600 + 21*60 },
    {23*3600 + 22*60,  23*3600 + 32*60 },
}

local TARGET_TEXT = "here"
local TARGET_PATH = {
    "Hоhо_gеn4","MAIN_UI","MAIN_ZONES","PAGES_TAB","ANCHOR",
    "CONFIG_PAGES","MINI_11_CONFIG_4","ScrollingFrame",
    "Tab2","Textbox2","Box",
}

local SHRINE_TEXT    = "A mysterious shrine has appeared in the sea"
local BLUE_MOON_TEXT = "The Blue Moon fades away"

local UPTIME_CHECK_SEC   = 30
local SHRINE_WAIT_SEC    = 7 * 60
local BOX_WAIT_TIMEOUT   = 30
local VERIFY_WAIT_SEC    = 10
local HOP_INTERVAL       = 20 * 60   -- 20 минут → server hop

print("[HOHO] === START ===")

-- 1. Хаб
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(HUB_URL))()
    end)
    if ok then print("[HOHO] Хаб загружен успешно.")
    else warn("[HOHO] Ошибка загрузки хаба: " .. tostring(err)) end
end)

-- 2. Команда
do
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then
            pcall(function() commF:InvokeServer("SetTeam", "Marines") end)
        end
    end
end

-- 3. Персонаж
local function isCharacterReady()
    local ok, res = pcall(function()
        local c = player.Character
        if not c then return false end
        local h = c:FindFirstChild("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if not h or not r then return false end
        return h.Health > 0
    end)
    return ok and res
end

repeat task.wait(0.5) until isCharacterReady()
task.wait(3)

-- ============================================================
-- 4. Аптайм — МОДА
-- ============================================================
local function getServerUptimeSeconds()
    local currentTime = workspace:GetServerTimeNow()
    local counts = {}

    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            for k, val in pairs(v) do
                if type(k) == "string" and (k == "timeIn" or k == "TimeIn") then
                    if type(val) == "number" and val > 1700000000 then
                        local sec = currentTime - val
                        if sec > 60 and sec < 30 * 86400 then
                            local key = math.floor(sec)
                            counts[key] = (counts[key] or 0) + 1
                        end
                    end
                end
            end
        end
    end

    if next(counts) == nil then return nil end

    local parts = {}
    for k, cnt in pairs(counts) do
        table.insert(parts, string.format("%ds(x%d)", k, cnt))
    end
    table.sort(parts)
    print("[uptime] candidates: " .. table.concat(parts, ", "))

    local best, bestCount = nil, 0
    for k, cnt in pairs(counts) do
        if cnt > bestCount or (cnt == bestCount and (best == nil or k < best)) then
            best, bestCount = k, cnt
        end
    end
    return best
end

local function inAnyWindow(sec)
    for _, w in ipairs(UPTIME_WINDOWS_SEC) do
        if sec >= w[1] and sec <= w[2] then return true end
    end
    return false
end

local function fmtUptime(sec)
    if not sec then return "nil" end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    return string.format("%dh:%02dm:%02ds (%ds)", h, m, s, sec)
end

-- ============================================================
-- 5. Watcher уведомлений
-- ============================================================
local shrineSeen   = false
local blueMoonSeen = false
local lastShrineTime   = 0
local lastBlueMoonTime = 0

local function scanNotifications()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    local notif = pg:FindFirstChild("Notifications")
    if not notif then return end
    local now = os.time()

    for _, obj in ipairs(notif:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local t = obj.Text or ""
            if t ~= "" then
                if t:find(SHRINE_TEXT, 1, true) and (now - lastShrineTime) > 5 then
                    shrineSeen = true
                    lastShrineTime = now
                    print("[watch] ★ SHRINE detected: " .. t:sub(1, 80))
                end
                if t:find(BLUE_MOON_TEXT, 1, true) and (now - lastBlueMoonTime) > 5 then
                    blueMoonSeen = true
                    lastBlueMoonTime = now
                    print("[watch] ★ BLUE MOON detected: " .. t:sub(1, 80))
                end
            end
        end
    end
end

task.spawn(function()
    task.wait(5)
    print("[watch] scan loop started (every 0.5s)")
    while true do
        scanNotifications()
        task.wait(0.5)
    end
end)

-- ============================================================
-- 6. Поиск TextBox
-- ============================================================
local function matchesPath(obj, segments)
    local cur = obj
    for i = #segments, 1, -1 do
        if not cur or cur.Name ~= segments[i] then return false end
        cur = cur.Parent
    end
    return true
end

local function dumpAllTextBoxes()
    print("[find] дамп TextBox:")
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") then
            print(string.format("[find]   text='%s' pos=(%.1f,%.1f) path=%s",
                tostring(obj.Text),
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                obj:GetFullName()))
        end
    end
end

local function findTargetBox(waitTimeout)
    waitTimeout = waitTimeout or BOX_WAIT_TIMEOUT
    local t0 = tick()
    local lastLog = 0
    while tick() - t0 < waitTimeout do
        if TARGET_TEXT and TARGET_TEXT ~= "" then
            for _, obj in ipairs(CoreGui:GetDescendants()) do
                if obj:IsA("TextBox") and (obj.Text or "") == TARGET_TEXT then
                    print(("[find] метка '%s' за %.1fs"):format(TARGET_TEXT, tick() - t0))
                    return obj
                end
            end
        end
        local cands = {}
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if obj:IsA("TextBox") and matchesPath(obj, TARGET_PATH) then
                table.insert(cands, obj)
            end
        end
        if #cands >= 1 then
            table.sort(cands, function(a, b)
                return a.AbsolutePosition.Y > b.AbsolutePosition.Y
            end)
            print(("[find] по пути за %.1fs (%d шт)"):format(tick() - t0, #cands))
            return cands[1]
        end
        if tick() - lastLog > 5 then
            lastLog = tick()
            print(("[find] ... ждём TextBox (%.0fs/%.0fs)"):format(tick() - t0, waitTimeout))
        end
        task.wait(0.5)
    end
    print(("[find] НЕ нашли за %.0fs"):format(waitTimeout))
    dumpAllTextBoxes()
    return nil
end

-- ============================================================
-- 7. Вставка
-- ============================================================
local function doInsert(box, value)
    if not box or not box.Parent then return false end
    pcall(function() box:CaptureFocus() end)
    task.wait(0.1)
    if not box.Parent then return false end
    box.Text = value
    task.wait(0.1)
    pcall(function() box:ReleaseFocus(true) end)
    task.wait(0.1)
    local sig = box.FocusLost
    if sig then
        local ok, conns = pcall(function() return getconnections(sig) end)
        if ok and conns then
            for _, c in ipairs(conns) do
                if c.Enabled and type(c.Function) == "function" then
                    pcall(c.Function)
                end
            end
        end
    end
    return true
end

-- ============================================================
-- 8. HTTP
-- ============================================================
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res then return res end
    warn("[http] error: " .. tostring(res))
    return nil
end

local function requestHohos()
    local url = FLASK_URL .. "/parse"
    local res = httpGet(url)
    if not res or res == "" then
        warn("[parse] empty response")
        return nil
    end

    print(("[parse] response: %d bytes, start='%s', end='%s'")
        :format(#res, res:sub(1, 40), res:sub(-40)))

    local ok, data = pcall(HttpService.JSONDecode, HttpService, res)
    if not ok then
        warn("[parse] JSONDecode FAILED — truncated")
        warn("[parse] raw: " .. res:sub(1, math.min(#res, 300)))
        return nil
    end
    if not data then
        warn("[parse] JSONDecode → nil")
        return nil
    end

    if data.hohos then return data.hohos end
    if data.details then
        warn("[parse] old format (details), converting")
        local out = {}
        for _, it in ipairs(data.details) do
            if it.hoho then table.insert(out, it.hoho) end
        end
        return out
    end
    warn("[parse] no 'hohos' in response")
    return nil
end

-- ============================================================
-- 9. Verify
-- ============================================================
local function countNotifications()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return 0 end
    local notif = pg:FindFirstChild("Notifications")
    if not notif then return 0 end
    local stack = notif:FindFirstChild("NotificationStack")
    if not stack then return 0 end
    local n = 0
    for _ in pairs(stack:GetChildren()) do n = n + 1 end
    return n
end

local function tryInsertAndVerify(hoho, box)
    if not box or not box.Parent then
        warn("[try] box пропал")
        return false
    end
    print("[try] insert " .. hoho:sub(1, 40) .. "...")
    local before = countNotifications()
    if not doInsert(box, hoho) then return false end

    local t0 = tick()
    while tick() - t0 < VERIFY_WAIT_SEC do
        task.wait(0.5)
        if countNotifications() > before then
            print(("[try] ✓ new notification за %.1fs"):format(tick() - t0))
            return true
        end
    end
    print(("[try] ✗ нет уведомления за %ds — следующий"):format(VERIFY_WAIT_SEC))
    return false
end

-- ============================================================
-- 10. doParseAndInsert
-- ============================================================
local function doParseAndInsert(reason)
    print("[main] request hohos (" .. (reason or "?") .. ")")
    local hohos = requestHohos()
    if not hohos then
        warn("[main] /parse failed (nil)")
        return false
    end
    if #hohos == 0 then
        warn("[main] кэш пуст — нечего вставлять")
        return false
    end
    print(("[main] got %d hohos — ищем TextBox..."):format(#hohos))

    local box = findTargetBox(BOX_WAIT_TIMEOUT)
    if not box then
        warn("[main] TextBox не найден")
        return false
    end

    for i, hoho in ipairs(hohos) do
        print(("[main] === try %d/%d ==="):format(i, #hohos))
        if tryInsertAndVerify(hoho, box) then
            print(("[main] ✓ hoho %d/%d сработал"):format(i, #hohos))
            return true
        end
        task.wait(2)
    end
    print("[main] ✗ все испробованы — ни один не сработал")
    return false
end

-- ============================================================
-- 11. Server hop
-- ============================================================
local function serverHop()
    print("[hop] === SERVER HOP ===")
    local ok, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
    if not ok then
        warn("[hop] Teleport error: " .. tostring(err))
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId)
        end)
    end
    -- после хопа скрипт умрёт вместе с сервером; новый экземпляр запустится на новом
end

-- ============================================================
-- 12. Main loop
-- ============================================================
print("[main] main loop started")
local lastUptimeCheck = 0
local lastHopTime     = os.time()

while true do
    -- === SERVER HOP каждые HOP_INTERVAL ===
    local sinceHop = os.time() - lastHopTime
    if sinceHop >= HOP_INTERVAL then
        print(("[hop] %d минут прошло → server hop"):format(HOP_INTERVAL / 60))
        serverHop()
        lastHopTime = os.time()
        task.wait(30)   -- ждём телепорта
    end

    -- === SHRINE ===
    if shrineSeen then
        shrineSeen   = false
        blueMoonSeen = false
        print("[shrine] shrine detected → wait blue moon")

        local t0 = os.time()
        local trigger = nil
        while (os.time() - t0) < SHRINE_WAIT_SEC do
            if blueMoonSeen then trigger = "blue moon"; break end
            task.wait(1)
        end
        if not trigger then
            trigger = "timeout " .. SHRINE_WAIT_SEC .. "s"
        end
        blueMoonSeen = false

        print(("[shrine] ended (%s, waited %ds) → try all hohos")
            :format(trigger, os.time() - t0))
        doParseAndInsert("shrine: " .. trigger)
        lastUptimeCheck = os.time()

    -- === BLUE MOON ===
    elseif blueMoonSeen then
        blueMoonSeen = false
        print("[main] blue moon → try all hohos")
        doParseAndInsert("blue moon")
        lastUptimeCheck = os.time()

    -- === UPTIME CHECK ===
    elseif (os.time() - lastUptimeCheck) >= UPTIME_CHECK_SEC then
        lastUptimeCheck = os.time()
        local sec = getServerUptimeSeconds()
        if not sec then
            print("[main] uptime unknown")
        elseif inAnyWindow(sec) then
            print("[main] " .. fmtUptime(sec) .. " | IN WINDOW")
        else
            print("[main] " .. fmtUptime(sec) .. " | OUT → try all hohos")
            doParseAndInsert("out of window")
        end
    end

    task.wait(1)
end
