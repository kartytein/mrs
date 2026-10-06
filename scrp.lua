--!nocheck
-- ============================================================
-- MERGED SCRIPT — Green + Full Dispatcher
-- ============================================================

-- ============================================================
-- КОНФИГ
-- ============================================================
local BELT_SCAN_INTERVAL    = 30
local BELT_SCAN_RETRY_FAST  = 5
local HOLD_CHECK_INTERVAL   = 30
local HOLD_TOGGLE_INTERVAL  = 90
local NOBELT_MASTERY_TIMEOUT= 60
local STUCK_TIMEOUT         = 180
local STUCK_CHECK_INTERVAL  = 30
local STUCK_MOVE_THRESHOLD  = 5
local SERVER_URL            = "http://192.168.31.179:8000"
local BELT_ORDER            = {"White","Yellow","Orange","Green","Blue","Purple","Red","Black"}

local SCROLL_STEP_PIXELS  = 10
local SCROLL_WAIT_TIME    = 0.15
local SCROLL_INITIAL_WAIT = 1.0
local SCROLL_FINAL_WAIT   = 1.0

local FIXED_POS           = Vector3.new(9825.3, -1962.3, 9822.5)
local TRADE_WAYPOINT      = Vector3.new(-12549.7, 337.5, -7501.1)
local POST_TRADE_WAYPOINT = Vector3.new(5866.9, 1258.6, 872.0)
local POST_TRADE_NPC_NAME = "Dojo Trainer"

-- GREEN
local GREEN_HOST_POS      = Vector3.new(5842.3, 1208.6, 886.3)
local GREEN_GUEST_POS     = Vector3.new(5847.1, 1208.6, 882.4)
local GREEN_MOVE_SPEED    = 250
local GREEN_POS_TOLERANCE = 8
local PARTNER_NEAR_RADIUS = 30
local CLAIM_RETRY_DELAY   = 2
local DELAY_AFTER_ARRIVE  = 2
local DELAY_AFTER_DROP    = 2
local DELAY_BEFORE_CLAIM  = 5
local DELAY_AFTER_CLAIM   = 5
local DELAY_BEFORE_DROP2  = 2
local TAB_FRUIT,  OPT_FRUIT  = 8, 7
local TAB_TOGGLE, OPT_TOGGLE = 6, 1

-- ============================================================
-- ЛОГГЕР
-- ============================================================
local T0 = tick()
local function LOG(tag, msg)  print(string.format("[%7.2fs][%s] %s", tick() - T0, tag, msg)) end
local function WARN(tag, msg) warn(string.format("[%7.2fs][%s] %s", tick() - T0, tag, msg)) end

-- ============================================================
-- СЕРВИСЫ И СОСТОЯНИЕ
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- ВЫБОР КОМАНДЫ НА СТАРТЕ
-- ============================================================
do
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then
            pcall(function() commF:InvokeServer("SetTeam", "Marines") end)
            LOG("Team", "SetTeam Marines (старт)")
        else WARN("Team", "нет Remotes.CommF_ на старте") end
    else WARN("Team", "нет Remotes на старте") end
end

local RF_InteractDragonQuest = nil
do
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local net = modules:FindFirstChild("Net")
        if net then
            RF_InteractDragonQuest = net:FindFirstChild("RF/InteractDragonQuest")
        end
    end
end

local State = {
    currentBelt     = "Unknown",
    beltChangedAt   = tick(),
    beltScanPaused  = false,
    running         = true,
    nobeltDone      = false,
    tradeDone       = false,
    greenDone       = false,
    inTrade         = false,
    mode            = "none",
}

-- ============================================================
-- КОЛЛИЗИИ (глобально)
-- ============================================================
local collisionsDisabledGlobal = false
local savedCollisionsGlobal = {}

local function disableCollisionsNow()
    pcall(function()
        local myChar = player.Character
        local saved = savedCollisionsGlobal
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if myChar and obj:IsDescendantOf(myChar) then
                    -- skip
                else
                    if obj.CanCollide then
                        saved[obj] = true
                        obj.CanCollide = false
                    end
                end
            end
        end
    end)
end

local function restoreCollisionsNow()
    for part, _ in pairs(savedCollisionsGlobal) do
        if part and part.Parent then
            pcall(function() part.CanCollide = true end)
        end
    end
    savedCollisionsGlobal = {}
end

task.spawn(function()
    while true do
        if collisionsDisabledGlobal then
            disableCollisionsNow()
            task.wait(1.0)
        else
            task.wait(0.5)
        end
    end
end)

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
local function fireSequence(btn)
    if not btn then return false end
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local fired = false
    for _, sigName in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn.Enabled and type(conn.Function) == "function" then
                        pcall(conn.Function); fired = true
                    end
                end
            end
        end
    end
    return fired
end

local function findObjectByPath(root, ...)
    local current = root
    for _, segment in ipairs({...}) do
        if not current then return nil end
        current = current:FindFirstChild(segment)
    end
    return current
end

local function findHudButtonByName(buttonName)
    local hudRoot = playerGui:FindFirstChild("HUDRoot")
    if not hudRoot then return nil end
    local frame = hudRoot:FindFirstChild("Frame")
    if not frame then return nil end
    local hud = frame:FindFirstChild("HUD")
    if not hud then return nil end
    local function search(node)
        for _, child in ipairs(node:GetChildren()) do
            if (child:IsA("TextButton") or child:IsA("ImageButton")) and child.Name == buttonName then
                return child
            end
            local found = search(child)
            if found then return found end
        end
        return nil
    end
    return search(hud)
end

local function waitForHudButton(buttonName, timeout)
    local waited = 0
    while waited < timeout do
        local btn = findHudButtonByName(buttonName)
        if btn then return btn end
        task.wait(0.5); waited += 0.5
    end
    return nil
end

local function waitForObjectByPath(pathTable, timeout)
    local waited = 0
    while waited < timeout do
        local obj = findObjectByPath(playerGui, table.unpack(pathTable))
        if obj then return obj end
        task.wait(0.5); waited += 0.5
    end
    return nil
end

