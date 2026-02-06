---------------------------------------------------------------------------------------------------
-- |> DATA PROCESSING
-- 📌 Functions that help acquire and manage data involving the PlayerDB
---------------------------------------------------------------------------------------------------
local _, NS = ...

--: 🆙 Upvalues :----------------------
local issecretvalue = issecretvalue
local GetGuildInfo, GetUnitName = GetGuildInfo, GetUnitName
local UnitPercentHealthFromGUID = UnitPercentHealthFromGUID
local UnitClass, UnitLevel, UnitRace = UnitClass, UnitLevel, UnitRace
local UnitCanAttack, UnitExists, UnitOnTaxi = UnitCanAttack, UnitExists, UnitOnTaxi
local CanInspect, InCombatLockdown, NotifyInspect = CanInspect, InCombatLockdown, NotifyInspect
local UnitIsDeadOrGhost, UnitIsEnemy, UnitIsPlayer = UnitIsDeadOrGhost, UnitIsEnemy, UnitIsPlayer
local UnitHealth, UnitHealthMax, UnitName = UnitHealth, UnitHealthMax, UnitName
local UnitFactionGroup, UnitGUID = UnitFactionGroup, UnitGUID
local select = select
local gsub = gsub
local time = time

--> AddNewPlayer <---------------------------------------------------
-- : Updates data in the PlayerActiveCache
-- : Sends data off the Lists to be processed
local function AddNewPlayer(PID, name)
	-- Update PlayerCache info
	NS.PlayerActiveCache[PID] = NS.PlayerActiveCache[PID] or {}
	NS.PlayerActiveCache[PID].PID = PID
	-- NAME
	NS.PlayerActiveCache[PID].Name = name

	-- : has NPC data?
	if NS.NPC[PID] then
		-- : copy from NPC
		NS.PlayerActiveCache[PID].C = NS.NPC[PID].C
		NS.PlayerActiveCache[PID].CID = NS.NPC[PID].CID
		NS.PlayerActiveCache[PID].E = NS.NPC[PID].E
		NS.PlayerActiveCache[PID].F = NS.NPC[PID].F
		NS.PlayerActiveCache[PID].G = NS.NPC[PID].G
		NS.PlayerActiveCache[PID].HL = NS.NPC[PID].HL
		NS.PlayerActiveCache[PID].L = NS.NPC[PID].L
		NS.PlayerActiveCache[PID].R = NS.NPC[PID].R
		NS.PlayerActiveCache[PID].RC = NS.NPC[PID].RC
		NS.PlayerActiveCache[PID].RID = NS.NPC[PID].RID
		NS.PlayerActiveCache[PID].RL = NS.NPC[PID].RL
		NS.PlayerActiveCache[PID].S = NS.NPC[PID].S
		NS.PlayerActiveCache[PID].realGUID = NS.NPC[PID].realGUID
		NS.PlayerActiveCache[PID].realName = NS.NPC[PID].realName
		NS.PlayerActiveCache[PID].macrotext = NS.NPC[PID].macrotext
		NS.PlayerActiveCache[PID].displayGuild = NS.NPC[PID].G or nil
	end

	-- not secret?
	if not issecretvalue(name) then
		-- DISPLAY NAME
		NS.PlayerActiveCache[PID].realName = name
		NS.PlayerActiveCache[PID].macrotext = "/target " .. name
		NS.PlayerActiveCache[PID].displayName = gsub(name, "-(.*)", "")

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
	else
		-- use same
		NS.PlayerActiveCache[PID].displayName = name
	end
end

