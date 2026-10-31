local commands = Config.Menu.Commands

lib.addCommand(commands.Open, { help = locale('info.keymapping_desc') }, function(source)
    if not IsAuthorized(source, 'menuopen') then return Notify(source, locale('info.no_perm'), 'error') end
    if not IsOnDutyOrExempt(source) then return Notify(source, locale('info.not_on_duty'), 'error') end

    TriggerClientEvent('butter_admin:client:openMenu', source)
    SyncReportsForPlayer(source)
    SyncStaffChatForPlayer(source)
end)

lib.addCommand(commands.Reset, { help = locale('info.reset_data') }, function(source)
    if not IsAuthorized(source, 'menureset') then
        return Notify(source, locale(WasDutyDeniedOnly(source) and 'info.not_on_duty' or 'info.no_perm'), 'error')
    end
    TriggerClientEvent('butter_admin:client:resetPreferences', source)
end)

lib.addCommand(commands.Report, { help = locale('info.send_report') }, function(source)
    SyncReportsForPlayer(source)
    TriggerClientEvent('butter_admin:client:openReport', source)
end)
