local modPath = '/mods/Notify/'
local EnhanceCommon = import('/lua/enhancementcommon.lua')
local FindClients = import('/lua/ui/game/chat.lua').FindClients
local RegisterChatFunc = import('/lua/ui/game/gamemain.lua').RegisterChatFunc

local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local UIUtil = import('/lua/ui/uiutil.lua')

local enhancementQueue = {}

local acu
local watch_enhancements = {}

local watchThread = nil

local overlays = {}

function init(isReplay, parent)
	
end

function formatTime(time)
	return string.format("%.2d:%.2d", time/60, math.mod(time, 60))
end

function round(num, idp)
	if(not idp) then
		return tonumber(string.format("%." .. (idp or 0) .. "f", num))
	else
  		local mult = 10^(idp or 0)
		return math.floor(num * mult + 0.5) / mult
  	end
end

function getEnhancementQueue()
	return enhancementQueue
end

function enqueueEnhancement(units, enhancement)
    local enhancements = units[1]:GetBlueprint().Enhancements

    if(enhancements[enhancement]) then
        for _, u in units do
            local id = u:GetEntityId()
            if not enhancementQueue[id] then
                enhancementQueue[id] = {}
            end

            found = false
            for k, v in enhancementQueue[id] do
                if(enhancement == v.Enhancement) then
                    found = true
                end
            end

            if not found then
                table.insert(enhancementQueue[id], enhancements[enhancement])
                
            end
        end        

		import('/lua/ui/game/construction.lua').checkEnhancementTab()
    end
end

function NotifyStartEnhancement(unit, enhancement)
	local valid = {ResourceAllocation = "RAS", ResourceAllocationAdvanced = "ARAS"}

	if(valid[enhancement.ID] and not watch_enhancements[enhancement.ID]) then
		acu = unit
		local enhancements = EnhanceCommon.GetEnhancements(acu:GetEntityId()) or {}
		local exists = {}

		for _, e in enhancements do
			exists[e] = true
		end

		if(exists[enhancement.ID] or exists['ResourceAllocationAdvanced']) then
			return
		end

		enhancement.Name = valid[enhancement.ID]
		enhancement.notified = false
		if(enhancement.Name == 'ARAS' and not exists['ResourceAllocation'] and not watch_enhancements['ResourceAllocation']) then
			local ras = unit:GetBlueprint().Enhancements['ResourceAllocation']
			ras.notified = true
			ras.Name = valid[ras.ID]
			watch_enhancements[ras.ID] = ras

			enhancement.Name = 'RAS+ARAS'
		end

		watch_enhancements[enhancement.ID] = enhancement
		
		if not watchThread then
			ForkThread(CheckEnhancement)
		end
	end
end

function CheckEnhancement() 
	local done = false
	local start = GetGameTimeSeconds()

	while(table.getsize(watch_enhancements) > 0) do
		if(acu:IsDead()) then 
			watch_enhancements = {}
		else 
			local enhancements = EnhanceCommon.GetEnhancements(acu:GetEntityId())
			local eco = acu:GetEconData()
			
			for id, e in watch_enhancements do
				if(enhancements[e.Slot] == e.ID) then
					watch_enhancements[id] = nil
					
					msg = { to = 'allies', Chat = true, text = e.Name .. " done! (" .. formatTime(GetGameTimeSeconds()) .. ', ' .. round(GetGameTimeSeconds()-start, 2) .. 's)'}
					SessionSendChatMessage(FindClients(), msg)
				--elseif(not acu:GetFocus() and (eco['energyRequested'] > 1000 or GetIsPaused({acu}))) then 
				elseif(not acu:IsIdle() and not acu:GetFocus()) then
					queue = acu:GetCommandQueue()

					if(queue[1] and queue[1]['type'] == 'Script') then
					--if(id == 'ResourceAllocation' or not watch_enhancements['ResourceAllocation'] or enhancements[e.Slot] == 'ResourceAllocation') then
						if(not e.notified) then
							msg = { to = 'allies', Chat = true, text = 'Upgrading ' .. e.Name}
							SessionSendChatMessage(FindClients(), msg)
							e.notified = true
						end
					end
				end
			end

			if(acu:IsIdle()) then
				watch_enhancements = {}
				enhancementQueue[acu:GetEntityId()] = {}
			end
		end

		WaitSeconds(0.2)
	end

	watch_enhancements = {}
end

