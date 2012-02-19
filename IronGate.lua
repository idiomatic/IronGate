
-- World of Warcraft Ironman Challenge

-- TODO detect and notify:
-- TODO detect assistance (damage dealt < mob's total HP)
-- TODO detect refer-a-friend effects
-- TODO detect leveing addons (?)

-- TODO take preventitive actions:
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
-- TODO prevent suicidal quests
-- TODO prevent dungeons, raids, battlegrounds, arenas

-- TODO user interface:
-- TODO display status HUD
-- TODO option to disable prevention
-- TODO option to try to remedy (cancel aura, equip a lesser item)
-- TODO stop flashing talent button
-- TODO block guild invites?
-- TODO addon broadcast transgressions (collaborative debugging)
-- TODO announce on "iron" channel death (level, generation) cause
-- TODO reset recent_warnings occasionally

IronGateDB = { }

IronGate = {
    Locales = { },
    max_warnings = 5,
    recent_warnings = { },
}

local DB = IronGateDB

local preferred_locale = GetLocale()
local fallback_locale = 'enUS'

local L = setmetatable({ }, {
    __index = function (self, key)
		  local pl = IronGate.Locales[preferred_locale]
		  local fl = IronGate.Locales[fallback_locale]
		  local value = (pl and pl[key]) or (fl and fl[key]) or key
		  if value == true then
		      value = key
		  end
		  rawset(self, key, value)
		  return value
	      end,
})

function IronGate.ChatMessage(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffc0c0c0IronGate:|r %s",
						string.format(fmt, ...)))
end

function IronGate.DebugMessage(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff7f7f7fIronGate:|r %s",
						string.format(fmt, ...)))
end

function IronGate.ResetRecentWarnings()
    IronGate.recent_warnings = { }
end

function IronGate.Warning(reason, ...)
    IronGate.ChatMessage(string.format("|cffffc000%s:|r %s", L["Warning"],
				       string.format(reason, ...)))
end

function IronGate.Disqualify(reason, ...)
    if not IronGateDB.disqualified then
	IronGateDB.disqualified = true
	IronGateDB.disqualification_reason = string.format(reason, ...)
    end
    if not IronGate.disqualified then
	IronGate.disqualified = true
	IronGate.ChatMessage("|cffff0000%s: %s|r", L["Disqualified"],
			     string.format(reason, ...))
	-- bug the player no longer with warnings
	IronGate.max_warnings = 0
    end
end

function IronGate.DisqualifyOnFirstTransgression(...)
    for _, audit in ipairs({...}) do
	local co = coroutine.create(audit)
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
	local co = coroutine.create(audit)
	repeat
	    local ok, message = coroutine.resume(co)
	    if ok and message and IronGate.recent_warnings[message] == nil then
		warnings = warnings + 1
		if warnings <= IronGate.max_warnings then
		    IronGate.Warning(message)
		    IronGate.recent_warnings[message] = true
		end
	    end
	until not ok
    end
    if warnings > IronGate.max_warnings and IronGate.max_warnings > 0 then
	IronGate.Warning(L["(and %d more)"], warnings - IronGate.max_warnings)
    end
end

local stats_that_should_be_zero = {
    60, -- Deaths
    1501, -- Player vs. Player: Total deaths from other players
    796, -- Resurrection: Resurrected by priests
    798, -- Resurrection: Rebirthed by druids
    1229, -- Resurrection: Revived by druids
    799, -- Resurrection: Spirit returned to body by shamans
    800, -- Resurrection: Redeemed by paladins
    801, -- Resurrection: Resurrected by soulstones
    1253, -- Resurrection: Raised as a ghoul
    1149, -- Character: Talent tree respecs
    1524, -- Secondary Skills: Cooking skill
    1519, -- Secondary Skills: Fishing skill
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
    839, -- Battlegrounds: Battlegrounds played
    838, -- Rated Arenas: Arenas played
    345, -- Consumables: Health potions consumed
    922, -- Consumables: Mana potions consumed
    923, -- Consumables: Elixirs consumed
    811, -- Consumables: Flasks consumed
    927, -- Gear: Equipped epic items in item slots
    2277, -- Travel: Summons accepted
}

function IronGate.StatisticsAudit()
    for _, stat_id in ipairs(stats_that_should_be_zero) do
	local value = GetStatistic(stat_id)
	if value ~= 0 and value ~= '--' then
	    local id, name, points, completed, month, day, year, description, flags, image, reward = GetAchievementInfo(stat_id)
	    coroutine.yield(string.format(L["%s statistic should be 0 but is %s."],
					  name, value))
	end
    end
end

