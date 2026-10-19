-- Settings window (Settings button, right-click on the minimap icon, or /cob settings)
-- and the minimap button. A small page under Esc > Interface > AddOns opens the window too.

local COB = CraftOrBuy

local panel -- the settings window, created on first open
local controls = {}

local function Refresh()
	if COB.RefreshUI then COB.RefreshUI() end
end

local function Checkbox(key, label, tip, y, onChange)
	local name = "CraftOrBuySetting_" .. key
	local cb = CreateFrame("CheckButton", name, panel, "UICheckButtonTemplate")
	cb:SetWidth(26); cb:SetHeight(26)
	cb:SetPoint("TOPLEFT", 20, y)
	local text = _G[name .. "Text"]
	text:SetFontObject(GameFontHighlight)
	text:SetText(label)
	if tip then
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label)
			GameTooltip:AddLine(tip, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	cb:SetScript("OnClick", function(self)
		COB.db[key] = self:GetChecked() and true or false
		if onChange then onChange() end
		Refresh()
	end)
	cb.load = function() cb:SetChecked(COB.db[key] and true or false) end
	table.insert(controls, cb)
	return cb
end

local function Slider(key, label, minV, maxV, step, fmt, y, onChange)
	local name = "CraftOrBuySetting_" .. key
	local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", 30, y)
	s:SetWidth(300); s:SetHeight(17)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	_G[name .. "Low"]:SetText(string.format(fmt, minV))
	_G[name .. "High"]:SetText(string.format(fmt, maxV))
	local text = _G[name .. "Text"]
	text:SetFontObject(GameFontNormal)
	s.load = function()
		s.loading = true
		s:SetValue(COB.db[key])
		text:SetText(label .. ": " .. string.format(fmt, COB.db[key]))
		s.loading = false
	end
	s:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value / step + 0.5) * step
		text:SetText(label .. ": " .. string.format(fmt, value))
		if self.loading then return end
		COB.db[key] = value
		if onChange then COB.SafeCall(onChange) end
	end)
	table.insert(controls, s)
	return s
end

local function Heading(text, y)
	local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 20, y)
	fs:SetText(text)
end

local function CreateSettingsWindow()
	panel = CreateFrame("Frame", "CraftOrBuySettingsFrame", UIParent)
	panel:SetWidth(470); panel:SetHeight(450)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("DIALOG")
	panel:SetToplevel(true)
	panel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	tinsert(UISpecialFrames, "CraftOrBuySettingsFrame")

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 20, -18)
	title:SetText("CraftOrBuy - Settings")
	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	Heading("Window", -52)
	Slider("scale", "Window size", 0.6, 1.6, 0.05, "%.2f", -84, function() COB.ApplyScale() end)
	Slider("fontSize", "Font size", 10, 16, 1, "%d", -134, function() COB.ApplyFontSize(); Refresh() end)

	Heading("Prices", -176)
	local median = Checkbox("useMedian", "Compare with the median AH price",
		"Median is the typical price over Auctionator's recent full scans and ignores one-off cheap listings. Off = lowest buyout at the last scan.", -196,
		function() COB.db.priceMode = COB.db.useMedian and "median" or "lowest" end)
	median.load = function() median:SetChecked(COB.db.priceMode == "median") end
	Checkbox("craftIntermediates", "Price mats not on the AH by their crafting cost",
		"For example Cured Rugged Hide or Jadefire Ink.", -224)

	Heading("Other", -264)
	Checkbox("tooltip", "Show craft and AH prices in item tooltips", nil, -284)
	Checkbox("minimap", "Show the minimap button", nil, -312, function() COB.UpdateMinimapButton() end)

	Heading("About", -350)
	local about = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	about:SetPoint("TOPLEFT", 24, -370)
	about:SetText("Creator: Kristijan Ljamov    Website: |cff66bbffljamov.com|r    Version " .. (GetAddOnMetadata("CraftOrBuy", "Version") or "?"))

	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetWidth(200); reset:SetHeight(24)
	reset:SetPoint("BOTTOMLEFT", 20, 20)
	reset:SetText("Reset size and font")
	reset:SetScript("OnClick", function()
		COB.db.scale, COB.db.fontSize = 1, 12
		COB.ApplyScale(); COB.ApplyFontSize(); Refresh()
		panel.refresh()
	end)
	local done = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	done:SetWidth(120); done:SetHeight(24)
	done:SetPoint("BOTTOMRIGHT", -20, 20)
	done:SetText("Close")
	done:SetScript("OnClick", function() panel:Hide() end)

	panel.refresh = function()
		for _, c in ipairs(controls) do c.load() end
	end
	panel:SetScript("OnShow", function() COB.SafeCall(panel.refresh) end)
	panel:Hide()
