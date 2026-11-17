-- EverlookUI: the settings window look shared by quikmn's addons (the Lattice style).
--
-- Single source of truth: D:\Dev\EverlookUI\EverlookUI.lua. Each addon carries a copy in
-- Libs\EverlookUI\ (sync.py writes it; release-addon.py and install-addons.ps1 keep it current).
-- Versioned with LibStub: when several addons carry it, the newest copy is the one every addon uses.
-- Bump MINOR whenever this file changes.
--
--   local UI = LibStub("EverlookUI-1")
--   local app = UI:NewApp({ name = "Whack", addon = ADDON, slash = "/whack", tagline = "...", accent = {r, g, b} })
--   app:Setting({ key = "fontsize", type = "number", label = "Font size", min = 8, max = 48, get = ..., set = ... })
--   app:Command("test", "test", "show fake numbers", function(rest) ... end)
--   app:Section("general", "General", function(stack, app) app:Widget(stack, "fontsize") end)
--   SlashCmdList.WHACK = function(msg) app:HandleSlash(msg) end
--
-- Widgets: Header, Note, Toggle, Slider, Dropdown, Color, Input, CopyBox, Stat, List, Button, ConfirmButton,
-- ButtonRow, TextArea, ScrollPage. Bound widgets take { label, desc, get, set, disabled, after } and have :Refresh().
-- The mouse wheel scrolls the page: sliders and dropdowns never take it. The page scroll bar is 12 px and draggable.
local MAJOR, MINOR = "EverlookUI-1", 2
local UI = LibStub:NewLibrary(MAJOR, MINOR)
if not UI then return end
UI.version = MINOR

------------------------------------------------------------------------
-- Theme
------------------------------------------------------------------------
UI.Theme = {
	bg        = { 0.071, 0.078, 0.094, 0.97 }, -- window
	sidebar   = { 0.055, 0.060, 0.074, 1 },
	surface   = { 0.105, 0.114, 0.137, 1 },   -- cards / inputs
	surfaceHi = { 0.137, 0.149, 0.180, 1 },   -- hover
	border    = { 0.180, 0.196, 0.235, 1 },
	text      = { 0.902, 0.910, 0.933, 1 },
	muted     = { 0.553, 0.580, 0.639, 1 },
	accent    = { 0.353, 0.663, 1.000, 1 },   -- #5aa9ff (Lattice blue)
	accentDim = { 0.353, 0.663, 1.000, 0.18 },
	danger    = { 0.937, 0.365, 0.365, 1 },
	ok        = { 0.384, 0.812, 0.533, 1 },
	onAccent  = { 0.05, 0.07, 0.1, 1 },        -- text and knobs drawn on the accent colour

	fontSmall = 10,
	font      = 12,
	fontTitle = 14,
	fontHuge  = 18,

	pad = 16,
	rowGap = 10,
}

-- A theme with another accent colour ({ r, g, b }); everything else from UI.Theme.
function UI.MakeTheme(accent)
	local T = {}
	for k, v in pairs(UI.Theme) do T[k] = v end
	if type(accent) == "table" and accent[1] then
		T.accent = { accent[1], accent[2], accent[3], 1 }
		T.accentDim = { accent[1], accent[2], accent[3], 0.18 }
	end
	return T
end

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
local function hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end

------------------------------------------------------------------------
-- Util
------------------------------------------------------------------------
local U = {}
UI.Util = U
U.WHITE = "Interface\\Buttons\\WHITE8X8"
U.rgba, U.Hex = rgba, hex

function U.CopyTable(src)
	if type(src) ~= "table" then return src end
	local t = {}
	for k, v in pairs(src) do t[k] = U.CopyTable(v) end
	return t
end

-- Fill missing keys in `dst` from `defaults`, recursively. Never overwrites.
-- Arrays (tables with [1]) are values: copied only when missing.
function U.FillDefaults(dst, defaults)
	for k, v in pairs(defaults) do
		if dst[k] == nil then
			dst[k] = U.CopyTable(v)
		elseif type(v) == "table" and type(dst[k]) == "table" and v[1] == nil then
			U.FillDefaults(dst[k], v)
		end
	end
	return dst
end

