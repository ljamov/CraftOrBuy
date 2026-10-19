-- CraftOrBuy: buy vs craft comparison on top of Auctionator's scan data.

local ADDON = "CraftOrBuy"
local DB_VERSION = 3

CraftOrBuy = CraftOrBuy or {}
local COB = CraftOrBuy

-- Fallback when Log.lua is not loaded (WoW only picks up new files after a full restart).
if not COB.SafeCall then
	function COB.SafeCall(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then geterrorhandler()(err) end
		return ok, err
	end
	COB.LogCount = function() return 0 end
	COB.ToggleLog = function() COB.Print("the error log needs a full restart of WoW after the update.") end
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CraftOrBuy|r: " .. tostring(msg))
end
COB.Print = Print

-- Formats copper as "12g 34s 56c" with coloured unit letters.
function COB.FormatMoney(copper, short)
	if not copper then return "|cff808080?|r" end
	local neg = copper < 0
	copper = math.floor(math.abs(copper) + 0.5)
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	local G, S, C = "|cffffd700g|r", "|cffc7c7cfs|r", "|cffeda55fc|r"
	local out
	if g > 0 then
		out = short and (g .. G .. " " .. s .. S) or (g .. G .. " " .. s .. S .. " " .. c .. C)
	elseif s > 0 then
		out = s .. S .. " " .. c .. C
	else
		out = c .. C
	end
	return (neg and "-" or "") .. out
end

-- Same key Auctionator uses, e.g. "Icecrown_Horde".
function COB.RealmKey()
	return GetRealmName() .. "_" .. (UnitFactionGroup("player") or "Neutral")
end

local function ToName(item)
	if type(item) == "number" or (type(item) == "string" and item:find("|H")) then
		return (GetItemInfo(item))
	end
	return item
end

-- Lowest buyout per single item in Auctionator's last scan (copper), or nil.
function COB.GetLowest(item)
	local name = ToName(item)
	if name and gAtr_ScanDB then return gAtr_ScanDB[name] end
end

-- Median of the lowest prices from Auctionator's recent full scans (it keeps up to 15).
function COB.GetMedian(item)
	local name = ToName(item)
	local list = name and gAtr_MeanDB and gAtr_MeanDB[name]
	if not list or #list == 0 then return nil end
	local t = {}
	for i = 1, #list do t[i] = list[i] end
	table.sort(t)
	local n = #t
	if n % 2 == 1 then return t[(n + 1) / 2] end
	return math.floor((t[n / 2] + t[n / 2 + 1]) / 2)
end

-- Price used for comparisons, following the Lowest / Median switch in the window.
function COB.GetAHPrice(item)
	if COB.db and COB.db.priceMode == "median" then
		return COB.GetMedian(item) or COB.GetLowest(item)
	end
	return COB.GetLowest(item)
end

-- Vendor price: what you saw at a merchant, else the known 3.3.5 vendor price.
function COB.GetVendor(name, id)
	local seen = COB.db and COB.db.vendor[name]
	if seen then return seen end
	return id and CraftOrBuy_Vendor[id]
end

-- Cheapest way to get one unit of a reagent. Returns price, source ("Vendor"/"AH").
function COB.MatPrice(name, id)
	local v = COB.GetVendor(name, id)
	local a = COB.GetAHPrice(name)
	if v and (not a or v <= a) then return v, "Vendor" end
	if a then return a, "AH" end
	-- Not sold anywhere (e.g. Cured Rugged Hide, Jadefire Ink): use its own crafting cost.
	local rec = id and COB.db.craftIntermediates and COB.byItem[id]
	if rec and (COB.depth or 0) < 3 then
		COB.depth = (COB.depth or 0) + 1
		local res = COB.Evaluate(rec)
		COB.depth = COB.depth - 1
		if res.complete then return res.costEach, "Craft" end
	end
	return nil
end

-- Recipes flattened from Data.lua: { spell, item, quality, name, prof, cat }.
local function BuildRecipes()
	COB.recipes, COB.bySpell, COB.byItem = {}, {}, {}
	for _, prof in ipairs(CraftOrBuy_Professions) do
		prof.all = {}
		for _, cat in ipairs(prof.categories) do
			cat.list = {}
			for _, r in ipairs(cat.recipes) do
				local rec = { spell = r[1], item = r[2], quality = r[3], name = r[4], made = r[5] or 1,
					reagents = r[6] or {}, group = r[7] or "Other", prof = prof.name, cat = cat.name }
				table.insert(COB.recipes, rec)
				table.insert(cat.list, rec)
				table.insert(prof.all, rec)
				COB.bySpell[rec.spell] = rec
				if rec.item > 0 and not COB.byItem[rec.item] then COB.byItem[rec.item] = rec end
			end
		end
	end
end

-- Name the AH lists the crafted result under. Enchants sell as "Scroll of <enchant>".
function COB.OutputName(rec)
	if rec.item > 0 then
		return (GetItemInfo(rec.item)) or rec.name
	end
	if rec.prof == "Enchanting" and rec.name:find("^Enchant ") then
		return "Scroll of " .. rec.name
	end
	return rec.name
end

-- Full buy vs craft numbers for one recipe.
function COB.Evaluate(rec)
	local info = COB.GetReagents(rec.spell)
	local res = { rec = rec, reagents = {}, cost = 0, missing = 0, made = 1 }
	if info then
		res.made = info.made or 1
		for i, r in ipairs(info.reagents) do
			local unit, src = COB.MatPrice(r[1], r[3])
			res.reagents[i] = { name = r[1], count = r[2], unit = unit, src = src, total = unit and unit * r[2] }
			if unit then res.cost = res.cost + unit * r[2] else res.missing = res.missing + 1 end
		end
	end
	res.costEach = res.cost / res.made
	res.hasReagents = #res.reagents > 0
	res.complete = info ~= nil and #res.reagents > 0 and res.missing == 0
	res.outName = COB.OutputName(rec)
	res.low = COB.GetLowest(res.outName)
	res.median = COB.GetMedian(res.outName)
	res.ah = COB.GetAHPrice(res.outName)
	if res.complete and res.ah then
		res.diff = res.ah - res.costEach
		res.profit = res.ah * 0.95 - res.costEach
	end
	return res
end

function COB.CountScanDB()
	local n = 0
	if gAtr_ScanDB then for _ in pairs(gAtr_ScanDB) do n = n + 1 end end
	return n
end

local function InitDB()
	if type(CraftOrBuyDB) ~= "table" then CraftOrBuyDB = {} end
	local db = CraftOrBuyDB
	if (db.version or 0) < DB_VERSION then
		db.reagents = nil -- old tooltip-based reagent cache, replaced by Data.lua
		db.version = DB_VERSION
	end
	db.realms = db.realms or {}
	db.vendor = db.vendor or {}
	db.reagents = db.reagents or {}
	db.known = db.known or {}
	db.priceMode = db.priceMode or "lowest"
	db.scale = db.scale or 1
	db.fontSize = db.fontSize or 12
	if db.tooltip == nil then db.tooltip = true end
	if db.minimap == nil then db.minimap = true end
	db.minimapAngle = db.minimapAngle or 200
	if db.craftIntermediates == nil then db.craftIntermediates = true end
	local key = COB.RealmKey()
	db.realms[key] = db.realms[key] or {}
	db.realms[key].daily = db.realms[key].daily or {}
	db.realms[key].monthly = db.realms[key].monthly or {}
	COB.db = db
	COB.realm = db.realms[key]
	COB.charKey = UnitName("player") .. "-" .. GetRealmName()
	db.known[COB.charKey] = db.known[COB.charKey] or {}
end

local function SlashHandler(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()

	if cmd == "" or cmd == "show" then
		COB.SafeCall(COB.ToggleUI)
	elseif cmd == "status" then
		Print("v" .. GetAddOnMetadata(ADDON, "Version") .. " on " .. COB.RealmKey())
		if gAtr_ScanDB then
			Print("Auctionator prices known: " .. COB.CountScanDB())
		else
			Print("Auctionator price data not found. Is Auctionator enabled?")
		end
		if AUCTIONATOR_LAST_SCAN_TIME then
			Print("Last full scan: " .. date("%Y-%m-%d %H:%M", AUCTIONATOR_LAST_SCAN_TIME))
		end
		Print("Recipes: " .. #COB.recipes .. ", read from your profession windows: " .. COB.CountReagentCache())
	elseif cmd == "scale" and tonumber(rest) then
		COB.db.scale = math.max(0.5, math.min(2, tonumber(rest)))
		if COB.ApplyScale then COB.ApplyScale() end
		Print("window scale set to " .. COB.db.scale)
	elseif cmd == "config" or cmd == "settings" or cmd == "options" then
		COB.OpenSettings()
	elseif cmd == "log" then
		COB.ToggleLog()
	elseif cmd == "minimap" then
		COB.db.minimap = not COB.db.minimap
		COB.UpdateMinimapButton()
		Print("minimap button " .. (COB.db.minimap and "shown" or "hidden"))
	elseif cmd == "price" and rest ~= "" then
		Print(rest .. ": lowest " .. COB.FormatMoney(COB.GetLowest(rest)) .. ", median " .. COB.FormatMoney(COB.GetMedian(rest)))
	else
		Print("/cob - open the window")
		Print("/cob status - addon and Auctionator data status")
		Print("/cob price <item> - lowest and median AH price")
		Print("/cob scale <0.5-2> - make the window bigger or smaller, e.g. /cob scale 1.2")
		Print("/cob settings - open the settings panel")
		Print("/cob minimap - show or hide the minimap button")
		Print("/cob log - open the error log")
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		COB.SafeCall(InitDB)
		COB.SafeCall(BuildRecipes)
		if COB.OnLogin_History then COB.SafeCall(COB.OnLogin_History) end
		if COB.OnLogin_Settings then COB.SafeCall(COB.OnLogin_Settings) end
		SLASH_CRAFTORBUY1 = "/cob"
		SLASH_CRAFTORBUY2 = "/craftorbuy"
		SlashCmdList["CRAFTORBUY"] = SlashHandler
		Print("loaded. Type /cob to open.")
		if not COB.OpenSettings or not COB.UpdateLogWindow then
			COB.OpenSettings = COB.OpenSettings or function() end
			COB.UpdateMinimapButton = COB.UpdateMinimapButton or function() end
			Print("|cffff5050was updated with new files. Please exit WoW completely and start it again (/reload is not enough).|r")
		end
	end
end)
