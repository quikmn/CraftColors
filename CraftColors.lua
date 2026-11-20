-- CraftColors: tint recipe names in ProfessionsFrame (and the classic TradeSkillFrame / CraftFrame, if
-- the client uses them) by relative difficulty.
-- Orange = guaranteed skill-up, yellow = likely, green = rare, gray = none.
-- /craftcolors opens the settings window; /craftcolors help lists the commands.

local ADDON, ns = ...
local UI = LibStub("EverlookUI-1")

-- Default colours (Blizzard's own skill-up colours) and settings.
ns.DEFAULTS = {
    version = 1,
    enabled = true,
    hoverBoost = 0.2, -- brighten the hovered row this much so the highlight still reads
    showChance = true, -- "37%" after a yellow or green recipe (needs EverlookDB Crafting for the skill numbers)
    showCount = true,  -- "(4)": how many you can make from your bags
    countMore = false, -- "(4 +5)": and how many more with your bank and other characters (EverlookDB Crafting)
    colors = {
        orange = { 1.00, 0.50, 0.25 }, -- Optimal
        yellow = { 1.00, 1.00, 0.00 }, -- Medium
        green  = { 0.25, 0.75, 0.25 }, -- Easy
        gray   = { 0.50, 0.50, 0.50 }, -- Trivial
    },
}
local ORDER = { "orange", "yellow", "green", "gray" }
local LABELS = {
    orange = "Orange: always a skill-up",
    yellow = "Yellow: usually a skill-up",
    green  = "Green: rarely a skill-up",
    gray   = "Gray: no skill-up",
}

-- relativeDifficulty -> colour name. Prefer the live enum values in case the client numbers them differently.
local NAMES = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "gray" }
local D = Enum and Enum.TradeskillRelativeDifficulty
if D and D.Optimal ~= nil then
    NAMES = { [D.Optimal] = "orange", [D.Medium] = "yellow", [D.Easy] = "green", [D.Trivial] = "gray" }
end
ns.NAMES = NAMES

local db -- CraftColorsDB, set on ADDON_LOADED

function ns.ColorFor(difficulty)
    local name = NAMES[difficulty]
    return name and db and db.colors[name], name
end

local function GetRecipeInfo(frame)
    if not frame.GetElementData then return end
    local node = frame:GetElementData()
    local data = node and node.GetData and node:GetData()
    return data and data.recipeInfo
end

local function Same(c, r, g, b)
    return c and math.abs(c[1] - r) < 0.002 and math.abs(c[2] - g) < 0.002 and math.abs(c[3] - b) < 0.002
end

-- Remember the colour the game last painted the label (normal, hover or selected). Rows are recycled and
-- the game repaints on hover and selection, so a colour saved once goes stale; this runs after each repaint.
local function NoteGameColor(frame)
    if not frame.Label.GetTextColor then return end
    local r, g, b = frame.Label:GetTextColor()
    if not r or Same(frame.ccApplied, r, g, b) then return end -- still our tint: the game didn't repaint
    frame.ccGameColor = { r, g, b }
end

local function Paint(frame, r, g, b)
    frame.Label:SetTextColor(r, g, b)
    frame.ccApplied = { r, g, b }
end

local function Recolor(frame)
    if not db or not frame.Label then return end
    NoteGameColor(frame)
    if not db.enabled then
        -- put back the game's own colour, but only over a tint of ours
        local o = frame.ccGameColor
        if frame.ccApplied and o then frame.Label:SetTextColor(o[1], o[2], o[3]) end
        frame.ccApplied = nil
        if frame.ccExtra then frame.ccExtra:Hide() end
        return
    end
    local c
    if frame.ccColorName then
        local name = frame:ccColorName()
        c = name and db.colors[name]
    else
        local info = GetRecipeInfo(frame)
        c = info and ns.ColorFor(info.relativeDifficulty)
    end
    if not c then frame.ccApplied = nil; return end
    if not frame.ccColorName and ns.Extras then ns.Extras(frame) end
    if frame.IsMouseOver and frame:IsMouseOver() then
        local b = db.hoverBoost or 0
        Paint(frame, math.min(c[1] + b, 1), math.min(c[2] + b, 1), math.min(c[3] + b, 1))
    else
        Paint(frame, c[1], c[2], c[3])
    end
