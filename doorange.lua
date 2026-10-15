--!nocheck
-- ============================================================
-- CHAIN ACTIVATOR v2 (infinite wait for appearance)
-- 1) HOMEPAGE_BUTTON  (pos ≈ 557, 276)
-- 2) Button           (pos ≈ 485, 245)
--    Путь родителя: Hоhо_gеn4.MAIN_UI.MAIN_ZONES.PAGES_TAB.ANCHOR
--                   .MINI_PAGES.MINI_11.ScrollingFrame
-- Метод: fireSequence 1:1
-- ============================================================
loadstring(game:HttpGet("https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"))()

local CoreGui = game:GetService("CoreGui")

print("[HPB] === START chain v2 ===")

-- ---------- fireSequence 1:1 ----------
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

-- ---------- Поиск кнопки по имени + координатам ----------
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

-- ---------- Бесконечное ожидание кнопки ----------
local function waitButtonInfinite(name, tx, ty, tol, logTag)
    logTag = logTag or name
    local lastLog = 0
    local t0 = tick()
    while true do
        local b = findButtonByCoords(name, tx, ty, tol)
        if b then
            print(string.format("[HPB] %s: появилась через %.1fс (%s)",
                logTag, tick() - t0, b:GetFullName()))
            return b
        end
        local el = tick() - t0
        if el - lastLog >= 5 then
            lastLog = el
            print(string.format("[HPB] %s: жду появления... %.0fс", logTag, el))
        end
        task.wait(0.3)
    end
end

-- ---------- Ходьба по пути (фолбэк) ----------
local function walkPath(segments)
    local cur = CoreGui
    for _, seg in ipairs(segments) do
        if not cur then return nil end
        cur = cur:FindFirstChild(seg)
    end
    return cur
end

-- ============================================================
-- ШАГ 1: HOMEPAGE_BUTTON (557, 276) — ждём появления
-- ============================================================
print("[HPB] --- ШАГ 1: жду HOMEPAGE_BUTTON (557, 276) ---")
local btn1 = waitButtonInfinite("HOMEPAGE_BUTTON", 557.18, 276.32, 5, "HOMEPAGE_BUTTON")

print("[HPB] активирую HOMEPAGE_BUTTON...")
local ok1 = fireSequence(btn1)
print("[HPB] fireSequence => " .. tostring(ok1))
if not ok1 then
    pcall(function() btn1:Click() end)
    task.wait(0.15)
    pcall(function() btn1:Activate() end)
end

-- ============================================================
-- ШАГ 2: Button (485, 245) — ждём появления (никакой фиксированной паузы)
-- ============================================================
print("[HPB] --- ШАГ 2: жду Button (485, 245) ---")

-- 2a. Сначала пробуем найти строго через родителя MINI_11.ScrollingFrame
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

local btn2 = nil
local lastLog = 0
local t0 = tick()
while not btn2 do
    -- пробуем через родителя
    local parent = walkPath(PARENT_PATH)
    if parent then
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "Button" and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                local dx = math.abs(c.AbsolutePosition.X - 484.81)
                local dy = math.abs(c.AbsolutePosition.Y - 244.62)
                if dx <= 5 and dy <= 5 then
                    btn2 = c
                    print(string.format("[HPB] Button: появилась через %.1fс (через MINI_11.ScrollingFrame)",
                        tick() - t0))
                    break
                end
            end
        end
    end
    -- фолбэк — глобальный поиск
    if not btn2 then
        btn2 = findButtonByCoords("Button", 484.81, 244.62, 5)
    end
    if not btn2 then
        local el = tick() - t0
        if el - lastLog >= 5 then
            lastLog = el
            print(string.format("[HPB] Button: жду появления... %.0fс", el))
        end
        task.wait(0.3)
    end
end

print("[HPB] найден: " .. btn2:GetFullName())
print(string.format("[HPB]   pos=(%.2f, %.2f) size=(%.2f, %.2f) vis=%s",
    btn2.AbsolutePosition.X, btn2.AbsolutePosition.Y,
    btn2.AbsoluteSize.X, btn2.AbsoluteSize.Y,
    tostring(btn2.Visible)))

print("[HPB] fireSequence на Button...")
local ok2 = fireSequence(btn2)
print("[HPB] fireSequence => " .. tostring(ok2))
if not ok2 then
    print("[HPB] фолбэк :Click()")
    pcall(function() btn2:Click() end)
    task.wait(0.15)
    print("[HPB] фолбэк :Activate()")
    pcall(function() btn2:Activate() end)
end

print("[HPB] === DONE ===")
