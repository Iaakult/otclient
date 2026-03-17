local standModeBox
local chaseModeBox
local vBotQuickButton = nil
local optionsAmount = 0
local specialsAmount = 0
local storeAmount = 0

local chaseModeRadioGroup
local controlButton1400 = nil
local optionPanel = nil
local buttonConfigs = {}
local buttonOrder = {}
local COLORS = {
    BASE_1 = "#484848",
    BASE_2 = "#414141"
}

local PANEL_CONSTANTS = {
    ICON_WIDTH = 18,
    ICON_HEIGHT = 20,
    MAX_ICONS_PER_ROW = {
        OPTIONS = 5,
        SPECIALS = 2,
        STORE = 1
    },
    MULTI_STORE_HEIGHT = 20,
    PANEL_SPACING = 2,
    STORE_OPTIONS_GAP = 10,
    STORE_BASE_HEIGHT = 20,
    HEIGHT_EXTRA_ONPANEL = 0,
    HEIGHT_EXTRA_SHRINK = 5
}

local optionsShrink = false

local function forceControlButtonVisible(buttonId, tooltip, placeLast)
    local config = g_settings.getNode('control_buttons') or { buttons = {}, order = {} }
    config.buttons = config.buttons or {}
    config.order = config.order or {}

    local changed = false
    if not config.buttons[buttonId] then
        config.buttons[buttonId] = { visible = true, tooltip = tooltip }
        changed = true
    elseif config.buttons[buttonId].visible ~= true then
        config.buttons[buttonId].visible = true
        changed = true
    end

    local orderIds = {}
    local orderKeys = {}
    for key in pairs(config.order) do
        local numericKey = tonumber(key)
        if numericKey then
            table.insert(orderKeys, numericKey)
        end
    end
    table.sort(orderKeys)
    for _, key in ipairs(orderKeys) do
        local id = config.order[tostring(key)]
        if id then
            table.insert(orderIds, id)
        end
    end

    local currentIndex = nil
    for i, id in ipairs(orderIds) do
        if id == buttonId then
            currentIndex = i
            break
        end
    end

    if currentIndex == nil then
        table.insert(orderIds, buttonId)
        changed = true
    elseif placeLast and currentIndex ~= #orderIds then
        table.remove(orderIds, currentIndex)
        table.insert(orderIds, buttonId)
        changed = true
    end

    if changed then
        config.order = {}
        for i, id in ipairs(orderIds) do
            config.order[tostring(i)] = id
        end
    end

    if changed then
        g_settings.setNode('control_buttons', config)
        g_settings.save()
    end
end

local function toggleVBotQuick()
    if not modules.game_bot then
        g_modules.ensureModuleLoaded('game_bot')
    end

    if modules.game_bot and modules.game_bot.toggle then
        modules.game_bot.toggle()
        return
    end

    displayInfoBox(tr('vBot'), tr('Nao foi possivel carregar o modulo game_bot.'))
end

local function calculatePanelHeight(panel, max_icons_per_row)
    if not panel or (panel.isDestroyed and panel:isDestroyed()) or (panel.isVisible and not panel:isVisible()) then
        return 0, 0
    end

    local function rowsToHeight(rows)
        if rows <= 0 then
            return 0
        end
        return (rows * PANEL_CONSTANTS.ICON_HEIGHT) + ((rows - 1) * PANEL_CONSTANTS.PANEL_SPACING)
    end

    if panel and panel:getId() == 'specials' then
        local gridPanel = panel:getChildById('specialsGrid')
        local widePanel = panel:getChildById('specialsWide')
        if gridPanel and widePanel then
            local gridVisible = 0
            for _, icon in ipairs(gridPanel:getChildren()) do
                if icon:isVisible() then
                    gridVisible = gridVisible + 1
                end
            end
            local wideVisible = 0
            for _, icon in ipairs(widePanel:getChildren()) do
                if icon:isVisible() then
                    wideVisible = wideVisible + 1
                end
            end

            local gridRows = math.ceil(gridVisible / (max_icons_per_row > 0 and max_icons_per_row or 1))
            local totalRows = gridRows + wideVisible
            if totalRows <= 0 then
                return 0, 0
            end
            local height = rowsToHeight(totalRows)
            return height, gridVisible + wideVisible
        end
    end

    local icon_count = 0
    for _, icon in ipairs(panel:getChildren()) do
        if icon:isVisible() then
            icon_count = icon_count + 1
        end
    end
    local rows = math.ceil(icon_count / max_icons_per_row)
    local height = rowsToHeight(rows)
    return height, icon_count
