local modPath = '/mods/Notify/'

local originalCreateUI = CreateUI

function CreateUI(isReplay, parent)
    originalCreateUI(isReplay)
    import(modPath .. "modules/notify.lua").init(isReplay, import('/lua/ui/game/borders.lua').GetMapGroup())
end