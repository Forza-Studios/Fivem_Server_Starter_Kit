if not Config.SocietyMoney or not Config.SocietyMoney.Enabled then return end

local currentJob, currentGrade = nil, nil

local function OnJobChange(job)
    if not job then return end
    local grade = type(job.grade) == 'table' and (job.grade.level or 0) or (job.grade or 0)
    if job.name ~= currentJob or grade ~= currentGrade then
        currentJob, currentGrade = job.name, grade
        if IsPlayerLoaded() and IsHudVisible() then SetTimeout(200, FetchSocietyMoney) end
    end
end

local function RefreshSocietyDelayed()
    if IsPlayerLoaded() and IsHudVisible() then SetTimeout(300, FetchSocietyMoney) end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', OnJobChange)
RegisterNetEvent('esx:setJob', OnJobChange)
RegisterNetEvent('qb-bossmenu:client:refreshAccount', RefreshSocietyDelayed)
RegisterNetEvent('banking:societyUpdate', RefreshSocietyDelayed)
RegisterNetEvent('codem-bossmenuv2:client:updateSociety', RefreshSocietyDelayed)
RegisterNetEvent('qb-banking:societyUpdated', RefreshSocietyDelayed)
RegisterNetEvent('qb-management:client:refreshAccount', RefreshSocietyDelayed)
RegisterNetEvent('renewed-banking:accountUpdated', RefreshSocietyDelayed)
RegisterNetEvent('g-boss-menu:client:societyUpdate', RefreshSocietyDelayed)

-- Periodic refresh (catches withdrawals/deposits from any script)
CreateThread(function()
    while true do
        Wait(15000)
        if IsPlayerLoaded() and IsHudVisible() then
            FetchSocietyMoney()
        end
    end
end)

debugPrint('[Society] Module loaded')
