-- SmartPotion - zone-aware mana & healing potion macro generator
-- Interface: 20505 (TBC Classic Anniversary 2.5.5)

local addonName, addon = ...

local frame = CreateFrame("Frame")
local Rows = {}
local version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("SmartPotion", "Version")) or "1.0.0"
addon.version = version

local UpdateMacro
local RefreshUI
local UpdateTabVisuals

-- Active UI tab: "mana" or "heal"
local activeTab = "mana"

local TAB_CONFIG = {
    mana = { macroName = "SP", fallbackIcon = "INV_Potion_77", titleSuffix = "Mana"    },
    heal = { macroName = "SH", fallbackIcon = "INV_Potion_54", titleSuffix = "Healing" },
}

local function GetActiveList()
    if not SmartPotionDB then return nil end
    return SmartPotionDB[activeTab]
end

local function GetDefaultsFor(tab)
    if tab == "heal" then return SmartPotion_DefaultHealPotions end
    return SmartPotion_DefaultManaPotions
end

--==========================================================
--                  1. OPTIONS WINDOW
--==========================================================

local MainFrame = CreateFrame("Frame", "SmartPotionMainFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(560, 580)
MainFrame:SetPoint("CENTER")
MainFrame:SetFrameStrata("DIALOG")
MainFrame:SetMovable(true); MainFrame:EnableMouse(true); MainFrame:RegisterForDrag("LeftButton")
tinsert(UISpecialFrames, "SmartPotionMainFrame")
MainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
MainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
MainFrame:Hide()

MainFrame.Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
MainFrame.Title:SetPoint("TOP", 0, -20)
MainFrame.Title:SetText("SmartPotion")

local CloseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
CloseBtn:SetPoint("TOPRIGHT", -5, -5)

-- Tab buttons
local ManaTab = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
ManaTab:SetSize(90, 26); ManaTab:SetPoint("TOPLEFT", 25, -50); ManaTab:SetText("Mana (SP)")

local HealTab = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
HealTab:SetSize(90, 26); HealTab:SetPoint("LEFT", ManaTab, "RIGHT", 8, 0); HealTab:SetText("Healing (SH)")

ManaTab:SetScript("OnClick", function()
    activeTab = "mana"
    if SmartPotionDB then SmartPotionDB.activeTab = activeTab end
    UpdateTabVisuals(); RefreshUI()
end)
HealTab:SetScript("OnClick", function()
    activeTab = "heal"
    if SmartPotionDB then SmartPotionDB.activeTab = activeTab end
    UpdateTabVisuals(); RefreshUI()
end)

-- Info / current zone indicator
MainFrame.Info = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
MainFrame.Info:SetPoint("TOP", 0, -90)
MainFrame.Info:SetWidth(500); MainFrame.Info:SetJustifyH("CENTER")
MainFrame.Info:SetText("Macros |cFFFFFF00SP|r (mana) and |cFFFFFF00SH|r (healing) auto-update on zone change.\nTop-to-bottom = priority. Click [any]/[SSC]/[TK] to cycle zone restriction.")

MainFrame.ZoneText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
MainFrame.ZoneText:SetPoint("TOP", 0, -130); MainFrame.ZoneText:SetText("")

-- Input row
local InputLabel = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
InputLabel:SetPoint("TOPLEFT", 25, -155)
InputLabel:SetText("Add Potion (type a name, or shift-click an item):")

local PotionInput = CreateFrame("EditBox", "SmartPotionInput", MainFrame, "InputBoxTemplate")
PotionInput:SetSize(300, 22); PotionInput:SetPoint("TOPLEFT", 30, -178)
PotionInput:SetAutoFocus(false)

local AddBtn = CreateFrame("Button", "SmartPotionAddBtn", MainFrame, "UIPanelButtonTemplate")
AddBtn:SetSize(60, 26); AddBtn:SetPoint("LEFT", PotionInput, "RIGHT", 10, 0); AddBtn:SetText("Add")

local ResetBtn = CreateFrame("Button", "SmartPotionResetBtn", MainFrame, "UIPanelButtonTemplate")
ResetBtn:SetSize(110, 26); ResetBtn:SetPoint("LEFT", AddBtn, "RIGHT", 10, 0); ResetBtn:SetText("Reset Defaults")

-- Scroll list background
local ListBG = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
ListBG:SetSize(510, 340); ListBG:SetPoint("BOTTOM", 0, 25)
ListBG:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
ListBG:SetBackdropColor(0, 0, 0, 0.5)

local ScrollFrame = CreateFrame("ScrollFrame", "SmartPotionScroll", ListBG, "UIPanelScrollFrameTemplate")
ScrollFrame:SetPoint("TOPLEFT", 10, -10); ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

local Content = CreateFrame("Frame", nil, ScrollFrame)
Content:SetSize(470, 1)
ScrollFrame:SetScrollChild(Content)

UpdateTabVisuals = function()
    if activeTab == "mana" then
        ManaTab:Disable(); HealTab:Enable()
        MainFrame.Title:SetText("SmartPotion - Mana")
    else
        ManaTab:Enable(); HealTab:Disable()
        MainFrame.Title:SetText("SmartPotion - Healing")
    end
end

--==========================================================
--                  2. ZONE HELPERS
--==========================================================

local function GetZoneCode()
    local zone = GetRealZoneText() or ""
    if not SmartPotion_ZoneNames then return nil end
    for code, zoneList in pairs(SmartPotion_ZoneNames) do
        if type(zoneList) == "table" then
            for _, z in ipairs(zoneList) do
                if z == zone then return code end
            end
        elseif zoneList == zone then
            return code
        end
    end
    return nil
end

local function ZoneLabel(zoneCode)
    if zoneCode == "tk"  then return "TK"  end
    if zoneCode == "ssc" then return "SSC" end
    return "any"
end

local function ZoneColor(zoneCode)
    if zoneCode == "tk"  then return "|cFFCC66FF" end
    if zoneCode == "ssc" then return "|cFF00CCFF" end
    return "|cFF888888"
end

--==========================================================
--                  3. ROW MANAGEMENT
--==========================================================

local function AddPotionRow(index, potionData, yPos)
    local row = CreateFrame("Frame", nil, Content)
    row:SetSize(460, 40); row:SetPoint("TOPLEFT", 5, yPos)

    -- Icon
    row.Icon = row:CreateTexture(nil, "OVERLAY")
    row.Icon:SetSize(28, 28); row.Icon:SetPoint("LEFT", 5, 0)
    local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
    if potionData.id then
        local t = GetItemIcon(potionData.id)
        if t then iconTexture = t end
    end
    row.Icon:SetTexture(iconTexture)

    -- Hover tooltip on icon
    row.IconHover = CreateFrame("Frame", nil, row)
    row.IconHover:SetAllPoints(row.Icon)
    row.IconHover:EnableMouse(true)
    row.IconHover:SetScript("OnEnter", function(self)
        if potionData.id then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. potionData.id)
            GameTooltip:Show()
        end
    end)
    row.IconHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Enabled checkbox
    row.Check = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
    row.Check:SetPoint("LEFT", row.Icon, "RIGHT", 0, 0)
    row.Check:SetChecked(potionData.enabled)
    row.Check:SetScript("OnClick", function(self)
        potionData.enabled = self:GetChecked() and true or false
        UpdateMacro()
    end)

    -- Name
    row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Name:SetPoint("LEFT", row.Check, "RIGHT", 5, 0)
    row.Name:SetWidth(180); row.Name:SetJustifyH("LEFT")
    row.Name:SetText(potionData.name)

    -- Zone tag (clickable to cycle: any -> SSC -> TK -> any)
    row.Zone = CreateFrame("Button", nil, row)
    row.Zone:SetSize(60, 22)
    row.Zone:SetPoint("LEFT", row.Name, "RIGHT", 5, 0)
    row.Zone.Text = row.Zone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Zone.Text:SetAllPoints()
    row.Zone.Text:SetText(ZoneColor(potionData.zone) .. "[" .. ZoneLabel(potionData.zone) .. "]|r")
    row.Zone:SetScript("OnClick", function()
        if potionData.zone == nil then
            potionData.zone = "ssc"
        elseif potionData.zone == "ssc" then
            potionData.zone = "tk"
        else
            potionData.zone = nil
        end
        RefreshUI(); UpdateMacro()
    end)
    row.Zone:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Click to cycle zone restriction")
        GameTooltip:AddLine("|cFF888888any|r -> |cFF00CCFFSSC|r -> |cFFCC66FFTK|r -> |cFF888888any|r")
        GameTooltip:Show()
    end)
    row.Zone:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Up
    row.Up = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Up:SetSize(24, 20); row.Up:SetPoint("RIGHT", -105, 0); row.Up:SetText("^")
    row.Up:SetScript("OnClick", function()
        if index > 1 then
            local p = GetActiveList()
            if not p then return end
            local item = table.remove(p, index)
            table.insert(p, index - 1, item)
            RefreshUI(); UpdateMacro()
        end
    end)

    -- Down
    row.Down = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Down:SetSize(24, 20); row.Down:SetPoint("LEFT", row.Up, "RIGHT", 3, 0); row.Down:SetText("v")
    row.Down:SetScript("OnClick", function()
        local p = GetActiveList()
        if not p then return end
        if index < #p then
            local item = table.remove(p, index)
            table.insert(p, index + 1, item)
            RefreshUI(); UpdateMacro()
        end
    end)

    -- Remove
    row.Remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Remove:SetSize(60, 20); row.Remove:SetPoint("RIGHT", -30, 0); row.Remove:SetText("Remove")
    row.Remove:SetScript("OnClick", function()
        local p = GetActiveList()
        if not p then return end
        print("|cFFFF0000SmartPotion:|r Removed " .. potionData.name)
        table.remove(p, index)
        RefreshUI(); UpdateMacro()
    end)

    table.insert(Rows, row)
