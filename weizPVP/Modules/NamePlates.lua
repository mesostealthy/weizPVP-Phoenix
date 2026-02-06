---------------------------------------------------------------------------------------------------
--|> NAMEPLATES
-- 📌 Manages the name plates of players
---------------------------------------------------------------------------------------------------
local _, NS = ...

--: Libraries :------------------------
local RAC = LibStub("LibRaces-1.0")

--: ⬆️ Upvalues :--
local select = select
local GetTime = GetTime
local issecretvalue = issecretvalue
local GetScoreInfo = C_PvP.GetScoreInfo
local GetZonePVPInfo = C_PvP.GetZonePVPInfo
local GetNamePlates = C_NamePlate.GetNamePlates
local GetActiveMatchState = C_PvP.GetActiveMatchState
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitCanAttack, UnitIsEnemy = UnitCanAttack, UnitIsEnemy
local UnitClassBase, UnitRace, UnitSex = UnitClassBase, UnitRace, UnitSex
local UnitIsMercenary, UnitTokenFromGUID = UnitIsMercenary, UnitTokenFromGUID
local InCombatLockdown, IsInRaid, UnitIsSameServer = InCombatLockdown, IsInRaid, UnitIsSameServer
local UnitExists, UnitIsPlayer, UnitGUID, UnitName = UnitExists, UnitIsPlayer, UnitGUID, UnitName
local UnitFactionGroup, GetGuildInfo, UnitHonorLevel = UnitFactionGroup, GetGuildInfo, UnitHonorLevel
local GetNumBattlefieldScores, GetRaidRosterInfo = GetNumBattlefieldScores, GetRaidRosterInfo
local GetInspectSpecialization, GetSpecializationInfoByID = GetInspectSpecialization, GetSpecializationInfoByID
local GetPlayerInfoByGUID, NotifyInspect = GetPlayerInfoByGUID, NotifyInspect
local RequestBattlefieldScoreData = RequestBattlefieldScoreData

-- : load libraries
local SM = LibStub:GetLibrary("LibSharedMedia-3.0")

-- : customizations
NS.ButtonHeight = 22
NS.ButtonWidth = 150
NS.NumPerColumn = 10

-- : globals
NS.NPC = {}
NS.PSC = {}
NS.mainAssist = nil
NS.NotifyInspectCache = {}

--|> find player from PSC
function NS.FindPlayerFromPSC(C, RC, HL)
	-- : process all
	for GUID, data in pairs(NS.PSC) do
		-- : valid class match?
		local matched = 0
		if data.C and data.C == C then
			-- : matched!
			matched = matched + 1
		end

		-- : valid race match?
		if data.RC and data.RC == RC then
			-- : matched!
			matched = matched + 1
		end

		-- : valid honor level match?
		if data.HL and data.HL == HL then
			-- : matched!
			matched = matched + 1
		end

		-- : enough matches?
		if matched >= 3 then
			-- : return GUID
			return GUID
		end
	end
	return nil
end

--|> calculate PID
function NS.CalculatePID(classID, raceID, factionID, rankID, sexID, honorLevel)
	-- : missing class or honor level?
	if not classID or not honorLevel then
		-- : failed
		return nil
	end

	-- : missing faction?
	if not factionID then
		-- : force 0 for now
		factionID = 0
	end

	-- : missing race?
	if not raceID then
		-- : force 0 for now
		raceID = 0
	end

	-- : missing rank?
	if not rankID then
		-- : force 0 for now
		rankID = 0
	end

	-- : missing sex?
	if not sexID then
		-- : force 0 for now
		sexID = 0
	end

	-- : calulate PID
	local PID =
		classID * 268435456 +		-- 0x10000000
		raceID * 1048576 +		-- 0x00100000
		factionID * 262144 +		-- 0x00040000
		sexID * 65536 +			-- 0x00010000
		rankID * 4096 +			-- 0x00001000
		honorLevel
	return PID
end

