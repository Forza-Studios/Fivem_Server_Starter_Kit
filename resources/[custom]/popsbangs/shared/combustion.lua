
PopsCombustion = {}

local defaultLevels = {
    [1] = { flameScale = 0.48, heavyChance = 0.12, limiter = false },
    [2] = { flameScale = 0.86, heavyChance = 0.35, limiter = true },
    [3] = { flameScale = 1.38, heavyChance = 0.58, limiter = true },
    [4] = { flameScale = 1.5, heavyChance = 0.85, limiter = true }
}

local energyMultipliers = { 0.7, 0.86, 1.05, 1.1 }
local boomChances = { 0.0, 0.22, 0.62, 0.85 }
local bangBiases = { 1.0, 1.0, 1.0, 1.8 }
local heavyPhrases = {
    single_bang = true,
    double_bang = true,
    triple_bang = true,
    pop_bang = true,
    bang_tail = true,
    bang_crackle = true,
    salvo = true
}
function IsFiniteNumber(argParam)
  local tempVal_2, targetVal_2
  tempVal_2 = type
  targetVal_2 = argParam
  tempVal_2 = tempVal_2(targetVal_2)
  tempVal_2 = "number" == tempVal_2 and argParam == argParam
  return tempVal_2
end
function ClampNumber(val, minVal, maxVal, defaultVal)
  if not IsFiniteNumber(val) then
    val = defaultVal or minVal
  end
  return math.max(minVal, math.min(maxVal, val))
end
function RoundNumber(argParam)
  local tempVal_2, targetVal_2
  tempVal_2 = math
  tempVal_2 = tempVal_2.floor
  targetVal_2 = argParam + 0.5
  return tempVal_2(targetVal_2)
end
function CreatePseudoRandom(seed)
  local currentSeed = math.floor(math.abs(ClampNumber(seed, -2147483646, 2147483646, 1))) % 2147483646 + 1.0
  return function()
    currentSeed = (currentSeed * 48271) % 2147483647
    return (currentSeed - 1) / 2147483646
  end
end
sampleOffsets = {}
sampleOffsets.snap = 137
sampleOffsets.crackle = 487
sampleOffsets.bang = 1093
sampleOffsets.burble = 2381
sampleOffsets.boom = 4817
function GetSampleCount(argParam)
  local tempVal_2, targetVal_2, calcVal_2, minVal_2, maxVal_2, stepVal_2, fuelVal_2
  tempVal_2 = Config
  if tempVal_2 then
    tempVal_2 = Config
    tempVal_2 = tempVal_2.Audio
    if tempVal_2 then
      tempVal_2 = Config
      tempVal_2 = tempVal_2.Audio
      tempVal_2 = tempVal_2.samples
      if tempVal_2 then
        tempVal_2 = Config
        tempVal_2 = tempVal_2.Audio
        tempVal_2 = tempVal_2.samples
        tempVal_2 = tempVal_2[argParam]
      end
    end
  end
  targetVal_2 = type
  calcVal_2 = tempVal_2
  targetVal_2 = targetVal_2(calcVal_2)
  if "table" == targetVal_2 then
    targetVal_2 = #tempVal_2
    if targetVal_2 then
      goto lbl_26
    end
  end
  targetVal_2 = 6
  ::lbl_26::
  return math.max(2, math.min(32, targetVal_2))
end
function CreateShuffledSampleList(argParam, tuneLevel, eventType)
  local calcVal_2, minVal_2, maxVal_2, stepVal_2, fuelVal_2, richVal_2, isBrutal_2, loadVal_2, rpmVal_2
  calcVal_2 = CreatePseudoRandom
  minVal_2 = sampleOffsets
  minVal_2 = minVal_2[argParam]
  maxVal_2 = tuneLevel * 104729
  minVal_2 = minVal_2 + maxVal_2
  minVal_2 = minVal_2 % 2147483646
  calcVal_2 = calcVal_2(minVal_2)
  minVal_2 = {}
  maxVal_2 = 1
  stepVal_2 = eventType
  fuelVal_2 = 1
  for richVal_2 = maxVal_2, stepVal_2, fuelVal_2 do
    minVal_2[richVal_2] = richVal_2
  end
  maxVal_2 = eventType
  stepVal_2 = 2
  fuelVal_2 = -1
  for richVal_2 = maxVal_2, stepVal_2, fuelVal_2 do
    isBrutal_2 = math
    isBrutal_2 = isBrutal_2.floor
    loadVal_2 = calcVal_2
    loadVal_2 = loadVal_2()
    loadVal_2 = loadVal_2 * richVal_2
    isBrutal_2 = isBrutal_2(loadVal_2)
    isBrutal_2 = isBrutal_2 + 1
    loadVal_2 = minVal_2[isBrutal_2]
    rpmVal_2 = minVal_2[richVal_2]
    minVal_2[isBrutal_2] = rpmVal_2
    minVal_2[richVal_2] = loadVal_2
  end
  return minVal_2
end
function PickSampleStep(argParam, tuneLevel)
  local targetVal_2, calcVal_2, minVal_2, maxVal_2, stepVal_2, fuelVal_2, richVal_2, isBrutal_2, loadVal_2
  targetVal_2 = GetSampleCount
  calcVal_2 = argParam
  targetVal_2 = targetVal_2(calcVal_2)
  calcVal_2 = math
  calcVal_2 = calcVal_2.floor
  minVal_2 = tuneLevel / targetVal_2
  calcVal_2 = calcVal_2(minVal_2)
  minVal_2 = tuneLevel % targetVal_2
  minVal_2 = minVal_2 + 1
  maxVal_2 = CreateShuffledSampleList
  stepVal_2 = argParam
  fuelVal_2 = calcVal_2
  richVal_2 = targetVal_2
  maxVal_2 = maxVal_2(stepVal_2, fuelVal_2, richVal_2)
  if calcVal_2 > 0 then
    stepVal_2 = maxVal_2[1]
    fuelVal_2 = CreateShuffledSampleList
    richVal_2 = argParam
    isBrutal_2 = calcVal_2 - 1
    loadVal_2 = targetVal_2
    fuelVal_2 = fuelVal_2(richVal_2, isBrutal_2, loadVal_2)
    fuelVal_2 = fuelVal_2[targetVal_2]
    if stepVal_2 == fuelVal_2 then
      stepVal_2 = maxVal_2[2]
      fuelVal_2 = maxVal_2[1]
      maxVal_2[2] = fuelVal_2
      maxVal_2[1] = stepVal_2
    end
  end
  stepVal_2 = maxVal_2[minVal_2]
  return stepVal_2
end
function ResolveTuneLevel(argParam)
  local tempVal_2, targetVal_2, calcVal_2, minVal_2, maxVal_2, stepVal_2
  tempVal_2 = type
  targetVal_2 = argParam
  tempVal_2 = tempVal_2(targetVal_2)
  if "table" == tempVal_2 then
    tempVal_2 = math.floor(ClampNumber(argParam.level, 1, 4, 2))
    targetVal_2 = Config
    if targetVal_2 then
      targetVal_2 = Config
      targetVal_2 = targetVal_2.Levels
      if targetVal_2 then
        targetVal_2 = 1
        calcVal_2 = 4
        minVal_2 = 1
        for maxVal_2 = targetVal_2, calcVal_2, minVal_2 do
          stepVal_2 = Config
          stepVal_2 = stepVal_2.Levels
          stepVal_2 = stepVal_2[maxVal_2]
          if stepVal_2 == argParam then
            tempVal_2 = maxVal_2
            break
          end
        end
      end
    end
    targetVal_2 = tempVal_2
    calcVal_2 = argParam
    return targetVal_2, calcVal_2
  end
  tempVal_2 = IsFiniteNumber
  targetVal_2 = argParam
  tempVal_2 = tempVal_2(targetVal_2)
  if tempVal_2 then
    tempVal_2 = argParam % 1
    if 0 == tempVal_2 then
      tempVal_2 = defaultLevels
      tempVal_2 = tempVal_2[argParam]
      if tempVal_2 then
        goto lbl_52
      end
    end
  end
  tempVal_2 = nil
  do return tempVal_2 end
  ::lbl_52::
  tempVal_2 = argParam
  targetVal_2 = Config
  if targetVal_2 then
    targetVal_2 = Config
    targetVal_2 = targetVal_2.Levels
    if targetVal_2 then
      targetVal_2 = Config
      targetVal_2 = targetVal_2.Levels
      targetVal_2 = targetVal_2[argParam]
      if targetVal_2 then
        goto lbl_67
      end
    end
  end
  targetVal_2 = defaultLevels
  targetVal_2 = targetVal_2[argParam]
  ::lbl_67::
  return tempVal_2, targetVal_2
end
function GetCombustionSituation(argParam, tuneLevel)
  local targetVal_2, calcVal_2, minVal_2, maxVal_2, stepVal_2, fuelVal_2, richVal_2, isBrutal_2, loadVal_2, rpmVal_2, tempThreshold_2, checkProb_2, subItem_2, entryVal_2
  targetVal_2 = ClampNumber
  minVal_2 = ClampNumber(tuneLevel.rpm, 0, 1)
  maxVal_2 = ClampNumber(tuneLevel.previousRpm, 0, 1)
  stepVal_2 = ClampNumber(tuneLevel.peakRpm, 0, 1)
  calcVal_2 = math.max(minVal_2, maxVal_2, stepVal_2)
  targetVal_2 = ClampNumber(calcVal_2, 0, 1)
  calcVal_2 = ClampNumber
  minVal_2 = tuneLevel.load
  maxVal_2 = 0
  stepVal_2 = 1
  fuelVal_2 = 0.5
  calcVal_2 = calcVal_2(minVal_2, maxVal_2, stepVal_2, fuelVal_2)
  minVal_2 = ClampNumber
  maxVal_2 = tuneLevel.temperature
  stepVal_2 = 0
  fuelVal_2 = 1
  richVal_2 = 0.5
  minVal_2 = minVal_2(maxVal_2, stepVal_2, fuelVal_2, richVal_2)
  maxVal_2 = ClampNumber
  stepVal_2 = tuneLevel.soak
  fuelVal_2 = 0
  richVal_2 = 1
  isBrutal_2 = minVal_2
  maxVal_2 = maxVal_2(stepVal_2, fuelVal_2, richVal_2, isBrutal_2)
  stepVal_2 = ClampNumber
  fuelVal_2 = tuneLevel.speed
  richVal_2 = 0
  isBrutal_2 = 160
  loadVal_2 = 10
  stepVal_2 = stepVal_2(fuelVal_2, richVal_2, isBrutal_2, loadVal_2)
  fuelVal_2 = ClampNumber
  richVal_2 = tuneLevel.health
  isBrutal_2 = 0
  loadVal_2 = 1
  rpmVal_2 = 1
  fuelVal_2 = fuelVal_2(richVal_2, isBrutal_2, loadVal_2, rpmVal_2)
  richVal_2 = ClampNumber
  isBrutal_2 = targetVal_2 * 0.36
  isBrutal_2 = 0.12 + isBrutal_2
  loadVal_2 = calcVal_2 * 0.34
  isBrutal_2 = isBrutal_2 + loadVal_2
  loadVal_2 = minVal_2 * 0.18
  isBrutal_2 = isBrutal_2 + loadVal_2
  loadVal_2 = 0.18
  rpmVal_2 = 1
  richVal_2 = richVal_2(isBrutal_2, loadVal_2, rpmVal_2)
  isBrutal_2 = {}
  isBrutal_2.rpm = targetVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = tuneLevel.rpm
  tempThreshold_2 = 0
  checkProb_2 = 1
  subItem_2 = targetVal_2
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2, subItem_2)
  isBrutal_2.rpmNow = loadVal_2
  isBrutal_2.load = calcVal_2
  isBrutal_2.temperature = minVal_2
  isBrutal_2.soak = maxVal_2
  isBrutal_2.speed = stepVal_2
  isBrutal_2.gear = math.floor(ClampNumber(tuneLevel.gear, 0, 16, 2))
  isBrutal_2.health = fuelVal_2
  isBrutal_2.fuel = richVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = richVal_2 - 0.48
  rpmVal_2 = rpmVal_2 * 2.1
  tempThreshold_2 = 0
  checkProb_2 = 1
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2)
  isBrutal_2.rich = loadVal_2
  if "overrun" == argParam then
    loadVal_2 = math.floor(ClampNumber(tuneLevel.chain, 0, 8, 0))
  else
    loadVal_2 = 0
  end
  isBrutal_2.chain = loadVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = 0.3
  rpmVal_2 = rpmVal_2 - maxVal_2
  rpmVal_2 = rpmVal_2 / 0.3
  tempThreshold_2 = 0
  checkProb_2 = 1
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2)
  isBrutal_2.cold = loadVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = maxVal_2 - 0.55
  rpmVal_2 = rpmVal_2 / 0.45
  tempThreshold_2 = 0
  checkProb_2 = 1
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2)
  isBrutal_2.hot = loadVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = stepVal_2 - 15
  rpmVal_2 = rpmVal_2 / 25
  tempThreshold_2 = 0
  checkProb_2 = 1
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2)
  isBrutal_2.fast = loadVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = 0.55
  rpmVal_2 = rpmVal_2 - fuelVal_2
  rpmVal_2 = rpmVal_2 / 0.35
  tempThreshold_2 = 0
  checkProb_2 = 1
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2)
  isBrutal_2.damaged = loadVal_2
  loadVal_2 = 2.5
  loadVal_2 = stepVal_2 < loadVal_2
  isBrutal_2.standing = loadVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = targetVal_2 - 0.72
  rpmVal_2 = rpmVal_2 / 0.22
  tempThreshold_2 = 0
  checkProb_2 = 1
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2)
  isBrutal_2.revs = loadVal_2
  loadVal_2 = ClampNumber
  rpmVal_2 = calcVal_2 - 0.4
  rpmVal_2 = rpmVal_2 / 0.35
  tempThreshold_2 = 0
  checkProb_2 = 1
  loadVal_2 = loadVal_2(rpmVal_2, tempThreshold_2, checkProb_2)
  isBrutal_2.pull = loadVal_2
  return isBrutal_2
