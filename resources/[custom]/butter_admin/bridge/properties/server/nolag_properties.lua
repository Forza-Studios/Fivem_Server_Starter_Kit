if not UseBridge('properties', 'nolag_properties') then return end

-- nolag_properties keeps ownership in properties_owners and prices in
-- properties_prices; entrance coords are inside the JSON metadata column.
local OWNED_QUERY = [[
    SELECT p.id, p.label, p.metadata FROM properties p
    INNER JOIN properties_owners o ON p.ownerid = o.id
    WHERE o.type = 'user' AND o.identifier = ?
]]

local ALL_QUERY = [[
    SELECT p.id, p.label, p.address, p.type, o.identifier AS owner, o.purchase_price, pr.price
    FROM properties p
    LEFT JOIN properties_owners o ON p.ownerid = o.id
    LEFT JOIN properties_prices pr ON p.priceid = pr.id
]]

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await(OWNED_QUERY, { citizenId }) or {}) do
        local metadata = DecodeJson(row.metadata)
        local coords = metadata?.coords
        properties[#properties + 1] = {
            id = row.id,
            name = row.label or 'Property',
            coords = coords?.x and vec3(coords.x, coords.y, coords.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await(ALL_QUERY) or {}) do
        local label = row.label or row.address or 'Property'
        properties[#properties + 1] = {
            id = row.id,
            label = label,
            address = row.address or label,
            owner = row.owner or 'Unowned',
            price = tonumber(row.price) or tonumber(row.purchase_price) or 0,
            type = row.type or 'Residential',
        }
    end
    return properties
end
