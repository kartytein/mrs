--!nocheck
-- ============================================================
-- COMBINED: GREEN MODE -> AUTO-TRADE
-- В green-режиме 6,1 принудительно OFF (без авто-возврата).
-- После выхода из green 6,1 остаётся выключенным (можно вернуть вручную).
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
-- CONFIG
-- ============================================================
local SERVER_URL = "http://192.168.31.179:8000"

-- Green mode
local POST_TRADE_NPC_NAME  = "Dojo Trainer"
local GREEN_HOST_POS       = Vector3.new(5842.3, 1208.6, 886.3)
local GREEN_GUEST_POS      = Vector3.new(5847.1, 1208.6, 882.4)
local MOVE_SPEED           = 250
local POS_TOLERANCE        = 8
local PARTNER_NEAR_RADIUS  = 30
local CLAIM_RETRY_DELAY    = 2
local DELAY_AFTER_ARRIVE   = 2
local DELAY_AFTER_DROP     = 2
local DELAY_BEFORE_CLAIM   = 5
local DELAY_AFTER_CLAIM    = 5
local DELAY_BEFORE_DROP2   = 2

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local TAB_FRUIT, OPT_FRUIT   = 8, 7
local TAB_TOGGLE, OPT_TOGGLE = 6, 1
local TELEPORT_TAB           = 19
local TELEPORT_OPT_TEXT      = 2
local TELEPORT_OPT_ACTIVATE  = 3

-- Trade mode
local SEND_INVENTORY_INTERVAL = 20
local CONFIG_POLL_INTERVAL    = 10
local MOVE_TIMEOUT            = 30
local ARRIVE_DISTANCE         = 5
local MAX_RESIT_ATTEMPTS      = 10

-- ============================================================
-- LOGGER
-- ============================================================
local T0 = tick()
local function LOG(tag, msg)  print(string.format("[%7.2fs][%s] %s", tick() - T0, tag, msg)) end
local function WARN(tag, msg) warn(string.format("[%7.2fs][%s] %s", tick() - T0, tag, msg)) end

local State = { running = true, mode = "none" }

-- ============================================================
-- SHARED HELPERS
-- ============================================================
local function fireSequence(btn)
    if not btn then return end
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then pcall(conn.Function) end
            end
        end
    end
end

local function findObjectByPath(root, ...)
    local current = root
    for _, segment in ipairs({...}) do
        if not current then return nil end
        current = current:FindFirstChild(segment)
    end
    return current
end

local function waitForObjectByPath(pathTable, timeout, description)
    local waited = 0
    while waited < timeout do
        local obj = findObjectByPath(playerGui, table.unpack(pathTable))
        if obj then return obj end
        task.wait(0.5); waited += 0.5
    end
    WARN("Wait", "Не найден за " .. timeout .. "с: " .. (description or "?"))
    return nil
end

-- RF
local RF_InteractDragonQuest = nil
do
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local net = modules:FindFirstChild("Net")
        if net then RF_InteractDragonQuest = net:FindFirstChild("RF/InteractDragonQuest") end
    end
end

-- ============================================================
-- HUB (green)
-- ============================================================
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
end
local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end
local function waitForInterface()
    return getRoot() and safeFind(getRoot(), "Window", "Components", "TabsScroll")
end
local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local c = tostring(child.BackgroundColor3)
            if c == COLOR_ON or c == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child)
        if found then return found end
    end
end
local function getOptionState(tabIndex, optIndex)
    local root = getRoot() if not root then return nil end
    local ts = safeFind(root, "Window", "Components", "TabsScroll")
    if not ts then return nil end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == tabIndex then tabButton = c; return end
            end
            findTab(c)
        end
    end
    findTab(ts)
    if not tabButton then return nil end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == optIndex then optionBtn = c; break end
        end
    end
    if not optionBtn then return nil end
    local ind = findIndicatorFrame(optionBtn)
    if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    if col == COLOR_ON then return "on" end
    if col == COLOR_OFF then return "off" end
    return nil
end
local function setOptionState(tabIndex, optIndex, desiredState)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot() if not root then return false end
    local ts = safeFind(root, "Window", "Components", "TabsScroll")
    if not ts then return false end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == tabIndex then tabButton = c; return end
            end
            findTab(c)
        end
    end
    findTab(ts)
    if not tabButton then return false end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return false end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == optIndex then optionBtn = c; break end
        end
    end
    if not optionBtn then return false end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return false end
    local isOn   = (tostring(indicator.BackgroundColor3) == COLOR_ON)
    local wantOn = (desiredState == "on")
    if isOn == wantOn then return true end
    fireSequence(optionBtn) task.wait(0.1)
    return true
