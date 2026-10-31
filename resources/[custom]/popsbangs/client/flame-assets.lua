
PopsNativeFlameAssets = {}

local colours = {
    "cobalt", "cyan", "turquoise", "emerald", "lime", "ruby", "orange",
    "yellow", "gold", "copper", "amethyst", "magenta", "pearl", "black"
}

function BuildFlameAssetDefinition(colourName)
    local assetDict = "oxlyn_exhaust_flames_v1"
    return {
        core = {
            veh_backfire = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_backfire" },
            veh_backfire_narrow = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_backfire_narrow" },
            veh_sm_car_small_backfire = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_sm_car_small_backfire" },
            veh_exhaust_afterburner = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_exhaust_afterburner" }
        },
        veh_xs_vehicle_mods = {
            veh_nitrous = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_nitrous" }
        },
        veh_impexp_rocket = {
            veh_rocket_boost = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_rocket_boost" }
        },
        veh_sanctus = {
            veh_sanctus_backfire = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_sanctus_backfire" }
        },
        veh_thruster = {
            veh_xm_thruster_afterburner = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_xm_thruster_afterburner" }
        },
        veh_sm_pyro = {
            veh_exhaust_afterburner_pyro = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_exhaust_afterburner_pyro" }
        },
        veh_sm_vig = {
            veh_rocket_boost_vig = { asset = assetDict, name = "oxlyn_" .. colourName .. "_veh_rocket_boost_vig" }
        }
    }
end

for _, colour in ipairs(colours) do
    PopsNativeFlameAssets[colour] = BuildFlameAssetDefinition(colour)
end
--fivevault-n-OnOITop3s : https://discord.gg/fivevault
--fivevault$DOn-DTopqU : https://discord.gg/fivevault
--fivevaultsN4OnSOTopyq : https://discord.gg/fivevault
--fivevaults7sOnxJTopXw : https://discord.gg/fivevault
--fivevault-3pOnFQTopN- : https://discord.gg/fivevault
