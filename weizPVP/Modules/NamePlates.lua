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
local blshift = bit.lshift
local mfloor = math.floor
local strfind = string.find
local strsub = string.sub
local tinsert = table.insert

-- : local variables
local weizFrame = nil

-- : always dps classes
local ALWAYS_DPS = {
	HUNTER = true,
	MAGE = true,
	ROGUE = true,
	WARLOCK = true,
}

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
		return playerButton.PlayerDetails
	end

	-- : failed
	return nil
end

--|> calculate PID
local function CalculatePID(classID, raceID, factionID, sexID, honorLevel, rankID)
	-- : sanity checks
	if not (classID and honorLevel) then return nil end

	-- : calculate PID
	local PID = blshift(classID, 28)
	          + blshift(raceID or 0, 20)
	          + blshift(factionID or 0, 18)
	          + blshift(sexID or 0, 16)
	          + honorLevel

	-- : return PID
	return PID
end

--|> get data for unit
local function GetDataForUnit(unitToken)
	-- : found nameplate?
	local cachedPID = NS.NPC[unitToken]
	if cachedPID then
		-- : found cache?
		local data = NS.PID_Cache[cachedPID]
		if data then
			-- : update levels
			data.level = UnitLevel(unitToken)
			data.honorLevel = UnitHonorLevel(unitToken)

			-- : return data
			return data
		end
	end

	-- : sanity checks
	local classToken, classID = UnitClassBase(unitToken)
	local honorLevel = UnitHonorLevel(unitToken)
	if not (classToken and classID and honorLevel) then
		-- : failed
		return nil
	end

	-- : calculate PID
	local sexID = UnitSex(unitToken)
	local level = UnitLevel(unitToken)
	local raceName, raceToken, raceID = UnitRace(unitToken)
	local factionID = (UnitFactionGroup(unitToken) == FACTION_ALLIANCE) and 1 or 0
	local guildName, rankName, rankID, guildRealm = GetGuildInfo(unitToken)
	local PID = CalculatePID(classID, raceID, factionID, sexID, honorLevel, rankID)

	-- : create data
	local data = {
		PID = PID,
		classID = classID,
		classToken = classToken,
		factionID = factionID,
		honorLevel = honorLevel,
		guildName = guildName,
		guildRealm = guildRealm,
		level = level,
		raceID = raceID,
		raceName = raceName,
		raceToken = raceToken,
		rankID = rankID,
		rankName = rankName,
		sexID = sexID,
	}

	-- : extract more data
	data.level = UnitLevel(unitToken)
	data.realmRelationship = UnitRealmRelationship(unitToken)

	-- : return data
	return data
end

--|> is valid unit token
local function IsValidUnitToken(unitToken)
	-- : enemy?
	return (
		UnitExists(unitToken) 
		and UnitIsPlayer(unitToken) 
		and (UnitCanAttack("player", unitToken) or UnitIsEnemy("player", unitToken))
	) or nil
end

--|> get pid by unit
function NS.GetPIDForUnit(unitToken)
	-- : valid unitToken?
	if not IsValidUnitToken(unitToken) then
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
local function GetMouseoverSpecialization(unitToken)
	-- : has mouse over?
	local specialization = nil
	if UnitExists(unitToken) then
		-- : has guild?
		local guildName, rankName, rankID, guildRealm = GetGuildInfo(unitToken)
		if guildName then
			-- : save specialization
			specialization = GameTooltipTextLeft4:GetText()
		else
			-- : check numlines
			local numLines = GameTooltip:NumLines()
			if numLines == 4 or numLines == 5 then
				-- : save specialization
				specialization = GameTooltipTextLeft3:GetText()
			elseif numLines == 6 then
				-- : save specialization
				specialization = GameTooltipTextLeft4:GetText()
			end
		end
	end

	-- : return specialization
	return specialization
end

