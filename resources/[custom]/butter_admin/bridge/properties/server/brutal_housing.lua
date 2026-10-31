if not UseBridge('properties', 'brutal_housing') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, label, coords, address FROM brutal_housing WHERE owner = ?', { citizenId }) or {}) do
        local coords = DecodeJson(row.coords)
        local door = coords?.door
        properties[#properties + 1] = {
            id = row.id,
            name = row.label,
            address = row.address,
            coords = door and vec3(door.x, door.y, door.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, label, address, owner, price FROM brutal_housing') or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.label or 'Property',
            address = row.address or 'N/A',
            owner = row.owner or 'Unowned',
            price = tonumber(row.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
