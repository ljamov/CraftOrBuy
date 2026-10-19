-- Main window: professions on the left, recipes in the middle, details and history on the right.

local COB = CraftOrBuy

local W, H = 1100, 640
local NAV_ROWS, NAV_H = 22, 22
local LIST_ROWS, LIST_H = 20, 24
local REAGENT_LINES = 8
local LINE_H = 17
local CHART_W, CHART_H, CHART_BARS = 300, 108, 30

-- Own font objects so the font size setting changes every text in the window at once.
local F_TEXT, F_LABEL, F_DIM, F_BIG = "CraftOrBuyFontText", "CraftOrBuyFontLabel", "CraftOrBuyFontDim", "CraftOrBuyFontBig"
do
	local base = GameFontNormal:GetFont()
	local fonts = {
		{ F_TEXT, 0, 1, 1, 1 },
		{ F_LABEL, 0, 1, 0.82, 0 },
		{ F_DIM, 0, 0.6, 0.6, 0.6 },
		{ F_BIG, 4, 1, 0.82, 0 },
	}
	for _, f in ipairs(fonts) do
		local fo = CreateFont(f[1])
		fo:SetFont(base, 12 + f[2])
		fo:SetTextColor(f[3], f[4], f[5])
		fo:SetShadowColor(0, 0, 0, 1)
		fo:SetShadowOffset(1, -1)
	end
	function CraftOrBuy.ApplyFontSize()
		local size = (CraftOrBuy.db and CraftOrBuy.db.fontSize) or 12
		for _, f in ipairs(fonts) do
			_G[f[1]]:SetFont(base, size + f[2])
		end
	end
end

local PROF_ICONS = {
	["Alchemy"] = "Trade_Alchemy",
	["Blacksmithing"] = "Trade_BlackSmithing",
	["Cooking"] = "INV_Misc_Food_15",
	["Enchanting"] = "Trade_Engraving",
	["Engineering"] = "Trade_Engineering",
	["First Aid"] = "Spell_Holy_SealOfSacrifice",
	["Inscription"] = "INV_Inscription_Tradeskill01",
	["Jewelcrafting"] = "INV_Misc_Gem_01",
	["Leatherworking"] = "INV_Misc_ArmorKit_17",
	["Mining"] = "Trade_Mining",
	["Tailoring"] = "Trade_Tailoring",
}

-- Order item groups are shown in; anything not listed comes after, alphabetically.
local GROUP_ORDER = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs", "Feet",
	"Finger", "Trinket", "Two-Hand", "One-Hand", "Main Hand", "Off Hand", "Held In Off-hand", "Shield", "Ranged",
	"Relic", "Ammo", "Quiver", "Bag",
}
local GROUP_RANK = {}
for i, g in ipairs(GROUP_ORDER) do GROUP_RANK[g] = i end
local function GroupRank(g)
	if g == "Other" then return 1000 end
	return GROUP_RANK[g] or 500
end

local PANEL_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local state = {
	expanded = {},      -- profession name -> true
	collapsed = {},     -- item group -> true
	nav = { kind = "deals" },
	sortKey = "diff",
	sortDesc = true,
	search = "",
	onlyKnown = false,
	rows = {},          -- list rows: evaluated recipes and group headers
	count = 0,
	selected = nil,     -- recipe
	histMode = "day",
}

local frame -- main frame, created on first open

local function Color(hex, text) return "|cff" .. hex .. text .. "|r" end

local function QualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	return c and c.hex or "|cffffffff"
end

local function RecipeIcon(rec)
	if rec.item > 0 then
		local icon = GetItemIcon and GetItemIcon(rec.item)
		if icon then return icon end
	end
	return select(3, GetSpellInfo(rec.spell)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function DiffText(res, short)
	if not res.hasReagents then return Color("808080", "no recipe data") end
	if not res.complete then return Color("808080", "mats unpriced") end
	if not res.ah then return Color("808080", "not on AH") end
	if res.diff >= 0 then return Color("40ff40", "+" .. COB.FormatMoney(res.diff, short)) end
	return Color("ff5050", COB.FormatMoney(res.diff, short))
end

local function CostText(res, short)
	if not res.hasReagents then return Color("808080", "?") end
	if res.complete then return COB.FormatMoney(res.costEach, short) end
	if res.cost > 0 then return COB.FormatMoney(res.costEach, short) .. Color("808080", "+?") end
	return Color("808080", "?")
end

-- A FontString that stays on one line (cut with "..." if too long) so nothing overlaps.
local function Font(parent, template, justify, width, height)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or F_TEXT)
	fs:SetJustifyH(justify or "LEFT")
	if width then fs:SetWidth(width) end
	fs:SetHeight(height or 16)
	return fs
