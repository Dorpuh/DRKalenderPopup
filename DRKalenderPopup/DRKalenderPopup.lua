local ADDON_TITLE = "DRKalenderPopup"
local GUILD_NAME = "Darkness Rising"
local LOGO_PATH = "Interface\\AddOns\\DRKalenderPopup\\logo.tga"
local ICON_PATH = "Interface\\AddOns\\DRKalenderPopup\\icon.tga"

DRKalenderPopupDB = DRKalenderPopupDB or {}

local function EnsureCoreDB()
    if type(DRKalenderPopupDB) ~= "table" then
        DRKalenderPopupDB = {}
    end
    if type(DRKalenderPopupDB.pendingEventIDs) ~= "table" then
        DRKalenderPopupDB.pendingEventIDs = {}
    end
    if type(DRKalenderPopupDB.knownEventIDs) ~= "table" then
        DRKalenderPopupDB.knownEventIDs = {}
    end
    if type(DRKalenderPopupDB.minimap) ~= "table" then
        DRKalenderPopupDB.minimap = {}
    end
    if type(DRKalenderPopupDB.completedEventIDs) ~= "table" then
        DRKalenderPopupDB.completedEventIDs = {}
    end
    if type(DRKalenderPopupDB.snoozedEventIDs) ~= "table" then
        DRKalenderPopupDB.snoozedEventIDs = {}
    end
    if type(DRKalenderPopupDB.minimap.angle) ~= "number" then
        DRKalenderPopupDB.minimap.angle = 225
    end
    if DRKalenderPopupDB.minimap.hide == nil then
        DRKalenderPopupDB.minimap.hide = false
    end
    if type(DRKalenderPopupDB.reminderIcon) ~= "table" then
        DRKalenderPopupDB.reminderIcon = {}
    end
    if type(DRKalenderPopupDB.reminderIcon.point) ~= "string" then
        DRKalenderPopupDB.reminderIcon.point = "RIGHT"
    end
    if type(DRKalenderPopupDB.reminderIcon.relativePoint) ~= "string" then
        DRKalenderPopupDB.reminderIcon.relativePoint = "RIGHT"
    end
    if type(DRKalenderPopupDB.reminderIcon.x) ~= "number" then
        DRKalenderPopupDB.reminderIcon.x = -18
    end
    if type(DRKalenderPopupDB.reminderIcon.y) ~= "number" then
        DRKalenderPopupDB.reminderIcon.y = 0
    end
end

local function EnsureReminderIconDB()
    EnsureCoreDB()
end

EnsureCoreDB()

local function RebuildPendingFromSnoozed()
    EnsureCoreDB()
    DRKalenderPopupDB.pendingEventIDs = {}
    for eventID, data in pairs(DRKalenderPopupDB.snoozedEventIDs) do
        if type(data) == "table" then
            DRKalenderPopupDB.pendingEventIDs[eventID] = {
                title = data.title,
                dateText = data.dateText,
            }
        end
    end
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
addon.snoozedPopup = nil
addon.pendingEventList = {}
addon.pendingEventIndex = 1


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
popup.subtitle:SetText("Kalenderereignisse")
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
popup.noticeLabel:SetText("Offenes Kalenderereignis")
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
popup.infoText:SetText("Dieses Ereignis ist für Darkness Rising noch offen. Setze den Haken, um es als erledigt zu markieren.")
popup.infoText:SetTextColor(0.96, 0.96, 0.96, 1)
popup.infoText:SetJustifyH("LEFT")
popup.infoText:SetJustifyV("TOP")
popup.infoText:SetWordWrap(true)
popup.infoText:SetSpacing(4)

popup.footer = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
popup.footer:SetJustifyH("CENTER")
popup.footer:SetText("Setze den Haken zum Abschließen. Später und X minimieren das Fenster zum Logo.")

popup.completeCheckContainer = CreateFrame("Button", nil, popup, "BackdropTemplate")
popup.completeCheckContainer:SetSize(220, 36)
popup.completeCheckContainer:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
popup.completeCheckContainer:SetBackdropColor(0.06, 0.03, 0.10, 0.90)
popup.completeCheckContainer:SetBackdropBorderColor(0.78, 0.64, 0.18, 0.95)
popup.completeCheckContainer:RegisterForClicks("LeftButtonUp")

popup.completeCheckButton = CreateFrame("CheckButton", nil, popup.completeCheckContainer, "UICheckButtonTemplate")
popup.completeCheckButton:SetSize(28, 28)
popup.completeCheckButton:SetPoint("LEFT", popup.completeCheckContainer, "LEFT", 8, 0)
popup.completeCheckButton:SetChecked(false)
popup.completeCheckButton:SetHitRectInsets(0, 0, 0, 0)

