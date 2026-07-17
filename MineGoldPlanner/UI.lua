-- ============================================================================
-- Mine Gold Planner
-- User Interface
-- ============================================================================

local UI = MineGoldPlanner.UI

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function FormatMoney(money)
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100

    return string.format("%dg %ds %dc", gold, silver, copper)
end

-- ============================================================================
-- Planner Calculations
-- ============================================================================

local function GetGoal()
    if MineGoldPlannerDB and type(MineGoldPlannerDB.goal) == "number" then
        return MineGoldPlannerDB.goal
    end

    return 5000
end

local function GetDays()
    local daysInMonth = MineGoldPlanner.GetDaysInCurrentMonth()
    local completedDays = MineGoldPlanner.GetCompletedDaysCount()
    return math.max(daysInMonth - completedDays, 0)
end

local GetRemainingToday

local function GetMonthRemaining(remainingToday, extraToday)
    local daysInMonth = MineGoldPlanner.GetDaysInCurrentMonth()
    local currentDay = MineGoldPlanner.GetCurrentDay()
    local completedDays = MineGoldPlannerDB and MineGoldPlannerDB.completedDays or {}
    local dailyGoalCopper = GetGoal() * 10000
    local futureRemaining = 0

    for day = currentDay + 1, daysInMonth do
        if not completedDays[day] then
            futureRemaining = futureRemaining + dailyGoalCopper
        end
    end

    return math.max(futureRemaining + remainingToday - extraToday, 0)
end

GetRemainingToday = function()
    local earnedToday = MineGoldPlanner.UpdateDailyEarnings()
    local dailyGoalCopper = GetGoal() * 10000
    local currentDay = MineGoldPlanner.GetCurrentDay()
    local completedDays = MineGoldPlannerDB and MineGoldPlannerDB.completedDays or {}
    local uncompletedDays = 0

    for day = 1, currentDay do
        if not completedDays[day] then
            uncompletedDays = uncompletedDays + 1
        end
    end

    local autoClosedDays = MineGoldPlannerDB and MineGoldPlannerDB.autoClosedDaysToday or {}
    local closedToday = 0

    for _ in pairs(autoClosedDays) do
        closedToday = closedToday + 1
    end

    local availableEarnings = math.max(earnedToday - closedToday * dailyGoalCopper, 0)
    local outstandingGoals = uncompletedDays * dailyGoalCopper
    local remainingToday = math.max(outstandingGoals - availableEarnings, 0)
    local extraToday = math.max(availableEarnings - outstandingGoals, 0)
    return remainingToday, extraToday
end

UI.MainFrame = CreateFrame("Frame", "MineGoldPlannerFrame", UIParent, "BackdropTemplate")
local MainFrame = UI.MainFrame
local shutdownInProgress = false

table.insert(UISpecialFrames, "MineGoldPlannerFrame")

-- ============================================================================
-- Main Window
-- ============================================================================

MainFrame:SetSize(400, 280)
MainFrame:SetPoint("CENTER")

