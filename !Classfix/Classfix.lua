-- Classfix: unofficial Wrath adaptation.
-- Attribution: Class Colors by Phanx, copyright 2009-2018.
-- https://github.com/phanx-wow/ClassColors

local _, ns = ...
if CUSTOM_CLASS_COLORS then
	ns.alreadyLoaded = true
	print("Classfix: another custom class-color provider is active. Disable it and reload to use Classfix.")
	return
end

CUSTOM_CLASS_COLORS = {}

------------------------------------------------------------------------

local L = ns.L 
L.TITLE = GetAddOnMetadata("!Classfix", "Title")

------------------------------------------------------------------------

local CreateColor = ns.CreateColor
local meta = {}
local callbacks = {}
local numCallbacks = 0

function meta:RegisterCallback(method, handler)
	assert(type(method) == "string" or type(method) == "function", "Bad argument #1 to :RegisterCallback (string or function expected)")
	if type(method) == "string" then
		assert(type(handler) == "table", "Bad argument #2 to :RegisterCallback (table expected)")
		assert(type(handler[method]) == "function", "Bad argument #1 to :RegisterCallback (method \"" .. method .. "\" not found)")
		method = handler[method]
	end
	-- assert(not callbacks[method] "Callback already registered!")
	if not callbacks[method] then numCallbacks = numCallbacks + 1 end
	callbacks[method] = handler or true
end

function meta:UnregisterCallback(method, handler)
	assert(type(method) == "string" or type(method) == "function", "Bad argument #1 to :UnregisterCallback (string or function expected)")
	if type(method) == "string" then
		assert(type(handler) == "table", "Bad argument #2 to :UnregisterCallback (table expected)")
		assert(type(handler[method]) == "function", "Bad argument #1 to :UnregisterCallback (method \"" .. method .. "\" not found)")
		method = handler[method]
	end
	-- assert(callbacks[method], "Callback not registered!")
	if callbacks[method] then numCallbacks = numCallbacks - 1 end
	callbacks[method] = nil
end

local function DispatchCallbacks()
	if ns.Apply then ns.Apply() end
	if numCallbacks < 1 then return end
	--print("CUSTOM_CLASS_COLORS: DispatchCallbacks")
	for method, handler in pairs(callbacks) do
		local ok, err = pcall(method, handler ~= true and handler or nil)
		if not ok then
			print("ERROR:", err)
		end
	end
end

------------------------------------------------------------------------

local classes = {}
for class in pairs(RAID_CLASS_COLORS) do
	tinsert(classes, class)
end
sort(classes)

local classTokens = {}
for token, class in pairs(LOCALIZED_CLASS_NAMES_MALE) do
	classTokens[class] = token
end
for token, class in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
	classTokens[class] = token
end

function meta:GetClassToken(className)
	return className and classTokens[className]
end

------------------------------------------------------------------------

function meta:NotifyChanges()
	--print("CUSTOM_CLASS_COLORS: NotifyChanges")
	local changed

	for i = 1, #classes do
		local class = classes[i]
		local color = CUSTOM_CLASS_COLORS[class]
		local cache = ClassfixDB[class]

		color.colorStr = ns.Hex(color.r, color.g, color.b)
		if cache.r ~= color.r or cache.g ~= color.g or cache.b ~= color.b then
			--print("Change found in", class)
			cache.r = color.r
			cache.g = color.g
			cache.b = color.b
			cache.colorStr = ns.Hex(color.r, color.g, color.b)

			changed = true
		end
	end

	if changed then
		DispatchCallbacks()
	end
end

------------------------------------------------------------------------

setmetatable(CUSTOM_CLASS_COLORS, { __index = meta })

------------------------------------------------------------------------

