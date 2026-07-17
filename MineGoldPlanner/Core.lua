-- ============================================================================
-- Mine Gold Planner
-- Core
-- ============================================================================

MineGoldPlanner = MineGoldPlanner or {}
MineGoldPlanner.UI = MineGoldPlanner.UI or {}

-- ============================================================================
-- Calendar
-- ============================================================================

local function GetCalendarInfo()
    local today = date("*t")
    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

    local isLeapYear = today.year % 400 == 0
        or (today.year % 4 == 0 and today.year % 100 ~= 0)

    if isLeapYear then
        daysInMonth[2] = 29
    end

    return today, daysInMonth[today.month]
end

function MineGoldPlanner.GetDaysInCurrentMonth()
    local _, daysInMonth = GetCalendarInfo()
    return daysInMonth
end

function MineGoldPlanner.GetCurrentDay()
    local today = GetCalendarInfo()
    return today.day
end

function MineGoldPlanner.GetMonthKey()
    local today = GetCalendarInfo()
    return string.format("%04d-%02d", today.year, today.month)
end

function MineGoldPlanner.GetCompletedDaysCount()
    local completedDays = MineGoldPlannerDB and MineGoldPlannerDB.completedDays or {}
    local count = 0

    for _, completed in pairs(completedDays) do
        if completed then
            count = count + 1
        end
    end

    return count
end

-- ============================================================================
-- Window Positions
-- ============================================================================

function MineGoldPlanner.SaveFramePosition(frame, key)
    if not MineGoldPlannerDB or not frame then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    MineGoldPlannerDB.windowPositions = MineGoldPlannerDB.windowPositions or {}
    MineGoldPlannerDB.windowPositions[key] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end

function MineGoldPlanner.RestoreFramePosition(frame, key)
    local positions = MineGoldPlannerDB and MineGoldPlannerDB.windowPositions
    local position = positions and positions[key]

    if not frame or not position then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or position.point or "CENTER",
        position.x or 0,
        position.y or 0
    )
end

-- ============================================================================
-- Daily Gold Tracking
-- ============================================================================

local moneyBaselineReady = false

local function GetCharacterKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
end

local function PrepareDailyTracking()
    local todayKey = date("%Y-%m-%d")
    local monthKey = MineGoldPlanner.GetMonthKey()
    local today = date("*t")
    local currentMonthIndex = today.year * 12 + today.month

    MineGoldPlannerDB.completedDaysByMonth = MineGoldPlannerDB.completedDaysByMonth or {}

    -- Keep only one year of history and one year of future calendar data.
    for savedMonthKey in pairs(MineGoldPlannerDB.completedDaysByMonth) do
        local year, month

        if type(savedMonthKey) == "string" then
            year, month = savedMonthKey:match("^(%d%d%d%d)%-(%d%d)$")
        end

        local savedMonthIndex = year and (tonumber(year) * 12 + tonumber(month))

        if not savedMonthIndex or math.abs(savedMonthIndex - currentMonthIndex) > 12 then
            MineGoldPlannerDB.completedDaysByMonth[savedMonthKey] = nil
        end
    end

    if MineGoldPlannerDB.monthKey ~= monthKey then
        MineGoldPlannerDB.monthKey = monthKey
        MineGoldPlannerDB.completedDaysByMonth[monthKey] =
            MineGoldPlannerDB.completedDaysByMonth[monthKey] or {}
        MineGoldPlannerDB.completedDays = MineGoldPlannerDB.completedDaysByMonth[monthKey]
    end

    if MineGoldPlannerDB.dailyDate ~= todayKey then
        MineGoldPlannerDB.dailyDate = todayKey
        MineGoldPlannerDB.earnedToday = 0
        MineGoldPlannerDB.dayStartMoney = {}
        MineGoldPlannerDB.dayPeakMoney = {}
        MineGoldPlannerDB.characterEarnings = {}
        MineGoldPlannerDB.autoProcessedGoals = 0
        MineGoldPlannerDB.autoClosedDaysToday = {}
    end

    MineGoldPlannerDB.earnedToday = MineGoldPlannerDB.earnedToday or 0
    MineGoldPlannerDB.dayStartMoney = MineGoldPlannerDB.dayStartMoney or {}
    MineGoldPlannerDB.dayPeakMoney = MineGoldPlannerDB.dayPeakMoney or {}
    MineGoldPlannerDB.characterEarnings = MineGoldPlannerDB.characterEarnings or {}
    MineGoldPlannerDB.autoProcessedGoals = MineGoldPlannerDB.autoProcessedGoals or 0
    MineGoldPlannerDB.autoClosedDaysToday = MineGoldPlannerDB.autoClosedDaysToday or {}
end

MineGoldPlanner.RefreshDateState = PrepareDailyTracking

