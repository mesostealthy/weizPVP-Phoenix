-----------------------------------------------------------
--|> LUT: CLASSES
-----------------------------------------------------------
local _, NS = ...

-- ⬆️ Upvalues
--------------------------------------------------------
local GetNumClasses, GetClassInfo = GetNumClasses, GetClassInfo

-- : global variables
NS.Classes = {}

--|> BUILD CLASSES
function NS.BuildClasses()
	-- : process all
	for i = 1, GetNumClasses() do
		-- : get class info
		local _, className, classID = GetClassInfo(i)
		NS.Classes[className] = classID
	end
end

--|> GET CLASS ID FROM NAME
function NS.GetClassIDFromName(className)
	-- : found?
	if NS.Classes[className] then
		-- : return ID
		return NS.Classes[className]
	end
	return nil
end