--|>  is valid unit token
function NS.IsValidUnitToken(unit)
	-- : exists?
	if not UnitExists(unit) then
		-- : failed
		return nil
	end

	-- : not player?
	if not UnitIsPlayer(unit) then
		-- : failed
		return nil
	end

	-- : not an enemy player?
	if not UnitCanAttack("player", unit) and not UnitIsEnemy("player", unit) then
		-- : failed
		return nil
	end

	-- : success
	return true
end

--|> get player id by unit
function NS.GetPlayerIDByUnit(unit)
	-- : valid unit?
	if not NS.IsValidUnitToken(unit) then
		-- : failed
		return nil
	end

	-- : check guid
	local PlayerID = nil
	local guid = UnitGUID(unit)
	if not guid then
		-- : failed
		return nil
	elseif not issecretvalue(guid) then
		-- : set PlayerID
		PlayerID = "G:" .. guid
	else
		-- : check name
		local name, realm = UnitName(unit)
		if not name then
			-- : failed
			return nil
		elseif not issecretvalue(name) then
			-- : same server as player?
			if UnitIsSameServer(unit) then
				-- : set PlayerID
				PlayerID = "N:" .. name .. "-" .. NS.PlayerRealm
			else
				-- : set PlayerID
				PlayerID = "N:" .. name .. "-" .. realm
			end
		end
	end

	-- : not found yet?
	if not PlayerID then
		-- : calculate PID
		local sexID = UnitSex(unit)
		local level = UnitLevel(unit)
		local _, raceName, raceID = UnitRace(unit)
		local className, classID = UnitClassBase(unit)
		local honorLevel = UnitHonorLevel(unit)
		local factionID = UnitFactionGroup(unit) == "Alliance" and 1 or 0
		local guildName, rankName, rankID, guildRealm = GetGuildInfo(unit)
		local PID = NS.CalculatePID(classID, raceID, factionID, rankID, sexID, honorLevel)
		PlayerID = "P:" .. PID
	end

	-- : return PlayerID
	return PlayerID
end

