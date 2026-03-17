-- Auxiliar miniWindows
local acceptWindow = nil
local changeNameWindow = nil
local transferPointsWindow = nil
local processingWindow = nil
local messageBox = nil


local oldProtocol = false
local a0xF2 = true

local offerDescriptions = {}
local requestedOfferDescriptions = {}
local currentDescriptionOfferId = nil
local reasonCategory = {}
local bannersHome = {}
local storeDescriptionRootId = 'storeDescriptionRoot'

local STORE_DESCRIPTION_TTF_FONT = '/data/fonts/ttf/verdana-bold.ttf'
local STORE_DESCRIPTION_TTF_FONT_ITALIC = '/data/fonts/ttf/verdana-bold-italic.ttf'
local STORE_DESCRIPTION_TTF_SIZE = 11
local STORE_DESCRIPTION_TTF_STROKE_WIDTH = 0
local STORE_DESCRIPTION_TTF_STROKE_COLOR = tocolor('#000000')
local STORE_DESCRIPTION_COLOR = '#dfdfdf'
local STORE_DESCRIPTION_BULLET_ICON = '/game_store/images/icon-star-gold'

local function requestOfferDescription(offerId)
    if g_game.requestStoreOfferDescription then
        g_game.requestStoreOfferDescription(offerId)
        return true
    end
    return false
end

local function ensureStoreDescriptionRoot(container)
    if not container or container:isDestroyed() then
        return nil
    end

    local root = container:getChildById(storeDescriptionRootId)
    if root and not root:isDestroyed() then
        root:fill('parent')
        return root
    end

    root = g_ui.createWidget('UIWidget', container)
    root:setId(storeDescriptionRootId)
    root:setFocusable(false)
    root:setPhantom(true)
    root:fill('parent')
    root:setLayout(UIVerticalLayout.create(root))
    return root
end

local function normalizeStoreDescription(description)
    local text = description or ""
    if type(text) ~= 'string' then
        text = tostring(text)
    end
    return text:gsub("\r\n", "\n"):gsub("\r", "\n")
end

local function splitStoreDescriptionLines(text)
    local out = {}
    local startIndex = 1
    while true do
        local newlineIndex = text:find("\n", startIndex, true)
        if not newlineIndex then
            table.insert(out, text:sub(startIndex))
            break
        end

        table.insert(out, text:sub(startIndex, newlineIndex - 1))
        startIndex = newlineIndex + 1
    end
    return out
end

local function createStoreDescriptionLineLabel(parent)
    local label = g_ui.createWidget('Label', parent)
    label:setTextAlign(AlignLeft)
    label:setTextWrap(true)
    label:setTextVerticalAutoResize(true)
    label:setTTFFont(STORE_DESCRIPTION_TTF_FONT, STORE_DESCRIPTION_TTF_SIZE, STORE_DESCRIPTION_TTF_STROKE_WIDTH, STORE_DESCRIPTION_TTF_STROKE_COLOR)
    label:setColor(STORE_DESCRIPTION_COLOR)
    return label
end

local function addStoreDescriptionSpacer(parent)
    local spacer = g_ui.createWidget('UIWidget', parent)
    spacer:setFocusable(false)
    spacer:setPhantom(true)
    spacer:setFixedSize(true)
    spacer:setSize(tosize('1 6'))
    return spacer
end

local function addStoreDescriptionLine(parent, line)
    if line:match("^%s*$") then
        return addStoreDescriptionSpacer(parent)
    end

    local italicText = line:match("^%s*<i>(.-)</i>%s*$") or line:match("^%s*<em>(.-)</em>%s*$")
    if italicText then
        local label = createStoreDescriptionLineLabel(parent)
        label:setTTFFont(STORE_DESCRIPTION_TTF_FONT_ITALIC, STORE_DESCRIPTION_TTF_SIZE, STORE_DESCRIPTION_TTF_STROKE_WIDTH, STORE_DESCRIPTION_TTF_STROKE_COLOR)
        label:setText(italicText)
        return label
    end

    local replaced, count = line:gsub("^%s*<icon%-star%-gold%s*/?>%s*", "", 1)
    if count > 0 then
        local label = createStoreDescriptionLineLabel(parent)
        label:setIcon(STORE_DESCRIPTION_BULLET_ICON)
        label:setIconAlign(AlignTopLeft)
        label:setIconOffset({ x = 0, y = 3 })
        label:setIconSize(tosize('9 10'))
        label:setTextOffset({ x = 14, y = 0 })
        label:setText(replaced)
        return label
    end

    local label = createStoreDescriptionLineLabel(parent)
    label:setText(line)
    return label
end

local function setStoreDescription(container, description)
    if not container or container:isDestroyed() then
        return
    end

    local root = ensureStoreDescriptionRoot(container)
    if not root then
        return
    end

    root:destroyChildren()

    local text = normalizeStoreDescription(description)
    local lines = splitStoreDescriptionLines(text)
    for i = 1, #lines do
        addStoreDescriptionLine(root, lines[i])
    end

    root:updateLayout()
end

local currentIndex = 1

local function resetStoreSessionState()
    a0xF2 = true
    offerDescriptions = {}
    requestedOfferDescriptions = {}
    currentDescriptionOfferId = nil
    reasonCategory = {}
    bannersHome = {}
    currentIndex = 1

    if controllerShop and controllerShop.ui and controllerShop.ui.panelItem then
        local container = controllerShop.ui.panelItem:getChildById('lblDescription')
        if container and not container:isDestroyed() then
            container:destroyChildren()
        end
    end

    if controllerShop and controllerShop.ui then
        if controllerShop.ui.selectedOption then
            controllerShop.ui.selectedOption:hide()
            controllerShop.ui.selectedOption = nil
        end

        controllerShop.ui.openedCategory = nil
        controllerShop.ui.openedSubCategory = nil

        if controllerShop.ui.listCategory then
            controllerShop.ui.listCategory:destroyChildren()
        end

        if controllerShop.ui.panelItem then
            if controllerShop.ui.panelItem.listProduct then
                controllerShop.ui.panelItem.listProduct:destroyChildren()
            end
            local stack = controllerShop.ui.panelItem:getChildById('StackOffers')
            if stack then
                stack:destroyChildren()
            end
        end

        if controllerShop.ui.HomePanel and controllerShop.ui.HomePanel.HomeRecentlyAdded and controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos then
            controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos:destroyChildren()
        end

        if controllerShop.ui.transferHistory and controllerShop.ui.transferHistory.historyPanel then
            controllerShop.ui.transferHistory.historyPanel:destroyChildren()
        end
    end
end

-- /*=============================================
-- =            To-do                  =
-- =============================================*/
-- - Fix filter functionality
-- - Correct HTML string syntax
-- - cache
-- - try on outfit
-- - improve homePanel/hystoryPanel

GameStore = GameStore or {}
GameStore.website = GameStore.website or {}

GameStore.CoinType = {
    Coin = 0,
    Transferable = 1
}

GameStore.ClientOfferTypes = {
	CLIENT_STORE_OFFER_OTHER = 0,
	CLIENT_STORE_OFFER_NAMECHANGE = 1,
	CLIENT_STORE_OFFER_WORLD_TRANSFER = 2,
	CLIENT_STORE_OFFER_HIRELING = 3, --idk
	CLIENT_STORE_OFFER_CHARACTER = 4,--idk
	CLIENT_STORE_OFFER_TOURNAMENT = 5,--idk
	CLIENT_STORE_OFFER_CONFIRM = 6,--idk
}

GameStore.States = {
    STATE_NONE = 0,
    STATE_NEW = 1,
    STATE_SALE = 2,
    STATE_TIMED = 3
}

