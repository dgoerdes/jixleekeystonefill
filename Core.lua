local addonName, ns = ...

ns.addonName = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

ns.partyKeystones = {}
ns.db = {}

local defaults = {
    framePoint = { "CENTER", nil, "CENTER", 0, 0 },
    frameWidth = 320,
    frameHeight = 220,
}

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function ns.RegisterEvent(event, handler)
    eventHandlers[event] = eventHandlers[event] or {}
    table.insert(eventHandlers[event], handler)
    eventFrame:RegisterEvent(event)
end

function ns.UnregisterEvent(event, handler)
    local handlers = eventHandlers[event]
    if not handlers then return end
    for i = #handlers, 1, -1 do
        if handlers[i] == handler then
            table.remove(handlers, i)
        end
    end
    if #handlers == 0 then
        eventFrame:UnregisterEvent(event)
        eventHandlers[event] = nil
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if not handlers then return end
    for _, handler in ipairs(handlers) do
        handler(event, ...)
    end
end)

local function OnAddonLoaded(event, loadedAddon)
    if loadedAddon ~= addonName then return end

    JixleeKeystoneFillDB = JixleeKeystoneFillDB or {}
    for k, v in pairs(defaults) do
        if JixleeKeystoneFillDB[k] == nil then
            JixleeKeystoneFillDB[k] = v
        end
    end
    ns.db = JixleeKeystoneFillDB

    ns.InitKeystoneData()
    ns.InitOptions()

    ns.UnregisterEvent("ADDON_LOADED", OnAddonLoaded)
end

ns.RegisterEvent("ADDON_LOADED", OnAddonLoaded)

local function OnPlayerEnteringWorld()
    C_Timer.After(2, function()
        ns.RefreshOwnKeystone()
        if IsInGroup() then
            ns.RequestPartyKeystones()
        end
    end)
end

ns.RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)

SLASH_JIXLEEKEYSTONEFILL1 = "/jkf"
SlashCmdList["JIXLEEKEYSTONEFILL"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "help" then
        print("|cff00ccff[JixleeKeystoneFill]|r Commands:")
        print("  /jkf - Toggle keystone window")
        print("  /jkf refresh - Refresh keystone data")
        print("  /jkf settings - Open settings")
        print("  /jkf help - Show this help")
    elseif msg == "settings" or msg == "options" then
        ns.OpenSettings()
    elseif msg == "refresh" then
        ns.RefreshOwnKeystone()
        if IsInGroup() then
            ns.RequestPartyKeystones()
        end
        print("|cff00ccff[JixleeKeystoneFill]|r Refreshing keystone data...")
    else
        ns.ToggleKeystoneFrame()
    end
end

ns.RegisterEvent("GROUP_LEFT", function()
    wipe(ns.partyKeystones)
    if ns.UpdateKeystoneUI then
        ns.UpdateKeystoneUI()
    end
end)