end

function reloadMainPanelSizes()
    local main_panel = modules.game_interface.getMainRightPanel()
    local right_panel = modules.game_interface.getRightPanel()
    if not main_panel or not right_panel then
        return
    end
    local total_height = 1
    for _, panel in ipairs(main_panel:getChildren()) do
        if panel.panelHeight ~= nil then
            if panel:isVisible() then
                panel:setHeight(panel.panelHeight)
                total_height = total_height + panel.panelHeight
                if panel:getId() == 'mainoptionspanel' then
                    if panel:isOn() then
                        local options_panel = optionsController.ui.onPanel.options
                        local options_height, options_count =
                            calculatePanelHeight(options_panel, PANEL_CONSTANTS.MAX_ICONS_PER_ROW.OPTIONS)
                        local specials_panel = optionsController.ui.onPanel.specials
                        local specials_height, specials_count =
                            calculatePanelHeight(specials_panel, PANEL_CONSTANTS.MAX_ICONS_PER_ROW.SPECIALS)
                        local store_panel = panel.onPanel.store
                        local store_height, store_count = calculatePanelHeight(store_panel,
                            PANEL_CONSTANTS.MAX_ICONS_PER_ROW.STORE)
                        local content_height = math.max(options_height, specials_height)
                        local combined_height = math.max(0, store_height - PANEL_CONSTANTS.STORE_BASE_HEIGHT)
                        if content_height > 0 then
                            combined_height = combined_height + PANEL_CONSTANTS.STORE_OPTIONS_GAP + content_height
                        end
                        combined_height = combined_height + PANEL_CONSTANTS.HEIGHT_EXTRA_ONPANEL
                        store_panel:setHeight(store_height)
                        panel:setHeight(combined_height + panel.panelHeight)
                        total_height = total_height + combined_height
                    else
                        total_height = total_height + PANEL_CONSTANTS.HEIGHT_EXTRA_SHRINK
                    end
                end
            else
                panel:setHeight(0)
            end
        end
    end
    main_panel:setHeight(total_height)
    right_panel:fitAll()
end

local function refreshOptionsSizes()
    if optionsShrink then
        optionsController.ui:setOn(true)
        optionsController.ui.offPanel:hide()
        optionsController.ui.onPanel.options:hide()
        optionsController.ui.onPanel.specials:hide()
        local separator = optionsController.ui.onPanel:recursiveGetChildById('storeSeparator')
        if separator then
            separator:hide()
        end
    else
        optionsController.ui:setOn(true)
        optionsController.ui.offPanel:hide()
        optionsController.ui.onPanel.options:show()
        optionsController.ui.onPanel.specials:show()
        local separator = optionsController.ui.onPanel:recursiveGetChildById('storeSeparator')
        if separator then
            separator:show()
        end
    end
    reloadMainPanelSizes()
end

local function createButton_large(id, description, image, callback, special, front)
    local panel = optionsController.ui.onPanel.store

    storeAmount = storeAmount + 1

    local button = panel:getChildById(id)
    if not button then
        button = g_ui.createWidget('largeToggleButton')
        if front then
            panel:insertChild(1, button)
        else
            panel:addChild(button)
        end
    end
    button:setId(id)
    button:setTooltip(description)
    button:setImageSource(image)
    button:setImageClip('0 0 108 20')
    button.onMouseRelease = function(widget, mousePos, mouseButton)
        if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
            callback()
            return true
        end
    end

    return button
end

local function createButton(id, description, image, callback, special, front, index)
    local panel
    if special then
        local specialsPanel = optionsController.ui.onPanel.specials
        panel = specialsPanel and specialsPanel:getChildById('specialsGrid') or specialsPanel
        specialsAmount = specialsAmount + 1
    else
        panel = optionsController.ui.onPanel.options
        optionsAmount = optionsAmount + 1
    end

    local button = panel:getChildById(id)
    if not button then
        button = g_ui.createWidget('MainToggleButton')
        if front then
            panel:insertChild(1, button)
        else
            panel:addChild(button)
        end
    end

    button:setId(id)
    button:setTooltip(description)
    button:setSize('20 20')
    button:setImageSource(image)
    button:setImageClip('0 0 20 20')
    button.onMouseRelease = function(widget, mousePos, mouseButton)
        if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
            callback()
            return true
        end
    end
    local shouldReorder = false
    if not button.index and type(index) == 'number' then
        button.index = index or 1000
        shouldReorder = true
    end

    if shouldReorder then
        local children = panel:getChildren()
        table.sort(children, function(a, b)
            return (a.index or 1000) < (b.index or 1000)
        end)
        panel:reorderChildren(children)
    end

    refreshOptionsSizes()
    return button
