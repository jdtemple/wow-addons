# SummonPet Biggins v1.4.4

### Changed
- **Tuned Debounce Timers:** Reduced `DISMOUNT_DEBOUNCE_DELAY` and `TOUCHDOWN_DEBOUNCE_DELAY` from 2.0s down to a responsive, uniform 1.0s. This cuts pet summon delay in half upon dismounting or touching down on foot, while preserving a safe 1.0s buffer to protect concurrent casts, gathering channels (mining/herbalism), and defensive buffs without risking race conditions.

# SummonPet Biggins v1.4.3

### Fixed
- **Grounded Mount Jump Flickering:** Removed `IsFalling()` from the active flight detection check (`IsInFlightActive()`). Jumping on flat ground with a Skyriding or ground mount previously triggered the flight dismissal cycle because WoW's physics engine temporarily flags jump arcs as falling, causing companion pets to despawn mid-jump and reappear seconds later. The addon now exclusively relies on genuine flight state (`isGliding == true` or `IsFlying() == true`).

# SummonPet Biggins v1.4.2

### Fixed
- **In-Flight Pet Dismissal & Stealth Protection:** Companions are now actively dismissed upon taking flight in Skyriding or steady flight (`IsInFlightActive()`). Previously, pets remained registered as active in the journal while airborne, causing `autoDismissInStealth` to fire a pet dismissal action (`C_PetJournal.SummonPetByGUID`) upon landing and stealthing simultaneously, which Blizzard's spellcast engine treated as an active player action that broke Stealth. Dismissing upon takeoff ensures 0 active pets exist when touching down, allowing seamless landing-stealth dismounts with zero stealth interruption.

# SummonPet Biggins v1.4.1

### Fixed
- **Unstealth Cast Interruption:** Added a snappy 1.0s debounced grace period (`UNSTEALTH_DEBOUNCE_DELAY = 1.0s`) and active cast/channel guards when breaking stealth. Companion pet auto-summoning will no longer interrupt active channels (such as Fishing) or spellcasts initiated from stealth.

# SummonPet Biggins v1.4.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/togglepet` and `/spb` with `/summonpetb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/summonpetb`.
- **Aligned Slash Command Behavior:** The bare `/summonpetb` command now opens the settings panel in the game menu (aligning with all other addons in the Biggins suite), while `/summonpetb toggle` toggles companion auto-summoning on or off.

### Added
- **Help Command & Alias:** Added `/summonpetb help` and `/summonpetb ?` slash commands with formatted in-game command documentation in chat.

# SummonPet Biggins v1.3.0

### Added
- **Named Companion Pinning:** `/spb pin <pet-name>` now allows pinning and summoning a specific companion directly by custom nickname or species name. If another pet is currently summoned, it will be automatically swapped to the requested pet.