--|> get unit player data
function NS.GetUnitPlayerData(unit)
	-- : valid unit?
	if not NS.IsValidUnitToken(unit) then
		-- : failed
		return nil
	end

	-- : check guid
	local PlayerID = nil
	local guid = UnitGUID(unit)
	if not guid then
		-- : failed
		return nil
	elseif not issecretvalue(guid) then
		-- : set PlayerID
		PlayerID = "G:" .. guid
	else
		-- : check name
		local name, realm = UnitName(unit)
		if not name then
			-- : failed
			return nil
		elseif not issecretvalue(name) then
			-- : same server as player?
			if UnitIsSameServer(unit) then
				-- : set PlayerID
				PlayerID = "N:" .. name .. "-" .. NS.PlayerRealm
			else
				-- : set PlayerID
				PlayerID = "N:" .. name .. "-" .. realm
			end
		end
	end

	-- : not cached?
	if not PlayerID or not NS.NPC[PlayerID] then
		-- : calculate PID
		local sexID = UnitSex(unit)
		local level = UnitLevel(unit)
		local _, raceName, raceID = UnitRace(unit)
		local className, classID = UnitClassBase(unit)
		local honorLevel = UnitHonorLevel(unit)
		local factionID = UnitFactionGroup(unit) == "Alliance" and 1 or 0
		local guildName, rankName, rankID, guildRealm = GetGuildInfo(unit)
		local PID = NS.CalculatePID(classID, raceID, factionID, rankID, sexID, honorLevel)
		if not PlayerID then
			-- : set PlayerID
			PlayerID = "P:" .. PID
		end

		-- : unit is mercenary?
		if UnitIsMercenary(unit) then
			-- : swap factionID
			if factionID == 1 then
				factionID = 0
			else
				factionID = 1
			end
		end

		-- : still not found?
		if not NS.NPC[PlayerID] then
			-- : check name
			local name, realm = UnitName(unit)
			if not name then
				-- : failed
				return nil
			end

			-- : same server as player?
			local fullName
			if UnitIsSameServer(unit) then
				-- : finalize
				realm = nil
				fullName = name .. "-" .. NS.PlayerRealm
			-- : has realm?
			elseif realm then
				-- : finalize name
				fullName = name .. "-" .. realm
			end

			-- : create nameplate cache
			local player = name
			NS.NPC[PlayerID] = {}
			NS.NPC[PlayerID].PID = PlayerID
			NS.NPC[PlayerID].guid = guid
			NS.NPC[PlayerID].name = name
			NS.NPC[PlayerID].realm = realm
			NS.NPC[PlayerID].player = player
			NS.NPC[PlayerID].fullName = fullName
			NS.NPC[PlayerID].C = className
			NS.NPC[PlayerID].CID = classID
			NS.NPC[PlayerID].F = factionID
			NS.NPC[PlayerID].G = guildName
			NS.NPC[PlayerID].HL = honorLevel
			NS.NPC[PlayerID].L = level
			NS.NPC[PlayerID].R = rankID
			NS.NPC[PlayerID].RC = raceName
			NS.NPC[PlayerID].RID = raceID
			NS.NPC[PlayerID].RL = NS.ClassRoleAssign(className)
			NS.NPC[PlayerID].S = sexID

			-- : no GUID?
			if not NS.NPC[PlayerID].GUID then
				-- : find player from PSC
				local GUID = NS.FindPlayerFromPSC(className, raceName, honorLevel)
				if GUID then
					-- : save data
					NS.NPC[PlayerID].realGUID = NS.PSC[GUID].realGUID
					NS.NPC[PlayerID].realName = NS.PSC[GUID].realName
					NS.NPC[PlayerID].macrotext = NS.PSC[GUID].macrotext

					-- : role needed?
					if not NS.NPC[PlayerID].RL and NS.PSC[GUID].RL then
						-- : save role
						NS.NPC[PlayerID].RL = NS.PSC[GUID].RL
					end
				end
			end
		end
	end

	-- : not secret full name?
	local player = NS.NPC[PlayerID].name
	if not issecretvalue(player) then
		-- : save / update data
		NS.PlayerDB[player] = NS.PlayerDB[player] or {}
		NS.PlayerDB[player].C = NS.NPC[PlayerID].C
		NS.PlayerDB[player].CID = NS.NPC[PlayerID].CID
		NS.PlayerDB[player].F = NS.NPC[PlayerID].F
		NS.PlayerDB[player].G = NS.NPC[PlayerID].G
		NS.PlayerDB[player].HL = NS.NPC[PlayerID].HL
		NS.PlayerDB[player].L = NS.NPC[PlayerID].L
		NS.PlayerDB[player].R = NS.NPC[PlayerID].R
		NS.PlayerDB[player].RC = NS.NPC[PlayerID].RC
		NS.PlayerDB[player].RID = NS.NPC[PlayerID].RID
		NS.PlayerDB[player].S = NS.NPC[PlayerID].S
		NS.PlayerDB[player].T = GetTime()

		-- : non secret guid?
		if not issecretvalue(guid) then
			-- : save guid
			NS.PlayerDB[player].guid = guid
		end

		-- : has database role?
		if NS.PlayerDB[player].RL then
			-- : not estimated
			NS.NPC[PlayerID].RL = NS.PlayerDB[player].RL
			NS.PlayerDB[player].E = nil

			-- : notify pending?
			if NS.NotifyInspectCache[PlayerID] then
				-- : delete
				NS.NotifyInspectCache[PlayerID] = nil
			end
		else
			-- : can not guess from damage only roles?
			NS.PlayerDB[player].RL = NS.ClassRoleAssign(NS.PlayerDB[player].C)
			if not NS.PlayerDB[player].RL then
				-- : not already notified?
				if not NS.NotifyInspectCache[PlayerID] then
					-- : not in combat?
					if not InCombatLockdown() then
						-- : not mouseover
						if unit ~= "mouseover" then
							-- : can inspect?
							if CanInspect(unit) then
								-- : estimated / inspect GUID
								NS.PlayerDB[player].E = true
								NotifyInspect(unit)
								NS.NotifyInspectCache[PlayerID] = player
							end
						end
					end
				end
			end
		end
	end

	-- : final try for role
	if not NS.NPC[PlayerID].RL and NS.NPC[PlayerID].C then
		-- : check damage only roles
		NS.NPC[PlayerID].RL = NS.ClassRoleAssign(NS.NPC[PlayerID].C)
	end

	-- : main assist?
	if NS.mainAssist then
		-- : target main assist's target
		NS.NPC[PlayerID].macrotext = "/assist [nodead] " .. NS.mainAssist
	elseif NS.NPC[PlayerID].realName and not issecretvalue(NS.NPC[PlayerID].realName) then
		-- : target real name
		NS.NPC[PlayerID].macrotext = "/target " .. NS.NPC[PlayerID].realName
	end

	-- : return data
	NS.NPC[PlayerID].T = GetTime()
	return NS.NPC[PlayerID]
