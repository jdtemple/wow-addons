# Changelog - SummonPet Biggins

## [1.2.0] - 2026-10-23

### Added
- **Unified Suite Navigation:** Registered as a subcategory under the unified `Biggins AddOns` parent category in the modern Blizzard Settings menu.
- **Suite Overview Dashboard Integration:** Accessible via the new `/biggins` slash command, featuring live suite module status detection and cross-navigation.

### Changed
- **Patch 12.1.7 Compatibility:** Updated Interface version to `120107` for full compatibility with World of Warcraft: Midnight Patch 12.1.7.

---

## [1.1.0] - 2026-10-22

### Added
- **Modern Canvas Options UI:** Transitioned settings interface to Blizzard's modern Canvas layout (`Settings.RegisterCanvasLayoutCategory`) to display multi-tier configuration cleanly without text truncation or awkward column wrapping.
- **Top-Right Defaults Button:** Standardized top-right `[ Defaults ]` button matching Blizzard UI conventions to easily reset all options and companion selections back to factory defaults.
- **Master Enable Toggle & Cascading Disables:** Added top-level master toggle to enable or disable the pet summoning engine. Unchecking master enable dynamically grays out and disables all child options throughout the full hierarchy (Raids, Mythic+, Regular Dungeons, Delves & Labyrinths, Stealth auto-dismiss, and mounted summoning).

---

## [1.0.2] - 2026-10-14

### Added
- **Granular Instance Auto-Dismiss:** Replaced the single M+ toggle with a master "Auto-Dismiss in Instances" setting and individual sub-toggles ordered top-down by challenge level:
  - Raids
  - Mythic+ Dungeons
  - Regular Dungeons
  - Delves & Labyrinths
- **Touchdown Watcher:** Added contextual flight watcher for grounded mount summoning so pets summon seamlessly upon landing from flight while continuously running.

### Changed
- **Options Panel Title:** Removed version number string from settings panel for a cleaner, cohesive UI presentation.

### Fixed
- **Mounted Pet Dismissal:** Companions are now reliably dismissed upon mounting when "Summon Companion While Mounted" is disabled, and re-summoned automatically upon dismounting.

## [1.0.1] - 2026-10-14

### Added
- **Mounted Summoning Option:** Added "Summon Companion While Mounted (Ground Only)" setting and `/spb mount` slash command. When enabled, companion pets summon to run alongside ground mounts, and automatically summon when touching down and moving on a flying mount.

### Fixed
- **Stealth Auto-Dismiss Toggle:** Fixed an issue where disabling "Auto-Dismiss in Stealth" prevented pet summoning when exiting stealth.
- **Immediate State Refresh:** Toggling stealth or M+ auto-dismiss in the settings panel now immediately updates the companion pet's active state.

## [1.0.0] - 2026-10-13

### Initial Release
- **Event-Driven Architecture:** Replaced movement key hooking with native events (`PLAYER_MOUNT_DISPLAY_CHANGED`, `UPDATE_STEALTH`, `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`).
- **Native Keybinding Support:** Added `Bindings.xml` integration under `Game Menu -> Keybindings -> AddOns -> SummonPetBiggins`.
- **Unified Settings Panel:** Added native canvas category in `Game Menu -> Options -> AddOns -> SummonPetBiggins`.
- **One-Click Pinning:** Added `/spb pin` and `[ Use Currently Summoned Pet ]` button to easily pin a specific companion.
- **Three Modes:** Added support for Random Favorites, Completely Random, and Specific Pinned Pet.
- **Auto-Dismiss & Debounce:** Added automatic pet dismissal in Stealth and Mythic+ dungeons with a debounced retry loop to prevent race conditions during rapid stealthing or dismounting.
- **Fluid Dismount Handling:** Integrated `PLAYER_MOUNT_DISPLAY_CHANGED` and falling state checks so pets summon reliably when landing and running in one fluid motion.
- **Zero-Bloat Standalone Lua:** Completely removed Ace3 library dependencies for < 20 KB total memory usage.
