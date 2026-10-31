--[[
    Vehicle Controls System
    - Door controls
    - Window controls
    - Seat switching
    - Lock toggle
]]

-- ═══════════════════════════════════════════════════════════════
-- DOOR SYSTEM
-- ═══════════════════════════════════════════════════════════════

local function GetDoorNames()
    return {
        [0] = L('vehicle.driver'),
        [1] = L('vehicle.passenger'),
        [2] = L('vehicle.rear_left'),
        [3] = L('vehicle.rear_right'),
        [4] = L('vehicle.hood'),
        [5] = L('vehicle.trunk')
    }
end

local DOOR_BONES = {
    [0] = 'door_dside_f',
    [1] = 'door_pside_f',
    [2] = 'door_dside_r',
    [3] = 'door_pside_r',
    [4] = 'bonnet',
    [5] = 'boot'
}

local function DoorExists(vehicle, doorIndex)
    local bone = DOOR_BONES[doorIndex]
    if not bone then return false end
    return GetEntityBoneIndexByName(vehicle, bone) ~= -1
end

local function GetVehicleDoorInfo(vehicle)
    if not vehicle or vehicle == 0 then
        return { isLocked = false, lockStatus = 1, doors = {}, error = 'No vehicle' }
    end

    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    local isLocked = lockStatus == 2 or lockStatus == 3
    local doors = {}

    for doorIndex = 0, 5 do
        if DoorExists(vehicle, doorIndex) then
            local angleRatio = GetVehicleDoorAngleRatio(vehicle, doorIndex)
            local isOpen = IsVehicleDoorDamaged(vehicle, doorIndex) or angleRatio > 0.1

            table.insert(doors, {
                id = doorIndex,
                name = GetDoorNames()[doorIndex] or ('Door ' .. doorIndex),
                isOpen = isOpen,
                angleRatio = angleRatio
            })
        end
    end

    return {
        isLocked = isLocked,
        lockStatus = lockStatus,
        doors = doors
    }
end

RegisterNUICallback('GET_DOOR_INFO', function(_, cb)
    local vehicle = Utils.GetCurrentVehicle()
    cb(GetVehicleDoorInfo(vehicle))
end)

RegisterNUICallback('TOGGLE_DOOR', function(data, cb)
    local vehicle = Utils.GetCurrentVehicle()
    if vehicle == 0 then
        return cb({ success = false, error = 'Not in vehicle' })
    end

    local doorIndex = data.doorIndex
    if doorIndex == nil then
        return cb({ success = false, error = 'No door index' })
    end

    if data.shouldOpen then
        SetVehicleDoorOpen(vehicle, doorIndex, false, false)
    else
        SetVehicleDoorShut(vehicle, doorIndex, false)
    end

    cb({ success = true })
end)

function PlayLockEffect(vehicle)
    PlaySoundFrontend(-1, "Remote_Control_Fob", "PI_Menu_Sounds", true)
    CreateThread(function()
        SetVehicleLights(vehicle, 2)
        Wait(200)
        SetVehicleLights(vehicle, 0)
        Wait(150)
        SetVehicleLights(vehicle, 2)
        Wait(200)
        SetVehicleLights(vehicle, 0)
    end)
end

RegisterNUICallback('TOGGLE_LOCK', function(_, cb)
    local vehicle = Utils.GetCurrentVehicle()
    if vehicle == 0 then
        return cb({ success = false, error = 'Not in vehicle' })
    end

    PlayLockEffect(vehicle)

    local lockScript = Config.VehiclePanel and Config.VehiclePanel.LockScript
    local bridge = lockScript and LockBridge and LockBridge[lockScript]

    if bridge and bridge.ToggleLock then
        pcall(bridge.ToggleLock, vehicle)
    else
        local currentLockStatus = GetVehicleDoorLockStatus(vehicle)
        local isLocked = currentLockStatus == 2 or currentLockStatus == 3
        if isLocked then
            SetVehicleDoorsLocked(vehicle, 1)
        else
            SetVehicleDoorsLocked(vehicle, 2)
        end
    end

    Wait(100)

    local doorInfo = GetVehicleDoorInfo(vehicle)
    cb({ success = true, doorInfo = doorInfo })
end)

-- ═══════════════════════════════════════════════════════════════
-- WINDOW SYSTEM
-- ═══════════════════════════════════════════════════════════════

local function GetWindowNames()
    return {
        [0] = L('vehicle.driver'),
        [1] = L('vehicle.front_right'),
        [2] = L('vehicle.rear_left'),
        [3] = L('vehicle.rear_right')
    }
end