--|> get role for unit
local function GetRoleForUnit(unitToken, classToken)
	-- : only dps?
	if ALWAYS_DPS[classToken] then
		return "DAMAGER"
	end

	-- : monk?
	if classToken == "MONK" then
		-- : has mana?
		if UnitPowerType(unitToken) == 0 then
			return "HEALER"
		-- : tanks always stuck with 4
		elseif UnitPowerMax(unitToken, 12) == 4 then
			return "TANK"
		end
		return "DAMAGER"
	-- : priest?
	elseif classToken == "PRIEST" then
		return (UnitPowerType(unitToken) == 13) and "DAMAGER" or "HEALER"
	-- : shaman?
	elseif classToken == "SHAMAN" then
		return (UnitPowerType(unitToken) == 0) and "HEALER" or "DAMAGER"
	end

	-- : try battleground enemies
	local playerDetails = NS.BattleGroundEnemies_GetPlayerDetails(unitToken)
	if playerDetails and playerDetails.PlayerRole then
		-- : not secret?
		if not issecretvalue(playerDetails.PlayerRole) then
			-- : found
			return playerDetails.PlayerRole
		end
	end

	-- : failed
	return nil
end

--|> refresh active player data
local function RefreshActivePlayerData(unitToken)
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
local function UpdateNamePlateSpecialization(namePlate, unitToken)
	-- : specialization text not enabled?
	if not NS.Options.BattleGrounds.SpecText then
		-- : finished
		return
	end

	-- : sanity checks
	if namePlate and unitToken and UnitIsUnit("target", unitToken) then
		-- : found specialization?
		local pid = NS.NPC[unitToken]
		local cachedData = pid and NS.PID_Cache[pid]
		local specialization = cachedData and cachedData.specialization
		if specialization then
			-- : show
			local textWidget = weizFrame.Text
			textWidget:SetText(specialization)
			weizFrame:SetPoint("CENTER", namePlate, "CENTER", 0, -15)
			weizFrame:Show()
			return
		end
	end

	-- : shown?
	if weizFrame:IsShown() then
		-- : hide
		weizFrame:Hide()
		weizFrame:ClearAllPoints()
	end
end

--|> get honor level range
local function GetHonorLevelRange(honorLevel)
	-- : larger ranges needed?
	if honorLevel > 50 then return 10 + mfloor(honorLevel / 50) end
	if honorLevel > 5 then return mfloor(honorLevel / 5) end

	-- : smallest range
	return 1
end

