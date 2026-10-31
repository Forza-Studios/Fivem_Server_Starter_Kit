
PopsFlames = PopsFlames or {}

local activeFlames = {}
local particlePool = {}
local flameCounter = 0
local activeParticleCount = 0
local trackedEntities = {}
local outletCache = {}
local lastWeatherUpdate = 0
local exhaustBoneList = {}
local ptfxAssetList = {}
local flameContexts = {}
local ambientWeather = { at = -100000, rain = 0.0, light = 1.0 }
local nextProbeTime = 0
local maxOutlets = 6
local flameLayers = {}
local flameColors = {}
local ParticleConfig = {}

function IsFiniteNumber(val)
    return type(val) == "number" and val == val
end

function ClampNumber(val, minVal, maxVal, defaultVal)
    if not IsFiniteNumber(val) then
        return defaultVal or minVal
    end
    return math.max(minVal, math.min(maxVal, val))
end

flameStyles = {
    dart = {
        weight = 3.0, maxEnergy = 0.72, size = 0.9,
        layers = { { "core", 1.0, true } },
        when = { upshift = 2.0, limiter = 2.0, chain = 1.5, standing = 0.4, cold = 0.6, hot = 0.6 }
    },
    plume = {
        weight = 4.0, big = 2.0, size = 1.0,
        layers = { { "core", 0.85, true }, { "plume", 1.0 } },
        when = { fast = 0.5, cold = 0.6, hot = 0.5, standing = 0.8, damaged = 0.5, antilag = 0.6, launch = 0.4 }
    },
    ember = {
        weight = 1.5, maxEnergy = 0.62, size = 0.85, colour = { 1.0, 0.3, 0.08 },
        layers = { { "plume", 1.0 } },
        when = { cold = 4.5, hot = 0.2, damaged = 3.0, chain = 1.4 }
    },
    tongue = {
        weight = 2.5, big = 1.5, minEnergy = 0.35, size = 1.1, colour = { 1.0, 0.58, 0.16 }, jet = 1.5,
        layers = { { "plume", 0.9 } },
        when = { fast = 2.4, overrun = 1.2, standing = 0.3, cold = 0.7 }
    },
    blue = {
        weight = 1.5, big = 1.0, minEnergy = 0.35, size = 1.0, colour = { 0.4, 0.62, 1.0 }, jet = 1.15,
        layers = { { "core", 0.9, true } },
        when = { hot = 4.0, cold = 0.1, antilag = 2.0, fast = 1.3 }
    },
    afterburn = {
        weight = 1.2, big = 3.0, minEnergy = 0.55, size = 1.0, colour = { 1.0, 0.88, 0.6 },
        layers = { { "core", 0.9, true }, { "afterburner", 0.22 } },
        when = { fast = 1.8, hot = 1.8, cold = 0.2, standing = 0.5 }
    },
    fireball = {
        weight = 1.5, big = 4.0, minEnergy = 0.6, size = 1.0, colour = { 1.0, 0.42, 0.12 },
        layers = { { "plume", 1.75 }, { "small", 1.4 }, { "core", 1.0, true } },
        when = { standing = 3.5, launch = 3.0, downshift = 1.3, fast = 0.4 }
    },
    rocket = {
        weight = 1.0, big = 3.0, heavy = true, size = 1.0, colour = { 1.0, 0.95, 0.85 }, jet = 1.3,
        layers = { { "core", 1.0, true }, { "rocket", 0.3 } },
        when = { fast = 2.0, hot = 1.5, cold = 0.2, standing = 0.4 }
    },
    violet = {
        weight = 1.0, big = 14.0, heavy = true, minEnergy = 1.0, size = 1.15, colour = { 0.7, 0.28, 1.0 }, jet = 1.8,
        layers = { { "core", 1.3, true }, { "small", 1.2 }, { "plume", 1.2 } },
        when = { hot = 1.8, cold = 0.35, launch = 1.5 }
    },
    inferno = {
        weight = 1.5, big = 4.0, heavy = true, minEnergy = 0.7, size = 1.0, colour = { 1.0, 0.45, 0.12 },
        layers = { { "sanctus", 0.9 }, { "core", 0.9, true } },
        when = { standing = 2.5, launch = 3.0, hot = 1.3, fast = 0.6 }
    },
    thruster = {
        weight = 1.2, big = 2.5, minEnergy = 0.5, size = 1.0, colour = { 0.85, 0.9, 1.0 },
        layers = { { "thruster", 0.35 }, { "core", 0.8, true } },
        when = { antilag = 2.0, fast = 1.6, hot = 2.2, cold = 0.1 }
    },
    pyro = {
        weight = 0.8, big = 2.0, minEnergy = 0.7, size = 1.0, colour = { 1.0, 0.7, 0.35 },
        layers = { { "pyro", 0.22 }, { "core", 0.9, true } },
        when = { fast = 1.6, hot = 1.3, cold = 0.3, standing = 0.5 }
    },
    vigilante = {
        weight = 0.8, big = 2.0, heavy = true, size = 1.0,
        layers = { { "vigilante", 0.3 }, { "plume", 1.1 } },
        when = { fast = 1.6, hot = 1.3, cold = 0.3, standing = 0.5 }
    },
    whitehot = {
        weight = 1.0, big = 2.5, minEnergy = 0.55, size = 1.05, colour = { 0.92, 0.95, 1.0 }, jet = 1.2,
        layers = { { "core", 1.15, true } },
        when = { hot = 4.0, cold = 0.05, limiter = 1.5 }
    },
    green = {
        weight = 0.5, big = 1.0, minEnergy = 0.8, size = 1.0, colour = { 0.4, 1.0, 0.35 }, jet = 1.2,
        layers = { { "core", 1.0, true }, { "plume", 0.8 } },
        when = { hot = 1.5, cold = 0.2 }
    },
    twin = {
        weight = 1.5, big = 1.5, minEnergy = 0.35, size = 0.95, twin = 60,
        layers = { { "core", 0.9, true }, { "plume", 0.9 } },
        when = { downshift = 2.2, chain = 1.3 }
    },
    sparkler = {
        weight = 1.0, minEnergy = 0.4, maxEnergy = 1.0, size = 0.9,
        layers = { { "core", 0.9, true } },
        extras = { "sparks", "wire" },
        when = { downshift = 1.8, chain = 1.5, damaged = 2.0 }
    },
    sooty = {
        weight = 0.8, big = 0.5, size = 0.95, colour = { 1.0, 0.36, 0.1 },
        layers = { { "plume", 1.0 }, { "core", 0.7, true } },
        extras = { "smoke" },
        when = { cold = 5.0, hot = 0.2, damaged = 7.0, standing = 1.4 }
    },
    flicker = {
        weight = 1.2, minEnergy = 0.25, maxEnergy = 0.95, size = 0.75, twin = 26, repeats = 2,
        layers = { { "core", 1.0, true } },
        when = { limiter = 3.0, chain = 2.2, upshift = 1.2, antilag = 1.4, standing = 0.5 }
    },
    lance = {
        weight = 1.2, big = 1.5, minEnergy = 0.35, size = 1.0, colour = { 1.0, 0.86, 0.55 }, jet = 2.1,
        layers = { { "core", 0.6, true } },
        when = { fast = 4.0, hot = 1.3, standing = 0.1 }
    },
    bloom = {
        weight = 1.0, big = 1.5, minEnergy = 0.3, size = 1.0,
        layers = { { "small", 1.6 }, { "plume", 1.3 } },
        when = { standing = 5.0, launch = 2.0, fast = 0.2, downshift = 1.2 }
    }
}

styleDefinitions = {
    "dart", "plume", "ember", "tongue", "blue", "afterburn",
    "fireball", "rocket", "violet", "inferno", "thruster", "pyro",
    "vigilante", "whitehot", "green", "twin", "sparkler", "sooty",
    "flicker", "lance", "bloom"
}

function ResolveFlameStyle(styleName, defaultStyle)
    local override = (ParticleConfig and ParticleConfig.styles and ParticleConfig.styles[styleName])
    if override == false then
        return nil
    end
    if type(override) ~= "table" then
        return defaultStyle
    end
    if override.enabled == false then
        return nil
    end
    local merged = {}
    for k, v in pairs(defaultStyle) do
        merged[k] = v
    end
    for k, v in pairs(override) do
        merged[k] = v
    end
    return merged
end

styleProps = ResolveFlameStyle
styleEntry = styleDefinitions

function StopParticle(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2
  flameActive_2 = particlePool
  flameActive_2 = flameActive_2[vehicle]
  if not flameActive_2 then
    return
  end
  if pulses then
    boneIndex_2 = StopParticleFxLooped
    currentSpeed_2 = flameActive_2.handle
    targetScale_2 = false
    boneIndex_2(currentSpeed_2, targetScale_2)
  else
    boneIndex_2 = SetParticleFxLoopedAlpha
    currentSpeed_2 = flameActive_2.handle
    targetScale_2 = 0.0
    boneIndex_2(currentSpeed_2, targetScale_2)
    boneIndex_2 = StopParticleFxLooped
    currentSpeed_2 = flameActive_2.handle
    targetScale_2 = false
    boneIndex_2(currentSpeed_2, targetScale_2)
    boneIndex_2 = RemoveParticleFx
    currentSpeed_2 = flameActive_2.handle
    targetScale_2 = false
    boneIndex_2(currentSpeed_2, targetScale_2)
  end
  boneIndex_2 = particlePool
  currentSpeed_2 = nil
  targetScale_2 = flameCounter
  targetScale_2 = targetScale_2 - 1
  flameCounter = targetScale_2
  boneIndex_2[vehicle] = currentSpeed_2
end
subProps = StopParticle
function CancelFlames(vehicle)
  local currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2
  currentCoords_2 = pairs
  flameActive_2 = particlePool
  currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2 = currentCoords_2(flameActive_2)
  for targetScale_2, durationMs_2 in currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2 do
    ptfxAsset_2 = durationMs_2.netId
    if ptfxAsset_2 == vehicle then
      ptfxAsset_2 = StopParticle
      ptfxName_2 = targetScale_2
      energyVal_2 = false
      ptfxAsset_2(ptfxName_2, energyVal_2)
    end
  end
  currentCoords_2 = exhaustBoneList
  currentCoords_2 = #currentCoords_2
  flameActive_2 = 1
  boneIndex_2 = -1
  for currentSpeed_2 = currentCoords_2, flameActive_2, boneIndex_2 do
    targetScale_2 = exhaustBoneList
    targetScale_2 = targetScale_2[currentSpeed_2]
    targetScale_2 = targetScale_2.netId
    if targetScale_2 == vehicle then
      targetScale_2 = table
      targetScale_2 = targetScale_2.remove
      durationMs_2 = exhaustBoneList
      ptfxAsset_2 = currentSpeed_2
      targetScale_2(durationMs_2, ptfxAsset_2)
    end
  end
  currentCoords_2 = ptfxAssetList
  currentCoords_2 = #currentCoords_2
  flameActive_2 = 1
  boneIndex_2 = -1
  for currentSpeed_2 = currentCoords_2, flameActive_2, boneIndex_2 do
    targetScale_2 = ptfxAssetList
    targetScale_2 = targetScale_2[currentSpeed_2]
    targetScale_2 = targetScale_2.netId
    if targetScale_2 == vehicle then
      targetScale_2 = table
      targetScale_2 = targetScale_2.remove
      durationMs_2 = ptfxAssetList
      ptfxAsset_2 = currentSpeed_2
      targetScale_2(durationMs_2, ptfxAsset_2)
    end
  end
  currentCoords_2 = pairs
  flameActive_2 = flameContexts
  currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2 = currentCoords_2(flameActive_2)
  for targetScale_2, durationMs_2 in currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2 do
    ptfxAsset_2 = durationMs_2.netId
    if ptfxAsset_2 == vehicle then
      ptfxAsset_2 = flameContexts
      ptfxAsset_2[targetScale_2] = nil
    end
  end
end
PopsFlames.Cancel = CancelFlames
function CancelBurstFlames(vehicle)
  local currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2
  currentCoords_2 = type
  flameActive_2 = vehicle
  currentCoords_2 = currentCoords_2(flameActive_2)
  if "string" ~= currentCoords_2 then
    return
  end
  currentCoords_2 = pairs
  flameActive_2 = particlePool
  currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2 = currentCoords_2(flameActive_2)
  for targetScale_2, durationMs_2 in currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2 do
    ptfxAsset_2 = durationMs_2.burstId
    if ptfxAsset_2 == vehicle then
      ptfxAsset_2 = StopParticle
      ptfxName_2 = targetScale_2
      energyVal_2 = true
      ptfxAsset_2(ptfxName_2, energyVal_2)
    end
  end
  currentCoords_2 = exhaustBoneList
  currentCoords_2 = #currentCoords_2
  flameActive_2 = 1
  boneIndex_2 = -1
  for currentSpeed_2 = currentCoords_2, flameActive_2, boneIndex_2 do
    targetScale_2 = exhaustBoneList
    targetScale_2 = targetScale_2[currentSpeed_2]
    targetScale_2 = targetScale_2.burstId
    if targetScale_2 == vehicle then
      targetScale_2 = table
      targetScale_2 = targetScale_2.remove
      durationMs_2 = exhaustBoneList
      ptfxAsset_2 = currentSpeed_2
      targetScale_2(durationMs_2, ptfxAsset_2)
    end
  end
end
PopsFlames.CancelBurst = CancelBurstFlames
function ClearAllFlames()
  local entityHandle_2, currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2
  entityHandle_2 = lastWeatherUpdate
  entityHandle_2 = entityHandle_2 + 1
  lastWeatherUpdate = entityHandle_2
  entityHandle_2 = pairs
  currentCoords_2 = particlePool
  entityHandle_2, currentCoords_2, flameActive_2, boneIndex_2 = entityHandle_2(currentCoords_2)
  for currentSpeed_2 in entityHandle_2, currentCoords_2, flameActive_2, boneIndex_2 do
    targetScale_2 = StopParticle
    durationMs_2 = currentSpeed_2
    ptfxAsset_2 = false
    targetScale_2(durationMs_2, ptfxAsset_2)
  end
  entityHandle_2 = {}
  currentCoords_2 = 0
  flameActive_2 = {}
  boneIndex_2 = {}
  currentSpeed_2 = {}
  targetScale_2 = {}
  flameContexts = targetScale_2
  ptfxAssetList = currentSpeed_2
  exhaustBoneList = boneIndex_2
  trackedEntities = flameActive_2
  flameCounter = currentCoords_2
  particlePool = entityHandle_2
  entityHandle_2 = pairs
  currentCoords_2 = outletCache
  entityHandle_2, currentCoords_2, flameActive_2, boneIndex_2 = entityHandle_2(currentCoords_2)
  for currentSpeed_2 in entityHandle_2, currentCoords_2, flameActive_2, boneIndex_2 do
    targetScale_2 = RemoveNamedPtfxAsset
    durationMs_2 = currentSpeed_2
    targetScale_2(durationMs_2)
  end
  entityHandle_2 = {}
  outletCache = entityHandle_2
end
PopsFlames.Clear = ClearAllFlames
function RequestPtfxAsset(vehicle)
  local currentCoords_2, flameActive_2, boneIndex_2
  currentCoords_2 = type
  flameActive_2 = vehicle
  currentCoords_2 = currentCoords_2(flameActive_2)
  if "string" == currentCoords_2 then
    currentCoords_2 = outletCache
    currentCoords_2 = currentCoords_2[vehicle]
    if not currentCoords_2 then
      goto lbl_11
    end
  end
  do return end
  ::lbl_11::
  currentCoords_2 = outletCache
  currentCoords_2[vehicle] = true
  currentCoords_2 = lastWeatherUpdate
  flameActive_2 = RequestNamedPtfxAsset
  boneIndex_2 = vehicle
  flameActive_2(boneIndex_2)
  flameActive_2 = CreateThread
  function boneIndex_2()
    local entityHandle_3, currentCoords_3, flameActive_3, boneIndex_3, currentSpeed_3
    entityHandle_3 = GetGameTimer
    entityHandle_3 = entityHandle_3()
    entityHandle_3 = entityHandle_3 + 8000
    while true do
      currentCoords_3 = currentCoords_2
      flameActive_3 = lastWeatherUpdate
      if currentCoords_3 ~= flameActive_3 then
        break
      end
      currentCoords_3 = HasNamedPtfxAssetLoaded
      flameActive_3 = vehicle
      currentCoords_3 = currentCoords_3(flameActive_3)
      if currentCoords_3 then
        break
      end
      currentCoords_3 = GetGameTimer
      currentCoords_3 = currentCoords_3()
      if not (entityHandle_3 > currentCoords_3) then
        break
      end
      currentCoords_3 = Wait
      flameActive_3 = 25
      currentCoords_3(flameActive_3)
    end
    currentCoords_3 = currentCoords_2
    flameActive_3 = lastWeatherUpdate
    if currentCoords_3 ~= flameActive_3 then
      return
    end
    flameActive_3 = vehicle
    currentCoords_3 = trackedEntities
    boneIndex_3 = HasNamedPtfxAssetLoaded
    currentSpeed_3 = vehicle
    boneIndex_3 = boneIndex_3(currentSpeed_3)
    currentCoords_3[flameActive_3] = boneIndex_3
    flameActive_3 = vehicle
    currentCoords_3 = trackedEntities
    currentCoords_3 = currentCoords_3[flameActive_3]
    if not currentCoords_3 then
      currentCoords_3 = print
      flameActive_3 = "[oxlyn-popsbangs] Could not load particles: "
      boneIndex_3 = vehicle
      currentSpeed_3 = ". Using the available native effects as fallback."
      flameActive_3 = flameActive_3 .. boneIndex_3 .. currentSpeed_3
      currentCoords_3(flameActive_3)
    end
  end
  flameActive_2(boneIndex_2)
end
function InitFlames(vehicle)
  local currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2
  currentCoords_2 = PopsFlames
  currentCoords_2 = currentCoords_2.Clear
  currentCoords_2()
  currentCoords_2 = {}
  styleDefinitions = currentCoords_2
  if not vehicle then
    currentCoords_2 = {}
    vehicle = currentCoords_2
  end
  currentCoords_2 = vehicle.Particle
  if not currentCoords_2 then
    currentCoords_2 = {}
  end
  flameActive_2 = vehicle.Levels
  if not flameActive_2 then
    flameActive_2 = {}
  end
  activeFlames = flameActive_2
  ParticleConfig = currentCoords_2
  currentCoords_2 = ClampNumber
  flameActive_2 = vehicle.MaxExhausts
  boneIndex_2 = 1
  currentSpeed_2 = 16
  targetScale_2 = 6
  currentCoords_2 = currentCoords_2(flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2)
  maxOutlets = currentCoords_2
  currentCoords_2 = ParticleConfig.asset
  if not currentCoords_2 then
    currentCoords_2 = "core"
  end
  flameActive_2 = {}
  boneIndex_2 = {}
  boneIndex_2.asset = currentCoords_2
  currentSpeed_2 = ParticleConfig.name
  if not currentSpeed_2 then
    currentSpeed_2 = "veh_backfire"
  end
  boneIndex_2.name = currentSpeed_2
  flameActive_2.plume = boneIndex_2
  boneIndex_2 = {}
  boneIndex_2.asset = currentCoords_2
  currentSpeed_2 = ParticleConfig.narrowName
  if not currentSpeed_2 then
    currentSpeed_2 = "veh_backfire_narrow"
  end
  boneIndex_2.name = currentSpeed_2
  flameActive_2.core = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "small"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "veh_sm_car_small_backfire"
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.small = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "afterburner"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "veh_exhaust_afterburner"
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.afterburner = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "rocket"
  targetScale_2 = {}
  targetScale_2.asset = "veh_impexp_rocket"
  targetScale_2.name = "veh_rocket_boost"
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.rocket = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "sanctus"
  targetScale_2 = {}
  targetScale_2.asset = "veh_sanctus"
  targetScale_2.name = "veh_sanctus_backfire"
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.sanctus = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "thruster"
  targetScale_2 = {}
  targetScale_2.asset = "veh_thruster"
  targetScale_2.name = "veh_xm_thruster_afterburner"
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.thruster = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "pyro"
  targetScale_2 = {}
  targetScale_2.asset = "veh_sm_pyro"
  targetScale_2.name = "veh_exhaust_afterburner_pyro"
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.pyro = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "vigilante"
  targetScale_2 = {}
  targetScale_2.asset = "veh_sm_vig"
  targetScale_2.name = "veh_rocket_boost_vig"
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.vigilante = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "jet"
  targetScale_2 = {}
  targetScale_2.asset = "veh_xs_vehicle_mods"
  targetScale_2.name = "veh_nitrous"
  targetScale_2.scale = 0.55
  targetScale_2.minEnergy = 0.5
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.jet = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "sparks"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "veh_train_sparks"
  targetScale_2.scale = 0.45
  targetScale_2.durationMs = 130
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.sparks = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "wire"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "ent_brk_sparking_wires"
  targetScale_2.scale = 0.35
  targetScale_2.durationMs = 160
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.wire = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "smoke"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "veh_exhaust_misfire"
  targetScale_2.scale = 0.9
  targetScale_2.durationMs = 320
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.smoke = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "embers"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "ent_ray_heli_aprtmnt_embers"
  targetScale_2.scale = 0.3
  targetScale_2.durationMs = 550
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.embers = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "haze"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "ent_amb_foundry_heat_haze"
  targetScale_2.scale = 0.25
  targetScale_2.durationMs = 900
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.haze = boneIndex_2
  boneIndex_2 = styleProps
  currentSpeed_2 = "steam"
  targetScale_2 = {}
  targetScale_2.asset = "core"
  targetScale_2.name = "ent_sht_steam"
  targetScale_2.scale = 0.3
  targetScale_2.durationMs = 450
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2)
  flameActive_2.steam = boneIndex_2
  flameLayers = flameActive_2
  flameActive_2 = pairs
  boneIndex_2 = flameLayers
  flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2 = flameActive_2(boneIndex_2)
  for durationMs_2, ptfxAsset_2 in flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2 do
    RequestPtfxAsset(ptfxAsset_2.asset)
  end
  flameActive_2 = Config
  flameActive_2 = flameActive_2.ColouredFlames
  if not flameActive_2 then
    flameActive_2 = {}
  end
  flameActive_2 = flameActive_2.enabled
  if false ~= flameActive_2 then
    flameActive_2 = pairs
    boneIndex_2 = PopsNativeFlameAssets
    if not boneIndex_2 then
      boneIndex_2 = {}
    end
    flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2 = flameActive_2(boneIndex_2)
    for durationMs_2, ptfxAsset_2 in flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2 do
      ptfxName_2 = pairs
      energyVal_2 = flameLayers
      ptfxName_2, energyVal_2, outletList_2, pulseItem_2 = ptfxName_2(energyVal_2)
      for tempVal_2, clampedScale_2 in ptfxName_2, energyVal_2, outletList_2, pulseItem_2 do
        boneCoords_2 = clampedScale_2.asset
        boneCoords_2 = ptfxAsset_2[boneCoords_2]
        if boneCoords_2 then
          boneCoords_2 = clampedScale_2.asset
          boneCoords_2 = ptfxAsset_2[boneCoords_2]
          calcOffset_2 = clampedScale_2.name
          boneCoords_2 = boneCoords_2[calcOffset_2]
        end
        if boneCoords_2 then
          RequestPtfxAsset(boneCoords_2.asset)
        end
      end
    end
  end
  flameActive_2 = {}
  flameColors = flameActive_2
  flameActive_2 = type
  boneIndex_2 = ParticleConfig.styles
  flameActive_2 = flameActive_2(boneIndex_2)
  if "table" == flameActive_2 then
    flameActive_2 = ParticleConfig.styles
    if flameActive_2 then
      goto lbl_245
    end
  end
  flameActive_2 = {}
  ::lbl_245::
  boneIndex_2 = ipairs
  currentSpeed_2 = styleEntry
  boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2 = boneIndex_2(currentSpeed_2)
  for ptfxAsset_2, ptfxName_2 in boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2 do
    energyVal_2 = flameActive_2[ptfxName_2]
    if false ~= energyVal_2 then
      outletList_2 = {}
      outletList_2.name = ptfxName_2
      pulseItem_2 = pairs
      tempVal_2 = flameStyles
      tempVal_2 = tempVal_2[ptfxName_2]
      pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2 = pulseItem_2(tempVal_2)
      for calcOffset_2, checkResult_2 in pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2 do
        outletList_2[calcOffset_2] = checkResult_2
      end
      pulseItem_2 = type
      tempVal_2 = energyVal_2
      pulseItem_2 = pulseItem_2(tempVal_2)
      if "table" == pulseItem_2 then
        pulseItem_2 = pairs
        tempVal_2 = energyVal_2
        pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2 = pulseItem_2(tempVal_2)
        for calcOffset_2, checkResult_2 in pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2 do
          if "when" == calcOffset_2 then
            iterKey_2 = type
            iterValue_2 = checkResult_2
            iterKey_2 = iterKey_2(iterValue_2)
            if "table" == iterKey_2 then
              iterKey_2 = type
              iterValue_2 = outletList_2.when
              iterKey_2 = iterKey_2(iterValue_2)
              if "table" == iterKey_2 then
                iterKey_2 = {}
                iterValue_2 = pairs
                soundRadius_2 = outletList_2.when
                iterValue_2, soundRadius_2, burstKey_2, ambientLight_2 = iterValue_2(soundRadius_2)
                for rainLevel_2, colorR_2 in iterValue_2, soundRadius_2, burstKey_2, ambientLight_2 do
                  iterKey_2[rainLevel_2] = colorR_2
                end
                iterValue_2 = pairs
                soundRadius_2 = checkResult_2
                iterValue_2, soundRadius_2, burstKey_2, ambientLight_2 = iterValue_2(soundRadius_2)
                for rainLevel_2, colorR_2 in iterValue_2, soundRadius_2, burstKey_2, ambientLight_2 do
                  iterKey_2[rainLevel_2] = colorR_2
                end
                outletList_2.when = iterKey_2
            end
          end
          else
            outletList_2[calcOffset_2] = checkResult_2
          end
        end
      end
      pulseItem_2 = ClampNumber
      tempVal_2 = outletList_2.weight
      clampedScale_2 = 0
      boneCoords_2 = 100
      calcOffset_2 = 0
      pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2)
      if not (pulseItem_2 > 0) then
        pulseItem_2 = ClampNumber
        tempVal_2 = outletList_2.big
        clampedScale_2 = 0
        boneCoords_2 = 100
        calcOffset_2 = 0
        pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2)
        if not (pulseItem_2 > 0) then
          goto lbl_331
        end
      end
      pulseItem_2 = flameColors
      pulseItem_2 = #pulseItem_2
      tempVal_2 = pulseItem_2 + 1
      pulseItem_2 = flameColors
      pulseItem_2[tempVal_2] = outletList_2
    end
    ::lbl_331::
  end
