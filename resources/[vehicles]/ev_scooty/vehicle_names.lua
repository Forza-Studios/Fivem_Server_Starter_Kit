-- vehicle_names.lua
-- Added by gta5modsconvertor.com so the vehicle shows a name in game instead of NULL.
-- Each line gives a text to a key from vehicles.meta: <gameName> is the vehicle's
-- name, <vehicleMakeName> its manufacturer. The texts are derived from those keys,
-- not from the mod's title. To rename a vehicle, edit the last quoted value on its
-- line and restart the resource.
-- A key that already has a text (a base-game name, or one set by a resource that
-- started earlier) is left as it is.

if GetLabelText('jiuhao_e300_1_bsgta') == 'NULL' then AddTextEntry('jiuhao_e300_1_bsgta', 'Jiuhao E300 1 Bsgta') end -- spawn name: jiuhao_e300_1_bsgta
if GetLabelText('PEGASSI') == 'NULL' then AddTextEntry('PEGASSI', 'Pegassi') end -- manufacturer