end
PopsCombustion.Situation = GetCombustionSituation
function GetCombustionRealism(argParam, tuneLevel)
  local targetVal_2, calcVal_2
  if argParam >= 4 then
    targetVal_2 = 1
    return targetVal_2
  end
  targetVal_2 = tuneLevel.revs
  targetVal_2 = targetVal_2 ^ 1.4
  calcVal_2 = tuneLevel.pull
  calcVal_2 = 0.65 * calcVal_2
  calcVal_2 = 0.35 + calcVal_2
  targetVal_2 = targetVal_2 * calcVal_2
  return targetVal_2
end
PopsCombustion.Realism = GetCombustionRealism
function PickCombustionPhrase(argParam, tuneLevel, eventType, situation, flameActive, seed, bangBias, heavyChance)
  local richVal_2, isBrutal_2, loadVal_2, rpmVal_2, tempThreshold_2, checkProb_2, subItem_2, entryVal_2, curPhrase_2, pulseList_2, curDelay_2, flameColor_2, outletIdx_2, emitterVal_2, soundGain_2, pitchVal_2, pulseIdx_2, isHeavy_2, pulseKind_2, pulseEnergy_2, durationMs_2, flameSize_2, var_2_30
  richVal_2 = situation.fuel
  isBrutal_2 = situation.rich
  loadVal_2 = tuneLevel >= 4
  rpmVal_2 = situation.load
  if loadVal_2 then
    tempThreshold_2 = 0.22
    if tempThreshold_2 then
      goto lbl_14
    end
  end
  tempThreshold_2 = 0.33
  ::lbl_14::
  if rpmVal_2 > tempThreshold_2 then
    rpmVal_2 = situation.rpm
    if loadVal_2 then
      tempThreshold_2 = 0.55
      if tempThreshold_2 then
        goto lbl_23
      end
    end
    tempThreshold_2 = 0.63
    ::lbl_23::
    if rpmVal_2 > tempThreshold_2 then
      rpmVal_2 = situation.temperature
      if loadVal_2 then
        tempThreshold_2 = 0.35
        if tempThreshold_2 then
          goto lbl_32
        end
      end
      tempThreshold_2 = 0.43
      ::lbl_32::
      if rpmVal_2 > tempThreshold_2 then
        rpmVal_2 = flameActive * isBrutal_2
        rpmVal_2 = rpmVal_2 * 5.0
        tempThreshold_2 = heavyChance or tempThreshold_2
        if not heavyChance then
          tempThreshold_2 = 1
        end
        rpmVal_2 = rpmVal_2 * tempThreshold_2
        if rpmVal_2 then
          goto lbl_46
        end
      end
    end
  end
  rpmVal_2 = 0
  ::lbl_46::
  tempThreshold_2 = nil
  if "upshift" == eventType then
    checkProb_2 = {}
    subItem_2 = {}
    entryVal_2 = "single_pop"
    curPhrase_2 = 3.2
    subItem_2[1] = entryVal_2
    subItem_2[2] = curPhrase_2
    entryVal_2 = {}
    curPhrase_2 = "single_bang"
    pulseList_2 = rpmVal_2 * 0.7
    entryVal_2[1] = curPhrase_2
    entryVal_2[2] = pulseList_2
    curPhrase_2 = {}
    pulseList_2 = "double_pop"
    if tuneLevel > 1 then
      curDelay_2 = 1.2 + richVal_2
      if curDelay_2 then
        goto lbl_72
      end
    end
    curDelay_2 = 0
    ::lbl_72::
    curPhrase_2[1] = pulseList_2
    curPhrase_2[2] = curDelay_2
    pulseList_2 = {}
    curDelay_2 = "double_bang"
    if tuneLevel >= 3 then
      flameColor_2 = rpmVal_2 * 0.3
      if flameColor_2 then
        goto lbl_83
      end
    end
    flameColor_2 = 0
    ::lbl_83::
    pulseList_2[1] = curDelay_2
    pulseList_2[2] = flameColor_2
    curDelay_2 = {}
    flameColor_2 = "pop_bang"
    if tuneLevel > 1 then
      outletIdx_2 = rpmVal_2 * 0.25
      if outletIdx_2 then
        goto lbl_94
      end
    end
    outletIdx_2 = 0
    ::lbl_94::
    curDelay_2[1] = flameColor_2
    curDelay_2[2] = outletIdx_2
    checkProb_2[1] = subItem_2
    checkProb_2[2] = entryVal_2
    checkProb_2[3] = curPhrase_2
    checkProb_2[4] = pulseList_2
    checkProb_2[5] = curDelay_2
    tempThreshold_2 = checkProb_2
  elseif "limiter" == eventType then
    checkProb_2 = {}
    subItem_2 = {}
    entryVal_2 = "single_pop"
    curPhrase_2 = 1.6
    subItem_2[1] = entryVal_2
    subItem_2[2] = curPhrase_2
    entryVal_2 = {}
    curPhrase_2 = "double_pop"
    pulseList_2 = 1.6
    entryVal_2[1] = curPhrase_2
    entryVal_2[2] = pulseList_2
    curPhrase_2 = {}
    pulseList_2 = "stutter"
    if tuneLevel >= 3 then
      curDelay_2 = 1.2
      if curDelay_2 then
        goto lbl_121
      end
    end
    curDelay_2 = 0
    ::lbl_121::
    curPhrase_2[1] = pulseList_2
    curPhrase_2[2] = curDelay_2
    pulseList_2 = {}
    curDelay_2 = "single_bang"
    if loadVal_2 then
      flameColor_2 = rpmVal_2 * 0.1
      if flameColor_2 then
        goto lbl_132
      end
    end
    flameColor_2 = 0
    ::lbl_132::
    pulseList_2[1] = curDelay_2
    pulseList_2[2] = flameColor_2
    curDelay_2 = {}
    flameColor_2 = "pop_bang"
    if loadVal_2 then
      outletIdx_2 = rpmVal_2 * 0.25
      if outletIdx_2 then
        goto lbl_143
      end
    end
    outletIdx_2 = 0
    ::lbl_143::
    curDelay_2[1] = flameColor_2
    curDelay_2[2] = outletIdx_2
    flameColor_2 = {}
    outletIdx_2 = "bang_tail"
    if loadVal_2 then
      emitterVal_2 = rpmVal_2 * 0.2
      if emitterVal_2 then
        goto lbl_154
      end
    end
    emitterVal_2 = 0
    ::lbl_154::
    flameColor_2[1] = outletIdx_2
    flameColor_2[2] = emitterVal_2
    checkProb_2[1] = subItem_2
    checkProb_2[2] = entryVal_2
    checkProb_2[3] = curPhrase_2
    checkProb_2[4] = pulseList_2
    checkProb_2[5] = curDelay_2
    checkProb_2[6] = flameColor_2
    tempThreshold_2 = checkProb_2
  elseif "antilag" == eventType then
    checkProb_2 = {}
    subItem_2 = {}
    entryVal_2 = "stutter"
    curPhrase_2 = 2.8
    subItem_2[1] = entryVal_2
    subItem_2[2] = curPhrase_2
    entryVal_2 = {}
    curPhrase_2 = "rolling"
    pulseList_2 = 1.4 + isBrutal_2
    entryVal_2[1] = curPhrase_2
    entryVal_2[2] = pulseList_2
    curPhrase_2 = {}
    pulseList_2 = "bang_tail"
    curDelay_2 = rpmVal_2 * 0.55
    curPhrase_2[1] = pulseList_2
    curPhrase_2[2] = curDelay_2
    pulseList_2 = {}
    curDelay_2 = "sparse"
    flameColor_2 = 0.6
    pulseList_2[1] = curDelay_2
    pulseList_2[2] = flameColor_2
    checkProb_2[1] = subItem_2
    checkProb_2[2] = entryVal_2
    checkProb_2[3] = curPhrase_2
    checkProb_2[4] = pulseList_2
    tempThreshold_2 = checkProb_2
  elseif "launch" == eventType then
    checkProb_2 = {}
    subItem_2 = {}
    entryVal_2 = "single_bang"
    curPhrase_2 = 2.0
    subItem_2[1] = entryVal_2
    subItem_2[2] = curPhrase_2
    entryVal_2 = {}
    curPhrase_2 = "double_bang"
    if tuneLevel > 1 then
      pulseList_2 = 1.2
      if pulseList_2 then
        goto lbl_205
      end
    end
    pulseList_2 = 0
    ::lbl_205::
    entryVal_2[1] = curPhrase_2
    entryVal_2[2] = pulseList_2
    curPhrase_2 = {}
    pulseList_2 = "pop_bang"
    curDelay_2 = 0.8
    curPhrase_2[1] = pulseList_2
    curPhrase_2[2] = curDelay_2
    pulseList_2 = {}
    curDelay_2 = "bang_tail"
    flameColor_2 = 0.8
    pulseList_2[1] = curDelay_2
    pulseList_2[2] = flameColor_2
    checkProb_2[1] = subItem_2
    checkProb_2[2] = entryVal_2
    checkProb_2[3] = curPhrase_2
    checkProb_2[4] = pulseList_2
    tempThreshold_2 = checkProb_2
  else
    checkProb_2 = situation.chain
    if checkProb_2 > 0 then
      checkProb_2 = math
      checkProb_2 = checkProb_2.max
      subItem_2 = 0.25
      entryVal_2 = situation.chain
      entryVal_2 = entryVal_2 * 0.14
      curPhrase_2 = 1
      entryVal_2 = curPhrase_2 - entryVal_2
      checkProb_2 = checkProb_2(subItem_2, entryVal_2)
      subItem_2 = {}
      entryVal_2 = {}
      curPhrase_2 = "crackle_burst"
      pulseList_2 = 1.6 * checkProb_2
      curDelay_2 = situation.hot
      curDelay_2 = curDelay_2 * 0.8
      pulseList_2 = pulseList_2 + curDelay_2
      entryVal_2[1] = curPhrase_2
      entryVal_2[2] = pulseList_2
      curPhrase_2 = {}
      pulseList_2 = "stutter"
      curDelay_2 = 1.2 * checkProb_2
      curPhrase_2[1] = pulseList_2
      curPhrase_2[2] = curDelay_2
      pulseList_2 = {}
      curDelay_2 = "sparse"
      flameColor_2 = situation.chain
      flameColor_2 = flameColor_2 * 0.25
      flameColor_2 = 0.8 + flameColor_2
      pulseList_2[1] = curDelay_2
      pulseList_2[2] = flameColor_2
      curDelay_2 = {}
      flameColor_2 = "lazy"
      outletIdx_2 = situation.chain
      outletIdx_2 = outletIdx_2 * 0.3
      outletIdx_2 = 0.7 + outletIdx_2
      curDelay_2[1] = flameColor_2
      curDelay_2[2] = outletIdx_2
      flameColor_2 = {}
      outletIdx_2 = "double_pop"
      emitterVal_2 = 1.0
      flameColor_2[1] = outletIdx_2
      flameColor_2[2] = emitterVal_2
      outletIdx_2 = {}
      emitterVal_2 = "single_pop"
      soundGain_2 = situation.chain
      soundGain_2 = soundGain_2 * 0.35
      soundGain_2 = 0.6 + soundGain_2
      outletIdx_2[1] = emitterVal_2
      outletIdx_2[2] = soundGain_2
      emitterVal_2 = {}
      soundGain_2 = "volley"
      if tuneLevel > 1 then
        pitchVal_2 = situation.chain
        if pitchVal_2 <= 2 then
          pitchVal_2 = situation.hot
          pitchVal_2 = 0.5 + pitchVal_2
          pitchVal_2 = pitchVal_2 * checkProb_2
          if pitchVal_2 then
            goto lbl_299
          end
        end
      end
      pitchVal_2 = 0
      ::lbl_299::
      emitterVal_2[1] = soundGain_2
      emitterVal_2[2] = pitchVal_2
      soundGain_2 = {}
      pitchVal_2 = "rolling"
      if tuneLevel > 1 then
        pulseIdx_2 = situation.chain
        if pulseIdx_2 <= 2 then
          pulseIdx_2 = 0.9 * checkProb_2
          if pulseIdx_2 then
            goto lbl_313
          end
        end
      end
      pulseIdx_2 = 0
      ::lbl_313::
      soundGain_2[1] = pitchVal_2
      soundGain_2[2] = pulseIdx_2
      pitchVal_2 = {}
      pulseIdx_2 = "pop_bang"
      if tuneLevel >= 3 then
        isHeavy_2 = situation.chain
        if 1 == isHeavy_2 then
          isHeavy_2 = rpmVal_2 * 0.2
          if isHeavy_2 then
            goto lbl_327
          end
        end
      end
      isHeavy_2 = 0
      ::lbl_327::
      pitchVal_2[1] = pulseIdx_2
      pitchVal_2[2] = isHeavy_2
      pulseIdx_2 = {}
      isHeavy_2 = "single_bang"
      if loadVal_2 then
        pulseKind_2 = situation.chain
        if pulseKind_2 <= 3 then
          pulseKind_2 = situation.rpmNow
          pulseEnergy_2 = 0.5
          if pulseKind_2 > pulseEnergy_2 then
            pulseKind_2 = flameActive * 0.4
            pulseKind_2 = pulseKind_2 * checkProb_2
            if pulseKind_2 then
              goto lbl_347
            end
          end
        end
      end
      pulseKind_2 = 0
      ::lbl_347::
      pulseIdx_2[1] = isHeavy_2
      pulseIdx_2[2] = pulseKind_2
      isHeavy_2 = {}
      pulseKind_2 = "bang_tail"
      if loadVal_2 then
        pulseEnergy_2 = situation.chain
        if pulseEnergy_2 <= 3 then
          pulseEnergy_2 = situation.rpmNow
          durationMs_2 = 0.5
          if pulseEnergy_2 > durationMs_2 then
            pulseEnergy_2 = flameActive * 0.8
            pulseEnergy_2 = pulseEnergy_2 * checkProb_2
            if pulseEnergy_2 then
              goto lbl_367
            end
          end
        end
      end
      pulseEnergy_2 = 0
      ::lbl_367::
      isHeavy_2[1] = pulseKind_2
      isHeavy_2[2] = pulseEnergy_2
      pulseKind_2 = {}
      pulseEnergy_2 = "bang_crackle"
      if loadVal_2 then
        durationMs_2 = situation.chain
        if durationMs_2 <= 3 then
          durationMs_2 = situation.rpmNow
          flameSize_2 = 0.5
          if durationMs_2 > flameSize_2 then
            durationMs_2 = flameActive * 1.0
            durationMs_2 = durationMs_2 * checkProb_2
            if durationMs_2 then
              goto lbl_387
            end
          end
        end
      end
      durationMs_2 = 0
      ::lbl_387::
      pulseKind_2[1] = pulseEnergy_2
      pulseKind_2[2] = durationMs_2
      subItem_2[1] = entryVal_2
      subItem_2[2] = curPhrase_2
      subItem_2[3] = pulseList_2
      subItem_2[4] = curDelay_2
      subItem_2[5] = flameColor_2
      subItem_2[6] = outletIdx_2
      subItem_2[7] = emitterVal_2
      subItem_2[8] = soundGain_2
      subItem_2[9] = pitchVal_2
      subItem_2[10] = pulseIdx_2
      subItem_2[11] = isHeavy_2
      subItem_2[12] = pulseKind_2
      tempThreshold_2 = subItem_2
    else
      checkProb_2 = situation.standing
      if checkProb_2 then
        checkProb_2 = {}
        subItem_2 = {}
        entryVal_2 = "single_bang"
        curPhrase_2 = rpmVal_2 * 2.2
        subItem_2[1] = entryVal_2
        subItem_2[2] = curPhrase_2
        entryVal_2 = {}
        curPhrase_2 = "double_bang"
        if tuneLevel > 1 then
          pulseList_2 = rpmVal_2 * 1.2
          if pulseList_2 then
            goto lbl_412
          end
        end
        pulseList_2 = 0
        ::lbl_412::
        entryVal_2[1] = curPhrase_2
        entryVal_2[2] = pulseList_2
        curPhrase_2 = {}
        pulseList_2 = "triple_bang"
        if tuneLevel >= 3 then
          curDelay_2 = rpmVal_2 * 0.5
          if curDelay_2 then
            goto lbl_423
          end
        end
        curDelay_2 = 0
        ::lbl_423::
        curPhrase_2[1] = pulseList_2
        curPhrase_2[2] = curDelay_2
        pulseList_2 = {}
        curDelay_2 = "pop_bang"
        flameColor_2 = rpmVal_2 or flameColor_2
        if not (tuneLevel > 1) or not rpmVal_2 then
          flameColor_2 = 0
        end
        pulseList_2[1] = curDelay_2
        pulseList_2[2] = flameColor_2
        curDelay_2 = {}
        flameColor_2 = "bang_tail"
        outletIdx_2 = rpmVal_2 * 1.3
        curDelay_2[1] = flameColor_2
        curDelay_2[2] = outletIdx_2
        flameColor_2 = {}
        outletIdx_2 = "lazy"
        emitterVal_2 = 1.2
        flameColor_2[1] = outletIdx_2
        flameColor_2[2] = emitterVal_2
        outletIdx_2 = {}
        emitterVal_2 = "single_pop"
        soundGain_2 = 1.0
        soundGain_2 = soundGain_2 - richVal_2
        soundGain_2 = soundGain_2 * 2.0
        soundGain_2 = 1.0 + soundGain_2
        outletIdx_2[1] = emitterVal_2
        outletIdx_2[2] = soundGain_2
        emitterVal_2 = {}
        soundGain_2 = "double_pop"
        pitchVal_2 = 1.0
        emitterVal_2[1] = soundGain_2
        emitterVal_2[2] = pitchVal_2
        soundGain_2 = {}
        pitchVal_2 = "sparse"
        pulseIdx_2 = 0.6
        soundGain_2[1] = pitchVal_2
        soundGain_2[2] = pulseIdx_2
        pitchVal_2 = {}
        pulseIdx_2 = "stutter"
        isHeavy_2 = 0.4
        pitchVal_2[1] = pulseIdx_2
        pitchVal_2[2] = isHeavy_2
        pulseIdx_2 = {}
        isHeavy_2 = "crackle_burst"
        pulseKind_2 = 0.3
        pulseIdx_2[1] = isHeavy_2
        pulseIdx_2[2] = pulseKind_2
        isHeavy_2 = {}
        pulseKind_2 = "salvo"
        if loadVal_2 then
          pulseEnergy_2 = rpmVal_2 * 0.5
          if pulseEnergy_2 then
            goto lbl_485
          end
        end
        pulseEnergy_2 = 0
        ::lbl_485::
        isHeavy_2[1] = pulseKind_2
        isHeavy_2[2] = pulseEnergy_2
        checkProb_2[1] = subItem_2
        checkProb_2[2] = entryVal_2
        checkProb_2[3] = curPhrase_2
        checkProb_2[4] = pulseList_2
        checkProb_2[5] = curDelay_2
        checkProb_2[6] = flameColor_2
        checkProb_2[7] = outletIdx_2
        checkProb_2[8] = emitterVal_2
        checkProb_2[9] = soundGain_2
        checkProb_2[10] = pitchVal_2
        checkProb_2[11] = pulseIdx_2
        checkProb_2[12] = isHeavy_2
        tempThreshold_2 = checkProb_2
      else
        checkProb_2 = {}
        subItem_2 = {}
        entryVal_2 = "single_pop"
        curPhrase_2 = 1.0
        curPhrase_2 = curPhrase_2 - richVal_2
        curPhrase_2 = curPhrase_2 * 4.2
        curPhrase_2 = 0.35 + curPhrase_2
        subItem_2[1] = entryVal_2
        subItem_2[2] = curPhrase_2
        entryVal_2 = {}
        curPhrase_2 = "single_bang"
        pulseList_2 = rpmVal_2
        entryVal_2[1] = curPhrase_2
        entryVal_2[2] = pulseList_2
        curPhrase_2 = {}
        pulseList_2 = "double_pop"
        curDelay_2 = 1.4
        curPhrase_2[1] = pulseList_2
        curPhrase_2[2] = curDelay_2
        pulseList_2 = {}
        curDelay_2 = "stutter"
        flameColor_2 = tuneLevel * 0.22
        flameColor_2 = 0.8 + flameColor_2
        flameColor_2 = isBrutal_2 * flameColor_2
        flameColor_2 = 0.6 + flameColor_2
        pulseList_2[1] = curDelay_2
        pulseList_2[2] = flameColor_2
        curDelay_2 = {}
        flameColor_2 = "rolling"
        if tuneLevel > 1 then
          if "overrun" == eventType then
            outletIdx_2 = 2.2
            if outletIdx_2 then
              goto lbl_535
            end
          end
          outletIdx_2 = 0.75
          ::lbl_535::
          outletIdx_2 = isBrutal_2 * outletIdx_2
          if outletIdx_2 then
            goto lbl_540
          end
        end
        outletIdx_2 = 0
        ::lbl_540::
        curDelay_2[1] = flameColor_2
        curDelay_2[2] = outletIdx_2
        flameColor_2 = {}
        outletIdx_2 = "bang_tail"
        emitterVal_2 = rpmVal_2 * 0.65
        flameColor_2[1] = outletIdx_2
        flameColor_2[2] = emitterVal_2
        outletIdx_2 = {}
        emitterVal_2 = "sparse"
        soundGain_2 = 1.0
        soundGain_2 = soundGain_2 - richVal_2
        soundGain_2 = soundGain_2 * 1.2
        soundGain_2 = 0.45 + soundGain_2
        outletIdx_2[1] = emitterVal_2
        outletIdx_2[2] = soundGain_2
        emitterVal_2 = {}
        soundGain_2 = "double_bang"
        if tuneLevel > 1 then
          pitchVal_2 = rpmVal_2 * 0.45
          if pitchVal_2 then
            goto lbl_568
          end
        end
        pitchVal_2 = 0
        ::lbl_568::
        emitterVal_2[1] = soundGain_2
        emitterVal_2[2] = pitchVal_2
        soundGain_2 = {}
        pitchVal_2 = "crackle_burst"
        pulseIdx_2 = tuneLevel * 0.2
        pulseIdx_2 = 0.5 + pulseIdx_2
        pulseIdx_2 = isBrutal_2 * pulseIdx_2
        pulseIdx_2 = 0.45 + pulseIdx_2
        soundGain_2[1] = pitchVal_2
        soundGain_2[2] = pulseIdx_2
        pitchVal_2 = {}
        pulseIdx_2 = "bang_crackle"
        if tuneLevel > 1 then
          isHeavy_2 = rpmVal_2 * 0.5
          if isHeavy_2 then
            goto lbl_591
          end
        end
        isHeavy_2 = 0
        ::lbl_591::
        pitchVal_2[1] = pulseIdx_2
        pitchVal_2[2] = isHeavy_2
        pulseIdx_2 = {}
        isHeavy_2 = "triple_bang"
        if tuneLevel >= 3 then
          pulseKind_2 = rpmVal_2 * 0.35
          if pulseKind_2 then
            goto lbl_602
          end
        end
        pulseKind_2 = 0
        ::lbl_602::
        pulseIdx_2[1] = isHeavy_2
        pulseIdx_2[2] = pulseKind_2
        isHeavy_2 = {}
        pulseKind_2 = "pop_bang"
        if tuneLevel > 1 then
          pulseEnergy_2 = rpmVal_2 * 0.4
          if pulseEnergy_2 then
            goto lbl_613
          end
        end
        pulseEnergy_2 = 0
        ::lbl_613::
        isHeavy_2[1] = pulseKind_2
        isHeavy_2[2] = pulseEnergy_2
        pulseKind_2 = {}
        pulseEnergy_2 = "volley"
        if tuneLevel > 1 then
          durationMs_2 = isBrutal_2 * 0.6
          durationMs_2 = 0.3 + durationMs_2
          if durationMs_2 then
            goto lbl_626
          end
        end
        durationMs_2 = 0
        ::lbl_626::
        pulseKind_2[1] = pulseEnergy_2
        pulseKind_2[2] = durationMs_2
        pulseEnergy_2 = {}
        durationMs_2 = "lazy"
        if "overrun" == eventType then
          flameSize_2 = 1.0
          flameSize_2 = flameSize_2 - richVal_2
          flameSize_2 = flameSize_2 * 0.8
          flameSize_2 = 0.4 + flameSize_2
          if flameSize_2 then
            goto lbl_642
          end
        end
        flameSize_2 = 0
        ::lbl_642::
        pulseEnergy_2[1] = durationMs_2
        pulseEnergy_2[2] = flameSize_2
        durationMs_2 = {}
        flameSize_2 = "salvo"
        if loadVal_2 then
          var_2_30 = rpmVal_2 * 0.8
          if var_2_30 then
            goto lbl_653
          end
        end
        var_2_30 = 0
        ::lbl_653::
        durationMs_2[1] = flameSize_2
        durationMs_2[2] = var_2_30
        checkProb_2[1] = subItem_2
        checkProb_2[2] = entryVal_2
        checkProb_2[3] = curPhrase_2
        checkProb_2[4] = pulseList_2
        checkProb_2[5] = curDelay_2
        checkProb_2[6] = flameColor_2
        checkProb_2[7] = outletIdx_2
        checkProb_2[8] = emitterVal_2
        checkProb_2[9] = soundGain_2
        checkProb_2[10] = pitchVal_2
        checkProb_2[11] = pulseIdx_2
        checkProb_2[12] = isHeavy_2
        checkProb_2[13] = pulseKind_2
        checkProb_2[14] = pulseEnergy_2
        checkProb_2[15] = durationMs_2
        tempThreshold_2 = checkProb_2
        checkProb_2 = {}
        function subItem_2(probVal, phraseName)
          local targetVal_3, calcVal_3
          targetVal_3 = checkProb_2
          calcVal_3 = checkProb_2
          calcVal_3 = calcVal_3[probVal]
          if not calcVal_3 then
            calcVal_3 = 1
          end
          calcVal_3 = calcVal_3 * phraseName
          targetVal_3[probVal] = calcVal_3
        end
        entryVal_2 = situation.gear
        if entryVal_2 <= 2 then
          entryVal_2 = subItem_2
          curPhrase_2 = "stutter"
          pulseList_2 = 1.5
          entryVal_2(curPhrase_2, pulseList_2)
          entryVal_2 = subItem_2
          curPhrase_2 = "double_pop"
          pulseList_2 = 1.3
          entryVal_2(curPhrase_2, pulseList_2)
          entryVal_2 = subItem_2
          curPhrase_2 = "single_pop"
          pulseList_2 = 1.2
          entryVal_2(curPhrase_2, pulseList_2)
          entryVal_2 = subItem_2
          curPhrase_2 = "rolling"
          pulseList_2 = 0.6
          entryVal_2(curPhrase_2, pulseList_2)
          entryVal_2 = subItem_2
          curPhrase_2 = "volley"
          pulseList_2 = 0.7
          entryVal_2(curPhrase_2, pulseList_2)
          entryVal_2 = subItem_2
          curPhrase_2 = "lazy"
          pulseList_2 = 0.6
          entryVal_2(curPhrase_2, pulseList_2)
        else
          entryVal_2 = situation.gear
          if entryVal_2 >= 4 then
            entryVal_2 = situation.speed
            if entryVal_2 > 28 then
              entryVal_2 = subItem_2
              curPhrase_2 = "rolling"
              pulseList_2 = 1.6
              entryVal_2(curPhrase_2, pulseList_2)
              entryVal_2 = subItem_2
              curPhrase_2 = "volley"
              pulseList_2 = 1.5
              entryVal_2(curPhrase_2, pulseList_2)
              entryVal_2 = subItem_2
              curPhrase_2 = "crackle_burst"
              pulseList_2 = 1.3
              entryVal_2(curPhrase_2, pulseList_2)
              entryVal_2 = subItem_2
              curPhrase_2 = "lazy"
              pulseList_2 = 1.3
              entryVal_2(curPhrase_2, pulseList_2)
              entryVal_2 = subItem_2
              curPhrase_2 = "single_pop"
              pulseList_2 = 0.7
              entryVal_2(curPhrase_2, pulseList_2)
            end
          end
        end
        entryVal_2 = pairs
        curPhrase_2 = {}
        curPhrase_2.crackle_burst = 0.5
        curPhrase_2.volley = 0.7
        curPhrase_2.rolling = 0.4
        curPhrase_2.triple_bang = 0.4
        curPhrase_2.double_bang = 0.3
        entryVal_2, curPhrase_2, pulseList_2, curDelay_2 = entryVal_2(curPhrase_2)
        for flameColor_2, outletIdx_2 in entryVal_2, curPhrase_2, pulseList_2, curDelay_2 do
          emitterVal_2 = subItem_2
          soundGain_2 = flameColor_2
          pitchVal_2 = situation.hot
          pitchVal_2 = outletIdx_2 * pitchVal_2
          pitchVal_2 = 1 + pitchVal_2
          emitterVal_2(soundGain_2, pitchVal_2)
        end
        entryVal_2 = pairs
        curPhrase_2 = {}
        curPhrase_2.single_pop = 0.8
        curPhrase_2.sparse = 0.8
        curPhrase_2.lazy = 0.4
        entryVal_2, curPhrase_2, pulseList_2, curDelay_2 = entryVal_2(curPhrase_2)
        for flameColor_2, outletIdx_2 in entryVal_2, curPhrase_2, pulseList_2, curDelay_2 do
          emitterVal_2 = subItem_2
          soundGain_2 = flameColor_2
          pitchVal_2 = situation.cold
          pitchVal_2 = outletIdx_2 * pitchVal_2
          pitchVal_2 = 1 + pitchVal_2
          emitterVal_2(soundGain_2, pitchVal_2)
        end
        entryVal_2 = pairs
        curPhrase_2 = {}
        curPhrase_2.volley = 0.7
        curPhrase_2.crackle_burst = 0.5
        curPhrase_2.rolling = 0.5
        curPhrase_2.triple_bang = 0.6
        entryVal_2, curPhrase_2, pulseList_2, curDelay_2 = entryVal_2(curPhrase_2)
        for flameColor_2, outletIdx_2 in entryVal_2, curPhrase_2, pulseList_2, curDelay_2 do
          emitterVal_2 = subItem_2
          soundGain_2 = flameColor_2
          pitchVal_2 = situation.cold
          pitchVal_2 = outletIdx_2 * pitchVal_2
          pulseIdx_2 = 1
          pitchVal_2 = pulseIdx_2 - pitchVal_2
          emitterVal_2(soundGain_2, pitchVal_2)
        end
        entryVal_2 = ipairs
        curPhrase_2 = tempThreshold_2
        entryVal_2, curPhrase_2, pulseList_2, curDelay_2 = entryVal_2(curPhrase_2)
        for flameColor_2, outletIdx_2 in entryVal_2, curPhrase_2, pulseList_2, curDelay_2 do
          emitterVal_2 = outletIdx_2[2]
          soundGain_2 = outletIdx_2[1]
          soundGain_2 = checkProb_2[soundGain_2]
          if not soundGain_2 then
            soundGain_2 = 1
          end
          emitterVal_2 = emitterVal_2 * soundGain_2
          outletIdx_2[2] = emitterVal_2
        end
      end
    end
  end
  checkProb_2 = situation.damaged
  if checkProb_2 > 0 and "antilag" ~= eventType then
    checkProb_2 = ipairs
    subItem_2 = tempThreshold_2
    checkProb_2, subItem_2, entryVal_2, curPhrase_2 = checkProb_2(subItem_2)
    for pulseList_2, curDelay_2 in checkProb_2, subItem_2, entryVal_2, curPhrase_2 do
      flameColor_2 = curDelay_2[1]
      if "volley" ~= flameColor_2 then
        flameColor_2 = curDelay_2[1]
        if "rolling" ~= flameColor_2 then
          flameColor_2 = curDelay_2[1]
          if "crackle_burst" ~= flameColor_2 then
            goto lbl_820
          end
        end
      end
      flameColor_2 = curDelay_2[2]
      outletIdx_2 = situation.damaged
      outletIdx_2 = 0.6 * outletIdx_2
      emitterVal_2 = 1
      outletIdx_2 = emitterVal_2 - outletIdx_2
      flameColor_2 = flameColor_2 * outletIdx_2
      curDelay_2[2] = flameColor_2
      goto lbl_833
      ::lbl_820::
      flameColor_2 = curDelay_2[1]
      if "sparse" ~= flameColor_2 then
        flameColor_2 = curDelay_2[1]
        if "lazy" ~= flameColor_2 then
          goto lbl_833
        end
      end
      flameColor_2 = curDelay_2[2]
      outletIdx_2 = situation.damaged
      outletIdx_2 = 1 + outletIdx_2
      flameColor_2 = flameColor_2 * outletIdx_2
      curDelay_2[2] = flameColor_2
      ::lbl_833::
    end
    checkProb_2 = #tempThreshold_2
    checkProb_2 = checkProb_2 + 1
    subItem_2 = {}
    entryVal_2 = "cough"
    curPhrase_2 = situation.damaged
    curPhrase_2 = curPhrase_2 * 3.0
    subItem_2[1] = entryVal_2
    subItem_2[2] = curPhrase_2
    tempThreshold_2[checkProb_2] = subItem_2
  end
  if 1 ~= bangBias then
    checkProb_2 = ipairs
    subItem_2 = tempThreshold_2
    checkProb_2, subItem_2, entryVal_2, curPhrase_2 = checkProb_2(subItem_2)
    for pulseList_2, curDelay_2 in checkProb_2, subItem_2, entryVal_2, curPhrase_2 do
      outletIdx_2 = curDelay_2[1]
      flameColor_2 = heavyPhrases
      flameColor_2 = flameColor_2[outletIdx_2]
      if flameColor_2 then
        flameColor_2 = curDelay_2[2]
        flameColor_2 = flameColor_2 * bangBias
        curDelay_2[2] = flameColor_2
      end
    end
  end
  if loadVal_2 then
    checkProb_2 = ipairs
    subItem_2 = tempThreshold_2
    checkProb_2, subItem_2, entryVal_2, curPhrase_2 = checkProb_2(subItem_2)
    for pulseList_2, curDelay_2 in checkProb_2, subItem_2, entryVal_2, curPhrase_2 do
      flameColor_2 = curDelay_2[1]
      if "bang_crackle" == flameColor_2 then
        flameColor_2 = curDelay_2[2]
        flameColor_2 = flameColor_2 * 1.8
        curDelay_2[2] = flameColor_2
      else
        flameColor_2 = curDelay_2[1]
        if "bang_tail" == flameColor_2 then
          flameColor_2 = curDelay_2[2]
          flameColor_2 = flameColor_2 * 1.4
          curDelay_2[2] = flameColor_2
        else
          flameColor_2 = curDelay_2[1]
          if "single_bang" == flameColor_2 and "limiter" ~= eventType and "upshift" ~= eventType then
            flameColor_2 = situation.chain
            if 0 == flameColor_2 then
              flameColor_2 = curDelay_2[2]
              flameColor_2 = flameColor_2 * 0.6
              curDelay_2[2] = flameColor_2
            end
          end
        end
      end
    end
  end
  checkProb_2 = 0
  subItem_2 = ipairs
  entryVal_2 = tempThreshold_2
  subItem_2, entryVal_2, curPhrase_2, pulseList_2 = subItem_2(entryVal_2)
  for curDelay_2, flameColor_2 in subItem_2, entryVal_2, curPhrase_2, pulseList_2 do
    outletIdx_2 = flameColor_2[2]
    checkProb_2 = checkProb_2 + outletIdx_2
  end
  subItem_2 = argParam
  subItem_2 = subItem_2()
  if seed then
    entryVal_2 = seed % 4096
    entryVal_2 = entryVal_2 * 0.618033988749895
    curPhrase_2 = subItem_2 * 0.14
    entryVal_2 = entryVal_2 + curPhrase_2
    subItem_2 = entryVal_2 % 1
  end
  entryVal_2 = subItem_2 * checkProb_2
  curPhrase_2 = ipairs
  pulseList_2 = tempThreshold_2
  curPhrase_2, pulseList_2, curDelay_2, flameColor_2 = curPhrase_2(pulseList_2)
  for outletIdx_2, emitterVal_2 in curPhrase_2, pulseList_2, curDelay_2, flameColor_2 do
    soundGain_2 = emitterVal_2[2]
    entryVal_2 = entryVal_2 - soundGain_2
    if entryVal_2 <= 0 then
      soundGain_2 = emitterVal_2[1]
      return soundGain_2
    end
  end
  curPhrase_2 = "single_pop"
  return curPhrase_2