end
PopsFlames.Init = InitFlames
function HasActiveFlames()
  local entityHandle_2, currentCoords_2
  entityHandle_2 = flameCounter
  entityHandle_2 = entityHandle_2 > 0
  return entityHandle_2
end
PopsFlames.HasActive = HasActiveFlames
function UpdateAmbientWeather(vehicle)
  local currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2
  currentCoords_2 = ambientWeather.at
  currentCoords_2 = vehicle - currentCoords_2
  flameActive_2 = 1000
  if currentCoords_2 < flameActive_2 then
    currentCoords_2 = ambientWeather
    return currentCoords_2
  end
  ambientWeather.at = vehicle
  currentCoords_2 = ParticleConfig.rain
  if false ~= currentCoords_2 then
    currentCoords_2 = ClampNumber
    flameActive_2 = GetRainLevel
    flameActive_2 = flameActive_2()
    boneIndex_2 = 0
    currentSpeed_2 = 1
    targetScale_2 = 0
    currentCoords_2 = currentCoords_2(flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2)
    if currentCoords_2 then
      goto lbl_23
    end
  end
  currentCoords_2 = 0
  ::lbl_23::
  ambientWeather.rain = currentCoords_2
  currentCoords_2 = GetClockHours
  currentCoords_2 = currentCoords_2()
  if currentCoords_2 >= 20 or currentCoords_2 < 6 then
    flameActive_2 = 1.0
    if flameActive_2 then
      goto lbl_39
    end
  end
  flameActive_2 = ClampNumber
  boneIndex_2 = ParticleConfig.dayLight
  currentSpeed_2 = 0.5
  targetScale_2 = 3.0
  durationMs_2 = 1.45
  flameActive_2 = flameActive_2(boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2)
  ::lbl_39::
  ambientWeather.light = flameActive_2
  flameActive_2 = ambientWeather
  return flameActive_2
end
function CalculateParticleEnvelope(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2
  flameActive_2 = math
  flameActive_2 = flameActive_2.max
  boneIndex_2 = 0
  currentSpeed_2 = vehicle.started
  currentSpeed_2 = pulses - currentSpeed_2
  flameActive_2 = flameActive_2(boneIndex_2, currentSpeed_2)
  boneIndex_2 = vehicle.duration
  if flameActive_2 >= boneIndex_2 then
    currentSpeed_2 = 0.0
    targetScale_2 = 0.0
    durationMs_2 = 0.0
    return currentSpeed_2, targetScale_2, durationMs_2
  end
  currentSpeed_2 = vehicle.attack
  targetScale_2 = vehicle.sustain
  targetScale_2 = boneIndex_2 * targetScale_2
  durationMs_2 = nil
  if flameActive_2 < currentSpeed_2 then
    ptfxAsset_2 = flameActive_2 / currentSpeed_2
    ptfxName_2 = 0.55 * ptfxAsset_2
    energyVal_2 = 2.0
    energyVal_2 = energyVal_2 - ptfxAsset_2
    ptfxName_2 = ptfxName_2 * energyVal_2
    durationMs_2 = 0.45 + ptfxName_2
  elseif flameActive_2 < targetScale_2 then
    ptfxAsset_2 = flameActive_2 - currentSpeed_2
    ptfxAsset_2 = 0.15 * ptfxAsset_2
    ptfxName_2 = math
    ptfxName_2 = ptfxName_2.max
    energyVal_2 = 1.0
    outletList_2 = targetScale_2 - currentSpeed_2
    ptfxName_2 = ptfxName_2(energyVal_2, outletList_2)
    ptfxAsset_2 = ptfxAsset_2 / ptfxName_2
    ptfxName_2 = 1.0
    durationMs_2 = ptfxName_2 - ptfxAsset_2
  else
    ptfxAsset_2 = boneIndex_2 - flameActive_2
    ptfxName_2 = math
    ptfxName_2 = ptfxName_2.max
    energyVal_2 = 1.0
    outletList_2 = boneIndex_2 - targetScale_2
    ptfxName_2 = ptfxName_2(energyVal_2, outletList_2)
    ptfxAsset_2 = ptfxAsset_2 / ptfxName_2
    ptfxAsset_2 = ptfxAsset_2 ^ 1.7
    durationMs_2 = 0.85 * ptfxAsset_2
  end
  ptfxAsset_2 = vehicle.phase
  ptfxName_2 = math
  ptfxName_2 = ptfxName_2.sin
  energyVal_2 = flameActive_2 * 0.131
  energyVal_2 = energyVal_2 + ptfxAsset_2
  ptfxName_2 = ptfxName_2(energyVal_2)
  ptfxName_2 = 0.06 * ptfxName_2
  ptfxName_2 = 0.92 + ptfxName_2
  energyVal_2 = math
  energyVal_2 = energyVal_2.sin
  outletList_2 = flameActive_2 * 0.277
  pulseItem_2 = ptfxAsset_2 * 1.61
  outletList_2 = outletList_2 + pulseItem_2
  energyVal_2 = energyVal_2(outletList_2)
  energyVal_2 = 0.04 * energyVal_2
  ptfxName_2 = ptfxName_2 + energyVal_2
  energyVal_2 = vehicle.peak
  outletList_2 = 0.65 * durationMs_2
  outletList_2 = 0.35 + outletList_2
  energyVal_2 = energyVal_2 * outletList_2
  energyVal_2 = energyVal_2 * ptfxName_2
  outletList_2 = energyVal_2
  pulseItem_2 = math
  pulseItem_2 = pulseItem_2.min
  tempVal_2 = 1.0
  clampedScale_2 = durationMs_2 ^ 0.6
  boneCoords_2 = vehicle.opacity
  clampedScale_2 = clampedScale_2 * boneCoords_2
  clampedScale_2 = clampedScale_2 * ptfxName_2
  pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2)
  tempVal_2 = durationMs_2
  return outletList_2, pulseItem_2, tempVal_2
end
function ValidateOutletOffset(vehicle)
  local currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2
  currentCoords_2 = type
  flameActive_2 = vehicle
  currentCoords_2 = currentCoords_2(flameActive_2)
  if "table" ~= currentCoords_2 then
    currentCoords_2 = nil
    return currentCoords_2
  end
  currentCoords_2 = vehicle.offset
  if not currentCoords_2 then
    currentCoords_2 = {}
  end
  flameActive_2 = type
  boneIndex_2 = currentCoords_2
  flameActive_2 = flameActive_2(boneIndex_2)
  if "table" ~= flameActive_2 then
    flameActive_2 = nil
    return flameActive_2
  end
  flameActive_2 = vehicle.bone
  if nil == flameActive_2 then
    flameActive_2 = IsFiniteNumber
    boneIndex_2 = currentCoords_2.x
    flameActive_2 = flameActive_2(boneIndex_2)
    if flameActive_2 then
      flameActive_2 = IsFiniteNumber
      boneIndex_2 = currentCoords_2.y
      flameActive_2 = flameActive_2(boneIndex_2)
      if flameActive_2 then
        flameActive_2 = IsFiniteNumber
        boneIndex_2 = currentCoords_2.z
        flameActive_2 = flameActive_2(boneIndex_2)
        if flameActive_2 then
          goto lbl_40
        end
      end
    end
    flameActive_2 = nil
    return flameActive_2
  end
  ::lbl_40::
  flameActive_2 = vehicle.bone
  if nil ~= flameActive_2 then
    flameActive_2 = IsFiniteNumber
    boneIndex_2 = vehicle.bone
    flameActive_2 = flameActive_2(boneIndex_2)
    if flameActive_2 then
      flameActive_2 = vehicle.bone
      if not (flameActive_2 < 0) then
        goto lbl_53
      end
    end
    flameActive_2 = nil
    return flameActive_2
  end
  ::lbl_53::
  flameActive_2 = type
  boneIndex_2 = vehicle.rotation
  flameActive_2 = flameActive_2(boneIndex_2)
  if "table" == flameActive_2 then
    flameActive_2 = vehicle.rotation
    if flameActive_2 then
      goto lbl_62
    end
  end
  flameActive_2 = currentCoords_2
  ::lbl_62::
  boneIndex_2 = {}
  currentSpeed_2 = vehicle.bone
  boneIndex_2.bone = currentSpeed_2
  currentSpeed_2 = ClampNumber
  targetScale_2 = currentCoords_2.x
  durationMs_2 = -30.0
  ptfxAsset_2 = 30.0
  ptfxName_2 = 0.0
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2)
  boneIndex_2.x = currentSpeed_2
  currentSpeed_2 = ClampNumber
  targetScale_2 = currentCoords_2.y
  durationMs_2 = -30.0
  ptfxAsset_2 = 30.0
  ptfxName_2 = 0.0
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2)
  boneIndex_2.y = currentSpeed_2
  currentSpeed_2 = ClampNumber
  targetScale_2 = currentCoords_2.z
  durationMs_2 = -30.0
  ptfxAsset_2 = 30.0
  ptfxName_2 = 0.0
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2)
  boneIndex_2.z = currentSpeed_2
  currentSpeed_2 = ClampNumber
  targetScale_2 = flameActive_2.rx
  durationMs_2 = -360.0
  ptfxAsset_2 = 360.0
  ptfxName_2 = 0.0
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2)
  boneIndex_2.rx = currentSpeed_2
  currentSpeed_2 = ClampNumber
  targetScale_2 = flameActive_2.ry
  durationMs_2 = -360.0
  ptfxAsset_2 = 360.0
  ptfxName_2 = 0.0
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2)
  boneIndex_2.ry = currentSpeed_2
  currentSpeed_2 = ClampNumber
  targetScale_2 = flameActive_2.rz
  durationMs_2 = -360.0
  ptfxAsset_2 = 360.0
  ptfxName_2 = 0.0
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2)
  targetScale_2 = vehicle.reversed
  if not targetScale_2 then
    targetScale_2 = currentCoords_2.reversed
    if not targetScale_2 then
      goto lbl_116
    end
  end
  targetScale_2 = 180.0
  ::lbl_116::
  if not targetScale_2 then
    targetScale_2 = 0.0
  end
  currentSpeed_2 = currentSpeed_2 + targetScale_2
  boneIndex_2.rz = currentSpeed_2
  currentSpeed_2 = ClampNumber
  targetScale_2 = vehicle.scale
  if not targetScale_2 then
    targetScale_2 = currentCoords_2.scale
  end
  durationMs_2 = 0.15
  ptfxAsset_2 = 2.0
  ptfxName_2 = 1.0
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2)
  boneIndex_2.scale = currentSpeed_2
  return boneIndex_2
