local NotifyStartEnhancement = import('/mods/Notify/modules/notify.lua').NotifyStartEnhancement

function checkEnhancementTab()
    if(controls.enhancementTab:IsChecked()) then
	   controls.enhancementTab:SetCheck(true)
    end
end

function OrderEnhancement(item, clean)
	local done = {}
	local orders = {}
	local units = sortedOptions.selection

    for _, u in units do
		local order
		local existingEnhancements = EnhanceCommon.GetEnhancements(u:GetEntityId())

		if existingEnhancements[item.enhTable.Slot] and existingEnhancements[item.enhTable.Slot] ~= item.enhTable.Prerequisite then
			order = existingEnhancements[item.enhTable.Slot]..'Remove'

			if(not done[order]) then
				done[order] = true
				table.insert(orders, order)

			end
		end

        if(clean and not u:IsIdle()) then
            local cmdqueue = u:GetCommandQueue()

            if(cmdqueue and cmdqueue[1] and cmdqueue[1].type == 'Script') then
                clean = false
            end
        end
	end

	if(item.enhTable.Prerequisite) then
		table.insert(orders, item.enhTable.Prerequisite)
	end

	table.insert(orders, item.id)

    local first_order = true
	for _, o in orders do
		order = {TaskName='EnhanceTask', Enhancement=o}
		IssueCommand("UNITCOMMAND_Script", order, clean)
        if(first_order and clean) then
            clean = false
            first_order = false
        end
	end
end

local oldCommonLogic = CommonLogic
function CommonLogic()
	local retval = oldCommonLogic()
	local oldControl = controls.secondaryChoices.SetControlToType

	controls.secondaryChoices.SetControlToType = function(control, type)
		if type == 'enhancement' then
            --local up, down, over, dis = GetEnhancementTextures(control.Data.unitID, control.Data.icon)
            local _,down,over,_,up = GetEnhancementTextures(control.Data.unitID, control.Data.icon)
            control:SetSolidColor('00000000')
            control.Icon:SetSolidColor('00000000')
            control.tooltipID = 'no description'
            --control:SetNewTextures(up, down, over, dis)
            control:SetNewTextures(GetEnhancementTextures(control.Data.unitID, control.Data.icon))
            control.Height:Set(48)
            control.Width:Set(48)
            control.Icon.Width:Set(48)
            control.Icon.Height:Set(48)
            

            control:SetUpAltButtons(up, up, up, up)
            control:Disable()
            control.Height:Set(48)
            control.Width:Set(48)
            control.Icon:Show()
            control:Enable()
        end

        return oldControl(control, type)
	end

    return retval
end

local oldOnClickHandler = OnClickHandler
function OnClickHandler(button, modifiers)
	local item = button.Data
	local unit = sortedOptions.selection[1]

	if item.type == 'enhancement' then
		local existingEnhancements = EnhanceCommon.GetEnhancements(sortedOptions.selection[1]:GetEntityId())
		local clean = not modifiers.Shift
		local doOrder = false

		if existingEnhancements[item.enhTable.Slot] and existingEnhancements[item.enhTable.Slot] ~= item.enhTable.Prerequisite then
			if existingEnhancements[item.enhTable.Slot] ~= item.id then
				UIUtil.QuickDialog(GetFrame(0), "<LOC enhancedlg_0000>Choosing this enhancement will destroy the existing enhancement in this slot.  Are you sure?", 
					"<LOC _Yes>",
					function()
						OrderEnhancement(item, clean)
						end,
						"<LOC _No>", nil,
						nil, nil,
						true,  {worldCover = true, enterButton = 1, escapeButton = 2})
			end
		else
			doOrder = true
		end

		if(doOrder) then
			OrderEnhancement(item, clean)
		end

		if unit:IsInCategory('COMMAND') then
			local enhancement = table.copy(item.enhTable)
			NotifyStartEnhancement(unit, enhancement)
		end

		button.Data.type = 'nil' -- prevent trigger in oldOnClickHandler
	end

	return oldOnClickHandler(button, modifiers)
end

