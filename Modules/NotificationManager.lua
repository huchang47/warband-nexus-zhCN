--[[
    Warband Nexus - Notification Manager
    Handles in-game notifications and reminders
]]

local ADDON_NAME, ns = ...
local WarbandNexus = ns.WarbandNexus

-- Current addon version
local CURRENT_VERSION = "1.0.0"

-- Changelog for current version (manual update required)
local CHANGELOG = {
    version = "1.0.0",
    date = "2024-12-16",
    changes = {
        "Added Smart Character Sorting System",
        "Added Favorite Characters feature",
        "Added ToS Compliance documentation",
        "Added Modern UI with rounded tabs and badges",
        "Added Minimap button with tooltip",
        "Added Enhanced item tooltips",
        "Added Cross-character PvE tracking",
    }
}

--[[============================================================================
    NOTIFICATION QUEUE
============================================================================]]

local notificationQueue = {}

---Add a notification to the queue
---@param notification table Notification data
local function QueueNotification(notification)
    table.insert(notificationQueue, notification)
end

---Process notification queue (show one at a time)
local function ProcessNotificationQueue()
    if #notificationQueue == 0 then
        return
    end
    
    -- Show first notification
    local notification = table.remove(notificationQueue, 1)
    
    if notification.type == "update" then
        WarbandNexus:ShowUpdateNotification(notification.data)
    elseif notification.type == "vault" then
        WarbandNexus:ShowVaultReminder(notification.data)
    end
    
    -- Schedule next notification (2 second delay)
    if #notificationQueue > 0 then
        C_Timer.After(2, ProcessNotificationQueue)
    end
end

--[[============================================================================
    VERSION CHECK & UPDATE NOTIFICATION
============================================================================]]

---Check if there's a new version
---@return boolean isNewVersion
function WarbandNexus:IsNewVersion()
    if not self.db or not self.db.profile or not self.db.profile.notifications then
        return false
    end
    
    local lastSeen = self.db.profile.notifications.lastSeenVersion or "0.0.0"
    return CURRENT_VERSION ~= lastSeen
end

