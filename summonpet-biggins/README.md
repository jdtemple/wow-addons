# SummonPet Biggins

**SummonPet Biggins** is an ultra-lightweight, high-performance World of Warcraft companion pet summoner designed to keep your favorite companion pet summoned automatically without CPU stutter, memory bloat, or clumsy UI overlays.

---

## Key Features

- **0.00% Movement CPU Usage:** Purely event-driven. Unlike legacy summoners that hook movement and camera keys on every step, SummonPet Biggins only executes for microseconds when you dismount, exit stealth, drop combat, or zone.
- **Native Game Engine Keybinding:** Binds directly in **Game Menu -> Options -> Keybindings -> AddOns -> SummonPetBiggins**. No action bar buttons, macros, or `/run` scripts needed.
- **Unified Settings UI:** All options live cleanly inside **Game Menu -> Options -> AddOns -> Biggins AddOns -> SummonPet** (or type `/summonpetb`). Zero hooking or tampering with Blizzard's PetJournal frames (100% taint-free and compatible with *Rematch*).
- **1-Click Pet Pinning:** Summon whatever companion pet you want in-game, then click **`[ Use Currently Summoned Pet ]`** (or type `/summonpetb pin`) to lock it in. No dragging icons across the screen.
- **3 Flexible Modes:**
  - **Random Favorites:** Automatically summons a random favorite pet from your Pet Journal stars.
  - **Completely Random:** Summons any pet in your collection.
  - **Specific Pinned Pet:** Keeps your chosen companion (e.g. Byte) summoned at all times.
- **Smart Stealth & Dungeon Mute:**
  - Automatically dismisses companion pets when entering Stealth (Rogues & Druids).
  - Automatically dismisses companion pets during Mythic+ dungeon keys (`CHALLENGE_MODE_START`) to keep nameplate clutter and visual noise at zero.
- **Ultra-Lightweight (< 20 KB Footprint):** Pure standalone Lua with zero external library dependencies (no Ace3 overhead).

---

## Slash Commands

Commands are available via `/summonpetb`. In-game command help is available at any time by typing `/summonpetb ?` or `/summonpetb help`:

| Command                             | Action                                                             |
| :---------------------------------- | :----------------------------------------------------------------- |
| `/summonpetb`                       | Opens the settings panel in the game menu                          |
| `/summonpetb toggle`                | Toggle companion auto-summoning on or off                          |
| `/summonpetb pin`                   | Pin your currently summoned pet as your active companion           |
| `/summonpetb pin <name>`            | Search by nickname or species name, pin it, and immediately summon |
| `/summonpetb fav`                   | Switch mode to Random Favorites                                    |
| `/summonpetb random`                | Switch mode to Completely Random                                   |
| `/summonpetb mount`                 | Toggle companion summoning while mounted on ground                 |
| `/summonpetb status`                | Display current addon status in chat                               |
| `/summonpetb options`               | Open the native settings panel                                     |
| `/summonpetb help`, `/summonpetb ?` | Display list of commands                                           |

---

## Installation

To install manually:
1. Copy the `SummonPetBiggins` folder into your World of Warcraft directory:
   `World of Warcraft\_retail_\Interface\AddOns\SummonPetBiggins`
2. Restart World of Warcraft or type `/reload`.
3. Open **Game Menu -> Options -> Keybindings -> AddOns -> SummonPet Biggins** to assign your toggle hotkey (or open **Options -> AddOns -> Biggins AddOns -> SummonPet** to configure).

---

## Credits & Acknowledgements

- **Callie (Caliaha):** Author of the original [BartrubySummonPet](https://github.com/Caliaha/BartrubySummonPet). SummonPet Biggins was created as a streamlined, modern tribute inspired by Callie's long-running companion pet utility.
