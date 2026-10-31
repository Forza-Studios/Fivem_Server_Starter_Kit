if not UseBridge('properties', 'vms_housing') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, property in pairs(exports.vms_housing:GetPlayerProperties(citizenId) or {}) do
        local enter = property.metadata and property.metadata.enter
        properties[#properties + 1] = {
            id = property.id,
            name = property.name,
            address = property.address,
            coords = enter and vec3(enter.x, enter.y, enter.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, property in pairs(exports.vms_housing:GetAllProperties() or {}) do
        properties[#properties + 1] = {
            id = property.id,
            label = property.name or property.address or 'Property',
            address = property.address or 'N/A',
            owner = property.owner or property.citizenid or 'Unowned',
            price = tonumber(property.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