--|> refresh unit data
local function RefreshUnitData(unitToken)
	-- : found unit data?
	local data = GetDataForUnit(unitToken)
	if not (data and data.PID) then return end

	-- : already cached?
	local PID = data.PID
	NS.NPC[unitToken] = PID
	local currentTime = time()
	local cacheEntry = NS.PID_Cache[PID]
	if cacheEntry then
		-- : update
		cacheEntry.HL = data.honorLevel
		cacheEntry.L = data.level
		cacheEntry.T = currentTime
		cacheEntry.isLeader = UnitLeadsAnyGroup(unitToken)

		-- : found NAME?
		local NAME = cacheEntry.NAME
		if NAME then
			-- : found database player?
			local dbEntry = NS.PlayerDB[NAME]
			if dbEntry then
				-- : update
				dbEntry.HL = data.honorLevel
				dbEntry.L = data.level
				dbEntry.T = currentTime
			end
		end

		-- : refresh active player data
		RefreshActivePlayerData(unitToken)
		return PID
	end

	-- : localize cache
	cacheEntry = {}
	NS.PID_Cache[PID] = cacheEntry
	local guid = UnitGUID(unitToken)
	local name, realm = UnitName(unitToken)
	cacheEntry.guid = guid
	cacheEntry.name = name
	cacheEntry.realm = realm

	-- : same realm as player?
	if data.realmRelationship == LE_REALM_RELATION_SAME then
		-- : update names / realm
		cacheEntry.displayedName = name
		cacheEntry.fullName = name .. "-" .. NS.PlayerRealm
		realm = NS.PlayerRealm
	else
		-- : update names
		cacheEntry.displayedName = name .. "|cFFFF00CC*|r"
		cacheEntry.fullName = name .. "-" .. realm
	end

	-- : update
	cacheEntry.lastNP = unitToken
	cacheEntry.C = data.classToken
	cacheEntry.CID = data.classID
	cacheEntry.FID = data.factionID
	cacheEntry.G = data.guildName
	cacheEntry.GR = data.rankName
	cacheEntry.GRID = data.rankID
	cacheEntry.GRN = data.guildRealm
	cacheEntry.HL = data.honorLevel
	cacheEntry.L = data.level
	cacheEntry.RID = data.raceID
	cacheEntry.RR = data.realmRelationship
	cacheEntry.S = data.sexID
	local role = GetRoleForUnit(unitToken, data.classToken)
	cacheEntry.RL = role
	cacheEntry.isLeader = UnitLeadsAnyGroup(unitToken)

	-- : match engaged?
	if NS.MatchState == Enum.PvPMatchState.Engaged then
		-- : process all
		local cid, rt, s, hl = data.classID, data.raceToken, data.sexID, data.honorLevel
		for _, v in pairs(NS.PSC) do
			-- : found matchable data?
			if v.CID == cid and v.RT == rt and v.S == s and v.HL then
				-- : get honor level range
				local diff = hl - v.HL
				if diff >= 0 and diff < GetHonorLevelRange(v.HL) then
					-- : get score info by player guid
					local vGUID = v.GUID
					if GetScoreInfoByPlayerGuid(vGUID) then
						-- : update
						cacheEntry.GUID = vGUID
						cacheEntry.NAME = v.NAME
						cacheEntry.fullName = v.NAME
						if not role then cacheEntry.RL = v.RL end
						break
					end
				end
			end
		end
	else
		-- : found non-secret guid?
		if not issecretvalue(guid) then
			-- : update
			cacheEntry.GUID = guid
			local fullName = name .. "-" .. realm
			cacheEntry.NAME = fullName
			cacheEntry.fullName = fullName
		end
	end

	-- : guid not found yet?
	if not cacheEntry.GUID then
		-- : process all
		local cid, rid, s, hl = data.classID, data.raceID, data.sexID, data.honorLevel
		for player, v in pairs(NS.PlayerDB) do
			-- : found matchable data?
			if v.CID == cid and v.RID == rid and v.S == s and v.HL then
				-- : get honor level range
				local diff = hl - v.HL
				if diff >= 0 and diff < GetHonorLevelRange(v.HL) then
					-- : get score info by player guid
					local vGUID = v.GUID
					if GetScoreInfoByPlayerGuid(vGUID) then
						-- : update
						cacheEntry.GUID = vGUID
						cacheEntry.NAME = player
						cacheEntry.fullName = player
						if not role then cacheEntry.RL = v.RL end
						break
					end
				end
			end
		end
	end

	-- : found real GUID?
	local targetGUID = cacheEntry.GUID
	if targetGUID then
		-- : build macrotext
		local player = cacheEntry.NAME
		local hyphPos = strfind(player, "-")
		local baseName = hyphPos and strsub(player, 1, hyphPos - 1) or player
		cacheEntry.macrotext = "/target " .. baseName

		-- : localize player database entry
		local dbEntry = NS.PlayerDB[player] or {}
		NS.PlayerDB[player] = dbEntry

		-- : update player databsae
		dbEntry.GUID = targetGUID
		dbEntry.C = data.classToken
		dbEntry.CID = data.classID
		dbEntry.F = data.factionID
		dbEntry.FID = data.factionID
		dbEntry.G = data.guildName
		dbEntry.GR = data.rankName
		dbEntry.GRID = data.rankID
		dbEntry.GRN = data.guildRealm
		dbEntry.HL = data.honorLevel
		dbEntry.L = data.level
		dbEntry.RC = data.raceName
		dbEntry.RID = data.raceID
		dbEntry.RT = data.raceToken
		dbEntry.S = data.sexID
		dbEntry.T = currentTime
		if not dbEntry.RL then dbEntry.RL = cacheEntry.RL end

		-- : localize player score cache entry
		local pscEntry = NS.PSC[targetGUID] or {}
		NS.PSC[targetGUID] = pscEntry

		-- : update player score cache entry
		pscEntry.GUID = targetGUID
		pscEntry.NAME = player
		pscEntry.fullName = player
		pscEntry.C = data.classToken
		pscEntry.CID = data.classID
		pscEntry.F = data.factionID
		pscEntry.FID = data.factionID
		pscEntry.HL = data.honorLevel
		pscEntry.RC = data.raceName
		pscEntry.RL = dbEntry.RL
		pscEntry.RR = data.realmRelationship
		pscEntry.RT = data.raceToken
		pscEntry.S = data.sexID
		pscEntry.macrotext = cacheEntry.macrotext
		pscEntry.T = currentTime
	end

	-- : refresh active player data
	RefreshActivePlayerData(unitToken)
	return PID
