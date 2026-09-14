-- ============================================================
-- ФУЛЛ-ДАМП OPTION1.BUTTON (исправлен pairs по Instance)
-- ============================================================
local Players = game:GetService("Players")
local CS = game:GetService("CollectionService")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local function fmt(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    local tp = type(v)
    if tp == "table" then
        local parts = {}
        for k, vv in pairs(v) do
            table.insert(parts, string.format("[%s]=%s", tostring(k), fmt(vv, depth+1)))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif tp == "string" then
        return string.format("%q", v)
    elseif typeof(v) == "Instance" then
        return string.format("[%s:%s]", v.ClassName, v.Name)
    else
        return tostring(v)
    end
end

local SIGNALS = {
    "MouseEnter", "MouseLeave",
    "MouseButton1Down", "MouseButton1Up", "MouseButton1Click",
    "MouseButton2Down", "MouseButton2Up", "MouseButton2Click",
    "Activated", "InputBegan", "InputChanged", "InputEnded",
    "TouchTap", "TouchLongPress",
    "SelectionGained", "SelectionLost",
    "Changed", "ChildAdded", "ChildRemoved",
    "DescendantAdded", "DescendantRemoving",
    "AncestryChanged", "AttributeChanged", "Destroying"
}

local function dumpConnections(inst, indent)
    local pre = indent .. "  "
    print(string.format("%s│  --- КОННЕКТЫ ---", pre))
    local any = false
    for _, sigName in ipairs(SIGNALS) do
        local sig
        pcall(function() sig = inst[sigName] end)
        if sig then
            local ok2, conns = pcall(function() return getconnections(sig) end)
            if ok2 and conns and #conns > 0 then
                any = true
                print(string.format("%s│    %s: %d", pre, sigName, #conns))
                for j, conn in ipairs(conns) do
                    print(string.format("%s│      [%d] Enabled=%s FuncType=%s",
                        pre, j, tostring(conn.Enabled), type(conn.Function)))
                end
            end
        end
    end
    if not any then print(string.format("%s│    (нет активных коннектов)", pre)) end
end

-- Безопасный сбор простых свойств
local function collectProps(inst)
    local result = {}
    -- Собираем имена свойств через getproperties (если есть), иначе через таблицу свойств класса
    local names = {}
    local ok = pcall(function()
        for _, n in ipairs(inst:GetProperties and inst:GetProperties() or {}) do
            table.insert(names, n)
        end
    end)
    if not ok or #names == 0 then
        -- Фоллбэк: список вручную
        names = {
            "Name","ClassName","Visible","Active","Position","Size",
            "AbsolutePosition","AbsoluteSize","AnchorPoint","ZIndex",
            "BackgroundColor3","BackgroundTransparency","BorderSizePixel",
            "ClipsDescendants","LayoutOrder","AutoButtonColor","Selectable",
            "Modal","Text","TextColor3","TextSize","TextScaled","TextWrapped",
            "Font","TextXAlignment","TextYAlignment","TextTransparency","RichText",
            "Image","ImageColor3","ImageTransparency","ScaleType",
            "Enabled","DisplayOrder","ResetOnSpawn","IgnoreGuiInset","ZIndexBehavior",
            "FillDirection","Padding","SortOrder","Rotation","Interactable"
        }
    end
    for _, k in ipairs(names) do
        local o, v = pcall(function() return inst[k] end)
        if o and v ~= nil then
            local tp = type(v)
            if tp == "string" or tp == "number" or tp == "boolean"
               or typeof(v) == "EnumItem" or typeof(v) == "Vector2"
               or typeof(v) == "Vector3" or typeof(v) == "UDim2"
               or typeof(v) == "UDim" or typeof(v) == "Color3" then
                table.insert(result, {k = k, v = v})
            end
        end
    end
    table.sort(result, function(a, b) return a.k < b.k end)
    return result
end

local function dumpInstance(inst, indent)
    indent = indent or ""
    local pre = indent .. "  "
    
    print(string.format("%s╭─ [%s] %s", indent, inst.ClassName, inst.Name))
    print(string.format("%s│  Полный путь: %s", pre, inst:GetFullName()))
    
    -- Простые свойства
    print(string.format("%s│  --- СВОЙСТВА ---", pre))
    for _, p in ipairs(collectProps(inst)) do
        print(string.format("%s│    .%s = %s", pre, p.k, fmt(p.v)))
    end
    
    -- Атрибуты
    local attrs = inst:GetAttributes()
    local attrList = {}
    for k, v in pairs(attrs) do table.insert(attrList, {k = k, v = v}) end
    if #attrList > 0 then
        print(string.format("%s│  --- АТРИБУТЫ ---", pre))
        for _, a in ipairs(attrList) do
            print(string.format("%s│    %s = %s", pre, a.k, fmt(a.v)))
        end
    end
    
    -- Тэги
    local tags = CS:GetTags(inst)
    if #tags > 0 then
        print(string.format("%s│  --- ТЭГИ ---", pre))
        for _, t in ipairs(tags) do print(string.format("%s│    %s", pre, t)) end
    end
    
    -- Коннекты
    dumpConnections(inst, indent)
    
    -- Дети (рекурсия)
    local children = inst:GetChildren()
    print(string.format("%s│  --- ДЕТИ (%d) ---", pre, #children))
    for _, c in ipairs(children) do
        if c:IsA("GuiObject") or c:IsA("LayerCollector") or c:IsA("UIComponent") then
            print(string.format("%s│", pre))
            dumpInstance(c, pre .. "│  ")
        else
            print(string.format("%s│    └─ [%s] %s", pre, c.ClassName, c.Name))
        end
    end
    print(string.format("%s╰─", indent))
end

-- ============================================================
-- Поиск кнопки
-- ============================================================
local function findTarget()
    local dg = pg:FindFirstChild("DialogueGui")
    if not dg then return nil end
    local t1
    for _, c in ipairs(dg:GetChildren()) do
        if c.Name:match("^table") then t1 = c; break end
    end
    if not t1 then return nil end
    local optList = t1:FindFirstChild("optionsList")
    if not optList then return nil end
    local scroller = optList:FindFirstChild("scroller")
    if not scroller then return nil end
    local opt1
    for _, c in ipairs(scroller:GetChildren()) do
        if c.Name:match("option1$") and c:FindFirstChild("button") then
            opt1 = c; break
        end
    end
    if not opt1 then return nil end
    return opt1:FindFirstChild("button"), opt1, scroller
end

print("╔══════════════════════════════════════════════════════╗")
print("║  ЖДУ ПОЯВЛЕНИЯ option1.button (до 15 сек)...         ║")
print("╚══════════════════════════════════════════════════════╝")

local btn, opt1, scroller
local t0 = tick()
while tick() - t0 < 15 do
    btn, opt1, scroller = findTarget()
    if btn then break end
    task.wait(0.2)
end

if not btn then warn("option1.button не найден за 15 сек.") return end

print("")
print("▶▶▶ ЧАСТЬ 1: ИЕРАРХИЯ ◀◀◀")
local chain = {}
local p = btn
while p and p ~= game do
    table.insert(chain, 1, string.format("[%s] %s", p.ClassName, p.Name))
    p = p.Parent
end
for i, s in ipairs(chain) do
    print(string.rep("  ", i-1) .. "└─ " .. s)
end

print("")
print("▶▶▶ ЧАСТЬ 2: ФУЛЛ-ДАМП OPTION1 ◀◀◀")
dumpInstance(opt1, "")

print("")
print("▶▶▶ ЧАСТЬ 3: ФУЛЛ-ДАМП BUTTON ◀◀◀")
dumpInstance(btn, "")

print("")
print("▶▶▶ ЧАСТЬ 4: ФУЛЛ-ДАМП SCROLLER ◀◀◀")
dumpInstance(scroller, "")

print("")
print("▶▶▶ ЧАСТЬ 5: ВСЕ БРАТЬЯ OPTION1 ◀◀◀")
for i, c in ipairs(scroller:GetChildren()) do
    print(string.format("  %d) [%s] %s", i, c.ClassName, c.Name))
    for _, cc in ipairs(c:GetChildren()) do
        print(string.format("       └─ [%s] %s", cc.ClassName, cc.Name))
    end
end

print("")
print("=== ДАМП ЗАВЕРШЁН ===")
