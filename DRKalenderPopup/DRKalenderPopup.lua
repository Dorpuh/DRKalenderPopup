local ADDON_TITLE = "DRKalenderPopup"
local GUILD_NAME = "Darkness Rising"
local LOGO_PATH = "Interface\\AddOns\\DRKalenderPopup\\logo.tga"

DRKalenderPopupDB = DRKalenderPopupDB or {}
if type(DRKalenderPopupDB.pendingEventIDs) ~= "table" then
    DRKalenderPopupDB.pendingEventIDs = {}
end
if type(DRKalenderPopupDB.knownEventIDs) ~= "table" then
    DRKalenderPopupDB.knownEventIDs = {}
end

local addon = CreateFrame("Frame")
addon.scanToken = 0
addon.currentPopupEventID = nil
addon.currentPopupTitle = nil
addon.currentPopupDate = nil
addon.popupVisibleForEventID = nil
addon.scanSchedule = { 2, 5, 9, 14, 20 }
addon.sessionDismissed = false
addon.deferredPopup = nil
addon.popupHiddenByCombat = false

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff7b68ee%s|r: %s", ADDON_TITLE, msg))
    end
end

local function EnsureCalendarLoaded()
    if not CalendarFrame then
        C_AddOns.LoadAddOn("Blizzard_Calendar")
    end
end

local function OpenCalendarWindow()
    EnsureCalendarLoaded()

    if Calendar_Toggle then
        Calendar_Toggle()
    elseif C_Calendar and C_Calendar.OpenCalendar then
        C_Calendar.OpenCalendar()
    else
        Print("Die Kalenderoberfläche konnte nicht geöffnet werden.")
    end
end

local function IsBlockedContext()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end

    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance then
            if instanceType == "party"
            or instanceType == "raid"
            or instanceType == "pvp"
            or instanceType == "arena"
            or instanceType == "scenario" then
                return true
            end
        end
    end

    return false
end

local popup = CreateFrame("Frame", "DRKalenderPopupFrame", UIParent, "BackdropTemplate")
popup:SetSize(820, 520)
popup:SetPoint("CENTER")
popup:SetFrameStrata("DIALOG")
popup:SetFrameLevel(100)
popup:SetMovable(true)
popup:EnableMouse(true)
popup:RegisterForDrag("LeftButton")
popup:SetScript("OnDragStart", popup.StartMoving)
popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
popup:Hide()

popup:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
popup:SetBackdropColor(0.03, 0.03, 0.05, 0.97)

popup.bgGlowTop = popup:CreateTexture(nil, "BACKGROUND")
popup.bgGlowTop:SetTexture("Interface/Buttons/WHITE8X8")
popup.bgGlowTop:SetPoint("TOPLEFT", 20, -22)
popup.bgGlowTop:SetPoint("TOPRIGHT", -20, -22)
popup.bgGlowTop:SetHeight(84)
popup.bgGlowTop:SetColorTexture(0.23, 0.11, 0.34, 0.45)

popup.banner = CreateFrame("Frame", nil, popup, "BackdropTemplate")
popup.banner:SetPoint("TOPLEFT", 28, -26)
popup.banner:SetPoint("TOPRIGHT", -28, -26)
popup.banner:SetHeight(82)
popup.banner:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
popup.banner:SetBackdropColor(0.03, 0.03, 0.12, 0.95)
popup.banner:SetBackdropBorderColor(0.80, 0.68, 0.22, 0.95)

popup.bannerTopLine = popup.banner:CreateTexture(nil, "ARTWORK")
popup.bannerTopLine:SetTexture("Interface/Buttons/WHITE8X8")
popup.bannerTopLine:SetPoint("TOPLEFT", 8, -8)
popup.bannerTopLine:SetPoint("TOPRIGHT", -8, -8)
popup.bannerTopLine:SetHeight(2)
popup.bannerTopLine:SetColorTexture(0.86, 0.73, 0.22, 0.95)