end

--|> name plate unit added
local function NamePlateUnitAdded(unitToken)
	-- : valid unit?
	if IsValidUnitToken(unitToken) then
		-- : unit refreshed?
		RefreshUnitData(unitToken)
	end
end

--|> name plate unit removed
local function NamePlateUnitRemoved(unitToken)
	-- : found unit?
	if NS.NPC[unitToken] then
		-- : delete unit
		NS.NPC[unitToken] = nil
	end
end

--|> update name plate unit
function NS.UpdateNamePlateUnit(unitToken)
	-- : not valid unit?
	if not IsValidUnitToken(unitToken) then
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
			RefreshUnitData(unitToken)

			-- : found?
			if NS.NPC[unitToken] then
				-- : refresh active player data
				RefreshActivePlayerData(unitToken)
			end
		end
	end
end

--|> refresh all nameplates
function NS.RefreshAllNamePlates()
	-- : get all nameplates
	local nameplates = GetNamePlates()
	for _, namePlate in ipairs(nameplates) do
		-- : found valid unit token?
		local unitToken = namePlate:GetUnit()
		if unitToken and IsValidUnitToken(unitToken) then
			-- : refresh unit data
			RefreshUnitData(unitToken)
		end
	end
end

--|> update group roles
local checkMainAssist = false
local function UpdateGroupRoles()
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
local function UpdateBattlefieldScore()
	-- : not engaged yet?
	local matchState = GetActiveMatchState()
	NS.MatchState = matchState
	if matchState <= Enum.PvPMatchState.Engaged then
		-- : get score info by player guid
		local playerInfo = GetScoreInfoByPlayerGuid(NS.Player.GUID)
		if playerInfo then
			-- : process all
			local numScores = GetNumBattlefieldScores()
			local enemyCache = NS.EnemyPlayerCache
			local playerFaction = playerInfo.faction
			for i = 1, numScores do
				-- : found enemy score info?
				local info = GetScoreInfo(i)
				if info and info.name and (playerFaction ~= info.faction) and not issecretvalue(info.name) then
					-- : update
					enemyCache[info.name] = info
				end
			end
		end
		return
	end

	-- : process all
	local count, maxlevels = 0, 0
	local targetMaxLevel = NS.MaxLevel
	for i = 1, MAX_RAID_MEMBERS do
		-- : get raid roster info
		local name, _, _, level = GetRaidRosterInfo(i)
		if name and level then
			-- : max level?
			if level == targetMaxLevel then
				-- : increase
				maxlevels = maxlevels + 1
			end

			-- : increase
			count = count + 1
		end
	end

	-- : max level / mercenary?
	local maxLevelPvP = (count > 0) and (count == maxlevels)
	local playerFaction = NS.Player.FactionID
	if UnitIsMercenary("player") then
		-- : swap faction
		playerFaction = (playerFaction == 1) and 0 or 1
	end

	-- : process all
	local psc = NS.PSC
	local currentTime = time()
	local numScores = GetNumBattlefieldScores()
	local playerDB = NS.PlayerDB
	local currentMapID = NS.mapID
	local playerRealm = NS.PlayerRealm
	local GetClassIDFromName = NS.GetClassIDFromName
	local GetRoleFromSpecialization = NS.GetRoleFromSpecialization
	local GetRaceInfoFromName = NS.GetRaceInfoFromName
	local GetRaceToken = RAC and RAC.GetRaceToken
	for i = 1, numScores do
		-- : found score info?
		local info = GetScoreInfo(i)
		if info and info.name and info.guid and (info.faction ~= playerFaction) then
			-- : found role?
			local guid = info.guid
			local role = "UNKNOWN"
			local roleAssigned = info.roleAssigned
			if info.talentSpec then
				role = GetRoleFromSpecialization(info.talentSpec)
			elseif roleAssigned == 2 then
				role = "TANK"
			elseif roleAssigned == 4 then
				role = "HEALER"
			elseif roleAssigned == 8 then
				role = "DAMAGER"
			end

			-- : finalize player
			local player = info.name
			if info.honorLevel > 0 and not strmatch(player, "-") then
				-- : add player realm
				player = player .. "-" .. playerRealm
			end

			-- : found race token?
			local sexID = select(5, GetPlayerInfoByGUID(guid))
			local classID = GetClassIDFromName(info.classToken)
			local raceToken, raceName = RAC:GetRaceToken(info.raceName)

			-- : localize
			local dbEntry = playerDB[player]
			if not dbEntry then
				-- : initialize
				dbEntry = {}
				playerDB[player] = dbEntry
			end

			-- : update player database entry
			dbEntry.GUID = guid
			dbEntry.C = info.classToken
			dbEntry.CID = classID
			dbEntry.HL = info.honorLevel
			dbEntry.MID = currentMapID
			dbEntry.RC = raceName
			dbEntry.RL = role
			dbEntry.ROLE = roleAssigned
			dbEntry.RT = raceToken
			dbEntry.S = sexID
			dbEntry.SPEC = info.talentSpec
			dbEntry.T = currentTime

			-- : localize
			local pscEntry = psc[guid]
			if not pscEntry then
				-- : initialize
				pscEntry = {}
				psc[guid] = pscEntry
			end

			-- : update player score cache entry
			pscEntry.GUID = guid
			pscEntry.NAME = player
			pscEntry.fullName = player
			pscEntry.C = info.classToken
			pscEntry.CID = classID
			pscEntry.F = info.faction
			pscEntry.HL = info.honorLevel
			pscEntry.MID = currentMapID
			pscEntry.RC = raceName
			pscEntry.RL = role
			pscEntry.ROLE = roleAssigned
			pscEntry.RT = raceToken
			pscEntry.S = sexID
			pscEntry.SPEC = info.talentSpec
			pscEntry.T = currentTime

			-- : found raceID + factionID ?
			local raceID, factionID = GetRaceInfoFromName(raceName, nil)
			if raceID and factionID then
				-- : update
				pscEntry.F = factionID
				pscEntry.RID = raceID
				dbEntry.F = factionID
				dbEntry.RID = raceID
			end

			-- : max level pvp?
			if maxLevelPvP then
				-- : update
				pscEntry.L = targetMaxLevel
				dbEntry.L = targetMaxLevel
			end
		end
	end
