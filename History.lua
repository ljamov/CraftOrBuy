-- Price history. One snapshot per day per item after each Auctionator full scan;
-- days older than KEEP_DAYS are folded into monthly low / average / high.

local COB = CraftOrBuy
local KEEP_DAYS = 62

local function DayKey(t) return date("%Y-%m-%d", t) end

-- Every item name CraftOrBuy cares about: crafted results and their reagents.
local function TrackedNames()
	local names = {}
	for _, rec in ipairs(COB.recipes) do
		names[COB.OutputName(rec)] = true
		local info = COB.db.reagents[rec.spell]
		if info then
			for _, r in ipairs(info.reagents) do names[r[1]] = true end
		end
	end
	return names
end

local function Rollup()
	local daily, monthly = COB.realm.daily, COB.realm.monthly
	local cutoff = DayKey(time() - KEEP_DAYS * 86400)
	for name, days in pairs(daily) do
		for day, price in pairs(days) do
			if day < cutoff then
				local m = day:sub(1, 7)
				monthly[name] = monthly[name] or {}
				local e = monthly[name][m]
				if not e then
					monthly[name][m] = { lo = price, hi = price, sum = price, n = 1 }
				else
					e.lo = math.min(e.lo, price)
					e.hi = math.max(e.hi, price)
					e.sum = e.sum + price
					e.n = e.n + 1
				end
				days[day] = nil
			end
		end
		if next(days) == nil then daily[name] = nil end
	end
end

function COB.RecordSnapshot(when)
	if not gAtr_ScanDB or not COB.realm then return 0 end
	local day = DayKey(when or time())
	local daily = COB.realm.daily
	local n = 0
	for name in pairs(TrackedNames()) do
		local price = gAtr_ScanDB[name]
		if price and price > 0 then
			daily[name] = daily[name] or {}
			daily[name][day] = price
			n = n + 1
		end
	end
	COB.realm.lastRecorded = day
	Rollup()
	return n
end

-- Returns a list of { label, lo, avg, hi } oldest first. mode: "day", "month", "year".
function COB.GetHistory(name, mode)
	local daily = COB.realm.daily[name] or {}
	local monthly = COB.realm.monthly[name] or {}
	local out = {}
	if mode == "day" then
		local keys = {}
		for d in pairs(daily) do table.insert(keys, d) end
		table.sort(keys)
		for i = math.max(1, #keys - 29), #keys do
			local p = daily[keys[i]]
			table.insert(out, { label = keys[i], lo = p, avg = p, hi = p })
		end
		return out
	end

	local months = {}
	for m, e in pairs(monthly) do
		months[m] = { lo = e.lo, hi = e.hi, sum = e.sum, n = e.n }
	end
	for d, p in pairs(daily) do
		local m = d:sub(1, 7)
		local e = months[m]
		if not e then
			months[m] = { lo = p, hi = p, sum = p, n = 1 }
		else
			e.lo = math.min(e.lo, p); e.hi = math.max(e.hi, p); e.sum = e.sum + p; e.n = e.n + 1
		end
	end

	local buckets = months
	if mode == "year" then
		buckets = {}
		for m, e in pairs(months) do
			local y = m:sub(1, 4)
			local b = buckets[y]
			if not b then
				buckets[y] = { lo = e.lo, hi = e.hi, sum = e.sum, n = e.n }
			else
				b.lo = math.min(b.lo, e.lo); b.hi = math.max(b.hi, e.hi); b.sum = b.sum + e.sum; b.n = b.n + e.n
			end
		end
	end

	local keys = {}
	for k in pairs(buckets) do table.insert(keys, k) end
	table.sort(keys)
	for i = math.max(1, #keys - 29), #keys do
		local e = buckets[keys[i]]
		table.insert(out, { label = keys[i], lo = e.lo, avg = math.floor(e.sum / e.n), hi = e.hi })
	end
	return out
end

local hooked = false
local function HookAuctionator()
	if hooked or not Atr_FullScanAnalyze then return end
	hooksecurefunc("Atr_FullScanAnalyze", function()
		local n = COB.RecordSnapshot()
		COB.Print("saved today's prices for " .. n .. " items to history.")
		if COB.RefreshUI then COB.RefreshUI() end
	end)
	hooked = true
end

function COB.OnLogin_History()
	HookAuctionator()
	Rollup()
	-- If Auctionator scanned on a day we have not recorded yet, keep that scan too.
	if AUCTIONATOR_LAST_SCAN_TIME and COB.realm.lastRecorded ~= DayKey(AUCTIONATOR_LAST_SCAN_TIME) then
		COB.RecordSnapshot(AUCTIONATOR_LAST_SCAN_TIME)
	end
end