local f = CreateFrame("Frame", "ClassfixOptions", InterfaceOptionsFramePanelContainer)
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
	if addon ~= "!Classfix" then return end
	--print("Classfix: ADDON_LOADED")

	--------------------------------------------------------------------

	local db
	local defaults = {}

	--------------------------------------------------------------------

	if not ClassfixDB then ClassfixDB = {} end
	db = ClassfixDB

	for i= 1, #classes do
		local class = classes[i]
		local color = RAID_CLASS_COLORS[class]
		local r, g, b = color.r, color.g, color.b
		local hex = ns.Hex(r, g, b)

		defaults[class] = {
			r = r,
			g = g,
			b = b,
			colorStr = hex,
		}

		if not db[class] or not db[class].r or not db[class].g or not db[class].b then
			db[class] = {
				r = r,
				g = g,
				b = b,
				colorStr = hex,
			}
		elseif not db[class].colorStr then
			db[class].colorStr = ns.Hex(db[class].r, db[class].g, db[class].b)
		end

		CUSTOM_CLASS_COLORS[class] = CreateColor(db[class].r, db[class].g, db[class].b)
		CUSTOM_CLASS_COLORS[class].colorStr = db[class].colorStr
	end

	--------------------------------------------------------------------

	if ns.Apply then ns.Apply() end

	local fire
	local shown
	local cache = {}
	local pickers = {}

	self.name = L.TITLE
	self:Hide()

	local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetPoint("TOPRIGHT", -16, -16)
	title:SetJustifyH("LEFT")
	title:SetText(L.TITLE)

	local notes = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	notes:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	notes:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -8)
	notes:SetHeight(28)
	notes:SetJustifyH("LEFT")
	notes:SetJustifyV("TOP")
	if notes.SetNonSpaceWrap then notes:SetNonSpaceWrap(true) end
	notes:SetText(L.NOTES)

	for i = 1, #classes do
		local class = classes[i]
		local color = db[class]

		cache[i] = {}

		pickers[i] = self:CreateColorPicker(L[class])
		pickers[i].class = class

		pickers[i].GetValue = function()
			return color.r, color.g, color.b
		end

		pickers[i].SetValue = function(self, r, g, b)
			self.label:SetTextColor(r, g, b)

			color.r = r
			color.g = g
			color.b = b
			color.colorStr = ns.Hex(r, g, b)

			CUSTOM_CLASS_COLORS[class].r = r
			CUSTOM_CLASS_COLORS[class].g = g
			CUSTOM_CLASS_COLORS[class].b = b
			CUSTOM_CLASS_COLORS[class].colorStr = color.colorStr

			if cache[i].r ~= r or cache[i].g ~= g or cache[i].b ~= b then
				DispatchCallbacks()
			end
		end

		pickers[i]:SetColor(color.r, color.g, color.b)
		pickers[i].label:SetTextColor(color.r, color.g, color.b)

		if i == 1 then
			pickers[i]:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 0, -12)
		elseif i == 2 then
			pickers[i]:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 200, -16)
		else
			pickers[i]:SetPoint("TOPLEFT", pickers[i-2], "BOTTOMLEFT", 0, -8)
		end
	end

	--------------------------------------------------------------------

	self:SetScript("OnShow", function(self)
		if shown then
			self.refresh()
		end

		--print("Classfix: OnShow")
		for i = 1, #pickers do
			local picker = pickers[i]
			local r, g, b = picker:GetValue()
			cache[i].r = r
			cache[i].g = g
			cache[i].b = b
		end

		shown = true
	end)

	self.refresh = function()
		--print("Classfix: refresh")
		for i = 1, #pickers do
			local picker = pickers[i]
			local r, g, b = picker:GetValue()
			picker.swatch:SetVertexColor(r, g, b)
			picker.label:SetTextColor(r, g, b)
		end
	end

	self.okay = function()
		if not shown then return end
		--print("Classfix: okay")
		for i = 1, #cache do
			wipe(cache[i])
		end

		shown = false
	end

	self.cancel = function()
		if not shown then return end
		--print("Classfix: cancel")
		local changed

		for i = 1, #pickers do
			local picker = pickers[i]
			local class = picker.class

			if db[class].r ~= cache[i].r or db[class].g ~= cache[i].g or db[class].b ~= cache[i].b then
				changed = true

				picker.swatch:SetVertexColor(cache[i].r, cache[i].g, cache[i].b)

				local r, g, b = cache[i].r, cache[i].g, cache[i].b
				local hex = ns.Hex(r, g, b)

				db[class].r = r
				db[class].g = g
				db[class].b = b
				db[class].colorStr = hex

				CUSTOM_CLASS_COLORS[class].r = r
				CUSTOM_CLASS_COLORS[class].g = g
				CUSTOM_CLASS_COLORS[class].b = b
				CUSTOM_CLASS_COLORS[class].colorStr = hex
			end

			wipe(cache[i])
		end

		if changed then
			DispatchCallbacks()
		end

		shown = false
	end

	ns.BlizzardDefaults = defaults
	ns.Pickers = pickers
	ns.Dispatch = DispatchCallbacks
	self.defaults = function()
		--print("Classfix: defaults")

		local changed

		for i = 1, #pickers do
			local picker = pickers[i]
			local class = picker.class
			local color = defaults[class]

			if db[class].r ~= color.r or db[class].g ~= color.g or db[class].b ~= color.b then
				changed = true

				local r, g, b = color.r, color.g, color.b
				local hex = ns.Hex(r, g, b)

				picker:SetColor(r, g, b)

				cache[i].r = r
				cache[i].g = g
				cache[i].b = b

				db[class].r = r
				db[class].g = g
				db[class].b = b
				db[class].colorStr = hex

				CUSTOM_CLASS_COLORS[class].r = r
				CUSTOM_CLASS_COLORS[class].g = g
				CUSTOM_CLASS_COLORS[class].b = b
				CUSTOM_CLASS_COLORS[class].colorStr = hex
			end
		end

		if changed then
			DispatchCallbacks()
		end
	end

	--------------------------------------------------------------------