end
local function ensureOptionOn(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == "on" then return true end
        setOptionState(tabIndex, optIndex, "on")
        task.wait(0.4)
    end
    return false
end
local function ensureOptionOff(tabIndex, optIndex)
    while State.running do
        if getOptionState(tabIndex, optIndex) == "off" then return true end
        setOptionState(tabIndex, optIndex, "off")
        task.wait(0.4)
    end
    return false
end
local function waitForHubReady()
    while State.running and not waitForInterface() do task.wait(0.5) end
    LOG("Hub", "готов")
    return true
end

-- Teleport
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

-- Noclip (оставляем включённым на всё время сессии)
local noclipEnabled = true
local function enableNoclip(char)
    if not char or not noclipEnabled then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    char.DescendantAdded:Connect(function(d)
        if noclipEnabled and d:IsA("BasePart") then d.CanCollide = false end
    end)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p:GetPropertyChangedSignal("CanCollide"):Connect(function()
                if noclipEnabled and p.CanCollide then p.CanCollide = false end
            end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end
end
player.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    enableNoclip(char)
end)

-- Position / movement
local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function isOnSpot(targetPos, tol)
    tol = tol or POS_TOLERANCE
    local hrp = getHRP()
    if not hrp then return false, math.huge end
    local d = (hrp.Position - targetPos).Magnitude
    return d <= tol, d
end
local function snapToSpot(targetPos, lookAtPos)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    enableNoclip(char)
    local lookDir
    if lookAtPos then
        lookDir = Vector3.new(lookAtPos.X - targetPos.X, 0, lookAtPos.Z - targetPos.Z)
    end
    if not lookDir or lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(0,0,1) end
    hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir.Unit)
    return true
end
local function goToAndFace(targetPos, lookAtPoint, speed)
    speed = speed or MOVE_SPEED
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    enableNoclip(char)

    local startPos = hrp.Position
    local delta    = targetPos - startPos
    local dist     = delta.Magnitude
    local lookSrc  = lookAtPoint or targetPos
    local lookDir  = Vector3.new(lookSrc.X - targetPos.X, 0, lookSrc.Z - targetPos.Z)
    if lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(delta.X, 0, delta.Z) end
    if lookDir.Magnitude < 1e-4 then lookDir = Vector3.new(0, 0, 1) end
    lookDir = lookDir.Unit

    if dist < 0.1 then
        hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir)
        return true
    end

    local duration = dist / speed
    local elapsed  = 0
    LOG("Green", string.format("идём %.2fs к (%.1f,%.1f,%.1f)", duration, targetPos.X, targetPos.Y, targetPos.Z))

    while elapsed < duration do
        elapsed += RunService.Heartbeat:Wait()
        local a   = math.min(elapsed / duration, 1)
        local pos = startPos:Lerp(targetPos, a)
        hrp.CFrame = CFrame.lookAt(pos, pos + lookDir)
    end
    hrp.CFrame = CFrame.lookAt(targetPos, targetPos + lookDir)
    task.wait(0.05)
    local ok, d = isOnSpot(targetPos)
    LOG("Green", string.format("встал (%.1f,%.1f,%.1f) dist=%.2f on=%s",
        hrp.Position.X, hrp.Position.Y, hrp.Position.Z, d, tostring(ok)))
    return ok
end

local function waitPartnerNearby(partnerName, radius)
    radius = radius or PARTNER_NEAR_RADIUS
    local lastLog = 0
    local t0 = tick()
    while State.running do
        local myHrp = getHRP()
        local partner = Players:FindFirstChild(partnerName)
        local partnerHrp = partner and partner.Character and partner.Character:FindFirstChild("HumanoidRootPart")
        if myHrp and partnerHrp then
            local d = (myHrp.Position - partnerHrp.Position).Magnitude
            if d <= radius then
                LOG("Wait", string.format("★ партнёр %s рядом (dist=%.1f ≤ %d)", partnerName, d, radius))
                return true, d
            end
            if tick() - t0 - lastLog >= 5 then
                lastLog = tick() - t0
                LOG("Wait", string.format("жду %s... dist=%.1f", partnerName, d))
            end
        else
            if tick() - t0 - lastLog >= 5 then
                lastLog = tick() - t0
                LOG("Wait", "жду партнёра... (не заспавнился)")
            end
        end
        task.wait(0.5)
    end
    return false, nil
end

-- HTTP (green)
local function requestMatch()
    local url = SERVER_URL
        .. "/match?nickname=" .. HttpService:UrlEncode(player.Name)
        .. "&job_id="    .. HttpService:UrlEncode(game.JobId)
    local ok, resp = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil, "http fail: " .. tostring(resp) end
    local ok2, data = pcall(function() return HttpService:JSONDecode(resp) end)
    if not ok2 or type(data) ~= "table" then return nil, "bad json: " .. tostring(resp) end
    return data