---Show update notification popup
---@param changelogData table Changelog data
function WarbandNexus:ShowUpdateNotification(changelogData)
    -- Create backdrop frame
    local backdrop = CreateFrame("Frame", "WarbandNexusUpdateBackdrop", UIParent)
    backdrop:SetFrameStrata("FULLSCREEN_DIALOG")
    backdrop:SetFrameLevel(1000)
    backdrop:SetAllPoints()
    backdrop:EnableMouse(true)
    backdrop:SetScript("OnMouseDown", function() end) -- Block clicks
    
    -- Semi-transparent black overlay
    local bg = backdrop:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Popup frame
    local popup = CreateFrame("Frame", nil, backdrop, "BackdropTemplate")
    popup:SetSize(450, 400)
    popup:SetPoint("CENTER", 0, 50)
    popup:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popup:SetBackdropColor(0.08, 0.08, 0.10, 1)
    popup:SetBackdropBorderColor(0.4, 0.2, 0.58, 1)
    
    -- Glow effect
    local glow = popup:CreateTexture(nil, "ARTWORK")
    glow:SetPoint("TOPLEFT", -10, 10)
    glow:SetPoint("BOTTOMRIGHT", 10, -10)
    glow:SetColorTexture(0.6, 0.4, 0.9, 0.1)
    
    -- Logo/Icon
    local logo = popup:CreateTexture(nil, "ARTWORK")
    logo:SetSize(64, 64)
    logo:SetPoint("TOP", 0, -20)
    logo:SetTexture("Interface\\AddOns\\WarbandNexus\\Media\\icon")
    
    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -10)
    title:SetText("|cff9966ffWarband Nexus|r")
    
    -- Version subtitle
    local versionText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionText:SetPoint("TOP", title, "BOTTOM", 0, -5)
    versionText:SetText("Version " .. changelogData.version .. " - " .. changelogData.date)
    versionText:SetTextColor(0.6, 0.6, 0.6)
    
    -- Separator line
    local separator = popup:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", 30, -140)
    separator:SetPoint("TOPRIGHT", -30, -140)
    separator:SetColorTexture(0.4, 0.2, 0.58, 0.5)
    
    -- "What's New" label
    local whatsNewLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    whatsNewLabel:SetPoint("TOP", separator, "BOTTOM", 0, -15)
    whatsNewLabel:SetText("|cffffd700What's New|r")
    
    -- Changelog scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, popup)
    scrollFrame:SetPoint("TOPLEFT", 30, -185)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 60)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Populate changelog
    local yOffset = 0
    for i, change in ipairs(changelogData.changes) do
        local bullet = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bullet:SetPoint("TOPLEFT", 0, -yOffset)
        bullet:SetPoint("TOPRIGHT", -20, -yOffset) -- Leave space for scrollbar
        bullet:SetJustifyH("LEFT")
        bullet:SetText("|cff9966ff•|r " .. change)
        bullet:SetTextColor(0.9, 0.9, 0.9)
        
        yOffset = yOffset + bullet:GetStringHeight() + 8
    end
    
    scrollChild:SetHeight(yOffset)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    closeBtn:SetSize(120, 35)
    closeBtn:SetPoint("BOTTOM", 0, 15)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    closeBtn:SetBackdropColor(0.4, 0.2, 0.58, 1)
    closeBtn:SetBackdropBorderColor(0.6, 0.4, 0.9, 1)
    
    local closeBtnText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeBtnText:SetPoint("CENTER")
    closeBtnText:SetText("Got it!")
    
    closeBtn:SetScript("OnClick", function()
        -- Mark version as seen
        self.db.profile.notifications.lastSeenVersion = CURRENT_VERSION
        
        -- Close popup
        backdrop:Hide()
        backdrop:SetParent(nil)
        
        -- Process next notification
        ProcessNotificationQueue()
    end)
    
    closeBtn:SetScript("OnEnter", function(btn)
        btn:SetBackdropColor(0.5, 0.3, 0.7, 1)
    end)
    
    closeBtn:SetScript("OnLeave", function(btn)
        btn:SetBackdropColor(0.4, 0.2, 0.58, 1)
    end)
    
    -- Escape key to close
    backdrop:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            closeBtn:Click()
        end
    end)
    backdrop:SetPropagateKeyboardInput(false)
end

--[[============================================================================
    GENERIC TOAST NOTIFICATION SYSTEM (WITH STACKING)
============================================================================]]

-- Initialize toast tracking (if not already initialized)
if not WarbandNexus.activeToasts then
    WarbandNexus.activeToasts = {} -- Currently visible toasts (max 3)
end
if not WarbandNexus.toastQueue then
    WarbandNexus.toastQueue = {} -- Waiting toasts (if >3 active)
end
if not WarbandNexus.isProcessingToast then
    WarbandNexus.isProcessingToast = false -- Flag to prevent simultaneous toast creation
end

