local IMBUEMENTTRACKER_SLOTS = {
    INVENTORYSLOT_HEAD = 1,
    INVENTORYSLOT_BACKPACK = 3,
    INVENTORYSLOT_ARMOR = 4,
    INVENTORYSLOT_RIGHT = 5,
    INVENTORYSLOT_LEFT = 6,
    INVENTORYSLOT_FEET = 8
}

local IMBUEMENTTRACKER_FILTERS = {
    ["showLessThan1h"] = true,
    ["showBetween1hAnd3h"] = true,
    ["showMoreThan3h"] = true,
    ["showNoImbuements"] = true
}

local TRACKED_SLOT_LOOKUP = {}
for _, slot in pairs(IMBUEMENTTRACKER_SLOTS) do
    TRACKED_SLOT_LOOKUP[slot] = true
end

local filtersCache = nil
local trackedWidgetsBySlot = {}

imbuementTrackerButton = nil
imbuementTrackerMenuButton = nil

function loadFilters()
    if filtersCache then
        return filtersCache
    end

    local settings = g_settings.getNode('ImbuementTracker')
    local storedFilters = settings and settings['filters'] or nil
    if not storedFilters then
        filtersCache = table.copy(IMBUEMENTTRACKER_FILTERS)
        return filtersCache
    end

    filtersCache = table.copy(IMBUEMENTTRACKER_FILTERS)
    for filter, value in pairs(storedFilters) do
        if filtersCache[filter] ~= nil then
            filtersCache[filter] = value
        end
    end
    return filtersCache
end

function saveFilters()
    g_settings.mergeNode('ImbuementTracker', { ['filters'] = loadFilters() })
end

function getFilter(filter)
    local filters = loadFilters()
    return filters[filter] or false
end

function setFilter(filter)
    local filters = loadFilters()
    local value = filters[filter]
    if value == nil then
        return false
    end
    
    filters[filter] = not value
    g_settings.mergeNode('ImbuementTracker', { ['filters'] = filters })
    g_game.imbuementDurations(imbuementTrackerButton:isOn())
end

function initialize()
    g_ui.importStyle('imbuementtracker')
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onUpdateImbuementTracker = onUpdateImbuementTracker
    })
    
    imbuementTracker = g_ui.createWidget('ImbuementTracker', modules.game_interface.getRightPanel())
    
    -- Set minimum height for imbuement tracker window
    imbuementTracker:setContentMinimumHeight(80)

    -- Hide toggleFilterButton and adjust button positioning
    local toggleFilterButton = imbuementTracker:recursiveGetChildById('toggleFilterButton')
    if toggleFilterButton then
        toggleFilterButton:setVisible(false)
        toggleFilterButton:setOn(false)
    end
    
    -- Hide newWindowButton
    local newWindowButton = imbuementTracker:recursiveGetChildById('newWindowButton')
    if newWindowButton then
        newWindowButton:setVisible(false)
    end

    -- Make sure contextMenuButton is visible and set up its positioning and click handler
    local contextMenuButton = imbuementTracker:recursiveGetChildById('contextMenuButton')
    local lockButton = imbuementTracker:recursiveGetChildById('lockButton')
    local minimizeButton = imbuementTracker:recursiveGetChildById('minimizeButton')
    
    if contextMenuButton then
        contextMenuButton:setVisible(true)
        
        -- Position contextMenuButton where toggleFilterButton was (similar to containers without upButton)
        if minimizeButton then
            contextMenuButton:breakAnchors()
            contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
            contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
            contextMenuButton:setMarginRight(7)
            contextMenuButton:setMarginTop(0)
        end
        
        -- Position lockButton to the left of contextMenu
        if lockButton then
            lockButton:breakAnchors()
            lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
            lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
            lockButton:setMarginRight(2)
            lockButton:setMarginTop(0)
        end
        
        contextMenuButton.onClick = function(widget, mousePos, mouseButton)
            local menu = g_ui.createWidget('ImbuementTrackerMenu')
            menu:setGameMenu(true)
            for _, choice in ipairs(menu:getChildren()) do
                local choiceId = choice:getId()
                choice:setChecked(getFilter(choiceId))
                choice.onCheckChange = function()
                    setFilter(choiceId)
                    menu:destroy()
                end
            end
            menu:display(mousePos)
            return true
        end
    end

    imbuementTracker:setup()
    imbuementTracker:hide()