popup.completeCheckLabel = popup.completeCheckContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popup.completeCheckLabel:SetText("Ereignis erledigt")
popup.completeCheckLabel:SetTextColor(0.97, 0.92, 0.70, 1)
popup.completeCheckLabel:SetJustifyH("LEFT")
popup.completeCheckLabel:SetPoint("LEFT", popup.completeCheckButton, "RIGHT", 8, 0)
popup.completeCheckLabel:SetPoint("RIGHT", popup.completeCheckContainer, "RIGHT", -12, 0)

popup.laterButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
popup.laterButton:SetSize(180, 32)
popup.laterButton:SetText("Später")

popup.prevButton = CreateFrame("Button", nil, popup, "BackdropTemplate")
popup.prevButton:SetSize(44, 68)
popup.prevButton:SetFrameLevel(112)
popup.prevButton:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
popup.prevButton:SetBackdropColor(0.06, 0.03, 0.10, 0.90)
popup.prevButton:SetBackdropBorderColor(0.78, 0.64, 0.18, 0.95)
popup.prevButton:Hide()

popup.prevArrow = popup.prevButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
popup.prevArrow:SetPoint("CENTER", -2, 1)
popup.prevArrow:SetText("‹")
popup.prevArrow:SetTextColor(1.0, 0.86, 0.22, 1)

popup.nextButton = CreateFrame("Button", nil, popup, "BackdropTemplate")
popup.nextButton:SetSize(44, 68)
popup.nextButton:SetFrameLevel(112)
popup.nextButton:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
popup.nextButton:SetBackdropColor(0.06, 0.03, 0.10, 0.90)
popup.nextButton:SetBackdropBorderColor(0.78, 0.64, 0.18, 0.95)
popup.nextButton:Hide()

popup.nextArrow = popup.nextButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
popup.nextArrow:SetPoint("CENTER", 2, 1)
popup.nextArrow:SetText("›")
popup.nextArrow:SetTextColor(1.0, 0.86, 0.22, 1)

popup.completeCheckButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Ereignis abschließen", 1, 0.82, 0)
    GameTooltip:AddLine("Setze den Haken, um dieses Ereignis dauerhaft als erledigt zu markieren.", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)

popup.completeCheckButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function SetCompleteContainerHighlight(highlighted)
    if highlighted then
        popup.completeCheckContainer:SetBackdropColor(0.13, 0.06, 0.19, 0.95)
        popup.completeCheckContainer:SetBackdropBorderColor(0.95, 0.78, 0.26, 1)
    else
        popup.completeCheckContainer:SetBackdropColor(0.06, 0.03, 0.10, 0.90)
        popup.completeCheckContainer:SetBackdropBorderColor(0.78, 0.64, 0.18, 0.95)
    end
end

