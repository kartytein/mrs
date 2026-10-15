--!nocheck
-- ============================================================
-- HOHO_H HUB LOADER + UI WAIT + BUTTON ACTIVATOR (retry until success)
-- Хаб: loadstring(game:HttpGet("https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"))()
--
-- Логика:
--  - ШАГ 1 активируется → ждём появления ШАГ 2 (это = успех шага 1).
--    Если ШАГ 2 не появился за RETRY_DELAY — повторяем активацию ШАГ 1.
--  - ШАГ 2 активируется → ждём появления ШАГ 3 (маркер успеха ШАГ 2).
--    Пока ШАГ 3 не задан — можно указать любой маркер (имя+координаты).
-- ============================================================

local CoreGui = game:GetService("CoreGui")

print("[HOHO] === START ===")

local RETRY_DELAY = 5   -- сек между попытками активации

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

local function walkPath(segments)
    local cur = CoreGui
    for _, seg in ipairs(segments) do
        if not cur then return nil end
        cur = cur:FindFirstChild(seg)
    end
    return cur
end

-- Ищем «маркер» — кнопку по имени+координатам, в т.ч. через конкретный путь.
-- marker = { name, x, y, tol, path? }
local function findMarker(marker)
    if marker.path then
        local parent = walkPath(marker.path)
        if parent then
            for _, c in ipairs(parent:GetChildren()) do
                if c.Name == marker.name and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                    local dx = math.abs(c.AbsolutePosition.X - marker.x)
                    local dy = math.abs(c.AbsolutePosition.Y - marker.y)
                    if dx <= (marker.tol or 5) and dy <= (marker.tol or 5) then
                        return c
                    end
                end
            end
        end
    end
    return findButtonByCoords(marker.name, marker.x, marker.y, marker.tol or 5)
end

-- ============================================================
-- 3. ЖДЁМ ПОЯВЛЕНИЯ ХАБА (появление целевой ШАГ1-кнопки)
-- ============================================================
print("[HOHO] жду появления UI хаба...")
do
    local t0 = tick()
    while true do
        local ready = false
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == "HOMEPAGE_BUTTON" then
                ready = true
                break
            end
        end
        if ready then
            print(string.format("[HOHO] UI появился через %.1fс", tick() - t0))
            break
        end
        task.wait(0.5)
    end
end

-- ============================================================
-- 4. МАРКЕРЫ
-- ============================================================
-- ШАГ 1 = сама кнопка, которую надо нажать
local STEP1_BTN = {
    name = "HOMEPAGE_BUTTON", x = 557.18, y = 276.32, tol = 5,
}

-- ШАГ 2 = кнопка, которую надо нажать после ШАГ 1;
-- её появление = индикатор успеха ШАГ 1.
local STEP2_BTN = {
    name = "Button", x = 484.81, y = 244.62, tol = 5,
    path = {
        "H\u{043E}h\u{043E}_g\u{0435}n4",
        "MAIN_UI",
        "MAIN_ZONES",
        "PAGES_TAB",
        "ANCHOR",
        "MINI_PAGES",
        "MINI_11",
        "ScrollingFrame",
    },
}

-- ============================================================
-- 5. АКТИВАЦИЯ С ПОВТОРАМИ
-- ============================================================
-- activateUntilMarker:
--   активирует targetBTN, ждёт появления marker'а.
--   если marker не появился за RETRY_DELAY — повторяет.
--   Возвращает найденный marker-инстанс.
local function activateUntilMarker(targetBTN, marker, tag)
    tag = tag or targetBTN.name
    local attempt = 0
    while true do
        attempt += 1

        local btn = findMarker(targetBTN)
        if not btn then
            print(string.format("[HOHO] %s: попытка #%d — target не найден, ждём...", tag, attempt))
            task.wait(1)
        else
            print(string.format("[HOHO] %s: попытка #%d — активирую %s (%.1f, %.1f)",
                tag, attempt, btn:GetFullName(),
                btn.AbsolutePosition.X, btn.AbsolutePosition.Y))

            local ok = fireSequence(btn)
            if not ok then
                pcall(function() btn:Click() end)
                task.wait(0.15)
                pcall(function() btn:Activate() end)
            end
        end

        -- ждём появления marker'а RETRY_DELAY секунд
        local t0 = tick()
        while tick() - t0 < RETRY_DELAY do
            local m = findMarker(marker)
            if m then
                print(string.format("[HOHO] %s: ✓ успех через %.1fс (маркер %s)",
                    tag, tick() - t0, m:GetFullName()))
                return m
            end
            task.wait(0.2)
        end

        print(string.format("[HOHO] %s: маркер не появился за %dс — повтор", tag, RETRY_DELAY))
    end
end

-- ============================================================
-- 6. ЦЕПОЧКА
-- ============================================================
print("[HOHO] --- ШАГ 1 → ШАГ 2 ---")
local step2 = activateUntilMarker(STEP1_BTN, STEP2_BTN, "STEP1")

-- ============================================================
-- 7. ШАГ 2
-- ============================================================
-- Пока не знаем «маркер успеха» для шага 2 — просто активируем
-- с повторами до тех пор, пока что-то дальше не подтвердит.
-- Здесь в качестве маркера можно использовать любой следующий
-- элемент, который должен появиться. Если его нет — оставь nil
-- и просто один раз нажми ШАГ 2.
print("[HOHO] --- ШАГ 2 ---")
local nextMarker = nil  -- ← сюда можно положить {name=..., x=..., y=...}

if nextMarker then
    activateUntilMarker(STEP2_BTN, nextMarker, "STEP2")
else
    -- без маркера: жмём один раз и выходим
    local b2 = step2 or findMarker(STEP2_BTN)
    if b2 then
        print("[HOHO] STEP2: маркер не задан, разовая активация")
        local ok = fireSequence(b2)
        print("[HOHO] STEP2: fireSequence => " .. tostring(ok))
        if not ok then
            pcall(function() b2:Click() end)
            task.wait(0.15)
            pcall(function() b2:Activate() end)
        end
    else
        warn("[HOHO] STEP2: кнопка не найдена")
    end
end

print("[HOHO] === DONE ===")
