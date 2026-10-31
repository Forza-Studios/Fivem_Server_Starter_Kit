if not UseBridge('properties', 'qbx_apartments') then return end

function GetPlayerProperties(citizenId)
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, name, label FROM apartments WHERE citizenid = ?', { citizenId }) or {}) do
        properties[#properties + 1] = { id = row.id, name = row.name, address = row.label }
    end
    return properties
end

function GetAllProperties()
    local properties = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, name, label, citizenid FROM apartments') or {}) do
        properties[#properties + 1] = {
            id = row.id,
            label = row.name,
            address = row.label,
            owner = row.citizenid or 'Unowned',
            price = 0,
            type = 'Apartment',
        }
    end
    return properties
end
