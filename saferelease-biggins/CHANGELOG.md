# SafeRelease Biggins v1.1.2 (2026-11-27)

### Architecture Modularization & Settings Decoupling
- **Modular File Structure:**
  - Extracted configuration defaults, instance scope evaluations, modifier key logic, and raid wipe detection into `Core/State.lua`.
  - Extracted click-interception overlay button, countdown timer, modifier bypass, and StaticPopup hooks into `Modules/Overlay.lua`.
  - Extracted Blizzard Settings options canvas and control toggles into `Core/Options.lua`.
  - Streamlined `SafeReleaseBiggins.lua` as lifecycle event orchestrator and slash command router.
- **Suite-Wide Architectural Consistency:**
  - Standardized load order: `LibBigginsSuite.lua` -> `Core\*.lua` -> `Modules\*.lua` -> `<AddonName>.lua`.

# SafeRelease Biggins v1.1.1

### Polish
- **Options Slash Command Footer:** Elevated slash command documentation in the options panel with highlighted Blizzard Gold styling (`/safereleaseb`) to enhance visual hierarchy and readability across the Biggins Suite.

# SafeRelease Biggins v1.1.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/saferelease` and `/srb` with `/safereleaseb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/safereleaseb`.

### Added
- **Help Command & Alias:** Added `/safereleaseb help` and `/safereleaseb ?` slash commands with formatted in-game command documentation in chat.

# SafeRelease Biggins v1.0.2

### Changed
- **Compatibility:** Updated for World of Warcraft Retail 12.1.5 and 12.1.7 compatibility.
