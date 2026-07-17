-- ============================================================================
-- Mine Gold Planner
-- Daily Goal Tracker
-- ============================================================================

local UI = MineGoldPlanner.UI

-- ============================================================================
-- Window
-- ============================================================================

UI.TrackerFrame = CreateFrame("Frame", "MineGoldPlannerTrackerFrame", UIParent, "BackdropTemplate")
local trackerFrame = UI.TrackerFrame

table.insert(UISpecialFrames, "MineGoldPlannerTrackerFrame")

trackerFrame:SetSize(480, 285)
trackerFrame:SetPoint("CENTER")
trackerFrame:SetMovable(true)
trackerFrame:EnableMouse(true)
trackerFrame:RegisterForDrag("LeftButton")
trackerFrame:SetClampedToScreen(true)
trackerFrame:SetFrameStrata("DIALOG")
trackerFrame:SetToplevel(true)

trackerFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

trackerFrame:Hide()

trackerFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

trackerFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    MineGoldPlanner.SaveFramePosition(self, "tracker")
end)

local closeButton = CreateFrame("Button", nil, trackerFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)
closeButton:SetScript("OnClick", function()
    trackerFrame:Hide()
end)

local title = trackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -20)
title:SetText("Daily Goals")

local subtitle = trackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
subtitle:SetText("Completed daily goals are checked automatically")

local checkButtons = {}
local monthNames = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
}
local viewedYear = tonumber(date("%Y"))
local viewedMonth = tonumber(date("%m"))

local function GetMonthKey(year, month)
    return string.format("%04d-%02d", year, month)
end

local function GetMonthIndex(year, month)
    return year * 12 + month
end

local function GetDaysInMonth(year, month)
    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    local isLeapYear = year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0)

    if isLeapYear then
        daysInMonth[2] = 29
    end

    return daysInMonth[month]
end

local function UpdateDayAppearance(checkButton, currentDay)
    if checkButton:GetChecked() then
        checkButton.label:SetTextColor(0.2, 1, 0.2)
    elseif checkButton.day < currentDay then
        checkButton.label:SetTextColor(1, 0.25, 0.25)
    else
        checkButton.label:SetTextColor(1, 0.82, 0)
    end
end

-- ============================================================================
-- Month Navigation
-- ============================================================================

local previousMonthButton = CreateFrame("Button", nil, trackerFrame, "UIPanelButtonTemplate")
previousMonthButton:SetSize(28, 22)
previousMonthButton:SetPoint("BOTTOMLEFT", 20, 16)
previousMonthButton:SetText("<")

local viewedMonthText = trackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
viewedMonthText:SetPoint("LEFT", previousMonthButton, "RIGHT", 8, 0)
viewedMonthText:SetWidth(105)
viewedMonthText:SetJustifyH("CENTER")

local nextMonthButton = CreateFrame("Button", nil, trackerFrame, "UIPanelButtonTemplate")
nextMonthButton:SetSize(28, 22)
nextMonthButton:SetPoint("LEFT", viewedMonthText, "RIGHT", 8, 0)
nextMonthButton:SetText(">")

-- ============================================================================
-- Day Checkboxes
-- ============================================================================

for day = 1, 31 do
    local column = (day - 1) % 7
    local row = math.floor((day - 1) / 7)
    local checkButton = CreateFrame("CheckButton", nil, trackerFrame, "UICheckButtonTemplate")

    checkButton:SetSize(26, 26)
    checkButton:SetPoint("TOPLEFT", 20 + column * 64, -78 - row * 36)
    checkButton.day = day

    local label = checkButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkButton, "RIGHT", 1, 0)
    label:SetText(day)
    checkButton.label = label

    checkButton:SetScript("OnClick", function(self)
        local monthKey = GetMonthKey(viewedYear, viewedMonth)
        local completedDays = MineGoldPlannerDB.completedDaysByMonth[monthKey]

        completedDays[self.day] = self:GetChecked() and true or nil
        UpdateDayAppearance(self, MineGoldPlanner.GetCurrentDay())

        if monthKey == MineGoldPlanner.GetMonthKey() and MineGoldPlanner.UpdateUI then
            MineGoldPlanner.UpdateUI()
        end
    end)

    checkButton:SetScript("OnEnter", function(self)
        local isChecked = self:GetChecked()
        local status = isChecked and "Completed" or "Not completed"
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label:GetText())
        GameTooltip:AddLine(status, isChecked and 0.2 or 1, isChecked and 1 or 0.3, 0.2)
        GameTooltip:Show()
    end)

    checkButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    checkButtons[day] = checkButton
end

local function RefreshTracker()
    MineGoldPlannerDB.completedDaysByMonth = MineGoldPlannerDB.completedDaysByMonth or {}

    local viewedMonthKey = GetMonthKey(viewedYear, viewedMonth)
    local currentMonthKey = MineGoldPlanner.GetMonthKey()
    local viewedIndex = GetMonthIndex(viewedYear, viewedMonth)
    local currentYear = tonumber(date("%Y"))
    local currentMonth = tonumber(date("%m"))
    local currentIndex = GetMonthIndex(currentYear, currentMonth)
    local currentDay = MineGoldPlanner.GetCurrentDay()
    local daysInMonth = GetDaysInMonth(viewedYear, viewedMonth)

    MineGoldPlannerDB.completedDaysByMonth[viewedMonthKey] =
        MineGoldPlannerDB.completedDaysByMonth[viewedMonthKey] or {}

    local completedDays = MineGoldPlannerDB.completedDaysByMonth[viewedMonthKey]
    viewedMonthText:SetText(monthNames[viewedMonth] .. " " .. viewedYear)

    if viewedIndex <= currentIndex - 12 then
        previousMonthButton:Disable()
    else
        previousMonthButton:Enable()
    end

    if viewedIndex >= currentIndex + 12 then
        nextMonthButton:Disable()
    else
        nextMonthButton:Enable()
    end

    for day = 1, 31 do
        local checkButton = checkButtons[day]

        if day <= daysInMonth then
            checkButton:Show()
            checkButton.label:SetText(string.format("%02d.%02d", day, viewedMonth))
            checkButton:SetChecked(completedDays[day] == true)

            if viewedIndex < currentIndex then
                checkButton:Disable()

                if completedDays[day] then
                    checkButton.label:SetTextColor(0.2, 1, 0.2)
                else
                    checkButton.label:SetTextColor(0.5, 0.5, 0.5)
                end
            elseif viewedMonthKey == currentMonthKey and day <= currentDay then
                checkButton:Enable()
                UpdateDayAppearance(checkButton, currentDay)
            else
                checkButton:Disable()
                checkButton.label:SetTextColor(0.5, 0.5, 0.5)
            end
        else
            checkButton:Hide()
        end
    end
end

previousMonthButton:SetScript("OnClick", function()
    viewedMonth = viewedMonth - 1

    if viewedMonth < 1 then
        viewedMonth = 12
        viewedYear = viewedYear - 1
    end

    RefreshTracker()
end)

nextMonthButton:SetScript("OnClick", function()
    viewedMonth = viewedMonth + 1

    if viewedMonth > 12 then
        viewedMonth = 1
        viewedYear = viewedYear + 1
    end

    RefreshTracker()
end)

MineGoldPlanner.RefreshTracker = RefreshTracker

function MineGoldPlanner.OpenTracker()
    if trackerFrame:IsShown() then
        trackerFrame:Hide()
    else
        viewedYear = tonumber(date("%Y"))
        viewedMonth = tonumber(date("%m"))
        RefreshTracker()
        trackerFrame:Show()
        trackerFrame:Raise()
    end
end
