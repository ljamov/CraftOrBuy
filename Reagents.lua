-- Reagent lists and vendor prices.
-- Reagents come from Data.lua (the 3.3.5 game data) for every recipe, and are
-- replaced by what your profession window shows for recipes you know.

local COB = CraftOrBuy

local function ItemName(id)
	return (GetItemInfo(id)) or CraftOrBuy_Items[id] or ("item:" .. id)
end

local staticCache = {}

-- Returns { reagents = { {name, count, itemID}, ... }, made = n, src = "data"|"ts" } or nil.
function COB.GetReagents(spell)
	local seen = COB.db.reagents[spell]
	if seen then return seen end
	local info = staticCache[spell]
	if info then return info end
	local rec = COB.bySpell[spell]
	if not rec or #rec.reagents == 0 then return nil end
	info = { reagents = {}, made = rec.made, src = "data" }
	for i = 1, #rec.reagents, 2 do
		local id, count = rec.reagents[i], rec.reagents[i + 1]
		table.insert(info.reagents, { ItemName(id), count, id })
	end
	staticCache[spell] = info
	return info
end

function COB.CountReagentCache()
	local n = 0
	for _ in pairs(COB.db.reagents) do n = n + 1 end
	return n
end

-- Exact reagents and number made, read from your open profession window.
local function ReadTradeSkill()
	if not GetNumTradeSkills then return end
	local linked = IsTradeSkillLinked and IsTradeSkillLinked()
	local known = COB.db.known[COB.charKey]
	local changed = false
	for i = 1, GetNumTradeSkills() do
		local _, kind = GetTradeSkillInfo(i)
		if kind and kind ~= "header" then
			local link = GetTradeSkillRecipeLink(i)
			local spell = link and tonumber(link:match("enchant:(%d+)"))
			if spell then
				local list = {}
				for j = 1, GetTradeSkillNumReagents(i) do
					local name, _, count = GetTradeSkillReagentInfo(i, j)
					local itemLink = GetTradeSkillReagentItemLink(i, j)
					local id = itemLink and tonumber(itemLink:match("item:(%d+)"))
					if not name then list = nil; break end
					table.insert(list, { name, count, id })
				end
				if list and #list > 0 then
					local minMade, maxMade = GetTradeSkillNumMade(i)
					local made = ((minMade or 1) + (maxMade or minMade or 1)) / 2
					COB.db.reagents[spell] = { reagents = list, made = made, src = "ts" }
					staticCache[spell] = nil
					changed = true
				end
				if not linked then known[spell] = true end
			end
		end
	end
	if changed and COB.RefreshUI then COB.RefreshUI() end
end

-- Records unlimited-stock vendor items, so Warmane's real vendor prices win over the defaults.
local function ReadMerchant()
	local changed = false
	for i = 1, GetMerchantNumItems() do
		local name, _, price, quantity, numAvailable, _, extendedCost = GetMerchantItemInfo(i)
		if name and price and price > 0 and numAvailable == -1 and not extendedCost then
			local each = price / math.max(quantity or 1, 1)
			if COB.db.vendor[name] ~= each then
				COB.db.vendor[name] = each
				changed = true
			end
		end
	end
	if changed and COB.RefreshUI then COB.RefreshUI() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRADE_SKILL_UPDATE")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:SetScript("OnEvent", function(self, event)
	if not COB.db then return end
	if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
		ReadTradeSkill()
	else
		ReadMerchant()
	end
end)
