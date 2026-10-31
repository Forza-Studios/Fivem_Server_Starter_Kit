local isProgressActive = false
local canCancel = false
local currentAction = nil
local wasCancelled = false

-- Controls to disable during progressbar
local controls = {
    disableMouse = { 1, 2, 106 },
    disableMovement = { 30, 31, 36, 21, 75 },
    disableCarMovement = { 63, 64, 71, 72 },
    disableCombat = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 263, 264, 257 }
}

-- Variables for animations and props
local prop_net = nil
local propTwo_net = nil
local isAnim = false
local isProp = false
local isPropTwo = false

-- Helper functions
local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(5)
    end
end

local function loadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(5)
    end
end

local function createAndAttachProp(prop, ped)
    if not prop or not prop.model then return nil end
    loadModel(prop.model)
    local propEntity = CreateObject(GetHashKey(prop.model), 0.0, 0.0, 0.0, true, true, true)
    local netId = ObjToNet(propEntity)
    SetNetworkIdExistsOnAllMachines(netId, true)
    NetworkUseHighPrecisionBlending(netId, true)
    SetNetworkIdCanMigrate(netId, false)
    local boneIndex = GetPedBoneIndex(ped, prop.bone or 60309)
    AttachEntityToEntity(
        propEntity, ped, boneIndex,
        prop.coords.x, prop.coords.y, prop.coords.z,
        prop.rotation.x, prop.rotation.y, prop.rotation.z,
        true, true, false, true, 0, true
    )
    return netId
end

local function startAnimation(ped, action)
    if not action.animation then return end

    if action.animation.task then
        TaskStartScenarioInPlace(ped, action.animation.task, 0, true)
    elseif action.animation.animDict and action.animation.anim then
        loadAnimDict(action.animation.animDict)
        TaskPlayAnim(ped, action.animation.animDict, action.animation.anim, 3.0, 3.0, -1, action.animation.flags or 1, 0, false, false, false)
    end
end

local function startProps(ped, action)
    if action.prop and action.prop.model and not isProp then
        prop_net = createAndAttachProp(action.prop, ped)
        isProp = true
    end
    if action.propTwo and action.propTwo.model and not isPropTwo then
        propTwo_net = createAndAttachProp(action.propTwo, ped)
        isPropTwo = true
    end
end

local function cleanupAnimationAndProps(ped, action)
    -- clear animations
    if action and action.animation then
        if action.animation.task or (action.animation.animDict and action.animation.anim) then
            StopAnimTask(ped, action.animation.animDict, action.animation.anim, 1.0)
            ClearPedSecondaryTask(ped)
        else
            ClearPedTasks(ped)
        end
    end

    -- clear props
    if prop_net then
        if DoesEntityExist(NetToObj(prop_net)) then
            DetachEntity(NetToObj(prop_net), true, true)
            DeleteObject(NetToObj(prop_net))
        end
        prop_net = nil
    end
    if propTwo_net then
        if DoesEntityExist(NetToObj(propTwo_net)) then
            DetachEntity(NetToObj(propTwo_net), true, true)
            DeleteObject(NetToObj(propTwo_net))
        end
        propTwo_net = nil
    end

    isAnim = false
    isProp = false
    isPropTwo = false
end

local function disableControlsDuringAction(action)
    CreateThread(function()
        while isProgressActive do
            if action and action.controlDisables then
                for disableType, isEnabled in pairs(action.controlDisables) do
                    if isEnabled and controls[disableType] then
                        for _, control in ipairs(controls[disableType]) do
                            DisableControlAction(0, control, true)
                        end
                    end
                end
                if action.controlDisables.disableCombat then
                    DisablePlayerFiring(PlayerId(), true)
                end
            end
            Wait(0)
        end
    end)
