local _, ns = ...

local DUNGEON_CATEGORY_ID = 2

local activityCache = {}

local function BuildActivityCache()
    wipe(activityCache)

    local activities = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY_ID)
    if not activities then return end

    for _, activityID in ipairs(activities) do
        local info = C_LFGList.GetActivityInfoTable(activityID)
        if info and info.isMythicPlusActivity then
            activityCache[activityID] = info
        end
    end
end

local function FindActivityForMap(challengeMapID)
    if not next(activityCache) then
        BuildActivityCache()
    end

    local targetName = C_ChallengeMode.GetMapUIInfo(challengeMapID)
    if not targetName then return nil end
    local targetLower = targetName:lower()

    for activityID, info in pairs(activityCache) do
        if info.fullName and info.fullName:lower():find(targetLower, 1, true) then
            return activityID, info
        end
    end

    for activityID, info in pairs(activityCache) do
        if info.shortName and info.shortName:lower():find(targetLower, 1, true) then
            return activityID, info
        end
    end

    return nil
end

local function TryOpenGroupFinderForActivity(activityID)
    PVEFrame_ShowFrame("GroupFinderFrame", LFGListPVEStub)

    C_Timer.After(0.3, function()
        if not LFGListFrame or not LFGListFrame.EntryCreation then return end

        local entryCreation = LFGListFrame.EntryCreation
        local baseFilters = LFGListFrame.baseFilters or Enum.LFGListFilter.PvE

        local origSetTitle = LFGListEntryCreation_SetTitleFromActivityInfo
        LFGListEntryCreation_SetTitleFromActivityInfo = function() end

        LFGListEntryCreation_Show(entryCreation, baseFilters, DUNGEON_CATEGORY_ID)
        LFGListEntryCreation_Select(entryCreation, nil, nil, nil, activityID)

        local playstyle = ns.db.defaultPlaystyle
        if playstyle and playstyle > 0 then
            LFGListEntryCreation_OnPlayStyleSelectedInternal(entryCreation, playstyle)
            entryCreation.PlayStyleDropdown:GenerateMenu()
        end

        LFGListEntryCreation_SetTitleFromActivityInfo = origSetTitle

        local mpRating = ns.db.defaultMythicPlusRating
        if mpRating and mpRating > 0 and entryCreation.MythicPlusRating:IsShown() then
            entryCreation.MythicPlusRating.CheckButton:SetChecked(true)
            entryCreation.MythicPlusRating.EditBox:SetText(tostring(mpRating))
        end

        local ilvl = ns.db.defaultItemLevel
        if ilvl and ilvl > 0 and entryCreation.ItemLevel:IsShown() then
            entryCreation.ItemLevel.CheckButton:SetChecked(true)
            entryCreation.ItemLevel.EditBox:SetText(tostring(ilvl))
        end
    end)
end

function ns.OnKeystoneClicked(keystoneInfo)
    if not keystoneInfo or not keystoneInfo.challengeMapID then return end

    local activityID = FindActivityForMap(keystoneInfo.challengeMapID)

    if activityID then
        TryOpenGroupFinderForActivity(activityID)
        print(string.format(
            "|cff00ccff[JixleeKeystoneFill]|r Opening Group Finder for %s +%d",
            keystoneInfo.dungeonName or "Unknown",
            keystoneInfo.level or 0
        ))
    else
        PVEFrame_ShowFrame("GroupFinderFrame", LFGListPVEStub)
        print(string.format(
            "|cff00ccff[JixleeKeystoneFill]|r Could not find M+ activity for %s. Group Finder opened.",
            keystoneInfo.dungeonName or "Unknown"
        ))
    end
end

local entryCreationHooked = false

local function SetupEntryCreationHook()
    if entryCreationHooked then return true end
    if not LFGListFrame or not LFGListFrame.EntryCreation then
        return false
    end

    LFGListFrame.EntryCreation:HookScript("OnShow", function()
        if LFGListFrame.categoryID == DUNGEON_CATEGORY_ID then
            ns.ShowKeystoneFrame()
        end
    end)

    entryCreationHooked = true
    return true
end

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(5, BuildActivityCache)
    SetupEntryCreationHook()
end)

if not SetupEntryCreationHook() then
    local function OnAddonLoaded(event, loadedAddon)
        if SetupEntryCreationHook() then
            ns.UnregisterEvent("ADDON_LOADED", OnAddonLoaded)
        end
    end
    ns.RegisterEvent("ADDON_LOADED", OnAddonLoaded)
end
