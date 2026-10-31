if not UseBridge('properties', 'sn_properties') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, property in pairs(exports.sn_properties:getPlayerProperties(citizenId) or {}) do
        local coords = property.coords
        properties[#properties + 1] = {
            id = property.id,
            name = property.label,
            coords = coords and vec3(coords.x, coords.y, coords.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, property in pairs(exports.sn_properties:getAllProperties() or {}) do
        properties[#properties + 1] = {
            id = property.id,
            label = property.label or 'Property',
            address = property.label or 'N/A',
            owner = property.owner or 'Unowned',
            price = tonumber(property.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
