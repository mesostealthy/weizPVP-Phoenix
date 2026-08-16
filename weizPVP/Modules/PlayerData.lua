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
local function AddNewPlayer(playerToken, player, name, realm)
	-- Update PlayerCache info
	NS.PlayerActiveCache[playerToken] = NS.PlayerActiveCache[playerToken] or {}
	NS.PlayerActiveCache[playerToken].name = name
	NS.PlayerActiveCache[playerToken].realm = realm
	NS.PlayerActiveCache[playerToken].player = player
	NS.PlayerActiveCache[playerToken].displayName = gsub(name, "-(.*)", "")
	NS.PlayerActiveCache[playerToken].macrotext = "/target " .. gsub(name, "-(.*)", "")
end

--> UpdatePlayerActiveCache <----------------------------------------
local newPlayerOnList = false
function NS.UpdatePlayerActiveCache(NPC, unitToken, dead)
	-- : Check for player already in cache
	local playerToken, player, name, realm = NS.GetPlayerTokens(unitToken)
	if playerToken and player then
		-- : not created yet?
		if not NS.PlayerActiveCache[playerToken] then
			-- : add new player
			AddNewPlayer(playerToken, player, name, realm)
			newPlayerOnList = true
		end

		-- : update fields
		NS.PlayerActiveCache[playerToken].C = NPC.C
		NS.PlayerActiveCache[playerToken].CID = NPC.CID
		NS.PlayerActiveCache[playerToken].G = NPC.G
		NS.PlayerActiveCache[playerToken].L = NPC.L
		NS.PlayerActiveCache[playerToken].RC = NPC.RC
		NS.PlayerActiveCache[playerToken].RID = NPC.RID
		NS.PlayerActiveCache[playerToken].name = NPC.name
		NS.PlayerActiveCache[playerToken].realm = NPC.realm
		NS.PlayerActiveCache[playerToken].player = NPC.player
		NS.PlayerActiveCache[playerToken].PT = NPC.PT

		-- : add player to near by
		NS.AddPlayerDataToNearby(playerToken, newPlayerOnList)
		newPlayerOnList = false
	end
end

--> ValidatePlayerActiveCache
function NS.ValidatePlayerActiveCache(unitToken, playerToken)
	-- : no player active cache?
	local playerCache = NS.PlayerActiveCache[playerToken]
	if not playerCache then
		-- : finished
		return
	end

	-- : CLASS
	if not playerCache.C then
		playerCache.C, playerCache.CID = UnitClassBase(unitToken)
	end 

	-- : FACTION
	if not playerCache.F then
		playerCache.F = UnitFactionGroup(unitToken) == "Alliance" and 1 or 0
	end

	-- : GUILD
	if not playerCache.G then
		playerCache.G = getGuildInfo(unitToken)
	end

	-- : LEVEL
	if not playerCache.L then
		playerCache.L = UnitLevel(unitToken)
	end

	-- : RACE / RACE ID
	if not playerCache.RC then
		playerCache.RC, playerCache.RT, playerCache.RID = UnitRace(unitToken)
	end

	-- : REALM RELATIONSHIP
	if not playerCache.RR then
		playerCache.RR = UnitRealmRelationship(unitToken)
	end

	-- : SEX
	if not playerCache.S then
		playerCache.S = UnitSex(unit)
	end
end