end

---------------------------------------------------------------------------
-- Navigation (left)
---------------------------------------------------------------------------

local function BuildNav()
	local nav = { { kind = "deals", text = "Best deals (all)", icon = "INV_Misc_Coin_02" } }
	for pi, prof in ipairs(CraftOrBuy_Professions) do
		table.insert(nav, { kind = "prof", prof = pi, text = prof.name, icon = PROF_ICONS[prof.name] })
		if state.expanded[prof.name] then
			for ci, cat in ipairs(prof.categories) do
				table.insert(nav, { kind = "cat", prof = pi, cat = ci, text = cat.name })
			end
		end
	end
	return nav
end

local function NavMatches(a, b)
	return a.kind == b.kind and a.prof == b.prof and a.cat == b.cat
end

local function UpdateNav()
	local nav = BuildNav()
	local scroll = frame.navScroll
	FauxScrollFrame_Update(scroll, #nav, NAV_ROWS, NAV_H)
	local offset = FauxScrollFrame_GetOffset(scroll)
	for i = 1, NAV_ROWS do
		local btn = frame.navButtons[i]
		local entry = nav[i + offset]
		if entry then
			btn.entry = entry
			local indent = entry.kind == "cat" and 24 or 4
			btn.icon:ClearAllPoints()
			btn.icon:SetPoint("LEFT", indent, 0)
			btn.text:ClearAllPoints()
			if entry.icon then
				btn.icon:SetTexture("Interface\\Icons\\" .. entry.icon)
				btn.icon:Show()
				btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 5, 0)
			else
				btn.icon:Hide()
				btn.text:SetPoint("LEFT", indent, 0)
			end
			btn.text:SetPoint("RIGHT", -2, 0)
			local label = entry.text
			if entry.kind == "prof" then
				label = (state.expanded[entry.text] and "- " or "+ ") .. label
			end
			btn.text:SetText(label)
			if NavMatches(entry, state.nav) then
				btn.text:SetTextColor(1, 0.82, 0)
				btn.sel:Show()
			else
				if entry.kind == "cat" then btn.text:SetTextColor(0.85, 0.85, 0.85) else btn.text:SetTextColor(1, 1, 1) end
				btn.sel:Hide()
			end
			btn:Show()
		else
			btn:Hide()
		end
	end
end

---------------------------------------------------------------------------
-- Recipe list (middle)
---------------------------------------------------------------------------

local function SourceRecipes()
	local nav = state.nav
	if nav.kind == "prof" then
		return CraftOrBuy_Professions[nav.prof].all
	elseif nav.kind == "cat" then
		return CraftOrBuy_Professions[nav.prof].categories[nav.cat].list
	end
	return COB.recipes
end

local SORTERS = {
	name = function(a, b) return a.rec.name < b.rec.name end,
	cost = function(a, b) return (a.hasReagents and a.costEach or -1) < (b.hasReagents and b.costEach or -1) end,
	ah = function(a, b) return (a.ah or -1) < (b.ah or -1) end,
	diff = function(a, b) return (a.diff or -math.huge) < (b.diff or -math.huge) end,
}

