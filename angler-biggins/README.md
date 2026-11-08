# Angler Biggins

**Angler Biggins** is an ultra-lightweight, dedicated World of Warcraft addon that automates the Underlight Angler artifact fishing pole's water walking, fish form, swim speed, and underwater breathing without bag clutter, item juggling, or gear-swapping loops.

> **Prerequisite:** Requires the Legion artifact **Underlight Angler** to be socketed directly in your character's **Fishing Profession Equipment slot (Slot 28)**. Angler Biggins operates purely on your slotted fishing equipment without touching your bags.

---

## Key Features

- **Zero-Taint Event-Driven Architecture:** Purely event-driven (`MOUNT_JOURNAL_USABILITY_CHANGED`, `MIRROR_TIMER_START`, `PLAYER_REGEN_ENABLED`) with zero background `OnUpdate` polling loops.
- **Dedicated Slot 28 Integration:** Operates directly on your character's dedicated Fishing Profession Tool slot (slot 28), eliminating bag shuffling.
- **Dragonflight & The War Within Trait Wakeup:** Resolves Blizzard's dormant profession equipment trait bug cleanly when entering water, waking up the Underlight Angler traits without breaking your UI.
- **Instance & Dungeon Resilience:** Fully functional across Dungeons, Raids, and Delves. Eliminates the infinite gear-swapping loop bug found in legacy addons by completely avoiding fragile outdoor cosmetic aura dependencies (`394009`).
- **Underwater Delve & Submerged Breath Support:** Detects active breath timers in underwater Delves (such as *The Sinkhole* and *Tak-Rethan Abyss*), maintaining fish form and infinite water breathing even when walking on the sea floor.
- **Persistent Water Walking & Stand-on-Water Fishing:** Never strips the Underlight Angler upon transitioning from deep water to surface walking or dry land. Enables seamless water walking across lakes and lets you fish while standing directly on top of deep water pools.
- **Modern Blizzard Canvas Settings UI:** Integrated into `Game Menu -> Options -> AddOns -> Biggins AddOns -> Angler` with master enable toggle, live telemetry diagnostics, and top-right `[ Defaults ]` button.
- **Zero Overhead & Zero Dependencies:** Under 15 KB footprint, zero background memory allocation, and fully self-contained.

---

## In-Game Configuration

Configure your preferences via the native Blizzard Settings panel (**Game Menu -> Options -> AddOns -> Biggins AddOns -> Angler**) or by typing:

```
/anglerb
```

---

## Slash Commands

Commands are available via `/anglerb`. In-game command help is available at any time by typing `/anglerb ?` or `/anglerb help`:

| Command                       | Action                                                                    |
| :---------------------------- | :------------------------------------------------------------------------ |
| `/anglerb`                    | Opens the settings panel in the Blizzard Game Menu                        |
| `/anglerb toggle`             | Toggles the master addon automation on or off                             |
| `/anglerb wake`               | Re-engages Underlight Angler traits (Fish Form / Water Walking) on demand |
| `/anglerb instances`          | Toggles activation inside Dungeons and Raids                              |
| `/anglerb delves`             | Toggles underwater Delve & breath meter detection                         |
| `/anglerb status`             | Displays current rod location, environment, and buff state                |
| `/anglerb help`, `/anglerb ?` | Displays available in-game slash commands and descriptions                |

---

## Installation

### Automatic (via PowerShell)

From the `angler-biggins` directory:

```powershell
.\package.ps1 -Install
```
