---CollectionManager: Handles mount/pet/toy collection detection and validation
---@class CollectionManager
local addonName, ns = ...
local WarbandNexus = LibStub("AceAddon-3.0"):GetAddon("WarbandNexus")

--[[============================================================================
    COLLECTION CACHE
    Cache player's entire collection for fast lookup
============================================================================]]

---Build collection cache (all owned mounts/pets/toys)
function WarbandNexus:BuildCollectionCache()
    local success, err = pcall(function()
    self.collectionCache = {
        mounts = {},
        pets = {},
        toys = {}
    }
    
    -- Cache all mounts
    if C_MountJournal and C_MountJournal.GetMountIDs then
        local mountIDs = C_MountJournal.GetMountIDs()
        for _, mountID in ipairs(mountIDs) do
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected then
                self.collectionCache.mounts[mountID] = true
            end
        end
    end
    
    -- Cache all pets (by speciesID)
    if C_PetJournal and C_PetJournal.GetNumPets then
        local numPets, numOwned = C_PetJournal.GetNumPets()
        -- Iterate through all pets to build initial cache of owned species
        -- Note: We use GetNumPets and iterate to ensure we get all unique species
        -- For a more complete cache, we might need a different approach if this only shows journal list
        -- But for "owned" check, this is usually sufficient for loaded journal
        for i = 1, numPets do
             local petID, speciesID, owned, customName, _, _, _, _, _, _, _, _, _, _, isTradeable, isUnique = C_PetJournal.GetPetInfoByIndex(i)
             if speciesID and owned then
                 self.collectionCache.pets[speciesID] = true
             end
        end
    end
    
    -- Cache all toys
    if C_ToyBox and C_ToyBox.GetNumToys then
        -- C_ToyBox.GetNumToys returns total available toys, we need to check ownership
        -- We iterate by index which corresponds to the filtered list usually, 
        -- but for a true snapshot we should ideally check "all" toys.
        -- However, iterating known toys is safer. 
        -- Optimization: We rely on C_ToyBox.PlayerHasToy for checks, 
        -- but we populate cache for diffing.
        -- Since GetNumToys depends on filters, this might be incomplete.
        -- Better approach for snapshot: Use C_ToyBox.GetToyInfo on demand or accept filter limitations?
        -- The plan suggests: "C_ToyBox taranır."
        -- Let's stick to iterating what we can see or rely on events for new additions.
        -- To be safe against filter bugs, we primarily rely on PlayerHasToy in checks.
        -- But for the cache diff, we'll try to populate what we can.
        for i = 1, C_ToyBox.GetNumToys() do
            local itemID = C_ToyBox.GetToyFromIndex(i)
            if itemID and PlayerHasToy and PlayerHasToy(itemID) then
                self.collectionCache.toys[itemID] = true
            end
        end
    end
    end)
    
    if not success then
        -- Initialize with empty cache on error
        self.collectionCache = {
            mounts = {},
            pets = {},
            toys = {}
        }
    end
end

---Check if player owns a mount/pet/toy
---@param collectibleType string "mount", "pet", or "toy"
---@param id number mountID, speciesID, or toyItemID
---@return boolean owned
function WarbandNexus:IsCollectibleOwned(collectibleType, id)
    if not self.collectionCache then
        self:BuildCollectionCache()
    end
    
    if collectibleType == "mount" then
        return self.collectionCache.mounts[id] == true
    elseif collectibleType == "pet" then
        return self.collectionCache.pets[id] == true
    elseif collectibleType == "toy" then
        return self.collectionCache.toys[id] == true
    end
    
    return false
end

