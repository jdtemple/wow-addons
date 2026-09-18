# Changelog - LazySpeed Biggins

All notable changes to LazySpeed Biggins will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.6.1] - 2026-09-17

### Fixed
- **Mythic+ Client Freeze & Error Cascade Hotfix:** Resolved an issue where running Mythic+ dungeons with "Show While on Ground" enabled caused severe game client freezing and micro-stuttering due to Patch 12.0+ Secret Value restrictions.
  - **Secret Value Gating:** Added `issecretvalue()` checks across all velocity queries (`GetUnitSpeed`, `GetGlidingInfo`, `IsFlying`, `IsSwimming`). In Patch 12.0+ and Midnight, velocity data in Mythic+ dungeons and challenge modes is flagged as secret; performing comparisons or arithmetic on secret values in tainted code causes fatal Lua errors. The engine now detects secret values immediately and cleanly enters dormant state.
  - **Defensive Execution Wrapper (`pcall`):** Wrapped the 20 FPS high-speed update loop in a protected call failsafe (`pcall`). If any unhandled taint violation or restricted API exception occurs, the engine detaches immediately, eliminating any risk of 20 FPS error cascades or frame drops.
  - **Challenge Mode & Instance State Tracking:** Registered `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_RESET`, and `ZONE_CHANGED_NEW_AREA` events to cleanly shut down during active keystones and automatically evaluate restoration upon completion or zoning.
  - **Passive Poll Loop Recovery:** Updated the low-frequency 4 Hz passive watcher to safely resume the speedometer when leaving combat or restricted instances if "Show While on Ground" is enabled.

---

## [3.6.0] - 2026-09-17

### Added
- **Percentage Speed Mode (`%`):** Added a 4th speed measurement unit that displays movement velocity as a percentage of standard running speed (7.0 y/s = 100%).
  - Formatted as clean integer percentages (`%.0f%%`) to avoid visual jitter during rapid acceleration.
  - Calibrated maximum flight capacity (`MAX_CAP_FLIGHT = 84.0` y/s) to accurately track Skyriding terminal velocity dives up to 1,200%.
- **Custom Pixel Sizing Sliders:** Added granular width and height sliders to the native Blizzard Settings panel (`/lazyspeed settings`).
  - **Bar Width:** 100px - 300px (1px granular step, default: 180px).
  - **Bar Height:** 14px - 36px (1px granular step, default: 22px).
- **Dynamic Proportional Font Scaling:** Typography dynamically recalculates font size relative to bar height (`math.floor(height * 0.55)`, clamped between 9pt and 20pt) so text never clips or overflows at custom aspect ratios.
- **Reset to Defaults:** Added a native Blizzard Settings button (`Reset to Defaults`) and chat slash command (`/lazyspeed defaults`) to restore all checkboxes, unit modes, and bar dimensions back to defaults without moving custom screen placement.

### Changed
- **Documentation Refactor:** Stripped all emojis across project READMEs and CurseForge descriptions for clean, professional plain-text rendering.
- **Strict ASCII Compliance:** Standardized all dashes, hyphens, and arrow transitions to ASCII-only characters.

---

## [3.5.0] - 2026-09-17

### Added
- Initial implementation of Percentage mode mathematical multipliers and Skyriding terminal velocity calibration.

---

## [3.4.0] - 2026-09-09

### Added
- **Nameplate HUD Aesthetic:** Redesigned status bar into a compact 180px x 20px nameplate-style HUD with high-contrast centered text overlay (`12pt OUTLINE`) and Blizzard Metallic Gold styling.
- **Modular Visibility Checkboxes:** Added individual triggers for Skyriding/Flight, Swimming, Ground movement, and In-Combat hide killswitch.
- **Zero-Allocation Pipeline:** Replaced dynamic string concatenations in update loops with pre-cached static format string pointers via `FontString:SetFormattedText()`, eliminating Lua garbage generation.
- **Engine Script Detachment:** Unhooked `OnUpdate` script (`SetScript("OnUpdate", nil)`) when dormant or grounded to achieve 0.00ms idle CPU usage.
- **Stationary Dirty Check:** Skips GPU texture redraws and text reformatting while stationary.
