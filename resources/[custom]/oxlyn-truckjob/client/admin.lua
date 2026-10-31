---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Current position of the player (or their vehicle) with zone/street names.
local function getPlayerLocation()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local entity = (vehicle and vehicle ~= 0) and vehicle or ped

    local coords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)

    local zone = GetNameOfZone(coords.x, coords.y, coords.z) or ""
    local zoneLabel = (zone ~= "" and GetLabelText(zone)) or ""
    if zoneLabel == "NULL" or zoneLabel == "" then
        zoneLabel = zone
    end

    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z) or 0
    local street = (streetHash ~= 0 and GetStreetNameFromHashKey(streetHash)) or ""

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        zone = zoneLabel,
        street = street,
    }
end

-- Prints a line in the chat with the [truckroute] prefix.
local function chat(message)
    TriggerEvent("chat:addMessage", {
        color = { 244, 244, 245 },
        args = { "[truckroute]", message },
    })
end

local function showHelp()
    chat(_U("cmd_help_header"))
    chat("  /truckroute pickup                 - mark a pickup point")
    chat("  /truckroute delivery               - mark the destination (auto-saves)")
    chat("  /truckroute cancel                 - drop an in-progress capture")
    chat("  /truckroute list                   - list saved routes")
    chat("  /truckroute remove <id|index>      - delete a route")
    chat("  /truckroute level <id|index> <N>   - override min level")
    chat("  /truckroute price <id|index> <N>   - override payment")
    chat("  /truckroute difficulty <id|index> <easy|medium|hard>")
    chat("  /truckroute auto <id|index>        - revert to auto-balance")
    chat("  /truckroute bonus                  - start a manual bonus event")
    chat("  /truckroute edit <id|index> [model]   - place trailer visually")
    chat("  /truckroute settrailer <id> <model>   - set trailer model")
    chat("  /truckroute unlock <id|index>         - back to auto ground placement")
end

---------------------------------------------------------------------------
-- /truckroute command
---------------------------------------------------------------------------

local function handleCommand(_, args)
    local sub = ((args and args[1]) or ""):lower()

    if sub == "pickup" or sub == "delivery" then
        local location = getPlayerLocation()
        chat(("registering %s in %s..."):format(sub, location.zone ~= "" and location.zone or "coords"))
        TriggerServerEvent("oxlyn-truckjob:server:admin:capture", sub, location)

    elseif sub == "cancel" then
        TriggerServerEvent("oxlyn-truckjob:server:admin:cancel")

    elseif sub == "list" then
        TriggerServerEvent("oxlyn-truckjob:server:admin:list")

    elseif sub == "remove" then
        local id = args and args[2]
        if not id or id == "" then
            chat("Usage: /truckroute remove <id|index>")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:remove", id)

    elseif sub == "level" then
        local id = args and args[2]
        local level = tonumber(args and args[3])
        if not id or not level then
            chat("Usage: /truckroute level <id|index> <level>")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:setOverride", id, "level", level)

    elseif sub == "price" or sub == "pay" then
        local id = args and args[2]
        local amount = tonumber(args and args[3])
        if not id or not amount then
            chat("Usage: /truckroute price <id|index> <amount>")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:setOverride", id, "value", amount)

    elseif sub == "difficulty" then
        local id = args and args[2]
        local difficulty = ((args and args[3]) or ""):lower()
        if not id or (difficulty ~= "easy" and difficulty ~= "medium" and difficulty ~= "hard") then
            chat("Usage: /truckroute difficulty <id|index> <easy|medium|hard>")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:setOverride", id, "difficulty", difficulty)

    elseif sub == "auto" or sub == "reset" then
        local id = args and args[2]
        if not id or id == "" then
            chat("Usage: /truckroute auto <id|index>")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:clearOverride", id)

    elseif sub == "bonus" then
        TriggerServerEvent("oxlyn-truckjob:server:admin:bonus")

    elseif sub == "edit" or sub == "place" or sub == "trailer" then
        local id = args and args[2]
        local model = args and args[3]
        if not id or id == "" then
            chat("Usage: /truckroute edit <id|index> [trailer_model]")
            return
        end
        if Editor and Editor.IsActive() then
            chat("You are already editing a route. Press ENTER to save or BACKSPACE to cancel.")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:requestEdit", id, model)

    elseif sub == "settrailer" or sub == "model" then
        local id = args and args[2]
        local model = args and args[3]
        if not (id and model) or model == "" then
            chat("Usage: /truckroute settrailer <id|index> <model>")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:setTrailer", id, model)

    elseif sub == "unlock" or sub == "unfix" then
        local id = args and args[2]
        if not id or id == "" then
            chat("Usage: /truckroute unlock <id|index>")
            return
        end
        TriggerServerEvent("oxlyn-truckjob:server:admin:unlockPickup", id)

    else
        showHelp()
    end
