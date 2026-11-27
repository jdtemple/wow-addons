# AutoJoin Biggins v1.4.2 (2026-11-27)

### Architecture Modularization & Settings Decoupling
- **Modular File Structure:**
  - Extracted name normalization, Guild membership verification, Character Friends list, Battle.net checks, and AFK safety gating into `Core/Whitelist.lua`.
  - Extracted party invite handling, popup suppression, and automatic chat channel switching into `Modules/Invite.lua`.
  - Extracted Blizzard Settings options canvas and control toggles into `Core/Options.lua`.
  - Streamlined `AutoJoinBiggins.lua` as lifecycle event orchestrator and slash command router.
- **Suite-Wide Architectural Consistency:**
  - Standardized load order: `LibBigginsSuite.lua` -> `Core\*.lua` -> `Modules\*.lua` -> `<AddonName>.lua`.

# AutoJoin Biggins v1.4.1

### Polish
- **Options Slash Command Footer:** Elevated slash command documentation in the options panel with highlighted Blizzard Gold styling (`/autojoinb`) to enhance visual hierarchy and readability across the Biggins Suite.

# AutoJoin Biggins v1.4.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/autojoin` and `/aj` with `/autojoinb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/autojoinb`.

### Added
- **Help Command & Alias:** Added `/autojoinb help` and `/autojoinb ?` slash commands with formatted in-game command documentation in chat.

# AutoJoin Biggins v1.3.2

### Changed
- **Compatibility:** Updated for World of Warcraft Retail 12.1.5 and 12.1.7 compatibility.
