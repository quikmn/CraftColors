-- CraftColors: tint recipe names in ProfessionsFrame by relative difficulty.
-- Orange = guaranteed skill-up, yellow = likely, green = rare, gray = none.
-- /craftcolors opens the settings window; /craftcolors help lists the commands.

local ADDON, ns = ...
local UI = LibStub("EverlookUI-1")

-- Default colours (Blizzard's own skill-up colours) and settings.
ns.DEFAULTS = {
    version = 1,
    enabled = true,
    hoverBoost = 0.2, -- brighten the hovered row this much so the highlight still reads
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

local function Recolor(frame)
    if not db or not frame.Label then return end
    if not db.enabled then
        -- put back the label's own colour (saved before we first tinted it)
        local o = frame.ccOrigColor
        if o then frame.Label:SetTextColor(o[1], o[2], o[3]) end
        return
    end
    local info = GetRecipeInfo(frame)
    if not info then return end
    if not frame.ccOrigColor and frame.Label.GetTextColor then
        local r, g, b = frame.Label:GetTextColor()
        if r then frame.ccOrigColor = { r, g, b } end
    end
    local c = ns.ColorFor(info.relativeDifficulty)
    if not c then return end
    if frame.IsMouseOver and frame:IsMouseOver() then
        local b = db.hoverBoost or 0
        frame.Label:SetTextColor(math.min(c[1] + b, 1), math.min(c[2] + b, 1), math.min(c[3] + b, 1))
    else
        frame.Label:SetTextColor(c[1], c[2], c[3])
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

-- Recolour an open profession window right away after a setting changes (turning it off puts the
-- game's own colours back).
function ns.Apply()
    local scrollBox = scrollBoxHooked and RecipeScrollBox()
    if scrollBox then RefreshAll(scrollBox) end
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

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        CraftColorsDB = UI.Util.FillDefaults(type(CraftColorsDB) == "table" and CraftColorsDB or {}, ns.DEFAULTS)
        db = CraftColorsDB
        ns.db = db
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
    UI.ButtonRow(stack, {
        { label = "Back to default colours", width = 200, confirm = true, onClick = function() ns.ResetColors() end,
            keywords = { "reset", "defaults", "colors" } },
    })
end)

app:RegisterSlash("CRAFTCOLORS") -- /ccolors, also /craftcolors