end

RegisterCommand("truckroute", handleCommand, false)

TriggerEvent("chat:addSuggestion", "/truckroute", "Manage truck-job routes (admin)", {
    {
        name = "subcommand",
        help = "pickup | delivery | cancel | list | remove | level | price | difficulty | auto | bonus | edit | settrailer | unlock",
    },
    { name = "...", help = "extra arguments depending on the subcommand" },
})

---------------------------------------------------------------------------
-- Trailer position editor
---------------------------------------------------------------------------

Editor = Editor or { active = false }

-- Tuning
local MOVE_STEP = 0.04        -- metres per frame
local ROTATE_STEP = 0.7       -- degrees per frame
local COARSE_MULTIPLIER = 6   -- while holding SHIFT

-- Control IDs
local KEY_UP = 172
local KEY_DOWN = 173
local KEY_LEFT = 174
local KEY_RIGHT = 175
local KEY_W = 32
local KEY_S = 33
local KEY_SHIFT = 21
local KEY_Q = 44
local KEY_E = 38
local KEY_ENTER = 191
local KEY_BACKSPACE = 177
local KEY_PAGEUP = 10
local KEY_PAGEDOWN = 11
local KEY_G = 47
local KEY_R = 45
local KEY_V = 0

-- Controls blocked while the editor is open
local blockedControls = {
    KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_S, KEY_SHIFT, KEY_Q, KEY_E,
    KEY_ENTER, KEY_BACKSPACE, KEY_G, KEY_R,
    0, 22, 36, 34, 35, 24, 25, 263, 264, 140, 141, 142, 37,
}

-- Heights probed (above the trailer) when searching for the ground
local GROUND_PROBES = { 2.0, 8.0, 25.0, 80.0, 250.0 }

local groundCache = { key = nil, z = nil }
local nextCycleAt = 0

local function deleteEntitySafe(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        if DeleteVehicle then
            DeleteVehicle(entity)
        end
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
end

-- Puts the player on foot ~7m behind the position so the trailer is in view.
local function teleportPlayerNear(pos, heading)
    local ped = PlayerPedId()
    local rad = math.rad((heading or 0.0) - 180.0)
    local offsetX = math.sin(rad) * 7.0
    local offsetY = math.cos(rad) * 7.0

    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 16)

        local timeout = GetGameTimer() + 600
        while IsPedInAnyVehicle(ped, false) and timeout > GetGameTimer() do
            Wait(50)
        end
    end

    SetEntityCoords(ped, pos.x - offsetX, pos.y - offsetY, pos.z + 0.2, false, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
end

-- Fades out, runs `fn`, fades back in.
local function fadeTransition(fn)
    DoScreenFadeOut(400)

    local timeout = GetGameTimer() + 600
    while not IsScreenFadedOut() and timeout > GetGameTimer() do
        Wait(10)
    end

    fn()
    Wait(150)
    DoScreenFadeIn(500)
end

-- Finds the ground Z below/around (x, y, z), or nil.
local function findGroundZ(x, y, z)
    for _, offset in ipairs(GROUND_PROBES) do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, z + offset, false)
        if found and groundZ > -100.0 then
            return groundZ
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- HUD drawing
---------------------------------------------------------------------------

local function drawText(x, y, text, scale, r, g, b, a)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(scale or 0.34, scale or 0.34)
    SetTextColour(r or 255, g or 255, b or 255, a or 230)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Draws a rectangle from its top-left corner.
local function drawRect(x, y, width, height, r, g, b, a)
    DrawRect(x + width / 2.0, y + height / 2.0, width, height, r, g, b, a or 180)
end

