local oldOnCommandIssued = OnCommandIssued

function OnCommandIssued(command)
	if(command.CommandType == 'Script' and command.LuaParams and command.LuaParams.Enhancement and not string.find(command.LuaParams.Enhancement, 'Remove')) then
		local enqueueEnhancement = import('/mods/Notify/modules/notify.lua').enqueueEnhancement
		enqueueEnhancement(command.Units, command.LuaParams.Enhancement)
	end

	oldOnCommandIssued(command)
end