GameStore.SendingPackets = {
    S_CoinBalance = 0xDF, -- 223
    S_StoreError = 0xE0, -- 224
    S_RequestPurchaseData = 0xE1, -- 225
    S_CoinBalanceUpdating = 0xF2, -- 242
    S_OpenStore = 0xFB, -- 251
    S_StoreOffers = 0xFC, -- 252
    S_OpenTransactionHistory = 0xFD, -- 253
    S_CompletePurchase = 0xFE -- 254
}

GameStore.RecivedPackets = {
    C_StoreEvent = 0xE9, -- 233
    C_TransferCoins = 0xEF, -- 239
    C_ParseHirelingName = 0xEC, -- 236
    C_OpenStore = 0xFA, -- 250
    C_RequestStoreOffers = 0xFB, -- 251
    C_BuyStoreOffer = 0xFC, -- 252
    C_OpenTransactionHistory = 0xFD, -- 253
    C_RequestTransactionHistory = 0xFE -- 254
}

-- /*=============================================
-- =            Local Function auxiliaries      =
-- =============================================*/

local function showPanel(panel)
    if panel == "HomePanel" then
        controllerShop.ui.HomePanel:setVisible(true)
        controllerShop.ui.panelItem:setVisible(false)
        controllerShop.ui.transferHistory:setVisible(false)
    elseif panel == "transferHistory" then
        controllerShop.ui.HomePanel:setVisible(false)
        controllerShop.ui.panelItem:setVisible(false)
        controllerShop.ui.transferHistory:setVisible(true)
    elseif panel == "panelItem" then
        controllerShop.ui.HomePanel:setVisible(false)
        controllerShop.ui.panelItem:setVisible(true)
        controllerShop.ui.transferHistory:setVisible(false)
    end
end

local function destroyWindow(windows)
    if type(windows) == "table" then
        for _, window in ipairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
                window = nil
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
            windows = nil
        end
    end
end

local function getPageLabelHistory()
    local text = controllerShop.ui.transferHistory.lblPage:getText()
    local currentPage, pageCount = text:match("Page (%d+)/(%d+)")
    return tonumber(currentPage), tonumber(pageCount)
end

local imageQueue = {}
local imageActive = 0
local IMAGE_MAX_CONCURRENCY = 2
local IMAGE_DOWNLOAD_TIMEOUT = 10
local STORE_IMAGE_FALLBACK = "/data/images/ui/icon-questionmark"
local STORE_IMAGE_MAX_RETRIES = 2
local STORE_IMAGE_RETRY_DELAY_MS = 700

local function sanitizeStorePath(path)
    if type(path) ~= "string" then
        return ""
    end
    path = path:gsub("\\\\", "/")
    path = path:gsub(" ", "%%20")
    return path
end

local function joinUrl(base, path)
    base = tostring(base or "")
    path = tostring(path or "")
    if base:sub(-1) == "/" and path:sub(1, 1) == "/" then
        return base:sub(1, -2) .. path
    end
    return base .. path
end

local function downloadStoreImage(url, callback)
    local oldTimeout = HTTP.timeout
    HTTP.timeout = IMAGE_DOWNLOAD_TIMEOUT
    local ok, err = pcall(function()
        HTTP.downloadImage(url, callback)
    end)
    HTTP.timeout = oldTimeout
    if not ok and callback then
        callback(nil, tostring(err))
    end
end

local function isMissingStoreImageError(err)
    if not err then
        return false
    end
    err = tostring(err):lower()
    return err:find("404", 1, true) ~= nil or err:find("not found", 1, true) ~= nil
end

local function setStoreImageFallback(widget, isIcon)
    if isIcon then
        widget:setIcon(STORE_IMAGE_FALLBACK)
    else
        widget:setImageSource(STORE_IMAGE_FALLBACK)
        widget:setImageFixedRatio(false)
    end
end

local function setImagenHttp(widget, url, isIcon)
    local wref = setmetatable({ w = widget }, { __mode = 'v' })
    local function startNext()
        if imageActive >= IMAGE_MAX_CONCURRENCY then return end
        local task = table.remove(imageQueue, 1)
        if not task then return end
        imageActive = imageActive + 1
        downloadStoreImage(task.fullUrl, function(path, err)
            imageActive = imageActive - 1
            local w = task.wref.w
            if not w or w:isDestroyed() then
                startNext()
                return
            end

            if w.__storeImageKey ~= task.key then
                startNext()
                return
            end

            if err then
                setStoreImageFallback(w, task.isIcon)

                if not isMissingStoreImageError(err) and (task.attempt or 0) < STORE_IMAGE_MAX_RETRIES then
                    local nextAttempt = (task.attempt or 0) + 1
                    scheduleEvent(function()
                        if w and not w:isDestroyed() and w.__storeImageKey == task.key then
                            table.insert(imageQueue, {
                                wref = setmetatable({ w = w }, { __mode = 'v' }),
                                fullUrl = task.fullUrl,
                                key = task.key,
                                isIcon = task.isIcon,
                                attempt = nextAttempt
                            })
                            startNext()
                        end
                    end, STORE_IMAGE_RETRY_DELAY_MS * nextAttempt)
                end
            else
                if task.isIcon then
                    w:setIcon(path)
                else
                    w:setImageSource(path)
                end
            end
            startNext()
        end)
        startNext()
    end

    local sanitizedUrl = sanitizeStorePath(url)
    local baseUrl = GameStore.website and GameStore.website.IMAGES_URL or ""
    if type(baseUrl) ~= "string" or baseUrl == "" then
        setStoreImageFallback(widget, isIcon)
        return
    end

    local fullUrl = joinUrl(baseUrl, sanitizedUrl)
    local key = tostring(isIcon and "icon|" or "img|") .. sanitizedUrl
    widget.__storeImageKey = key

    table.insert(imageQueue, { wref = wref, fullUrl = fullUrl, key = key, isIcon = isIcon, attempt = 0 })
    startNext()
end

local function formatNumberWithCommas(value)
    local sign = value < 0 and "-" or ""
    value = math.abs(value)
    local formattedValue = string.format("%d", value)
    formattedValue = formattedValue:reverse():gsub("(%d%d%d)", "%1,")
    formattedValue = formattedValue:reverse():gsub("^,", "")
    return sign .. formattedValue
end

local function getCoinsBalance()
    local function extractNumber(text)
        if type(text) ~= "string" then 
            return 0 
        end
        local numberStr = text:match("%d[%d,]*")
        if not numberStr then 
            return 0 
        end
        local cleanNumber = numberStr:gsub("[^%d]", "")
        return tonumber(cleanNumber) or 0
    end

    local lblNormal = controllerShop.ui.lblCoins.lblTibiaCoins
    local lblTransfer = controllerShop.ui.lblCoins.lblTibiaTransfer

    local labelNormalCoins = lblNormal and extractNumber(lblNormal:getText()) or 0
    local labelTransferableCoins = lblTransfer and extractNumber(lblTransfer:getText()) or 0

    local player = g_game.getLocalPlayer()
    local resourceNormalCoins = 0
    local resourceTransferableCoins = 0
    if player and player.getResourceBalance then
        resourceNormalCoins = player:getResourceBalance(ResourceTypes.COIN_NORMAL) or 0
        resourceTransferableCoins = player:getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE) or 0
    end

    local normalCoins = labelNormalCoins > 0 and labelNormalCoins or resourceNormalCoins
    local transferableCoins = labelTransferableCoins > 0 and labelTransferableCoins or resourceTransferableCoins

    return normalCoins, transferableCoins
end