end

optionsController = Controller:new()
optionsController:setUI('mainoptionspanel', modules.game_interface.getMainRightPanel())

function optionsController:onInit()
    createButton_large('Store shop', tr('Store shop'), '/images/options/store_large', toggleStore,
    false, 8)

    local storePanel = optionsController.ui and optionsController.ui.onPanel and optionsController.ui.onPanel.store
    if storePanel then
        local wrapper = storePanel:getChildById('battlepassStoreButton')
        if not wrapper then
            wrapper = g_ui.createWidget('BattlePassStoreButtonWrapper', storePanel)
            wrapper:setId('battlepassStoreButton')
        end
        if wrapper and wrapper.setMarginTop then
            wrapper:setMarginTop(4)
        end
        local button = wrapper and wrapper.getChildById and (wrapper:getChildById('battlepassButton') or wrapper:getChildById('button')) or nil
        if button then
            button:setTooltip(tr('Battle Pass'))
            button:setText(tr('Battle Pass'))
            button:setFont('verdana-11px-antialised')
            if button.setIcon then
                button:setIcon('/images/topbuttons/archpass')
            end
            button.onMouseRelease = function(widget, mousePos, mouseButton)
                if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                    if modules.game_battlepass and modules.game_battlepass.m_BattlepassFunctions and modules.game_battlepass.m_BattlepassFunctions.open then
                        modules.game_battlepass.m_BattlepassFunctions.open()
                    end
                    return true
                end
            end
        end

        -- Helper button (game_helper mod)
        local helperWrapper = storePanel:getChildById('helperStoreButton')
        if not helperWrapper then
            helperWrapper = g_ui.createWidget('BattlePassStoreButtonWrapper', storePanel)
            helperWrapper:setId('helperStoreButton')
        end
        if helperWrapper then
            if helperWrapper.setMarginTop then
                helperWrapper:setMarginTop(4)
            end
            local helperBtn = helperWrapper.getChildById and (helperWrapper:getChildById('battlepassButton') or helperWrapper:getChildById('button')) or nil
            if helperBtn then
                helperBtn:setTooltip(tr('Helper'))
                helperBtn:setText(tr('Helper'))
                helperBtn:setFont('verdana-11px-antialised')
                if helperBtn.setIcon then
                    helperBtn:setIcon('/images/icons/icon-healing')
                end
                helperBtn.onMouseRelease = function(widget, mousePos, mouseButton)
                    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                        if modules.game_helper and modules.game_helper.show then
                            modules.game_helper.show()
                        elseif modules.game_helper and modules.game_helper.toggle then
                            modules.game_helper.toggle()
                        end
                        return true
                    end
                end
            end
        end

        -- Guild Management button (game_guildmanagement mod)
        local guildWrapper = storePanel:getChildById('guildManagementStoreButton')
        if not guildWrapper then
            guildWrapper = g_ui.createWidget('BattlePassStoreButtonWrapper', storePanel)
            guildWrapper:setId('guildManagementStoreButton')
        end
        if guildWrapper then
            if guildWrapper.setMarginTop then
                guildWrapper:setMarginTop(4)
            end
            if guildWrapper.setMarginBottom then
                guildWrapper:setMarginBottom(4)
            end
            local guildBtn = guildWrapper.getChildById and (guildWrapper:getChildById('battlepassButton') or guildWrapper:getChildById('button')) or nil
            if guildBtn then
                guildBtn:setTooltip(tr('Guild Management'))
                guildBtn:setText(tr('Guilds'))
                guildBtn:setFont('verdana-11px-antialised')
                if guildBtn.setIcon then
                    guildBtn:setIcon('/images/icons/icon_shielding')
                end
                guildBtn.onMouseRelease = function(widget, mousePos, mouseButton)
                    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                        if modules.game_guildmanagement and modules.game_guildmanagement.toggle then
                            modules.game_guildmanagement.toggle()
                        end
                        return true
                    end
                end
            end
        end
    end
    if not optionPanel then
        optionPanel = g_ui.loadUI('option_control_buttons', modules.client_options:getPanel())
        modules.client_options.addButton("Interface", "Control Buttons", optionPanel, function() initControlButtons() end)
    end

    if not vBotQuickButton then
        vBotQuickButton = createButton('vBotQuickButton', tr('vBot'), '/images/options/button_vbot', toggleVBotQuick, false, false, 99999)
    end

    forceControlButtonVisible('vBotQuickButton', tr('vBot'), true)
    if vBotQuickButton then
        vBotQuickButton:setVisible(true)
    end
