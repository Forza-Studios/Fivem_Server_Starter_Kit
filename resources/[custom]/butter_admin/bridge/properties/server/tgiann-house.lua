if not UseBridge('properties', 'tgiann-house') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, name FROM tgiann_house WHERE owner = ?', { citizenId }) or {}) do
        properties[#properties + 1] = { id = row.id, name = row.name }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, name, owner, price FROM tgiann_house') or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.name or 'Property',
            address = row.name or 'N/A',
            owner = row.owner or 'Unowned',
            price = tonumber(row.price) or 0,
            type = 'Residential',
        }
    end
    return properties
end
