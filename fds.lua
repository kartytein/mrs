-- ============================================================
-- GREEN MODE — обмен фруктами (host/guest)
-- ============================================================
local GREEN_HOST_POS   = SIMPLE_HOST_POS
local GREEN_HOST_LOOK  = SIMPLE_HOST_LOOK
local GREEN_GUEST_POS  = SIMPLE_GUEST_POS
local GREEN_GUEST_LOOK = SIMPLE_GUEST_LOOK

local TAB_FRUIT, OPT_FRUIT = 7, 7

-- --- Fruit helpers ---
local function hasFruitTool()
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

local function waitFruitTool()
    while State.running do
        local t = hasFruitTool()
        if t then return t end
        task.wait(0.2)
    end
    return nil
end

-- Один вызов ClaimQuest
local function claimQuestOnce()
    if not RF_InteractDragonQuest then return false, "no RF" end
    local ok, resp = pcall(function()
        return RF_InteractDragonQuest:InvokeServer({
            NPC = POST_TRADE_NPC_NAME,
            Command = "ClaimQuest"
        })
    end)
    if not ok then return false, resp end
    return true, resp
end

-- --- Основная функция ---
local function runGreenMode()
    State.mode = "green"
    LOG("Green", "=== START ===")

    -- 1) Матч
    local match = nil
    while State.running and not match do
        local data, err = requestMatch()
        if not data then
            WARN("Green", "match error: " .. tostring(err))
            task.wait(3)
        elseif data.waiting then
            LOG("Green", "waiting for partner...")
            task.wait(3)
        else
            match = data
        end
    end
    if not match then State.mode = "none"; return end

    LOG("Green", "role=" .. tostring(match.role)
        .. " partner=" .. tostring(match.partner_name))

    -- 2) Guest телепортится на job_id хоста
    if match.role == "guest"
       and match.job_id and match.job_id ~= ""
       and match.job_id ~= game.JobId then

        LOG("Green", "guest: телепорт на " .. tostring(match.job_id))
        pcall(function() teleportToJobId(match.job_id) end)
        local w = 0
        while w < 60 and game.JobId ~= match.job_id do
            task.wait(1); w += 1
        end
        if game.JobId ~= match.job_id then
            WARN("Green", "телепорт не удался — выход")
            requestUnmatch()
            State.mode = "none"
            return
        end
        task.wait(2)
        requestMatch()  -- обновляем job_id на сервере
    end

    -- 3) Ждём хаб и идём на позицию
    if not waitForHubReady() then
        State.mode = "none"; return
    end

    local myPos, myLook
    if match.role == "host" then
        myPos, myLook = GREEN_HOST_POS, GREEN_HOST_LOOK
    else
        myPos, myLook = GREEN_GUEST_POS, GREEN_GUEST_LOOK
    end

    collisionsDisabledGlobal = true
    disableCollisionsNow()
    task.wait(0.3)
    goToAndFace(myPos, myLook)
    collisionsDisabledGlobal = false
    restoreCollisionsNow()
    task.wait(0.5)

    -- 4) Host активирует 7,7 и ждёт фрукт
    if match.role == "host" then
        LOG("Green", "host: 7,7 ON")
        ensureOptionOn(TAB_FRUIT, OPT_FRUIT)
        LOG("Green", "host: ждём fruit-tool...")
        waitFruitTool()
        LOG("Green", "host: fruit есть → 7,7 OFF")
        ensureOptionOff(TAB_FRUIT, OPT_FRUIT)
    end

    -- 5) Ping-pong цикл. Идём до ClaimQuest == true.
    local claimedMe = false
    local iteration = 0

    while State.running and not claimedMe do
        iteration += 1

        if match.role == "host" then
            LOG("Green", "host #" .. iteration .. ": drop")
            eatFruitDrop()

            local _, resp = claimQuestOnce()
            LOG("Green", "host #" .. iteration .. ": ClaimQuest → " .. tostring(resp))
            if resp == true then claimedMe = true; break end

            LOG("Green", "host #" .. iteration .. ": ждём от guest")
            waitFruitTool()
        else
            LOG("Green", "guest #" .. iteration .. ": ждём от host")
            waitFruitTool()

            LOG("Green", "guest #" .. iteration .. ": drop")
            eatFruitDrop()

            local _, resp = claimQuestOnce()
            LOG("Green", "guest #" .. iteration .. ": ClaimQuest → " .. tostring(resp))
            if resp == true then claimedMe = true; break end
        end
    end

    LOG("Green", "=== DONE claimed=" .. tostring(claimedMe) .. " ===")
    requestUnmatch()
    State.mode = "none"
end
