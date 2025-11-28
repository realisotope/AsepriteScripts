local dlg = Dialog("Toolbar")

local tools = {
    -- Selection group
    {name="Rectangular Marquee", id="rectangular_marquee"},
    {name="Elliptical Marquee", id="elliptical_marquee"},
    {name="Lasso", id="lasso"},
    {name="Polygonal Lasso", id="polygonal_lasso"},
    {name="Magic Wand", id="magic_wand"},

    -- Pencil / paint
    {name="Pencil", id="pencil"},
    {name="Spray", id="spray"},
    {name="Eraser", id="eraser"},
    {name="Eyedropper", id="eyedropper"},

    -- View / navigation
    {name="Hand", id="hand"},
    {name="Zoom", id="zoom"},

    -- Move / slice
    {name="Move", id="move"},
    {name="Slice", id="slice"},

    -- Paint / gradients
    {name="Paint Bucket", id="paint_bucket"},
    {name="Gradient", id="gradient"},

    -- Shapes & lines
    {name="Line", id="line"},
    {name="Curve", id="curve"},
    {name="Rectangle", id="rectangle"},
    {name="Filled Rectangle", id="filled_rectangle"},
    {name="Ellipse", id="ellipse"},
    {name="Filled Ellipse", id="filled_ellipse"},

    -- Contours / polygons
    {name="Contour", id="contour"},
    {name="Polygon", id="polygon"},

    -- Effects
    {name="Blur", id="blur"},
    {name="Jumble", id="jumble"},

    -- Text
    {name="Text", id="text"},
}

local toolsById = {}
for _,t in ipairs(tools) do toolsById[t.id] = t.name end

local function shortLabel(id)
    local map = {
        rectangular_marquee = "▭", elliptical_marquee = "◯", lasso = "➰", polygonal_lasso = "🔺", magic_wand = "✨",
        pencil = "✏", spray = "⋯", eraser = "⌫", eyedropper = "◉",
        hand = "✋", zoom = "🔍", move = "⇄", slice = "✂",
        paint_bucket = "▦", gradient = "∿",
        line = "─", curve = "~", rectangle = "▭", filled_rectangle = "■",
        ellipse = "◯", filled_ellipse = "●", contour = "◔", polygon = "⬠",
        blur = "≈", jumble = "✳", text = "T",
    }
    if map[id] then return map[id] end
    local name = toolsById[id]
    if name and #name > 0 then return name:sub(1,1) end
    return id:sub(1,1)
end

local function setTool(toolId)
    if type(Tool) == "function" then
        pcall(function() app.tool = Tool{ id = toolId } end)
    elseif type(app.tool) ~= "nil" then
        pcall(function() app.tool = toolId end)
    elseif type(app.useTool) == "function" then
        pcall(function() app.useTool{ tool = toolId } end)
    else
        pcall(function() app.activeTool = toolId end)
    end
end

local visibility = {}

local function getConfigPath()
    return app.fs.joinPath(app.fs.userConfigPath, "toolbar_visibility.json")
end

local function loadVisibility()
    local configPath = getConfigPath()
    local file = io.open(configPath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            local status, data = pcall(json.decode, content)
            if status and data then
                for k, v in pairs(data) do
                    visibility[k] = v
                end
            end
        end
    end
    for _,t in ipairs(tools) do if visibility[t.id] == nil then visibility[t.id] = true end end
end

local function saveVisibility()
    local configPath = getConfigPath()
    local data = {}
    for k, v in pairs(visibility) do
        data[k] = v
    end
    local file = io.open(configPath, "w")
    if file then
        file:write(json.encode(data))
        file:close()
    end
end

local function showSettingsDialog()
    local sd = Dialog("Toolbar Settings")
    local groups = {
        { "rectangular_marquee", "elliptical_marquee", "lasso", "polygonal_lasso", "magic_wand" },
        { "pencil", "spray", "eraser", "eyedropper","paint_bucket", "gradient" },
        { "hand", "zoom","move", "slice" },
        { "line", "curve", "rectangle", "filled_rectangle", "ellipse", "filled_ellipse" },
        { "contour", "polygon","blur", "jumble","text" }
    }
    for i, group in ipairs(groups) do
        if i > 1 then sd:separator{} end
        for _, id in ipairs(group) do
            sd:check{ id = id, text = toolsById[id], selected = visibility[id], hexpand = false }
        end
        sd:newrow()
    end
    sd:newrow()
    sd:button{ id = "ok", text = "OK", onclick = function()
        local data = sd.data
        for _,t in ipairs(tools) do
            if data[t.id] ~= nil then
                visibility[t.id] = data[t.id]
            end
        end
        for _,t in ipairs(tools) do pcall(function() dlg:modify{ id = t.id, visible = visibility[t.id] } end) end
        saveVisibility()
        sd:close()
    end }
    sd:button{ id = "cancel", text = "Cancel", onclick = function() sd:close() end }
    sd:show{ wait = true, floating = true }
end

loadVisibility()

dlg:button{ id = "settings_btn", text = "⚙", hexpand = false, width = 25, height = 25, onclick = function() showSettingsDialog() end }

for _,t in ipairs(tools) do
    dlg:button{ id = t.id, text = shortLabel(t.id), hexpand = false, width = 25, height = 25, visible = visibility[t.id], onclick = function() setTool(t.id) end }
end

dlg:show{wait=false, floating=true}
