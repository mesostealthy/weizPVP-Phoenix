---------------------------------------------------------------------------------------------------
-- |> DATA PROCESSING
-- 📌 Functions that help acquire and manage data involving the PlayerDB
---------------------------------------------------------------------------------------------------
local _, NS = ...

--: 🆙 Upvalues :----------------------
local issecretvalue = issecretvalue
local GetGuildInfo, GetUnitName = GetGuildInfo, GetUnitName
local UnitClassBase, UnitLevel, UnitRace = UnitClassBase, UnitLevel, UnitRace
local UnitFactionGroup, UnitGUID, UnitName = UnitFactionGroup, UnitGUID, UnitName
local select = select
local gsub = gsub
local time = time

--> AddNewPlayer <---------------------------------------------------
-- : Updates data in the PlayerActiveCache
-- : Sends data off the Lists to be processed
local function AddNewPlayer(PID, name, realm)
	-- Update PlayerCache info
	NS.PlayerActiveCache[PID] = NS.PlayerActiveCache[PID] or {}
	NS.PlayerActiveCache[PID].PID = PID
	-- Name / Realm
	NS.PlayerActiveCache[PID].Name = name
	NS.PlayerActiveCache[PID].Realm = realm

	-- has data?
	if NS.PID_Cache[PID] then
		-- : update base info
		NS.PlayerActiveCache[PID].C = NS.PID_Cache[PID].C
		NS.PlayerActiveCache[PID].CID = NS.PID_Cache[PID].CID
		NS.PlayerActiveCache[PID].E = NS.PID_Cache[PID].E
		NS.PlayerActiveCache[PID].F = NS.PID_Cache[PID].F
		NS.PlayerActiveCache[PID].FID = NS.PID_Cache[PID].FID
		NS.PlayerActiveCache[PID].G = NS.PID_Cache[PID].G
		NS.PlayerActiveCache[PID].GR = NS.PID_Cache[PID].GR
		NS.PlayerActiveCache[PID].GRID = NS.PID_Cache[PID].GRID
		NS.PlayerActiveCache[PID].GRN = NS.PID_Cache[PID].GRN
		NS.PlayerActiveCache[PID].HL = NS.PID_Cache[PID].HL
		NS.PlayerActiveCache[PID].L = NS.PID_Cache[PID].L
		NS.PlayerActiveCache[PID].RC = NS.PID_Cache[PID].RC
		NS.PlayerActiveCache[PID].RID = NS.PID_Cache[PID].RID
		NS.PlayerActiveCache[PID].RL = NS.PID_Cache[PID].RL
		NS.PlayerActiveCache[PID].RR = NS.PID_Cache[PID].RR
		NS.PlayerActiveCache[PID].RT = NS.PID_Cache[PID].RT
		NS.PlayerActiveCache[PID].S = NS.PID_Cache[PID].S

		-- : update potentially secret data
		NS.PlayerActiveCache[PID].GUID = NS.PID_Cache[PID].GUID
		NS.PlayerActiveCache[PID].NAME = NS.PID_Cache[PID].NAME
		NS.PlayerActiveCache[PID].macrotext = NS.PID_Cache[PID].macrotext
		NS.PlayerActiveCache[PID].displayGuild = NS.PID_Cache[PID].G or nil
		NS.PlayerActiveCache[PID].fullName = NS.PID_Cache[PID].fullName or nil
	end

	-- has name?
	if name then
		-- not secret?
		if not issecretvalue(name) then
			-- DISPLAY NAME
			NS.PlayerActiveCache[PID].NAME = name
			NS.PlayerActiveCache[PID].displayName = gsub(name, "-(.*)", "")
			NS.PlayerActiveCache[PID].macrotext = "/target " .. gsub(name, "-(.*)", "")

			-- has database data?
			if NS.PlayerDB[name] then
				-- DISPLAY GUILD
				NS.PlayerActiveCache[PID].G = NS.PlayerDB[name].G or nil
				NS.PlayerActiveCache[PID].displayGuild = NS.PlayerDB[name].G or nil

				-- LEVEL
				if NS.PlayerActiveCache[PID].L and NS.PlayerDB[name].L then
					NS.PlayerActiveCache[PID].L = NS.PlayerDB[name].L
					NS.PlayerActiveCache[PID].E = NS.PlayerDB[name].E
				end

				-- ROLE
				if not NS.PlayerActiveCache[PID].RL and NS.PlayerDB[name].RL then
					NS.PlayerActiveCache[PID].RL = NS.PlayerDB[name].RL
				end
			end
		else
			-- use same
			NS.PlayerActiveCache[PID].displayName = name
		end
	end
end

