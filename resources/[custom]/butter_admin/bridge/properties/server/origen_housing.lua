if not UseBridge('properties', 'origen_housing') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, houseId in pairs(exports.origen_housing:getOwnedHouses(citizenId) or {}) do
        local house = exports.origen_housing:getHouse(houseId)
        if house then
            local positions = house.positions or {}
            local coords = positions.entry or positions.garage
            properties[#properties + 1] = {
                id = house.id,
                name = house.name,
                coords = coords and vec3(coords.x, coords.y, coords.z) or nil,
            }
        end
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, house in pairs(exports.origen_housing:getAllHouses() or {}) do
        properties[#properties + 1] = {
            id = house.id,
            label = house.name or 'Property',
            address = house.name or 'N/A',
            owner = house.owner or 'Unowned',
            price = tonumber(house.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