local function BuildRows()
	local known = COB.db.known[COB.charKey]
	local search = state.search:lower()
	local deals = state.nav.kind == "deals"
	local list = {}
	for _, rec in ipairs(SourceRecipes()) do
		if (search == "" or rec.name:lower():find(search, 1, true))
			and (not state.onlyKnown or known[rec.spell]) then
			local res = COB.Evaluate(rec)
			if not deals or res.diff then table.insert(list, res) end
		end
	end
	local cmp = SORTERS[state.sortKey]
	local function ordered(a, b)
		if state.sortDesc then return cmp(b, a) end
		return cmp(a, b)
	end
	state.count = #list

	if deals then
		table.sort(list, ordered)
		state.rows = list
		return
	end

	-- Group by item slot / type, each group sorted by quality, then by the chosen column.
	table.sort(list, function(a, b)
		local ga, gb = a.rec.group, b.rec.group
		if ga ~= gb then
			local ra, rb = GroupRank(ga), GroupRank(gb)
			if ra ~= rb then return ra < rb end
			return ga < gb
		end
		-- Inside a group: Legendary, Epic, Rare, Uncommon, Common, then the chosen column.
		local qa, qb = a.rec.quality or 1, b.rec.quality or 1
		if qa ~= qb then return qa > qb end
		if ordered(a, b) then return true end
		if ordered(b, a) then return false end
		return a.rec.name < b.rec.name
	end)
	local rows, counts = {}, {}
	for _, res in ipairs(list) do counts[res.rec.group] = (counts[res.rec.group] or 0) + 1 end
	local current
	for _, res in ipairs(list) do
		local g = res.rec.group
		if g ~= current then
			current = g
			table.insert(rows, { header = g, count = counts[g] })
		end
		if not state.collapsed[g] then table.insert(rows, res) end
	end
	state.rows = rows
end

local function UpdateList()
	local rows = state.rows
	local scroll = frame.listScroll
	FauxScrollFrame_Update(scroll, #rows, LIST_ROWS, LIST_H)
	local offset = FauxScrollFrame_GetOffset(scroll)
	local known = COB.db.known[COB.charKey]
	for i = 1, LIST_ROWS do
		local row = frame.listRows[i]
		local res = rows[i + offset]
		row.res = res
		if res and res.header then
			row.icon:Hide()
			row.name:SetText((state.collapsed[res.header] and "+ " or "- ") .. res.header .. Color("808080", "  (" .. res.count .. ")"))
			row.name:SetFontObject(F_LABEL)
			row.cost:SetText(""); row.ah:SetText(""); row.diff:SetText("")
			row.headerBg:Show()
			row.sel:Hide()
			row:Show()
		elseif res then
			local rec = res.rec
			row.headerBg:Hide()
			row.icon:SetTexture(RecipeIcon(rec))
			row.icon:Show()
			row.name:SetFontObject(F_TEXT)
			local name = QualityColor(rec.quality) .. rec.name .. "|r"
			if known[rec.spell] then name = name .. Color("40ff40", " *") end
			row.name:SetText(name)
			row.cost:SetText(CostText(res, true))
			row.ah:SetText(res.ah and COB.FormatMoney(res.ah, true) or Color("808080", "-"))
			row.diff:SetText(DiffText(res, true))
			if state.selected == rec then row.sel:Show() else row.sel:Hide() end
			row:Show()
		else
			row:Hide()
		end
	end
	frame.countText:SetText(state.count .. " recipes")
end

---------------------------------------------------------------------------
-- Detail panel (right)
---------------------------------------------------------------------------

local function UpdateChart(name)
	local chart = frame.chart
	local hist = COB.GetHistory(name, state.histMode)
	local maxP = 0
	for _, h in ipairs(hist) do maxP = math.max(maxP, h.hi) end
	local n = #hist
	local barW = n > 0 and math.floor(CHART_W / math.max(n, 8)) or 0
	for i = 1, CHART_BARS do
		local bar = chart.bars[i]
		local h = hist[i]
		if h and maxP > 0 then
			bar:ClearAllPoints()
			bar:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", (i - 1) * barW + 1, 0)
			bar:SetWidth(math.max(barW - 2, 2))
			bar:SetHeight(math.max(2, CHART_H * h.avg / maxP))
			local lowY = CHART_H * h.lo / maxP
			bar.range:ClearAllPoints()
			bar.range:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, lowY)
			bar.range:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, lowY)
			bar.range:SetHeight(math.max(2, CHART_H * (h.hi - h.lo) / maxP))
			bar.data = h
			bar:Show()
		else
			bar:Hide()
		end
	end
	if n == 0 then
		chart.empty:SetText("No history yet.\nDo an Auctionator full scan and\nCraftOrBuy saves today's prices.")
		chart.empty:Show()
		chart.first:SetText(""); chart.last:SetText(""); chart.max:SetText("")
	else
		chart.empty:Hide()
		chart.first:SetText(hist[1].label)
		chart.last:SetText(n > 1 and hist[n].label or "")
		chart.max:SetText("max " .. COB.FormatMoney(maxP, true))
	end
	for mode, btn in pairs(frame.histButtons) do
		if mode == state.histMode then btn:LockHighlight() else btn:UnlockHighlight() end
	end
