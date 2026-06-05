---------------------------------------------------------------------------------------------------
--|> NAMEPLATES
-- 📌 Manages the name plates of players
---------------------------------------------------------------------------------------------------
local _, NS = ...
weizNS = NS

-- : Libraries :------------------------
local RAC = LibStub("LibRaces-1.0")
local SM = LibStub:GetLibrary("LibSharedMedia-3.0")

-- : ⬆️ Upvalues :--
local GetScoreInfo = C_PvP.GetScoreInfo
local GetZonePVPInfo = C_PvP.GetZonePVPInfo
local GetNamePlates = C_NamePlate.GetNamePlates
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetActiveMatchState = C_PvP.GetActiveMatchState
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetScoreInfoByPlayerGuid = C_PvP.GetScoreInfoByPlayerGuid
local InCombatLockdown, IsInRaid = InCombatLockdown, IsInRaid
local UnitClassBase, UnitRace, UnitSex = UnitClassBase, UnitRace, UnitSex
local UnitIsDeadOrGhost, UnitHealthPercent = UnitIsDeadOrGhost, UnitHealthPercent
local UnitExists, UnitIsPlayer, UnitGUID, UnitName = UnitExists, UnitIsPlayer, UnitGUID, UnitName
local UnitIsPossessed, UnitPowerMax, UnitPowerType = UnitIsPossessed, UnitPowerMax, UnitPowerType
local RequestBattlefieldScoreData, UnitLeadsAnyGroup = RequestBattlefieldScoreData, UnitLeadsAnyGroup
local UnitIsMercenary, UnitIsUnit, UnitTokenFromGUID = UnitIsMercenary, UnitIsUnit, UnitTokenFromGUID
local UnitFactionGroup, GetGuildInfo, UnitHonorLevel = UnitFactionGroup, GetGuildInfo, UnitHonorLevel
local UnitCanAttack, UnitIsEnemy, UnitRealmRelationship = UnitCanAttack, UnitIsEnemy, UnitRealmRelationship
local GetInspectSpecialization, GetSpecializationInfoByID = GetInspectSpecialization, GetSpecializationInfoByID
local GetPlayerInfoByGUID, IsInInstance, NotifyInspect = GetPlayerInfoByGUID, IsInInstance, NotifyInspect
local GetNumBattlefieldScores, GetRaidRosterInfo = GetNumBattlefieldScores, GetRaidRosterInfo
local gsub, select, strmatch, strsplit, wipe = gsub, select, strmatch, strsplit, wipe
local issecretvalue = issecretvalue
local tinsert = table.insert
local mfloor = math.floor

-- : local variables
local weizFrame = nil

-- : globals
NS.NPC = {}
NS.mapID = 0
NS.PID_Cache = {}
NS.MatchState = 0
NS.mainAssist = nil
NS.EnemyPlayerCache = {}
NS.NotifyInspectCache = {}
NS.NamePlateLastTarget = nil

--|> get player details from battleground enemies
function NS.BattleGroundEnemies_GetPlayerDetails(unitToken)
	-- : not installed?
	if not (BattleGroundEnemies and BattleGroundEnemies.GetPlayerbuttonByUnitID) then
		-- : failed
		return nil
	end

	-- : get player button by unit
	local playerButton = BattleGroundEnemies:GetPlayerbuttonByUnitID(unitToken, "Enemies")
	if playerButton and playerButton.PlayerDetails then
		-- : return player details
		return playerDetails
	end

	-- failed
	return nil
end

--|> calculate PID
function NS.CalculatePID(classID, raceID, factionID, sexID, honorLevel, rankID)
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

	-- : missing sex?
	if not sexID then
		-- : force 0 for now
		sexID = 0
	end

	-- : missing rank?
	if not rankID then
		-- : force 0 for now
		rankID = 0
	end

	-- : calulate PID
	local PID =
		classID * 268435456 +		-- 0x10000000
		raceID * 1048576 +		-- 0x00100000
		factionID * 262144 +		-- 0x00040000
		sexID * 65536 +			-- 0x00010000
		honorLevel
	return PID
end

