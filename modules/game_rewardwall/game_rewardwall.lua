rewardWallController = Controller:new()

local ServerPackets = {
    ShowDialog = 0xED,
    DailyRewardCollectionState = 0xDE,
    OpenRewardWall = 0xE2,
    CloseRewardWall = 0xE3,
    DailyRewardBasic = 0xE4,
    DailyRewardHistory = 0xE5
    -- RestingAreaState = 0xA9
}

local ClientPackets = {
    OpenRewardWall = 0xD8,
    OpenRewardHistory = 0xD9,
    SelectReward = 0xDA,
    CollectionResource = 0x14,
    JokerResource = 0x15
}

-- @ widget
local ButtonRewardWall = nil
local windowsPickWindow = nil
local generalBox = nil
-- @ array
local bonuses = {}
local actualUsed = {}
-- @ variable
local bonusShrine = 0
-- @ const
local COLORS = {
    BASE_1 = "#484848",
    BASE_2 = "#414141"
}
local ZONE = {
    LAST_ZONE = -99,
    RESTING_AREA_ZONE = 1,
    ICON_ID = "condition_Rewards",
    NUMERIC_ICON_ID = 30
}

local bundleType = {
    ITEMS = 1,
    PREY = 2,
    XPBOOST = 3
}

local STATUS = {
    COLLECTED = 1,
    ACTIVE = 2,
    LOCKED = 3
}

local OPEN_WINDOWS = {
    BUTTON_WIDGET = 0,
    SHRINE = 1 -- itemClientId = 25802
}

local DailyRewardStatus = { -- sendDailyRewardCollectionState 0xDE ?
    DAILY_REWARD_COLLECTED = 0,
    DAILY_REWARD_NOTCOLLECTED = 1,
    DAILY_REWARD_NOTAVAILABLE = 2
}

local CONST_WINDOWS_BOX = {
    ALREADY = 1,
    RELEASE = 2,
    NO_IRA = 4
}

local BOX_CONFIGS = {
    [CONST_WINDOWS_BOX.ALREADY] = {
        title = "Warning",
        content = "Sorry, you have already taken your daily reward or you are unable to collect it"
    },
    [CONST_WINDOWS_BOX.NO_IRA] = {
        title = "Warning: No Sufficient Instant Reward Access",
        content = "Remember! you can always collect your daily reward for free by visiting a reward shrine!\nyou do not have an Instant Reward Access.\nVisit the store to buy more!"
    }
}

-- /*=============================================
-- =            Local function                  =
-- =============================================*/
local function destroyWindows(windows)
    if type(windows) == "table" then
        for _, window in pairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
        end
    end
    return nil
end

local function premiumStatusWindwos(isPremium)
    rewardWallController.ui.premiumStatus.premiumMessage:setText(isPremium and
                                                                     "Great! You benefit from the best possible rewards and bonuses due to your premium status." or
                                                                     "With a Premium account, you would benefit from even better rewards and bonuses.")
    rewardWallController.ui.premiumStatus.premiumButton:setOn(not isPremium)
    rewardWallController.ui.infoPanel.free:setColor(isPremium and "#909090" or "#FFFFFF")
    rewardWallController.ui.infoPanel.premium:setColor(isPremium and "#FFFFFF" or "#909090")
    if isPremium then
        local restingAreaPanel = rewardWallController.ui.restingAreaPanel
        local bonusIcons = restingAreaPanel and restingAreaPanel:recursiveGetChildById('bonusIcons') or nil
        if bonusIcons then
            for _, widget in pairs(bonusIcons:getChildren()) do
                if widget then
                    widget:setOn(true)
                end
            end
        end
    end
end

local function convert_timestamp(timestamp)
    return os.date("%Y-%m-%d, %H:%M:%S", timestamp)
end

local function formatDurationShort(totalSeconds)
    totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    return string.format("%02d:%02d", hours, minutes)
end

local cooldownDeadlineTs = 0
local cooldownTotalSeconds = 0
local cooldownUpdateEvent = nil
local DEFAULT_COOLDOWN_TOTAL_SECONDS = 24 * 60 * 60

local function stopCooldownTicker()
    if cooldownUpdateEvent then
        removeEvent(cooldownUpdateEvent)
        cooldownUpdateEvent = nil
    end
end

local function ensureCooldownLabelStyle(widget)
    if not widget then
        return
    end

    widget:setVisible(true)
    widget:setTextAlign(AlignCenter)
    widget:setColor("#dfdfdf")
end

local function setCooldownLabelText(widget, text)
    if not widget then
        return
    end

    widget:setText(text)
    ensureCooldownLabelStyle(widget)
    widget:setTextOffset('1 0')
    widget:setTextOffset('0 0')
