--[[
    Boat Features
    Handles anchor deployment and seat changing for boats
]]

local anchorDeployed = false
local currentBoat = 0
local currentSeat = 0

-- Check if vehicle is a boat
local function IsBoat(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local modelHash = GetEntityModel(vehicle)
    return IsThisModelABoat(modelHash)
end

-- Get current boat if player is in one
local function GetCurrentBoat()
    local ped = PlayerPedId()
    if not IsPedInAnyBoat(ped) then return 0 end
    return GetVehiclePedIsIn(ped, false)
end

-- Anchor thread handle
local anchorThread = nil

-- Get boat speed in km/h
local function GetBoatSpeed(boat)
    return GetEntitySpeed(boat) * 3.6
end

-- Toggle anchor state
local function ToggleAnchor(deployed)
    local boat = GetCurrentBoat()
    if boat == 0 then
        debugPrint('[Boat] Not in a boat, cannot toggle anchor')
        return false
    end

    currentBoat = boat

    if deployed and GetBoatSpeed(boat) > 10.0 then
        debugPrint('[Boat] Too fast to deploy anchor')
        Notify(L('boat_notify.anchor_too_fast'), 'error')
        return false
    end

    anchorDeployed = deployed

    if deployed then
        -- Deploy anchor - use native anchor + gentle resistance
        SetBoatAnchor(boat, true)
        SetBoatFrozenWhenAnchored(boat, true)

        -- Gradually slow down the boat
        local vel = GetEntityVelocity(boat)
        SetEntityVelocity(boat, vel.x * 0.3, vel.y * 0.3, vel.z * 0.3)

        -- Start anchor hold thread - keeps boat mostly still but allows slight wave movement
        if anchorThread then return true end
        anchorThread = CreateThread(function()
            local anchorPos = GetEntityCoords(boat)
            local maxDrift = 1.5 -- Allow 1.5m drift for natural feel

            while anchorDeployed and currentBoat ~= 0 do
                Wait(100)

                if not DoesEntityExist(currentBoat) then break end

                local currentPos = GetEntityCoords(currentBoat)
                local distance = #(currentPos.xy - anchorPos.xy)

                -- If drifted too far, gently pull back
                if distance > maxDrift then
                    local dirX = (anchorPos.x - currentPos.x) / distance
                    local dirY = (anchorPos.y - currentPos.y) / distance

                    -- Apply gentle force toward anchor point
                    local vel = GetEntityVelocity(currentBoat)
                    SetEntityVelocity(currentBoat,
                        vel.x * 0.9 + dirX * 0.5,
                        vel.y * 0.9 + dirY * 0.5,
                        vel.z
                    )
                end

                -- Dampen any strong movement
                local vel = GetEntityVelocity(currentBoat)
                local speed = #(vel.xy)
                if speed > 1.0 then
                    SetEntityVelocity(currentBoat, vel.x * 0.85, vel.y * 0.85, vel.z)
                end
            end

            anchorThread = nil
        end)

        debugPrint('[Boat] Anchor deployed')
        Notify(L('boat_notify.anchor_deployed'), 'success')
    else
        -- Retract anchor - allow boat to move freely
        SetBoatAnchor(boat, false)
        SetBoatFrozenWhenAnchored(boat, false)

        -- Stop anchor thread
        anchorThread = nil

        debugPrint('[Boat] Anchor retracted')
        Notify(L('boat_notify.anchor_retracted'), 'success')
    end

    -- Update UI
    SendNUIMessage({
        action = 'boat:setAnchorState',
        data = { deployed = deployed }
    })

    return true
end

-- Get current anchor state
local function GetAnchorState()
    return {
        deployed = anchorDeployed,
        inBoat = GetCurrentBoat() ~= 0
    }
end

-- Get max seats for current boat
local function GetBoatMaxSeats(boat)
    if not boat or boat == 0 then return 0 end
    return GetVehicleMaxNumberOfPassengers(boat) + 1 -- +1 for driver
end

-- Get current seat index (0-based)
local function GetCurrentSeatIndex()
    local ped = PlayerPedId()
    local boat = GetCurrentBoat()
    if boat == 0 then return -1 end

    for i = -1, GetVehicleMaxNumberOfPassengers(boat) - 1 do
        if GetPedInVehicleSeat(boat, i) == ped then
            return i + 1 -- Convert to 0-based (driver = 0)
        end
    end
    return -1
end

-- Change seat in boat
local function ChangeSeat(targetSeat)
    local ped = PlayerPedId()
    local boat = GetCurrentBoat()
    if boat == 0 then
        debugPrint('[Boat] Not in a boat, cannot change seat')
        return false
    end

    local maxSeats = GetBoatMaxSeats(boat)
    if targetSeat < 0 or targetSeat >= maxSeats then
        debugPrint('[Boat] Invalid seat index:', targetSeat)
        return false
    end

    -- FiveM seat indices: -1 = driver, 0 = front passenger, 1+ = back seats
    local seatIndex = targetSeat - 1

    -- Check if seat is free
    if not IsVehicleSeatFree(boat, seatIndex) then
        debugPrint('[Boat] Seat is occupied:', targetSeat)
        Notify(L('boat_notify.seat_occupied'), 'error')
        return false
    end

    -- Move to seat
    SetPedIntoVehicle(ped, boat, seatIndex)
    currentSeat = targetSeat

    debugPrint('[Boat] Changed to seat:', targetSeat)

    -- Update UI
    SendNUIMessage({
        action = 'boat:setSeatState',
        data = {
            currentSeat = currentSeat,
            maxSeats = maxSeats
        }
    })

    return true
end

-- Update seat state to UI
local function UpdateSeatState()
    local boat = GetCurrentBoat()
    if boat == 0 then return end

    currentSeat = GetCurrentSeatIndex()
    local maxSeats = GetBoatMaxSeats(boat)

    SendNUIMessage({
        action = 'boat:setSeatState',
        data = {
            currentSeat = currentSeat,
            maxSeats = maxSeats
        }
    })
end

-- NUI Callbacks
RegisterNUICallback('boat:toggleAnchor', function(data, cb)
    local deployed = data.deployed
    local success = ToggleAnchor(deployed)
    cb({ success = success, deployed = anchorDeployed })
end)

RegisterNUICallback('boat:getState', function(data, cb)
    local state = GetAnchorState()

    SendNUIMessage({
        action = 'boat:setAnchorState',
        data = { deployed = state.deployed }
    })

    cb(state)
end)

-- Seat change callbacks
RegisterNUICallback('boat:changeSeat', function(data, cb)
    local targetSeat = data.seat
    local success = ChangeSeat(targetSeat)
    cb({ success = success, currentSeat = currentSeat })
end)

RegisterNUICallback('boat:getSeatState', function(data, cb)
    UpdateSeatState()
    cb({ currentSeat = currentSeat, maxSeats = GetBoatMaxSeats(GetCurrentBoat()) })
end)

-- When leaving boat, just reset local tracking (anchor stays as is on boat)
RegisterNetEvent('codem-hud:client:baseevents:leftVehicle', function()
    -- Stop anchor thread first to prevent leak
    anchorDeployed = false
    currentBoat = 0
    anchorThread = nil
end)

-- When swapping vehicles, reset boat state and re-check
AddEventHandler('codem-hud:client:baseevents:vehicleSwapped', function(vehicle, seat)
    anchorDeployed = false
    currentBoat = 0
    anchorThread = nil
    if IsBoat(vehicle) then
        currentBoat = vehicle
        anchorDeployed = IsBoatAnchoredAndFrozen(vehicle)
        SendNUIMessage({ action = 'boat:setAnchorState', data = { deployed = anchorDeployed } })
    end
end)

-- When entering a boat, check its anchor and seat state
RegisterNetEvent('codem-hud:client:baseevents:enteredVehicle', function(vehicle, seat)
    if IsBoat(vehicle) then
        currentBoat = vehicle
        anchorDeployed = IsBoatAnchoredAndFrozen(vehicle)

        SendNUIMessage({
            action = 'boat:setAnchorState',
            data = { deployed = anchorDeployed }
        })

        -- Update seat state
        UpdateSeatState()

        debugPrint('[Boat] Entered boat, anchor state:', anchorDeployed)
    end
end)

-- Fallback for servers without baseevents (only runs if baseevents not available)
local useBaseevents = GetResourceState('baseevents') == 'started'
if not useBaseevents then
    CreateThread(function()
        local wasInBoat = false

        while true do
            Wait(500)

            local boat = GetCurrentBoat()
            local inBoat = boat ~= 0

            if inBoat ~= wasInBoat then
                wasInBoat = inBoat

                if inBoat then
                    currentBoat = boat
                    anchorDeployed = IsBoatAnchoredAndFrozen(boat)

                    SendNUIMessage({
                        action = 'boat:setAnchorState',
                        data = { deployed = anchorDeployed }
                    })

                    -- Update seat state
                    UpdateSeatState()
                else
                    -- Left boat - just reset local vars, don't touch anchor
                    anchorDeployed = false
                    currentBoat = 0
                    currentSeat = 0
                end
            end
        end
    end)
end

-- Export functions
exports('IsAnchorDeployed', function() return anchorDeployed end)
exports('ToggleBoatAnchor', ToggleAnchor)
exports('GetBoatAnchorState', GetAnchorState)

debugPrint('[Boat] Boat anchor feature loaded')