end
function ExpandCombustionPhrase(argParam, tuneLevel)
  local targetVal_2, calcVal_2, minVal_2, maxVal_2, stepVal_2, fuelVal_2, richVal_2, isBrutal_2, loadVal_2, rpmVal_2, tempThreshold_2, checkProb_2
  targetVal_2 = {}
  function calcVal_2(probVal, phraseName, pulseDelay, pulsePitch)
    local minVal_3, maxVal_3, stepVal_3, fuelVal_3, richVal_3, isBrutal_3, loadVal_3
    minVal_3 = targetVal_2
    minVal_3 = #minVal_3
    maxVal_3 = minVal_3 + 1
    minVal_3 = targetVal_2
    stepVal_3 = {}
    stepVal_3.kind = probVal
    fuelVal_3 = math
    fuelVal_3 = fuelVal_3.floor
    richVal_3 = argParam
    richVal_3 = richVal_3()
    isBrutal_3 = GetSampleCount
    loadVal_3 = probVal
    isBrutal_3 = isBrutal_3(loadVal_3)
    richVal_3 = richVal_3 * isBrutal_3
    fuelVal_3 = fuelVal_3(richVal_3)
    fuelVal_3 = 1 + fuelVal_3
    stepVal_3.take = fuelVal_3
    fuelVal_3 = RoundNumber
    richVal_3 = phraseName * 10
    fuelVal_3 = fuelVal_3(richVal_3)
    fuelVal_3 = fuelVal_3 / 10
    stepVal_3.gain = fuelVal_3
    fuelVal_3 = RoundNumber
    richVal_3 = pulseDelay
    fuelVal_3 = fuelVal_3(richVal_3)
    stepVal_3.delay = fuelVal_3
    fuelVal_3 = RoundNumber
    richVal_3 = pulsePitch * 1000
    fuelVal_3 = fuelVal_3(richVal_3)
    fuelVal_3 = fuelVal_3 / 1000
    stepVal_3.pitch = fuelVal_3
    minVal_3[maxVal_3] = stepVal_3
  end
  if "boom" == tuneLevel then
    minVal_2 = calcVal_2
    maxVal_2 = argParam
    maxVal_2 = maxVal_2()
    stepVal_2 = 0.5
    if maxVal_2 < stepVal_2 then
      maxVal_2 = "snap"
      if maxVal_2 then
        goto lbl_16
      end
    end
    maxVal_2 = "crackle"
    ::lbl_16::
    stepVal_2 = argParam
    stepVal_2 = stepVal_2()
    stepVal_2 = stepVal_2 * 4
    stepVal_2 = -9 + stepVal_2
    fuelVal_2 = argParam
    fuelVal_2 = fuelVal_2()
    fuelVal_2 = fuelVal_2 * 3
    richVal_2 = argParam
    richVal_2 = richVal_2()
    richVal_2 = richVal_2 * 0.3
    richVal_2 = 0.95 + richVal_2
    minVal_2(maxVal_2, stepVal_2, fuelVal_2, richVal_2)
    minVal_2 = argParam
    minVal_2 = minVal_2()
    maxVal_2 = 0.45
    if minVal_2 < maxVal_2 then
      minVal_2 = argParam
      minVal_2 = minVal_2()
      minVal_2 = minVal_2 * 60
      minVal_2 = 70 + minVal_2
      maxVal_2 = 1
      stepVal_2 = math
      stepVal_2 = stepVal_2.floor
      fuelVal_2 = argParam
      fuelVal_2 = fuelVal_2()
      fuelVal_2 = fuelVal_2 * 2
      stepVal_2 = stepVal_2(fuelVal_2)
      stepVal_2 = 2 + stepVal_2
      fuelVal_2 = 1
      for richVal_2 = maxVal_2, stepVal_2, fuelVal_2 do
        isBrutal_2 = calcVal_2
        loadVal_2 = "crackle"
        rpmVal_2 = argParam
        rpmVal_2 = rpmVal_2()
        rpmVal_2 = rpmVal_2 * 5
        rpmVal_2 = -17 + rpmVal_2
        tempThreshold_2 = minVal_2
        checkProb_2 = argParam
        checkProb_2 = checkProb_2()
        checkProb_2 = checkProb_2 * 0.4
        checkProb_2 = 1.0 + checkProb_2
        isBrutal_2(loadVal_2, rpmVal_2, tempThreshold_2, checkProb_2)
        isBrutal_2 = minVal_2 + 35
        loadVal_2 = argParam
        loadVal_2 = loadVal_2()
        loadVal_2 = loadVal_2 * 60
        minVal_2 = isBrutal_2 + loadVal_2
      end
    end
  elseif "bang" == tuneLevel then
    minVal_2 = argParam
    minVal_2 = minVal_2()
    maxVal_2 = 0.6
    if minVal_2 < maxVal_2 then
      minVal_2 = calcVal_2
      maxVal_2 = argParam
      maxVal_2 = maxVal_2()
      stepVal_2 = 0.5
      if maxVal_2 < stepVal_2 then
        maxVal_2 = "snap"
        if maxVal_2 then
          goto lbl_99
        end
      end
      maxVal_2 = "crackle"
      ::lbl_99::
      stepVal_2 = argParam
      stepVal_2 = stepVal_2()
      stepVal_2 = stepVal_2 * 4
      stepVal_2 = -11 + stepVal_2
      fuelVal_2 = argParam
      fuelVal_2 = fuelVal_2()
      fuelVal_2 = fuelVal_2 * 3
      richVal_2 = argParam
      richVal_2 = richVal_2()
      richVal_2 = richVal_2 * 0.3
      richVal_2 = 0.95 + richVal_2
      minVal_2(maxVal_2, stepVal_2, fuelVal_2, richVal_2)
    end
    minVal_2 = argParam
    minVal_2 = minVal_2()
    maxVal_2 = 0.3
    if minVal_2 < maxVal_2 then
      minVal_2 = calcVal_2
      maxVal_2 = "crackle"
      stepVal_2 = argParam
      stepVal_2 = stepVal_2()
      stepVal_2 = stepVal_2 * 4
      stepVal_2 = -16 + stepVal_2
      fuelVal_2 = argParam
      fuelVal_2 = fuelVal_2()
      fuelVal_2 = fuelVal_2 * 90
      fuelVal_2 = 60 + fuelVal_2
      richVal_2 = argParam
      richVal_2 = richVal_2()
      richVal_2 = richVal_2 * 0.4
      richVal_2 = 1.0 + richVal_2
      minVal_2(maxVal_2, stepVal_2, fuelVal_2, richVal_2)
    end
  elseif "snap" == tuneLevel then
    minVal_2 = argParam
    minVal_2 = minVal_2()
    maxVal_2 = 0.3
    if minVal_2 < maxVal_2 then
      minVal_2 = calcVal_2
      maxVal_2 = "crackle"
      stepVal_2 = argParam
      stepVal_2 = stepVal_2()
      stepVal_2 = stepVal_2 * 4
      stepVal_2 = -13 + stepVal_2
      fuelVal_2 = argParam
      fuelVal_2 = fuelVal_2()
      fuelVal_2 = fuelVal_2 * 27
      fuelVal_2 = 18 + fuelVal_2
      richVal_2 = argParam
      richVal_2 = richVal_2()
      richVal_2 = richVal_2 * 0.35
      richVal_2 = 1.0 + richVal_2
      minVal_2(maxVal_2, stepVal_2, fuelVal_2, richVal_2)
    end
  elseif "burble" == tuneLevel then
    minVal_2 = argParam
    minVal_2 = minVal_2()
    maxVal_2 = 0.25
    if minVal_2 < maxVal_2 then
      minVal_2 = calcVal_2
      maxVal_2 = "burble"
      stepVal_2 = argParam
      stepVal_2 = stepVal_2()
      stepVal_2 = stepVal_2 * 3
      stepVal_2 = -9 + stepVal_2
      fuelVal_2 = argParam
      fuelVal_2 = fuelVal_2()
      fuelVal_2 = fuelVal_2 * 30
      fuelVal_2 = 30 + fuelVal_2
      richVal_2 = argParam
      richVal_2 = richVal_2()
      richVal_2 = richVal_2 * 0.25
      richVal_2 = 0.9 + richVal_2
      minVal_2(maxVal_2, stepVal_2, fuelVal_2, richVal_2)
    end
  end
  return targetVal_2