end

local function getCooldownWidgets()
    if not rewardWallController.ui or rewardWallController.ui:isDestroyed() then
        return nil, nil
    end

    local timeLeftContainer = rewardWallController.ui.restingAreaPanel.restingAreaInfo.timeLeft
    if not timeLeftContainer then
        return nil, nil
    end

    local bar = timeLeftContainer.timeLeftBar or timeLeftContainer
    local label = timeLeftContainer.timeLeftText
    return bar, label
end

local function setCooldownBarPercent(widget, percent)
    if not widget or not widget.getWidth or not widget.getHeight or not widget.setImageRect then
        return false
    end

    if widget.getImageTextureWidth and widget.setImageSource and widget:getImageTextureWidth() == 0 then
        widget:setImageSource('/game_rewardwall/images/progressbar-orange-large')
    end

    local w = widget:getWidth()
    local h = widget:getHeight()
    if w <= 0 or h <= 0 then
        return false
    end

    percent = math.max(0, math.min(100, tonumber(percent) or 0))
    local filled = math.floor(((percent / 100) * w) + 0.5)
    filled = math.max(1, math.min(w, filled))
    widget:setImageRect({x = 0, y = 0, width = filled, height = h})
    return true
end

local function updateCooldownLabel()
    local barWidget, labelWidget = getCooldownWidgets()
    if not barWidget then
        stopCooldownTicker()
        return
    end

    if cooldownDeadlineTs <= 0 then
        if labelWidget then
            setCooldownLabelText(labelWidget, "Expired")
            if barWidget.setText then
                barWidget:setText('')
            end
        else
            setCooldownLabelText(barWidget, "Expired")
        end
        setCooldownBarPercent(barWidget, 100)
        stopCooldownTicker()
        return
    end

    local remaining = cooldownDeadlineTs - os.time()
    if remaining <= 0 then
        if labelWidget then
            setCooldownLabelText(labelWidget, "Expired")
            if barWidget.setText then
                barWidget:setText('')
            end
        else
            setCooldownLabelText(barWidget, "Expired")
        end
        setCooldownBarPercent(barWidget, 100)
        stopCooldownTicker()
        return
    end

    if cooldownTotalSeconds > 0 then
        local total = math.max(1, math.floor(cooldownTotalSeconds))
        local remainingClamped = math.max(0, math.min(total, math.floor(remaining)))
        setCooldownBarPercent(barWidget, (remainingClamped / total) * 100)
    end

    if labelWidget then
        setCooldownLabelText(labelWidget, formatDurationShort(remaining))
        if barWidget.setText then
            barWidget:setText('')
        end
    else
        setCooldownLabelText(barWidget, formatDurationShort(remaining))
    end
end

local function getBonusStrings(bonuses)
    local result = {}
    for _, bonus in ipairs(bonuses) do
        table.insert(result, bonus["name"])
    end
    return table.concat(result, ", ")
end

local function visibleHistory(bool)
    for i, widget in ipairs(rewardWallController.ui:getChildren()) do
        if widget:getId() == "historyPanel" then
            widget:setVisible(bool)
        else
            widget:setVisible(not bool)
        end
        if i == 5 then -- foot
            break
        end
    end
end

