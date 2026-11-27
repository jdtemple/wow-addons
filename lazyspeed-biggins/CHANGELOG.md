# LazySpeed Biggins v4.3.0

### Added
- **Background Opacity Slider:** Added a dedicated 1% step slider (0% - 100%, default 25%) to customize the opacity of the dark container backdrop and depleted status bar tracks. Supports anywhere from fully transparent floating bars (showing only the gold border, active bar fill, and text) to a completely opaque dark plate.
- **New Slash Command:** Added `/lazyspeedb opacity <0-100>` (aliases `/lazyspeedb alpha`, `/lazyspeedb bg`) to configure background opacity directly from chat.

# LazySpeed Biggins v4.2.0

### Added
- **Configurable Bar Spacing:** Added a new Bar Spacing slider (0 - 50 px, default 4 px) to adjust the distance between HUD bars in both vertical and horizontal stacking modes. Allows seamless spacing adjustment to avoid overlap with custom UI skins (such as Clockwork Biggins).
- **New Slash Command:** Added `/lazyspeedb spacing <0-50>` (alias `/lazyspeedb gap`) to adjust bar spacing directly from chat.

### Polish
- **Options Slash Command Footer:** Elevated slash command documentation in the options panel with highlighted Blizzard Gold styling (`/lazyspeedb`) to enhance visual hierarchy and readability across the Biggins Suite.

# LazySpeed Biggins v4.1.1

### Fixed
- **Settings Panel Two-Column Layout:** Reorganized the Blizzard Settings options panel into a clean two-column grid. Visibility and behavioral checkboxes are anchored on the left column, while Stacking Mode, Speed Measurement Units, Bar Dimensions sliders, and Reset Position occupy the right column. This eliminates vertical overflow and prevents controls from bleeding past the bottom frame border.
- **Slash Commands Note Spacing:** Repositioned the slash commands footer note cleanly below the Reset Position button across the entire panel width, preventing text overlap with right-column controls.

# LazySpeed Biggins v4.1.0

### Added
- **Hide Vigor Bar When Full:** Added a new setting to automatically hide the Skyriding Vigor bar when charges are at maximum (e.g. 6/6), collapsing the HUD to the speedometer alone. As soon as Vigor is spent (e.g. on Surge Forward or Skyward Ascent), the Vigor bar smoothly reappears and tracks recharge until full again.
- **Nested Options UI:** Nested the "Hide Vigor Bar When Full" checkbox directly as an indented child option under "Show Skyriding Vigor Bar" in the Blizzard Settings panel, dynamically dimming alongside the glow option when Vigor is disabled.
- **New Slash Command:** Added `/lazyspeedb vigorfull` (alias `/lazyspeedb hidefull`) to quickly toggle the full-charge auto-hide feature from chat.

# LazySpeed Biggins v4.0.0

### Added
- **Skyriding Vigor HUD:** Added a dedicated second telemetry bar tracking 1-6 Surge Forward / Skyward Ascent Vigor charges with smooth fractional recharge progress and live cooldown timers.
- **Accelerated Recharge Aura Glow:** Vigor bar illuminates with an intuitive color-coded aura glow: Blue during *Thrill of the Skies*, Red during *Ground Skimming*, and Violet when both buffs are active. Displays strictly during accelerated recharge with zero glow during normal flight.
- **Dynamic Multi-Bar Stack Layout:** Integrated PerfBiggins-style stacking engine supporting Vertical (default: Speedometer above Vigor bar) and Horizontal (side-by-side) stacking modes.
- **Dynamic Single-Bar Collapse:** Vigor bar displays strictly while mounted in active Skyriding mode; collapses smoothly to a single bar with zero gaps when swimming, grounded, or in steady flight.
- **Unified Dragging:** Dragging either bar moves the entire stack as a single locked unit.
- **New Settings & Slash Commands:** Added Stacking Mode radio controls, Vigor toggle, Glow toggle, and `/lazyspeedb stack [horiz|vert]` and `/lazyspeedb vigor` slash commands.

# LazySpeed Biggins v3.9.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/lazyspeed` and `/lsb` with `/lazyspeedb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/lazyspeedb`.

### Added
- **Help Command & Alias:** Added `/lazyspeedb help` and `/lazyspeedb ?` slash commands with formatted in-game command documentation in chat.

# LazySpeed Biggins v3.8.2

### Changed
- **Compatibility:** Updated for World of Warcraft Retail 12.1.5 and 12.1.7 compatibility.