end

function toggleStore()
    if  g_game.getFeature(GameIngameStore) then
        modules.game_store.toggle() -- cipsoft packets
    else
        modules.game_shop.toggle() -- custom
    end
end

function optionsController:onTerminate()
    if optionPanel then
        optionPanel:destroy()
        optionPanel = nil
        modules.client_options.removeButton("Interface", "Control Buttons")  -- hot reload
    end
    if controlButton1400 then
        controlButton1400:destroy()
        controlButton1400 = nil
    end
    if vBotQuickButton then
        vBotQuickButton:destroy()
        vBotQuickButton = nil
    end
end

function optionsController:onGameStart()
    optionsShrink = g_settings.getBoolean('mainpanel_shrink_options')
    refreshOptionsSizes()
    modules.game_interface.setupOptionsMainButton()
    modules.client_options.setupOptionsMainButton()
    local getOptionsPanel = optionsController.ui.onPanel.options
    local children = getOptionsPanel:getChildren()
    table.sort(children, function(a, b)
        return (a.index or 1000) < (b.index or 1000)
    end)
    getOptionsPanel:reorderChildren(children)
    optionsController:scheduleEvent(function()
        if optionPanel then
            local config = loadButtonConfig()
            buttonConfigs = config.buttons or {}
            buttonOrder = config.order or {}
            local optionsPanel = optionsController.ui.onPanel.options
            if optionsPanel then
                for _, button in ipairs(optionsPanel:getChildren()) do
                    local id = button:getId()
                    if id and buttonConfigs[id] then
                        button:setVisible(buttonConfigs[id].visible)
                    end
                end
                reorderButtons()
                updateDisplayedButtonsList()
                updateAvailableButtonsList()
                reloadMainPanelSizes()
            end
        end

        forceControlButtonVisible('vBotQuickButton', tr('vBot'), true)
        local vbotBtn = getButton('vBotQuickButton')
        if vbotBtn then
            vbotBtn:setVisible(true)
        end
    end, 50, "onGameStart")
    if g_game.getClientVersion() >= 1400 and not controlButton1400 then
        controlButton1400 = modules.game_mainpanel.addToggleButton('controButtons', tr('Manage control buttons'),
        '/images/options/button_control', function() modules.client_options.openOptionsCategory("Interface", "Control Buttons") end, false, 1)
        controlButton1400:setOn(false)
    end
end

function optionsController:onGameEnd()
end

function changeOptionsSize()
    optionsShrink = not optionsShrink
    g_settings.set('mainpanel_shrink_options', optionsShrink)
    refreshOptionsSizes()
end

function addToggleButton(id, description, image, callback, front, index)
    return createButton(id, description, image, callback, false, front, index)
end

function addSpecialToggleButton(id, description, image, callback, front, index)
    return createButton(id, description, image, callback, true, front, index)
end

function addStoreButton(id, description, image, callback, front)
    return createButton_large(id, description, image, callback, true, front)
end

function getButton(id)
    return optionsController.ui.onPanel.options:recursiveGetChildById(id)
end

function toggleExtendedViewButtons(extended)
    local optionsPanel = optionsController.ui.onPanel.options
    local specialsPanel = optionsController.ui.onPanel.store
    local rightGamePanel = modules.client_topmenu.getRightGameButtonsPanel()
    if extended then
        local optionChildren = optionsPanel:getChildren()
        for _, button in ipairs(optionChildren) do
            if not button:isDestroyed() then
                button.originalPanel = "options"
                rightGamePanel:addChild(button)
            end
        end
        local specialChildren = specialsPanel:getChildren()
        for _, button in ipairs(specialChildren) do
            if not button:isDestroyed() then
                button.originalPanel = "specials"
                rightGamePanel:addChild(button)
            end
        end
        optionsController.ui:hide()
        optionsController.ui:setHeight(0)
    else
        local children = rightGamePanel:getChildren()
        for _, button in ipairs(children) do
            if not button:isDestroyed() then
                if button.originalPanel == "options" then
                    optionsPanel:addChild(button)
                elseif button.originalPanel == "specials" then
                    specialsPanel:addChild(button)
                end
            end
        end
        optionsController.ui:show()
        optionsController.ui:setHeight(28)
        local mainRightPanel = modules.game_interface.getMainRightPanel()
        if mainRightPanel:hasChild(optionsController.ui) then
            mainRightPanel:moveChildToIndex(optionsController.ui, 4)
        end
    end
    refreshOptionsSizes()
