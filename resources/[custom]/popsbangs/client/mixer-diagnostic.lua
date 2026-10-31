
local activeProbes = {}
local isProbing = false
local resourceStopped = false

local scenesToTest = {
    "oxlyn_probe_global",
    "oxlyn_probe_native_group",
    "oxlyn_probe_custom_group",
    (type(Config) == "table" and Config.Valve and Config.Valve.engine and Config.Valve.engine.scene) or "oxlyn_exhaust_valves"
}

function RunMixerProbe()
    if isProbing or resourceStopped then
        return
    end

    isProbing = true
    print(string.format("[oxlyn-popsbangs][mixer-probe] player=%s loading=%s", tostring(NetworkIsPlayerActive(PlayerId())), tostring(GetIsLoadingScreenActive())))

    for _, sceneName in ipairs(scenesToTest) do
        if resourceStopped then
            break
        end

        local wasActive = IsAudioSceneActive(sceneName)
        local startResult = wasActive
        if not wasActive then
            startResult = StartAudioScene(sceneName)
        end

        activeProbes[sceneName] = not wasActive
        Wait(100)

        local isActiveNow = IsAudioSceneActive(sceneName)
        print(string.format("[oxlyn-popsbangs][mixer-probe] %s before=%s start=%s type=%s active=%s", sceneName, tostring(wasActive), tostring(startResult), type(startResult), tostring(isActiveNow)))

        if not wasActive then
            StopAudioScene(sceneName)
        end
        activeProbes[sceneName] = nil
    end

    isProbing = false
end

CreateThread(function()
    while not resourceStopped do
        if NetworkIsPlayerActive(PlayerId()) and not GetIsLoadingScreenActive() then
            break
        end
        Wait(250)
    end

    Wait(7000)

    if not resourceStopped then
        RunMixerProbe()
    end
end)

RegisterCommand("oxp_mixer_probe", function()
    CreateThread(RunMixerProbe)
end, false)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    resourceStopped = true

    for sceneName in pairs(activeProbes) do
        StopAudioScene(sceneName)
    end
end)
--fivevault-FAOnfLTopc0 : https://discord.gg/fivevault
--fivevaults50Ont7Top-! : https://discord.gg/fivevault
--fivevault_dmOnAtTop84 : https://discord.gg/fivevault
--fivevault-lqOnjpTopoy : https://discord.gg/fivevault
--fivevault-I9OnX0Topjq : https://discord.gg/fivevault