-- Distance of the trailer's underside above the ground (nil if unknown),
-- plus the ground Z. Ground lookups are cached per 0.25m XY cell.
local function groundOffset()
    local state = Editor.state
    if not state then
        return nil
    end

    local key = ("%d,%d"):format(math.floor(state.pos.x * 4), math.floor(state.pos.y * 4))
    if groundCache.key ~= key then
        groundCache.z = findGroundZ(state.pos.x, state.pos.y, state.pos.z)
        groundCache.key = key
    end

    if not groundCache.z then
        return nil
    end

    if not (state.trailer and DoesEntityExist(state.trailer)) then
        return nil
    end

    local minDim = GetModelDimensions(GetEntityModel(state.trailer))
    local underside = state.pos.z - math.abs(minDim.z)
    return underside - groundCache.z, groundCache.z
end

local HELP_LINES = {
    { 0.635, "~b~UP / DOWN~s~     Move Z (up / down)" },
    { 0.660, "~b~LEFT / RIGHT~s~  Move X (sides)" },
    { 0.685, "~b~W / S~s~         Move Y (forward/back)" },
    { 0.710, "~b~Q / E~s~         Rotate heading" },
    { 0.735, "~b~SHIFT~s~ (hold)  Coarse step (x6)" },
    { 0.760, "~b~V~s~             Cycle trailer model" },
    { 0.785, "~b~G~s~             Snap to ground" },
    { 0.810, "~b~R~s~             Reset to initial" },
    { 0.840, "~g~ENTER~s~         Save & exit" },
    { 0.865, "~r~BACKSPACE~s~     Cancel" },
}

local function drawHud()
    local state = Editor.state
    if not state then
        return
    end

    -- Top banner
    drawRect(0.3, 0.015, 0.4, 0.075, 0, 0, 0, 170)
    drawText(0.4, 0.022, "~y~TRAILER POSITION EDITOR~s~", 0.42)
    drawText(0.32, 0.052, ("#%s  ~b~%s~s~  ~y~[%s]~s~"):format(
        tostring(state.index or "?"),
        tostring(state.label or state.id or "?"),
        tostring(state.trailerModel or "-")
    ), 0.34)

    -- Position panel
    drawRect(0.71, 0.015, 0.28, 0.075, 0, 0, 0, 170)
    drawText(0.715, 0.022, ("X ~b~%.3f~s~  Y ~b~%.3f~s~"):format(state.pos.x, state.pos.y), 0.34)

    local offset = groundOffset()
    local groundText
    if offset == nil then
        groundText = "~w~?~s~"
    elseif math.abs(offset) < 0.2 then
        groundText = ("~g~%.2fm~s~"):format(offset)
    elseif offset > 0 then
        groundText = ("~r~+%.2fm~s~"):format(offset)
    else
        groundText = ("~y~%.2fm~s~"):format(offset)
    end

    drawText(0.715, 0.052, ("Z ~b~%.3f~s~  H ~b~%.1f~s~  ground %s"):format(
        state.pos.z, state.pos.heading, groundText
    ), 0.34)

    -- Controls help
    drawRect(0.015, 0.595, 0.3, 0.375, 0, 0, 0, 170)
    drawText(0.025, 0.6, "~y~Trailer editor controls~s~", 0.4)
    for _, line in ipairs(HELP_LINES) do
        drawText(0.025, line[1], line[2], 0.32)
    end

    drawText(0.025, 0.905, ("Step: %s"):format(state.coarse and "~r~COARSE (x6)~s~" or "~g~FINE~s~"), 0.32)
    drawText(0.025, 0.935, state.locked and "~g~Saved data locked~s~" or "~y~Auto-ground (locks on save)~s~", 0.32)
end

-- Marker on the ground under the trailer.
local function drawGroundMarker()
    local state = Editor.state
    if not state then
        return
    end

    local _, groundZ = groundOffset()
    if not groundZ then
        return
    end

    DrawMarker(
        25,
        state.pos.x, state.pos.y, groundZ + 0.02,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        3.5, 3.5, 0.1,
        80, 220, 255, 130,
        false, false, 2, false, nil, nil, false
    )
end

---------------------------------------------------------------------------
-- Editor actions
---------------------------------------------------------------------------

local function disableControls()
    for _, control in ipairs(blockedControls) do
        DisableControlAction(0, control, true)
    end
end