--> UpdatePlayerActiveCache <----------------------------------------
local newPlayerOnList = false
function NS.UpdatePlayerActiveCache(PID, name, dead)
	-- : exists?
	if not PID or not name then
		return
	end

	-- : Check for player already in cache
	if not NS.PlayerActiveCache[PID] then
		AddNewPlayer(PID, name)
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
		if (not NS.PlayerActiveCache[PID].displayGuild) and NS.PlayerDB[name].G then
			NS.PlayerActiveCache[PID].displayGuild = NS.ConvertString_CyrillicToRomanian(NS.PlayerDB[name].G)
		end
	end

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
	-- : CLASS?
	local className, classID = NS.PlayerActiveCache[PID].C, NS.PlayerActiveCache[PID].CID
	if not NS.PlayerActiveCache[PID].C or not NS.PlayerActiveCache[PID].CID then
		className, classID = UnitClassBase(unit)
		NS.PlayerActiveCache[PID].C = className
		NS.PlayerActiveCache[PID].CID = classID
	end

	-- : FACTION ID
	local factionID = NS.PlayerActiveCache[PID].F
	if not NS.PlayerActiveCache[PID].F then
		factionID = UnitFactionGroup(unit) == "Alliance" and 1 or 0
		NS.PlayerActiveCache[PID].F = factionID
	end

	-- : GUILD
	local guildName, rankID = NS.PlayerActiveCache[PID].G, NS.PlayerActiveCache[PID].R
	if not NS.PlayerActiveCache[PID].G or not NS.PlayerActiveCache[PID].R then
		guildName, _, rankID, _ = GetGuildInfo(unit)
		NS.PlayerActiveCache[PID].G = guildName
		NS.PlayerActiveCache[PID].R = rankID or 0
	end

	-- : HONOR LEVEL
	local honorLevel = NS.PlayerActiveCache[PID].HL
	if not NS.PlayerActiveCache[PID].HL then
		honorLevel = UnitHonorLevel(unit)
		NS.PlayerActiveCache[PID].HL = honorLevel
	end

	-- : LEVEL
	local level = NS.PlayerActiveCache[PID].L
	if not NS.PlayerActiveCache[PID].L then
		level = UnitLevel(unit)
		NS.PlayerActiveCache[PID].L = level
		NS.PlayerActiveCache[PID].E = nil
	end

	-- : RACE
	local raceName, raceID = NS.PlayerActiveCache[PID].RC, NS.PlayerActiveCache[PID].RID
	if not NS.PlayerActiveCache[PID].RC or not NS.PlayerActiveCache[PID].RID then
		_, raceName, raceID = UnitRace(unit)
		NS.PlayerActiveCache[PID].RC = raceName
		NS.PlayerActiveCache[PID].RID = raceID
	end

	-- : SEX
	local sexID = NS.PlayerActiveCache[PID].S
	if not NS.PlayerActiveCache[PID].S then
		sexID = UnitSex(unit)
		NS.PlayerActiveCache[PID].S = sexID
	end

	-- : no real name yet?
	if not NS.PlayerActiveCache[PID].realName or not NS.PlayerActiveCache[PID].macrotext then
		-- : find player from PSC
		local GUID = NS.FindPlayerFromPSC(className, raceName, honorLevel)
		if GUID then
			-- : save data
			NS.PlayerActiveCache[PID].realGUID = NS.PSC[GUID].realGUID
			NS.PlayerActiveCache[PID].realName = NS.PSC[GUID].realName
			NS.PlayerActiveCache[PID].macrotext = NS.PSC[GUID].macrotext

			-- : role needed?
			if not NS.PlayerActiveCache[PID].RL and NS.PSC[GUID].RL then
				-- : save role
				NS.PlayerActiveCache[PID].RL = NS.PSC[GUID].RL
			end
		end
	end

	-- : has PID updated?
	local currentPID = NS.GetPlayerIDByUnit(unit)
	if currentPID ~= PID then
		-- : TODO - fix collision
		print("TODO: PID has changed from " .. PID .. " to " .. currentPID)
	end
end

--> Static Role Assignment <-----------------------------------------
function NS.ClassRoleAssign(class)
	if class == "ROGUE" or class == "MAGE" or class == "WARLOCK" or class == "HUNTER" then
		return "DAMAGER"
	end
	return nil
end

