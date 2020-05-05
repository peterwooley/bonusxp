local _G = _G
local _, BonusXP = ...
_G.BonusXPCounter = BonusXP
local playerFaction, _ = UnitFactionGroup("player");
BonusXPConfig = {};


local playerLevel = UnitLevel("player");
local playerLanguage = "en";
 
local xpBonusQuest = 0;
local xpBonusKill = 0;

local equipXpBonus = {kill=0, quest=0}; 
local auraXpBonus = {kill=0, quest=0};
local auras = {};
local heirloomXpBonus = {kill=0, quest=0};

local xpBonus5, xpBonus10, rafBonus = { quest = 5, kill = 5 }, { quest = 10, kill = 10 }, { kill=50, quest=50 };
local Heirloom5, Heirloom10, Rubellite5, Heirloom50PvPInstance = 71354, 57353, 258645, 186334; 

local isPlayerReadyFired = false;
local isEquipmentChanged = false;
local awaitingData = {};
local awaitingHeirloomData = {};

local xpProgress, xpLeft, xpDisabled = 0,0, false;

local xpExhaustion = 0;
local isCurrentRAFBonusActive;
local lineHeight = 15;
local gapLineHeight = 5;

local button = BonusXP_InventoryButton;
local tooltip = BonusXP_Tooltip;
local fontFRIZQT;
local valColor = "ffffffff";
local forceCalculateEquipment = false;
local forceUpdateGearInfo = false;
local bfaMapBonusIds = {
-- Kul Tiras
	[876] = true, -- Continent	Azeroth
	[992] = true, -- Continent	nil
	[1014] = true, -- Continent	nil
-- Zandalar
	[875] = true, -- Continent	Azeroth
	[991] = true, -- Continent	nil
	[1011] = true, -- Continent	nil
};
local CosmosId = 946;
local AzerothId = 947;
local currentPlayerZoneId = -1;
local currentPlayerContinent = -1;
local isInPvPInstance = nil;
local currentUiMapID = nil;
local linePositions = nil;
local equipItemData = { 
};

BonusXP.equipAllSlots = {
	INVSLOT_AMMO,
	INVSLOT_HEAD,
	INVSLOT_NECK,
	INVSLOT_SHOULDER,
	INVSLOT_BODY, -- (shirt)
	INVSLOT_CHEST,
	INVSLOT_WAIST,
	INVSLOT_LEGS,
	INVSLOT_FEET,
	INVSLOT_WRIST,
	INVSLOT_HAND,
	INVSLOT_FINGER1,
	INVSLOT_FINGER2,
	INVSLOT_TRINKET1,
	INVSLOT_TRINKET2,
	INVSLOT_BACK,
	INVSLOT_MAINHAND,
	INVSLOT_OFFHAND,
	INVSLOT_RANGED,
	INVSLOT_TABARD,
};

BonusXP.heirloomSlotAuras = {
	[INVSLOT_HEAD]		= Heirloom10,
	[INVSLOT_SHOULDER]	= Heirloom10,
	[INVSLOT_CHEST]		= Heirloom10,
	[INVSLOT_LEGS]		= Heirloom10,
	[INVSLOT_FINGER1]	= Heirloom5,
	[INVSLOT_FINGER2]	= Heirloom5,
	[INVSLOT_BACK]		= Heirloom5,
	[INVSLOT_TRINKET1]	= Heirloom50PvPInstance,
	[INVSLOT_TRINKET2]	= Heirloom50PvPInstance,
};

BonusXP.itemAuras = {
	[153714] = Rubellite5,
};

BonusXP.anniversaryPattern = {
	["en"] = { "WoW(.*)niversary" },
	["pt"] = { "(.*)versário do WoW" },
	["it"] = { "(.*)versario di WoW" },
	["fr"] = { "(.*)versaire de WoW" },
	["es"] = { "(.*)versario de WoW" },
	["de"] = { "(.*)eburtstag von WoW" },
	["ru"] = { "(.*)годовщина World of Warcraft" },
	["cn"] = { "魔兽世界(.*)周年" },
	["ko"] = { "월드 오브(.*)주년", "와우(.*)주년" },
};

BonusXP.slotItemIdMap = {
	[INVSLOT_AMMO]		= nil,
	[INVSLOT_HEAD]		= nil,
	[INVSLOT_NECK]		= nil,
	[INVSLOT_SHOULDER]	= nil,
	[INVSLOT_BODY]		= nil, -- (shirt)
	[INVSLOT_CHEST]		= nil,
	[INVSLOT_WAIST]		= nil,
	[INVSLOT_LEGS]		= nil,
	[INVSLOT_FEET]		= nil,
	[INVSLOT_WRIST]		= nil,
	[INVSLOT_HAND]		= nil,
	[INVSLOT_FINGER1]	= nil,
	[INVSLOT_FINGER2]	= nil,
	[INVSLOT_TRINKET1]	= nil,
	[INVSLOT_TRINKET2]	= nil,
	[INVSLOT_BACK]		= nil,
	[INVSLOT_MAINHAND]	= nil,
	[INVSLOT_OFFHAND]	= nil,
	[INVSLOT_RANGED]	= nil,
	[INVSLOT_TABARD]	= nil,
};

local function xpTrinketGetPvpZoneBonus(id)
	if isInPvPInstance and ( id == 126948 or id == 126949 ) then
		return { quest = 50, kill = 50 };
	else
		return { quest = 0, kill = 0 };
	end