local function updateDailyRewards(dayStreakDay, wasDailyRewardTaken)
    local dailyRewardsPanel = rewardWallController.ui.dailyRewardsPanel
    for i = 1, dayStreakDay do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        local rewardArrow = dailyRewardsPanel:getChildById("arrow" .. i)
        if rewardWidget then
            local test = g_ui.createWidget("RewardButton", rewardWidget:getChildById("rewardGold" .. i))
            test:setOn(true)
            local checkmark = test:getChildById('checkmark')
            if checkmark then
                checkmark:setVisible(true)
            end
            test:fill("parent")
            test:setPhantom(true)
            rewardArrow:setImageClip("5 0 5 7")
            rewardWidget:getChildById("rewardButton" .. i):setOn(true)
            rewardWidget:getChildById("rewardButton" .. i).ditherpattern:setVisible(true)
            rewardWidget:getChildById("rewardGold" .. i).status = 1
        end
    end

    local currentReward = dailyRewardsPanel:getChildById("reward" .. dayStreakDay + 1)
    if currentReward then
        local isShrineAccess = bonusShrine == OPEN_WINDOWS.SHRINE
        local testStyle = isShrineAccess and "GoldLabel2DailyShrineCost" or "GoldLabel2DailyOptions"
        local test = g_ui.createWidget(testStyle, currentReward:getChildById("rewardGold" .. dayStreakDay + 1))
        test:setOn(true)
        test:setPhantom(true)
        local iraBalance = 0
        if not isShrineAccess then
            local player = g_game.getLocalPlayer()
            if player and player.getResourceBalance and ResourceTypes and ResourceTypes.DAILYREWARD_STREAK then
                iraBalance = tonumber(player:getResourceBalance(ResourceTypes.DAILYREWARD_STREAK)) or 0
            end
        end
        local textWidget = test:recursiveGetChildById('text')
        if textWidget then
            if isShrineAccess then
                textWidget:setText(0)
                textWidget:setColor("#FFFFFF")
            else
                textWidget:setText(iraBalance >= 1 and iraBalance or 1)
                textWidget:setColor(iraBalance >= 1 and "#FFFFFF" or "#D33C3C")
            end
            if textWidget.setFont then
                textWidget:setFont('Verdana Bold-11px')
            end
        end

        local strikeText = test:recursiveGetChildById('strikeText')
        if strikeText then
            strikeText:setText('1')
            strikeText:setColor('#909090')
            if strikeText.setOpacity then
                strikeText:setOpacity(0.7)
            end
            strikeText:setVisible(isShrineAccess)
        end

        local goldWidget = test:recursiveGetChildById('gold')
        if goldWidget then
            goldWidget:setImageSource("/game_rewardwall/images/instant-reward-access-icon")
            goldWidget:setImageSize("12 12")
            goldWidget:setImageOffset(isShrineAccess and "-25 0" or "0 0")
        end
        currentReward:getChildById("rewardGold" .. dayStreakDay + 1).status = 2
        currentReward:setOn(false)
        currentReward:getChildById("rewardButton" .. dayStreakDay + 1).ditherpattern:setVisible(false)
        currentReward:getChildById("rewardButton" .. dayStreakDay + 1):setOn(false)
    end

    for i = dayStreakDay + 2, 7 do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        if rewardWidget then
            local test = g_ui.createWidget("RewardButton", rewardWidget:getChildById("rewardGold" .. i))
            test:setOn(false)
            local checkmark = test:getChildById('checkmark')
            if checkmark then
                checkmark:setVisible(false)
            end
            test:fill("parent")
            test:setPhantom(true)
            rewardWidget:getChildById("rewardButton" .. i):setOn(true)
            rewardWidget:getChildById("rewardButton" .. i).ditherpattern:setVisible(true)
            rewardWidget:getChildById("rewardGold" .. i).status = 3
        end
    end
end

local function getDayStreakIcon(dayStreakLevel)
    local IconConsecutiveDays = {
        [24] = "icon-rewardstreak-default",
        [49] = "icon-rewardstreak-bronze",
        [99] = "icon-rewardstreak-silver",
        [100] = "icon-rewardstreak-gold"
    }
    if dayStreakLevel <= 24 then
        return IconConsecutiveDays[24]
    elseif dayStreakLevel <= 49 then
        return IconConsecutiveDays[49]
    elseif dayStreakLevel <= 99 then
        return IconConsecutiveDays[99]
    else
        return IconConsecutiveDays[100]
    end
end

local function checkRewards(data)
    local premium = g_game.getLocalPlayer():isPremium()
    local rewardType = premium and data.premiumRewards or data.freeRewards
    local altType = premium and data.freeRewards or data.premiumRewards

    for index = 1, #rewardType do
        local reward = rewardType[index]
        local altReward = altType[index]

        local hasSelectableItems = reward.selectableItems and next(reward.selectableItems) ~= nil
        local rewardButton = rewardWallController.ui.dailyRewardsPanel:getChildById("reward" .. index):getChildById(
            "rewardButton" .. index)
        local iconWidget = rewardWallController.ui.dailyRewardsPanel:getChildById("reward" .. index):getChildByIndex(1)

        if hasSelectableItems then
            iconWidget:setIcon("game_rewardwall/images/icon-reward-pickitems")
            rewardButton.bundleType = bundleType.ITEMS
            rewardButton.rewardItem = reward.selectableItems
            rewardButton.itemsToSelect = {reward.itemsToSelect or 0, altReward and altReward.itemsToSelect or 0}
        elseif reward.bundleItems[1] and reward.bundleItems[1].bundleType == bundleType.XPBOOST then
            iconWidget:setIcon("game_rewardwall/images/icon-reward-xpboost")
            rewardButton.bundleType = bundleType.XPBOOST
            rewardButton.itemsToSelect = {reward.bundleItems[1].itemId or 0,
                                          altReward and altReward.bundleItems[1].itemId or 0}
        else
            iconWidget:setIcon("game_rewardwall/images/icon-reward-fixeditems")
            rewardButton.bundleType = bundleType.PREY
            rewardButton.itemsToSelect = {reward.bundleItems[1].count or 0,
                                          altReward and altReward.bundleItems[1].count or 0}
        end
    end