function MineGoldPlanner.UpdateDailyEarnings()
    if not MineGoldPlannerDB then
        return 0
    end

    if not moneyBaselineReady then
        return MineGoldPlannerDB.earnedToday or 0
    end

    PrepareDailyTracking()
    local currentMoney = GetMoney()
    local characterKey = GetCharacterKey()
    local startMoney = MineGoldPlannerDB.dayStartMoney[characterKey]

    if type(startMoney) ~= "number" then
        startMoney = currentMoney
        MineGoldPlannerDB.dayStartMoney[characterKey] = currentMoney
        MineGoldPlannerDB.dayPeakMoney[characterKey] = currentMoney
    end

    local peakMoney = MineGoldPlannerDB.dayPeakMoney[characterKey] or startMoney

    if currentMoney > peakMoney then
        peakMoney = currentMoney
        MineGoldPlannerDB.dayPeakMoney[characterKey] = currentMoney
    end

    MineGoldPlannerDB.characterEarnings[characterKey] = math.max(peakMoney - startMoney, 0)
    MineGoldPlannerDB.earnedToday = 0

    for _, earned in pairs(MineGoldPlannerDB.characterEarnings) do
        MineGoldPlannerDB.earnedToday = MineGoldPlannerDB.earnedToday + earned
    end

    local dailyGoalCopper = (MineGoldPlannerDB.goal or 0) * 10000

    if dailyGoalCopper > 0 then
        MineGoldPlannerDB.completedDays = MineGoldPlannerDB.completedDays or {}
        local earnedGoals = math.floor(MineGoldPlannerDB.earnedToday / dailyGoalCopper)

        while MineGoldPlannerDB.autoProcessedGoals < earnedGoals do
            local oldestUncompletedDay
            MineGoldPlannerDB.autoProcessedGoals = MineGoldPlannerDB.autoProcessedGoals + 1

            for day = 1, MineGoldPlanner.GetCurrentDay() do
                if not MineGoldPlannerDB.completedDays[day] then
                    oldestUncompletedDay = day
                    break
                end
            end

            if not oldestUncompletedDay then
                MineGoldPlannerDB.autoProcessedGoals = earnedGoals
                break
            end

            MineGoldPlannerDB.completedDays[oldestUncompletedDay] = true
            MineGoldPlannerDB.autoClosedDaysToday[oldestUncompletedDay] = true
        end
    end

    return MineGoldPlannerDB.earnedToday
end

function MineGoldPlanner.SetCurrentMoneyBaseline()
    if not MineGoldPlannerDB then
        return
    end

    PrepareDailyTracking()

    local characterKey = GetCharacterKey()

    if MineGoldPlannerDB.dayStartMoney[characterKey] == nil then
        local currentMoney = GetMoney()
        MineGoldPlannerDB.dayStartMoney[characterKey] = currentMoney
        MineGoldPlannerDB.dayPeakMoney[characterKey] = currentMoney
        MineGoldPlannerDB.characterEarnings[characterKey] = 0
    end

    moneyBaselineReady = true
end

function MineGoldPlanner.ResetToday()
    if not MineGoldPlannerDB then
        return
    end

    PrepareDailyTracking()

    -- Remove only the checkmarks that were added automatically today.
    for day in pairs(MineGoldPlannerDB.autoClosedDaysToday or {}) do
        MineGoldPlannerDB.completedDays[day] = nil
    end

    local characterKey = GetCharacterKey()
    local currentMoney = GetMoney()

    MineGoldPlannerDB.earnedToday = 0
    MineGoldPlannerDB.dayStartMoney = { [characterKey] = currentMoney }
    MineGoldPlannerDB.dayPeakMoney = { [characterKey] = currentMoney }
    MineGoldPlannerDB.characterEarnings = { [characterKey] = 0 }
    MineGoldPlannerDB.autoProcessedGoals = 0
    MineGoldPlannerDB.autoClosedDaysToday = {}
    moneyBaselineReady = true
end

-- ============================================================================
-- Initialization
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

-- SavedVariables are ready only when this addon's ADDON_LOADED event fires.
eventFrame:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= "MineGoldPlanner" then
        return
    end

    MineGoldPlannerDB = MineGoldPlannerDB or {}

    if type(MineGoldPlannerDB.goal) ~= "number" or MineGoldPlannerDB.goal <= 0 then
        MineGoldPlannerDB.goal = 5000
    end

    local monthKey = MineGoldPlanner.GetMonthKey()
    local previousMonthKey = MineGoldPlannerDB.monthKey or monthKey
    local previousCompletedDays = MineGoldPlannerDB.completedDays

    MineGoldPlannerDB.completedDaysByMonth = MineGoldPlannerDB.completedDaysByMonth or {}

    -- Migrate the existing current-month table into the monthly history.
    if type(previousCompletedDays) == "table"
        and MineGoldPlannerDB.completedDaysByMonth[previousMonthKey] == nil then
        MineGoldPlannerDB.completedDaysByMonth[previousMonthKey] = previousCompletedDays
    end

    MineGoldPlannerDB.completedDaysByMonth[monthKey] =
        MineGoldPlannerDB.completedDaysByMonth[monthKey] or {}
    MineGoldPlannerDB.monthKey = monthKey
    MineGoldPlannerDB.completedDays = MineGoldPlannerDB.completedDaysByMonth[monthKey]

    -- Start the daily-maximum tracker without carrying over older calculations.
    if MineGoldPlannerDB.earningsTrackingVersion ~= 3 then
        MineGoldPlannerDB.earnedToday = 0
        MineGoldPlannerDB.dayStartMoney = {}
        MineGoldPlannerDB.dayPeakMoney = {}
        MineGoldPlannerDB.characterEarnings = {}
        MineGoldPlannerDB.autoProcessedGoals = 0
        MineGoldPlannerDB.autoClosedDaysToday = {}
        MineGoldPlannerDB.earningsTrackingVersion = 3
    end

    MineGoldPlanner.RestoreFramePosition(MineGoldPlanner.UI.MainFrame, "main")
    MineGoldPlanner.RestoreFramePosition(MineGoldPlanner.UI.SettingsFrame, "settings")
    MineGoldPlanner.RestoreFramePosition(MineGoldPlanner.UI.TrackerFrame, "tracker")

    if MineGoldPlanner.UpdateMinimapButtonPosition then
        MineGoldPlanner.UpdateMinimapButtonPosition(MineGoldPlannerDB.minimapAngle or 2.4)
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
