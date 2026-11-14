# Angler Biggins v2.0.1

### Fixed
- **Settings Panel Subtitle Layout:** Added explicit width bounding and word wrapping to the options panel subtitle to prevent long descriptive text from overflowing into the suite logo icon in the top right.

# Angler Biggins v2.0.0

### Major Release Overview
- **Dual-Rod Fishing Suite:** Upgraded Angler Biggins from a standalone Underlight Angler utility into a complete dual-rod fishing suite. Pin any high-stat primary fishing rod (such as an engineered or expansion-specific rod) and seamlessly toggle between it and the Underlight Angler.

### Added
- **Dual-Pole Pinning & Action Bar Swapping:** Added support for pinning a secondary high-stat fishing pole and toggling between it and the Underlight Angler using a dynamic action bar button.
- **Dedicated Pin Command & Settings:** Equip your desired secondary rod and use `/anglerb pin` or click [ Pin Currently Equipped Pole ] in Options -> AddOns -> Biggins AddOns -> Angler.
- **Action Bar Toggle Macro:** Added [ Put Swap Button on Cursor ] in options (and `/anglerb button`) to place a one-click toggle macro directly onto your action bars. The macro dynamically flips its icon and tooltip to show whichever pole will be equipped on the next click.
- **Manual Swap Command:** Added `/anglerb swap` to toggle between Underlight Angler and your pinned pole via slash command or keybinding.
- **Lifejacket Mode Option:** Added an explicit toggle in settings (and `/anglerb lifejacket`) to control whether the addon automatically equips the Underlight Angler when entering water while holding a secondary rod (enabled by default).
- **Native Slot 28 Container Swapping:** Replaced fragile Blizzard API calls with native 1-to-1 container-to-inventory equipment swapping (`EquipItemToFishingSlot`) to ensure fishing tools are never abandoned in bags during unseat/reseat handshakes.
- **Dungeon & Raid Setting Clarification:** Updated the in-game settings checkbox to "Enable in Dungeons & Raids (Mythic+ Excluded)" with an expanded tooltip clarifying Blizzard's equipment lockdown during timed keystones.

### Fixed
- **Cosmetic Fishing Aura False-Positive:** Resolved a bug where casting with any third-party or vendor fishing pole applied the "Fishing for Attention" cosmetic buff (Spell ID 394009), causing `IsUnderlightAwake()` to falsely flag the Underlight Angler as active while sitting unequipped in bags. Underlight Angler slot verification is now strictly enforced before aura evaluation.
- **Action Bar Macro Execution:** Updated the action bar macro to execute `/anglerb swap` directly rather than through insecure `/click` frames, ensuring reliable cross-client execution in Dragonflight and The War Within.
- **Header Font Glyph Display:** Replaced non-ASCII arrow characters in options headers with standard ASCII to prevent missing-glyph boxes (`[]`) in the game client font.

# Angler Biggins v1.1.2

### Fixed
- **Mythic+ Challenge Mode Suppression:** Added challenge mode and difficulty guards (`C_ChallengeMode.IsChallengeModeActive()` and difficulty ID 8) to suppress automatic fishing tool unseating and reseating during timed Mythic+ runs. This prevents equipment lockdown chatter and gear swap sounds caused by Blizzard blocking item modifications during active keys, while preserving automatic fish form and water walking in raids and open-world water.

# Angler Biggins v1.1.1

### Fixed
- **Mounted Water Entry Stutter:** Added mount state suppression guards (`IsMounted()`). Entering water or skimming water surfaces while mounted previously triggered rapid activation queue cycles because mounts naturally suppress the Underlight Angler fish form aura, causing micro-stutters and unnecessary equipment unseating.

# Angler Biggins v1.1.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/angb`, `/angler`, `/anglerbiggins`, and `/ab` with `/anglerb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/anglerb`.

### Added
- **Help Command & Alias:** Added `/anglerb help` and `/anglerb ?` slash commands with formatted in-game command documentation in chat.

# Angler Biggins v1.0.1

### Changed
- **Aura Synchronization:** Refined dual-buff state detection (`394009` and `201944`) with instant `UNIT_AURA` player event reactivity for seamless re-activation if buffs are canceled.
- **Manual Control:** Added `/angb wake` and `/angb reset` slash commands to force manual wake cycles on demand.
- **Standalone Release:** Streamlined project metadata and package documentation for standalone release.

# Angler Biggins v1.0.0

### Added
- **Initial Release:** Complete Underlight Angler automation for World of Warcraft Retail (The War Within / Midnight).
- **Zero Bag Juggling:** Directly integrates with Fishing Profession Tool slot 28 (and main hand weapon slot 16).
- **Dragonflight Passive-Slot Wakeup:** Resolves Blizzard's dormant profession equipment trait bug cleanly when entering water.
- **Instance & Delve Resilience:** Fully supported across Dungeons, Raids, and underwater Delves without gear swapping loops.
- **Persistent Water Walking:** Never strips the rod on dry land or water surface, allowing uninterrupted water walking and fishing on water surfaces.
- **Modern Blizzard Canvas Settings:** Options -> AddOns -> Biggins AddOns -> Angler with master enable toggle, instance controls, and live telemetry diagnostics.