end

--|> validate player score cache
local EXPIRY_TIME = 86400 * 7
local function ValidatePSC()
	-- : localize
	local psc = NS.PSC
	local playerFaction = NS.Player.FactionID
	local currentTime = time()
	local cutOffTime = currentTime - EXPIRY_TIME

	-- : process all
	local GetRaceToken = RAC and RAC.GetRaceToken
	for GUID, data in pairs(psc) do
		-- : invalid player?
		local shouldDelete = false
		if data.HL == 0 or data.F == playerFaction or not data.T then
			shouldDelete = true
		elseif mfloor(data.T) ~= data.T then
			data.T = currentTime
		elseif data.T < cutOffTime then
			shouldDelete = true
		end

		-- : should delete?
		if shouldDelete then
			-- : delete
			wipe(data)
			psc[GUID] = nil
		else
			-- : no race name?
			local raceName, raceToken
			if not data.RC then
				-- : found data race name?
				local info = data.info
				if info and info.raceName then
					-- : found race token?
					raceToken, raceName = RAC:GetRaceToken(info.raceName)
					if raceToken and raceName then
						-- : update
						data.RC = raceName
						data.RT = raceToken
					end
				end
			-- : no race token?
			elseif not data.RT then
				-- : found race token?
				raceToken, raceName = RAC:GetRaceToken(data.RC)
				if raceToken and raceName then
					-- : update
					data.RC = raceName
					data.RT = raceToken
				end
			end

			-- : found GUID?
			if not data.GUID then
				data.GUID = GUID
			end

			-- : found old realName?
			local realName = data.realName
			if realName then
				data.NAME = realName
				data.fullName = realName
				data.realName = nil
			end

			-- : delete
			data.realGUID = nil
		end
	end
