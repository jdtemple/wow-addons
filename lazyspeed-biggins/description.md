# LazySpeed Biggins

**LazySpeed Biggins** is an ultra-lightweight, high-performance flight, swim, and movement speedometer for *World of Warcraft: Midnight* and *The War Within*.

Engineered with a sleek, modern **nameplate-style HUD** and a classic **Blizzard Metallic Gold** border, it provides real-time velocity telemetry without ever cluttering your screen or impacting your frame rates.

---

## Credits & Attribution

This project is a modernized, ground-up performance re-architecture of the classic addon **[LazySpeed by Darthterac](https://www.curseforge.com/wow/addons/lazyspeed)**.

Huge thanks and full credit go to **Darthterac** for creating the original concept and mathematical foundation! If you enjoy this addon, please check out and support Darthterac's original work.

---

## What Makes LazySpeed Biggins Different?

While traditional speedometers run continuous background timers that churn through memory, **LazySpeed Biggins** was built from the ground up for **extreme CPU efficiency and zero memory overhead**:

* **Zero-Allocation C++ Rendering Pipeline:** Formats speed telemetry directly inside Blizzard's native C++ engine via `FontString:SetFormattedText()` using pre-cached static format string pointers. It generates **0 bytes/sec of Lua garbage**, eliminating micro-stutters.
* **True Script Detachment Engine (`OnUpdate = nil`):** When you are on foot, standing still, or in combat, the update script is completely detached from the game engine. **Zero background CPU cycles** are consumed while raiding, doing dungeons, or idling in town.
* **Stationary "Dirty Check":** Automatically skips redundant text reformatting and status bar redraws while standing still.
* **Memory Footprint:** Less than **20 KB** total memory usage.

---

## Key Features

* **Sleek Nameplate HUD:** A compact 180px x 20px status bar featuring centered high-contrast typography (`12pt OUTLINE`) overlaid directly on the dynamic fill bar for a clean, modern aesthetic.
* **Skyriding Vigor Telemetry & Turbo Glow:** A dedicated secondary bar tracking 1-6 Surge Forward / Skyward Ascent charges with continuous fractional fill and cooldown timer. Features color-coded aura glows for accelerated recharge states:
  * **Blue Glow:** *Thrill of the Skies* (high-speed flight recharge).
  * **Red Glow:** *Ground Skimming* (low-altitude terrain recharge; danger of collision!).
  * **Violet Glow:** Both buffs active (*Blue + Red = Purple* max turbo recharge).
  * **No Glow:** Normal gliding with classic Blizzard metallic gold border.
* **Dynamic Multi-Bar Stacking Engine:** Choose between Vertical (Speedometer above Vigor bar) and Horizontal stacking modes. Automatically collapses to a clean single bar when swimming, grounded, or in steady flight. Unified dragging moves both bars together.
* **Modular Visibility Triggers:** Choose exactly when your speedometer wakes up:
  * **Show While Flying / Skyriding:** Automatically appears during Skyriding, Dragonriding, and Steady Flight.
  * **Show While Swimming:** Automatically tracks swim speed and aquatic mount velocity (Seahorses, Turtles, Otters).
  * **Show While on Ground:** Tracks on-foot movement and ground mounts.
  * **Hide During Combat (Killswitch):** Instantly hides and detaches during combat to keep your interface clean.
* **Contextual Color Grading:**
  * **Flight & Ground:** Smoothly transitions from **Cruising Green** -> **High-Speed Yellow** -> **Max Thruster Red**.
  * **Swimming:** Dynamic **Deep Ocean Blue** -> **Electric Cyan** gradient.
* **Fully Draggable:** Simply left-click and drag the frame anywhere on your screen. Your custom position saves automatically across sessions.

---

## In-Game Configuration

Configure your preferences via the native Blizzard Settings panel (**Game Menu -> Options -> AddOns -> Biggins AddOns -> LazySpeed**) or by typing:

```
/lazyspeedb
```

### Configurable Options:
1. **Speed Units:**
   * **Miles per Hour (mph)** *(Default)*
   * **Yards per Second (y/s)**
   * **Kilometers per Hour (km/h)**
   * **Percentage (%)**
2. **Custom Sizing Sliders:**
   * **Bar Width:** 100px - 300px (1px step)
   * **Bar Height:** 14px - 36px (1px step) with dynamic proportional font scaling
3. **Behavioral Triggers & Telemetry:**
   * Toggle Skyriding / Flight visibility
   * Toggle Swimming visibility
   * Toggle Ground movement visibility
   * Toggle Skyriding Vigor bar
   * Toggle Accelerated Recharge Aura Glow
   * Toggle In-Combat hide killswitch
4. **Stacking Mode:**
   * Vertical Stack (Speedometer on top, Vigor bar below)
   * Horizontal Stack (Side-by-side)
5. **Reset to Defaults:**
   * In-panel button or `/lazyspeedb defaults` to restore all options to defaults.

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