popup.title = popup.banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
popup.title:SetPoint("CENTER", 0, 12)
popup.title:SetText(GUILD_NAME)
popup.title:SetTextColor(1.0, 0.88, 0.26, 1)

popup.subtitle = popup.banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popup.subtitle:SetPoint("TOP", popup.title, "BOTTOM", 0, -4)
popup.subtitle:SetText("Gildenkalender")
popup.subtitle:SetTextColor(0.82, 0.82, 0.9, 1)

popup.closeX = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
popup.closeX:SetPoint("TOPRIGHT", -8, -8)

popup.body = CreateFrame("Frame", nil, popup)
popup.body:SetPoint("TOPLEFT", popup, "TOPLEFT", 36, -126)
popup.body:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -36, 88)

popup.logoBorder = CreateFrame("Frame", nil, popup.body, "BackdropTemplate")
popup.logoBorder:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
popup.logoBorder:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
popup.logoBorder:SetBackdropBorderColor(0.72, 0.58, 0.16, 0.95)

popup.logo = popup.logoBorder:CreateTexture(nil, "ARTWORK")
popup.logo:SetPoint("TOPLEFT", 8, -8)
popup.logo:SetPoint("BOTTOMRIGHT", -8, 8)
popup.logo:SetTexture(LOGO_PATH)
popup.logo:SetTexCoord(0, 1, 0, 1)

popup.rightPane = CreateFrame("Frame", nil, popup.body, "BackdropTemplate")
popup.rightPane:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
popup.rightPane:SetBackdropColor(0.08, 0.03, 0.12, 0.72)
popup.rightPane:SetBackdropBorderColor(0.30, 0.18, 0.08, 0.65)

popup.noticeLabel = popup.rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popup.noticeLabel:SetText("Offenes Gildenereignis")
popup.noticeLabel:SetTextColor(1.0, 0.84, 0.18, 1)
popup.noticeLabel:SetJustifyH("LEFT")
popup.noticeLabel:SetJustifyV("TOP")

popup.divider = popup.rightPane:CreateTexture(nil, "ARTWORK")
popup.divider:SetTexture("Interface/Buttons/WHITE8X8")
popup.divider:SetHeight(2)
popup.divider:SetColorTexture(0.74, 0.62, 0.21, 0.95)

popup.eventTitleLabel = popup.rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popup.eventTitleLabel:SetText("Ereignis")
popup.eventTitleLabel:SetTextColor(0.78, 0.78, 0.84, 1)
popup.eventTitleLabel:SetJustifyH("LEFT")

popup.eventTitle = popup.rightPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
popup.eventTitle:SetTextColor(1, 1, 1, 1)
popup.eventTitle:SetJustifyH("LEFT")
popup.eventTitle:SetJustifyV("TOP")
popup.eventTitle:SetWordWrap(true)

popup.dateLabel = popup.rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popup.dateLabel:SetText("Datum")
popup.dateLabel:SetTextColor(0.78, 0.78, 0.84, 1)
popup.dateLabel:SetJustifyH("LEFT")

popup.dateText = popup.rightPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popup.dateText:SetTextColor(0.94, 0.94, 0.94, 1)
popup.dateText:SetJustifyH("LEFT")
popup.dateText:SetJustifyV("TOP")
popup.dateText:SetWordWrap(true)

popup.infoText = popup.rightPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popup.infoText:SetText("Dieses Ereignis ist für Darkness Rising noch offen. Mit OK öffnest du direkt den Kalender.")
popup.infoText:SetTextColor(0.96, 0.96, 0.96, 1)
popup.infoText:SetJustifyH("LEFT")
popup.infoText:SetJustifyV("TOP")
popup.infoText:SetWordWrap(true)
popup.infoText:SetSpacing(4)

popup.footer = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
popup.footer:SetJustifyH("CENTER")
popup.footer:SetText("Später blendet das Fenster nur für diesen Login dieses Charakters aus.")