local function findInventoryButtonByName(buttonName)
    local inv = playerGui:FindFirstChild("Inventory")
    if not inv then return nil end
    for _, obj in ipairs(inv:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == buttonName then
            return obj
        end
    end
    return nil
end

local function findCategory(catName)
    local c = findObjectByPath(playerGui, "Inventory","Inventory","Main","NavigationRail", catName)
    if c then return c end
    return findInventoryButtonByName(catName)
end

local function ensureCategoryOpen(catName)
    local category = findCategory(catName)
    if category then
        fireSequence(category); task.wait(SCROLL_INITIAL_WAIT)
        return category
    end
    local menuButton = waitForHudButton("Menu", 10)
    if not menuButton then WARN("Cat", "нет Menu"); return nil end
    fireSequence(menuButton); task.wait(1.5)

    local itemsButton = waitForHudButton("Items", 10)
    if not itemsButton then WARN("Cat", "нет Items"); return nil end
    fireSequence(itemsButton); task.wait(1.5)

    category = waitForObjectByPath({"Inventory","Inventory","Main","NavigationRail", catName}, 5)
    if not category then category = findInventoryButtonByName(catName) end
    if not category then WARN("Cat", "нет " .. catName); return nil end
    fireSequence(category); task.wait(SCROLL_INITIAL_WAIT)
    return category
end

-- ============================================================
-- CALL REMOTE
-- ============================================================
local function callRemote(args, label)
    if not RF_InteractDragonQuest then
        WARN("Remote", "RF/InteractDragonQuest не найден")
        return false
    end
    LOG("Remote", "▶ " .. label)
    local ok, resp = pcall(function()
        return RF_InteractDragonQuest:InvokeServer(args)
    end)
    if ok then
        LOG("Remote", "  ✓ " .. label .. " OK, ответ: " .. tostring(resp))
    else
        WARN("Remote", "  ✗ " .. label .. " ошибка: " .. tostring(resp))
    end
    return ok, resp
end

-- ============================================================
-- ПЕРЕМЕЩЕНИЕ
-- ============================================================
local STEP_XZ          = 4
local TELEPORT_DIST_XZ = 12
local Y_UP_SPEED       = 50
local Y_TOLERANCE      = 3
local MAX_ITER         = 6000

local function goToPosition(targetPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end

    hum.PlatformStand = true

    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyPosition") or v:IsA("BodyGyro")
           or v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
            v:Destroy()
        end
    end

    local bv = hrp:FindFirstChildOfClass("BodyVelocity")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
    end

    local lastLogAt = tick()
    local iter = 0
    LOG("Move", string.format("старт (%.0f,%.0f,%.0f)", targetPos.X, targetPos.Y, targetPos.Z))

    while iter < MAX_ITER do
        iter += 1
        char = player.Character
        if not char then break end
        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then break end
        if hum.Health <= 0 then WARN("Move", "персонаж мёртв"); break end

        bv = hrp:FindFirstChildOfClass("BodyVelocity")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
        end

        local cur = hrp.Position
        local dx, dz = targetPos.X - cur.X, targetPos.Z - cur.Z
        local dy = targetPos.Y - cur.Y
        local distXZ = math.sqrt(dx*dx + dz*dz)

        if distXZ < 1 and math.abs(dy) < Y_TOLERANCE then break end

        if distXZ < TELEPORT_DIST_XZ and distXZ > 0 then
            hrp.CFrame = CFrame.new(targetPos.X, cur.Y, targetPos.Z)
        elseif distXZ >= TELEPORT_DIST_XZ then
            local step = math.min(STEP_XZ, distXZ)
            local nx, nz = dx / distXZ, dz / distXZ
            hrp.CFrame = CFrame.new(cur.X + nx * step, cur.Y, cur.Z + nz * step)
        end

        local velY = 0
        if dy > Y_TOLERANCE then
            velY = math.min(Y_UP_SPEED, dy * 2)
        elseif dy < -Y_TOLERANCE then
            velY = -20
        end
        bv.Velocity = Vector3.new(0, velY, 0)

        if tick() - lastLogAt >= 2 then
            lastLogAt = tick()
            LOG("Move", string.format("dxz=%.1f dy=%.1f velY=%.1f", distXZ, dy, velY))
        end

        task.wait()
    end

    if char and hrp and hum then
        hum.PlatformStand = false
        local bv2 = hrp:FindFirstChildOfClass("BodyVelocity")
        if bv2 then bv2:Destroy() end
    end
    LOG("Move", "дошли до точки")
    return true
end

-- ============================================================
-- ЗАГРУЗКА ХАБА
-- ============================================================
LOG("Hub", "загружаю хаб...")
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

-- ============================================================
-- СКАНЕР ПОЯСА
-- ============================================================
local ItemId = nil
do
    local ok, mod = pcall(require, ReplicatedStorage.Economy.ItemId)
    if ok then
        ItemId = mod
        LOG("BeltScan", "ItemId модуль загружен")
    else
        WARN("BeltScan", "не удалось загрузить ItemId")
    end
end

local function getItemInfo(id)
    if not ItemId then return nil, nil end
    local ok, d = pcall(ItemId.getDataFromId, id)
    if not ok or type(d) ~= "table" then return nil, nil end
    local n = d._ok or d.value or d
    if type(n) ~= "table" then return nil, nil end
    return n.StorageKey or n.Name, n.Type
end

local function isUidKey(k)
    return type(k) == "string" and k:match("^%d+_[%w]+$") ~= nil
end

local function findInventoryCache()
    local best, bestN = nil, 0
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            local n = 0
            pcall(function()
                for k in pairs(obj) do
                    if isUidKey(k) then n += 1 end
                    if n > 500 then break end
                end
            end)
            if n > bestN then best, bestN = obj, n end
        end
    end
    return best, bestN
end

local function doBeltScan()
    local cache, count = findInventoryCache()
    if not cache then
        LOG("BeltScan", "cache не найден (инвентарь ни разу не открыт)")
        return nil
    end

    LOG("BeltScan", "cache найден, записей: " .. count)

    local foundBelts = {}
    local allAcc = {}
    for k in pairs(cache) do
        local id = tonumber(k:match("^(%d+)_"))
        if id then
            local name, tp = getItemInfo(id)
            if tp == "Accessory" and name then
                table.insert(allAcc, name)
                local lname = name:lower()
                if lname:find("belt", 1, true) then
                    for _, color in ipairs(BELT_ORDER) do
                        if lname:find(color:lower(), 1, true) then
                            foundBelts[color] = name
                            break
                        end
                    end
                end
            end
        end
    end

    LOG("BeltScan", "accessory всего: " .. #allAcc .. " | belt-like: " .. (function()
        local n = 0
        for _ in pairs(foundBelts) do n += 1 end
        return n
    end)())

    for color, name in pairs(foundBelts) do
        LOG("BeltScan", "  найден belt-цвет: " .. color .. " ('" .. name .. "')")
    end

    local highest, highestIdx = nil, 0
    for color, _ in pairs(foundBelts) do
        for i, oc in ipairs(BELT_ORDER) do
            if color == oc and i > highestIdx then
                highestIdx = i; highest = color; break
            end
        end
    end

    if highest then
        LOG("BeltScan", "результат: " .. highest)
        return highest
    end

    LOG("BeltScan", "результат: None (belt не найден, но cache есть)")
    return "None"
end

task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end

    local w = 0
    while not findHudButtonByName("Menu") and w < 90 do task.wait(1); w += 1 end
    if not findHudButtonByName("Menu") then
        WARN("BeltScan", "HUD Menu не появилась"); return
    end
    task.wait(5)

    while State.running do
        if not State.beltScanPaused then
            local ok, belt = pcall(doBeltScan)
            if not ok then
                WARN("BeltScan", "ошибка: " .. tostring(belt))
            elseif belt == nil then
                task.wait(BELT_SCAN_RETRY_FAST)
            elseif belt ~= State.currentBelt then
                LOG("BeltScan", "НОВЫЙ РЕЖИМ: " .. State.currentBelt .. " -> " .. belt)
                State.currentBelt = belt
                State.beltChangedAt = tick()
            end
        end
        task.wait(BELT_SCAN_INTERVAL)
    end
end)

