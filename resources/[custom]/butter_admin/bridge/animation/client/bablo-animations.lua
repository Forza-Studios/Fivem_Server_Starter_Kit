if not UseBridge('animation', 'bablo-animations') then return end

---@return table
function GetAnimationList()
    local ok, animations = pcall(function()
        return exports['bablo-animations']:getAnimations()
    end)
    return ok and type(animations) == 'table' and animations or {}
end