end;
local itemAuraXPInfo = {
	[Heirloom5]		= xpBonus5, -- "Heirloom Experience Bonus +5%"
	[Heirloom10]	= xpBonus10, -- "Heirloom Experience Bonus +10%"
	[Rubellite5]	= xpBonus5, -- "Rubellite - Experience Bonus +5%"
	[Heirloom50PvPInstance]     = { getBonus = xpTrinketGetPvpZoneBonus }
};

local xpNoExperience = { isBlockXPGainAura = true };
local xpLegionInvasion = { killId=1, questId=2 }; 	-- -90%
local xpEnlisted = { killId=4, questId=5 };  		-- 1,2 - display bonus, 3 - all reps bonus, 4 - kill bonus, 5 - quest bonus, 6... - ???
local function xpBfaGetZoneBonus(self, auraInfo)
	local res = { 
		quest = self.quest or self.questId and auraInfo[15 + self.questId] or 0,
		kill = self.kill or self.killId and auraInfo[15 + self.killId] or 0
	};
	
	if res.quest == 0 and res.kill == 0 then
		if bfaMapBonusIds[currentPlayerContinent] then
			res.quest = 10;
			res.kill = 10;
		end
	end
	
	return res;
end;

local SpellXPInfo = {
  [326419]  = { questId = 1, killId = 2}, -- "Winds of Wisdom"
	[269083]	= xpEnlisted, -- War mode
	[130283]	= { questId = 1, killId = 2},	-- "Enlightenment" 50% Monk
	[127250]	= { questId = 1, killId = 2},	-- "Ancient Knowledge" 300%
	[155755]	= { killId = 1 },				-- "Apexis Charge" 10%
	[277952]	= { killId=1, questId=3 },		-- "WoW's 14th Anniversary"
	[46668]		= { killId=1, questId=2 },		-- "WHEE!" Darkmoon Carusel 
	[281561]	= xpNoExperience,				-- = "Uncontested" ???  Zero all xpBonus and add -100%
	[212846]	= { killId=1, questId=2 },		-- "The Council's Wisdom" 5%
	
	[290340]	= { killId=1, questId=2 },		-- "Taste of Victory" 10%
	-- Next two auras have tooltip with 10% XP bonus but no XP bonus value provided
	[290337]	= { killId=1, questId=2, getBonus = xpBfaGetZoneBonus },		-- "Taste of Victory" 10% -- no bonus value provided 
	[292137]	= { killId=1, questId=2, getBonus = xpBfaGetZoneBonus },		-- "Taste of Victory" 10% -- no bonus value provided 
	
	[189375]	= { questId = 1, killId = 2,	-- "Rapid Mind" 300%
					-- level={ [100] = {quest = 0, kill = 0}  } 
				}, 
	[292242]	= xpNoExperience,				-- "No Experience" -100%
	[262759]	= xpNoExperience,				-- "No Experience" -100%
	[217514]	= xpLegionInvasion,				-- "Legion Invasion" -90%
	[218273]	= xpLegionInvasion,
	[218285]	= xpLegionInvasion,
	[218336]	= xpLegionInvasion,
	[218337]	= xpLegionInvasion,
	[227520]	= xpLegionInvasion,
	[227521]	= xpLegionInvasion,
	[86963]		= { questId = 1 },				-- "Learning by Example" 10%
	[91991]		= { killId=1, questId=2 },		-- "Juju Instinct" 5%
	
	[186334]	= { kill = 2, quest = 1 },		-- "Honored Champion" 50% PvP exp, trinket effect 126948, 126949
	
	[171333]	= { questId = 2, killId = 3 },	-- "Garrison Ability Override" 20%
	[171334]	= { questId = 2, killId = 3 },	-- "Garrison Ability Override" 20%
	[78631]		= { questId = 1, killId = 2 },	-- "Fast Track (Rank 1)" 5% Guild Perk
	[78632]		= { questId = 1, killId = 2 },	-- "Fast Track (Rank 2)" 10% Guild Perk
	
	-- Next two capital-auras look like bugged. It displays bonus but not apply it to end expierence.
	[289954]	= xpEnlisted, 					-- "War mode Alliance in Stormwind"  Bugged? 
	[282559]	= xpEnlisted, 					-- "War mode Horde in Orgrimmar"     Bugged? 
	
	[146929]	= { questId = 1, killId = 2, 	-- "Enduring Elixir of Wisdom" 100% ??? mageonly? nonInGame?
					-- level={ [100] = {quest = 0, kill = 0}  } 
				}, 
	[289982]	= { killId=2, questId=3 },		-- "Draught of Ten Lands" 10%
	[136583]	= { killId=1, questId=2 },		-- "Darkmoon Top Hat" 10%
	[85617]		= { killId=1, questId=2 },		-- "Argus' Journal" 2%
	[178119]	= { questId = 1, killId = 2 },	-- "Accelerated Learning" 20%
	[210072]	= { questId = 1 },				-- "_JKL - live update crash test 2" -100%
	[33377]		= { killId=1 }, 				-- Blessing of Auchindoun
	[176798]	= { killId=1 }, 				-- Blessing of Spirits
	[58045]		= { killId=1 }, 				-- Essence of Wintergrasp 5%
	[194110]	= { killId=1 }, 				-- Gift of the Storm 60%
	[24705]		= { killId=1 }, 				-- Grim Visage 10%
	[95987]		= { killId=1 }, 				-- Unburdened 10%
	[90708]		= { killId=1 }, 				-- Guild Battle Standard
	[90216]		= { killId=1 }, 				-- Guild Battle Standard
	[32098]		= { killId=1 }, 				-- Honor Hold's Favor 25%
	[88257]		= { killId=1 }, 				-- Night Dragon Deftness 2%
	[95988]		= { killId=1 }, 				-- Reverence for the Flame 10%
	[29175]		= { killId=1 }, 				-- Ribbon Dance 10%
	[58440]		= { killId=1 }, 				-- Rork Red Ribbon
	[230272]	= xpNoExperience,				-- Stranglethorn Streaker
	[32096]		= { killId=1 }, 				-- Thrallmar's Favor
	[87592]		= { killId=2 }, 				-- Ex-KEF: Active Aura -50%
	[177771]	= { killId=1 }, 				-- Farondis/Idri Guardian Aura -95%
	[87391]		= { killId=2 }, 				-- Viking Helmet -50%
	[42138]		= { killId=1 }, 				-- Brewfest Enthusiast 2%
};