MainFrame:SetBackdrop({
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

MainFrame:Hide()
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetClampedToScreen(true)

local closeButton = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)
closeButton:SetScript("OnClick", function()
    MainFrame:Hide()
end)

MainFrame:SetScript("OnShow", function()
    if MineGoldPlannerDB then
        MineGoldPlannerDB.mainVisible = true
    end
end)

MainFrame:SetScript("OnHide", function()
    if MineGoldPlannerDB and not shutdownInProgress and UIParent:IsShown() then
        MineGoldPlannerDB.mainVisible = false
    end
end)

-- ============================================================================
-- Reload Button
-- ============================================================================

UI.ReloadButton = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")

UI.ReloadButton:SetSize(60, 22)
UI.ReloadButton:SetPoint("BOTTOMRIGHT", -15, 15)

UI.ReloadButton:SetText("Reload")

UI.ReloadButton:SetScript("OnClick", function()
    ReloadUI()
end)

-- ============================================================================
-- Reset Today Button
-- ============================================================================

StaticPopupDialogs["MINE_GOLD_PLANNER_RESET_TODAY"] = {
    text = "Reset today's progress?\n\nAutomatically completed goals from today will be undone. This cannot be reversed.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        MineGoldPlanner.ResetToday()
        MineGoldPlanner.UpdateUI()

        if UI.TrackerFrame:IsShown() and MineGoldPlanner.RefreshTracker then
            MineGoldPlanner.RefreshTracker()
        end

    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

UI.ResetTodayButton = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
UI.ResetTodayButton:SetSize(90, 22)
UI.ResetTodayButton:SetPoint("BOTTOMLEFT", 15, 15)
UI.ResetTodayButton:SetText("Reset Today")

UI.ResetTodayButton:SetScript("OnClick", function()
    StaticPopup_Show("MINE_GOLD_PLANNER_RESET_TODAY")
end)

UI.ResetTodayButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Reset Today")
    GameTooltip:AddLine("Clear today's tracked earnings and start again from the current balance.", 1, 1, 1, true)
    GameTooltip:Show()
end)

UI.ResetTodayButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ============================================================================
-- Settings Button
-- ============================================================================

UI.SettingsButton = CreateFrame("Button", nil, MainFrame)

UI.SettingsButton:SetSize(26, 26)
UI.SettingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
UI.SettingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

UI.SettingsButton:SetScript("OnClick", function()
    if MineGoldPlanner.OpenSettings then
        MineGoldPlanner.OpenSettings()
    end
end)

UI.SettingsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Change Goal")
    GameTooltip:Show()
end)

UI.SettingsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

UI.TrackerButton = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
UI.TrackerButton:SetSize(55, 22)
UI.TrackerButton:SetText("Days")

UI.TrackerButton:SetScript("OnClick", function()
    if MineGoldPlanner.OpenTracker then
        MineGoldPlanner.OpenTracker()
    end
end)

-- ============================================================================
-- Window Dragging
-- ============================================================================

MainFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

MainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    MineGoldPlanner.SaveFramePosition(self, "main")
end)

-- ============================================================================
-- UI Elements
-- ============================================================================

local function CreateLabel(yOffset)
    local text = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 20, yOffset)
    return text
end

UI.Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UI.Title:SetPoint("TOP", 0, -20)
UI.Title:SetText("Mine Gold Planner")

UI.GoldText = CreateLabel(-60)
UI.GoalText = CreateLabel(-90)
UI.CompletedText = CreateLabel(-120)
UI.DaysText = CreateLabel(-150)
UI.RemainingTodayText = CreateLabel(-180)
UI.MonthRemainingText = CreateLabel(-210)

UI.SettingsButton:SetPoint("LEFT", UI.GoalText, "RIGHT", 8, 0)
UI.TrackerButton:SetPoint("LEFT", UI.CompletedText, "RIGHT", 8, 0)

-- ============================================================================
-- Update Functions
-- ============================================================================

local function UpdateMonthRemaining(remainingToday, extraToday)
    local remaining = GetMonthRemaining(remainingToday, extraToday)
    UI.MonthRemainingText:SetText("Month Remaining: " .. FormatMoney(remaining))

    if remaining > 0 then
        UI.MonthRemainingText:SetTextColor(1, 0.35, 0.2)
    else
        UI.MonthRemainingText:SetTextColor(0.2, 1, 0.2)
    end
end

local function UpdateRemainingToday(remainingToday, extraToday)
    if extraToday > 0 then
        UI.RemainingTodayText:SetText("Remaining Today: 0g | Extra Today: " .. FormatMoney(extraToday))
        UI.RemainingTodayText:SetTextColor(0.2, 1, 0.2)
    else
        UI.RemainingTodayText:SetText("Remaining Today: " .. FormatMoney(remainingToday))

        if remainingToday > 0 then
            UI.RemainingTodayText:SetTextColor(1, 0.35, 0.2)
        else
            UI.RemainingTodayText:SetTextColor(0.2, 1, 0.2)
        end
    end
end

local function UpdateGold()
    UI.GoldText:SetText("Money: " .. FormatMoney(GetMoney()))
end

local function UpdateGoal()
    UI.GoalText:SetText("Daily Goal: " .. GetGoal() .. "g")
end

local function UpdateDays()
    UI.DaysText:SetText("Uncompleted Days: " .. GetDays())
