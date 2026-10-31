if not UseBridge('properties', 'bcs_housing') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for index, home in pairs(exports.bcs_housing:GetOwnedHomeKeys(citizenId) or {}) do
        local flat = home.data and home.data.flat
        local coords = home.complex == 'Flat' and flat and flat.coords or home.entry
        properties[#properties + 1] = {
            id = home.id or index,
            name = home.name,
            coords = coords and vec3(coords.x, coords.y, coords.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    -- The owner column is `identifier` or `owner` depending on the bcs_housing version.
    for _, row in ipairs(MySQL.query.await('SELECT * FROM houses') or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.name or 'Property',
            address = row.name or 'N/A',
            owner = row.identifier or row.owner or 'Unowned',
            price = tonumber(row.price) or 0,
            type = row.type or 'Residential',
        }
    end
    return properties
end