--|> get data for unit
function NS.GetDataForUnit(unitToken)
	-- : found nameplate?
	if NS.NPC[unitToken] then
		-- : found PID / cache?
		local PID = NS.NPC[unitToken]
		if PID and NS.PID_Cache[PID] then
			-- : return data from cache
			return NS.PID_Cache[PID]
		end
	end

	-- : calculate PID
	local data = {}
	data.sexID = UnitSex(unitToken)
	data.level = UnitLevel(unitToken)
	data.honorLevel = UnitHonorLevel(unitToken)
	data.classToken, data.classID = UnitClassBase(unitToken)
	data.realmRelationship = UnitRealmRelationship(unitToken)
	data.raceName, data.raceToken, data.raceID = UnitRace(unitToken)
	data.factionID = (UnitFactionGroup(unitToken) == FACTION_ALLIANCE) and 1 or 0
	data.guildName, data.rankName, data.rankID, data.guildRealm = GetGuildInfo(unitToken)
	data.PID = NS.CalculatePID(data.classID, data.raceID, data.factionID, data.sexID, data.honorLevel, data.rankID)
	if not data.PID then
		-- : failed
		print("ERROR: Invalid Class or Honor Level?", data.classID, data.honorLevel)
		return nil
	end

	-- : return data
	return data
end

--|> is valid unit token
function NS.IsValidUnitToken(unitToken)
	-- : exists?
	if not UnitExists(unitToken) then
		-- : failed
		return nil
	end

	-- : not player?
	if not UnitIsPlayer(unitToken) then
		-- : failed
		return nil
	end

	-- : not an enemy to player?
	if not (UnitCanAttack("player", unitToken) or UnitIsEnemy("player", unitToken)) then
		-- : failed
		return nil
	end

	-- : mind controlled?
	if UnitIsPossessed(unitToken) then
		-- : same faction as player?
		if UnitFactionGroup(unitToken) == NS.Player.Faction then
			-- : failed
			return nil
		end
	end

	-- : success
	return true
end

--|> get pid by unit
function NS.GetPIDForUnit(unitToken)
	-- : valid unitToken?
	if not NS.IsValidUnitToken(unitToken) then
		-- : failed
		return nil
	end

	-- : target?
	if (unitToken == "target") or (unitToken == "mouseover") then
		-- : search units
		for unit, PID in pairs(NS.NPC) do
			-- : unit matches?
			if UnitIsUnit(unitToken, unit) then
				-- : update unit
				unitToken = unit
				break
			end
		end
	end

	-- : found unit?
	if NS.NPC[unitToken] then
		-- : return PID
		return NS.NPC[unitToken]
	end

	-- : failed
	return nil
end

--|> get mouseover specialziation
function NS.GetMouseoverSpecialization(unitToken)
	-- : has mouse over?
	local specialization = nil
	if UnitExists(unitToken) then
		-- has guild?
		local guildName, rankName, rankID, guildRealm = GetGuildInfo(unitToken)
		if guildName then
			-- save specialization
			specialization = GameTooltipTextLeft4:GetText()
		else
			-- check numlines
			local numLines = GameTooltip:NumLines()
			if numLines == 4 or numLines == 5 then
				-- save specialization
				specialization = GameTooltipTextLeft3:GetText()
			elseif numLines == 6 then
				-- save specialization
				specialization = GameTooltipTextLeft4:GetText()
			end
		end
	end

	-- return specialization
	return specialization
end

--|> get role for unit
function NS.GetRoleForUnit(unitToken, classToken)
	-- : hunter?
	local role = nil
	if classToken == "HUNTER" then
		-- : always damager
		role = "DAMAGER"
	-- : mage?
	elseif classToken == "MAGE" then
		-- : always damager
		role = "DAMAGER"
	-- : monk?
	elseif classToken == "MONK" then
		-- : get power type
		local powerType = UnitPowerType(unitToken)
		if powerType == 0 then
			role = "HEALER"
		else
			-- : get power max
			local powerMax = UnitPowerMax(unitToken, 12)
			if powerMax == 4 then
				role = "TANK"
			else
				role = "DAMAGER"
			end
		end
	-- : priest?
	elseif classToken == "PRIEST" then
		-- : get power type
		local powerType = UnitPowerType(unitToken)
		if powerType == 13 then
			role = "DAMAGER"
		else
			role = "HEALER"
		end
	-- : rogue?
	elseif classToken == "ROGUE" then
		-- : always damager
		role = "DAMAGER"
	-- : shaman?
	elseif classToken == "SHAMAN" then
		-- : get power type
		local powerType = UnitPowerType(unitToken)
		if powerType == 0 then
			role = "HEALER"
		else
			role = "DAMAGER"
		end
	-- : warlock?
	elseif classToken == "WARLOCK" then
		-- : always damager
		role = "DAMAGER"
	end

	-- : return role
	return role
end