end

local function onRestingAreaState(zone, state, message)
    if ZONE.LAST_ZONE == zone then
        return
    end
    ZONE.LAST_ZONE = zone
    local gameInterface = modules.game_interface
    if zone == ZONE.RESTING_AREA_ZONE then
        gameInterface.processIcon(ZONE.NUMERIC_ICON_ID, function(icon)
            icon:setTooltip(message)
        end, true)
    else
        gameInterface.processIcon(ZONE.ICON_ID, function(icon)
            icon:destroy()
        end)
    end
end

local function onDailyReward(data)
    bonuses = data.bonuses
    checkRewards(data)
end

local function onServerError(code, error)
    generalBox = destroyWindows(generalBox)
    local cancelCallback = function()
        generalBox = destroyWindows(generalBox)
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "ok",
        callback = cancelCallback
    }}

    generalBox = displayGeneralBox3(rewardWallController.ui:getText(), error, standardButtons)
end

local function connectOnServerError()
    connect(g_game, {
        onServerError = onServerError
    })
end

local function disconnectOnServerError()
    disconnect(g_game, {
        onServerError = onServerError
    })
end

local function onOpenRewardWall(bonusShrines, nextRewardTime, dayStreakDay, wasDailyRewardTaken, errorMessage, tokens,
    timeLeft, dayStreakLevel, lastServerSave, nextServerSave)
    if bonusShrines == OPEN_WINDOWS.SHRINE then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
    bonusShrine = bonusShrines
    updateDailyRewards(dayStreakDay, wasDailyRewardTaken)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setText(dayStreakLevel)
    do
        local streakValue = tostring(tonumber(dayStreakLevel) or 0)
        local digits = #streakValue
        local offsetX = 29 - (math.max(0, digits - 1) * 4)
        if offsetX < 0 then
            offsetX = 0
        end
        local icon = rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon
        if icon and icon.setTextOffset then
            icon:setTextOffset(offsetX .. " 2")
        end
    end

    local lastSSTs = tonumber(lastServerSave) or 0
    local nextSSTs = tonumber(nextServerSave) or 0
    local deadlineTs
    if nextSSTs > 0 then
        deadlineTs = nextSSTs
    elseif wasDailyRewardTaken ~= 0 then
        deadlineTs = tonumber(nextRewardTime) or 0
    else
        deadlineTs = tonumber(timeLeft) or 0
    end

    cooldownTotalSeconds = deadlineTs > 0 and DEFAULT_COOLDOWN_TOTAL_SECONDS or 0

    local timeLeftContainer = rewardWallController.ui.restingAreaPanel.restingAreaInfo.timeLeft
    local timeLeftWidget = timeLeftContainer and (timeLeftContainer.timeLeftText or timeLeftContainer.timeLeftBar) or timeLeftContainer
    cooldownDeadlineTs = deadlineTs
    ensureCooldownLabelStyle(timeLeftWidget)
    updateCooldownLabel()
    if cooldownUpdateEvent then
        removeEvent(cooldownUpdateEvent)
        cooldownUpdateEvent = nil
    end
    if cooldownDeadlineTs > 0 then
        cooldownUpdateEvent = cycleEvent(updateCooldownLabel, 1000)
    end

    local restingAreaGold = rewardWallController.ui.restingAreaPanel.restingAreaInfo.restingAreaGold
    restingAreaGold.gold:setVisible(true)
    restingAreaGold.text:setText(tokens)

    rewardWallController.ui.footerPanel.footerGold1.text:setText(tokens)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setImageSource(
        "/game_rewardwall/images/" .. getDayStreakIcon(dayStreakLevel))

    rewardWallController.ui.footerPanel.footerGold2.text:setText(
        g_game.getLocalPlayer():getResourceBalance(ResourceTypes.DAILYREWARD_STREAK))
end

local function onRewardHistory(rewardHistory)
    local transferHistory = rewardWallController.ui.historyPanel.historyList.List
    transferHistory:destroyChildren()

    local headerRow = g_ui.createWidget("historyData2", transferHistory)
    headerRow:setBackgroundColor("#363636")
    headerRow:setBorderColor("#00000077")
    headerRow:setBorderWidth(1)
    headerRow.date:setText("Date")
    headerRow.Balance:setText("Streak")
    headerRow.Description:setText("Event")

    for i, data in ipairs(rewardHistory) do
        local row = g_ui.createWidget("historyData2", transferHistory)
        row:setHeight(30)
        row.date:setText(convert_timestamp(data[1]))
        row.Balance:setText(data[4])
        row.Description:setText(data[3])
        row.Description:setTextWrap(true)
        row:setBackgroundColor(i % 2 == 0 and "#ffffff12" or "#00000012")
    end
