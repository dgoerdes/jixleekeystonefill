local _, ns = ...

local PLAYSTYLE_LABELS = {}
local PLAYSTYLE_ORDER = {}

local function BuildPlaystyleOptions()
    wipe(PLAYSTYLE_LABELS)
    wipe(PLAYSTYLE_ORDER)

    local styles = {
        { value = 0, label = "None" },
        { value = Enum.LFGEntryGeneralPlaystyle.Learning, label = "Learning" },
        { value = Enum.LFGEntryGeneralPlaystyle.FunRelaxed, label = "Relaxed" },
        { value = Enum.LFGEntryGeneralPlaystyle.FunSerious, label = "Competitive" },
        { value = Enum.LFGEntryGeneralPlaystyle.Expert, label = "Carry Offered" },
    }

    for _, s in ipairs(styles) do
        PLAYSTYLE_LABELS[s.value] = s.label
        table.insert(PLAYSTYLE_ORDER, s.value)
    end
end

function ns.GetPlaystyleLabel(value)
    return PLAYSTYLE_LABELS[value] or "None"
end

function ns.InitOptions()
    BuildPlaystyleOptions()

    if ns.db.defaultPlaystyle == nil then
        ns.db.defaultPlaystyle = Enum.LFGEntryGeneralPlaystyle.FunSerious
    end

    local panel = CreateFrame("Frame")
    panel:SetSize(600, 400)
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ccffJixlee Keystone Fill|r")

    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ver:SetText("v" .. (ns.version or "1.0.0"))

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -20)
    header:SetText("Group Finder")

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    divider:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    divider:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -16)
    label:SetText("Default Playstyle:")

    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", label, "RIGHT", 12, 0)
    dropdown:SetWidth(200)

    dropdown:SetDefaultText("Select Playstyle")

    dropdown:SetSelectionText(function()
        return PLAYSTYLE_LABELS[ns.db.defaultPlaystyle] or "None"
    end)

    dropdown:SetupMenu(function(dd, rootDescription)
        for _, value in ipairs(PLAYSTYLE_ORDER) do
            rootDescription:CreateRadio(
                PLAYSTYLE_LABELS[value],
                function() return ns.db.defaultPlaystyle == value end,
                function() ns.db.defaultPlaystyle = value end,
                value
            )
        end
    end)

    local playstyleDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    playstyleDesc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    playstyleDesc:SetText("The playstyle to auto-select when opening Group Finder from a keystone click.\nSet to \"None\" to leave the playstyle unchanged.")
    playstyleDesc:SetTextColor(0.6, 0.6, 0.6)

    -- Helper to create a labeled numeric input row
    local function CreateNumberSetting(parent, anchor, dbKey, labelText, descText, maxLetters)
        if ns.db[dbKey] == nil then ns.db[dbKey] = 0 end

        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(50)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
        row:SetPoint("RIGHT", parent, "RIGHT", -16, 0)

        local rowLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        rowLabel:SetPoint("TOPLEFT")
        rowLabel:SetText(labelText)

        local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        editBox:SetSize(80, 22)
        editBox:SetPoint("LEFT", rowLabel, "RIGHT", 12, 0)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(maxLetters or 5)
        editBox:SetNumeric(true)
        editBox:SetText(ns.db[dbKey] > 0 and tostring(ns.db[dbKey]) or "")

        editBox:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText()) or 0
            ns.db[dbKey] = val
            self:ClearFocus()
        end)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editBox:SetScript("OnEditFocusLost", function(self)
            local val = tonumber(self:GetText()) or 0
            ns.db[dbKey] = val
            if val == 0 then self:SetText("") end
        end)

        local rowDesc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rowDesc:SetPoint("TOPLEFT", rowLabel, "BOTTOMLEFT", 0, -4)
        rowDesc:SetText(descText)
        rowDesc:SetTextColor(0.6, 0.6, 0.6)

        return row
    end

    local ratingRow = CreateNumberSetting(panel, playstyleDesc, "defaultMythicPlusRating",
        "Min. Mythic+ Rating:",
        "Minimum M+ rating requirement. Leave empty or 0 to skip.", 5)

    CreateNumberSetting(panel, ratingRow, "defaultItemLevel",
        "Min. Item Level:",
        "Minimum item level requirement. Leave empty or 0 to skip.", 4)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Jixlee Keystone Fill")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategoryID = category:GetID()
end

function ns.OpenSettings()
    Settings.OpenToCategory(ns.settingsCategoryID)
end