end
ns.Recolor = Recolor

local hooked = setmetatable({}, { __mode = "k" })

local function HookRow(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    -- Blizzard resets the label color on init, hover and selection; recolor after each.
    for _, method in ipairs({ "Init", "SetLabelFontColors", "OnEnter", "OnLeave", "SetSelected" }) do
        if type(frame[method]) == "function" then
            hooksecurefunc(frame, method, Recolor)
        end
    end
end

local function RefreshAll(scrollBox)
    scrollBox:ForEachFrame(function(frame)
        if GetRecipeInfo(frame) then
            HookRow(frame)
            Recolor(frame)
        end
    end)
end

local scrollBoxHooked = false
local function RecipeScrollBox()
    local list = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
    return list and list.ScrollBox
end

local function TryHookProfessions()
    if scrollBoxHooked then return true end
    local scrollBox = RecipeScrollBox()
    if not scrollBox then return false end
    scrollBoxHooked = true

    hooksecurefunc(scrollBox, "Update", RefreshAll)
    if ScrollBoxListMixin and ScrollBoxListMixin.Event and ScrollBoxListMixin.Event.OnAcquiredFrame then
        scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, frame)
            HookRow(frame)
        end, ADDON)
    end
    RefreshAll(scrollBox)
    return true
end

-- Classic-style windows, in case this client opens them for some professions: the trade skill window
-- (Blizzard_TradeSkillUI) and the craft window Enchanting uses in Classic (Blizzard_CraftUI). Their rows
-- are fixed buttons (TradeSkillSkill1.., Craft1..) and the difficulty comes as a word ("optimal", ...).
local SKILL_TYPES = { optimal = "orange", medium = "yellow", easy = "green", trivial = "gray" }
ns.SKILL_TYPES = SKILL_TYPES
local CLASSIC = {
    {
        addon = "Blizzard_TradeSkillUI", frame = "TradeSkillFrame", update = "TradeSkillFrame_Update",
        prefix = "TradeSkillSkill", count = "TRADE_SKILLS_DISPLAYED",
        kind = function(index) local _, skillType = GetTradeSkillInfo(index); return skillType end,
    },
    {
        addon = "Blizzard_CraftUI", frame = "CraftFrame", update = "CraftFrame_Update",
        prefix = "Craft", count = "CRAFTS_DISPLAYED",
        kind = function(index) local _, _, craftType = GetCraftInfo(index); return craftType end,
    },
}
ns.CLASSIC = CLASSIC
local classicRows = setmetatable({}, { __mode = "k" })

local function ClassicRow(win, button)
    local row = classicRows[button]
    if row then return row end
    local label = _G[button:GetName() .. "Text"] or (button.GetFontString and button:GetFontString())
    if not label then return end
    row = {
        Label = label,
        IsMouseOver = function() return button.IsMouseOver and button:IsMouseOver() end,
        ccColorName = function()
            local index = button.GetID and button:GetID()
            if not index or index < 1 then return end
            local ok, kind = pcall(win.kind, index)
            return ok and SKILL_TYPES[kind] or nil
        end,
    }
    classicRows[button] = row
    -- the game repaints the name on hover; tint again after it
    if button.HookScript then
        button:HookScript("OnEnter", function() Recolor(row) end)
        button:HookScript("OnLeave", function() Recolor(row) end)
    end
    return row
end

local function RefreshClassic(win)
    for i = 1, tonumber(_G[win.count]) or 8 do
        local button = _G[win.prefix .. i]
        if button and button.IsShown and button:IsShown() then
            local row = ClassicRow(win, button)
            if row then Recolor(row) end
        end
    end
end

local function TryHookClassic()
    for _, win in ipairs(CLASSIC) do
        if not win.hooked and type(_G[win.update]) == "function" then
            win.hooked = true
            hooksecurefunc(win.update, function() RefreshClassic(win) end)
        end
    end
end
ns.TryHookClassic = TryHookClassic

