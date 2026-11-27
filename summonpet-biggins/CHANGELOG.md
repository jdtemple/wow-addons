# SummonPet Biggins v1.5.5 (2026-11-27)

### Architecture Modularization & Settings Decoupling
- **Modular File Structure:**
  - Extracted shared defaults, grace period timing constants, and state guards into `Core/Constants.lua`.
  - Extracted companion summoning, debounced safe dismissal, pet pinning, and journal search into `Core/Engine.lua`.
  - Extracted mount touchdown watcher ticker, debounce timers, and movement hooks into `Modules/Watcher.lua`.
  - Extracted Blizzard Settings options canvas and control toggles into `Core/Options.lua`.
  - Streamlined `SummonPetBiggins.lua` as lifecycle event orchestrator and slash command router.
- **Suite-Wide Architectural Consistency:**
  - Standardized load order: `LibBigginsSuite.lua` -> `Core\*.lua` -> `Modules\*.lua` -> `<AddonName>.lua`.

# SummonPet Biggins v1.5.4

### Changed
- **Mounted Summoning Stealth Warning:** Added an explicit warning to the "Summon Companion While Mounted (Ground Only)" setting tooltip informing users that this setting can disrupt stealth abilities when stealth is used immediately upon landing. The option remains disabled by default for maximum combat stability.

# SummonPet Biggins v1.5.3

### Polish
- **Options Slash Command Footer:** Elevated slash command documentation in the options panel with highlighted Blizzard Gold styling (`/summonpetb`) to enhance visual hierarchy and readability across the Biggins Suite.

# SummonPet Biggins v1.5.2

### Fixed
- **TOC Keybindings Optimization:** Removed `Bindings.xml` from the `.toc` manifest. The game client automatically loads `Bindings.xml` natively for keybindings; removing it from the `.toc` eliminates FrameXML parse warnings.

# SummonPet Biggins v1.5.1

### Fixed
- **Settings Keybinding Category Label:** Standardized the Blizzard keybindings category and header label to "SummonPet Biggins" with proper word spacing.

# SummonPet Biggins v1.5.0

### Fixed
- **Chained Spellcast and Channeling Race Conditions:** Eliminated pet summoning interruptions during rapid chained casts (e.g. repeated Fishing casts after breaking stealth). Replaced the periodic 1.0s unstealth polling loop with native, player-filtered spellcast events (`UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_CHANNEL_STOP`). Any active cast or channel immediately suppresses summoning, and completing a cast or channel engages an event-driven 1.5s idle debounce (`CAST_IDLE_DEBOUNCE_DELAY`). Chained casts seamlessly reset the timer before a pet can be summoned, ensuring subsequent casts are never clipped.

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