local monitored_slot_names = {
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

function IronGate.EquippedAudit()
    for _, slot_name in ipairs(monitored_slot_names) do
	local slot_id = GetInventorySlotInfo(slot_name)
	local quality = GetInventoryItemQuality("player", slot_id)
	if quality and quality >= ITEM_QUALITY_UNCOMMON and quality <= 7 then
	    coroutine.yield(string.format(L["%s equipment should be |cff9d9d9dpoor|r or |cffffffffcommon|r."], _G[string.upper(slot_name)]))
	end
    end
end

function IronGate.PartyAudit()
    if GetNumPartyMembers() > 0 then
	coroutine.yield(L["Player is in a party."])
    end
    if GetNumRaidMembers() > 0 then
	coroutine.yield(L["Player is in a raid."])
    end
end

local acceptable_aura_sources = {
    ["player"] = true,
    ["pet"] = true,
    ["vehicle"] = true,
}

local acceptable_aura_spell_ids = {
    [69867] = true, -- Barrens Bloom
    -- human starter zone
}

function IronGate.AuraAudit()
    for i = 1, MAX_TARGET_BUFFS do
	local name, _, _, _, _, _, _, source, _, _, spell_id = UnitBuff("player", i)
	if name == nil then
	    break
	end
	if not acceptable_aura_sources[source] and not acceptable_aura_spell_ids[spell_id] then
	    coroutine.yield(string.format(L["%s buff."], name))
	end
    end
end

function IronGate.GuildAudit()
    if IsInGuild() then
	local guild_name = GetGuildInfo("player")
	local guild_level = GetGuildLevel()
	if guild_level > 1 then
	    coroutine.yield(string.format(L["Guild %s is level %d."], guild_name, guild_level))
	end
    end
end

function IronGate.TalentAudit()
    function talent_audit(pet)
	for tab_index = 1, GetNumTalentTabs(false, pet) do
	    for talent_index = 1, GetNumTalents(tab_index, false, pet) do
		local name, _, _, _, rank = GetTalentInfo(tab_index, talent_index)
		if rank > 0 then
		    coroutine.yield(string.format(L["%d points in %s talent."]))
		end
	    end
	end
    end
    talent_audit(false)
    talent_audit(true)
end

local deadly_quests = {
    [27377] = true, -- Twilight Highlands: Devoured
    -- Howling Fjord: (from Valgarde)
}

function IronGate.QuestAudit()
    local quest_entries, _ = GetNumQuestLogEntries()
    for i = 1, quest_entries do
	local title, _, _, _, header, _, _, _, quest_id = GetQuestLogTitle(i)
	if not header then
	    if deadly_quests[quest_id] then
		coroutine.yield(string.format(L["Quest \"%s\" may kill you."], title))
	    end
	end
    end
end

function IronGate.TrainerProfessionsAudit()
    if IsTradeskillTrainer() then
	for i = 1, GetNumTrainerServices() do
	    local skill = GetTrainerServiceSkillLine(i)
	    if skill ~= PROFESSIONS_FIRST_AID then
		coroutine.yield(string.format(L["%s trainer."], skill))
		break
	    end
	end
    end
end

function IronGate.PLAYER_DEAD()
    IronGate.Disqualify(L["Player died."])
end

function IronGate.PLAYER_LOGIN()
    local generation = IronGateDB.generation or 1
    if UnitLevel("player") == 1 and UnitXP("player") == 0 then
	-- character is rerolled
	generation = generation + (IronGateDB.experienced and 1 or 0)
	wipe(IronGateDB)
    end
    IronGateDB.generation = generation
    IronGate.ChatMessage(L["Welcome to the Ironman Challenge. Watch your step."])
    IronGate.DisqualifyOnFirstTransgression(IronGate.StatisticsAudit)
    IronGate.WarnTransgressions(
	IronGate.EquippedAudit,
	IronGate.PartyAudit,
	IronGate.AuraAudit,
	IronGate.GuildAudit,
	IronGate.TalentAudit
    )
end

function IronGate.PLAYER_XP_UPDATE()
    IronGate.DisqualifyOnFirstTransgression(
	IronGate.EquippedAudit,
	IronGate.PartyAudit,
	IronGate.AuraAudit,
	IronGate.GuildAudit,
	IronGate.TalentAudit
    )
    IronGateDB.experienced = true
    -- ill placed
    IronGate.ResetRecentWarnings()
end

function IronGate.PLAYER_EQUIPMENT_CHANGED()
    IronGate.WarnTransgressions(IronGate.EquippedAudit)
end

function IronGate.PARTY_MEMBERS_CHANGED()
    IronGate.WarnTransgressions(IronGate.PartyAudit)
end

function IronGate.UNIT_AURA()
    IronGate.WarnTransgressions(IronGate.AuraAudit)
end

function IronGate.PLAYER_GUILD_UPDATE()
    IronGate.WarnTransgressions(IronGate.GuildAudit)
end

function IronGate.QUEST_ACCEPTED()
    IronGate.WarnTransgressions(IronGate.QuestAudit)
end

function IronGate.ToggleTalentFrame()
    if PlayerTalentFrameTalents and PlayerTalentFrameTalents:IsVisible() then
	IronGate.Warning(L["Talents."])
    end
end

function IronGate.PLAYER_TALENT_UPDATE()
    IronGate.DisqualifyOnFirstTransgression(IronGate.TalentAudit)
end

function IronGate.TRADE_SHOW()
    IronGate.Warning(L["Trading."])
end

function IronGate.TRADE_ACCEPT_UPDATE(player_agreed, target_agreed)
    if player_agreed == 1 and target_agreed == 1 then
	-- XXX Should check on whether anything was traded
	IronGate.Disqualify(L["Trading."])
    end
end

function IronGate.TRAINER_SHOW()
    IronGate.WarnTransgressions(IronGate.TrainerProfessionsAudit)
end

local frame = CreateFrame("Frame", "IronGate")
function frame:OnEvent(event, ...)
    local fn = IronGate[event]
    if fn then
	fn(...)
    else
	IronGate.DebugMessage(event, ...)
    end
end

frame:SetScript("OnEvent", frame.OnEvent)
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("QUEST_ACCEPTED")
hooksecurefunc("ToggleTalentFrame", IronGate.ToggleTalentFrame)
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
frame:RegisterEvent("TRAINER_SHOW")
