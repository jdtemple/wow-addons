# LazySpeed Biggins (v4.0.0)

A high-performance speedometer, flight, and swim gauge for *World of Warcraft: Midnight* (Patch 12.1+).

Originally based on `LazySpeed` by Darthterac, this fork has been completely re-architected from the ground up for **maximum CPU efficiency, zero-allocation C++ memory management, modular checkbox settings, and a sleek nameplate-style integrated HUD**.

---

## Performance Benchmarks

* **Average CPU Usage:** `0.00 ms` (Dormant on foot / in combat), `< 0.07%` (Active in flight or swim)
* **Memory Footprint:** `~19 KB` (Static UI objects only; zero heap churn)
* **Lua Garbage Generation:** `0 bytes/sec` (Zero dynamic strings, zero runtime table allocations)

---

## Key Features

* **Nameplate-Style Integrated HUD:** A sleek 180px x 20px status bar with centered numeric and unit telemetry (`12pt OUTLINE` text overlaying the dynamic fill bar) for a clean, modern castbar / cooldown bar aesthetic.
* **Skyriding Vigor Telemetry & Turbo Glow:** A dedicated secondary bar tracking 1-6 Surge Forward / Skyward Ascent charges with continuous fractional fill and cooldown timer. Features color-coded aura glows for accelerated recharge states:
  * **Blue Glow:** *Thrill of the Skies* (high-speed flight recharge).
  * **Red Glow:** *Ground Skimming* (low-altitude terrain recharge; danger of collision!).
  * **Violet Glow:** Both buffs active (*Blue + Red = Purple* max turbo recharge).
  * **No Glow:** Normal gliding with classic Blizzard metallic gold border.
* **Dynamic Multi-Bar Stacking Engine:** Choose between Vertical (Speedometer above Vigor bar) and Horizontal stacking modes. Automatically collapses to a clean single bar when swimming, grounded, or in steady flight. Unified dragging moves both bars together.
* **Modular Checkbox Triggers:** Pick and choose exactly when your speedometer wakes up:
  * **Show While Flying / Skyriding:** Automatically activates during Skyriding, Dragonriding, and Steady Flight.
  * **Show While Swimming:** Automatically activates when submerged in water, tracking swim speed and aquatic mounts (Seahorses, Turtles, Otters).
  * **Show While on Ground:** Tracks on-foot and ground mount movement.
  * **Hide During Combat (Killswitch):** Instantly detaches and hides during combat to keep your interface clean.
* **Contextual Color Theming:**
  * **Flying / Ground:** Green (Cruising) -> Yellow (High Speed) -> Red (Max Thruster).
  * **Swimming:** Deep Ocean Blue -> Electric Cyan gradient.
* **Zero-Allocation C++ Rendering Pipeline:** Formats speed values directly inside Blizzard's native C++ engine via `FontString:SetFormattedText()` using pre-cached static format string pointers. No temporary string objects are ever created on Lua's garbage-collected heap.
* **True Script Detachment Engine (`OnUpdate = nil`):** When inactive on the ground or in combat, the `OnUpdate` script is completely unhooked from the frame engine. This guarantees zero background function calls while walking, standing, or fighting in dungeons and raids.
* **Stationary "Dirty Check":** Includes an idle gate that detects when speed is zero and skips redundant text reformatting and GPU status bar redraws while standing still.
* **Hardware-Accelerated UI:** Single native Blizzard `StatusBar` with smooth fill and classic Blizzard Metallic Gold backdrop.
* **Draggable & Moveable:** Left-click and drag the frame anywhere on your screen.

---

## Blizzard Settings Integration

LazySpeed Biggins integrates directly into the official game menu (`Escape -> Options -> AddOns -> Biggins AddOns -> LazySpeed` or `/lazyspeedb`):

### 1. Modular Visibility & Telemetry Checkboxes
* **Show While Flying / Skyriding** *(Default: ON)*
* **Show While Swimming** *(Default: ON)*
* **Show While on Ground** *(Default: OFF)*
* **Show Skyriding Vigor Bar** *(Default: ON)*
* **Glow on Accelerated Recharge Buffs** *(Default: ON)*
* **Hide During Combat** *(Default: ON)*

### 2. Stacking Mode
* **Vertical Stack** *(Default: Speedometer on top, Vigor bar below)*
* **Horizontal Stack** *(Side-by-side)*

### 3. Speed Measurement Unit
* **Miles per Hour (mph)** *(Default)*
* **Yards per Second (y/s)**
* **Kilometers per Hour (km/h)**
* **Percentage (%)**

### 4. Custom Sizing Sliders
* **Bar Width** *(100px - 300px, 1px step, Default: 180px)*
* **Bar Height** *(14px - 36px, 1px step, Default: 22px)* - with automatic dynamic font scaling!

### 5. Reset to Defaults
* **Reset to Defaults Button:** Native button in the settings panel (or `/lazyspeedb defaults`) that restores all triggers, speed measurement units, and bar dimensions back to default.

---

## Slash Commands

Commands are available via `/lazyspeedb`. In-game command help is available at any time by typing `/lazyspeedb ?` or `/lazyspeedb help`:

| Command                             | Action                                                     |
| :---------------------------------- | :--------------------------------------------------------- |
| `/lazyspeedb`                       | Opens the settings panel in the game menu                  |
| `/lazyspeedb toggle`                | Toggles the master speedometer and Vigor HUD on or off     |
| `/lazyspeedb vigor`                 | Toggles the Skyriding Vigor bar on or off                  |
| `/lazyspeedb glow` (or `/aura`)     | Toggles recharge buff glow on or off                       |
| `/lazyspeedb stack [horiz/vert]`    | Switches between vertical and horizontal stacking modes    |
| `/lazyspeedb lock`                  | Toggles locking frame position                             |
| `/lazyspeedb reset`                 | Resets frame position to center                            |
| `/lazyspeedb status`                | Displays current configuration in chat                     |
| `/lazyspeedb defaults`              | Resets all settings to defaults                            |
| `/lazyspeedb help`, `/lazyspeedb ?` | Displays available in-game slash commands and descriptions |

---

## Installation

1. Download the latest release from the repository.
2. Place the `LazySpeedBiggins` folder into your World of Warcraft AddOns directory:
   ```
   World of Warcraft\_retail_\Interface\AddOns\LazySpeedBiggins\
   ```
3. Ensure the folder contains:
   * `LazySpeedBiggins.lua`
   * `LazySpeedBiggins.toc`
4. Launch World of Warcraft (or type `/reload` if already in-game) and ensure **LazySpeed Biggins** is enabled in your AddOn list.

---

## Credits & Attribution

* **Original Addon & Concept:** Created by **Darthterac** - [LazySpeed on CurseForge](https://www.curseforge.com/wow/addons/lazyspeed)
* **v3.0 - v3.6.1 Architecture, Zero-Allocation Engine, Swim Mode, Nameplate UI & Settings:** Biggins (US-Whisperwind)

Please support and check out the original project by Darthterac at https://www.curseforge.com/wow/addons/lazyspeed!

---

## License

This project is licensed under the [MIT License](../../LICENSE) - feel free to use, modify, distribute, or incorporate this code into your own projects.
