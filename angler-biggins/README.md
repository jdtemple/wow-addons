# Angler Biggins

**Angler Biggins 2.0** is an ultra-lightweight, dedicated dual-rod fishing suite for World of Warcraft. It allows you to pin your favorite high-stat primary fishing rod (such as engineered or expansion-specific rods) alongside the Legion artifact **Underlight Angler**, seamlessly toggling between them via a dynamic action bar button while automating water walking, instant fish form, and emergency lifejacket water rescue.

> **Requirements:** The Legion artifact **Underlight Angler** (equipped or in your bags). *(Optional: A secondary fishing rod if using dual-pole swapping).*

---

## Key Features

- **Dual-Pole Pinning & Action Bar Swapping:** Pin your preferred high-stat fishing rod (such as an engineered Khaz Algar or Midnight rod) and toggle between it and the Underlight Angler using a dynamic action bar button.
- **One-Click Action Bar Toggle Macro:** Place a macro directly onto your action bars via `[ Put Swap Button on Cursor ]` or `/anglerb button`. The macro dynamically flips its icon, name, and tooltip to show whichever pole will be equipped on next click.
- **Emergency Water Lifejacket:** Automatically equips the Underlight Angler from your backpack whenever you enter water with your primary rod equipped, granting instant fish form, swim speed, and permanent water walking (customizable in settings).
- **Native Slot 28 Container Swapping:** Leverages direct 1-to-1 container-to-inventory equipment swapping to ensure fishing tools are never abandoned in bags during unseat/reseat handshakes.
- **Zero-Taint Event-Driven Architecture:** Purely event-driven (`MOUNT_JOURNAL_USABILITY_CHANGED`, `MIRROR_TIMER_START`, `PLAYER_REGEN_ENABLED`) with zero background `OnUpdate` polling loops.
- **Dedicated Slot 28 Integration:** Operates directly on your character's dedicated Fishing Profession Tool slot (slot 28), eliminating bag shuffling.
- **Dragonflight & The War Within Trait Wakeup:** Resolves Blizzard's dormant profession equipment trait bug cleanly when entering water, waking up the Underlight Angler traits without breaking your UI.
- **Instance & Dungeon Resilience:** Fully functional across standard Dungeons, Raids, and Delves (Mythic+ keystones are safely suppressed due to Blizzard's active equipment lockdown). Eliminates the infinite gear-swapping loop bug found in legacy addons by completely avoiding fragile outdoor cosmetic aura dependencies (`394009`).
- **Underwater Delve & Submerged Breath Support:** Detects active breath timers in underwater Delves (such as *The Sinkhole* and *Tak-Rethan Abyss*), maintaining fish form and infinite water breathing even when walking on the sea floor.
- **Persistent Water Walking & Stand-on-Water Fishing:** Never strips the Underlight Angler upon transitioning from deep water to surface walking or dry land. Enables seamless water walking across lakes and lets you fish while standing directly on top of deep water pools.
- **Modern Blizzard Canvas Settings UI:** Integrated into `Game Menu -> Options -> AddOns -> Biggins AddOns -> Angler` with master enable toggle, dual-pole pinning controls, live telemetry diagnostics, and top-right `[ Defaults ]` button.
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
| `/anglerb pin`                | Pins currently equipped fishing pole as secondary rod                     |
| `/anglerb button`             | Puts one-click rod swap button onto cursor to drop onto any action bar    |
| `/anglerb swap`               | Manually swaps between Underlight Angler and pinned pole                  |
| `/anglerb lifejacket`         | Toggles auto-equipping Underlight Angler when entering water              |
| `/anglerb toggle`             | Toggles the master addon automation on or off                             |
| `/anglerb wake`               | Re-engages Underlight Angler traits (Fish Form / Water Walking) on demand |
| `/anglerb instances`          | Toggles activation inside Dungeons and Raids                              |
| `/anglerb delves`             | Toggles underwater Delve & breath meter detection                         |
| `/anglerb status`             | Displays current rod location, pinned pole, environment, and buff state   |
| `/anglerb help`, `/anglerb ?` | Displays available in-game slash commands and descriptions                |

---

## Installation

### Automatic (via PowerShell)

From the `angler-biggins` directory:

```powershell
.\package.ps1 -Install
```