end
local CancelProgressbar
-- Start progressbar
---@param data table {
---    label: string,
---    duration: number,
---    icon?: string,
---    canCancel?: boolean,
---    color?: string,
---    useWhileDead?: boolean,
---    controlDisables?: table,
---    animation?: table,
---    prop?: table,
---    propTwo?: table
---}
---@param onComplete? function Callback when completed
---@param onCancel? function Callback when cancelled
local function StartProgressbar(data, onComplete, onCancel)
    if isProgressActive then
        CancelProgressbar()
        Wait(100)
    end

    local ped = PlayerPedId()
    local isPlayerDead = IsEntityDead(ped)

    -- Verify if player can start action while dead
    if not data.useWhileDead and isPlayerDead then
        if onCancel then onCancel() end
        return
    end

    isProgressActive = true
    canCancel = data.canCancel or false
    wasCancelled = false
    currentAction = data

    -- start animation if provided
    if data.animation then
        startAnimation(ped, data)
        isAnim = true
    end

    -- start props
    if data.prop or data.propTwo then
        startProps(ped, data)
    end

    -- disable controls
    if data.controlDisables then
        disableControlsDuringAction(data)
    end

    -- Update state to indicate player is busy (used for inventory and other checks)
    LocalPlayer.state:set('inv_busy', true, true)

    NuiMessage('progressbar:start', {
        id = tostring(GetGameTimer()),
        label = data.label or 'Loading...',
        duration = data.duration or 5000,
        icon = data.icon,
        canCancel = data.canCancel or false,
        color = data.color
    })

    -- Main waiting thread
    CreateThread(function()
        local startTime = GetGameTimer()
        local duration = data.duration or 5000

        while isProgressActive do
            Wait(0)
            local elapsed = GetGameTimer() - startTime

            -- Verify if player died during the action
            if not data.useWhileDead and IsEntityDead(ped) then
                CancelProgressbar()
                if onCancel then onCancel() end
                wasCancelled = true
                break
            end

            -- Verify cancel key (only if canCancel is true)
            if data.canCancel then
                if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) or IsControlJustPressed(0, 167) then -- ESC or Backspace

                    CancelProgressbar()
                    if onCancel then onCancel() end
                    wasCancelled = true
                    break
                end
            end

            if elapsed >= duration then
                -- Completed
                isProgressActive = false
                if onComplete then
                    onComplete()
                end
                break
            end
        end

        -- clear animations and props
        cleanupAnimationAndProps(ped, data)
        LocalPlayer.state:set('inv_busy', false, true)
        currentAction = nil
    end)
end
CancelProgressbar = function()
    if isProgressActive then
        isProgressActive = false
        wasCancelled = true
        NuiMessage('progressbar:cancel', {})

        local ped = PlayerPedId()
        cleanupAnimationAndProps(ped, currentAction)
        LocalPlayer.state:set('inv_busy', false, true)
    end
end

-- Check if progressbar is active
local function IsProgressbarActive()
    return isProgressActive
end

-- NUI Callbacks
RegisterNUICallback('progressbar:complete', function(data, cb)
    isProgressActive = false
    cb('ok')
end)

RegisterNUICallback('progressbar:cancelled', function(data, cb)
    isProgressActive = false
    cb('ok')
end)

-- Exports for other resources
exports('Progress', StartProgressbar)
exports('ProgressWithStartEvent', StartProgressbar)
exports('isDoingSomething', IsProgressbarActive)
exports('CancelProgress', CancelProgressbar)

-- Legacy exports for compatibility with older scripts (these can be removed in the future)
exports('ProgressWithTickEvent', function(data, tick, finish)
    -- Note: The tick callback is not implemented in this version, but you can trigger it from the main waiting thread if needed.
    StartProgressbar(data, finish)
end)

exports('ProgressWithStartAndTick', function(data, start, tick, finish)
    StartProgressbar(data, finish)
    if start then start() end
end)

exports('ToggleBusyness', function(bool)
    isProgressActive = bool
end)

if Config.Debug then
    local presetList = {
        { name = 'ammo',   label = 'Reloading...' },
        { name = 'health', label = 'Healing...' },
        { name = 'armor',  label = 'Equipping armor...' },
        { name = 'craft',  label = 'Crafting...' },
        { name = 'repair', label = 'Repairing...' },
        { name = 'hack',   label = 'Hacking...' },
        { name = 'lock',   label = 'Lockpicking...' },
        { name = 'eat',    label = 'Eating...' },
        { name = 'drink',  label = 'Drinking...' },
        { name = 'card',   label = 'Swiping card...' },
        { name = 'pill',   label = 'Taking pills...' },
    }

    -- /progressbar [preset number 1-9 or icon name] [duration]
    RegisterCommand('progressbar', function(_, args)
        local arg = args[1] or '1'
        local duration = tonumber(args[2]) or 5000
        local num = tonumber(arg)
        if num and presetList[num] then
            local p = presetList[num]
            StartProgressbar({
                label = p.label,
                duration = duration,
                icon = p.name,
                canCancel = true,
            }, function()
                Notify('Progressbar completed!', 'success')
            end, function()
                Notify('Progressbar cancelled!', 'error')
            end)
        else
            StartProgressbar({
                label = 'Test: ' .. arg,
                duration = duration,
                icon = arg,
                canCancel = true,
            }, function()
                Notify('Progressbar completed!', 'success')
            end, function()
                Notify('Progressbar cancelled!', 'error')
            end)
        end
    end, false)
end
