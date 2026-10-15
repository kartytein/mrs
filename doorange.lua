--!nocheck
-- ============================================================
-- HOHO_H HUB LOADER + UI WAIT + BUTTON ACTIVATOR
-- Хаб: loadstring(game:HttpGet("https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"))()
-- ============================================================

local CoreGui = game:GetService("CoreGui")

print("[HOHO] === START ===")

-- ============================================================
-- 1. ЗАГРУЗКА ХАБА
-- ============================================================
print("[HOHO] загружаю хаб...")
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"))()
    end)
    if ok then
        print("[HOHO] хаб загружен")
    else
        warn("[HOHO] ошибка загрузки хаба: " .. tostring(err))
    end
end)

-- ============================================================
-- 2. УТИЛИТЫ
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

local function findButtonByCoords(name, tx, ty, tol)
    tol = tol or 5
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == name then
            local dx = math.abs(obj.AbsolutePosition.X - tx)
            local dy = math.abs(obj.AbsolutePosition.Y - ty)
            if dx <= tol and dy <= tol then return obj end
        end
    end
    return nil
end

-- ============================================================
-- 3. ОЖИДАНИЕ ПОЯВЛЕНИЯ КНОПКИ (бесконечное)
-- ============================================================
local function waitButtonInfinite(name, tx, ty, tol, logTag)
    logTag = logTag or name
    local lastLog = 0
    local t0 = tick()
    while true do
        local b = findButtonByCoords(name, tx, ty, tol)
        if b then
            print(string.format("[HOHO] %s: появилась через %.1fс (%s)",
                logTag, tick() - t0, b:GetFullName()))
            return b
        end
        local el = tick() - t0
        if el - lastLog >= 5 then
            lastLog = el
            print(string.format("[HOHO] %s: жду появления... %.0fс", logTag, el))
        end
        task.wait(0.3)
    end
end

-- ============================================================
-- 4. АКТИВАЦИЯ КНОПКИ
-- ============================================================
local function activateButton(btn, tag)
    tag = tag or "button"
    if not btn then
        warn("[HOHO] " .. tag .. ": кнопка nil")
        return false
    end
    print("[HOHO] " .. tag .. ": активирую " .. btn:GetFullName())
    local ok = fireSequence(btn)
    print("[HOHO] " .. tag .. ": fireSequence => " .. tostring(ok))
    if not ok then
        pcall(function() btn:Click() end)
        task.wait(0.15)
        pcall(function() btn:Activate() end)
    end
    return ok
end

-- ============================================================
-- 5. ЖДЁМ ПОЯВЛЕНИЯ ХАБА (проверяем появление любой кнопки)
-- ============================================================
print("[HOHO] жду появления UI хаба...")
local hubReady = false
local t0 = tick()
while not hubReady do
    -- проверяем, появилась ли хоть одна кнопка с нужным именем
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == "HOMEPAGE_BUTTON" then
            hubReady = true
            print(string.format("[HOHO] UI появился через %.1fс", tick() - t0))
            break
        end
    end
    if not hubReady then
        task.wait(0.5)
    end
end

-- ============================================================
-- 6. ЦЕПОЧКА АКТИВАЦИИ
-- ============================================================

-- ШАГ 1: HOMEPAGE_BUTTON (557, 276)
print("[HOHO] --- ШАГ 1: HOMEPAGE_BUTTON (557, 276) ---")
local btn1 = waitButtonInfinite("HOMEPAGE_BUTTON", 557.18, 276.32, 5, "HOMEPAGE_BUTTON")
activateButton(btn1, "HOMEPAGE_BUTTON")

-- ШАГ 2: Button (485, 245) внутри PAGES_TAB.ANCHOR.MINI_PAGES.MINI_11.ScrollingFrame
print("[HOHO] --- ШАГ 2: Button (485, 245) ---")

local PARENT_PATH = {
    "H\u{043E}h\u{043E}_g\u{0435}n4",
    "MAIN_UI",
    "MAIN_ZONES",
    "PAGES_TAB",
    "ANCHOR",
    "MINI_PAGES",
    "MINI_11",
    "ScrollingFrame",
}

local function walkPath(segments)
    local cur = CoreGui
    for _, seg in ipairs(segments) do
        if not cur then return nil end
        cur = cur:FindFirstChild(seg)
    end
    return cur
end

local btn2 = nil
local lastLog = 0
local t1 = tick()
while not btn2 do
    local parent = walkPath(PARENT_PATH)
    if parent then
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "Button" and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                local dx = math.abs(c.AbsolutePosition.X - 484.81)
                local dy = math.abs(c.AbsolutePosition.Y - 244.62)
                if dx <= 5 and dy <= 5 then
                    btn2 = c
                    print(string.format("[HOHO] Button: появилась через %.1fс (через MINI_11.ScrollingFrame)",
                        tick() - t1))
                    break
                end
            end
        end
    end
    if not btn2 then
        btn2 = findButtonByCoords("Button", 484.81, 244.62, 5)
    end
    if not btn2 then
        local el = tick() - t1
        if el - lastLog >= 5 then
            lastLog = el
            print(string.format("[HOHO] Button: жду появления... %.0fс", el))
        end
        task.wait(0.3)
    end
end

activateButton(btn2, "Button")

print("[HOHO] === DONE ===")
