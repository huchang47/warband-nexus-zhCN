--[[
    Warband Nexus - Currency Tab
    Display all currencies across characters with search and organization
]]

local ADDON_NAME, ns = ...
local WarbandNexus = ns.WarbandNexus

-- Import shared UI components
local CreateCard = ns.UI_CreateCard
local CreateCollapsibleHeader = ns.UI_CreateCollapsibleHeader
local FormatGold = ns.UI_FormatGold
local DrawEmptyState = ns.UI_DrawEmptyState
local COLORS = ns.UI_COLORS

-- Performance: Local function references
local format = string.format
local floor = math.floor

-- Import shared UI constants
local UI_LAYOUT = ns.UI_LAYOUT
local ROW_HEIGHT = UI_LAYOUT.ROW_HEIGHT
local ROW_SPACING = UI_LAYOUT.ROW_SPACING
local HEADER_SPACING = UI_LAYOUT.HEADER_SPACING
local SECTION_SPACING = UI_LAYOUT.SECTION_SPACING

--============================================================================
-- CURRENCY FORMATTING & HELPERS
--============================================================================

---Format currency quantity with cap indicator
---@param quantity number Current amount
---@param maxQuantity number Maximum amount (0 = no cap)
---@return string Formatted text with color
local function FormatCurrencyAmount(quantity, maxQuantity)
    if maxQuantity > 0 then
        local percentage = (quantity / maxQuantity) * 100
        local color
        
        if percentage >= 100 then
            color = "|cffff4444" -- Red (capped)
        elseif percentage >= 80 then
            color = "|cffffaa00" -- Orange (near cap)
        elseif percentage >= 50 then
            color = "|cffffff00" -- Yellow (half)
        else
            color = "|cffffffff" -- White (safe)
        end
        
        return format("%s%d|r / %d", color, quantity, maxQuantity)
    else
        return format("|cffffffff%d|r", quantity)
    end
end

---Get currency category display name
---@param category string Category name
---@return string Display name
local function GetCategoryDisplayName(category)
    local names = {
        ["Crest"] = "Crests",
        ["Upgrade"] = "Upgrade Materials",
        ["Profession"] = "Profession",
        ["Event"] = "Event Currencies",
        ["Shop"] = "Shop Currencies",
        ["Special"] = "Special Currencies",
        ["Supplies"] = "Supplies",
        ["Key"] = "Keys",
        ["Currency"] = "General Currencies",
        ["PvP"] = "PvP",
        ["Other"] = "Other",
    }
    return names[category] or category
end

---Check if currency matches search text
---@param currency table Currency data
---@param searchText string Search text (lowercase)
---@return boolean matches
local function CurrencyMatchesSearch(currency, searchText)
    if not searchText or searchText == "" then
        return true
    end
    
    local name = (currency.name or ""):lower()
    local category = (currency.category or ""):lower()
    
    return name:find(searchText, 1, true) or category:find(searchText, 1, true)
end

--============================================================================
-- DRAW CURRENCY TAB
--============================================================================