--> Get Unit Data <--------------------------------------------------
local currentTime
local fullName
local unitUpdateThreshold = 120 -- 2 minutes between guild/race/level/role checks
function NS.GetUnitData(unit)
	if not unit then
		return
	end
	if UnitExists(unit) and NS.IsUnitValidForTracking(unit) then
		-- : has necessary data?
		currentTime = time()
		local PlayerID = nil
		local GUID = UnitGUID(unit) or nil
		fullName = NS.GetFullNameOfUnit(unit) or nil
		if GUID and fullName and not issecretvalue(GUID) and not issecretvalue(fullName) then
			-- : using GUID
			local PID = "G:" .. GUID
			local name, realm = UnitName(unit)

			-- : Add player to DB if not found
			if not NS.PlayerDB[fullName] then
				NS.PlayerDB[fullName] = {}
				_, NS.PlayerDB[fullName].C = UnitClass(unit)
				NS.PlayerDB[fullName].RL = NS.ClassRoleAssign(NS.PlayerDB[fullName].C)
			end

			-- : update time
			NS.PlayerDB[fullName].T = currentTime

			-- : Update player info if estimated or past update threshold
			if NS.PlayerDB[fullName].T + unitUpdateThreshold > currentTime or NS.PlayerDB[fullName].E then
				local guildName, _, rankID, _ = GetGuildInfo(unit)
				NS.PlayerDB[fullName].G = guildName
				NS.PlayerDB[fullName].L = UnitLevel(unit)
				NS.PlayerDB[fullName].R = rankID or 0
				NS.PlayerDB[fullName].RC = UnitRace(unit)
			end

			-- : Player On Bars?
			if NS.PlayersOnBars[PID] and NS.PlayerActiveCache[PID] then
				NS.PlayerActiveCache[PID].OnTaxi = UnitOnTaxi(unit) or nil
				NS:UnitHealthEvent(unit)
			end

			-- : invalid player database role?
			if not NS.PlayerDB[fullName].RL then
				-- : not already notified?
				if not NS.NotifyInspectCache[PID] then
					-- : not in combat?
					if not InCombatLockdown() then
						-- : not mouseover
						if unit ~= "mouseover" then
							-- : can inspect?
							if CanInspect(unit) then
								-- : estimated / inspect GUID
								NS.PlayerDB[fullName].E = true
								NotifyInspect(unit)
								NS.NotifyInspectCache[PID] = fullName
							end
						end
					end
				end
			else
				-- : not estimated
				NS.PlayerDB[fullName].E = nil
			end

			-- : update player active cache
			NS.UpdatePlayerActiveCache(PID, fullName, nil) -- (PID, name, dead)
			NS.ValidatePlayerActiveCache(unit, PID)
		end
	end
end

--> Remove Friendly Player <-----------------------------------------
local function RemoveFriendlyPlayer(PID)
	--: Remove from Cache
	NS.PlayerActiveCache[PID] = nil

	--: Remove player for lists
	-- Alive
	if NS.ActiveList[PID] then
		NS.ActiveList[PID].TimeAdded = 0
		NS.ActiveList[PID].TimeUpdated = 0
	elseif NS.ActiveDeadList[PID] then
		-- Dead
		NS.ActiveDeadList[PID].TimeAdded = 0
		NS.ActiveDeadList[PID].TimeUpdated = 0
	elseif NS.InactiveList[PID] then
		-- Inactive
		NS.InactiveList[PID].TimeAdded = 0
		NS.InactiveList[PID].TimeUpdated = 0
	elseif NS.InactiveDeadList[PID] then
		-- Inactive Dead
		NS.InactiveDeadList[PID].TimeAdded = 0
		NS.InactiveDeadList[PID].TimeUpdated = 0
	end

	--: Wipe from Current List
	if NS.CurrentNameplates[PID] then
		NS.CurrentNameplates[PID] = nil
	end

	--: Refresh list by re-checking timeouts (which we zeroed)
	NS.ManageListTimeouts()
end

--> Is Unit Valid For Tracking <-------------------------------------
function NS.IsUnitValidForTracking(unit)
	--: Is Player?
	if (not unit) or (not UnitIsPlayer(unit)) then -- input check
		return false
	end

	--: Can we attack this unit?
	if UnitCanAttack("player", unit) or UnitIsEnemy("player", unit) then -- enemy player check
		return true
	end

	--: check name
	local name = UnitName(unit)
	if not name or issecretvalue(name) then
		return false
	end

	--: Check for previously mind-controlled friendly players
	local PID = NS.GetPlayerIDByUnit(unit)
	if NS.PlayerActiveCache[PID] and select(1, UnitFactionGroup(unit)) == NS.Player.Faction then
		RemoveFriendlyPlayer(PID)
	end
	return false
end

-->	Get Full Name of Unit <-----------------------------------------
local name, realm
function NS.GetFullNameOfUnit(unit)
	if not unit then -- check for unit
		return
	end

	-- get name
	name, realm = UnitName(unit, true)
	if not name then
		return
	end

	-- add "-" + realm
	if not realm then
		-- same realm
		return name .. "-" .. NS.PlayerRealm
	else
		-- different realm
		return name .. "-" .. realm
	end
end

--> UnitHealthCheck <------------------------------------------------
local function UnitHealthCheck(unit, PID)
	local GUID = UnitGUID(unit)
	NS.PlayerActiveCache[PID].Dead = UnitIsDeadOrGhost(unit)
	NS.PlayerActiveCache[PID].Health = UnitPercentHealthFromGUID(GUID)
	NS.RefreshBarByPID(PID)
end

--> ⚡ : UNIT_HEALTH ---------------------------------------
function NS.UnitHealthEvent(_, unit)
	if NS.IsUnitValidForTracking(unit) then
		local PID = NS.GetPlayerIDByUnit(unit)
		if NS.PlayersOnBars[PID] then
			UnitHealthCheck(unit, PID)
		end
	end
end
