if not UseBridge('properties', 'bnl-housing') then return end

local OWNED_QUERY = [[
    SELECT p.id AS id, p.street_name AS label, p.entrance_location AS door_data
    FROM properties p JOIN property_key pk ON pk.property_id = p.id
    WHERE pk.player = ? AND pk.permission IN ('owner', 'member', 'renter')
]]

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await(OWNED_QUERY, { citizenId }) or {}) do
        local coords = DecodeJson(row.door_data)
        properties[#properties + 1] = {
            id = row.id,
            name = row.label,
            coords = coords?.x and vec3(coords.x, coords.y, coords.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, street_name, name, owner, price FROM properties') or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.street_name or row.name or 'Property',
            address = row.street_name or row.name or 'N/A',
            owner = row.owner or 'Unowned',
            price = tonumber(row.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