-- Drops the trailer onto the ground at its current XY.
local function snapToGround()
    local state = Editor.state
    if not (state and state.trailer and DoesEntityExist(state.trailer)) then
        return
    end

    local model = GetEntityModel(state.trailer)
    local groundZ = findGroundZ(state.pos.x, state.pos.y, state.pos.z)

    if not groundZ then
        Notify.Send(nil, "No ground found at this XY — moved trailer manually.", "warning", 4000)
        return
    end

    local minDim = GetModelDimensions(model)
    state.pos.z = groundZ + math.abs(minDim.z) + 0.05

    SetEntityCoordsNoOffset(state.trailer, state.pos.x, state.pos.y, state.pos.z, true, true, true)
end

-- Restores the trailer to where it was when editing started.
local function resetToInitial()
    local state = Editor.state
    if not (state and state.initialPos and state.trailer and DoesEntityExist(state.trailer)) then
        return
    end

    state.pos.x = state.initialPos.x
    state.pos.y = state.initialPos.y
    state.pos.z = state.initialPos.z
    state.pos.heading = state.initialPos.heading

    SetEntityCoordsNoOffset(state.trailer, state.pos.x, state.pos.y, state.pos.z, true, true, true)
    SetEntityHeading(state.trailer, state.pos.heading)
end

-- Swaps the editor trailer for the next (direction = 1) or previous (-1) model.
local function cycleTrailerModel(direction)
    local trailers = Config.Trailers or { "trailers" }
    if #trailers == 0 then
        return
    end

    local state = Editor.state

    local index = 1
    for i, model in ipairs(trailers) do
        if model == state.trailerModel then
            index = i
            break
        end
    end

    index = index + (direction or 1)
    if index < 1 then
        index = #trailers
    end
    if index > #trailers then
        index = 1
    end

    local newModel = trailers[index]
    if newModel == state.trailerModel then
        return
    end

    local oldTrailer = state.trailer
    state.trailerModel = newModel
    state.trailer = nil

    local spawned = Truck.SpawnPickupTrailer({
        pickup = { x = state.pos.x, y = state.pos.y, z = state.pos.z },
        pickupHeading = state.pos.heading,
        trailer = newModel,
        pickupLocked = true,
    })

    if spawned and DoesEntityExist(spawned) then
        SetEntityCollision(spawned, true, true)
        FreezeEntityPosition(spawned, true)
        state.trailer = spawned
        deleteEntitySafe(oldTrailer)
    else
        state.trailer = oldTrailer
        Notify.Send(nil, "Failed to spawn trailer model: " .. newModel, "error", 4000)
    end
end

-- Ends the editor; saves the position to the server if `save` is true.
local function finishEditing(save)
    local state = Editor.state
    Editor.active = false
    Editor.state = nil

    if not state then
        return
    end

    deleteEntitySafe(state.trailer)

    if save then
        TriggerServerEvent("oxlyn-truckjob:server:admin:saveTrailerPos", state.id, {
            x = state.pos.x,
            y = state.pos.y,
            z = state.pos.z,
            heading = state.pos.heading % 360,
            trailer = state.trailerModel,
        })
    else
        chat("Edit canceled — no changes saved.")
    end
end

function Editor.IsActive()
    return Editor.active == true
end

-- Starts editing a route's pickup trailer.
function Editor.Begin(route)
    if Editor.active then
        return
    end

    if Truck.onDuty then
        Notify.Send(nil, _U("job_in_progress"), "warning")
        return
    end

    local pickup = route.pickup
    local heading = route.pickupHeading or 0.0
    local trailers = Config.Trailers or { "trailers" }
    local model = route.trailerOverride or route.trailer or trailers[1] or "trailers"

    fadeTransition(function()
        teleportPlayerNear(pickup, heading)
    end)

    local trailer = Truck.SpawnPickupTrailer({
        pickup = { x = pickup.x, y = pickup.y, z = pickup.z },
        pickupHeading = heading,
        trailer = model,
        pickupLocked = route.pickupLocked or false,
    })

    if not (trailer and DoesEntityExist(trailer)) then
        Notify.Send(nil, "Failed to spawn editor trailer.", "error", 5000)
        return
    end

    SetEntityCollision(trailer, true, true)
    FreezeEntityPosition(trailer, true)

    local x, y, z, h
    if route.pickupLocked then
        -- Saved position: use it exactly
        x, y, z, h = pickup.x, pickup.y, pickup.z, heading
        SetEntityCoordsNoOffset(trailer, x, y, z, true, true, true)
        SetEntityHeading(trailer, h)
    else
        -- Auto-grounded: use wherever the spawn put it
        local coords = GetEntityCoords(trailer)
        x, y, z, h = coords.x, coords.y, coords.z, GetEntityHeading(trailer)
    end

    Editor.active = true
    Editor.state = {
        id = route.id,
        index = route.index,
        label = route.label,
        trailer = trailer,
        trailerModel = model,
        pos = { x = x, y = y, z = z, heading = h },
        initialPos = { x = x, y = y, z = z, heading = h },
        locked = route.pickupLocked or false,
        coarse = false,
    }

    chat(("Editing trailer of #%s (%s) — ENTER to save, BACKSPACE to cancel."):format(
        tostring(route.index or "?"),
        tostring(route.label or route.id or "?")
    ))