function WarbandNexus:DrawCurrencyTab(parent)
    local yOffset = 8
    local width = parent:GetWidth() - 20
    local indent = 20
    
    -- Get search text from namespace
    local currencySearchText = ns.UI_GetCurrencySearchText()
    local hasSearchText = currencySearchText and currencySearchText ~= ""
    
    -- ===== COLLECT CURRENCY DATA IF MISSING =====
    -- Check if current character has currency data
    local currentPlayerName = UnitName("player")
    local currentPlayerRealm = GetRealmName()
    local currentPlayerKey = currentPlayerName .. "-" .. currentPlayerRealm
    
    if self.db.global.characters and self.db.global.characters[currentPlayerKey] then
        local char = self.db.global.characters[currentPlayerKey]
        if not char.currencies or not next(char.currencies) then
            -- No currency data, collect it now
            if self.UpdateCurrencyData then
                self:UpdateCurrencyData()
                self:Debug("Currency data collected on tab open")
            end
        end
    end
    
    -- ===== HEADER CARD =====
    local titleCard = CreateCard(parent, 70)
    titleCard:SetPoint("TOPLEFT", 10, -yOffset)
    titleCard:SetPoint("TOPRIGHT", -10, -yOffset)
    
    local titleIcon = titleCard:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(40, 40)
    titleIcon:SetPoint("LEFT", 15, 0)
    titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    
    local titleText = titleCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 12, 5)
    titleText:SetText("|cffa335eeCurrency Tracker|r")
    
    local subtitleText = titleCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitleText:SetPoint("LEFT", titleIcon, "RIGHT", 12, -12)
    subtitleText:SetTextColor(0.6, 0.6, 0.6)
    subtitleText:SetText("Track all currencies across your characters")
    
    -- Filter Toggle Button
    local filterMode = self.db.profile.currencyFilterMode or "filtered"
    local toggleBtn = CreateFrame("Button", nil, titleCard, "BackdropTemplate")
    toggleBtn:SetSize(120, 30)
    toggleBtn:SetPoint("RIGHT", -15, 0)
    toggleBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    if filterMode == "filtered" then
        toggleBtn:SetBackdropColor(0.2, 0.5, 0.2, 0.8)
        toggleBtn:SetBackdropBorderColor(0.3, 0.7, 0.3, 1)
    else
        toggleBtn:SetBackdropColor(0.5, 0.3, 0.2, 0.8)
        toggleBtn:SetBackdropBorderColor(0.7, 0.4, 0.3, 1)
    end
    
    local toggleText = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleText:SetPoint("CENTER")
    toggleText:SetText(filterMode == "filtered" and "|cff88ff88Filtered|r" or "|cffffaa88Non-Filtered|r")
    
    toggleBtn:SetScript("OnClick", function()
        self.db.profile.currencyFilterMode = (self.db.profile.currencyFilterMode == "filtered") and "nonfiltered" or "filtered"
        self:RefreshUI()
    end)
    
    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("View Mode", 1, 1, 1)
        GameTooltip:AddLine("|cff88ff88Filtered|r: Group by categories", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("|cffffaa88Non-Filtered|r: Simple list view", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    yOffset = yOffset + 78
    
    -- Get all characters
    local characters = self.GetCachedCharacters and self:GetCachedCharacters() or self:GetAllCharacters()
    
    if not characters or #characters == 0 then
        return DrawEmptyState(self, parent, yOffset, false, "No characters found")
    end
    
    -- Get expanded state
    local expanded = self.db.profile.currencyExpanded or {}
    
    -- Toggle function
    local function ToggleExpand(key, isExpanded)
        if type(isExpanded) == "boolean" then
            expanded[key] = isExpanded
        else
            expanded[key] = not expanded[key]
        end
        self:RefreshUI()
    end
    
    -- Default expanded function (for first time or search)
    local function GetExpandedState(key, defaultValue)
        -- If searching, force expand
        if hasSearchText then
            return true
        end
        
        if expanded[key] == nil then
            expanded[key] = defaultValue
            return defaultValue
        end
        return expanded[key]
    end
    
    -- ===== ORGANIZE CURRENCIES BY CHARACTER =====
    local hasAnyData = false
    local charactersWithCurrencies = {}
    
    for _, char in ipairs(characters) do
        if char.currencies and next(char.currencies) then
            local charKey = (char.name or "Unknown") .. "-" .. (char.realm or "Unknown")
            
            -- Filter by search AND quantity > 0 AND not hidden
            local matchingCurrencies = {}
            for currencyID, currency in pairs(char.currencies) do
                -- ONLY show currencies with quantity > 0, not hidden, and matching search
                if currency.quantity and currency.quantity > 0 
                   and not currency.isHidden 
                   and CurrencyMatchesSearch(currency, currencySearchText) then
                    table.insert(matchingCurrencies, {
                        id = currencyID,
                        data = currency,
                    })
                end
            end
            
            if #matchingCurrencies > 0 then
                hasAnyData = true
                table.insert(charactersWithCurrencies, {
                    char = char,
                    key = charKey,
                    currencies = matchingCurrencies,
                })
            end
        end
    end
    
    -- If no data, show empty state
    if not hasAnyData then
        local isSearch = currencySearchText and currencySearchText ~= ""
        return DrawEmptyState(self, parent, yOffset, isSearch, currencySearchText)
    end
    
    -- ===== DRAW CHARACTER SECTIONS =====
    for _, charData in ipairs(charactersWithCurrencies) do
        local char = charData.char
        local charKey = charData.key
        local currencies = charData.currencies
        
        -- Sort currencies by name
        table.sort(currencies, function(a, b)
            return (a.data.name or "") < (b.data.name or "")
        end)
        
        -- Character header (default: expanded)
        local charExpanded = GetExpandedState(charKey, true)
        
        local classColor = RAID_CLASS_COLORS[char.classFile] or {r = 1, g = 1, b = 1}
        local charName = format("|c%s%s|r", 
            format("%02x%02x%02x%02x", 255, classColor.r * 255, classColor.g * 255, classColor.b * 255),
            char.name or "Unknown")
        
        local headerText = format("%s - |cffaaaaaa%d currencies|r", charName, #currencies)
        
        local charHeader, charBtn = CreateCollapsibleHeader(
            parent,
            headerText,
            charKey,
            charExpanded,
            function(isExpanded) ToggleExpand(charKey, isExpanded) end
        )
        charHeader:SetPoint("TOPLEFT", 10, -yOffset)
        charHeader:SetPoint("RIGHT", -10, 0)
        
        yOffset = yOffset + HEADER_SPACING
        
        -- If expanded, show currencies
        if charExpanded then
            local filterMode = self.db.profile.currencyFilterMode or "filtered"
            
            if filterMode == "nonfiltered" then
                -- ===== NON-FILTERED MODE: Simple list by expansion =====
                -- Group by expansion only
                local byExpansion = {}
                for _, curr in ipairs(currencies) do
                    local expansion = curr.data.expansion or "Other"
                    if not byExpansion[expansion] then
                        byExpansion[expansion] = {}
                    end
                    table.insert(byExpansion[expansion], curr)
                end
                
                local expansionOrder = {
                    "The War Within", "Dragonflight", "Shadowlands", "Battle for Azeroth",
                    "Legion", "Warlords of Draenor", "Mists of Pandaria", "Cataclysm",
                    "Account-Wide", "Current Season", "Legacy", "Other"
                }
                
                -- Expansion icons
                local expansionIcons = {
                    ["The War Within"] = "Interface\\Icons\\INV_Misc_Gem_Diamond_01",
                    ["Dragonflight"] = "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze",
                    ["Shadowlands"] = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
                    ["Battle for Azeroth"] = "Interface\\Icons\\INV_Sword_39",
                    ["Legion"] = "Interface\\Icons\\INV_Legion_Artifact_RelicShadow",
                    ["Warlords of Draenor"] = "Interface\\Icons\\Achievement_Garrison_Blueprints",
                    ["Mists of Pandaria"] = "Interface\\Icons\\Achievement_Character_Pandaren_Female",
                    ["Cataclysm"] = "Interface\\Icons\\Spell_Fire_Flameshock",
                    ["Account-Wide"] = "Interface\\Icons\\INV_Misc_Coin_02",
                    ["Current Season"] = "Interface\\Icons\\INV_Misc_Trophy_Bronze",
                    ["Legacy"] = "Interface\\Icons\\INV_Misc_Book_11",
                    ["Other"] = "Interface\\Icons\\INV_Misc_QuestionMark",
                }
                
                for _, expansion in ipairs(expansionOrder) do
                    if byExpansion[expansion] then
                        -- Expansion key for collapse/expand
                        local expansionKey = charKey .. "-nf-exp-" .. expansion
                        local expansionExpanded = GetExpandedState(expansionKey, true)
                        
                        -- Collapsible expansion header
                        local expHeader, expBtn = CreateCollapsibleHeader(
                            parent,
                            "|cffffffff" .. expansion .. " (" .. #byExpansion[expansion] .. ")|r",
                            expansionKey,
                            expansionExpanded,
                            function(isExpanded) ToggleExpand(expansionKey, isExpanded) end,
                            expansionIcons[expansion] or "Interface\\Icons\\INV_Misc_QuestionMark"
                        )
                        expHeader:SetPoint("TOPLEFT", indent, -yOffset)
                        expHeader:SetPoint("RIGHT", -10, 0)
                        expHeader:SetBackdropColor(0.12, 0.10, 0.15, 0.9)
                        expHeader:SetBackdropBorderColor(0.4, 0.3, 0.5, 0.8)
                        yOffset = yOffset + HEADER_SPACING
                        
                        -- Only show currencies if expanded
                        if expansionExpanded then
                            for i, curr in ipairs(byExpansion[expansion]) do
                                local currency = curr.data
                            
                                local row = CreateFrame("Button", nil, parent)
                                row:SetSize(width - indent, ROW_HEIGHT)
                                row:SetPoint("TOPLEFT", indent, -yOffset)
                                row:EnableMouse(true)
                                
                                -- Background (alternating)
                                local bg = row:CreateTexture(nil, "BACKGROUND")
                                bg:SetAllPoints()
                                bg:SetColorTexture(i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.09 or 0.06, 1)
                                
                                -- Currency icon
                                local icon = row:CreateTexture(nil, "ARTWORK")
                                icon:SetSize(22, 22)
                                icon:SetPoint("LEFT", 15, 0)
                                if currency.iconFileID then
                                    icon:SetTexture(currency.iconFileID)
                                else
                                    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                                end
                                
                                -- Currency name
                                local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                nameText:SetPoint("LEFT", 43, 0)
                                nameText:SetText(currency.name or "Unknown Currency")
                                nameText:SetTextColor(1, 1, 1)
                                nameText:SetJustifyH("LEFT")
                                
                                -- Currency amount
                                local amountText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                amountText:SetPoint("RIGHT", -10, 0)
                                amountText:SetText(FormatCurrencyAmount(currency.quantity or 0, currency.maxQuantity or 0))
                                amountText:SetJustifyH("RIGHT")
                                
                                -- Hover effect
                                row:SetScript("OnEnter", function(self)
                                    bg:SetColorTexture(0.15, 0.15, 0.18, 1)
                                    
                                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                    if curr.id then
                                        GameTooltip:SetCurrencyByID(curr.id)
                                    else
                                        GameTooltip:SetText(currency.name or "Currency", 1, 1, 1)
                                        GameTooltip:Show()
                                    end
                                end)
                                row:SetScript("OnLeave", function()
                                    bg:SetColorTexture(i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.09 or 0.06, 1)
                                    GameTooltip:Hide()
                                end)
                            
                            yOffset = yOffset + ROW_SPACING
                        end -- end for currencies
                        end -- end if expansionExpanded
                    end -- end if byExpansion[expansion]
                end -- end for expansionOrder
            else
                -- ===== FILTERED MODE: Original nested structure =====
            -- Group currencies by EXPANSION first
            local byExpansion = {}
            for _, curr in ipairs(currencies) do
                local expansion = curr.data.expansion or "Other"
                if not byExpansion[expansion] then
                    byExpansion[expansion] = {}
                end
                table.insert(byExpansion[expansion], curr)
            end
            
            -- Expansion order (newest first)
            local expansionOrder = {
                "The War Within", 
                "Dragonflight", 
                "Shadowlands", 
                "Battle for Azeroth",
                "Legion",
                "Warlords of Draenor",
                "Mists of Pandaria",
                "Cataclysm",
                "Account-Wide", 
                "Current Season", 
                "Legacy", 
                "Other"
            }
            
            for _, expansion in ipairs(expansionOrder) do
                if byExpansion[expansion] then
                    -- Expansion key for collapse/expand
                    local expansionKey = charKey .. "-exp-" .. expansion
                    local expansionExpanded = GetExpandedState(expansionKey, true)
                    
                    -- Expansion icons (classic, guaranteed-safe item icons)
                    local expansionIcons = {
                        ["The War Within"] = "Interface\\Icons\\INV_Misc_Gem_Diamond_01",
                        ["Dragonflight"] = "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze",
                        ["Shadowlands"] = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
                        ["Battle for Azeroth"] = "Interface\\Icons\\INV_Sword_39",
                        ["Legion"] = "Interface\\Icons\\INV_Legion_Artifact_RelicShadow",
                        ["Warlords of Draenor"] = "Interface\\Icons\\Achievement_Garrison_Blueprints",
                        ["Mists of Pandaria"] = "Interface\\Icons\\Achievement_Character_Pandaren_Female",
                        ["Cataclysm"] = "Interface\\Icons\\Spell_Fire_Flameshock",
                        ["Account-Wide"] = "Interface\\Icons\\INV_Misc_Coin_02",
                        ["Current Season"] = "Interface\\Icons\\INV_Misc_Trophy_Bronze",
                        ["Legacy"] = "Interface\\Icons\\INV_Misc_Book_11",
                        ["Other"] = "Interface\\Icons\\INV_Misc_QuestionMark",
                    }
                    
                    -- EXPANSION HEADER (collapsible)
                    local expHeader, expBtn = CreateCollapsibleHeader(
                        parent,
                        "|cffffffff" .. expansion .. "|r",
                        expansionKey,
                        expansionExpanded,
                        function(isExpanded) ToggleExpand(expansionKey, isExpanded) end,
                        expansionIcons[expansion] or "Interface\\Icons\\INV_Misc_QuestionMark"
                    )
                    expHeader:SetPoint("TOPLEFT", indent, -yOffset)
                    expHeader:SetPoint("RIGHT", -10, 0)
                    expHeader:SetBackdropColor(0.12, 0.10, 0.15, 0.9)
                    expHeader:SetBackdropBorderColor(0.4, 0.3, 0.5, 0.8)
                    
                    yOffset = yOffset + HEADER_SPACING
                    
                    -- Only show categories if expansion is expanded
                    if expansionExpanded then
                        -- Group by category within expansion
                        local categorized = {}
                        for _, curr in ipairs(byExpansion[expansion]) do
                            local category = curr.data.category or "Other"
                            if not categorized[category] then
                                categorized[category] = {}
                            end
                            table.insert(categorized[category], curr)
                        end
                        
                        -- Sort categories
                        local categoryOrder = {"Crest", "Upgrade", "Profession", "Key", "Currency", "PvP", "Event", "Shop", "Special", "Supplies", "Other"}
                        
                        for _, category in ipairs(categoryOrder) do
                            if categorized[category] then
                                -- Category key for collapse/expand
                                local categoryKey = expansionKey .. "-cat-" .. category
                                local categoryExpanded = GetExpandedState(categoryKey, true)
                                
                                -- Category header (collapsible)
                                local catHeader, catBtn = CreateCollapsibleHeader(
                                    parent,
                                    GetCategoryDisplayName(category) .. " |cff888888(" .. #categorized[category] .. ")|r",
                                    categoryKey,
                                    categoryExpanded,
                                    function(isExpanded) ToggleExpand(categoryKey, isExpanded) end
                                )
                                catHeader:SetPoint("TOPLEFT", indent + 10, -yOffset)
                                catHeader:SetPoint("RIGHT", -10, 0)
                                catHeader:SetBackdropColor(0.10, 0.10, 0.12, 0.7)
                                catHeader:SetBackdropBorderColor(0.4, 0.3, 0.5, 0.8)
                                
                                yOffset = yOffset + HEADER_SPACING
                                
                                -- Only show currency rows if category is expanded
                                if categoryExpanded then
                                    -- Currency rows
                                    for i, curr in ipairs(categorized[category]) do
                                        local currency = curr.data
                                
                                        local row = CreateFrame("Button", nil, parent)
                                        row:SetSize(width - (indent + 10), ROW_HEIGHT)
                                        row:SetPoint("TOPLEFT", indent + 10, -yOffset)
                                        row:EnableMouse(true)
                                        
                                        -- Background (alternating)
                                        local bg = row:CreateTexture(nil, "BACKGROUND")
                                        bg:SetAllPoints()
                                        bg:SetColorTexture(i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.09 or 0.06, 1)
                                        
                                        -- Currency icon
                                        local icon = row:CreateTexture(nil, "ARTWORK")
                                        icon:SetSize(22, 22)
                                        icon:SetPoint("LEFT", 15, 0)
                                        
                                        if currency.iconFileID then
                                            icon:SetTexture(currency.iconFileID)
                                        else
                                            icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                                        end
                                        
                                        -- Currency name
                                        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                        nameText:SetPoint("LEFT", 43, 0)
                                        nameText:SetText(currency.name or "Unknown Currency")
                                        nameText:SetTextColor(1, 1, 1)
                                        nameText:SetJustifyH("LEFT")
                                        
                                        -- Currency amount (right side)
                                        local amountText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                        amountText:SetPoint("RIGHT", -10, 0)
                                        amountText:SetText(FormatCurrencyAmount(currency.quantity or 0, currency.maxQuantity or 0))
                                        amountText:SetJustifyH("RIGHT")
                                        
                                        -- Hover effect
                                        row:SetScript("OnEnter", function(self)
                                            bg:SetColorTexture(0.15, 0.15, 0.18, 1)
                                            
                                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                            if curr.id then
                                                GameTooltip:SetCurrencyByID(curr.id)
                                            else
                                                GameTooltip:SetText(currency.name or "Currency", 1, 1, 1)
                                                
                                                if currency.maxQuantity and currency.maxQuantity > 0 then
                                                    local percentage = floor((currency.quantity / currency.maxQuantity) * 100)
                                                    GameTooltip:AddLine(format("Capacity: %d%%", percentage), 1, 1, 0.5)
                                                    
                                                    if currency.isCapped then
                                                        GameTooltip:AddLine("|cffff4444CAPPED!|r Spend some to avoid waste", 1, 0.2, 0.2)
                                                    end
                                                end
                                                
                                                if currency.quantityEarnedThisWeek and currency.quantityEarnedThisWeek > 0 then
                                                    GameTooltip:AddLine(format("Earned this week: %d", currency.quantityEarnedThisWeek), 0.5, 1, 0.5)
                                                end
                                                
                                                if currency.isAccountWide then
                                                    GameTooltip:AddLine("|cff00ff00Account-Wide Currency|r", 0, 1, 0)
                                                end
                                                
                                                if currency.isAccountTransferable then
                                                    GameTooltip:AddLine("|cff00aaffTransferable|r", 0, 0.7, 1)
                                                end
                                                
                                                GameTooltip:Show()
                                            end
                                        end)
                                        row:SetScript("OnLeave", function()
                                            bg:SetColorTexture(i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.07 or 0.05, i % 2 == 0 and 0.09 or 0.06, 1)
                                            GameTooltip:Hide()
                                        end)
                                        
                                        yOffset = yOffset + ROW_SPACING
                                    end
                                end -- end categoryExpanded
                            end -- end if categorized[category]
                        end -- end for categoryOrder
                    end -- end if expansionExpanded
                end -- end if byExpansion[expansion]
            end -- end for expansionOrder
            end -- end if filterMode == "nonfiltered"
        end -- end if charExpanded
        
        -- Add minimal spacing between characters
        yOffset = yOffset + 5
    end
    
    -- Save expanded state
    self.db.profile.currencyExpanded = expanded
    
    return yOffset
end