end
local function requestUnmatch()
    local url = SERVER_URL .. "/unmatch?nickname=" .. HttpService:UrlEncode(player.Name)
    pcall(function() return game:HttpGet(url) end)
end

-- Fruit tools (green)
local function findFruitTool()
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
local function dumpInventory(tag)
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
local function waitFruitTool()
    local lastLog = 0
    local t0 = tick()
    while State.running do
        local t = findFruitTool()
        if t then return t end
        if tick() - t0 - lastLog >= 5 then
            lastLog = tick() - t0
            LOG("Wait", string.format("жду fruit-tool... (%.0fs)", lastLog))
        end
        task.wait(0.2)
    end
    return nil
end
local function eatFruitDrop()
    local char = player.Character
    if not char then return false, "нет Character" end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false, "нет Humanoid" end
    local tool = findFruitTool()
    if not tool then dumpInventory("eatFruitDrop"); return false, "fruit-tool не найден" end
    LOG("Eat", "tool: " .. tool.Name .. " (parent=" .. tool.Parent.Name .. ")")
    if tool.Parent ~= char then
        hum:EquipTool(tool); task.wait(0.5)
    end
    if tool.Parent ~= char then return false, "не экипировалось" end
    local eatRemote = tool:FindFirstChild("EatRemote")
    if not eatRemote or not eatRemote:IsA("RemoteFunction") then return false, "нет EatRemote" end
    local ok, result = pcall(function() return eatRemote:InvokeServer("Drop") end)
    LOG("Eat", "ok=" .. tostring(ok) .. " result=" .. tostring(result))
    if not ok then return false, "eat error: " .. tostring(result) end
    return true, result
end

-- Claim quest
local function tryClaimQuest(myPos, tag)
    tag = tag or "Claim"
    if not RF_InteractDragonQuest then return false, "no RF" end
    if myPos then
        local ok, d = isOnSpot(myPos)
        if not ok then
            WARN(tag, string.format("сдвинуло (dist=%.2f) — snap", d))
            snapToSpot(myPos, nil); task.wait(0.1)
        end
    end
    LOG(tag, "ClaimQuest...")
    local sOk, resp = pcall(function()
        return RF_InteractDragonQuest:InvokeServer({ NPC = POST_TRADE_NPC_NAME, Command = "ClaimQuest" })
    end)
    LOG(tag, "ok=" .. tostring(sOk) .. " resp=" .. tostring(resp))
    if not sOk then return false, resp end
    return true, resp
end
local function claimLoop(myPos, tag)
    tag = tag or "Claim"
    local i = 0
    while State.running do
        i += 1
        LOG(tag, "=== попытка " .. i .. " ===")
        local ok, resp = tryClaimQuest(myPos, tag)
        if ok and resp == true then LOG(tag, "УСПЕХ #" .. i); return true end
        if myPos and not isOnSpot(myPos) then snapToSpot(myPos, nil) end
        task.wait(CLAIM_RETRY_DELAY)
    end
    return false
end

