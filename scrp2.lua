-- ============================================================
-- ФУЛЛ-ДАМП OPTION1.BUTTON И ВСЕГО ВОКРУГ (исправлен)
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

-- Безопасная проверка сигнала
local function dumpConnections(inst, indent)
    local pre = indent .. "  "
    local SIGNALS = {
        "MouseEnter", "MouseLeave",
        "MouseButton1Down", "MouseButton1Up", "MouseButton1Click",
        "MouseButton2Down", "MouseButton2Up", "MouseButton2Click",
        "Activated", "InputBegan", "InputChanged", "InputEnded",
        "TouchTap", "TouchLongPress",
        "SelectionGained", "SelectionLost",
        "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving",
        "AncestryChanged", "AttributeChanged", "Destroying"
    }
    print(string.format("%s│  --- КОННЕКТЫ ---", pre))
    local any = false
    for _, sigName in ipairs(SIGNALS) do
        local sig
        local ok = pcall(function() sig = inst[sigName] end)
        if ok and sig then
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
    if not any then
        print(string.format("%s│    (нет активных коннектов)", pre))
    end
end

local function dumpInstance(inst, indent)
    indent = indent or ""
    local pre = indent .. "  "
    
    print(string.format("%s╭─ [%s] %s", indent, inst.ClassName, inst.Name))
    print(string.format("%s│  Полный путь: %s", pre, inst:GetFullName()))
    
    if inst:IsA("GuiObject") then
        print(string.format("%s│  Visible = %s", pre, tostring(inst.Visible)))
        print(string.format("%s│  Active = %s", pre, tostring(inst.Active)))
        print(string.format("%s│  Position = %s", pre, tostring(inst.Position)))
        print(string.format("%s│  Size = %s", pre, tostring(inst.Size)))
        print(string.format("%s│  AbsolutePosition = %s", pre, tostring(inst.AbsolutePosition)))
        print(string.format("%s│  AbsoluteSize = %s", pre, tostring(inst.AbsoluteSize)))
        print(string.format("%s│  AnchorPoint = %s", pre, tostring(inst.AnchorPoint)))
        print(string.format("%s│  ZIndex = %s", pre, tostring(inst.ZIndex)))
        print(string.format("%s│  BackgroundColor3 = %s", pre, tostring(inst.BackgroundColor3)))
        print(string.format("%s│  BackgroundTransparency = %s", pre, tostring(inst.BackgroundTransparency)))
        print(string.format("%s│  BorderSizePixel = %s", pre, tostring(inst.BorderSizePixel)))
        print(string.format("%s│  ClipsDescendants = %s", pre, tostring(inst.ClipsDescendants)))
        print(string.format("%s│  LayoutOrder = %s", pre, tostring(inst.LayoutOrder)))
    end
    if inst:IsA("GuiButton") then
        print(string.format("%s│  AutoButtonColor = %s", pre, tostring(inst.AutoButtonColor)))
        print(string.format("%s│  Selectable = %s", pre, tostring(inst.Selectable)))
        print(string.format("%s│  Modal = %s", pre, tostring(inst.Modal)))
    end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        print(string.format("%s│  Text = %q", pre, inst.Text))
        print(string.format("%s│  TextColor3 = %s", pre, tostring(inst.TextColor3)))
        print(string.format("%s│  TextSize = %s", pre, tostring(inst.TextSize)))
        print(string.format("%s│  TextScaled = %s", pre, tostring(inst.TextScaled)))
        print(string.format("%s│  TextWrapped = %s", pre, tostring(inst.TextWrapped)))
        print(string.format("%s│  Font = %s", pre, tostring(inst.Font)))
        print(string.format("%s│  TextXAlignment = %s", pre, tostring(inst.TextXAlignment)))
        print(string.format("%s│  TextYAlignment = %s", pre, tostring(inst.TextYAlignment)))
        print(string.format("%s│  TextTransparency = %s", pre, tostring(inst.TextTransparency)))
        print(string.format("%s│  RichText = %s", pre, tostring(inst.RichText)))
    end
    if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
        print(string.format("%s│  Image = %s", pre, tostring(inst.Image)))
        print(string.format("%s│  ImageColor3 = %s", pre, tostring(inst.ImageColor3)))
        print(string.format("%s│  ImageTransparency = %s", pre, tostring(inst.ImageTransparency)))
        print(string.format("%s│  ScaleType = %s", pre, tostring(inst.ScaleType)))
    end
    if inst:IsA("ScreenGui") then
        print(string.format("%s│  Enabled = %s", pre, tostring(inst.Enabled)))
        print(string.format("%s│  DisplayOrder = %s", pre, tostring(inst.DisplayOrder)))
        print(string.format("%s│  ResetOnSpawn = %s", pre, tostring(inst.ResetOnSpawn)))
        print(string.format("%s│  IgnoreGuiInset = %s", pre, tostring(inst.IgnoreGuiInset)))
        print(string.format("%s│  ZIndexBehavior = %s", pre, tostring(inst.ZIndexBehavior)))
    end
    if inst:IsA("UIGridLayout") or inst:IsA("UIListLayout") then
        print(string.format("%s│  FillDirection = %s", pre, tostring(inst.FillDirection)))
        print(string.format("%s│  Padding = %s", pre, tostring(inst.Padding)))
        print(string.format("%s│  SortOrder = %s", pre, tostring(inst.SortOrder)))
    end
    
    -- Все простые свойства через pcall
    print(string.format("%s│  --- Все простые свойства ---", pre))
    local props = {}
    for k, v in pairs(inst) do
        if type(k) == "string" and not k:match("^_") then
            local o, val = pcall(function() return inst[k] end)
            if o and (type(val) == "string" or type(val) == "number"
                   or type(val) == "boolean" or typeof(val) == "EnumItem"
                   or typeof(val) == "Vector2" or typeof(val) == "Vector3"
                   or typeof(val) == "UDim2" or typeof(val) == "UDim"
                   or typeof(val) == "Color3") then
                table.insert(props, {k = k, v = val})
            end
        end
    end
    table.sort(props, function(a, b) return a.k < b.k end)
    for _, p in ipairs(props) do
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
    
    -- Коннекты (для всех, не только кнопок)
    dumpConnections(inst, indent)
    
    -- Дети
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
-- 1. Поиск кнопки
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
    return opt1:FindFirstChild("button"), opt1, scroller, optList, t1, dg
end

print("╔══════════════════════════════════════════════════════╗")
print("║  ЖДУ ПОЯВЛЕНИЯ option1.button (до 15 сек)...         ║")
print("╚══════════════════════════════════════════════════════╝")

local btn, opt1, scroller, optList, t1, dg
local t0 = tick()
while tick() - t0 < 15 do
    btn, opt1, scroller, optList, t1, dg = findTarget()
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
