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
local C_ClassColor_GetClassColor = C_ClassColor.GetClassColor
local InCombatLockdown, GetTime = InCombatLockdown, GetTime
local pairs, gsub, wipe = pairs, gsub, wipe
local PixelUtil_SetStatusBarValue = PixelUtil.SetStatusBarValue
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion

-- Locals
-----------------------------------------------------------
local NearbyCountTopColorLimit = 100
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
	-- : process all bars
	for i=1, NS.Options.Bars.MaxNumBars do
		-- : bar not nearby?
		if i > NS.NearbyListSize then
			NS.CoreUI.Bar[i]:SetAlpha(0)
			NS.CoreUI.Bar[i]:SetValue(1)
			NS.CoreUI.Bar[i].DeadIcon:Hide()
			NS.CoreUI.Bar[i].DeadIcon:Hide()
			NS.CoreUI.Bar[i].RoleIcon:SetTexture("Interface/Addons/weizPVP/Media/Icons/unknown.tga", false)
			NS.CoreUI.Bar[i].Name:SetText("")
			NS.CoreUI.Bar[i].Target = ""
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
	for playerToken in pairs(NS.ActiveList) do
		local diff = math.floor(timestamp - NS.ActiveList[playerToken].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyActiveTimeout then
			NS.InactiveList[playerToken] = NS.ActiveList[playerToken]
			NS.InactiveList[playerToken].TimeAdded = timestamp + (count * 0.001)
			NS.ActiveList[playerToken] = nil
			count = count + 1
			expired = true
		end
	end
	ActiveListCount = count
	count = 0
	--: ACTIVE DEAD
	timestamp = GetTime()
	for playerToken in pairs(NS.ActiveDeadList) do
		local diff = math.floor(timestamp - NS.ActiveDeadList[playerToken].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyActiveTimeout then
			NS.InactiveDeadList[playerToken] = NS.ActiveDeadList[playerToken]
			NS.InactiveDeadList[playerToken].TimeAdded = timestamp + (count * 0.001)
			NS.ActiveDeadList[playerToken] = nil
			expired = true
			count = count + 1
		end
	end
	--: INACTIVE
	timestamp = GetTime()
	for playerToken in pairs(NS.InactiveList) do
		local diff = math.floor(timestamp - NS.InactiveList[playerToken].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyInactiveTimeout then
			NS.InactiveList[playerToken] = nil
			NS.NearbyList[playerToken] = nil
			NS.PlayerActiveCache[playerToken] = nil
			expiredCount = expiredCount + 1
			expired = true
			removed = true
		end
	end
	--: INACTIVE DEAD
	timestamp = GetTime()
	for playerToken in pairs(NS.InactiveDeadList) do
		local diff = math.floor(timestamp - NS.InactiveDeadList[playerToken].TimeUpdated)
		if diff > NS.Options.Sorting.NearbyInactiveTimeout then
			NS.InactiveDeadList[playerToken] = nil
			NS.NearbyList[playerToken] = nil
			NS.PlayerActiveCache[playerToken] = nil
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
function NS.SetBarTargetMacrotext(barID, playerToken)
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
		if bar and bar.playerToken then
			-- : has macro text?
			local data = NS.PlayerActiveCache[bar.playerToken]
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
local function UpdateBar(num, playerToken, Alpha, Health, Class, Guild, Level, Estimated, Dead, Role, Name, FormattedName)
	if not Name or not playerToken then
		return
	end
	if NS.CoreUI.Bar[num] and playerToken then
		--: SYNC INFO
		NS.CoreUI.Bar[num].Class = Class
		NS.CoreUI.Bar[num].playerToken = playerToken
		NS.PlayersOnBars[playerToken] = num

		--: TARGET MACRO
		NS.SetBarTargetMacrotext(num)

		--: ALPHA SET
		NS.CoreUI.Bar[num].Button:SetAlpha(0.2)
		if Alpha and Alpha ~= 0 then
			NS.CoreUI.Bar[num]:SetAlpha(Alpha)
		else
			NS.CoreUI.Bar[num]:SetAlpha(NS.Options.Bars.AlphaDefault)
		end

		--: NAME TEXT
		NS.CoreUI.Bar[num].displayName = NS.PlayerActiveCache[playerToken].name
		NS.CoreUI.Bar[num].Name:SetText(NS.CoreUI.Bar[num].displayName)

		--: GUILD TEXT
		NS.CoreUI.Bar[num].displayGuild = NS.PlayerActiveCache[playerToken].G
		NS.CoreUI.Bar[num].Guild:SetText(NS.CoreUI.Bar[num].displayGuild)

		--: KOS ICON
		if not issecretvalue(fullName) and NS.KosList[fullName] then
			NS.CoreUI.Bar[num].KOSRibbon:Show()
		else
			NS.CoreUI.Bar[num].KOSRibbon:Hide()
		end

		--: LEVEL
		NS.CoreUI.Bar[num].Level:SetText(NS.FormatLevelString(Estimated, Level))

		--: CLASS COLOR (BAR COLOR)
		local classColor = C_ClassColor_GetClassColor(Class)
		NS.CoreUI.Bar[num]:SetStatusBarColor(
			classColor.r,
			classColor.g,
			classColor.b,
			Alpha
		)
		NS.CoreUI.Bar[num].bg:SetVertexColor(0, 0, 0, 0.5)

		--: HEALTH (BAR VALUE)
		if Health ~= nil then
			NS.CoreUI.Bar[num]:SetValue(Health)
		else
			NS.CoreUI.Bar[num]:SetValue(1)
		end

		--: ROLE
		if Role and not issecretvalue(Role) then
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
	end
end

-- ⚒️ Update Player List
-----------------------------------------------------------
function NS.UpdatePlayerLists(playerToken, timeUpdate, dead, newPlayerOnList)
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
		if NS.PlayersOnBars[playerToken] ~= nil then
			if dead then
				reSortList = true
			end
		end
	end

	-- NEW PLAYER
	if NS.NearbyList[playerToken] == nil or newPlayerOnList then -- ADDING NEW PLAYER
		playerOnBar = false
		reSortList = true

		--: Alerts: KOS or 'New Detection'
		if not issecretvalue(NS.PlayerActiveCache[playerToken].fullName) then
			if NS.KosList[NS.PlayerActiveCache[playerToken].fullName] then
				NS.KOSAlert(playerToken)
			else
				--: New player detected
				NS.NewPlayerAlert()
			end
		else
			--: New player detected
			NS.NewPlayerAlert()
		end

		NS.NearbyList[playerToken] = {}
		NS.NearbyList[playerToken].TimeUpdated = timeUpdate
		NS.NearbyList[playerToken].TimeAdded = timeUpdate
		if dead then
			NS.ActiveDeadList[playerToken] = NS.ActiveDeadList[playerToken] or {}
			NS.ActiveDeadList[playerToken].TimeUpdated = timeUpdate
			NS.ActiveDeadList[playerToken].TimeAdded = timeUpdate
		else
			NS.ActiveList[playerToken] = NS.ActiveList[playerToken] or {}
			NS.ActiveList[playerToken].TimeAdded = timeUpdate
			NS.ActiveList[playerToken].TimeUpdated = timeUpdate
		end
	elseif not NS.ActiveList[playerToken] and not NS.ActiveDeadList[playerToken] then -- EXISTING PLAYER; WAS INACTIVE
		reSortList = true
		if dead then
			NS.ActiveDeadList[playerToken] = NS.InactiveDeadList[playerToken] or {}
			NS.ActiveDeadList[playerToken].TimeUpdated = timeUpdate
			NS.ActiveDeadList[playerToken].TimeAdded = timeUpdate
			NS.NearbyList[playerToken].TimeUpdated = timeUpdate
			NS.NearbyList[playerToken].TimeAdded = timeUpdate
			NS.ActiveList[playerToken] = nil
		else
			NS.ActiveList[playerToken] = NS.InactiveList[playerToken] or {}
			NS.ActiveList[playerToken].TimeUpdated = timeUpdate
			NS.ActiveList[playerToken].TimeAdded = timeUpdate
			NS.NearbyList[playerToken].TimeUpdated = timeUpdate
			NS.NearbyList[playerToken].TimeAdded = timeUpdate
			NS.ActiveDeadList[playerToken] = nil
		end
		NS.InactiveList[playerToken] = nil
		NS.InactiveDeadList[playerToken] = nil
	else -- EXISTING PLAYER; ACTIVE
		if dead then
			NS.ActiveDeadList[playerToken] = NS.ActiveDeadList[playerToken] or {}
			NS.ActiveDeadList[playerToken].TimeUpdated = timeUpdate
			NS.NearbyList[playerToken].TimeUpdated = timeUpdate
			NS.ActiveList[playerToken] = nil
		else
			NS.ActiveList[playerToken] = NS.ActiveList[playerToken] or {}
			NS.ActiveList[playerToken].TimeUpdated = timeUpdate
			NS.NearbyList[playerToken].TimeUpdated = timeUpdate
			NS.ActiveDeadList[playerToken] = nil
		end
	end
	-- Check to see if we need to add a kos player to the bars
	if not playerOnBar and ActiveListCount > NS.Options.Bars.MaxNumBars then
		if not NS.KosList[NS.PlayerActiveCache[playerToken].name] then
			return
		else
			reSortList = true
			newPlayerOnList = true
		end
	end
	-- Sort only if we moved the player from one sub-list to another
	if reSortList then
		NS.SortNearbyList()
		if NS.PlayerActiveCache[playerToken] or newPlayerOnList then
			NS.RefreshCurrentList()
		end
	else
		if NS.PlayerActiveCache[playerToken] or newPlayerOnList then
			NS.RefreshBarByPlayerToken(playerToken)
		end
	end
end

-- ⚒️ Add Player Data
-----------------------------------------------------------
local timeGotten = GetTime()
local dead = false
function NS.AddPlayerDataToNearby(playerToken, newPlayerOnList)
	if not playerToken then
		return
	end
	dead = false
	if NS.PlayerActiveCache[playerToken] and NS.PlayerActiveCache[playerToken].Dead ~= nil then
		dead = NS.PlayerActiveCache[playerToken].Dead
	else
		NS.PlayerActiveCache[playerToken].Dead = false
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
	NS.UpdatePlayerLists(playerToken, lastTimestamp, dead, newPlayerOnList)
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
			local playerToken = data.playerToken
			alphaCurrentList = NS.Options.Bars.AlphaDefault or 1
			if NS.InactiveList[playerToken] or NS.InactiveDeadList[playerToken] then
				alphaCurrentList = NS.Options.Bars.AlphaInactive
			elseif NS.ActiveDeadList[playerToken] then
				alphaCurrentList = NS.Options.Bars.AlphaDead
			end
			if NS.PlayerActiveCache[playerToken] then
				localPlayersOnBars[playerToken] = k
				if not NS.PlayerActiveCache[playerToken].name then
					return
				end
				-- Update Bar
				UpdateBar(
					k,
					playerToken,
					alphaCurrentList,
					NS.PlayerActiveCache[playerToken].Health,
					NS.PlayerActiveCache[playerToken].C,
					NS.PlayerActiveCache[playerToken].G,
					NS.PlayerActiveCache[playerToken].L,
					NS.PlayerActiveCache[playerToken].E,
					NS.PlayerActiveCache[playerToken].Dead,
					NS.PlayerActiveCache[playerToken].RL,
					NS.PlayerActiveCache[playerToken].name,
					NS.PlayerActiveCache[playerToken].displayName
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
function NS.RefreshBarByPlayerToken(playerToken)
	--: sanity checks
	if not playerToken or not NS.PlayerActiveCache[playerToken].name then
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

	if NS.InactiveList[playerToken] or NS.InactiveDeadList[playerToken] then
		alpha = NS.Options.Bars.AlphaInactive or 0.6
	end

	if NS.ActiveDeadList[playerToken] then
		alpha = NS.Options.Bars.AlphaDead or 0.8
	end

	-- Update Bar
	UpdateBar(
		NS.PlayersOnBars[playerToken],
		playerToken,
		alpha,
		NS.PlayerActiveCache[playerToken].Health,
		NS.PlayerActiveCache[playerToken].C,
		NS.PlayerActiveCache[playerToken].G,
		NS.PlayerActiveCache[playerToken].L,
		NS.PlayerActiveCache[playerToken].E,
		NS.PlayerActiveCache[playerToken].Dead,
		NS.PlayerActiveCache[playerToken].RL,
		NS.PlayerActiveCache[playerToken].name,
		NS.PlayerActiveCache[playerToken].displayName
	)
end
