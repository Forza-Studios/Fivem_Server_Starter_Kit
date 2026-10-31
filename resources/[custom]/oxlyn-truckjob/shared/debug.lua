Debug = Debug or {}

local PREFIX = "[oxlyn-truckjob]"

-- Convert every argument to a string and join them with spaces
local function joinArgs(args)
  local parts = {}
  for i = 1, #args do
    parts[i] = tostring(args[i])
  end
  return table.concat(parts, " ")
end

-- Only prints when Config.Debug is enabled
function Debug.info(...)
  if Config and Config.Debug then
    print(("^5%s^7 %s"):format(PREFIX, joinArgs({ ... })))
  end
end

function Debug.warn(...)
  print(("^3%s^7 %s"):format(PREFIX, joinArgs({ ... })))
end

function Debug.error(...)
  print(("^1%s ERROR^7 %s"):format(PREFIX, joinArgs({ ... })))
end

-- Only prints when Config.Debug is enabled
function Debug.section(title)
  if not (Config and Config.Debug) then
    return
  end
  print(("^5%s ── %s ──^7"):format(PREFIX, tostring(title)))
end