--|> refresh active player data
function NS.RefreshActivePlayerData(unitToken)
	-- : unit still exists?
	if UnitExists(unitToken) then
		-- : found PID / cache?
		local PID = NS.NPC[unitToken]
		if PID and NS.PID_Cache[PID] then
			-- : update player cache
			local data = NS.PID_Cache[PID]
			NS.UpdatePlayerActiveCache(PID, data.name, data.realm, nil)
			NS.ValidatePlayerActiveCache(unitToken, PID)

			-- : player actively cached?
			if NS.PlayerActiveCache[PID] then
				-- : update health?
				NS.PlayerActiveCache[PID].unitToken = unitToken
				if NS.Options.Bars.UpdateHealth then
					-- : refresh dead / health
					NS.PlayerActiveCache[PID].Dead = UnitIsDeadOrGhost(unitToken)
					NS.PlayerActiveCache[PID].Health = UnitHealthPercent(unitToken)
					NS.RefreshBarByPID(PID)
				end
			end

			-- : return data
			return data
		end
	end

	-- : failed
	return nil
end

--|> update specialization
function NS.UpdateNamePlateSpecialization(namePlate, unitToken)
	-- : specialization text no tenabled?
	if not NS.Options.BattleGrounds.SpecText then
		-- : finished
		return
	end

	-- : sanity check
	if namePlate and unitToken then
		-- : currently targeted?
		if UnitIsUnit("target", unitToken) then
			-- : has specialization?
			local PID = NS.NPC[unitToken]
			if PID and NS.PID_Cache[PID].specialization then
				-- : set text
				weizFrame.Text:SetText(NS.PID_Cache[PID].specialization)
				weizFrame:SetPoint("CENTER", namePlate, "CENTER", 0, -15)
				weizFrame:Show()
				return
			end
		end
	end

	-- : hide
	weizFrame.Text:SetText("")
	weizFrame:ClearAllPoints()
	weizFrame:Hide()
end