function SetSecondaryDisplay(type)
	local data = {}
	if type == 'buildQueue' then
		if currentCommandQueue and table.getn(currentCommandQueue) > 0 then
			for index, unit in currentCommandQueue do
				table.insert(data, {type = 'queuestack', id = unit.id, count = unit.count, position = index})
			end
		end
		if table.getn(sortedOptions.selection) == 1 and table.getn(data) > 0 then
			controls.secondaryProgress:SetNeedsFrameUpdate(true)
		else
			controls.secondaryProgress:SetNeedsFrameUpdate(false)
			controls.secondaryProgress:SetAlpha(0, true)
		end
	elseif type == 'attached' then
		local attachedUnits = EntityCategoryFilterDown(categories.MOBILE, GetAttachedUnitsList(sortedOptions.selection))
		if attachedUnits and table.getn(attachedUnits) > 0 then
			for _, v in attachedUnits do
				table.insert(data, {type = 'attachedunit', id = v:GetBlueprint().BlueprintId, unit = v})
			end
		end

		controls.secondaryProgress:SetAlpha(0, true)
	elseif type == 'enhQueue' then
		local unit = sortedOptions.selection[1]
		local uid = unit:GetEntityId()
		local queue = import('/mods/Notify/modules/notify.lua').getEnhancementQueue()
		local enhancements = EnhanceCommon.GetEnhancements(uid) or {}
		local exists = {}

		for _, e in enhancements do
			exists[e] = true
		end

		if(unit:IsIdle()) then
			queue[uid] = {}
		end

        if(queue[uid]) then
		  for _, e in queue[uid] do
            if not exists[e.ID] then
                table.insert(data, {type = 'enhancement', unitID = e.UnitID, icon = e.Icon})
                exists[e.ID] = true
                end
            end
        end

		controls.secondaryProgress:SetAlpha(0, true)
	end

	controls.secondaryChoices:Refresh(data)
end

function OnTabCheck(self, checked)
    if self.ID == 'construction' then
        controls.selectionTab:SetCheck(false, true)
        controls.enhancementTab:SetCheck(false, true)
        SetSecondaryDisplay('buildQueue')
    elseif self.ID == 'selection' then
        controls.constructionTab:SetCheck(false, true)
        controls.enhancementTab:SetCheck(false, true)
        controls.choices:Refresh(FormatData(sortedOptions.selection, 'selection'))
        SetSecondaryDisplay('attached')
    elseif self.ID == 'enhancement' then
        controls.selectionTab:SetCheck(false, true)
        controls.constructionTab:SetCheck(false, true)
        SetSecondaryDisplay('enhQueue')
    end
    CreateTabs(self.ID)

    controls.secondaryChoices:CalcVisible()
end

function OnNestedTabCheck(self, checked)
    activeTab = self
    for _, tab in controls.tabs do
        if tab != self then
            tab:SetCheck(false, true)
        end
    end
    controls.choices:Refresh(FormatData(sortedOptions[self.ID], nestedTabKey[self.ID] or self.ID))
    if(controls.constructionTab:IsChecked()) then
        SetSecondaryDisplay('buildQueue')
    end
    if(controls.enhancementTab:IsChecked()) then
        SetSecondaryDisplay('enhQueue')
    end
end

