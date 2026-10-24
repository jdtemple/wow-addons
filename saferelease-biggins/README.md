# SafeRelease Biggins

**SafeRelease Biggins** is an ultra-lightweight, dedicated World of Warcraft addon designed to prevent accidental and reflexive "Release Spirit" clicks during wipes across raids, Mythic+ dungeons, and delves when combat resurrections, soulstones, or mass resurrections are available.

---

## Key Features

- **Zero-Taint Secure Hooking:** Intercepts `StaticPopup` death dialogs via native `hooksecurefunc` without replacing or tainting protected Blizzard UI frame scripts.
- **Physical Click Interception:** Places an inert, non-interactive overlay button directly over the native Release button during lockouts, making early release physically impossible even with frantic mouse clicking.
- **3 Flexible Guard Modes:**
  - **Countdown Timer Delay (Default):** Temporarily locks the Release button for a configurable duration (1 to 10 seconds) with an active countdown (`Release (5s)...`). Breaks panic-click muscle memory without requiring extra keystrokes.
  - **Modifier-Key Hold:** Locks the Release button until `Alt`, `Shift`, or `Ctrl` is held down, displaying the assigned key directly on the button (`Hold ALT`).
  - **Hybrid Mode:** Combines both approaches: runs a visual countdown on the button with the instant modifier key bypass indicator (`Hold ALT (5s)`).
- **Full Raid Wipe Detection (Optional):** Can automatically detect when the entire raid group is dead and drop the guard for a run-back (Default: OFF, keeping release guarded in case a runner revives the raid).
- **Usable Self-Resurrection Bypass:** Automatically detects when a Shaman Reincarnation, Warlock Soulstone, or other self-resurrection option is ready (`C_DeathInfo.GetSelfResurrectOptions`) and leaves the dialog unblocked.
- **Modular Content Scoping:**
  - **Raids** *(Default: ON - protects LFR, Normal, Heroic, Mythic)*
  - **Mythic+ Dungeons** *(Default: OFF)*
  - **Dungeons (Normal, Heroic, Mythic 0)** *(Default: OFF)*
  - **Delves & Scenarios** *(Default: OFF)*
  - *Never blocks release in open-world questing, leveling, or PvP.*
- **Modern Blizzard Canvas Settings UI:** Integrated directly into `Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease` with top-right `[ Defaults ]` button, master toggle, and dynamic control attenuation.
- **Zero Overhead & Zero Dependencies:** Under 20 KB footprint, zero background update loops, and zero external framework bloat.

---

## In-Game Configuration

Configure your preferences via the native Blizzard Settings panel (**Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease**) or by typing:

```
/saferelease
```
*(or `/srb`)*

---

## Slash Commands

Commands are available via `/saferelease` or `/srb`:

| Command                     | Action                                                              |
| :-------------------------- | :------------------------------------------------------------------ |
| `/srb`                      | Opens the settings panel in the game menu                           |
| `/srb toggle`               | Toggles the master release guard on or off                          |
| `/srb countdown`            | Sets guard mechanism to Countdown Timer Delay                       |
| `/srb modifier`             | Sets guard mechanism to Modifier-Key Hold                           |
| `/srb hybrid`               | Sets guard mechanism to Hybrid (Countdown with modifier key bypass) |
| `/srb mod <alt/shift/ctrl>` | Sets the modifier key required to unlock release                    |
| `/srb delay <1-10>`         | Sets the countdown delay duration in seconds                        |
| `/srb raids`                | Toggles raid instance protection on or off                          |
| `/srb status`               | Displays current addon configuration in chat                        |
| `/srb defaults`             | Restores all settings to default values                             |

---

## Installation

### Automatic (via PowerShell)
Run the included packaging script:
```powershell
.\package.ps1 -Install
```

### Manual
1. Copy the `SafeReleaseBiggins` folder into your World of Warcraft directory:
   `World of Warcraft\_retail_\Interface\AddOns\SafeReleaseBiggins`
2. Restart World of Warcraft or run `/reload`.
3. Type `/srb` or open **Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease** to customize your settings.

---

## Author

- **Biggins** (US-Whisperwind)