end

local function UpdateDetail()
	local d = frame.detail
	local rec = state.selected
	if not rec then
		d.icon:SetTexture(nil)
		d.title:SetText("Select a recipe")
		d.sub:SetText("Click any item in the list.")
		for i = 1, REAGENT_LINES do d.reagents[i]:SetText(""); d.reagentCost[i]:SetText("") end
		for i = 1, #d.summary do d.summary[i]:SetText(""); d.summaryVal[i]:SetText("") end
		d.verdict:SetText("")
		frame.chartBox:Hide()
		return
	end
	frame.chartBox:Show()
	local res = COB.Evaluate(rec)
	d.icon:SetTexture(RecipeIcon(rec))
	d.title:SetText(QualityColor(rec.quality) .. rec.name .. "|r")
	local sub = rec.cat .. " - " .. rec.group
	if COB.db.known[COB.charKey][rec.spell] then sub = Color("40ff40", "Known  ") .. sub end
	d.sub:SetText(sub)

	for i = 1, REAGENT_LINES do
		local r = res.reagents[i]
		if r then
			local src = (r.src == "Vendor" and Color("80c0ff", " (vendor)")) or (r.src == "Craft" and Color("ffb040", " (crafted)")) or ""
			d.reagents[i]:SetText(r.count .. " x " .. r.name .. src)
			d.reagentCost[i]:SetText(r.total and COB.FormatMoney(r.total, true) or Color("ff5050", "no price"))
		else
			d.reagents[i]:SetText(i == 1 and not res.hasReagents and Color("808080", "No reagent data for this recipe.") or "")
			d.reagentCost[i]:SetText("")
		end
	end

	local madeText = res.made ~= 1 and string.format(" (makes %g)", res.made) or ""
	local lines = {
		{ "Mats cost" .. madeText, CostText(res) },
		{ "AH lowest", COB.FormatMoney(res.low) },
		{ "AH median", COB.FormatMoney(res.median) },
		{ "Crafting saves", res.diff and DiffText(res) or Color("808080", "-") },
		{ "Profit if sold (-5%)", res.profit and (res.profit >= 0 and Color("40ff40", COB.FormatMoney(res.profit)) or Color("ff5050", COB.FormatMoney(res.profit))) or Color("808080", "-") },
	}
	for i, l in ipairs(lines) do
		d.summary[i]:SetText(l[1])
		d.summaryVal[i]:SetText(l[2])
	end
	if res.diff then
		d.verdict:SetText(res.diff >= 0 and Color("40ff40", "CRAFT IT") or Color("ff5050", "BUY IT"))
	elseif res.hasReagents and not res.complete then
		d.verdict:SetText(Color("808080", "Scan the AH to price all mats"))
	else
		d.verdict:SetText("")
	end
	frame.chartTitle:SetText("Price history")
	UpdateChart(res.outName)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local function UpdateHeader()
	local mode = COB.db.priceMode == "median" and "Median" or "Lowest"
	frame.modeButton:SetText("AH price: " .. mode)
	local scan = AUCTIONATOR_LAST_SCAN_TIME and date("%Y-%m-%d %H:%M", AUCTIONATOR_LAST_SCAN_TIME) or "never"
	frame.scanText:SetText(COB.RealmKey() .. "    Last full scan: " .. scan)
	for key, h in pairs(frame.headers) do
		local arrow = ""
		if state.sortKey == key then arrow = state.sortDesc and " v" or " ^" end
		h:SetText(h.label .. arrow)
	end
end

local function Refresh()
	BuildRows()
	UpdateHeader()
	UpdateNav()
	UpdateList()
	UpdateDetail()
