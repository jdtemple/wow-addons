# Perf Biggins v1.7.1 (2026-11-27)

### Architecture Modularization & Settings Decoupling
- **Modular File Structure:**
  - Extracted shared constants, defaults, format strings, and color scales into `Core/Constants.lua`.
  - Extracted status bars, container frames, unified drag handlers, and dynamic layout engine into `Modules/HUD.lua`.
  - Extracted 10 FPS telemetry update loop and dynamic FPS ceiling evaluation into `Core/Telemetry.lua`.
  - Extracted Blizzard Settings options canvas and two-column control grid into `Core/Options.lua`.
  - Streamlined `PerfBiggins.lua` as lifecycle event orchestrator and slash command router.
- **Suite-Wide Architectural Consistency:**
  - Standardized load order: `LibBigginsSuite.lua` -> `Core\*.lua` -> `Modules\*.lua` -> `<AddonName>.lua`.
  - Implemented explicit `addon:UpdateInteractivity()` to support runtime `/perfb lock` toggle.

# Perf Biggins v1.7.0

### Added
- **Background Opacity Slider:** Added a dedicated 1% step slider (0% - 100%, default 25%) to customize the opacity of the dark container backdrop and depleted status bar tracks. Supports anywhere from fully transparent floating bars (showing only the gold border and active bar fill) to a completely opaque dark plate.
- **New Slash Command:** Added `/perfb opacity <0-100>` (aliases `/perfb alpha`, `/perfb bg`) to configure background opacity directly from chat.

# Perf Biggins v1.6.0

### Added
- **Configurable Bar Spacing:** Added a new Bar Spacing slider (0 - 50 px, default 4 px) to adjust the distance between telemetry bars in both vertical and horizontal stacking modes. Allows seamless spacing adjustment to avoid overlap with custom UI skins (such as Clockwork Biggins).
- **New Slash Command:** Added `/perfb spacing <0-50>` (alias `/perfb gap`) to adjust bar spacing directly from chat.

### Changed
- **Settings Panel Two-Column Layout:** Reorganized the Blizzard Settings options panel into a clean two-column grid. Visibility and behavior checkboxes are anchored on the left column, while Stacking Mode, Bar Dimensions sliders, Bar Spacing, and Reset Position occupy the right column. Eliminates vertical overflow and matches the LazySpeed Biggins options layout.

### Polish
- **Options Slash Command Footer:** Elevated slash command documentation in the options panel with highlighted Blizzard Gold styling (`/perfb`) to enhance visual hierarchy and readability across the Biggins Suite.

# Perf Biggins v1.5.2

### Fixed
- **TOC Keybindings Optimization:** Removed `Bindings.xml` from the `.toc` manifest. The game client automatically loads `Bindings.xml` natively for keybindings; removing it from the `.toc` eliminates FrameXML parse warnings.

# Perf Biggins v1.5.1

### Fixed
- **Settings Keybinding Category Label:** Standardized the Blizzard keybindings category and header label to "Perf Biggins" with proper word spacing.

# Perf Biggins v1.5.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/perf` and `/pb` with `/perfb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/perfb`.

### Added
- **Help Command & Alias:** Added `/perfb help` and `/perfb ?` slash commands with formatted in-game command documentation in chat.

# Perf Biggins v1.4.0

### Added
- **Configurable Stacking Mode:** Added support for horizontal vs. vertical telemetry bar layouts.
  - **Vertical (Default):** Retains the classic nameplate stack where bars are neatly stacked top-to-bottom.
  - **Horizontal:** Places active telemetry bars side-by-side in a sleek, streamlined horizontal ribbon.
  - **Interactive Ribbon Dragging:** Dragging any bar in horizontal mode dynamically moves the entire ribbon as a unified locked unit.
  - **Slash Command:** Toggle stacking modes on the fly using `/pb stack` or `/perf stack` (or specify `/pb stack vertical` / `/pb stack horizontal`).
  - **Modern Settings UI:** Added dedicated Stacking Mode radio buttons in **Options -> AddOns -> Biggins AddOns -> Perf**.