end

function saveButtonConfig()
    local config = {
        buttons = {},
        order = {}
    }
    for id, buttonConfig in pairs(buttonConfigs) do
        if type(id) == "string" and type(buttonConfig) == "table" then
            config.buttons[id] = {
                visible = buttonConfig.visible,
                tooltip = buttonConfig.tooltip
            }
        end
    end
    for i, id in ipairs(buttonOrder) do
        config.order[tostring(i)] = id
    end
    g_settings.setNode('control_buttons', config)
end

function loadButtonConfig()
    local config = g_settings.getNode('control_buttons') or {
        buttons = {},
        order = {}
    }
    local orderArray = {}
    if config.order then
        local keys = {}
        for k in pairs(config.order) do
            table.insert(keys, tonumber(k))
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            table.insert(orderArray, config.order[tostring(k)])
        end
    end

    return {
        buttons = config.buttons or {},
        order = orderArray
    }
end

local function updateList(listWidget, isVisibleList)
    if not g_game.isOnline() or not listWidget then
        return
    end
    local focusedItem = listWidget:getFocusedChild()
    local focusedId = focusedItem and focusedItem.buttonId
    local existingItems = {}
    for _, child in ipairs(listWidget:getChildren()) do
        existingItems[child.buttonId] = child
    end
    local displayButtons = {}
    for id, config in pairs(buttonConfigs) do
        if (config.visible == true) == isVisibleList then
            table.insert(displayButtons, {
                id = id,
                config = config
            })
        end
    end
    if isVisibleList then
        table.sort(displayButtons, function(a, b)
            local indexA = table.find(buttonOrder, a.id) or 999
            local indexB = table.find(buttonOrder, b.id) or 999
            return indexA < indexB
        end)
    end
    for buttonId, item in pairs(existingItems) do
        local shouldBeInList = false
        for _, buttonData in ipairs(displayButtons) do
            if buttonData.id == buttonId then
                shouldBeInList = true
                break
            end
        end
        if not shouldBeInList then
            item:destroy()
            existingItems[buttonId] = nil
        end
    end

    local currentChildren = {}
    for i, buttonData in ipairs(displayButtons) do
        local buttonId = buttonData.id
        local buttonConfig = buttonData.config
        local item = existingItems[buttonId]
        if not item then
            item = g_ui.createWidget('HotkeyListLabel', listWidget)
            item:setId(buttonId)
            item.buttonId = buttonId
            item:setText(buttonConfig.tooltip)
            item:setTextAlign(AlignLeft)
        end
        if not item:isFocused() then
            item:setBackgroundColor((i % 2 == 0) and COLORS.BASE_1 or COLORS.BASE_2)
        end

        table.insert(currentChildren, item)
    end
    listWidget:reorderChildren(currentChildren)
    if focusedId then
        for _, child in ipairs(listWidget:getChildren()) do
            if child.buttonId == focusedId then
                child:focus()
                break
            end
        end
    end
end

function updateDisplayedButtonsList()
    updateList(optionPanel.panelDisplayedButtons.displayedButtonsList, true)
end

function updateAvailableButtonsList()
    updateList(optionPanel.panelAvailableButtons.displayedAvailableButtonsList, false)
end

function moveToAvailable()
    local displayedList = optionPanel.panelDisplayedButtons.displayedButtonsList
    local selectedItem = displayedList:getFocusedChild()

    if not selectedItem then
        return
    end

    local buttonId = selectedItem.buttonId
    local optionsPanel = optionsController.ui.onPanel.options
    local button = optionsPanel:getChildById(buttonId)
    if button then
        button:setVisible(false)
        buttonConfigs[buttonId].visible = false
        table.removevalue(buttonOrder, buttonId)
        updateDisplayedButtonsList()
        updateAvailableButtonsList()
        saveButtonConfig()
        reloadMainPanelSizes()
        displayedList:focusNextChild(KeyboardFocusReason)
    end
end

