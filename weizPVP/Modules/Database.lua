---------------------------------------------------------------------------------------------------
--|> DATABASE
---------------------------------------------------------------------------------------------------
local _, NS = ...

-- : Libraries :------------------------
local RAC = LibStub("LibRaces-1.0")

-- : 🆙 Upvalues :----------------------
local GetFactionInfo = C_CreatureInfo.GetFactionInfo
local CopyTable, MergeTable = CopyTable, MergeTable
local C_Timer_After = C_Timer.After
local issecretvalue = issecretvalue
local pairs, time, wipe = pairs, time, wipe
local strmatch = string.match

-- : Constants :------------------------
local SECOND_IN_DAY = 86400
local DATABASE_VERSION = 3

--> get player info by name
function weizPVP:GetPlayerInfoByName(player)
	-- : sanity check
	if player and not issecretvalue(player) and (player ~= "") then
		-- : no hyphen?
		if (not strmatch(player, "-")) then
			-- add player realm
			player = player .. "-" .. NS.PlayerRealm
		end

		-- : found?
		if NS.PlayerDB[player] then
			-- : return player
			return NS.PlayerDB[player]
		end
	end

	-- : failed
	return nil
end

--> process player info
local numPlayersChecked = 0
local function CheckPlayerInfoByGUID(player, guid, bRetry)
	-- : valid guid?
	if not guid or issecretvalue(guid) or (guid == "") then
		-- : failed
		return 0
	end

	-- : found player?
	if NS.PlayerDB[player] then
		-- : bot?
		if NS.PlayerDB[player].HL and (NS.PlayerDB[player].HL == 0) then
			-- : finished
			return 0
		end
	end

	-- : too many?
	if numPlayersChecked >= 500 then
		-- : try later
		return 0
	end

	-- : increase
	numPlayersChecked = numPlayersChecked + 1

	-- : get player info by guid
	local _, className, _, raceName, sexID, name, realm = GetPlayerInfoByGUID(guid)
	if issecretvalue(name) or issecretvalue(realm) then
		-- : failed
		return 0
	elseif not name or (name == "") then
		-- : should retry?
		if bRetry then
			-- : try again
			C_Timer_After(1, function(guid, bRetry)
				-- : call recursively
				CheckPlayerInfoByGUID(player, guid, bRetry)
			end)
			return
		end

		-- : failed
		return 0
	end

	-- : no realm?
	if not realm or (realm == "") then
		-- : use player realm
		realm = NS.PlayerRealm
	end

	-- : player name updated?
	local currentPlayer = name .. "-" .. realm
	if player ~= currentPlayer then
		-- : has old entry?
		if NS.PlayerDB[player] then
			-- : has new entry?
			if NS.PlayerDB[currentPlayer] then
				-- : merge tables
				MergeTable(NS.PlayerDB[currentPlayer], NS.PlayerDB[player])
			else
				-- : copy table
				NS.PlayerDB[currentPlayer] = CopyTable(NS.PlayerDB[player])
			end

			-- : delete old
			wipe(NS.PlayerDB[player])
			NS.PlayerDB[player] = nil
			player = currentPlayer
		end
	end

	-- : found player?
	if NS.PlayerDB[player] then
		-- : no class name?
		if not NS.PlayerDB[player].C then
			NS.PlayerDB[player].C = className
		end

		-- : no class ID?
		if not NS.PlayerDB[player].CID then
			local classID = NS.Classes[className]
			NS.PlayerDB[player].CID = classID
		end

		-- : no race name?
		if not NS.PlayerDB[player].RC then
			NS.PlayerDB[player].RC = raceName
		end

		-- : no race ID?
		if not NS.PlayerDB[player].RID then
			-- : get race info from name (if possible)
			local raceID, factionID = NS.GetRaceInfoFromName(NS.PlayerDB[player].RC, nil)
			if raceID and factionID then
				if not NS.PlayerDB[player].RID then
					NS.PlayerDB[player].RID = raceID
				end
				NS.PlayerDB[player].F = factionID
			end
		end

		-- : no sex?
		if not NS.PlayerDB[player].S then
			NS.PlayerDB[player].S = sexID
		end
	end
end