-- ============================================================
-- GREEN MODE
-- ============================================================
local function runGreenMode()
    State.mode = "green"
    LOG("Green", "=== START ===")

    local match = nil
    while State.running and not match do
        local data, err = requestMatch()
        if not data then WARN("Green", "match error: " .. tostring(err)); task.wait(3)
        elseif data.waiting then LOG("Green", "waiting for partner..."); task.wait(3)
        else match = data end
    end
    if not match then State.mode = "none"; return end

    LOG("Green", "role=" .. tostring(match.role) .. " partner=" .. tostring(match.partner_name))

    if not waitForHubReady() then State.mode = "none"; return end

    -- Guest teleport
    if match.role == "guest" and match.job_id and match.job_id ~= "" and match.job_id ~= game.JobId then
        LOG("Green", "guest: телепорт на " .. tostring(match.job_id))
        local teleported = false
        while State.running and not teleported do
            if teleportToJobId(match.job_id) then
                local w = 0
                while w < 30 and game.JobId ~= match.job_id do task.wait(1); w += 1 end
                if game.JobId == match.job_id then teleported = true; break end
            end
            LOG("Green", "телепорт не удался, повтор"); task.wait(2)
        end
        task.wait(8)
        requestMatch()
    end

    -- ★ 6,1 OFF — единственное место, где мы трогаем 6,1 (без возврата)
    LOG("Green", "★ 6,1 → OFF (без авто-восстановления)")
    if getOptionState(TAB_TOGGLE, OPT_TOGGLE) ~= "off" then
        ensureOptionOff(TAB_TOGGLE, OPT_TOGGLE)
    end

    local myPos, partnerPos
    if match.role == "host" then
        myPos, partnerPos = GREEN_HOST_POS, GREEN_GUEST_POS
    else
        myPos, partnerPos = GREEN_GUEST_POS, GREEN_HOST_POS
    end

    goToAndFace(myPos, partnerPos, MOVE_SPEED)
    task.wait(0.3)
    do
        local ok, d = isOnSpot(myPos)
        LOG("Green", string.format("после прилёта dist=%.2f on=%s", d, tostring(ok)))
        if not ok then snapToSpot(myPos, partnerPos) end
    end

    LOG("Green", "★ жду партнёра в радиусе " .. PARTNER_NEAR_RADIUS)
    waitPartnerNearby(match.partner_name, PARTNER_NEAR_RADIUS)

    task.wait(DELAY_AFTER_ARRIVE)

    if match.role == "host" then
        dumpInventory("host:before-8,7")
        LOG("Green", "host: 8,7 ON")
        ensureOptionOn(TAB_FRUIT, OPT_FRUIT)
        local tool = waitFruitTool()
        LOG("Green", "host: fruit = " .. tostring(tool and tool.Name))
        dumpInventory("host:after-8,7")
        LOG("Green", "host: 8,7 OFF")
        ensureOptionOff(TAB_FRUIT, OPT_FRUIT)
    else
        LOG("Green", "guest: 8,7 не трогаю")
    end

    local claimedMe = false

    if match.role == "host" then
        LOG("Green", "=== HOST PHASE ===")
        LOG("Green", "host: drop #1")
        local ok1, err1 = eatFruitDrop()
        LOG("Green", "host: drop #1 = " .. tostring(ok1) .. " / " .. tostring(err1))
        dumpInventory("host:after-drop1")
        task.wait(DELAY_AFTER_DROP)

        LOG("Green", "host: жду fruit обратно...")
        local tool = waitFruitTool()
        LOG("Green", "host: обратно = " .. tostring(tool and tool.Name))
        dumpInventory("host:after-receive1")

        task.wait(DELAY_BEFORE_CLAIM)
        claimedMe = claimLoop(myPos, "Claim")

        task.wait(DELAY_BEFORE_DROP2)
        LOG("Green", "host: drop #2")
        local ok2, err2 = eatFruitDrop()
        LOG("Green", "host: drop #2 = " .. tostring(ok2) .. " / " .. tostring(err2))
        dumpInventory("host:after-drop2")

        task.wait(DELAY_AFTER_CLAIM)
        LOG("Green", "★ host: done (6,1 оставлен OFF)")
    else
        LOG("Green", "=== GUEST PHASE ===")
        LOG("Green", "guest: жду fruit #1...")
        local tool1 = waitFruitTool()
        LOG("Green", "guest: #1 = " .. tostring(tool1 and tool1.Name))
        dumpInventory("guest:after-receive1")

        task.wait(DELAY_AFTER_DROP)
        LOG("Green", "guest: drop #1")
        local ok1, err1 = eatFruitDrop()
        LOG("Green", "guest: drop #1 = " .. tostring(ok1) .. " / " .. tostring(err1))
        dumpInventory("guest:after-drop1")

        task.wait(DELAY_AFTER_DROP)
        LOG("Green", "guest: жду fruit #2...")
        local tool2 = waitFruitTool()
        LOG("Green", "guest: #2 = " .. tostring(tool2 and tool2.Name))
        dumpInventory("guest:after-receive2")

        task.wait(DELAY_BEFORE_CLAIM)
        local guestClaimed = claimLoop(myPos, "ClaimGuest")
        LOG("Green", "guest: ClaimQuest = " .. tostring(guestClaimed))

        LOG("Green", "★ guest: done (6,1 оставлен OFF)")
    end

    LOG("Green", "=== DONE claimed=" .. tostring(claimedMe) .. " ===")
    requestUnmatch()
    State.mode = "none"
end

-- ============================================================
-- TRADE MODE
-- ============================================================
local function selectTeam()
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then error("Remotes не найдены") end
        local commF = remotes:FindFirstChild("CommF_")
        if not commF then error("CommF_ не найден") end
        commF:InvokeServer("SetTeam", "Marines")
        LOG("Trade", "Команда Marines выбрана")
    end)
    task.wait(3)
end

