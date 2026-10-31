if not UseBridge('properties', 'tk_housing') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, property in pairs(exports.tk_housing:getPropertiesByIdentifier(citizenId) or {}) do
        properties[#properties + 1] = { id = property.id, name = property.name or property.address }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, property in pairs(exports.tk_housing:getProperties() or {}) do
        properties[#properties + 1] = {
            id = property.id,
            label = property.name or property.address or 'Property',
            address = property.address or property.name or 'N/A',
            owner = property.owner or property.citizenid or 'Unowned',
            price = tonumber(property.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
