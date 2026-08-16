-----------------------------------------------------------
--|> LUT: RACES
-----------------------------------------------------------
local _, NS = ...

-- ⬆️ Upvalues
--------------------------------------------------------
local GetFactionInfo = C_CreatureInfo.GetFactionInfo
local GetRaceInfo = C_CreatureInfo.GetRaceInfo

-- : global variables
NS.Races = {}

--|> BUILD RACES
function NS.BuildRaces()
	-- : process 100 (increase if more later)
	for i = 1, 100 do
		-- : get race info
		local raceInfo  = GetRaceInfo(i)
		if raceInfo  then
			NS.Races[raceInfo.raceID] = { raceID = raceInfo.raceID, raceName = raceInfo.raceName, clientFileString = raceInfo.clientFileString }
			local factionInfo = GetFactionInfo(raceInfo.raceID)
			if factionInfo then
				-- : horde?
				if factionInfo.name == FACTION_HORDE then
					NS.Races[raceInfo.raceID].factionID = 0
				-- : alliance?
				elseif factionInfo.name == FACTION_ALLIANCE then
					NS.Races[raceInfo.raceID].factionID = 1
				end
			end
		end
	end
end

--|> GET RACE INFO FROM NAME
function NS.GetRaceInfoFromName(raceName, factionID)
	-- : special cases?
	if raceName == "Pandaren" then
		-- : horde?
		if factionID == 0 then
			-- : horde
			return 26, 0
		-- : alliance?
		elseif factionID == 1 then
			-- : alliance
			return 25, 1
		else
			-- : neutral
			return 24, nil
		end
	elseif raceName == "Dracthyr" then
		-- : horde?
		if factionID == 0 then
			-- : horde
			return 70, 0
		-- : alliance?
		elseif factionID == 1 then
			-- : alliance
			return 52, 1
		else
			-- : unknown
			return nil, nil
		end
	elseif (raceName == "Earthen") or (raceName == "EarthenDwarf") then
		-- : horde?
		if factionID == 0 then
			-- : horde
			return 84, 0
		-- : alliance?
		elseif factionID == 1 then
			-- : alliance
			return 85, 1
		else
			-- : unknown
			return nil, nil
		end
	elseif raceName == "Haranir" then
		-- : horde?
		if factionID == 0 then
			-- : horde
			return 91, 0
		-- : alliance?
		elseif factionID == 1 then
			-- : alliance
			return 86, 1
		else
			-- : unknown
			return nil, nil
		end
	end

	-- : search races
	for i, info in pairs(NS.Races) do
		-- : matches?
		if info.clientFileString == raceName then
			-- : return ID
			return info.raceID, info.factionID
		elseif info.raceName == raceName then
			-- : return ID
			return info.raceID, info.factionID
		end
	end

	-- : unknown
	return nil, nil
end