end

function onMiniWindowOpen()
    if imbuementTrackerButton then
        imbuementTrackerButton:setOn(true)
    end
end

function onMiniWindowClose()
    if imbuementTrackerButton then
        imbuementTrackerButton:setOn(false)
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onUpdateImbuementTracker = onUpdateImbuementTracker
    })

    if imbuementTrackerButton then
        imbuementTrackerButton:destroy()
        imbuementTrackerButton = nil
    end
    filtersCache = nil
    trackedWidgetsBySlot = {}
    imbuementTracker:destroy()
end

function toggle()
    if imbuementTrackerButton:isOn() then
        imbuementTrackerButton:setOn(false)
        imbuementTracker:close()
    else
        if not imbuementTracker:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(imbuementTracker, imbuementTracker:getMinimumHeight())
            if not panel then
                return
            end

            panel:addChild(imbuementTracker)
        end
        imbuementTracker:open()
        imbuementTrackerButton:setOn(true)
        -- updateHeight()
    end
    g_game.imbuementDurations(imbuementTrackerButton:isOn())
end

local function getTrackedItems(items)
    local trackedItems = {}
    for _, item in ipairs(items) do
        if TRACKED_SLOT_LOOKUP[item['slot']] then
            trackedItems[#trackedItems + 1] = item
        end
    end
    return trackedItems
end

local function setDuration(label, duration)
    if duration == 0 then
        label:setVisible(false)
        return
    end
    local hours = math.floor(duration / 3600)
    local minutes = math.floor(duration / 60 - (hours * 60))
    if duration < 60 then
        label:setColor('#ff0000')
        label:setText(string.format('%2.fs', duration))
    elseif duration < 3600 then
        label:setColor('#ff0000')
        label:setText(string.format('%2.fm', minutes))
    elseif duration < 10800 then
        label:setColor('#ffff00')
        label:setText(string.format('%2.fh%02.f', hours, minutes))
    else
        label:setColor('#ffffff')
        label:setText(string.format('%02.fh', hours))
    end
    label:setVisible(true)
end

local function getItemKey(item)
    if not item then
        return 'nil'
    end

    local itemId = item.getId and item:getId() or 0
    local itemCount = item.getCountOrSubType and item:getCountOrSubType() or (item.getCount and item:getCount() or 0)
    local itemTier = item.getTier and item:getTier() or 0
    return string.format('%s:%s:%s', itemId, itemCount, itemTier)
end

local function getActiveSlotsMap(itemSlots)
    local activeSlots = {}
    for _, imbuementSlot in pairs(itemSlots or {}) do
        if type(imbuementSlot) == 'table' and imbuementSlot['id'] ~= nil then
            activeSlots[imbuementSlot['id']] = imbuementSlot
        end
    end
    return activeSlots
end

local function getMaxDuration(activeSlots)
    local maxDuration = 0
    for _, imbuementSlot in pairs(activeSlots) do
        local duration = imbuementSlot['duration'] or 0
        if duration > maxDuration then
            maxDuration = duration
        end
    end
    return maxDuration
end

local function shouldShowItem(item, activeSlots, maxDuration)
    local hasActiveImbuements = next(activeSlots) ~= nil and maxDuration > 0
    local hasSlots = (item['totalSlots'] or 0) > 0

    if not hasActiveImbuements and hasSlots and not getFilter('showNoImbuements') then
        return false
    end

    if not hasActiveImbuements and not hasSlots then
        return false
    end

    if maxDuration > 0 and maxDuration < 3600 and not getFilter('showLessThan1h') then
        return false
    end

    if maxDuration >= 3600 and maxDuration < 10800 and not getFilter('showBetween1hAnd3h') then
        return false
    end

    if maxDuration >= 10800 and not getFilter('showMoreThan3h') then
        return false
    end

    return true
end

local function ensureTrackedItemWidget(slot)
    local trackedItem = trackedWidgetsBySlot[slot]
    if trackedItem then
        return trackedItem
    end

    trackedItem = g_ui.createWidget('InventoryItem', imbuementTracker.contentsPanel)
    trackedItem:setId('trackedItem' .. slot)
    trackedItem.item:setVirtual(true)
    trackedItem.itemKey = nil
    trackedItem.renderKey = nil
    trackedWidgetsBySlot[slot] = trackedItem
    return trackedItem
end

local function buildRenderKey(item, activeSlots)
    local renderKey = {
        getItemKey(item['item']),
        tostring(item['totalSlots'] or 0)
    }

    local totalSlots = item['totalSlots'] or 0
    for slotIndex = 0, totalSlots - 1 do
        local imbuementSlot = activeSlots[slotIndex]
        if imbuementSlot then
            renderKey[#renderKey + 1] = string.format('%d:%d:%d:%d', slotIndex, imbuementSlot['iconId'] or 0, imbuementSlot['duration'] or 0, imbuementSlot['state'] and 1 or 0)
        else
            renderKey[#renderKey + 1] = string.format('%d:0:0:0', slotIndex)
        end
    end

    return table.concat(renderKey, '|')
end

local function updateTrackedItemWidget(trackedItem, item, activeSlots)
    local itemKey = getItemKey(item['item'])
    if trackedItem.itemKey ~= itemKey then
        trackedItem.item:setItem(item['item'])
        ItemsDatabase.setTier(trackedItem.item, trackedItem.item:getItem())
        trackedItem.item:setVirtual(true)
        trackedItem.itemKey = itemKey
    end

    local totalSlots = item['totalSlots'] or 0
    local slotsPanel = trackedItem.imbuementSlots

    for i = slotsPanel:getChildCount(), 1, -1 do
        local child = slotsPanel:getChildByIndex(i)
        local childId = child:getId() or ''
        local childSlot = tonumber(childId:match('^slot(%d+)$'))
        if childSlot == nil or childSlot >= totalSlots then
            child:destroy()
        end
    end

    for slotIndex = 0, totalSlots - 1 do
        local slotWidget = slotsPanel:getChildById('slot' .. slotIndex)
        if not slotWidget then
            slotWidget = g_ui.createWidget('ImbuementSlot', slotsPanel)
            slotWidget:setId('slot' .. slotIndex)
            slotWidget:setMarginLeft(3)
        end

        local imbuementSlot = activeSlots[slotIndex]
        if imbuementSlot then
            slotWidget:setImageSource('/images/game/imbuing/icons/' .. imbuementSlot['iconId'])
            setDuration(slotWidget.duration, imbuementSlot['duration'])
        else
            slotWidget:setImageSource('/images/game/imbuing/slot_inactive')
            slotWidget.duration:setVisible(false)
        end
    end
end

function onUpdateImbuementTracker(items)
    local trackedItems = getTrackedItems(items)
    table.sort(trackedItems, function(a, b)
        return (a['slot'] or 0) < (b['slot'] or 0)
    end)

    local seenSlots = {}
    local orderIndex = 1
    for _, item in ipairs(trackedItems) do
        local slot = item['slot']
        seenSlots[slot] = true

        local activeSlots = getActiveSlotsMap(item['slots'])
        local maxDuration = getMaxDuration(activeSlots)
        local show = shouldShowItem(item, activeSlots, maxDuration)

        local trackedItem = ensureTrackedItemWidget(slot)
        local renderKey = buildRenderKey(item, activeSlots)
        if trackedItem.renderKey ~= renderKey then
            updateTrackedItemWidget(trackedItem, item, activeSlots)
            trackedItem.renderKey = renderKey
        end

        trackedItem:setVisible(show)
        imbuementTracker.contentsPanel:moveChildToIndex(trackedItem, orderIndex)
        orderIndex = orderIndex + 1
    end

    for slot, trackedItem in pairs(trackedWidgetsBySlot) do
        if not seenSlots[slot] then
            trackedItem:destroy()
            trackedWidgetsBySlot[slot] = nil
        end
    end
end

function onGameStart()
    if g_game.getClientVersion() >= 1100 then
        imbuementTrackerButton = modules.game_mainpanel.addToggleButton('imbuementTrackerButton', tr('Imbuement Tracker'), '/images/options/button_imbuementtracker', toggle)
        g_game.imbuementDurations(imbuementTrackerButton:isOn())
        imbuementTracker:setupOnStart()
        loadFilters()
    end
end

function onGameEnd()
    imbuementTracker.contentsPanel:destroyChildren()
    trackedWidgetsBySlot = {}
    saveFilters()
end
