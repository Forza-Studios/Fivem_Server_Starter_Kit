Inventory = {}

-- Resolves Config.Inventory, auto-detecting from running resources if "auto".
local function detectInventory()
    local inventory = Config.Inventory or "auto"
    if inventory ~= "auto" then
        return inventory
    end

    if GetResourceState("ak47_inventory") == "started" then
        return "ak47_inventory"
    end
    if GetResourceState("ox_inventory") == "started" then
        return "ox_inventory"
    end
    if GetResourceState("qb-inventory") == "started" then
        return "qb-inventory"
    end
    if GetResourceState("es_extended") == "started" then
        return "esx"
    end
    return "none"
end

-- Does the player have at least `count` (default 1) of `item`?
-- ox/ak47 are queried directly; everything else goes through the framework Bridge.
function Inventory.HasItem(source, item, count)
    count = count or 1

    local backend = detectInventory()

    if backend == "ox_inventory" or backend == "ak47_inventory" then
        local inv = (backend == "ak47_inventory" and exports.ak47_inventory) or exports.ox_inventory

        if IsDuplicityVersion() then
            -- Server: GetItemCount first, then GetAmount as a fallback
            local ok, result = pcall(function()
                return inv:GetItemCount(source, item)
            end)
            if ok and result ~= nil then
                return count <= (tonumber(result) or 0)
            end

            local ok2, result2 = pcall(function()
                return inv:GetAmount(source, item)
            end)
            return ok2 and count <= (tonumber(result2) or 0)
        else
            -- Client: Search("count", item)
            local ok, result = pcall(function()
                return inv:Search("count", item)
            end)
            return ok and count <= (tonumber(result) or 0)
        end
    end

    return Bridge.HasItem(source, item, count)
end

-- Removes `count` (default 1) of `item`. Server only; always false on the client.
function Inventory.RemoveItem(source, item, count)
    count = count or 1

    if not IsDuplicityVersion() then
        return false
    end

    local backend = detectInventory()

    if backend == "ak47_inventory" then
        local ok, result = pcall(function()
            return exports.ak47_inventory:RemoveItem(source, item, count)
        end)
        -- ak47 may return nothing on success, so only an explicit false is a failure
        return ok and result ~= false
    end

    if backend == "ox_inventory" then
        local ok, result = pcall(function()
            return exports.ox_inventory:RemoveItem(source, item, count)
        end)
        return (ok and result) and true or false
    end

    return Bridge.RemoveItem(source, item, count) and true or false
end