end

--|> setup bar macrotext
function NS.SetupBarMacrotext(i, data)
	-- : not in combat?
	if (not InCombatLockdown()) then
		-- : has main assist?
		local macrotext = nil
		if NS.mainAssist then
			-- : target main assist's target
			macrotext = "/assist [nodead] " .. NS.mainAssist
		elseif data.player and not issecretvalue(data.player) then
			-- : target player by name
			macrotext = "/target " .. data.player
		elseif data.realName and not issecretvalue(data.realName) then
			-- : target player by real name
			macrotext = "/target " .. data.realName
		elseif data.macrotext and not issecretvalue(data.macrotext) then
			-- : already has macrotext
			macrotext = data.macrotext
		end

		-- : found macrotext?
		if macrotext then
			-- : not added / updated?
			if not NS.weizPVP_Frame.Bars[i].macrotext or (NS.weizPVP_Frame.Bars[i].macrotext ~= macrotext) then
				-- : set attributes
				NS.weizPVP_Frame.Bars[i].macrotext = macrotext
				NS.weizPVP_Frame.Bars[i]:SetAttribute("type1", "macro")
				NS.weizPVP_Frame.Bars[i]:SetAttribute("macrotext1", macrotext)
				NS.weizPVP_Frame.Bars[i]:EnableMouse(true)
			end
		else
			-- : set attributes
			NS.weizPVP_Frame.Bars[i].macrotext = nil
			NS.weizPVP_Frame.Bars[i]:SetAttribute("type1", "macro")
			NS.weizPVP_Frame.Bars[i]:SetAttribute("macrotext1", "")
			NS.weizPVP_Frame.Bars[i]:EnableMouse(false)
		end
	end
end