--> UpdatePlayerActiveCache <----------------------------------------
local newPlayerOnList = false
function NS.UpdatePlayerActiveCache(PID, name, realm, dead)
	-- : exists?
	if not PID or not name then
		return
	end

	-- : Check for player already in cache
	if not NS.PlayerActiveCache[PID] then
		AddNewPlayer(PID, name, realm)
		newPlayerOnList = true
	end

	-- : DEAD
	if dead ~= nil then
		NS.PlayerActiveCache[PID].Dead = dead
		if dead then
			NS.PlayerActiveCache[PID].Health = 0
		elseif not dead and NS.PlayerActiveCache[PID].Health == 0 then
			NS.PlayerActiveCache[PID].Health = 1
		end
	end

	-- : Formatted Guild
	if not issecretvalue(name) then
		if (not NS.PlayerActiveCache[PID].displayGuild) and NS.PlayerDB[name] and NS.PlayerDB[name].G then
			NS.PlayerActiveCache[PID].displayGuild = NS.ConvertString_CyrillicToRomanian(NS.PlayerDB[name].G)
		end
	end

	-- : add player to near by
	NS.AddPlayerDataToNearby(PID, newPlayerOnList)

	-- : no longer estimated?
	if NS.PlayerActiveCache[PID].L then
		-- : not estimated
		NS.PlayerActiveCache[PID].E = nil
	end

	newPlayerOnList = false
end

--> ValidatePlayerActiveCache
function NS.ValidatePlayerActiveCache(unit, PID)
	-- : no player active cache?
	if not NS.PlayerActiveCache[PID] then
		-- : finished
		return
	end
 
	-- : CLASS?
	local className, classID = NS.PlayerActiveCache[PID].C, NS.PlayerActiveCache[PID].CID
	if not NS.PlayerActiveCache[PID].C or not NS.PlayerActiveCache[PID].CID then
		-- : update
		className, classID = UnitClassBase(unit)
		NS.PlayerActiveCache[PID].C = className
		NS.PlayerActiveCache[PID].CID = classID
	end

	-- : FACTION ID
	local factionID = NS.PlayerActiveCache[PID].F
	if not NS.PlayerActiveCache[PID].F then
		-- : update
		factionID = UnitFactionGroup(unit) == "Alliance" and 1 or 0
		NS.PlayerActiveCache[PID].F = factionID
	end

	-- : GUILD
	local guildName, rankID = NS.PlayerActiveCache[PID].G, NS.PlayerActiveCache[PID].GRID
	if not NS.PlayerActiveCache[PID].G or not NS.PlayerActiveCache[PID].GRID then
		-- : update
		guildName, _, rankID, _ = GetGuildInfo(unit)
		NS.PlayerActiveCache[PID].G = guildName
		NS.PlayerActiveCache[PID].GRID = rankID or 0
	end

	-- : HONOR LEVEL
	local honorLevel = NS.PlayerActiveCache[PID].HL
	if not NS.PlayerActiveCache[PID].HL then
		-- : update
		honorLevel = UnitHonorLevel(unit)
		NS.PlayerActiveCache[PID].HL = honorLevel
	end

	-- : LEVEL
	local level = NS.PlayerActiveCache[PID].L
	if not NS.PlayerActiveCache[PID].L then
		-- : update
		level = UnitLevel(unit)
		NS.PlayerActiveCache[PID].L = level
		NS.PlayerActiveCache[PID].E = nil
	end

	-- : RACE / RACE ID
	local raceToken = nil
	local raceName, raceID = NS.PlayerActiveCache[PID].RC, NS.PlayerActiveCache[PID].RID
	if not NS.PlayerActiveCache[PID].RC or not NS.PlayerActiveCache[PID].RID then
		-- : update
		raceName, raceToken, raceID = UnitRace(unit)
		NS.PlayerActiveCache[PID].RC = raceName
		NS.PlayerActiveCache[PID].RID = raceID
	end

	-- : REALM RELATIONSHIP
	local realmRelationship = NS.PlayerActiveCache[PID].RR
	if not NS.PlayerActiveCache[PID].RR then
		-- : save
		realmRelationship = UnitRealmRelationship(unit)
		NS.PlayerActiveCache[PID].RR = realmRelationship
	end

	-- : SEX
	local sexID = NS.PlayerActiveCache[PID].S
	if not NS.PlayerActiveCache[PID].S then
		-- : update
		sexID = UnitSex(unit)
		NS.PlayerActiveCache[PID].S = sexID
	end

	-- : no real name yet?
	if not NS.PlayerActiveCache[PID].NAME or not NS.PlayerActiveCache[PID].macrotext then
		-- : has data?
		if NS.PID_Cache[PID] then
			-- : save data
			NS.PlayerActiveCache[PID].GUID = NS.PID_Cache[PID].GUID
			NS.PlayerActiveCache[PID].NAME = NS.PID_Cache[PID].NAME
			NS.PlayerActiveCache[PID].macrotext = NS.PID_Cache[PID].macrotext

			-- : role needed?
			if not NS.PlayerActiveCache[PID].RL and NS.PID_Cache[PID].RL then
				-- : save role
				NS.PlayerActiveCache[PID].RL = NS.PID_Cache[PID].RL
			end
		end
	end
end
