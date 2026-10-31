fx_version 'cerulean'
games { 'gta5' }
files {
	'common/vehicles.meta',
	'common/carvariations.meta',
	'common/handling.meta',
	'common/*.meta'
}
data_file 'HANDLING_FILE' 'common/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'common/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE' 'common/carvariations.meta'
client_script 'vehicle_names.lua'