--|> refresh frame list
function NS.RefreshFrameList()
	-- : pre-process
	local activeList = {}
	for k,v in pairs(NS.NPC) do
		-- : player on bars?
		if NS.PlayersOnBars[k] then
			-- : add active
			table.insert(activeList, k)
		end
	end

	-- : hide previous bars
	for k,v in pairs(NS.weizPVP_Frame.Bars) do
		-- : hide
		NS.weizPVP_Frame.Bars[k].hidden = true
		NS.weizPVP_Frame.Bars[k]:Hide()
	end

	-- : process active list
	local numPlayers = 0
	local left, top = 0, 0
	for i, PID in ipairs(activeList) do
		-- : setup bar
		NS.weizPVP_Frame.Bars[i] = NS.weizPVP_Frame.Bars[i] or CreateFrame("Button", nil, NS.weizPVP_Frame, "InsecureActionButtonTemplate")
		NS.weizPVP_Frame.Bars[i]:RegisterForClicks("AnyDown", "AnyUp")
		NS.weizPVP_Frame.Bars[i]:SetSize(NS.ButtonWidth, NS.ButtonHeight)
		NS.weizPVP_Frame.Bars[i]:SetPoint("LEFT", left, top - NS.ButtonHeight - 2)
		NS.weizPVP_Frame.Bars[i].bg = NS.weizPVP_Frame.Bars[i].bg or NS.weizPVP_Frame.Bars[i]:CreateTexture(nil, "BACKGROUND")
		NS.weizPVP_Frame.Bars[i].bg:SetAllPoints()
		NS.weizPVP_Frame.Bars[i].Name = NS.weizPVP_Frame.Bars[i].Name or NS.weizPVP_Frame.Bars[i]:CreateFontString(nil, "ARTWORK", nil, 2)
		NS.weizPVP_Frame.Bars[i].Name:SetFont(SM:Fetch("font", "Roboto Condensed BoldItalic"), 12, "OUTLINE")
		NS.weizPVP_Frame.Bars[i].Name:SetJustifyH("LEFT")
		NS.weizPVP_Frame.Bars[i].Name:SetPoint("LEFT", 2, 0)
		NS.weizPVP_Frame.Bars[i].Name:SetSize(NS.ButtonWidth - 5, NS.ButtonHeight)
		NS.weizPVP_Frame.Bars[i].Name:SetTextColor(1, 1, 1, 1)
		NS.weizPVP_Frame.Bars[i].Name:SetWordWrap(false)

		-- : update bar
		local data = NS.NPC[PID]
		local color = RAID_CLASS_COLORS[data.C] or { 0, 0, 0 }
		NS.weizPVP_Frame.Bars[i].bg:SetColorTexture(color.r, color.g, color.b, 1)
		NS.weizPVP_Frame.Bars[i].Name:SetText(data.fullName)
		NS.weizPVP_Frame.Bars[i].PID = PID
		NS.NPC[PID].BarID = i
		NS.SetupBarMacrotext(i, data)

		-- : show
		NS.weizPVP_Frame.Bars[i].hidden = nil
		NS.weizPVP_Frame.Bars[i]:Show()

		-- : next
		top = top - NS.ButtonHeight
		numPlayers = numPlayers + 1
	end

	-- update count
	NS.weizPVP_Frame.Header:SetText(numPlayers .. " Enemies")
end

--|> refresh name plate list
function NS.RefreshNamePlateList()
	-- : process all
	local timestamp = GetTime()
	for PID, data in pairs(NS.NPC) do
		-- : inactive?
		if (timestamp - data.T) > NS.Options.Sorting.NearbyActiveTimeout then
			-- : delete
			NS.NPC[PID] = nil
		else
			-- : update player active cache
			NS.UpdatePlayerActiveCache(data.PID, data.name, nil)
		end
	end

	-- : update target
	NS.UpdateNamePlateUnit("target")
end

--|> refresh all nameplates
function NS.RefreshAllNamePlates()
	-- : get all nameplates
	local nameplates = GetNamePlates()
	for _, np in ipairs(nameplates) do
		-- : has PID?
		local PID = np.PID
		if not PID then
			-- : try by unit
			PID = NS.GetPlayerIDByUnit(np.namePlateUnitToken)
		end

		-- : found?
		if PID and NS.NPC[PID] then
			-- : update player active cache
			np.PID = PID
			local data = NS.NPC[PID]
			NS.UpdatePlayerActiveCache(data.PID, data.name, nil)

			-- : has unit?
			if np.namePlateUnitToken then
				-- : validate player active cache
				NS.ValidatePlayerActiveCache(np.namePlateUnitToken, data.PID)
			end
		else
			-- : delete
			if NS.NPC[PID] then
				NS.NPC[PID] = nil
			end
			np.PID = nil
		end
	end

	-- : refresh frame list
	NS.RefreshFrameList()
end

