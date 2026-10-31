--[[
    Inventory Module
    Handles item checking for minimap visibility and tracked items (markedbills, etc.)
]]

local itemCache = {}
local hasAnyRequiredItem = false
local lastTrackedValues = {}
local trackedItems = {} -- Items we care about (minimap required + markedbills, etc.)

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════

local function GetRequiredItems()
    return Config.Minimap and Config.Minimap.RequiredItems or {}
end

-- Build list of items we need to track
local function BuildTrackedItemsList()
    trackedItems = {}

    -- Minimap required items
    for _, itemName in ipairs(GetRequiredItems()) do
        trackedItems[itemName] = true
    end

    -- Markedbills
    if Config.MarkedBills and Config.MarkedBills.Enabled then
        trackedItems[Config.MarkedBills.ItemName or 'markedbills'] = true
    end
end

-- Check if we care about this item
local function IsTrackedItem(itemName)
    if not itemName then return true end -- If no item specified, refresh all
    return trackedItems[itemName] == true
end

local isFirstLoad = true

local function RefreshTrackedItems()
    if not (IsPlayerLoaded() and IsHudVisible()) then return end

    -- Markedbills
    if Config.MarkedBills and Config.MarkedBills.Enabled then
        local cfg = Config.MarkedBills
        local itemName = cfg.ItemName or 'markedbills'
        local newValue
        if cfg.ItemInfo then
            local metaKey = cfg.MetaKey or 'worth'
            newValue = GetItemMetadataSum(itemName, metaKey) or 0
        else
            newValue = GetItemMetadataSum(itemName) or 0
        end
        debugPrint('[MarkedBills] value:', newValue, 'item:', itemName, 'itemInfo:', cfg.ItemInfo and 'true' or 'false', 'lastTracked:', lastTrackedValues.marked or 'nil')

        if newValue ~= lastTrackedValues.marked then
            local oldValue = lastTrackedValues.marked or 0
            lastTrackedValues.marked = newValue

            -- Send update - only show change animation if not first load
            local updateData = { marked = newValue }
            if not isFirstLoad and oldValue >= 0 then
                local diff = newValue - oldValue
                if diff ~= 0 then
                    updateData.change = {
                        type = 'marked',
                        amount = math.abs(diff),
                        isMinus = diff < 0
                    }
                end
            end
            NuiMessage('updatePlayerInfo', updateData)
        end
    end

    -- Mark first load complete after first refresh
    if isFirstLoad then
        isFirstLoad = false
    end
end

local function RefreshItems()
    -- Refresh required items for minimap
    local items = GetRequiredItems()
    if #items > 0 then
        local hasAny = false
        for _, itemName in ipairs(items) do
            local count = GetItemMetadataSum(itemName) -- count only, no metadata key
            itemCache[itemName] = count
            if count > 0 then hasAny = true end
        end

        if hasAny ~= hasAnyRequiredItem then
            hasAnyRequiredItem = hasAny
            TriggerEvent('codem-hud:client:RequiredItemChanged', hasAny)
        end
    end

    -- Refresh tracked items (markedbills, etc.)
    RefreshTrackedItems()
end

-- ═══════════════════════════════════════════════════════════════
-- INVENTORY EVENTS
-- ═══════════════════════════════════════════════════════════════
-- Only refresh if the changed item is in our tracked list

-- ox_inventory (provides itemName)
-- https://overextended.dev/ox_inventory/Events/Client
AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount)
    if not IsTrackedItem(itemName) then return end
    if itemCache[itemName] ~= nil then
        itemCache[itemName] = totalCount
    end
    RefreshItems()
end)

-- qb-inventory (itemAdded/Removed provides item name)
-- https://docs.qbcore.org/qbcore-documentation/qbcore-resources/qb-inventory
RegisterNetEvent('qb-inventory:client:itemAdded', function(_, item)
    if not IsTrackedItem(item) then return end
    Wait(100)
    RefreshItems()
end)

RegisterNetEvent('qb-inventory:client:itemRemoved', function(_, item)
    if not IsTrackedItem(item) then return end
    Wait(100)
    RefreshItems()
end)

-- qb-inventory fallback (updateInventory has no item info, always refresh)
RegisterNetEvent('qb-inventory:client:updateInventory', function()
    Wait(100)
    RefreshItems()
end)

-- esx (provides itemName)
-- https://docs.esx-framework.org/en/esx_core/es_extended/events/client
RegisterNetEvent('esx:addInventoryItem', function(itemName)
    if not IsTrackedItem(itemName) then return end
    Wait(100)
    RefreshItems()
end)

RegisterNetEvent('esx:removeInventoryItem', function(itemName)
    if not IsTrackedItem(itemName) then return end
    Wait(100)
    RefreshItems()
end)

-- qs-inventory (uses same qb-inventory events, already registered above)
-- https://docs.quasar-store.com/player-systems/inventory/handle-items-events

-- codem-inventory (no item info in event, always refresh)
AddEventHandler('codem-inventory:client:additemtoclientInventory', function()
    Wait(100)
    RefreshItems()
end)

AddEventHandler('codem-inventory:client:removeitemtoclientInventory', function()
    Wait(100)
    RefreshItems()
end)

-- tgiann-inventory (follows ox_inventory pattern, likely has item info)
-- https://docs.tgiann.com/scripts/tgiann-inventory/events
RegisterNetEvent('tgiann-inventory:itemAdded', function(itemName)
    if itemName and not IsTrackedItem(itemName) then return end
    Wait(100)
    RefreshItems()
end)

RegisterNetEvent('tgiann-inventory:itemRemoved', function(itemName)
    if itemName and not IsTrackedItem(itemName) then return end
    Wait(100)
    RefreshItems()
end)

-- QBCore player data update (catches all inventory changes including drops)
-- https://docs.qbcore.org/qbcore-documentation/qbcore-resources/qb-core/player-data#setplayerdata
RegisterNetEvent('QBCore:Player:SetPlayerData', function(newData)
    Wait(100)
    RefreshItems()
end)

-- qb-inventory close event (catches manual inventory closes after drops/transfers)
RegisterNetEvent('qb-inventory:client:closeInv', function()
    Wait(150)
    RefreshItems()
end)

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════

function HasItem(itemName)
    if itemCache[itemName] == nil then
        itemCache[itemName] = GetItemMetadataSum(itemName)
    end
    return itemCache[itemName] > 0
end

function GetItemCount(itemName)
    if itemCache[itemName] == nil then
        itemCache[itemName] = GetItemMetadataSum(itemName)
    end
    return itemCache[itemName]
end

function HasAnyRequiredItem()
    return hasAnyRequiredItem
end

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

-- Build tracked items list on resource start
BuildTrackedItemsList()

AddEventHandler('codem-hud:client:PlayerLoaded', function()
    Wait(500)
    debugPrint('[Inventory] PlayerLoaded - refreshing items, MarkedBills.Enabled:', Config.MarkedBills and Config.MarkedBills.Enabled or false)
    RefreshItems()
end)
