if not UseBridge('properties', 'qb-houses') then return end

local OWNED_QUERY = [[
    (SELECT hl.id AS id, hl.label AS label, hl.coords AS coords
        FROM player_houses ph JOIN houselocations hl ON ph.house = hl.name
        WHERE ph.citizenid = ?)
    UNION ALL
    (SELECT a.id AS id, a.label AS label, NULL AS coords
        FROM apartments a WHERE a.citizenid = ?)
]]

local ALL_QUERY = [[
    (SELECT ph.id AS id, hl.label AS label, ph.citizenid AS owner, hl.price AS price, 'House' AS type
        FROM player_houses ph JOIN houselocations hl ON ph.house = hl.name)
    UNION ALL
    (SELECT a.id AS id, a.label AS label, a.citizenid AS owner, 0 AS price, 'Apartment' AS type
        FROM apartments a)
]]

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await(OWNED_QUERY, { citizenId, citizenId }) or {}) do
        local coords = DecodeJson(row.coords)
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
    for _, row in ipairs(MySQL.query.await(ALL_QUERY) or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.label,
            address = row.label,
            owner = row.owner or 'Unowned',
            price = tonumber(row.price) or 0,
            type = row.type,
        }
    end
    return properties
end