--|> refresh unit data
function NS.RefreshUnitData(unitToken)
	-- : get data for unit
	local data = NS.GetDataForUnit(unitToken)
	if data and data.PID then
		-- : save PID
		local PID = data.PID
		NS.NPC[unitToken] = PID

		-- : already cached?
		if NS.PID_Cache[PID] then
			-- : update pid cache
			local currentTime = time()
			NS.PID_Cache[PID].HL = honorLevel
			NS.PID_Cache[PID].L = level
			NS.PID_Cache[PID].T = currentTime
			NS.PID_Cache[PID].isLeader = UnitLeadsAnyGroup(unitToken)

			-- : has NAME?
			if NS.PID_Cache[PID].NAME then
				-- : update database
				local NAME = NS.PID_Cache[PID].NAME
				NS.PlayerDB[NAME].HL = honorLevel
				NS.PlayerDB[NAME].L = level
				NS.PlayerDB[NAME].T = currentTime
			end
		else
			-- : initialize
			NS.PID_Cache[PID] = {}

			-- : save potentially secret stuff
			local guid = UnitGUID(unitToken)
			local name, realm = UnitName(unitToken)
			NS.PID_Cache[PID].guid = guid
			NS.PID_Cache[PID].name = name
			NS.PID_Cache[PID].realm = realm
			if not realm or (data.realmRelationship == LE_REALM_RELATION_SAME) then
				-- : same realm
				NS.PID_Cache[PID].displayedName = name
				NS.PID_Cache[PID].fullName = name .. "-" .. NS.PlayerRealm
			else
				-- : use realm
				NS.PID_Cache[PID].displayedName = name .. "|cFFFF00CC*|r"
				NS.PID_Cache[PID].fullName = name .. "-" .. realm
			end

			-- : save non-secret stuff
			NS.PID_Cache[PID].lastNP = unitToken
			NS.PID_Cache[PID].C = data.classToken
			NS.PID_Cache[PID].CID = data.classID
			NS.PID_Cache[PID].FID = data.factionID
			NS.PID_Cache[PID].G = data.guildName
			NS.PID_Cache[PID].GR = data.rankName
			NS.PID_Cache[PID].GRID = data.rankID
			NS.PID_Cache[PID].GRN = data.guildRealm
			NS.PID_Cache[PID].HL = data.honorLevel
			NS.PID_Cache[PID].L = data.level
			NS.PID_Cache[PID].RID = data.raceID
			NS.PID_Cache[PID].RR = data.realmRelationship
			NS.PID_Cache[PID].S = data.sexID
			NS.PID_Cache[PID].RL = NS.GetRoleForUnit(unitToken, data.classToken)
			NS.PID_Cache[PID].isLeader = UnitLeadsAnyGroup(unitToken)

			-- : check match state
			if NS.MatchState == Enum.PvPMatchState.Engaged then
				-- : search PSC
				for k,v in pairs(NS.PSC) do
					-- : matches stuff?
					if v.CID == data.classID and v.RT == data.raceToken and v.S == data.sexID and v.HL then
						-- : calculate range
						local range = 1
						if v.HL > 50 then
							range = 10 + mfloor(v.HL / 50)
						elseif v.HL > 5 then
							range = mfloor(v.HL / 5)
						end

						-- : honor level within range?
						if (data.honorLevel >= v.HL) and ((data.honorLevel - v.HL) < range) then
							-- : found player by guid?
							if GetScoreInfoByPlayerGuid(v.GUID) then
								-- : save GUID / NAME
								NS.PID_Cache[PID].GUID = v.GUID
								NS.PID_Cache[PID].NAME = v.NAME
								NS.PID_Cache[PID].fullName = v.NAME

								-- : no role yet?
								if not NS.PID_Cache[PID].RL then
									-- : try using role from database
									NS.PID_Cache[PID].RL = v.RL
								end
								break
							end
						end
					end
				end
			else
				-- : non secret?
				if not issecretvalue(guid) then
					-- : save GUID
					NS.PID_Cache[PID].GUID = guid

					-- no realm?
					if not realm or (realm == "") or (data.realmRelationship == LE_REALM_RELATION_SAME) then
						-- same realm
						NS.PID_Cache[PID].displayedName = name
						realm = NS.PlayerRealm
					else
						-- different realm
						NS.PID_Cache[PID].displayedName = name .. "|cFFFF00CC*|r"
					end

					-- : save NAME
					NS.PID_Cache[PID].NAME = name .. "-" .. realm
					NS.PID_Cache[PID].fullName = name .. "-" .. realm
				end
			end

			-- : not found yet?
			if not NS.PID_Cache[PID].GUID then
				-- : search player database
				for player,v in pairs(NS.PlayerDB) do
					-- : matches stuff?
					if v.CID == data.classID and v.RID == data.raceID and v.S == data.sexID and v.HL then
						-- : calculate range
						local range = 1
						if v.HL > 50 then
							range = 10 + mfloor(v.HL / 50)
						elseif v.HL > 5 then
							range = mfloor(v.HL / 5)
						end

						-- : honor level within range?
						if (data.honorLevel >= v.HL) and ((data.honorLevel - v.HL) < range) then
							-- : found player by guid?
							if GetScoreInfoByPlayerGuid(v.GUID) then
								-- : save GUID / NAME
								NS.PID_Cache[PID].GUID = v.GUID
								NS.PID_Cache[PID].NAME = player
								NS.PID_Cache[PID].fullName = player

								-- : no role yet?
								if not NS.PID_Cache[PID].RL then
									-- : try using role from database
									NS.PID_Cache[PID].RL = v.RL
								end
								break
							end
						end
					end
				end
			end

			-- : finally found?
			if NS.PID_Cache[PID].GUID then
				-- : save macrotext
				local GUID = NS.PID_Cache[PID].GUID
				local player = NS.PID_Cache[PID].NAME
				NS.PID_Cache[PID].macrotext = "/target " .. gsub(player, "-(.*)", "")

				-- : new player found?
				if not NS.PlayerDB[player] then
					-- : initialize
					NS.PlayerDB[player] = {}
				end

				-- : add / update database
				local currentTime = time()
				NS.PlayerDB[player].GUID = NS.PID_Cache[PID].GUID
				NS.PlayerDB[player].C = data.classToken
				NS.PlayerDB[player].CID = data.classID
				NS.PlayerDB[player].F = data.factionID
				NS.PlayerDB[player].FID = data.factionID
				NS.PlayerDB[player].G = data.guildName
				NS.PlayerDB[player].GR = data.rankName
				NS.PlayerDB[player].GRID = data.rankID
				NS.PlayerDB[player].GRN = data.guildRealm
				NS.PlayerDB[player].HL = data.honorLevel
				NS.PlayerDB[player].L = data.level
				NS.PlayerDB[player].RC = data.raceName
				NS.PlayerDB[player].RID = data.raceID
				NS.PlayerDB[player].RT = data.raceToken
				NS.PlayerDB[player].S = data.sexID
				NS.PlayerDB[player].T = currentTime

				-- : no role?
				if not NS.PlayerDB[player].RL then
					-- : try using role from pid cache
					NS.PlayerDB[player].RL = NS.PID_Cache[PID].RL
				end

				-- : new player score cache?
				if not NS.PSC[GUID] then
					-- : initialize
					NS.PSC[GUID] = {}
				end

				-- : update player score cache
				NS.PSC[GUID].GUID = GUID
				NS.PSC[GUID].NAME = player
				NS.PSC[GUID].fullName = player
				NS.PSC[GUID].C = data.classToken
				NS.PSC[GUID].CID = data.classID
				NS.PSC[GUID].F = data.factionID
				NS.PSC[GUID].FID = data.factionID
				NS.PSC[GUID].HL = data.honorLevel
				NS.PSC[GUID].RC = data.raceName
				NS.PSC[GUID].RL = NS.PlayerDB[player].RL
				NS.PSC[GUID].RR = data.realmRelationship
				NS.PSC[GUID].RT = data.raceToken
				NS.PSC[GUID].S = data.sexID
				NS.PSC[GUID].macrotext = NS.PID_Cache[PID].macrotext
				NS.PSC[GUID].T = currentTime
			end
		end

		-- : refresh active player data
		NS.RefreshActivePlayerData(unitToken)

		-- : return PID
		return PID
	end

	-- : failed
	return nil
