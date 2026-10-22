# Changelog - Perf Biggins

All notable changes to **Perf Biggins** will be documented in this file.

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