local function syncCoinLabelsFromPlayer()
    if not controllerShop.ui or not controllerShop.ui.lblCoins then
        return
    end
    local player = g_game.getLocalPlayer()
    if not player or not player.getResourceBalance then
        return
    end

    local coinBalance = player:getResourceBalance(ResourceTypes.COIN_NORMAL) or 0
    local transferBalance = player:getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE) or 0

    local lblNormal = controllerShop.ui.lblCoins.lblTibiaCoins
    local lblTransfer = controllerShop.ui.lblCoins.lblTibiaTransfer

    local function extractNumber(text)
        if type(text) ~= "string" then
            return 0
        end
        local numberStr = text:match("%d[%d,]*")
        if not numberStr then
            return 0
        end
        local cleanNumber = numberStr:gsub("[^%d]", "")
        return tonumber(cleanNumber) or 0
    end

    local labelNormalCoins = lblNormal and extractNumber(lblNormal:getText()) or 0
    local labelTransferableCoins = lblTransfer and extractNumber(lblTransfer:getText()) or 0
    local hasResourceData = (coinBalance > 0) or (transferBalance > 0)
    local labelsEmpty = (labelNormalCoins == 0 and labelTransferableCoins == 0)
    if not hasResourceData and not labelsEmpty then
        return
    end

    if lblNormal then
        lblNormal:setText(formatNumberWithCommas(coinBalance))
    end
    if lblTransfer then
        lblTransfer:setText(string.format("(Including: %s", formatNumberWithCommas(transferBalance)))
    end
end

local function refreshStorePriceColors()
    if not controllerShop.ui or controllerShop.ui:isDestroyed() then
        return
    end

    syncCoinLabelsFromPlayer()

    local normalCoins, transferableCoins = getCoinsBalance()
    local fullBalance = normalCoins + transferableCoins

    local function priceFromLabel(label)
        if not label then
            return 0
        end
        local text = label:getText()
        if type(text) ~= "string" then
            return 0
        end
        local clean = text:gsub("[^%d]", "")
        return tonumber(clean) or 0
    end

    local function recolorStackOffer(offerWidget)
        if not offerWidget or offerWidget:isDestroyed() then
            return
        end
        local priceLabel = offerWidget:getChildById('lblPrice') or offerWidget.lblPrice
        if not priceLabel then
            return
        end
        local price = offerWidget.storePrice or priceFromLabel(priceLabel)
        local isTransferable = offerWidget.storeIsTransferable
        local balance = isTransferable and transferableCoins or fullBalance
        priceLabel:setColor(balance < price and "#d33c3c" or "white")
    end

    local function refreshProductList()
        local listProduct = controllerShop.ui.panelItem and controllerShop.ui.panelItem.listProduct or nil
        if not listProduct then
            return
        end
        for _, row in ipairs(listProduct:getChildren()) do
            local stack = row and row:getChildById('StackOffers') or nil
            if stack then
                for _, offerWidget in ipairs(stack:getChildren()) do
                    recolorStackOffer(offerWidget)
                end
            end
        end
    end

    local function refreshItemPanel()
        local panel = controllerShop.ui.panelItem
        if not panel then
            return
        end
        local stack = panel:getChildById('StackOffers')
        if not stack then
            return
        end
        for _, offerPanel in ipairs(stack:getChildren()) do
            local priceLabel = offerPanel and offerPanel:getChildById('lblPrice') or nil
            local btnBuy = offerPanel and offerPanel:getChildById('btnBuy') or nil
            if priceLabel and btnBuy then
                local price = offerPanel.storePrice or priceFromLabel(priceLabel)
                local isTransferable = offerPanel.storeIsTransferable
                local balance = isTransferable and transferableCoins or fullBalance
                if offerPanel.storeDisabled then
                    btnBuy:disable()
                    btnBuy:setOpacity(0.8)
                else
                    if balance < price then
                        btnBuy:disable()
                    else
                        btnBuy:enable()
                    end
                end
                priceLabel:setColor(balance < price and "#d33c3c" or "white")
            end
        end
    end

    local function refreshHome()
        local homeList = controllerShop.ui.HomePanel and controllerShop.ui.HomePanel.HomeRecentlyAdded and controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos or nil
        if not homeList then
            return
        end
        for _, row in ipairs(homeList:getChildren()) do
            local stack = row and row:getChildById('StackOffers') or nil
            if stack then
                for _, offerWidget in ipairs(stack:getChildren()) do
                    recolorStackOffer(offerWidget)
                end
            end
        end
    end

    refreshProductList()
    refreshItemPanel()
    refreshHome()
end

local function fixServerNoSend0xF2()
    if a0xF2 then
        local player = g_game.getLocalPlayer()
        local coin, transfer = getCoinsBalance()
        local coinBalance = player:getResourceBalance(ResourceTypes.COIN_NORMAL)
        local transferBalance = player:getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE)
        local hasResourceData = (coinBalance and coinBalance > 0) or (transferBalance and transferBalance > 0)
        local labelsEmpty = (coin == 0 and transfer == 0)
        if hasResourceData or labelsEmpty then
            if coin ~= coinBalance then
                controllerShop.ui.lblCoins.lblTibiaCoins:setText(formatNumberWithCommas(coinBalance))
            end
            if transfer ~= transferBalance then
                controllerShop.ui.lblCoins.lblTibiaTransfer:setText(string.format("(Including: %s", formatNumberWithCommas(transferBalance)))
            end
        end
    end
end

local function convert_timestamp(timestamp)
    local fecha_hora = os.date("%Y-%m-%d, %H:%M:%S", timestamp)
    return fecha_hora
end

local function getProductData(product)
    if product.itemId or product.itemType then
        return {
            VALOR = "item",
            ID = product.itemId or product.itemType
        }
    elseif product.icon then
        return {
            VALOR = "icon",
            ID = product.icon
        }
    elseif product.mountId then
        return {
            VALOR = "mountId",
            ID = product.mountId
        }
    elseif product.outfitId or product.sexId then
        local outfitId = product.outfitId or product.sexId
        local head = nil
        local body = nil
        local legs = nil
        local feet = nil
        local player = g_game and g_game.getLocalPlayer and g_game.getLocalPlayer() or nil
        if player then
            local currentOutfit = player:getOutfit()
            if currentOutfit then
                head = currentOutfit.head
                body = currentOutfit.body
                legs = currentOutfit.legs
                feet = currentOutfit.feet
            end
        end
        head = head or product.outfitHead
        body = body or product.outfitBody
        legs = legs or product.outfitLegs
        feet = feet or product.outfitFeet
        if product.outfit then
            head = head or product.outfit.lookHead
            body = body or product.outfit.lookBody
            legs = legs or product.outfit.lookLegs
            feet = feet or product.outfit.lookFeet
        end
        return {
            VALOR = "outfit",
            ID = outfitId,
            addons = tonumber(product.collection) or tonumber(product.addons) or 3,
            head = math.min(132, math.max(0, tonumber(head) or 0)),
            body = math.min(132, math.max(0, tonumber(body) or 0)),
            legs = math.min(132, math.max(0, tonumber(legs) or 0)),
            feet = math.min(132, math.max(0, tonumber(feet) or 0))
        }
    elseif product.maleOutfitId then
        return {
            VALOR = "outfitId",
            ID = product.maleOutfitId,
            addons = tonumber(product.collection) or tonumber(product.addons) or 3
        }
    end
end

local function shouldShowOfferCountLabel(offer, product)
    local count = tonumber(offer and offer.count) or tonumber(product and product.count) or 1
    if count <= 1 then
        return false
    end

    local itemId = tonumber((offer and (offer.itemId or offer.itemType or offer.itemtype)) or (product and (product.itemId or product.itemType or product.itemtype)) or 0) or 0
    local name = nil

    if itemId > 0 and g_things and ThingCategoryItem then
        local thingType = g_things.getThingType(itemId, ThingCategoryItem)
        if thingType then
            name = thingType:getName()
        end
    end

    if type(name) ~= "string" or name == "" then
        name = (offer and offer.name) or (product and product.name) or ""
    end

    if type(name) ~= "string" then
        return false
    end

    local lower = name:lower()
    return lower:find("potion", 1, true) ~= nil or lower:find("rune", 1, true) ~= nil