end

function COB.RefreshUI()
	if not frame or not frame:IsShown() then return end
	COB.SafeCall(Refresh)
end

-- Log button turns red with the number of errors when there are any.
function COB.UpdateLogButton()
	if not frame or not frame.logButton then return end
	local n = COB.LogCount()
	frame.logButton:SetText(n > 0 and ("|cffff5050Log (" .. n .. ")|r") or "Log")
end

function COB.ApplyScale()
	if frame then frame:SetScale(COB.db.scale or 1) end
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function MakePanel(parent, x, y, w, h)
	local p = CreateFrame("Frame", nil, parent)
	p:SetPoint("TOPLEFT", x, y)
	p:SetWidth(w); p:SetHeight(h)
	p:SetBackdrop(PANEL_BACKDROP)
	p:SetBackdropColor(0, 0, 0, 0.6)
	p:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	return p
end

local function Tip(widget, title, text)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(title)
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function CreateNav()
	local panel = MakePanel(frame, 14, -62, 214, NAV_ROWS * NAV_H + 16)
	local scroll = CreateFrame("ScrollFrame", "CraftOrBuyNavScroll", panel, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 6, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, NAV_H, UpdateNav)
	end)
	frame.navScroll = scroll
	frame.navButtons = {}
	for i = 1, NAV_ROWS do
		local btn = CreateFrame("Button", nil, panel)
		btn:SetHeight(NAV_H)
		btn:SetPoint("TOPLEFT", 6, -8 - (i - 1) * NAV_H)
		btn:SetPoint("RIGHT", panel, "RIGHT", -28, 0)
		btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		btn.sel = btn:CreateTexture(nil, "BACKGROUND")
		btn.sel:SetAllPoints()
		btn.sel:SetTexture(1, 0.82, 0, 0.15)
		btn.icon = btn:CreateTexture(nil, "ARTWORK")
		btn.icon:SetWidth(18); btn.icon:SetHeight(18)
		btn.text = Font(btn, F_TEXT, "LEFT")
		btn:SetScript("OnClick", function(self)
			local e = self.entry
			if e.kind == "prof" then
				local name = e.text
				if NavMatches(e, state.nav) or not state.expanded[name] then
					state.expanded[name] = not state.expanded[name]
				end
			end
			state.nav = { kind = e.kind, prof = e.prof, cat = e.cat }
			FauxScrollFrame_SetOffset(frame.listScroll, 0)
			frame.listScroll:SetVerticalScroll(0)
			COB.RefreshUI()
		end)
		frame.navButtons[i] = btn
	end
end