end
function GetExhaustBones(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2
  flameActive_2 = pulses.bone
  if nil ~= flameActive_2 then
    flameActive_2 = GetWorldPositionOfEntityBone
    boneIndex_2 = vehicle
    currentSpeed_2 = pulses.bone
    return flameActive_2(boneIndex_2, currentSpeed_2)
  end
  flameActive_2 = GetOffsetFromEntityInWorldCoords
  boneIndex_2 = vehicle
  currentSpeed_2 = pulses.x
  targetScale_2 = pulses.y
  durationMs_2 = pulses.z
  return flameActive_2(boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2)
end
function GetBoneOffset(vehicle, pulses, situation, tune)
  local currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2
  if vehicle then
    targetScale_2 = vehicle.asset
    currentSpeed_2 = trackedEntities
    currentSpeed_2 = currentSpeed_2[targetScale_2]
    if currentSpeed_2 then
      goto lbl_10
    end
  end
  currentSpeed_2 = nil
  do return currentSpeed_2 end
  ::lbl_10::
  currentSpeed_2 = UseParticleFxAsset
  targetScale_2 = vehicle.asset
  currentSpeed_2(targetScale_2)
  currentSpeed_2 = nil
  targetScale_2 = situation.bone
  if nil ~= targetScale_2 then
    targetScale_2 = StartParticleFxLoopedOnEntityBone
    durationMs_2 = vehicle.name
    ptfxAsset_2 = pulses
    ptfxName_2 = situation.x
    energyVal_2 = situation.y
    outletList_2 = situation.z
    pulseItem_2 = situation.rx
    tempVal_2 = situation.ry
    clampedScale_2 = situation.rz
    boneCoords_2 = situation.bone
    calcOffset_2 = tune
    checkResult_2 = false
    iterKey_2 = false
    iterValue_2 = false
    targetScale_2 = targetScale_2(durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2)
    currentSpeed_2 = targetScale_2
  else
    targetScale_2 = StartParticleFxLoopedOnEntity
    durationMs_2 = vehicle.name
    ptfxAsset_2 = pulses
    ptfxName_2 = situation.x
    energyVal_2 = situation.y
    outletList_2 = situation.z
    pulseItem_2 = situation.rx
    tempVal_2 = situation.ry
    clampedScale_2 = situation.rz
    boneCoords_2 = tune
    calcOffset_2 = false
    checkResult_2 = false
    iterKey_2 = false
    targetScale_2 = targetScale_2(durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2)
    currentSpeed_2 = targetScale_2
  end
  if currentSpeed_2 and 0 ~= currentSpeed_2 then
    return currentSpeed_2
  end
  targetScale_2 = nil
  return targetScale_2
end
function SpawnFlameParticle(vehicle, pulses, situation, tune, flameScale, seed, outletIdx)
  local ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2
  ptfxAsset_2 = UseParticleFxAsset
  ptfxName_2 = vehicle.asset
  ptfxAsset_2(ptfxName_2)
  ptfxAsset_2 = SetParticleFxNonLoopedColour
  ptfxName_2 = flameScale
  energyVal_2 = seed
  outletList_2 = outletIdx
  ptfxAsset_2(ptfxName_2, energyVal_2, outletList_2)
  ptfxAsset_2 = SetParticleFxNonLoopedAlpha
  ptfxName_2 = 1.0
  ptfxAsset_2(ptfxName_2)
  ptfxAsset_2 = nil
  ptfxName_2 = nil
  energyVal_2 = situation.bone
  if nil ~= energyVal_2 then
    energyVal_2 = type
    outletList_2 = _ENV
    pulseItem_2 = "StartNetworkedParticleFxNonLoopedOnEntityBone"
    outletList_2 = outletList_2[pulseItem_2]
    energyVal_2 = energyVal_2(outletList_2)
    if "function" == energyVal_2 then
      energyVal_2 = _ENV
      outletList_2 = "StartNetworkedParticleFxNonLoopedOnEntityBone"
      energyVal_2 = energyVal_2[outletList_2]
      outletList_2 = vehicle.name
      pulseItem_2 = pulses
      tempVal_2 = situation.x
      clampedScale_2 = situation.y
      boneCoords_2 = situation.z
      calcOffset_2 = situation.rx
      checkResult_2 = situation.ry
      iterKey_2 = situation.rz
      iterValue_2 = situation.bone
      soundRadius_2 = tune
      burstKey_2 = false
      ambientLight_2 = false
      rainLevel_2 = false
      energyVal_2 = energyVal_2(outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2)
      ptfxName_2 = "no osso"
      ptfxAsset_2 = energyVal_2
  end
  else
    energyVal_2 = situation.x
    outletList_2 = situation.y
    pulseItem_2 = situation.z
    tempVal_2 = situation.bone
    if nil ~= tempVal_2 then
      tempVal_2 = GetWorldPositionOfEntityBone
      clampedScale_2 = pulses
      boneCoords_2 = situation.bone
      tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2)
      clampedScale_2 = GetOffsetFromEntityGivenWorldCoords
      boneCoords_2 = pulses
      calcOffset_2 = tempVal_2.x
      checkResult_2 = tempVal_2.y
      iterKey_2 = tempVal_2.z
      clampedScale_2 = clampedScale_2(boneCoords_2, calcOffset_2, checkResult_2, iterKey_2)
      boneCoords_2 = clampedScale_2.x
      calcOffset_2 = situation.x
      boneCoords_2 = boneCoords_2 + calcOffset_2
      calcOffset_2 = clampedScale_2.y
      checkResult_2 = situation.y
      calcOffset_2 = calcOffset_2 + checkResult_2
      checkResult_2 = clampedScale_2.z
      iterKey_2 = situation.z
      pulseItem_2 = checkResult_2 + iterKey_2
      outletList_2 = calcOffset_2
      energyVal_2 = boneCoords_2
    end
    tempVal_2 = StartParticleFxNonLoopedOnEntity
    clampedScale_2 = vehicle.name
    boneCoords_2 = pulses
    calcOffset_2 = energyVal_2
    checkResult_2 = outletList_2
    iterKey_2 = pulseItem_2
    iterValue_2 = situation.rx
    soundRadius_2 = situation.ry
    burstKey_2 = situation.rz
    ambientLight_2 = tune
    rainLevel_2 = false
    colorR_2 = false
    colorG_2 = false
    tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2)
    ptfxName_2 = "por offset"
    ptfxAsset_2 = tempVal_2
  end
  energyVal_2 = false ~= ptfxAsset_2
  outletList_2 = ptfxName_2
  return energyVal_2, outletList_2
end
function ProbeFlame(vehicle, pulses, situation, tune)
  local currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2
  targetScale_2 = (type(pulses) == 'table' and pulses[1]) or nil
  currentSpeed_2 = ValidateOutletOffset(targetScale_2)
  if currentSpeed_2 and 0 ~= vehicle then
    targetScale_2 = DoesEntityExist
    durationMs_2 = vehicle
    targetScale_2 = targetScale_2(durationMs_2)
    if targetScale_2 then
      goto lbl_24
    end
  end
  targetScale_2 = false
  durationMs_2 = "no exhaust point"
  do return targetScale_2, durationMs_2 end
  ::lbl_24::
  targetScale_2 = tune[1]
  durationMs_2 = tune[2]
  ptfxAsset_2 = tune[3]
  ptfxName_2 = {}
  energyVal_2 = flameLayers.core
  ptfxName_2.A = energyVal_2
  energyVal_2 = flameLayers.plume
  ptfxName_2.C = energyVal_2
  energyVal_2 = flameLayers.jet
  ptfxName_2.D = energyVal_2
  energyVal_2 = flameLayers.afterburner
  ptfxName_2.F = energyVal_2
  energyVal_2 = {}
  outletList_2 = flameLayers.plume
  energyVal_2.B = outletList_2
  outletList_2 = flameLayers.core
  energyVal_2.E = outletList_2
  outletList_2 = ptfxName_2[situation]
  if not outletList_2 then
    outletList_2 = energyVal_2[situation]
  end
  if not outletList_2 then
    pulseItem_2 = false
    tempVal_2 = "unknown variant"
    return pulseItem_2, tempVal_2
  end
  tempVal_2 = outletList_2.asset
  pulseItem_2 = trackedEntities
  pulseItem_2 = pulseItem_2[tempVal_2]
  if not pulseItem_2 then
    RequestPtfxAsset(outletList_2.asset)
    pulseItem_2 = false
    tempVal_2 = "asset "
    clampedScale_2 = tostring
    boneCoords_2 = outletList_2.asset
    clampedScale_2 = clampedScale_2(boneCoords_2)
    boneCoords_2 = " not loaded yet, try again"
    tempVal_2 = tempVal_2 .. clampedScale_2 .. boneCoords_2
    return pulseItem_2, tempVal_2
  end
  pulseItem_2 = ptfxName_2[situation]
  if pulseItem_2 then
    pulseItem_2 = GetBoneOffset
    tempVal_2 = outletList_2
    clampedScale_2 = vehicle
    boneCoords_2 = currentSpeed_2
    calcOffset_2 = 1.6
    pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2)
    if not pulseItem_2 then
      tempVal_2 = false
      clampedScale_2 = outletList_2.name
      boneCoords_2 = " did not start"
      clampedScale_2 = clampedScale_2 .. boneCoords_2
      return tempVal_2, clampedScale_2
    end
    tempVal_2 = SetParticleFxLoopedColour
    clampedScale_2 = pulseItem_2
    boneCoords_2 = targetScale_2
    calcOffset_2 = durationMs_2
    checkResult_2 = ptfxAsset_2
    iterKey_2 = false
    tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2)
    tempVal_2 = SetParticleFxLoopedAlpha
    clampedScale_2 = pulseItem_2
    boneCoords_2 = 1.0
    tempVal_2(clampedScale_2, boneCoords_2)
    tempVal_2 = SetTimeout
    clampedScale_2 = 450
    function boneCoords_2()
      local entityHandle_3, currentCoords_3, flameActive_3
      entityHandle_3 = StopParticleFxLooped
      currentCoords_3 = pulseItem_2
      flameActive_3 = false
      entityHandle_3(currentCoords_3, flameActive_3)
      entityHandle_3 = RemoveParticleFx
      currentCoords_3 = pulseItem_2
      flameActive_3 = false
      entityHandle_3(currentCoords_3, flameActive_3)
    end
    tempVal_2(clampedScale_2, boneCoords_2)
    tempVal_2 = true
    clampedScale_2 = outletList_2.name
    boneCoords_2 = " looped, cor depois de arrancar"
    clampedScale_2 = clampedScale_2 .. boneCoords_2
    return tempVal_2, clampedScale_2
  end
  pulseItem_2 = SpawnFlameParticle
  tempVal_2 = outletList_2
  clampedScale_2 = vehicle
  boneCoords_2 = currentSpeed_2
  calcOffset_2 = 1.6
  checkResult_2 = targetScale_2
  iterKey_2 = durationMs_2
  iterValue_2 = ptfxAsset_2
  pulseItem_2, tempVal_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2)
  clampedScale_2 = pulseItem_2
  boneCoords_2 = outletList_2.name
  calcOffset_2 = " non-looped, colour before start, "
  checkResult_2 = tempVal_2
  boneCoords_2 = boneCoords_2 .. calcOffset_2 .. checkResult_2
  return clampedScale_2, boneCoords_2
end
PopsFlames.Probe = ProbeFlame
local probeCandidates = {
  { 'A', 'core', 'exp_grd_flare', false },
  { 'B', 'core', 'proj_flare_fuse', true },
  { 'C', 'scr_rcbarry2', 'scr_clown_appears', false },
  { 'D', 'scr_rcbarry2', 'scr_exp_clown', false },
  { 'E', 'scr_rcbarry1', 'scr_alien_teleport', false },
  { 'F', 'weap_xs_vehicle_weapons', 'muz_xs_turret_flamethrower_looping', true },
  { 'G', 'core', 'ent_sht_flame', true },
  { 'H', 'core', 'ent_amb_torch_fire', true },
  { 'I', 'core', 'veh_light_red_trail', true }
}

function GetProbeCandidates()
  return probeCandidates
end
PopsFlames.ProbeCandidates = GetProbeCandidates
function ProbeEffect(vehicle, pulses, situation, tune, flameScale, seed)
  local durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2
  ptfxAsset_2 = (type(pulses) == 'table' and pulses[1]) or nil
  durationMs_2 = ValidateOutletOffset(ptfxAsset_2)
  if durationMs_2 and 0 ~= vehicle then
    ptfxAsset_2 = DoesEntityExist
    ptfxName_2 = vehicle
    ptfxAsset_2 = ptfxAsset_2(ptfxName_2)
    if ptfxAsset_2 then
      goto lbl_24
    end
  end
  ptfxAsset_2 = false
  ptfxName_2 = "no exhaust point"
  do return ptfxAsset_2, ptfxName_2 end
  ::lbl_24::
  ptfxAsset_2 = RequestNamedPtfxAsset
  ptfxName_2 = situation
  ptfxAsset_2(ptfxName_2)
  ptfxAsset_2 = GetGameTimer
  ptfxAsset_2 = ptfxAsset_2()
  ptfxAsset_2 = ptfxAsset_2 + 3000
  while true do
    ptfxName_2 = HasNamedPtfxAssetLoaded
    energyVal_2 = situation
    ptfxName_2 = ptfxName_2(energyVal_2)
    if ptfxName_2 then
      break
    end
    ptfxName_2 = GetGameTimer
    ptfxName_2 = ptfxName_2()
    if not (ptfxAsset_2 > ptfxName_2) then
      break
    end
    ptfxName_2 = Wait
    energyVal_2 = 25
    ptfxName_2(energyVal_2)
  end
  ptfxName_2 = HasNamedPtfxAssetLoaded
  energyVal_2 = situation
  ptfxName_2 = ptfxName_2(energyVal_2)
  if not ptfxName_2 then
    ptfxName_2 = false
    energyVal_2 = "asset "
    outletList_2 = situation
    pulseItem_2 = " did not load"
    energyVal_2 = energyVal_2 .. outletList_2 .. pulseItem_2
    return ptfxName_2, energyVal_2
  end
  ptfxName_2 = trackedEntities
  ptfxName_2[situation] = true
  ptfxName_2 = seed[1]
  energyVal_2 = seed[2]
  outletList_2 = seed[3]
  pulseItem_2 = {}
  pulseItem_2.asset = situation
  pulseItem_2.name = tune
  if flameScale then
    tempVal_2 = UseParticleFxAsset
    clampedScale_2 = situation
    tempVal_2(clampedScale_2)
    tempVal_2 = SetParticleFxNonLoopedColour
    clampedScale_2 = ptfxName_2
    boneCoords_2 = energyVal_2
    calcOffset_2 = outletList_2
    tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2)
    tempVal_2 = GetBoneOffset
    clampedScale_2 = pulseItem_2
    boneCoords_2 = vehicle
    calcOffset_2 = durationMs_2
    checkResult_2 = 1.0
    tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2)
    if not tempVal_2 then
      clampedScale_2 = false
      boneCoords_2 = tune
      calcOffset_2 = " did not start"
      boneCoords_2 = boneCoords_2 .. calcOffset_2
      return clampedScale_2, boneCoords_2
    end
    clampedScale_2 = SetParticleFxLoopedColour
    boneCoords_2 = tempVal_2
    calcOffset_2 = ptfxName_2
    checkResult_2 = energyVal_2
    iterKey_2 = outletList_2
    iterValue_2 = false
    clampedScale_2(boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2)
    clampedScale_2 = SetParticleFxLoopedAlpha
    boneCoords_2 = tempVal_2
    calcOffset_2 = 1.0
    clampedScale_2(boneCoords_2, calcOffset_2)
    clampedScale_2 = SetTimeout
    boneCoords_2 = 700
    function calcOffset_2()
      local entityHandle_3, currentCoords_3, flameActive_3
      entityHandle_3 = StopParticleFxLooped
      currentCoords_3 = tempVal_2
      flameActive_3 = false
      entityHandle_3(currentCoords_3, flameActive_3)
      entityHandle_3 = RemoveParticleFx
      currentCoords_3 = tempVal_2
      flameActive_3 = false
      entityHandle_3(currentCoords_3, flameActive_3)
    end
    clampedScale_2(boneCoords_2, calcOffset_2)
    clampedScale_2 = true
    boneCoords_2 = situation
    calcOffset_2 = "/"
    checkResult_2 = tune
    iterKey_2 = " looped"
    boneCoords_2 = boneCoords_2 .. calcOffset_2 .. checkResult_2 .. iterKey_2
    return clampedScale_2, boneCoords_2
  end
  tempVal_2 = SpawnFlameParticle
  clampedScale_2 = pulseItem_2
  boneCoords_2 = vehicle
  calcOffset_2 = durationMs_2
  checkResult_2 = 1.0
  iterKey_2 = ptfxName_2
  iterValue_2 = energyVal_2
  soundRadius_2 = outletList_2
  tempVal_2, clampedScale_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2)
  boneCoords_2 = tempVal_2
  calcOffset_2 = situation
  checkResult_2 = "/"
  iterKey_2 = tune
  iterValue_2 = " non-looped, "
  soundRadius_2 = clampedScale_2
  calcOffset_2 = calcOffset_2 .. checkResult_2 .. iterKey_2 .. iterValue_2 .. soundRadius_2
  return boneCoords_2, calcOffset_2
