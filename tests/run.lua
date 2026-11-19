-- Offline tests for CraftColors against wowmock.lua: settings defaults and old saved data, the
-- recolouring, every slash command and the settings window.
local ROOT = ...
local ADDON = "CraftColors"
local ns = {}
local failures, passes = {}, 0

local function step(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passes = passes + 1
		print("  ok   " .. name)
	else
		failures[#failures + 1] = name .. ": " .. tostring(err)
		print("  FAIL " .. name .. "\n         " .. tostring(err))
	end
end
local function check(cond, msg) if not cond then error(msg, 2) end end
local function last() return MOCK.log[#MOCK.log] or "" end

-- Taint guard: every global the addon assigns is recorded.
local globalWrites = {}
local addonEnv = setmetatable({}, { __index = _G, __newindex = function(_, k, v) globalWrites[k] = true; _G[k] = v end })

local function loadToc(savedVars)
	for k, v in pairs(savedVars or {}) do _G[k] = v end
	local toc = assert(io.open(ROOT .. "/" .. ADDON .. ".toc")):read("*a")
	for line in toc:gmatch("[^\r\n]+") do
		if not line:match("^%s*#") and line:match("%.lua%s*$") then
			local chunk, err = loadfile(ROOT .. "/" .. line:gsub("\\", "/"):gsub("%s+$", ""))
			if not chunk then error("syntax: " .. err) end
			setfenv(chunk, addonEnv)
			chunk(ADDON, ns)
		end
	end
end

step("loads with old saved data (none) and fills the defaults", function()
	CraftColorsDB = nil
	loadToc()
	MOCK.Fire("ADDON_LOADED", ADDON)
	local db = CraftColorsDB
	check(db and db.enabled == true and db.hoverBoost == 0.2, "defaults")
	check(db.colors.orange[1] == 1 and db.colors.orange[2] == 0.5 and db.colors.orange[3] == 0.25, "orange default changed")
	check(db.colors.yellow[1] == 1 and db.colors.yellow[2] == 1 and db.colors.yellow[3] == 0, "yellow default changed")
	check(db.colors.green[1] == 0.25 and db.colors.green[2] == 0.75, "green default changed")
	check(db.colors.gray[1] == 0.5, "gray default changed")
	check(SlashCmdList.CRAFTCOLORS, "no slash command")
end)

step("saved settings are kept; missing ones are filled", function()
	local saved = { enabled = false, colors = { orange = { 0, 0, 1 } } }
	ns.app.spec.position = ns.app.spec.position -- unchanged
	local filled = LibStub("EverlookUI-1").Util.FillDefaults(saved, ns.DEFAULTS)
	check(filled.enabled == false and filled.colors.orange[3] == 1, "saved values overwritten")
	check(filled.colors.gray[1] == 0.5 and filled.hoverBoost == 0.2, "missing values not filled")
end)

step("recolours a recipe row by difficulty, brighter on hover, not when off", function()
	local color
	local row = {
		Label = { SetTextColor = function(_, r, g, b) color = { r, g, b } end },
		GetElementData = function() return { GetData = function() return { recipeInfo = { relativeDifficulty = Enum.TradeskillRelativeDifficulty.Optimal } } end } end,
		IsMouseOver = function() return false end,
	}
	ns.Recolor(row)
	check(color and color[1] == 1 and color[2] == 0.5, "not orange")
	row.IsMouseOver = function() return true end
	ns.Recolor(row)
	check(math.abs(color[2] - 0.7) < 1e-9, "hover not brighter")
	color = nil
	CraftColorsDB.enabled = false
	ns.Recolor(row)
	check(color == nil, "recoloured while off")
	CraftColorsDB.enabled = true
end)

step("bare slash opens and closes the window; Escape closes it", function()
	SlashCmdList.CRAFTCOLORS("")
	local f = CraftColorsOptionsWindow
	check(f and f:IsShown(), "window not shown")
	f:GetScript("OnKeyDown")(f, "ESCAPE")
	check(not f:IsShown(), "escape didn't close")
	SlashCmdList.CRAFTCOLORS("")
	check(f:IsShown(), "didn't reopen")
	SlashCmdList.CRAFTCOLORS("")
	check(not f:IsShown(), "didn't toggle closed")
end)

step("every subcommand and setting works from chat", function()
	SlashCmdList.CRAFTCOLORS("")
	MOCK.log = {}
	SlashCmdList.CRAFTCOLORS("help")
	local all = table.concat(MOCK.log, "\n")
	check(all:find("/ccolors debug", 1, true) and all:find("/ccolors reset", 1, true) and all:find("/ccolors feedback", 1, true)
		and all:find("/ccolors on || off || toggle", 1, true) and all:find("Also works as /craftcolors", 1, true), "help: " .. all)
	SlashCmdList.CRAFTCOLORS("enabled off")
	check(CraftColorsDB.enabled == false and last():find("off", 1, true), "enabled off: " .. last())
	SlashCmdList.CRAFTCOLORS("enabled on")
	check(CraftColorsDB.enabled == true, "enabled on")
	SlashCmdList.CRAFTCOLORS("orange 00ff00")
	check(CraftColorsDB.colors.orange[2] == 1 and CraftColorsDB.colors.orange[1] == 0, "orange colour")
	check(last():find("#00ff00", 1, true), "colour reply: " .. last())
	SlashCmdList.CRAFTCOLORS("gray purple")
	check(last():find("Example: /ccolors gray", 1, true), "bad colour reply: " .. last())
	SlashCmdList.CRAFTCOLORS("hover 0.3")
	check(math.abs(CraftColorsDB.hoverBoost - 0.3) < 1e-9, "hover")
	SlashCmdList.CRAFTCOLORS("hover 2")
	check(math.abs(CraftColorsDB.hoverBoost - 0.3) < 1e-9 and last():find("0.00 to 0.50", 1, true), "hover range: " .. last())
	SlashCmdList.CRAFTCOLORS("check")
	check(last():find("select a recipe", 1, true), "check without a profession: " .. last())
	ProfessionsFrame = { CraftingPage = { SchematicForm = { GetRecipeInfo = function() return { name = "Bolt|of Cloth", relativeDifficulty = Enum.TradeskillRelativeDifficulty.Medium, numSkillUps = 1, canSkillUp = true } end } } }
	SlashCmdList.CRAFTCOLORS("debug")
	check(last():find("Bolt||of Cloth", 1, true) and last():find("yellow", 1, true), "check: " .. last())
	ProfessionsFrame = nil
	SlashCmdList.CRAFTCOLORS("reset")
	check(CraftColorsDB.colors.orange[1] == 0 and last():find("/ccolors reset again within 10 s", 1, true), "reset didn't ask first: " .. last())
	SlashCmdList.CRAFTCOLORS("reset")
	check(CraftColorsDB.colors.orange[1] == 1 and CraftColorsDB.colors.orange[2] == 0.5 and CraftColorsDB.hoverBoost == 0.2, "reset")
	SlashCmdList.CRAFTCOLORS("feedback")
	check(CraftColorsFeedbackWindow and CraftColorsFeedbackWindow:IsShown(), "feedback window")
	check(CraftColorsFeedbackWindow.box:GetText():find("craftcolors", 1, true), "feedback url")
	CraftColorsFeedbackWindow:Hide()
	SlashCmdList.CRAFTCOLORS("bug")
	check(CraftColorsFeedbackWindow:IsShown(), "bug alias")
	CraftColorsFeedbackWindow:Hide()
	SlashCmdList.CRAFTCOLORS("wat")
	check(last():find("/ccolors help", 1, true), "unknown: " .. last())
	SlashCmdList.CRAFTCOLORS("settings")
	CraftColorsOptionsWindow:Hide()
end)

step("chat commands follow the shared pattern: both names, on/off, get/set, suggestions", function()
	check(SLASH_CRAFTCOLORS1 == "/ccolors" and SLASH_CRAFTCOLORS2 == "/craftcolors", "slash words")
	SlashCmdList.CRAFTCOLORS("off")
	check(CraftColorsDB.enabled == false and last():find("Recipe colours: off", 1, true), "off: " .. last())
	SlashCmdList.CRAFTCOLORS("toggle")
	check(CraftColorsDB.enabled == true, "toggle")
	SlashCmdList.CRAFTCOLORS("off enabled")
	check(CraftColorsDB.enabled == false, "off <setting>")
	SlashCmdList.CRAFTCOLORS("on")
	SlashCmdList.CRAFTCOLORS("set hover 0.25")
	check(math.abs(CraftColorsDB.hoverBoost - 0.25) < 1e-9, "set")
	SlashCmdList.CRAFTCOLORS("get hover")
	check(last():find("0.25", 1, true), "get: " .. last())
	SlashCmdList.CRAFTCOLORS("oragne 00ff00")
	check(last():find("Did you mean /ccolors orange 00ff00?", 1, true), "typo: " .. last())
	SlashCmdList.CRAFTCOLORS("brightness")
	check(last():find("Did you mean /ccolors hover?", 1, true), "keyword: " .. last())
	SlashCmdList.CRAFTCOLORS("search grey")
	check(CraftColorsOptionsWindow:IsShown() and CraftColorsOptionsWindow.searchBox:GetText() == "grey", "search")
	CraftColorsOptionsWindow:Hide()
	SlashCmdList.CRAFTCOLORS("status")
	check(last():find("Recipe colours:", 1, true), "status: " .. last())
end)

step("classic trade skill and craft windows are coloured too, if the client has them", function()
	local colors, scripts = {}, {}
	local types = { [11] = "optimal", [12] = "trivial", [13] = "header" }
	local function button(name, id)
		local label = { SetTextColor = function(_, r, g, b) colors[name] = { r, g, b } end,
			GetTextColor = function() local c = colors[name] or { 1, 0.82, 0 }; return c[1], c[2], c[3] end }
		_G[name .. "Text"] = label
		_G[name] = { GetName = function() return name end, GetID = function() return id end, IsShown = function() return true end,
			IsMouseOver = function() return false end, HookScript = function(_, k, fn) scripts[name .. k] = fn end }
	end
	button("TradeSkillSkill1", 11); button("TradeSkillSkill2", 12); button("TradeSkillSkill3", 13)
	TRADE_SKILLS_DISPLAYED = 3
	GetTradeSkillInfo = function(i) return "Recipe " .. i, types[i] end
	TradeSkillFrame = { IsShown = function() return true end }
	local painted = 0
	TradeSkillFrame_Update = function() painted = painted + 1 end
	MOCK.Fire("ADDON_LOADED", "Blizzard_TradeSkillUI")
	TradeSkillFrame_Update()
	check(painted == 1, "game's own update not called")
	check(colors.TradeSkillSkill1 and colors.TradeSkillSkill1[2] == 0.5, "optimal not orange")
	check(colors.TradeSkillSkill2 and colors.TradeSkillSkill2[1] == 0.5 and colors.TradeSkillSkill2[3] == 0.5, "trivial not gray")
	check(colors.TradeSkillSkill3 == nil, "header row tinted")
	check(scripts.TradeSkillSkill1OnEnter and scripts.TradeSkillSkill1OnLeave, "hover not hooked")
	SlashCmdList.CRAFTCOLORS("off")
	check(colors.TradeSkillSkill1[1] == 1 and colors.TradeSkillSkill1[2] == 0.82, "own colour not back: " .. table.concat(colors.TradeSkillSkill1, ","))
	SlashCmdList.CRAFTCOLORS("on")
	check(colors.TradeSkillSkill1[2] == 0.5, "not tinted again after on")
	-- the craft window (Enchanting in Classic)
	button("Craft1", 21)
	CRAFTS_DISPLAYED = 1
	GetCraftInfo = function() return "Enchant Bracer", "", "medium" end
	CraftFrame_Update = function() end
	MOCK.Fire("ADDON_LOADED", "Blizzard_CraftUI")
	CraftFrame_Update()
	check(colors.Craft1 and colors.Craft1[1] == 1 and colors.Craft1[2] == 1 and colors.Craft1[3] == 0, "craft medium not yellow")
	TradeSkillFrame, TradeSkillFrame_Update, GetTradeSkillInfo, CraftFrame_Update, GetCraftInfo = nil, nil, nil, nil, nil
	for _, n in ipairs({ "TradeSkillSkill1", "TradeSkillSkill2", "TradeSkillSkill3", "Craft1" }) do _G[n], _G[n .. "Text"] = nil, nil end
end)

step("no taint: only our own globals; no Blizzard popups", function()
	local allowed = { CraftColorsDB = true, SLASH_CRAFTCOLORS1 = true, LibStub = true }
	for k in pairs(globalWrites) do check(allowed[k], "addon assigned the global " .. tostring(k)) end
	check(next(StaticPopupDialogs) == nil, "StaticPopupDialogs used")
	check(next(UISpecialFrames) == nil, "UISpecialFrames used")
end)

step("turning colouring off puts the label's own colour back", function()
	local color = { 0.9, 0.8, 0.1 }
	local row = {
		Label = { SetTextColor = function(_, r, g, b) color = { r, g, b } end, GetTextColor = function() return color[1], color[2], color[3] end },
		GetElementData = function() return { GetData = function() return { recipeInfo = { relativeDifficulty = Enum.TradeskillRelativeDifficulty.Easy } } end } end,
		IsMouseOver = function() return false end,
	}
	ns.Recolor(row)
	check(color[1] == 0.25 and color[2] == 0.75, "not green")
	CraftColorsDB.enabled = false
	ns.Recolor(row)
	check(color[1] == 0.9 and color[2] == 0.8 and color[3] == 0.1, "own colour not restored")
	CraftColorsDB.enabled = true
	ns.Recolor(row)
	check(color[1] == 0.25, "not recoloured after turning back on")
end)

step("turning colouring off never leaves a row in a stale hover colour", function()
	local NORMAL, HOVER = { 0.9, 0.8, 0.1 }, { 1, 1, 1 }
	local color = { NORMAL[1], NORMAL[2], NORMAL[3] }
	local over = false
	local row = {
		Label = { SetTextColor = function(_, r, g, b) color = { r, g, b } end, GetTextColor = function() return color[1], color[2], color[3] end },
		GetElementData = function() return { GetData = function() return { recipeInfo = { relativeDifficulty = Enum.TradeskillRelativeDifficulty.Easy } } end } end,
		IsMouseOver = function() return over end,
	}
	-- the game paints the hover colour, we tint over it
	over = true
	color = { HOVER[1], HOVER[2], HOVER[3] }
	ns.Recolor(row)
	-- mouse leaves: the game paints its normal colour, we tint again
	over = false
	color = { NORMAL[1], NORMAL[2], NORMAL[3] }
	ns.Recolor(row)
	check(color[1] == 0.25, "not tinted")
	CraftColorsDB.enabled = false
	ns.Recolor(row)
	check(color[1] == 0.9 and color[2] == 0.8 and color[3] == 0.1, "left in hover colour: " .. table.concat(color, ","))
	-- while off, a game repaint (hover) is left alone
	color = { HOVER[1], HOVER[2], HOVER[3] }
	ns.Recolor(row)
	check(color[1] == 1 and color[3] == 1, "touched the game's own hover colour while off")
	CraftColorsDB.enabled = true
end)

step("no Lua errors reported", function()
	check(#MOCK.errors == 0, table.concat(MOCK.errors, "\n"))
end)

print(("\n%d passed, %d failed"):format(passes, #failures))
return #failures
