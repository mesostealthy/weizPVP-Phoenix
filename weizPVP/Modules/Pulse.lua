---------------------------------------------------------------------------------------------------
--|> Pulse
-- 📌 PulseEvent occurs every 1 second
---------------------------------------------------------------------------------------------------
local _, NS = ...

--: 🆙 Upvalues :----------------------
local UnitExists = UnitExists

--> Pulse Timeouts <-------------------------------------------------
local pulseTimeoutCount = 1
local pulseTargetCount = 1
local function PulseTimeoutUpdate()
	if pulseTimeoutCount == 2 then
		pulseTimeoutCount = 1
		if NS.NearbyCount and NS.NearbyCount > 0 then
			NS.ManageListTimeouts()
			NS.RefreshAllNamePlates()
		end
	else
		pulseTimeoutCount = pulseTimeoutCount + 1
	end
	if pulseTargetCount == 5 then
		pulseTargetCount = 1
		NS.UpdateNamePlateUnit("target")
		NS.UpdateGroupRoles()
	else
		pulseTargetCount = pulseTargetCount + 1
	end
end

--> Update pulsed functions <----------------------------------------
function NS.PulseEvent()
	PulseTimeoutUpdate()
end
