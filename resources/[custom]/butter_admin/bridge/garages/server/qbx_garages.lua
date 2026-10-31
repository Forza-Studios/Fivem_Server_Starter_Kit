if not UseBridge('garages', 'qbx_garages') then return end

---@return table<string, { Name: string, Label: string?, Vehicles: table[] }>
function GetDefinedGarages()
    local garages = {}
    for name, garage in pairs(exports.qbx_garages:GetGarages() or {}) do
        garages[name] = {
            Name = name,
            Label = type(garage) == 'table' and garage.label or name,
            Vehicles = {},
        }
    end
    return garages
end