end

-- /*=============================================
-- =            Windows                  =
-- =============================================*/
function show(requestServer)
    if not rewardWallController.ui then
        return
    end
    if requestServer == nil then
        requestServer = true
    end
    if requestServer then
        bonusShrine = OPEN_WINDOWS.BUTTON_WIDGET
        g_game.sendOpenRewardWall()
    end
    rewardWallController.ui:show()
    rewardWallController.ui:raise()
    rewardWallController.ui:focus()
    connectOnServerError()
    premiumStatusWindwos(g_game.getLocalPlayer():isPremium())
end

function hide(bool)
    if not rewardWallController.ui then
        return
    end
    rewardWallController.ui:hide()
    stopCooldownTicker()
    if bool then
        disconnectOnServerError()
    end
end

function toggle()
    if not rewardWallController.ui then
        return
    end
    if rewardWallController.ui:isVisible() then
        ButtonRewardWall:setOn(false)
        return hide(true)
    end
    show(true)
    ButtonRewardWall:setOn(true)
end

local function fixCssIncompatibility() -- temp
    rewardWallController.ui.historyPanel.historyList:fill('parent')

    -- note: I don't know how to edit children in css
    local restingAreaGold = rewardWallController.ui.restingAreaPanel.restingAreaInfo.restingAreaGold
    restingAreaGold.gold:setImageSource("/game_rewardwall/images/icon-daily-reward-joker")
    restingAreaGold.gold:setImageSize("12 12")
    restingAreaGold.gold:setImageOffset("-25 0")
    if restingAreaGold.text and restingAreaGold.text.setFont then
        restingAreaGold.text:setFont('Verdana Bold-11px')
    end

    local footerGold1 = rewardWallController.ui.footerPanel.footerGold1
    footerGold1.gold:setImageSource("/game_rewardwall/images/icon-daily-reward-joker")
    footerGold1.gold:setImageSize("11 11")
    footerGold1.gold:setImageOffset("-3 0")
    footerGold1.text:setTextAlign(AlignRightCenter)
    if footerGold1.text and footerGold1.text.setFont then
        footerGold1.text:setFont('Verdana Bold-11px')
    end

    local footerGold2 = rewardWallController.ui.footerPanel.footerGold2
    footerGold2.gold:setImageSource("/game_rewardwall/images/instant-reward-access-icon")
    footerGold2.gold:setImageSize("12 12")
    footerGold2.gold:setImageOffset("-5 0")
    if footerGold2.text and footerGold2.text.setFont then
        footerGold2.text:setFont('Verdana Bold-11px')
    end
end
-- /*=============================================
-- =            Controller                  =
-- =============================================*/
function rewardWallController:onInit()
    g_ui.importStyle("styles/style.otui")
    rewardWallController:loadHtml('game_rewardwall.html')
    rewardWallController.ui:hide()

    rewardWallController:registerEvents(g_game, {
        onOpenRewardWall = onOpenRewardWall,
        onDailyReward = onDailyReward,
        onRewardHistory = onRewardHistory,
        onRestingAreaState = onRestingAreaState
    })
    fixCssIncompatibility()
end

function rewardWallController:onTerminate()
    generalBox, windowsPickWindow, ButtonRewardWall = destroyWindows({generalBox, windowsPickWindow, ButtonRewardWall})
    stopCooldownTicker()
end

function rewardWallController:onGameStart()
    if g_game.getClientVersion() > 1140 then -- Summer Update 2017
        if not ButtonRewardWall then
            ButtonRewardWall = modules.game_mainpanel.addToggleButton("rewardWall", tr("Open rewardWall"),
                "/images/options/rewardwall", toggle, false, 21)
        end
    else
        scheduleEvent(function()
            g_modules.getModule("game_rewardwall"):unload()
        end, 100)
    end
end

function rewardWallController:onGameEnd()
    if rewardWallController.ui:isVisible() then
        rewardWallController.ui:hide()
        ButtonRewardWall:setOn(false)
    end
    stopCooldownTicker()
    generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
end
-- /*=============================================
-- =            Call css onClick                =
-- =============================================*/
function rewardWallController:onClickshowHistory()
    visibleHistory(not rewardWallController.ui.historyPanel:isVisible())
    if rewardWallController.ui.historyPanel:isVisible() then
        g_game.requestOpenRewardHistory()
    end
    rewardWallController.ui.footerPanel.historyButton:setText(
    rewardWallController.ui.historyPanel:isVisible() and "back" or "history")
end