local function CreateList()
	local panel = MakePanel(frame, 234, -88, 520, LIST_ROWS * LIST_H + 34)
	frame.headers = {}
	local cols = {
		{ key = "name", label = "Item", x = 30, w = 214, justify = "LEFT",
			tip = "Sort by name. A green * means this character knows the recipe. Click a group title to fold it." },
		{ key = "cost", label = "Mats", x = 248, w = 78, justify = "RIGHT",
			tip = "Reagent cost for one item: the cheaper of the vendor price or the AH price. +? means some mats have no price yet." },
		{ key = "ah", label = "AH", x = 330, w = 78, justify = "RIGHT",
			tip = "Price of the finished item on the AH. Lowest = cheapest buyout at your last full scan. Median = typical price over Auctionator's recent scans. Switch with the button at the top." },
		{ key = "diff", label = "Craft saves", x = 410, w = 78, justify = "RIGHT",
			tip = "AH price minus mats cost. Green: crafting is cheaper. Red: buying is cheaper." },
	}
	for _, c in ipairs(cols) do
		local h = CreateFrame("Button", nil, panel)
		h:SetPoint("TOPLEFT", c.x, -6)
		h:SetWidth(c.w); h:SetHeight(20)
		local fs = Font(h, F_LABEL, c.justify)
		fs:SetAllPoints()
		h:SetFontString(fs)
		h.label = c.label
		h:SetText(c.label)
		h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		h:SetScript("OnClick", function()
			if state.sortKey == c.key then state.sortDesc = not state.sortDesc
			else state.sortKey = c.key; state.sortDesc = (c.key ~= "name") end
			COB.RefreshUI()
		end)
		Tip(h, c.label, c.tip)
		frame.headers[c.key] = h
	end

	local scroll = CreateFrame("ScrollFrame", "CraftOrBuyListScroll", panel, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 6, -28)
	scroll:SetPoint("BOTTOMRIGHT", -28, 6)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, LIST_H, UpdateList)
	end)
	frame.listScroll = scroll

	frame.listRows = {}
	for i = 1, LIST_ROWS do
		local row = CreateFrame("Button", nil, panel)
		row:SetHeight(LIST_H)
		row:SetPoint("TOPLEFT", 6, -28 - (i - 1) * LIST_H)
		row:SetPoint("RIGHT", panel, "RIGHT", -28, 0)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.headerBg = row:CreateTexture(nil, "BACKGROUND")
		row.headerBg:SetAllPoints()
		row.headerBg:SetTexture(1, 1, 1, 0.08)
		row.sel = row:CreateTexture(nil, "BACKGROUND")
		row.sel:SetAllPoints()
		row.sel:SetTexture(1, 0.82, 0, 0.18)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(20); row.icon:SetHeight(20)
		row.icon:SetPoint("LEFT", 2, 0)
		row.name = Font(row, F_TEXT, "LEFT", 214)
		row.name:SetPoint("LEFT", 26, 0)
		row.cost = Font(row, F_TEXT, "RIGHT", 78)
		row.cost:SetPoint("LEFT", 244, 0)
		row.ah = Font(row, F_TEXT, "RIGHT", 78)
		row.ah:SetPoint("LEFT", 326, 0)
		row.diff = Font(row, F_TEXT, "RIGHT", 80)
		row.diff:SetPoint("LEFT", 404, 0)
		row:SetScript("OnClick", function(self)
			local res = self.res
			if res.header then
				state.collapsed[res.header] = not state.collapsed[res.header]
				COB.RefreshUI()
				return
			end
			if IsModifiedClick("CHATLINK") and res.rec.item > 0 then
				local _, link = GetItemInfo(res.rec.item)
				if link then ChatEdit_InsertLink(link) end
				return
			end
			state.selected = res.rec
			UpdateList()
			UpdateDetail()
		end)
		row:SetScript("OnEnter", function(self)
			if not self.res or self.res.header then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local rec = self.res.rec
			if rec.item > 0 then GameTooltip:SetHyperlink("item:" .. rec.item)
			else GameTooltip:SetHyperlink("enchant:" .. rec.spell) end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.listRows[i] = row
	end
	frame.countText = Font(frame, F_DIM, "RIGHT", 200)
	frame.countText:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -4, -2)
end