end
PopsFlames.ProbeEffect = ProbeEffect
function ClampFiniteNumber(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2
  flameActive_2 = type
  boneIndex_2 = vehicle
  flameActive_2 = flameActive_2(boneIndex_2)
  if "number" == flameActive_2 and vehicle == vehicle then
    flameActive_2 = math
    flameActive_2 = flameActive_2.abs
    boneIndex_2 = vehicle
    flameActive_2 = flameActive_2(boneIndex_2)
    boneIndex_2 = 1.0E15
    if not (flameActive_2 > boneIndex_2) then
      goto lbl_16
    end
  end
  do return pulses end
  ::lbl_16::
  flameActive_2 = math
  flameActive_2 = flameActive_2.floor
  boneIndex_2 = math
  boneIndex_2 = boneIndex_2.abs
  currentSpeed_2 = vehicle
  boneIndex_2, currentSpeed_2 = boneIndex_2(currentSpeed_2)
  flameActive_2 = flameActive_2(boneIndex_2, currentSpeed_2)
  flameActive_2 = flameActive_2 % 2147483647
  flameActive_2 = flameActive_2 + 0.0
  return flameActive_2
end
function PseudoRandomFloat(vehicle, pulses)
  local flameActive_2 = ClampFiniteNumber(vehicle, 1)
  flameActive_2 = (flameActive_2 + (pulses or 0)) % 2147483646 + 1.0
  local boneIndex_2 = (flameActive_2 * 48271) % 2147483647
  local rem = boneIndex_2 % 46337
  local currentSpeed_2 = (boneIndex_2 + (rem * rem)) % 2147483647
  return math.floor((currentSpeed_2 * 69621) % 2147483647)
end
function FindVehicleOutlets(vehicle, pulses, situation, tune, flameScale)
  local targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2
  targetScale_2 = math
  targetScale_2 = targetScale_2.floor
  durationMs_2 = ClampNumber
  ptfxAsset_2 = situation
  ptfxName_2 = 1
  energyVal_2 = 16
  outletList_2 = 1
  durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  targetScale_2 = targetScale_2(durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2)
  situation = targetScale_2
  targetScale_2 = math
  targetScale_2 = targetScale_2.floor
  durationMs_2 = ClampNumber
  ptfxAsset_2 = pulses
  ptfxName_2 = 0
  energyVal_2 = 1000000
  outletList_2 = 1
  durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  targetScale_2 = targetScale_2(durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2)
  pulses = targetScale_2
  targetScale_2 = {}
  if 1 == situation then
    durationMs_2 = {}
    ptfxAsset_2 = 1
    durationMs_2[1] = ptfxAsset_2
    return durationMs_2
  end
  if not tune then
    durationMs_2 = ParticleConfig.alternate
    if false ~= durationMs_2 then
      goto lbl_42
    end
  end
  durationMs_2 = 1
  ptfxAsset_2 = situation
  ptfxName_2 = 1
  for energyVal_2 = durationMs_2, ptfxAsset_2, ptfxName_2 do
    targetScale_2[energyVal_2] = energyVal_2
  end
  do return targetScale_2 end
  ::lbl_42::
  durationMs_2 = PseudoRandomFloat(vehicle, 1)
  vehicle = durationMs_2
  durationMs_2 = PseudoRandomFloat(vehicle, 977)
  durationMs_2 = durationMs_2 % 100
  ptfxAsset_2 = PseudoRandomFloat(vehicle, 31)
  ptfxAsset_2 = ptfxAsset_2 % 2
  if flameScale then
    ptfxName_2 = PseudoRandomFloat(vehicle, pulses * 7919)
    ptfxName_2 = ptfxName_2 % 100
    if ptfxName_2 < 30 then
      ptfxName_2 = 0
      if ptfxName_2 then
        goto lbl_74
        durationMs_2 = ptfxName_2 or durationMs_2
      end
    end
    durationMs_2 = 50
  end
  ::lbl_74::
  if durationMs_2 < 30 then
    ptfxName_2 = 1
    energyVal_2 = situation
    outletList_2 = 1
    for pulseItem_2 = ptfxName_2, energyVal_2, outletList_2 do
      targetScale_2[pulseItem_2] = pulseItem_2
    end
    return targetScale_2
  elseif durationMs_2 < 70 then
    ptfxName_2 = pulses + ptfxAsset_2
    ptfxAsset_2 = ptfxName_2 % 2
  elseif durationMs_2 < 88 then
    ptfxName_2 = {}
    energyVal_2 = PseudoRandomFloat(vehicle, pulses * 7919)
    energyVal_2 = (energyVal_2 % situation) + 1
    ptfxName_2[1] = energyVal_2
    return ptfxName_2
  end
  ptfxName_2 = 1
  energyVal_2 = situation
  outletList_2 = 1
  for pulseItem_2 = ptfxName_2, energyVal_2, outletList_2 do
    tempVal_2 = pulseItem_2 % 2
    if tempVal_2 == ptfxAsset_2 then
      tempVal_2 = #targetScale_2
      tempVal_2 = tempVal_2 + 1
      targetScale_2[tempVal_2] = pulseItem_2
    end
  end
  ptfxName_2 = #targetScale_2
  if 0 == ptfxName_2 then
    targetScale_2[1] = 1
  end
  return targetScale_2
end
PopsFlames.Outlets = FindVehicleOutlets
function CalculateExhaustColor(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2
  if pulses then
    flameActive_2 = 0.82
    if vehicle > flameActive_2 then
      flameActive_2 = vehicle - 0.82
      flameActive_2 = flameActive_2 / 0.18
      boneIndex_2 = 0.3 * flameActive_2
      currentSpeed_2 = 1.0
      boneIndex_2 = currentSpeed_2 - boneIndex_2
      currentSpeed_2 = 0.06 * flameActive_2
      targetScale_2 = 0.92
      currentSpeed_2 = targetScale_2 - currentSpeed_2
      targetScale_2 = 0.2 * flameActive_2
      targetScale_2 = 0.8 + targetScale_2
      return boneIndex_2, currentSpeed_2, targetScale_2
    end
    flameActive_2 = 1.0
    boneIndex_2 = vehicle * 0.14
    boneIndex_2 = 0.8 + boneIndex_2
    currentSpeed_2 = vehicle * 0.34
    currentSpeed_2 = 0.52 + currentSpeed_2
    return flameActive_2, boneIndex_2, currentSpeed_2
  end
  flameActive_2 = 1.0
  boneIndex_2 = vehicle * 0.3
  boneIndex_2 = 0.46 + boneIndex_2
  currentSpeed_2 = vehicle * 0.24
  currentSpeed_2 = 0.14 + currentSpeed_2
  return flameActive_2, boneIndex_2, currentSpeed_2
end
local defaultPurpleColor = { 0.7, 0.28, 1.0 }
function CalculateFlamePosition(vehicle, pulses, situation, tune, flameScale, seed)
  local durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2
  durationMs_2 = nil
  ptfxAsset_2 = nil
  ptfxName_2 = nil
  energyVal_2 = vehicle or energyVal_2
  if vehicle then
    energyVal_2 = vehicle.colour
  end
  outletList_2 = type
  pulseItem_2 = seed
  outletList_2 = outletList_2(pulseItem_2)
  if "table" == outletList_2 then
    outletList_2 = ClampNumber
    pulseItem_2 = seed[1]
    tempVal_2 = 0
    clampedScale_2 = 1
    boneCoords_2 = 1
    outletList_2 = outletList_2(pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2)
    pulseItem_2 = ClampNumber
    tempVal_2 = seed[2]
    clampedScale_2 = 0
    boneCoords_2 = 1
    calcOffset_2 = 0.6
    pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2)
    tempVal_2 = ClampNumber
    clampedScale_2 = seed[3]
    boneCoords_2 = 0
    calcOffset_2 = 1
    checkResult_2 = 0.2
    tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2)
    ptfxName_2 = tempVal_2
    ptfxAsset_2 = pulseItem_2
    durationMs_2 = outletList_2
    if situation then
      outletList_2 = 1
      outletList_2 = outletList_2 - durationMs_2
      outletList_2 = outletList_2 * 0.4
      outletList_2 = durationMs_2 + outletList_2
      pulseItem_2 = 1
      pulseItem_2 = pulseItem_2 - ptfxAsset_2
      pulseItem_2 = pulseItem_2 * 0.4
      pulseItem_2 = ptfxAsset_2 + pulseItem_2
      tempVal_2 = 1
      tempVal_2 = tempVal_2 - ptfxName_2
      tempVal_2 = tempVal_2 * 0.4
      ptfxName_2 = ptfxName_2 + tempVal_2
      ptfxAsset_2 = pulseItem_2
      durationMs_2 = outletList_2
    end
    outletList_2 = durationMs_2
    pulseItem_2 = ClampNumber
    tempVal_2 = ptfxAsset_2 * tune
    clampedScale_2 = 0
    boneCoords_2 = 1
    calcOffset_2 = ptfxAsset_2
    pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2)
    tempVal_2 = ClampNumber
    clampedScale_2 = 2
    clampedScale_2 = clampedScale_2 - tune
    clampedScale_2 = ptfxName_2 * clampedScale_2
    boneCoords_2 = 0
    calcOffset_2 = 1
    checkResult_2 = ptfxName_2
    tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2)
    return outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2
  end
  outletList_2 = type
  pulseItem_2 = energyVal_2
  outletList_2 = outletList_2(pulseItem_2)
  if "table" ~= outletList_2 then
    outletList_2, pulseItem_2, tempVal_2 = CalculateExhaustColor(pulses, situation)
    ptfxName_2 = tempVal_2
    ptfxAsset_2 = pulseItem_2
    durationMs_2 = outletList_2
  else
    outletList_2 = ClampNumber
    pulseItem_2 = energyVal_2[1]
    tempVal_2 = 0
    clampedScale_2 = 1
    boneCoords_2 = 1
    outletList_2 = outletList_2(pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2)
    pulseItem_2 = ClampNumber
    tempVal_2 = energyVal_2[2]
    clampedScale_2 = 0
    boneCoords_2 = 1
    calcOffset_2 = 0.6
    pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2)
    tempVal_2 = ClampNumber
    clampedScale_2 = energyVal_2[3]
    boneCoords_2 = 0
    calcOffset_2 = 1
    checkResult_2 = 0.2
    tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2)
    ptfxName_2 = tempVal_2
    ptfxAsset_2 = pulseItem_2
    durationMs_2 = outletList_2
    if situation then
      outletList_2 = 1
      outletList_2 = outletList_2 - durationMs_2
      outletList_2 = outletList_2 * 0.55
      outletList_2 = durationMs_2 + outletList_2
      pulseItem_2 = 1
      pulseItem_2 = pulseItem_2 - ptfxAsset_2
      pulseItem_2 = pulseItem_2 * 0.55
      pulseItem_2 = ptfxAsset_2 + pulseItem_2
      tempVal_2 = 1
      tempVal_2 = tempVal_2 - ptfxName_2
      tempVal_2 = tempVal_2 * 0.55
      ptfxName_2 = ptfxName_2 + tempVal_2
      ptfxAsset_2 = pulseItem_2
      durationMs_2 = outletList_2
    end
  end
  outletList_2 = ParticleConfig.purple
  if false ~= outletList_2 and situation then
    outletList_2 = ClampNumber
    pulseItem_2 = flameScale - 1.15
    pulseItem_2 = pulseItem_2 / 0.3
    tempVal_2 = 0
    clampedScale_2 = 0.75
    boneCoords_2 = 0
    outletList_2 = outletList_2(pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2)
    if outletList_2 then
      goto lbl_151
    end
  end
  outletList_2 = 0
  ::lbl_151::
  if outletList_2 > 0 then
    pulseItem_2 = defaultPurpleColor[1]
    pulseItem_2 = pulseItem_2 - durationMs_2
    pulseItem_2 = pulseItem_2 * outletList_2
    pulseItem_2 = durationMs_2 + pulseItem_2
    tempVal_2 = defaultPurpleColor[2]
    tempVal_2 = tempVal_2 - ptfxAsset_2
    tempVal_2 = tempVal_2 * outletList_2
    tempVal_2 = ptfxAsset_2 + tempVal_2
    clampedScale_2 = defaultPurpleColor[3]
    clampedScale_2 = clampedScale_2 - ptfxName_2
    clampedScale_2 = clampedScale_2 * outletList_2
    ptfxName_2 = ptfxName_2 + clampedScale_2
    ptfxAsset_2 = tempVal_2
    durationMs_2 = pulseItem_2
  end
  pulseItem_2 = durationMs_2
  tempVal_2 = ClampNumber
  clampedScale_2 = ptfxAsset_2 * tune
  boneCoords_2 = 0
  calcOffset_2 = 1
  checkResult_2 = ptfxAsset_2
  tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2)
  clampedScale_2 = ClampNumber
  boneCoords_2 = 2
  boneCoords_2 = boneCoords_2 - tune
  boneCoords_2 = ptfxName_2 * boneCoords_2
  calcOffset_2 = 0
  checkResult_2 = 1
  iterKey_2 = ptfxName_2
  clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2 = clampedScale_2(boneCoords_2, calcOffset_2, checkResult_2, iterKey_2)
  return pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2
