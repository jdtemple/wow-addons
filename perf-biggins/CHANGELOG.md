# Changelog - Perf Biggins

All notable changes to **Perf Biggins** will be documented in this file.

---

## [1.3.0] - 2026-10-31

### Added
- **Dynamic FPS Scale Ceiling & Auto-Detection:** The FPS status bar now dynamically scales its 100% full capacity based on the user's active hardware or graphics settings rather than a hardcoded 144 FPS limit.
  - **Foreground FPS CVar Detection:** Automatically reads `GetCVar("maxFPS")` (when `useMaxFPS` is active) and locks the bar ceiling strictly to the user's configured hardware limit (e.g. 240 FPS / 244 FPS on high-refresh monitors).
  - **Adaptive Floor for Uncapped Setups:** When Max Foreground FPS is disabled, the system operates in true uncapped mode: it begins at a clean 60 FPS baseline for standard 60Hz displays and automatically expands upward to match actual observed performance (120, 144, 240+ FPS) with zero ceiling clipping.
- **Event-Driven Rescaling (`CVAR_UPDATE`):** Listens for real-time graphics setting adjustments in World of Warcraft; toggling or sliding Max Foreground FPS instantly rescales the bar with zero `/reload` required.
- **Float Rounding & Color Boundary Polish:** Adjusted color threshold boundaries to 59.5 FPS (Green) and 29.5 FPS (Yellow) so floating-point rounding display values (such as `60.0 FPS` and `30.0 FPS`) consistently map to their intended color brackets.
- **Transparent Options UI Controls:** Added an `[x] Auto-Detect Max FPS (Recommended)` checkbox and an `FPS Bar Max Scale` slider (60 - 360 FPS).
  - When Auto-Detect is enabled, the slider is disabled (grayed out) but visually tracks and displays the active detected ceiling (e.g., `244 FPS (Auto)`).
  - When Auto-Detect is disabled, the slider becomes fully interactive for manual fixed refresh rate calibration.
- **Enhanced Status Diagnostics:** `/pb status` now outputs active auto-detection status and current numeric FPS scale ceiling.

---

## [1.2.0] - 2026-10-23

### Added
- **Native Keybinding Support:** Registered action binding (`PERFBIGGINS_TOGGLE`) in `Bindings.xml` under `Keybindings -> AddOns -> Perf Biggins` to quickly toggle the telemetry HUD on/off.
- **Unified Suite Navigation:** Registered as a subcategory under the unified `Biggins AddOns` parent category in the modern Blizzard Settings menu.
- **Suite Overview Dashboard Integration:** Accessible via the new `/biggins` slash command, featuring live suite module status detection and cross-navigation.

### Changed
- **Patch 12.1.7 Compatibility:** Updated Interface version to `120107` for full compatibility with World of Warcraft: Midnight Patch 12.1.7.

---

## [1.1.0] - 2026-10-22

### Added
- **Split-Bar Nameplate Stack Aesthetic:** Refactored HUD rendering from a single monolithic rectangular container into a sleek stack of 3 individual nameplate-style status bar containers with an air gap between them (`gap = 4`), styled with dark slate tooltip backdrops and Blizzard Metallic Gold borders matching LazySpeed.
- **Unified Single-Unit Stack Dragging:** Anchored all bar containers to a master parent frame so dragging any visible bar moves the entire stack as a single locked unit.
- **Modern Canvas Options UI:** Migrated options panel to Blizzard's modern Canvas layout (`Settings.RegisterCanvasLayoutCategory`) with top-right `[ Defaults ]` button, master toggle, lock toggle, granular width/height sliders, and position reset button.
- **Slash Commands:** Added `/perf toggle` and `/perf reset` command support.

---

## [1.0.0] - 2026-10-21

### Added
- Initial release of **Perf Biggins**.
- Tri-bar performance HUD featuring stacked status bars for **FPS**, **World Latency**, and **Home Latency**.
- Centered numeric and unit telemetry overlays with high-contrast text dropshadows.
- Dynamic color-coding for FPS (Green &ge; 60, Yellow 30-59, Red < 30) and Latency (Green &le; 50ms, Yellow 51-100ms, Orange 101-200ms, Red > 200ms).
- Dynamic layout engine that allows individual bars to be hidden with automatic re-anchoring and seamless container height adjustment.
- High-performance 20 FPS (0.05s) update loop with dirty tracking and zero-allocation native C++ formatting (`FontString:SetFormattedText`).
- Classic Blizzard gold border and dark slate tooltip backdrop matching the LazySpeed visual identity.
- Movable container frame with Left-Click dragging and persistent coordinate storage in SavedVariables (`PerfBigginsDB`).
- Modern Blizzard Settings panel integration (`Settings.RegisterAddOnCategory`) with width and height sliders, visibility toggles, lock switch, and position reset.
- Combat visibility killswitch that detaches the `OnUpdate` script during encounters for 0.00ms CPU footprint.
- Comprehensive `/perf` and `/pb` slash command suite.
