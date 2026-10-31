if not UseBridge('animation', 'bablo-animations') then return end

---@param target number
---@param animation string
---@return boolean
function PlayAnimation(target, animation)
    return pcall(function()
        exports['bablo-animations']:playAnimation(target, animation)
    end)
end