---Show a generic toast notification (unified style for all notifications)
---@param config table Configuration: {icon, title, message, color, autoDismiss, onClose}
function WarbandNexus:ShowToastNotification(config)
    -- If we already have 3 active toasts, queue this one
    if #self.activeToasts >= 3 then
        table.insert(self.toastQueue, config)
        return
    end
    
    -- If we're already processing a toast from the queue, wait
    if self.isProcessingToast then
        table.insert(self.toastQueue, config)
        return
    end
    
    -- Mark as processing
    self.isProcessingToast = true
    
    -- Default values
    config = config or {}
    local iconTexture = config.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local titleText = config.title or "Notification"
    local messageText = config.message or ""
    local categoryText = config.category or nil
    local subtitleText = config.subtitle or ""
    local planType = config.planType or "custom" -- mount, pet, toy, custom
    local autoDismissDelay = config.autoDismiss or 8 -- Default 8 seconds (was too fast at 10 with old timing)
    local onCloseCallback = config.onClose
    local playSound = config.playSound ~= false -- Default true
    
    -- Type-specific colors (gold for mount, green for pet, yellow for toy, purple for custom)
    local typeColors = {
        mount = {1.0, 0.8, 0.2},     -- Gold
        pet = {0.3, 1.0, 0.4},       -- Green
        toy = {1.0, 0.9, 0.2},       -- Yellow
        custom = {0.6, 0.4, 0.9},    -- Purple
        recipe = {0.8, 0.8, 0.5},    -- Tan
    }
    local titleColor = config.titleColor or typeColors[planType] or typeColors.custom
    
    -- Calculate vertical position (stack toasts: 1st=-100, 2nd=-220, 3rd=-340)
    local toastIndex = #self.activeToasts + 1
    local toastHeight = 70 -- Compact height
    local toastSpacing = 10
    local yOffset = -(100 + (toastIndex - 1) * (toastHeight + toastSpacing))
    
    -- === MAIN POPUP FRAME ===
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(360, toastHeight) -- Compact width
    popup:SetPoint("TOP", UIParent, "TOP", 0, yOffset)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(1000 + toastIndex)
    popup:EnableMouse(true)
    
    -- Premium backdrop with balanced border
    popup:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    
    -- Darker background for contrast
    popup:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    popup:SetBackdropBorderColor(titleColor[1], titleColor[2], titleColor[3], 1)
    
    -- Track this toast
    table.insert(self.activeToasts, popup)
    popup.toastIndex = toastIndex
    popup.isClosing = false
    
    -- === BACKGROUND LAYERS ===
    -- Background glows removed for cleaner look
    
    -- All shine effects removed (were causing lighter areas)
    
    -- === ICON WITH PREMIUM FRAME (LEFT SIDE) ===
    -- Icon outer glow removed for cleaner look
    
    -- Icon border frame (compact, transparent background)
    local iconBorder = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    iconBorder:SetSize(54, 54)
    iconBorder:SetPoint("LEFT", 8, 0)
    iconBorder:SetBackdrop({
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    iconBorder:SetBackdropBorderColor(titleColor[1], titleColor[2], titleColor[3], 1)
    
    -- Icon inner frame (double border effect)
    local iconInnerBorder = CreateFrame("Frame", nil, iconBorder, "BackdropTemplate")
    iconInnerBorder:SetPoint("TOPLEFT", 3, -3)
    iconInnerBorder:SetPoint("BOTTOMRIGHT", -3, 3)
    iconInnerBorder:SetBackdrop({
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    iconInnerBorder:SetBackdropBorderColor(titleColor[1] * 0.5, titleColor[2] * 0.5, titleColor[3] * 0.5, 0.5)
    
    -- Icon texture (perfectly fitted)
    local icon = iconBorder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -3, 3)
    icon:SetDrawLayer("ARTWORK", 1)
    
    -- Handle both numeric IDs and texture paths
    if type(iconTexture) == "number" then
        icon:SetTexture(iconTexture)
    elseif iconTexture and iconTexture ~= "" then
        -- Clean the path and set texture
        local cleanPath = iconTexture:gsub("\\", "/")
        icon:SetTexture(cleanPath)
    else
        icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
    end
    
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:Show()
    
    -- Icon glow removed for cleaner look
    -- Create a placeholder texture for animation compatibility
    local iconGlow = iconBorder:CreateTexture(nil, "BACKGROUND")
    iconGlow:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", -1, 1)
    iconGlow:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", 1, -1)
    iconGlow:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    iconGlow:SetVertexColor(titleColor[1], titleColor[2], titleColor[3], 0)  -- Invisible
    iconGlow:SetBlendMode("ADD")
    
    -- === CONTENT AREA (RIGHT OF ICON) ===
    
    -- === CONTENT LAYOUT (BALANCED HIERARCHY) ===
    
    -- Achievement-style decorative corner (smaller)
    local cornerDecor = popup:CreateTexture(nil, "OVERLAY")
    cornerDecor:SetSize(16, 16)
    cornerDecor:SetPoint("TOPRIGHT", -3, -3)
    cornerDecor:SetTexture("Interface\\AchievementFrame\\UI-Achievement-TinyShields")
    cornerDecor:SetTexCoord(0, 0.5, 0, 0.5)
    cornerDecor:SetVertexColor(titleColor[1], titleColor[2], titleColor[3], 0.6)
    
    -- Category badge (compact style)
    if categoryText then
        local categoryBadge = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        categoryBadge:SetPoint("TOPRIGHT", -22, -5)
        categoryBadge:SetText(string.format("|cff%02x%02x%02x• %s •|r",
            titleColor[1]*220, titleColor[2]*220, titleColor[3]*220, categoryText:upper()))
        categoryBadge:SetJustifyH("RIGHT")
        categoryBadge:SetShadowOffset(1, -1)
        categoryBadge:SetShadowColor(0, 0, 0, 0.8)
    end
    
    -- Title (compact, vertically centered)
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 8, -6)
    title:SetPoint("RIGHT", -30, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 0.9)
    
    -- Create bright gradient text for title
    local titleGradient = string.format("|cff%02x%02x%02x%s|r",
        math.min(255, titleColor[1]*255*1.4),
        math.min(255, titleColor[2]*255*1.4),
        math.min(255, titleColor[3]*255*1.4),
        titleText)
    title:SetText(titleGradient)
    
    -- Subtitle (if provided)
    local yOffsetMessage = -22
    if subtitleText and subtitleText ~= "" then
        local subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        subtitle:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 8, -22)
        subtitle:SetPoint("RIGHT", -30, 0)
        subtitle:SetJustifyH("LEFT")
        subtitle:SetText("|cffcccccc" .. subtitleText .. "|r")
        subtitle:SetWordWrap(true)
        subtitle:SetShadowOffset(1, -1)
        subtitle:SetShadowColor(0, 0, 0, 0.6)
        yOffsetMessage = -36
    end
    
    -- Message (main content - compact)
    local message = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    message:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 8, yOffsetMessage)
    message:SetPoint("RIGHT", -30, 0)
    message:SetJustifyH("LEFT")
    message:SetText(messageText)
    message:SetTextColor(1, 1, 1)
    message:SetWordWrap(true)
    message:SetMaxLines(2)
    message:SetShadowOffset(1, -1)
    message:SetShadowColor(0, 0, 0, 0.9)
    
    -- === PROGRESS BAR (compact auto-dismiss indicator) ===
    
    local progressBarBg = popup:CreateTexture(nil, "BORDER")
    progressBarBg:SetPoint("BOTTOMLEFT", 2, 2)
    progressBarBg:SetPoint("BOTTOMRIGHT", -2, 2)
    progressBarBg:SetHeight(2)
    progressBarBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    
    local progressBar = popup:CreateTexture(nil, "ARTWORK")
    progressBar:SetPoint("BOTTOMLEFT", 2, 2)
    progressBar:SetHeight(2)
    progressBar:SetWidth(popup:GetWidth() - 4)
    progressBar:SetColorTexture(titleColor[1]*0.7, titleColor[2]*0.7, titleColor[3]*0.7, 1)
    
    -- Progress bar shine overlay removed (no shine effects allowed)
    local progressShine = popup:CreateTexture(nil, "OVERLAY")
    progressShine:SetPoint("BOTTOMLEFT", 2, 2)
    progressShine:SetHeight(2)
    progressShine:SetWidth(popup:GetWidth() - 4)
    progressShine:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    progressShine:SetColorTexture(0, 0, 0, 0)  -- Invisible placeholder for animation compatibility
    
    -- White flash effect overlay (exact same size as toast)
    local flashOverlay = popup:CreateTexture(nil, "OVERLAY", nil, 7)
    flashOverlay:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    flashOverlay:SetSize(360, 70) -- Exact toast size
    flashOverlay:SetPoint("CENTER", popup, "CENTER", 0, 0)
    flashOverlay:SetVertexColor(1, 1, 1)
    flashOverlay:SetBlendMode("ADD")
    flashOverlay:SetAlpha(0)
    
    -- === SOUND EFFECT ===
    
    if playSound then
        -- Play a pleasant completion sound
        PlaySound(44295) -- SOUNDKIT.UI_EPICACHIEVEMENTUNLOCKED (lighter alternative: 888)
    end
    
    -- Helper function to remove this toast and process queue (must be defined before use)
    local function CloseToast()
        -- Cancel timers safely
        if popup and popup.progressTimer then
            popup.progressTimer:Cancel()
            popup.progressTimer = nil
        end
        if popup and popup.dismissTimer then
            popup.dismissTimer:Cancel()
            popup.dismissTimer = nil
        end
        
        -- Remove from active toasts
        local wasRemoved = false
        for i, toast in ipairs(self.activeToasts) do
            if toast == popup then
                table.remove(self.activeToasts, i)
                wasRemoved = true
                break
            end
        end
        
        if not wasRemoved then
            return -- Toast was already removed, prevent duplicate processing
        end
        
        popup:Hide()
        popup:SetParent(nil)
        
        -- Call user callback
        if onCloseCallback then onCloseCallback() end
        
        -- Reposition ALL remaining toasts (always reposition for perfect queue)
        local stackHeight = 70 -- Must match toastHeight above
        local stackSpacing = 10 -- Must match toastSpacing above
        
        for i, toast in ipairs(self.activeToasts) do
            -- Recalculate position based on NEW index
            local newYOffset = -(100 + (i - 1) * (stackHeight + stackSpacing))
            
            -- ALWAYS clear old position and set new one
            toast:ClearAllPoints()
            toast:SetPoint("TOP", UIParent, "TOP", 0, newYOffset)
            
            -- Update frame properties
            toast:SetFrameLevel(1000 + i)
            toast.toastIndex = i
        end
        
        -- Show next queued toast (if any) - wait for repositioning to complete
        if #self.toastQueue > 0 and #self.activeToasts < 3 then
            local nextConfig = table.remove(self.toastQueue, 1)
            C_Timer.After(0.3, function() -- Fixed delay after repositioning
                if self and self.ShowToastNotification and #self.activeToasts < 3 then
                    self:ShowToastNotification(nextConfig)
                end
            end)
        end
    end
    
    -- === HOVER EFFECTS & CLICK TO DISMISS ===
    
    popup:SetScript("OnEnter", function(self)
        -- Brighten border on hover
        self:SetBackdropBorderColor(
            math.min(1, titleColor[1]*1.3),
            math.min(1, titleColor[2]*1.3),
            math.min(1, titleColor[3]*1.3),
            1
        )
    end)
    
    popup:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(titleColor[1], titleColor[2], titleColor[3], 1)
    end)
    
    -- Click anywhere on toast to dismiss
    popup:SetScript("OnMouseDown", function(self)
        -- Prevent multiple clicks
        if self.isClosing then
            return
        end
        self.isClosing = true
        
        -- Cancel auto-dismiss timer
        if popup and popup.dismissTimer then
            popup.dismissTimer:Cancel()
            popup.dismissTimer = nil
        end
        
        -- Cancel progress timer
        if popup and popup.progressTimer then
            popup.progressTimer:Cancel()
            popup.progressTimer = nil
        end
        
        -- Fade out quickly on click
        local quickFadeAg = popup:CreateAnimationGroup()
        local quickFade = quickFadeAg:CreateAnimation("Alpha")
        quickFade:SetFromAlpha(popup:GetAlpha())
        quickFade:SetToAlpha(0)
        quickFade:SetDuration(0.25)
        quickFadeAg:SetScript("OnFinished", function()
            if popup and popup:IsShown() then
                CloseToast()
            end
        end)
        quickFadeAg:Play()
    end)
    
    -- === ANIMATIONS ===
    
    -- Progress bar animation setup (will start after entrance)
    local progressMaxWidth = popup:GetWidth() - 4
    local function StartProgressBar()
        local progressStartTime = GetTime()
        local progressDuration = autoDismissDelay
        
        popup.progressTimer = C_Timer.NewTicker(0.05, function()
            if not popup or not popup:IsShown() then
                if popup.progressTimer then
                    popup.progressTimer:Cancel()
                    popup.progressTimer = nil
                end
                return
            end
            
            local elapsed = GetTime() - progressStartTime
            local remaining = math.max(0, progressDuration - elapsed)
            local percent = remaining / progressDuration
            local newWidth = progressMaxWidth * percent
            progressBar:SetWidth(math.max(1, newWidth))
            progressShine:SetWidth(math.max(1, newWidth))
            
            if remaining <= 0 then
                if popup.progressTimer then
                    popup.progressTimer:Cancel()
                    popup.progressTimer = nil
                end
            end
        end)
    end
    
    -- Flash animation (full white, dramatic)
    local flashAg = popup:CreateAnimationGroup()
    
    local flashIn = flashAg:CreateAnimation("Alpha")
    flashIn:SetTarget(flashOverlay)
    flashIn:SetFromAlpha(0)
    flashIn:SetToAlpha(1.0) -- FULL white, no transparency
    flashIn:SetDuration(0.08)
    flashIn:SetStartDelay(0)
    flashIn:SetSmoothing("NONE") -- Instant impact
    
    local flashOut = flashAg:CreateAnimation("Alpha")
    flashOut:SetTarget(flashOverlay)
    flashOut:SetFromAlpha(1.0)
    flashOut:SetToAlpha(0)
    flashOut:SetDuration(0.35)
    flashOut:SetStartDelay(0.08)
    flashOut:SetSmoothing("IN")
    
    -- Auto-dismiss after delay (entrance animation + display time)
    local entranceDuration = 0.4 -- Total entrance animation time (simplified)
    local totalDelay = entranceDuration + autoDismissDelay
    
    popup.dismissTimer = C_Timer.NewTimer(totalDelay, function()
        -- Check if toast still exists and is shown
        if not popup or not popup:IsShown() or popup.isClosing then
            return
        end
        
        popup.isClosing = true
        
        -- Fade out animation
        local fadeOutAg = popup:CreateAnimationGroup()
        local fadeOut = fadeOutAg:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(popup:GetAlpha())
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.5)
        fadeOut:SetSmoothing("IN")
        
        -- Slide up slightly
        local slideUp = fadeOutAg:CreateAnimation("Translation")
        slideUp:SetOffset(0, 30)
        slideUp:SetDuration(0.5)
        slideUp:SetSmoothing("IN")
        
        fadeOutAg:SetScript("OnFinished", function()
            if popup and popup:IsShown() then
                CloseToast()
            end
        end)
        fadeOutAg:Play()
    end)
    
    -- === ENTRANCE ANIMATION (smooth slide down with fade) ===
    
    popup:SetAlpha(0)
    local startYOffset = yOffset + 40 -- Start 40px above final position
    popup:ClearAllPoints()
    popup:SetPoint("TOP", UIParent, "TOP", 0, startYOffset)
    
    local enterAg = popup:CreateAnimationGroup()
    
    -- Fade in smoothly
    local fadeIn = enterAg:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.3)
    fadeIn:SetSmoothing("OUT")
    
    -- Slide down smoothly to final position
    local slideDown = enterAg:CreateAnimation("Translation")
    slideDown:SetOffset(0, -40) -- Move down to final position
    slideDown:SetDuration(0.4)
    slideDown:SetSmoothing("OUT")
    
    -- After entrance, start looping animations
    enterAg:SetScript("OnFinished", function()
        if not popup or not popup:IsShown() then
            if self then
                self.isProcessingToast = false
            end
            return
        end
        popup:ClearAllPoints()
        popup:SetPoint("TOP", UIParent, "TOP", 0, yOffset)
        popup:SetAlpha(1.0)
        StartProgressBar() -- Start progress bar AFTER entrance animation completes
        
        -- Reset processing flag now that entrance is complete
        if self then
            self.isProcessingToast = false
        end
    end)
    
    -- Start entrance animation and flash
    enterAg:Play()
    flashAg:Play()
    
    -- Show popup
    popup:Show()
