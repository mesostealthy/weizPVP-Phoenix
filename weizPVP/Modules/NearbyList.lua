---------------------------------------------------------------------------------------------------
--|> NEARBY LISTS
-- 📌 Manages the lists of players nearby
---------------------------------------------------------------------------------------------------
local _, NS = ...

--: ⬆️ Upvalues :--
local CopyTable = CopyTable
local issecretvalue = issecretvalue
local tinsert, sort, wipe = tinsert, sort, wipe
local pairs = pairs
local GetTime = GetTime

--: NS Lists :-------------------------
NS.CurrentNameplates = {}
NS.CurrentNameplatesSize = {}

NS.Nearby = {}

NS.NearbyListSize = 0
NS.NearbyList = {}

NS.ActiveList = {}
NS.InactiveList = {}
NS.ActiveDeadList = {}
NS.InactiveDeadList = {}

NS.PlayersOnBars = {}
NS.PlayersOnBarsSize = {}

--> Manage List Timeouts <-------------------------------------------
function NS.ManageNearbyListTimeouts()
	local expired = false
	local removed = false
	local expiredCount = 0
	local count = 1
	local timestamp = GetTime()
	--: ACTIVE
	for PID in pairs(NS.ActiveList) do
		if (timestamp - NS.ActiveList[PID].TimeUpdated) > NS.Options.Sorting.NearbyActiveTimeout and
			NS.CurrentNameplates[PID] == nil then
			NS.InactiveList[PID] = NS.ActiveList[PID]
			NS.InactiveList[PID].TimeAdded = timestamp + (count * 0.001)
			NS.ActiveList[PID] = nil
			count = count + 1
			expired = true
		end
	end
	count = 0
	--: ACTIVE DEAD
	timestamp = GetTime()
	for PID in pairs(NS.ActiveDeadList) do
		if (timestamp - NS.ActiveDeadList[PID].TimeUpdated) > NS.Options.Sorting.NearbyActiveTimeout then
			NS.InactiveDeadList[PID] = NS.ActiveDeadList[PID]
			NS.InactiveDeadList[PID].TimeAdded = timestamp + (count * 0.001)
			NS.ActiveDeadList[PID] = nil
			expired = true
			count = count + 1
		end
	end
	--: INACTIVE
	timestamp = GetTime()
	for PID in pairs(NS.InactiveList) do
		if (timestamp - NS.InactiveList[PID].TimeUpdated) > NS.Options.Sorting.NearbyInactiveTimeout then
			NS.InactiveList[PID] = nil
			NS.NearbyList[PID] = nil
			NS.PlayerActiveCache[PID] = nil
			expiredCount = expiredCount + 1
			expired = true
			removed = true
		end
	end
	--: INACTIVE DEAD
	timestamp = GetTime()
	for PID in pairs(NS.InactiveDeadList) do
		if (timestamp - NS.InactiveDeadList[PID].TimeUpdated) > NS.Options.Sorting.NearbyInactiveTimeout then
			NS.InactiveDeadList[PID] = nil
			NS.NearbyList[PID] = nil
			NS.PlayerActiveCache[PID] = nil
			expiredCount = expiredCount + 1
			expired = true
			removed = true
		end
	end
	if expired or removed then
		NS.NearbyListSize = NS.NearbyListSize - expiredCount
		NS.SortNearbyList()
		NS.UpdateNearbyCount()
		NS.RefreshCurrentList()
		NS.CoreUI.ChangeTargetIcon()
	end
	if removed then
		NS.ManageBarsDisplayed()
	end
end

