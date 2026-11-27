--[[ ==============================================================================
    SummonPet Biggins - Companion Summoning & Journal Engine
    ------------------------------------------------------------------------------
    Zero-garbage summoning, debounced safe dismissal, pet pinning, journal search,
    and mode management.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local C_PetJournal      = C_PetJournal
local C_Timer           = C_Timer
local InCombatLockdown  = InCombatLockdown
local CopyTable         = CopyTable
local tostring          = tostring

-- Core Summon Function (Zero-Garbage)
function addon:Summon()
    if not addon:CanSummon() then
        return
    end

    local currentPet = C_PetJournal.GetSummonedPetGUID()
    local mode = SummonPetBigginsDB.mode or "FAVORITES"

    if mode == "PINNED" and SummonPetBigginsDB.pinnedPetGUID then
        if currentPet ~= SummonPetBigginsDB.pinnedPetGUID then
            C_PetJournal.SummonPetByGUID(SummonPetBigginsDB.pinnedPetGUID)
        end
        return
    end

    -- If already holding an active pet in Random or Favorites, do nothing
    if currentPet then
        return
    end

    if mode == "RANDOM" then
        C_PetJournal.SummonRandomPet(false)
    else
        -- Default: Random Favorite Companion
        C_PetJournal.SummonRandomPet(true)
    end
end

-- Core Dismiss Function (Debounced Safe Dismissal)
function addon:Dismiss(attempt)
    attempt = attempt or 1
    addon:CancelAllPendingSummons()

    if not InCombatLockdown() then
        local currentPet = C_PetJournal.GetSummonedPetGUID()
        if currentPet then
            C_PetJournal.SummonPetByGUID(currentPet)
        end
    end

    -- Retry up to 3 times to catch pets delayed by unmounting or combat sync
    if attempt >= addon.MAX_DISMISS_ATTEMPTS then
        return
    end

    C_Timer.After(addon.DISMISS_RETRY_INTERVAL * attempt, function()
        local shouldDismiss = addon:ShouldDismissInStealth() or addon:ShouldDismissInCurrentInstance() or addon:ShouldDismissMounted()
        if not shouldDismiss then
            return
        end

        local pet = C_PetJournal.GetSummonedPetGUID()
        if pet or InCombatLockdown() then
            addon:Dismiss(attempt + 1)
        end
    end)
end

-- Pin Currently Active Pet
function addon:PinCurrentPet()
    local currentPet = C_PetJournal.GetSummonedPetGUID()
    if not currentPet then
        addon:PrintMsg("|cFFFF5555No companion pet currently summoned!|r Summon a pet first, then pin it.")
        return false
    end

    local _, customName, _, _, _, _, _, speciesName = C_PetJournal.GetPetInfoByPetID(currentPet)
    local displayName = customName or speciesName or "Unknown Pet"

    SummonPetBigginsDB.mode = "PINNED"
    SummonPetBigginsDB.pinnedPetGUID = currentPet
    SummonPetBigginsDB.pinnedPetName = displayName

    addon:PrintMsg("Pinned active companion: |cFF00FF00" .. displayName .. "|r (Mode set to Pinned).")
    addon:UpdateOptionsUI()
    return true
end

-- Search for an owned pet by custom nickname or species name
function addon:FindPetByName(targetName)
    if not targetName or targetName == "" then return nil end
    local searchLower = targetName:lower()

    local numPets = C_PetJournal.GetNumPets()
    local matchedPetID, matchedDisplayName

    -- First pass: search current view (prioritizing custom nickname over species name)
    for i = 1, numPets do
        local petID, _, isOwned, customName, _, _, _, speciesName = C_PetJournal.GetPetInfoByIndex(i)
        if isOwned and petID then
            if customName and customName:lower() == searchLower then
                return petID, customName
            elseif speciesName and speciesName:lower() == searchLower and not matchedPetID then
                matchedPetID = petID
                matchedDisplayName = speciesName
            end
        end
    end

    if matchedPetID then
        return matchedPetID, matchedDisplayName
    end

    -- Second pass: if user had an active search/filter in Pet Journal, clear filter and retry
    if C_PetJournal.ClearSearchFilter then
        C_PetJournal.ClearSearchFilter()
        numPets = C_PetJournal.GetNumPets()
        for i = 1, numPets do
            local petID, _, isOwned, customName, _, _, _, speciesName = C_PetJournal.GetPetInfoByIndex(i)
            if isOwned and petID then
                if customName and customName:lower() == searchLower then
                    return petID, customName
                elseif speciesName and speciesName:lower() == searchLower and not matchedPetID then
                    matchedPetID = petID
                    matchedDisplayName = speciesName
                end
            end
        end
    end

    return matchedPetID, matchedDisplayName
end

-- Pin & Summon Pet by Name
function addon:PinPetByName(targetName)
    if not targetName or targetName:trim() == "" then
        return addon:PinCurrentPet()
    end

    targetName = targetName:trim():gsub('^["\']', ''):gsub('["\']$', '')
    local petID, displayName = addon:FindPetByName(targetName)

    if not petID then
        addon:PrintMsg("|cFFFF5555Could not find an owned companion pet named '|r" .. targetName .. "|cFFFF5555'.|r")
        return false
    end

    SummonPetBigginsDB.mode = "PINNED"
    SummonPetBigginsDB.pinnedPetGUID = petID
    SummonPetBigginsDB.pinnedPetName = displayName

    local currentPet = C_PetJournal.GetSummonedPetGUID()
    if addon:CanSummon() then
        if currentPet ~= petID then
            C_PetJournal.SummonPetByGUID(petID)
        end
        addon:PrintMsg("Pinned and summoned: |cFF00FF00" .. displayName .. "|r (Mode set to Pinned).")
    else
        local reason = "will summon when conditions allow"
        if addon:IsStealthedActive() then
            reason = "will summon when exiting stealth"
        elseif addon:IsInFlightActive() or addon:IsMountedBlocked() then
            reason = "will summon upon landing / dismounting"
        elseif InCombatLockdown() then
            reason = "will summon after combat"
        elseif addon:ShouldDismissInCurrentInstance() then
            reason = "will summon outside instance"
        end
        addon:PrintMsg("Pinned: |cFF00FF00" .. displayName .. "|r (" .. reason .. ").")
    end

    addon:UpdateOptionsUI()
    return true
end

-- Set Summon Mode
function addon:SetMode(newMode)
    if newMode == "FAVORITES" or newMode == "RANDOM" or newMode == "PINNED" then
        SummonPetBigginsDB.mode = newMode
        local modeLabels = {
            FAVORITES = "Random Favorites",
            RANDOM = "Completely Random",
            PINNED = "Pinned Pet (" .. (SummonPetBigginsDB.pinnedPetName or "None") .. ")"
        }
        addon:PrintMsg("Mode set to: |cFF00FF00" .. (modeLabels[newMode] or newMode) .. "|r.")
        addon:UpdateOptionsUI()
        addon:Summon()
    end
end

-- Toggle Function (Triggered via Native Keybind or /summonpetb toggle)
function addon:Toggle()
    if not SummonPetBigginsDB then
        SummonPetBigginsDB = CopyTable(addon.defaults)
    end

    local newState = not SummonPetBigginsDB.enabled
    SummonPetBigginsDB.enabled = newState

    if newState then
        addon:Summon()
    else
        addon:Dismiss()
    end

    if SummonPetBigginsDB.printStatus then
        local status = newState and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Companion auto-summoning is now " .. status .. ".")
    end
    addon:UpdateOptionsUI()
end
