--|> Player Lists
-- 📌 Manages the lists of players shown
---------------------------------------------------------------------------------------------------

--|> Upvalues Globals
-----------------------------------------------------------
local _, NS = ...

-- ⬆️ Upvalues
-----------------------------------------------------------
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CopyTable = CopyTable
local InCombatLockdown, GetTime = InCombatLockdown, GetTime
local pairs, gsub, wipe = pairs, gsub, wipe
local PixelUtil_SetStatusBarValue = PixelUtil.SetStatusBarValue
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion

-- Locals
-----------------------------------------------------------
local NearbyCountTopColorLimit = 100
local darkenValue = 0.05
local guildTxtLength
local roleIcons = {
	["TANK"] = "Interface/Addons/weizPVP/Media/Roles/tank.tga",
	["DAMAGER"] = "Interface/Addons/weizPVP/Media/Roles/damager.tga",
	["HEALER"] = "Interface/Addons/weizPVP/Media/Roles/healer.tga",
	["UNKNOWN"] = "Interface/Addons/weizPVP/Media/Roles/unknown.tga"
}
local ActiveListCount = 0
local levelText
local MAX_PLAYER_LEVEL = GetMaxLevelForPlayerExpansion()
local lastTimestamp = GetTime()

-- 📛 NAMESPACE
-----------------------------------------------------------
NS.NearbyListSize = 0
NS.CurrentList = {}
NS.NearbyList = {}
NS.ActiveList = {}
NS.InactiveList = {}
NS.ActiveDeadList = {}
NS.InactiveDeadList = {}
NS.PlayersOnBars = {}

-- ⚒️ Update Nearby Count
-----------------------------------------------------------
function NS.UpdateNearbyCount()
	NS.NearbyCount = NS.NearbyListSize
	if NS.NearbyCount < 100 then
		weizPVP_CoreBar.Title:SetText(
			"|cff" ..
			NS.GetColorValueFromGradient(
				(NS.NearbyCount / NearbyCountTopColorLimit),
				0.4,
				1,
				0,
				1,
				0.74,
				0,
				1,
				0.35,
				0,
				1,
				0,
				0.34,
				1,
				0,
				0
			) ..
			NS.NearbyCount .. "|r"
		)
	else
		weizPVP_CoreBar.Title:SetText("|cffff0000" .. NS.NearbyCount .. "|r")
	end
	if NS.NearbyCount <= NS.Options.Bars.MaxNumBars then
		NS.AutoResize()
	end
end

-- ⚒️ Manage Bars Displayed
-----------------------------------------------------------
function NS.ManageBarsDisplayed()
	for i = 1, NS.Options.Bars.MaxNumBars do
		if i > NS.NearbyListSize then
			NS.CoreUI.Bar[i]:SetAlpha(0)
			NS.CoreUI.Bar[i]:SetValue(1)
			NS.CoreUI.Bar[i].DeadIcon:Hide()
			NS.CoreUI.Bar[i].DeadIcon:Hide()
			NS.CoreUI.Bar[i].RoleIcon:SetTexture("Interface/Addons/weizPVP/Media/Icons/unknown.tga", false)
			NS.CoreUI.Bar[i].Name:SetText("")
			NS.CoreUI.Bar[i].Target = ""
			NS.CoreUI.Bar[i].NAME = nil
			NS.CoreUI.Bar[i].displayName = nil
			NS.CoreUI.Bar[i].displayGuild = nil

			-- : not in combat lockdown?
			if not InCombatLockdown() then
				-- : main assist set?
				if NS.mainAssist then
					-- : enable
					NS.CoreUI.Bar[i].Button:EnableMouse(true)
				else
					-- : disable
					NS.CoreUI.Bar[i].macrotext = nil
					NS.CoreUI.Bar[i].Button:SetAttribute("macrotext1", "")
					NS.CoreUI.Bar[i].Button:EnableMouse(false)
				end
			end
		end
	end
	NS.CoreUI.ChangeTargetIcon()
end

-- ⚒️ Manage List Timeouts
-----------------------------------------------------------