--|> update unit
function NS.UpdateNamePlateUnit(unit)
	-- : exists?
	if UnitExists(unit) then
		-- : get unit player data
		local data = NS.GetUnitPlayerData(unit)
		if data then
			-- : get name plate
			local np = GetNamePlateForUnit(unit)
			if np then
				-- : save data
				np.PID = data.PID
			end

			-- : update player cache
			NS.UpdatePlayerActiveCache(data.PID, data.name, nil)
			NS.ValidatePlayerActiveCache(unit, data.PID)

			-- : refresh frame list
			NS.RefreshFrameList()
		end
	end
end

--|> update group roles
function NS.UpdateGroupRoles()
	-- : has community flare?
	if CommunityFlare_GetMainAssist then
		-- : check for main assist
		NS.mainAssist = CommunityFlare_GetMainAssist()
		if not NS.mainAssist and CommunityFlare_GetMainTank then
			-- : check for main tank
			NS.mainAssist = CommunityFlare_GetMainTank()
		end

		-- : main assist found?
		if NS.mainAssist then
			-- : not in combat lockdown?
			if not InCombatLockdown() then
				-- : process all
				local macrotext = "/assist [nodead] " .. NS.mainAssist
				for k = 1, NS.Options.Bars.MaxNumBars do
					-- : not set?
					if not NS.CoreUI.Bar[k].macrotext or (NS.CoreUI.Bar[k].macrotext ~= macrotext) then
						-- : enable
						NS.CoreUI.Bar[k].macrotext = macrotext
						NS.CoreUI.Bar[k].Button:RegisterForClicks("AnyUp", "AnyDown")
						NS.CoreUI.Bar[k].Button:SetAttribute("type1", "macro")
						NS.CoreUI.Bar[k].Button:SetAttribute("macrotext1", macrotext)
						NS.CoreUI.Bar[k].Button:EnableMouse(true)
					end
				end
			end
		end
	end
end

--|> update battlefield score
function NS.UpdateBattlefieldScore()
	-- : scoreboard secret when inside PvP content?
	local parse = true
	if (NS.BuildVersion >= 120001) then
		-- : check match state
		local state = GetActiveMatchState()
		if state == Enum.PvPMatchState.Engaged then
			-- : do not parse
			parse = false
		end
	end

	-- : should parse?
	if parse == true then
		-- : process all
		local currentTime = GetTime()
		for i = 1, GetNumBattlefieldScores() do
			-- : get score info
			local info = GetScoreInfo(i)
			if info and info.name and info.guid then
				-- : not intialized?
				if not NS.PSC[info.guid] then
					-- : create
					NS.PSC[info.guid] = {}

					-- : get role
					local role = "UNKNOWN"
					if info.talentSpec then
						role = NS.GetRoleFromSpecialization(info.talentSpec)
					elseif info.roleAssigned == 2 then
						role = "TANK"
					elseif info.roleAssigned == 4 then
						role = "HEALER"
					end

					-- : save stuff
					local sexID = select(5, GetPlayerInfoByGUID(info.guid))
					local classID = NS.GetClassIDFromName(info.classToken)
					local raceName = RAC:GetRaceToken(info.raceName) or nil
					NS.PSC[info.guid].realGUID = info.guid
					NS.PSC[info.guid].realName = info.name
					NS.PSC[info.guid].C = info.classToken
					NS.PSC[info.guid].CID = classID
					NS.PSC[info.guid].F = info.faction
					NS.PSC[info.guid].HL = info.honorLevel
					NS.PSC[info.guid].RC = raceName
					NS.PSC[info.guid].RL = role
					NS.PSC[info.guid].S = sexID
					NS.PSC[info.guid].T = currentTime

					-- : main assist?
					if NS.mainAssist then
						-- : target main assist's target
						NS.PSC[info.guid].macrotext = "/assist [nodead] " .. NS.mainAssist
					elseif info.name and not issecretvalue(info.name) then
						-- : target name
						NS.PSC[info.guid].macrotext = "/target " .. info.name
					end
				end

				-- : save current info (for debugging)
				NS.PSC[info.guid].info = info
			end
		end
	end