local AnniversaryId = nil;
local AnniversaryWorkId = 277952;

local maxPlayerLevel = nil;
local maxRAFPlayerLevel = nil;
local isRAFEnabled = nil;

function BonusXP:isXpInfoDisabled()
	return maxPlayerLevel==playerLevel or IsXPUserDisabled();
end

function BonusXP:getShortHeight()
	return xpDisabled and lineHeight or lineHeight * 2;
end

function BonusXP:getFullHeight()
	return xpDisabled and lineHeight*5 + gapLineHeight*3 or lineHeight*6 + gapLineHeight*4;
end

function BonusXP:getMapTopParentInfo(mapID)
  local mapInfo = mapID and C_Map.GetMapInfo(mapID) or {};

  while (mapInfo.parentMapID and mapInfo.parentMapID ~= 0 and mapInfo.parentMapID ~= AzerothId and mapInfo.parentMapID ~= CosmosId) do
	mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID) or {};
  end
  return mapInfo;
end

function BonusXP:getContinentId(event)
	currentUiMapID = C_Map.GetBestMapForUnit("player");
	local mapInfo = BonusXP:getMapTopParentInfo(currentUiMapID);
	
	return mapInfo.mapID or currentPlayerContinent;
end

function BonusXP:initialize(f)
	playerLevel = UnitLevel("player");
	maxPlayerLevel = GetMaxPlayerLevel();
	maxRAFPlayerLevel = MAX_PLAYER_LEVEL_TABLE[GetMaximumExpansionLevel() - 1];
	isRAFEnabled = C_RecruitAFriend.IsEnabled();
	
	xpDisabled = BonusXP:isXpInfoDisabled();
	
	local l = GetLocale();
	playerLanguage = l and string.sub(l, 1, 2) or "en";
	currentPlayerContinent = BonusXP:getContinentId("Initialize");
	local _, instanceType = IsInInstance(); 
	isInPvPInstance = instanceType=="pvp" or instanceType=="arena";
	
	xpExhaustion = GetXPExhaustion() or 0;
	
	local isRafQuestBonusActive, isRafKillBonusActive = BonusXP:getGroupInfo();
	isCurrentRAFBonusActive = isRafQuestBonusActive or isRafKillBonusActive;
	
	f:SetWidth(200);
	linePositions = {
		[0] = -gapLineHeight,
		[1] = -gapLineHeight-lineHeight,
		[2] = -gapLineHeight*2-lineHeight*2,
		[3] = -gapLineHeight*2-lineHeight*3,
		[4] = -gapLineHeight*3-lineHeight*4
	};
	
	local rafdy = isCurrentRAFBonusActive and (lineHeight + gapLineHeight) or 0;
	local shortHeight = BonusXP:getShortHeight();
	local fullHeight = BonusXP:getFullHeight();

  --BonusXP_Tooltip_BuffTitle:SetText("Buffs");
	f.shortLine = BonusXP:createLabel(f, 10, linePositions[0]);
	f.RafXpBonus = BonusXP:createLabel(f, 10, linePositions[0]);
	f.equipXpBonus = BonusXP:createLabel(f, 10, linePositions[0]-rafdy);
	f.auraXpBonus = BonusXP:createLabel(f, 10, linePositions[1]-rafdy);
	f.totalKillXpBonus = BonusXP:createLabel(f, 10, linePositions[2]-rafdy);
	f.totalQuestXpBonus = BonusXP:createLabel(f, 10, linePositions[3]-rafdy);
	f.XPexhaustion = BonusXP:createLabel(f, 10, linePositions[4]-rafdy);
	f.shortXpLine =  BonusXP:createLabel(f, 10, 0);
	
	BonusXP:updateFrameTextPositions(f, false);
	
	BonusXP:registerEvents(f);
end