end

local function UpdateCompleted()
    local completed = MineGoldPlanner.GetCompletedDaysCount()
    local currentDay = MineGoldPlanner.GetCurrentDay()
    UI.CompletedText:SetText("Completed Days: " .. completed .. "/" .. currentDay)

    if completed >= currentDay then
        UI.CompletedText:SetTextColor(0.2, 1, 0.2)
    else
        UI.CompletedText:SetTextColor(1, 0.65, 0.2)
    end
end

-- ============================================================================
-- Events
-- ============================================================================

MainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
MainFrame:RegisterEvent("PLAYER_MONEY")
MainFrame:RegisterEvent("PLAYER_LOGOUT")

MainFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        -- PLAYER_LOGOUT also fires for /reload, before WoW hides all frames.
        shutdownInProgress = true
        MineGoldPlannerDB.mainVisible = MainFrame:IsShown()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Restore visibility only after the world and UI are fully available.
        MineGoldPlanner.SetCurrentMoneyBaseline()

        if MineGoldPlannerDB.mainVisible ~= false then
            MainFrame:Show()
        else
            MainFrame:Hide()
        end

        MineGoldPlanner.UpdateUI()

    elseif event == "PLAYER_MONEY" then
        MineGoldPlanner.UpdateUI()

    end
end)

function MineGoldPlanner.UpdateUI()
    local remainingToday, extraToday = GetRemainingToday()

    UpdateGold()
    UpdateGoal()
    UpdateRemainingToday(remainingToday, extraToday)
    UpdateCompleted()
    UpdateMonthRemaining(remainingToday, extraToday)
    UpdateDays()
end

local calendarUpdateElapsed = 0

-- Refresh the date-dependent values while the player stays online at midnight.
MainFrame:SetScript("OnUpdate", function(_, elapsed)
    calendarUpdateElapsed = calendarUpdateElapsed + elapsed

    if calendarUpdateElapsed >= 60 then
        calendarUpdateElapsed = 0
        MineGoldPlanner.RefreshDateState()
        MineGoldPlanner.UpdateUI()

        if UI.TrackerFrame:IsShown() and MineGoldPlanner.RefreshTracker then
            MineGoldPlanner.RefreshTracker()
        end
    end
end)

-- ============================================================================
-- Minimap Button
-- ============================================================================

UI.MinimapButton = CreateFrame("Button", "MineGoldPlannerMinimapButton", Minimap)

UI.MinimapButton:SetSize(32, 32)
UI.MinimapButton:SetFrameStrata("MEDIUM")
UI.MinimapButton:SetFrameLevel(8)

UI.MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

local minimapIcon = UI.MinimapButton:CreateTexture(nil, "ARTWORK")
minimapIcon:SetSize(18, 18)
minimapIcon:SetPoint("CENTER", 0, 0)
minimapIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")

local border = UI.MinimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT", UI.MinimapButton, "TOPLEFT", 0, 0)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapButtonPosition(angle)
    local radius = 80
    UI.MinimapButton:ClearAllPoints()
    UI.MinimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

MineGoldPlanner.UpdateMinimapButtonPosition = UpdateMinimapButtonPosition

UpdateMinimapButtonPosition(MineGoldPlannerDB and MineGoldPlannerDB.minimapAngle or 2.4)

UI.MinimapButton:RegisterForClicks("LeftButtonUp")
UI.MinimapButton:RegisterForDrag("LeftButton")

UI.MinimapButton:SetScript("OnClick", function()
    if MainFrame:IsShown() then
        MainFrame:Hide()
    else
        MainFrame:Show()
    end
end)

UI.MinimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Mine Gold Planner")
    GameTooltip:AddLine("Click to show or hide", 1, 1, 1)
    GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

UI.MinimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

UI.MinimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local minimapX, minimapY = Minimap:GetCenter()
        local angle = math.atan2(cursorY / scale - minimapY, cursorX / scale - minimapX)
        UpdateMinimapButtonPosition(angle)

        if MineGoldPlannerDB then
            MineGoldPlannerDB.minimapAngle = angle
        end
    end)
end)

UI.MinimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)