local function collectInventory()
    LOG("Trade", "Открываю инвентарь...")
    local menuButton = waitForObjectByPath({"Main", "MenuButton"}, 10, "MenuButton")
    if not menuButton then return {} end
    fireSequence(menuButton); task.wait(1)

    local inventoryButton = waitForObjectByPath({"Main", "InventoryButton"}, 10, "InventoryButton")
    if not inventoryButton then return {} end
    fireSequence(inventoryButton); task.wait(1)

    local category2 = waitForObjectByPath(
        {"Inventory", "Inventory", "Main", "NavigationRail", "HoverBox", "UpperBar", "Category2"},
        15, "Category2")
    if not category2 then return {} end
    fireSequence(category2); task.wait(2)

    local tileGrid = waitForObjectByPath({"Inventory", "Inventory", "Main", "PageContent", "TileGrid"}, 10, "TileGrid")
    if not tileGrid then return {} end

    local fruits = {}
    for _, child in ipairs(tileGrid:GetChildren()) do
        if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
            local line1 = nil
            local details = child:FindFirstChild("Details")
            if details then line1 = details:FindFirstChild("Line-1") end
            if not line1 then
                for _, obj in ipairs(child:GetDescendants()) do
                    if obj:IsA("TextLabel") then line1 = obj; break end
                end
            end
            local text = ""
            if line1 and line1:IsA("TextLabel") then text = line1.Text end
            if text and text:find(",") then text = text:sub(1, text:find(",") - 1) end
            text = text:gsub("%s+$", "")
            if text ~= "" then table.insert(fruits, text) end
        end
    end
    LOG("Trade", "Инвентарь: " .. table.concat(fruits, ","))
    return fruits
end

local function sendInventory(fruits)
    local fruitsStr = table.concat(fruits, ",")
    local url = SERVER_URL .. "/send_inventory?nickname=" .. HttpService:UrlEncode(player.Name)
        .. "&fruits=" .. HttpService:UrlEncode(fruitsStr)
        .. "&job_id=" .. HttpService:UrlEncode(game.JobId)
    local success, result = pcall(function() return game:HttpGet(url) end)
    if success then LOG("Trade", "Инвентарь отправлен: " .. tostring(result))
    else WARN("Trade", "Ошибка отправки: " .. tostring(result)) end
end

local function fetchConfig()
    local url = SERVER_URL .. "/get_config?nickname=" .. HttpService:UrlEncode(player.Name)
    local success, response = pcall(function() return game:HttpGet(url) end)
    if not success then WARN("Trade", "Ошибка запроса: " .. tostring(response)); return nil end
    local data = HttpService:JSONDecode(response)
    if data and data.partner_name then LOG("Trade", "Конфиг получен"); return data
    elseif data and data.error then LOG("Trade", "Сервер: " .. tostring(data.error)); return nil
    else LOG("Trade", "Конфиг не готов"); return nil end
end

local function formatItemName(name)
    local lower = name:lower()
    local cap = lower:sub(1, 1):upper() .. lower:sub(2)
    return cap .. "-" .. cap
end

local function invokeLoadFruit(fruitName)
    local success, result = pcall(function()
        return ReplicatedStorage.Remotes.CommF_:InvokeServer("LoadFruit", fruitName)
    end)
    if success then LOG("Trade", "[OK] LoadFruit " .. fruitName .. " -> " .. tostring(result))
    else WARN("Trade", "[ERR] LoadFruit " .. fruitName .. " -> " .. tostring(result)) end
end

local function respawnCharacter()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    pcall(function() hum.Health = 0 end)
    return true
end

local function waitForCharacterRespawn()
    local oldChar = player.Character
    local waited = 0
    while waited < 30 do
        local char = player.Character
        if char and char ~= oldChar then return char end
        task.wait(0.5); waited += 0.5
    end
    return nil
end

local function processLoadFruit(loadFruitItems)
    if #loadFruitItems == 0 then LOG("Trade", "LoadFruit пуст"); return true end
    for _, item in ipairs(loadFruitItems) do
        local formatted = formatItemName(item)
        LOG("Trade", "LoadFruit: " .. item .. " -> " .. formatted)
        invokeLoadFruit(formatted)
        respawnCharacter()
        waitForCharacterRespawn()
        task.wait(1)
    end
    return true
end

local function findTradeTable(expectedPartnerName)
    local tradeTables = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "TradeTable" then
            table.insert(tradeTables, obj)
        end
    end

    local fullyFree, partiallyOccupied, withPartner = {}, {}, {}

    for _, tradeTable in ipairs(tradeTables) do
        local seats = {}
        for _, part in ipairs(tradeTable:GetDescendants()) do
            if part:IsA("Seat") or part:IsA("VehicleSeat") then
                table.insert(seats, part)
            end
        end
        if #seats >= 2 then
            local occupiedCount = 0
            local freeSeats, occupiedSeat = {}, nil
            for _, seat in ipairs(seats) do
                if seat.Occupant then
                    occupiedCount += 1; occupiedSeat = seat
                else
                    table.insert(freeSeats, seat)
                end
            end
            if occupiedCount == 0 then
                table.insert(fullyFree, {tradeTable = tradeTable, freeSeat = freeSeats[1], wasFullyFree = true})
            elseif occupiedCount == 1 then
                local occupantName = nil
                if occupiedSeat and occupiedSeat.Occupant then
                    local oh = occupiedSeat.Occupant
                    if oh:IsA("Humanoid") then
                        local character = oh.Parent
                        if character then
                            local plr = Players:GetPlayerFromCharacter(character)
                            if plr then occupantName = plr.Name end
                        end
                    end
                end
                local entry = {tradeTable = tradeTable, freeSeat = freeSeats[1],
                               wasFullyFree = false, occupantName = occupantName}
                if expectedPartnerName ~= "" and occupantName
                   and string.lower(occupantName) == string.lower(expectedPartnerName) then
                    table.insert(withPartner, entry)
                else
                    table.insert(partiallyOccupied, entry)
                end
            end
        end
    end

    if #withPartner > 0 then return withPartner[1].tradeTable, withPartner[1].freeSeat, false end
    if #fullyFree > 0 then return fullyFree[1].tradeTable, fullyFree[1].freeSeat, true end
    if #partiallyOccupied > 0 then return partiallyOccupied[1].tradeTable, partiallyOccupied[1].freeSeat, false end
    return nil, nil, nil