function U.Get(t, path)
	for key in string.gmatch(path, "[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[tonumber(key) or key]
	end
	return t
end

function U.Set(t, path, value)
	local keys = {}
	for key in string.gmatch(path, "[^%.]+") do keys[#keys + 1] = tonumber(key) or key end
	for i = 1, #keys - 1 do
		local k = keys[i]
		if type(t[k]) ~= "table" then t[k] = {} end
		t = t[k]
	end
	t[keys[#keys]] = value
end

-- Text shown literally in chat or a font string: a lone "|" starts an escape code.
function U.Escape(s) return (tostring(s):gsub("|", "||")) end

function U.Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function U.Font() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end

function U.SetFont(fs, size, flags)
	local ok = fs:SetFont(U.Font(), size or 11, flags or "")
	if not ok then fs:SetFontObject(GameFontHighlightSmall) end
end

function U.Solid(parent, layer, r, g, b, a, sublevel)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
	t:SetTexture(U.WHITE)
	t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	return t
end

-- 1 px border from 4 textures (no backdrop templates).
function U.Border(parent, size, r, g, b, a, layer)
	size = size or 1
	local border = {}
	local function edge()
		local t = parent:CreateTexture(nil, layer or "BORDER", nil, 7)
		t:SetTexture(U.WHITE)
		t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		return t
	end
	border.top = edge()
	border.top:SetPoint("TOPLEFT")
	border.top:SetPoint("TOPRIGHT")
	border.top:SetHeight(size)
	border.bottom = edge()
	border.bottom:SetPoint("BOTTOMLEFT")
	border.bottom:SetPoint("BOTTOMRIGHT")
	border.bottom:SetHeight(size)
	border.left = edge()
	border.left:SetPoint("TOPLEFT")
	border.left:SetPoint("BOTTOMLEFT")
	border.left:SetWidth(size)
	border.right = edge()
	border.right:SetPoint("TOPRIGHT")
	border.right:SetPoint("BOTTOMRIGHT")
	border.right:SetWidth(size)
	function border:SetColor(r2, g2, b2, a2)
		for _, key in ipairs({ "top", "bottom", "left", "right" }) do self[key]:SetVertexColor(r2, g2, b2, a2 or 1) end
	end
	function border:SetShown(shown)
		for _, key in ipairs({ "top", "bottom", "left", "right" }) do self[key]:SetShown(shown) end
	end
	return border
end

-- The theme a widget should use: the stack's, or the nearest parent window's.
local function ThemeOf(x)
	if type(x) == "table" then
		if rawget(x, "isStack") then return x.T end
		local f = x
		for _ = 1, 25 do
			if type(f) ~= "table" then break end
			local t = rawget(f, "eluiTheme")
			if t then return t end
			f = f.GetParent and f:GetParent()
		end
	end
	return UI.Theme
end
UI.ThemeOf = ThemeOf

------------------------------------------------------------------------
-- Basic pieces
------------------------------------------------------------------------
local function Text(parent, size, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	U.SetFont(fs, size or UI.Theme.font)
	fs:SetTextColor(rgba(color or UI.Theme.text))
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	return fs
end
UI.Text = Text

local function Tooltip(frame, title, body)
	if not body and not title then return end
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if title then GameTooltip:AddLine(title, 1, 1, 1) end
		if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
UI.Tooltip = Tooltip

-- Escape closes `frame` through its own key handler. Not UISpecialFrames: Blizzard walks that list when
-- Escape closes its own windows, and an entry written by an addon taints the walk (secret-value errors
-- in Blizzard's OnHide). Other keys pass through to the game. SetPropagateKeyboardInput is blocked in
-- combat, so a window opened in combat leaves the keyboard alone and Escape then also reaches the game.
-- Call after the frame's own OnShow script is set (this hooks it).
function UI.CloseOnEscape(frame)
	frame:HookScript("OnShow", function(self)
		local ok = not InCombatLockdown()
		if ok then self:SetPropagateKeyboardInput(true) end
		self:EnableKeyboard(ok)
	end)
	frame:SetScript("OnKeyDown", function(self, key)
		local esc = key == "ESCAPE"
		if not InCombatLockdown() then self:SetPropagateKeyboardInput(not esc) end
		if not esc then return end
		-- an open dropdown list closes first; the next Escape closes the window
		if UI.IsPopupShown and UI.IsPopupShown() then UI.ClosePopup() return end
		self:Hide()
	end)
end

------------------------------------------------------------------------
-- Stack: the vertical layout of a page. Rows can change height later (lists, notes) and the
-- rows under them move with :Relayout().
------------------------------------------------------------------------
local Stack = {}
Stack.__index = Stack

function UI.Stack(parent, width, T)
	return setmetatable({ parent = parent, width = width, y = 0, widgets = {}, entries = {}, T = T or ThemeOf(parent), isStack = true }, Stack)
end

function Stack:Place(e)
	local f = e.frame
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", self.parent, "TOPLEFT", e.indent, -self.y)
	f:SetWidth(self.width - e.indent)
	f:SetHeight(e.height)
	self.y = self.y + e.height + e.gap
end

function Stack:Add(frame, height, gap, indent)
	frame:SetParent(self.parent)
	local e = { frame = frame, height = height, gap = gap or self.T.rowGap, indent = indent or 0 }
	self.entries[#self.entries + 1] = e
	frame.stackEntry = e
	self:Place(e)
	if frame.Refresh then self.widgets[#self.widgets + 1] = frame end
	self.parent:SetHeight(self.y + self.T.pad)
	return frame
end

function Stack:Space(px)
	px = px or self.T.pad
	self.entries[#self.entries + 1] = { space = px }
	self.y = self.y + px
	self.parent:SetHeight(self.y + self.T.pad)
end

function Stack:Relayout()
	self.y = 0
	for _, e in ipairs(self.entries) do
		if e.space then self.y = self.y + e.space else self:Place(e) end
	end
	self.parent:SetHeight(self.y + self.T.pad)
end

-- Give a row a new height and move the rows below it.
function Stack:SetHeightOf(frame, h)
	local e = frame.stackEntry
	if not e or e.height == h then return end
	e.height = h
	self:Relayout()
end

function Stack:RefreshAll()
	for _, w in ipairs(self.widgets) do w:Refresh() end
end

------------------------------------------------------------------------
-- Static text
------------------------------------------------------------------------
function UI.Header(stack, text, sub)
	local T = stack.T
	local f = CreateFrame("Frame")
	local title = Text(f, T.fontTitle, T.text)
	title:SetPoint("TOPLEFT")
	title:SetText(text)
	local line = U.Solid(f, "ARTWORK", rgba(T.border))
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	local h = 26
	if sub then
		local s = Text(f, T.fontSmall + 1, T.muted)
		s:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		s:SetWidth(stack.width)
		s:SetText(sub)
		h = 34 + math.max(10, s:GetStringHeight())
	end
	stack:Space(stack.y > 0 and 8 or 0)
	return stack:Add(f, h, 12)
end

-- A paragraph. `text` may be a function (the note then updates on Refresh).
function UI.Note(stack, text, color)
	local T = stack.T
	local f = CreateFrame("Frame")
	local fs = Text(f, T.fontSmall + 1, color or T.muted)
	fs:SetPoint("TOPLEFT")
	fs:SetWidth(stack.width)
	f.text = fs
	local function fill()
		fs:SetText(type(text) == "function" and (text() or "") or text)
		return math.max(14, fs:GetStringHeight() + 2)
	end
	local h = fill()
	if type(text) == "function" then
		function f:Refresh() stack:SetHeightOf(f, fill()) end
	end
	return stack:Add(f, h)
end

-- "Label      value" line; value is a function, read again on Refresh.
function UI.Stat(stack, label, value, labelWidth)
	local T = stack.T
	local f = CreateFrame("Frame")
	local l = Text(f, T.font, T.muted)
	l:SetPoint("LEFT")
	l:SetWidth(labelWidth or 190)
	l:SetWordWrap(false)
	l:SetText(label)
	local v = Text(f, T.font, T.text)
	v:SetPoint("LEFT", labelWidth or 190, 0)
	v:SetPoint("RIGHT")
	v:SetWordWrap(false)
	f.value = v
	function f:Refresh() v:SetText(tostring(value() or "")) end
	stack:Add(f, 16, 6)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
-- style: nil, "accent" or "danger".
function UI.Button(parent, label, onClick, width, style)
	local T = ThemeOf(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 26)
	local accent, danger = style == "accent", style == "danger"
	b.bg = U.Solid(b, "BACKGROUND", rgba(accent and T.accent or T.surface))
	b.bg:SetAllPoints()
	if accent then b.bg:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.85) end
	b.border = U.Border(b, 1, rgba(danger and T.danger or T.border))
	b.label = Text(b, T.font, accent and T.onAccent or (danger and T.danger or T.text))
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b.label:SetText(label)
	b:SetScript("OnEnter", function(self)
		if accent then self.bg:SetVertexColor(rgba(T.accent)) else self.bg:SetVertexColor(rgba(T.surfaceHi)) end
	end)
	b:SetScript("OnLeave", function(self)
		if accent then self.bg:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.85) else self.bg:SetVertexColor(rgba(T.surface)) end
	end)
	b:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
	function b:SetText(t) self.label:SetText(t) end
	function b:GetText() return self.label:GetText() end
	-- Greyed out and not clickable while `on` is false.
	function b:SetUsable(on)
		self:SetAlpha(on and 1 or 0.4)
		self:EnableMouse(on and true or false)
	end
	return b
end

-- For something that can't be undone: the first click asks, a second click within 4 seconds does it.
-- A narrow button (a list row's) asks "Click again", which fits where "Click again to confirm" would not.
function UI.ConfirmButton(parent, label, onConfirm, width, style)
	local b
	local armed, before = nil, nil -- armed: a token for the 4-second timer; before: the label to put back
	local ask = (width or 120) < 150 and "Click again" or "Click again to confirm"
	local function disarm()
		if armed then armed = nil; b:SetText(before or label) end
	end
	b = UI.Button(parent, label, function(self, ...)
		if not armed then
			before = self:GetText()
			local token = {}
			armed = token
			self:SetText(ask)
			C_Timer.After(4, function() if armed == token then disarm() end end)
			return
		end
		disarm()
		onConfirm(self, ...)
	end, width, style or "danger")
	b:HookScript("OnHide", disarm)
	return b
end

-- A row of buttons: { { label, onClick, width, style, confirm }, ... }. Returns the row (row.buttons[i]).
function UI.ButtonRow(stack, buttons)
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent) -- so the buttons find the window theme
	f.buttons = {}
	local x = 0
	for i, d in ipairs(buttons) do
		local make = d.confirm and UI.ConfirmButton or UI.Button
		local b = make(f, d.label, d.onClick, d.width or 140, d.style)
		b:SetPoint("LEFT", x, 0)
		x = x + (d.width or 140) + 8
		f.buttons[i] = b
		if d.desc then Tooltip(b, d.label, d.desc) end
	end
	if buttons.refresh then
		function f:Refresh() buttons.refresh(f) end
	end
	stack:Add(f, 26, 12)
	if f.Refresh then f:Refresh() end
	return f
end

------------------------------------------------------------------------
-- Switch (the toggle's track and knob, also used in list rows)
------------------------------------------------------------------------
local function Switch(parent, T)
	local track = CreateFrame("Frame", nil, parent)
	track:SetSize(34, 18)
	track.bg = U.Solid(track, "BACKGROUND", rgba(T.surface))
	track.bg:SetAllPoints()
	track.border = U.Border(track, 1, rgba(T.border))
	local knob = U.Solid(track, "ARTWORK", rgba(T.muted))
	knob:SetSize(12, 12)
	function track:SetOn(on)
		knob:ClearAllPoints()
		if on then
			knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
			knob:SetVertexColor(rgba(T.onAccent))
			track.bg:SetVertexColor(rgba(T.accent))
			track.border:SetColor(rgba(T.accent))
		else
			knob:SetPoint("LEFT", track, "LEFT", 3, 0)
			knob:SetVertexColor(rgba(T.muted))
			track.bg:SetVertexColor(rgba(T.surface))
			track.border:SetColor(rgba(T.border))
		end
	end
	return track
end

------------------------------------------------------------------------
-- Toggle
------------------------------------------------------------------------
function UI.Toggle(stack, opt)
	local T = stack.T
	local f = CreateFrame("Button")
	local track = Switch(f, T)
	track:SetPoint("LEFT")
	local label = Text(f, T.font, T.text)
	label:SetPoint("LEFT", track, "RIGHT", 10, 0)
	label:SetPoint("RIGHT")
	label:SetText(opt.label)
	function f:Refresh()
		track:SetOn(opt.get() and true or false)
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		f:EnableMouse(enabled)
	end
	f:SetScript("OnClick", function()
		opt.set(not opt.get())
		stack:RefreshAll() -- settings that depend on this one grey out or come back at once
		if opt.after then opt.after() end
	end)
	Tooltip(f, opt.label, opt.desc)
	stack:Add(f, 20)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Slider with an editable value. No mouse wheel: the wheel scrolls the page.
------------------------------------------------------------------------
function UI.Slider(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	local label = Text(f, T.font, T.text)
	label:SetPoint("TOPLEFT")
	label:SetText(opt.label)

	local slider = CreateFrame("Slider", nil, f)
	slider:SetOrientation("HORIZONTAL")
	slider:SetHeight(16)
	slider:SetPoint("TOPLEFT", 0, -20)
	slider:SetPoint("RIGHT", f, "RIGHT", -70, 0)
	slider:SetMinMaxValues(opt.min, opt.max)
	slider:SetValueStep(opt.step or 1)
	slider:SetObeyStepOnDrag(true)
	local rail = U.Solid(slider, "BACKGROUND", rgba(T.surface))
	rail:SetHeight(4)
	rail:SetPoint("LEFT")
	rail:SetPoint("RIGHT")
	local fill = U.Solid(slider, "ARTWORK", rgba(T.accent))
	fill:SetHeight(4)
	fill:SetPoint("LEFT")
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(U.WHITE)
	thumb:SetVertexColor(rgba(T.text))
	thumb:SetSize(10, 14)
	slider:SetThumbTexture(thumb)

	local box = CreateFrame("EditBox", nil, f)
	box:SetSize(56, 20)
	box:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")
	U.SetFont(box, T.font)
	box:SetTextColor(rgba(T.text))
	U.Solid(box, "BACKGROUND", rgba(T.surface)):SetAllPoints()
	U.Border(box, 1, rgba(T.border))

	local fmt = opt.fmt or (opt.step and opt.step < 1 and "%.2f" or "%d")
	local updating = false
	local function updateFill(v)
		local w = slider:GetWidth()
		if w and w > 0 then fill:SetWidth(math.max(1, w * (v - opt.min) / (opt.max - opt.min))) end
	end
	function f:Refresh()
		updating = true
		local v = opt.get() or opt.min
		slider:SetValue(v)
		box:SetText(string.format(fmt, v))
		updateFill(v)
		updating = false
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		slider:EnableMouse(enabled)
		box:EnableMouse(enabled)
	end
	slider:SetScript("OnValueChanged", function(_, v)
		if updating then return end
		local step = opt.step or 1
		v = math.floor(v / step + 0.5) * step
		box:SetText(string.format(fmt, v))
		updateFill(v)
		opt.set(v)
		if opt.after then opt.after() end
	end)
	slider:SetScript("OnSizeChanged", function() updateFill(slider:GetValue()) end)
	box:SetScript("OnEnterPressed", function(self)
		local v = tonumber(self:GetText())
		if v then
			-- snap to the step like dragging does, and set it once (the slider moving must not set it again)
			local step = opt.step or 1
			v = math.min(opt.max, math.max(opt.min, math.floor(v / step + 0.5) * step))
			updating = true
			slider:SetValue(v)
			updating = false
			opt.set(v)
			if opt.after then opt.after() end
		end
		self:ClearFocus()
		f:Refresh()
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)
	Tooltip(f, opt.label, opt.desc)
	stack:Add(f, 40)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Dropdown (one shared popup list)
------------------------------------------------------------------------
local popup, catcher

local function ClosePopup()
	if popup then popup:Hide() end
	if catcher then catcher:Hide() end
end
UI.ClosePopup = ClosePopup
function UI.IsPopupShown() return popup ~= nil and popup:IsShown() end

-- items = { { value, text, icon?, title? }, ... }. A title row can't be clicked.
-- opts.width overrides the owner's width; opts.atCursor opens it at the mouse.
local function OpenPopup(owner, items, current, onPick, opts)
	opts = opts or {}
	local T = ThemeOf(owner)
	if not popup then
		catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:SetScript("OnClick", ClosePopup)
		popup = CreateFrame("Frame", nil, UIParent)
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:SetFrameLevel(catcher:GetFrameLevel() + 10)
		popup:SetClampedToScreen(true)
		popup.bg = U.Solid(popup, "BACKGROUND", rgba(T.surface))
		popup.bg:SetAllPoints()
		U.Border(popup, 1, rgba(T.border))
		popup.buttons = {}
	end
	for _, b in ipairs(popup.buttons) do b:Hide() end
	local width = opts.width or (owner and owner:GetWidth()) or 200
	for i, item in ipairs(items) do
		local b = popup.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, popup)
			b:SetHeight(22)
			b.hl = U.Solid(b, "BACKGROUND", rgba(T.accentDim))
			b.hl:SetAllPoints()
			b.hl:Hide()
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetSize(16, 16)
			b.icon:SetPoint("LEFT", 8, 0)
			b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			b.text = Text(b, T.font, T.text)
			b.text:SetWordWrap(false)
			b:SetScript("OnEnter", function(self) if not self.isTitle then self.hl:Show() end end)
			b:SetScript("OnLeave", function(self) if not self.selected then self.hl:Hide() end end)
			popup.buttons[i] = b
		end
		b.hl:SetVertexColor(rgba(T.accentDim))
		b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 22)
		b:SetPoint("RIGHT", -1, 0)
		b.icon:SetShown(item.icon ~= nil)
		if item.icon then b.icon:SetTexture(item.icon) end
		b.text:ClearAllPoints()
		b.text:SetPoint("LEFT", item.icon and 30 or 10, 0)
		b.text:SetPoint("RIGHT", -10, 0)
		b.text:SetText(item.text)
		b.isTitle = item.title and true or false
		b.selected = not b.isTitle and current ~= nil and item.value == current
		b.hl:SetShown(b.selected)
		b.text:SetTextColor(rgba((b.isTitle and T.muted) or (b.selected and T.accent) or T.text))
		b:SetScript("OnClick", function()
			if b.isTitle then return end
			ClosePopup()
			onPick(item.value)
		end)
		b:Show()
	end
	popup:SetSize(width, #items * 22 + 2)
	popup:ClearAllPoints()
	if opts.atCursor or not owner then
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 4, y / scale - 4)
	else
		popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	end
	catcher:Show()
	popup:Show()
end
UI.OpenPopup = OpenPopup

function UI.Dropdown(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	local label = Text(f, T.font, T.text)
	label:SetPoint("TOPLEFT")
	label:SetText(opt.label)
	local b = CreateFrame("Button", nil, f)
	b:SetHeight(24)
	b:SetPoint("TOPLEFT", 0, -18)
	b:SetWidth(opt.width or 240)
	b.eluiTheme = T
	local bg = U.Solid(b, "BACKGROUND", rgba(T.surface))
	bg:SetAllPoints()
	U.Border(b, 1, rgba(T.border))
	local value = Text(b, T.font, T.text)
	value:SetPoint("LEFT", 10, 0)
	value:SetPoint("RIGHT", -24, 0)
	value:SetWordWrap(false)
	local arrow = Text(b, T.font, T.muted)
	arrow:SetPoint("RIGHT", -8, 0)
	arrow:SetText("v")
	b:SetScript("OnEnter", function() bg:SetVertexColor(rgba(T.surfaceHi)) end)
	b:SetScript("OnLeave", function() bg:SetVertexColor(rgba(T.surface)) end)
	local function items() if type(opt.items) == "function" then return opt.items() or {} end return opt.items or {} end
	function f:Refresh()
		local cur = opt.get()
		local shown = cur == nil and (opt.placeholder or "Choose...") or (opt.format and opt.format(cur)) or tostring(cur)
		for _, it in ipairs(items()) do
			if it.value == cur then shown = it.text break end
		end
		value:SetText(shown)
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		b:EnableMouse(enabled)
	end
	b:SetScript("OnClick", function()
		OpenPopup(b, items(), opt.get(), function(v)
			opt.set(v)
			stack:RefreshAll()
			if opt.after then opt.after() end
		end)
	end)
	Tooltip(b, opt.label, opt.desc)
	stack:Add(f, 44)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Colour swatch
------------------------------------------------------------------------
function UI.Color(stack, opt)
	local T = stack.T
	local f = CreateFrame("Button")
	local sw = CreateFrame("Frame", nil, f)
	sw:SetSize(30, 18)
	sw:SetPoint("LEFT")
	local fill = U.Solid(sw, "ARTWORK", 1, 1, 1, 1)
	fill:SetAllPoints()
	U.Border(sw, 1, rgba(T.border))
	local label = Text(f, T.font, T.text)
	label:SetPoint("LEFT", sw, "RIGHT", 10, 0)
	label:SetText(opt.label)
	function f:Refresh()
		local c = opt.get() or { 1, 1, 1, 1 }
		fill:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		local enabled = not opt.disabled or not opt.disabled()
		f:SetAlpha(enabled and 1 or 0.4)
		f:EnableMouse(enabled)
	end
	f:SetScript("OnClick", function()
		local c = opt.get() or { 1, 1, 1, 1 }
		local start = { c[1], c[2], c[3], c[4] or 1 }
		local function apply(r, g, b, a)
			opt.set({ r, g, b, opt.hasAlpha and a or (c[4] or 1) })
			f:Refresh()
			if opt.after then opt.after() end
		end
		local function picked()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or start[4]
			apply(r, g, b, a)
		end
		local info = {
			r = start[1], g = start[2], b = start[3], opacity = start[4],
			hasOpacity = opt.hasAlpha and true or false,
			swatchFunc = picked, opacityFunc = picked,
			cancelFunc = function() apply(start[1], start[2], start[3], start[4]) end,
		}
		if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow(info)
		end
	end)
	Tooltip(f, opt.label, opt.desc)
	stack:Add(f, 20)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Text input
------------------------------------------------------------------------
function UI.EditBox(parent, width, height)
	local T = ThemeOf(parent)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width or 200, height or 24)
	box:SetAutoFocus(false)
	box:SetTextInsets(8, 8, 0, 0)
	U.SetFont(box, T.font)
	box:SetTextColor(rgba(T.text))
	U.Solid(box, "BACKGROUND", rgba(T.surface)):SetAllPoints()
	box.border = U.Border(box, 1, rgba(T.border))
	box:SetScript("OnEditFocusGained", function(self) self.border:SetColor(rgba(T.accent)) end)
	box:SetScript("OnEditFocusLost", function(self) self.border:SetColor(rgba(T.border)) end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return box
end

-- A labelled text box. opt: label, placeholder, width, get/set (bound: saved on Enter or leaving the box),
-- onChange(text) while typing, onEnter(text), button = { label, onClick(text, box), width, style }, maxLetters.
function UI.Input(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent)
	local top = 0
	if opt.label then
		local label = Text(f, T.font, T.text)
		label:SetPoint("TOPLEFT")
		label:SetText(opt.label)
		top = -18
	end
	local box = UI.EditBox(f, opt.width or 240, 24)
	box:SetPoint("TOPLEFT", 0, top)
	if opt.maxLetters then box:SetMaxLetters(opt.maxLetters) end
	f.box = box
	local hint = Text(box, T.font, T.muted)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(opt.placeholder or "")
	local function updateHint() hint:SetShown(not box:HasFocus() and (box:GetText() or "") == "") end
	box:HookScript("OnEditFocusGained", updateHint)
	box:HookScript("OnEditFocusLost", function(self)
		updateHint()
		if opt.set and (not opt.get or self:GetText() ~= (opt.get() or "")) then
			opt.set(self:GetText())
			if opt.after then opt.after() end
		end
	end)
	box:SetScript("OnTextChanged", function(self, user)
		updateHint()
		if user and opt.onChange then opt.onChange(self:GetText()) end
	end)
	box:SetScript("OnEnterPressed", function(self)
		if opt.onEnter then opt.onEnter(self:GetText(), self) end
		self:ClearFocus()
	end)
	if opt.get then
		-- Escape throws away what was typed (leaving the box would otherwise save it)
		box:SetScript("OnEscapePressed", function(self) self:SetText(opt.get() or ""); self:ClearFocus() end)
	end
	if opt.button then
		local b = UI.Button(f, opt.button.label, function() opt.button.onClick(box:GetText(), box) end, opt.button.width or 110, opt.button.style)
		b:SetPoint("LEFT", box, "RIGHT", 8, 0)
		f.button = b
	end
	if opt.get then
		function f:Refresh()
			if not box:HasFocus() then box:SetText(opt.get() or "") end
			updateHint()
		end
	end
	Tooltip(box, opt.label, opt.desc)
	stack:Add(f, opt.label and 44 or 26)
	if f.Refresh then f:Refresh() else updateHint() end
	return f
end

-- Read-only text to copy (a link, a file path): clicking selects it all; typing can't change it.
function UI.CopyBox(stack, label, text)
	local T = stack.T
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent)
	local l = Text(f, T.font, T.text)
	l:SetPoint("TOPLEFT")
	l:SetText(label)
	local box = UI.EditBox(f, stack.width, 24)
	box:SetPoint("TOPLEFT", 0, -18)
	box:SetPoint("RIGHT")
	local function value() if type(text) == "function" then return text() or "" end return text or "" end
	box:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= value() then self:SetText(value()); self:HighlightText() end
	end)
	box:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.box = box
	function f:Refresh() box:SetText(value()) end
	Tooltip(box, label, "Click, then Ctrl+C to copy.")
	stack:Add(f, 44)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- List: rows of data with an optional switch on the left and buttons on the right.
-- opt.items() -> array; opt.title(item); opt.detail(item); opt.icon(item); opt.color(item) (title colour)
-- opt.toggle = { get(item), set(item, on) }; opt.buttons = { { label = text or fn(item), width, style,
-- onClick(item, button), shown(item), usable(item), confirm } }; opt.tooltip(item) (lines or a hook
-- function(row, item)); opt.onClick(item); opt.empty (text when there are no rows); opt.max (rows shown);
-- opt.rowHeight (default 30; 40 or more shows the detail on a second line).
------------------------------------------------------------------------
function UI.List(stack, opt)
	local T = stack.T
	local f = CreateFrame("Frame")
	f:SetParent(stack.parent)
	f.rows = {}
	local rowH = opt.rowHeight or 30
	local twoLine = rowH >= 40
	local empty = Text(f, T.font, T.muted)
	empty:SetPoint("TOPLEFT", 4, -4)
	empty:SetText(opt.empty or "Nothing here yet.")

	local function newRow(i)
		local r = CreateFrame("Button", nil, f)
		r:SetHeight(rowH)
		r:SetPoint("TOPLEFT", 0, -(i - 1) * (rowH + 2))
		r:SetPoint("RIGHT")
		r.bg = U.Solid(r, "BACKGROUND", rgba(T.surface))
		r.bg:SetAllPoints()
		local x = 8
		if opt.toggle then
			r.switch = Switch(r, T)
			r.switch:SetPoint("LEFT", x, 0)
			r.switch:EnableMouse(true)
			r.switch:SetScript("OnMouseDown", function()
				if r.item == nil then return end
				opt.toggle.set(r.item, not opt.toggle.get(r.item))
				stack:RefreshAll()
			end)
			x = x + 44
		end
		if opt.icon then
			r.icon = r:CreateTexture(nil, "ARTWORK")
			r.icon:SetSize(18, 18)
			r.icon:SetPoint("LEFT", x, 0)
			r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			x = x + 26
		end
		r.buttons = {}
		local right = -6
		for bi = #(opt.buttons or {}), 1, -1 do
			local d = opt.buttons[bi]
			local make = d.confirm and UI.ConfirmButton or UI.Button
			local b = make(r, type(d.label) == "string" and d.label or "", function(btn) if r.item ~= nil then d.onClick(r.item, btn) end end, d.width or 90, d.style)
			b:SetHeight(math.min(22, rowH - 6))
			b:SetPoint("RIGHT", right, 0)
			right = right - (d.width or 90) - 6
			r.buttons[bi] = b
		end
		r.title = Text(r, T.font, T.text)
		r.title:SetWordWrap(false)
		r.detail = Text(r, twoLine and T.fontSmall + 1 or T.font, T.muted)
		r.detail:SetWordWrap(false)
		if twoLine then
			r.title:SetPoint("TOPLEFT", x, -6)
			r.title:SetPoint("RIGHT", right - 4, 0)
			r.detail:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
			r.detail:SetPoint("RIGHT", right - 4, 0)
		else
			r.title:SetPoint("LEFT", x, 0)
			r.detail:SetPoint("LEFT", r.title, "RIGHT", 10, 0)
			r.detail:SetPoint("RIGHT", right - 4, 0)
		end
		r.titleMax = (opt.titleWidth or 220)
		r:SetScript("OnEnter", function(self)
			self.bg:SetVertexColor(rgba(T.surfaceHi))
			if self.item == nil or not opt.tooltip then return end
			local tip = opt.tooltip(self.item, self)
			if type(tip) == "table" then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				for li, line in ipairs(tip) do
					if li == 1 then GameTooltip:AddLine(line, 1, 1, 1) else GameTooltip:AddLine(line, nil, nil, nil, true) end
				end
				GameTooltip:Show()
			end
		end)
		r:SetScript("OnLeave", function(self)
			self.bg:SetVertexColor(rgba(T.surface))
			GameTooltip:Hide()
		end)
		r:SetScript("OnClick", function(self) if self.item ~= nil and opt.onClick then opt.onClick(self.item) end end)
		f.rows[i] = r
		return r
	end

	function f:Refresh()
		local items = opt.items() or {}
		local n = math.min(#items, opt.max or 500)
		for i = 1, n do
			local item = items[i]
			local r = f.rows[i] or newRow(i)
			r.item = item
			r.title:SetText(opt.title(item) or "")
			if not twoLine then
				local w = (r.title.GetUnboundedStringWidth and r.title:GetUnboundedStringWidth()) or r.title:GetStringWidth() or r.titleMax
				r.title:SetWidth(math.min(r.titleMax, (w or 0) + 2))
			end
			if opt.color then
				local c = opt.color(item)
				r.title:SetTextColor(rgba(c or T.text))
			end
			r.detail:SetText(opt.detail and opt.detail(item) or "")
			if r.icon then
				local icon = opt.icon(item)
				r.icon:SetShown(icon ~= nil)
				if icon then r.icon:SetTexture(icon) end
			end
			if r.switch then r.switch:SetOn(opt.toggle.get(item) and true or false) end
			for bi, d in ipairs(opt.buttons or {}) do
				local b = r.buttons[bi]
				if type(d.label) == "function" then b:SetText(d.label(item)) end
				b:SetShown(not d.shown or d.shown(item) and true or false)
				b:SetUsable(not d.usable or d.usable(item) and true or false)
			end
			r:Show()
		end
		for i = n + 1, #f.rows do f.rows[i].item = nil; f.rows[i]:Hide() end
		empty:SetShown(n == 0)
		local h = n == 0 and 24 or n * (rowH + 2)
		if #items > n then
			f.more = f.more or Text(f, T.fontSmall + 1, T.muted)
			f.more:ClearAllPoints()
			f.more:SetPoint("TOPLEFT", 4, -h - 4)
			f.more:SetText(("%d more not shown."):format(#items - n))
			f.more:Show()
			h = h + 20
		elseif f.more then
			f.more:Hide()
		end
		stack:SetHeightOf(f, h)
	end
	stack:Add(f, 24)
	f:Refresh()
	return f
end

------------------------------------------------------------------------
-- Scroll bar (page body and text areas)
------------------------------------------------------------------------
local BAR_W = 12
local PAGE_STEP = 40

-- The page scroll around `frame`, if it sits in one.
local function OuterScroll(frame)
	local p = frame:GetParent()
	while p do
		if rawget(p, "ScrollBy") then return p end -- set by AttachScrollBar below
		p = p:GetParent()
	end
end

-- A scroll bar for `scroll` (a ScrollFrame showing `child`), parented to `holder`; the caller anchors it.
-- Drag the thumb with the left mouse button, or click the track above or below it to jump a page.
-- Offsets are whole pixels, so text never lands between pixels and blurs. The wheel scrolls by `step`.
-- With `onlyWhile` given, the wheel scrolls this area only while onlyWhile() is true (a text area you
-- are typing in) and otherwise scrolls the page around it, as it also does once this area is at its end.
local function AttachScrollBar(scroll, child, holder, step, onlyWhile)
	local T = ThemeOf(holder)
	local track = CreateFrame("Frame", nil, holder)
	track:SetWidth(BAR_W)
	U.Solid(track, "BACKGROUND", T.muted[1], T.muted[2], T.muted[3], 0.12):SetAllPoints()
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetWidth(BAR_W)
	local thumbTex = U.Solid(thumb, "ARTWORK", T.muted[1], T.muted[2], T.muted[3], 0.55)
	thumbTex:SetAllPoints()
	track:Hide()

	local function maxScroll()
		return math.max(0, math.floor(child:GetHeight() - scroll:GetHeight() + 0.5))
	end
	local function update()
		local viewH, contentH, m = scroll:GetHeight(), child:GetHeight(), maxScroll()
		if scroll:GetVerticalScroll() > m then scroll:SetVerticalScroll(m) end
		if m <= 0 or not scroll:IsShown() then track:Hide() return end
		local trackH = track:GetHeight()
		local h = math.min(trackH, math.max(30, trackH * viewH / contentH))
		thumb:SetHeight(h)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -(trackH - h) * scroll:GetVerticalScroll() / m)
		track:Show()
	end
	local function setScroll(v)
		ClosePopup() -- an open dropdown list would be left behind
		scroll:SetVerticalScroll(math.min(maxScroll(), math.max(0, math.floor(v + 0.5))))
		update()
	end
	-- Scrolls by `delta` pixels; false when it was already at that end.
	function scroll:ScrollBy(delta)
		local before = self:GetVerticalScroll()
		setScroll(before + delta)
		return self:GetVerticalScroll() ~= before
	end

	local function hover(on) thumbTex:SetVertexColor(T.muted[1], T.muted[2], T.muted[3], on and 0.85 or 0.55) end
	local function stopDrag(self)
		self.dragging = nil
		hover(self:IsMouseOver())
	end
	thumb:EnableMouse(true)
	thumb:SetScript("OnEnter", function() hover(true) end)
	thumb:SetScript("OnLeave", function(self) if not self.dragging then hover(false) end end)
	thumb:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local _, y = GetCursorPosition()
		self.dragging = { y = y / self:GetEffectiveScale(), start = scroll:GetVerticalScroll() }
		hover(true)
	end)
	thumb:SetScript("OnMouseUp", stopDrag)
	thumb:SetScript("OnHide", stopDrag)
	thumb:SetScript("OnUpdate", function(self)
		local d = self.dragging
		if not d then return end
		if not IsMouseButtonDown("LeftButton") then stopDrag(self) return end
		local _, y = GetCursorPosition()
		y = y / self:GetEffectiveScale()
		local room = track:GetHeight() - self:GetHeight()
		if room > 0 then setScroll(d.start + (d.y - y) * maxScroll() / room) end
	end)
	track:EnableMouse(true)
	track:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local _, y = GetCursorPosition()
		y = y / self:GetEffectiveScale()
		local page = math.max(step, scroll:GetHeight() - 40)
		setScroll(scroll:GetVerticalScroll() + (y < thumb:GetBottom() and page or -page))
	end)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local outer = OuterScroll(self)
		if outer and onlyWhile and not onlyWhile() then outer:ScrollBy(-delta * PAGE_STEP) return end
		if not self:ScrollBy(-delta * step) and outer then outer:ScrollBy(-delta * PAGE_STEP) end
	end)
	return track, update, setScroll
end

-- Multi-line text area. Inside a page the wheel scrolls the page; it scrolls the text only while you type in it.
function UI.TextArea(parent, width, height)
	local T = ThemeOf(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height)
	U.Solid(holder, "BACKGROUND", rgba(T.surface)):SetAllPoints()
	U.Border(holder, 1, rgba(T.border))
	local scroll = CreateFrame("ScrollFrame", nil, holder)
	scroll:SetPoint("TOPLEFT", 8, -6)
	scroll:SetPoint("BOTTOMRIGHT", -(BAR_W + 8), 6)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetWidth(width - BAR_W - 16)
	U.SetFont(box, T.fontSmall + 1)
	box:SetTextColor(rgba(T.text))
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(box)
	local track, update, setScroll = AttachScrollBar(scroll, box, holder, 30, function() return box:HasFocus() end)
	track:SetPoint("TOPRIGHT", -3, -3)
	track:SetPoint("BOTTOMRIGHT", -3, 3)
	local want
	box:SetScript("OnCursorChanged", function(_, _, y, _, h)
		y = -y
		local top = scroll:GetVerticalScroll()
		if y < top then want = y
		elseif y + h > top + scroll:GetHeight() then want = y + h - scroll:GetHeight()
		else want = nil return end
		setScroll(want)
		if math.abs(scroll:GetVerticalScroll() - want) < 1 then want = nil end
	end)
	box:HookScript("OnSizeChanged", function()
		update()
		if want then setScroll(want); want = nil end
	end)
	scroll:SetScript("OnSizeChanged", update)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function() box:SetFocus() end)
	holder.box = box
	holder.track = track
	return holder
end

-- Scrollable page body. The bar takes the right edge of `parent`: build the page about 24 px narrower.
function UI.ScrollPage(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT")
	scroll:SetPoint("BOTTOMRIGHT", -(BAR_W + 6), 0)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	local track, update = AttachScrollBar(scroll, child, parent, PAGE_STEP)
	track:SetPoint("TOPRIGHT", -3, -2)
	track:SetPoint("BOTTOMRIGHT", -3, 2)
	scroll:SetScript("OnSizeChanged", function(_, w)
		child:SetWidth(w)
		update()
	end)
	-- the bar sits beside the scroll area, so it follows the page's visibility by hand
	scroll:SetScript("OnShow", update)
	scroll:SetScript("OnHide", function() track:Hide() end)
	child:SetScript("OnSizeChanged", update)
	scroll.child = child
	scroll.track = track
	scroll.UpdateBar = update
	return scroll
end

------------------------------------------------------------------------
-- Link window: a link to copy (addons can't open a browser). Our own frame, not a StaticPopup:
-- touching Blizzard's popups from an addon taints Blizzard's own dialogs.
------------------------------------------------------------------------
function UI.LinkWindow(name, T, intro, url)
	T = T or UI.Theme
	local f = CreateFrame("Frame", name, UIParent)
	f.eluiTheme = T
	f:SetSize(380, 132)
	f:SetPoint("TOP", 0, -160)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	U.Solid(f, "BACKGROUND", rgba(T.bg)):SetAllPoints()
	U.Border(f, 1, rgba(T.border))
	local text = Text(f, T.font, T.text)
	text:SetPoint("TOPLEFT", 16, -14)
	text:SetPoint("TOPRIGHT", -16, -14)
	text:SetJustifyH("CENTER")
	text:SetText(intro or "Press Ctrl+C to copy the link, then paste it in your browser.")
	local box = UI.EditBox(f, 348, 24)
	box:SetPoint("TOP", 0, -54)
	box:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= f.url then self:SetText(f.url); self:HighlightText() end
	end)
	box:SetScript("OnEnterPressed", function() f:Hide() end)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	f.box = box
	UI.Button(f, CLOSE or "Close", function() f:Hide() end, 100):SetPoint("BOTTOM", 0, 14)
	f.url = url
	function f:SetLink(newIntro, newUrl)
		if newIntro then text:SetText(newIntro) end
		if newUrl then self.url = newUrl end
	end
	f:SetScript("OnShow", function()
		box:SetText(f.url or "")
		box:SetFocus()
		box:HighlightText()
	end)
	f:SetScript("OnHide", function() box:ClearFocus() end)
	UI.CloseOnEscape(f)
	return f
end

------------------------------------------------------------------------
-- Apps: one settings window per addon, its slash command and its Settings (AddOns) entry.
-- Methods live in UI.App, a table that survives library upgrades, so apps made by an older
-- copy of this file use the newest methods.
------------------------------------------------------------------------
UI.App = UI.App or {}
local App = UI.App
App.__index = App

local SIDEBAR_W = 170

local function addonVersion(addon)
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local v = addon and get and get(addon, "Version")
	return v
end

-- spec: name, addon (folder name), version (else the TOC's), tagline, slash ("/whack"), accent { r, g, b },
-- frameName (prefix for global frame names; default name without spaces), width, height,
-- position (function returning the table the window position is saved in, as .window),
-- buttons ({ { label, onClick(app, button), text = fn() -> label } } shown under the sidebar or along the bottom),
-- feedbackURL, onShow(app), onHide(app), settingsPanel (false: no entry in Blizzard's Settings).
function UI:NewApp(spec)
	local app = setmetatable({}, App)
	app.spec = spec
	app.name = spec.name
	app.slash = spec.slash or ("/" .. spec.name:lower())
	app.T = UI.MakeTheme(spec.accent)
	app.frameName = spec.frameName or spec.name:gsub("[^%w]", "")
	app.sections, app.order = {}, {}
	app.settings, app.settingOrder = {}, {}
	app.commands, app.commandOrder = {}, {}
	if spec.settingsPanel ~= false then app:RegisterSettingsPanel() end
	return app
end

function App:Version()
	local v = self.spec.version or addonVersion(self.spec.addon) or "?"
	v = tostring(v)
	if v:sub(1, 1) ~= "v" then v = "v" .. v end
	return v
end

function App:ColorCode() return "|cff" .. hex(self.T.accent) end

function App:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(self:ColorCode() .. self.name .. "|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Settings: one definition drives the window widget and the slash command.
-- def: key, type ("bool" | "number" | "choice" | "color" | "string"), label, desc, get(), set(v),
-- min, max, step, fmt, choices ({ { value, text } }), width, disabled(), after(v), example (for the help text),
-- hasAlpha, chatLabel (the label in chat replies when it needs more context than in the window).
------------------------------------------------------------------------
function App:Setting(def)
	assert(def.key and def.type and def.get and def.set, "setting needs key, type, get and set")
	local k = def.key:lower()
	assert(not self.settings[k], "duplicate setting " .. k)
	self.settings[k] = def
	self.settingOrder[#self.settingOrder + 1] = def
	return def
end

function App:GetSetting(key) return key and self.settings[tostring(key):lower()] end

local BOOL_WORDS = {
	on = true, ["true"] = true, yes = true, ["1"] = true, enable = true, enabled = true, show = true,
	off = false, ["false"] = false, no = false, ["0"] = false, disable = false, disabled = false, hide = false,
}

local function numFmt(def)
	return def.fmt or (def.step and def.step < 1 and "%.2f" or "%d")
end

-- The value as shown in chat.
function App:FormatValue(def, v)
	if def.type == "bool" then return v and "on" or "off" end
	if def.type == "number" then return v == nil and "?" or string.format(numFmt(def), v) end
	if def.type == "color" then return type(v) == "table" and ("#" .. hex(v)) or "?" end
	if def.type == "choice" then
		for _, c in ipairs(def.choices) do
			if c.value == v then return tostring(c.value) .. " (" .. c.text .. ")" end
		end
		return tostring(v)
	end
	return U.Escape(v == nil and "" or v)
end

function App:Example(def)
	if def.example then return def.example end
	if def.type == "bool" then return "on" end
	if def.type == "number" then return string.format(numFmt(def), def.get() or def.min or 0) end
	if def.type == "color" then return "ff8040" end
	if def.type == "choice" then return tostring(def.choices[1] and def.choices[1].value or "") end
	return "text"
end

-- What a setting accepts, for help lines.
function App:Accepts(def)
	if def.type == "bool" then return "on or off" end
	if def.type == "number" then
		return string.format(numFmt(def), def.min) .. " to " .. string.format(numFmt(def), def.max)
	end
	if def.type == "color" then return "a colour like ff8040 (hex) or 1 0.5 0.25" end
	if def.type == "choice" then
		local t = {}
		for _, c in ipairs(def.choices) do t[#t + 1] = tostring(c.value) end
		return table.concat(t, ", ")
	end
	return "any text"
end

-- Parse `text` for `def`. Returns ok, value or false, reason.
function App:Parse(def, text)
	text = U.Trim(text)
	if def.type == "bool" then
		local w = text:lower()
		if w == "toggle" then return true, not def.get() end
		local v = BOOL_WORDS[w]
		if v == nil then return false, "needs on or off" end
		return true, v
	elseif def.type == "number" then
		local v = tonumber(text)
		if not v then return false, "needs a number from " .. self:Accepts(def) end
		if v < def.min - 1e-9 or v > def.max + 1e-9 then return false, "must be " .. self:Accepts(def) end
		if def.step then v = math.min(def.max, math.max(def.min, math.floor(v / def.step + 0.5) * def.step)) end
		return true, v
	elseif def.type == "choice" then
		local w = text:lower()
		if w == "" then return false, "needs one of: " .. self:Accepts(def) end
		for _, c in ipairs(def.choices) do
			if tostring(c.value):lower() == w then return true, c.value end
		end
		local found
		for _, c in ipairs(def.choices) do
			if c.text:lower():sub(1, #w) == w then
				if found then return false, "more than one choice starts with that; use one of: " .. self:Accepts(def) end
				found = c
			end
		end
		if found then return true, found.value end
		return false, "needs one of: " .. self:Accepts(def)
	elseif def.type == "color" then
		local h = text:match("^#?(%x%x%x%x%x%x)$")
		if h then
			return true, { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, 1 }
		end
		local r, g, b = text:match("^([%d%.]+)[%s,]+([%d%.]+)[%s,]+([%d%.]+)$")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		if r and g and b and r <= 1 and g <= 1 and b <= 1 then return true, { r, g, b, 1 } end
		return false, "needs " .. self:Accepts(def)
	end
	if def.validate then
		local ok, why = def.validate(text)
		if not ok then return false, why end
	end
	return true, text
end

-- Apply a value the same way the window does, then refresh the window.
function App:Apply(def, v)
	def.set(v)
	if def.after then def.after(v) end
	self:Refresh()
end

-- "/x <setting> <value>": set it and reply with the new value; no value shows it and how to set it.
function App:SetFromText(def, text)
	local usage = self.slash .. " " .. def.key .. " " .. self:Example(def)
	local label = def.chatLabel or def.label
	if U.Trim(text) == "" then
		self:Print(label .. ": " .. self:FormatValue(def, def.get()) .. ". Set it with " .. U.Escape(usage) .. " (" .. self:Accepts(def) .. ").")
		return false
	end
	local ok, v = self:Parse(def, text)
	if not ok then
		self:Print("|cffff6060" .. label .. ": " .. U.Escape(v) .. ".|r Example: " .. U.Escape(usage))
		return false
	end
	self:Apply(def, v)
	self:Print(label .. ": " .. self:FormatValue(def, def.get()))
	return true
end

-- Try "<setting> [value]"; true when the first word named a setting.
function App:TrySetting(msg)
	local word, rest = U.Trim(msg):match("^(%S+)%s*(.*)$")
	local def = self:GetSetting(word)
	if not def then return false end
	self:SetFromText(def, rest or "")
	return true
end

function App:PrintSettings()
	if #self.settingOrder == 0 then self:Print("no settings.") return end
	self:Print("settings (" .. U.Escape(self.slash) .. " <setting> <value>):")
	for _, def in ipairs(self.settingOrder) do
		DEFAULT_CHAT_FRAME:AddMessage("  " .. self:ColorCode() .. def.key .. "|r = " .. self:FormatValue(def, def.get())
			.. "  |cff8d94a3" .. (def.chatLabel or def.label) .. " (" .. self:Accepts(def) .. ")|r")
	end
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------
-- name: the first word; usage: shown in help ("recent", "on <macro>"); run(rest, app).
function App:Command(name, usage, desc, run, aliases)
	local c = { name = name, usage = usage or name, desc = desc, run = run }
	self.commands[name:lower()] = c
	self.commandOrder[#self.commandOrder + 1] = c
	for _, a in ipairs(aliases or {}) do self.commands[a:lower()] = c end
	return c
end

function App:Help()
	local s = U.Escape(self.slash)
	self:Print(self:Version() .. (self.spec.tagline and (" - " .. self.spec.tagline) or ""))
	local cc = self:ColorCode()
	local function line(cmd, desc) DEFAULT_CHAT_FRAME:AddMessage("  " .. cc .. U.Escape(cmd) .. "|r - " .. desc) end
	line(self.slash, "open or close the settings window")
	for _, c in ipairs(self.commandOrder) do
		if not c.hidden then line(self.slash .. " " .. c.usage, c.desc or "") end
	end
	if #self.settingOrder > 0 then
		line(self.slash .. " <setting> <value>", "change a setting, e.g. " .. s .. " " .. self.settingOrder[1].key .. " " .. U.Escape(self:Example(self.settingOrder[1])))
		line(self.slash .. " settings", "list every setting and its value")
	end
	line(self.slash .. " help", "this list")
end

-- The whole slash command: bare opens the window; help; settings; commands; "<setting> <value>".
function App:HandleSlash(msg)
	msg = U.Trim(msg)
	if msg == "" then self:Toggle() return "toggle" end
	local word, rest = msg:match("^(%S+)%s*(.*)$")
	local w = word:lower()
	if w == "help" or w == "?" then self:Help() return "help" end
	local c = self.commands[w]
	if c then c.run(rest or "", self) return "command" end
	if w == "settings" or w == "options" or w == "config" then
		if (rest or "") == "" and w ~= "settings" then self:Open() return "open" end
		self:PrintSettings()
		return "settings"
	end
	if self:TrySetting(msg) then return "setting" end
	self:Print("|cffff6060unknown command '" .. U.Escape(word) .. "'.|r " .. U.Escape(self.slash) .. " help lists the commands.")
	return "unknown"
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
-- build(stack, app, section) fills the section's page; called once, when it is first shown.
function App:Section(id, title, build)
	assert(not self.sections[id], "duplicate section " .. id)
	self.sections[id] = { id = id, title = title, build = build }
	self.order[#self.order + 1] = id
end

-- The widget for a setting (by key), with `extra` options mixed in.
function App:Widget(stack, key, extra)
	local def = self:GetSetting(key)
	assert(def, "no setting " .. tostring(key))
	local app = self
	local opt = {
		label = def.label, desc = def.desc, get = def.get, disabled = def.disabled,
		min = def.min, max = def.max, step = def.step, fmt = def.fmt, items = def.choices,
		width = def.width, hasAlpha = def.hasAlpha, placeholder = def.placeholder,
		set = function(v) def.set(v) end,
		after = function() if def.after then def.after(def.get()) end; app:RefreshButtons() end,
	}
	if extra then for k, v in pairs(extra) do opt[k] = v end end
	local t = def.type
	if t == "bool" then return UI.Toggle(stack, opt) end
	if t == "number" then return UI.Slider(stack, opt) end
	if t == "choice" then return UI.Dropdown(stack, opt) end
	if t == "color" then return UI.Color(stack, opt) end
	return UI.Input(stack, opt)
end

local function SavePosition(app, f)
	local holder = app.spec.position and app.spec.position()
	if type(holder) ~= "table" then return end
	local point, _, rel, x, y = f:GetPoint()
	if point then holder.window = { point, rel or point, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) } end
end

local function RestorePosition(app, f)
	local holder = app.spec.position and app.spec.position()
	local p = type(holder) == "table" and holder.window
	f:ClearAllPoints()
	if type(p) == "table" and type(p[1]) == "string" then
		f:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
	else
		f:SetPoint("CENTER")
	end
end

function App:CreateWindow()
	local app, T, spec = self, self.T, self.spec
	local sidebar = #self.order > 1
	local W = spec.width or (sidebar and 780 or 600)
	local H = spec.height or 560
	local f = CreateFrame("Frame", self.frameName .. "OptionsWindow", UIParent)
	f.eluiTheme = T
	f.app = self
	f:SetSize(W, H)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition(app, self)
	end)
	f:Hide()
	RestorePosition(self, f)
	U.Solid(f, "BACKGROUND", rgba(T.bg)):SetAllPoints()
	U.Border(f, 1, rgba(T.border))

	f.footer = {}
	local function footerButton(parent, d, width)
		local b = UI.Button(parent, d.label, function(btn) d.onClick(app, btn); app:RefreshButtons() end, width, d.style)
		b.def = d
		f.footer[#f.footer + 1] = b
		if d.desc then Tooltip(b, d.label, d.desc) end
		return b
	end
	local buttons = {}
	for _, d in ipairs(spec.buttons or {}) do buttons[#buttons + 1] = d end
	if spec.feedbackURL then
		buttons[#buttons + 1] = { label = "Feedback / report a bug", onClick = function() app:ShowFeedback() end }
	end

	local contentLeft, contentTop, contentBottom
	if sidebar then
		local side = CreateFrame("Frame", nil, f)
		side:SetPoint("TOPLEFT", 1, -1)
		side:SetPoint("BOTTOMLEFT", 1, 1)
		side:SetWidth(SIDEBAR_W)
		U.Solid(side, "BACKGROUND", rgba(T.sidebar)):SetAllPoints()
		local sideLine = U.Solid(side, "BORDER", rgba(T.border))
		sideLine:SetWidth(1)
		sideLine:SetPoint("TOPRIGHT")
		sideLine:SetPoint("BOTTOMRIGHT")

		local logo = Text(side, T.fontHuge, T.text)
		logo:SetPoint("TOPLEFT", 18, -18)
		logo:SetWidth(SIDEBAR_W - 30)
		logo:SetText(self.name)
		local ver = Text(side, T.fontSmall, T.muted)
		ver:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -3)
		ver:SetText(self:Version())
		-- the nav starts under the name (which may wrap), the version and the tagline
		local navTop = 18 + math.max(20, math.ceil(logo:GetStringHeight() or 20)) + 3 + math.max(10, math.ceil(ver:GetStringHeight() or 10))
		if spec.tagline then
			local tag = Text(side, T.fontSmall, T.muted)
			tag:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -8)
			tag:SetWidth(SIDEBAR_W - 30)
			tag:SetText(spec.tagline)
			navTop = navTop + 8 + math.ceil(tag:GetStringHeight() or 12)
		end
		navTop = navTop + 14
		f.tagline = spec.tagline

		f.navButtons = {}
		for i, id in ipairs(self.order) do
			local s = self.sections[id]
			local b = CreateFrame("Button", nil, side)
			b:SetHeight(30)
			b:SetPoint("TOPLEFT", 8, -navTop - (i - 1) * 32)
			b:SetPoint("RIGHT", -8, 0)
			b.bg = U.Solid(b, "BACKGROUND", rgba(T.accentDim))
			b.bg:SetAllPoints()
			b.bg:Hide()
			b.bar = U.Solid(b, "ARTWORK", rgba(T.accent))
			b.bar:SetWidth(2)
			b.bar:SetPoint("TOPLEFT")
			b.bar:SetPoint("BOTTOMLEFT")
			b.bar:Hide()
			b.text = Text(b, T.font, T.muted)
			b.text:SetPoint("LEFT", 12, 0)
			b.text:SetText(s.title)
			b:SetScript("OnEnter", function(self) if app.current ~= id then self.text:SetTextColor(rgba(T.text)) end end)
			b:SetScript("OnLeave", function(self) if app.current ~= id then self.text:SetTextColor(rgba(T.muted)) end end)
			b:SetScript("OnClick", function() app:ShowSection(id) end)
			f.navButtons[id] = b
		end
		-- footer buttons stack up from the bottom of the sidebar
		for i, d in ipairs(buttons) do
			local b = footerButton(side, d, SIDEBAR_W - 16)
			b:SetPoint("BOTTOMLEFT", 8, 12 + (#buttons - i) * 32)
		end
		contentLeft, contentTop, contentBottom = SIDEBAR_W + 1 + T.pad + 8, -T.pad - 8, T.pad
	else
		local title = Text(f, T.fontHuge, T.text)
		title:SetPoint("TOPLEFT", T.pad, -14)
		title:SetWordWrap(false)
		title:SetText(self.name)
		local ver = Text(f, T.fontSmall, T.muted)
		ver:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
		ver:SetText(self:Version())
		local top = 44
		if spec.tagline then
			local tag = Text(f, T.fontSmall + 1, T.muted)
			tag:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
			tag:SetWidth(W - 2 * T.pad - 30)
			tag:SetText(spec.tagline)
			top = 14 + 22 + 6 + math.ceil(tag:GetStringHeight()) + 10
		end
		f.tagline = spec.tagline
		local line = U.Solid(f, "ARTWORK", rgba(T.border))
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", 1, -top)
		line:SetPoint("TOPRIGHT", -1, -top)
		local bottom = T.pad
		if #buttons > 0 then
			local x = T.pad
			for _, d in ipairs(buttons) do
				local w = d.width or 150
				local b = footerButton(f, d, w)
				-- never narrower than the label ("Feedback / report a bug" needs about 160 px)
				local tw = b.label.GetUnboundedStringWidth and b.label:GetUnboundedStringWidth() or b.label:GetStringWidth() or 0
				if tw + 24 > w then w = math.ceil(tw + 24); b:SetWidth(w) end
				b:SetPoint("BOTTOMLEFT", x, 14)
				x = x + w + 8
			end
			bottom = 52
		end
		contentLeft, contentTop, contentBottom = T.pad, -top - 14, bottom
	end

	local close = CreateFrame("Button", nil, f)
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -8, -8)
	local x = Text(close, T.fontTitle, T.muted)
	x:SetPoint("CENTER")
	x:SetText("x")
	close:SetScript("OnEnter", function() x:SetTextColor(rgba(T.text)) end)
	close:SetScript("OnLeave", function() x:SetTextColor(rgba(T.muted)) end)
	close:SetScript("OnClick", function() f:Hide() end)
	f.close = close

	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", contentLeft, contentTop)
	content:SetPoint("BOTTOMRIGHT", -T.pad, contentBottom)
	f.content = content
	f.contentWidth = W - contentLeft - T.pad

	f:SetScript("OnShow", function()
		app:RefreshButtons()
		if spec.onShow then spec.onShow(app) end
	end)
	f:SetScript("OnHide", function()
		ClosePopup()
		if spec.onHide then spec.onHide(app) end
	end)
	UI.CloseOnEscape(f)
	self.window = f
	return f
end

function App:RefreshButtons()
	local f = self.window
	if not f then return end
	for _, b in ipairs(f.footer) do
		if b.def.text then b:SetText(b.def.text(self)) end
	end
end

function App:ShowSection(id)
	local f = self.window
	if not f then return end
	local s = self.sections[id]
	if not s then return end
	ClosePopup()
	for sid, other in pairs(self.sections) do
		if other.scroll then other.scroll:SetShown(sid == id) end
		local b = f.navButtons and f.navButtons[sid]
		if b then
			local active = sid == id
			b.bg:SetShown(active)
			b.bar:SetShown(active)
			b.text:SetTextColor(rgba(active and self.T.text or self.T.muted))
		end
	end
	self.current = id
	if not s.scroll then
		s.scroll = UI.ScrollPage(f.content)
		local width = f.contentWidth - 24 -- the scroll bar takes the right edge
		s.scroll.child:SetWidth(width)
		s.stack = UI.Stack(s.scroll.child, width, self.T)
		s.build(s.stack, self, s)
		s.scroll.UpdateBar()
	else
		s.stack:RefreshAll()
	end
	s.scroll:Show()
end

-- Build a section again from scratch (its rows depend on data).
function App:RebuildSection(id)
	local s = self.sections[id]
	if not s or not s.scroll then return end
	s.scroll:Hide()
	s.scroll:SetParent(nil)
	s.scroll, s.stack = nil, nil
	if self.current == id and self:IsShown() then self:ShowSection(id) end
end

-- Re-read every value shown in the open window.
function App:Refresh()
	if not self.window then return end
	self:RefreshButtons()
	local s = self.current and self.sections[self.current]
	if s and s.stack then s.stack:RefreshAll() end
end

function App:Open(id)
	if not self.window then self:CreateWindow() end
	self.window:Show()
	self:ShowSection(id or self.current or self.order[1])
end

function App:Close()
	if self.window then self.window:Hide() end
end

function App:IsShown() return self.window ~= nil and self.window:IsShown() end

function App:Toggle()
	if self:IsShown() then self:Close() else self:Open() end
end

function App:ShowFeedback()
	if not self.feedback then
		self.feedback = UI.LinkWindow(self.frameName .. "FeedbackWindow", self.T,
			"Report a bug or suggest an idea.\nPress Ctrl+C to copy the link, then paste it in your browser.", self.spec.feedbackURL)
	end
	self.feedback:Show()
	return self.feedback
end

------------------------------------------------------------------------
-- Blizzard's Settings > AddOns: a small page with a button that opens the window.
-- Only the official registration calls; Blizzard's panel is never hidden or changed by us.
------------------------------------------------------------------------
function App:RegisterSettingsPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local app, T = self, self.T
	local p = CreateFrame("Frame")
	p.eluiTheme = T
	p.name = self.name
	local title = Text(p, T.fontHuge + 2, T.text)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(self.name)
	local ver = Text(p, T.fontSmall + 1, T.muted)
	ver:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
	p:SetScript("OnShow", function() ver:SetText(app:Version()) end)
	local tag = Text(p, T.font, T.muted)
	tag:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	tag:SetWidth(520)
	tag:SetText((self.spec.tagline or "") .. "\n\nAll settings are in " .. self.name .. "'s own window (also " .. self.slash .. ").")
	local b = UI.Button(p, "Open " .. self.name .. " settings", function() app:Open() end, 240, "accent")
	b:SetPoint("TOPLEFT", tag, "BOTTOMLEFT", 0, -16)
	p.openButton = b
	p.OnCommit = function() end
	p.OnDefault = function() end
	p.OnRefresh = function() end
	local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, p, self.name)
	if ok and category then
		pcall(Settings.RegisterAddOnCategory, category)
		self.settingsCategory = category
	end
	self.settingsPanel = p
end