end

--|> OnEvent
local function OnEvent(self, event, ...)
	-- : inspect ready?
	if event == "INSPECT_READY" then
		-- : get unit token from GUID
		local GUID = ...
		local player = nil
		local PlayerID = nil
		local unitToken = UnitTokenFromGUID(GUID)
		if unitToken then
			-- : get inspect specialization ID
			local specID = GetInspectSpecialization(unitToken)
			if specID then
				-- : get role
				local _, _, _, _, Role = GetSpecializationInfoByID(specID)
				if Role then
					-- : get PID
					local PID = NS.GetPlayerIDByUnit(unitToken)
					if NS.NotifyInspectCache[PID] then
						-- : finally get the role
						player = NS.NotifyInspectCache[PID]
						PlayerID = PID
					end
				end

				-- : found player
				if player and PlayerID then
					-- : save role
					NS.PlayerDB[player].RL = Role
					NS.PlayerDB[player].E = nil
		
					-- : clear notify inspect
					NS.NotifyInspectCache[PlayerID] = nil

					-- : player on bars?
					if NS.PlayersOnBars[PlayerID] then
						-- : refresh bar by PID
						NS.PlayerActiveCache[PlayerID].RL = Role
						NS.RefreshBarByPID(PlayerID)
					else
						-- : refresh current list
						NS.RefreshCurrentList()
					end

					-- : tooltip shown?
					if weizPVP_CoreTooltip:IsShown() then
						-- : update tooltip
						NS.ShowPlayerTooltip(PlayerID)
					end
				end
			end
		end

		-- : reset?
		if not player or not PlayerID then
			-- : reset
			NS.NotifyInspectCache = {}
		end
	-- : name plate unit added?
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		-- : update unit
		local unitToken = ...
		NS.UpdateNamePlateUnit(unitToken)
	-- : name plate unit removed?
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		-- : get name plate
		local unitToken = ...
		local np = GetNamePlateForUnit(unitToken)
		if np and np.PID then
			-- : delete
			NS.NPC[np.PID] = nil
			np.PID = nil

			-- : refresh frame list
			NS.RefreshFrameList()
		end
	-- : player entering battleground
	elseif event == "PLAYER_ENTERING_BATTLEGROUND" then
		-- : request battlefield score data
		RequestBattlefieldScoreData()
	-- : player entering world?
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- : has window position?
		_weizpvp_global_settings = _weizpvp_global_settings or {}
		if (_weizpvp_global_settings.WindowPosition) then
			-- : calculate position
			local height = _weizpvp_global_settings.WindowPosition.height or NS.ButtonHeight
			local left = _weizpvp_global_settings.WindowPosition.left or 0
			local scale = _weizpvp_global_settings.WindowPosition.scale or 1
			local top =  _weizpvp_global_settings.WindowPosition.top or 0
			local width = _weizpvp_global_settings.WindowPosition.width or NS.ButtonWidth
			if (height < NS.ButtonHeight) then height = NS.ButtonHeight end
			if (width < NS.ButtonWidth) then width = NS.ButtonWidth end

			-- : move window
			NS.weizPVP_Frame:ClearAllPoints()
			NS.weizPVP_Frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
			NS.weizPVP_Frame:SetWidth(width / scale)
			NS.weizPVP_Frame:SetHeight(height / scale)
		end

		-- : reset / refresh
		NS.NPC = {}
		NS.UpdateGroupRoles()
		NS.RefreshFrameList()
	-- : player logout?
	elseif event == "PLAYER_LOGOUT" then
		-- : get position
		local scale = NS.weizPVP_Frame:GetScale()
		local left, top = NS.weizPVP_Frame:GetLeft() * scale, NS.weizPVP_Frame:GetTop() * scale
		local width, height = NS.weizPVP_Frame:GetWidth() * scale, NS.weizPVP_Frame:GetHeight() * scale
		if (height > NS.ButtonHeight) then height = NS.ButtonHeight end
		if (width > NS.ButtonWidth) then width = NS.ButtonWidth end

		-- : save settings
		_weizpvp_global_settings = _weizpvp_global_settings or {}
		_weizpvp_global_settings.WindowPosition = { height = height, left = left, scale = scale, top = top, width = width }
	-- : player roles changed?
	elseif event == "PLAYER_ROLES_ASSIGNED" then
		-- : update group roles
		NS.UpdateGroupRoles()
	-- : player target changed?
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- : update target
		NS.UpdateNamePlateUnit("target")
	-- : pvp match state changed?
	elseif event == "PVP_MATCH_STATE_CHANGED" then
		-- : request battlefield score data
		RequestBattlefieldScoreData()
	-- : update battlefield score
	elseif event == "UPDATE_BATTLEFIELD_SCORE" then
		-- : update battlefield score
		NS.UpdateBattlefieldScore()

		-- : update group roles
		NS.UpdateGroupRoles()
	-- : update mouseover unit
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		-- : update mouseover
		NS.UpdateNamePlateUnit("mouseover")
	-- : zone changed
	elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
		-- : reset / refresh
		NS.NPC = {}
		NS.RefreshFrameList()
	end
