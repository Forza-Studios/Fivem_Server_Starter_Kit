if not UseBridge('properties', 'qs-housing') then return end

local OWNED_QUERY = [[
    SELECT hl.id AS id, hl.label AS label, hl.coords AS coords
    FROM player_houses ph JOIN houselocations hl ON ph.house = hl.name
    WHERE ph.citizenid = ?
]]

local ALL_QUERY = [[
    SELECT ph.id AS id, hl.label AS label, ph.citizenid AS owner, hl.price AS price
    FROM player_houses ph JOIN houselocations hl ON ph.house = hl.name
]]

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await(OWNED_QUERY, { citizenId }) or {}) do
        local coords = DecodeJson(row.coords)
        local enter = coords?.enter
        properties[#properties + 1] = {
            id = row.id,
            name = row.label,
            coords = enter and vec3(enter.x, enter.y, enter.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await(ALL_QUERY) or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.label,
            address = row.label,
            owner = row.owner or 'Unowned',
            price = tonumber(row.price) or 0,
            type = 'House',
        }
    end
    return properties
end