local function CreateDetail()
	local PW = 330
	local panel = MakePanel(frame, 758, -88, PW, 534)
	local inner = PW - 24
	local d = {}
	frame.detail = d
	d.icon = panel:CreateTexture(nil, "ARTWORK")
	d.icon:SetWidth(36); d.icon:SetHeight(36)
	d.icon:SetPoint("TOPLEFT", 12, -12)
	d.title = Font(panel, F_BIG, "LEFT", inner - 44, 18)
	d.title:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 8, 0)
	d.sub = Font(panel, F_DIM, "LEFT", inner - 44, 16)
	d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -2)

	local rh = Font(panel, F_LABEL, "LEFT", inner)
	rh:SetPoint("TOPLEFT", 12, -60)
	rh:SetText("Reagents")
	d.reagents, d.reagentCost = {}, {}
	for i = 1, REAGENT_LINES do
		local y = -78 - (i - 1) * LINE_H
		local fs = Font(panel, F_TEXT, "LEFT", inner - 90)
		fs:SetPoint("TOPLEFT", 16, y)
		local v = Font(panel, F_TEXT, "RIGHT", 86)
		v:SetPoint("TOPRIGHT", -12, y)
		d.reagents[i], d.reagentCost[i] = fs, v
	end

	d.summary, d.summaryVal = {}, {}
	for i = 1, 5 do
		local y = -226 - (i - 1) * LINE_H
		local fs = Font(panel, F_LABEL, "LEFT", inner - 120)
		fs:SetPoint("TOPLEFT", 12, y)
		local v = Font(panel, F_TEXT, "RIGHT", 118)
		v:SetPoint("TOPRIGHT", -12, y)
		d.summary[i], d.summaryVal[i] = fs, v
	end
	d.verdict = Font(panel, F_BIG, "CENTER", inner, 20)
	d.verdict:SetPoint("TOP", 0, -318)

	-- History chart
	local box = CreateFrame("Frame", nil, panel)
	box:SetPoint("TOPLEFT", 12, -348)
	box:SetPoint("BOTTOMRIGHT", -12, 10)
	frame.chartBox = box
	frame.chartTitle = Font(box, F_LABEL, "LEFT", 120)
	frame.chartTitle:SetPoint("TOPLEFT", 0, 0)

	frame.histButtons = {}
	local modes = { { "day", "Days" }, { "month", "Months" }, { "year", "Years" } }
	for i, m in ipairs(modes) do
		local b = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
		b:SetWidth(78); b:SetHeight(20)
		b:SetPoint("TOPLEFT", (i - 1) * 82, -20)
		b:SetText(m[2])
		b:SetScript("OnClick", function()
			state.histMode = m[1]
			UpdateDetail()
		end)
		frame.histButtons[m[1]] = b
	end

	local chart = CreateFrame("Frame", nil, box)
	chart:SetPoint("BOTTOMLEFT", 2, 18)
	chart:SetWidth(CHART_W); chart:SetHeight(CHART_H)
	local bg = chart:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(1, 1, 1, 0.05)
	chart.bars = {}
	for i = 1, CHART_BARS do
		local bar = CreateFrame("Frame", nil, chart)
		bar:EnableMouse(true)
		local t = bar:CreateTexture(nil, "ARTWORK")
		t:SetAllPoints()
		t:SetTexture(0.25, 0.6, 1, 0.85)
		bar.range = bar:CreateTexture(nil, "OVERLAY")
		bar.range:SetTexture(1, 0.82, 0, 0.35)
		bar:SetScript("OnEnter", function(self)
			local h = self.data
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(h.label)
			if h.lo == h.hi then
				GameTooltip:AddDoubleLine("Price", COB.FormatMoney(h.avg), 1, 1, 1, 1, 1, 1)
			else
				GameTooltip:AddDoubleLine("Low", COB.FormatMoney(h.lo), 1, 1, 1, 1, 1, 1)
				GameTooltip:AddDoubleLine("Average", COB.FormatMoney(h.avg), 1, 1, 1, 1, 1, 1)
				GameTooltip:AddDoubleLine("High", COB.FormatMoney(h.hi), 1, 1, 1, 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
		bar:Hide()
		chart.bars[i] = bar
	end
	chart.empty = chart:CreateFontString(nil, "OVERLAY", F_DIM)
	chart.empty:SetPoint("CENTER")
	chart.first = Font(box, F_DIM, "LEFT", 140)
	chart.first:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -1)
	chart.last = Font(box, F_DIM, "RIGHT", 140)
	chart.last:SetPoint("TOPRIGHT", chart, "BOTTOMRIGHT", 0, -1)
	chart.max = Font(box, F_DIM, "LEFT", CHART_W)
	chart.max:SetPoint("BOTTOMLEFT", chart, "TOPLEFT", 2, 2)
	frame.chart = chart
end

local function CreateToolbar()
	local search = CreateFrame("EditBox", "CraftOrBuySearch", frame, "InputBoxTemplate")
	search:SetPoint("TOPLEFT", 300, -58)
	search:SetWidth(170); search:SetHeight(22)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function(self)
		state.search = self:GetText() or ""
		COB.RefreshUI()
	end)
	search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	local label = Font(frame, F_LABEL, "RIGHT", 60)
	label:SetPoint("RIGHT", search, "LEFT", -8, 0)
	label:SetText("Search")

	local mode = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	mode:SetPoint("LEFT", search, "RIGHT", 12, 0)
	mode:SetWidth(150); mode:SetHeight(22)
	mode:SetScript("OnClick", function()
		COB.db.priceMode = (COB.db.priceMode == "median") and "lowest" or "median"
		COB.db.useMedian = COB.db.priceMode == "median"
		COB.RefreshUI()
	end)
	Tip(mode, "Which AH price to compare",
		"Lowest: cheapest buyout per item at your last Auctionator full scan.\n\nMedian: middle of the lowest prices from Auctionator's recent full scans (up to 15). Less affected by one cheap or expensive listing.")
	frame.modeButton = mode

	local cb = CreateFrame("CheckButton", "CraftOrBuyOnlyKnown", frame, "UICheckButtonTemplate")
	cb:SetPoint("LEFT", mode, "RIGHT", 10, 0)
	cb:SetWidth(26); cb:SetHeight(26)
	local cbText = _G["CraftOrBuyOnlyKnownText"]
	cbText:SetFontObject(F_TEXT)
	cbText:SetText("Only my recipes")
	cb:SetScript("OnClick", function(self)
		state.onlyKnown = self:GetChecked() and true or false
		COB.RefreshUI()
	end)
	Tip(cb, "Only my recipes", "Recipes this character knows. Open each profession window once so CraftOrBuy can learn them.")