end

function COB.OpenSettings()
	COB.SafeCall(function()
		if not panel then CreateSettingsWindow() end
		if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
		if panel:IsShown() then panel:Hide() else panel:Show() end
	end)
end

-- Page under Esc > Interface > AddOns that points to the settings window.
local function CreateOptionsPage()
	local page = CreateFrame("Frame", "CraftOrBuyOptionsPage", UIParent)
	page.name = "CraftOrBuy"
	local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("CraftOrBuy")
	local by = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	by:SetPoint("TOPLEFT", 16, -90)
	by:SetText("Creator: Kristijan Ljamov  -  ljamov.com")
	local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	b:SetWidth(180); b:SetHeight(24)
	b:SetPoint("TOPLEFT", 16, -50)
	b:SetText("Open settings")
	b:SetScript("OnClick", function()
		InterfaceOptionsFrame:Hide()
		HideUIPanel(GameMenuFrame)
		COB.OpenSettings()
	end)
	local b2 = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	b2:SetWidth(180); b2:SetHeight(24)
	b2:SetPoint("LEFT", b, "RIGHT", 10, 0)
	b2:SetText("Open CraftOrBuy")
	b2:SetScript("OnClick", function()
		InterfaceOptionsFrame:Hide()
		HideUIPanel(GameMenuFrame)
		COB.ToggleUI()
	end)
	InterfaceOptions_AddCategory(page)
end

---------------------------------------------------------------------------
-- Minimap button: left-click opens the window, right-click opens settings, drag to move.
---------------------------------------------------------------------------

local button = CreateFrame("Button", "CraftOrBuyMinimapButton", Minimap)
button:SetWidth(31); button:SetHeight(31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetWidth(53); overlay:SetHeight(53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")
local background = button:CreateTexture(nil, "BACKGROUND")
background:SetWidth(20); background:SetHeight(20)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", 7, -5)
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetWidth(20); icon:SetHeight(20)
icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
icon:SetPoint("TOPLEFT", 7, -5)
button:Hide()

local function PlaceButton()
	local angle = math.rad(COB.db.minimapAngle or 200)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cx, cy = cx / scale, cy / scale
	COB.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
	PlaceButton()
end

button:SetScript("OnDragStart", function(self)
	self:LockHighlight()
	self:SetScript("OnUpdate", OnDragUpdate)
end)
button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
end)
button:SetScript("OnClick", function(self, mouse)
	if mouse == "RightButton" then COB.OpenSettings() else COB.SafeCall(COB.ToggleUI) end
end)
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("CraftOrBuy")
	GameTooltip:AddLine("Left-click: open the window", 1, 1, 1)
	GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
	GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function COB.UpdateMinimapButton()
	if COB.db.minimap then
		PlaceButton()
		button:Show()
	else
		button:Hide()
	end
end

function COB.OnLogin_Settings()
	COB.db.useMedian = COB.db.priceMode == "median"
	COB.SafeCall(CreateOptionsPage)
	COB.UpdateMinimapButton()
end
