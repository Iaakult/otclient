function pcolored(text, color)
    color = color or 'white'
    modules.client_terminal.addLine(tostring(text), color)
end

function draw_debug_boxes()
    g_ui.setDebugBoxesDrawing(not g_ui.isDrawingDebugBoxes())
end

local uiInspectorEnabled = false
local uiInspectorLabel = nil
local uiInspectorLastWidget = nil

local function parseInspectorToggle(state)
    if state == nil or state == '' then
        return nil
    end

    state = tostring(state):lower()
    if state == '1' or state == 'on' or state == 'true' or state == 'enable' then
        return true
    end
    if state == '0' or state == 'off' or state == 'false' or state == 'disable' then
        return false
    end
    if state == 'toggle' then
        return nil
    end

    return 'invalid'
end

local function getInspectorWidgetInfo(widget)
    if not widget then
        return '<nil>'
    end

    local function safeWidgetCall(methodName, fallback)
        if type(widget[methodName]) ~= 'function' then
            return fallback
        end

        local ok, value = pcall(function()
            return widget[methodName](widget)
        end)

        if not ok then
            return fallback
        end

        return value
    end

    local className = safeWidgetCall('getClassName', '?')
    local styleName = safeWidgetCall('getStyleName', '')
    local widgetId = safeWidgetCall('getId', '')

    if widgetId == '' then
        widgetId = '<no-id>'
    end
    if styleName == '' then
        styleName = '<no-style>'
    end

    return string.format('%s | id=%s | style=%s', className, widgetId, styleName)
end

local function buildInspectorHierarchy(widget, maxDepth)
    local lines = {}
    local depth = 0
    maxDepth = maxDepth or 20

    while widget and depth < maxDepth do
        table.insert(lines, string.format('[%d] %s', depth, getInspectorWidgetInfo(widget)))
        local ok, parent = pcall(function()
            return widget:getParent()
        end)
        widget = ok and parent or nil
        depth = depth + 1
    end

    return table.concat(lines, '\n')
end

local function ensureInspectorLabel()
    if uiInspectorLabel and not uiInspectorLabel:isDestroyed() then
        return
    end

    uiInspectorLabel = g_ui.createWidget('UILabel', rootWidget)
    uiInspectorLabel:setId('uiInspectorLabel')
    uiInspectorLabel:setFont('terminus-10px')
    uiInspectorLabel:setBackgroundColor('#1b1b1bee')
    uiInspectorLabel:setColor('#e6e6e6ff')
    uiInspectorLabel:setBorderColor('#4c4c4cff')
    uiInspectorLabel:setBorderWidth(1)
    uiInspectorLabel:setTextAlign(AlignLeft)
    uiInspectorLabel:setTextOffset(topoint('4 3'))
    uiInspectorLabel:setPhantom(true)
    uiInspectorLabel:hide()
end

local function moveInspectorLabel()
    if not uiInspectorLabel or not uiInspectorLabel:isVisible() then
        return
    end

    local pos = g_window.getMousePosition()
    local windowSize = g_window.getSize()
    local labelSize = uiInspectorLabel:getSize()

    pos.x = pos.x + 12
    pos.y = pos.y + 12

    if windowSize.width - (pos.x + labelSize.width) < 10 then
        pos.x = pos.x - labelSize.width - 16
    end

    if windowSize.height - (pos.y + labelSize.height) < 10 then
        pos.y = pos.y - labelSize.height - 16
    end

    uiInspectorLabel:setPosition(pos)
end

local function updateInspectorLabel()
    if not uiInspectorEnabled or not rootWidget then
        return
    end

    local mousePos = g_window.getMousePosition()
    local ok, widget = pcall(function()
        return rootWidget:recursiveGetChildByPos(mousePos, false)
    end)
    if not ok then
        return
    end

    if not widget then
        uiInspectorLastWidget = nil
        if uiInspectorLabel then
            uiInspectorLabel:hide()
        end
        return
    end

    ensureInspectorLabel()

    if widget ~= uiInspectorLastWidget then
        uiInspectorLastWidget = widget

        local okParent, parent = pcall(function()
            return widget:getParent()
        end)
        if not okParent then
            parent = nil
        end
        local text = 'UI Inspector\n' ..
            getInspectorWidgetInfo(widget) .. '\n' ..
            'parent: ' .. getInspectorWidgetInfo(parent) .. '\n' ..
            'left click: print hierarchy'

        uiInspectorLabel:setText(text)
        uiInspectorLabel:resizeToText()
        uiInspectorLabel:resize(uiInspectorLabel:getWidth() + 8, uiInspectorLabel:getHeight() + 6)
    end

    moveInspectorLabel()
    uiInspectorLabel:show()
    uiInspectorLabel:raise()