function rewardWallController:onClickToggle()
    toggle()
end

function rewardWallController:onClickSendStoreRewardWall()
    modules.game_store.toggle()
    g_game.sendRequestStorePremiumBoost()
end

function rewardWallController:onClickbuyInstantRewardAccess()
    modules.game_store.toggle()
    g_game.sendRequestUsefulThings(StoreConst.InstantRewardAccess)
end

function rewardWallController:onClickDisplayWindowsPickRewardWindow(event)
    if event.target:isOn() then
        return
    end

    if event.target.bundleType == bundleType.ITEMS then
        local isPremium = g_game.getLocalPlayer():isPremium()
        local itemsToSelect = event.target.itemsToSelect
        if not windowsPickWindow then
            if type(itemsToSelect) == "table" then
                itemsToSelect = isPremium and itemsToSelect[1] or itemsToSelect[2]
            else
                itemsToSelect = itemsToSelect or 1
            end
            windowsPickWindow = g_ui.displayUI('styles/pickreward')
            windowsPickWindow:show()
            windowsPickWindow:getChildById('capacity'):setText("Free capacity: " ..
                                                                   g_game:getLocalPlayer():getFreeCapacity() .. " oz")

            local text = string.format("You have selected [color=#D33C3C]0[/color] of %d reward items", itemsToSelect)
            windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text, "#c0c0c0")

            for i, item in pairs(event.target.rewardItem) do
                local getItem = g_ui.createWidget('ItemReward', windowsPickWindow:getChildById('rewardList'))
                getItem:getChildById('item'):setItemId(item.itemId)
                getItem:getChildById('title'):setText(item.name)
                getItem:setBackgroundColor((i % 2 == 0) and COLORS.BASE_1 or COLORS.BASE_2)
                getItem.totalWeight = item.weight or 1
                getItem.itemsToSelect = itemsToSelect

            end
            actualUsed = {}
            hide()
        else
            windowsPickWindow:show()
            windowsPickWindow:raise()
            windowsPickWindow:focus()
        end

    elseif event.target.bundleType == bundleType.XPBOOST or event.target.bundleType == bundleType.PREY then
        hide()
        actualUsed = {}
        g_game.requestGetRewardDaily(bonusShrine == OPEN_WINDOWS.SHRINE and 0 or 1, actualUsed)
        show(bonusShrine ~= OPEN_WINDOWS.SHRINE)
    end
end

-- /*=============================================
-- =            Call onHover css                  =
-- =============================================*/

function rewardWallController:onhoverBonus(event)
    if not event.value then
        rewardWallController.ui.infoPanel:setText("")
        return
    end

    local id = event.target:getId()
    local index = tonumber(id:match("%d+"))
    local bonus = bonuses[index]

    if not bonus then
        rewardWallController.ui.infoPanel:setText("Unknown bonus.")
        return
    end

    local isPremium = g_game.getLocalPlayer():isPremium()
    local bonusText = string.format(
        "Allow [color=#909090]%s[/color]%s\nThis bonus is active because you are [color=%s]Premium[/color] and reached a reward streak of at least [color=#44AD25]%d[/color].%s",
        bonus.name, isPremium and "" or "[color=#ff0000](Locked)[/color]", isPremium and "#44AD25" or "#ff0000",
        bonus.id,
        isPremium and ("\n\nActive bonuses: [color=#909090]%s[/color]."):format(getBonusStrings(bonuses)) or "")

    rewardWallController.ui.infoPanel:parseColoredText(bonusText)
end

function rewardWallController:onhoverStatusPlayer(event)
    if not event.value then
        rewardWallController.ui.infoPanel:setText("")
        return
    end

    local playerStatus = {
        rewardStreakIcon = "This explains the reward streak system. You need to claim your daily reward between regular server saves to maintain your streak. At a streak of 2+, your character gets resting area bonuses. Free accounts can reach a maximum bonus at streak level 3, while premium players can reach higher levels. Characters on the same account share the streak.",
        timeLeft = "This is an urgent notification to claim your daily reward within one minute (before the next server save) to raise your reward streak by 1. It mentions that 3 Daily Reward Jokers will be used to prevent resetting your streak. It also encourages raising your streak to benefit from bonuses in resting areas.",
        restingAreaGold = "This explains how Daily Reward Jokers work. They help you maintain your streak on days when you can't claim your daily reward. Each character receives one Daily Reward Joker on the first day of each month. The message recommends collecting rewards daily to stay safe."
    }

    local DEFAULT_MESSAGE = "Unknown bonus."

    local id = event.target:getId()
    local info = playerStatus[id]
    rewardWallController.ui.infoPanel:parseColoredText(info or DEFAULT_MESSAGE)
end