--> Sort Nearby List <-----------------------------------------------
local tempCurrentList = {}
local tempActiveList = {}
local tempActiveDeadList = {}
local tempInactiveList = {}
local tempInactiveDeadList = {}
function NS.SortNearbyList(newTargetPID)
	--: ActiveList
	for PID in pairs(NS.ActiveList) do
		if NS.NearbyList[PID] then
			if NS.NearbyList[PID].TimeAdded then
				tinsert(tempActiveList, { PID = PID, time = NS.NearbyList[PID].TimeAdded })
			end
		end
	end
	--: ActiveDeadList
	for PID in pairs(NS.ActiveDeadList) do
		if NS.NearbyList[PID] then
			if NS.NearbyList[PID].TimeAdded then
				tinsert(tempActiveDeadList, { PID = PID, time = NS.NearbyList[PID].TimeAdded })
			end
		end
	end
	--: InactiveDeadList
	for PID in pairs(NS.InactiveDeadList) do
		if NS.NearbyList[PID] then
			if NS.NearbyList[PID].TimeAdded then
				tinsert(tempInactiveDeadList, { PID = PID, time = NS.NearbyList[PID].TimeAdded })
			end
		end
	end
	--: InactiveList
	for PID in pairs(NS.InactiveList) do
		if NS.NearbyList[PID] then
			if NS.NearbyList[PID].TimeAdded then
				tinsert(tempInactiveList, { PID = PID, time = NS.NearbyList[PID].TimeAdded })
			end
		end
	end
	--: sorts
	sort(
	tempActiveList,
		function(a, b)
			return a.time < b.time
		end
	)
	sort(
	tempActiveDeadList,
		function(a, b)
			return a.time < b.time
		end
	)
	sort(
	tempInactiveList,
		function(a, b)
			return a.time < b.time
		end
	)
	sort(
	tempInactiveDeadList,
		function(a, b)
			return a.time < b.time
		end
	)
	-- : put target first?
	--[[if newTargetPID then
		for PID in pairs(tempActiveList) do
			if tempActiveList[PID].PID == newTargetPID then
				tinsert(tempCurrentList, tempActiveList[PID])
				tempActiveList[PID] = nil
				break
			end
		end
	end]]--
	--: create PID list
	for PID in pairs(tempActiveList) do
		if NS.PlayerActiveCache[tempActiveList[PID].PID] then
			if not issecretvalue(NS.PlayerActiveCache[tempActiveList[PID].PID].Name) then
				if NS.KosList[NS.PlayerActiveCache[tempActiveList[PID].PID].Name] then
					tinsert(tempCurrentList, tempActiveList[PID])
					tempActiveList[PID] = nil
				end
			end
		end
	end
	for PID in pairs(tempActiveList) do
		tinsert(tempCurrentList, tempActiveList[PID])
	end
	for PID in pairs(tempActiveDeadList) do
		tinsert(tempCurrentList, tempActiveDeadList[PID])
	end
	for PID in pairs(tempInactiveList) do
		tinsert(tempCurrentList, tempInactiveList[PID])
	end
	for PID in pairs(tempInactiveDeadList) do
		tinsert(tempCurrentList, tempInactiveDeadList[PID])
	end
	NS.CurrentList = CopyTable(tempCurrentList)
	wipe(tempCurrentList)
	wipe(tempActiveList)
	wipe(tempActiveDeadList)
	wipe(tempInactiveList)
	wipe(tempInactiveDeadList)
end

--> Clear List Data <------------------------------------------------
function NS.ClearNearbyListData()
	if NS.NearbyCount ~= 0 then
		wipe(NS.CurrentList)
		wipe(NS.CurrentNameplates)
		wipe(NS.NearbyList)
		wipe(NS.ActiveList)
		wipe(NS.InactiveList)
		wipe(NS.ActiveDeadList)
		wipe(NS.InactiveDeadList)
		wipe(NS.PlayersOnBars)
		wipe(NS.PlayerActiveCache)
		NS.NearbyListSize = 0
		NS.SortNearbyList()
		NS.ManageBarsDisplayed()
		NS.RefreshCurrentList()
		NS.UpdateNearbyCount()
		weizPVP_CoreFrame.ScrollFrame:SetVerticalScroll(0)
		NS:PlayerTargetEvent()
		NS.AutoResize()
		NS.CoreUI.ChangeTargetIcon()
	end
end