end

--|> name plate unit added
function NS.NamePlateUnitAdded(unitToken)
	-- : valid unit?
	if NS.IsValidUnitToken(unitToken) then
		-- : unit refreshed?
		NS.RefreshUnitData(unitToken)
	end
end

--|> name plate unit removed
function NS.NamePlateUnitRemoved(unitToken)
	-- : found unit?
	if NS.NPC[unitToken] then
		-- : delete unit
		NS.NPC[unitToken] = nil
	end
end

--|> update name plate unit
function NS.UpdateNamePlateUnit(unitToken)
	-- : not valid unit?
	if not NS.IsValidUnitToken(unitToken) then
		-- : finished
		return
	end

	-- : target?
	if (unitToken == "target") or (unitToken == "mouseover") then
		-- : search units
		for unit, PID in pairs(NS.NPC) do
			-- : unit is target?
			if UnitIsUnit(unitToken, unit) then
				-- : update unit
				unitToken = unit
				break
			end
		end
	end

	-- : get name plate
	local PID = nil
	local namePlate = GetNamePlateForUnit(unitToken)
	if namePlate and namePlate.UnitFrame then
		-- : get unit
		local processed = false
		unitToken = namePlate:GetUnit()
		if unitToken then
			-- : refresh unit data
			NS.RefreshUnitData(unitToken)

			-- : found?
			if NS.NPC[unitToken] then
				-- : refresh active player data
				NS.RefreshActivePlayerData(unitToken)
			end
		end
	end
end

--|> refresh all nameplates
function NS.RefreshAllNamePlates()
	-- : get all nameplates
	local nameplates = GetNamePlates()
	for _, namePlate in ipairs(nameplates) do
		-- : get unit
		local unitToken = namePlate:GetUnit()
		if unitToken then
			-- : valid unit?
			if NS.IsValidUnitToken(unitToken) then
				-- : refresh unit data
				NS.RefreshUnitData(unitToken)
			end
		end
	end
end

--|> update group roles
local checkMainAssist = false
function NS.UpdateGroupRoles()
	-- : in combat lockdown?
	if InCombatLockdown() then
		-- : finished
		checkMainAssist = true
		return
	end

	-- : has community flare?
	checkMainAssist = false
	if CommunityFlare_GetMainAssist then
		-- : check for main assist
		local player = CommunityFlare_GetMainAssist()
		if NS.mainAssist ~= player then
			-- : update main assist
			NS.mainAssist = player
		end

		-- : no main assist, check for main tank?
		if not NS.mainAssist and CommunityFlare_GetMainTank then
			-- : check for main tank
			NS.mainAssist = CommunityFlare_GetMainTank()
		end

		-- : main assist?
		if NS.mainAssist and (NS.mainAssist ~= NS.Player.Name) then
			-- : process all
			local macrotext = "/assist [nodead] " .. gsub(NS.mainAssist, "-(.*)", "")
			for k = 1, NS.Options.Bars.MaxNumBars do
				-- : not set?
				local enable = false
				if not NS.CoreUI.Bar[k].macrotext then
					-- : enabled
					enable = true
				elseif (NS.CoreUI.Bar[k].macrotext ~= macrotext) then
					-- : direct /target macro not
					if not NS.CoreUI.Bar[k].macrotext:find("/target") then
						-- : enabled
						enable = true
					end					
				end

				-- enabled?
				if enabled then
					-- : setup button
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

