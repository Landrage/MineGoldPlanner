-- ============================================================================
-- Mine Gold Planner
-- Daily Goal Settings
-- ============================================================================

local UI = MineGoldPlanner.UI

-- ============================================================================
-- Window
-- ============================================================================

UI.SettingsFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
local settingsFrame = UI.SettingsFrame

settingsFrame:SetSize(230, 150)
settingsFrame:SetPoint("CENTER")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetClampedToScreen(true)
settingsFrame:SetFrameStrata("DIALOG")
settingsFrame:SetToplevel(true)

settingsFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = {
        left = 8,
        right = 8,
        top = 8,
        bottom = 8
    }
})

settingsFrame:Hide()

settingsFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

settingsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    MineGoldPlanner.SaveFramePosition(self, "settings")
end)

local closeButton = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)
closeButton:SetScript("OnClick", function()
    settingsFrame:Hide()
end)

local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -20)
title:SetText("Change Daily Goal")

-- ============================================================================
-- Goal Controls
-- ============================================================================

local goalLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
goalLabel:SetPoint("TOPLEFT", 20, -55)
goalLabel:SetText("Daily Goal")

local goalEditBox = CreateFrame("EditBox", nil, settingsFrame, "InputBoxTemplate")

goalEditBox:SetSize(120, 25)
goalEditBox:SetPoint("TOPLEFT", goalLabel, "BOTTOMLEFT", 0, -8)

goalEditBox:SetAutoFocus(false)
goalEditBox:SetNumeric(true)
goalEditBox:SetMaxLetters(10)

local saveButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
saveButton:SetSize(80, 24)
saveButton:SetPoint("BOTTOM", 0, 20)
saveButton:SetText("Save")

local function SaveSettings()
    local goal = goalEditBox:GetNumber()

    if goal <= 0 then
        print("Mine Gold Planner: goal must be greater than 0.")
        goalEditBox:SetFocus()
        goalEditBox:HighlightText()
        return
    end

    MineGoldPlannerDB.goal = goal
    MineGoldPlannerDB.autoProcessedGoals = 0
    MineGoldPlannerDB.autoClosedDaysToday = {}

    if MineGoldPlanner.UpdateUI then
        MineGoldPlanner.UpdateUI()
    end

    settingsFrame:Hide()
end

saveButton:SetScript("OnClick", SaveSettings)

goalEditBox:SetScript("OnEnterPressed", function(self)
    SaveSettings()
    self:ClearFocus()
end)

goalEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    settingsFrame:Hide()
end)

function MineGoldPlanner.OpenSettings()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        goalEditBox:SetNumber(MineGoldPlannerDB.goal)
        settingsFrame:Show()
        settingsFrame:Raise()
        goalEditBox:SetFocus()
        goalEditBox:HighlightText()
    end
end
