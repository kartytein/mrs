-- ============================================================
-- ФУЛЛ-ДАМП OPTION1 (всё в виде строк, без pairs по Instance)
-- ============================================================
local Players = game:GetService("Players")
local CS = game:GetService("CollectionService")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- Список свойств для проверки (все типичные для UI)
local PROP_LIST = {
    -- GuiObject
    "Name","ClassName","Visible","Active","Position","Size",
    "AbsolutePosition","AbsoluteSize","AnchorPoint","ZIndex","ZIndexBehavior",
    "BackgroundColor3","BackgroundTransparency","BorderColor3","BorderSizePixel",
    "BorderMode","ClipsDescendants","LayoutOrder","Rotation","Selectable",
    "NextSelectionDown","NextSelectionUp","NextSelectionLeft","NextSelectionRight",
    "SelectionImageObject","SelectionOrder","AutomaticSize",
    -- GuiButton
    "AutoButtonColor","Modal","Interactable","Selected","Hovering","Pressed",
    -- Text
    "Text","TextColor3","TextSize","TextScaled","TextWrapped","Font",
    "FontFace","TextXAlignment","TextYAlignment","TextTransparency",
    "TextStrokeColor3","TextStrokeTransparency","RichText","LineHeight",
    "MaxVisibleGraphemes","TextTruncate",
    -- Image
    "Image","ImageColor3","ImageTransparency","ScaleType","SliceCenter",
    "SliceScale","TileSize","ResampleMode",
    -- ScreenGui
    "Enabled","DisplayOrder","ResetOnSpawn","IgnoreGuiInset",
    -- ScrollingFrame
    "CanvasPosition","CanvasSize","ScrollBarThickness","ScrollBarImageColor3",
    "ScrollingDirection","ScrollingEnabled","ElasticBehavior",
    "AutomaticCanvasSize","TopImage","BottomImage","MidImage","ScrollBarImageTransparency",
    -- UIComponent (layouts)
    "FillDirection","Padding","SortOrder","HorizontalAlignment",
    "VerticalAlignment","FillDirectionMaxCells","StartCorner","CellPadding",
    "CellSize","AspectRatio","AspectType","DominantAxis",
}