--|> update battlefield score
function NS.UpdateBattlefieldScore()
	-- : check match state
	NS.MatchState = GetActiveMatchState()
	if NS.MatchState <= Enum.PvPMatchState.Engaged then
		-- : get player info
		local playerInfo = GetScoreInfoByPlayerGuid(NS.Player.GUID)
		if playerInfo then
			-- : process all
			for i=1, GetNumBattlefieldScores() do
				-- : get score info
				local info = GetScoreInfo(i)
				if info and info.name and not issecretvalue(info.name) then
					-- : enemy team faction?
					if playerInfo.faction ~= info.faction then
						-- : add to enemy player cache
						NS.EnemyPlayerCache[info.name] = info
					end
				end
			end
		end

		-- : finished
		return
	end

	-- : process all
	local count, maxlevels = 0, 0
	for i=1, MAX_RAID_MEMBERS do
		-- get name / rank
		local name, rank, _, level = GetRaidRosterInfo(i)
		if name and level then
			-- : max level?
			if level == NS.MaxLevel then
				-- : increase
				maxlevels = maxlevels + 1
			end

			-- : increase
			count = count + 1
		end
	end

	-- : max level pvp?
	local maxLevelPvP = false
	if (count > 0) and (count == maxlevels) then
		maxLevelPvP = true
	end

	-- : player is mercenary?
	local playerFaction = NS.Player.FactionID
	if UnitIsMercenary("player") then
		-- : alliance?
		if playerFaction == 1 then
			-- : horde for now
			playerFaction = 0
		else
			-- : alliance for now
			playerFaction = 1
		end
	end

	-- : process all
	local currentTime = time()
	for i=1, GetNumBattlefieldScores() do
		-- : get score info
		local info = GetScoreInfo(i)
		if info and info.name and info.guid and (info.faction ~= playerFaction) then
			-- : calculate stuff
			local role = "UNKNOWN"
			local sexID = select(5, GetPlayerInfoByGUID(info.guid))
			local classID = NS.GetClassIDFromName(info.classToken)
			local raceToken, raceName = RAC:GetRaceToken(info.raceName) or nil
			if info.talentSpec then
				role = NS.GetRoleFromSpecialization(info.talentSpec)
			elseif info.roleAssigned == 2 then
				role = "TANK"
			elseif info.roleAssigned == 4 then
				role = "HEALER"
			elseif info.roleAssigned == 8 then
				role = "DAMAGER"
			end

			-- : always use full name
			local player = info.name
			if not strmatch(player, "-") then
				-- : has honor level?
				if info.honorLevel > 0 then
					-- : use player realm
					player = player .. "-" .. NS.PlayerRealm
				end
			end

			-- : new player score cache?
			if not NS.PSC[info.guid] then
				-- : initialize
				NS.PSC[info.guid] = {}
			end

			-- : update player score cache
			NS.PSC[info.guid].GUID = info.guid
			NS.PSC[info.guid].NAME = player
			NS.PSC[info.guid].fullName = player
			NS.PSC[info.guid].C = info.classToken
			NS.PSC[info.guid].CID = classID
			NS.PSC[info.guid].F = info.faction
			NS.PSC[info.guid].HL = info.honorLevel
			NS.PSC[info.guid].MID = NS.mapID
			NS.PSC[info.guid].RC = raceName
			NS.PSC[info.guid].RL = role
			NS.PSC[info.guid].ROLE = info.roleAssigned
			NS.PSC[info.guid].RT = raceToken
			NS.PSC[info.guid].S = sexID
			NS.PSC[info.guid].SPEC = info.talentSpec
			NS.PSC[info.guid].T = currentTime

			-- : new player?
			if not NS.PlayerDB[player] then
				-- : create
				NS.PlayerDB[player] = {}
			end

			-- : save / update base info
			NS.PlayerDB[player].GUID = info.guid
			NS.PlayerDB[player].C = info.classToken
			NS.PlayerDB[player].CID = classID
			NS.PlayerDB[player].HL = info.honorLevel
			NS.PlayerDB[player].MID = NS.mapID
			NS.PlayerDB[player].RC = raceName
			NS.PlayerDB[player].RL = role
			NS.PlayerDB[player].ROLE = info.roleAssigned
			NS.PlayerDB[player].RT = raceToken
			NS.PlayerDB[player].S = sexID
			NS.PlayerDB[player].SPEC = info.talentSpec
			NS.PlayerDB[player].T = currentTime

			-- : get race info from name (if possible)
			local raceID, factionID = NS.GetRaceInfoFromName(raceName, nil)
			if raceID and factionID then
				-- : update
				NS.PSC[info.guid].F = factionID
				NS.PSC[info.guid].RID = raceID
				NS.PlayerDB[player].F = factionID
				NS.PlayerDB[player].RID = raceID
			end

			-- : max level pvp?
			if maxLevelPvP then
				-- : update
				NS.PSC[info.guid].L = NS.MaxLevel
				NS.PlayerDB[player].L = NS.MaxLevel
			end
		end
	end
end