function NS.ManageListTimeouts()
	local expired = false
	local removed = false
	local expiredCount = 0
	local count = 1
	local timestamp = GetTime()
	--: ACTIVE
	for PID in pairs(NS.ActiveList) do
		local diff = math.floor(timestamp - NS.ActiveList[PID].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyActiveTimeout then
			NS.InactiveList[PID] = NS.ActiveList[PID]
			NS.InactiveList[PID].TimeAdded = timestamp + (count * 0.001)
			NS.ActiveList[PID] = nil
			count = count + 1
			expired = true
		end
	end
	ActiveListCount = count
	count = 0
	--: ACTIVE DEAD
	timestamp = GetTime()
	for PID in pairs(NS.ActiveDeadList) do
		local diff = math.floor(timestamp - NS.ActiveDeadList[PID].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyActiveTimeout then
			NS.InactiveDeadList[PID] = NS.ActiveDeadList[PID]
			NS.InactiveDeadList[PID].TimeAdded = timestamp + (count * 0.001)
			NS.ActiveDeadList[PID] = nil
			expired = true
			count = count + 1
		end
	end
	--: INACTIVE
	timestamp = GetTime()
	for PID in pairs(NS.InactiveList) do
		local diff = math.floor(timestamp - NS.InactiveList[PID].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyInactiveTimeout then
			NS.InactiveList[PID] = nil
			NS.NearbyList[PID] = nil
			NS.PlayerActiveCache[PID] = nil
			expiredCount = expiredCount + 1
			expired = true
			removed = true
		end
	end
	--: INACTIVE DEAD
	timestamp = GetTime()
	for PID in pairs(NS.InactiveDeadList) do
		local diff = math.floor(timestamp - NS.InactiveDeadList[PID].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyInactiveTimeout then
			NS.InactiveDeadList[PID] = nil
			NS.NearbyList[PID] = nil
			NS.PlayerActiveCache[PID] = nil
			expiredCount = expiredCount + 1
			expired = true
			removed = true
		end
	end
	if expired or removed then
		NS.NearbyListSize = NS.NearbyListSize - expiredCount
		NS.SortNearbyList()
		NS.UpdateNearbyCount()
		NS.RefreshCurrentList()
		NS.CoreUI.ChangeTargetIcon()
	end
	if removed then
		NS.ManageBarsDisplayed()
	end
end

-- ⚒️ FormatLevelString
-----------------------------------------------------------

function NS.FormatLevelString(estimated, level)
	-- input check
	if not level then
		return
	end

	-- Color text based on level difference
	levelText = ""
	if level == 0 then -- 0
		levelText = "|cFFFF00CC??|r"
	elseif level < NS.Player.Level - 20 then -- 20+ below
		levelText = "|cFF7cffd1" .. level .. "|r"
	elseif level < NS.Player.Level - 10 then -- 10-20 below
		levelText = "|cFF7cd1ff" .. level .. "|r"
	elseif level < NS.Player.Level then -- 1-9 below
		levelText = "|cFF7cff7f" .. level .. "|r"
	elseif level > NS.Player.Level then -- Higher level
		levelText = "|cFFf7694a" .. level .. "|r"
	else -- same level
		levelText = "|cFFffc863" .. level .. "|r"
	end

	-- estimated value
	if estimated and level ~= 0 and level ~= MAX_PLAYER_LEVEL then
		levelText = levelText .. "|cFFFF00CC+|r"
	end

	-- returns a formatted string
	return levelText
end

-- ⚒️ Set Bar Target Macrotext
function NS.SetBarTargetMacrotext(barID, PID)
	-- : main assist set?
	if NS.mainAssist then
		-- : finished
		return
	end

	-- : not in combat lockdown?
	if not InCombatLockdown() then
		-- : found bar?
		local NAME = nil
		local macrotext = nil
		local bar = NS.CoreUI.Bar[barID]
		if bar and bar.PID then
			-- : has macro text?
			local data = NS.PlayerActiveCache[bar.PID]
			if data and data.macrotext then
				-- : found
				NAME = data.NAME
				macrotext = data.macrotext
			end
		end

		-- : found macrotext?
		if macrotext then
			-- : needs macrotext?
			if not bar.macrotext or (bar.macrotext ~= macrotext) then
				-- : enabled
				bar.macrotext = macrotext
				bar.Button:RegisterForClicks("AnyUp", "AnyDown")
				bar.Button:SetAttribute("type1", "macro")
				bar.Button:SetAttribute("macrotext1", macrotext)
				bar.Button:EnableMouse(true)
				bar.Target = NAME
			end
		else
			-- : disabled
			bar.macrotext = nil
			bar.Button:RegisterForClicks("AnyUp", "AnyDown")
			bar.Button:SetAttribute("type1", "macro")
			bar.Button:SetAttribute("macrotext1", "")
			bar.Button:EnableMouse(false)
			bar.Target = nil
		end
	end
end

-- ⚒️ Update Bar
-----------------------------------------------------------
local function UpdateBar(num, PID, Alpha, Health, Class, Guild, Level, Estimated, Dead, Role, Name, FormattedName)
	if (not Name) or (not PID) then
		return
	end
	if NS.CoreUI.Bar[num] and PID then
		--: SYNC INFO
		if not issecretvalue(Name) then
			NS.CoreUI.Bar[num].displayName = gsub(Name, "-(.*)", "")
		else
			NS.CoreUI.Bar[num].displayName = Name
		end
		NS.CoreUI.Bar[num].PID = PID
		NS.PlayersOnBars[PID] = num

		--: TARGET MACRO
		NS.SetBarTargetMacrotext(num)

		--: ALPHA SET
		NS.CoreUI.Bar[num].Button:SetAlpha(0.2)
		if Alpha and Alpha ~= 0 then
			NS.CoreUI.Bar[num]:SetAlpha(Alpha)
		else
			NS.CoreUI.Bar[num]:SetAlpha(NS.Options.Bars.AlphaDefault)
		end

		--: KOS ICON
		if not issecretvalue(Name) and NS.KosList[Name] then
			NS.CoreUI.Bar[num].KOSRibbon:Show()
		else
			NS.CoreUI.Bar[num].KOSRibbon:Hide()
		end

		--: NAME TEXT
		if not issecretvalue(Name) then
			local _, realmName = strsplit("-", Name)
			if realmName ~= NS.Player.FromSubRealm then
				NS.CoreUI.Bar[num].Name:SetText(NS.CoreUI.Bar[num].displayName .. "|cFFFF00CC*|r")
			else
				NS.CoreUI.Bar[num].Name:SetText(NS.CoreUI.Bar[num].displayName)
			end
		else
			NS.CoreUI.Bar[num].Name:SetText(NS.CoreUI.Bar[num].displayName)
		end

		--: LEVEL
		NS.CoreUI.Bar[num].Level:SetText(NS.FormatLevelString(Estimated, Level))

		--: CLASS COLOR (BAR COLOR)
		if Class and RAID_CLASS_COLORS[Class] then
			NS.CoreUI.Bar[num]:SetStatusBarColor(
				RAID_CLASS_COLORS[Class].r - darkenValue,
				RAID_CLASS_COLORS[Class].g - darkenValue,
				RAID_CLASS_COLORS[Class].b - darkenValue,
				Alpha
			)
		end
		NS.CoreUI.Bar[num].bg:SetVertexColor(0, 0, 0, 0.5)

		--: HEALTH (BAR VALUE)
		if Health ~= nil then
			NS.CoreUI.Bar[num]:SetValue(Health)
		else
			NS.CoreUI.Bar[num]:SetValue(1)
		end

		--: ROLE
		if Role then
			NS.CoreUI.Bar[num].RoleIcon:SetTexture(roleIcons[Role])
		elseif not issecretvalue(Name) and NS.PlayerDB[Name] and NS.PlayerDB[Name].RL then
			NS.CoreUI.Bar[num].RoleIcon:SetTexture(roleIcons[NS.PlayerDB[Name].RL])
		else
			NS.CoreUI.Bar[num].RoleIcon:SetTexture(roleIcons["UNKNOWN"])
		end

		--: DEAD ICON
		if Dead ~= nil then
			if Dead then
				NS.CoreUI.Bar[num].DeadIcon:Show()
				NS.CoreUI.Bar[num]:SetValue(0)
			elseif not Dead then
				NS.CoreUI.Bar[num].DeadIcon:Hide()
			end
		end

		--: GUILD TEXT
		--guildTxtLength = NS.CoreUI.Bar[num].Level:GetWidth() + NS.CoreUI.Bar[num].Name:GetWidth() + 28
		if NS.CoreUI.Bar[num].DeadIcon:IsShown() then
			--guildTxtLength = guildTxtLength + NS.CoreUI.Bar[num].DeadIcon:GetWidth()
		end
		--guildTxtLength = NS.CoreUI.Bar[num]:GetWidth() - guildTxtLength
		NS.CoreUI.Bar[num].Guild:SetText(Guild)
		--NS.CoreUI.Bar[num].Guild:SetWidth(guildTxtLength)
		NS.CoreUI.Bar[num]:SetAlpha(NS.Options.Bars.AlphaDefault)
	end
end

-- ⚒️ Update Player List
-----------------------------------------------------------
function NS.UpdatePlayerLists(PID, timeUpdate, dead, newPlayerOnList)
	if not NS.Options.Bars then
		return
	end

	local reSortList = false
	local playerOnBar = true
	if NS.NearbyListSize <= NS.Options.Bars.MaxNumBars then
		if dead or newPlayerOnList then
			reSortList = true
		end
	else
		if NS.PlayersOnBars[PID] ~= nil then
			if dead then
				reSortList = true
			end
		end
	end

	-- NEW PLAYER
	if NS.NearbyList[PID] == nil or newPlayerOnList then -- ADDING NEW PLAYER
		playerOnBar = false
		reSortList = true

		--: Alerts: KOS or 'New Detection'
		if not issecretvalue(NS.PlayerActiveCache[PID].Name) then
			if NS.KosList[NS.PlayerActiveCache[PID].Name] then
				NS.KOSAlert(PID)
			else
				--: New player detected
				NS.NewPlayerAlert()
			end
		else
			--: New player detected
			NS.NewPlayerAlert()
		end

		NS.NearbyList[PID] = {}
		NS.NearbyList[PID].TimeUpdated = timeUpdate
		NS.NearbyList[PID].TimeAdded = timeUpdate
		if dead then
			NS.ActiveDeadList[PID] = NS.ActiveDeadList[PID] or {}
			NS.ActiveDeadList[PID].TimeUpdated = timeUpdate
			NS.ActiveDeadList[PID].TimeAdded = timeUpdate
		else
			NS.ActiveList[PID] = NS.ActiveList[PID] or {}
			NS.ActiveList[PID].TimeAdded = timeUpdate
			NS.ActiveList[PID].TimeUpdated = timeUpdate
		end
	elseif not NS.ActiveList[PID] and not NS.ActiveDeadList[PID] then -- EXISTING PLAYER; WAS INACTIVE
		reSortList = true
		if dead then
			NS.ActiveDeadList[PID] = NS.InactiveDeadList[PID] or {}
			NS.ActiveDeadList[PID].TimeUpdated = timeUpdate
			NS.ActiveDeadList[PID].TimeAdded = timeUpdate
			NS.NearbyList[PID].TimeUpdated = timeUpdate
			NS.NearbyList[PID].TimeAdded = timeUpdate
			NS.ActiveList[PID] = nil
		else
			NS.ActiveList[PID] = NS.InactiveList[PID] or {}
			NS.ActiveList[PID].TimeUpdated = timeUpdate
			NS.ActiveList[PID].TimeAdded = timeUpdate
			NS.NearbyList[PID].TimeUpdated = timeUpdate
			NS.NearbyList[PID].TimeAdded = timeUpdate
			NS.ActiveDeadList[PID] = nil
		end
		NS.InactiveList[PID] = nil
		NS.InactiveDeadList[PID] = nil
	else -- EXISTING PLAYER; ACTIVE
		if dead then
			NS.ActiveDeadList[PID] = NS.ActiveDeadList[PID] or {}
			NS.ActiveDeadList[PID].TimeUpdated = timeUpdate
			NS.NearbyList[PID].TimeUpdated = timeUpdate
			NS.ActiveList[PID] = nil
		else
			NS.ActiveList[PID] = NS.ActiveList[PID] or {}
			NS.ActiveList[PID].TimeUpdated = timeUpdate
			NS.NearbyList[PID].TimeUpdated = timeUpdate
			NS.ActiveDeadList[PID] = nil
		end
	end
	-- Check to see if we need to add a kos player to the bars
	if not playerOnBar and ActiveListCount > NS.Options.Bars.MaxNumBars then
		if not NS.KosList[NS.PlayerActiveCache[PID].Name] then
			return
		else
			reSortList = true
			newPlayerOnList = true
		end
	end
	-- Sort only if we moved the player from one sub-list to another
	if reSortList then
		NS.SortNearbyList()
		if NS.PlayersOnBars[PID] or newPlayerOnList then
			NS.RefreshCurrentList()
		end
	else
		if NS.PlayersOnBars[PID] then
			NS.RefreshBarByPID(PID)
		end
	end
end

-- ⚒️ Add Player Data
-----------------------------------------------------------
local timeGotten = GetTime()
local dead = false
function NS.AddPlayerDataToNearby(PID, newPlayerOnList)
	if not PID then
		return
	end
	dead = false
	if NS.PlayerActiveCache[PID] and NS.PlayerActiveCache[PID].Dead ~= nil then
		dead = NS.PlayerActiveCache[PID].Dead
	else
		NS.PlayerActiveCache[PID].Dead = false
	end
	timeGotten = GetTime()
	if lastTimestamp >= timeGotten then
		lastTimestamp = lastTimestamp + 0.0001
	else
		lastTimestamp = timeGotten
	end
	if newPlayerOnList then
		NS.NearbyListSize = NS.NearbyListSize + 1
		NS.UpdateNearbyCount()
	end
	NS.UpdatePlayerLists(PID, lastTimestamp, dead, newPlayerOnList)
end

-- ⚒️ Refresh Current List
-----------------------------------------------------------
local alphaCurrentList
local localPlayersOnBars = {}
function NS.RefreshCurrentList()
	-- Refreshing all bars due to required sorting
	localPlayersOnBars = {}
	for k, data in pairs(NS.CurrentList) do
		if k <= NS.Options.Bars.MaxNumBars then
			-- Update Alpha if needed
			local PID = data.PID
			alphaCurrentList = NS.Options.Bars.AlphaDefault or 1
			if NS.InactiveList[PID] or NS.InactiveDeadList[PID] then
				alphaCurrentList = NS.Options.Bars.AlphaInactive
			elseif NS.ActiveDeadList[PID] then
				alphaCurrentList = NS.Options.Bars.AlphaDead
			end
			if NS.PlayerActiveCache[PID] then
				localPlayersOnBars[NS.PlayerActiveCache[PID].PID] = k
				if not NS.PlayerActiveCache[PID].Name then
					return
				end
				-- Update Bar
				UpdateBar(
					k,
					PID,
					alphaCurrentList,
					NS.PlayerActiveCache[PID].Health,
					NS.PlayerActiveCache[PID].C,
					NS.PlayerActiveCache[PID].displayGuild,
					NS.PlayerActiveCache[PID].L,
					NS.PlayerActiveCache[PID].E,
					NS.PlayerActiveCache[PID].Dead,
					NS.PlayerActiveCache[PID].RL,
					NS.PlayerActiveCache[PID].Name,
					NS.PlayerActiveCache[PID].displayName
				)
			end
		else
			break
		end
	end
	NS.PlayersOnBars = CopyTable(localPlayersOnBars)
end

-- ⚒️ Clear List Dat
-----------------------------------------------------------a
function NS.ClearListData()
	if NS.NearbyCount ~= 0 then
		wipe(NS.CurrentList)
		wipe(NS.NearbyList)
		wipe(NS.ActiveList)
		wipe(NS.InactiveList)
		wipe(NS.ActiveDeadList)
		wipe(NS.InactiveDeadList)
		wipe(NS.PlayersOnBars)
		wipe(NS.PlayerActiveCache)
		NS.NearbyListSize = 0
		NS.SortNearbyList()
		NS.ManageBarsDisplayed()
		NS.RefreshCurrentList()
		NS.UpdateNearbyCount()
		weizPVP_CoreFrame.ScrollFrame:SetVerticalScroll(0)
		NS.AutoResize()
		NS.UpdateNamePlateUnit("target")
		NS.CoreUI.ChangeTargetIcon()
	end
end

-- ⚒️ Refresh One Bar
-----------------------------------------------------------
local alpha = 1
function NS.RefreshBarByPID(PID)
	--: sanity checks
	if not PID or not NS.PlayersOnBars[PID] or not NS.PlayerActiveCache[PID].Name then
		return
	end

	--: Alpha
	alpha = 1
	if not NS.Options.Bars then
		alpha = 1
	end

	if NS.Options.Bars then
		alpha = NS.Options.Bars.AlphaDefault
	end

	if NS.InactiveList[PID] or NS.InactiveDeadList[PID] then
		alpha = NS.Options.Bars.AlphaInactive or 0.6
	end

	if NS.ActiveDeadList[PID] then
		alpha = NS.Options.Bars.AlphaDead or 0.8
	end

	-- Update Bar
	UpdateBar(
		NS.PlayersOnBars[PID],
		PID,
		alpha,
		NS.PlayerActiveCache[PID].Health,
		NS.PlayerActiveCache[PID].C,
		NS.PlayerActiveCache[PID].displayGuild,
		NS.PlayerActiveCache[PID].L,
		NS.PlayerActiveCache[PID].E,
		NS.PlayerActiveCache[PID].Dead,
		NS.PlayerActiveCache[PID].RL,
		NS.PlayerActiveCache[PID].Name,
		NS.PlayerActiveCache[PID].displayName
	)
end