--> Calculate Base ID
local function Validate_Player(player)
	-- : sanity checks
	if (not NS.PlayerDB[player]) then
		-- : failed
		return 0
	end

	-- : no guid?
	if not NS.PlayerDB[player].GUID then
		-- : delete
		NS.PlayerDB[player] = nil
		return 0
	end

	-- : class ID?
	local classID = NS.PlayerDB[player].CID
	if not classID then
		-- : class token?
		if NS.PlayerDB[player].C then
			-- : update
			classID = NS.Classes[NS.PlayerDB[player].C]
			NS.PlayerDB[player].CID = classID
		end
	end

	-- : has race name?
	if NS.PlayerDB[player].RC then
		-- : proper race?
		local raceToken, raceName = RAC:GetRaceToken(NS.PlayerDB[player].RC)
		if raceToken and raceName  then
			-- : updated?
			if raceName and NS.PlayerDB[player].RC ~= raceName then
				-- : update
				NS.PlayerDB[player].RC = raceName
			end
		end
	end

	-- : race ID?
	local factionID
	local raceID = NS.PlayerDB[player].RID
	if raceID then
		-- : no faction id?
		if not NS.PlayerDB[player].F then
			-- : horde?
			local factionInfo = GetFactionInfo(raceID)
			if factionInfo.name == FACTION_HORDE then
				NS.PlayerDB[player].F = 0
			elseif factionInfo.name == FACTION_ALLIANCE then
				NS.PlayerDB[player].F = 1
			end
		end
	-- : has race?
	elseif NS.PlayerDB[player].RC then
		-- : get race info from name (if possible)
		raceID, factionID = NS.GetRaceInfoFromName(NS.PlayerDB[player].RC, nil)
		if raceID and factionID then
			if not NS.PlayerDB[player].RID then
				NS.PlayerDB[player].RID = raceID
			end
			NS.PlayerDB[player].F = factionID
		end
	-- : has guid?
	elseif NS.PlayerDB[player].GUID then
		-- : check player info by GUID
		CheckPlayerInfoByGUID(player, NS.PlayerDB[player].GUID, true)
	end

	-- : no longer exists?
	if not NS.PlayerDB[player] then
		-- : delete
		NS.PlayerDB[player] = nil
		return 0
	end

	-- : faction ID?
	factionID = NS.PlayerDB[player].F
	if factionID ~= 0 and factionID ~= 1 then
		-- : failed
		factionID = nil
	end

	-- : sexID?
	local sexID = NS.PlayerDB[player].S
	if not sexID then
		-- : has guid?
		if NS.PlayerDB[player].GUID then
			-- : check player info by GUID
			CheckPlayerInfoByGUID(player, NS.PlayerDB[player].GUID, true)
		end
	end

	-- : time?
	if NS.PlayerDB[player].T then
		-- : has decimals?
		if math.floor(NS.PlayerDB[player].T) ~= NS.PlayerDB[player].T then
			-- : update
			NS.PlayerDB[player].T = time()
		end
	end

	-- : invalid GUID?
	if NS.PlayerDB[player].GUID then
		-- : check for 
		local _, count = gsub(NS.PlayerDB[player].GUID, "-", "")
		if (count > 2) then
			-- : split name
			local name, realm = strsplit("-", player)
			if name then
				-- move player
				NS.PlayerDB[name] = CopyTable(NS.PlayerDB[player])
				wipe(NS.PlayerDB[player])
				NS.PlayerDB[player] = nil
			end
		end
	end

	-- : finished
	return 1
end

--> Optimize Database <----------------------------------------------
local function OptimizeDatabase(currentTime, days)
	NS.Options.Database.LastCleaned = currentTime
	NS.Options.Database.VERSION = DATABASE_VERSION
	local additionalTime = days * SECOND_IN_DAY

	for player, k in pairs(NS.PlayerDB) do
		--* v2 -  clean old db leftovers (Name)
		if NS.PlayerDB[player].Role then
			NS.PlayerDB[player].RL = NS.PlayerDB[player].Role
			NS.PlayerDB[player].Role = nil
		end
		if NS.PlayerDB[player].Race then
			NS.PlayerDB[player].RC = NS.PlayerDB[player].Race
			NS.PlayerDB[player].Race = nil
		end
		if NS.PlayerDB[player].Guild then
			NS.PlayerDB[player].G = NS.PlayerDB[player].Guild
			NS.PlayerDB[player].Guild = nil
		end
		if NS.PlayerDB[player].Class then
			NS.PlayerDB[player].C = NS.PlayerDB[player].Class
			NS.PlayerDB[player].Class = nil
		end
		if NS.PlayerDB[player].Timestamp then
			NS.PlayerDB[player].T = NS.PlayerDB[player].Timestamp
			NS.PlayerDB[player].Timestamp = nil
		end
		if NS.PlayerDB[player].Level then
			NS.PlayerDB[player].L = NS.PlayerDB[player].Level
			NS.PlayerDB[player].Level = nil
		end
		if NS.PlayerDB[player].Estimated ~= nil then
			NS.PlayerDB[player].E = NS.PlayerDB[player].Estimated
			NS.PlayerDB[player].Estimated = nil
		end
		if NS.PlayerDB[player].E == false then
			NS.PlayerDB[player].E = nil
		end

		--* v1 -  clean old db leftovers (Name)
		if NS.PlayerDB[player].Name then
			NS.PlayerDB[player].Name = nil
		end

		--* v5?
		if NS.PlayerDB[player].guid then
			if not NS.PlayerDB[player].GUID then
				NS.PlayerDB[player].GUID = NS.PlayerDB[player].guid
			end
			NS.PlayerDB[player].guid = nil
		end
		if NS.PlayerDB[player].C and not NS.PlayerDB[player].CID then
			NS.PlayerDB[player].CID = NS.Classes[NS.PlayerDB[player].C]
		end
		if NS.PlayerDB[player].E and NS.PlayerDB[player].L and NS.PlayerDB[player].RID then
			NS.PlayerDB[player].E = nil
		end
		if NS.PlayerDB[player].R then
			NS.PlayerDB[player].GRID = NS.PlayerDB[player].R
			NS.PlayerDB[player].R = nil
		end

		--* v0 - Clean out players not seen since x days
		if k.T and k.T + additionalTime < currentTime then
			wipe(NS.PlayerDB[player])
			NS.PlayerDB[player] = nil
		end

		-- : validate player
		Validate_Player(player)
	end