popup.okButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
popup.okButton:SetSize(180, 32)
popup.okButton:SetText("OK")

popup.laterButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
popup.laterButton:SetSize(180, 32)
popup.laterButton:SetText("Später")

local function ApplyResponsiveLayout()
    local bodyWidth = popup.body:GetWidth()
    local bodyHeight = popup.body:GetHeight()
    if bodyWidth <= 0 or bodyHeight <= 0 then
        return
    end

    local gap = 28
    local logoSize = math.floor(math.min(math.max(bodyWidth * 0.34, 260), 320) + 0.5)
    logoSize = math.min(logoSize, bodyHeight - 12)

    popup.logoBorder:ClearAllPoints()
    popup.logoBorder:SetPoint("TOPLEFT", popup.body, "TOPLEFT", 0, 0)
    popup.logoBorder:SetSize(logoSize, logoSize)

    popup.rightPane:ClearAllPoints()
    popup.rightPane:SetPoint("TOPLEFT", popup.logoBorder, "TOPRIGHT", gap, 0)
    popup.rightPane:SetPoint("BOTTOMRIGHT", popup.body, "BOTTOMRIGHT", 0, 0)

    local textWidth = math.max(popup.rightPane:GetWidth() - 36, 220)

    popup.noticeLabel:ClearAllPoints()
    popup.noticeLabel:SetPoint("TOPLEFT", popup.rightPane, "TOPLEFT", 18, -18)
    popup.noticeLabel:SetWidth(textWidth)

    popup.divider:ClearAllPoints()
    popup.divider:SetPoint("TOPLEFT", popup.noticeLabel, "BOTTOMLEFT", 0, -8)
    popup.divider:SetPoint("TOPRIGHT", popup.rightPane, "TOPRIGHT", -18, -44)

    popup.eventTitleLabel:ClearAllPoints()
    popup.eventTitleLabel:SetPoint("TOPLEFT", popup.divider, "BOTTOMLEFT", 0, -18)
    popup.eventTitleLabel:SetWidth(textWidth)

    popup.eventTitle:ClearAllPoints()
    popup.eventTitle:SetPoint("TOPLEFT", popup.eventTitleLabel, "BOTTOMLEFT", 0, -8)
    popup.eventTitle:SetWidth(textWidth)

    popup.dateLabel:ClearAllPoints()
    popup.dateLabel:SetPoint("TOPLEFT", popup.eventTitle, "BOTTOMLEFT", 0, -24)
    popup.dateLabel:SetWidth(textWidth)

    popup.dateText:ClearAllPoints()
    popup.dateText:SetPoint("TOPLEFT", popup.dateLabel, "BOTTOMLEFT", 0, -8)
    popup.dateText:SetWidth(textWidth)

    popup.infoText:ClearAllPoints()
    popup.infoText:SetPoint("TOPLEFT", popup.dateText, "BOTTOMLEFT", 0, -26)
    popup.infoText:SetWidth(textWidth)
    popup.infoText:SetHeight(math.max(popup.rightPane:GetHeight() - 220, 40))

    popup.footer:ClearAllPoints()
    popup.footer:SetPoint("BOTTOM", popup, "BOTTOM", 0, 66)
    popup.footer:SetWidth(popup:GetWidth() - 120)

    popup.okButton:ClearAllPoints()
    popup.okButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -104, 24)

    popup.laterButton:ClearAllPoints()
    popup.laterButton:SetPoint("RIGHT", popup.okButton, "LEFT", -24, 0)
end

popup:SetScript("OnSizeChanged", ApplyResponsiveLayout)
ApplyResponsiveLayout()

local function BuildDateText(info)
    if not info then
        return nil
    end

    local y = tonumber(info.year or 0) or 0
    local m = tonumber(info.month or 0) or 0
    local d = tonumber(info.monthDay or 0) or 0
    local hh = tonumber(info.hour or 0) or 0
    local mm = tonumber(info.minute or 0) or 0

    if y > 0 and m > 0 and d > 0 then
        return string.format("%02d.%02d.%04d um %02d:%02d Uhr", d, m, y, hh, mm)
    end

    return "Im Kalender ansehen"
