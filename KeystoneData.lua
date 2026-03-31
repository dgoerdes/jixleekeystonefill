local _, ns = ...

local COMM_PREFIX = "JixleeKF"
local REQUEST_DELAY = 1.0

local openRaidLib = nil
local libKeystone = nil
local libKeystoneTable = {}

local function NormalizeName(name)
    if not name then return nil end
    return (strsplit("-", name))
end

local function FullName(name)
    if not name then return nil end
    if not name:find("-") then
        return name .. "-" .. GetRealmName()
    end
    return name
end

local function PlayerExists(data, playerName, mapID, level)
    local norm = NormalizeName(playerName)
    if not norm then return false end
    for existing, info in pairs(data) do
        if NormalizeName(existing) == norm
            and info.challengeMapID == mapID
            and info.level == level then
            return true
        end
    end
    return false
end

function ns.GetActiveDataSources()
    local sources = {}
    if openRaidLib and openRaidLib.GetAllKeystonesInfo then
        table.insert(sources, "LibOpenRaid")
    end
    if libKeystone then
        table.insert(sources, "LibKeystone")
    end
    table.insert(sources, "JixleeKF")
    return sources
end

function ns.RefreshOwnKeystone()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()

    if not mapID or mapID == 0 or not level or level == 0 then
        local activeLevel, _, isActive = C_ChallengeMode.GetActiveKeystoneInfo()
        if isActive and activeLevel and activeLevel > 0 then
            local activeMapID = C_ChallengeMode.GetActiveChallengeMapID()
            if activeMapID and activeMapID > 0 then
                mapID = activeMapID
                level = activeLevel
            end
        end
    end

    local playerFullName = FullName(UnitName("player"))

    if mapID and mapID > 0 and level and level > 0 then
        ns.partyKeystones[playerFullName] = {
            challengeMapID = mapID,
            level = level,
            source = "self",
        }
    else
        ns.partyKeystones[playerFullName] = nil
    end

    if ns.UpdateKeystoneUI then
        ns.UpdateKeystoneUI()
    end
end

local function OnLibKeystoneData(keyLevel, keyMapID, playerRating, playerName, channel)
    if channel ~= "PARTY" then return end

    local fullName = FullName(playerName)
    if not fullName then return end

    if not PlayerExists(ns.partyKeystones, fullName, keyMapID, keyLevel) then
        ns.partyKeystones[fullName] = {
            challengeMapID = keyMapID,
            level = keyLevel,
            source = "LibKeystone",
        }
    end

    if ns.UpdateKeystoneUI then
        ns.UpdateKeystoneUI()
    end
end

local function MergeOpenRaidData()
    if not openRaidLib or not openRaidLib.GetAllKeystonesInfo then return end

    local success, result = pcall(openRaidLib.GetAllKeystonesInfo)
    if not success or not result then return end

    for playerName, info in pairs(result) do
        if info and info.challengeMapID and info.level and info.level > 0 then
            local fullName = FullName(playerName)
            if not PlayerExists(ns.partyKeystones, fullName, info.challengeMapID, info.level) then
                local existing = ns.partyKeystones[fullName]
                if not existing or existing.source == "comm" then
                    ns.partyKeystones[fullName] = {
                        challengeMapID = info.challengeMapID,
                        level = info.level,
                        source = "LibOpenRaid",
                    }
                end
            end
        end
    end

    if ns.UpdateKeystoneUI then
        ns.UpdateKeystoneUI()
    end
end

local function OnCommReceived(event, prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end

    sender = Ambiguate(sender, "none")
    local fullSender = FullName(sender)

    if message == "REQ" then
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        if mapID and mapID > 0 and level and level > 0 then
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, "KEY:" .. mapID .. ":" .. level, "PARTY")
        else
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, "NOKEY", "PARTY")
        end
        return
    end

    local cmd, mapStr, levelStr = strsplit(":", message)
    if cmd == "KEY" and mapStr and levelStr then
        local mapID = tonumber(mapStr)
        local level = tonumber(levelStr)
        if mapID and level and level > 0 then
            if not PlayerExists(ns.partyKeystones, fullSender, mapID, level) then
                local existing = ns.partyKeystones[fullSender]
                if not existing or existing.source == "comm" then
                    ns.partyKeystones[fullSender] = {
                        challengeMapID = mapID,
                        level = level,
                        source = "comm",
                    }
                    if ns.UpdateKeystoneUI then
                        ns.UpdateKeystoneUI()
                    end
                end
            end
        end
    end
end

function ns.RequestPartyKeystones()
    ns.RefreshOwnKeystone()
    MergeOpenRaidData()

    if libKeystone then
        pcall(function()
            libKeystone.Request("PARTY")
        end)
    end

    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "REQ", "PARTY")

    C_Timer.After(2, function()
        MergeOpenRaidData()
    end)
end

function ns.GetSortedKeystones()
    local result = {}
    local playerFullName = FullName(UnitName("player"))

    for unitName, info in pairs(ns.partyKeystones) do
        if info and info.challengeMapID and info.level and info.level > 0 then
            local isInParty = (unitName == playerFullName)
                or UnitInParty(unitName)
                or UnitInParty(NormalizeName(unitName))

            if isInParty then
                local dungeonName = C_ChallengeMode.GetMapUIInfo(info.challengeMapID)
                table.insert(result, {
                    playerName = NormalizeName(unitName),
                    fullName = unitName,
                    dungeonName = dungeonName or "Unknown",
                    challengeMapID = info.challengeMapID,
                    level = info.level,
                    source = info.source,
                })
            end
        end
    end

    table.sort(result, function(a, b)
        if a.level ~= b.level then
            return a.level > b.level
        end
        return a.playerName < b.playerName
    end)

    return result
end

function ns.InitKeystoneData()
    C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)

    if LibStub then
        openRaidLib = LibStub("LibOpenRaid-1.0", true)
        libKeystone = LibStub("LibKeystone", true)
    end

    if libKeystone then
        pcall(function()
            libKeystone.Register(libKeystoneTable, OnLibKeystoneData)
        end)
    end

    ns.RegisterEvent("CHAT_MSG_ADDON", OnCommReceived)

    ns.RegisterEvent("GROUP_ROSTER_UPDATE", function()
        if IsInGroup() then
            C_Timer.After(REQUEST_DELAY, function()
                if IsInGroup() then
                    ns.RequestPartyKeystones()
                end
            end)
        end
    end)

    ns.RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", function()
        ns.RefreshOwnKeystone()
    end)

    ns.RegisterEvent("BAG_UPDATE", function()
        ns.RefreshOwnKeystone()
    end)

    ns.RegisterEvent("CHALLENGE_MODE_COMPLETED", function()
        C_Timer.After(2, function()
            ns.RefreshOwnKeystone()
            if IsInGroup() then
                ns.RequestPartyKeystones()
            end
        end)
    end)
end