end

--|> create weizFrame (for specialization text)
local function weizFrame_Create()
	-- : create / setup frame
	weizFrame = weizFrame or CreateFrame("Frame", nil, UIParent)
	weizFrame:SetSize(150, 20)
	weizFrame:ClearAllPoints()
	weizFrame.Text = weizFrame:CreateFontString(nil, "OVERLAY")
	weizFrame.Text:SetFont(SM:Fetch("font", "Roboto Condensed BoldItalic"), 12, "OUTLINE")
	weizFrame.Text:SetAllPoints()
	weizFrame.Text:SetTextColor(1, 1, 1, 1)
end

--|> pulse update
local pulseTimeoutCount = 1
local pulseTargetCount = 1
local function PulseTimeoutUpdate()
	-- : every 2 seconds?
	if pulseTimeoutCount == 2 then
		pulseTimeoutCount = 1
		if NS.NearbyCount and NS.NearbyCount > 0 then
			NS.ManageListTimeouts()
			NS.RefreshAllNamePlates()
		end
	else
		pulseTimeoutCount = pulseTimeoutCount + 1
	end

	-- : every 5 seconds?
	if pulseTargetCount == 5 then
		pulseTargetCount = 1
		NS.UpdateNamePlateUnit("target")
		UpdateGroupRoles()
	else
		pulseTargetCount = pulseTargetCount + 1
	end
end

--|> pulse event
function NS.PulseEvent()
	PulseTimeoutUpdate()
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
		NamePlateUnitAdded(unitToken)
	-- : name plate unit removed?
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		-- : get name plate
		local unitToken = ...
		NamePlateUnitRemoved(unitToken)
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
		UpdateGroupRoles()
		weizFrame_Create()

		-- : get proper zone / state
		NS.Zone.pvpType = select(1, GetZonePVPInfo())
		NS.Zone.InInstance, NS.Zone.instance = IsInInstance()
		NS.MatchState = GetActiveMatchState()
		NS.mapID = GetBestMapForUnit("player")

		-- : validate player score cache
		ValidatePSC()
	-- : player leaving world?
	elseif event == "PLAYER_LEAVING_WORLD" then
		-- : update specialization
		UpdateNamePlateSpecialization()

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
			UpdateGroupRoles()
		end
	-- : player roles changed?
	elseif event == "PLAYER_ROLES_ASSIGNED" then
		-- : update group roles
		UpdateGroupRoles()
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
		UpdateNamePlateSpecialization(namePlate, unitToken)
	-- : player target died?
	elseif event == "PLAYER_TARGET_DIED" then
		-- : update specialization
		UpdateNamePlateSpecialization()
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
		UpdateBattlefieldScore()

		-- : update group roles
		UpdateGroupRoles()
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
						NS.PID_Cache[PID].specialization = GetMouseoverSpecialization("mouseover")
						if NS.PID_Cache[PID].specialization then
							-- : update specialization
							UpdateNamePlateSpecialization(namePlate, unitToken)
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