end

local function createProductImage(imageParent, data)
    if data.VALOR == "item" then
        local itemWidget = g_ui.createWidget('StoreItem', imageParent)
        itemWidget:setId(data.ID)
        itemWidget:setItemId(data.ID)
        itemWidget:setVirtual(true)
        itemWidget:setSize('64 64')
        itemWidget:fill('parent')
    elseif data.VALOR == "icon" then
        local widget = g_ui.createWidget('UIWidget', imageParent)
        setImagenHttp(widget, "/64/" .. data.ID, false)
        widget:setImageFixedRatio(true)
        widget:setImageSmooth(true)
        widget:fill('parent')
    elseif data.VALOR == "outfit" then
        local creature = g_ui.createWidget('StoreCreature', imageParent)
        creature:setOutfit({
            type = data.ID,
            addons = 3,
            head = data.head,
            body = data.body,
            legs = data.legs,
            feet = data.feet
        })
        creature:fill('parent')
    elseif data.VALOR == "mountId" or data.VALOR:find("outfitId") then
        local creature = g_ui.createWidget('StoreCreature', imageParent)
        creature:setOutfit({
            type = data.ID,
            addons = 3
        })
        creature:fill('parent')
    end
end

-- /*=============================================
-- =    behavior categories and subcategories    =
-- =============================================*/

local function disableAllButtons()
    local panel = controllerShop.ui.panelItem
    panel:getChildById('StackOffers'):destroyChildren()
    panel:getChildById('image'):destroyChildren()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.Button then
            widget.Button:setEnabled(false)
            if widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button then
                        subWidget.Button:setEnabled(false)
                    end
                end
            end
        end
    end
    offerDescriptions = {}
    requestedOfferDescriptions = {}
    currentDescriptionOfferId = nil
end

local function enableAllButtons()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.Button then
            widget.Button:setEnabled(true)
            if widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button then
                        subWidget.Button:setEnabled(true)
                    end
                end
            end
        end
    end
end

local categoryBoxBottomTrim = {
    Consumables = 5,
    Houses = 5,
    Cosmetics = 1,
    Extras = 1,
    Tournament = 1
}

local function toggleSubCategories(parent, isOpen)
    local selectedSubId = parent.selectedSubId or 1
    local lastIndex = nil
    local desiredHeight = nil

    if parent.subCategoriesSize then
        parent.closedSize = parent.closedSize or parent:getHeight()
        if isOpen then
            lastIndex = parent.subCategoriesSize
            while lastIndex > 0 and not parent:getChildById(lastIndex) do
                lastIndex = lastIndex - 1
            end
            local categoryId = parent.getId and parent:getId() or nil
            local trim = categoryBoxBottomTrim[categoryId] or 1
            parent.openedSize = math.max(0, (21 * (lastIndex + 1)) - trim)
        end
    end

    desiredHeight = isOpen and parent.openedSize or parent.closedSize

    if isOpen and parent.Button and parent.subCategoriesSize then
        parent.Button:setChecked(false)
    end

    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)
        if subWidget then
            subWidget:setVisible(isOpen)
            if subWidget.Button then
                subWidget.Button:setChecked(false)
                subWidget.Button.Arrow:setVisible(false)
            end
            if subWidget.ArrowLeft then
                subWidget.ArrowLeft:setVisible(false)
            end
        end
    end

    if isOpen then
        local selectedWidget = parent:getChildById(selectedSubId) or parent:getChildById(1)
        if selectedWidget and selectedWidget.Button then
            local resolvedId = selectedWidget:getId()
            parent.selectedSubId = resolvedId
            selectedWidget.Button:setChecked(true)
            selectedWidget.Button.Arrow:setVisible(false)
            if selectedWidget.ArrowLeft then
                selectedWidget.ArrowLeft:setVisible(true)
                selectedWidget.ArrowLeft:setImageSource("/images/ui/icon-arrow7x7-right")
            end
            controllerShop.ui.openedSubCategory = selectedWidget
        end
    end

    parent.opened = isOpen
    if parent.subCategoriesSize then
        parent.Button.Arrow:setVisible(true)
        parent.Button.Arrow:setImageSource(isOpen and "/images/ui/icon-arrow7x7-down" or "/images/ui/icon-arrow7x7-right")
    else
        parent.Button.Arrow:setVisible(false)
    end

    if desiredHeight then
        parent:setHeight(desiredHeight)
    end

    local container = parent:getParent()
    if container then
        container:updateLayout()
    end
end

local function close(parent)
    if parent.subCategories then
        toggleSubCategories(parent, false)
    end

    parent.selectedSubId = nil
    if parent.Button then
        parent.Button:setChecked(false)
    end

    if parent.Button and parent.subCategoriesSize then
        parent.Button.Arrow:setVisible(true)
        parent.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")
    end
end

local function open(parent)
    local oldOpen = controllerShop.ui.openedCategory
    if oldOpen and oldOpen ~= parent then
        close(oldOpen)
    end
    toggleSubCategories(parent, true)
    if parent.Button then
        parent.Button:setChecked(not parent.subCategoriesSize)
    end
    controllerShop.ui.openedCategory = parent
end

local function closeCategoryButtons()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.subCategories then
            for subId, _ in ipairs(widget.subCategories) do
                local subWidget = widget:getChildById(subId)
                if subWidget then
                    subWidget.Button:setChecked(false)
                    subWidget.Button.Arrow:setVisible(false)
                    if subWidget.ArrowLeft then
                        subWidget.ArrowLeft:setVisible(false)
                    end
                end
            end
        end
    end
end

local function createSubWidget(parent, subId, subButton)
    local subWidget = g_ui.createWidget("storeCategory", parent)
    subWidget:setId(subId)
    setImagenHttp(subWidget.Button.Icon, subButton.icon, true)
    subWidget.Button.Title:setText(subButton.text)
    subWidget:setVisible(false)
    subWidget.open = subButton.open
    subWidget:setMarginLeft(15)
    subWidget.Button:setSize('163 20')
    function subWidget.Button.onClick()
        disableAllButtons()
        local selectedOption = controllerShop.ui.selectedOption
        closeCategoryButtons()
        parent.Button:setChecked(false)
        parent.Button.Arrow:setVisible(true)
        parent.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
        subWidget.Button:setChecked(true)
        subWidget.Button.Arrow:setVisible(false)
        subWidget.ArrowLeft:setVisible(true)
        subWidget.ArrowLeft:setImageSource("/images/ui/icon-arrow7x7-right")
        parent.selectedSubId = subId
        controllerShop.ui.openedSubCategory = subWidget

        if selectedOption then
            selectedOption:hide()
        end
        if subWidget.open == "Home" then
            g_game.sendRequestStoreHome()
        else
            g_game.requestStoreOffers(subButton.text,"", 0, 1)
        end
    end

    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
    if subId == 1 then
        subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
        subWidget:setMarginTop(20)
    else
        subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
        subWidget:setMarginTop(-1)
    end

    return subWidget
end

