if not UseBridge('clothing', 'illenium-appearance') then return end

function ResetSkin()
    TriggerEvent('illenium-appearance:client:reloadSkin')
end

function OpenClothingMenu()
    exports['illenium-appearance']:startPlayerCustomization(function() end)
end