function BonusXP:registerEvents(frame)
	frame:RegisterEvent("PLAYER_LEVEL_UP");
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	frame:RegisterEvent("ZONE_CHANGED");
	frame:RegisterEvent("ZONE_CHANGED_INDOORS");
	frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	frame:RegisterEvent("PLAYER_XP_UPDATE");
	frame:RegisterEvent("UPDATE_EXHAUSTION");
	frame:RegisterEvent("PLAYER_REGEN_DISABLED");
	frame:RegisterEvent("PLAYER_REGEN_ENABLED");

	BonusXP.elapsedTimer = 1;
  button:SetScript("OnUpdate", BonusXP.onUpdate);
end

BonusXP_UpdateInterval = 1.0;
function BonusXP:onUpdate(elapsed)
  BonusXP.elapsedTimer = BonusXP.elapsedTimer + elapsed;
  if BonusXP.elapsedTimer < BonusXP_UpdateInterval then return end

  local isRafQuestBonusActive, isRafKillBonusActive, closeMemberCount, closeFriendCount = BonusXP:getGroupInfo();

  local isRAFBonusActive = isRafQuestBonusActive or isRafKillBonusActive;
  local isRAFStateChanged = isCurrentRAFBonusActive ~= isRAFBonusActive;
  isCurrentRAFBonusActive = isRAFBonusActive;

  equipXpBonus.totalKill = equipXpBonus.kill + (not isRafKillBonusActive and heirloomXpBonus.kill or 0);
  equipXpBonus.totalQuest = equipXpBonus.quest + (not isRafQuestBonusActive and heirloomXpBonus.quest or 0);

  rafBonus.killActive = isRafKillBonusActive and rafBonus.kill or 0;
  rafBonus.questActive = isRafQuestBonusActive and rafBonus.quest or 0;

  local isRestBonusActive = xpExhaustion > 0;
  local xpBaseModBonusKill = (100 + equipXpBonus.totalKill + auraXpBonus.kill) / 100; 
  xpBonusKill = (xpBaseModBonusKill / closeMemberCount) * (1 + 0.1078 * (closeMemberCount-1)) * (isRestBonusActive and 2 or ((100 + rafBonus.killActive) / 100)) * 100 - 100;
  xpBonusQuest = (100 + equipXpBonus.totalQuest + auraXpBonus.quest) * (100 + rafBonus.questActive) / 100 - 100;

  BonusXP:updateFrameTextPositions(tooltip, isRAFStateChanged);
  BonusXP:updateFrameText(tooltip);
  BonusXP:updateTooltipHeight();
  BonusXP.elapsedTimer = 0;
end

function BonusXP:updateTooltipHeight()
  tooltip:SetHeight(tooltip:GetTop() - BonusXP_Tooltip_Total:GetBottom() + 10);
end


function BonusXP:getItemAuraXpBonus(auraId, itemId)
	local spinfo = itemAuraXPInfo[auraId];
	
	return spinfo and spinfo.getBonus and spinfo.getBonus(itemId) or spinfo;
end

function BonusXP:getSpInfoBonus(spinfo, sr)
	return spinfo.getBonus and spinfo.getBonus(spinfo, sr) or { 
		quest = spinfo.quest or spinfo.questId and sr[15 + spinfo.questId] or 0,
		kill = spinfo.kill or spinfo.killId and sr[15 + spinfo.killId] or 0
	};
end

function BonusXP:isWowAnniversaryAura(label, id)
	if AnniversaryId then
		return AnniversaryId == id and AnniversaryWorkId;
	end
	
	local pattern = BonusXP.anniversaryPattern[playerLanguage];
	
	for i=1, #pattern do
		if string.match(label, pattern[i]) then 
			AnniversaryId = id;
			return AnniversaryWorkId; 
		end
	end
	return nil;
end

function BonusXP:getAuraXpBonus(sr, canbeAnniversary)
	local spinfo, cnt, result, lvl;
	local name = sr[1];
	local spellId = sr[10];
	
	if canbeAnniversary then
		spellId = BonusXP:isWowAnniversaryAura(name, spellId) or spellId;
	end
	
	spinfo = SpellXPInfo[spellId];
	if spinfo then
		if spinfo.isBlockXPGainAura then
			return spinfo;
		end
		
		if spinfo.level then
			lvl = 0;
			for k,v in pairs(spinfo.level) do
				if playerLevel >= k and k > lvl then
					lvl = k;
				end
			end
			spinfo = spinfo.level[lvl] or spinfo;
		end
		
		result = BonusXP:getSpInfoBonus(spinfo, sr);
	else
		result = { kill = 0, quest = 0 };
	end
	result.isAnniversary = spellId == AnniversaryWorkId;

	return result;
end

function BonusXP:isMemberVisible(memberId, isInDraenorGarrison)
	local memberDistance, _ = UnitDistanceSquared(memberId);
	-- UnitIsVisible(memberId)
	if memberDistance < 10000 then
		if isInDraenorGarrison then 
			return UnitCanAssist("player", memberId);
		end
		return true;
	end
	return false;
end