---Count table entries (helper for debug)
---@param tbl table
---@return number
function WarbandNexus:TableCount(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end
    return count
end

--[[============================================================================
    COLLECTION DETECTION LOGIC
============================================================================]]

---Check if an item is a NEW collectible (mount/pet/toy) that player doesn't have
---@param itemID number The item ID
---@param hyperlink string|nil Item hyperlink (required for caged pets)
---@return table|nil collectibleData {type, id, name, icon} or nil
function WarbandNexus:CheckNewCollectible(itemID, hyperlink)
    if not itemID then return nil end
    
    -- Get basic item info
    local itemName, _, _, _, _, _, _, _, _, itemIcon, _, classID, subclassID = GetItemInfo(itemID)
    if not classID then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    
    -- ========================================
    -- MOUNT (classID 15, subclass 5)
    -- ========================================
    if classID == 15 and subclassID == 5 then
        if not C_MountJournal or not C_MountJournal.GetMountFromItem then
            return nil
        end
        
        local mountID = C_MountJournal.GetMountFromItem(itemID)
        if not mountID then return nil end
        
        -- Check cache: do we already own this?
        if self:IsCollectibleOwned("mount", mountID) then
            return nil
        end
        
        local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
        if not name then return nil end
        
        return {
            type = "mount",
            id = mountID,
            name = name,
            icon = icon
        }
    end
    
    -- ========================================
    -- PET (classID 17)
    -- ========================================
    if classID == 17 then
        -- NOTE: Normal companion pets (items you right-click to learn) are classID 15 (Misc) subclass 2 (Companion Pets)
        -- classID 17 is for "Battle Pets" (Caged pets usually). 
        -- However, TWW might have changed some classifications or user might be referring to learning items.
        -- If an item is classID 17, it is definitely a battle pet cage/item.
        -- If it's a "Companion Pet" item (old style), it might be 15/2.
        
        if not C_PetJournal then return nil end
        
        local speciesID = nil
        
        -- Try API first (works for non-caged pets)
        if C_PetJournal.GetPetInfoByItemID then
            speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
        end
        
        -- For caged pets, extract speciesID from hyperlink
        if not speciesID and hyperlink then
            speciesID = tonumber(hyperlink:match("|Hbattlepet:(%d+):"))
        end
        
        -- Fallback: If no speciesID found, this might be a companion pet item
        -- that hasn't been learned yet (not a caged battle pet)
        -- We can try to assume it's a pet item if classID is 17
        -- But we need speciesID to check if we own it.
        
        if not speciesID then return nil end
        
        -- Check cache: already collected?
        -- Note: For "Pet Cage" items, we want to notify if it's a new species for the player
        if self:IsCollectibleOwned("pet", speciesID) then
            return nil
        end
        
        -- Get display info
        local speciesName, speciesIcon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        
        return {
            type = "pet",
            id = speciesID,
            name = speciesName or itemName or "Unknown Pet",
            icon = speciesIcon or itemIcon or 134400
        }
    end

    -- ========================================
    -- COMPANION PETS (classID 15, subclass 2)
    -- ========================================
    -- Catch-all for items that teach pets but aren't classID 17
    if classID == 15 and subclassID == 2 then
        if not C_PetJournal then return nil end
        
        local speciesID = nil
        if C_PetJournal.GetPetInfoByItemID then
            speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
        end
        
        -- Tooltip Scan Fallback (For items like "Void-Scarred Egg" where GetPetInfoByItemID might fail)
        if not speciesID then
             -- We need to check if the tooltip says "Teaches you how to summon..."
             -- and try to extract the pet name to find speciesID
             -- This is complex without a tooltip scanner.
             -- However, almost all Class 15/Subclass 2 items are pets.
             -- If we can't get speciesID, we can't check ownership accurately.
             -- But maybe we can assume it's a pet if it's 15/2.
             -- The risk is notifying for a duplicate.
             -- But user wants notification ON LOOT.
             
             -- Let's try to trust 15/2 as a pet candidate.
             -- If GetPetInfoByItemID fails, we can't get SpeciesID.
             -- But wait, maybe the API works but we need to rely on it.
        end

        if speciesID then
             if self:IsCollectibleOwned("pet", speciesID) then
                return nil
            end
            
            local speciesName, speciesIcon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
             return {
                type = "pet",
                id = speciesID,
                name = speciesName or itemName or "Unknown Pet",
                icon = speciesIcon or itemIcon or 134400
            }
        end
    end
    
    -- ========================================
    -- UNIVERSAL FALLBACK (For Items with weird ClassIDs)
    -- ========================================
    -- Some items (like Void-Scarred Egg) are Consumables (Class 0) but teach Mounts or Pets.
    -- We perform a check here if previous specific checks failed.
    
    -- 1. Check for MOUNT
    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local mountID = C_MountJournal.GetMountFromItem(itemID)
        if mountID then
            if not self:IsCollectibleOwned("mount", mountID) then
                local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
                if name then
                    return {
                        type = "mount",
                        id = mountID,
                        name = name,
                        icon = icon
                    }
                end
            else
                -- It is a mount, but we own it. Return nil to stop checking.
                return nil
            end
        end
    end

    -- 2. Check for PET
    if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        local speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
        if speciesID then
             if not self:IsCollectibleOwned("pet", speciesID) then
                local speciesName, speciesIcon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
                 return {
                    type = "pet",
                    id = speciesID,
                    name = speciesName or itemName or "Unknown Pet",
                    icon = speciesIcon or itemIcon or 134400
                }
            else
                return nil
            end
        end
    end
    
    -- 3. Check for TOY
    if C_ToyBox and C_ToyBox.GetToyInfo then
        local toyInfo = C_ToyBox.GetToyInfo(itemID)
        
        -- Only proceed if this is a collectible toy
        if toyInfo then
            -- Check cache: do we already own this?
            if self:IsCollectibleOwned("toy", itemID) then
                return nil
            end
            
            return {
                type = "toy",
                id = itemID,
                name = itemName or "Unknown Toy",
                icon = itemIcon or 134400
            }
        end
    end
    
    -- Not a collectible
    return nil
end

--[[============================================================================
    EVENT HANDLING
============================================================================]]

---Update local cache with new item
function WarbandNexus:UpdateCollectionCache(type, id)
    if not self.collectionCache then self:BuildCollectionCache() end
    
    if type == "mount" then
        self.collectionCache.mounts[id] = true
    elseif type == "pet" then
        self.collectionCache.pets[id] = true
    elseif type == "toy" then
        self.collectionCache.toys[id] = true
    end
end

---Handle ACHIEVEMENT_EARNED event
function WarbandNexus:OnAchievementEarned(event, achievementID)
    self:HandleAchievement(achievementID)
end

---Process achievement rewards
---@param achievementID number
function WarbandNexus:HandleAchievement(achievementID)
    if not achievementID then return end
    
    local rewardItemID = C_AchievementInfo.GetRewardItemID(achievementID)
    if not rewardItemID or rewardItemID == 0 then return end
    
    -- Load item data if needed (async mixin)
    local item = Item:CreateFromItemID(rewardItemID)
    item:ContinueOnItemLoad(function()
        -- Check if it's a collectible
        -- Note: CheckNewCollectible checks IsCollectibleOwned internally
        local collectibleData = self:CheckNewCollectible(rewardItemID)
        
        if collectibleData then
            -- Double check cache to prevent race conditions
            if self:IsCollectibleOwned(collectibleData.type, collectibleData.id) then
                return -- Already owned/handled
            end
            
            -- Update Cache & Toast
            self:UpdateCollectionCache(collectibleData.type, collectibleData.id)
            self:ShowCollectibleToast(collectibleData)
        end
    end)
end

---Initialize collection tracking system
function WarbandNexus:InitializeCollectionTracking()
    self:BuildCollectionCache()
    self.notifiedCollectibles = {}
    self.lastBagSnapshot = self:UpdateBagSnapshot()
    
    self:RegisterBucketEvent("BAG_UPDATE_DELAYED", 0.2, "OnBagUpdateForCollections")
    
    -- Event-based tracking (Standard)
    self:RegisterEvent("NEW_MOUNT_ADDED", "OnCollectionUpdated")
    self:RegisterEvent("NEW_PET_ADDED", "OnCollectionUpdated")
    self:RegisterEvent("NEW_TOY_ADDED", "OnCollectionUpdated")
    
    -- Achievement-based tracking (Direct Injection)
    self:RegisterEvent("ACHIEVEMENT_EARNED", "OnAchievementEarned")
    
    -- Ensure cache is built on login
    if IsLoggedIn() then
        self:BuildCollectionCache()
    else
        self:RegisterEvent("PLAYER_LOGIN", "BuildCollectionCache")
    end
end

---Handle collection update events (add new collectible to cache)
---@param event string Event name
---@param ... any Event parameters
function WarbandNexus:OnCollectionUpdated(event, ...)
    if not self.collectionCache then
        self:BuildCollectionCache()
        return
    end
    
    local type, id, name, icon
    
    if event == "NEW_MOUNT_ADDED" then
        local mountID = ...
        if not mountID then return end
        
        -- Snapshot Diff Check
        if self.collectionCache.mounts[mountID] then return end
        
        type = "mount"
        id = mountID
        local mName, _, mIcon = C_MountJournal.GetMountInfoByID(mountID)
        name = mName
        icon = mIcon
    
    elseif event == "NEW_PET_ADDED" then
        local petID = ...
        if petID and C_PetJournal then
            local speciesID = C_PetJournal.GetPetInfoByPetID(petID)
            if speciesID then
                -- Check duplicates (0 -> 1 is new)
                local numOwned = C_PetJournal.GetNumCollectedInfo(speciesID)
                if numOwned and numOwned > 1 then return end -- Duplicate
                
                if self.collectionCache.pets[speciesID] then return end
                
                type = "pet"
                id = speciesID
                local sName, sIcon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
                name = sName
                icon = sIcon
            end
        end
    
    elseif event == "NEW_TOY_ADDED" then
        local itemID, new = ...
        if not itemID or not new then return end
        
        if self.collectionCache.toys[itemID] then return end
        
        type = "toy"
        id = itemID
        local _, tName, _, _, _, _, _, _, _, tIcon = GetItemInfo(itemID)
        
        if not tName then
            C_Item.RequestLoadItemDataByID(itemID)
            name = "New Toy"
            icon = 134400
        else
            name = tName
            icon = tIcon
        end
    end
    
    if type and id and name then
        self:UpdateCollectionCache(type, id)
        
        -- Check if we already notified this item via Loot/Bag detection
        -- This prevents "Double Toasts" when learning an item we just looted
        local trackingKey = type .. "_" .. id
        
        -- Check session-based notification
        if self.notifiedCollectibles[trackingKey] then
            return
        end
        
        -- Check pending learning (items looted recently)
        if self.pendingLearning and self.pendingLearning[trackingKey] then
            -- If it was looted less than 5 minutes ago, consider it handled
            if (GetTime() - self.pendingLearning[trackingKey]) < 300 then
                return
            end
        end
        
        -- Global Debounce (Last resort double-toast prevention)
        -- If we showed a toast for this ID < 5 seconds ago (regardless of source), skip.
        if self.lastToastData and self.lastToastData.id == id and self.lastToastData.type == type then
            if (GetTime() - self.lastToastTime) < 5.0 then
                return
            end
        end
        
        -- Record this toast
        self.lastToastData = { id = id, type = type }
        self.lastToastTime = GetTime()
        
        self:ShowCollectibleToast({
            type = type,
            id = id,
            name = name,
            icon = icon
        })
    end
end

---Update bag snapshot
function WarbandNexus:UpdateBagSnapshot()
    local snapshot = {}
    
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local key = itemInfo.itemID
                    
                    -- Use speciesID for battle pets if possible to differentiate
                    if itemInfo.hyperlink and itemInfo.hyperlink:match("|Hbattlepet:") then
                        local speciesID = tonumber(itemInfo.hyperlink:match("|Hbattlepet:(%d+):"))
                        if speciesID then
                             key = "pet:" .. speciesID
                        else
                             key = itemInfo.hyperlink
                        end
                    end
                    
                    snapshot[key] = true
                end
            end
        end
    end
    
    return snapshot
end

---Handle BAG_UPDATE_DELAYED - detect new loot
function WarbandNexus:OnBagUpdateForCollections()
    if not self.db or not self.db.profile or not self.db.profile.notifications then
        return
    end

    if not self.db.profile.notifications.showLootNotifications then
        return
    end

    if not self.notifiedCollectibles then
        self.notifiedCollectibles = {}
    end
    
    if not self.lastBagSnapshot then
        self.lastBagSnapshot = {}
    end

    local currentSnapshot = self:UpdateBagSnapshot()

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local key = itemInfo.itemID
                    if itemInfo.hyperlink and itemInfo.hyperlink:match("|Hbattlepet:") then
                        local speciesID = tonumber(itemInfo.hyperlink:match("|Hbattlepet:(%d+):"))
                        if speciesID then
                             key = "pet:" .. speciesID
                        else
                             key = itemInfo.hyperlink
                        end
                    end
                    
                    if not self.lastBagSnapshot[key] then
                        -- Found a new item in bag
                        -- Use Async check to ensure ItemInfo is ready (critical for Vendor items)
                        local item = Item:CreateFromItemID(itemInfo.itemID)
                        item:ContinueOnItemLoad(function()
                            -- Re-verify item is still relevant/new in logic terms
                            -- (We can't rely on lastBagSnapshot inside async callback as it might have changed,
                            -- but we know this specific item instance *was* new at the moment of scan)
                            
                            local collectibleData = self:CheckNewCollectible(itemInfo.itemID, itemInfo.hyperlink)
                            
                            if collectibleData then
                                local trackingKey = collectibleData.type .. "_" .. collectibleData.id
                                
                                -- Double check "Owned" status
                                if not self:IsCollectibleOwned(collectibleData.type, collectibleData.id) then
                                    if not self.notifiedCollectibles[trackingKey] then
                                        
                                        -- Global Debounce check for Loot/Bag events too
                                        if self.lastToastData and self.lastToastData.id == collectibleData.id and self.lastToastData.type == collectibleData.type then
                                            if (GetTime() - self.lastToastTime) < 5.0 then
                                                return -- Skip if recently toasted (e.g. from another source)
                                            end
                                        end
                                        
                                        self:ShowCollectibleToast(collectibleData)
                                        self.notifiedCollectibles[trackingKey] = true
                                        
                                        -- Record for global debounce
                                        self.lastToastData = { id = collectibleData.id, type = collectibleData.type }
                                        self.lastToastTime = GetTime()
                                        
                                        -- Mark as "Pending Learning" to catch the subsequent NEW_MOUNT_ADDED event
                                        -- This helps bridge the gap between "Item in Bag" and "Item Learned"
                                        if not self.pendingLearning then self.pendingLearning = {} end
                                        self.pendingLearning[trackingKey] = GetTime()
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
    
    self.lastBagSnapshot = currentSnapshot
end