end

RefreshUI = function()
    for _, row in ipairs(Rows) do row:Hide() end
    Rows = {}

    local list = GetActiveList()
    if not list then return end

    for i, potion in ipairs(list) do
        AddPotionRow(i, potion, -((i - 1) * 45))
    end
    Content:SetHeight(math.max(1, #list * 45))

    local zc = GetZoneCode()
    local zoneText = GetRealZoneText() or "Unknown"
    if zc then
        MainFrame.ZoneText:SetText("Current zone: " .. ZoneColor(zc) .. zoneText .. "|r (zone-restricted potions active)")
    else
        MainFrame.ZoneText:SetText("Current zone: |cFFFFFFFF" .. zoneText .. "|r (anywhere potions only)")
    end
end

--==========================================================
--                  4. NAME -> ID RESOLUTION
--==========================================================

-- Walk every potion and try to resolve its real item ID by name.
-- Works as soon as the client has seen the item once (loot, vendor, AH, link).
-- Returns true if anything changed.
local function ResolveItemIds()
    if not SmartPotionDB then return false end
    local changed = false
    for _, listKey in ipairs({"mana", "heal"}) do
        local list = SmartPotionDB[listKey]
        if list then
            for _, potion in ipairs(list) do
                if potion.name then
                    local _, link = GetItemInfo(potion.name)
                    if link then
                        local id = tonumber(link:match("item:(%d+)"))
                        if id and id ~= potion.id then
                            potion.id = id
                            changed = true
                        end
                    end
                end
            end
        end
    end
    return changed
end

--==========================================================
--                  5. MACRO ENGINE
--==========================================================

-- Build the macro body. Only includes potions you actually have so that
-- TBC's non-inventory-aware #showtooltip lands on the right icon.
local function UpdateMacroForList(listKey, zoneChanged)
    if InCombatLockdown() then return end
    if not SmartPotionDB then return end
    local list = SmartPotionDB[listKey]
    if not list then return end

    local cfg = TAB_CONFIG[listKey]
    local zoneCode = GetZoneCode()

    local lines = { "#showtooltip" }
    local firstIcon = nil

    -- Pass 1: in-stock potions only (or those with unknown IDs)
    for _, potion in ipairs(list) do
        if potion.enabled and ((not potion.zone) or potion.zone == zoneCode) then
            local hasStock = (not potion.id) or (GetItemCount(potion.id) or 0) > 0
            if hasStock then
                tinsert(lines, "/use " .. potion.name)
                if not firstIcon and potion.id then
                    firstIcon = GetItemIcon(potion.id)
                end
            end
        end
    end

    -- Pass 2: if we have nothing in stock, fall back to everything (so the
    -- macro at least shows *something* and reports "you don't have that").
    if #lines == 1 then
        for _, potion in ipairs(list) do
            if potion.enabled and ((not potion.zone) or potion.zone == zoneCode) then
                tinsert(lines, "/use " .. potion.name)
                if not firstIcon and potion.id then
                    firstIcon = GetItemIcon(potion.id)
                end
            end
        end
    end

    if #lines == 1 then return end

    local body = table.concat(lines, "\n")
    local icon = firstIcon or cfg.fallbackIcon
    local index = GetMacroIndexByName(cfg.macroName)
    local oldBody = (index and index > 0) and GetMacroBody(index) or ""
    oldBody = (oldBody or ""):gsub("%s+$", "")
    local trimmed = body:gsub("%s+$", "")

    local bodyChanged = (trimmed ~= oldBody)
    local iconChanged = false
    if index and index > 0 then
        local _, currentIcon = GetMacroInfo(index)
        iconChanged = (currentIcon ~= icon)
    end

    if bodyChanged or iconChanged or not index or index == 0 then
        if not index or index == 0 then
            CreateMacro(cfg.macroName, icon, body, 1)
            print("|cFF00FFFFSmartPotion:|r Created macro '" .. cfg.macroName .. "'.")
        else
            EditMacro(index, cfg.macroName, icon, body)
            if zoneChanged then
                print("|cFF00FFFFSmartPotion:|r " .. cfg.macroName .. " updated for " .. (GetRealZoneText() or "current zone") .. ".")
            end
        end
    end
end

local lastZoneCode = false  -- false, distinct from nil "no zone match"
UpdateMacro = function()
    local zoneCode = GetZoneCode()
    local zoneChanged = (lastZoneCode ~= zoneCode)
    lastZoneCode = zoneCode
    UpdateMacroForList("mana", zoneChanged)
    UpdateMacroForList("heal", zoneChanged)
end

--==========================================================
--                  5. INPUT LOGIC
--==========================================================

AddBtn:SetScript("OnClick", function()
    local val = PotionInput:GetText()
    if not val or val == "" then return end

    local itemID = val:match("item:(%d+)")
    local cleanName = val:match("%[(.-)%]") or val

    local list = GetActiveList()
    if not list then return end

    tinsert(list, {
        name = cleanName,
        id = tonumber(itemID),
        zone = SmartPotion_KnownZones and SmartPotion_KnownZones[cleanName] or nil,
        enabled = true,
    })

    print("|cFF00FF00SmartPotion:|r Added " .. cleanName .. " to " .. activeTab .. " list")
    PotionInput:SetText(""); PotionInput:ClearFocus()
    RefreshUI(); UpdateMacro()
end)

ResetBtn:SetScript("OnClick", function()
    local list = GetActiveList()
    if not list then return end
    wipe(list)
    for _, p in ipairs(GetDefaultsFor(activeTab)) do
        tinsert(list, { name = p.name, id = p.id, zone = p.zone, enabled = true })
    end
    RefreshUI(); UpdateMacro()
    print("|cFF00FFFFSmartPotion:|r " .. activeTab .. " list reset to defaults.")
end)

if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if SmartPotionMainFrame and SmartPotionMainFrame:IsVisible() then
            if PotionInput then
                PotionInput:SetFocus()
                PotionInput:SetText(link)
            end
        end
    end)
end

--==========================================================
--                  6. MINIMAP BUTTON
--==========================================================

local btn = CreateFrame("Button", "SmartPotionMinimapButton", Minimap)
btn:SetSize(31, 31); btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(10)
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

btn.icon = btn:CreateTexture(nil, "BACKGROUND")
btn.icon:SetSize(20, 20)
btn.icon:SetTexture("Interface\\Icons\\INV_Potion_77")
btn.icon:SetPoint("CENTER", 0, 0)

btn.border = btn:CreateTexture(nil, "OVERLAY")
btn.border:SetSize(53, 53); btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
btn.border:SetPoint("TOPLEFT")

local function UpdateButtonPosition()
    local angle = math.rad(SmartPotionDB.minimapPos or 200)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(angle)), (80 * math.sin(angle)) - 52)