end

local function moveToPositionWithJump(targetPosition)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")
    local rootPart  = character:WaitForChild("HumanoidRootPart")

    humanoid:MoveTo(targetPosition)

    local isMoving = true
    local stuckCoroutine = task.spawn(function()
        local lastPosition, stuckSeconds = rootPart.Position, 0
        while isMoving do
            task.wait(1)
            local currentPosition   = rootPart.Position
            local distanceMoved     = (currentPosition - lastPosition).Magnitude
            local distanceToTarget  = (currentPosition - targetPosition).Magnitude
            if distanceToTarget < ARRIVE_DISTANCE then break end
            if distanceMoved < 1 then
                stuckSeconds += 1
                if stuckSeconds >= 2 then humanoid.Jump = true; stuckSeconds = 0 end
            else
                stuckSeconds = 0
            end
            lastPosition = currentPosition
        end
    end)

    local waited = 0
    while waited < MOVE_TIMEOUT do
        if (rootPart.Position - targetPosition).Magnitude < ARRIVE_DISTANCE then
            isMoving = false; task.cancel(stuckCoroutine); return true
        end
        task.wait(0.5); waited += 0.5
    end
    isMoving = false; task.cancel(stuckCoroutine); return false
end

local function waitForSeat(seatPart, timeout)
    local waited = 0
    while waited < timeout do
        local char = player.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Sit and hum.SeatPart == seatPart then return true end
        end
        task.wait(0.5); waited += 0.5
    end
    return false
end

local function isSeated(mySeat)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    return hum.Sit and hum.SeatPart == mySeat
end

local function getPartnerName(tradeTable, mySeat)
    local seats = {}
    for _, part in ipairs(tradeTable:GetDescendants()) do
        if part:IsA("Seat") or part:IsA("VehicleSeat") then
            table.insert(seats, part)
        end
    end
    local otherSeat
    for _, seat in ipairs(seats) do
        if seat ~= mySeat then otherSeat = seat; break end
    end
    if not otherSeat then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Sit and hum.SeatPart == otherSeat then return plr.Name end
            end
        end
    end
    return nil
end

local function resetSeatAndWait(mySeat, targetPos)
    LOG("Trade", "Пересадка...")
    local attempt = 0
    while attempt < MAX_RESIT_ATTEMPTS do
        attempt += 1
        local char = player.Character
        if not char then WARN("Trade", "Персонаж исчез"); return false end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then WARN("Trade", "Humanoid нет"); return false end
        if isSeated(mySeat) then return true end

        pcall(function() hum.Sit = false end)
        task.wait(0.2)
        hum.Jump = true
        task.wait(0.2)

        for i = 1, 5 do
            if isSeated(mySeat) then return true end
            local direction = math.random(1,2) == 1 and 1 or -1
            local offsetDistance = math.random(3, 6)
            local offset = Vector3.new(direction * offsetDistance, 0, 0)
            hum:MoveTo(targetPos + offset); task.wait(0.3)
            hum:MoveTo(targetPos);          task.wait(0.3)
            for _ = 1, 5 do
                if isSeated(mySeat) then return true end
                task.wait(0.2)
            end
        end
        LOG("Trade", "Не сел после попытки " .. attempt)
    end
    WARN("Trade", "Лимит пересадок")
    return false
end

-- Auto-trade
local addButtonPath       = {"Main", "Trade", "Container", "1", "Frame", "AddButton"}
local firstContainerPath  = {"Main", "Trade", "Container", "FrameAdd", "Frame"}
local resultContainerPath = {"Main", "Trade", "Container", "1", "Frame"}
local secondContainerPath = {"Main", "Trade", "Container", "2", "Frame"}
local acceptPath          = {"Main", "Trade", "Info", "Accept"}
local ready1Path          = {"Main", "Trade", "Info", "Ready1"}
local bottomTitlePath     = {"Main", "Trade", "BottomTitle"}