end

--[[============================================================================
    VAULT REMINDER
============================================================================]]

---Check if player has unclaimed vault rewards
---@return boolean hasRewards
function WarbandNexus:HasUnclaimedVaultRewards()
    -- Check if API is available
    if not C_WeeklyRewards or not C_WeeklyRewards.HasAvailableRewards then
        return false
    end
    
    -- Check for rewards
    local hasRewards = C_WeeklyRewards.HasAvailableRewards()
    return hasRewards
end

---Show vault reminder popup (small toast notification)
---@param data table Vault data
function WarbandNexus:ShowVaultReminder(data)
    -- Use the generic toast notification system (with stacking support)
    self:ShowToastNotification({
        icon = "Interface\\Icons\\achievement_guildperk_bountifulbags",
        title = "Weekly Vault Ready!",
        message = "You have unclaimed Weekly Vault Rewards",
        titleColor = {0.6, 0.4, 0.9}, -- Purple
        autoDismiss = 10, -- 10 seconds
        onClose = function()
            -- Toast stacking system handles queue automatically
            -- Only process main notification queue (for update popups)
            ProcessNotificationQueue()
        end
    })
end

--[[============================================================================
    NOTIFICATION SYSTEM INITIALIZATION
============================================================================]]

---Check and queue notifications on login
function WarbandNexus:CheckNotificationsOnLogin()
    if not self.db or not self.db.profile or not self.db.profile.notifications then
        return
    end
    
    local notifs = self.db.profile.notifications
    
    -- Check if notifications are enabled
    if not notifs.enabled then
        return
    end
    
    -- 1. Check for new version
    if notifs.showUpdateNotes and self:IsNewVersion() then
        QueueNotification({
            type = "update",
            data = CHANGELOG
        })
    end
    
    -- 2. Check for vault rewards (delayed to ensure API is ready)
    C_Timer.After(2, function()
        if notifs.showVaultReminder and self:HasUnclaimedVaultRewards() then
            QueueNotification({
                type = "vault",
                data = {}
            })
        end
    end)
    
    -- Process queue (delayed by 3 seconds after login)
    if #notificationQueue > 0 then
        C_Timer.After(3, ProcessNotificationQueue)
    else
        -- Check again after vault check completes
        C_Timer.After(4, function()
            if #notificationQueue > 0 then
                ProcessNotificationQueue()
            end
        end)
    end
