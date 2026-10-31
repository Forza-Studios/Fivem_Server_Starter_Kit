if not UseBridge('properties', 'ps-housing') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT property_id, street, door_data FROM properties WHERE owner_citizenid = ?', { citizenId }) or {}) do
        local coords = DecodeJson(row.door_data)
        properties[#properties + 1] = {
            id = row.property_id,
            name = row.street,
            coords = coords?.x and vec3(coords.x, coords.y, coords.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT property_id, street, owner_citizenid, price FROM properties') or {}) do
        properties[#properties + 1] = {
            id = row.property_id,
            label = row.street,
            address = row.street,
            owner = row.owner_citizenid or 'Unowned',
            price = tonumber(row.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
