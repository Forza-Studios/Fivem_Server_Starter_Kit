if not UseBridge('clothing', 'qb-clothing') then return end

function ResetSkin(model, skin)
    TriggerEvent('qb-clothing:client:loadSkin', false, model, skin)
end

function OpenClothingMenu()
    TriggerEvent('qb-clothing:client:openMenu')
end