end
function ResolveFlameContext(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2
  flameActive_2 = type
  boneIndex_2 = pulses
  flameActive_2 = flameActive_2(boneIndex_2)
  flameActive_2 = pulses or flameActive_2
  if "table" ~= flameActive_2 or not pulses then
    flameActive_2 = {}
  end
  boneIndex_2 = ClampNumber
  currentSpeed_2 = flameActive_2.speed
  targetScale_2 = 0
  durationMs_2 = 160
  ptfxAsset_2 = 10
  boneIndex_2 = boneIndex_2(currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2)
  currentSpeed_2 = ClampNumber
  targetScale_2 = flameActive_2.soak
  durationMs_2 = 0
  ptfxAsset_2 = 1
  ptfxName_2 = ClampNumber
  energyVal_2 = flameActive_2.temperature
  outletList_2 = 0
  pulseItem_2 = 1
  tempVal_2 = 0.5
  ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2 = ptfxName_2(energyVal_2, outletList_2, pulseItem_2, tempVal_2)
  currentSpeed_2 = currentSpeed_2(targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2)
  targetScale_2 = {}
  durationMs_2 = ClampNumber
  ptfxAsset_2 = 0.3
  ptfxAsset_2 = ptfxAsset_2 - currentSpeed_2
  ptfxAsset_2 = ptfxAsset_2 / 0.3
  ptfxName_2 = 0
  energyVal_2 = 1
  outletList_2 = 0
  durationMs_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  targetScale_2.cold = durationMs_2
  durationMs_2 = ClampNumber
  ptfxAsset_2 = currentSpeed_2 - 0.55
  ptfxAsset_2 = ptfxAsset_2 / 0.45
  ptfxName_2 = 0
  energyVal_2 = 1
  outletList_2 = 0
  durationMs_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  targetScale_2.hot = durationMs_2
  durationMs_2 = ClampNumber
  ptfxAsset_2 = boneIndex_2 - 15
  ptfxAsset_2 = ptfxAsset_2 / 25
  ptfxName_2 = 0
  energyVal_2 = 1
  outletList_2 = 0
  durationMs_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  targetScale_2.fast = durationMs_2
  durationMs_2 = 2.5
  if boneIndex_2 < durationMs_2 then
    durationMs_2 = 1
    if durationMs_2 then
      goto lbl_67
    end
  end
  durationMs_2 = 0
  ::lbl_67::
  targetScale_2.standing = durationMs_2
  durationMs_2 = ClampNumber
  ptfxAsset_2 = ClampNumber
  ptfxName_2 = flameActive_2.health
  energyVal_2 = 0
  outletList_2 = 1
  pulseItem_2 = 1
  ptfxAsset_2 = ptfxAsset_2(ptfxName_2, energyVal_2, outletList_2, pulseItem_2)
  ptfxName_2 = 0.55
  ptfxAsset_2 = ptfxName_2 - ptfxAsset_2
  ptfxAsset_2 = ptfxAsset_2 / 0.35
  ptfxName_2 = 0
  energyVal_2 = 1
  outletList_2 = 0
  durationMs_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  targetScale_2.damaged = durationMs_2
  durationMs_2 = ClampNumber
  ptfxAsset_2 = flameActive_2.chain
  ptfxName_2 = 0
  energyVal_2 = 8
  outletList_2 = 0
  durationMs_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  if durationMs_2 > 0 then
    durationMs_2 = 1
    if durationMs_2 then
      goto lbl_97
    end
  end
  durationMs_2 = 0
  ::lbl_97::
  targetScale_2.chain = durationMs_2
  targetScale_2.soak = currentSpeed_2
  targetScale_2.speed = boneIndex_2
  durationMs_2 = type
  ptfxAsset_2 = vehicle
  durationMs_2 = durationMs_2(ptfxAsset_2)
  if "string" == durationMs_2 then
    targetScale_2[vehicle] = 1
  end
  return targetScale_2
end
PopsFlames.Context = ResolveFlameContext
function EvaluateStyleWeight(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2
  flameActive_2 = vehicle.when
  boneIndex_2 = type
  currentSpeed_2 = flameActive_2
  boneIndex_2 = boneIndex_2(currentSpeed_2)
  if "table" == boneIndex_2 then
    boneIndex_2 = type
    currentSpeed_2 = pulses
    boneIndex_2 = boneIndex_2(currentSpeed_2)
    if "table" == boneIndex_2 then
      boneIndex_2 = ParticleConfig.situational
      if false ~= boneIndex_2 then
        goto lbl_17
      end
    end
  end
  boneIndex_2 = 1.0
  do return boneIndex_2 end
  ::lbl_17::
  boneIndex_2 = 1.0
  currentSpeed_2 = ipairs
  targetScale_2 = {}
  durationMs_2 = "upshift"
  ptfxAsset_2 = "downshift"
  ptfxName_2 = "overrun"
  energyVal_2 = "limiter"
  outletList_2 = "antilag"
  pulseItem_2 = "launch"
  tempVal_2 = "chain"
  clampedScale_2 = "standing"
  boneCoords_2 = "fast"
  calcOffset_2 = "cold"
  checkResult_2 = "hot"
  iterKey_2 = "damaged"
  targetScale_2[1] = durationMs_2
  targetScale_2[2] = ptfxAsset_2
  targetScale_2[3] = ptfxName_2
  targetScale_2[4] = energyVal_2
  targetScale_2[5] = outletList_2
  targetScale_2[6] = pulseItem_2
  targetScale_2[7] = tempVal_2
  targetScale_2[8] = clampedScale_2
  targetScale_2[9] = boneCoords_2
  targetScale_2[10] = calcOffset_2
  targetScale_2[11] = checkResult_2
  targetScale_2[12] = iterKey_2
  currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2 = currentSpeed_2(targetScale_2)
  for ptfxName_2, energyVal_2 in currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2 do
    outletList_2 = flameActive_2[energyVal_2]
    pulseItem_2 = pulses[energyVal_2]
    tempVal_2 = type
    clampedScale_2 = outletList_2
    tempVal_2 = tempVal_2(clampedScale_2)
    if "number" == tempVal_2 then
      tempVal_2 = type
      clampedScale_2 = pulseItem_2
      tempVal_2 = tempVal_2(clampedScale_2)
      if "number" == tempVal_2 and pulseItem_2 > 0 then
        tempVal_2 = outletList_2 - 1
        tempVal_2 = tempVal_2 * pulseItem_2
        tempVal_2 = 1 + tempVal_2
        boneIndex_2 = boneIndex_2 * tempVal_2
      end
    end
  end
  currentSpeed_2 = math
  currentSpeed_2 = currentSpeed_2.max
  targetScale_2 = 0
  durationMs_2 = boneIndex_2
  return currentSpeed_2(targetScale_2, durationMs_2)
end
function ResolveFlameContext(vehicle, pulses, situation, tune)
  local currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2
  currentSpeed_2 = nil
  if pulses >= 1.0 and situation then
    targetScale_2 = vehicle.big
    if targetScale_2 then
      targetScale_2 = vehicle.big
      durationMs_2 = vehicle.name
      if "violet" == durationMs_2 then
        durationMs_2 = 1.15
        if pulses >= durationMs_2 then
          durationMs_2 = 1.5
          if durationMs_2 then
            goto lbl_20
          end
        end
      end
      durationMs_2 = 1.0
      ::lbl_20::
      currentSpeed_2 = targetScale_2 * durationMs_2
  end
  else
    targetScale_2 = vehicle.weight
    if not targetScale_2 then
      targetScale_2 = 0
    end
    if situation then
      durationMs_2 = vehicle.minEnergy
      if not durationMs_2 then
        durationMs_2 = 0
      end
      ptfxAsset_2 = 0.6
      if durationMs_2 >= ptfxAsset_2 then
        durationMs_2 = 2.2
        if durationMs_2 then
          goto lbl_40
        end
      end
    end
    durationMs_2 = 1.0
    ::lbl_40::
    currentSpeed_2 = targetScale_2 * durationMs_2
  end
  local styleMult = EvaluateStyleWeight(vehicle, tune)
  return (currentSpeed_2 or 0) * (styleMult or 1.0)
end
function reg_1_38(vehicle, pulses, situation, tune)
  local currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2
  currentSpeed_2 = 0
  targetScale_2 = {}
  durationMs_2 = {}
  ptfxAsset_2 = ipairs
  ptfxName_2 = flameColors
  ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2 = ptfxAsset_2(ptfxName_2)
  for pulseItem_2, tempVal_2 in ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2 do
    clampedScale_2 = tempVal_2.minEnergy
    if not clampedScale_2 then
      clampedScale_2 = 0
    end
    if pulses >= clampedScale_2 then
      clampedScale_2 = tempVal_2.maxEnergy
      if not clampedScale_2 then
        clampedScale_2 = 10
      end
      if pulses <= clampedScale_2 then
        clampedScale_2 = tempVal_2.heavy
        if not clampedScale_2 or situation then
          clampedScale_2 = ResolveFlameContext
          boneCoords_2 = tempVal_2
          calcOffset_2 = pulses
          checkResult_2 = situation
          iterKey_2 = tune
          clampedScale_2 = clampedScale_2(boneCoords_2, calcOffset_2, checkResult_2, iterKey_2)
          if clampedScale_2 > 0 then
            boneCoords_2 = #targetScale_2
            boneCoords_2 = boneCoords_2 + 1
            calcOffset_2 = #durationMs_2
            calcOffset_2 = calcOffset_2 + 1
            checkResult_2 = tempVal_2
            durationMs_2[calcOffset_2] = clampedScale_2
            targetScale_2[boneCoords_2] = checkResult_2
            currentSpeed_2 = currentSpeed_2 + clampedScale_2
          end
        end
      end
    end
  end
  ptfxAsset_2 = #targetScale_2
  if 0 == ptfxAsset_2 then
    ptfxAsset_2 = flameStyles.plume
    return ptfxAsset_2
  end
  ptfxAsset_2 = vehicle * 48271
  ptfxAsset_2 = ptfxAsset_2 % 2147483647
  ptfxAsset_2 = ptfxAsset_2 / 2147483647
  ptfxAsset_2 = ptfxAsset_2 * currentSpeed_2
  ptfxName_2 = ipairs
  energyVal_2 = targetScale_2
  ptfxName_2, energyVal_2, outletList_2, pulseItem_2 = ptfxName_2(energyVal_2)
  for tempVal_2, clampedScale_2 in ptfxName_2, energyVal_2, outletList_2, pulseItem_2 do
    boneCoords_2 = durationMs_2[tempVal_2]
    ptfxAsset_2 = ptfxAsset_2 - boneCoords_2
    if ptfxAsset_2 <= 0 then
      return clampedScale_2
    end
  end
  ptfxName_2 = #targetScale_2
  ptfxName_2 = targetScale_2[ptfxName_2]
  return ptfxName_2
end
function reg_1_39(vehicle, pulses, situation, tune, flameScale, seed, outletIdx)
  local ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2
  ptfxAsset_2 = flameCounter
  ptfxName_2 = ClampNumber
  energyVal_2 = ParticleConfig.maxActive
  outletList_2 = 1
  pulseItem_2 = 240
  tempVal_2 = 160
  ptfxName_2 = ptfxName_2(energyVal_2, outletList_2, pulseItem_2, tempVal_2)
  if ptfxAsset_2 >= ptfxName_2 then
    ptfxAsset_2 = nil
    return ptfxAsset_2
  end
  ptfxAsset_2 = GetBoneOffset
  ptfxName_2 = pulses
  energyVal_2 = situation
  outletList_2 = tune
  pulseItem_2 = outletIdx.peak
  ptfxAsset_2 = ptfxAsset_2(ptfxName_2, energyVal_2, outletList_2, pulseItem_2)
  if not ptfxAsset_2 then
    ptfxName_2 = nil
    return ptfxName_2
  end
  ptfxName_2 = outletIdx
  energyVal_2 = ptfxAsset_2
  ptfxName_2.part = pulses
  ptfxName_2.handle = energyVal_2
  energyVal_2 = flameScale.netId
  outletList_2 = flameScale.epoch
  if not outletList_2 then
    outletList_2 = 0
  end
  pulseItem_2 = flameScale.burstId
  ptfxName_2.burstId = pulseItem_2
  ptfxName_2.epoch = outletList_2
  ptfxName_2.netId = energyVal_2
  energyVal_2 = situation
  outletList_2 = tune
  ptfxName_2.outlet = seed
  ptfxName_2.point = outletList_2
  ptfxName_2.vehicle = energyVal_2
  energyVal_2 = particlePool
  outletList_2 = ptfxName_2
  pulseItem_2 = flameCounter
  pulseItem_2 = pulseItem_2 + 1
  flameCounter = pulseItem_2
  energyVal_2[vehicle] = outletList_2
  energyVal_2 = pulses.bakedColour
  if energyVal_2 then
    energyVal_2 = SetParticleFxLoopedColour
    outletList_2 = ptfxAsset_2
    pulseItem_2 = 1.0
    tempVal_2 = 1.0
    clampedScale_2 = 1.0
    boneCoords_2 = false
    energyVal_2(outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2)
  else
    energyVal_2 = ParticleConfig.tint
    if false ~= energyVal_2 then
      energyVal_2 = ptfxName_2.colour
      if energyVal_2 then
        energyVal_2 = SetParticleFxLoopedColour
        outletList_2 = ptfxAsset_2
        pulseItem_2 = ptfxName_2.colour
        pulseItem_2 = pulseItem_2[1]
        tempVal_2 = ptfxName_2.colour
        tempVal_2 = tempVal_2[2]
        clampedScale_2 = ptfxName_2.colour
        clampedScale_2 = clampedScale_2[3]
        boneCoords_2 = false
        energyVal_2(outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2)
      end
    end
  end
  return ptfxName_2
end
function reg_1_40(vehicle, pulses, situation, tune, flameScale, seed, outletIdx, param_2_7, param_2_8, param_2_9, param_2_10, param_2_11, param_2_12, param_2_13)
  local boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2
  boneCoords_2 = activeParticleCount
  boneCoords_2 = boneCoords_2 + 1
  activeParticleCount = boneCoords_2
  boneCoords_2 = reg_1_39
  calcOffset_2 = outletIdx
  checkResult_2 = ":"
  iterKey_2 = pulses
  iterValue_2 = ":"
  soundRadius_2 = activeParticleCount
  calcOffset_2 = calcOffset_2 .. checkResult_2 .. iterKey_2 .. iterValue_2 .. soundRadius_2
  checkResult_2 = vehicle
  iterKey_2 = tune
  iterValue_2 = flameScale
  soundRadius_2 = seed
  burstKey_2 = outletIdx
  ambientLight_2 = {}
  ambientLight_2.kind = "burst"
  ambientLight_2.which = pulses
  rainLevel_2 = param_2_7 - param_2_8
  ambientLight_2.started = rainLevel_2
  ambientLight_2.duration = param_2_9
  ambientLight_2.peak = param_2_10
  ambientLight_2.phase = param_2_11
  rainLevel_2 = math
  rainLevel_2 = rainLevel_2.min
  colorR_2 = param_2_9 * 0.14
  if situation then
    colorG_2 = 5.0
    if colorG_2 then
      goto lbl_37
    end
  end
  colorG_2 = 9.0
  ::lbl_37::
  rainLevel_2 = rainLevel_2(colorR_2, colorG_2)
  ambientLight_2.attack = rainLevel_2
  if situation then
    rainLevel_2 = 0.38
    if rainLevel_2 then
      goto lbl_45
    end
  end
  rainLevel_2 = 0.52
  ::lbl_45::
  ambientLight_2.sustain = rainLevel_2
  if situation then
    rainLevel_2 = 0.95
    if rainLevel_2 then
      goto lbl_52
    end
  end
  rainLevel_2 = 0.92
  ::lbl_52::
  ambientLight_2.opacity = rainLevel_2
  ambientLight_2.energy = param_2_12
  ambientLight_2.colour = param_2_13
  boneCoords_2 = boneCoords_2(calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2)
  if not boneCoords_2 then
    calcOffset_2 = false
    return calcOffset_2
  end
  calcOffset_2, checkResult_2 = CalculateParticleEnvelope(boneCoords_2, param_2_7)
  iterKey_2 = SetParticleFxLoopedScale
  iterValue_2 = boneCoords_2.handle
  soundRadius_2 = calcOffset_2
  iterKey_2(iterValue_2, soundRadius_2)
  iterKey_2 = SetParticleFxLoopedAlpha
  iterValue_2 = boneCoords_2.handle
  soundRadius_2 = checkResult_2
  iterKey_2(iterValue_2, soundRadius_2)
  iterKey_2 = true
  return iterKey_2
end
function reg_1_41(vehicle, pulses, situation, tune, flameScale, seed, outletIdx, param_2_7, param_2_8, param_2_9)
  local outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2
  outletList_2 = flameLayers
  outletList_2 = outletList_2[vehicle]
  if not outletList_2 then
    return
  end
  pulseItem_2 = activeParticleCount
  pulseItem_2 = pulseItem_2 + 1
  activeParticleCount = pulseItem_2
  pulseItem_2 = reg_1_39
  tempVal_2 = flameScale
  clampedScale_2 = ":"
  boneCoords_2 = vehicle
  calcOffset_2 = ":"
  checkResult_2 = activeParticleCount
  tempVal_2 = tempVal_2 .. clampedScale_2 .. boneCoords_2 .. calcOffset_2 .. checkResult_2
  clampedScale_2 = outletList_2
  boneCoords_2 = pulses
  calcOffset_2 = situation
  checkResult_2 = tune
  iterKey_2 = flameScale
  iterValue_2 = {}
  iterValue_2.kind = "extra"
  soundRadius_2 = seed - outletIdx
  iterValue_2.started = soundRadius_2
  soundRadius_2 = ClampNumber
  burstKey_2 = outletList_2.durationMs
  ambientLight_2 = 40
  rainLevel_2 = 2000
  colorR_2 = 200
  soundRadius_2 = soundRadius_2(burstKey_2, ambientLight_2, rainLevel_2, colorR_2)
  iterValue_2.duration = soundRadius_2
  soundRadius_2 = ClampNumber
  burstKey_2 = outletList_2.scale
  ambientLight_2 = 0.05
  rainLevel_2 = 3.0
  colorR_2 = 0.5
  soundRadius_2 = soundRadius_2(burstKey_2, ambientLight_2, rainLevel_2, colorR_2)
  burstKey_2 = math
  burstKey_2 = burstKey_2.min
  ambientLight_2 = 1.8
  rainLevel_2 = param_2_7
  burstKey_2 = burstKey_2(ambientLight_2, rainLevel_2)
  soundRadius_2 = soundRadius_2 * burstKey_2
  iterValue_2.peak = soundRadius_2
  iterValue_2.energy = 0
  iterValue_2.colour = param_2_8
  pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2)
  if pulseItem_2 and param_2_9 then
    tempVal_2 = SetParticleFxLoopedAlpha
    clampedScale_2 = pulseItem_2.handle
    boneCoords_2 = param_2_9
    tempVal_2(clampedScale_2, boneCoords_2)
  end
end
function reg_1_42(vehicle, pulses)
  local flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2
  if vehicle then
    flameActive_2 = type
    boneIndex_2 = pulses.tint
    flameActive_2 = flameActive_2(boneIndex_2)
    if "table" == flameActive_2 then
      flameActive_2 = Config
      flameActive_2 = flameActive_2.ColouredFlames
      if not flameActive_2 then
        flameActive_2 = {}
      end
      flameActive_2 = flameActive_2.enabled
      if false ~= flameActive_2 then
        goto lbl_18
      end
    end
  end
  do return vehicle end
  ::lbl_18::
  flameActive_2 = PopsNativeFlameAssets
  if not flameActive_2 then
    flameActive_2 = {}
  end
  boneIndex_2 = pulses.exhaust
  flameActive_2 = flameActive_2[boneIndex_2]
  boneIndex_2 = flameActive_2 or boneIndex_2
  if flameActive_2 then
    boneIndex_2 = vehicle.asset
    boneIndex_2 = flameActive_2[boneIndex_2]
    if boneIndex_2 then
      boneIndex_2 = vehicle.asset
      boneIndex_2 = flameActive_2[boneIndex_2]
      currentSpeed_2 = vehicle.name
      boneIndex_2 = boneIndex_2[currentSpeed_2]
    end
  end
  if not boneIndex_2 then
    return vehicle
  end
  targetScale_2 = boneIndex_2.asset
  currentSpeed_2 = trackedEntities
  currentSpeed_2 = currentSpeed_2[targetScale_2]
  if not currentSpeed_2 then
    RequestPtfxAsset(boneIndex_2.asset)
    return vehicle
  end
  currentSpeed_2 = vehicle.asset
  targetScale_2 = ":"
  durationMs_2 = vehicle.name
  ptfxAsset_2 = ":"
  ptfxName_2 = pulses.exhaust
  currentSpeed_2 = currentSpeed_2 .. targetScale_2 .. durationMs_2 .. ptfxAsset_2 .. ptfxName_2
  targetScale_2 = styleDefinitions
  targetScale_2 = targetScale_2[currentSpeed_2]
  if not targetScale_2 then
    targetScale_2 = {}
    durationMs_2 = pairs
    ptfxAsset_2 = vehicle
    durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2 = durationMs_2(ptfxAsset_2)
    for outletList_2, pulseItem_2 in durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2 do
      targetScale_2[outletList_2] = pulseItem_2
    end
    durationMs_2 = boneIndex_2.asset
    ptfxAsset_2 = boneIndex_2.name
    targetScale_2.bakedColour = true
    targetScale_2.name = ptfxAsset_2
    targetScale_2.asset = durationMs_2
    durationMs_2 = styleDefinitions
    durationMs_2[currentSpeed_2] = targetScale_2
  end
  targetScale_2 = styleDefinitions
  targetScale_2 = targetScale_2[currentSpeed_2]
  return targetScale_2
end
function reg_1_43(vehicle, pulses, situation, tune, flameScale, seed, outletIdx, param_2_7, param_2_8, param_2_9, param_2_10, param_2_11, param_2_12)
  local clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2, colorB_2, layerEntry_2, styleItem_2, ptfxHandle_2, isDone_2, reg_2_30, reg_2_31, reg_2_32, reg_2_33, reg_2_34, reg_2_35, reg_2_36, reg_2_37, reg_2_38, reg_2_39, reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45
  clampedScale_2 = false
  boneCoords_2 = tune.context
  if not boneCoords_2 then
    boneCoords_2 = {}
  end
  calcOffset_2 = boneCoords_2.fast
  if not calcOffset_2 then
    calcOffset_2 = 0
  end
  calcOffset_2 = 0.18 * calcOffset_2
  checkResult_2 = 1.0
  calcOffset_2 = checkResult_2 - calcOffset_2
  checkResult_2 = boneCoords_2.standing
  if not checkResult_2 then
    checkResult_2 = 0
  end
  checkResult_2 = 0.15 * checkResult_2
  calcOffset_2 = calcOffset_2 + checkResult_2
  checkResult_2 = vehicle.layers
  iterKey_2 = ipairs
  iterValue_2 = checkResult_2
  iterKey_2, iterValue_2, soundRadius_2, burstKey_2 = iterKey_2(iterValue_2)
  for ambientLight_2, rainLevel_2 in iterKey_2, iterValue_2, soundRadius_2, burstKey_2 do
    colorR_2 = reg_1_42
    colorB_2 = rainLevel_2[1]
    colorG_2 = flameLayers
    colorG_2 = colorG_2[colorB_2]
    colorB_2 = tune
    colorR_2 = colorR_2(colorG_2, colorB_2)
    colorG_2 = rainLevel_2[3]
    colorG_2 = true == colorG_2
    if colorR_2 then
      layerEntry_2 = colorR_2.asset
      colorB_2 = trackedEntities
      colorB_2 = colorB_2[layerEntry_2]
      if colorB_2 then
        goto lbl_57
      end
    end
    colorB_2 = reg_1_42
    if colorG_2 then
      layerEntry_2 = flameLayers.core
      if layerEntry_2 then
        goto lbl_54
      end
    end
    layerEntry_2 = flameLayers.plume
    ::lbl_54::
    styleItem_2 = tune
    colorB_2 = colorB_2(layerEntry_2, styleItem_2)
    colorR_2 = colorB_2
    ::lbl_57::
    colorB_2 = rainLevel_2[1]
    if "plume" == colorB_2 then
      colorB_2 = ParticleConfig.dualLayer
      if false == colorB_2 then
        colorB_2 = #checkResult_2
        if 1 ~= colorB_2 then
          goto lbl_134
        end
      end
    end
    colorB_2 = CalculateFlamePosition
    layerEntry_2 = vehicle
    styleItem_2 = param_2_11
    ptfxHandle_2 = colorG_2
    isDone_2 = param_2_12
    reg_2_30 = param_2_10
    if colorR_2 then
      reg_2_31 = colorR_2.bakedColour
      if reg_2_31 then
        reg_2_31 = tune.tint
        if reg_2_31 then
          goto lbl_81
        end
      end
    end
    reg_2_31 = nil
    ::lbl_81::
    colorB_2, layerEntry_2, styleItem_2 = colorB_2(layerEntry_2, styleItem_2, ptfxHandle_2, isDone_2, reg_2_30, reg_2_31)
    ptfxHandle_2 = reg_1_40
    isDone_2 = colorR_2
    reg_2_30 = rainLevel_2[1]
    reg_2_31 = colorG_2
    reg_2_32 = pulses
    reg_2_33 = situation
    reg_2_34 = tune
    reg_2_35 = flameScale
    reg_2_36 = seed
    reg_2_37 = outletIdx
    if colorG_2 then
      reg_2_38 = 1.0
      if reg_2_38 then
        goto lbl_98
      end
    end
    reg_2_38 = 1.15
    ::lbl_98::
    reg_2_38 = param_2_7 * reg_2_38
    reg_2_39 = ClampNumber
    reg_2_40 = rainLevel_2[2]
    reg_2_41 = 0.05
    reg_2_42 = 4.0
    reg_2_43 = 1.0
    reg_2_39 = reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43)
    reg_2_39 = param_2_8 * reg_2_39
    if colorG_2 then
      reg_2_40 = 1.0
      if reg_2_40 then
        goto lbl_114
      end
    end
    reg_2_40 = calcOffset_2
    ::lbl_114::
    reg_2_39 = reg_2_39 * reg_2_40
    if colorG_2 then
      reg_2_40 = 0
      if reg_2_40 then
        goto lbl_122
      end
    end
    reg_2_40 = 1.3
    ::lbl_122::
    reg_2_40 = param_2_9 + reg_2_40
    reg_2_41 = param_2_10
    reg_2_42 = {}
    reg_2_43 = colorB_2
    reg_2_44 = layerEntry_2
    reg_2_45 = styleItem_2
    reg_2_42[1] = reg_2_43
    reg_2_42[2] = reg_2_44
    reg_2_42[3] = reg_2_45
    ptfxHandle_2 = ptfxHandle_2(isDone_2, reg_2_30, reg_2_31, reg_2_32, reg_2_33, reg_2_34, reg_2_35, reg_2_36, reg_2_37, reg_2_38, reg_2_39, reg_2_40, reg_2_41, reg_2_42)
    clampedScale_2 = ptfxHandle_2 or clampedScale_2
    if not ptfxHandle_2 then
    end
    ::lbl_134::
  end
  return clampedScale_2
