-- oxlyn-truckjob NPC / interaction client (decompiled output, cleaned: names restored, temp registers removed)
-- Spawns the job NPC near the player, handles the target/prompt interaction and the map blip.
-- Relies on globals defined elsewhere: Config, Truck, _U

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local npc = nil
local npcSpawned = false
local promptVisible = false
local iconVisible = false

local targetCfg = Config.Target or { system = "none" }
local targetSystem = targetCfg.system or "none" -- "native" | "ox_target" | "qb-target" | "none"

local HEAD_BONE = 31086 -- SKEL_Head

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local function projectToScreen(coords, dist)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return nil end

    local scale = 4.0 / math.max(1.0, dist)
    scale = math.max(0.35, math.min(1.05, scale))
    return x, y, scale
end

local function showIcon(x, y, scale)
    iconVisible = true
    SendNUIMessage({ action = "show3DIcon", x = x, y = y, scale = scale })
end

local function hideIcon()
    if not iconVisible then return end
    iconVisible = false
    SendNUIMessage({ action = "hide3DIcon" })
end

local function showPrompt()
    if promptVisible then return end
    promptVisible = true
    SendNUIMessage({
        action = "showInteractPrompt",
        label = _U("interact_label"),
        hint = _U("interact_hint"),
        key = targetCfg.keyLabel or "E",
    })
end

local function hidePrompt()
    if not promptVisible then return end
    promptVisible = false
    SendNUIMessage({ action = "hideInteractPrompt" })
end

local function openMenu()
    TriggerEvent("oxlyn-truckjob:client:openMenu")
end

---------------------------------------------------------------------
-- NPC spawn / despawn
---------------------------------------------------------------------
local function spawnNpc()
    local hash = GetHashKey(Config.NPC.model)
    RequestModel(hash)

    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        Wait(10)
        if deadline < GetGameTimer() then return end
    end

    local c = Config.NPC.coords
    npc = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)

    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetEntityInvincible(npc, true)
    SetPedFleeAttributes(npc, 0, false)
    SetPedDiesWhenInjured(npc, false)
    FreezeEntityPosition(npc, true)

    if Config.NPC.scenario then
        TaskStartScenarioInPlace(npc, Config.NPC.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(hash)
    npcSpawned = true

    local targetDistance = (targetCfg.interactDist or 2.0) + 0.4

    if targetSystem == "ox_target" then
        if GetResourceState("ox_target") == "started" then
            exports.ox_target:addLocalEntity(npc, {
                {
                    name = "oxlyn_truckjob_npc",
                    icon = "fa-solid fa-truck",
                    label = _U("interact_label"),
                    distance = targetDistance,
                    onSelect = openMenu,
                },
            })
        end
    elseif targetSystem == "qb-target" then
        if GetResourceState("qb-target") == "started" then
            exports["qb-target"]:AddTargetEntity(npc, {
                options = {
                    {
                        type = "client",
                        icon = "fa-solid fa-truck",
                        label = _U("interact_label"),
                        action = openMenu,
                    },
                },
                distance = targetDistance,
            })
        end
    end
end

local function despawnNpc()
    if npc and DoesEntityExist(npc) then
        if targetSystem == "ox_target" and GetResourceState("ox_target") == "started" then
            pcall(function()
                exports.ox_target:removeLocalEntity(npc)
            end)
        end
        DeleteEntity(npc)
    end

    npc = nil
    npcSpawned = false
end

---------------------------------------------------------------------
-- Map blip
---------------------------------------------------------------------
CreateThread(function()
    if not Config.NPC.blip then return end

    local c = Config.NPC.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipDisplay(blip, Config.Blip.display)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(_U("npc_blip"))
    EndTextCommandSetBlipName(blip)
end)

---------------------------------------------------------------------
-- Proximity loop: spawn NPC, draw icon, show prompt, handle key press
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1500

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local npcCoords = Config.NPC.coords
        local dist = #(pedCoords - vector3(npcCoords.x, npcCoords.y, npcCoords.z))

        if dist < 60.0 then
            sleep = 0

            if not npcSpawned then
                spawnNpc()
            end

            if targetSystem == "native" then
                -- Only show the interaction while not in the menu and not on a job
                if not Truck.menuOpen and not Truck.onDuty then
                    local renderDist = targetCfg.renderDist or 12.0
                    local interactDist = targetCfg.interactDist or 2.0
                    local iconHeight = targetCfg.iconHeight or 1.05 -- (unused in the original too)

                    if dist < renderDist then
                        -- Anchor the icon just above the NPC's head
                        local anchor
                        if npc and DoesEntityExist(npc) then
                            anchor = GetPedBoneCoords(npc, HEAD_BONE, 0.0, 0.0, 0.0)
                        end

                        if anchor and anchor.x ~= 0.0 then
                            anchor = vector3(anchor.x, anchor.y, anchor.z + 0.18)
                        else
                            anchor = vector3(npcCoords.x, npcCoords.y, npcCoords.z + 1.0)
                        end

                        local sx, sy, scale = projectToScreen(anchor, dist)
                        if sx then
                            showIcon(sx, sy, scale)
                        end
                    else
                        hideIcon()
                    end

                    if dist < interactDist then
                        showPrompt()
                        if IsControlJustReleased(0, targetCfg.key or 38) then
                            openMenu()
                        end
                    else
                        hidePrompt()
                    end
                end
            else
                -- ox_target / qb-target handle interaction themselves
                hideIcon()
                hidePrompt()
            end
        else
            if iconVisible then hideIcon() end
            if promptVisible then hidePrompt() end

            -- Despawn the NPC once the player is well away
            if npcSpawned and dist > 100.0 then
                despawnNpc()
            end
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:client:menuStateChanged", function(isOpen)
    if isOpen then
        hidePrompt()
        hideIcon()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    despawnNpc()
    hidePrompt()
    hideIcon()
end)