function FormatData(unitData, type)
    local retData = {}
    if type == 'construction' then
        local function SortFunc(unit1, unit2)
            local bp1 = __blueprints[unit1].BuildIconSortPriority or __blueprints[unit1].StrategicIconSortPriority
            local bp2 = __blueprints[unit2].BuildIconSortPriority or __blueprints[unit2].StrategicIconSortPriority
            if bp1 >= bp2 then
                return false
            else
                return true
            end
        end
        local sortedUnits = {}
        local sortCategories = {
            categories.SORTCONSTRUCTION,
            categories.SORTECONOMY,
            categories.SORTDEFENSE,
            categories.SORTSTRATEGIC,
            categories.SORTINTEL,
            categories.SORTOTHER,
        }
        local miscCats = categories.ALLUNITS
        local borders = {}
        for i, v in sortCategories do
            local category = v
            local index = i - 1
            local tempIndex = i
            while index > 0 do
                category = category - sortCategories[index]
                index = index - 1
            end
            local units = EntityCategoryFilterDown(category, unitData)
            table.insert(sortedUnits, units)
            miscCats = miscCats - v
        end
        
        table.insert(sortedUnits, EntityCategoryFilterDown(miscCats, unitData))
        
        for i, units in sortedUnits do
            table.sort(units, SortFunc)
            local index = i
            if table.getn(units) > 0 then
                if table.getn(retData) > 0 then
                    table.insert(retData, {type = 'spacer'})
                end
                for unitIndex, unit in units do
                    table.insert(retData, {type = 'item', id = unit})
                end
            end
        end
        CreateExtraControls('construction')
        SetSecondaryDisplay('buildQueue')
    elseif type == 'selection' then
        local sortedUnits = {}
        local lowFuelUnits = {}
        local ids = {}
        for _, unit in unitData do
            local id = unit:GetBlueprint().BlueprintId

            if unit:IsInCategory('AIR') and unit:GetFuelRatio() < .2 and unit:GetFuelRatio() > -1 then
                if not lowFuelUnits[id] then 
                    table.insert(ids, id)
                    lowFuelUnits[id] = {}
                end
                table.insert(lowFuelUnits[id], unit)
            else
                if not sortedUnits[id] then 
                    table.insert(ids, id)
                    sortedUnits[id] = {}
                end
                table.insert(sortedUnits[id], unit)
            end
        end
        
        local displayUnits = true
        if table.getsize(sortedUnits) == table.getsize(lowFuelUnits) then
            displayUnits = false
            for id, units in sortedUnits do
                if lowFuelUnits[id] and not table.equal(lowFuelUnits[id], units) then
                    displayUnits = true
                    break
                end
            end
        end
        if displayUnits then
            for i, v in sortedUnits do
                table.insert(retData, {type = 'unitstack', id = i, units = v})
            end
        end
        for i, v in lowFuelUnits do
            table.insert(retData, {type = 'unitstack', id = i, units = v, lowFuel = true})
        end
        CreateExtraControls('selection')
        SetSecondaryDisplay('attached')
    elseif type == 'templates' then
        table.sort(unitData, function(a,b)
            if a.key and not b.key then
                return true
            elseif b.key and not a.key then
                return false
            elseif a.key and b.key then
                return a.key <= b.key
            elseif a.name == b.name then
                return false
            else
                if LOC(a.name) <= LOC(b.name) then
                    return true
                else
                    return false
                end
            end
        end)
        for _, v in unitData do
            table.insert(retData, {type = 'templates', id = 'template', template = v})
        end
        CreateExtraControls('templates')
        SetSecondaryDisplay('buildQueue')
    else
        #Enhancements
        local existingEnhancements = EnhanceCommon.GetEnhancements(sortedOptions.selection[1]:GetEntityId())
        local slotToIconName = {
            RCH = 'ra',
            LCH = 'la',
            Back = 'b',
        }
        local filteredEnh = {}
        local usedEnhancements = {}
        local restrictList = EnhanceCommon.GetRestricted()
        for index, enhTable in unitData do
            if not string.find(enhTable.ID, 'Remove') then
                local restricted = false
                for _, enhancement in restrictList do
                    if enhancement == enhTable.ID then
                        restricted = true
                        break
                    end
                end
                if not restricted then
                    table.insert(filteredEnh, enhTable)
                end
            end
        end
        local function GetEnhByID(id)
            for i, enh in filteredEnh do
                if enh.ID == id then
                    return enh
                end
            end
        end
        local function FindDependancy(id)
            for i, enh in filteredEnh do
                if enh.Prerequisite and enh.Prerequisite == id then
                    return enh.ID
                end
            end
        end
        local function AddEnhancement(enhTable, disabled)
            local iconData = {
                type = 'enhancement', 
                enhTable = enhTable, 
                unitID = enhTable.UnitID, 
                id = enhTable.ID,
                icon = enhTable.Icon, 
                Selected = false,
                Disabled = disabled,
            }
            if existingEnhancements[enhTable.Slot] == enhTable.ID then
                iconData.Selected = true
            end
            table.insert(retData, iconData)
        end
        for i, enhTable in filteredEnh do
            if not usedEnhancements[enhTable.ID] and not enhTable.Prerequisite then
                AddEnhancement(enhTable, false)
                usedEnhancements[enhTable.ID] = true
                if FindDependancy(enhTable.ID) then
                    local searching = true
                    local curID = enhTable.ID
                    while searching do
                        table.insert(retData, {type = 'arrow'})
                        local tempEnh = GetEnhByID(FindDependancy(curID))
                        
                        local disabled = false -- allow multi stage upgrades
                        --[[
                        local disabled = true

                        if existingEnhancements[enhTable.Slot] == tempEnh.Prerequisite then
                            disabled = false
                        end
                        ]]
                        AddEnhancement(tempEnh, disabled)
                        usedEnhancements[tempEnh.ID] = true
                        if FindDependancy(tempEnh.ID) then
                            curID = tempEnh.ID
                        else
                            searching = false
                            if table.getsize(usedEnhancements) <= table.getsize(filteredEnh)-1 then
                                table.insert(retData, {type = 'spacer'})
                            end
                        end
                    end
                else
                    if table.getsize(usedEnhancements) <= table.getsize(filteredEnh)-1 then
                        table.insert(retData, {type = 'spacer'})
                    end
                end
            end
        end
        CreateExtraControls('enhancement')
        SetSecondaryDisplay('enhQueue')
    end
    import(UIUtil.GetLayoutFilename('construction')).OnTabChangeLayout(type)
    return retData
end