end

local function onInspectorMouseMove()
    updateInspectorLabel()
end

local function onInspectorMousePress(widget, mousePos, mouseButton)
    if not uiInspectorEnabled or mouseButton ~= MouseLeftButton then
        return false
    end

    local ok, target = pcall(function()
        return rootWidget:recursiveGetChildByPos(mousePos, false)
    end)
    if not ok then
        return false
    end
    if not target then
        return false
    end

    pcolored('[ui_inspector] ' .. getInspectorWidgetInfo(target), 'yellow')
    pcolored(buildInspectorHierarchy(target), 'white')
    return false
end

local function setUiInspectorEnabled(enabled)
    if enabled == uiInspectorEnabled then
        return
    end

    if not rootWidget then
        pcolored('ui_inspector is unavailable: rootWidget not ready.', 'red')
        return
    end

    uiInspectorEnabled = enabled
    if uiInspectorEnabled then
        ensureInspectorLabel()
        connect(rootWidget, {
            onMouseMove = onInspectorMouseMove,
            onMousePress = onInspectorMousePress
        })
        pcolored('UI inspector enabled. Hover widgets to inspect and left click to print hierarchy.', 'green')
        updateInspectorLabel()
    else
        disconnect(rootWidget, {
            onMouseMove = onInspectorMouseMove,
            onMousePress = onInspectorMousePress
        })

        uiInspectorLastWidget = nil
        if uiInspectorLabel and not uiInspectorLabel:isDestroyed() then
            uiInspectorLabel:hide()
        end
        pcolored('UI inspector disabled.', 'yellow')
    end
end

function ui_inspector(state)
    local parsed = parseInspectorToggle(state)
    if parsed == 'invalid' then
        pcolored('usage: ui_inspector [on|off|toggle]', 'red')
        return
    end

    if parsed == nil then
        parsed = not uiInspectorEnabled
    end

    setUiInspectorEnabled(parsed)
end

function draw_ui_inspector(state)
    ui_inspector(state)
end

function inspector(state)
    ui_inspector(state)
end

function hide_map()
    modules.game_interface.getMapPanel():hide()
end

function show_map()
    modules.game_interface.getMapPanel():show()
end

function live_textures_reload()
    g_textures.liveReload()
end

local pinging = false
local function pingBack(ping)
    if ping < 300 then
        color = 'green'
    elseif ping < 600 then
        color = 'yellow'
    else
        color = 'red'
    end
    pcolored(g_game.getWorldName() .. ' => ' .. ping .. ' ms', color)
end
function ping()
    if pinging then
        pcolored('Ping stopped.')
        g_game.setPingDelay(1000)
        disconnect(g_game, 'onPingBack', pingBack)
    else
        if not (g_game.getFeature(GameClientPing) or g_game.getFeature(GameExtendedClientPing)) then
            pcolored('this server does not support ping', 'red')
            return
        elseif not g_game.isOnline() then
            pcolored('ping command is only allowed when online', 'red')
            return
        end

        pcolored('Starting ping...')
        g_game.setPingDelay(0)
        connect(g_game, 'onPingBack', pingBack)
    end
    pinging = not pinging
end

function clear()
    modules.client_terminal.clear()
end

function ls(path)
    path = path or '/'
    local files = g_resources.listDirectoryFiles(path)
    for k, v in pairs(files) do
        if g_resources.directoryExists(path .. v) then
            pcolored(path .. v, 'blue')
        else
            pcolored(path .. v)
        end
    end
end

function about_version()
    pcolored(g_app.getName() .. ' ' .. g_app.getVersion() .. '\n' .. 'Rev  ' .. g_app.getBuildRevision() .. ' (' ..
                 g_app.getBuildCommit() .. ')\n' .. 'Built on ' .. g_app.getBuildDate())
end

function about_graphics()
    pcolored('Vendor ' .. g_graphics.getVendor())
    pcolored('Renderer' .. g_graphics.getRenderer())
    pcolored('Version' .. g_graphics.getVersion())
end

function about_modules()
    for k, m in pairs(g_modules.getModules()) do
        local loadedtext
        if m:isLoaded() then
            pcolored(m:getName() .. ' => loaded', 'green')
        else
            pcolored(m:getName() .. ' => not loaded', 'red')
        end
    end
end
