-----------------------------------------------------------
--|> LUT: SPECS
-----------------------------------------------------------
local _, NS = ...

-- ⬆️ Upvalues
--------------------------------------------------------
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local issecretvalue = issecretvalue

-- : global variables
NS.TankSpecs = {}
NS.HealerSpecs = {}

--|> BUILD SPECIALIZATIONS
function NS.BuildSpecs()
	-- : use known specializations as base
	local specID, specName
	specID, specName = GetSpecializationInfoForClassID(1, 3) -- Warrior = Protection
	NS.TankSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(6, 1) -- Death Knight - Blood
	NS.TankSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(10, 1) --  Monk - Brewmaster
	NS.TankSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(11, 3) -- Druid - Guardian
	NS.TankSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(12, 2) -- Demon Hunter - Vengeance
	NS.TankSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(2, 1) -- Paladin - Holy
	NS.HealerSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(5, 1) -- Priest - Discipline
	NS.HealerSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(7, 3) -- Shaman - Restoration
	NS.HealerSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(10, 2) -- Monk - Mistweaver
	NS.HealerSpecs[specName] = true
	specID, specName = GetSpecializationInfoForClassID(13, 2) -- Evoker - Preservation
	NS.HealerSpecs[specName] = true
end

-- |> IS TANK
function NS.IsTank(specName)
	-- : tank specialization?
	if NS.TankSpecs[specName] then
		return true
	end
	return false
end

-- |> IS HEALER
function NS.IsHealer(specName)
	-- : healer specialization?
	if NS.HealerSpecs[specName] then
		return true
	end
	return false
end

-- |> GET ROLE FROM SPECIALIZATION
function NS.GetRoleFromSpecialization(specName)
	-- : sanity check
	if not specName or issecretvalue(specName) then
		-- : failed
		return nil
	end

	-- : tank?
	if NS.IsTank(specName) then
		return "TANK"
	-- : healer?
	elseif NS.IsHealer(specName) then
		return "HEALER"
	else
		return "DAMAGER"
	end

	-- : failed
	return nil
end