--|> purge PSC
function NS.ValidatePSC()
	-- : process all
	local currentTime = time()
	for GUID, data in pairs(NS.PSC) do
		-- : purge bots
		if data.HL == 0 then
			-- : delete
			wipe(NS.PSC[GUID])
			NS.PSC[GUID] = nil
		-- : same faction as player?
		elseif data.F == NS.Player.FactionID then
			-- : delete
			wipe(NS.PSC[GUID])
			NS.PSC[GUID] = nil
		else
			-- : no time?
			if not data.T then
				-- : delete
				wipe(NS.PSC[GUID])
				NS.PSC[GUID] = nil
			else
				-- : has decimal?
				if mfloor(data.T) ~= data.T then
					-- : update time
					NS.PSC[GUID].T = currentTime
				else
					-- : expired?
					if data.T < (currentTime - (86400 * 7)) then
						-- : delete
						wipe(NS.PSC[GUID])
						NS.PSC[GUID] = nil
					end
				end
			end
		end

		-- : not purged?
		if NS.PSC[GUID] then
			-- : no race name?
			if not NS.PSC[GUID].RC then
				-- : has info still?
				if NS.PSC[GUID].info then
					-- : has race name?
					local info = NS.PSC[GUID].info
					if info.raceName then
						-- : get race token
						local raceToken, raceName = RAC:GetRaceToken(info.raceName) or nil
						if raceToken and raceName then
							-- : update race
							NS.PSC[GUID].RC = raceName
							NS.PSC[GUID].RT = raceToken
						end
					end
				end
			-- : no race token?
			elseif not NS.PSC[GUID].RT then
				-- : get race token
				local raceToken, raceName = RAC:GetRaceToken(NS.PSC[GUID].RC) or nil
				if raceToken and raceName then
					-- : update race
					NS.PSC[GUID].RC = raceName
					NS.PSC[GUID].RT = raceToken
				end
			end

			-- : no GUID?
			if not NS.PSC[GUID].GUID then
				-- : save GUID
				NS.PSC[GUID].GUID = GUID
			end

			-- : old realName?
			if NS.PSC[GUID].realName then
				-- : save name
				NS.PSC[GUID].NAME = NS.PSC[GUID].realName
				NS.PSC[GUID].fullName = NS.PSC[GUID].realName
				NS.PSC[GUID].realName = nil
			end

			-- : remove old field
			NS.PSC[GUID].realGUID = nil
		end
	end
end

--|> create weizFrame (for specialization text)
function NS.weizFrame_Create()
	-- : create / setup frame
	weizFrame = weizFrame or CreateFrame("Frame", nil, UIParent)
	weizFrame:SetSize(150, 20)
	weizFrame:ClearAllPoints()
	weizFrame.Text = weizFrame:CreateFontString(nil, "OVERLAY")
	weizFrame.Text:SetFont(SM:Fetch("font", "Roboto Condensed BoldItalic"), 12, "OUTLINE")
	weizFrame.Text:SetAllPoints()
	weizFrame.Text:SetTextColor(1, 1, 1, 1)
	weizFrame.Text:SetText("TESTING")
end

