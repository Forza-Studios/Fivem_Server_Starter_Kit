if not UseBridge('properties', 'qbx_properties') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, property_name, coords FROM properties WHERE owner = ?', { citizenId }) or {}) do
        local coords = DecodeJson(row.coords)
        properties[#properties + 1] = {
            id = row.id,
            name = row.property_name,
            coords = coords?.x and vec3(coords.x, coords.y, coords.z) or nil,
        }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, property_name, owner, price, interior FROM properties') or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.property_name,
            address = row.property_name,
            owner = row.owner or 'Unowned',
            price = tonumber(row.price) or 0,
            type = row.interior or 'Residential',
        }
    end
    return properties
end

-- Decorations cascade in the database and qbx_properties reads the table on
-- every interaction, so no runtime state goes stale.
function DeleteProperty(id)
    return MySQL.update.await('DELETE FROM properties WHERE id = ?', { id }) > 0
end

function GetPropertyCoords(id)
    local coords = DecodeJson(MySQL.scalar.await('SELECT coords FROM properties WHERE id = ?', { id }))
    if type(coords) ~= 'table' then return nil end

    local entrance = coords.enter or coords
    local x, y, z = tonumber(entrance.x), tonumber(entrance.y), tonumber(entrance.z)
    if not (x and y and z) then return nil end
    return vec3(x, y, z)
end