end

-- : create frame
NS.weizPVP_Frame = CreateFrame("Frame", nil, UIParent)
NS.weizPVP_Frame.Bars = {}
NS.weizPVP_Frame:SetSize(NS.ButtonWidth, NS.ButtonHeight)
NS.weizPVP_Frame:SetPoint("CENTER", 0, 0)
NS.weizPVP_Frame.bg = NS.weizPVP_Frame:CreateTexture(nil, "BACKGROUND")
NS.weizPVP_Frame.bg:SetAllPoints()
NS.weizPVP_Frame.bg:SetColorTexture(0, 0, 0, 1)
NS.weizPVP_Frame:SetMovable(true)
NS.weizPVP_Frame:EnableMouse(true)
NS.weizPVP_Frame:RegisterForDrag("LeftButton")
NS.weizPVP_Frame.Header = NS.weizPVP_Frame:CreateFontString(nil, "ARTWORK", nil, 2)
NS.weizPVP_Frame.Header:SetFont(SM:Fetch("font", "Roboto Condensed BoldItalic"), 12, "OUTLINE")
NS.weizPVP_Frame.Header:SetPoint("LEFT", NS.weizPVP_Frame, "LEFT", 2, 0)
NS.weizPVP_Frame.Header:SetSize(NS.ButtonWidth, NS.ButtonHeight)
NS.weizPVP_Frame.Header:SetTextColor(1, 1, 1, 1)
NS.weizPVP_Frame.Header:SetJustifyH("LEFT")
NS.weizPVP_Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
NS.weizPVP_Frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
NS.weizPVP_Frame.Events = CreateFrame("Frame", nil, NS.weizPVP_Frame)
NS.weizPVP_Frame.Events:RegisterEvent("INSPECT_READY")
NS.weizPVP_Frame.Events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
NS.weizPVP_Frame.Events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
NS.weizPVP_Frame.Events:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
NS.weizPVP_Frame.Events:RegisterEvent("PLAYER_ENTERING_WORLD")
NS.weizPVP_Frame.Events:RegisterEvent("PLAYER_LOGOUT")
NS.weizPVP_Frame.Events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
NS.weizPVP_Frame.Events:RegisterEvent("PLAYER_TARGET_CHANGED")
NS.weizPVP_Frame.Events:RegisterEvent("PVP_MATCH_STATE_CHANGED")
NS.weizPVP_Frame.Events:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
NS.weizPVP_Frame.Events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
NS.weizPVP_Frame.Events:RegisterEvent("ZONE_CHANGED")
NS.weizPVP_Frame.Events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
NS.weizPVP_Frame.Events:SetScript("OnEvent", OnEvent)
NS.weizPVP_Frame:Hide()