function BonusXP:getGroupInfo()		
	local closeMemberCount, closeFriendCount = 1, 1;
	local minLevelRange, minEffLevelRange = 1000, 1000;
	local isSameExpansion = false;
	local isInQuestLevelRange = false;

	local numPartyMembers = GetNumSubgroupMembers();
    if numPartyMembers > 0 then
        local index = 1;
		local playerEffLevel = UnitEffectiveLevel("player");
		local nearestExpansionLevel = GetExpansionForLevel(playerEffLevel);
		
		local isRafUsable = isRAFEnabled and playerLevel < maxRAFPlayerLevel;
		local maxPlayerLevelOfExpansionForPlayer = MAX_PLAYER_LEVEL_TABLE[nearestExpansionLevel];
		local isInDraenorGarrison = C_Garrison.IsPlayerInGarrison(LE_GARRISON_TYPE_6_0);
		
		local notABnFriend = { isFriend = false };
        while index <= numPartyMembers do
            local memberId = "party" .. index;
            if UnitIsPlayer(memberId) then
				if BonusXP:isMemberVisible(memberId, isInDraenorGarrison) then
					closeMemberCount = closeMemberCount + 1;
					
					local memberGuid = UnitGUID(memberId);
				
					if C_FriendList.IsFriend(memberGuid) or (C_BattleNet.GetAccountInfoByGUID(memberGuid) or notABnFriend).isFriend then
						closeFriendCount = closeFriendCount + 1;
						
						if isRafUsable and IsRecruitAFriendLinked(memberGuid) then
							local memberEffLevel = UnitEffectiveLevel(memberId);
							local memberLevel = UnitLevel(memberId);
						
							if not isSameExpansion then
								isSameExpansion = GetExpansionForLevel(memberEffLevel) == nearestExpansionLevel;
							end
							
							if not isInQuestLevelRange then
								isInQuestLevelRange = (maxPlayerLevelOfExpansionForPlayer + 5) > memberLevel;
							end
							
							minEffLevelRange = math.min(math.abs(memberEffLevel - playerEffLevel), minEffLevelRange);
							minLevelRange = math.min(math.abs(memberLevel - playerLevel), minLevelRange);
						end
					end
				end
            end
            index = index + 1;
        end
    end
	
	return	minEffLevelRange < 5 or isSameExpansion or isInQuestLevelRange,	-- isRafQuestBonusActive 
			minLevelRange < 5,					-- isRafKillBonusActive 
			closeMemberCount, closeFriendCount;	-- including player
end