local RESULT_TIMEOUT          = 30
local MAX_ATTEMPTS_PER_ITEM   = 3
local READY_TIMEOUT           = 30
local ACCEPT_CHECK_INTERVAL   = 0.5
local ACCEPT_WAIT_TIMEOUT     = 30

local function findParentButton(obj)
    local current = obj
    while current do
        if current:IsA("TextButton") or current:IsA("ImageButton") then return current end
        current = current.Parent
    end
    return nil
end

local function findTextElementInContainer(container, search)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then return obj end
        end
    end
    return nil
end

local function findResultElement(search)
    local container = findObjectByPath(playerGui, table.unpack(resultContainerPath))
    if not container then return nil end
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            if obj.Text and obj.Text:lower():find(search:lower(), 1, true) then
                local parent = obj.Parent
                if parent and parent.Name == "Title" then return obj end
            end
        end
    end
    return nil
end

local function waitForObject(path, timeout)
    local waited = 0
    while waited < timeout do
        local obj = findObjectByPath(playerGui, table.unpack(path))
        if obj then return obj end
        task.wait(0.5); waited += 0.5
    end
    return nil
end

local function getPercent()
    local bottomTitle = findObjectByPath(playerGui, table.unpack(bottomTitlePath))
    if not bottomTitle or not (bottomTitle:IsA("TextLabel") or bottomTitle:IsA("TextButton") or bottomTitle:IsA("TextBox")) then
        return nil
    end
    local percent = bottomTitle.Text:match("(%d+)%%")
    return percent and tonumber(percent) or nil
end

local function checkSecondContainer(loadFruitItems)
    local secondContainer = findObjectByPath(playerGui, table.unpack(secondContainerPath))
    if not secondContainer then return false end
    for _, item in ipairs(loadFruitItems) do
        if not findTextElementInContainer(secondContainer, item) then return false end
    end
    return true
end