end

RegisterNetEvent("oxlyn-truckjob:client:admin:beginEdit", function(route)
    if type(route) ~= "table" then
        return
    end
    Editor.Begin(route)
end)

---------------------------------------------------------------------------
-- Editor main loop
---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local state = Editor.state

        if Editor.active and state then
            disableControls()

            state.coarse = IsDisabledControlPressed(0, KEY_SHIFT)
            local multiplier = state.coarse and COARSE_MULTIPLIER or 1
            local moveStep = MOVE_STEP * multiplier
            local rotateStep = ROTATE_STEP * multiplier

            local dx, dy, dz, dHeading = 0.0, 0.0, 0.0, 0.0

            if IsDisabledControlPressed(0, KEY_UP) then dz = dz + moveStep end
            if IsDisabledControlPressed(0, KEY_DOWN) then dz = dz - moveStep end
            if IsDisabledControlPressed(0, KEY_LEFT) then dx = dx - moveStep end
            if IsDisabledControlPressed(0, KEY_RIGHT) then dx = dx + moveStep end
            if IsDisabledControlPressed(0, KEY_W) then dy = dy + moveStep end
            if IsDisabledControlPressed(0, KEY_S) then dy = dy - moveStep end
            if IsDisabledControlPressed(0, KEY_Q) then dHeading = dHeading - rotateStep end
            if IsDisabledControlPressed(0, KEY_E) then dHeading = dHeading + rotateStep end

            -- Translation
            if dx ~= 0.0 or dy ~= 0.0 or dz ~= 0.0 then
                state.pos.x = state.pos.x + dx
                state.pos.y = state.pos.y + dy
                state.pos.z = state.pos.z + dz

                if state.trailer and DoesEntityExist(state.trailer) then
                    SetEntityCoordsNoOffset(state.trailer, state.pos.x, state.pos.y, state.pos.z, true, true, true)
                end
            end

            -- Rotation
            if dHeading ~= 0.0 then
                state.pos.heading = (state.pos.heading + dHeading) % 360
                if state.pos.heading < 0 then
                    state.pos.heading = state.pos.heading + 360
                end

                if state.trailer and DoesEntityExist(state.trailer) then
                    SetEntityHeading(state.trailer, state.pos.heading)
                end
            end

            -- Cycle trailer model (V / PageUp = next, PageDown = previous), debounced
            local now = GetGameTimer()
            if now >= nextCycleAt then
                if IsDisabledControlJustReleased(0, KEY_V) or IsDisabledControlJustReleased(0, KEY_PAGEUP) then
                    cycleTrailerModel(1)
                    nextCycleAt = now + 250
                elseif IsDisabledControlJustReleased(0, KEY_PAGEDOWN) then
                    cycleTrailerModel(-1)
                    nextCycleAt = now + 250
                end
            end

            if IsDisabledControlJustReleased(0, KEY_G) then
                snapToGround()
            elseif IsDisabledControlJustReleased(0, KEY_R) then
                resetToInitial()
            end

            if IsDisabledControlJustReleased(0, KEY_ENTER) then
                finishEditing(true)
            elseif IsDisabledControlJustReleased(0, KEY_BACKSPACE) then
                finishEditing(false)
            end

            -- Moving in XY invalidates the cached ground height
            if dx ~= 0.0 or dy ~= 0.0 then
                groundCache.key = nil
            end

            drawHud()
            drawGroundMarker()
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- Clean up the editor trailer if the resource stops mid-edit
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if Editor.state and Editor.state.trailer then
        deleteEntitySafe(Editor.state.trailer)
    end
end)