--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              CUSTOM SOCIETY MONEY INTEGRATION                  ║
    ║                      (Server-Side)                             ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  This file is ONLY used when:                                 ║
    ║  Config.SocietyMoney.Script = 'custom'                        ║
    ║                                                               ║
    ║  If you're using a supported script, set Script = 'auto'     ║
    ║  and you don't need to edit this file at all!                ║
    ║                                                               ║
    ║  Supported scripts (auto-detected):                          ║
    ║    qb-management, qb-bossmenu, qb-banking, renewed-banking,  ║
    ║    esx_society, esx_addonaccount, okokBanking,               ║
    ║    codem-bossmenuv2, mBossmenu                               ║
    ╚═══════════════════════════════════════════════════════════════╝

    ═══════════════════════════════════════════════════════════════
    REFRESH EVENT - Add this to your banking script!
    ═══════════════════════════════════════════════════════════════

    After deposit/withdraw, trigger this event to update the HUD:

    -- From server (after transaction):
    TriggerClientEvent('codem-hud:RefreshSociety', source)

    -- From client (after callback):
    TriggerEvent('codem-hud:RefreshSociety')
]]

if not Config.SocietyMoney or Config.SocietyMoney.Script ~= 'custom' then
    return
end

-- ═══════════════════════════════════════════════════════════════
-- EDIT THIS FUNCTION
-- ═══════════════════════════════════════════════════════════════
-- Return the society/job account money for the given job name
-- This runs on SERVER-SIDE
--
-- @param jobName (string) - The job name (e.g., 'police', 'ambulance')
-- @return (number or nil) - The society money amount

function CustomGetSocietyMoney(jobName)
    -- ┌─────────────────────────────────────────────────────────┐
    -- │ EXAMPLE 1: Export from another script                   │
    -- └─────────────────────────────────────────────────────────┘
    -- return exports['your-banking-script']:GetJobMoney(jobName)

    -- ┌─────────────────────────────────────────────────────────┐
    -- │ EXAMPLE 2: Database query                               │
    -- └─────────────────────────────────────────────────────────┘
    -- local result = MySQL.scalar.await(
    --     'SELECT money FROM society_accounts WHERE job_name = ?',
    --     { jobName }
    -- )
    -- return result

    -- Default: disabled (returns nil)
    return nil
end

debugPrint('[Society] Custom module loaded')
