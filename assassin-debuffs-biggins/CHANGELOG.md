# Changelog - Assassin Debuffs Biggins

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-10-11

### Fixed
* **Debuff Refresh & Frame Pool Recycling**: Eliminated the destructive `OnHide` script hook that was wiping aura keys during Blizzard's internal `auraItemFramePool:ReleaseAll()` updates, ensuring halos persist seamlessly through debuff refreshes and combat cycles.
* **Modern Retail Container Support**: Added `unitFrame.AurasFrame` support to hook Blizzard's primary nameplate aura frame pools on modern retail (Dragonflight / The War Within 11.0+).
* **Immediate Active Aura Evaluation**: When hooking newly acquired or existing frames in the aura pool, active debuffs are immediately evaluated and styled without requiring re-application or retargeting.
* **Target Swap Halo Refresh**: Registered `PLAYER_TARGET_CHANGED` to ensure active halos are immediately verified and refreshed upon target acquisition and switching.
* **Outward Halo Reach**: Projected top and bottom halos beyond Blizzard's default `IconOverlay` drop shadow border into open air.
* **Target Opener Aura Resolution**: Fixed player source resolution in `ResolveSpellKey` to prevent false rejections when opening on target dummies or newly engaged enemies where `sourceUnit` is temporarily unassigned.
* **Locale Auto-Detection**: Added startup localization initialization via `C_Spell.GetSpellName` so all tracked debuffs match accurately across any client language.
* **TOC Dependency**: Added `## Dependencies: Blizzard_NamePlates` to ensure Blizzard's nameplate mixins and templates are always fully loaded prior to addon initialization.

### Added
* **Collision-Free Top & Bottom Halos**: Locked halos down exclusively to outward-radiating bars positioned above and below debuff icons, completely eliminating horizontal collision between neighboring icons while keeping Blizzard's layout engine 100% untouched.
* **Halo Position Selector**: Added in-game options dropdown to choose between `Top & Bottom` (default), `Top Only`, or `Bottom Only`.
* **Improved Garrote Support**: Added spell IDs and localized aura names for Improved Garrote (381623, 381632, 392401) and Garrote - Silence (1330), seamlessly mapping them to the Garrote color palette.
* **Expanded Thickness Slider**: Increased thickness slider range to 1 - 8 px (default: 4 px).

---

## [1.0.0] - 2026-10-10

### Initial Release
* **Built-in Auto-Scaling Architecture**: Halo borders dynamically stretch and conform to the game's debuff dimensions, automatically scaling spacing and halo thickness proportionally with changes to the game's icon size slider.
* **Horizontal Debuff Spacing**: Added configurable spacing slider (0px to 12px, default 4px) to separate nameplate debuff buttons.
* **Soft Gradient Halo Borders**: Implemented directional gradient borders that fade smoothly toward outer edges for 5 core debuffs:
  * **Garrote** (Default: Amber / Orange `#FF9900`)
  * **Rupture** (Default: Crimson / Red `#FF2020`)
  * **Deathstalker's Mark** (Default: Vivid Purple `#A335EE`)
  * **Kingsbane** (Default: Toxic / Neon Green `#00FF66`)
  * **Deathmark** (Default: Electric Cyan `#00D4FF`)
* **Glow Thickness Slider**: Added configurable halo border thickness slider (1px to 8px, default 3px).
* **Interactive Color Pickers**: Added color swatches for all 5 tracked debuffs supporting modern `ColorPickerFrame:SetupColorPickerAndShow`.
* **Zero-Allocation Architecture**: Pre-cached `ColorMixin` pointers and lazy-allocated border textures on debuff frames.
* **Settings & Slash Command**: Integrated with native Blizzard Settings panel and added `/adb` and `/assassindebuffs` slash commands.
* **Zero CVar Taint**: Runs 100% in RAM with zero `SetCVar` calls.