-- Track window states (GTA doesn't have a native to check window state)
-- LRU-style cleanup: max 20 vehicles tracked, oldest removed first
local windowStates = {}
local windowStateOrder = {}
local MAX_WINDOW_STATES = 20

local function GetWindowKey(vehicle)
    return Utils.GetNormalizedPlate(vehicle)
end

local function CleanupOldWindowStates()
    while #windowStateOrder > MAX_WINDOW_STATES do
        local oldestKey = table.remove(windowStateOrder, 1)
        windowStates[oldestKey] = nil
    end
end

local function TouchWindowState(key)
    -- Move to end of order (most recently used)
    for i, k in ipairs(windowStateOrder) do
        if k == key then
            table.remove(windowStateOrder, i)
            break
        end
    end
    table.insert(windowStateOrder, key)
    CleanupOldWindowStates()
end

local function GetVehicleWindowInfo(vehicle)
    if not vehicle or vehicle == 0 then
        return { windows = {}, error = 'No vehicle' }
    end

    local key = GetWindowKey(vehicle)
    if key == '' then
        return { windows = {}, error = 'Invalid vehicle' }
    end

    if not windowStates[key] then
        windowStates[key] = { false, false, false, false }
    end
    TouchWindowState(key)

    -- Araç kapı sayısına göre cam sayısını belirle
    local numDoors = GetNumberOfVehicleDoors(vehicle)
    local maxWindows = 2 -- Varsayılan: sadece ön camlar
    if numDoors >= 4 then
        maxWindows = 4 -- 4+ kapılı araçlarda arka camlar da var
    end

    local windows = {}
    for windowIndex = 0, maxWindows - 1 do
        table.insert(windows, {
            id = windowIndex,
            name = GetWindowNames()[windowIndex] or ('Window ' .. windowIndex),
            isOpen = windowStates[key][windowIndex + 1] or false
        })
    end

    return { windows = windows }
end

function IsAnyWindowRolledDown(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local key = GetWindowKey(vehicle)
    if key == '' or not windowStates[key] then return false end
    for i = 1, 4 do
        if windowStates[key][i] then return true end
    end
    return false
end

RegisterNUICallback('GET_WINDOW_INFO', function(_, cb)
    local vehicle = Utils.GetCurrentVehicle()
    cb(GetVehicleWindowInfo(vehicle))
end)

RegisterNUICallback('TOGGLE_WINDOW', function(data, cb)
    local vehicle = Utils.GetCurrentVehicle()
    if vehicle == 0 then
        return cb({ success = false, error = 'Not in vehicle' })
    end

    local windowIndex = data.windowIndex
    if windowIndex == nil then
        return cb({ success = false, error = 'No window index' })
    end

    local key = GetWindowKey(vehicle)
    if key == '' then
        return cb({ success = false, error = 'Invalid vehicle' })
    end

    if not windowStates[key] then
        windowStates[key] = { false, false, false, false }
    end
    TouchWindowState(key)

    local isCurrentlyOpen = windowStates[key][windowIndex + 1]

    if isCurrentlyOpen then
        RollUpWindow(vehicle, windowIndex)
        windowStates[key][windowIndex + 1] = false
    else
        RollDownWindow(vehicle, windowIndex)
        windowStates[key][windowIndex + 1] = true
    end

    cb({ success = true, windowInfo = GetVehicleWindowInfo(vehicle) })
end)

-- ═══════════════════════════════════════════════════════════════
-- SEAT SYSTEM
-- ═══════════════════════════════════════════════════════════════

local function GetSeatNames()
    return {
        [-1] = L('vehicle.drivers_seat'),
        [0] = L('vehicle.front_passenger'),
        [1] = L('vehicle.rear_left'),
        [2] = L('vehicle.rear_right'),
        [3] = L('vehicle.extra_seat', 1),
        [4] = L('vehicle.extra_seat', 2),
        [5] = L('vehicle.extra_seat', 3)
    }
end

local function GetVehicleSeatInfo(vehicle)
    if not vehicle or vehicle == 0 then
        return { currentSeat = 1, seats = {}, totalSeats = 0, error = 'No vehicle' }
    end

    local ped = cache.ped
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle) + 1 -- +1 for driver
    local currentSeatIndex = nil

    -- Find current seat
    for seatIndex = -1, maxSeats - 2 do
        if GetPedInVehicleSeat(vehicle, seatIndex) == ped then
            currentSeatIndex = seatIndex
            break
        end
    end

    local seats = {}
    for seatIndex = -1, maxSeats - 2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seatIndex)
        local isOccupied = pedInSeat ~= 0 and pedInSeat ~= ped
        local isCurrent = seatIndex == currentSeatIndex

        table.insert(seats, {
            id = seatIndex + 2, -- Convert to 1-based ID (driver = 1)
            seatIndex = seatIndex,
            name = GetSeatNames()[seatIndex] or ('Seat ' .. (seatIndex + 2)),
            isOccupied = isOccupied,
            isCurrent = isCurrent
        })
    end

    return {
        currentSeat = currentSeatIndex and (currentSeatIndex + 2) or 1,
        seats = seats,
        totalSeats = maxSeats
    }
end

RegisterNUICallback('GET_SEAT_INFO', function(_, cb)
    local vehicle = Utils.GetCurrentVehicle()
    cb(GetVehicleSeatInfo(vehicle))
end)

RegisterNUICallback('CHANGE_SEAT', function(data, cb)
    local vehicle = Utils.GetCurrentVehicle()
    if vehicle == 0 then
        return cb({ success = false, error = 'Not in vehicle' })
    end

    local targetSeatIndex = data.seatIndex
    if targetSeatIndex == nil then
        return cb({ success = false, error = 'No seat index' })
    end

    local ped = cache.ped

    if GetPedInVehicleSeat(vehicle, -1) == ped and GetEntitySpeed(vehicle) > 0.5 then
        Notify(L('boat_notify.cannot_change_while_driving'), 'error')
        return cb({ success = false, error = 'Cannot change seat while driving' })
    end

    local pedInSeat = GetPedInVehicleSeat(vehicle, targetSeatIndex)
    if pedInSeat ~= 0 then
        Notify(L('boat_notify.seat_occupied'), 'error')
        return cb({ success = false, error = 'Seat is occupied' })
    end

    -- Shuffle to the new seat
    SetPedIntoVehicle(ped, vehicle, targetSeatIndex)

    -- Wait for animation
    Wait(200)

    local seatInfo = GetVehicleSeatInfo(vehicle)
    cb({ success = true, seatInfo = seatInfo })
end)

-- Clean up window states when player exits vehicle
AddEventHandler('codem-hud:client:VehicleExited', function()
    -- Keep states for a while in case player re-enters same vehicle
end)

debugPrint('[VehicleControls] Module loaded')
