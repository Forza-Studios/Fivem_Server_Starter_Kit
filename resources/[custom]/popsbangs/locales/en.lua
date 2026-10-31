
-- ===========================================================================
--  locales/en.lua — English (the fallback for every other language)
-- ===========================================================================
--
--  Every text a player sees. Config.Locale (config/config.lua) picks the
--  language; a key missing from a language falls back to THIS file, so a
--  half-finished translation still reads.
--
--  Add a language by copying this file to locales/<code>.lua, renaming the
--  table, and listing it in fxmanifest.lua. Keep the keys and the
--  placeholders exactly as they are:
--    %s  a word or a name    %d  a whole number    %.0f  a rounded number
--  The order of the placeholders in a line must stay the same.
--
--  The names of the exhausts are not here: they are the `label` fields of
--  config/exhausts.lua.
-- ===========================================================================

Locales = Locales or {}

Locales.en = {
    -- commands and common refusals
    usage_pops = 'Use /%s with a level: %s.',
    usage_pops_server = 'Use /%s 0 to %d.',
    usage_antilag = 'Use /%s 1 to install or 0 to remove.',
    usage_antilag_server = 'Use /%s 0 or 1.',
    help_remove = '0: remove',
    cmd_pops_desc = 'Install or replace the pops and bangs level on the car you are driving.',
    cmd_pops_arg = 'level',
    cmd_antilag_desc = 'Install or remove the anti-lag (turbo sound) on this car.',
    cmd_antilag_arg = 'state',
    cmd_antilag_help = '1: install | 0: remove',
    need_driver = 'You have to be at the wheel of the vehicle.',
    need_driver_seat = 'You have to be in the driver\'s seat of a vehicle.',
    not_synced = 'This vehicle is not synchronised yet. Try again in a moment.',
    not_synced_short = 'This vehicle is not synchronised yet.',
    enter_car = 'Get in a car first.',
    no_permission_pops = 'You are not allowed to install pops and bangs.',
    no_permission_antilag = 'You are not allowed to install anti-lag.',
    pops_removed = 'Pops and bangs removed.',
    pops_installed = 'Pops and bangs: level %d (%s) installed.',
    antilag_on = 'Anti-lag installed: turbo active.',
    antilag_off = 'Anti-lag removed.',
    -- the valve remote
    need_valve_item = 'You need the valve control in your inventory.',
    valve_nothing = 'This vehicle has no custom exhaust and no pops and bangs installed.',
    finish_job_first = 'Finish the exhaust job first.',
    -- the workshop (items)
    kit_label = 'Anti-lag kit',
    remover_label = 'Removal kit',
    exhaust_item = '%s exhaust',
    stock_label = 'Stainless steel',
    job_busy = 'You already have a job in progress.',
    job_cancelled = 'Job cancelled.',
    left_car = 'You left the car: the job was left undone.',
    car_moved = 'The car moved: the job was left undone.',
    stop_first = 'Stop the car first.',
    no_antilag = 'This car has no anti-lag installed.',
    no_room_kit = 'No room in your inventory to keep the kit.',
    item_useless = 'This item is no use here.',
    exhaust_already = 'The %s exhaust is already fitted.',
    no_room_exhaust = 'No room in your inventory to keep the %s exhaust.',
    mechanic_only = 'Only a mechanic can do this.',
    item_gone = 'You no longer have that item.',
    not_finished = 'The work was not finished yet.',
    left_car_midwork = 'You left the car in the middle of the work.',
    car_changed = 'The car is no longer as it was.',
    choose_level = 'Choose a power level.',
    item_failed = 'The item could not be used.',
    part_refused = 'The car did not take the part.',
    done_install = 'Anti-lag installed: level %d (%s).',
    done_remove_kit = 'Anti-lag removed. The kit is back in your inventory.',
    done_remove = 'Anti-lag removed.',
    done_exhaust = '%s exhaust fitted. The %s exhaust went to your inventory.',
    -- debug commands
    rooms_measured = 'Space measured: %d walls, roof %s. Details in F8.',
    rooms_roof_at = 'at %.0f m',
    no = 'no',
    none = 'none',
    exhaust_debug = 'Exhaust: %s (%s). Cache %s, state bag %s. Last sync: %s.',
    exhaust_since = 'exhaust %s, %d s ago',
    -- the screen: titles and phases of the work
    ui_title_install = 'Installing the anti-lag',
    ui_title_remove = 'Removing the anti-lag',
    ui_title_tune = 'Anti-lag tuning',
    ui_title_exhaust = 'Fitting the %s exhaust',
    ph_install_1 = 'Opening the engine bay',
    ph_install_2 = 'Fixing the anti-lag module',
    ph_install_3 = 'Connecting the sensors and the valve',
    ph_install_4 = 'Tightening the terminals',
    ph_install_5 = 'Testing the turbo',
    ph_remove_1 = 'Disconnecting the battery',
    ph_remove_2 = 'Loosening the terminals',
    ph_remove_3 = 'Taking the module out',
    ph_remove_4 = 'Closing the engine bay',
    ph_exhaust_1 = 'Loosening the clamps',
    ph_exhaust_2 = 'Taking the exhaust off',
    ph_exhaust_3 = 'Seating the new exhaust',
    ph_exhaust_4 = 'Tightening the clamps',
    ph_exhaust_5 = 'Checking for leaks',
    -- the screen: selector, outcome, hints
    ui_power_level = 'Power level',
    ui_installed = 'installed',
    ui_installed_is = 'Installed: %s.',
    ui_choose = 'Choose the pops and bangs level.',
    ui_is_installed = 'This is the level installed.',
    ui_applying = 'Applying level %d',
    ui_saving = '%s: saving the tune to the car.',
    ui_done = 'Done',
    ui_failed = 'Not possible',
    ui_exhaust_done = 'Exhaust fitted. Rev it to hear it.',
    ui_remove_done = 'The car is back on its stock exhaust.',
    ui_antilag_ready = 'Anti-lag ready at level %d.',
    ui_ready = 'Ready.',
    ui_nothing_spent = 'Nothing was spent.',
    ui_spent = 'Spent: %s',
    ui_received = 'Received: %s',
    ui_you_receive = 'You receive: %s',
    ui_spends = 'Spends: %s',
    ui_cancel = 'cancel',
    ui_choose_key = 'choose',
    ui_confirm = 'confirm',
    ui_or = 'or',
    ui_bangs_rare = 'rare bangs',
    ui_bangs_some = 'occasional bangs',
    ui_bangs_limiter = 'bangs on the limiter',
    ui_bangs_constant = 'constant bangs',
    ui_reach = 'up to %d m',
    -- The decimal separator of this language, used on the screens.
    ui_decimal = '.'
}
--fivevaultsFyOnRtTopYi : https://discord.gg/fivevault
--fivevaultsW3One8Tope@ : https://discord.gg/fivevault
--fivevault-duOnujTopcy : https://discord.gg/fivevault
--fivevault$dOnHTTop-D : https://discord.gg/fivevault
--fivevaultsxAOnncTopPN : https://discord.gg/fivevault