--[[
	local reset = CreateFrame("Button", "$parentReset", self, "UIPanelButtonTemplate")
	reset:SetPoint("BOTTOMLEFT", self, 16, 16)
	reset:SetSize(96, 22)
	reset:SetText(L.RESET)
	reset:SetScript("OnClick", self.defaults)
	reset:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.RESET_DESC, nil, nil, nil, nil, true)
	end)
	reset:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
]]
	--------------------------------------------------------------------

	local help = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOP", pickers[#pickers], "BOTTOM", 0, -16)
	help:SetPoint("BOTTOMLEFT", 16, 54)
	help:SetPoint("BOTTOMRIGHT", -16, 54)
	help:SetHeight(84)
	help:SetJustifyH("LEFT")
	help:SetJustifyV("TOP")
	if help.SetNonSpaceWrap then help:SetNonSpaceWrap(true) end
	help:SetText(L.NOTES_DESC)

	--------------------------------------------------------------------

	InterfaceOptions_AddCategory(self)

	--------------------------------------------------------------------

	SLASH_CLASSFIXOPTIONS1 = "/cf"
	SlashCmdList.CLASSFIXOPTIONS = function()
		InterfaceOptionsFrame_OpenToCategory(self)
		InterfaceOptionsFrame_OpenToCategory(self)
	end

	--------------------------------------------------------------------

	if ns.InitializeDefaults then ns.InitializeDefaults() end
	self:UnregisterEvent("ADDON_LOADED")
	self:SetScript("OnEvent", nil)
end)

------------------------------------------------------------------------

do
	local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
	local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
	local ColorPickerFrame = ColorPickerFrame
	local GameTooltip = GameTooltip

	local function OnEnter(self)
		local color = NORMAL_FONT_COLOR
		self.bg:SetVertexColor(color.r, color.g, color.b)

		if self.hint then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.hint, nil, nil, nil, nil, true)
		end
	end

	local function OnLeave(self)
		local color = HIGHLIGHT_FONT_COLOR
		self.bg:SetVertexColor(color.r, color.g, color.b)

		GameTooltip:Hide()
	end

	local function OnClick(self)
		OnLeave(self)

		if ColorPickerFrame:IsShown() then
			ColorPickerFrame:Hide()
		else
			self.r, self.g, self.b = self:GetValue()

			UIDropDownMenuButton_OpenColorPicker(self)
			ColorPickerFrame:SetFrameStrata("TOOLTIP")
			ColorPickerFrame:Raise()
		end
	end

	local function SetColor(self, r, g, b)
		self.swatch:SetVertexColor(r, g, b)
		if not ColorPickerFrame:IsShown() then
			self:SetValue(r, g, b)
		end
	end

	function f:CreateColorPicker(name)
		local frame = CreateFrame("Button", nil, self)
		frame:SetSize(26, 26)

		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
		bg:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		bg:SetPoint("LEFT", 5, 1)
		bg:SetSize(16, 16)
		frame.bg = bg

		local bgi = frame:CreateTexture(nil, "BORDER")
		bgi:SetTexture("Interface\\BUTTONS\\WHITE8X8")
		bgi:SetVertexColor(0, 0, 0)
		bgi:SetPoint("BOTTOMLEFT", bg, 1, 1)
		bgi:SetPoint("TOPRIGHT", bg, -1, -1)
		frame.bgInner = bgi

		local swatch = frame:CreateTexture(nil, "OVERLAY")
		swatch:SetTexture("Interface\\BUTTONS\\WHITE8X8")
		swatch:SetPoint("BOTTOMLEFT", bgi, 1, 1)
		swatch:SetPoint("TOPRIGHT", bgi, -1, -1)
		frame.swatch = swatch

		local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		label:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
		frame.label = label

		frame.SetColor = SetColor
		frame.swatchFunc = function() frame:SetColor(ColorPickerFrame:GetColorRGB()) end
		frame.cancelFunc = function() frame:SetColor(frame.r, frame.g, frame.b) end

		frame:SetScript("OnClick", OnClick)
		frame:SetScript("OnEnter", OnEnter)
		frame:SetScript("OnLeave", OnLeave)

		label:SetText(name)
		frame:SetHitRectInsets(0,  -1 * max(100, label:GetStringWidth() + 4), 0, 0)

		return frame
	end
end

------------------------------------------------------------------------
