local _, ns = ...

local FRAME_WIDTH = 320
local FRAME_HEIGHT = 220
local ROW_HEIGHT = 24
local HEADER_HEIGHT = 28
local MAX_ROWS = 5
local PADDING = 8

local LEVEL_COLORS = {
    { threshold = 15, r = 1.0, g = 0.3, b = 0.3 },
    { threshold = 10, r = 1.0, g = 0.6, b = 0.2 },
    { threshold = 5,  r = 1.0, g = 1.0, b = 0.3 },
    { threshold = 0,  r = 0.3, g = 1.0, b = 0.3 },
}

local function GetLevelColor(level)
    for _, entry in ipairs(LEVEL_COLORS) do
        if level >= entry.threshold then
            return entry.r, entry.g, entry.b
        end
    end
    return 1, 1, 1
end

local mainFrame, rows, statusText, noDataText

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING, -(HEADER_HEIGHT + (index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PADDING, -(HEADER_HEIGHT + (index - 1) * ROW_HEIGHT))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.15, 0.15, 0.15, index % 2 == 0 and 0.5 or 0.3)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(0.3, 0.6, 1.0, 0.2)

    row.playerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.playerText:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.playerText:SetWidth(90)
    row.playerText:SetJustifyH("LEFT")

    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.dungeonText:SetPoint("LEFT", row.playerText, "RIGHT", 4, 0)
    row.dungeonText:SetWidth(140)
    row.dungeonText:SetJustifyH("LEFT")

    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.levelText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.levelText:SetWidth(50)
    row.levelText:SetJustifyH("RIGHT")

    row:SetScript("OnClick", function(self)
        if self.keystoneInfo then
            ns.OnKeystoneClicked(self.keystoneInfo)
        end
    end)

    row:SetScript("OnEnter", function(self)
        if self.keystoneInfo then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.keystoneInfo.dungeonName .. " +" .. self.keystoneInfo.level, 1, 1, 1)
            GameTooltip:AddLine(self.keystoneInfo.playerName, 0.7, 0.7, 0.7)
            GameTooltip:AddDoubleLine("Source:", self.keystoneInfo.source, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to open Group Finder for this dungeon", 0, 1, 0)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:Hide()
    return row
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "JixleeKeystoneFillFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.1, 0.92)
    f:SetBackdropBorderColor(0.3, 0.6, 1.0, 0.8)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.framePoint = { point, nil, relPoint, x, y }
    end)
    f:SetClampedToScreen(true)

    local savedPoint = ns.db.framePoint
    if savedPoint then
        f:SetPoint(savedPoint[1], UIParent, savedPoint[3], savedPoint[4], savedPoint[5])
    else
        f:SetPoint("CENTER")
    end

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(HEADER_HEIGHT)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -4)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 2, 0)
    titleText:SetText("|cff00ccffJixlee Keystone Fill|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(18, 18)
    refreshBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    refreshBtn:SetNormalFontObject("GameFontNormalSmall")
    refreshBtn:SetText("R")
    refreshBtn:SetScript("OnClick", function()
        ns.RefreshOwnKeystone()
        if IsInGroup() then
            ns.RequestPartyKeystones()
        end
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Refresh Keystones")
        GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local settingsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    settingsBtn:SetSize(18, 18)
    settingsBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -2, 0)
    settingsBtn:SetNormalFontObject("GameFontNormalSmall")
    settingsBtn:SetText("S")
    settingsBtn:SetScript("OnClick", function()
        ns.OpenSettings()
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Settings")
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local headerBg = f:CreateTexture(nil, "ARTWORK")
    headerBg:SetHeight(1)
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -(HEADER_HEIGHT + 2))
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -(HEADER_HEIGHT + 2))
    headerBg:SetColorTexture(0.4, 0.6, 1.0, 0.4)

    noDataText = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noDataText:SetPoint("CENTER", f, "CENTER", 0, -10)
    noDataText:SetText("No keystones found.\nJoin a party to see keys.")
    noDataText:Hide()

    statusText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING + 2, 6)
    statusText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING - 2, 6)
    statusText:SetJustifyH("LEFT")

    rows = {}
    for i = 1, MAX_ROWS do
        rows[i] = CreateRow(f, i)
    end

    f:Hide()
    return f
end

function ns.UpdateKeystoneUI()
    if not mainFrame then return end
    if not mainFrame:IsShown() then return end

    local keystones = ns.GetSortedKeystones()

    for _, row in ipairs(rows) do
        row:Hide()
        row.keystoneInfo = nil
    end

    if #keystones == 0 then
        noDataText:Show()
    else
        noDataText:Hide()
        for i, info in ipairs(keystones) do
            if i > MAX_ROWS then break end
            local row = rows[i]
            row.playerText:SetText(info.playerName)
            row.dungeonText:SetText(info.dungeonName)

            local r, g, b = GetLevelColor(info.level)
            row.levelText:SetText(string.format("|cff%02x%02x%02x+%d|r", r * 255, g * 255, b * 255, info.level))

            row.keystoneInfo = info
            row:Show()
        end
    end

    local neededHeight = HEADER_HEIGHT + 4 + math.max(#keystones, 1) * ROW_HEIGHT + 24
    mainFrame:SetHeight(math.max(neededHeight, 100))

    local sources = ns.GetActiveDataSources()
    statusText:SetText("Sources: " .. table.concat(sources, ", "))
end

function ns.ToggleKeystoneFrame()
    if not mainFrame then
        mainFrame = CreateMainFrame()
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        ns.RefreshOwnKeystone()
        if IsInGroup() then
            ns.RequestPartyKeystones()
        end
        ns.UpdateKeystoneUI()
    end
end

function ns.ShowKeystoneFrame()
    if not mainFrame then
        mainFrame = CreateMainFrame()
    end
    if not mainFrame:IsShown() then
        mainFrame:Show()
        ns.RefreshOwnKeystone()
        if IsInGroup() then
            ns.RequestPartyKeystones()
        end
    end
    ns.UpdateKeystoneUI()
end