function rewardWallController:onhoverRewardType(event)
    if not event.value then
        rewardWallController.ui.infoPanel.free:setText("")
        rewardWallController.ui.infoPanel.premium:setText("")
        return
    end

    local itemsToSelect = event.target.itemsToSelect or {1, 1}
    local freeAmount = 0
    local premiumAmount = 0

    if type(itemsToSelect) == "table" then
        freeAmount = itemsToSelect[2] or 0
        premiumAmount = itemsToSelect[1] or 0
    else
        freeAmount = itemsToSelect
        premiumAmount = itemsToSelect
    end

    local rewardType = event.target.bundleType
    local rewardTexts = {}

    if rewardType == bundleType.ITEMS then
        rewardTexts = {
            free = string.format(
                "Reward for Free Accounts:\nPick %d items from the list. Among\nother items it contains: health\npotion, a fire bomb rune, a\nthundestorm rune.",
                freeAmount),
            premium = string.format(
                "Reward for Premium Accounts:\nPick %d items from the list. Among\nother items it contains: health\npotion, a fire bomb rune, a\nthundestorm rune.",
                premiumAmount)
        }
    elseif rewardType == bundleType.PREY then
        rewardTexts = {
            free = string.format("Reward for Free Accounts:\n * %d x Prey Wildcard", freeAmount),
            premium = string.format("Reward for Premium Accounts:\n * %d x Prey Wildcard", premiumAmount)
        }
    elseif rewardType == bundleType.XPBOOST then
        rewardTexts = {
            free = string.format("Reward for Free Accounts:\n * %d minutes 50%% XP Boost", freeAmount),
            premium = string.format("Reward for Premium Accounts:\n * %d minutes 50%% XP Boost", premiumAmount)
        }
    else
        print("WARNING: Unknown rewardType:", rewardType)
        return
    end

    rewardWallController.ui.infoPanel.free:setText(rewardTexts.free)
    rewardWallController.ui.infoPanel.premium:setText(rewardTexts.premium)
end

function rewardWallController:onhoverStatusReward(event)
    local statusReward = {
        [STATUS.COLLECTED] = "You have already collected this daily reward.\nThe daily rewards follow a specific cycle where each day you claim it, you get another reward. The cycle repeats after 7 claimed rewards. You will be able to claim this daily reward again as soon as you have reached this postion in the next cycle.",
        [STATUS.ACTIVE] = "The daily reward can be claimed now.\nIf you claim this reward now, it will cost you one Instant Reward Access.\nGet your daily reward for free by visiting a reward shrine.\nYou did not claim your daily reward in time.\nToo bad, you do not have enough Daily Reward Jokers.",
        [STATUS.LOCKED] = "This daily reward is still locked.\nFirst collect the previous daily rewards of this cycle."
    }
    if not event.value then
        rewardWallController.ui.infoPanel:setText("")
        return
    end
    rewardWallController.ui.infoPanel:setText(statusReward[event.target.status])
end

-- /*=============================================
-- =            Auxiliar Windows pickReward      =
-- =============================================*/

function onClickBtnOk()
    if table.empty(actualUsed) then
        return
    end
    g_game.requestGetRewardDaily(bonusShrine == OPEN_WINDOWS.SHRINE and 0 or 1, actualUsed)
    if windowsPickWindow then
        windowsPickWindow:destroy()
        windowsPickWindow = nil
    end
    if generalBox then
        generalBox:destroy()
        generalBox = nil
    end
    show(bonusShrine ~= OPEN_WINDOWS.SHRINE)
end

function destroyPickReward(bool)
    windowsPickWindow = destroyWindows(windowsPickWindow)

    if bool then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
end

function onTextChangeChangeNumber(getPanel)
    if not getPanel.itemsToSelect then
        return
    end

    local alreadyUsed = 0
    local itemId = getPanel:getChildById('item'):getItemId()
    local thisPanelUsed = actualUsed[itemId] or 0

    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end

    local numberField = getPanel:getChildById('number')
    local currentValue = tonumber(numberField:getText()) or 0
    local maxAllowed = getPanel.itemsToSelect - (alreadyUsed - thisPanelUsed)

    if currentValue > maxAllowed then
        numberField:setText(maxAllowed)
    end
    actualUsed[itemId] = tonumber(numberField:getText()) or 0
    alreadyUsed = 0
    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end
    local color = alreadyUsed == 0 and "#D33C3C" or "#00FF00"
    windowsPickWindow:getChildById('btnOk'):setEnabled(alreadyUsed > 0)

    local text = string.format("You have selected [color=%s]%d[/color] of %d reward items", color, alreadyUsed,
        getPanel.itemsToSelect)
    windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text)
    getPanel:getChildById('weight'):setText(string.format("%.2f oz", actualUsed[itemId] * getPanel.totalWeight))
    local totalWeight = 0
    for i, widget in pairs(getPanel:getParent():getChildren()) do
        local weightLabel = widget:getChildById('weight')
        if weightLabel then
            local weightText = weightLabel:getText()
            local weightValue = tonumber(weightText:match("(%d+)"))
            if weightValue then
                totalWeight = totalWeight + weightValue
            end
        end
    end
    windowsPickWindow:getChildById("weight"):setText(string.format("Total weight: %.2f oz", totalWeight))
    windowsPickWindow:getChildById("weight"):resizeToText()