end
function reg_1_44(vehicle, pulses, situation)
  local boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2
  boneIndex_2 = exhaustBoneList
  boneIndex_2 = #boneIndex_2
  currentSpeed_2 = boneIndex_2 + 1
  boneIndex_2 = exhaustBoneList
  targetScale_2 = {}
  targetScale_2.at = vehicle
  durationMs_2 = pulses.netId
  targetScale_2.netId = durationMs_2
  durationMs_2 = pulses.burstId
  targetScale_2.burstId = durationMs_2
  targetScale_2.run = situation
  boneIndex_2[currentSpeed_2] = targetScale_2
end
function EmitFlames(vehicle, pulses, situation, tune)
  local currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2, colorB_2, layerEntry_2, styleItem_2, ptfxHandle_2, isDone_2, reg_2_30, reg_2_31, reg_2_32, reg_2_33, reg_2_34, reg_2_35, reg_2_36, reg_2_37, reg_2_38, reg_2_39, reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51, reg_2_52, reg_2_53, reg_2_54, reg_2_55, reg_2_56
  currentSpeed_2 = type
  targetScale_2 = pulses
  currentSpeed_2 = currentSpeed_2(targetScale_2)
  if "table" == currentSpeed_2 then
    currentSpeed_2 = type
    targetScale_2 = situation
    currentSpeed_2 = currentSpeed_2(targetScale_2)
    if "table" == currentSpeed_2 then
      currentSpeed_2 = type
      targetScale_2 = tune
      currentSpeed_2 = currentSpeed_2(targetScale_2)
      if "table" == currentSpeed_2 then
        currentSpeed_2 = IsFiniteNumber
        targetScale_2 = tune.netId
        currentSpeed_2 = currentSpeed_2(targetScale_2)
        if currentSpeed_2 and 0 ~= vehicle then
          currentSpeed_2 = DoesEntityExist
          targetScale_2 = vehicle
          currentSpeed_2 = currentSpeed_2(targetScale_2)
          if currentSpeed_2 then
            currentSpeed_2 = GetIsVehicleEngineRunning
            targetScale_2 = vehicle
            currentSpeed_2 = currentSpeed_2(targetScale_2)
            if currentSpeed_2 then
              goto lbl_35
            end
          end
        end
      end
    end
  end
  currentSpeed_2 = false
  do return currentSpeed_2 end
  ::lbl_35::
  currentSpeed_2 = flameLayers.plume
  if currentSpeed_2 then
    currentSpeed_2 = flameLayers.plume
    currentSpeed_2 = currentSpeed_2.asset
  end
  targetScale_2 = trackedEntities
  currentSpeed_2 = targetScale_2[currentSpeed_2]
  if not currentSpeed_2 then
    currentSpeed_2 = false
    return currentSpeed_2
  end
  currentSpeed_2 = GetGameTimer
  currentSpeed_2 = currentSpeed_2()
  targetScale_2 = ClampNumber
  durationMs_2 = ParticleConfig.minDurationMs
  ptfxAsset_2 = 40
  ptfxName_2 = 140
  energyVal_2 = 85
  targetScale_2 = targetScale_2(durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2)
  durationMs_2 = ClampNumber
  ptfxAsset_2 = situation.durationMs
  if not ptfxAsset_2 then
    ptfxAsset_2 = situation.flameMs
  end
  ptfxName_2 = targetScale_2
  energyVal_2 = 420
  outletList_2 = 95
  durationMs_2 = durationMs_2(ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2)
  ptfxAsset_2 = ClampNumber
  ptfxName_2 = tune.ageMs
  energyVal_2 = 0
  outletList_2 = 1000000
  pulseItem_2 = 0
  ptfxAsset_2 = ptfxAsset_2(ptfxName_2, energyVal_2, outletList_2, pulseItem_2)
  if durationMs_2 <= ptfxAsset_2 then
    ptfxName_2 = false
    return ptfxName_2
  end
  ptfxName_2 = pairs
  energyVal_2 = particlePool
  ptfxName_2, energyVal_2, outletList_2, pulseItem_2 = ptfxName_2(energyVal_2)
  for tempVal_2, clampedScale_2 in ptfxName_2, energyVal_2, outletList_2, pulseItem_2 do
    boneCoords_2 = clampedScale_2.netId
    calcOffset_2 = tune.netId
    if boneCoords_2 == calcOffset_2 then
      boneCoords_2 = clampedScale_2.epoch
      calcOffset_2 = tune.epoch
      if not calcOffset_2 then
        calcOffset_2 = 0
      end
      if boneCoords_2 > calcOffset_2 then
        boneCoords_2 = false
        return boneCoords_2
      end
      boneCoords_2 = clampedScale_2.epoch
      calcOffset_2 = tune.epoch
      if not calcOffset_2 then
        calcOffset_2 = 0
      end
      if boneCoords_2 < calcOffset_2 then
        boneCoords_2 = PopsFlames
        boneCoords_2 = boneCoords_2.Cancel
        calcOffset_2 = tune.netId
        boneCoords_2(calcOffset_2)
        break
      end
    end
  end
  ptfxName_2 = ClampNumber
  energyVal_2 = situation.energy
  outletList_2 = 0.05
  pulseItem_2 = 1.5
  tempVal_2 = 0.65
  ptfxName_2 = ptfxName_2(energyVal_2, outletList_2, pulseItem_2, tempVal_2)
  outletList_2 = tune.level
  energyVal_2 = activeFlames
  energyVal_2 = energyVal_2[outletList_2]
  if not energyVal_2 then
    energyVal_2 = {}
  end
  outletList_2 = ClampNumber
  pulseItem_2 = situation.scale
  tempVal_2 = 0.04
  clampedScale_2 = 3.6
  boneCoords_2 = ClampNumber
  calcOffset_2 = energyVal_2.flameScale
  checkResult_2 = 0.1
  iterKey_2 = 2.0
  iterValue_2 = 0.6
  boneCoords_2 = boneCoords_2(calcOffset_2, checkResult_2, iterKey_2, iterValue_2)
  boneCoords_2 = boneCoords_2 * ptfxName_2
  outletList_2 = outletList_2(pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2)
  tempVal_2 = situation.seed or tune.seed
  pulseItem_2 = PseudoRandomFloat(tempVal_2, tune.netId * 19)
  tempVal_2 = math
  tempVal_2 = tempVal_2.floor
  clampedScale_2 = ClampNumber
  boneCoords_2 = tune.level
  calcOffset_2 = 1
  checkResult_2 = 4
  iterKey_2 = 1
  clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2, colorB_2, layerEntry_2, styleItem_2, ptfxHandle_2, isDone_2, reg_2_30, reg_2_31, reg_2_32, reg_2_33, reg_2_34, reg_2_35, reg_2_36, reg_2_37, reg_2_38, reg_2_39, reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51, reg_2_52, reg_2_53, reg_2_54, reg_2_55, reg_2_56 = clampedScale_2(boneCoords_2, calcOffset_2, checkResult_2, iterKey_2)
  tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2, colorB_2, layerEntry_2, styleItem_2, ptfxHandle_2, isDone_2, reg_2_30, reg_2_31, reg_2_32, reg_2_33, reg_2_34, reg_2_35, reg_2_36, reg_2_37, reg_2_38, reg_2_39, reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51, reg_2_52, reg_2_53, reg_2_54, reg_2_55, reg_2_56)
  clampedScale_2 = ClampNumber
  boneCoords_2 = energyVal_2.minFlameScale
  calcOffset_2 = 0.2
  checkResult_2 = 1.6
  iterKey_2 = {}
  iterValue_2 = 0.7
  soundRadius_2 = 0.9
  burstKey_2 = 1.1
  ambientLight_2 = 1.2
  iterKey_2[1] = iterValue_2
  iterKey_2[2] = soundRadius_2
  iterKey_2[3] = burstKey_2
  iterKey_2[4] = ambientLight_2
  iterKey_2 = iterKey_2[tempVal_2]
  clampedScale_2 = clampedScale_2(boneCoords_2, calcOffset_2, checkResult_2, iterKey_2)
  boneCoords_2 = ClampNumber
  calcOffset_2 = tune.temperature
  checkResult_2 = 0
  iterKey_2 = 1
  iterValue_2 = 0.55
  boneCoords_2 = boneCoords_2(calcOffset_2, checkResult_2, iterKey_2, iterValue_2)
  calcOffset_2 = type
  checkResult_2 = tune.context
  calcOffset_2 = calcOffset_2(checkResult_2)
  if "table" == calcOffset_2 then
    calcOffset_2 = tune.context
    if calcOffset_2 then
      goto lbl_178
    end
  end
  calcOffset_2 = {}
  ::lbl_178::
  checkResult_2 = situation.kind
  checkResult_2 = "boom" == checkResult_2
  iterKey_2 = situation.heavy
  iterKey_2 = situation.kind
  iterKey_2 = true == iterKey_2 or iterKey_2
  iterValue_2 = reg_1_38
  soundRadius_2 = pulseItem_2
  burstKey_2 = ptfxName_2
  ambientLight_2 = iterKey_2
  rainLevel_2 = calcOffset_2
  iterValue_2 = iterValue_2(soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2)
  soundRadius_2 = pulseItem_2 % 211
  soundRadius_2 = soundRadius_2 / 211
  soundRadius_2 = soundRadius_2 * 0.2
  soundRadius_2 = 0.9 + soundRadius_2
  burstKey_2 = UpdateAmbientWeather(currentSpeed_2)
  ambientLight_2 = burstKey_2.rain
  rainLevel_2 = 0.2
  ambientLight_2 = ambientLight_2 > rainLevel_2
  rainLevel_2 = PopsFlames
  rainLevel_2 = rainLevel_2.Outlets
  colorR_2 = tune.burstSeed
  if not colorR_2 then
    colorR_2 = pulseItem_2
  end
  colorG_2 = tune.index
  if not colorG_2 then
    colorG_2 = 1
  end
  colorB_2 = math
  colorB_2 = colorB_2.min
  layerEntry_2 = #pulses
  styleItem_2 = maxOutlets
  colorB_2 = colorB_2(layerEntry_2, styleItem_2)
  layerEntry_2 = iterKey_2
  styleItem_2 = tune.continuous
  styleItem_2 = true == styleItem_2
  rainLevel_2 = rainLevel_2(colorR_2, colorG_2, colorB_2, layerEntry_2, styleItem_2)
  colorR_2 = false
  colorG_2 = true
  colorB_2 = ipairs
  layerEntry_2 = rainLevel_2
  colorB_2, layerEntry_2, styleItem_2, ptfxHandle_2 = colorB_2(layerEntry_2)
  for isDone_2, reg_2_30 in colorB_2, layerEntry_2, styleItem_2, ptfxHandle_2 do
    reg_2_31 = ValidateOutletOffset(pulses[reg_2_30])
    if reg_2_31 then
      reg_2_32 = pulseItem_2 % 997
      reg_2_32 = reg_2_32 * 0.013
      reg_2_33 = reg_2_30 * 2.17
      reg_2_32 = reg_2_32 + reg_2_33
      reg_2_33 = tostring
      reg_2_34 = tune.netId
      reg_2_33 = reg_2_33(reg_2_34)
      reg_2_34 = ":"
      reg_2_35 = tostring
      reg_2_36 = vehicle
      reg_2_35 = reg_2_35(reg_2_36)
      reg_2_36 = ":"
      reg_2_37 = reg_2_30
      reg_2_33 = reg_2_33 .. reg_2_34 .. reg_2_35 .. reg_2_36 .. reg_2_37
      reg_2_34 = math
      reg_2_34 = reg_2_34.sin
      reg_2_35 = reg_2_32
      reg_2_34 = reg_2_34(reg_2_35)
      reg_2_34 = 0.08 * reg_2_34
      reg_2_34 = 0.92 + reg_2_34
      reg_2_35 = ClampNumber
      reg_2_36 = ParticleConfig.scale
      reg_2_37 = 0.3
      reg_2_38 = 3.0
      reg_2_39 = 1.0
      reg_2_35 = reg_2_35(reg_2_36, reg_2_37, reg_2_38, reg_2_39)
      reg_2_36 = ClampNumber
      reg_2_37 = iterValue_2.size
      reg_2_38 = 0.2
      reg_2_39 = 3.0
      reg_2_40 = 1.0
      reg_2_36 = reg_2_36(reg_2_37, reg_2_38, reg_2_39, reg_2_40)
      reg_2_35 = reg_2_35 * reg_2_36
      reg_2_36 = math
      reg_2_36 = reg_2_36.min
      reg_2_37 = ClampNumber
      reg_2_38 = ParticleConfig.maxScale
      reg_2_39 = 0.2
      reg_2_40 = 5.0
      reg_2_41 = 3.6
      reg_2_37 = reg_2_37(reg_2_38, reg_2_39, reg_2_40, reg_2_41)
      reg_2_38 = math
      reg_2_38 = reg_2_38.max
      reg_2_39 = clampedScale_2
      reg_2_40 = outletList_2 * 1.35
      reg_2_38 = reg_2_38(reg_2_39, reg_2_40)
      reg_2_39 = reg_2_31.scale
      reg_2_38 = reg_2_38 * reg_2_39
      reg_2_38 = reg_2_38 * reg_2_34
      reg_2_38 = reg_2_38 * reg_2_35
      if checkResult_2 then
        reg_2_39 = 1.3
        if reg_2_39 then
          goto lbl_321
        end
      end
      if iterKey_2 then
        reg_2_39 = 1.2
        if reg_2_39 then
          goto lbl_321
        end
      end
      reg_2_39 = 1.0
      ::lbl_321::
      reg_2_38 = reg_2_38 * reg_2_39
      reg_2_39 = burstKey_2.rain
      reg_2_39 = 0.12 * reg_2_39
      reg_2_40 = 1
      reg_2_39 = reg_2_40 - reg_2_39
      reg_2_38 = reg_2_38 * reg_2_39
      reg_2_36 = reg_2_36(reg_2_37, reg_2_38)
      reg_2_37 = pairs
      reg_2_38 = particlePool
      reg_2_37, reg_2_38, reg_2_39, reg_2_40 = reg_2_37(reg_2_38)
      for reg_2_41, reg_2_42 in reg_2_37, reg_2_38, reg_2_39, reg_2_40 do
        reg_2_43 = reg_2_42.outlet
        if reg_2_43 == reg_2_33 then
          reg_2_43 = reg_2_42.kind
          if "burst" == reg_2_43 then
            reg_2_43 = reg_2_42.started
            reg_2_43 = currentSpeed_2 - reg_2_43
            if reg_2_43 > 45 then
              reg_2_43 = StopParticle
              reg_2_44 = reg_2_41
              reg_2_45 = true
              reg_2_43(reg_2_44, reg_2_45)
            end
          end
        end
      end
      reg_2_37 = reg_1_43
      reg_2_38 = iterValue_2
      reg_2_39 = vehicle
      reg_2_40 = reg_2_31
      reg_2_41 = tune
      reg_2_42 = reg_2_33
      reg_2_43 = currentSpeed_2
      reg_2_44 = ptfxAsset_2
      reg_2_45 = durationMs_2
      reg_2_46 = reg_2_36
      reg_2_47 = reg_2_32
      reg_2_48 = ptfxName_2
      reg_2_49 = boneCoords_2
      reg_2_50 = soundRadius_2
      reg_2_37 = reg_2_37(reg_2_38, reg_2_39, reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50)
      colorR_2 = reg_2_37 or colorR_2
      if not reg_2_37 then
      end
      reg_2_37 = iterValue_2.twin
      if reg_2_37 then
        reg_2_37 = ClampNumber
        reg_2_38 = iterValue_2.twin
        reg_2_39 = 15
        reg_2_40 = 200
        reg_2_41 = 60
        reg_2_37 = reg_2_37(reg_2_38, reg_2_39, reg_2_40, reg_2_41)
        reg_2_38 = 1
        reg_2_39 = math
        reg_2_39 = reg_2_39.floor
        reg_2_40 = ClampNumber
        reg_2_41 = iterValue_2.repeats
        reg_2_42 = 1
        reg_2_43 = 4
        reg_2_44 = 1
        reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51, reg_2_52, reg_2_53, reg_2_54, reg_2_55, reg_2_56 = reg_2_40(reg_2_41, reg_2_42, reg_2_43, reg_2_44)
        reg_2_39 = reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51, reg_2_52, reg_2_53, reg_2_54, reg_2_55, reg_2_56)
        reg_2_40 = 1
        for reg_2_41 = reg_2_38, reg_2_39, reg_2_40 do
          reg_2_42 = 0.85
          reg_2_42 = reg_2_42 ^ reg_2_41
          reg_2_43 = reg_1_44
          reg_2_44 = currentSpeed_2 - ptfxAsset_2
          reg_2_45 = reg_2_37 * reg_2_41
          reg_2_44 = reg_2_44 + reg_2_45
          reg_2_45 = pulseItem_2 % 17
          reg_2_44 = reg_2_44 + reg_2_45
          reg_2_45 = tune
          function reg_2_46(particleId)
            local currentCoords_3, flameActive_3, boneIndex_3, currentSpeed_3, targetScale_3, durationMs_3, ptfxAsset_3, ptfxName_3, energyVal_3, outletList_3, pulseItem_3, tempVal_3, clampedScale_3, boneCoords_3
            currentCoords_3 = DoesEntityExist
            flameActive_3 = vehicle
            currentCoords_3 = currentCoords_3(flameActive_3)
            if currentCoords_3 then
              currentCoords_3 = GetIsVehicleEngineRunning
              flameActive_3 = vehicle
              currentCoords_3 = currentCoords_3(flameActive_3)
              if currentCoords_3 then
                currentCoords_3 = reg_1_43
                flameActive_3 = iterValue_2
                boneIndex_3 = vehicle
                currentSpeed_3 = reg_2_31
                targetScale_3 = tune
                durationMs_3 = reg_2_33
                ptfxAsset_3 = particleId
                ptfxName_3 = 0
                energyVal_3 = durationMs_2
                energyVal_3 = energyVal_3 * 0.8
                outletList_3 = reg_2_36
                pulseItem_3 = reg_2_42
                outletList_3 = outletList_3 * pulseItem_3
                pulseItem_3 = reg_2_32
                tempVal_3 = reg_2_41
                tempVal_3 = 0.9 * tempVal_3
                pulseItem_3 = pulseItem_3 + tempVal_3
                tempVal_3 = ptfxName_2
                clampedScale_3 = reg_2_42
                tempVal_3 = tempVal_3 * clampedScale_3
                clampedScale_3 = boneCoords_2
                boneCoords_3 = soundRadius_2
                currentCoords_3(flameActive_3, boneIndex_3, currentSpeed_3, targetScale_3, durationMs_3, ptfxAsset_3, ptfxName_3, energyVal_3, outletList_3, pulseItem_3, tempVal_3, clampedScale_3, boneCoords_3)
              end
            end
          end
          reg_2_43(reg_2_44, reg_2_45, reg_2_46)
        end
      end
      reg_2_37 = reg_1_42
      reg_2_38 = flameLayers.jet
      reg_2_39 = tune
      reg_2_37 = reg_2_37(reg_2_38, reg_2_39)
      reg_2_38 = iterValue_2.jet
      if not reg_2_38 then
        reg_2_38 = tune.continuous
        if reg_2_38 or iterKey_2 then
          reg_2_38 = 1.0
          if reg_2_38 then
            goto lbl_428
          end
        end
        reg_2_38 = nil
      end
      ::lbl_428::
      if reg_2_37 and reg_2_38 then
        reg_2_39 = iterValue_2.jet
        if reg_2_39 then
          reg_2_39 = 0.35
          if reg_2_39 then
            goto lbl_444
          end
        end
        reg_2_39 = ClampNumber
        reg_2_40 = reg_2_37.minEnergy
        reg_2_41 = 0
        reg_2_42 = 1.5
        reg_2_43 = 0.5
        reg_2_39 = reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43)
        ::lbl_444::
        if ptfxName_2 >= reg_2_39 then
          reg_2_39 = reg_2_33
          reg_2_40 = ":jet"
          reg_2_39 = reg_2_39 .. reg_2_40
          reg_2_40 = particlePool
          reg_2_40 = reg_2_40[reg_2_39]
          if reg_2_40 then
            reg_2_41 = DoesParticleFxLoopedExist
            reg_2_42 = reg_2_40.handle
            reg_2_41 = reg_2_41(reg_2_42)
            if reg_2_41 then
              reg_2_41 = reg_2_40.part
              reg_2_41 = reg_2_41.asset
              reg_2_42 = reg_2_37.asset
              if reg_2_41 == reg_2_42 then
                reg_2_41 = reg_2_40.part
                reg_2_41 = reg_2_41.name
                reg_2_42 = reg_2_37.name
                if reg_2_41 == reg_2_42 then
                  goto lbl_473
                end
              end
            end
            reg_2_41 = StopParticle
            reg_2_42 = reg_2_39
            reg_2_43 = false
            reg_2_41(reg_2_42, reg_2_43)
            reg_2_40 = nil
          end
          ::lbl_473::
          reg_2_41 = ClampNumber
          reg_2_42 = reg_2_37.scale
          reg_2_43 = 0.1
          reg_2_44 = 3.0
          reg_2_45 = 0.55
          reg_2_41 = reg_2_41(reg_2_42, reg_2_43, reg_2_44, reg_2_45)
          reg_2_41 = reg_2_41 * reg_2_36
          reg_2_42 = ClampNumber
          reg_2_43 = reg_2_38
          reg_2_44 = 0.2
          reg_2_45 = 3.0
          reg_2_46 = 1.0
          reg_2_42 = reg_2_42(reg_2_43, reg_2_44, reg_2_45, reg_2_46)
          reg_2_41 = reg_2_41 * reg_2_42
          reg_2_42 = calcOffset_2.fast
          if not reg_2_42 then
            reg_2_42 = 0
          end
          reg_2_42 = 0.35 * reg_2_42
          reg_2_42 = 1 + reg_2_42
          reg_2_41 = reg_2_41 * reg_2_42
          reg_2_42 = CalculateFlamePosition
          reg_2_43 = iterValue_2
          reg_2_44 = boneCoords_2
          reg_2_45 = 0.82
          reg_2_45 = boneCoords_2 > reg_2_45
          reg_2_46 = soundRadius_2
          reg_2_47 = ptfxName_2
          reg_2_48 = reg_2_37.bakedColour
          if reg_2_48 then
            reg_2_48 = tune.tint
            if reg_2_48 then
              goto lbl_519
            end
          end
          reg_2_48 = nil
          ::lbl_519::
          reg_2_42, reg_2_43, reg_2_44 = reg_2_42(reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48)
          if not reg_2_40 then
            reg_2_45 = reg_1_39
            reg_2_46 = reg_2_39
            reg_2_47 = reg_2_37
            reg_2_48 = vehicle
            reg_2_49 = reg_2_31
            reg_2_50 = tune
            reg_2_51 = reg_2_33
            reg_2_52 = {}
            reg_2_52.kind = "jet"
            reg_2_52.peak = reg_2_41
            reg_2_53 = {}
            reg_2_54 = reg_2_42
            reg_2_55 = reg_2_43
            reg_2_56 = reg_2_44
            reg_2_53[1] = reg_2_54
            reg_2_53[2] = reg_2_55
            reg_2_53[3] = reg_2_56
            reg_2_52.colour = reg_2_53
            reg_2_45 = reg_2_45(reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51, reg_2_52)
            reg_2_40 = reg_2_45
          else
            reg_2_45 = ParticleConfig.tint
            if false ~= reg_2_45 then
              reg_2_45 = reg_2_40.part
              reg_2_45 = reg_2_45.bakedColour
              if not reg_2_45 then
                reg_2_45 = SetParticleFxLoopedColour
                reg_2_46 = reg_2_40.handle
                reg_2_47 = reg_2_42
                reg_2_48 = reg_2_43
                reg_2_49 = reg_2_44
                reg_2_50 = false
                reg_2_45(reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50)
              end
            end
          end
          if reg_2_40 then
            reg_2_45 = currentSpeed_2 - ptfxAsset_2
            if iterKey_2 then
              reg_2_46 = 1.5
              if reg_2_46 then
                goto lbl_567
              end
            end
            reg_2_46 = 1.2
            ::lbl_567::
            reg_2_46 = durationMs_2 * reg_2_46
            reg_2_40.duration = reg_2_46
            reg_2_40.started = reg_2_45
            reg_2_45 = reg_2_41
            reg_2_46 = reg_2_32 + 0.7
            reg_2_40.energy = ptfxName_2
            reg_2_40.phase = reg_2_46
            reg_2_40.peak = reg_2_45
            reg_2_45 = {}
            reg_2_46 = reg_2_42
            reg_2_47 = reg_2_43
            reg_2_48 = reg_2_44
            reg_2_45[1] = reg_2_46
            reg_2_45[2] = reg_2_47
            reg_2_45[3] = reg_2_48
            reg_2_40.colour = reg_2_45
            reg_2_45 = math
            reg_2_45 = reg_2_45.min
            reg_2_46 = durationMs_2 * 0.12
            reg_2_47 = 8.0
            reg_2_45 = reg_2_45(reg_2_46, reg_2_47)
            reg_2_46 = 0.45
            reg_2_40.opacity = 0.85
            reg_2_40.sustain = reg_2_46
            reg_2_40.attack = reg_2_45
            reg_2_45 = tune.burstId
            reg_2_46 = tune.epoch
            if not reg_2_46 then
              reg_2_46 = 0
            end
            reg_2_40.epoch = reg_2_46
            reg_2_40.burstId = reg_2_45
            reg_2_45, reg_2_46 = CalculateParticleEnvelope(reg_2_40, currentSpeed_2)
            reg_2_47 = SetParticleFxLoopedScale
            reg_2_48 = reg_2_40.handle
            reg_2_49 = reg_2_45
            reg_2_47(reg_2_48, reg_2_49)
            reg_2_47 = SetParticleFxLoopedAlpha
            reg_2_48 = reg_2_40.handle
            reg_2_49 = reg_2_46
            reg_2_47(reg_2_48, reg_2_49)
          end
        end
      end
      reg_2_39 = ipairs
      reg_2_40 = iterValue_2.extras
      if not reg_2_40 then
        reg_2_40 = {}
      end
      reg_2_39, reg_2_40, reg_2_41, reg_2_42 = reg_2_39(reg_2_40)
      for reg_2_43, reg_2_44 in reg_2_39, reg_2_40, reg_2_41, reg_2_42 do
        reg_2_45 = reg_1_41
        reg_2_46 = reg_2_44
        reg_2_47 = vehicle
        reg_2_48 = reg_2_31
        reg_2_49 = tune
        reg_2_50 = reg_2_33
        reg_2_51 = currentSpeed_2
        reg_2_52 = ptfxAsset_2
        reg_2_53 = reg_2_36
        reg_2_54 = nil
        if "smoke" == reg_2_44 then
          reg_2_55 = 0.6
          if reg_2_55 then
            goto lbl_637
          end
        end
        reg_2_55 = nil
        ::lbl_637::
        reg_2_45(reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51, reg_2_52, reg_2_53, reg_2_54, reg_2_55)
      end
      if iterKey_2 then
        reg_2_39 = reg_1_41
        reg_2_40 = "sparks"
        reg_2_41 = vehicle
        reg_2_42 = reg_2_31
        reg_2_43 = tune
        reg_2_44 = reg_2_33
        reg_2_45 = currentSpeed_2
        reg_2_46 = ptfxAsset_2
        reg_2_47 = reg_2_36
        reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47)
        reg_2_39 = reg_1_41
        reg_2_40 = "smoke"
        reg_2_41 = vehicle
        reg_2_42 = reg_2_31
        reg_2_43 = tune
        reg_2_44 = reg_2_33
        reg_2_45 = currentSpeed_2
        reg_2_46 = ptfxAsset_2
        reg_2_47 = reg_2_36
        reg_2_48 = nil
        reg_2_49 = 0.55
        reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49)
        if ambientLight_2 then
          reg_2_39 = reg_1_41
          reg_2_40 = "steam"
          reg_2_41 = vehicle
          reg_2_42 = reg_2_31
          reg_2_43 = tune
          reg_2_44 = reg_2_33
          reg_2_45 = currentSpeed_2
          reg_2_46 = ptfxAsset_2
          reg_2_47 = reg_2_36
          reg_2_48 = nil
          reg_2_49 = burstKey_2.rain
          reg_2_49 = 0.4 * reg_2_49
          reg_2_49 = 0.5 + reg_2_49
          reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49)
        end
      else
        reg_2_39 = calcOffset_2.damaged
        if not reg_2_39 then
          reg_2_39 = 0
        end
        reg_2_40 = 0.3
        if reg_2_39 > reg_2_40 then
          reg_2_39 = 0.4
          if ptfxName_2 > reg_2_39 then
            reg_2_39 = reg_1_41
            reg_2_40 = "smoke"
            reg_2_41 = vehicle
            reg_2_42 = reg_2_31
            reg_2_43 = tune
            reg_2_44 = reg_2_33
            reg_2_45 = currentSpeed_2
            reg_2_46 = ptfxAsset_2
            reg_2_47 = reg_2_36
            reg_2_48 = nil
            reg_2_49 = calcOffset_2.damaged
            reg_2_49 = 0.35 * reg_2_49
            reg_2_49 = 0.35 + reg_2_49
            reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49)
          end
        end
      end
      reg_2_39 = tune.soot
      if reg_2_39 then
        reg_2_39 = 0.3
        if ptfxName_2 > reg_2_39 then
          reg_2_39 = reg_1_41
          reg_2_40 = "smoke"
          reg_2_41 = vehicle
          reg_2_42 = reg_2_31
          reg_2_43 = tune
          reg_2_44 = reg_2_33
          reg_2_45 = currentSpeed_2
          reg_2_46 = ptfxAsset_2
          reg_2_47 = reg_2_36
          reg_2_48 = nil
          reg_2_49 = 0.3 * ptfxName_2
          reg_2_49 = 0.55 + reg_2_49
          reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49)
        end
      end
      if checkResult_2 then
        reg_2_39 = CalculateFlamePosition
        reg_2_40 = iterValue_2
        reg_2_41 = boneCoords_2
        reg_2_42 = true
        reg_2_43 = soundRadius_2
        reg_2_44 = ptfxName_2
        reg_2_45 = tune.tint
        reg_2_39, reg_2_40, reg_2_41 = reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45)
        reg_2_42 = reg_1_41
        reg_2_43 = "embers"
        reg_2_44 = vehicle
        reg_2_45 = reg_2_31
        reg_2_46 = tune
        reg_2_47 = reg_2_33
        reg_2_48 = currentSpeed_2
        reg_2_49 = ptfxAsset_2
        reg_2_50 = reg_2_36
        reg_2_51 = {}
        reg_2_52 = reg_2_39
        reg_2_53 = reg_2_40
        reg_2_54 = reg_2_41
        reg_2_51[1] = reg_2_52
        reg_2_51[2] = reg_2_53
        reg_2_51[3] = reg_2_54
        reg_2_42(reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50, reg_2_51)
        reg_2_42 = reg_1_41
        reg_2_43 = "haze"
        reg_2_44 = vehicle
        reg_2_45 = reg_2_31
        reg_2_46 = tune
        reg_2_47 = reg_2_33
        reg_2_48 = currentSpeed_2
        reg_2_49 = ptfxAsset_2
        reg_2_50 = reg_2_36
        reg_2_42(reg_2_43, reg_2_44, reg_2_45, reg_2_46, reg_2_47, reg_2_48, reg_2_49, reg_2_50)
      end
      reg_2_39 = tune.last
      if reg_2_39 and not iterKey_2 then
        reg_2_39 = tune.count
        if not reg_2_39 then
          reg_2_39 = 0
        end
        if reg_2_39 >= 4 then
          reg_2_39 = ParticleConfig.wisp
          if false ~= reg_2_39 then
            reg_2_39 = reg_1_44
            reg_2_40 = currentSpeed_2 - ptfxAsset_2
            reg_2_40 = reg_2_40 + 140
            reg_2_41 = tune
            function reg_2_42(particleId)
              local currentCoords_3, flameActive_3, boneIndex_3, currentSpeed_3, targetScale_3, durationMs_3, ptfxAsset_3, ptfxName_3, energyVal_3, outletList_3, pulseItem_3
              currentCoords_3 = DoesEntityExist
              flameActive_3 = vehicle
              currentCoords_3 = currentCoords_3(flameActive_3)
              if currentCoords_3 then
                currentCoords_3 = GetIsVehicleEngineRunning
                flameActive_3 = vehicle
                currentCoords_3 = currentCoords_3(flameActive_3)
                if currentCoords_3 then
                  currentCoords_3 = reg_1_41
                  flameActive_3 = "smoke"
                  boneIndex_3 = vehicle
                  currentSpeed_3 = reg_2_31
                  targetScale_3 = tune
                  durationMs_3 = reg_2_33
                  ptfxAsset_3 = particleId
                  ptfxName_3 = 0
                  energyVal_3 = reg_2_36
                  energyVal_3 = energyVal_3 * 0.8
                  outletList_3 = nil
                  pulseItem_3 = calcOffset_2.cold
                  if not pulseItem_3 then
                    pulseItem_3 = 0
                  end
                  pulseItem_3 = 0.3 * pulseItem_3
                  pulseItem_3 = 0.25 + pulseItem_3
                  currentCoords_3(flameActive_3, boneIndex_3, currentSpeed_3, targetScale_3, durationMs_3, ptfxAsset_3, ptfxName_3, energyVal_3, outletList_3, pulseItem_3)
                end
              end
            end
            reg_2_39(reg_2_40, reg_2_41, reg_2_42)
          end
        end
      end
      if checkResult_2 or iterKey_2 then
        reg_2_39 = ParticleConfig.flash
        if false ~= reg_2_39 and colorG_2 then
          reg_2_39 = CalculateFlamePosition
          reg_2_40 = iterValue_2
          reg_2_41 = boneCoords_2
          reg_2_42 = false
          reg_2_43 = soundRadius_2
          reg_2_44 = ptfxName_2
          reg_2_45 = tune.tint
          reg_2_39, reg_2_40, reg_2_41 = reg_2_39(reg_2_40, reg_2_41, reg_2_42, reg_2_43, reg_2_44, reg_2_45)
          reg_2_42 = ptfxAssetList
          reg_2_42 = #reg_2_42
          reg_2_43 = reg_2_42 + 1
          reg_2_42 = ptfxAssetList
          reg_2_44 = {}
          reg_2_45 = tune.netId
          reg_2_44.netId = reg_2_45
          reg_2_44.vehicle = vehicle
          reg_2_44.point = reg_2_31
          reg_2_45 = currentSpeed_2 - ptfxAsset_2
          reg_2_44.started = reg_2_45
          if checkResult_2 then
            reg_2_45 = 90
            if reg_2_45 then
              goto lbl_826
            end
          end
          reg_2_45 = 60
          ::lbl_826::
          reg_2_44.duration = reg_2_45
          reg_2_45 = {}
          reg_2_46 = reg_2_39
          reg_2_47 = reg_2_40
          reg_2_48 = reg_2_41
          reg_2_45[1] = reg_2_46
          reg_2_45[2] = reg_2_47
          reg_2_45[3] = reg_2_48
          reg_2_44.colour = reg_2_45
          if checkResult_2 then
            reg_2_45 = 10.0
            if reg_2_45 then
              goto lbl_840
            end
          end
          reg_2_45 = 6.5
          ::lbl_840::
          reg_2_44.range = reg_2_45
          if checkResult_2 then
            reg_2_45 = 9.0
            if reg_2_45 then
              goto lbl_847
            end
          end
          reg_2_45 = 5.0
          ::lbl_847::
          reg_2_44.intensity = reg_2_45
          reg_2_42[reg_2_43] = reg_2_44
        end
      end
      reg_2_39 = ParticleConfig.glow
      if false ~= reg_2_39 then
        reg_2_39 = flameContexts
        reg_2_39 = reg_2_39[reg_2_33]
        if not reg_2_39 then
          reg_2_39 = {}
          reg_2_40 = tune.netId
          reg_2_39.netId = reg_2_40
          reg_2_39.heat = 0.0
        end
        reg_2_40 = vehicle
        reg_2_39.point = reg_2_31
        reg_2_39.vehicle = reg_2_40
        reg_2_40 = math
        reg_2_40 = reg_2_40.min
        reg_2_41 = 1.0
        reg_2_42 = reg_2_39.heat
        if checkResult_2 then
          reg_2_43 = 0.34
          if reg_2_43 then
            goto lbl_879
          end
        end
        if iterKey_2 then
          reg_2_43 = 0.26
          if reg_2_43 then
            goto lbl_879
          end
        end
        reg_2_43 = 0.1
        ::lbl_879::
        reg_2_43 = ptfxName_2 * reg_2_43
        reg_2_42 = reg_2_42 + reg_2_43
        reg_2_40 = reg_2_40(reg_2_41, reg_2_42)
        reg_2_39.heat = reg_2_40
        reg_2_40 = flameContexts
        reg_2_40[reg_2_33] = reg_2_39
      end
      colorG_2 = false
    end
  end
  colorB_2 = colorR_2
  layerEntry_2 = iterValue_2.name
  styleItem_2 = rainLevel_2
  return colorB_2, layerEntry_2, styleItem_2