function moveToDisplayed()
    local availableList = optionPanel.panelAvailableButtons.displayedAvailableButtonsList
    local selectedItem = availableList:getFocusedChild()

    if not selectedItem then
        return
    end

    local buttonId = selectedItem.buttonId
    local optionsPanel = optionsController.ui.onPanel.options
    local button = optionsPanel:getChildById(buttonId)

    if button then
        button:setVisible(true)
        buttonConfigs[buttonId].visible = true
        table.insert(buttonOrder, buttonId)
        updateDisplayedButtonsList()
        updateAvailableButtonsList()
        reorderButtons()
        saveButtonConfig()
        reloadMainPanelSizes()
        availableList:focusNextChild(KeyboardFocusReason)
    end
end

function moveButtonUp()
    if not g_game.isOnline() then
        return
    end

    local displayedList = optionPanel.panelDisplayedButtons.displayedButtonsList
    local selectedItem = displayedList:getFocusedChild()

    if not selectedItem then
        return
    end

    local buttonId = selectedItem.buttonId
    local index = table.find(buttonOrder, buttonId)

    if index and index > 1 then
        buttonOrder[index], buttonOrder[index - 1] = buttonOrder[index - 1], buttonOrder[index]
        updateDisplayedButtonsList()
        reorderButtons()
        saveButtonConfig()
        local focusedChild = displayedList:getFocusedChild()
        if focusedChild then
            displayedList:ensureChildVisible(focusedChild)
        end
    end
end

function moveButtonDown()
    if not g_game.isOnline() then
        return
    end

    local displayedList = optionPanel.panelDisplayedButtons.displayedButtonsList
    local selectedItem = displayedList:getFocusedChild()

    if not selectedItem then
        return
    end

    local buttonId = selectedItem.buttonId
    local index = table.find(buttonOrder, buttonId)

    if index and index < #buttonOrder then
        buttonOrder[index], buttonOrder[index + 1] = buttonOrder[index + 1], buttonOrder[index]

        updateDisplayedButtonsList()
        reorderButtons()
        saveButtonConfig()
        local focusedChild = displayedList:getFocusedChild()
        if focusedChild then
            displayedList:ensureChildVisible(focusedChild)
        end
    end
end

function reorderButtons()
    if not g_game.isOnline() then
        return
    end
    local optionsPanel = optionsController.ui.onPanel.options
    local children = {}
    for _, id in ipairs(buttonOrder) do
        local button = optionsPanel:getChildById(id)
        if button then
            table.insert(children, button)
        end
    end
    for _, button in ipairs(optionsPanel:getChildren()) do
        local id = button:getId()
        if not table.find(buttonOrder, id) then
            table.insert(children, button)
        end
    end
    optionsPanel:reorderChildren(children)
end

function reset()
    g_settings.setNode('control_buttons', {})
    buttonConfigs = {}
    buttonOrder = {}
    local optionsPanel = optionsController.ui.onPanel.options
    if optionsPanel then
        for _, button in ipairs(optionsPanel:getChildren()) do
            local id = button:getId()
            if id then
                button:setVisible(true)
                buttonConfigs[id] = {
                    visible = true,
                    tooltip = button:getTooltip() or id
                }
                table.insert(buttonOrder, id)
            end
        end
    end
    updateDisplayedButtonsList()
    updateAvailableButtonsList()
    reorderButtons()
    reloadMainPanelSizes()
end

function initControlButtons()
    local config = loadButtonConfig()
    buttonConfigs = config.buttons or {}
    buttonOrder = config.order or {}
    local currentButtons = {}
    for _, button in ipairs(optionsController.ui.onPanel.options:getChildren()) do
        local id = button:getId()
        if id then
            currentButtons[id] = true
            if not buttonConfigs[id] then
                buttonConfigs[id] = {
                    visible = button:isVisible(),
                    tooltip = button:getTooltip() or id
                }

                if button:isVisible() and not table.find(buttonOrder, id) then
                    table.insert(buttonOrder, id)
                end
            else
                button:setVisible(buttonConfigs[id].visible)
            end
        end
    end

    local toRemove = {}
    for id in pairs(buttonConfigs) do
        if not currentButtons[id] then
            table.insert(toRemove, id)
        end
    end

    for _, id in ipairs(toRemove) do
        buttonConfigs[id] = nil
        for i, orderId in ipairs(buttonOrder) do
            if orderId == id then
                table.remove(buttonOrder, i)
                break
            end
        end
    end
    updateDisplayedButtonsList()
    updateAvailableButtonsList()
    reorderButtons()
    reloadMainPanelSizes()
end