-- /*=============================================
-- =            Controller                   =
-- =============================================*/
controllerShop = Controller:new()
g_ui.importStyle("style/ui.otui")
controllerShop:setUI('game_store')
function controllerShop:onInit()
    controllerShop.ui:hide()

    for k, v in pairs({{'Most Popular Fist', 'MostPopularFist'}, {'Alphabetically', 'Alphabetically'},
                       {'Newest Fist', 'NewestFist'}}) do
        controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst:addOption(v[1], v[2])
    end

    controllerShop.ui.transferPoints.onClick = transferPoints
    controllerShop.ui.panelItem.listProduct.onChildFocusChange = chooseOffert
    controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos.onChildFocusChange = chooseHome
    -- /*=============================================
    -- =            Parse                         =
    -- =============================================*/

    controllerShop:registerEvents(g_game, {
        onParseStoreGetCoin = onParseStoreGetCoin,
        onParseStoreGetCategories = onParseStoreGetCategories,
        onParseStoreCreateHome = onParseStoreCreateHome,
        onParseStoreCreateProducts = onParseStoreCreateProducts,
        onParseStoreGetHistory = onParseStoreGetHistory,
        onParseStoreGetPurchaseStatus = onParseStoreGetPurchaseStatus,
        onParseStoreOfferDescriptions = onParseStoreOfferDescriptions,
        onParseStoreError = onParseStoreError,
        onStoreInit = onStoreInit,
        onResourcesBalanceChange = onResourcesBalanceChange
    })
end

function controllerShop:onGameStart()
    oldProtocol = g_game.getClientVersion() < 1310
    resetStoreSessionState()
end

function controllerShop:onGameEnd()
    if controllerShop.ui:isVisible() then
        controllerShop.ui:hide()
    end

    resetStoreSessionState()

    destroyWindow({transferPointsWindow, changeNameWindow, acceptWindow, processingWindow,messageBox})
    imageQueue = {}
    imageActive = 0
end

function controllerShop:onTerminate()
    destroyWindow({transferPointsWindow, changeNameWindow, acceptWindow, processingWindow,messageBox})
    imageQueue = {}
    imageActive = 0

    if controllerShop.ui then
        controllerShop.ui.openedCategory = nil
        controllerShop.ui.openedSubCategory = nil
    end
end

-- /*=============================================
-- =            Parse                           =
-- =============================================*/

function onStoreInit(url, coinsPacketSize)
    return
end

function onParseStoreGetCoin(getTibiaCoins, getTransferableCoins)
    a0xF2 = false
    controllerShop.ui.lblCoins.lblTibiaCoins:setText(formatNumberWithCommas(getTibiaCoins))
    controllerShop.ui.lblCoins.lblTibiaTransfer:setText(string.format("(Including: %s",
        formatNumberWithCommas(getTransferableCoins)))
    refreshStorePriceColors()
end

function onResourcesBalanceChange(_, _, resourceType)
    if resourceType ~= ResourceTypes.COIN_NORMAL and resourceType ~= ResourceTypes.COIN_TRANSFERRABLE then
        return
    end
    refreshStorePriceColors()
end

function onParseStoreOfferDescriptions(offerId, description)
    offerDescriptions[offerId] = {
        id = offerId,
        description = description
    }

    if currentDescriptionOfferId == offerId and controllerShop.ui and controllerShop.ui.panelItem then
        setStoreDescription(controllerShop.ui.panelItem:getChildById('lblDescription'), description)
    end
end

function onParseStoreGetPurchaseStatus(purchaseStatus)
    destroyWindow({processingWindow, messageBox})
    controllerShop.ui:hide()
    messageBox = g_ui.createWidget('confirmarSHOP', g_ui.getRootWidget())
    messageBox.Box:setText(purchaseStatus)
    messageBox.buttonAnimation.animation:setImageClip("0 0 108 108")
    messageBox.buttonAnimation.onClick = function(widget)
        messageBox.buttonAnimation:disable()
        local phase = 0
        local animationEvent = periodicalEvent(function()
            if messageBox and messageBox.buttonAnimation and messageBox.buttonAnimation.animation then
                messageBox.buttonAnimation.animation:setImageClip((phase % 13 * 108) .. " 0 108 108")
                phase = phase + 1
                if phase >= 12 then
                    phase = 11
                end
            end
        end, function()
            return messageBox and messageBox.buttonAnimation and messageBox.buttonAnimation.animation
        end, 120, 120)
        controllerShop:scheduleEvent(function()
            destroyWindow({messageBox})
            controllerShop.ui:show()
            if animationEvent then
                removeEvent(animationEvent)
                animationEvent = nil
            end
            fixServerNoSend0xF2()
            local ui = controllerShop.ui
            local target = ui and (ui.openedSubCategory or ui.openedCategory) or nil
            local categoryName = target and (target.open or target:getId()) or nil
            if categoryName == "Boosts" then
                g_game.requestStoreOffers(categoryName, "", 0, 1)
            end
            refreshStorePriceColors()
        end, 2000)
    end
end

function onParseStoreCreateProducts(storeProducts)
    local comboBox = controllerShop.ui.panelItem.comboBoxContainer.showAll
    comboBox:clearOptions()
    comboBox:addOption("Disable", 0)

    if #storeProducts.menuFilter > 0 then
        for k, t in pairs(storeProducts.menuFilter) do
            comboBox:addOption(t, k - 1)
        end
--[[         comboBox.onOptionChange = function(a, b, c, d)
            pdump(a:getCurrentOption())
        end ]]
    end
    reasonCategory = storeProducts.disableReasons
    local listProduct = controllerShop.ui.panelItem.listProduct
    listProduct:destroyChildren()
    if not storeProducts then
        return
    end
    for _, product in ipairs(storeProducts.offers) do
        local row = g_ui.createWidget('RowStore', listProduct)
        row.product, row.type = product, product.type
        row:setOpacity(1)

        local nameLabel = row:getChildById('lblName')
        nameLabel:setText(product.name)
        nameLabel:setTextAlign(AlignLeft)
        nameLabel:setMarginRight(10)

        local subOffers = product.subOffers or { product }
        for _, subOffer in ipairs(subOffers) do
            local offerI = g_ui.createWidget('stackOfferPanel', row:getChildById('StackOffers'))
            local id = subOffer.id or product.id or 0
            local disabled = subOffer.disabled or product.disabled or false
            local price = subOffer.price or product.price or 0
            local isTransferable = (subOffer.coinType or product.coinType) == GameStore.CoinType.Transferable
            offerI:setId(id)
            offerI.storePrice = price
            offerI.storeIsTransferable = isTransferable
            offerI.storeDisabled = disabled
            offerI:enable()
            offerI:setOpacity(1)
            local priceLabel = offerI:getChildById('lblPrice')
            priceLabel:setText(price)

            local countLabel = offerI:getChildById('count')
            if countLabel then
                if shouldShowOfferCountLabel(subOffer, product) then
                    countLabel:setVisible(true)
                    countLabel:setText(tostring(tonumber(subOffer.count) or 1) .. "x")
                else
                    countLabel:setVisible(false)
                    countLabel:setText("")
                end
            end
            fixServerNoSend0xF2()
            local normalCoins, transferableCoins = getCoinsBalance()
            local balance = isTransferable and transferableCoins or (normalCoins + transferableCoins)
            priceLabel:setColor(balance < price and "#d33c3c" or "white")

            if isTransferable then
                priceLabel:setIcon("/game_store/images/icon-tibiacointransferable")
            end
        end
        local data = getProductData(product)
        if data then
            createProductImage(row:getChildById('image'), data)
        end
    end

    controllerShop:scheduleEvent(function()
        local redirectId = storeProducts.redirectId
        if redirectId and type(redirectId) == "number" and redirectId ~= 0 then -- home behavior 
            for _, child in ipairs(listProduct:getChildren()) do
                for _, subOffer in ipairs(child.product.subOffers or { child.product }) do
                    if subOffer.id == redirectId then
                        listProduct:focusChild(child)
                        listProduct:ensureChildVisible(child)
                        return
                    end
                end
            end
        else
            local firstChild = listProduct:getFirstChild()
            if firstChild and firstChild:isEnabled() then
                listProduct:focusChild(firstChild)
                listProduct:ensureChildVisible(firstChild)
            end
        end
    end, 300, 'onParseStoreOfferDescriptionsSafeDelay')

    enableAllButtons()
    showPanel("panelItem")
    fixServerNoSend0xF2()
    refreshStorePriceColors()
