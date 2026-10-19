-- Error log: collects Lua errors (from CraftOrBuy and other addons) into a window
-- where they can be copied, and cleared after an update. Loaded first so it also
-- catches errors while the other files load.

CraftOrBuy = CraftOrBuy or {}
local COB = CraftOrBuy

local MAX_ENTRIES = 100
local pending = {}  -- errors raised before saved variables are loaded

local function Entries()
	if CraftOrBuyDB and CraftOrBuyDB.log then return CraftOrBuyDB.log end
	return pending
end

function COB.LogError(msg, stack)
	msg = tostring(msg or "unknown error")
	local list = Entries()
	-- Same error again: just count it, so a repeating error does not flood the log.
	for _, e in ipairs(list) do
		if e.msg == msg then
			e.count = (e.count or 1) + 1
			e.last = date("%Y-%m-%d %H:%M:%S")
			if COB.UpdateLogWindow then COB.UpdateLogWindow() end
			return
		end
	end
	table.insert(list, {
		msg = msg,
		stack = stack or (debugstack and debugstack(3, 12, 0)) or "",
		count = 1,
		first = date("%Y-%m-%d %H:%M:%S"),
		last = date("%Y-%m-%d %H:%M:%S"),
		version = GetAddOnMetadata("CraftOrBuy", "Version"),
	})
	while #list > MAX_ENTRIES do table.remove(list, 1) end
	if COB.UpdateLogWindow then COB.UpdateLogWindow() end
end

-- Runs fn and logs any error instead of letting it break the caller.
function COB.SafeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		COB.LogError(err, debugstack and debugstack(2, 12, 0))
		if COB.Print then COB.Print("|cffff5050an error happened. Open the Log button in the window to see it.|r") end
	end
	return ok, err
end

-- Wrap the game's error handler so every Lua error lands in the log too.
local previous = geterrorhandler()
seterrorhandler(function(msg, ...)
	pcall(COB.LogError, msg)
	if previous then return previous(msg, ...) end
end)

function COB.ClearLog()
	if CraftOrBuyDB then CraftOrBuyDB.log = {} end
	pending = {}
	if COB.UpdateLogWindow then COB.UpdateLogWindow() end
end

function COB.LogCount()
	return #Entries()
end

local function LogText()
	local list = Entries()
	if #list == 0 then return "No errors logged." end
	local out = {}
	for i = #list, 1, -1 do
		local e = list[i]
		table.insert(out, string.format("[%s] CraftOrBuy %s  (x%d, last %s)\n%s\n%s",
			e.first or "?", e.version or "?", e.count or 1, e.last or "?", e.msg, e.stack or ""))
	end
	return table.concat(out, "\n----------------------------------------\n")
end

---------------------------------------------------------------------------
-- Log window
---------------------------------------------------------------------------

local win

local function CreateLogWindow()
	win = CreateFrame("Frame", "CraftOrBuyLogFrame", UIParent)
	win:SetWidth(640); win:SetHeight(420)
	win:SetPoint("CENTER", 40, -20)
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	win:EnableMouse(true)
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	tinsert(UISpecialFrames, "CraftOrBuyLogFrame")

	local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 20, -18)
	title:SetText("CraftOrBuy - Error log")
	win.count = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	win.count:SetPoint("LEFT", title, "RIGHT", 12, 0)

	local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	hint:SetPoint("TOPLEFT", 20, -42)
	hint:SetText("Click Select all, then Ctrl+C to copy. Paste it to whoever helps you fix it.")

	local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	local scroll = CreateFrame("ScrollFrame", "CraftOrBuyLogScroll", win, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, -64)
	scroll:SetPoint("BOTTOMRIGHT", -40, 52)
	local bg = CreateFrame("Frame", nil, win)
	bg:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 6)
	bg:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 26, -6)
	bg:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	bg:SetBackdropColor(0, 0, 0, 0.8)
	bg:SetFrameLevel(math.max(0, scroll:GetFrameLevel() - 1))

	local edit = CreateFrame("EditBox", "CraftOrBuyLogEdit", scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(560)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	-- Read-only: typing puts the log text back.
	edit:SetScript("OnTextChanged", function(self, user)
		if user then self:SetText(win.text or "") end
	end)
	scroll:SetScrollChild(edit)
	win.edit = edit

	local function Button(label, x, onClick)
		local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
		b:SetWidth(120); b:SetHeight(24)
		b:SetPoint("BOTTOMLEFT", x, 18)
		b:SetText(label)
		b:SetScript("OnClick", onClick)
		return b
	end
	Button("Select all", 20, function()
		edit:SetFocus()
		edit:HighlightText()
	end)
	Button("Clear log", 146, function() COB.ClearLog() end)
	Button("Close", 272, function() win:Hide() end)

	win:SetScript("OnShow", function() COB.UpdateLogWindow() end)
	win:Hide()
end

function COB.UpdateLogWindow()
	if not win or not win:IsShown() then
		if COB.UpdateLogButton then COB.UpdateLogButton() end
		return
	end
	win.text = LogText()
	win.edit:SetText(win.text)
	win.edit:SetCursorPosition(0)
	local n = COB.LogCount()
	win.count:SetText(n == 0 and "|cff40ff40no errors|r" or ("|cffff5050" .. n .. " error(s)|r"))
	if COB.UpdateLogButton then COB.UpdateLogButton() end
end

function COB.ToggleLog()
	if not win then CreateLogWindow() end
	if win:IsShown() then win:Hide() else win:Show() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
	if name ~= "CraftOrBuy" then return end
	if type(CraftOrBuyDB) ~= "table" then CraftOrBuyDB = {} end
	CraftOrBuyDB.log = CraftOrBuyDB.log or {}
	for _, e in ipairs(pending) do table.insert(CraftOrBuyDB.log, e) end
	pending = {}
	self:UnregisterEvent("ADDON_LOADED")
end)