end

btn:RegisterForDrag("LeftButton")
btn:SetScript("OnUpdate", function(self)
    if self.isDragging then
        local x, y = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        SmartPotionDB.minimapPos = math.deg(math.atan2(y/scale - cy, x/scale - cx))
        UpdateButtonPosition()
    end
end)
btn:SetScript("OnDragStart", function(self) self.isDragging = true end)
btn:SetScript("OnDragStop", function(self) self.isDragging = false end)
btn:SetScript("OnClick", function()
    if MainFrame:IsShown() then MainFrame:Hide() else RefreshUI(); MainFrame:Show() end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("SmartPotion - v" .. version)
    GameTooltip:AddLine("|cff777777Click for options|r")
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

--==========================================================
--                  7. SLASH & EVENTS
--==========================================================

SLASH_SP1 = "/sp"
SLASH_SP2 = "/smartpotion"
SlashCmdList["SP"] = function()
    if MainFrame:IsShown() then
        MainFrame:Hide()
    else
        RefreshUI(); MainFrame:Show()
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local bagUpdatePending = false
local function ScheduleBagRefresh()
    if bagUpdatePending then return end
    bagUpdatePending = true
    C_Timer.After(0.5, function()
        bagUpdatePending = false
        if not InCombatLockdown() then
            local changed = ResolveItemIds()
            if changed and MainFrame:IsShown() then RefreshUI() end
            UpdateMacro()
        end
    end)
end

local function PopulateDefault(listKey)
    SmartPotionDB[listKey] = {}
    for _, p in ipairs(GetDefaultsFor(listKey)) do
        tinsert(SmartPotionDB[listKey], { name = p.name, id = p.id, zone = p.zone, enabled = true })
    end
end

frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "SmartPotion" then
        SmartPotionDB = SmartPotionDB or {}

        -- Migrate flat list (v1.0) into mana sublist
        if SmartPotionDB.potions and not SmartPotionDB.mana then
            SmartPotionDB.mana = SmartPotionDB.potions
            SmartPotionDB.potions = nil
        end

        if not SmartPotionDB.mana or #SmartPotionDB.mana == 0 then PopulateDefault("mana") end
        if not SmartPotionDB.heal or #SmartPotionDB.heal == 0 then PopulateDefault("heal") end

        -- Force-correct stale IDs from older versions of this addon
        if SmartPotion_KnownIds then
            for _, listKey in ipairs({"mana", "heal"}) do
                for _, p in ipairs(SmartPotionDB[listKey]) do
                    local known = SmartPotion_KnownIds[p.name]
                    if known and p.id ~= known then p.id = known end
                end
            end
        end

        activeTab = SmartPotionDB.activeTab or "mana"

        -- Warm the item cache so icons populate (try both name and id)
        for _, listKey in ipairs({"mana", "heal"}) do
            for _, p in ipairs(SmartPotionDB[listKey]) do
                if p.name then GetItemInfo(p.name) end
                if p.id   then GetItemInfo(p.id)   end
            end
        end

        UpdateButtonPosition()
        UpdateTabVisuals()

        C_Timer.After(1, function()
            ResolveItemIds()
            RefreshUI(); UpdateMacro()
        end)

    elseif event == "BAG_UPDATE" then
        ScheduleBagRefresh()

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if ResolveItemIds() then
            if MainFrame:IsShown() then RefreshUI() end
            if not InCombatLockdown() then UpdateMacro() end
        end

    elseif event ~= "ADDON_LOADED" then
        if not InCombatLockdown() then
            UpdateMacro()
            if MainFrame:IsShown() then RefreshUI() end
        end
    end
end)
