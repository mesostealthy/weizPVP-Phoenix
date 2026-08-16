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
local GetGuildInfo, UnitIsUnit = GetGuildInfo, UnitIsUnit
local UnitExists, UnitIsPlayer, UnitName = UnitExists, UnitIsPlayer, UnitName
local UnitIsDeadOrGhost, UnitHealthPercent = UnitIsDeadOrGhost, UnitHealthPercent
local GetNumBattlefieldScores, IsInInstance = GetNumBattlefieldScores, IsInInstance
local InCombatLockdown, RequestBattlefieldScoreData = InCombatLockdown, RequestBattlefieldScoreData
local UnitCanAttack, UnitIsEnemy, UnitRealmRelationship = UnitCanAttack, UnitIsEnemy, UnitRealmRelationship
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
NS.MatchState = 0
NS.mainAssist = nil
NS.EnemyPC = {}
NS.FriendPC = {}
NS.NamePlateLastTarget = nil

--:> get player tokens
function NS.GetPlayerTokens(unitToken)
	-- : invalid?
	if not unitToken then
		-- : invalid
		return nil, nil, nil, nil
	end

	-- : found name?
	local player, playerToken
	local name, realm = UnitName(unitToken)
	if not name or issecretvalue(name) or issecretvalue(realm) then
		-- : invalid
		return nil, nil, nil, nil
	end

	-- : check realm relationship
	local realmRelationship = UnitRealmRelationship(unitToken)
	if not realmRelationship then
		-- : invalid
		return nil, nil, nil, nil
	end

	-- : same realm?
	if (realmRelationship == LE_REALM_RELATION_SAME) then
		-- : same realm
		player = name .. "-" .. NS.PlayerRealm
		playerToken = name
	else
		-- : no realm?
		if not realm then
			-- : invalid
			return nil, nil, nil, nil
		end

		-- : add realm
		player = name .. "-" .. realm
		playerToken = player
	end

	-- : success
	return playerToken, player, name, realm
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

--|> get mouseover specialization
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
		end
	-- : priest?
	elseif classToken == "PRIEST" then
		return (UnitPowerType(unitToken) == 13) and "DAMAGER" or "HEALER"
	-- : shaman?
	elseif classToken == "SHAMAN" then
		return (UnitPowerType(unitToken) == 0) and "HEALER" or "DAMAGER"
	end

	-- : failed
	return nil
end

--|> update specialization
local function UpdateNamePlateSpecialization()
	-- : specialization text not enabled?
	if not NS.Options.BattleGrounds.SpecText then
		-- : finished
		return
	end

	-- : sanity checks
	local namePlate = GetNamePlateForUnit("target")
	if namePlate then
		-- : get player tokens
		local playerToken, player, name, realm = NS.GetPlayerTokens("target")
		local eCache = NS.EnemyPC[playerToken]
		if eCache and eCache.talentSpec then
			-- : show
			local textWidget = weizFrame.Text
			textWidget:SetText(eCache.talentSpec)
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

--|> refresh unit data
local function RefreshUnitData(unitToken)
	-- : valid unitToken?
	if not IsValidUnitToken(unitToken) then
		-- : failed
		return nil
	end

	-- : get player tokens
	local playerToken, player, name, realm = NS.GetPlayerTokens(unitToken)
	if playerToken and player then
		-- : not created?
		if not NS.NPC[player] then
			-- : create
			NS.NPC[player] = {}
			NS.NPC[player].C, NS.NPC[player].CID = UnitClassBase(unitToken)
			NS.NPC[player].L = UnitLevel(unitToken)
			NS.NPC[player].RC, _, NS.NPC[player].RID = UnitRace(unitToken)
			NS.NPC[player].name = name
			NS.NPC[player].realm = realm
			NS.NPC[player].player = player
			NS.NPC[player].PT = playerToken
		end

		-- : update stuff
		NS.NPC[player].G = GetGuildInfo(unitToken)
		NS.NPC[player].T = currentTime

		-- : update player cache
		NS.UpdatePlayerActiveCache(NS.NPC[player], unitToken)
	end
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
		for unit, playerToken in pairs(NS.NPC) do
			-- : unit is target?
			if UnitIsUnit(unitToken, unit) then
				-- : update unit
				unitToken = unit
				break
			end
		end
	end

	-- : get name plate
	local namePlate = GetNamePlateForUnit(unitToken)
	if namePlate and namePlate.UnitFrame then
		-- : get unit
		local processed = false
		local unit = namePlate:GetUnit()
		if unit then
			-- : refresh unit data
			RefreshUnitData(unit)
		end
	end

	-- : update specialization
	UpdateNamePlateSpecialization()
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
	-- : get score info by player guid
	local playerInfo = GetScoreInfoByPlayerGuid(NS.Player.GUID)
	if not playerInfo then
		-- : finished
		return
	end

	-- : process all
	local eCache = NS.EnemyPC
	local fCache = NS.FriendPC
	local numScores = GetNumBattlefieldScores()
	for i = 1, numScores do
		-- : get info
		local info = GetScoreInfo(i)
		if info and info.name then
			-- : matches player?
			if info.faction == playerInfo.faction then
				-- : friend
				fCache[info.name] = info
			else
				-- : enemy
				eCache[info.name] = info
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
	-- : name plate unit added?
	if event == "NAME_PLATE_UNIT_ADDED" then
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
		NS.EnemyPC = {}
		NS.FriendPC = {}
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
		if (baseToken == "nameplate") or (unitToken == "player") then
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
			end
		end
	end
end

-- : create events frame
NS.weizPVP_Events = CreateFrame("Frame", nil, UIParent)
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