--|> OnEvent
local function OnEvent(self, event, ...)
	-- : inspect ready?
	if event == "INSPECT_READY" then
		-- : get unit token from GUID
		local GUID = ...
		if GUID and not issecretvalue(GUID) then
			-- : inspecting?
			if NS.NotifyInspectCache[GUID] then
				-- : get unit token
				local unitToken = UnitTokenFromGUID(GUID)
				if unitToken then
					-- : get inspect specialization ID
					local specID = GetInspectSpecialization(unitToken)
					if specID then
						-- : get role
						local _, _, _, _, Role = GetSpecializationInfoByID(specID)
						if Role then
							-- : get PlayerID
							local player = NS.NotifyInspectCache[GUID]
							local PlayerID = NS.GetPIDForUnit(unitToken)
							if PlayerID then
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
				end

				-- : delete
				NS.NotifyInspectCache[GUID] = nil
			end
		end
	-- : name plate unit added?
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		-- : update unit
		local unitToken = ...
		NS.NamePlateUnitAdded(unitToken)
	-- : name plate unit removed?
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		-- : get name plate
		local unitToken = ...
		NS.NamePlateUnitRemoved(unitToken)
	-- : player entering battleground
	elseif event == "PLAYER_ENTERING_BATTLEGROUND" then
		-- : request battlefield score data
		RequestBattlefieldScoreData()
	-- : player entering world?
	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = ...

		-- : reset / refresh
		NS.NPC = {}
		NS.PID_Cache = {}
		NS.EnemyPlayerCache = {}
		NS.UpdateGroupRoles()
		NS.weizFrame_Create()

		-- : get proper zone / state
		NS.Zone.pvpType = select(1, GetZonePVPInfo())
		NS.Zone.InInstance, NS.Zone.instance = IsInInstance()
		NS.MatchState = GetActiveMatchState()
		NS.mapID = GetBestMapForUnit("player")

		-- : validate player score cache
		NS.ValidatePSC()
	-- : player leaving world?
	elseif event == "PLAYER_LEAVING_WORLD" then
		-- : update specialization
		NS.UpdateNamePlateSpecialization()

		-- : leaving pvp?
		if NS.Zone.instance == "pvp" then
			-- : backup PID for debugging
			NS.bPID_Cache = CopyTable(NS.PID_Cache)
		end
	-- : player logout?
	elseif event == "PLAYER_LOGOUT" then
		-- : save settings
		NS.globalDB.global.PSC = NS.PSC or {}
	-- : player regen enabled?
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- : check main assist?
		if checkMainAssist == true then
			-- : update group roles
			NS.UpdateGroupRoles()
		end
	-- : player roles changed?
	elseif event == "PLAYER_ROLES_ASSIGNED" then
		-- : update group roles
		NS.UpdateGroupRoles()
	-- : player target changed?
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- : get name plate
		local unitToken = nil
		local namePlate = GetNamePlateForUnit("target")
		if namePlate then
			-- : get unit
			unitToken = namePlate:GetUnit()
			if unitToken then
				-- : update unit
				NS.UpdateNamePlateUnit(unitToken)

				-- : save last target name plate
				NS.NamePlateLastTarget = namePlate
			end
		end

		-- : update specialization
		NS.UpdateNamePlateSpecialization(namePlate, unitToken)
	-- : player target died?
	elseif event == "PLAYER_TARGET_DIED" then
		-- : update specialization
		NS.UpdateNamePlateSpecialization()
	-- : pvp match state changed?
	elseif event == "PVP_MATCH_STATE_CHANGED" then
		-- : save match state
		NS.MatchState = GetActiveMatchState()

		-- : request battlefield score data
		RequestBattlefieldScoreData()
	-- : unit flags
	elseif event == "UNIT_FLAGS" then
		-- : get name plate
		local unitToken = ...
		local baseToken = unitToken:gsub("%d", "")
		if baseToken == "nameplate" then
			-- : update unit
			NS.UpdateNamePlateUnit(unitToken)
		end
	-- : unit health
	elseif event == "UNIT_HEALTH" then
		-- : update unit
		local unitToken = ...
		local baseToken = unitToken:gsub("%d", "")
		if baseToken == "nameplate" then
			-- : update unit
			NS.UpdateNamePlateUnit(unitToken)
		end
	-- : unit target
	elseif event == "UNIT_TARGET" then
		-- : update unit
		local unitToken = ...
		local baseToken = unitToken:gsub("%d", "")
		if baseToken == "nameplate" then
			-- : update unit
			NS.UpdateNamePlateUnit(unitToken)
		end
	-- : update battlefield score
	elseif event == "UPDATE_BATTLEFIELD_SCORE" then
		-- : update battlefield score
		NS.UpdateBattlefieldScore()

		-- : update group roles
		NS.UpdateGroupRoles()
	-- : update mouseover unit
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		-- : get name plate
		local namePlate = GetNamePlateForUnit("mouseover")
		if namePlate then
			-- : get unit
			local unitToken = namePlate:GetUnit()
			if unitToken then
				-- : update unit
				NS.UpdateNamePlateUnit(unitToken)

				-- : specialization text enabled?
				if NS.Options.BattleGrounds.SpecText then
					-- : cached with no specialization?
					local PID = NS.NPC[unitToken]
					if PID and NS.PID_Cache[PID] and not NS.PID_Cache[PID].specialization then
						-- : get mouse over specialization
						NS.PID_Cache[PID].specialization = NS.GetMouseoverSpecialization("mouseover")
						if NS.PID_Cache[PID].specialization then
							-- : update specialization
							NS.UpdateNamePlateSpecialization(namePlate, unitToken)
						end
					end
				end
			end
		end
	end
end

-- : create events frame
NS.weizPVP_Events = CreateFrame("Frame", nil, UIParent)
NS.weizPVP_Events:RegisterEvent("INSPECT_READY")
NS.weizPVP_Events:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
NS.weizPVP_Events:RegisterEvent("PLAYER_ENTERING_WORLD")
NS.weizPVP_Events:RegisterEvent("PLAYER_LEAVING_WORLD")
NS.weizPVP_Events:RegisterEvent("PLAYER_LOGOUT")
NS.weizPVP_Events:RegisterEvent("PLAYER_REGEN_ENABLED")
NS.weizPVP_Events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
NS.weizPVP_Events:RegisterEvent("PVP_MATCH_STATE_CHANGED")
NS.weizPVP_Events:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
NS.weizPVP_Events:RegisterEvent("ZONE_CHANGED")
NS.weizPVP_Events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
NS.weizPVP_Events:SetScript("OnEvent", OnEvent)
