
-- World of Warcraft Ironman Challenge

-- TODO prevent equpping green (or better) items (hard because protected API)
-- TODO prevent partying
-- TODO prevent trades
-- TODO prevent enchanting (except rogue poisons)
-- TODO prevent gemming
-- TODO prevent reforging
-- TODO prevent specialization
-- TODO prevent talent points
-- TODO prevent pet talent points
-- TODO prevent glyphs
-- TODO prevent professions (except First Aid)
-- TODO prevent using potions, flasks, elixirs (except Quest items)
-- TODO prevent using buff foods
-- TODO prevent suicidal quests (27377)
-- TODO prevent dungeons, raids, battlegrounds, arenas
-- TODO detect assistance (damage dealt < mob's total HP)
-- TODO detect level 2 or higher guild
-- TODO detect refer-a-friend effects
-- TODO detect leveing addons (?)
-- TODO detect buffs (from other players) and cancel aura


IronGate_DB = { }

IronGate = {
    DB = IronGate_DB,
}

local max_warnings = 5

function IronGate.ChatMessage(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffc0c0c0IronGate:|r %s",
						string.format(fmt, ...)))
end

function IronGate.DebugMessage(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff7f7f7fIronGate:|r %s",
						string.format(fmt, ...)))
end

function IronGate.Warning(reason, ...)
    IronGate.ChatMessage(string.format("|cffffc000%s:|r %s", "Warning",
				       string.format(reason, ...)))
end

function IronGate.Disqualify(reason, ...)
    if not IronGate.DB.disqualified then
	IronGate.DB.disqualified = true
	IronGate.DB.disqualification_reason = reason
    end
    IronGate.ChatMessage("|cffff0000%s: %s|r", "Disqualified",
			 string.format(reason, ...))
    max_warnings = 0
end

function IronGate.DisqualifyOnFirstTransgression(...)
    for _, audit in ipairs({...}) do
	co = coroutine.create(audit)
	local ok, message = coroutine.resume(co)
	if ok and message then
	    IronGate.Disqualify(message)
	    break
	end
    end
end

function IronGate.WarnTransgressions(...)
    local warnings = 0
    for _, audit in ipairs({...}) do
	co = coroutine.create(audit)
	local ok, message = true
	repeat
	    ok, message = coroutine.resume(co)
	    if ok and message then
		warnings = warnings + 1
		if warnings <= max_warnings then
		    IronGate.Warning(message)
		end
	    end
	until not ok
    end
    if warnings > max_warnings and max_warnings > 0 then
	IronGate.Warning("(and %d more)", warnings - max_warnings)
    end
end

local stats_that_should_be_zero = {
    1149, -- Character: Talent tree respecs
    838, -- Rated Arenas: Arenas played
    1524, -- Secondary Skills: Cooking skill
    1519, -- Secondary Skills: Fishing skill
    345, -- Consumables: Health potions consumed
    922, -- Consumables: Mana potions consumed
    923, -- Consumables: Elixirs consumed
    811, -- Consumables: Flasks consumed
    839, -- Battlegrounds: Battlegrounds played
    1527, -- Professions: Highest Alchemy skill
    1532, -- Professions: Highest Blacksmithing skill
    1535, -- Professions: Highest Enchanting skill
    1544, -- Professions: Highest Engineering skill
    1538, -- Professions: Highest Herbalism skill
    1539, -- Professions: Highest Inscription skill
    1540, -- Professions: Highest Jewelcrafting skill
    1536, -- Professions: Highest Leatherworking skill
    1537, -- Professions: Highest Mining skill
    1541, -- Professions: Highest Skinning skill
    1542, -- Professions: Highest Tailoring skill
    60, -- Deaths
    927, -- Gear: Equipped epic items in item slots
    796, -- Resurrection: Resurrected by priests
    798, -- Resurrection: Rebirthed by druids
    1229, -- Resurrection: Revived by druids
    799, -- Resurrection: Spirit returned to body by shamans
    800, -- Resurrection: Redeemed by paladins
    801, -- Resurrection: Resurrected by soulstones
    1253, -- Resurrection: Raised as a ghoul
    2277, -- Travel: Summons accepted
    1501, -- Player vs. Player: Total deaths from other players
}

function IronGate.CheckStatisticsAudit()
    for _, stat_id in ipairs(stats_that_should_be_zero) do
	local value = GetStatistic(stat_id)
	if value ~= 0 and value ~= '--' then
	    local id, name, points, completed, month, day, year, description, flags, image, reward = GetAchievementInfo(stat_id)
	    coroutine.yield(string.format("%s should be 0 but is %s",
					  name, value))
	end
    end
end

local slot_names = {
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "ShirtSlot",
    "TabardSlot",
    "WristSlot",
    "HandsSlot",
    "WaistSlot",
    "LegsSLot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot",
    "MainHandSlot",
    "SecondaryHandSlot",
    "RangedSlot",
    "AmmoSlot",
}

function IronGate.CheckEquippedAudit()
    for _, slot_name in ipairs(slot_names) do
	local slot_id = GetInventorySlotInfo(slot_name)
	local quality = GetInventoryItemQuality("player", slot_id)
	if quality and quality >= ITEM_QUALITY_UNCOMMON and quality <= 7 then
	    coroutine.yield(string.format("%s equipment should be |cff9d9d9dpoor|r or |cffffffffcommon|r", _G[string.upper(slot_name)]))
	end
    end
end

function IronGate.CheckPartyAudit()
    if GetNumPartyMembers() > 0 then
	coroutine.yield("player is in a party")
    end
    if GetNumRaidMembers() > 0 then
	coroutine.yield("player is in a raid")
    end
end

function IronGate.PLAYER_DEAD()
    IronGate.Disqualify("Player died")
end

function IronGate.PLAYER_LOGIN()
    IronGate.DisqualifyOnFirstTransgression(IronGate.CheckStatisticsAudit)
end

function IronGate.PLAYER_XP_UPDATE()
    IronGate.DisqualifyOnFirstTransgression(
	IronGate.CheckEquippedAudit,
	IronGate.CheckPartyAudit
    )
end

function IronGate.PLAYER_EQUIPMENT_CHANGED()
    IronGate.WarnTransgressions(IronGate.CheckEquippedAudit)
end

function IronGate.PARTY_MEMBERS_CHANGED()
    IronGate.WarnTransgressions(IronGate.CheckPartyAudit)
end

local frame = CreateFrame("Frame", "IronGate")
function frame:OnEvent(event, arg1, arg2, arg3)
    local fn = IronGate[event]
    if fn then
	fn()
    end
end

frame:SetScript("OnEvent", frame.OnEvent)
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
--frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
--frame:RegisterEvent("WEAR_EQUIPMENT_SET")
--frame:RegisterEvent("EQUIPMENT_SWAP_PENDING")
--frame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