end

function onParseStoreCreateHome(offer)
    local homeProductos = controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos
    homeProductos:destroyChildren()
    for _, product in ipairs(offer.offers) do
        local row = g_ui.createWidget('RowStoreHome', homeProductos)
        row.product, row.type = product, product.type

        local nameLabel = row:getChildById('lblName')
        nameLabel:setText(product.name)
        nameLabel:setTextAlign(AlignLeft)
        nameLabel:setMarginRight(10)
        
        local subOfferWidget = g_ui.createWidget('stackOfferPanel', row:getChildById('StackOffers'))
        subOfferWidget.storePrice = product.price or 0
        subOfferWidget.storeIsTransferable = product.coinType == GameStore.CoinType.Transferable
        subOfferWidget.storeDisabled = product.disabled or false

        subOfferWidget.lblPrice:setText(product.price)

        local countLabel = subOfferWidget:getChildById('count')
        if countLabel then
            if shouldShowOfferCountLabel(product, product) then
                countLabel:setVisible(true)
                countLabel:setText(tostring(tonumber(product.count) or 1) .. "x")
            else
                countLabel:setVisible(false)
                countLabel:setText("")
            end
        end
        if product.coinType == GameStore.CoinType.Transferable then
            subOfferWidget.lblPrice:setIcon("/game_store/images/icon-tibiacointransferable")
        end

        local data = getProductData(product)
        if data then
            createProductImage(row:getChildById('image'), data)
        end
    end

    local ramdomImg = offer.banners[math.random(1, #offer.banners)].image
    setImagenHttp(controllerShop.ui.HomePanel.HomeImagen, ramdomImg, false)
    enableAllButtons()
    bannersHome = table.copy(offer.banners)
    showPanel("HomePanel")
    fixServerNoSend0xF2()
    refreshStorePriceColors()
end

function onParseStoreGetHistory(currentPage, pageCount, historyData)
    local transferHistory = controllerShop.ui.transferHistory.historyPanel
    transferHistory:destroyChildren()
    local headerRow = g_ui.createWidget("historyData2", transferHistory)
    headerRow:setBackgroundColor("#363636")
    headerRow:setBorderColor("#00000077")
    headerRow:setBorderWidth(1)
    headerRow.date:setText("Date")
    headerRow.Balance:setText("Balance")
    headerRow.Description:setText("Description")
    controllerShop.ui.transferHistory.lblPage:setText(string.format("Page %d/%d", currentPage + 1, pageCount))
    for i, data in ipairs(historyData) do
        local row = g_ui.createWidget("historyData2", transferHistory)
        row.date:setText(convert_timestamp(data[1]))
        local balance = data[3]
        row.Balance:setText(formatNumberWithCommas(balance))
        row.Balance:setColor(balance < 0 and "#D33C3C" or "#3CD33C")
        row.Description:setText(data[5])
        row.Balance:setIcon(data[4] == GameStore.CoinType.Transferable and 
                            "/game_store/images/icon-tibiacointransferable" or 
                            "images/ui/tibiaCoin")
        row:setBackgroundColor(i % 2 == 0 and "#ffffff12" or "#00000012")
    end
    showPanel("transferHistory")
end

function onParseStoreGetCategories(buttons)
    controllerShop.ui.listCategory:destroyChildren()
    controllerShop.ui.openedCategory = nil
    controllerShop.ui.openedSubCategory = nil

    local categories = {}

    local subcategories = {}

    for _, button in ipairs(buttons) do
        if not button.parent then
            categories[button.name] = button
            categories[button.name].subCategories = {}
        else
            table.insert(subcategories, button)
        end
    end

    for _, subcat in ipairs(subcategories) do
        if categories[subcat.parent] then
            table.insert(categories[subcat.parent].subCategories, subcat)
        end
    end

    if not categories["Home"] then
        categories["Home"] = {
            ["subCategories"] = {},
            ["name"] = "Home",
            ["icons"] = {
                [1] = "icon-store-home.png"
            },
            ["state"] = 0
        }
    end

    -- Ordem desejada ( igual client CIP ): Home, VIP Shop, LendariumShop, Vocation Items, Consumables, Cosmetics, Houses, Boosts, Extras, Tournament
    local orderedCategoryNames = {"Home", "VIP Shop", "LendariumShop", "Vocation Items", "Consumables", "Cosmetics",
                                "Houses", "Boosts", "Extras", "Tournament", "Premium Time"}

    -- Construir categoryArray na ordem exata (iterar sobre ordem desejada, nao sobre pairs)
    local categoryArray = {}
    local used = {}
    for _, wantedName in ipairs(orderedCategoryNames) do
        for catName, data in pairs(categories) do
            local nameMatch = (catName == wantedName) or (catName and wantedName and catName:lower() == wantedName:lower())
            if nameMatch and not used[catName] then
                table.insert(categoryArray, data)
                used[catName] = true
                break
            end
        end
    end
    -- Categorias enviadas pelo servidor mas nao na lista: adicionar no final (ordem alfabetica para consistencia)
    local rest = {}
    for name, data in pairs(categories) do
        if not used[name] then
            table.insert(rest, data)
        end
    end
    table.sort(rest, function(a, b) return (a.name or "") < (b.name or "") end)
    for _, data in ipairs(rest) do
        table.insert(categoryArray, data)
    end

    for index, category in ipairs(categoryArray) do
        local widget = g_ui.createWidget("storeCategory", controllerShop.ui.listCategory)
        widget:setId(category.name)
            -- widget.Button.Icon:setIcon("/game_store/images/13/" .. category.icons[1])
            if category.icons[1] == "icon-store-home.png" then
                widget.Button.Icon:setIcon("/game_store/images/icon-store-home")
            else
                setImagenHttp(widget.Button.Icon, "/13/" .. category.icons[1], true)
            end

            widget.Button.Title:setText(category.name)
            widget.open = category.name

            if #category.subCategories > 0 then
                widget.subCategories = category.subCategories
                widget.subCategoriesSize = #category.subCategories
                widget.Button.Arrow:setVisible(true)
                widget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")

                for subId, subButton in ipairs(category.subCategories) do
                    local subWidget = createSubWidget(widget, subId, {
                        text = subButton.name,
                        icon = "/13/" .. subButton.icons[1],
                        open = subButton.name
                    })
                end
            else
                widget.Button.Arrow:setVisible(false)
            end

            widget:setMarginTop(10)

            widget.Button.onClick = function()
                disableAllButtons()
                local parent = widget
                local oldOpen = controllerShop.ui.openedCategory
                local panel = controllerShop.ui.panelItem
                local btnBuy = panel:getChildById('btnBuy')
                local image = panel:getChildById('image')
                local lblPrice = panel:getChildById('lblPrice')
                local btnBuy = panel:getChildById('StackOffers')

                image:setImageSource("")
                btnBuy:destroyChildren()

                local firstChild = image:getFirstChild()
                if image:getChildCount() ~= 0 and firstChild then
                    local styleClass = firstChild:getStyle().__class
                    if styleClass == "UIItem" then
                        firstChild:setItemId(nil)
                    elseif styleClass == "UICreature" then
                        firstChild:setOutfit({
                            type = nil
                        })
                    else
                        firstChild:setImageSource("")
                    end
                end

                if oldOpen and oldOpen ~= parent then
                    if oldOpen.Button then
                        oldOpen.Button:setChecked(false)
                    end
                    if controllerShop.ui.openedSubCategory and controllerShop.ui.openedSubCategory:getParent() == oldOpen then
                        controllerShop.ui.openedSubCategory = nil
                    end
                    close(oldOpen)
                end

                if parent.subCategoriesSize then
                    open(parent)

                else
                    widget.Button:setChecked(true)
                end

                if parent.subCategoriesSize then
                    widget.Button.Arrow:setVisible(true)
                    widget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
                end

                if controllerShop.ui.selectedOption then
                    controllerShop.ui.selectedOption:hide()
                end
                if category.name == "Home" then
                    controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos:destroyChildren()
                    g_game.sendRequestStoreHome()
                else
                    if parent.subCategoriesSize and parent.subCategories then
                        local selectedSubId = parent.selectedSubId or 1
                        local selectedSub = parent.subCategories[selectedSubId]
                        local selectedName = selectedSub and selectedSub.name or nil
                        if selectedName then
                            g_game.requestStoreOffers(selectedName, "", 0, 1)
                        else
                            g_game.requestStoreOffers(category.name, "", 0, 1)
                        end
                    else
                        g_game.requestStoreOffers(category.name, "", 0, 1)
                    end
                end
                controllerShop.ui.openedCategory = parent
            end
        end
        local firstCategory = controllerShop.ui.listCategory:getChildByIndex(1)
        if controllerShop.ui.openedCategory == nil and firstCategory then
            controllerShop.ui.openedCategory = firstCategory
            firstCategory.Button:onClick()
        end

end

function onParseStoreError(errorMessage)
    destroyWindow(processingWindow)
    displayErrorBox(controllerShop.ui:getText(), errorMessage)
end

-- /*=============================================
-- =            buttons                          =
-- =============================================*/

function hide()
    if not controllerShop.ui then
        return
    end
    if controllerShop.ui.openedCategory then
        close(controllerShop.ui.openedCategory)
    end
    controllerShop.ui.openedCategory = nil
    controllerShop.ui.openedSubCategory = nil
    controllerShop.ui:hide()
end

function toggle()
    if not controllerShop.ui then
        return
    end

    if controllerShop.ui:isVisible() then
        return hide()
    end
    show()
end

function show()
    if not controllerShop.ui then
        return
    end

    controllerShop.ui:show()
    controllerShop.ui:raise()
    controllerShop.ui:focus()

    g_game.openStore()

    controllerShop:scheduleEvent(function()
        if not controllerShop.ui or not controllerShop.ui.listCategory then
            return
        end

        local homeWidget = controllerShop.ui.listCategory:getChildById("Home")
        if homeWidget and homeWidget.Button then
            homeWidget.Button:onClick()
        else
            g_game.sendRequestStoreHome()
        end
    end, 50, function() return 'forceStoreHomeOnOpen' end)

    controllerShop:scheduleEvent(function()
        if controllerShop.ui.listCategory:getChildCount() == 0 then
            g_game.sendRequestStoreHome() -- fix 13.10
            local packet1 = GameStore.RecivedPackets.C_OpenStore
            g_logger.warning(string.format("[game_store BUG] Check 0x%X (%d) L827", packet1, packet1))
        end
    end, 1000, function() return 'serverNoSendPackets0xF20xFA' end)
end



function getUI()
    return controllerShop.ui
end

function getCoinsWebsite()
    if GameStore.website.WEBSITE_GETCOINS ~= "" then
        g_platform.openUrl(GameStore.website.WEBSITE_GETCOINS)
    else
        sendMessageBox("Error", "No data for store URL.")
    end
end
-- /*=============================================
-- =            History                         =
-- =============================================*/

function toggleTransferHistory()
    if controllerShop.ui.transferHistory:isVisible() then
        if controllerShop.ui.openedCategory and controllerShop.ui.openedCategory:getId() == "Home" then
            showPanel("HomePanel")
        else
            showPanel("panelItem")
        end
    else
        g_game.requestTransactionHistory()
    end
end

function requestTransactionHistory(widget)
    local currentPage, pageCount = getPageLabelHistory()
    local newPage = currentPage + (widget:getId() == "btnNextPage" and 1 or -1)
    
    if newPage > 0 and newPage <= pageCount then
        g_game.requestTransactionHistory(newPage - 1)
    end
end

-- /*=============================================
-- =            focusedChild                     =
-- =============================================*/

function chooseOffert(self, focusedChild)
    if not focusedChild then
        return
    end

    local product = focusedChild.product
    local panel = controllerShop.ui.panelItem
    panel:getChildById('lblName'):setText(product.name)
    local description = product.description or ""
    local subOffers = product.subOffers or {}
    if not table.empty(subOffers) then
        local offerId = subOffers[1].id
        currentDescriptionOfferId = offerId
        if not offerDescriptions[offerId] and not requestedOfferDescriptions[offerId] then
            requestedOfferDescriptions[offerId] = true
            requestOfferDescription(offerId)
        end
        local descriptionInfo = offerDescriptions[offerId]
        if descriptionInfo and descriptionInfo.description and descriptionInfo.description ~= "" then
            description = descriptionInfo.description
        end
    elseif (not description or description == "") and product.id then
        currentDescriptionOfferId = product.id
        if not offerDescriptions[product.id] and not requestedOfferDescriptions[product.id] then
            requestedOfferDescriptions[product.id] = true
            requestOfferDescription(product.id)
        end
        local descriptionInfo = offerDescriptions[product.id]
        if descriptionInfo then
            description = descriptionInfo.description
        end
    end

    setStoreDescription(panel:getChildById('lblDescription'), description)

    local data = getProductData(product)
    local imagePanel = panel:getChildById('image')
    imagePanel:destroyChildren()
    if data then
        createProductImage(imagePanel, data)
    end
    fixServerNoSend0xF2()

    -- example use getCoinsBalance
    local normalCoins, transferableCoins = getCoinsBalance()
    local offerStackPanel = panel:getChildById('StackOffers')
    offerStackPanel:destroyChildren()

    local offers = not table.empty(subOffers) and subOffers or { product }
    for _, offer in ipairs(offers) do
        local offerPanel = g_ui.createWidget('OfferPanel2', offerStackPanel)

        local priceLabel = offerPanel:getChildById('lblPrice')
        local offerPrice = offer.price or product.price or 0
        priceLabel:setText(offerPrice)

        local itemCount = (offer.count and offer.count > 0) and offer.count or 1
        if itemCount > 1 and shouldShowOfferCountLabel(offer, product) then
            offerPanel:getChildById('btnBuy'):setText("Buy " .. itemCount .. "x")
        end

        if product.configurable then
            offerPanel:getChildById('btnBuy'):setText("Configurable")
        end

        local isTransferable = (offer.coinType or product.coinType) == GameStore.CoinType.Transferable
        local currentBalance = isTransferable and transferableCoins or (normalCoins + transferableCoins)

        offerPanel.storePrice = offerPrice
        offerPanel.storeIsTransferable = isTransferable
        offerPanel.storeDisabled = offer.disabled or false

        if isTransferable then
            priceLabel:setIcon("/game_store/images/icon-tibiacointransferable")
        else
            priceLabel:setIcon("images/ui/tibiaCoin")
        end

        if currentBalance < offerPrice then
            priceLabel:setColor("#d33c3c")
            offerPanel:getChildById('btnBuy'):disable()
        else
            priceLabel:setColor("white")
            offerPanel:getChildById('btnBuy'):enable()
        end

        if offer.disabled then
            local btnBuy = offerPanel:getChildById('btnBuy')
            btnBuy:disable()
            btnBuy:setOpacity(0.8)
            local lblDescription = panel:getChildById('lblDescription')
            setStoreDescription(lblDescription, description)
            if offer.reasonIdDisable then
                local tooltipOverlay = g_ui.createWidget('UIWidget', offerPanel)
                tooltipOverlay:setId('tooltipOverlay')
                tooltipOverlay:setFocusable(false)
                tooltipOverlay:setSize(btnBuy:getSize())
                tooltipOverlay:setPosition(btnBuy:getPosition())
                local reasonText = oldProtocol and offer.reasonIdDisable or reasonCategory[offer.reasonIdDisable + 1]
                tooltipOverlay:parseColoreDisplayToolTip(string.format(
                    "[color=#ff0000]The product is not available for this character:\n\n- %s[/color]",
                    reasonText
                ))
                tooltipOverlay:setOpacity(0)
                tooltipOverlay:addAnchor(AnchorLeft, btnBuy:getId(), AnchorLeft)
                tooltipOverlay:addAnchor(AnchorTop, btnBuy:getId(), AnchorTop)
            end
        end

        -- 👇 Confirmação corrigida
        offerPanel:getChildById('btnBuy').onClick = function(widget)
            if acceptWindow then
                destroyWindow(acceptWindow)
            end

            if product.configurable or product.name == "Character Name Change" then
                return displayChangeName(offer)
            end

            if product.name == "Hireling Apprentice" then
                return displayErrorBox(controllerShop.ui:getText(), "not yet, UI missing")
            end

            local function acceptFunc()
                fixServerNoSend0xF2()
                local latestNormal, latestTransferable = getCoinsBalance()
                local latestCurrentBalance = isTransferable and latestTransferable or (latestNormal + latestTransferable)

                if latestCurrentBalance >= (offer.price or product.price or 0) then
                    g_game.buyStoreOffer((offer.id or product.id), GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_OTHER)
                    local closeWindow = function() destroyWindow(processingWindow) end
                    controllerShop.ui:hide()
                    processingWindow = displayGeneralBox(
                        'Processing purchase.', 
                        'Your purchase is being processed',
                        {
                          { text = tr('ok'),  callback = closeWindow },
                          anchor = 50
                        }, 
                        closeWindow, 
                        closeWindow
                    )
                else
                    displayErrorBox(controllerShop.ui:getText(), tr("You don't have enough coins"))
                end
                destroyWindow(acceptWindow)
            end

            local function cancelFunc()
                destroyWindow(acceptWindow)
            end

            local coinType = isTransferable and "transferable coins" or "regular coins"
            local confirmationMessage = string.format(
                'Do you want to buy the product "%s" for %d %s?', 
                product.name, 
                (offer.price or product.price or 0), 
                coinType
            )

            local itemCountConfirm = (offer.count and offer.count > 0) and offer.count or 1
            local detailsMessage = string.format(
                "%dx %s\nPrice: %d %s",
                itemCountConfirm,
                product.name,
                (offer.price or product.price or 0),
                coinType
            )

            acceptWindow = displayGeneralSHOPBox(
                tr('Confirmation of Purchase'),
                confirmationMessage,
                detailsMessage,
                {
                    { text = tr('Buy'), callback = acceptFunc },
                    { text = tr('Cancel'), callback = cancelFunc },
                    anchor = AnchorHorizontalCenter
                },
                acceptFunc,
                cancelFunc
            )
            if data then
                createProductImage(acceptWindow.Box, data)
            end
        end
    end
end


-- /*=============================================
-- =            Home                             =
-- =============================================*/

function chooseHome(self, focusedChild)
    if not focusedChild then
        return
    end
    local product = focusedChild.product
    local panel = controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos
    g_game.sendRequestStoreOfferById(product.id)
end

function changeImagenHome(direction)
    if direction == "nextImagen" then
        currentIndex = currentIndex + 1
        if currentIndex > #bannersHome then
            currentIndex = 1
        end
    elseif direction == "prevImagen" then
        currentIndex = currentIndex - 1
        if currentIndex < 1 then
            currentIndex = #bannersHome
        end
    end
    local currentBanner = bannersHome[currentIndex]
    local imagePath = currentBanner.image
    setImagenHttp(controllerShop.ui.HomePanel.HomeImagen, imagePath, false)
end

-- /*=============================================
-- =            Behavior  Change Name            =
-- =============================================*/

function displayChangeName(offer)
    controllerShop.ui:hide()
    g_game.buyStoreOffer(offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_OTHER) -- canary send this packets?
    destroyWindow(changeNameWindow)
    changeNameWindow = g_ui.displayUI('style/changename')
    changeNameWindow:show()
    local newName = changeNameWindow:getChildById('transferPointsText')
    newName:setText('')
    local function closeWindow()
        newName:setText('')
        changeNameWindow:setVisible(false)
    end
    changeNameWindow.closeButton.onClick = closeWindow
    changeNameWindow.buttonOk.onClick = function()
        g_game.buyStoreOffer(offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_NAMECHANGE,newName:getText() )
        closeWindow()
    end
    changeNameWindow.onEscape = function()
        destroyWindow(changeNameWindow)
    end
end

-- /*=============================================
-- =            Button TransferPoints            =
-- =============================================*/

function transferPoints()
    destroyWindow(transferPointsWindow)
    transferPointsWindow = g_ui.displayUI('style/transferpoints')
    transferPointsWindow:show()

    local playerBalance = g_game.getLocalPlayer():getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE)
    fixServerNoSend0xF2()

    local normalCoins, transferableCoins = getCoinsBalance()

    if playerBalance == 0 then
        playerBalance = transferableCoins -- temp fix canary 1340
    end

    transferPointsWindow.giftable:setText(formatNumberWithCommas(playerBalance))

    local initialValue, minimumValue = 0, 0
    if playerBalance >= 25 then
        initialValue = 25
        minimumValue = 25
    end

    transferPointsWindow.amountBar:setStep(25)
    transferPointsWindow.amountBar:setMinimum(minimumValue)
    local maxStep = math.floor(playerBalance / 25) * 25 -- coins multiple 25
    transferPointsWindow.amountBar:setMaximum(maxStep)
    transferPointsWindow.amountBar:setValue(initialValue)
    transferPointsWindow.amount:setText(formatNumberWithCommas(initialValue))

    local sliderButton = transferPointsWindow.amountBar:getChildById('sliderButton')
    if sliderButton then
        sliderButton:setEnabled(true)
        sliderButton:setVisible(true)
    end

    transferPointsWindow.onEscape = function()
        destroyWindow(transferPointsWindow)
    end

    local lastDisplayedValue = initialValue
    transferPointsWindow.amountBar.onValueChange = function(scrollbar, value)
        -- Round to the nearest multiple of 25
        local val = math.floor((value + 12) / 25) * 25
        
        -- Only update the display if the value has changed
        if val ~= lastDisplayedValue then
            lastDisplayedValue = val
            transferPointsWindow.amount:setText(formatNumberWithCommas(val))
        end
    end

    transferPointsWindow.closeButton.onClick = function()
        destroyWindow(transferPointsWindow)
    end

    transferPointsWindow.buttonOk.onClick = function()
        local receipient = transferPointsWindow.transferPointsText:getText():trim()
        local amount = transferPointsWindow.amountBar:getValue()

        if receipient:len() < 3 then
            return
        end
        if amount < 1 or playerBalance < amount then
            return
        end

        g_game.transferCoins(receipient, amount)
        destroyWindow(transferPointsWindow)
    end
end




-- /*=============================================
-- =            Search Button            =
-- =============================================*/

function search()
    if  controllerShop.ui.openedCategory ~= nil then
        close(controllerShop.ui.openedCategory)
    end
    g_game.sendRequestStoreSearch(controllerShop.ui.SearchEdit:getText(), 0, 1)
end