end

local function SetPopupText(title, dateText)
    popup.eventTitle:SetText(title or "Gildenereignis")
    popup.dateText:SetText(dateText or "Im Kalender ansehen")
    ApplyResponsiveLayout()
end

local function HidePopupForCombatDefer()
    if not popup:IsShown() or not addon.currentPopupEventID then
        return
    end

    addon.deferredPopup = {
        eventID = addon.currentPopupEventID,
        title = addon.currentPopupTitle,
        dateText = addon.currentPopupDate,
    }
    addon.popupHiddenByCombat = true
    addon.popupVisibleForEventID = nil
    popup:Hide()
end

local function ShowPopupForEvent(eventID, title, dateText)
    if addon.sessionDismissed then
        return false
    end

    if popup:IsShown() and addon.popupVisibleForEventID == eventID then
        return true
    end

    if IsBlockedContext() then
        addon.deferredPopup = {
            eventID = eventID,
            title = title,
            dateText = dateText,
        }
        return true
    end

    addon.currentPopupEventID = eventID
    addon.currentPopupTitle = title
    addon.currentPopupDate = dateText
    addon.popupVisibleForEventID = eventID
    addon.popupHiddenByCombat = false

    if popup.logo:GetTexture() == nil then
        popup.logo:SetColorTexture(0.35, 0.35, 0.35, 1)
    end

    SetPopupText(title, dateText)
    popup:Show()

    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    end

    return true
end

local function TryShowDeferredPopup()
    if addon.sessionDismissed or not addon.deferredPopup then
        return false
    end

    if IsBlockedContext() then
        return false
    end

    local data = addon.deferredPopup
    addon.deferredPopup = nil
    addon.popupHiddenByCombat = false
    return ShowPopupForEvent(data.eventID, data.title, data.dateText)
end

local function DismissForCurrentSession()
    addon.sessionDismissed = true
    addon.deferredPopup = nil
    addon.popupHiddenByCombat = false
    addon.scanToken = addon.scanToken + 1
    addon.popupVisibleForEventID = nil
    popup:Hide()
end

popup.closeX:SetScript("OnClick", DismissForCurrentSession)
popup.laterButton:SetScript("OnClick", DismissForCurrentSession)

popup.okButton:SetScript("OnClick", function()
    local eventID = addon.currentPopupEventID
    addon.scanToken = addon.scanToken + 1
    addon.popupVisibleForEventID = nil
    addon.deferredPopup = nil
    addon.popupHiddenByCombat = false
    if eventID then
        DRKalenderPopupDB.pendingEventIDs[eventID] = nil
    end
    popup:Hide()
    OpenCalendarWindow()
end)

local function GetFirstPendingEventInfo(foundEvents)
    for _, event in ipairs(foundEvents) do
        if DRKalenderPopupDB.pendingEventIDs[event.eventID] then
            return event
        end
    end
    return nil
end