end

--> CLEAN DB: Specific Days <----------------------------------------
function NS.CleanDB_SpecificDays(days)
	numPlayersChecked = 0
	days = days or NS.Options.Database.CleanTime
	local currentTime = time()
	if NS.Options.Database.VERSION ~= DATABASE_VERSION then
		OptimizeDatabase(currentTime, days)
	elseif NS.Options.Database.LastCleaned + SECOND_IN_DAY < currentTime then -- only update once a day
		OptimizeDatabase(currentTime, days)
	end
end

--> Refresh Config <-------------------------------------------
function NS.RefreshConfig(event, charDB, profileName)
	wipe(NS.Options)
	NS.Options = CopyTable(NS.charDB.profile.Options)
	NS.oldKosList = NS.charDB.profile.KosList or nil
	NS.PSC = NS.globalDB.global.PSC or {}
	NS.SetCoreFramePosition()
	NS.GetPVPZone()

	-- copied?
	if event == "OnProfileCopied" then
		-- OLD format being copied?
		local profile = charDB.profiles[profileName]
		if profile.PSC then
			for k,v in pairs(profile.PSC) do
				NS.PSC[k] = CopyTable(profile.PSC[k])
				wipe(profile.PSC[k])
				profile.PSC[k] = nil
			end
			profile.PSC = nil
		end

		-- OLD format currently?
		if NS.charDB.profile.PSC then
			for k,v in pairs(NS.charDB.profile.PSC) do
				NS.PSC[k] = CopyTable(NS.charDB.profile.PSC[k])
				wipe(NS.charDB.profile.PSC[k])
				NS.charDB.profile.PSC[k] = nil
			end
			NS.charDB.profile.PSC = nil
		end
	end
end

--> Load Database <--------------------------------------------------
function NS.LoadDB()
	-- LOAD GLOBAL INFO (ACCOUNT-WIDE) DB
	NS.global_info = LibStub("AceDB-3.0"):New("_weizpvp_global_info", {}, false)

	-- LOAD GLOBAL (ACCOUNT-WIDE) DB
	NS.globalDB = LibStub("AceDB-3.0"):New("_weizpvp_globaldb", NS._DefaultGlobalOptions, false)
	NS.GlobalVersionUpgradeCheck()
	NS.PlayerDB = NS.globalDB.global.PlayerDB or {}
	NS.KosList = NS.globalDB.global.KosList or {}
	NS.PSC = NS.globalDB.global.PSC or {}

	-- LOAD CHARACTER DB
	NS.charDB = LibStub("AceDB-3.0"):New("_weizpvp_chardb", NS._DefaultProfileOptions, true)
	NS.charDB.RegisterCallback(NS, "OnProfileChanged", NS.RefreshConfig)
	NS.charDB.RegisterCallback(NS, "OnProfileCopied", NS.RefreshConfig)
	NS.charDB.RegisterCallback(NS, "OnProfileReset", NS.RefreshConfig)
	NS.Options = NS.charDB.profile.Options
	NS.oldKosList = NS.charDB.profile.KosList or nil

	-- OLD format?
	if NS.charDB.profile.PSC then
		for k,v in pairs(NS.charDB.profile.PSC) do
			NS.PSC[k] = CopyTable(NS.charDB.profile.PSC[k])
			wipe(NS.charDB.profile.PSC[k])
			NS.charDB.profile.PSC[k] = nil
		end
		NS.charDB.profile.PSC = nil
	end

	-- MAINTAIN DB
	NS.CleanDB_SpecificDays(NS.Options.Database.CleanTime)
	NS.VersionUpgradeCheck() -- update check
end
