# UI Biggins (v1.0.0)

A sleek, lightweight action bar and interface visual enhancer for *World of Warcraft: Midnight* (Patch 12.1+) and *The War Within*.

Part of the **Biggins Suite**, **UI Biggins** modernizes your default action buttons and companion addons with clean, flat squircle geometry, soft drop shadows matching Blizzard's Cooldown Manager, signature gold telemetry status bar framing, and intelligent contextual text management.

---

## Key Features

### 1. Flatten Action Bar Buttons
* **Bulky Frame Stripping:** Strips heavy metallic bezels, background slot art, and decorative bevels across all 8 standard action bars, pet bar, stance bar, possess bar, extra action buttons, and spell flyouts (leaving the circular vehicle exit button untouched).
* **Knowledge Biggins Integration:** Automatically flattens the floating popup consumer button in `Knowledge Biggins`, harmonizing your profession consumables with your action bars.
* **45-Degree Chamfer Squircles:** Preserves native icon sizing, aspect ratio, and modern 45-degree chamfered squircle corners.
* **Soft Depth Shadows:** Adds a soft, subtle drop shadow strictly behind each button on the `BACKGROUND` layer, matching modern Blizzard Cooldown Manager aesthetics.
* **Leak-Free Safety:** Requires a clean UI reload to apply or revert, ensuring zero combat taint or frame reference leaks.

### 2. Skin TellMeWhen (Icons & Bars)
* **Square Icons:** Applies matching 45-degree chamfer squircle masks and soft drop shadows to TellMeWhen icon groups while suppressing clunky stock square borders.
* **Telemetry Status Bars:** Wraps TMW status bars (such as Rogue Energy bars) in the signature Biggins Suite gold tooltip border (`UI-Tooltip-Border`, edgeSize 12) with a smooth `UI-StatusBar` fill texture.
* **Concealed Chamfers:** Borders cleanly sit on the outside of the bar at frame level `+2`, covering raw 90-degree square corners with 45-degree metallic corner bevels.
* **High-Contrast Dark Track:** Consumed bar tracks render as a subtle dark telemetry track (`COLOR_TRACK_BG = { 0.05, 0.05, 0.05, 0.75 }`) over solid slate backing so world geometry does not show through depleted resources.

### 3. Smart Macro Name Hiding
* **Clutter-Free Gameplay:** Macro name text labels are completely hidden during normal gameplay for a clean, minimalist HUD.
* **Instant Drag Reveal:** Automatically reveals macro labels the instant you pick up an ability, macro, or item (`ACTIONBAR_SHOWGRID` / cursor pickup) so you always know where you are placing macros.

### 4. Smart Keybind Text Hiding
* **Clean Action Slots:** Hotkey labels are hidden during normal play.
* **Dynamic Binding Assist:** Automatically reveals keybinding text whenever you drag spells or reorganize buttons, giving you immediate layout awareness.

### 5. 100% Non-Invasive Architecture
* Does not alter Edit Mode, unit frames, nameplates, chat, CVars, or keybindings.
* Buff and debuff frames remain 100% untouched to preserve stock Blizzard dispel type color indicators (Magic blue, Curse purple, Poison green, Disease brown, Physical red).

---

## Blizzard Settings Integration

UI Biggins integrates directly into the official game menu (`Escape -> Options -> AddOns -> Biggins Suite -> UI` or `/uibiggins`):

| Setting                            | Type     | Description                                                                                                              |
| ---------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Flatten Action Bar Buttons**     | Checkbox | Strips bulky metallic frames on action bars and standalone buttons (including Knowledge Biggins). *(Requires UI Reload)* |
| **Skin TellMeWhen (Icons & Bars)** | Checkbox | Applies 45-degree squircle masks to TMW icons and signature gold tooltip borders to status bars. *(Requires UI Reload)*  |
| **Hide Macro Names**               | Checkbox | Hides macro text labels; automatically reveals them while dragging abilities. *(Live)*                                   |
| **Hide Keybind Labels**            | Checkbox | Hides hotkey labels; automatically reveals them while dragging abilities. *(Live)*                                       |
| **Defaults**                       | Button   | Restores all UI Biggins settings back to default.                                                                        |
| **Reload UI**                      | Button   | Dedicated button to immediately reload your interface and apply pending skin changes.                                    |

---

## Slash Commands

The settings panel and help can be accessed via `/uibiggins`:

| Command        | Action                                               |
| -------------- | ---------------------------------------------------- |
| `/uibiggins`   | Opens the UI Biggins settings panel in the game menu |
| `/uibiggins ?` | Displays available slash commands in chat            |

---

## Installation

1. Download the latest release from the repository or CurseForge/Wago.
2. Place the `UIBiggins` folder into your World of Warcraft AddOns directory:
   ```
   World of Warcraft\_retail_\Interface\AddOns\UIBiggins\
   ```
3. Launch World of Warcraft (or type `/reload` if already in-game) and ensure **UI Biggins** is enabled in your AddOn list.

---

## License

All Rights Reserved. Part of the Biggins Suite by Biggins (US-Whisperwind).