end

-- /*=============================================
-- =            Auxiliar GeneralBox             =
-- =============================================*/
function displayGeneralBox3(title, message, buttons, onEnterCallback, onEscapeCallback)
    if generalBox then
        generalBox = destroyWindows(generalBox)
    end

    generalBox = g_ui.createWidget('MessageBoxWindow', rootWidget)
    if not generalBox then
        return nil
    end

    local titleWidget = generalBox:getChildById('title')
    if titleWidget then
        titleWidget:setText(title)
    end

    local holder = generalBox:getChildById('holder')
    if holder and buttons then
        for i = 1, #buttons do
            local button = g_ui.createWidget('Button', holder)
            local buttonId = buttons[i].text:lower():gsub(" ", "_")

            button:setId(buttonId)
            button:setText(buttons[i].text)
            button:setWidth(math.max(86, 10 + (string.len(buttons[i].text) * 8)))
            button:setHeight(20)
            button:setMarginTop(-5)

            if i == 1 then
                button:addAnchor(AnchorTop, 'parent', AnchorTop)
                button:addAnchor(AnchorRight, 'parent', AnchorRight)
            else
                button:addAnchor(AnchorTop, 'parent', AnchorTop)
                button:addAnchor(AnchorRight, 'prev', AnchorLeft)
                button:setMarginRight(5)
            end
            button.onClick = buttons[i].callback
        end
    end
    if onEnterCallback then
        generalBox.onEnter = onEnterCallback
    end
    if onEscapeCallback then
        generalBox.onEscape = onEscapeCallback
    end

    local content = generalBox:getChildById('content')
    if not content then
        generalBox = destroyWindows(generalBox)

        return nil
    end

    content:setText(message)
    content:resizeToText()

    local contentWidth = content:getWidth() + 32
    local contentHeight = content:getHeight() + 42 + (holder and holder:getHeight() or 0)
    generalBox:setWidth(math.min(916, math.max(300, contentWidth)))
    generalBox:setHeight(math.min(616, math.max(119, contentHeight)))

    generalBox.setContent = function(self, newMessage)
        local content = generalBox:getChildById('content')
        if not content then
            return
        end

        content:setText(newMessage)
        content:resizeToText()
        content:setTextWrap(false)
        content:setTextAutoResize(false)

        local holder = generalBox:getChildById('holder')
        if not holder then
            return
        end

        local contentWidth = content:getWidth() + 32
        local contentHeight = content:getHeight() + 50 + holder:getHeight()
        generalBox:setWidth(math.min(736, math.max(300, contentWidth)))
        generalBox:setHeight(math.min(300, math.max(89, contentHeight)))
    end

    generalBox.setTitle = function(self, newTitle)
        local titleWidget = generalBox:getChildById('title')
        if not titleWidget then
            return
        end

        titleWidget:setText(newTitle)
    end
    generalBox.modifyButton = function(self, buttonId, newText, newCallback)
        local holder = generalBox:getChildById('holder')
        if not holder then
            return nil
        end

        local button = holder:getChildById(buttonId)
        if button then
            if newText then
                button:setText(newText)
                button:setWidth(math.max(86, 10 + (string.len(newText) * 8)))
            end
            if newCallback then
                disconnect(button, {
                    onClick = button.onClick
                })
                connect(button, {
                    onClick = newCallback
                })
                button.onClick = newCallback
            end
        end
        return button
    end
    generalBox:show()
    generalBox:raise()
    generalBox:focus()
    return generalBox
end

function managerMessageBoxWindow(id)
    local config = BOX_CONFIGS[id]
    if not config then
        return
    end

    local cancelCallback = function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local okCallback = config.okCallback or function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "cancel",
        callback = cancelCallback
    }, {
        text = "ok",
        callback = okCallback
    }}

    generalBox = displayGeneralBox3(config.title, config.content, standardButtons)

    rewardWallController.ui:hide()

    if windowsPickWindow then
        windowsPickWindow = destroyWindows(windowsPickWindow)
    end
end
