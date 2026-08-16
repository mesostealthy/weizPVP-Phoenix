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

NS.Nearby = {}

NS.NearbyListSize = 0
NS.NearbyList = {}

NS.ActiveList = {}
NS.InactiveList = {}
NS.ActiveDeadList = {}
NS.InactiveDeadList = {}

NS.PlayersOnBars = {}
NS.PlayersOnBarsSize = {}

--> Sort Nearby List <-----------------------------------------------
local tempCurrentList = {}
local tempActiveList = {}
local tempActiveDeadList = {}
local tempInactiveList = {}
local tempInactiveDeadList = {}
function NS.SortNearbyList()
	--: ActiveList
	for playerToken in pairs(NS.ActiveList) do
		if NS.NearbyList[playerToken] then
			if NS.NearbyList[playerToken].TimeAdded then
				tinsert(tempActiveList, { playerToken = playerToken, time = NS.NearbyList[playerToken].TimeAdded })
			end
		end
	end
	--: ActiveDeadList
	for playerToken in pairs(NS.ActiveDeadList) do
		if NS.NearbyList[playerToken] then
			if NS.NearbyList[playerToken].TimeAdded then
				tinsert(tempActiveDeadList, { playerToken = playerToken, time = NS.NearbyList[playerToken].TimeAdded })
			end
		end
	end
	--: InactiveDeadList
	for playerToken in pairs(NS.InactiveDeadList) do
		if NS.NearbyList[playerToken] then
			if NS.NearbyList[playerToken].TimeAdded then
				tinsert(tempInactiveDeadList, { playerToken = playerToken, time = NS.NearbyList[playerToken].TimeAdded })
			end
		end
	end
	--: InactiveList
	for playerToken in pairs(NS.InactiveList) do
		if NS.NearbyList[playerToken] then
			if NS.NearbyList[playerToken].TimeAdded then
				tinsert(tempInactiveList, { playerToken = playerToken, time = NS.NearbyList[playerToken].TimeAdded })
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
	--: create playerToken list
	for playerToken,info in pairs(tempActiveList) do
		if NS.PlayerActiveCache[info.playerToken] then
			if not issecretvalue(NS.PlayerActiveCache[info.playerToken].fullName) then
				if NS.KosList[NS.PlayerActiveCache[info.playerToken].fullName] then
					tinsert(tempCurrentList, info)
					tempActiveList[playerToken] = nil
				end
			end
		end
	end
	for playerToken in pairs(tempActiveList) do
		tinsert(tempCurrentList, tempActiveList[playerToken])
	end
	for playerToken in pairs(tempActiveDeadList) do
		tinsert(tempCurrentList, tempActiveDeadList[playerToken])
	end
	for playerToken in pairs(tempInactiveList) do
		tinsert(tempCurrentList, tempInactiveList[playerToken])
	end
	for playerToken in pairs(tempInactiveDeadList) do
		tinsert(tempCurrentList, tempInactiveDeadList[playerToken])
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
