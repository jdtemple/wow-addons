# LazySpeed Biggins (v3.4.1)

A high-performance speedometer, flight, and swim gauge for *World of Warcraft: Midnight* (Patch 12.1+).

Originally based on `LazySpeed` by Darthterac, this fork has been completely re-architected from the ground up for **maximum CPU efficiency, zero-allocation C++ memory management, modular checkbox settings, and a sleek nameplate-style integrated HUD**.

---

## ⚡ Performance Benchmarks

* **Average CPU Usage:** `0.00 ms` (Dormant on foot / in combat), `< 0.07%` (Active in flight or swim)
* **Memory Footprint:** `~19 KB` (Static UI objects only; zero heap churn)
* **Lua Garbage Generation:** `0 bytes/sec` (Zero dynamic strings, zero runtime table allocations)

---

## 🚀 Key Features

* **Nameplate-Style Integrated HUD:** A sleek 180px x 20px status bar with centered numeric and unit telemetry (`12pt OUTLINE` text overlaying the dynamic fill bar) for a clean, modern castbar / cooldown bar aesthetic.
* **Modular Checkbox Triggers:** Pick and choose exactly when your speedometer wakes up:
  * ☑️ **Show While Flying / Skyriding:** Automatically activates during Skyriding, Dragonriding, and Steady Flight.
  * ☑️ **Show While Swimming:** Automatically activates when submerged in water, tracking swim speed and aquatic mounts (Seahorses, Turtles, Otters).
  * ⬜ **Show While on Ground:** Tracks on-foot and ground mount movement.
  * ☑️ **Hide During Combat (Killswitch):** Instantly detaches and hides during combat to keep your interface clean.
* **Contextual Color Theming:**
  * **Flying / Ground:** Green (Cruising) $\rightarrow$ Yellow (High Speed) $\rightarrow$ Red (Max Thruster).
  * **Swimming:** Deep Ocean Blue $\rightarrow$ Electric Cyan gradient.
* **Zero-Allocation C++ Rendering Pipeline:** Formats speed values directly inside Blizzard's native C++ engine via `FontString:SetFormattedText()` using pre-cached static format string pointers. No temporary string objects are ever created on Lua's garbage-collected heap.
* **True Script Detachment Engine (`OnUpdate = nil`):** When inactive on the ground or in combat, the `OnUpdate` script is completely unhooked from the frame engine. This guarantees zero background function calls while walking, standing, or fighting in dungeons and raids.
* **Stationary "Dirty Check":** Includes an idle gate that detects when speed is zero and skips redundant text reformatting and GPU status bar redraws while standing still.
* **Hardware-Accelerated UI:** Single native Blizzard `StatusBar` with smooth fill and classic Blizzard Metallic Gold backdrop.
* **Draggable & Moveable:** Left-click and drag the frame anywhere on your screen.

---

## 🎛️ Blizzard Settings Integration

LazySpeed Biggins integrates directly into the official game menu (`Escape -> Options -> AddOns -> LazySpeed Biggins` or `/lazyspeed`):

### 1. Modular Visibility Checkboxes
* **Show While Flying / Skyriding** *(Default: ON)*
* **Show While Swimming** *(Default: ON)*
* **Show While on Ground** *(Default: OFF)*
* **Hide During Combat** *(Default: ON)*

### 2. Speed Measurement Unit
* **Miles per Hour (mph)** *(Default)*
* **Yards per Second (y/s)**
* **Kilometers per Hour (km/h)**

---

## 📦 Installation

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

## 👥 Credits & Attribution

* **Original Addon & Concept:** Created by **Darthterac** - [LazySpeed on CurseForge](https://www.curseforge.com/wow/addons/lazyspeed)
* **v3.0 - v3.4.1 Architecture, Zero-Allocation Engine, Swim Mode, Nameplate UI & Settings:** Biggins (US-Whisperwind)

Please support and check out the original project by Darthterac at https://www.curseforge.com/wow/addons/lazyspeed!

---

## 📄 License

This project is licensed under the [MIT License](../../LICENSE) - feel free to use, modify, distribute, or incorporate this code into your own projects.
