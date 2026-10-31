if not UseBridge('garages', 'jg-advancedgarages') then return end

---@return table<string, { Name: string, Label: string?, Vehicles: table[] }>
function GetDefinedGarages()
    local garages = {}
    for key, garage in pairs(exports['jg-advancedgarages']:getAllGarages() or {}) do
        local name = type(garage) == 'table' and (garage.name or (type(key) == 'string' and key))
        if name and name ~= '' then
            garages[name] = { Name = name, Label = garage.label or name, Vehicles = {} }
        end
    end
    return garages
end
