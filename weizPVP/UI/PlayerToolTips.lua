---------------------------------------------------------------------------------------------------
--|> Player ToolTip
-- 📌 Detailed tooltips for player bars
---------------------------------------------------------------------------------------------------
local _, NS = ...

--: 🆙 Upvalues :----------------------
local WrapTextInColorCode = C_ColorUtil.WrapTextInColorCode
local GetClassColor = GetClassColor
local issecretvalue = issecretvalue
local select = select
local strsplit = strsplit
local gsub = gsub

local roleIcons = {
	["TANK"] = "|TInterface/Addons/weizPVP/Media/Roles/tank.tga:0|t",
	["DAMAGER"] = "|TInterface/Addons/weizPVP/Media/Roles/damager.tga:0|t",
	["HEALER"] = "|TInterface/Addons/weizPVP/Media/Roles/healer.tga:0|t",
	["UNKNOWN"] = "|TInterface/Addons/weizPVP/Media/Roles/unknown.tga:0|t"
}

--> Show Player Tooltip <--------------------------------------------
function NS.ShowPlayerTooltip(playerToken)
	if not NS.Options.Frames.PlayerTooltips then
		NS.HidePlayerTooltip()
		return
	end
	if playerToken and NS.PlayerActiveCache[playerToken] then
		-- Has Real Name?
		local formattedName, NAME, realm
		if NS.PlayerActiveCache[playerToken].NAME then
			-- Get player info
			NAME = NS.PlayerActiveCache[playerToken].name
			local name, realmName = strsplit("-", NAME)
			formattedName = gsub(NAME, "-(.*)", "")
			NS.PlayerActiveCache[playerToken].displayName = formattedName
			realmName = NS.PlayerActiveCache[playerToken].realm

			-- Realm
			if not realmName then
				realm = "|cff75e6ff" .. NS.Player.FromSubRealm .. "|r" -- blue for same realm
			else
				realm = "|cFFFF00CC" .. realmName .. "|r" -- bright purple for other realms
			end
		else
			-- Get player info
			NS.PlayerActiveCache[playerToken].displayName = NS.PlayerActiveCache[playerToken].name
			formattedName = NS.PlayerActiveCache[playerToken].name
			realm = NS.PlayerActiveCache[playerToken].realm
		end

		local class = NS.PlayerActiveCache[playerToken].C
		local estimated = NS.PlayerActiveCache[playerToken].E
		local race = NS.PlayerActiveCache[playerToken].RC or nil
		local level = NS.FormatLevelString(estimated, NS.PlayerActiveCache[playerToken].L)

		-- Guild
		local guild = NS.PlayerActiveCache[playerToken].displayGuild or NS.PlayerActiveCache[playerToken].G or nil
		if (not guild) and (not estimated) or (guild == "") then
			guild = "|c44999999[no guild]|r "
		elseif not guild then
			guild = nil
		elseif guild then
			guild = " |cffe3fff3" .. guild .. "|r"
		end

		-- Role
		local role = NS.PlayerActiveCache[playerToken].RL or nil
		local roleIcon
		if role then
			roleIcon = roleIcons[role]
		else
			roleIcon = nil
		end

		-- Set Tooltip
		weizPVP_CoreTooltip:SetOwner(weizPVP_CoreBar)
		weizPVP_CoreTooltip:ClearAllPoints()
		weizPVP_CoreTooltip:SetAnchorType("ANCHOR_TOPRIGHT")

		-- : Build Title Left (Name, Level, Role)
		local titleLeft = ""

		-- * Add Role Icon, if we have one
		if roleIcon then
			titleLeft = titleLeft .. roleIcon .. " "
		end

		-- * KOS check
		if not issecretvalue(NAME) and NS.KosList[NAME] then
			titleLeft = titleLeft ..
				"|TInterface/Addons/weizPVP/Media/Icons/kos.tga:0|t |cFFFF0040>|r" ..
				WrapTextInColorCode(formattedName .. "|cFFFF0040<|r", select(4, GetClassColor(class)))
		else
			titleLeft = titleLeft .. WrapTextInColorCode(formattedName .. " ", select(4, GetClassColor(class)))
		end

		-- * Level Format
		titleLeft = titleLeft .. " |cffffffff" .. level .. "|r "

		-- : Build top line
		weizPVP_CoreTooltip:AddLine(titleLeft)
		if guild then
			weizPVP_CoreTooltip:AddLine(guild)
		end

		-- : Realm Text
		local realmText = ""
		if realm then
			-- : set realm text
			realmText = "      " .. realm .. " "
		end

		-- : Race
		if race then
			weizPVP_CoreTooltip:AddLine(" |cfff8ffa6" .. race .. "|r" .. realmText)
		else
			weizPVP_CoreTooltip:AddLine("|cffdfe1d0 [race unknown]|r" .. realmText)
		end

		if estimated then
			weizPVP_CoreTooltip:AddLine(" |cFFff59f8(Estimated Values)|r")
		end

		weizPVP_CoreTooltip:Show()
	end
end

--> Hide Player Tooltip <--------------------------------------------
function NS.HidePlayerTooltip()
	weizPVP_CoreTooltip:Hide()
end