-- Recolour an open profession window right away after a setting changes (turning it off puts the
-- game's own colours back).
function ns.Apply()
    local scrollBox = scrollBoxHooked and RecipeScrollBox()
    if scrollBox then RefreshAll(scrollBox) end
    for _, win in ipairs(CLASSIC) do
        local frame = _G[win.frame]
        if win.hooked and frame and frame:IsShown() then RefreshClassic(win) end
    end
end

-- The recipe selected in the profession window (for checking what the game reports).
function ns.SelectedRecipe()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    return form and form.GetRecipeInfo and form:GetRecipeInfo()
end

function ns.CheckText()
    local info = ns.SelectedRecipe()
    if not info then return "Open a profession and select a recipe first." end
    return ("%s: relativeDifficulty=%s (%s)  numSkillUps=%s  canSkillUp=%s  list hooked=%s"):format(
        UI.Util.Escape(tostring(info.name)), tostring(info.relativeDifficulty), NAMES[info.relativeDifficulty] or "?",
        tostring(info.numSkillUps), tostring(info.canSkillUp), tostring(scrollBoxHooked))
end

------------------------------------------------------------------------
-- Skill-up chance and "can make (n)" after each recipe name
------------------------------------------------------------------------
-- The chance needs each recipe's yellow and gray skill, which the game doesn't hand out: they come from EverlookDB
-- Crafting (EverlookCraftAPI) when it is installed. Without it the row shows only the count. The count is how many
-- you can make from your bags; with "countMore" on, "+5" says how many more your bank and other characters allow.
local function CraftAPI()
    local api = rawget(_G, "EverlookCraftAPI")
    if api and (api.version or 0) >= 1 then return api end
end
ns.CraftAPI = CraftAPI

local function plain(v)
    if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function itemCount(id, bank)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return 0 end
    local ok, n = pcall(fn, id, bank and true or false)
    return ok and tonumber(plain(n)) or 0
end

-- the recipe's basic reagents: { { item, n } }, from EverlookDB Crafting or the window's schematic
local function Reagents(recipeID, api)
    local ok, r = pcall(function() return api and api.recipe(recipeID) end)
    r = ok and r or nil
    if r and r.mats and #r.mats > 0 then return r.mats end
    local T = C_TradeSkillUI
    if not (T and T.GetRecipeSchematic) then return nil end
    local okS, sch = pcall(T.GetRecipeSchematic, recipeID, false)
    if not okS or type(sch) ~= "table" then return nil end
    local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    local out = {}
    for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
        local re = slot.reagents and slot.reagents[1]
        local item = re and plain(re.itemID)
        if item and (basic == nil or slot.reagentType == nil or slot.reagentType == basic) then
            out[#out + 1] = { item, plain(slot.quantityRequired) or 1 }
        end
    end
    return #out > 0 and out or nil
end
ns.Reagents = Reagents

-- How many crafts the materials allow: from the bags, and with the bank and your other characters (EverlookDB
-- Crafting's count; without it the game's own bank count). nil when the reagents are unknown.
function ns.CanMake(mats, api)
    if not mats then return nil end
    local bags, more = math.huge, math.huge
    for _, m in ipairs(mats) do
        local id, n = m[1], math.max(1, m[2] or 1)
        local b = itemCount(id, false)
        local all
        local okS, st = pcall(function() return api and api.stock and api.stock(id) end)
        st = okS and st or nil
        if st then all = b + (st.bank or 0) + (st.alts or 0) else all = itemCount(id, true) end
        bags = math.min(bags, math.floor(b / n))
        more = math.min(more, math.floor(math.max(all, b) / n))
    end
    if bags == math.huge then return nil end
    return bags, more
end

-- your skill in the profession the window shows; nil, true for someone else's window (a link, a guild list)
local function SkillNow(recipeID)
    local T = C_TradeSkillUI
    if not T then return nil end
    for _, k in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        if T[k] then
            local ok, v = pcall(T[k])
            if ok and v then return nil, true end
        end
    end
    if T.GetProfessionInfoByRecipeID then
        local ok, p = pcall(T.GetProfessionInfoByRecipeID, recipeID)
        local s = ok and type(p) == "table" and plain(p.skillLevel)
        if s and s > 0 then return s end
    end
    if T.GetBaseProfessionInfo then
        local ok, p = pcall(T.GetBaseProfessionInfo)
        return ok and type(p) == "table" and plain(p.skillLevel) or nil
    end
end

local function hex(c) return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end

-- The text after a recipe name, or nil. info = the row's recipeInfo; label = the name as the game wrote it.
function ns.ExtraText(info, label)
    if not db or type(info) ~= "table" or info.isHeader then return nil end
    local id = plain(info.recipeID)
    if not id then return nil end
    local api = CraftAPI()
    local skill, notMine = SkillNow(id)
    if notMine then return nil end
    local parts = {}
    if db.showChance and api and skill then
        local okR, r = pcall(api.recipe, id)
        local okC, chance = pcall(api.chance, id, skill)
        r = okR and r or nil
        if r and okC and chance and chance > 0 and chance < 1 then
            local name = skill < (r.green or r.gray) and "yellow" or "green"
            parts[#parts + 1] = hex(db.colors[name] or { 1, 1, 1 }) .. math.floor(chance * 100 + 0.5) .. "%|r"
        end
    end
    if db.showCount then
        local bags, more = ns.CanMake(Reagents(id, api), api)
        if bags == nil then bags = tonumber(plain(info.numAvailable)) end
        -- the game already writes "[n]" after the name: don't say it twice
        local gameShows = type(label) == "string" and label:find("%[%d+%]%s*$") ~= nil
        local extra = (db.countMore and more and bags and more > bags) and (more - bags) or 0
        if bags and (bags > 0 or extra > 0) then
            local s
            if gameShows then
                s = extra > 0 and ("|cff8d94a3(+" .. extra .. ")|r") or nil
            else
                s = "|cffffffff(" .. bags .. (extra > 0 and (" |cff8d94a3+" .. extra .. "|cffffffff") or "") .. ")|r"
            end
            if s then parts[#parts + 1] = s end
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

function ns.Extras(frame)
    if not frame.Label or not frame.CreateFontString then return end
    local info = GetRecipeInfo(frame)
    local textOf = frame.Label.GetText and frame.Label:GetText()
    local ok, t = pcall(ns.ExtraText, info, textOf)
    t = ok and t or nil
    if not t then
        if frame.ccExtra then frame.ccExtra:Hide() end
        return
    end
    local fs = frame.ccExtra
    if not fs then
        fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        frame.ccExtra = fs
    end
    fs:SetText(t)
    -- right after the name; never past the label's right edge
    local nameW = frame.Label.GetStringWidth and frame.Label:GetStringWidth() or 0
    local labelW = frame.Label.GetWidth and frame.Label:GetWidth() or nameW
    local extraW = fs.GetStringWidth and fs:GetStringWidth() or 30
    if not labelW or labelW <= 0 then labelW = nameW + extraW + 8 end
    local x = math.max(0, math.min(nameW, labelW - extraW - 4))
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", frame.Label, "LEFT", x + 4, 0)
    fs:Show()
end

-- counts change as bags do: refresh an open window (once per half second at most)
local bagsPending = false
local function BagsChanged()
    if bagsPending or not db then return end
    bagsPending = true
    C_Timer.After(0.5, function()
        bagsPending = false
        if ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown() then ns.Apply() end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "BAG_UPDATE_DELAYED" then BagsChanged() return end
    if event == "ADDON_LOADED" and arg1 == ADDON then
        CraftColorsDB = UI.Util.FillDefaults(type(CraftColorsDB) == "table" and CraftColorsDB or {}, ns.DEFAULTS)
        db = CraftColorsDB
        ns.db = db
    end
    if event == "ADDON_LOADED" and (arg1 == "Blizzard_TradeSkillUI" or arg1 == "Blizzard_CraftUI" or arg1 == ADDON) then
        TryHookClassic()
    end
    if event == "ADDON_LOADED" and arg1 ~= "Blizzard_Professions" and arg1 ~= ADDON then return end
    if TryHookProfessions() and event ~= "ADDON_LOADED" then
        RefreshAll(RecipeScrollBox())
    end
end)

------------------------------------------------------------------------
-- Settings window, chat commands and the Settings > AddOns entry
------------------------------------------------------------------------
local app = UI:NewApp({
    name = "CraftColors",
    addon = ADDON,
    slash = "/ccolors",
    aliases = { "/craftcolors" },
    tagline = "Colours recipe names in the profession window by how likely they are to give a skill-up.",
    accent = { 1.00, 0.50, 0.25 },
    height = 520,
    position = function() return db end,
    feedbackURL = "https://everlookdb.com/craftcolors.html#feedback",
})
ns.app = app

local function after() ns.Apply() end

app:Setting({
    key = "enabled", type = "bool", label = "Colour recipe names", keywords = { "color", "on", "off", "difficulty" },
    desc = "Off: recipe names keep the game's own colour.",
    get = function() return db.enabled end, set = function(v) db.enabled = v end, after = after,
})
for _, name in ipairs(ORDER) do
    app:Setting({
        key = name, type = "color", label = LABELS[name], keywords = { "colour", "color", "difficulty", "skill-up" },
        get = function() return db.colors[name] end,
        set = function(v) db.colors[name] = { v[1], v[2], v[3] } end,
        disabled = function() return not db.enabled end,
        after = after,
    })
end
app:Setting({
    key = "hover", type = "number", label = "Brighten the row under the mouse", min = 0, max = 0.5, step = 0.05,
    keywords = { "highlight", "mouseover", "brightness", "lighter" },
    desc = "How much lighter a recipe name gets while the mouse is over it, so the highlight still reads.",
    get = function() return db.hoverBoost end, set = function(v) db.hoverBoost = v end,
    disabled = function() return not db.enabled end, after = after,
})

app:Setting({
    key = "chance", type = "bool", label = "Skill-up chance after yellow and green recipes",
    keywords = { "chance", "percent", "skill-up", "odds", "probability" },
    desc = "\"37%\": the chance that one craft raises your skill. Needs EverlookDB Crafting (it knows each recipe's yellow and gray skill).",
    get = function() return db.showChance end, set = function(v) db.showChance = v end, after = after,
})
app:Setting({
    key = "count", type = "bool", label = "How many you can make",
    keywords = { "count", "can make", "materials", "reagents", "bags", "number" },
    desc = "\"(4)\": how many your bags have the materials for.",
    get = function() return db.showCount end, set = function(v) db.showCount = v end, after = after,
})
app:Setting({
    key = "countmore", type = "bool", label = "Also count my bank and other characters",
    keywords = { "bank", "alts", "twinks", "count", "more" },
    desc = "\"(4 +5)\": 5 more with your bank and your other characters' materials (EverlookDB Crafting counts those; without it, only your bank).",
    get = function() return db.countMore end, set = function(v) db.countMore = v end,
    disabled = function() return not db.showCount end, after = after,
})

function ns.ResetColors()
    db.colors = UI.Util.CopyTable(ns.DEFAULTS.colors)
    db.hoverBoost = ns.DEFAULTS.hoverBoost
    ns.Apply()
    app:Refresh()
end

-- /ccolors on, off, toggle: the colouring. /ccolors reset asks first, then puts the colours back.
app:OnOff({ label = "Recipe colours", get = function() return db.enabled end,
    set = function(v) db.enabled = v; ns.Apply() end })
app:Reset(nil, "the colours", function() ns.ResetColors() end)
-- Developer check, kept out of the settings window: /ccolors debug (the old /ccolors check still works).
app:Command("debug", "debug", "what the game says about the selected recipe (for bug reports)", function()
    app:Print(ns.CheckText())
end, { "check" })

app:Section("main", "CraftColors", function(stack)
    UI.Header(stack, "Recipe colours", "Open a profession: each recipe name shows how likely it is to raise your skill.")
    app:Widget(stack, "enabled")
    stack:Space(4)
    for _, name in ipairs(ORDER) do app:Widget(stack, name) end
    app:Widget(stack, "hover")
    UI.Header(stack, "After each recipe", "Skill-up chance and how many you can make, next to the name.")
    app:Widget(stack, "chance")
    app:Widget(stack, "count")
    app:Widget(stack, "countmore")
    UI.Stat(stack, "EverlookDB Crafting", function()
        return CraftAPI() and "|cff62cf88found|r: chance, and counts with your other characters" or "|cff8d94a3not installed|r: counts from your bags and bank, no chance"
    end)
    stack:Space(4)
    UI.ButtonRow(stack, {
        { label = "Back to default colours", width = 200, confirm = true, onClick = function() ns.ResetColors() end,
            keywords = { "reset", "defaults", "colors" } },
    })
end)

app:RegisterSlash("CRAFTCOLORS") -- /ccolors, also /craftcolors