end
PopsFlames.Emit = EmitFlames
function TickFlames(vehicle)
  local currentCoords_2, flameActive_2, boneIndex_2, currentSpeed_2, targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2, energyVal_2, outletList_2, pulseItem_2, tempVal_2, clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2, colorR_2, colorG_2, colorB_2, layerEntry_2
  currentCoords_2 = IsFiniteNumber
  flameActive_2 = vehicle
  currentCoords_2 = currentCoords_2(flameActive_2)
  if not currentCoords_2 or not vehicle then
    currentCoords_2 = GetGameTimer
    currentCoords_2 = currentCoords_2()
    vehicle = currentCoords_2
  end
  currentCoords_2 = math.max(0, math.min(250, vehicle - nextProbeTime))
  nextProbeTime = vehicle
  flameActive_2 = exhaustBoneList
  flameActive_2 = #flameActive_2
  boneIndex_2 = 1
  currentSpeed_2 = -1
  for targetScale_2 = flameActive_2, boneIndex_2, currentSpeed_2 do
    durationMs_2 = exhaustBoneList
    durationMs_2 = durationMs_2[targetScale_2]
    ptfxAsset_2 = durationMs_2.at
    if vehicle >= ptfxAsset_2 then
      ptfxAsset_2 = table
      ptfxAsset_2 = ptfxAsset_2.remove
      ptfxName_2 = exhaustBoneList
      energyVal_2 = targetScale_2
      ptfxAsset_2(ptfxName_2, energyVal_2)
      ptfxAsset_2 = durationMs_2.run
      ptfxName_2 = vehicle
      ptfxAsset_2(ptfxName_2)
    end
  end
  flameActive_2 = UpdateAmbientWeather(vehicle)
  boneIndex_2 = {}
  currentSpeed_2 = {}
  targetScale_2 = pairs
  durationMs_2 = particlePool
  targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2 = targetScale_2(durationMs_2)
  for energyVal_2, outletList_2 in targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2 do
    pulseItem_2 = outletList_2.vehicle
    tempVal_2 = currentSpeed_2[pulseItem_2]
    if nil == tempVal_2 then
      clampedScale_2 = DoesEntityExist
      boneCoords_2 = pulseItem_2
      clampedScale_2 = clampedScale_2(boneCoords_2)
      tempVal_2 = clampedScale_2 or tempVal_2
      if clampedScale_2 then
        clampedScale_2 = GetIsVehicleEngineRunning
        boneCoords_2 = pulseItem_2
        clampedScale_2 = clampedScale_2(boneCoords_2)
        tempVal_2 = clampedScale_2
      end
      currentSpeed_2[pulseItem_2] = tempVal_2
    end
    clampedScale_2 = outletList_2.started
    clampedScale_2 = vehicle - clampedScale_2
    boneCoords_2 = outletList_2.duration
    if not (clampedScale_2 >= boneCoords_2) and tempVal_2 then
      clampedScale_2 = DoesParticleFxLoopedExist
      boneCoords_2 = outletList_2.handle
      clampedScale_2 = clampedScale_2(boneCoords_2)
      if clampedScale_2 then
        goto lbl_89
      end
    end
    clampedScale_2 = StopParticle
    boneCoords_2 = energyVal_2
    calcOffset_2 = outletList_2.kind
    calcOffset_2 = "jet" ~= calcOffset_2
    clampedScale_2(boneCoords_2, calcOffset_2)
    goto lbl_134
    ::lbl_89::
    clampedScale_2 = outletList_2.kind
    if "extra" ~= clampedScale_2 then
      clampedScale_2, boneCoords_2, calcOffset_2 = CalculateParticleEnvelope(outletList_2, vehicle)
      checkResult_2 = SetParticleFxLoopedScale
      iterKey_2 = outletList_2.handle
      iterValue_2 = clampedScale_2
      checkResult_2(iterKey_2, iterValue_2)
      checkResult_2 = SetParticleFxLoopedAlpha
      iterKey_2 = outletList_2.handle
      iterValue_2 = boneCoords_2
      checkResult_2(iterKey_2, iterValue_2)
      checkResult_2 = ParticleConfig.light
      if false ~= checkResult_2 then
        checkResult_2 = outletList_2.energy
        checkResult_2 = calcOffset_2 * checkResult_2
        iterKey_2 = math
        iterKey_2 = iterKey_2.min
        iterValue_2 = 1.6
        soundRadius_2 = outletList_2.peak
        soundRadius_2 = soundRadius_2 * 0.4
        soundRadius_2 = 0.6 + soundRadius_2
        iterKey_2 = iterKey_2(iterValue_2, soundRadius_2)
        checkResult_2 = checkResult_2 * iterKey_2
        iterKey_2 = outletList_2.outlet
        iterKey_2 = boneIndex_2[iterKey_2]
        if iterKey_2 then
          iterValue_2 = iterKey_2.strength
          if not (checkResult_2 > iterValue_2) then
            goto lbl_134
          end
        end
        iterValue_2 = outletList_2.outlet
        soundRadius_2 = {}
        soundRadius_2.item = outletList_2
        soundRadius_2.strength = checkResult_2
        boneIndex_2[iterValue_2] = soundRadius_2
      end
    end
    ::lbl_134::
  end
  targetScale_2 = pairs
  durationMs_2 = boneIndex_2
  targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2 = targetScale_2(durationMs_2)
  for energyVal_2, outletList_2 in targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2 do
    pulseItem_2 = outletList_2.item
    tempVal_2 = outletList_2.strength
    clampedScale_2 = 0.018
    if tempVal_2 > clampedScale_2 then
      tempVal_2 = GetExhaustBones
      clampedScale_2 = pulseItem_2.vehicle
      boneCoords_2 = pulseItem_2.point
      tempVal_2 = tempVal_2(clampedScale_2, boneCoords_2)
      clampedScale_2 = pulseItem_2.colour
      if not clampedScale_2 then
        clampedScale_2 = {}
        boneCoords_2 = 1.0
        calcOffset_2 = 0.6
        checkResult_2 = 0.25
        clampedScale_2[1] = boneCoords_2
        clampedScale_2[2] = calcOffset_2
        clampedScale_2[3] = checkResult_2
      end
      boneCoords_2 = DrawLightWithRange
      calcOffset_2 = tempVal_2.x
      checkResult_2 = tempVal_2.y
      iterKey_2 = tempVal_2.z
      iterValue_2 = math
      iterValue_2 = iterValue_2.floor
      soundRadius_2 = clampedScale_2[1]
      soundRadius_2 = soundRadius_2 * 255
      iterValue_2 = iterValue_2(soundRadius_2)
      soundRadius_2 = math
      soundRadius_2 = soundRadius_2.floor
      burstKey_2 = clampedScale_2[2]
      burstKey_2 = burstKey_2 * 255
      soundRadius_2 = soundRadius_2(burstKey_2)
      burstKey_2 = math
      burstKey_2 = burstKey_2.floor
      ambientLight_2 = clampedScale_2[3]
      ambientLight_2 = ambientLight_2 * 255
      burstKey_2 = burstKey_2(ambientLight_2)
      ambientLight_2 = ClampNumber
      rainLevel_2 = ParticleConfig.lightRange
      colorR_2 = 0.25
      colorG_2 = 10.0
      colorB_2 = 3.4
      ambientLight_2 = ambientLight_2(rainLevel_2, colorR_2, colorG_2, colorB_2)
      rainLevel_2 = math
      rainLevel_2 = rainLevel_2.min
      colorR_2 = 1.6
      colorG_2 = outletList_2.strength
      rainLevel_2 = rainLevel_2(colorR_2, colorG_2)
      rainLevel_2 = 0.5 * rainLevel_2
      rainLevel_2 = 0.5 + rainLevel_2
      ambientLight_2 = ambientLight_2 * rainLevel_2
      rainLevel_2 = ClampNumber
      colorR_2 = ParticleConfig.lightIntensity
      colorG_2 = 0.0
      colorB_2 = 8.0
      layerEntry_2 = 2.6
      rainLevel_2 = rainLevel_2(colorR_2, colorG_2, colorB_2, layerEntry_2)
      colorR_2 = math
      colorR_2 = colorR_2.min
      colorG_2 = 1.6
      colorB_2 = outletList_2.strength
      colorR_2 = colorR_2(colorG_2, colorB_2)
      rainLevel_2 = rainLevel_2 * colorR_2
      colorR_2 = flameActive_2.light
      rainLevel_2 = rainLevel_2 * colorR_2
      boneCoords_2(calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2)
    end
  end
  targetScale_2 = ptfxAssetList
  targetScale_2 = #targetScale_2
  durationMs_2 = 1
  ptfxAsset_2 = -1
  for ptfxName_2 = targetScale_2, durationMs_2, ptfxAsset_2 do
    energyVal_2 = ptfxAssetList
    energyVal_2 = energyVal_2[ptfxName_2]
    outletList_2 = energyVal_2.started
    outletList_2 = vehicle - outletList_2
    pulseItem_2 = energyVal_2.duration
    outletList_2 = outletList_2 / pulseItem_2
    if not (outletList_2 >= 1) then
      pulseItem_2 = DoesEntityExist
      tempVal_2 = energyVal_2.vehicle
      pulseItem_2 = pulseItem_2(tempVal_2)
      if pulseItem_2 then
        goto lbl_244
      end
    end
    pulseItem_2 = table
    pulseItem_2 = pulseItem_2.remove
    tempVal_2 = ptfxAssetList
    clampedScale_2 = ptfxName_2
    pulseItem_2(tempVal_2, clampedScale_2)
    goto lbl_292
    ::lbl_244::
    pulseItem_2 = GetExhaustBones
    tempVal_2 = energyVal_2.vehicle
    clampedScale_2 = energyVal_2.point
    pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2)
    tempVal_2 = energyVal_2.colour
    clampedScale_2 = 1
    clampedScale_2 = clampedScale_2 - outletList_2
    clampedScale_2 = clampedScale_2 ^ 2
    boneCoords_2 = DrawLightWithRange
    calcOffset_2 = pulseItem_2.x
    checkResult_2 = pulseItem_2.y
    iterKey_2 = pulseItem_2.z
    iterKey_2 = iterKey_2 + 0.15
    iterValue_2 = math
    iterValue_2 = iterValue_2.floor
    soundRadius_2 = tempVal_2[1]
    soundRadius_2 = soundRadius_2 * 255
    iterValue_2 = iterValue_2(soundRadius_2)
    soundRadius_2 = math
    soundRadius_2 = soundRadius_2.floor
    burstKey_2 = tempVal_2[2]
    burstKey_2 = burstKey_2 * 255
    soundRadius_2 = soundRadius_2(burstKey_2)
    burstKey_2 = math
    burstKey_2 = burstKey_2.floor
    ambientLight_2 = tempVal_2[3]
    ambientLight_2 = ambientLight_2 * 255
    burstKey_2 = burstKey_2(ambientLight_2)
    ambientLight_2 = energyVal_2.range
    rainLevel_2 = 0.4 * clampedScale_2
    rainLevel_2 = 0.6 + rainLevel_2
    ambientLight_2 = ambientLight_2 * rainLevel_2
    rainLevel_2 = energyVal_2.intensity
    rainLevel_2 = rainLevel_2 * clampedScale_2
    colorR_2 = flameActive_2.light
    rainLevel_2 = rainLevel_2 * colorR_2
    boneCoords_2(calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2, ambientLight_2, rainLevel_2)
    ::lbl_292::
  end
  targetScale_2 = pairs
  durationMs_2 = flameContexts
  targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2 = targetScale_2(durationMs_2)
  for energyVal_2, outletList_2 in targetScale_2, durationMs_2, ptfxAsset_2, ptfxName_2 do
    pulseItem_2 = outletList_2.heat
    tempVal_2 = math
    tempVal_2 = tempVal_2.exp
    clampedScale_2 = -currentCoords_2
    boneCoords_2 = flameActive_2.rain
    boneCoords_2 = 0.5 * boneCoords_2
    calcOffset_2 = 1
    boneCoords_2 = calcOffset_2 - boneCoords_2
    boneCoords_2 = 2400 * boneCoords_2
    clampedScale_2 = clampedScale_2 / boneCoords_2
    tempVal_2 = tempVal_2(clampedScale_2)
    pulseItem_2 = pulseItem_2 * tempVal_2
    outletList_2.heat = pulseItem_2
    pulseItem_2 = outletList_2.heat
    tempVal_2 = 0.03
    if not (pulseItem_2 < tempVal_2) then
      pulseItem_2 = DoesEntityExist
      tempVal_2 = outletList_2.vehicle
      pulseItem_2 = pulseItem_2(tempVal_2)
      if pulseItem_2 then
        goto lbl_327
      end
    end
    pulseItem_2 = flameContexts
    pulseItem_2[energyVal_2] = nil
    goto lbl_370
    ::lbl_327::
    pulseItem_2 = GetExhaustBones
    tempVal_2 = outletList_2.vehicle
    clampedScale_2 = outletList_2.point
    pulseItem_2 = pulseItem_2(tempVal_2, clampedScale_2)
    tempVal_2 = DrawLightWithRange
    clampedScale_2 = pulseItem_2.x
    boneCoords_2 = pulseItem_2.y
    calcOffset_2 = pulseItem_2.z
    checkResult_2 = 255
    iterKey_2 = math
    iterKey_2 = iterKey_2.floor
    iterValue_2 = outletList_2.heat
    iterValue_2 = 120 * iterValue_2
    iterValue_2 = 50 + iterValue_2
    iterKey_2 = iterKey_2(iterValue_2)
    iterValue_2 = math
    iterValue_2 = iterValue_2.floor
    soundRadius_2 = outletList_2.heat
    soundRadius_2 = 50 * soundRadius_2
    soundRadius_2 = 8 + soundRadius_2
    iterValue_2 = iterValue_2(soundRadius_2)
    soundRadius_2 = outletList_2.heat
    soundRadius_2 = 0.55 * soundRadius_2
    soundRadius_2 = 0.4 + soundRadius_2
    burstKey_2 = ClampNumber
    ambientLight_2 = ParticleConfig.glowIntensity
    rainLevel_2 = 0.0
    colorR_2 = 6.0
    colorG_2 = 1.3
    burstKey_2 = burstKey_2(ambientLight_2, rainLevel_2, colorR_2, colorG_2)
    ambientLight_2 = outletList_2.heat
    burstKey_2 = burstKey_2 * ambientLight_2
    ambientLight_2 = flameActive_2.light
    burstKey_2 = burstKey_2 * ambientLight_2
    tempVal_2(clampedScale_2, boneCoords_2, calcOffset_2, checkResult_2, iterKey_2, iterValue_2, soundRadius_2, burstKey_2)
    ::lbl_370::
  end
end
PopsFlames.Tick = TickFlames
--fivevault-CVOnXETop45 : https://discord.gg/fivevault
--fivevault_rWOnWXTopx- : https://discord.gg/fivevault
--fivevaultsNbOnPnTopXI : https://discord.gg/fivevault
--fivevaultHeOni0Top6h : https://discord.gg/fivevault
--fivevault_y2On!lTopjD : https://discord.gg/fivevault