end
function BuildCombustionPulses(argParam, tuneLevel, eventType, situation, flameActive, seed)
  local stepVal_2, fuelVal_2, richVal_2, isBrutal_2, loadVal_2, rpmVal_2, tempThreshold_2, checkProb_2, subItem_2, entryVal_2, curPhrase_2, pulseList_2, curDelay_2, flameColor_2, outletIdx_2, emitterVal_2, soundGain_2, pitchVal_2, pulseIdx_2, isHeavy_2, pulseKind_2, pulseEnergy_2, durationMs_2, flameSize_2, var_2_30, var_2_31, var_2_32, var_2_33, var_2_34, var_2_35, var_2_36, var_2_37, var_2_38, var_2_39, var_2_40, var_2_41, var_2_42, var_2_43, var_2_44, var_2_45, var_2_46, var_2_47, var_2_48, var_2_49, var_2_50, var_2_51, var_2_52, var_2_53, var_2_54, var_2_55, var_2_56, var_2_57, var_2_58
  stepVal_2 = ResolveTuneLevel
  fuelVal_2 = argParam
  stepVal_2, fuelVal_2 = stepVal_2(fuelVal_2)
  if stepVal_2 then
    richVal_2 = type
    isBrutal_2 = eventType
    richVal_2 = richVal_2(isBrutal_2)
    if "table" == richVal_2 then
      goto lbl_14
    end
  end
  richVal_2 = {}
  do return richVal_2 end
  ::lbl_14::
  if "upshift" ~= tuneLevel and "downshift" ~= tuneLevel and "overrun" ~= tuneLevel and "limiter" ~= tuneLevel and "antilag" ~= tuneLevel and "launch" ~= tuneLevel then
    richVal_2 = {}
    return richVal_2
  end
  if "limiter" == tuneLevel then
    richVal_2 = fuelVal_2.limiter
    if false == richVal_2 then
      richVal_2 = {}
      return richVal_2
    end
  end
  richVal_2 = IsFiniteNumber
  isBrutal_2 = flameActive
  richVal_2 = richVal_2(isBrutal_2)
  if richVal_2 and flameActive >= 0 then
    richVal_2 = 2147483646
    if flameActive <= richVal_2 then
      richVal_2 = flameActive % 1
      if 0 == richVal_2 and flameActive then
        goto lbl_54
      end
    end
  end
  flameActive = nil
  ::lbl_54::
  richVal_2 = CreatePseudoRandom
  isBrutal_2 = situation
  richVal_2 = richVal_2(isBrutal_2)
  isBrutal_2 = richVal_2
  isBrutal_2()
  isBrutal_2 = richVal_2
  isBrutal_2()
  isBrutal_2 = richVal_2
  isBrutal_2()
  isBrutal_2 = PopsCombustion
  isBrutal_2 = isBrutal_2.Situation
  loadVal_2 = tuneLevel
  rpmVal_2 = eventType
  isBrutal_2 = isBrutal_2(loadVal_2, rpmVal_2)
  loadVal_2 = isBrutal_2.rpm
  rpmVal_2 = isBrutal_2.load
  tempThreshold_2 = isBrutal_2.temperature
  checkProb_2 = isBrutal_2.fuel
  subItem_2 = isBrutal_2.rich
  entryVal_2 = isBrutal_2.chain
  curPhrase_2 = isBrutal_2.standing
  curPhrase_2 = curPhrase_2 and "overrun" == tuneLevel
  pulseList_2 = ClampNumber
  curDelay_2 = fuelVal_2.flameScale
  flameColor_2 = 0.05
  outletIdx_2 = 3.0
  emitterVal_2 = defaultLevels
  emitterVal_2 = emitterVal_2[stepVal_2]
  emitterVal_2 = emitterVal_2.flameScale
  pulseList_2 = pulseList_2(curDelay_2, flameColor_2, outletIdx_2, emitterVal_2)
  curDelay_2 = ClampNumber
  flameColor_2 = fuelVal_2.heavyChance
  outletIdx_2 = 0
  emitterVal_2 = 0.9
  soundGain_2 = defaultLevels
  soundGain_2 = soundGain_2[stepVal_2]
  soundGain_2 = soundGain_2.heavyChance
  curDelay_2 = curDelay_2(flameColor_2, outletIdx_2, emitterVal_2, soundGain_2)
  flameColor_2 = energyMultipliers
  flameColor_2 = flameColor_2[stepVal_2]
  outletIdx_2 = PopsCombustion.Realism
  emitterVal_2 = stepVal_2
  soundGain_2 = isBrutal_2
  outletIdx_2 = outletIdx_2(emitterVal_2, soundGain_2)
  emitterVal_2 = ClampNumber
  soundGain_2 = fuelVal_2.boomChance
  pitchVal_2 = 0
  pulseIdx_2 = 1
  isHeavy_2 = boomChances
  isHeavy_2 = isHeavy_2[stepVal_2]
  emitterVal_2 = emitterVal_2(soundGain_2, pitchVal_2, pulseIdx_2, isHeavy_2)
  soundGain_2 = ClampNumber
  pitchVal_2 = subItem_2 * 0.75
  pitchVal_2 = 0.45 + pitchVal_2
  pulseIdx_2 = 0
  isHeavy_2 = 1
  soundGain_2 = soundGain_2(pitchVal_2, pulseIdx_2, isHeavy_2)
  emitterVal_2 = emitterVal_2 * soundGain_2
  if curPhrase_2 or "launch" == tuneLevel then
    soundGain_2 = 1.25
    if soundGain_2 then
      goto lbl_128
    end
  end
  soundGain_2 = 1.0
  ::lbl_128::
  emitterVal_2 = emitterVal_2 * soundGain_2
  soundGain_2 = isBrutal_2.cold
  soundGain_2 = 0.5 * soundGain_2
  pitchVal_2 = 1
  soundGain_2 = pitchVal_2 - soundGain_2
  emitterVal_2 = emitterVal_2 * soundGain_2
  if stepVal_2 >= 4 then
    soundGain_2 = 1
    if soundGain_2 then
      goto lbl_148
    end
  end
  soundGain_2 = isBrutal_2.revs
  soundGain_2 = 0.85 * soundGain_2
  soundGain_2 = 0.15 + soundGain_2
  ::lbl_148::
  emitterVal_2 = emitterVal_2 * soundGain_2
  soundGain_2 = isBrutal_2.cold
  soundGain_2 = 0.22 * soundGain_2
  pitchVal_2 = 1
  soundGain_2 = pitchVal_2 - soundGain_2
  pitchVal_2 = isBrutal_2.hot
  pitchVal_2 = 0.06 * pitchVal_2
  pitchVal_2 = 1 + pitchVal_2
  soundGain_2 = soundGain_2 * pitchVal_2
  pitchVal_2 = isBrutal_2.damaged
  pitchVal_2 = 0.1 * pitchVal_2
  pulseIdx_2 = 1
  pitchVal_2 = pulseIdx_2 - pitchVal_2
  soundGain_2 = soundGain_2 * pitchVal_2
  if entryVal_2 > 0 then
    pitchVal_2 = math
    pitchVal_2 = pitchVal_2.max
    pulseIdx_2 = 0.42
    isHeavy_2 = 0.1 * entryVal_2
    pulseKind_2 = 0.9
    isHeavy_2 = pulseKind_2 - isHeavy_2
    pitchVal_2 = pitchVal_2(pulseIdx_2, isHeavy_2)
    if pitchVal_2 then
      goto lbl_185
    end
  end
  pitchVal_2 = 1.0
  ::lbl_185::
  soundGain_2 = soundGain_2 * pitchVal_2
  if curPhrase_2 then
    pitchVal_2 = 1.06
    if pitchVal_2 then
      goto lbl_193
    end
  end
  pitchVal_2 = 1.0
  ::lbl_193::
  soundGain_2 = soundGain_2 * pitchVal_2
  pitchVal_2 = isBrutal_2.cold
  pitchVal_2 = 0.25 * pitchVal_2
  pulseIdx_2 = 1
  pitchVal_2 = pulseIdx_2 - pitchVal_2
  pulseIdx_2 = isBrutal_2.hot
  pulseIdx_2 = 0.15 * pulseIdx_2
  pulseIdx_2 = 1 + pulseIdx_2
  pitchVal_2 = pitchVal_2 * pulseIdx_2
  if curPhrase_2 then
    pulseIdx_2 = 1.2
    if pulseIdx_2 then
      goto lbl_219
    end
  end
  pulseIdx_2 = isBrutal_2.fast
  pulseIdx_2 = 0.08 * pulseIdx_2
  isHeavy_2 = 1.0
  pulseIdx_2 = isHeavy_2 - pulseIdx_2
  ::lbl_219::
  pitchVal_2 = pitchVal_2 * pulseIdx_2
  if curPhrase_2 then
    pulseIdx_2 = 1.2
    if pulseIdx_2 then
      goto lbl_227
    end
  end
  pulseIdx_2 = 1.0
  ::lbl_227::
  if "upshift" == tuneLevel or "limiter" == tuneLevel then
    isHeavy_2 = 1.0
    if isHeavy_2 then
      goto lbl_244
    end
  end
  isHeavy_2 = ClampNumber
  pulseKind_2 = isBrutal_2.rpmNow
  pulseKind_2 = 0.5 * pulseKind_2
  pulseEnergy_2 = 1.3
  pulseKind_2 = pulseEnergy_2 - pulseKind_2
  pulseEnergy_2 = 0.78
  durationMs_2 = 1.2
  isHeavy_2 = isHeavy_2(pulseKind_2, pulseEnergy_2, durationMs_2)
  ::lbl_244::
  pulseKind_2 = PickCombustionPhrase
  pulseEnergy_2 = richVal_2
  durationMs_2 = stepVal_2
  flameSize_2 = tuneLevel
  var_2_30 = isBrutal_2
  var_2_31 = curDelay_2
  var_2_32 = flameActive
  var_2_33 = ClampNumber
  var_2_34 = fuelVal_2.bangBias
  var_2_35 = 0.2
  var_2_36 = 5
  var_2_37 = bangBiases
  var_2_37 = var_2_37[stepVal_2]
  var_2_33 = var_2_33(var_2_34, var_2_35, var_2_36, var_2_37)
  var_2_34 = outletIdx_2
  pulseKind_2 = pulseKind_2(pulseEnergy_2, durationMs_2, flameSize_2, var_2_30, var_2_31, var_2_32, var_2_33, var_2_34)
  pulseEnergy_2 = nil
  if "antilag" == tuneLevel then
    if "sparse" == pulseKind_2 then
      pulseEnergy_2 = 3
    elseif "bang_tail" == pulseKind_2 then
      pulseEnergy_2 = 3 + math.floor(richVal_2() * 2)
    elseif "rolling" == pulseKind_2 then
      pulseEnergy_2 = 4 + math.floor(richVal_2() * 3)
    else
      pulseEnergy_2 = 3 + math.floor(richVal_2() * 4)
    end
  elseif "single_pop" == pulseKind_2 or "single_bang" == pulseKind_2 then
    pulseEnergy_2 = 1
  elseif "double_pop" == pulseKind_2 or "double_bang" == pulseKind_2 or "pop_bang" == pulseKind_2 then
    pulseEnergy_2 = 2
  elseif "triple_bang" == pulseKind_2 then
    pulseEnergy_2 = 3
  elseif "volley" == pulseKind_2 then
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = richVal_2
    flameSize_2 = flameSize_2()
    flameSize_2 = flameSize_2 * 5
    durationMs_2 = durationMs_2(flameSize_2)
    pulseEnergy_2 = 7 + durationMs_2
  elseif "lazy" == pulseKind_2 then
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = richVal_2
    flameSize_2 = flameSize_2()
    flameSize_2 = flameSize_2 * 3
    durationMs_2 = durationMs_2(flameSize_2)
    pulseEnergy_2 = 4 + durationMs_2
  elseif "cough" == pulseKind_2 then
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = richVal_2
    flameSize_2 = flameSize_2()
    flameSize_2 = flameSize_2 * 3
    durationMs_2 = durationMs_2(flameSize_2)
    pulseEnergy_2 = 2 + durationMs_2
  elseif "crackle_burst" == pulseKind_2 then
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = richVal_2
    flameSize_2 = flameSize_2()
    flameSize_2 = flameSize_2 * 4
    durationMs_2 = durationMs_2(flameSize_2)
    pulseEnergy_2 = 5 + durationMs_2
  elseif "bang_crackle" == pulseKind_2 then
    if stepVal_2 >= 4 then
      durationMs_2 = 5
      if durationMs_2 then
        goto lbl_378
      end
    end
    durationMs_2 = 4
    ::lbl_378::
    flameSize_2 = math
    flameSize_2 = flameSize_2.floor
    var_2_30 = richVal_2
    var_2_30 = var_2_30()
    var_2_30 = var_2_30 * 3
    flameSize_2 = flameSize_2(var_2_30)
    pulseEnergy_2 = durationMs_2 + flameSize_2
  elseif "salvo" == pulseKind_2 then
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = richVal_2
    flameSize_2 = flameSize_2()
    flameSize_2 = flameSize_2 * 3
    durationMs_2 = durationMs_2(flameSize_2)
    pulseEnergy_2 = 4 + durationMs_2
  elseif "stutter" == pulseKind_2 then
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = richVal_2
    flameSize_2 = flameSize_2()
    if stepVal_2 >= 3 then
      var_2_30 = 3
      if var_2_30 then
        goto lbl_412
      end
    end
    var_2_30 = 2
    ::lbl_412::
    flameSize_2 = flameSize_2 * var_2_30
    durationMs_2 = durationMs_2(flameSize_2)
    pulseEnergy_2 = 3 + durationMs_2
  elseif "rolling" == pulseKind_2 then
    if stepVal_2 >= 3 then
      durationMs_2 = 5
      if durationMs_2 then
        goto lbl_426
      end
    end
    durationMs_2 = 3
    ::lbl_426::
    flameSize_2 = math
    flameSize_2 = flameSize_2.floor
    var_2_30 = richVal_2
    var_2_30 = var_2_30()
    if stepVal_2 >= 3 then
      var_2_31 = 4
      if var_2_31 then
        goto lbl_436
      end
    end
    var_2_31 = 3
    ::lbl_436::
    var_2_30 = var_2_30 * var_2_31
    flameSize_2 = flameSize_2(var_2_30)
    pulseEnergy_2 = durationMs_2 + flameSize_2
  elseif "bang_tail" == pulseKind_2 then
    if stepVal_2 >= 4 then
      durationMs_2 = 3
      if durationMs_2 then
        goto lbl_450
      end
    end
    durationMs_2 = 2
    ::lbl_450::
    flameSize_2 = math
    flameSize_2 = flameSize_2.floor
    var_2_30 = richVal_2
    var_2_30 = var_2_30()
    var_2_30 = var_2_30 * 3
    flameSize_2 = flameSize_2(var_2_30)
    pulseEnergy_2 = durationMs_2 + flameSize_2
  else
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = richVal_2
    flameSize_2 = flameSize_2()
    flameSize_2 = flameSize_2 * 2
    durationMs_2 = durationMs_2(flameSize_2)
    pulseEnergy_2 = 2 + durationMs_2
  end
  if pulseEnergy_2 >= 4 and "antilag" ~= tuneLevel then
    durationMs_2 = math
    durationMs_2 = durationMs_2.floor
    flameSize_2 = isBrutal_2.hot
    flameSize_2 = flameSize_2 * 2.4
    var_2_30 = richVal_2
    var_2_30 = var_2_30()
    flameSize_2 = flameSize_2 * var_2_30
    durationMs_2 = durationMs_2(flameSize_2)
    durationMs_2 = pulseEnergy_2 + durationMs_2
    flameSize_2 = isBrutal_2.cold
    var_2_30 = 0.5
    if flameSize_2 > var_2_30 then
      flameSize_2 = 1
      if flameSize_2 then
        goto lbl_493
      end
    end
    flameSize_2 = 0
    ::lbl_493::
    pulseEnergy_2 = durationMs_2 - flameSize_2
  end
  durationMs_2 = math
  durationMs_2 = durationMs_2.max
  flameSize_2 = 1
  var_2_30 = math
  var_2_30 = var_2_30.min
  var_2_31 = pulseEnergy_2
  if "upshift" == tuneLevel then
    var_2_32 = 2
    if var_2_32 then
      goto lbl_532
    end
  end
  if "downshift" == tuneLevel then
    var_2_32 = 5
    if var_2_32 then
      goto lbl_532
    end
  end
  if "limiter" == tuneLevel then
    var_2_32 = 3
    if var_2_32 then
      goto lbl_532
    end
  end
  if "antilag" == tuneLevel then
    var_2_32 = 6
    if var_2_32 then
      goto lbl_532
    end
  end
  if "launch" == tuneLevel then
    var_2_32 = 3
    if var_2_32 then
      goto lbl_532
    end
  end
  if entryVal_2 > 0 then
    var_2_32 = 9
    if var_2_32 then
      goto lbl_532
    end
  end
  var_2_32 = 12
  ::lbl_532::
  pulseEnergy_2 = math.max(1, math.min(pulseEnergy_2, var_2_32))
  durationMs_2 = {}
  flameSize_2 = 0
  var_2_30 = 0
  var_2_31 = {}
  var_2_32 = 1
  var_2_33 = pulseEnergy_2
  var_2_34 = 1
  for var_2_35 = var_2_32, var_2_33, var_2_34 do
    if pulseEnergy_2 > 1 then
      var_2_36 = var_2_35 - 1
      var_2_37 = pulseEnergy_2 - 1
      var_2_36 = var_2_36 / var_2_37
      if var_2_36 then
        goto lbl_556
      end
    end
    var_2_36 = 0
    ::lbl_556::
    if "bang_tail" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_37 = 1.08
        if var_2_37 then
          goto lbl_716
        end
      end
      var_2_37 = var_2_36 * 0.13
      var_2_38 = 0.38
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "triple_bang" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_37 = 1.1
        if var_2_37 then
          goto lbl_716
        end
      end
      if 2 == var_2_35 then
        var_2_37 = 0.96
        if var_2_37 then
          goto lbl_716
        end
      end
      var_2_37 = 0.86
      if var_2_37 then
        goto lbl_716
      end
    end
    if "pop_bang" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_37 = 0.62
        if var_2_37 then
          goto lbl_716
        end
      end
      var_2_37 = 1.12
      if var_2_37 then
        goto lbl_716
      end
    end
    if "volley" == pulseKind_2 then
      var_2_37 = var_2_36 * 0.35
      var_2_38 = 0.72
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "lazy" == pulseKind_2 then
      var_2_37 = var_2_36 * 0.45
      var_2_38 = 0.85
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "cough" == pulseKind_2 then
      var_2_37 = var_2_36 * 0.25
      var_2_38 = 0.75
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "double_bang" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_37 = 1.08
        if var_2_37 then
          goto lbl_716
        end
      end
      var_2_37 = 0.82
      if var_2_37 then
        goto lbl_716
      end
    end
    if "bang_crackle" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_37 = 1.1
        if var_2_37 then
          goto lbl_716
        end
      end
      var_2_37 = var_2_36 * 0.2
      var_2_38 = 0.5
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "salvo" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_37 = 1.08
        if var_2_37 then
          goto lbl_716
        end
      end
      if var_2_35 == pulseEnergy_2 then
        var_2_37 = 1.0
        if var_2_37 then
          goto lbl_716
        end
      end
      var_2_37 = var_2_36 * 0.15
      var_2_38 = 0.5
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "crackle_burst" == pulseKind_2 then
      var_2_37 = var_2_36 * 0.4
      var_2_38 = 0.8
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "rolling" == pulseKind_2 then
      var_2_37 = var_2_36 * 0.62
      var_2_38 = 1.0
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "overrun" == tuneLevel then
      var_2_37 = var_2_36 * 0.58
      var_2_38 = 1.0
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "downshift" == tuneLevel then
      var_2_37 = var_2_36 * 0.32
      var_2_38 = 1.0
      var_2_37 = var_2_38 - var_2_37
      if var_2_37 then
        goto lbl_716
      end
    end
    if "upshift" == tuneLevel then
      if 1 == var_2_35 then
        var_2_37 = 1.0
        if var_2_37 then
          goto lbl_716
        end
      end
      var_2_37 = 0.58
      if var_2_37 then
        goto lbl_716
      end
    end
    var_2_37 = var_2_36 * 0.15
    var_2_38 = 1.0
    var_2_37 = var_2_38 - var_2_37
    ::lbl_716::
    var_2_38 = "single_bang" == pulseKind_2 or "double_bang" == pulseKind_2 or "triple_bang" == pulseKind_2 or ("bang_tail" == pulseKind_2 or "bang_crackle" == pulseKind_2) and 1 == var_2_35 or "pop_bang" == pulseKind_2 and 2 == var_2_35 or "salvo" == pulseKind_2 and (1 == var_2_35 or var_2_35 == pulseEnergy_2)
    if "rolling" == pulseKind_2 then
      var_2_38 = 1 == var_2_35
    elseif "antilag" == tuneLevel and "stutter" == pulseKind_2 then
      var_2_39 = richVal_2
      var_2_39 = var_2_39()
      var_2_40 = curDelay_2 * checkProb_2
      var_2_40 = var_2_40 * 0.35
      var_2_38 = var_2_39 < var_2_40
    end
    if "antilag" == tuneLevel then
      if not (var_2_30 >= 2) then
        var_2_39 = var_2_35 - 1
        var_2_39 = durationMs_2[var_2_39]
        if not var_2_39 then
          goto lbl_791
        end
        var_2_39 = var_2_35 - 1
        var_2_39 = durationMs_2[var_2_39]
        var_2_39 = var_2_39.heavy
        if not var_2_39 then
          goto lbl_791
        end
      end
      var_2_38 = false
    end
    ::lbl_791::
    if var_2_38 then
      var_2_30 = var_2_30 + 1
    end
    var_2_39 = richVal_2
    var_2_39 = var_2_39()
    var_2_40 = math
    var_2_40 = var_2_40.min
    var_2_41 = 0.9
    if "single_bang" == pulseKind_2 or "double_bang" == pulseKind_2 or "triple_bang" == pulseKind_2 then
      var_2_42 = 1.25
      if var_2_42 then
        goto lbl_810
      end
    end
    var_2_42 = 1.0
    ::lbl_810::
    var_2_42 = emitterVal_2 * var_2_42
    var_2_40 = var_2_40(var_2_41, var_2_42)
    var_2_39 = var_2_39 < var_2_40
    var_2_39 = var_2_38 or var_2_39
    var_2_39 = var_2_39 and var_2_38 and "antilag" ~= tuneLevel and (0 == entryVal_2 or stepVal_2 >= 4 and entryVal_2 <= 2)
    var_2_40 = ClampNumber
    var_2_41 = checkProb_2 * 0.68
    var_2_41 = 0.32 + var_2_41
    var_2_41 = var_2_41 * flameColor_2
    var_2_41 = var_2_41 * var_2_37
    var_2_42 = richVal_2
    var_2_42 = var_2_42()
    var_2_42 = var_2_42 * 0.29
    var_2_42 = 0.84 + var_2_42
    var_2_41 = var_2_41 * var_2_42
    var_2_41 = var_2_41 * soundGain_2
    if var_2_39 then
      var_2_42 = 1.4
      if var_2_42 then
        goto lbl_861
      end
    end
    if var_2_38 then
      var_2_42 = 1.32
      if var_2_42 then
        goto lbl_861
      end
    end
    var_2_42 = 1.0
    ::lbl_861::
    var_2_41 = var_2_41 * var_2_42
    var_2_42 = 0.12
    var_2_43 = 1.5
    var_2_40 = var_2_40(var_2_41, var_2_42, var_2_43)
    if var_2_39 then
      var_2_41 = "boom"
      if var_2_41 then
        goto lbl_976
      end
    end
    if var_2_38 then
      var_2_41 = "bang"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "single_pop" == pulseKind_2 then
      var_2_41 = "snap"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "double_pop" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_41 = "snap"
        if var_2_41 then
          goto lbl_976
        end
      end
      var_2_41 = "crackle"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "stutter" == pulseKind_2 then
      var_2_41 = var_2_35 % 3
      if 1 == var_2_41 then
        var_2_41 = "snap"
        if var_2_41 then
          goto lbl_976
        end
      end
      var_2_41 = "crackle"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "bang_tail" == pulseKind_2 then
      var_2_41 = "burble"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "bang_crackle" == pulseKind_2 or "salvo" == pulseKind_2 then
      var_2_41 = "crackle"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "crackle_burst" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_41 = "snap"
        if var_2_41 then
          goto lbl_976
        end
      end
      var_2_41 = "crackle"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "volley" == pulseKind_2 then
      if 1 == var_2_35 then
        var_2_41 = "snap"
        if var_2_41 then
          goto lbl_976
        end
      end
      var_2_41 = "crackle"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "lazy" == pulseKind_2 or "cough" == pulseKind_2 then
      var_2_41 = "burble"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "pop_bang" == pulseKind_2 then
      var_2_41 = "snap"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "upshift" == tuneLevel then
      var_2_41 = "snap"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "limiter" == tuneLevel then
      var_2_41 = "snap"
      if var_2_41 then
        goto lbl_976
      end
    end
    if "antilag" == tuneLevel then
      var_2_41 = var_2_35 % 2
      if 0 == var_2_41 then
        var_2_41 = "snap"
        if var_2_41 then
          goto lbl_976
        end
      end
      var_2_41 = "crackle"
      if var_2_41 then
        goto lbl_976
      end
    end
    var_2_41 = 0.64
    if var_2_36 > var_2_41 then
      var_2_41 = "burble"
      if var_2_41 then
        goto lbl_976
      end
    end
    var_2_41 = "crackle"
    ::lbl_976::
    if 1 == var_2_35 and "downshift" == tuneLevel and not var_2_38 then
      var_2_41 = "snap"
    end
    var_2_42 = var_2_31[var_2_41]
    if not var_2_42 then
      var_2_42 = 0
    end
    var_2_43 = var_2_42 + 1
    var_2_31[var_2_41] = var_2_43
    var_2_43 = type
    var_2_44 = seed
    var_2_43 = var_2_43(var_2_44)
    if "table" == var_2_43 then
      var_2_43 = seed[var_2_41]
      if var_2_43 then
        goto lbl_999
      end
    end
    var_2_43 = nil
    ::lbl_999::
    var_2_44 = IsFiniteNumber
    var_2_45 = var_2_43
    var_2_44 = var_2_44(var_2_45)
    if var_2_44 and var_2_43 >= 0 then
      var_2_44 = 2147483646
      if var_2_43 <= var_2_44 then
        var_2_44 = var_2_43 % 1
        var_2_44 = var_2_43 or var_2_44
      end
    end
    var_2_44 = flameActive or var_2_44
    if (0 ~= var_2_44 or not var_2_43) and not flameActive then
      var_2_44 = math
      var_2_44 = var_2_44.floor
      var_2_44 = math.floor(ClampNumber(situation, 0, 2147483646, 1))
    end
    var_2_45 = PickSampleStep
    var_2_46 = var_2_41
    var_2_47 = var_2_44 + var_2_42
    var_2_45 = var_2_45(var_2_46, var_2_47)
    if "boom" == var_2_41 then
      var_2_46 = var_2_40 * 120
      var_2_46 = 150 + var_2_46
      var_2_47 = richVal_2
      var_2_47 = var_2_47()
      var_2_47 = var_2_47 * 50
      var_2_46 = var_2_46 + var_2_47
      if var_2_46 then
        goto lbl_1097
      end
    end
    if "bang" == var_2_41 then
      var_2_46 = var_2_40 * 110
      var_2_46 = 110 + var_2_46
      var_2_47 = richVal_2
      var_2_47 = var_2_47()
      var_2_47 = var_2_47 * 45
      var_2_46 = var_2_46 + var_2_47
      if var_2_46 then
        goto lbl_1097
      end
    end
    if "burble" == var_2_41 then
      var_2_46 = var_2_40 * 100
      var_2_46 = 48 + var_2_46
      var_2_47 = richVal_2
      var_2_47 = var_2_47()
      var_2_47 = var_2_47 * 22
      var_2_46 = var_2_46 + var_2_47
      if var_2_46 then
        goto lbl_1097
      end
    end
    if "snap" == var_2_41 then
      var_2_46 = var_2_40 * 47
      var_2_46 = 36 + var_2_46
      var_2_47 = richVal_2
      var_2_47 = var_2_47()
      var_2_47 = var_2_47 * 18
      var_2_46 = var_2_46 + var_2_47
      if var_2_46 then
        goto lbl_1097
      end
    end
    var_2_46 = var_2_40 * 85
    var_2_46 = 45 + var_2_46
    var_2_47 = richVal_2
    var_2_47 = var_2_47()
    var_2_47 = var_2_47 * 25
    var_2_46 = var_2_46 + var_2_47
    ::lbl_1097::
    var_2_47 = RoundNumber
    var_2_48 = ClampNumber
    var_2_49 = var_2_46 * pulseIdx_2
    var_2_50 = 40
    if "antilag" == tuneLevel then
      var_2_51 = 175
      if var_2_51 then
        goto lbl_1108
      end
    end
    var_2_51 = 340
    ::lbl_1108::
    var_2_46 = RoundNumber(ClampNumber(var_2_46 * pulseIdx_2, 40, var_2_51))
    if "antilag" == tuneLevel then
      var_2_46 = math.min(var_2_46, RoundNumber(550 - flameSize_2))
    end
    var_2_49 = richVal_2() * 10 + 6
    if var_2_38 then
      var_2_49 = var_2_49 + 7
    end
    var_2_49 = var_2_49 + (tempThreshold_2 * 3)
    var_2_47 = RoundNumber(ClampNumber(var_2_49, 6, 28))
    var_2_48 = ClampNumber
    var_2_49 = stepVal_2 * 0.047
    var_2_50 = 1.13
    var_2_49 = var_2_50 - var_2_49
    var_2_50 = richVal_2
    var_2_50 = var_2_50()
    var_2_50 = var_2_50 - 0.5
    var_2_50 = var_2_50 * 0.34
    var_2_49 = var_2_49 + var_2_50
    var_2_50 = isBrutal_2.rpmNow
    var_2_50 = var_2_50 - 0.55
    var_2_50 = var_2_50 * 0.12
    var_2_49 = var_2_49 + var_2_50
    if var_2_38 then
      var_2_50 = 0.12
      if var_2_50 then
        goto lbl_1174
      end
    end
    var_2_50 = 0
    ::lbl_1174::
    var_2_49 = var_2_49 - var_2_50
    if var_2_39 then
      var_2_50 = 0.03
      if var_2_50 then
        goto lbl_1182
      end
    end
    var_2_50 = 0
    ::lbl_1182::
    var_2_49 = var_2_49 - var_2_50
    if curPhrase_2 then
      var_2_50 = 0.03
      if var_2_50 then
        goto lbl_1190
      end
    end
    var_2_50 = 0
    ::lbl_1190::
    var_2_49 = var_2_49 - var_2_50
    var_2_50 = isBrutal_2.damaged
    var_2_50 = var_2_50 * 0.05
    var_2_49 = var_2_49 - var_2_50
    var_2_50 = 0.73
    var_2_51 = 1.24
    var_2_48 = var_2_48(var_2_49, var_2_50, var_2_51)
    var_2_49 = ClampNumber
    if var_2_39 then
      var_2_50 = 0.8
      if var_2_50 then
        goto lbl_1217
      end
    end
    if var_2_38 then
      var_2_50 = 0.82
      if var_2_50 then
        goto lbl_1217
      end
    end
    if "crackle" == var_2_41 then
      var_2_50 = 1.1
      if var_2_50 then
        goto lbl_1217
      end
    end
    var_2_50 = 0.96
    ::lbl_1217::
    var_2_51 = richVal_2
    var_2_51 = var_2_51()
    var_2_51 = var_2_51 - 0.5
    var_2_51 = var_2_51 * 0.12
    var_2_50 = var_2_50 + var_2_51
    var_2_51 = isBrutal_2.soak
    var_2_51 = var_2_51 - 0.5
    var_2_51 = var_2_51 * 0.2
    var_2_50 = var_2_50 + var_2_51
    var_2_51 = isBrutal_2.damaged
    var_2_51 = var_2_51 * 0.12
    var_2_50 = var_2_50 - var_2_51
    var_2_51 = 0.7
    var_2_52 = 1.25
    var_2_49 = var_2_49(var_2_50, var_2_51, var_2_52)
    var_2_50 = ClampNumber
    if var_2_39 then
      var_2_51 = 2.2
      if var_2_51 then
        goto lbl_1257
      end
    end
    if var_2_38 then
      var_2_51 = 1.8
      if var_2_51 then
        goto lbl_1257
      end
    end
    if "burble" == var_2_41 then
      var_2_51 = 0.9
      if var_2_51 then
        goto lbl_1257
      end
    end
    var_2_51 = -0.4
    ::lbl_1257::
    var_2_52 = richVal_2
    var_2_52 = var_2_52()
    var_2_52 = var_2_52 - 0.5
    var_2_52 = var_2_52 * 1.0
    var_2_51 = var_2_51 + var_2_52
    var_2_52 = rpmVal_2 - 0.5
    var_2_52 = var_2_52 * 1.2
    var_2_51 = var_2_51 + var_2_52
    if curPhrase_2 then
      var_2_52 = 0.5
      if var_2_52 then
        goto lbl_1277
      end
    end
    var_2_52 = 0
    ::lbl_1277::
    var_2_51 = var_2_51 + var_2_52
    var_2_52 = -2
    var_2_53 = 4
    var_2_50 = var_2_50(var_2_51, var_2_52, var_2_53)
    if var_2_38 or curPhrase_2 then
      var_2_51 = 1.0
      if var_2_51 then
        goto lbl_1315
      end
    end
    if "crackle" == var_2_41 then
      var_2_51 = richVal_2
      var_2_51 = var_2_51()
      var_2_51 = var_2_51 * 0.12
      var_2_51 = 0.66 + var_2_51
      if var_2_51 then
        goto lbl_1315
      end
    end
    if "burble" == var_2_41 then
      var_2_51 = richVal_2
      var_2_51 = var_2_51()
      var_2_51 = var_2_51 * 0.16
      var_2_51 = 0.82 + var_2_51
      if var_2_51 then
        goto lbl_1315
      end
    end
    var_2_51 = richVal_2
    var_2_51 = var_2_51()
    var_2_51 = var_2_51 * 0.15
    var_2_51 = 0.79 + var_2_51
    ::lbl_1315::
    var_2_52 = ClampNumber
    if var_2_39 then
      var_2_53 = 1.08
      if var_2_53 then
        goto lbl_1334
      end
    end
    if var_2_38 then
      var_2_53 = 1.03
      if var_2_53 then
        goto lbl_1334
      end
    end
    if "stutter" == pulseKind_2 or "volley" == pulseKind_2 then
      var_2_53 = 0.67
      if var_2_53 then
        goto lbl_1334
      end
    end
    var_2_53 = 0.82
    ::lbl_1334::
    var_2_54 = richVal_2
    var_2_54 = var_2_54()
    var_2_54 = var_2_54 - 0.5
    var_2_54 = var_2_54 * 0.1
    var_2_53 = var_2_53 + var_2_54
    var_2_54 = 0.5
    var_2_55 = 1.15
    var_2_52 = var_2_52(var_2_53, var_2_54, var_2_55)
    var_2_53 = pulseList_2 * var_2_40
    if var_2_39 then
      var_2_54 = 1.8
      if var_2_54 then
        goto lbl_1358
      end
    end
    if var_2_38 then
      var_2_54 = 1.45
      if var_2_54 then
        goto lbl_1358
      end
    end
    var_2_54 = 0.85
    ::lbl_1358::
    var_2_53 = var_2_53 * var_2_54
    var_2_54 = richVal_2
    var_2_54 = var_2_54()
    var_2_54 = var_2_54 * 0.4
    var_2_54 = 0.8 + var_2_54
    var_2_53 = var_2_53 * var_2_54
    var_2_53 = var_2_53 * pitchVal_2
    var_2_54 = #durationMs_2
    var_2_54 = var_2_54 + 1
    var_2_55 = {}
    var_2_56 = RoundNumber
    var_2_57 = flameSize_2
    var_2_56 = var_2_56(var_2_57)
    var_2_55.delay = var_2_56
    var_2_55.soundDelayMs = var_2_47
    var_2_55.durationMs = var_2_46
    var_2_55.energy = var_2_40
    var_2_55.heavy = var_2_38
    var_2_55.pitch = var_2_48
    var_2_55.kind = var_2_41
    var_2_55.phrase = pulseKind_2
    var_2_55.sampleIndex = var_2_45
    var_2_55.tone = var_2_49
    var_2_55.bodyDb = var_2_50
    var_2_55.tail = var_2_51
    var_2_55.echoScale = var_2_52
    var_2_55.scale = var_2_53
    if "antilag" ~= tuneLevel then
      var_2_56 = ExpandCombustionPhrase
      var_2_57 = richVal_2
      var_2_58 = var_2_41
      var_2_56 = var_2_56(var_2_57, var_2_58)
      if var_2_56 then
        goto lbl_1402
      end
    end
    var_2_56 = {}
    ::lbl_1402::
    var_2_55.layers = var_2_56
    durationMs_2[var_2_54] = var_2_55
    if var_2_35 < pulseEnergy_2 then
      var_2_54 = nil
      if "upshift" == tuneLevel then
        var_2_54 = 43 + (richVal_2() * 37)
      elseif "antilag" == tuneLevel then
        if "sparse" == pulseKind_2 then
          var_2_54 = 100 + (richVal_2() * 40)
        elseif "bang_tail" == pulseKind_2 then
          if 1 == var_2_35 then
            var_2_54 = 110 + (richVal_2() * 25)
          else
            var_2_54 = 80 + (richVal_2() * 15)
          end
        elseif var_2_38 then
          var_2_54 = 70 + (richVal_2() * 24)
        elseif "stutter" == pulseKind_2 then
          var_2_54 = 35 + (richVal_2() * 17) + (var_2_35 % 3 == 0 and 18 or 0)
        else
          var_2_54 = 45 + (richVal_2() * 30)
        end
      elseif "limiter" == tuneLevel then
        var_2_54 = 44 + (richVal_2() * 32)
      elseif "double_pop" == pulseKind_2 then
        var_2_54 = 47 + (richVal_2() * 69)
      elseif "double_bang" == pulseKind_2 then
        var_2_54 = 140 + (richVal_2() * 130)
      elseif "triple_bang" == pulseKind_2 then
        var_2_54 = 150 + (richVal_2() * 110)
      elseif "pop_bang" == pulseKind_2 then
        var_2_54 = 60 + (richVal_2() * 50)
      elseif "volley" == pulseKind_2 then
        var_2_54 = 26 + (richVal_2() * 16)
      elseif "lazy" == pulseKind_2 then
        var_2_54 = 80 + (var_2_36 * 140) + (richVal_2() * 40)
      elseif "cough" == pulseKind_2 then
        var_2_54 = 120 + (richVal_2() * 200)
      elseif "crackle_burst" == pulseKind_2 then
        var_2_54 = 26 + (richVal_2() * 30) + (var_2_35 % 4 == 0 and 40 or 0)
      elseif "bang_crackle" == pulseKind_2 then
        if 1 == var_2_35 then
          var_2_54 = 90 + (richVal_2() * 60)
        else
          var_2_54 = 30 + (richVal_2() * 40)
        end
      elseif "salvo" == pulseKind_2 then
        if 1 == var_2_35 then
          var_2_54 = 90 + (richVal_2() * 60)
        elseif var_2_35 == pulseEnergy_2 - 1 then
          var_2_54 = 110 + (richVal_2() * 70)
        else
          var_2_54 = 30 + (richVal_2() * 40)
        end
      elseif "stutter" == pulseKind_2 then
        var_2_54 = 32 + (richVal_2() * 35) + (var_2_35 % 3 == 0 and 37 or 0)
      elseif "bang_tail" == pulseKind_2 then
        if 1 == var_2_35 then
          var_2_54 = 120 + (richVal_2() * 80)
        else
          var_2_54 = 80 + (richVal_2() * 60)
        end
      elseif "sparse" == pulseKind_2 then
        var_2_54 = 165 + (richVal_2() * 110)
      else
        if var_2_35 > 1 then
          var_2_54 = 30 + (richVal_2() * 33)
        else
          var_2_54 = 58 + (richVal_2() * 70) + (var_2_36 * 32)
        end
      end
      local maxFlame = 830
      if "antilag" == tuneLevel then
        maxFlame = 450
      elseif entryVal_2 > 0 then
        maxFlame = 640
      end
      flameSize_2 = math.min(maxFlame - ((pulseEnergy_2 - var_2_35 - 1) * 30), flameSize_2 + (var_2_54 * isHeavy_2))
    end
  end
  var_2_32 = PopsValve
  var_2_32 = var_2_32.Pulses
  var_2_33 = durationMs_2
  var_2_34 = fuelVal_2.valveClosed
  var_2_35 = tuneLevel
  var_2_36 = eventType
  return var_2_32(var_2_33, var_2_34, var_2_35, var_2_36)
end
PopsCombustion.Build = BuildCombustionPulses
return PopsCombustion
--fivevault-6EOnwuTopDN : https://discord.gg/fivevault
--fivevault4jOnVUTopM2 : https://discord.gg/fivevault
--fivevault_BTOnSdTop_C : https://discord.gg/fivevault
--fivevaults1SOn7cTopcS : https://discord.gg/fivevault
--fivevault!GOnuuTop-6 : https://discord.gg/fivevault
