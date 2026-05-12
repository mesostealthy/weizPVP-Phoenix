---------------------------------------------------------------------------------------------------
--|> EVENTS
---------------------------------------------------------------------------------------------------
local _, NS = ...

--: 🆙 Upvalues :----------------------
local wipe = wipe
local UnitLevel = UnitLevel
local C_Timer_After = C_Timer.After

NS.PlayerActiveCache = NS.PlayerActiveCache or {}

--> ENABLE EVENTS ---------------------------------------------------
function NS.EnableEvents()
	-- ADDON
	weizPVP:RegisterEvent("ADDON_LOADED", NS.AddonLoadedEvent)
	-- DATA COLLECTION
	NS.weizPVP_Events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	NS.weizPVP_Events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	NS.weizPVP_Events:RegisterEvent("PLAYER_TARGET_CHANGED")
	NS.weizPVP_Events:RegisterEvent("PLAYER_TARGET_DIED")
	NS.weizPVP_Events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	NS.weizPVP_Events:RegisterEvent("UNIT_FLAGS")
	NS.weizPVP_Events:RegisterEvent("UNIT_HEALTH")
	NS.weizPVP_Events:RegisterEvent("UNIT_TARGET")
	-- ZONE CHANGED
	weizPVP:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND", NS.PlayerEnteringBattlegroundEvent)
	weizPVP:RegisterEvent("PLAYER_ENTERING_WORLD", NS.PlayerEnteringWorldEvent)
	weizPVP:RegisterEvent("ZONE_CHANGED_NEW_AREA", NS.ZoneChangedNewAreaEvent)
	weizPVP:RegisterEvent("AREA_POIS_UPDATED", NS.AreaPositionUpdated)
	weizPVP:RegisterEvent("LOADING_SCREEN_ENABLED", NS.LoadingScreenEnabled)
	weizPVP:RegisterEvent("LOADING_SCREEN_DISABLED", NS.LoadingScreenDisabled)
	-- COMBAT/PVP
	-- weizPVP:RegisterEvent("WAR_MODE_STATUS_UPDATE", NS.WarModeChanged) --no longer working, thanks blizz -_-
	weizPVP:RegisterEvent("PLAYER_REGEN_DISABLED", NS.EnteringCombat)
	weizPVP:RegisterEvent("PLAYER_REGEN_ENABLED", NS.LeavingCombat)
	weizPVP:RegisterEvent("PVP_MATCH_STATE_CHANGED", NS.PvPMatchStateChangedEvent)
	-- PLAYER UPDATES
	weizPVP:RegisterEvent("UI_INFO_MESSAGE", NS.UiInfoMessage)
	weizPVP:RegisterEvent("PLAYER_LEVEL_UP", NS.PlayerLevelUp)
	-- DISPLAY CHANGES
	weizPVP:RegisterEvent("DISPLAY_SIZE_CHANGED", NS.UpdateDisplayData)
	-- Crosshair
	NS.Crosshair.Enable()
end

--> DISABLE EVENTS <-------------------------------------------------
function NS.DisableEvents()
	-- ADDON
	weizPVP:UnregisterEvent("ADDON_LOADED")
	-- DATA COLLECTION
	NS.weizPVP_Events:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
	NS.weizPVP_Events:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
	NS.weizPVP_Events:UnregisterEvent("PLAYER_TARGET_CHANGED")
	NS.weizPVP_Events:UnregisterEvent("PLAYER_TARGET_DIED")
	NS.weizPVP_Events:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
	NS.weizPVP_Events:UnregisterEvent("UNIT_FLAGS")
	NS.weizPVP_Events:UnregisterEvent("UNIT_HEALTH")
	NS.weizPVP_Events:UnregisterEvent("UNIT_TARGET")
	-- COMBAT/PVP
	weizPVP:UnregisterEvent("PLAYER_REGEN_DISABLED")
	weizPVP:UnregisterEvent("PLAYER_REGEN_ENABLED")
	-- PLAYER UPDATES
	weizPVP:UnregisterEvent("PLAYER_LEVEL_UP")
	-- DISPLAY CHANGES
	weizPVP:UnregisterEvent("DISPLAY_SIZE_CHANGED")
end

---------------------------------------------------------------------------------------------------
--|> ⚡ EVENTS ⚡ <|-------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

--|> PLAYER
-------------------------------------------------------------------------------

--> ⚡ PLAYER LEVELED UP -----------------------------------
function NS.PlayerLevelUp()
	NS.Player.Level = UnitLevel("player")
end

--> ⚡ DISPLAY_SIZE_CHANGED --------------------------------
function NS.UpdateDisplayData()
	NS.CoreUI.Initialize()
end

--> ⚡ UI_INFO_MESSAGE -------------------------------------
function NS.UiInfoMessage(_, errType, message)
	if message == ERR_PVP_WARMODE_TOGGLE_ON then
		NS.WarModeChanged(true)
	elseif message == ERR_PVP_WARMODE_TOGGLE_OFF then
		NS.WarModeChanged(false)
	end
end

--> ⚡ WAR_MODE_STATUS_UPDATE ------------------------------
function NS.WarModeChanged(input)
	NS.Player.WarMode = input or C_PvP.IsWarModeDesired()
	NS.GetPVPZone()
	C_Timer_After(
		0.5,
		function()
			NS.GetPVPZone()
		end
	)
end

--|> ADDON
-------------------------------------------------------------------------------

--> ⚡ ADDON_LOADED ----------------------------------------
function NS.AddonLoadedEvent()
	NS.Crosshair.OnLoad()
	weizPVP:UnregisterEvent("ADDON_LOADED")
end

--|> COMBAT
-------------------------------------------------------------------------------

--> ⚡ ENTERING COMBAT -------------------------------------
function NS.EnteringCombat()
	NS.CoreUI.CombatStart()
end

--> ⚡ LEAVING COMBAT --------------------------------------
function NS.LeavingCombat()
	NS.ManageListTimeouts()
	NS.CoreUI.CombatEnd()
end