end

---Export current version
function WarbandNexus:GetAddonVersion()
    return CURRENT_VERSION
end

--[[============================================================================
    LOOT NOTIFICATIONS (MOUNT/PET/TOY)
============================================================================]]

---Show loot notification toast (mount/pet/toy)
---Uses generic toast notification system for consistent style
---@param itemID number Item ID (or mount/pet ID)
---@param itemLink string Item link
---@param itemName string Item name
---@param collectionType string Type: "Mount", "Pet", or "Toy"
---@param iconOverride number|nil Optional icon override
function WarbandNexus:ShowLootNotification(itemID, itemLink, itemName, collectionType, iconOverride)
    -- Check if loot notifications are enabled
    if not self.db or not self.db.profile or not self.db.profile.notifications then
        return
    end
    
    if not self.db.profile.notifications.showLootNotifications then
        return
    end
    
    -- Get item icon (use override if provided)
    local icon = iconOverride
    
    if not icon then
        if collectionType == "Mount" then
            icon = select(3, C_MountJournal.GetMountInfoByID(itemID)) or "Interface\\Icons\\Ability_Mount_RidingHorse"
        elseif collectionType == "Pet" then
            icon = select(2, C_PetJournal.GetPetInfoBySpeciesID(itemID)) or "Interface\\Icons\\INV_Pet_BabyBlizzardBear"
        else
            icon = select(10, GetItemInfo(itemID)) or "Interface\\Icons\\INV_Misc_Toy_01"
        end
    end
    
    -- Use the generic toast notification system
    self:ShowToastNotification({
        icon = icon,
        title = itemName,
        message = "New " .. collectionType .. " collected!",
        titleColor = {1.0, 0.82, 0}, -- Gold color for collectibles
        autoDismiss = 8,
        sound = 12889, -- SOUNDKIT.UI_LEGENDARY_LOOT_TOAST
    })