local function valStr(v)
    if v == nil then return "nil" end
    local tp = typeof(v)
    if tp == "Instance" then
        return string.format("[%s] %s", v.ClassName, v:GetFullName())
    elseif tp == "EnumItem" then
        return tostring(v)
    elseif tp == "Color3" then
        return string.format("Color3(%.3f, %.3f, %.3f)", v.R, v.G, v.B)
    elseif tp == "Vector2" then
        return string.format("Vector2(%.2f, %.2f)", v.X, v.Y)
    elseif tp == "Vector3" then
        return string.format("Vector3(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
    elseif tp == "UDim2" then
        return string.format("UDim2(%s, %s)", tostring(v.X), tostring(v.Y))
    elseif tp == "UDim" then
        return string.format("UDim(%.2f, %d)", v.Scale, v.Offset)
    elseif tp == "NumberRange" then
        return string.format("NumberRange(%.2f, %.2f)", v.Min, v.Max)
    elseif tp == "Rect" then
        return string.format("Rect(%s, %s)", tostring(v.Min), tostring(v.Max))
    elseif tp == "CFrame" then
        return tostring(v)
    elseif tp == "string" then
        return string.format("%q", v)
    else
        return tostring(v)
    end
end

-- Проверка: является ли свойство доступным для чтения
local function getProp(inst, name)
    local ok, v = pcall(function() return inst[name] end)
    if ok then return v end
    return nil
end

-- Дамп одного объекта
local function dumpInstance(inst, indent)
    indent = indent or ""
    local pre = indent .. "  "
    print(string.format("%s╭─ [%s] %s", indent, inst.ClassName, inst.Name))
    print(string.format("%s│  Путь: %s", pre, inst:GetFullName()))
    
    -- Свойства
    print(string.format("%s│  --- СВОЙСТВА ---", pre))
    for _, k in ipairs(PROP_LIST) do
        local v = getProp(inst, k)
        if v ~= nil then
            print(string.format("%s│    .%s = %s", pre, k, valStr(v)))
        end
    end
    
    -- Атрибуты
    local attrs = inst:GetAttributes()
    local attrCount = 0
    local attrBuf = {}
    for k, v in pairs(attrs) do
        table.insert(attrBuf, string.format("%s│    [%s] = %s", pre, k, valStr(v)))
        attrCount = attrCount + 1
    end
    if attrCount > 0 then
        print(string.format("%s│  --- АТРИБУТЫ (%d) ---", pre, attrCount))
        for _, s in ipairs(attrBuf) do print(s) end
    end
    
    -- Тэги
    local tags = CS:GetTags(inst)
    if #tags > 0 then
        print(string.format("%s│  --- ТЭГИ ---", pre))
        for _, t in ipairs(tags) do print(string.format("%s│    %s", pre, t)) end
    end
    
    -- Коннекты (только для кнопок и важных сигналов)
    if inst:IsA("GuiButton") then
        print(string.format("%s│  --- КОННЕКТЫ ---", pre))
        local hasC = false
        local sigList = {
            "MouseEnter","MouseLeave",
            "MouseButton1Down","MouseButton1Up","MouseButton1Click",
            "MouseButton2Down","MouseButton2Up","MouseButton2Click",
            "Activated","InputBegan","InputChanged","InputEnded",
            "TouchTap","TouchLongPress","SelectionGained","SelectionLost"
        }
        for _, sigName in ipairs(sigList) do
            local sig = getProp(inst, sigName)
            if sig and typeof(sig) == "RBXScriptSignal" then
                local ok, conns = pcall(function() return getconnections(sig) end)
                if ok and conns and #conns > 0 then
                    hasC = true
                    print(string.format("%s│    %s: %d", pre, sigName, #conns))
                    for j, conn in ipairs(conns) do
                        print(string.format("%s│      [%d] Enabled=%s FuncType=%s",
                            pre, j, tostring(conn.Enabled), type(conn.Function)))
                    end
                end
            end
        end
        if not hasC then print(string.format("%s│    (нет)", pre)) end
    end
    
    -- Дети (рекурсивно)
    local children = inst:GetChildren()
    print(string.format("%s│  --- ДЕТИ (%d) ---", pre, #children))
    for _, c in ipairs(children) do
        if c:IsA("GuiObject") or c:IsA("LayerCollector") or c:IsA("UIComponent") or c:IsA("UIGradient") then
            dumpInstance(c, pre .. "│  ")
        else
            print(string.format("%s│    └─ [%s] %s", pre, c.ClassName, c.Name))
        end
    end
    
    print(string.format("%s╰─", indent))
end

-- ============================================================
-- Поиск option1
-- ============================================================
local function findOption1()
    local dg = pg:FindFirstChild("DialogueGui")
    if not dg then return nil end
    local t1 = nil
    for _, c in ipairs(dg:GetChildren()) do
        if c.Name:match("^table") then t1 = c; break end
    end
    if not t1 then return nil end
    local optList = t1:FindFirstChild("optionsList")
    if not optList then return nil end
    local scroller = optList:FindFirstChild("scroller")
    if not scroller then return nil end
    local opt1 = nil
    for _, c in ipairs(scroller:GetChildren()) do
        if c.Name:match("option1$") then opt1 = c; break end
    end
    return opt1, t1, optList, scroller, dg
end

print("Ожидание option1 (до 15 сек)...")
local opt1, t1, optList, scroller, dg
local t0 = tick()
while tick() - t0 < 15 do
    opt1, t1, optList, scroller, dg = findOption1()
    if opt1 then break end
    task.wait(0.2)
end

if not opt1 then
    warn("option1 не найден")
    return
end

print("")
print("╔══════════════════════════════════════════════════════╗")
print("║  ФУЛЛ-ДАМП: DialogueGui → table → optionsList →       ║")
print("║            scroller → option1 → button               ║")
print("╚══════════════════════════════════════════════════════╝")
print("")

-- Дамп сверху (только структура, без глубокой рекурсии наверху)
print("▶ ИЕРАРХИЯ:")
local p = opt1
local chain = {}
while p and p ~= game do
    table.insert(chain, 1, string.format("[%s] %s", p.ClassName, p.Name))
    p = p.Parent
end
for i, s in ipairs(chain) do
    print(string.rep("  ", i-1) .. "└─ " .. s)
end

print("")
print("▶▶▶ ДАМП option1 (ФУЛЛ) ◀◀◀")
dumpInstance(opt1, "")

print("")
print("▶▶▶ ДАМП scroller ◀◀◀")
dumpInstance(scroller, "")

print("")
print("▶▶▶ ВСЕ БРАТЬЯ OPTION1 В SCROLLER ◀◀◀")
for i, c in ipairs(scroller:GetChildren()) do
    if c:IsA("GuiObject") then
        local btn = c:FindFirstChild("button")
        print(string.format("  %d) [%s] %s%s",
            i, c.ClassName, c.Name,
            btn and (" | Text: " .. (btn.Text or "?")) or ""))
    end
end

print("")
print("=== КОНЕЦ ДАМПА ===")
