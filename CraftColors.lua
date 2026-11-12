-- CraftColors: tint recipe names in ProfessionsFrame by relative difficulty.
-- Orange = guaranteed skill-up, yellow = likely, green = rare, gray = none.

local ADDON = ...

local COLORS = {
    [0] = { 1.00, 0.50, 0.25 }, -- Optimal (orange)
    [1] = { 1.00, 1.00, 0.00 }, -- Medium  (yellow)
    [2] = { 0.25, 0.75, 0.25 }, -- Easy    (green)
    [3] = { 0.50, 0.50, 0.50 }, -- Trivial (gray)
}
local NAMES = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "gray" }

-- Prefer the live enum values in case the client numbers them differently.
local D = Enum and Enum.TradeskillRelativeDifficulty
if D then
    COLORS = {
        [D.Optimal] = COLORS[0], [D.Medium] = COLORS[1],
        [D.Easy] = COLORS[2],    [D.Trivial] = COLORS[3],
    }
    NAMES = {
        [D.Optimal] = "orange", [D.Medium] = "yellow",
        [D.Easy] = "green",     [D.Trivial] = "gray",
    }
end

local function GetRecipeInfo(frame)
    if not frame.GetElementData then return end
    local node = frame:GetElementData()
    local data = node and node.GetData and node:GetData()
    return data and data.recipeInfo
end

local function Recolor(frame)
    local info = GetRecipeInfo(frame)
    if not info or not frame.Label then return end
    local c = COLORS[info.relativeDifficulty]
    if not c then return end
    if frame.IsMouseOver and frame:IsMouseOver() then
        -- brighten a bit on hover so the highlight still reads
        frame.Label:SetTextColor(math.min(c[1] + 0.2, 1), math.min(c[2] + 0.2, 1), math.min(c[3] + 0.2, 1))
    else
        frame.Label:SetTextColor(c[1], c[2], c[3])
    end
end

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
local function TryHookProfessions()
    if scrollBoxHooked then return true end
    local list = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
    local scrollBox = list and list.ScrollBox
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

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= "Blizzard_Professions" and arg1 ~= ADDON then return end
    if TryHookProfessions() and event ~= "ADDON_LOADED" then
        RefreshAll(ProfessionsFrame.CraftingPage.RecipeList.ScrollBox)
    end
end)

-- /craftcolors : print the difficulty data for the selected recipe (for debugging).
SLASH_CRAFTCOLORS1 = "/craftcolors"
SlashCmdList.CRAFTCOLORS = function()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    local info = form and form.GetRecipeInfo and form:GetRecipeInfo()
    if not info then
        print("|cffff8040CraftColors|r: open a profession and select a recipe first.")
        return
    end
    print(("|cffff8040CraftColors|r: %s  relativeDifficulty=%s (%s)  numSkillUps=%s  canSkillUp=%s  hooked=%s"):format(
        tostring(info.name), tostring(info.relativeDifficulty), NAMES[info.relativeDifficulty] or "?",
        tostring(info.numSkillUps), tostring(info.canSkillUp), tostring(scrollBoxHooked)))
end