-- ============================================================
-- СЕРВЕР-ХОП
-- ============================================================
local function serverHop()
    LOG("Hop", "=== старт сервер-хопа ===")
    State.beltScanPaused = true

    local originalJobId = game.JobId

    local function findSB()
        local tb = playerGui:FindFirstChild("Topbar")
        if tb then
            local f = tb:FindFirstChild("Frame")
            if f then return f:FindFirstChild("ServerBrowserButton") end
        end
        return nil
    end

    local function findJoin()
        for _, v in ipairs(playerGui:GetDescendants()) do
            if (v:IsA("TextButton") or v:IsA("TextBox")) and v.Text == "Join" and v.Visible then
                return v
            end
        end
        return nil
    end

    for attempt = 1, 5 do
        local w = 0
        while not findSB() and w < 10 do task.wait(0.5); w += 0.5 end
        local sb = findSB()
        if not sb then WARN("Hop", "нет ServerBrowserButton"); task.wait(2); continue end
        fireSequence(sb); task.wait(1.5)

        w = 0
        while not findJoin() and w < 15 do task.wait(0.5); w += 0.5 end
        if not findJoin() then WARN("Hop", "нет Join"); task.wait(2); continue end

        local sBrowser = playerGui:FindFirstChild("ServerBrowser")
        if not sBrowser then WARN("Hop", "нет ServerBrowser"); task.wait(2); continue end
        local f = sBrowser:FindFirstChild("Frame")
        if not f then WARN("Hop", "нет Frame"); task.wait(2); continue end
        local sf = f:FindFirstChild("ScrollingFrame")
        if not sf then WARN("Hop", "нет ScrollingFrame"); task.wait(2); continue end

        local cY = sf.CanvasSize.Y
        local maxY = (typeof(cY) == "UDim") and cY.Offset or cY
        local dur = math.random(1, 10)
        local y, t0 = 0, tick()
        sf.CanvasPosition = Vector2.new(0, 0)
        task.wait(0.3)
        while (tick() - t0) < dur and y < maxY do
            y = math.min(y + 150, maxY)
            sf.CanvasPosition = Vector2.new(0, y)
            task.wait(0.03)
        end

        local btns = {}
        local function collect(p)
            for _, c in ipairs(p:GetChildren()) do
                if (c:IsA("TextButton") or c:IsA("TextBox")) and c.Text == "Join" and c.Visible then
                    table.insert(btns, c)
                end
                collect(c)
            end
        end
        collect(sBrowser)
        if #btns == 0 then WARN("Hop", "нет Join кнопок"); task.wait(2); continue end

        local chosen = btns[math.random(1, #btns)]
        fireSequence(chosen)

        task.wait(10)
        if game.JobId ~= originalJobId then
            LOG("Hop", "ТЕЛЕПОРТ: " .. originalJobId .. " -> " .. game.JobId)
            task.wait(8)
            State.nobeltDone    = false
            State.tradeDone     = false
            State.greenDone     = false
            State.currentBelt   = "Unknown"
            State.beltChangedAt = tick()
            State.beltScanPaused = false
            return true
        end
        task.wait(1)
    end

    State.beltScanPaused = false
    return false
end

-- ============================================================
-- ХАБ: опции
-- ============================================================
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local TAB_MAIN, OPT_MAIN = 6, 1
local TAB_FARM, OPT_FARM = 2, 4

local function getRoot()
    for _, c in ipairs(CoreGui:GetChildren()) do
        local obj = c:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end

local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child)
        if found then return found end
    end
    return nil
end

local function findTab(root, tabIndex)
    local ts = safeFind(root, "Window","Components","TabsScroll")
    if not ts then return nil end
    local btn, count = nil, 0
    local function scan(p)
        if btn then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                count += 1
                if count == tabIndex then btn = c; return end
            end
            scan(c)
        end
    end
    scan(ts)
    return btn
end

local function findOption(root, optIndex)
    local cont = safeFind(root, "Window","Components","Containers","Container")
    if not cont then return nil end
    local btn, count = nil, 0
    for _, c in ipairs(cont:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            count += 1
            if count == optIndex then btn = c; break end
        end
    end
    return btn
end

local function waitForOptions(expectedMin, timeout)
    timeout = timeout or 8
    expectedMin = expectedMin or 1
    local t0 = tick()
    local last, stable = -1, 0
    while tick() - t0 < timeout do
        local root = getRoot()
        local cont = root and safeFind(root, "Window","Components","Containers","Container")
        local count = 0
        if cont then
            for _, c in ipairs(cont:GetChildren()) do
                if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                    count += 1
                end
            end
        end
        if count >= expectedMin then
            if count == last then
                stable += 1
                if stable >= 2 then return true end
            else stable, last = 0, count end
        else last, stable = -1, 0 end
        task.wait(0.15)
    end
    return false
end

local function getOptionState(tabIndex, optIndex)
    local root = getRoot()
    if not root then return nil end
    local tb = findTab(root, tabIndex)
    if not tb then return nil end
    fireSequence(tb)
    if not waitForOptions(optIndex, 8) then return nil end
    local opt = findOption(root, optIndex)
    if not opt then return nil end
    local ind = findIndicatorFrame(opt)
    if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    if col == COLOR_ON then return true end
    if col == COLOR_OFF then return false end
    return nil
end

local function setOption(tabIndex, optIndex, wantOn)
    local root = getRoot()
    if not root then return false end
    local tb = findTab(root, tabIndex)
    if not tb then return false end
    fireSequence(tb)
    if not waitForOptions(optIndex, 8) then return false end

    local opt = findOption(root, optIndex)
    if not opt then return false end
    local ind = findIndicatorFrame(opt)
    if not ind then return false end
    local isOn = (tostring(ind.BackgroundColor3) == COLOR_ON)
    if isOn == wantOn then return true end

    fireSequence(opt); task.wait(0.2)
    for _ = 1, 5 do
        local i2 = findIndicatorFrame(opt)
        if i2 and (tostring(i2.BackgroundColor3) == COLOR_ON) == wantOn then return true end
        fireSequence(opt); task.wait(0.25)
    end
    return false
end

local function ensureOptionState(tabIndex, optIndex, wantOn, maxTries)
    maxTries = maxTries or 6
    for i = 1, maxTries do
        local st = getOptionState(tabIndex, optIndex)
        if st == wantOn then return true end
        setOption(tabIndex, optIndex, wantOn)
        task.wait(0.4)
    end
    return getOptionState(tabIndex, optIndex) == wantOn
end

local function ensureOptionOff(tabIndex, optIndex, maxTries)
    return ensureOptionState(tabIndex, optIndex, false, maxTries)
end

local function ensureOptionOn(tabIndex, optIndex, maxTries)
    return ensureOptionState(tabIndex, optIndex, true, maxTries)
end

-- бесконечные (для green)
local function ensureOptionOffInfinite(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == false then return true end
        setOption(tabIndex, optIndex, false)
        task.wait(0.4)
    end
    return false
end

local function ensureOptionOnInfinite(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == true then return true end
        setOption(tabIndex, optIndex, true)
        task.wait(0.4)
    end
    return false
end

-- ============================================================
-- ОЖИДАНИЕ ГОТОВНОСТИ ХАБА
-- ============================================================
local function waitForHubReady(timeout)
    local t0 = tick()
    local firstSeen = false
    local lastLogAt = tick()
    while State.running do
        if getRoot() then
            if not firstSeen then
                firstSeen = true
                LOG("Hub", "root появился, жду опции...")
            end
            if waitForOptions(1, 2) then
                LOG("Hub", "готов (t=" .. string.format("%.1f", tick() - t0) .. "s)")
                return true
            end
        end
        if timeout and (tick() - t0) >= timeout then
            WARN("Hub", "не готов за " .. timeout .. "с")
            return false
        end
        if tick() - lastLogAt >= 30 then
            lastLogAt = tick()
            LOG("Hub", string.format("жду... %.0fс (root=%s)",
                tick() - t0, tostring(getRoot() ~= nil)))
        end
        task.wait(0.5)
    end
    return false
end

-- ============================================================
-- STUCK WATCHDOG
-- ============================================================
task.spawn(function()
    task.wait(30)
    local lastPos = nil
    local lastMoveAt = tick()
    while State.running do
        if State.inTrade then
            lastPos = nil; lastMoveAt = tick()
        else
            local c = player.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                if not lastPos then
                    lastPos = hrp.Position; lastMoveAt = tick()
                else
                    local moved = (hrp.Position - lastPos).Magnitude
                    if moved > STUCK_MOVE_THRESHOLD then
                        lastPos = hrp.Position; lastMoveAt = tick()
                    end
                end
                local idle = tick() - lastMoveAt
                if idle > STUCK_TIMEOUT then
                    WARN("Stuck", "нет движения " .. math.floor(idle) .. "с — hop")
                    serverHop()
                    lastPos = nil; lastMoveAt = tick()
                end
            end
        end
        task.wait(STUCK_CHECK_INTERVAL)
    end
end)

-- ============================================================
-- NO BELT
-- ============================================================
local function hasDragonTalon()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return false end
    local wac = pg:FindFirstChild("WeaponAssetCache")
    if not wac then return false end
    return wac:FindFirstChild("dragontalon") ~= nil
end

local function isOnIsland()
    local world = Workspace:FindFirstChild("_WorldOrigin")
    if not world then return false end
    local sounds = world:FindFirstChild("Sounds")
    if not sounds then return false end
    local locs = sounds:FindFirstChild("Locations")
    if not locs then return false end
    return locs:FindFirstChild("Submerged Island") ~= nil
end

local function getMastery()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then return nil end
    local lbl = main:FindFirstChild("MobileMasteryLevel")
    if not lbl then return nil end
    return tonumber(string.match(lbl.Text or "", "%d+"))
end

local function isNoBeltActive()
    return State.currentBelt == "None" or State.currentBelt == "Unknown"
end

local function runNoBeltMode()
    if not isNoBeltActive() then
        LOG("NoBelt", "belt=" .. State.currentBelt .. " — не наш режим, выход")
        return
    end

    LOG("NoBelt", "=== START ===")
    if not waitForHubReady() then WARN("NoBelt", "выход по State.running=false"); return end
    if not isNoBeltActive() then LOG("NoBelt", "belt сменился — выход"); return end

    LOG("NoBelt", "2,4 OFF на старте")
    ensureOptionOff(TAB_FARM, OPT_FARM)
    task.wait(0.5)

    local guard = 0
    while not hasDragonTalon() and State.running and isNoBeltActive() do
        ensureOptionOn(TAB_MAIN, OPT_MAIN)
        task.wait(2.5); guard += 1
        if guard % 15 == 0 then LOG("NoBelt", "guard=" .. guard) end
    end
    if not isNoBeltActive() then return end
    LOG("NoBelt", "dragon talon OK")

    while not isOnIsland() and State.running and isNoBeltActive() do
        ensureOptionOn(TAB_MAIN, OPT_MAIN)
        task.wait(2.5)
    end
    if not isNoBeltActive() then return end
    LOG("NoBelt", "остров найден (sound)")

    LOG("NoBelt", "6,1 OFF")
    if not ensureOptionOff(TAB_MAIN, OPT_MAIN) then WARN("NoBelt", "не удалось выключить 6,1") end

    LOG("NoBelt", "2,4 OFF (перед goToPosition)")
    if not ensureOptionOff(TAB_FARM, OPT_FARM) then
        WARN("NoBelt", "2,4 не выключилось — повторная попытка")
        waitForHubReady(60)
        ensureOptionOff(TAB_FARM, OPT_FARM)
    end
    task.wait(1)

    LOG("NoBelt", "коллизии OFF")
    collisionsDisabledGlobal = true
    disableCollisionsNow()
    task.wait(0.5)

    LOG("NoBelt", "goTo FIXED_POS")
    goToPosition(FIXED_POS)
    task.wait(0.5)

    ensureOptionOff(TAB_FARM, OPT_FARM)

    LOG("NoBelt", "коллизии ON")
    collisionsDisabledGlobal = false
    restoreCollisionsNow()
    task.wait(0.5)

    LOG("NoBelt", "2,4 ON (после перемещения)")
    if not ensureOptionOn(TAB_FARM, OPT_FARM) then WARN("NoBelt", "не удалось включить 2,4") end

    local lastMastery = getMastery() or 0
    local lastChangeAt = tick()
    while State.running and isNoBeltActive() do
        task.wait(5)
        local m = getMastery() or 0
        if m > lastMastery then
            LOG("NoBelt", "mastery " .. lastMastery .. " -> " .. m)
            lastMastery = m; lastChangeAt = tick()
        end
        if m > 500 then break end
        if tick() - lastChangeAt > NOBELT_MASTERY_TIMEOUT then
            WARN("NoBelt", "mastery не растёт — hop")
            serverHop()
            return
        end
    end
    if not isNoBeltActive() then return end

    setOption(TAB_FARM, OPT_FARM, false); task.wait(0.5)
    setOption(TAB_MAIN, OPT_MAIN, true)
    State.nobeltDone = true
end

-- ============================================================
-- HOLD 6,1
-- ============================================================
local function runHoldSixOne()
    LOG("Hold", "жду готовности хаба...")
    if not waitForHubReady() then WARN("Hold", "выход по State.running=false"); return end

    local modeAtStart = State.currentBelt
    pcall(function() setOption(TAB_MAIN, OPT_MAIN, true) end)
    local lastToggleAt, lastStatusCheck = tick(), tick()
    local failStreak = 0

    while State.running do
        if State.currentBelt ~= modeAtStart then
            LOG("Hold", "belt сменился — выход")
            return
        end
        if tick() - lastToggleAt > HOLD_TOGGLE_INTERVAL then
            setOption(TAB_MAIN, OPT_MAIN, false); task.wait(0.5)
            setOption(TAB_MAIN, OPT_MAIN, true)
            lastToggleAt = tick()
        end
        if tick() - lastStatusCheck > HOLD_CHECK_INTERVAL then
            local state = getOptionState(TAB_MAIN, OPT_MAIN)
            if state ~= true then
                if not setOption(TAB_MAIN, OPT_MAIN, true) then
                    failStreak += 1
                    if failStreak >= 3 then task.wait(15); failStreak = 0 end
                else failStreak = 0 end
            else failStreak = 0 end
            lastStatusCheck = tick()
        end
        task.wait(3)
    end
end

-- ============================================================
-- ТРЕЙД
-- ============================================================
local function runTradeMode()
    LOG("Trade", "=== START ===")
    if not waitForHubReady() then WARN("Trade", "выход по State.running=false"); return end

    State.beltScanPaused = true
    State.inTrade = true

    LOG("Trade", "6,1 OFF")
    ensureOptionOff(TAB_MAIN, OPT_MAIN)
    task.wait(0.3)

    LOG("Trade", "2,4 OFF")
    ensureOptionOff(TAB_FARM, OPT_FARM)
    task.wait(0.3)

    local SEND_INVENTORY_INTERVAL = 20
    local CONFIG_POLL_INTERVAL    = 10

    local TELEPORT_TAB          = 19
    local TELEPORT_OPT_TEXT     = 2
    local TELEPORT_OPT_ACTIVATE = 3

    local function fastSitOnSeat(targetSeat, maxAttempts)
        maxAttempts = maxAttempts or 3
        for attempt = 1, maxAttempts do
            local char = player.Character
            if not char then return false end
            local hum = char:FindFirstChild("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp then return false end

            if hum.Sit and hum.SeatPart == targetSeat then return true end

            hum.PlatformStand = true
            local bv = hrp:FindFirstChildOfClass("BodyVelocity")
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = hrp
            end
            bv.Velocity = Vector3.zero

            local targetPos = targetSeat.Position + Vector3.new(0, 3.5, 0)
            hrp.CFrame = CFrame.new(targetPos)
            task.wait(0.05)

            hum.Sit = true
            task.wait(0.1)

            if hum.Sit and hum.SeatPart == targetSeat then
                bv:Destroy()
                hum.PlatformStand = false
                return true
            else
                bv:Destroy()
                hum.Sit = false
                hum.PlatformStand = false
                task.wait(0.2)
            end
        end
        return false
    end

    local function moveAndSitOnSeat(seat)
        local sitTarget = seat.Position + Vector3.new(0, 3.5, 0)
        LOG("Move", "иду к seat")
        goToPosition(sitTarget)
        for i = 1, 5 do
            if fastSitOnSeat(seat, 1) then LOG("Move", "СЕЛ"); return true end
            task.wait(0.3)
            goToPosition(seat.Position + Vector3.new(0, 3.5, 0))
        end
        return false
    end

    local function jumpAndReSeat(seat, sitTarget)
        local c = player.Character
        if c then
            local h = c:FindFirstChild("Humanoid")
            if h then
                pcall(function() h.Sit = false end)
                task.wait(0.1)
                pcall(function() h.Jump = true end)
                task.wait(0.3)
            end
        end
        goToPosition(sitTarget)
        return fastSitOnSeat(seat, 3)
    end

    local function selectTeam()
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", "Marines")
        end)
        task.wait(3)
    end

    local function extractTileInfo(tileObject)
        local details = tileObject:FindFirstChild("Details")
        local text = nil
        if details then
            local l1 = details:FindFirstChild("Line-1")
            if l1 and l1:IsA("TextLabel") and l1.Text ~= "" then text = l1.Text end
            if not text then
                local l2 = details:FindFirstChild("Line-2")
                if l2 and l2:IsA("TextLabel") and l2.Text ~= "" then text = l2.Text end
            end
            if not text then
                for _, o in ipairs(details:GetDescendants()) do
                    if o:IsA("TextLabel") and o.Text ~= "" then text = o.Text; break end
                end
            end
        end
        if not text then
            for _, o in ipairs(tileObject:GetDescendants()) do
                if o:IsA("TextLabel") and o.Text ~= "" then text = o.Text; break end
            end
        end
        if not text then return nil end
        local clean = text
        local ci = clean:find(",")
        if ci then clean = clean:sub(1, ci - 1) end
        clean = clean:gsub("%s+$", "")
        local num = tonumber(tileObject.Name:sub(6)) or 0
        return {Name = tileObject.Name, Number = num, Text = clean}
    end

    local function collectInventory()
        local category2 = ensureCategoryOpen("Category2")
        if not category2 then WARN("Inv", "нет Category2"); return {} end
        local tileGrid = waitForObjectByPath({"Inventory","Inventory","Main","PageContent","TileGrid"}, 5)
        if not tileGrid then return {} end
        local scrollingFrame = nil
        local obj = tileGrid
        while obj do
            if obj:IsA("ScrollingFrame") then scrollingFrame = obj; break end
            obj = obj.Parent
        end
        local collected, list = {}, {}
        local function collectVisible()
            for _, child in ipairs(tileGrid:GetDescendants()) do
                if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
                    local info = extractTileInfo(child)
                    if info and not collected[info.Name] then
                        collected[info.Name] = true
                        table.insert(list, info)
                    end
                end
            end
        end
        if scrollingFrame then
            local cy = scrollingFrame.AbsoluteCanvasSize.Y
            local wy = scrollingFrame.AbsoluteSize.Y
            scrollingFrame.CanvasPosition = Vector2.new(0, 0)
            task.wait(SCROLL_INITIAL_WAIT)
            collectVisible()
            local maxY = math.max(0, cy - wy)
            local y, s = 0, 0
            while y < maxY and s < 1000 do
                y = math.min(y + 10, maxY)
                scrollingFrame.CanvasPosition = Vector2.new(0, y)
                task.wait(0.15)
                collectVisible()
                s += 1
            end
            scrollingFrame.CanvasPosition = Vector2.new(0, maxY)
            task.wait(SCROLL_FINAL_WAIT)
            collectVisible()
        else
            collectVisible()
        end
        table.sort(list, function(a,b) return a.Number < b.Number end)
        local fruits = {}
        for _, t in ipairs(list) do if t.Text ~= "" then table.insert(fruits, t.Text) end end
        LOG("Inv", "собрано: " .. #fruits)
        return fruits
    end

    local function sendInventory(fruits)
        local url = SERVER_URL .. "/send_inventory?nickname=" .. HttpService:UrlEncode(player.Name)
            .. "&fruits=" .. HttpService:UrlEncode(table.concat(fruits, ","))
            .. "&job_id=" .. HttpService:UrlEncode(game.JobId)
        pcall(function() return game:HttpGet(url) end)
    end

    local function fetchConfig()
        local url = SERVER_URL .. "/get_config?nickname=" .. HttpService:UrlEncode(player.Name)
        local ok, response = pcall(function() return game:HttpGet(url) end)
        if not ok then return nil end
        local ok2, data = pcall(function() return HttpService:JSONDecode(response) end)
        if not ok2 then return nil end
        if data and data.partner_name then return data end
        return nil
    end

    local function formatItemName(n)
        local l = n:lower()
        local c = l:sub(1,1):upper() .. l:sub(2)
        return c .. "-" .. c
    end

    local function invokeLoadFruit(f)
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("LoadFruit", f) end)
    end

    local function respawn()
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("Humanoid")
        if h then pcall(function() h.Health = 0 end) end
    end

    local function waitRespawn()
        local old = player.Character
        local w = 0
        while w < 30 do
            if player.Character and player.Character ~= old then return end
            task.wait(0.5); w += 0.5
        end
    end

    local function processLoadFruit(items)
        if #items == 0 then return true end
        for _, item in ipairs(items) do
            invokeLoadFruit(formatItemName(item))
            respawn(); waitRespawn(); task.wait(1)
        end
        return true
    end

    local function findNthTabButton(ts, idx)
        local btn, cnt = nil, 0
        local function rec(p)
            if btn then return end
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("TextButton") or c:IsA("ImageButton") then
                    cnt += 1
                    if cnt == idx then btn = c; return end
                end
                rec(c)
            end
        end
        rec(ts)
        return btn
    end

    local function findNthOption(cont, idx)
        local btn, cnt = nil, 0
        for _, c in ipairs(cont:GetChildren()) do
            if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                cnt += 1
                if cnt == idx then btn = c; break end
            end
        end
        return btn
    end

    local function teleportToJobId(jobId)
        local root = getRoot() if not root then return false end
        local ts = safeFind(root, "Window","Components","TabsScroll")
        if not ts then return false end
        local tb = findNthTabButton(ts, TELEPORT_TAB)
        if not tb then return false end
        fireSequence(tb); task.wait(0.5)
        local cont = safeFind(root, "Window","Components","Containers","Container")
        if not cont then return false end
        local optText = findNthOption(cont, TELEPORT_OPT_TEXT)
        if not optText then return false end
        local function findTB(p)
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("TextBox") then return c end
                local f = findTB(c)
                if f then return f end
            end
        end
        local tx = findTB(optText)
        if not tx then return false end
        tx:CaptureFocus(); task.wait(0.2)
        tx.Text = jobId; task.wait(0.2)
        tx:ReleaseFocus(true); task.wait(0.3)
        local optAct = findNthOption(cont, TELEPORT_OPT_ACTIVATE)
        if not optAct then return false end
        fireSequence(optAct)
        return true
    end

    local function findTradeTable(expectedPartner)
        local tables = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "TradeTable" then table.insert(tables, obj) end
        end
        local free, partner = {}, {}
        for _, tbl in ipairs(tables) do
            local seats = {}
            for _, part in ipairs(tbl:GetDescendants()) do
                if part:IsA("Seat") or part:IsA("VehicleSeat") then table.insert(seats, part) end
            end
            if #seats >= 2 then
                local occ, freeSeats, occSeat = 0, {}, nil
                for _, s in ipairs(seats) do
                    if s.Occupant then occ += 1; occSeat = s else table.insert(freeSeats, s) end
                end
                if occ == 0 then
                    table.insert(free, {tbl = tbl, seat = freeSeats[1]})
                elseif occ == 1 then
                    local on = nil
                    if occSeat then
                        for _, pl in ipairs(Players:GetPlayers()) do
                            local c = pl.Character
                            if c then
                                local h = c:FindFirstChild("Humanoid")
                                if h and h.SeatPart == occSeat then on = pl.Name; break end
                            end
                        end
                    end
                    if expectedPartner ~= "" and on == expectedPartner then
                        table.insert(partner, {tbl = tbl, seat = freeSeats[1], on = on})
                    end
                end
            end
        end
        if #partner > 0 then return partner[1].tbl, partner[1].seat end
        if #free > 0 then return free[1].tbl, free[1].seat end
        return nil, nil
    end

    local function isSeated(seat)
        local c = player.Character
        if not c then return false end
        local h = c:FindFirstChild("Humanoid")
        if not h then return false end
        return h.Sit and h.SeatPart == seat
    end

    local function getPartnerName(tbl, mySeat)
        local seats = {}
        for _, part in ipairs(tbl:GetDescendants()) do
            if part:IsA("Seat") or part:IsA("VehicleSeat") then table.insert(seats, part) end
        end
        local other
        for _, s in ipairs(seats) do if s ~= mySeat then other = s; break end end
        if not other then return nil end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= player then
                local c = pl.Character
                if c then
                    local h = c:FindFirstChild("Humanoid")
                    if h and h.Sit and h.SeatPart == other then return pl.Name end
                end
            end
        end
        return nil
    end

    local function resetSeatAndWait(seat, sitTarget)
        local tries = 0
        while tries < 30 do
            tries += 1
            local c = player.Character
            if not c then return false end
            local h = c:FindFirstChild("Humanoid")
            if not h then return false end
            if isSeated(seat) then return true end
            if jumpAndReSeat(seat, sitTarget) then return true end
            task.wait(0.3)
        end
        return false
    end

    local addBtnPath      = {"Main","Trade","Container","1","Frame","AddButton"}
    local firstContPath   = {"Main","Trade","Container","FrameAdd","Frame"}
    local resultContPath  = {"Main","Trade","Container","1","Frame"}
    local secondContPath  = {"Main","Trade","Container","2","Frame"}
    local acceptPath      = {"Main","Trade","Info","Accept"}
    local ready1Path      = {"Main","Trade","Info","Ready1"}
    local bottomTitlePath = {"Main","Trade","BottomTitle"}

    local RESULT_TIMEOUT        = 30
    local MAX_ATTEMPTS_PER_ITEM = 3
    local READY_TIMEOUT         = 30
    local ACCEPT_CHECK_INTERVAL = 0.5
    local ACCEPT_WAIT_TIMEOUT   = 30

    local function findParentButton(obj)
        local cur = obj
        while cur do
            if cur:IsA("TextButton") or cur:IsA("ImageButton") then return cur end
            cur = cur.Parent
        end
    end

    local function findTextInContainer(cont, search)
        for _, obj in ipairs(cont:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then return obj end
            end
        end
    end

    local function findResultElement(search)
        local cont = findObjectByPath(playerGui, table.unpack(resultContPath))
        if not cont then return nil end
        for _, obj in ipairs(cont:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then
                    local p = obj.Parent
                    if p and p.Name == "Title" then return obj end
                end
            end
        end
    end

    local function waitForObject(path, t)
        local w = 0
        while w < t do
            local o = findObjectByPath(playerGui, table.unpack(path))
            if o then return o end
            task.wait(0.5); w += 0.5
        end
    end

    local function getPercent()
        local bt = findObjectByPath(playerGui, table.unpack(bottomTitlePath))
        if not bt then return nil end
        local p = bt.Text:match("(%d+)%%")
        return p and tonumber(p) or nil
    end

    local function checkSecondCont(items)
        local c = findObjectByPath(playerGui, table.unpack(secondContPath))
        if not c then return false end
        for _, item in ipairs(items) do
            if not findTextInContainer(c, item) then return false end
        end
        return true
    end

    local function isTradeCompleted()
        local n = playerGui:FindFirstChild("Notifications")
        if not n then return false end
        for _, obj in ipairs(n:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if obj.Text and obj.Text:lower():find("trade completed", 1, true) then return true end
            end
        end
        return false
    end

    local function processItem(search)
        if findResultElement(search) then return true end
        for att = 1, MAX_ATTEMPTS_PER_ITEM do
            local ab = findObjectByPath(playerGui, table.unpack(addBtnPath))
            if not ab then task.wait(2); continue end
            fireSequence(ab)
            local fc = waitForObject(firstContPath, 5)
            if not fc then task.wait(2); continue end
            local te = findTextInContainer(fc, search)
            if not te then task.wait(2); continue end
            local btn = findParentButton(te)
            if not btn then task.wait(2); continue end
            fireSequence(btn)
            local w = 0
            while w < RESULT_TIMEOUT do
                task.wait(0.5); w += 0.5
                if findResultElement(search) then return true end
            end
        end
        return false
    end

    local function waitPreAccept(items, seat)
        local w = 0
        while w < ACCEPT_WAIT_TIMEOUT do
            if not isSeated(seat) then return false end
            local p = getPercent()
            if p and p <= 40 and checkSecondCont(items) then return true end
            task.wait(ACCEPT_CHECK_INTERVAL); w += ACCEPT_CHECK_INTERVAL
        end
        return false
    end

    local function acceptAndWait(items, seat)
        if not isSeated(seat) then return false end
        if not waitPreAccept(items, seat) then return false end
        local ab = findObjectByPath(playerGui, table.unpack(acceptPath))
        if not ab then return false end
        fireSequence(ab)
        local w = 0
        local r1 = findObjectByPath(playerGui, table.unpack(ready1Path))
        while w < READY_TIMEOUT do
            task.wait(0.5); w += 0.5
            if not isSeated(seat) then return isTradeCompleted() end
            if isTradeCompleted() then return true end
            local tradeContainer = findObjectByPath(playerGui, "Main","Trade","Container")
            if not tradeContainer and w > 2 then return true end
            if r1 and r1:IsA("TextLabel") then
                if r1.Text == "Not ready." or r1.Text ~= "Ready!" then return false end
            end
        end
        return false
    end

    local function doTradeOnce(config)
        collisionsDisabledGlobal = true
        disableCollisionsNow()
        task.wait(0.3)

        LOG("Trade", "goTo TRADE_WAYPOINT")
        goToPosition(TRADE_WAYPOINT)
        task.wait(0.3)

        while State.running do
            local tbl, seat = findTradeTable(config.partner_name or "")
            if not tbl then
                LOG("Trade", "нет стола, ждём 5с")
                task.wait(5); continue
            end
            local sitTarget = seat.Position + Vector3.new(0, 3.5, 0)
            LOG("Trade", "стол найден")

            if not moveAndSitOnSeat(seat) then
                WARN("Trade", "не сел, другой стол")
                task.wait(2); continue
            end
            LOG("Trade", "СИЖУ")

            local function getOtherSeat(tbl_, mySeat)
                for _, part in ipairs(tbl_:GetDescendants()) do
                    if (part:IsA("Seat") or part:IsA("VehicleSeat")) and part ~= mySeat then
                        return part
                    end
                end
                return nil
            end

            local otherSeat = getOtherSeat(tbl, seat)

            while State.running do
                if not isSeated(seat) then
                    if not jumpAndReSeat(seat, sitTarget) then
                        task.wait(0.5)
                        if not isSeated(seat) then break end
                    end
                end

                if otherSeat and otherSeat.Occupant then
                    local otherHum = otherSeat.Occupant
                    local otherChar = otherHum and otherHum.Parent
                    local otherPlr = otherChar and Players:GetPlayerFromCharacter(otherChar)
                    local ep = config.partner_name or ""
                    if otherPlr and otherPlr ~= player and ep ~= "" and otherPlr.Name ~= ep then
                        jumpAndReSeat(seat, sitTarget)
                        task.wait(1)
                    end
                end

                local pn = getPartnerName(tbl, seat)
                local ep = config.partner_name or ""
                if pn == nil then
                    task.wait(0.2)
                elseif ep ~= "" and pn ~= ep then
                    jumpAndReSeat(seat, sitTarget)
                    task.wait(1)
                else
                    local ok = true
                    for _, item in ipairs(config.trade_items or {}) do
                        if not isSeated(seat) or not processItem(item) then ok = false; break end
                    end
                    if not ok then
                        if not resetSeatAndWait(seat, sitTarget) then break end
                    else
                        if acceptAndWait(config.load_fruit_items or {}, seat) then
                            LOG("Trade", "accept прошёл")
                            local c = player.Character
                            if c then
                                local h = c:FindFirstChild("Humanoid")
                                if h then pcall(function() h.Sit = false end) end
                            end
                            task.wait(0.15)
                            pcall(function()
                                game:HttpGet(SERVER_URL .. "/trade_completed?nickname=" .. HttpService:UrlEncode(player.Name))
                            end)
                            return true
                        else
                            if not resetSeatAndWait(seat, sitTarget) then break end
                        end
                    end
                end
            end
            break
        end
        return false
    end

    local function postTradeOnce()
        LOG("PostTrade", "=== START ===")

        LOG("PostTrade", "коллизии OFF")
        collisionsDisabledGlobal = true
        disableCollisionsNow()
        task.wait(0.5)

        LOG("PostTrade", "goTo POST_TRADE_WAYPOINT")
        goToPosition(POST_TRADE_WAYPOINT)
        task.wait(0.3)

        LOG("PostTrade", "коллизии ON")
        collisionsDisabledGlobal = false
        restoreCollisionsNow()
        task.wait(1.0)

        do
            local c = player.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = hrp.Position - POST_TRADE_WAYPOINT
                LOG("PostTrade", string.format(
                    "позиция (%.1f,%.1f,%.1f) Δ=(%.1f,%.1f,%.1f)",
                    hrp.Position.X, hrp.Position.Y, hrp.Position.Z,
                    d.X, d.Y, d.Z))
            end
        end

        if not RF_InteractDragonQuest then
            WARN("PostTrade", "нет RF/InteractDragonQuest")
            return "error"
        end

        local claimOk, claimResp = pcall(function()
            return RF_InteractDragonQuest:InvokeServer({NPC = POST_TRADE_NPC_NAME, Command = "ClaimQuest"})
        end)
        LOG("PostTrade", "ClaimQuest ok=" .. tostring(claimOk) .. " resp=" .. tostring(claimResp))

        if claimOk and claimResp ~= false and claimResp ~= nil then
            LOG("PostTrade", "=== CLAIMED ===")
            return "claimed"
        end

        local reqOk, reqResp = pcall(function()
            return RF_InteractDragonQuest:InvokeServer({NPC = POST_TRADE_NPC_NAME, Command = "RequestQuest"})
        end)

        local progress, goal, qname = nil, nil, nil
        if reqOk and type(reqResp) == "table" and type(reqResp.Quest) == "table" then
            local q = reqResp.Quest
            qname    = q.QuestName
            progress = q.Progress
            goal     = q.Goal
        end

        LOG("PostTrade", string.format(
            "Quest info: name=%s progress=%s goal=%s",
            tostring(qname), tostring(progress), tostring(goal)
        ))

        if type(progress) ~= "number" or type(goal) ~= "number" then
            WARN("PostTrade", "нет данных о квесте — считаем что трейд не прошёл")
            return "retry_trade"
        end

        if progress >= goal then
            task.wait(2)
            local ok2, resp2 = pcall(function()
                return RF_InteractDragonQuest:InvokeServer({NPC = POST_TRADE_NPC_NAME, Command = "ClaimQuest"})
            end)
            LOG("PostTrade", "ClaimQuest retry ok=" .. tostring(ok2) .. " resp=" .. tostring(resp2))
            if ok2 and resp2 ~= false and resp2 ~= nil then
                LOG("PostTrade", "=== CLAIMED (retry) ===")
                return "claimed"
            end
            WARN("PostTrade", "claim не сработал даже при готовом квесте — ре-трейд")
            return "retry_trade"
        else
            LOG("PostTrade", string.format("квест не выполнен (%d/%d) — ре-трейд", progress, goal))
            return "retry_trade"
        end
    end

    selectTeam()

    collisionsDisabledGlobal = true
    disableCollisionsNow()
    task.wait(0.3)

    local config = nil
    local att = 0
    while config == nil and State.running and att < 50 do
        att += 1
        local inv = collectInventory()
        if #inv > 0 then sendInventory(inv) else task.wait(SEND_INVENTORY_INTERVAL); continue end
        local w = 0
        while w < 120 do
            config = fetchConfig()
            if config then break end
            task.wait(CONFIG_POLL_INTERVAL); w += CONFIG_POLL_INTERVAL
        end
        if not config then task.wait(SEND_INVENTORY_INTERVAL) end
    end
    if not config then
        WARN("Trade", "не получили config — выход")
        State.beltScanPaused = false
        State.inTrade = false
        collisionsDisabledGlobal = false
        restoreCollisionsNow()
        return
    end

    local tele = config.teleport_to_job_id
    if tele and tele ~= "" and tele ~= game.JobId then
        for _ = 1, 5 do
            if teleportToJobId(tele) then
                local w = 0
                while w < 30 and game.JobId ~= tele do task.wait(1); w += 1 end
                if game.JobId == tele then break end
            end
            task.wait(2)
        end
        if game.JobId ~= tele then
            WARN("Trade", "телепорт не удался — выход")
            State.beltScanPaused = false
            State.inTrade = false
            collisionsDisabledGlobal = false
            restoreCollisionsNow()
            return
        end
    end

    processLoadFruit(config.load_fruit_items or {})

    local claimed = false
    while not claimed and State.running do
        LOG("Trade", "======== новая итерация трейд + пост-трейд ========")
        local tradeOk = doTradeOnce(config)
        if not tradeOk then
            LOG("Trade", "трейд прервался — выход")
            break
        end
        local result = postTradeOnce()
        if result == "claimed" then
            claimed = true
            break
        elseif result == "retry_trade" then
            LOG("Trade", "нужен ре-трейд — пауза 3с")
            task.wait(3)
        else
            WARN("Trade", "ошибка пост-трейда — пауза 5с")
            task.wait(5)
        end
    end

    LOG("Trade", "коллизии ON")
    collisionsDisabledGlobal = false
    restoreCollisionsNow()
    task.wait(0.3)

    State.beltScanPaused = false
    State.inTrade = false

    if claimed then
        State.tradeDone = true
        LOG("Trade", "=== DONE ===")
    else
        WARN("Trade", "выход без claimed")
    end
end

-- ============================================================
-- =======================  GREEN MODE  =======================
-- ============================================================

local function greenNoclip(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then d.CanCollide = false end
    end)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p:GetPropertyChangedSignal("CanCollide"):Connect(function()
                if p.CanCollide then p.CanCollide = false end
            end)
        end
    end
end

local function greenGetHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function greenIsOnSpot(targetPos, tol)
    tol = tol or GREEN_POS_TOLERANCE
    local hrp = greenGetHRP()
    if not hrp then return false, math.huge end
    local d = (hrp.Position - targetPos).Magnitude
    return d <= tol, d
end

local function greenSnapToSpot(targetPos, lookAtPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    greenNoclip(char)
    local lookDir
    if lookAtPos then
        lookDir = Vector3.new(lookAtPos.X - targetPos.X, 0, lookAtPos.Z - targetPos.Z)
    end
    if not lookDir or lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(0,0,1) end
    hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir.Unit)
    return true
end

local function goToAndFace(targetPos, lookAtPoint, speed)
    speed = speed or GREEN_MOVE_SPEED
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end

    greenNoclip(char)

    local startPos = hrp.Position
    local delta    = targetPos - startPos
    local dist     = delta.Magnitude

    local lookSrc = lookAtPoint or targetPos
    local lookDir = Vector3.new(lookSrc.X - targetPos.X, 0, lookSrc.Z - targetPos.Z)
    if lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(delta.X, 0, delta.Z) end
    if lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(0, 0, 1) end
    lookDir = lookDir.Unit

    if dist < 0.1 then
        hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir)
        return true
    end

    local duration = dist / speed
    local elapsed  = 0
    LOG("Green", string.format("идём за %.2fs к (%.1f,%.1f,%.1f)",
        duration, targetPos.X, targetPos.Y, targetPos.Z))

    while elapsed < duration and State.running do
        elapsed += RunService.Heartbeat:Wait()
        local a   = math.min(elapsed / duration, 1)
        local pos = startPos:Lerp(targetPos, a)
        hrp.CFrame = CFrame.lookAt(pos, pos + lookDir)
    end

    hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir)
    task.wait(0.05)
    local ok, d = greenIsOnSpot(targetPos)
    LOG("Green", string.format("встал на (%.1f,%.1f,%.1f) dist=%.2f onSpot=%s",
        hrp.Position.X, hrp.Position.Y, hrp.Position.Z, d, tostring(ok)))
    return ok
end

local function greenWaitPartnerNearby(partnerName, radius)
    radius = radius or PARTNER_NEAR_RADIUS
    local lastLog = 0
    local t0 = tick()
    while State.running do
        local myHrp = greenGetHRP()
        local partner = Players:FindFirstChild(partnerName)
        local partnerHrp = partner
            and partner.Character
            and partner.Character:FindFirstChild("HumanoidRootPart")
        if myHrp and partnerHrp then
            local d = (myHrp.Position - partnerHrp.Position).Magnitude
            if d <= radius then
                LOG("Wait", string.format("★ партнёр %s рядом (dist=%.1f ≤ %d)",
                    partnerName, d, radius))
                return true, d
            end
            if tick() - t0 - lastLog >= 5 then
                lastLog = tick() - t0
                LOG("Wait", string.format("жду партнёра %s... dist=%.1f (нужно ≤ %d)",
                    partnerName, d, radius))
            end
        else
            if tick() - t0 - lastLog >= 5 then
                lastLog = tick() - t0
                LOG("Wait", "жду партнёра... (персонаж не заспавнился)")
            end
        end
        task.wait(0.5)
    end
    return false, nil
end

local function greenRequestMatch()
    local url = SERVER_URL
        .. "/match?nickname=" .. HttpService:UrlEncode(player.Name)
        .. "&job_id="    .. HttpService:UrlEncode(game.JobId)
    local ok, resp = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil, "http fail: " .. tostring(resp) end
    local ok2, data = pcall(function() return HttpService:JSONDecode(resp) end)
    if not ok2 or type(data) ~= "table" then
        return nil, "bad json: " .. tostring(resp)
    end
    return data
end

local function greenRequestUnmatch()
    local url = SERVER_URL .. "/unmatch?nickname=" .. HttpService:UrlEncode(player.Name)
    pcall(function() return game:HttpGet(url) end)
end

local function greenFindFruitTool()
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    for _, cont in ipairs({char, backpack}) do
        if cont then
            for _, ch in ipairs(cont:GetChildren()) do
                if ch:IsA("Tool") and string.find(string.lower(ch.Name), "fruit", 1, true) then
                    return ch
                end
            end
        end
    end
    return nil
end

local function greenDumpInventory(tag)
    local char = player.Character
    local bp = player:FindFirstChild("Backpack")
    LOG(tag, "--- INVENTORY ---")
    if char then
        local any = false
        for _, ch in ipairs(char:GetChildren()) do
            if ch:IsA("Tool") then LOG(tag, "  [EQUIPPED] " .. ch.Name); any = true end
        end
        if not any then LOG(tag, "  [EQUIPPED] (пусто)") end
    end
    if bp then
        local any = false
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") then LOG(tag, "  [BACKPACK] " .. ch.Name); any = true end
        end
        if not any then LOG(tag, "  [BACKPACK] (пусто)") end
    end
    LOG(tag, "-----------------")
end

local function greenWaitFruitTool()
    local lastLog = 0
    local t0 = tick()
    while State.running do
        local t = greenFindFruitTool()
        if t then return t end
        if tick() - t0 - lastLog >= 5 then
            lastLog = tick() - t0
            LOG("Wait", string.format("жду fruit-tool... (%.0fs)", lastLog))
        end
        task.wait(0.2)
    end
    return nil
end

local function greenEatFruitDrop()
    local char = player.Character
    if not char then return false, "нет Character" end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false, "нет Humanoid" end
    local tool = greenFindFruitTool()
    if not tool then
        greenDumpInventory("eatFruitDrop")
        return false, "fruit-tool не найден"
    end
    LOG("Eat", "найден tool: " .. tool.Name .. " (parent=" .. tool.Parent.Name .. ")")
    if tool.Parent ~= char then
        hum:EquipTool(tool)
        task.wait(0.5)
    end
    if tool.Parent ~= char then return false, "не экипировалось: " .. tool.Name end
    LOG("Eat", "tool экипирован")
    local eatRemote = tool:FindFirstChild("EatRemote")
    if not eatRemote or not eatRemote:IsA("RemoteFunction") then
        return false, "нет EatRemote"
    end
    LOG("Eat", "вызываю EatRemote:InvokeServer(\"Drop\")")
    local ok, result = pcall(function()
        return eatRemote:InvokeServer("Drop")
    end)
    LOG("Eat", "ответ: ok=" .. tostring(ok) .. " result=" .. tostring(result))
    if not ok then return false, "eat error: " .. tostring(result) end
    return true, result
end

local function greenTryClaimQuest(myPos, tag)
    tag = tag or "Claim"
    if not RF_InteractDragonQuest then return false, "no RF" end
    if myPos then
        local ok, d = greenIsOnSpot(myPos)
        if not ok then
            WARN(tag, string.format("сдвинуло (dist=%.2f) — snap", d))
            greenSnapToSpot(myPos, nil); task.wait(0.1)
        end
    end
    LOG(tag, "отправляю ClaimQuest...")
    local sOk, resp = pcall(function()
        return RF_InteractDragonQuest:InvokeServer({
            NPC = POST_TRADE_NPC_NAME,
            Command = "ClaimQuest"
        })
    end)
    LOG(tag, "ответ: ok=" .. tostring(sOk) .. " resp=" .. tostring(resp))
    if not sOk then return false, resp end
    return true, resp
end

local function greenClaimLoop(myPos, tag)
    tag = tag or "Claim"
    local i = 0
    while State.running do
        i += 1
        LOG(tag, "=== попытка " .. i .. " ===")
        local ok, resp = greenTryClaimQuest(myPos, tag)
        if ok and resp == true then
            LOG(tag, "УСПЕХ на попытке " .. i)
            return true
        end
        if myPos then
            local onSpot = greenIsOnSpot(myPos)
            if not onSpot then greenSnapToSpot(myPos, nil) end
        end
        task.wait(CLAIM_RETRY_DELAY)
    end
    return false
end

local function runGreenMode()
    State.mode = "green"
    LOG("Green", "=== START ===")

    -- страховка: 6,1 должен быть OFF (диспетчер уже выключил)
    if getOptionState(TAB_MAIN, OPT_MAIN) == true then
        LOG("Green", "★ 6,1 внезапно ON — глушу (infinite)")
        ensureOptionOffInfinite(TAB_MAIN, OPT_MAIN)
    end

    -- матч
    local match = nil
    while State.running and not match do
        local data, err = greenRequestMatch()
        if not data then
            WARN("Green", "match error: " .. tostring(err)); task.wait(3)
        elseif data.waiting then
            LOG("Green", "waiting for partner..."); task.wait(3)
        else
            match = data
        end
    end
    if not match then State.mode = "none"; return end

    LOG("Green", "role=" .. tostring(match.role)
        .. " partner=" .. tostring(match.partner_name))
    LOG("Green", "match data: " .. HttpService:JSONEncode(match))

    if not waitForHubReady() then State.mode = "none"; return end

    -- guest телепорт
    if match.role == "guest"
       and match.job_id and match.job_id ~= ""
       and match.job_id ~= game.JobId then
        LOG("Green", "guest: телепорт на " .. tostring(match.job_id))
        local teleported = false
        while State.running and not teleported do
            if teleportToJobId(match.job_id) then
                local w = 0
                while w < 30 and game.JobId ~= match.job_id do
                    task.wait(1); w += 1
                end
                if game.JobId == match.job_id then
                    teleported = true
                    break
                end
            end
            LOG("Green", "guest: телепорт не удался, повтор"); task.wait(2)
        end
        LOG("Green", "guest: перелетели, ждём загрузку")
        task.wait(8)
        greenRequestMatch()
    end

    -- 6,1 проверка (без включения)
    LOG("Green", "★ проверяю (" .. TAB_TOGGLE .. "," .. OPT_TOGGLE .. ") — должно быть OFF")
    local st = getOptionState(TAB_TOGGLE, OPT_TOGGLE)
    LOG("Green", "  текущее: " .. tostring(st))
    if st == true then
        LOG("Green", "  выключаю (" .. TAB_TOGGLE .. "," .. OPT_TOGGLE .. ")")
        local okOff = ensureOptionOffInfinite(TAB_TOGGLE, OPT_TOGGLE)
        LOG("Green", "  ensureOptionOff = " .. tostring(okOff))
    else
        LOG("Green", "  уже OFF — ок")
    end

    local myPos, partnerPos
    if match.role == "host" then
        myPos, partnerPos = GREEN_HOST_POS, GREEN_GUEST_POS
    else
        myPos, partnerPos = GREEN_GUEST_POS, GREEN_HOST_POS
    end

    goToAndFace(myPos, partnerPos, GREEN_MOVE_SPEED)
    task.wait(0.3)
    do
        local ok, d = greenIsOnSpot(myPos)
        LOG("Green", string.format("после прилёта: dist=%.2f onSpot=%s", d, tostring(ok)))
        if not ok then greenSnapToSpot(myPos, partnerPos) end
    end

    LOG("Green", "★ жду партнёра в радиусе " .. PARTNER_NEAR_RADIUS .. " стадов...")
    greenWaitPartnerNearby(match.partner_name, PARTNER_NEAR_RADIUS)

    LOG("Green", "★ пауза " .. DELAY_AFTER_ARRIVE .. "с — оба на месте")
    task.wait(DELAY_AFTER_ARRIVE)

    if match.role == "host" then
        greenDumpInventory("host:before-8,7")
        LOG("Green", "host: 8,7 ON (оба на месте)")
        ensureOptionOnInfinite(TAB_FRUIT, OPT_FRUIT)
        LOG("Green", "host: жду fruit-tool...")
        local tool = greenWaitFruitTool()
        LOG("Green", "host: fruit появился = " .. tostring(tool and tool.Name))
        greenDumpInventory("host:after-8,7")
        LOG("Green", "host: 8,7 OFF")
        ensureOptionOffInfinite(TAB_FRUIT, OPT_FRUIT)
    else
        LOG("Green", "guest: 8,7 не трогаю")
    end

    local claimedMe = false

    if match.role == "host" then
        LOG("Green", "=== HOST PHASE ===")

        LOG("Green", "host: drop #1 (отдаю guest'у)")
        local ok1, err1 = greenEatFruitDrop()
        LOG("Green", "host: drop #1 = " .. tostring(ok1) .. " / " .. tostring(err1))
        greenDumpInventory("host:after-drop1")

        LOG("Green", "★ host: пауза " .. DELAY_AFTER_DROP .. "с после drop #1")
        task.wait(DELAY_AFTER_DROP)

        LOG("Green", "host: жду fruit обратно от guest'а...")
        local tool = greenWaitFruitTool()
        LOG("Green", "host: получил обратно = " .. tostring(tool and tool.Name))
        greenDumpInventory("host:after-receive1")

        LOG("Green", "★ host: пауза " .. DELAY_BEFORE_CLAIM .. "с перед ClaimQuest")
        task.wait(DELAY_BEFORE_CLAIM)
        claimedMe = greenClaimLoop(myPos, "Claim")

        LOG("Green", "★ host: пауза " .. DELAY_BEFORE_DROP2 .. "с перед drop #2")
        task.wait(DELAY_BEFORE_DROP2)

        LOG("Green", "host: drop #2 (отдаю guest'у для его ClaimQuest)")
        local ok2, err2 = greenEatFruitDrop()
        LOG("Green", "host: drop #2 = " .. tostring(ok2) .. " / " .. tostring(err2))
        greenDumpInventory("host:after-drop2")

        LOG("Green", "★ host: жду " .. DELAY_AFTER_CLAIM .. "с пока guest сделает ClaimQuest")
        task.wait(DELAY_AFTER_CLAIM)

        -- ★ 6,1 НЕ включаем — оставляем OFF
        LOG("Green", "★ host: ВСЁ СДЕЛАНО (6,1 остаётся OFF)")
    else
        LOG("Green", "=== GUEST PHASE ===")

        LOG("Green", "guest: жду fruit #1 от host'а...")
        local tool1 = greenWaitFruitTool()
        LOG("Green", "guest: получил #1 = " .. tostring(tool1 and tool1.Name))
        greenDumpInventory("guest:after-receive1")

        LOG("Green", "★ guest: пауза " .. DELAY_AFTER_DROP .. "с")
        task.wait(DELAY_AFTER_DROP)

        LOG("Green", "guest: drop #1 (возвращаю host'у)")
        local ok1, err1 = greenEatFruitDrop()
        LOG("Green", "guest: drop #1 = " .. tostring(ok1) .. " / " .. tostring(err1))
        greenDumpInventory("guest:after-drop1")

        LOG("Green", "★ guest: пауза " .. DELAY_AFTER_DROP .. "с после drop #1")
        task.wait(DELAY_AFTER_DROP)

        LOG("Green", "guest: жду fruit #2 от host'а...")
        local tool2 = greenWaitFruitTool()
        LOG("Green", "guest: получил #2 = " .. tostring(tool2 and tool2.Name))
        greenDumpInventory("guest:after-receive2")

        LOG("Green", "★ guest: пауза " .. DELAY_BEFORE_CLAIM .. "с перед ClaimQuest")
        task.wait(DELAY_BEFORE_CLAIM)
        local guestClaimed = greenClaimLoop(myPos, "ClaimGuest")
        LOG("Green", "guest: ClaimQuest = " .. tostring(guestClaimed))

        -- ★ 6,1 НЕ включаем — оставляем OFF
        LOG("Green", "★ guest: ВСЁ СДЕЛАНО (6,1 остаётся OFF)")
    end

    LOG("Green", "=== DONE claimed=" .. tostring(claimedMe) .. " ===")
    greenRequestUnmatch()
    State.greenDone = true
    State.mode = "none"
end

-- ============================================================
-- ГЛАВНЫЙ ДИСПЕТЧЕР
-- ============================================================
LOG("Main", "=== START === Me: " .. player.Name)

LOG("Main", "жду готовности хаба (бесконечно)...")
waitForHubReady()

local waitStart = tick()
while State.currentBelt == "Unknown" and tick() - waitStart < 90 do task.wait(1) end
LOG("Main", "belt = " .. State.currentBelt)

local loop = 0
while State.running do
    loop += 1
    LOG("Main", "---- цикл #" .. loop .. " belt=" .. State.currentBelt .. " ----")

    local belt = State.currentBelt

    if belt == "Yellow" and not State.tradeDone then
        if getOptionState(TAB_MAIN, OPT_MAIN) == true then
            setOption(TAB_MAIN, OPT_MAIN, false)
            task.wait(0.5)
        end
        runTradeMode()
    elseif belt == "Green" then
        -- ★ 6,1 гасим СРАЗУ при детекте green
        LOG("Main", "★ GREEN DETECTED — выключаю 6,1 немедленно")
        if getOptionState(TAB_MAIN, OPT_MAIN) == true then
            setOption(TAB_MAIN, OPT_MAIN, false)
            task.wait(0.5)
        end
        if getOptionState(TAB_MAIN, OPT_MAIN) == true then
            ensureOptionOffInfinite(TAB_MAIN, OPT_MAIN)
        end
        LOG("Main", "★ 6,1 OFF, стартую green")

        if not State.greenDone then
            runGreenMode()
        else
            task.wait(5)
        end
    elseif belt == "None" or belt == "Unknown" then
        if not State.nobeltDone then
            runNoBeltMode()
        else
            runHoldSixOne()
        end
    else
        runHoldSixOne()
    end
    task.wait(3)
end