end

local function CreateMainFrame()
	frame = CreateFrame("Frame", "CraftOrBuyFrame", UIParent)
	frame:SetWidth(W); frame:SetHeight(H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnShow", function() COB.RefreshUI() end)
	tinsert(UISpecialFrames, "CraftOrBuyFrame")

	local title = Font(frame, F_BIG, "LEFT", 140, 20)
	title:SetPoint("TOPLEFT", 22, -20)
	title:SetText("CraftOrBuy")
	frame.scanText = Font(frame, F_DIM, "LEFT", 600)
	frame.scanText:SetPoint("LEFT", title, "RIGHT", 10, 0)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	local settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	settings:SetWidth(90); settings:SetHeight(22)
	settings:SetPoint("RIGHT", close, "LEFT", -4, 0)
	settings:SetText("Settings")
	settings:SetScript("OnClick", function() COB.OpenSettings() end)

	local log = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	log:SetWidth(90); log:SetHeight(22)
	log:SetPoint("RIGHT", settings, "LEFT", -4, 0)
	log:SetScript("OnClick", function() COB.ToggleLog() end)
	frame.logButton = log
	COB.UpdateLogButton()

	local credit = Font(frame, F_DIM, "LEFT", 214)
	credit:SetPoint("BOTTOMLEFT", 22, 16)
	credit:SetText("Creator: |cffffffffKristijan Ljamov|r")
	local site = Font(frame, F_DIM, "LEFT", 214)
	site:SetPoint("BOTTOMLEFT", credit, "TOPLEFT", 0, 0)
	site:SetText("|cff66bbffljamov.com|r")

	CreateNav()
	CreateToolbar()
	CreateList()
	CreateDetail()
	COB.ApplyScale()
	COB.ApplyFontSize()
	frame:Hide()
end

function COB.ToggleUI()
	if not frame then CreateMainFrame() end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

---------------------------------------------------------------------------
-- Item tooltips: add craft cost vs AH price for craftable items.
---------------------------------------------------------------------------

local function OnTooltipSetItem(tt)
	if not COB.byItem or not COB.db or not COB.db.tooltip then return end
	local _, link = tt:GetItem()
	local id = link and tonumber(link:match("item:(%d+)"))
	local rec = id and COB.byItem[id]
	if not rec then return end
	local res = COB.Evaluate(rec)
	tt:AddLine(" ")
	tt:AddDoubleLine("|cff33ff99CraftOrBuy|r", rec.prof)
	tt:AddDoubleLine("Craft (mats)", CostText(res), 1, 1, 1, 1, 1, 1)
	tt:AddDoubleLine("Buy (AH)", COB.FormatMoney(res.ah), 1, 1, 1, 1, 1, 1)
	if res.diff then
		if res.diff >= 0 then
			tt:AddLine("Crafting saves " .. COB.FormatMoney(res.diff), 0.25, 1, 0.25)
		else
			tt:AddLine("Buying saves " .. COB.FormatMoney(-res.diff), 1, 0.3, 0.3)
		end
	end
	tt:Show()
end

GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
