--[[
    Warband Nexus - Characters Tab
    Display all tracked characters with gold, level, and last seen info
]]

local ADDON_NAME, ns = ...
local WarbandNexus = ns.WarbandNexus

-- Import shared UI components
local COLORS = ns.UI_COLORS
local CreateCard = ns.UI_CreateCard
local FormatGold = ns.UI_FormatGold
local CreateSortableTableHeader = ns.UI_CreateSortableTableHeader
local CreateCollapsibleHeader = ns.UI_CreateCollapsibleHeader

--============================================================================
-- DRAW CHARACTER LIST
--============================================================================

function WarbandNexus:DrawCharacterList(parent)
    local yOffset = 8 -- Top padding for breathing room
    local width = parent:GetWidth() - 20
    
    -- Get all characters (cached for performance)
    local characters = self.GetCachedCharacters and self:GetCachedCharacters() or self:GetAllCharacters()
    
    -- Get current player key
    local currentPlayerName = UnitName("player")
    local currentPlayerRealm = GetRealmName()
    local currentPlayerKey = currentPlayerName .. "-" .. currentPlayerRealm
    
    -- Load sorting preferences from profile (persistent across sessions)
    if not parent.sortPrefsLoaded then
        parent.sortKey = self.db.profile.characterSort.key
        parent.sortAscending = self.db.profile.characterSort.ascending
        parent.sortPrefsLoaded = true
    end
    
    -- ===== TITLE CARD =====
    local titleCard = CreateCard(parent, 70)
    titleCard:SetPoint("TOPLEFT", 10, -yOffset)
    titleCard:SetPoint("TOPRIGHT", -10, -yOffset)
    
    local titleIcon = titleCard:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(40, 40)
    titleIcon:SetPoint("LEFT", 15, 0)
    titleIcon:SetTexture("Interface\\Icons\\Achievement_Character_Human_Female")
    
    local titleText = titleCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 12, 5)
    titleText:SetText("|cffa335eeYour Characters|r")
    
    local subtitleText = titleCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitleText:SetPoint("LEFT", titleIcon, "RIGHT", 12, -12)
    subtitleText:SetTextColor(0.6, 0.6, 0.6)
    
    -- Show sorting status
    local sortText = #characters .. " characters tracked"
    if parent.sortKey then
        local sortLabels = {name = "Name", level = "Level", gold = "Gold", lastSeen = "Last Seen"}
        local sortLabel = sortLabels[parent.sortKey] or parent.sortKey
        local sortDir = parent.sortAscending and "ascending" or "descending"
        sortText = sortText .. "  |  |cff9966ffSorted by: " .. sortLabel .. " (" .. sortDir .. ")|r"
    else
        sortText = sortText .. "  |  |cff888888Default sort|r"
    end
    subtitleText:SetText(sortText)
    
    yOffset = yOffset + 75 -- Reduced spacing
    
    -- ===== TOTAL GOLD DISPLAY =====
    local totalGold = 0
    for _, char in ipairs(characters) do
        totalGold = totalGold + (char.gold or 0)
    end
    
    local goldCard = CreateCard(parent, 50)
    goldCard:SetPoint("TOPLEFT", 10, -yOffset)
    goldCard:SetPoint("TOPRIGHT", -10, -yOffset)
    goldCard:SetBackdropColor(0.12, 0.10, 0.05, 1)
    goldCard:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
    
    local goldIcon = goldCard:CreateTexture(nil, "ARTWORK")
    goldIcon:SetSize(28, 28)
    goldIcon:SetPoint("LEFT", 15, 0)
    goldIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    
    local goldLabel = goldCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldLabel:SetPoint("LEFT", goldIcon, "RIGHT", 10, 0)
    goldLabel:SetText("Total Gold: |cffffd700" .. FormatGold(totalGold) .. "|r")
    
    yOffset = yOffset + 55 -- Reduced spacing
    
    -- ===== SORTABLE TABLE HEADER =====
    -- Offset calculation: online/reorder(50) + star(32) + classIcon(32) = 114
    local columns = {
        {key = "name", label = "CHARACTER", align = "LEFT", offset = 114, width = 180},
        {key = "level", label = "LEVEL", align = "LEFT", offset = 266, width = 100},
        {key = "gold", label = "GOLD", align = "RIGHT", offset = -140, width = 120},
        {key = "lastSeen", label = "LAST SEEN", align = "RIGHT", offset = -15, width = 120}
    }
    
    local header, getCurrentSort = CreateSortableTableHeader(
        parent,
        columns,
        width,
        function(sortKey, isAscending)
            -- Save sort state (local)
            parent.sortKey = sortKey
            parent.sortAscending = isAscending
            -- Save to profile (persistent)
            self.db.profile.characterSort.key = sortKey
            self.db.profile.characterSort.ascending = isAscending
            -- Refresh to re-sort
            self:RefreshUI()
        end,
        parent.sortKey,
        parent.sortAscending
    )
    
    header:SetPoint("TOPLEFT", 10, -yOffset)
    yOffset = yOffset + 30  -- Reduced spacing (was 32)
    
    -- ===== SORT CHARACTERS: CURRENT → FAVORITES → REGULAR =====
    local currentChar = nil
    local favorites = {}
    local regular = {}
    
    for _, char in ipairs(characters) do
        local charKey = (char.name or "Unknown") .. "-" .. (char.realm or "Unknown")
        
        -- Separate current character
        if charKey == currentPlayerKey then
            currentChar = char
        elseif self:IsFavoriteCharacter(charKey) then
            table.insert(favorites, char)
        else
            table.insert(regular, char)
        end
    end
    
    -- Load custom order from profile
    if not self.db.profile.characterOrder then
        self.db.profile.characterOrder = {
            favorites = {},
            regular = {}
        }
    end
    
    -- Sort function (with custom order support)
    local function sortCharacters(list, orderKey)
        local customOrder = self.db.profile.characterOrder[orderKey] or {}
        
        -- If custom order exists and has items, use it
        if #customOrder > 0 then
            local ordered = {}
            local charMap = {}
            
            -- Create a map for quick lookup
            for _, char in ipairs(list) do
                local key = (char.name or "Unknown") .. "-" .. (char.realm or "Unknown")
                charMap[key] = char
            end
            
            -- Add characters in custom order
            for _, charKey in ipairs(customOrder) do
                if charMap[charKey] then
                    table.insert(ordered, charMap[charKey])
                    charMap[charKey] = nil  -- Remove to track remaining
                end
            end
            
            -- Add any new characters not in custom order (at the end, sorted)
            local remaining = {}
            for _, char in pairs(charMap) do
                table.insert(remaining, char)
            end
            table.sort(remaining, function(a, b)
                if (a.level or 0) ~= (b.level or 0) then
                    return (a.level or 0) > (b.level or 0)
                else
                    return (a.name or ""):lower() < (b.name or ""):lower()
                end
            end)
            for _, char in ipairs(remaining) do
                table.insert(ordered, char)
            end
            
            return ordered
        else
            -- Default sort: level desc → name asc (ignore table header sorting for now)
            table.sort(list, function(a, b)
                if (a.level or 0) ~= (b.level or 0) then
                    return (a.level or 0) > (b.level or 0)
                else
                    return (a.name or ""):lower() < (b.name or ""):lower()
                end
            end)
            return list
        end
    end
    
    -- Sort both groups with custom order
    favorites = sortCharacters(favorites, "favorites")
    regular = sortCharacters(regular, "regular")
    
    -- ===== EMPTY STATE =====
    if not currentChar and #favorites == 0 and #regular == 0 then
        local emptyIcon = parent:CreateTexture(nil, "ARTWORK")
        emptyIcon:SetSize(48, 48)
        emptyIcon:SetPoint("TOP", 0, -yOffset - 30)
        emptyIcon:SetTexture("Interface\\Icons\\Ability_Spy")
        emptyIcon:SetDesaturated(true)
        emptyIcon:SetAlpha(0.4)
        
        local emptyText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        emptyText:SetPoint("TOP", 0, -yOffset - 90)
        emptyText:SetText("|cff666666No characters tracked yet|r")
        
        local emptyDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyDesc:SetPoint("TOP", 0, -yOffset - 115)
        emptyDesc:SetTextColor(0.5, 0.5, 0.5)
        emptyDesc:SetText("Characters are automatically registered on login")
        
        return yOffset + 200
    end
    
    -- ===== CURRENT CHARACTER (Single row, no collapse) =====
    if currentChar then
        local currentKey = (currentChar.name or "Unknown") .. "-" .. (currentChar.realm or "Unknown")
        local isCurrentFavorite = self:IsFavoriteCharacter(currentKey)
        yOffset = self:DrawCharacterRow(parent, currentChar, 0, width, yOffset, isCurrentFavorite, false, nil, nil, true, nil, nil)
    end
    
    -- Initialize collapse state (persistent)
    if not self.db.profile.ui then
        self.db.profile.ui = {}
    end
    if self.db.profile.ui.favoritesExpanded == nil then
        self.db.profile.ui.favoritesExpanded = true
    end
    if self.db.profile.ui.charactersExpanded == nil then
        self.db.profile.ui.charactersExpanded = true
    end
    
    -- ===== FAVORITES SECTION =====
    if #favorites > 0 then
        local favHeader, _, favIcon = CreateCollapsibleHeader(
            parent,
            string.format("Favorites |cff888888(%d)|r", #favorites),
            "favorites",
            self.db.profile.ui.favoritesExpanded,
            function(isExpanded)
                self.db.profile.ui.favoritesExpanded = isExpanded
                self:RefreshUI()
            end,
            "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend"  -- Heart/people icon
        )
        favHeader:SetPoint("TOPLEFT", 10, -yOffset)
        favHeader:SetPoint("TOPRIGHT", -10, -yOffset)
        yOffset = yOffset + 32
        
        if self.db.profile.ui.favoritesExpanded then
            for i, char in ipairs(favorites) do
                yOffset = self:DrawCharacterRow(parent, char, i + (currentChar and 1 or 0), width, yOffset, true, true, favorites, "favorites", false, i, #favorites)
            end
        end
    end
    
    -- ===== REGULAR CHARACTERS SECTION =====
    if #regular > 0 then
        local charHeader = CreateCollapsibleHeader(
            parent,
            string.format("Characters |cff888888(%d)|r", #regular),
            "characters",
            self.db.profile.ui.charactersExpanded,
            function(isExpanded)
                self.db.profile.ui.charactersExpanded = isExpanded
                self:RefreshUI()
            end,
            "Interface\\Icons\\Achievement_Character_Human_Female"
        )
        charHeader:SetPoint("TOPLEFT", 10, -yOffset)
        charHeader:SetPoint("TOPRIGHT", -10, -yOffset)
        yOffset = yOffset + 32
        
        if self.db.profile.ui.charactersExpanded then
            for i, char in ipairs(regular) do
                yOffset = self:DrawCharacterRow(parent, char, i + (currentChar and 1 or 0) + #favorites, width, yOffset, false, true, regular, "regular", false, i, #regular)
            end
        end
    end
    
    return yOffset
end

--============================================================================
-- DRAW SINGLE CHARACTER ROW
--============================================================================

function WarbandNexus:DrawCharacterRow(parent, char, index, width, yOffset, isFavorite, showReorder, charList, listKey, isCurrent, positionInList, totalInList)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 36)
    row:SetPoint("TOPLEFT", 10, -yOffset)
    row:EnableMouse(true)
    
    -- Row background (alternating colors, green tint for current)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local bgColor
    if isCurrent then
        bgColor = {0.08, 0.15, 0.08, 1}  -- Green tint for current character
    else
        bgColor = index % 2 == 0 and {0.08, 0.08, 0.10, 1} or {0.05, 0.05, 0.06, 1}
    end
    bg:SetColorTexture(unpack(bgColor))
    row.bgColor = bgColor
    
    -- Class color
    local classColor = RAID_CLASS_COLORS[char.classFile] or {r = 1, g = 1, b = 1}
    
    local leftOffset = 0
    
    -- Online indicator or reorder buttons (both occupy same space for alignment)
    if isCurrent then
        -- Online indicator (green circle) - same width as reorder area
        local onlineIndicator = row:CreateTexture(nil, "ARTWORK")
        onlineIndicator:SetSize(16, 16)
        onlineIndicator:SetPoint("LEFT", leftOffset + 17, 0)  -- Centered in 50px space
        onlineIndicator:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
        leftOffset = leftOffset + 50  -- Same as reorder buttons
    elseif showReorder and charList then
        local reorderButtons = CreateFrame("Frame", nil, row)
        reorderButtons:SetSize(48, 24)  -- Wider for side-by-side buttons
        reorderButtons:SetPoint("LEFT", leftOffset, 0)
        reorderButtons:Hide()
        reorderButtons:SetFrameLevel(row:GetFrameLevel() + 10)
        
        -- Up arrow (LEFT side) - Move character UP in list
        local upBtn = CreateFrame("Button", nil, reorderButtons)
        upBtn:SetSize(22, 22)
        upBtn:SetPoint("LEFT", 0, 0)
        
        -- Disable if first in list
        if positionInList and positionInList == 1 then
            upBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
            upBtn:SetAlpha(0.5)
            upBtn:Disable()
            upBtn:EnableMouse(false)  -- Completely ignore mouse events
        else
            upBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            upBtn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
            upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            
            upBtn:SetScript("OnClick", function()
                WarbandNexus:ReorderCharacter(char, charList, listKey, -1)
            end)
            
            upBtn:SetScript("OnEnter", function()
                reorderButtons:Show()
                GameTooltip:SetOwner(upBtn, "ANCHOR_TOP")
                GameTooltip:SetText("Move Up")
                GameTooltip:Show()
            end)
            
            upBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        
        -- Down arrow (RIGHT side) - Move character DOWN in list
        local downBtn = CreateFrame("Button", nil, reorderButtons)
        downBtn:SetSize(22, 22)
        downBtn:SetPoint("RIGHT", 0, 0)
        
        -- Disable if last in list
        if positionInList and totalInList and positionInList == totalInList then
            downBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
            downBtn:SetAlpha(0.5)
            downBtn:Disable()
            downBtn:EnableMouse(false)  -- Completely ignore mouse events
        else
            downBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            downBtn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
            downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            
            downBtn:SetScript("OnClick", function()
                WarbandNexus:ReorderCharacter(char, charList, listKey, 1)
            end)
            
            downBtn:SetScript("OnEnter", function()
                reorderButtons:Show()
                GameTooltip:SetOwner(downBtn, "ANCHOR_TOP")
                GameTooltip:SetText("Move Down")
                GameTooltip:Show()
            end)
            
            downBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        
        row.reorderButtons = reorderButtons
        leftOffset = leftOffset + 50  -- More space for wider buttons
    else
        -- No reorder, no online indicator - add spacing to align with others
        leftOffset = leftOffset + 50  -- Match new reorder width
    end
    
    -- Favorite button (star icon)
    local charKey = (char.name or "Unknown") .. "-" .. (char.realm or "Unknown")
    
    local favButton = CreateFrame("Button", nil, row)
    favButton:SetSize(28, 28)  -- Bigger star
    favButton:SetPoint("LEFT", leftOffset, 0)
    leftOffset = leftOffset + 32
    
    local favIcon = favButton:CreateTexture(nil, "ARTWORK")
    favIcon:SetAllPoints()
    if isFavorite then
        -- Filled gold star (same as in header)
        favIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
        favIcon:SetVertexColor(1, 0.84, 0)  -- Gold color
    else
        -- Empty gray star
        favIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
        favIcon:SetDesaturated(true)
        favIcon:SetVertexColor(0.5, 0.5, 0.5)
    end
    favButton.icon = favIcon
    favButton.charKey = charKey
    
    favButton:SetScript("OnClick", function(self)
        local newStatus = WarbandNexus:ToggleFavoriteCharacter(self.charKey)
        -- Update icon (always use same star texture, just change color)
        if newStatus then
            self.icon:SetDesaturated(false)
            self.icon:SetVertexColor(1, 0.84, 0)  -- Gold
        else
            self.icon:SetDesaturated(true)
            self.icon:SetVertexColor(0.5, 0.5, 0.5)  -- Gray
        end
        -- Refresh to re-sort
        WarbandNexus:RefreshUI()
    end)
    
    favButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if isFavorite then
            GameTooltip:SetText("|cffffd700Favorite Character|r\nClick to remove from favorites")
        else
            GameTooltip:SetText("Click to add to favorites\n|cff888888Favorites are always shown at the top|r")
        end
        GameTooltip:Show()
    end)
    
    favButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Class icon
    local classIcon = row:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(24, 24)
    classIcon:SetPoint("LEFT", leftOffset, 0)
    leftOffset = leftOffset + 32
        local coords = CLASS_ICON_TCOORDS[char.classFile]
        if coords then
            classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            classIcon:SetTexCoord(unpack(coords))
        else
            classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        
    -- Character name (in class color)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", leftOffset, 0)
    nameText:SetWidth(140)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(string.format("|cff%02x%02x%02x%s|r", 
        classColor.r * 255, classColor.g * 255, classColor.b * 255, 
        char.name or "Unknown"))
    
    -- Level (in class color, aligned with header at 266)
    local levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelText:SetPoint("LEFT", 266, 0)
    levelText:SetText(string.format("|cff%02x%02x%02x%d|r", 
        classColor.r * 255, classColor.g * 255, classColor.b * 255, 
        char.level or 1))
        
        -- Gold (aligned with header)
        local goldText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        goldText:SetPoint("RIGHT", -140, 0)
        goldText:SetJustifyH("RIGHT")
        goldText:SetText("|cffffd700" .. FormatGold(char.gold or 0) .. "|r")
        
        -- Last seen (aligned with header)
        local lastSeenText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lastSeenText:SetPoint("RIGHT", -15, 0)
        lastSeenText:SetJustifyH("RIGHT")
        lastSeenText:SetTextColor(0.5, 0.5, 0.5)
        if char.lastSeen then
            local timeDiff = time() - char.lastSeen
            if timeDiff < 60 then
                lastSeenText:SetText("Just now")
            elseif timeDiff < 3600 then
                lastSeenText:SetText(math.floor(timeDiff / 60) .. "m ago")
            elseif timeDiff < 86400 then
                lastSeenText:SetText(math.floor(timeDiff / 3600) .. "h ago")
            else
                lastSeenText:SetText(math.floor(timeDiff / 86400) .. "d ago")
            end
        else
            lastSeenText:SetText("Unknown")
        end
        
    -- Hover effect + Tooltip
    row:SetScript("OnEnter", function(self)
        bg:SetColorTexture(0.18, 0.18, 0.25, 1)
        
        -- Show reorder buttons on hover (no animation)
        if showReorder and self.reorderButtons then
            self.reorderButtons:SetAlpha(1)
            self.reorderButtons:Show()
        end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(char.name or "Unknown", classColor.r, classColor.g, classColor.b)
        GameTooltip:AddLine(char.realm or "", 0.5, 0.5, 0.5)
        
        if isCurrent then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff00ff00● Currently Online|r", 0.3, 1, 0.3)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Class:", char.class or "Unknown", 1, 1, 1, classColor.r, classColor.g, classColor.b)
        GameTooltip:AddDoubleLine("Level:", tostring(char.level or 1), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Gold:", FormatGold(char.gold or 0), 1, 1, 1, 1, 0.82, 0)
        if char.faction then
            GameTooltip:AddDoubleLine("Faction:", char.faction, 1, 1, 1, 0.7, 0.7, 0.7)
        end
        if char.race then
            GameTooltip:AddDoubleLine("Race:", char.race, 1, 1, 1, 0.7, 0.7, 0.7)
        end
        
        
        GameTooltip:Show()
    end)
    
    row:SetScript("OnLeave", function(self)
        bg:SetColorTexture(unpack(self.bgColor))
        GameTooltip:Hide()
        
        -- Hide reorder buttons (no animation, direct hide)
        if showReorder and self.reorderButtons then
            self.reorderButtons:Hide()
        end
    end)
    
    return yOffset + 38
end

--============================================================================
-- REORDER CHARACTER IN LIST
--============================================================================

function WarbandNexus:ReorderCharacter(char, charList, listKey, direction)
    if not char or not listKey then return end
    
    local charKey = (char.name or "Unknown") .. "-" .. (char.realm or "Unknown")
    
    -- Get or initialize custom order
    if not self.db.profile.characterOrder then
        self.db.profile.characterOrder = {
            favorites = {},
            regular = {}
        }
    end
    
    if not self.db.profile.characterOrder[listKey] then
        self.db.profile.characterOrder[listKey] = {}
    end
    
    local customOrder = self.db.profile.characterOrder[listKey]
    
    -- If no custom order exists, create one from ALL characters in this category
    if #customOrder == 0 then
        -- Get all characters and rebuild the list for this category
        local allChars = self:GetAllCharacters()
        local currentPlayerName = UnitName("player")
        local currentPlayerRealm = GetRealmName()
        local currentPlayerKey = currentPlayerName .. "-" .. currentPlayerRealm
        
        for _, c in ipairs(allChars) do
            local key = (c.name or "Unknown") .. "-" .. (c.realm or "Unknown")
            -- Skip current player
            if key ~= currentPlayerKey then
                local isFav = self:IsFavoriteCharacter(key)
                -- Add to appropriate list
                if (listKey == "favorites" and isFav) or (listKey == "regular" and not isFav) then
                    table.insert(customOrder, key)
                end
            end
        end
    end
    
    -- Find current index in custom order
    local currentIndex = nil
    for i, key in ipairs(customOrder) do
        if key == charKey then
            currentIndex = i
            break
        end
    end
    
    if not currentIndex then 
        -- Character not in custom order, add it
        table.insert(customOrder, charKey)
        currentIndex = #customOrder
    end
    
    -- Calculate new index
    local newIndex = currentIndex + direction
    if newIndex < 1 or newIndex > #customOrder then return end
    
    -- Swap in custom order
    customOrder[currentIndex], customOrder[newIndex] = customOrder[newIndex], customOrder[currentIndex]
    
    -- Save and refresh
    self.db.profile.characterOrder[listKey] = customOrder
    self:RefreshUI()
end
