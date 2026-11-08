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