end

---Initialize loot notification system
function WarbandNexus:InitializeLootNotifications()
    -- Just a placeholder - CollectionManager handles everything now
    -- NotificationManager only provides toast display functions
end

---Show collectible toast notification (called by CollectionManager)
---@param data table {type, name, icon} from CollectionManager
function WarbandNexus:ShowCollectibleToast(data)
    if not data or not data.type or not data.name then return end
    
    -- Capitalize type for display
    local typeCapitalized = data.type:sub(1,1):upper() .. data.type:sub(2)
    
    -- Show toast using existing system
    self:ShowLootNotification(
        0, -- itemID not needed for display
        "|cff0070dd[" .. data.name .. "]|r", -- Fake link
        data.name,
        typeCapitalized,
        data.icon
    )
end

---Test loot notification system (Mounts, Pets, & Toys)
---With stacking system: all toasts can be shown at once (max 3 visible, rest queued)
function WarbandNexus:TestLootNotification(type)
    type = type and strlower(type) or "all"
    
    -- Special test: "spam" shows 5 toasts to test queue system
    if type == "spam" then
        for i = 1, 5 do
            local icons = {
                "Interface\\Icons\\Ability_Mount_Invincible",
                "Interface\\Icons\\INV_Pet_BabyBlizzardBear",
                "Interface\\Icons\\INV_Misc_Toy_01",
                "Interface\\Icons\\Ability_Mount_Drake_Azure",
                "Interface\\Icons\\INV_Pet_BabyEbonWhelp"
            }
            local names = {"Test Mount " .. i, "Test Pet " .. i, "Test Toy " .. i, "Test Mount " .. (i+1), "Test Pet " .. (i+1)}
            local types = {"Mount", "Pet", "Toy", "Mount", "Pet"}
            
            C_Timer.After(i * 0.3, function()
                self:ShowLootNotification(i, "|cff0070dd[" .. names[i] .. "]|r", names[i], types[i], icons[i])
            end)
        end
        self:Print("|cff00ff005 test toasts queued! (spam test)|r")
        return
    end
    
    -- Show mount test
    if type == "mount" or type == "all" then
        self:ShowLootNotification(
            1234,
            "|cff0070dd[Test Mount]|r",
            "Test Mount",
            "Mount",
            "Interface\\Icons\\Ability_Mount_Invincible"
        )
        if type == "mount" then
            self:Print("|cff00ff00Test mount notification shown!|r")
            return
        end
    end
    
    -- Show pet test
    if type == "pet" or type == "all" then
        C_Timer.After(type == "all" and 0.5 or 0, function()
            self:ShowLootNotification(
                5678,
                "|cff0070dd[Test Pet]|r",
                "Test Pet",
                "Pet",
                "Interface\\Icons\\INV_Pet_BabyBlizzardBear"
            )
            if type == "pet" then
                self:Print("|cff00ff00Test pet notification shown!|r")
            end
        end)
        if type == "pet" then return end
    end
    
    -- Show toy test
    if type == "toy" or type == "all" then
        C_Timer.After(type == "all" and 1.0 or 0, function()
            self:ShowLootNotification(
                9012,
                "|cff0070dd[Test Toy]|r",
                "Test Toy",
                "Toy",
                "Interface\\Icons\\INV_Misc_Toy_01"
            )
            if type == "toy" then
                self:Print("|cff00ff00Test toy notification shown!|r")
            end
        end)
    end
    
    if type == "all" then
        self:Print("|cff00ff00Testing all 3 collectible types! (with stacking)|r")
    end
end

---Manual test function for vault check (slash command)
function WarbandNexus:TestVaultCheck()
    self:Print("|cff00ccff=== VAULT CHECK TEST ===|r")
    
    -- Check API
    if not C_WeeklyRewards then
        self:Print("|cffff0000ERROR: C_WeeklyRewards API not found!|r")
        return
    else
        self:Print("|cff00ff00✓ C_WeeklyRewards API available|r")
    end
    
    if not C_WeeklyRewards.HasAvailableRewards then
        self:Print("|cffff0000ERROR: HasAvailableRewards function not found!|r")
        return
    else
        self:Print("|cff00ff00✓ HasAvailableRewards function available|r")
    end
    
    -- Check rewards
    local hasRewards = C_WeeklyRewards.HasAvailableRewards()
    self:Print("Result: " .. tostring(hasRewards))
    
    if hasRewards then
        self:Print("|cff00ff00✓ YOU HAVE UNCLAIMED REWARDS!|r")
        self:Print("Showing vault notification...")
        self:ShowVaultReminder({})
    else
        self:Print("|cff888888✗ No unclaimed rewards|r")
    end
    
    self:Print("|cff00ccff======================|r")
end








