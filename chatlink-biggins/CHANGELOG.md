# ChatLink Biggins v1.2.2 (2026-11-27)

### Architecture Modularization & Settings Decoupling
- **Modular File Structure:**
  - Extracted URL formatting, single-pattern isolation, sender GUID caching, and chat event filters into `Core/Links.lua`.
  - Extracted draggable Blizzard Factory copy dialog and position persistence into `Modules/Dialog.lua`.
  - Extracted player name hover tooltips, unit token resolution, and chat frame hooks into `Modules/Tooltips.lua`.
  - Extracted Blizzard Settings options canvas and controls into `Core/Options.lua`.
  - Streamlined `ChatLinkBiggins.lua` as lifecycle event orchestrator and slash command router.
- **Suite-Wide Architectural Consistency:**
  - Standardized load order: `LibBigginsSuite.lua` -> `Core\*.lua` -> `Modules\*.lua` -> `<AddonName>.lua`.

# ChatLink Biggins v1.2.1

### Polish
- **Options Slash Command Footer:** Elevated slash command documentation in the options panel with highlighted Blizzard Gold styling (`/chatlinkb`) to enhance visual hierarchy and readability across the Biggins Suite.

# ChatLink Biggins v1.2.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/chatlink` and `/clb` with `/chatlinkb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/chatlinkb`.

### Added
- **Help Command & Alias:** Added `/chatlinkb help` and `/chatlinkb ?` slash commands with formatted in-game command documentation in chat.

# ChatLink Biggins v1.1.2

### Changed
- **Compatibility:** Updated for World of Warcraft Retail 12.1.5 and 12.1.7 compatibility.