local function ScanGuildEvents()
    if addon.sessionDismissed then
        return false, false
    end

    EnsureCalendarLoaded()

    if not (C_Calendar and C_Calendar.GetNumGuildEvents and C_Calendar.GetGuildEventInfo) then
        return false, false
    end

    local numGuildEvents = tonumber(C_Calendar.GetNumGuildEvents() or 0) or 0
    if numGuildEvents <= 0 then
        return false, false
    end

    local foundEvents = {}
    local foundAny = false

    for index = 1, numGuildEvents do
        local info = C_Calendar.GetGuildEventInfo(index)
        if info and info.eventID then
            foundAny = true
            local eventID = tostring(info.eventID)
            local title = info.title or info.eventName or "Unbenanntes Gildenereignis"
            local dateText = BuildDateText(info)

            table.insert(foundEvents, {
                eventID = eventID,
                title = title,
                dateText = dateText,
            })

            if not DRKalenderPopupDB.knownEventIDs[eventID] then
                DRKalenderPopupDB.knownEventIDs[eventID] = true
                DRKalenderPopupDB.pendingEventIDs[eventID] = {
                    title = title,
                    dateText = dateText,
                }
            else
                local pending = DRKalenderPopupDB.pendingEventIDs[eventID]
                if pending then
                    pending.title = title
                    pending.dateText = dateText
                end
            end
        end
    end

    local pendingEvent = GetFirstPendingEventInfo(foundEvents)
    if pendingEvent then
        ShowPopupForEvent(pendingEvent.eventID, pendingEvent.title, pendingEvent.dateText)
        return true, foundAny
    end

    for eventID, data in pairs(DRKalenderPopupDB.pendingEventIDs) do
        if type(data) == "table" then
            ShowPopupForEvent(eventID, data.title, data.dateText)
            return true, foundAny
        end
    end

    return false, foundAny
end

local function StartLoginScanCycle()
    addon.scanToken = addon.scanToken + 1
    local myToken = addon.scanToken

    local function runScan()
        if myToken ~= addon.scanToken or addon.sessionDismissed then
            return
        end

        local shown = ScanGuildEvents()
        if shown then
            addon.scanToken = addon.scanToken + 1
        end
    end

    runScan()
    for _, delay in ipairs(addon.scanSchedule) do
        C_Timer.After(delay, runScan)
    end
end

SLASH_DRKALENDERPOPUP1 = "/drpopup"
SlashCmdList["DRKALENDERPOPUP"] = function(msg)
    msg = tostring(msg or ""):lower()

    if msg == "test" then
        ShowPopupForEvent("test-event", "Mitternachtsraid der Gilde", "15.03.2026 um 20:00 Uhr")
    elseif msg == "scan" then
        local shown, foundAny = ScanGuildEvents()
        if shown then
            Print("Ausstehendes Gildenereignis gefunden.")
        elseif foundAny then
            Print("Gildenereignisse gefunden, aber keines ist für das Addon mehr ausstehend.")
        else
            Print("Es wurden derzeit keine Gildenereignisse gefunden.")
        end
    elseif msg == "reset" then
        DRKalenderPopupDB.pendingEventIDs = {}
        for eventID in pairs(DRKalenderPopupDB.knownEventIDs) do
            DRKalenderPopupDB.pendingEventIDs[eventID] = {
                title = "Gildenereignis",
                dateText = "Im Kalender ansehen"
            }
        end
        Print("Alle bekannten Gildenereignisse wurden wieder als ausstehend markiert.")
    elseif msg == "clear" then
        DRKalenderPopupDB.pendingEventIDs = {}
        DRKalenderPopupDB.knownEventIDs = {}
        addon.deferredPopup = nil
        addon.popupHiddenByCombat = false
        Print("Gespeicherte Ereignisse wurden vollständig gelöscht.")
    else
        Print("Befehle: /drpopup test, /drpopup scan, /drpopup reset, /drpopup clear")
    end
end

addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        addon.sessionDismissed = false
        addon.deferredPopup = nil
        addon.popupHiddenByCombat = false
        StartLoginScanCycle()

    elseif event == "CALENDAR_UPDATE_GUILD_EVENTS" then
        if not addon.sessionDismissed then
            C_Timer.After(1, function()
                if not addon.sessionDismissed then
                    ScanGuildEvents()
                    TryShowDeferredPopup()
                end
            end)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        HidePopupForCombatDefer()

    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.5, function()
            TryShowDeferredPopup()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not addon.sessionDismissed then
            C_Timer.After(1, function()
                if not addon.sessionDismissed then
                    ScanGuildEvents()
                    TryShowDeferredPopup()
                end
            end)
        end
    end
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("CALENDAR_UPDATE_GUILD_EVENTS")
addon:RegisterEvent("PLAYER_REGEN_DISABLED")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")