local function isTradeCompleted()
    local notifications = playerGui:FindFirstChild("Notifications")
    if not notifications then return false end
    for _, obj in ipairs(notifications:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            if obj.Text and obj.Text:lower():find("trade completed", 1, true) then return true end
        end
    end
    return false
end

local function processItem(searchText)
    if findResultElement(searchText) then
        LOG("Trade", "'" .. searchText .. "' уже добавлен")
        return true
    end
    for attempt = 1, MAX_ATTEMPTS_PER_ITEM do
        LOG("Trade", string.format("'%s' (%d/%d)", searchText, attempt, MAX_ATTEMPTS_PER_ITEM))
        local addButton = findObjectByPath(playerGui, table.unpack(addButtonPath))
        if not addButton then WARN("Trade", "AddButton нет"); task.wait(2); continue end
        fireSequence(addButton)

        local firstContainer = waitForObject(firstContainerPath, 5)
        if not firstContainer then WARN("Trade", "FrameAdd нет"); task.wait(2); continue end

        local textElement = findTextElementInContainer(firstContainer, searchText)
        if not textElement then WARN("Trade", "Текст не найден: " .. searchText); task.wait(2); continue end

        local btn = findParentButton(textElement)
        if not btn then WARN("Trade", "Кнопка не найдена"); task.wait(2); continue end

        fireSequence(btn)

        local waitTime = 0
        while waitTime < RESULT_TIMEOUT do
            task.wait(0.5); waitTime += 0.5
            if findResultElement(searchText) then
                LOG("Trade", "'" .. searchText .. "' добавлен")
                return true
            end
        end
        WARN("Trade", "Результат не появился за " .. RESULT_TIMEOUT .. "с")
    end
    return false
end

local function checkPreAcceptConditions(loadFruitItems, mySeat)
    if not isSeated(mySeat) then LOG("Trade", "Не сидим"); return false end
    local percent = getPercent()
    if not percent or percent > 40 then
        LOG("Trade", "Процент > 40% (" .. tostring(percent) .. ")")
        return false
    end
    if not checkSecondContainer(loadFruitItems) then
        LOG("Trade", "Второй контейнер пуст")
        return false
    end
    return true
end

local function waitForPreAcceptConditions(loadFruitItems, mySeat)
    local waited = 0
    while waited < ACCEPT_WAIT_TIMEOUT do
        if not isSeated(mySeat) then return false end
        if checkPreAcceptConditions(loadFruitItems, mySeat) then return true end
        task.wait(ACCEPT_CHECK_INTERVAL)
        waited += ACCEPT_CHECK_INTERVAL
    end
    return false
end

local function acceptAndWaitForCompletion(loadFruitItems, mySeat)
    if not isSeated(mySeat) then LOG("Trade", "Не сидим перед Accept"); return false end
    if not waitForPreAcceptConditions(loadFruitItems, mySeat) then
        LOG("Trade", "Условия не выполнены"); return false
    end
    local acceptBtn = findObjectByPath(playerGui, table.unpack(acceptPath))
    if not acceptBtn then LOG("Trade", "Accept не найден"); return false end
    LOG("Trade", "Accept →")
    fireSequence(acceptBtn)

    local waited = 0
    local ready1 = findObjectByPath(playerGui, table.unpack(ready1Path))
    while waited < READY_TIMEOUT do
        task.wait(0.5); waited += 0.5
        if isTradeCompleted() then LOG("Trade", "Trade completed"); return true end
        if not isSeated(mySeat) then LOG("Trade", "Встали"); return false end
        if ready1 and ready1:IsA("TextLabel") then
            if ready1.Text == "Ready!" then
                -- continue
            elseif ready1.Text == "Not ready." then
                return false
            else
                return false
            end
        end
    end
    if isTradeCompleted() then return true end
    LOG("Trade", "Таймаут трейда")
    return false
end

local function runTradeMode()
    State.mode = "trade"
    LOG("Trade", "=== START ===")

    selectTeam()

    local config = nil
    while config == nil and State.running do
        local inventory = collectInventory()
        if #inventory > 0 then
            sendInventory(inventory)
        else
            WARN("Trade", "Инвентарь пуст, пауза " .. SEND_INVENTORY_INTERVAL)
            task.wait(SEND_INVENTORY_INTERVAL)
            continue
        end
        local waited = 0
        while waited < 120 do
            config = fetchConfig()
            if config then break end
            task.wait(CONFIG_POLL_INTERVAL)
            waited += CONFIG_POLL_INTERVAL
        end
        if not config then
            WARN("Trade", "Конфиг не получен за 120с")
            task.wait(SEND_INVENTORY_INTERVAL)
        end
    end
    if not config then State.mode = "none"; return end

    LOG("Trade", "Конфиг получен")

    if not processLoadFruit(config.load_fruit_items or {}) then
        WARN("Trade", "Ошибка LoadFruit"); State.mode = "none"; return
    end

    local tradeCompleted = false
    while not tradeCompleted and State.running do
        local tradeTable, mySeat, wasFullyFree = findTradeTable(config.partner_name or "")
        if not tradeTable then
            LOG("Trade", "Стол не найден, 5с"); task.wait(5); continue
        end

        local targetPos = mySeat.Position
        LOG("Trade", "Стол: " .. (wasFullyFree and "свободный" or "занятый"))

        if not moveToPositionWithJump(targetPos) then
            LOG("Trade", "Не добрались"); task.wait(2); continue
        end

        if not waitForSeat(mySeat, 30) then
            LOG("Trade", "Не сел, пересадка")
            if not resetSeatAndWait(mySeat, targetPos) then
                LOG("Trade", "Пересадка провалилась"); task.wait(2); continue
            end
        end

        LOG("Trade", "Сидим. Ждём партнёра...")

        while not tradeCompleted and State.running do
            if not isSeated(mySeat) then
                if not resetSeatAndWait(mySeat, targetPos) then break end
            end

            local partnerNameActual = getPartnerName(tradeTable, mySeat)
            local expectedPartner   = config.partner_name or ""
            LOG("Trade", "Партнёр: " .. (partnerNameActual or "нет") .. " | нужен: " .. expectedPartner)

            if partnerNameActual == nil then
                task.wait(1)
            elseif expectedPartner ~= "" and partnerNameActual ~= expectedPartner then
                LOG("Trade", "Партнёр не совпал, встаём")
                local char = player.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum then pcall(function() hum.Sit = false end) end
                end
                task.wait(1); break
            else
                LOG("Trade", "Партнёр подходит, добавляем предметы...")
                local allItemsAdded = true
                for _, itemName in ipairs(config.trade_items or {}) do
                    if not isSeated(mySeat) then
                        LOG("Trade", "Встали, пересадка и заново")
                        resetSeatAndWait(mySeat, targetPos)
                        allItemsAdded = false; break
                    end
                    if not processItem(itemName) then allItemsAdded = false; break end
                end

                if not allItemsAdded then
                    if not resetSeatAndWait(mySeat, targetPos) then break end
                else
                    if not isSeated(mySeat) then
                        if not resetSeatAndWait(mySeat, targetPos) then break end
                    end
                    if acceptAndWaitForCompletion(config.load_fruit_items or {}, mySeat) then
                        LOG("Trade", "Трейд успешен!")
                        tradeCompleted = true; break
                    else
                        LOG("Trade", "Трейд не удался, пересадка")
                        if not resetSeatAndWait(mySeat, targetPos) then break end
                    end
                end
            end
        end
    end
    State.mode = "none"
end

-- ============================================================
-- MAIN
-- ============================================================
LOG("Main", "=== COMBINED START === Me: " .. player.Name)

-- 1) Green
runGreenMode()

-- 2) Trade
runTradeMode()

LOG("Main", "=== COMBINED END ===")