function BonusXP:refreshSpellData()
	local name, spellId, iconId, perc;

	auraXpBonus = { kill=0, quest=0 };
  auras = {};
	
	local isAnniversaryFound = false;
	
	for i=1,40 do
		local sr = { UnitAura("player",i) };
		name = sr[1];
		iconId = sr[2];
		spellId = sr[10];

		
		if name then 
			local bonus = BonusXP:getAuraXpBonus(sr, not isAnniversaryFound);
			
			if bonus.isBlockXPGainAura then
				auraXpBonus = { kill=-100, quest=-100, isBlockXPGainAura = true };
				break;
			end
			
			isAnniversaryFound = bonus.isAnniversary or isAnniversaryFound;

      if bonus.quest > 0 or bonus.kill > 0 then
          auras[#auras+1] = { name = name, id = spellId, questBonus = bonus.quest, killBonus = bonus.kill };
      end
			
			auraXpBonus.quest = auraXpBonus.quest + bonus.quest;
			auraXpBonus.kill = auraXpBonus.kill + bonus.kill;
		else
			break;
		end 
	end 
end

function BonusXP:refreshEquipDataSlot(slotId, ...)
	local itemLink = GetInventoryItemLink("player", slotId);
	local eqItem, alreadyLoaded, id, name = {
		slotId = slotId,
		itemLink = itemLink,
	}, false, nil, nil;
	local forceLoad = ...;
	
	if itemLink then 
		id, name = getItemLinkInfo(itemLink);
		
		alreadyLoaded = not forceLoad and id and equipItemData[id];
		if not alreadyLoaded then
			if id and not name then
				awaitingData[id] = slotId;
				name = GetItemInfo(id);
				if name then
					awaitingData[id] = nil;
					itemLink = GetInventoryItemLink("player", slotId);
				end
			end	

			if name then
				eqItem = BonusXP:readFullItemData(itemLink);
				eqItem.slotId = slotId;
			end
			id = id or eqItem.id;
			
			if id then
				equipItemData[id] = eqItem;
			end
		else
			eqItem = alreadyLoaded;
		end
	end
	
	if eqItem.heirloom then 
		eqItem.heirloom.auraId = BonusXP.heirloomSlotAuras[slotId];
	end
	
	BonusXP.slotItemIdMap[slotId] = eqItem.id or nil;
	
	return eqItem;
end

function BonusXP:refreshEquipData()
	local count, eqItem, slotId;
	local heirloomIDs = _G.C_Heirloom.GetHeirloomItemIDs(); -- required to get heirlooms data ready
	
	count = #BonusXP.equipAllSlots;
	for i=1,count do
		slotId = BonusXP.equipAllSlots[i];
		BonusXP:refreshEquipDataSlot(slotId);
	end
end


function BonusXP:calculateEquipment()
	if 0 < #awaitingHeirloomData then
		forceUpdateGearInfo = true;
		return false;
	end
	local xpBonus,auraId, slotId, itemId, item;
	
	equipXpBonus = { kill=0, quest=0 };
	heirloomXpBonus = { kill=0, quest=0 };
	
	for slotId, itemId in pairs(BonusXP.slotItemIdMap) do 
		item = itemId and equipItemData[itemId];
		
		if item then
			if item.heirloom and playerLevel < item.heirloom.maxLevel then
				if item.heirloom.auraId then
					xpBonus = BonusXP:getItemAuraXpBonus(item.heirloom.auraId, itemId);
					
					if Heirloom50PvPInstance == item.heirloom.auraId then
						equipXpBonus.quest = equipXpBonus.quest + xpBonus.quest;
						equipXpBonus.kill = equipXpBonus.kill + xpBonus.kill;
					else
						heirloomXpBonus.quest = heirloomXpBonus.quest + xpBonus.quest;
						heirloomXpBonus.kill = heirloomXpBonus.kill + xpBonus.kill;
					end
				end
			end
			
			xpBonus = item.enchantId and BonusXP:getItemAuraXpBonus(item.enchantId, itemId);
			if xpBonus then
				equipXpBonus.quest = equipXpBonus.quest + xpBonus.quest;
				equipXpBonus.kill = equipXpBonus.kill + xpBonus.kill;
			end
			
			local cnt, gemId = #item.gems;
			for i=1, cnt do
				gemId = item.gems[i];
				auraId = gemId > 0 and BonusXP.itemAuras[gemId]
				if auraId then
					xpBonus = BonusXP:getItemAuraXpBonus(auraId, itemId);
					equipXpBonus.quest = equipXpBonus.quest + xpBonus.quest;
					equipXpBonus.kill = equipXpBonus.kill + xpBonus.kill;
				end
			end
		end
	end
		
	return true;
end

function BonusXP:updateGearInfo()
	if (#awaitingData) > 0 then 
		return false; 
	end
	if not BonusXP:calculateEquipment() then
		forceUpdateGearInfo = true;
		return false;
	end
	
	return true;
end

function BonusXP:updateFrameTextPositions(f, isRAFStateChanged)
	local rafdy = isCurrentRAFBonusActive and (lineHeight + gapLineHeight) or 0;
	local shortHeight = BonusXP:getShortHeight();
	local fullHeight = BonusXP:getFullHeight();
	
	if BonusXPConfig.collapsed then
		if(f:GetHeight() > shortHeight) then
			f:SetHeight(shortHeight);
			
			f.shortLine:SetShown(true);
			f.RafXpBonus:SetShown(false);
			f.equipXpBonus:SetShown(false);
			f.auraXpBonus:SetShown(false);
			f.totalKillXpBonus:SetShown(false);
			f.totalQuestXpBonus:SetShown(false);
			f.XPexhaustion:SetShown(false);
		end
	else
		if f:GetHeight() < (fullHeight + rafdy) then
			f.shortLine:SetShown(false);
			f.equipXpBonus:SetShown(true);
			f.auraXpBonus:SetShown(true);
			f.totalKillXpBonus:SetShown(true);
			f.totalQuestXpBonus:SetShown(true);
			f.XPexhaustion:SetShown(true);
		end
		
		f:SetHeight(fullHeight + rafdy);
		f.RafXpBonus:SetShown(isCurrentRAFBonusActive);
	end	
	
	f.shortXpLine:SetShown(true);
	
	if isRAFStateChanged then

		BonusXP:setLabelTop(f, f.equipXpBonus, linePositions[0]-rafdy);  -- 5
		BonusXP:setLabelTop(f, f.auraXpBonus, linePositions[1]-rafdy); -- 25
		BonusXP:setLabelTop(f, f.totalKillXpBonus, linePositions[2]-rafdy); --50
		BonusXP:setLabelTop(f, f.totalQuestXpBonus, linePositions[3]-rafdy); --70
		BonusXP:setLabelTop(f, f.XPexhaustion, linePositions[4]-rafdy); --95
	end
	
	BonusXP:setLabelTop(f, f.shortXpLine, -f:GetHeight()+lineHeight*2 );
end

function BonusXP:updateFrameText(f)
  BonusXP_Tooltip_BuffsTotal:SetText(auraXpBonus.quest .. "%");
  BonusXP_Tooltip_EquipmentTotal:SetText(equipXpBonus.totalQuest .. "%");
  BonusXP_Tooltip_Total:SetText("Total Bonus XP: " .. xpBonusQuest .. "%");

  if isCurrentRAFBonusActive then
    BonusXP_Tooltip_RAFTitle:Show();
    BonusXP_Tooltip_RAFTotal:SetText(((1+rafBonus.questActive/100)*(auraXpBonus.quest+100))-auraXpBonus.quest-100  .. "%");
    BonusXP_Tooltip_RAFTotal:Show();
  else
    BonusXP_Tooltip_RAFTitle:Hide();
    BonusXP_Tooltip_RAFTotal:Hide();
  end
	BonusXP:updateBuffText();
  updateButton();
end

function BonusXP:updateXPExhaustion(f)
	local isRestBonusActive = xpExhaustion > 0; 
	local killBonus = xpBonusKill;
	
  f.shortLine:SetText(string.format("Lvl: |c%s%d|r, K: |c%s%.1f%%|r, Q: |c%s%.1f%%|r, exH: |c%s%d|r", valColor, playerLevel, valColor, killBonus, valColor, xpBonusQuest, valColor, xpExhaustion));
	
	return XPExhaustion;
end

function BonusXP:updateBuffText()
  local names, values = "", "";
  for i=1, #auras do
    names = names .. string.format("%s\r", auras[i].name);
    values = values .. string.format("%s%%\r", auras[i].questBonus);
  end



  BonusXP_Tooltip_BuffsList:SetText(names);
  BonusXP_Tooltip_BuffsListTotal:SetText(values);
end

function BonusXP:onLaterLoading(self)
	local onDemand = IsAddOnLoadOnDemand("BonusXP");
	
	if not isPlayerReadyFired and IsLoggedIn() and onDemand then
		hqaawEventHandler(self, "PLAYER_LOGIN");
	end
end

function BonusXP:onPlayerReady(self, event, arg1)
	if isPlayerReadyFired then return end
	isPlayerReadyFired = true;
	
	BonusXP:initialize(self);
	
	BonusXP:refreshEquipData();
	BonusXP:refreshSpellData();
	BonusXP:updateGearInfo();
  
  updateButton();
	
end

function BonusXP:onEventHandler(self, event, ...)
	local arg1, arg2, arg3, arg4, arg5 = ...
	
	if event == "PLAYER_LOGIN" then
		local n = UnitAura("player",1);
		if not isPlayerReadyFired and n then
			BonusXP:onPlayerReady(self, event, arg1);
		end
		
		self:UnregisterEvent("PLAYER_LOGIN");
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		BonusXP:refreshEquipDataSlot(arg1);
		BonusXP:updateGearInfo();
		isEquipmentChanged = true;
	elseif event == "UNIT_AURA" and arg1 == "player" then
		if not isPlayerReadyFired then
			BonusXP:onPlayerReady(self, event, arg2);
		elseif isEquipmentChanged then
			isEquipmentChanged = false;
		else
			
			BonusXP:refreshSpellData();
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then 
		currentPlayerContinent = BonusXP:getContinentId(event);
		BonusXP:refreshSpellData();
		
		local _, instanceType = IsInInstance(); 
		local isInPvPArea = instanceType=="pvp" or instanceType=="arena";
		local isAreaChanged = isInPvPArea ~= isInPvPInstance;
		isInPvPInstance = isInPvPArea;
		if isAreaChanged then BonusXP:updateGearInfo(); end
		
		uiMapArtID = C_Map.GetMapArtID(currentUiMapID or -1); 
	elseif event == "ADDON_LOADED" and arg1=="BonusXP" then 
		BonusXP:onLaterLoading(self);
		
		self:UnregisterEvent("ADDON_LOADED");
	elseif event == "PLAYER_LEVEL_UP" then
		playerLevel = arg1 or UnitLevel("player");
		BonusXP:refreshEquipData();
		BonusXP:updateGearInfo();
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		local slotId = awaitingData[arg1];
		
		if slotId then 
			awaitingData[arg1] = nil;
			
			BonusXP:updateGearInfo();
		end
	elseif event == "HEIRLOOMS_UPDATED" and arg2=="UPGRADE" then
		local item = equipItemData[arg1];
		if item then
			olditemMaxLevel = item.heirloom.maxLevel;
			item.heirloom.maxLevel = select(10, C_Heirloom.GetHeirloomInfo(arg1));
			
			if BonusXP.slotItemIdMap[item.slotId] == arg1 and playerLevel > olditemMaxLevel and playerLevel < item.heirloom.maxLevel then
				BonusXP:updateGearInfo();
			end
		end
	elseif event == "HEIRLOOMS_UPDATED" then
		BonusXP:onPlayerReady(self, event, arg1);
		local cnt = #awaitingHeirloomData;
		if not arg1 and not arg2 and cnt > 0 then
			for i=1, cnt do
				local itemId = awaitingHeirloomData[i];
				local item = equipItemData[itemId];
				item.heirloom.maxLevel = select(10, C_Heirloom.GetHeirloomInfo(itemId));
				if item.heirloom.maxLevel then
					awaitingHeirloomData[i] = nil;
				end
			end
			if forceUpdateGearInfo then
				forceUpdateGearInfo = false;
				BonusXP:updateGearInfo();
			elseif forceCalculateEquipment then
				forceCalculateEquipment = false;
				BonusXP:calculateEquipment();
			end
		end
	elseif event == "UPDATE_EXHAUSTION" then
		xpExhaustion = GetXPExhaustion() or 0;
	elseif event == "PLAYER_REGEN_DISABLED" then
		if self:IsEventRegistered("UNIT_AURA") then 
			self:UnregisterEvent("UNIT_AURA");
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if not self:IsEventRegistered("UNIT_AURA") then 
			self:RegisterEvent("UNIT_AURA");
		end
	elseif event == "PLAYER_LOGOUT" then
		self:UnregisterAllEvents();
	end 
end


function BonusXP:readFullItemData(itemLink)
	local id, _, color, enchantId, jewels, bonusIds;
	id, _, _, _, _, color, enchantId, jewels, bonusIds = getItemLinkInfo(itemLink);
	
	local isHeirloom = 
			C_Heirloom.PlayerHasHeirloom(id);
	local item = {
		id = id,
		gems = jewels,
		enchantId = enchantId,
		heirloom = isHeirloom and { 
			maxLevel = select(10, C_Heirloom.GetHeirloomInfo(id));
		} or nil
	};
	if item.heirloom and not item.heirloom.maxLevel then
		table.insert(awaitingHeirloomData, id);
	end
	
	return item;
end

function BonusXP:createMainFrame()

  button:SetText("Bonus XP")
	button:SetScript("OnEnter", function() 
    tooltip:Show();
	end);
	button:SetScript("OnLeave", function() 
    tooltip:Hide();
	end);

  f = tooltip;
	f:Hide();
	
	f:RegisterEvent("ADDON_LOADED");
	f:RegisterEvent("PLAYER_LOGIN");
	f:RegisterEvent("UNIT_AURA");
	f:RegisterEvent("HEIRLOOMS_UPDATED");
	f:RegisterEvent("PLAYER_LOGOUT");
	
	f:SetScript("OnEvent", function(self, ...)
		BonusXP:onEventHandler(f, ...);
	end);
end

function updateButton()
  button:SetText(string.format("Bonus XP: %s%%\r", xpBonusQuest));
end

function BonusXP:createLabel(f, ...)
	local  x, y, parentPos, labelPos = ... ;
	local l = f:CreateFontString();
	l:SetFontObject(BonusXP:getFont());
	l:SetPoint(labelPos or "TOPLEFT", f, parentPos or "TOPLEFT", x or 0, y or 0);
	
	return l;
end

function BonusXP:createButton(f, opts)
	opts = opts or {};
	local f = CreateFrame("Button", opts.name, f or UIParent)
	local backDrop = opts.backDrop or {
                                   bgFile = "Interface\\Buttons\\GreyscaleRamp64", 
                                   edgeFile = "Interface\\Buttons\\WHITE8X8", 
		     	                   edgeSize = 1
			   	                  };
	local bdColor = opts.color or { a=0.8, r=50/255, g=50/255, b=50/255 };
	local bdBoderColor = opts.borderColor or { a=0.8, r=60/255, g=60/255, b=60/255 };
	
	f:SetBackdrop(backDrop);
	f:SetBackdropColor(bdColor.r, bdColor.g, bdColor.b, bdColor.a);
	f:SetBackdropBorderColor(bdBoderColor.r, bdBoderColor.g, bdBoderColor.b, bdBoderColor.a);
	f:SetNormalFontObject(opts.font or BonusXP:getFont());
	
	f:SetSize(opts.width or 25, opts.height or 19);
	
	if opts.text then f:SetText(opts.text) end
	return f
end

function BonusXP:setLabelTop(f, l, y)
	l:ClearAllPoints();
	l:SetPoint("TOPLEFT", f, "TOPLEFT", 5, y);
end

function BonusXP:getFont()
	local font = fontFRIZQT;

	if not font then
		font = CreateFont("fontFRIZQT");
		font:SetFontObject("Tooltip_Med");
		font:SetFont("Fonts\\FRIZQT__.ttf", 12, "");
		font:SetTextColor(1,1,1,1);
		fontFRIZQT = font;
	end

	return font
end

function getItemLinkInfo(itemLink)
	if not itemLink then return nil end
	
	local splRes = { strsplit(":", itemLink) };
	
	local prefix, itemId, enchantId, jewelId1, jewelId2, jewelId3, jewelId4, suffixId, uniqueId, linkLevel, specializationID, upgradeTypeID, instanceDifficultyId, numBonusIds = unpack(splRes);
	numBonusIds = tonumber(numBonusIds) or 0;

	local bonusIds = {};
	for i = 1, numBonusIds do
		local bonusId = splRes[14+i];
		table.insert(bonusIds, tonumber(bonusId) or 0)
	end
	
	local segmentsCount = #splRes;
	local suffix = splRes[segmentsCount];
	local _,_, color, lType = string.find(prefix, "|c(%x*)|H([^:]*)");
	local _,_, lastValue, name = string.find(suffix, "([^|]*)|h%[?([^%[%]]*)%]?|h|?r?");
	splRes[segmentsCount] = lastValue
  
    local upgradeValue = upgradeTypeID and upgradeTypeID ~= "" and (tonumber(splRes[15 + numBonusIds]) or 0) or nil;
	
	local relicBonuses = {};

	if splRes[16 + numBonusIds] == "1" then -- Relic bonus present
		local pos = 17 + numBonusIds;
		local relicNumBonusIDs, relicBonusID, relic;
		
		-- read all relicXBonusIDs
		while pos <= segmentsCount and #relicBonuses < 4 do
			relicNumBonusIDs = tonumber(splRes[pos]) or 0;
			relic = {};
			for i=1, relicNumBonusIDs do
				local relicBonusID = tonumber(splRes[pos + i]) or 0;
				table.insert(relic, relicBonusID);
			end
			pos = pos + relicNumBonusIDs + 1;
			table.insert(relicBonuses, relic);
		end
	end

	local found = false;
	local jewels = {};
	local gems = { jewelId4, jewelId3, jewelId2, jewelId1 };

	for i = 1, 4 do
		local g = tonumber(gems[i]) or 0;
		found = found or g > 0;
		if found then
			table.insert(jewels, 1, g);
		end
	end
	
	return tonumber(itemId), name, tonumber(linkLevel), lType, tonumber(suffixId), color, tonumber(enchantId), jewels, bonusIds, tonumber(uniqueId), tonumber(upgradeTypeID), tonumber(instanceDifficultyId), tonumber(specializationID), upgradeValue, relicBonuses, segmentsCount
end

if not _G.strsplit then 
	function _G.strsplit(sep, inputstr) 
		sep=sep or '%s' 
		local t={} 
		for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do 
			table.insert(t,field) 
			if s=="" then return unpack(t) end 
		end 
	end
end

BonusXP:createMainFrame();
