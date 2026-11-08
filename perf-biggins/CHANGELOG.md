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
