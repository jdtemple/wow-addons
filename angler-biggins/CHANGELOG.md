# Angler Biggins v2.0.5

### Fixed
- **Post-Combat Lifejacket Swapping & Unseat Order:** Resolved an issue where auto-equipping the Underlight Angler after combat while holding a secondary rod (such as Sin'dorei Reeler's Rod) attempted to swap the rod directly without unseating first. Because container slots are locked during single-frame cursor swaps, the secondary rod was colliding and causing activation retries. Lifejacket Mode now explicitly unseats any existing rod to bags before seating the Underlight Angler into slot 28.
- **Removed Self-Sustaining Retry Timer:** Removed a recursive deferred timer in `ActivateUnderlightAngler()` that caused repeating activation loops. Cooldown enforcement is now strictly passive.
- **Strict Server Confirmation on Equip Queue:** Updated `StepEquipSlot()` to only mark equipment swaps as complete once `GetInventoryItemID("player", 28)` is confirmed by the server, eliminating transient "Equipped Pole: None" states.

# Angler Biggins v2.0.4

### Fixed
- **Post-Combat Underwater Lifejacket Recovery:** Resolved an issue where engaging in combat in the water while holding a pinned pole prevented Lifejacket Mode from auto-equipping the Underlight Angler after combat ended. Dropping combat (`PLAYER_REGEN_ENABLED`) while in water now automatically clears the manual pinned override and safely waits for combat lockdown to clear before activating the Underlight Angler.
- **Breath Meter Lifejacket Override:** Added an emergency guard on `MIRROR_TIMER_START` ("BREATH") so that if your breath meter begins ticking down while in water, any manual pole override is immediately cleared to auto-equip the Underlight Angler and prevent drowning.
- **Water Exit Transition Listener:** Explicitly registered and handled `MIRROR_TIMER_STOP` alongside `MOUNT_JOURNAL_USABILITY_CHANGED` to ensure responsive state evaluations when leaving the water.

# Angler Biggins v2.0.3

### Fixed
- **Action Bar Rod Toggle Failure:** Resolved an issue where using `/anglerb swap` or the action bar toggle button failed with "Failed to equip pinned pole into fishing slot." The cursor swap logic was executing synchronously without waiting for server acknowledgment, and unseating logic previously hardcoded the Underlight Angler item ID when checking cursor contents. Both manual toggling and automatic activations now route through the unified asynchronous queue engine (`HandleQueue`), ensuring clean, collision-free slot-28 swaps.
- **Surface Tension Aura Detection:** Updated Underlight Angler trait detection to look for the real, definitive "Surface Tension" buff rather than generic cosmetic auras. In modern WoW, ordinary fishing rods grant "Fishing for Attention" (Spell 394009) while the Underlight Angler uniquely grants "Surface Tension".
- **Mining & Profession Gear Auto-Recovery:** When mining or gathering underwater, Blizzard's profession gear temporarily overrides the character model and suppresses fishing auras. Angler Biggins now automatically detects the loss of "Surface Tension" when swimming in water and triggers an instant wake cycle to dismiss mining gear and restore fish form without requiring manual slash commands or leaving the water.
- **Activation Cooldown & Retry Queue:** Added a deferred retry timer to `ActivateUnderlightAngler()` so that gathering channels finishing during the activation cooldown window are never dropped, ensuring 100% reliable wakeups upon gathering completion.
- **Telemetry & Status Display:** Updated the settings panel and `/anglerb status` command to display real-time "Surface Tension Buff" status alongside environment and equipped tool info.

# Angler Biggins v2.0.2

### Fixed
- **Submerged Gathering & Lakebed Unseating:** Resolved an issue where gathering nodes (mining or herbing) while underwater caused fish form to temporarily pause, falsely flagging the Underlight Angler as dormant. This previously triggered an unwanted unseat cycle that failed while channeling, leaving the rod in bags.
- **Casting & Channeling Protection (`IsPlayerBusy`):** Added strict state guards preventing automatic equipment unseating and swaps while the player is actively casting or channeling (e.g. mining, herbing, or crafting).
- **Session Awakening Persistence:** Once the Underlight Angler is awakened in slot 28, it remains marked awake for the session while slotted, eliminating needless unseat/reseat loops when feet touch lakebeds.
- **Spellcast Completion Reactivity:** Added listeners for `UNIT_SPELLCAST_STOP` and `UNIT_SPELLCAST_CHANNEL_STOP` to cleanly evaluate water state and re-equip fishing gear immediately upon finishing a gather.

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
