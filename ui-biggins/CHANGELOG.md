# UI Biggins Changelog

## v1.2.0 (2026-11-27)

### Global Typography & Modern Font Replacement
* **Global Font Replacement Engine (`Modules/Fonts.lua`):**
  * Seamlessly swaps core Blizzard UI typefaces across standard interface text, system labels, numeric cooldown counts, tooltips, quests, chat, and nameplates.
  * Preserves native Blizzard font scaling, outlines, and shadow offsets for crisp rendering without layout distortion.
  * Extensible drop-in architecture: easily drop additional `.ttf` font files into `Fonts/` and register them with a single line of Lua.
* **Open-Source Font Bundling:**
  * Sourced and bundled Share Tech (Carrois Apostrophe / SIL Open Font License 1.1).
* Sourced and bundled Oxanium (Severin Meyer / SIL Open Font License 1.1) featuring chamfered geometric glyphs and baked dotted zeros.
* Sourced and bundled Roboto (Google Fonts / Apache License 2.0).
  * Sourced and bundled Fira Sans Medium (Google Fonts / SIL Open Font License 1.1) for technical precision and coding aesthetic.
  * Included `Fonts/LICENSE-FONTS.md` citing upstream authors, licenses, and repositories.
* **Blizzard Settings Integration:**
  * Added a dedicated "Typography & Fonts" section with modern `WowStyle1DropdownTemplate` dropdown selector to easily switch between Blizzard Default and Roboto.
  * Fully integrated into the "Reset Defaults" action and UI reload warning system.
  * Added `/uibiggins font <default|roboto>` chat command for direct typography switching.

## v1.1.1 (2026-11-27)

### Architecture Modularization & Settings Decoupling
* **Dedicated Settings Module (`Core/Options.lua`):**
  * Extracted options panel, interactive checkboxes, opacity sliders, and reload notification logic into `Core/Options.lua` to match suite-wide architecture.
  * Streamlined `UIBiggins.lua` to serve as a focused lifecycle orchestrator and slash command router.
  * Standardized load order across the Biggins Suite: `LibBigginsSuite.lua` -> `Core\*.lua` -> `Modules\*.lua` -> `<AddonName>.lua`.

## v1.1.0 (2026-11-27)

### TellMeWhen Customization & UI Options Polish
* **Customizable Status Bar Background Opacity:**
  * Added a 1% step slider (0% - 100%, default 25%) for TellMeWhen status bar background opacity, matching LazySpeed and Perf Biggins visual styling.
  * Real-time live updates immediately apply opacity changes without requiring a UI reload.
  * Automatically dims and disables when TellMeWhen skinning is unchecked.
* **Reorganized Options Panel:**
  * Added a dedicated "TellMeWhen" parent section header.
  * Neatly indented "Skin Icons & Bars" and the new "Bar Background Opacity" slider under the TellMeWhen section.
  * Action bar options are cleanly grouped at the top.
* **Slash Commands:**
  * Added `/uibiggins opacity <0-100>` to inspect or configure TellMeWhen bar background opacity directly from chat.

## v1.0.0 (2026-11-26)

### Initial Release
* **Flatten Action Bar Buttons:**
  * Strips bulky metallic bezels, background slot art, and decorative bevels across all 8 standard action bars, pet action bar, stance bar, possess bar, extra action buttons, and spell flyouts (leaving the circular vehicle exit button untouched).
  * Preserves native icon sizing, proportions, and 45-degree chamfered squircle corners.
  * Adds a soft, subtle drop shadow strictly behind each button on the `BACKGROUND` layer matching modern Blizzard Cooldown Manager buttons.
* **Knowledge Biggins Integration:**
  * Automatically flattens the floating popup consumer button in `Knowledge Biggins`, removing the metallic bezel, expanding the icon to fill the frame, applying squircle masking, and adding matching drop shadows.
* **Skin TellMeWhen (Icons & Bars):**
  * Applies 45-degree chamfer squircle masks and soft drop shadows to square TellMeWhen icons while suppressing stock square borders.
  * Wraps TMW status bars (e.g. Rogue Energy bar) in the signature Biggins Suite gold tooltip border (`UI-Tooltip-Border`) with smooth `UI-StatusBar` fill and dark telemetry tracks (`COLOR_TRACK_BG = { 0.05, 0.05, 0.05, 0.75 }`).
  * Seamlessly covers 90-degree square corners with 45-degree chamfered corner bevels.
* **Smart Macro & Keybind Text Management:**
  * Hides macro name and keybind labels during normal gameplay for an uncluttered screen.
  * Automatically reveals text labels whenever abilities, macros, or items are dragged (`ACTIONBAR_SHOWGRID` / cursor pickup).
* **Blizzard Settings Integration:**
  * Integrated into Game Menu -> Options -> AddOns -> Biggins Suite -> UI (or `/uibiggins`).
  * Features live toggle callbacks and an explicit reload notification/button for frame-altering switches.
* **Architecture:**
  * Clean modular architecture split into `Core/Skinning.lua`, `Core/Options.lua`, `Modules/ActionBars.lua`, `Modules/TellMeWhen.lua`, and `UIBiggins.lua`.
