local _, BonusXP = ...
local playerFaction, _ = UnitFactionGroup("player");
local playerLevel = UnitLevel("player");
local playerLanguage = "en";
local xpBonusQuest = 0;
local auraXpBonus = {quest=0};
local auras = {};

local xpBonus5, xpBonus10, rafBonus = { quest = 5 }, { quest = 10 }, { quest=50 };

local isPlayerReadyFired = false;
local awaitingData = {};
local isCurrentRAFBonusActive = false;
local button = BonusXP_InventoryButton;
local tooltip = BonusXP_Tooltip;
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
local equipItemData = {};
local equipAllSlots = {
	INVSLOT_AMMO,
	INVSLOT_HEAD,
	INVSLOT_NECK,
	INVSLOT_SHOULDER,
	INVSLOT_BODY, -- Shirt
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

local itemAuras = {
	[153714] = Rubellite5,
};

local anniversaryPattern = {
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

local slotItemIdMap = {
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
		return { quest = 50 };
	else
		return { quest = 0 };
	end
end;

local xpNoExperience = { isBlockXPGainAura = true };
local xpLegionInvasion = { questId=2 };
local function xpBfaGetZoneBonus(self, auraInfo)
	local res = {
		quest = self.quest or self.questId and auraInfo[15 + self.questId] or 0
	};

	if res.quest == 0 then
		if bfaMapBonusIds[currentPlayerContinent] then
			res.quest = 10;
		end
	end

	return res;
end;

local SpellXPInfo = {
  [326419]  = { questId=1 },    -- "Winds of Wisdom" 100%
	[269083]	= { questId=5 },    -- "War Mode"
	[289954]	= { questId=1 },    -- "War Mode" (Alliance-specific in Stormwind)
	[282559]	= { questId=1 },    -- "War Mode" (Horde-specific in Orgrimmar)
	[130283]	= { questId=1 },    -- "Enlightenment" 50% Monk
	[127250]	= { questId=1 },    -- "Ancient Knowledge" 300%
	[277952]	= { questId=3 },	 	-- "WoW's 14th Anniversary"
	[46668]		= { questId=2 },	 	-- "WHEE!" Darkmoon Carusel
	[281561]	= xpNoExperience,	 	-- = "Uncontested" -100%
	[212846]	= { questId=2 },  	-- "The Council's Wisdom" 5%
	[290340]	= { questId=2 },  	-- "Taste of Victory" 10%
	[189375]	= { questId=1 },	  -- "Rapid Mind" 300%
	[292242]	= xpNoExperience,	  -- "No Experience" -100%
	[262759]	= xpNoExperience,	  -- "No Experience" -100%
	[217514]	= xpLegionInvasion, -- "Legion Invasion" -90%
	[218273]	= xpLegionInvasion, -- "Legion Invasion" -90%
	[218285]	= xpLegionInvasion, -- "Legion Invasion" -90%
	[218336]	= xpLegionInvasion, -- "Legion Invasion" -90%
	[218337]	= xpLegionInvasion, -- "Legion Invasion" -90%
	[227520]	= xpLegionInvasion, -- "Legion Invasion" -90%
	[227521]	= xpLegionInvasion, -- "Legion Invasion" -90%
	[86963]		= { questId=1 },    -- "Learning by Example" 10%
	[91991]		= { questId=2 },	  -- "Juju Instinct" 5%
	[186334]	= { questId=1 },	  -- "Honored Champion" 50% PvP Exp
	[171333]	= { questId=2 },	  -- "Garrison Ability Override" 20%
	[171334]	= { questId=2 },  	-- "Garrison Ability Override" 20%
	[78631]		= { questId=1 },  	-- "Fast Track (Rank 1)" 5% Guild Perk
	[78632]		= { questId=1 },  	-- "Fast Track (Rank 2)" 10% Guild Perk
	[146929]	= { questId=1 },  	-- "Enduring Elixir of Wisdom" 100% (Mage-only)
	[289982]	= { questId=3 },	  -- "Draught of Ten Lands" 10%
	[136583]	= { questId=2 },  	-- "Darkmoon Top Hat" 10%
	[85617]		= { questId=2 },  	-- "Argus' Journal" 2%
	[178119]	= { questId=1 },  	-- "Accelerated Learning" 20%
	[210072]	= { questId=1 },   	-- "_JKL - live update crash test 2" -100%
	[230272]	= xpNoExperience,		-- Stranglethorn Streaker -100%

	-- Next two auras have tooltip with 10% XP bonus but no XP bonus value provided
	[290337]	= { questId=2, getBonus = xpBfaGetZoneBonus },		-- "Taste of Victory" 10%
	[292137]	= { questId=2, getBonus = xpBfaGetZoneBonus },		-- "Taste of Victory" 10%

};

local AnniversaryId = nil;
local AnniversaryWorkId = 277952;

local maxRAFPlayerLevel = nil;
local isRAFEnabled = nil;

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

function BonusXP:initialize()


	playerLevel = UnitLevel("player");
	maxRAFPlayerLevel = GetMaxLevelForExpansionLevel(GetMaximumExpansionLevel() - 1);
	isRAFEnabled = C_RecruitAFriend.IsEnabled();

	local l = GetLocale();
	playerLanguage = l and string.sub(l, 1, 2) or "en";
	currentPlayerContinent = BonusXP:getContinentId("Initialize");
	local _, instanceType = IsInInstance();
	isInPvPInstance = instanceType=="pvp" or instanceType=="arena";

	isCurrentRAFBonusActive = BonusXP:getGroupInfo();
end

function BonusXP:registerEvents()
	button:RegisterEvent("PLAYER_LOGIN");
	button:RegisterEvent("UNIT_AURA");
	button:RegisterEvent("PLAYER_LOGOUT");
	button:RegisterEvent("PLAYER_LEVEL_UP");
	button:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	button:RegisterEvent("ZONE_CHANGED");
	button:RegisterEvent("ZONE_CHANGED_INDOORS");
	button:RegisterEvent("PLAYER_XP_UPDATE");
	button:RegisterEvent("PLAYER_REGEN_DISABLED");
	button:RegisterEvent("PLAYER_REGEN_ENABLED");
end

function BonusXP:updateUI()
  if not button:IsVisible() then return end

  BonusXP:updateButton();
  BonusXP:updateTooltipText();
  BonusXP:updateTooltipSize();
end

function BonusXP:calculateBonus()
  isCurrentRAFBonusActive = BonusXP:getGroupInfo();

  rafBonus.questActive = isCurrentRAFBonusActive and rafBonus.quest or 0;

  xpBonusQuest = (100 + auraXpBonus.quest) * (100 + rafBonus.questActive) / 100 - 100;

  --BonusXP:updateUI();
end

function BonusXP:updateTooltipSize()
  tooltip:SetHeight(tooltip:GetTop() - BonusXP_Tooltip_Total:GetBottom() + 10);

  local listWidth = BonusXP_Tooltip_BuffsList:GetWidth();
  local width = math.max(listWidth+50, 200);
  tooltip:SetWidth(width);
end

function BonusXP:getSpInfoBonus(spinfo, sr)
	return spinfo.getBonus and spinfo.getBonus(spinfo, sr) or {
		quest = spinfo.quest or spinfo.questId and sr[15 + spinfo.questId] or 0
	};
end

function BonusXP:isWowAnniversaryAura(label, id)
	if AnniversaryId then
		return AnniversaryId == id and AnniversaryWorkId;
	end

	local pattern = anniversaryPattern[playerLanguage];

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
		result = { quest=0 };
	end
	result.isAnniversary = spellId == AnniversaryWorkId;

	return result;
end

function BonusXP:isMemberVisible(memberId, isInDraenorGarrison)
	local memberDistance, _ = UnitDistanceSquared(memberId);
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
		local maxPlayerLevelOfExpansionForPlayer = GetMaxLevelForExpansionLevel(nearestExpansionLevel);
		local isInDraenorGarrison = C_Garrison.IsPlayerInGarrison(Enum.GarrisonType.Type_6_0);

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

	return	minEffLevelRange < 5 or isSameExpansion or isInQuestLevelRange;
end


function BonusXP:refreshSpellData()
	local name, spellId;

	auraXpBonus = { quest=0 };
  auras = {};

	local isAnniversaryFound = false;

	for i=1,40 do
		local sr = { UnitAura("player",i) };
		name = sr[1];
		spellId = sr[10];

		if name then
			local bonus = BonusXP:getAuraXpBonus(sr, not isAnniversaryFound);

			if bonus.isBlockXPGainAura then
				auraXpBonus = { quest=-100, isBlockXPGainAura = true };
				break;
			end

			isAnniversaryFound = bonus.isAnniversary or isAnniversaryFound;

      if bonus.quest > 0 then
          auras[#auras+1] = { name = name, id = spellId, questBonus = bonus.quest };
      end

			auraXpBonus.quest = auraXpBonus.quest + bonus.quest;
		else
			break;
		end
	end
end

function BonusXP:updateTooltipText()
  BonusXP:updateBuffText();
  BonusXP:updateRAFText();
  button.titleText = "Total Bonus XP: " .. xpBonusQuest .. "%";
end

function BonusXP:updateBuffText()
  local title = BonusXP_Tooltip_BuffsTitle;
  local total = BonusXP_Tooltip_BuffsTotal;
  if auraXpBonus.quest > 0 then
    title:SetFontObject(Game13FontEnabled)
    total:SetFontObject(Game13FontEnabled)
  else
    title:SetFontObject(Game13FontDisabled)
    total:SetFontObject(Game13FontDisabled)
  end

  total:SetText(auraXpBonus.quest .. "%");
	BonusXP:updateBuffListText();
end

function BonusXP:updateRAFText()
  local title = BonusXP_Tooltip_RAFTitle;
  local total = BonusXP_Tooltip_RAFTotal;
  if isCurrentRAFBonusActive then
    title:SetFontObject(Game13FontEnabled)
    total:SetFontObject(Game13FontEnabled)
  else
    title:SetFontObject(Game13FontDisabled)
    total:SetFontObject(Game13FontDisabled)
  end

  BonusXP_Tooltip_RAFTotal:SetText(((1+rafBonus.questActive/100)*(auraXpBonus.quest+100))-auraXpBonus.quest-100  .. "%");
end

function BonusXP:updateBuffListText()
  local names, values = "", "";
  for i=1, #auras do
    names = names .. string.format("%s\r", auras[i].name);
    values = values .. string.format("%s%%\r", auras[i].questBonus);
  end

  BonusXP_Tooltip_BuffsList:SetText(names);
  BonusXP_Tooltip_BuffsListTotal:SetText(values);
end

function BonusXP:onPlayerReady()
	if isPlayerReadyFired then return end
	isPlayerReadyFired = true;

	BonusXP:initialize();

	BonusXP:refreshSpellData();

  BonusXP:calculateBonus();
end

function BonusXP:onEventHandler(self, event, ...)
	local arg1, arg2, arg3, arg4, arg5 = ...

	if event == "PLAYER_LOGIN" then
		local n = UnitAura("player",1);
		if not isPlayerReadyFired and n then
			BonusXP:onPlayerReady();
		end

		button:UnregisterEvent("PLAYER_LOGIN");
	elseif event == "UNIT_AURA" and arg1 == "player" then
		if not isPlayerReadyFired then
			BonusXP:onPlayerReady();
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
	elseif event == "PLAYER_REGEN_DISABLED" then
		if button:IsEventRegistered("UNIT_AURA") then
			button:UnregisterEvent("UNIT_AURA");
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if not button:IsEventRegistered("UNIT_AURA") then
			button:RegisterEvent("UNIT_AURA");
		end
	elseif event == "PLAYER_LOGOUT" then
		button:UnregisterAllEvents();
    return
	end

  BonusXP:calculateBonus();
end

function BonusXP:setup()

  button.Title:SetText("Bonus XP")
	--button:SetScript("OnEnter", function()
    --tooltip:Show();
	--end);
	--button:SetScript("OnLeave", function()
    --tooltip:Hide();
	--end);

	tooltip:Hide();

  BonusXP:registerEvents();

  button:SetScript("OnEvent", function(self, ...)
		BonusXP:onEventHandler(f, ...);
	end);
  CharacterStatsPane:SetScript("OnShow", function(self, ...)
    if button:IsVisible() then return end

    local stats = { CharacterStatsPane:GetChildren() }

    print(dump(CharacterStatsPane.EnhancementsCategory));

    button:SetParent(CharacterStatsPane.EnhancementsCategory);
    button:SetPoint("TOP", stats[#stats-1], "BOTTOM", 0, -5);
    button:Show();

    BonusXP:onEventHandler(f, ...);
	end);
end

function BonusXP:updateButton()
  button.titleText = string.format("Bonus XP: %s%%\r", xpBonusQuest);
end

function BonusXP:getDetails()
  return xpBonusQuest .. "%";
end

_G.GetBonusXP = function()
  return BonusXP:getDetails();
end;

BonusXP:setup();
