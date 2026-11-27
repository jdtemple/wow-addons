--[[ ==============================================================================
    SummonPet Biggins - Grounded Mount Watcher & Debounce Timers
    ------------------------------------------------------------------------------
    Manages mount touchdown watcher ticker, landing/dismount/unstealth debounce
    timers, and grounded movement hooks.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local C_Timer           = C_Timer
local C_PetJournal      = C_PetJournal
local IsMounted         = IsMounted
local InCombatLockdown  = InCombatLockdown
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local hooksecurefunc    = hooksecurefunc
local pcall             = pcall

local mountWatcherTicker = nil
local touchdownTimer     = nil
local dismountTimer      = nil
local unstealthTimer     = nil
local castIdleTimer      = nil
local wasInFlight        = false

function addon:CancelTouchdownTimer()
    if touchdownTimer then
        touchdownTimer:Cancel()
        touchdownTimer = nil
    end
end

function addon:CancelDismountTimer()
    if dismountTimer then
        dismountTimer:Cancel()
        dismountTimer = nil
    end
end

function addon:CancelUnstealthTimer()
    if unstealthTimer then
        unstealthTimer:Cancel()
        unstealthTimer = nil
    end
end

function addon:CancelCastIdleTimer()
    if castIdleTimer then
        castIdleTimer:Cancel()
        castIdleTimer = nil
    end
end

function addon:CancelAllPendingSummons()
    addon:CancelTouchdownTimer()
    addon:CancelDismountTimer()
    addon:CancelUnstealthTimer()
    addon:CancelCastIdleTimer()
end

function addon:StopMountWatcher()
    addon:CancelTouchdownTimer()
    if mountWatcherTicker then
        mountWatcherTicker:Cancel()
        mountWatcherTicker = nil
    end
    wasInFlight = false
end

function addon:StartMountWatcher()
    if mountWatcherTicker or not SummonPetBigginsDB or not SummonPetBigginsDB.summonWhileMounted then
        return
    end

    wasInFlight = addon:IsInFlightActive()
    if wasInFlight and C_PetJournal.GetSummonedPetGUID() then
        addon:Dismiss(1)
    end

    mountWatcherTicker = C_Timer.NewTicker(addon.TICKER_POLL_INTERVAL, function()
        if not IsMounted() or not SummonPetBigginsDB or not SummonPetBigginsDB.summonWhileMounted then
            addon:StopMountWatcher()
            return
        end

        local inFlightNow = addon:IsInFlightActive()
        if inFlightNow then
            wasInFlight = true
            addon:CancelTouchdownTimer()
            if C_PetJournal.GetSummonedPetGUID() then
                addon:Dismiss(1)
            end
            return
        end

        -- If we were in flight and just touched down, delay summon decision by 1.0s
        -- to prevent race conditions when landing and stealthing in one fluid motion!
        if wasInFlight then
            wasInFlight = false
            addon:CancelTouchdownTimer()
            touchdownTimer = C_Timer.After(addon.TOUCHDOWN_DEBOUNCE_DELAY, function()
                touchdownTimer = nil
                if not IsMounted() or not addon:CanSummon() then
                    return
                end
                if not C_PetJournal.GetSummonedPetGUID() then
                    addon:Summon()
                end
            end)
            return
        end

        -- While the 1.0s touchdown timer is running, absolutely NO summons!
        if touchdownTimer then
            return
        end

        -- Grounded mount steady-state check (only when grounded for > 1.0s)
        if not addon:CanSummon() then
            return
        end
        if not C_PetJournal.GetSummonedPetGUID() then
            addon:Summon()
        end
    end)
end

-- Grounded Mount Movement Hook (backup trigger when starting movement on a mount)
function addon:OnMovementStart()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.enabled and SummonPetBigginsDB.summonWhileMounted) then
        return
    end
    if not IsMounted() or addon:IsInFlightActive() or wasInFlight or touchdownTimer then
        return
    end
    if not addon:CanSummon() then
        return
    end
    if C_PetJournal.GetSummonedPetGUID() then
        return
    end

    addon:Summon()
end

function addon:ScheduleDismountSummon()
    addon:StopMountWatcher()
    if addon:ShouldDismissInStealth() then
        addon:Dismiss(1)
        return
    end

    -- Debounced dismount summon; tracked and immediately cancellable by UPDATE_STEALTH
    dismountTimer = C_Timer.After(addon.DISMOUNT_DEBOUNCE_DELAY, function()
        dismountTimer = nil
        if IsMounted() or not addon:CanSummon() then
            return
        end

        if addon:IsInFlightActive() then
            dismountTimer = C_Timer.After(addon.DISMOUNT_DEBOUNCE_DELAY, function()
                dismountTimer = nil
                if not IsMounted() and addon:CanSummon() then
                    addon:Summon()
                end
            end)
            return
        end

        addon:Summon()
    end)
end

function addon:ScheduleUnstealthSummon()
    addon:CancelUnstealthTimer()
    unstealthTimer = C_Timer.After(addon.UNSTEALTH_DEBOUNCE_DELAY, function()
        unstealthTimer = nil
        if addon:IsStealthedActive() or InCombatLockdown() or UnitIsDeadOrGhost("player") then
            return
        end

        if addon:IsPlayerCastingOrChanneling() then
            -- While actively casting or channeling, defer summoning to the post-cast/channel idle handler
            return
        end

        if addon:CanSummon() then
            addon:Summon()
        end
    end)
end

function addon:ScheduleCastIdleSummon()
    addon:CancelCastIdleTimer()

    if addon:IsStealthedActive() or InCombatLockdown() or UnitIsDeadOrGhost("player") or addon:IsMountedBlocked() or addon:ShouldDismissInCurrentInstance() then
        return
    end

    if addon:IsPlayerCastingOrChanneling() then
        return
    end

    if C_PetJournal.GetSummonedPetGUID() then
        return
    end

    castIdleTimer = C_Timer.After(addon.CAST_IDLE_DEBOUNCE_DELAY, function()
        castIdleTimer = nil
        if not addon:CanSummon() then
            return
        end
        if not C_PetJournal.GetSummonedPetGUID() then
            addon:Summon()
        end
    end)
end