popup.completeCheckContainer:SetScript("OnEnter", function()
    SetCompleteContainerHighlight(true)
    GameTooltip:SetOwner(popup.completeCheckContainer, "ANCHOR_TOP")
    GameTooltip:AddLine("Ereignis abschließen", 1, 0.82, 0)
    GameTooltip:AddLine("Setze den Haken, um dieses Ereignis dauerhaft als erledigt zu markieren.", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)

popup.completeCheckContainer:SetScript("OnLeave", function()
    SetCompleteContainerHighlight(false)
    GameTooltip:Hide()
end)

local reminderIcon = CreateFrame("Button", "DRKalenderPopupReminderIcon", UIParent)
reminderIcon:SetSize(60, 60)
do
    EnsureReminderIconDB()
    local pos = DRKalenderPopupDB.reminderIcon
    reminderIcon:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end
reminderIcon:SetFrameStrata("DIALOG")
reminderIcon:SetFrameLevel(120)
reminderIcon:SetMovable(true)
reminderIcon:SetClampedToScreen(true)
reminderIcon:EnableMouse(true)
reminderIcon:Hide()
reminderIcon.isMouseDown = false
reminderIcon.isDragging = false
reminderIcon.dragStartX = 0
reminderIcon.dragStartY = 0

reminderIcon.bg = reminderIcon:CreateTexture(nil, "BACKGROUND")
reminderIcon.bg:SetAllPoints()
reminderIcon.bg:SetTexture(LOGO_PATH)
reminderIcon.bg:SetTexCoord(0, 1, 0, 1)

reminderIcon.glow = reminderIcon:CreateTexture(nil, "ARTWORK")
reminderIcon.glow:SetPoint("CENTER")
reminderIcon.glow:SetSize(94, 94)
reminderIcon.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
reminderIcon.glow:SetBlendMode("ADD")
reminderIcon.glow:SetAlpha(0.45)

reminderIcon.pulse = 0

reminderIcon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("DRKalenderPopup", 1, 0.82, 0)
    GameTooltip:AddLine("Offenes Kalenderereignis später erinnern.", 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine("Klicken, um das Popup erneut zu öffnen.", 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine("Halten und ziehen, um das Logo zu verschieben.", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)

reminderIcon:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function ShowReminderIcon()
    EnsureReminderIconDB()
    if addon.snoozedPopup then
        reminderIcon:Show()
    end
end

local function HideReminderIcon()
    reminderIcon:Hide()
end

local function SaveReminderIconPosition()
    EnsureReminderIconDB()
    local point, _, relativePoint, x, y = reminderIcon:GetPoint(1)
    DRKalenderPopupDB.reminderIcon.point = point or "RIGHT"
    DRKalenderPopupDB.reminderIcon.relativePoint = relativePoint or "RIGHT"
    DRKalenderPopupDB.reminderIcon.x = x or -18
    DRKalenderPopupDB.reminderIcon.y = y or 0
end

local optionsFrame
local minimapButton
local ShowPopupForEvent
local ScanCalendarEvents
local ShowPendingEventByIndex

local function EnsureMinimapDB()
    EnsureCoreDB()
end

local function OpenOptionsMenu()
    if optionsFrame then
        optionsFrame:Show()
        optionsFrame:Raise()
    end
end

local function CloseOptionsMenu()
    if optionsFrame then
        optionsFrame:Hide()
    end
end

local function ToggleOptionsMenu()
    if optionsFrame and optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        OpenOptionsMenu()
    end
end

local function UpdateMinimapButtonPosition()
    if not minimapButton or not Minimap then
        return
    end

    local angle = tonumber(DRKalenderPopupDB.minimap and DRKalenderPopupDB.minimap.angle) or 225
    local radians = math.rad(angle)
    local radius = (Minimap:GetWidth() * 0.5) + 6
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function SetMinimapButtonHidden(hidden)
    EnsureMinimapDB()
    DRKalenderPopupDB.minimap.hide = hidden and true or false
    if minimapButton then
        if DRKalenderPopupDB.minimap.hide then
            minimapButton:Hide()
        else
            minimapButton:Show()
            UpdateMinimapButtonPosition()
        end
    end

    if optionsFrame and optionsFrame.minimapToggleButton then
        optionsFrame.minimapToggleButton:SetText(DRKalenderPopupDB.minimap.hide and "Minimap-Button einblenden" or "Minimap-Button ausblenden")
    end
end

local function ToggleMinimapButton()
    EnsureMinimapDB()
    SetMinimapButtonHidden(not DRKalenderPopupDB.minimap.hide)
end

local function CreateOptionsMenu()
    if optionsFrame then
        return
    end

    local frame = CreateFrame("Frame", "DRKalenderPopupOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(130)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    frame:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.05, 0.97)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", 0, -20)
    frame.title:SetText("DRKalenderPopup Optionen")
    frame.title:SetTextColor(1.0, 0.88, 0.26, 1)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    frame.subtitle:SetText("Schnellzugriff auf die Addon-Funktionen")
    frame.subtitle:SetTextColor(0.82, 0.82, 0.9, 1)

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -8, -8)

    local buttonDefs = {
        { text = "Test Popup", onClick = function() ShowPopupForEvent("test-event", "Mitternachtsraid der Gilde", "15.03.2026 um 20:00 Uhr") end },
        { text = "Kalender scannen", onClick = function() local shown, foundAny = ScanCalendarEvents(); if shown then Print("Ausstehendes Kalenderereignis gefunden.") elseif foundAny then Print("Kalenderereignisse gefunden, aber keines ist für das Addon mehr ausstehend.") else Print("Es wurden derzeit keine passenden Kalenderereignisse gefunden.") end end },
        { text = "Events zurücksetzen", onClick = function() EnsureCoreDB(); DRKalenderPopupDB.pendingEventIDs = {}; DRKalenderPopupDB.completedEventIDs = {}; DRKalenderPopupDB.snoozedEventIDs = {}; for eventID in pairs(DRKalenderPopupDB.knownEventIDs) do DRKalenderPopupDB.pendingEventIDs[eventID] = { title = "Kalenderereignis", dateText = "Im Kalender ansehen" } end; Print("Alle bekannten Kalenderereignisse wurden wieder als ausstehend markiert.") end },
        { text = "Daten löschen", onClick = function() EnsureCoreDB(); DRKalenderPopupDB.pendingEventIDs = {}; DRKalenderPopupDB.knownEventIDs = {}; DRKalenderPopupDB.completedEventIDs = {}; DRKalenderPopupDB.snoozedEventIDs = {}; addon.deferredPopup = nil; addon.popupHiddenByCombat = false; addon.snoozedPopup = nil; HideReminderIcon(); EnsureCoreDB(); Print("Gespeicherte Kalenderereignisse wurden vollständig gelöscht.") end },
        { text = "Kalender öffnen", onClick = function() OpenCalendarWindow() end },
    }

    frame.buttons = {}
    local previous
    for index, def in ipairs(buttonDefs) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(250, 30)
        if previous then
            button:SetPoint("TOP", previous, "BOTTOM", 0, -10)
        else
            button:SetPoint("TOP", frame.subtitle, "BOTTOM", 0, -24)
        end
        button:SetText(def.text)
        button:SetScript("OnClick", def.onClick)
        frame.buttons[index] = button
        previous = button
    end

    local toggleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggleButton:SetSize(250, 30)
    toggleButton:SetPoint("TOP", previous, "BOTTOM", 0, -10)
    toggleButton:SetScript("OnClick", function()
        ToggleMinimapButton()
    end)
    frame.minimapToggleButton = toggleButton

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hint:SetPoint("TOP", toggleButton, "BOTTOM", 0, -18)
    frame.hint:SetWidth(300)
    frame.hint:SetJustifyH("CENTER")
    frame.hint:SetWordWrap(true)
    frame.hint:SetText("Minimap-Button: Linksklick öffnet dieses Menü. Rechtsklick öffnet den Kalender. Halten und ziehen verschiebt den Button.")

    optionsFrame = frame
    EnsureMinimapDB()
    SetMinimapButtonHidden(DRKalenderPopupDB.minimap.hide)
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "DRKalenderPopupMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("CENTER", 0, 1)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ICON_PATH)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            OpenCalendarWindow()
        else
            ToggleOptionsMenu()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        EnsureMinimapDB()
        self:SetScript("OnUpdate", function()
            local mx, my = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = Minimap:GetCenter()
            if not (mx and my and cx and cy) then
                return
            end
            mx = mx / scale
            my = my / scale
            local angle = math.deg(math.atan2(my - cy, mx - cx))
            DRKalenderPopupDB.minimap.angle = angle
            UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateMinimapButtonPosition()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("DRKalenderPopup", 1, 0.82, 0)
        GameTooltip:AddLine("Linksklick: Optionen öffnen", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine("Rechtsklick: Kalender öffnen", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine("Halten und ziehen: Position ändern", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    minimapButton = button
    EnsureMinimapDB()
    UpdateMinimapButtonPosition()
    SetMinimapButtonHidden(DRKalenderPopupDB.minimap.hide)
end

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

    popup.laterButton:ClearAllPoints()
    popup.laterButton:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 104, 24)

    popup.completeCheckContainer:ClearAllPoints()
    popup.completeCheckContainer:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -104, 22)

    popup.prevButton:ClearAllPoints()
    popup.prevButton:SetPoint("LEFT", popup, "LEFT", 18, 0)

    popup.nextButton:ClearAllPoints()
    popup.nextButton:SetPoint("RIGHT", popup, "RIGHT", -18, 0)
end

popup:SetScript("OnSizeChanged", ApplyResponsiveLayout)
ApplyResponsiveLayout()

local function BuildDateText(info, fallbackYear, fallbackMonth, fallbackMonthDay)
    if not info then
        return nil
    end

    local y = tonumber(info.year or fallbackYear or 0) or 0
    local m = tonumber(info.month or fallbackMonth or 0) or 0
    local d = tonumber(info.monthDay or info.day or fallbackMonthDay or 0) or 0
    local hh = tonumber(info.hour or 0) or 0
    local mm = tonumber(info.minute or 0) or 0

    if y > 0 and m > 0 and d > 0 then
        if hh > 0 or mm > 0 then
            return string.format("%02d.%02d.%04d um %02d:%02d Uhr", d, m, y, hh, mm)
        end
        return string.format("%02d.%02d.%04d", d, m, y)
    end

    return "Im Kalender ansehen"
end

local function UpdatePopupNavigation()
    local total = #(addon.pendingEventList or {})
    if total > 1 then
        popup.noticeLabel:SetText(string.format("Offenes Kalenderereignis (%d/%d)", addon.pendingEventIndex or 1, total))
        popup.prevButton:Show()
        popup.nextButton:Show()
    else
        popup.noticeLabel:SetText("Offenes Kalenderereignis")
        popup.prevButton:Hide()
        popup.nextButton:Hide()
    end
end

local function SetPopupText(title, dateText)
    popup.eventTitle:SetText(title or "Kalenderereignis")
    popup.dateText:SetText(dateText or "Im Kalender ansehen")
    if popup.completeCheckButton then
        popup.completeCheckButton:SetChecked(false)
    end
    UpdatePopupNavigation()
    ApplyResponsiveLayout()
end

local function FindPendingEventIndexByID(eventID)
    for index, eventData in ipairs(addon.pendingEventList or {}) do
        if eventData.eventID == eventID then
            return index
        end
    end
    return nil
end

local function BuildPendingEventList(foundEvents)
    local list = {}
    local seen = {}

    if type(foundEvents) == "table" then
        for _, event in ipairs(foundEvents) do
            if event.eventID and DRKalenderPopupDB.pendingEventIDs[event.eventID] then
                table.insert(list, {
                    eventID = event.eventID,
                    title = event.title,
                    dateText = event.dateText,
                    sortValue = event.sortValue or math.huge,
                })
                seen[event.eventID] = true
            end
        end
    end

    for eventID, data in pairs(DRKalenderPopupDB.pendingEventIDs) do
        if type(data) == "table" and not seen[eventID] then
            table.insert(list, {
                eventID = eventID,
                title = data.title,
                dateText = data.dateText,
                sortValue = math.huge,
            })
        end
    end

    table.sort(list, function(a, b)
        if (a.sortValue or math.huge) ~= (b.sortValue or math.huge) then
            return (a.sortValue or math.huge) < (b.sortValue or math.huge)
        end
        return tostring(a.title or "") < tostring(b.title or "")
    end)

    addon.pendingEventList = list
    if #list == 0 then
        addon.pendingEventIndex = 1
    else
        local currentIndex = FindPendingEventIndexByID(addon.currentPopupEventID)
        addon.pendingEventIndex = currentIndex or math.min(addon.pendingEventIndex or 1, #list)
    end
end

ShowPendingEventByIndex = function(index)
    if not addon.pendingEventList or #addon.pendingEventList == 0 then
        return false
    end

    local total = #addon.pendingEventList
    if index < 1 then
        index = total
    elseif index > total then
        index = 1
    end

    addon.pendingEventIndex = index
    local eventData = addon.pendingEventList[index]
    if not eventData then
        return false
    end

    return ShowPopupForEvent(eventData.eventID, eventData.title, eventData.dateText)
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
    HideReminderIcon()
end

ShowPopupForEvent = function(eventID, title, dateText)
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
    local matchedIndex = FindPendingEventIndexByID(eventID)
    if matchedIndex then
        addon.pendingEventIndex = matchedIndex
    end
    addon.popupVisibleForEventID = eventID
    addon.popupHiddenByCombat = false
    addon.snoozedPopup = nil
    HideReminderIcon()

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
    if addon.snoozedPopup then
        ShowReminderIcon()
        return false
    end

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
    addon.snoozedPopup = nil
    addon.scanToken = addon.scanToken + 1
    addon.popupVisibleForEventID = nil
    popup:Hide()
    HideReminderIcon()
end

local function SnoozePopupToReminder()
    if not addon.currentPopupEventID then
        return
    end

    addon.snoozedPopup = {
        eventID = addon.currentPopupEventID,
        title = addon.currentPopupTitle,
        dateText = addon.currentPopupDate,
    }
    EnsureCoreDB()
    DRKalenderPopupDB.snoozedEventIDs[addon.currentPopupEventID] = {
        title = addon.currentPopupTitle,
        dateText = addon.currentPopupDate,
    }
    DRKalenderPopupDB.pendingEventIDs[addon.currentPopupEventID] = {
        title = addon.currentPopupTitle,
        dateText = addon.currentPopupDate,
    }
    DRKalenderPopupDB.completedEventIDs[addon.currentPopupEventID] = nil
    addon.deferredPopup = nil
    addon.popupHiddenByCombat = false
    addon.popupVisibleForEventID = nil
    popup:Hide()
    ShowReminderIcon()
end

popup.closeX:SetScript("OnClick", SnoozePopupToReminder)
popup.laterButton:SetScript("OnClick", SnoozePopupToReminder)

popup.prevButton:SetScript("OnClick", function()
    ShowPendingEventByIndex((addon.pendingEventIndex or 1) - 1)
end)
popup.nextButton:SetScript("OnClick", function()
    ShowPendingEventByIndex((addon.pendingEventIndex or 1) + 1)
end)

local function SetNavButtonHighlight(button, highlighted)
    if highlighted then
        button:SetBackdropColor(0.13, 0.06, 0.19, 0.95)
        button:SetBackdropBorderColor(0.95, 0.78, 0.26, 1)
    else
        button:SetBackdropColor(0.06, 0.03, 0.10, 0.90)
        button:SetBackdropBorderColor(0.78, 0.64, 0.18, 0.95)
    end
end

popup.prevButton:SetScript("OnEnter", function(self) SetNavButtonHighlight(self, true) end)
popup.prevButton:SetScript("OnLeave", function(self) SetNavButtonHighlight(self, false) end)
popup.nextButton:SetScript("OnEnter", function(self) SetNavButtonHighlight(self, true) end)
popup.nextButton:SetScript("OnLeave", function(self) SetNavButtonHighlight(self, false) end)

reminderIcon:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then
        return
    end
    local scale = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    self.isMouseDown = true
    self.isDragging = false
    self.dragStartX = (mx or 0) / scale
    self.dragStartY = (my or 0) / scale
end)

reminderIcon:SetScript("OnMouseUp", function(self, button)
    if button ~= "LeftButton" then
        return
    end

    local wasDragging = self.isDragging
    self.isMouseDown = false
    self.isDragging = false
    self:StopMovingOrSizing()

    if wasDragging then
        SaveReminderIconPosition()
        return
    end

    if not addon.snoozedPopup then
        HideReminderIcon()
        return
    end

    local data = addon.snoozedPopup
    if IsBlockedContext() then
        addon.deferredPopup = {
            eventID = data.eventID,
            title = data.title,
            dateText = data.dateText,
        }
        return
    end

    ShowPopupForEvent(data.eventID, data.title, data.dateText)
end)

reminderIcon:SetScript("OnUpdate", function(self, elapsed)
    self.pulse = self.pulse + elapsed
    local alpha = 0.28 + (math.sin(self.pulse * 2.4) + 1) * 0.16
    self.glow:SetAlpha(alpha)

    if not self.isMouseDown or self.isDragging then
        return
    end

    local scale = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local currentX = (mx or 0) / scale
    local currentY = (my or 0) / scale
    local dx = currentX - self.dragStartX
    local dy = currentY - self.dragStartY

    if (dx * dx + dy * dy) >= 25 then
        self.isDragging = true
        self:StartMoving()
    end
end)

local function CompleteCurrentEvent()
    local eventID = addon.currentPopupEventID
    if not eventID then
        popup.completeCheckButton:SetChecked(false)
        return
    end

    local oldIndex = addon.pendingEventIndex or 1
    addon.scanToken = addon.scanToken + 1
    addon.popupVisibleForEventID = nil
    addon.deferredPopup = nil
    addon.popupHiddenByCombat = false
    addon.snoozedPopup = nil
    HideReminderIcon()

    EnsureCoreDB()
    DRKalenderPopupDB.pendingEventIDs[eventID] = nil
    DRKalenderPopupDB.snoozedEventIDs[eventID] = nil
    DRKalenderPopupDB.completedEventIDs[eventID] = true
    BuildPendingEventList(addon.pendingEventList)

    if addon.pendingEventList and #addon.pendingEventList > 0 then
        local nextIndex = math.min(oldIndex, #addon.pendingEventList)
        popup.completeCheckButton:SetChecked(false)
        ShowPendingEventByIndex(nextIndex)
    else
        addon.currentPopupEventID = nil
        addon.currentPopupTitle = nil
        addon.currentPopupDate = nil
        popup:Hide()
    end
end

popup.completeCheckContainer:SetScript("OnClick", function()
    popup.completeCheckButton:SetChecked(not popup.completeCheckButton:GetChecked())
    if popup.completeCheckButton:GetChecked() then
        CompleteCurrentEvent()
    end
end)

popup.completeCheckButton:SetScript("OnClick", function(self)
    if self:GetChecked() then
        CompleteCurrentEvent()
    end
end)

local function GetFirstPendingEventInfo(foundEvents)
    for _, event in ipairs(foundEvents) do
        if DRKalenderPopupDB.pendingEventIDs[event.eventID] then
            return event
        end
    end
    return nil
end

local function GetCurrentTimeTable()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local now = C_DateAndTime.GetCurrentCalendarTime()
        if now then
            return {
                year = tonumber(now.year or 0) or 0,
                month = tonumber(now.month or 0) or 0,
                day = tonumber(now.monthDay or now.day or 0) or 0,
                hour = tonumber(now.hour or 0) or 0,
                min = tonumber(now.minute or 0) or 0,
            }
        end
    end

    local nowDate = date("*t")
    return {
        year = tonumber(nowDate.year or 0) or 0,
        month = tonumber(nowDate.month or 0) or 0,
        day = tonumber(nowDate.day or 0) or 0,
        hour = tonumber(nowDate.hour or 0) or 0,
        min = tonumber(nowDate.min or 0) or 0,
    }
end

local function GetDaysInMonth(year, month)
    local t = date("*t", time({ year = year, month = month + 1, day = 0, hour = 12 }))
    return tonumber(t and t.day or 30) or 30
end

local function BuildEventSortValue(info)
    if not info then
        return math.huge
    end

    local y = tonumber(info.year or 0) or 0
    local m = tonumber(info.month or 0) or 0
    local d = tonumber(info.monthDay or 0) or 0
    local hh = tonumber(info.hour or 0) or 0
    local mm = tonumber(info.minute or 0) or 0

    if y <= 0 or m <= 0 or d <= 0 then
        return math.huge
    end

    return time({ year = y, month = m, day = d, hour = hh, min = mm, sec = 0 }) or math.huge
end

local function IsRelevantCalendarType(calendarType)
    return calendarType == "PLAYER"
        or calendarType == "GUILD_EVENT"
        or calendarType == "GUILD_ANNOUNCEMENT"
        or calendarType == "COMMUNITY_EVENT"
end

local function CollectRelevantCalendarEvents()
    if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then
        return {}
    end

    local now = GetCurrentTimeTable()
    local nowValue = time({
        year = now.year,
        month = now.month,
        day = now.day,
        hour = now.hour,
        min = now.min,
        sec = 0,
    }) or 0

    local results = {}
    local seen = {}
    local monthOffsetsToScan = 6

    for monthOffset = 0, monthOffsetsToScan do
        local base = date("*t", time({ year = now.year, month = now.month + monthOffset, day = 1, hour = 12 }))
        local year = tonumber(base and base.year or now.year) or now.year
        local month = tonumber(base and base.month or now.month) or now.month
        local daysInMonth = GetDaysInMonth(year, month)

        for monthDay = 1, daysInMonth do
            local numEvents = tonumber(C_Calendar.GetNumDayEvents(monthOffset, monthDay) or 0) or 0
            for index = 1, numEvents do
                local info = C_Calendar.GetDayEvent(monthOffset, monthDay, index)
                if info and IsRelevantCalendarType(info.calendarType) then
                    local eventValue = BuildEventSortValue(info)
                    if eventValue >= nowValue then
                        local rawEventID = info.eventID
                        local eventID = rawEventID and tostring(rawEventID) or string.format(
                            "%s:%04d-%02d-%02d:%02d:%02d:%s",
                            tostring(info.calendarType or "EVENT"),
                            tonumber(info.year or year) or year,
                            tonumber(info.month or month) or month,
                            tonumber(info.monthDay or monthDay) or monthDay,
                            tonumber(info.hour or 0) or 0,
                            tonumber(info.minute or 0) or 0,
                            tostring(info.title or info.eventName or "Kalenderereignis")
                        )

                        if not seen[eventID] then
                            seen[eventID] = true
                            table.insert(results, {
                                eventID = eventID,
                                title = info.title or info.eventName or "Unbenanntes Kalenderereignis",
                                dateText = BuildDateText(info, year, month, monthDay),
                                sortValue = eventValue,
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.sortValue ~= b.sortValue then
            return a.sortValue < b.sortValue
        end
        return tostring(a.title or "") < tostring(b.title or "")
    end)

    return results
end

ScanCalendarEvents = function()
    if addon.sessionDismissed then
        return false, false
    end

    if addon.snoozedPopup then
        ShowReminderIcon()
    end

    EnsureCalendarLoaded()

    local foundEvents = CollectRelevantCalendarEvents()
    local foundAny = #foundEvents > 0

    for _, event in ipairs(foundEvents) do
        local eventID = event.eventID
        local title = event.title
        local dateText = event.dateText

        if not DRKalenderPopupDB.knownEventIDs[eventID] then
            DRKalenderPopupDB.knownEventIDs[eventID] = true
            if not DRKalenderPopupDB.completedEventIDs[eventID] then
                DRKalenderPopupDB.pendingEventIDs[eventID] = {
                    title = title,
                    dateText = dateText,
                }
            end
        else
            local pending = DRKalenderPopupDB.pendingEventIDs[eventID]
            if pending then
                pending.title = title
                pending.dateText = dateText
            end
        end

        local snoozed = DRKalenderPopupDB.snoozedEventIDs[eventID]
        if snoozed then
            snoozed.title = title
            snoozed.dateText = dateText
        end
    end

    BuildPendingEventList(foundEvents)

    local pendingEvent = GetFirstPendingEventInfo(foundEvents)
    if pendingEvent then
        if addon.snoozedPopup then
            addon.snoozedPopup = {
                eventID = pendingEvent.eventID,
                title = pendingEvent.title,
                dateText = pendingEvent.dateText,
            }
            ShowReminderIcon()
            return true, foundAny
        end

        ShowPopupForEvent(pendingEvent.eventID, pendingEvent.title, pendingEvent.dateText)
        return true, foundAny
    end

    for eventID, data in pairs(DRKalenderPopupDB.pendingEventIDs) do
        if type(data) == "table" then
            if addon.snoozedPopup then
                addon.snoozedPopup = {
                    eventID = eventID,
                    title = data.title,
                    dateText = data.dateText,
                }
                ShowReminderIcon()
                return true, foundAny
            end

            ShowPopupForEvent(eventID, data.title, data.dateText)
            return true, foundAny
        end
    end

    if addon.snoozedPopup then
        addon.snoozedPopup = nil
        HideReminderIcon()
    end

    UpdatePopupNavigation()
    return false, foundAny
end

local function StartLoginScanCycle()
    addon.scanToken = addon.scanToken + 1
    local myToken = addon.scanToken

    local function runScan()
        if myToken ~= addon.scanToken or addon.sessionDismissed then
            return
        end

        local shown = ScanCalendarEvents()
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
    EnsureCoreDB()
    msg = tostring(msg or ""):lower()

    if msg == "test" then
        ShowPopupForEvent("test-event", "Mitternachtsraid der Gilde", "15.03.2026 um 20:00 Uhr")
    elseif msg == "scan" then
        local shown, foundAny = ScanCalendarEvents()
        if shown then
            Print("Ausstehendes Kalenderereignis gefunden.")
        elseif foundAny then
            Print("Kalenderereignisse gefunden, aber keines ist für das Addon mehr ausstehend.")
        else
            Print("Es wurden derzeit keine passenden Kalenderereignisse gefunden.")
        end
    elseif msg == "reset" then
        EnsureCoreDB()
        DRKalenderPopupDB.pendingEventIDs = {}
        DRKalenderPopupDB.completedEventIDs = {}
        DRKalenderPopupDB.snoozedEventIDs = {}
        for eventID in pairs(DRKalenderPopupDB.knownEventIDs) do
            DRKalenderPopupDB.pendingEventIDs[eventID] = {
                title = "Kalenderereignis",
                dateText = "Im Kalender ansehen"
            }
        end
        Print("Alle bekannten Kalenderereignisse wurden wieder als ausstehend markiert.")
    elseif msg == "clear" then
        EnsureCoreDB()
        DRKalenderPopupDB.pendingEventIDs = {}
        DRKalenderPopupDB.knownEventIDs = {}
        DRKalenderPopupDB.completedEventIDs = {}
        DRKalenderPopupDB.snoozedEventIDs = {}
        addon.deferredPopup = nil
        addon.popupHiddenByCombat = false
        addon.snoozedPopup = nil
        HideReminderIcon()
        EnsureCoreDB()

        Print("Gespeicherte Kalenderereignisse wurden vollständig gelöscht.")
    elseif msg == "options" then
        ToggleOptionsMenu()
    elseif msg == "minimap" then
        ToggleMinimapButton()
        if DRKalenderPopupDB.minimap.hide then
            Print("Minimap-Button ausgeblendet.")
        else
            Print("Minimap-Button eingeblendet.")
        end
    else
        Print("Befehle: /drpopup test, /drpopup scan, /drpopup reset, /drpopup clear, /drpopup options, /drpopup minimap")
    end
end

addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        EnsureCoreDB()
        EnsureMinimapDB()
        RebuildPendingFromSnoozed()
        addon.sessionDismissed = false
        addon.deferredPopup = nil
        addon.popupHiddenByCombat = false
        addon.snoozedPopup = nil
        HideReminderIcon()
        CreateOptionsMenu()
        CreateMinimapButton()

        StartLoginScanCycle()

    elseif event == "CALENDAR_UPDATE_GUILD_EVENTS" then
        if not addon.sessionDismissed then
            C_Timer.After(1, function()
                if not addon.sessionDismissed then
                    ScanCalendarEvents()
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
                    ScanCalendarEvents()
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
