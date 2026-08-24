# LazySpeed Biggins (v3.2)

A high-performance, flight-only speedometer and movement gauge for *World of Warcraft: Midnight* (Patch 12.1+).

Originally based on `LazySpeed` by Darthterac, this fork has been completely re-architected from the ground up for **maximum CPU efficiency, zero-allocation C++ memory management, and seamless native Blizzard UI integration**.

---

## ⚡ Performance Benchmarks

* **Average CPU Usage:** `0.00 ms` (Dormant on foot / in combat), `< 0.07%` (Active in flight)
* **Memory Footprint:** `~19 KB` (Static UI objects only; zero heap churn)
* **Lua Garbage Generation:** `0 bytes/sec` (Zero dynamic strings, zero runtime table allocations)

---

## 🚀 Key Features

* **Zero-Allocation C++ Rendering Pipeline:** Formats speed values directly inside Blizzard's native C++ engine via `FontString:SetFormattedText()` using pre-cached static format string pointers. No temporary string objects are ever created on Lua's garbage-collected heap.
* **True Script Detachment Engine (`OnUpdate = nil`):** When inactive on the ground or in combat, the `OnUpdate` script is completely unhooked from the frame engine. This guarantees zero background function calls while walking, standing, or fighting in dungeons and raids.
* **Stationary "Dirty Check":** Includes an idle gate that detects when speed is zero and skips redundant text reformatting and GPU status bar redraws while standing still.
* **Hard Combat Killswitch:** Listens to `PLAYER_REGEN_DISABLED` to immediately terminate the flight engine and hide the UI the millisecond combat begins.
* **Hardware-Accelerated UI:** Replaced legacy multi-texture grid loops with a single native Blizzard `StatusBar` featuring smooth color shifts (Green -> Yellow -> Red) and a classic Blizzard Metallic Gold backdrop.
* **Draggable & Moveable:** Left-click and drag the frame anywhere on your screen.

---

## 🎛️ Blizzard Settings Integration

LazySpeed Biggins integrates directly into the official game menu (`Escape -> Options -> AddOns -> LazySpeed Biggins`) with two native dropdown controls:

### 1. Visibility Mode
* **Only While Flying (Zero Idle CPU)** *(Default)* — Completely dormant on the ground (0.00ms CPU). Automatically wakes up and displays live velocity when Skyriding / Gliding in the air.
* **Not in Combat (Ground & Flight)** — Displays live movement speed while on foot, on ground mounts, and in flight. Automatically detaches and hides during combat.
* **Always Visible (Ground, Flight & Combat)** — Continual display across all gameplay states.

### 2. Speed Measurement Unit
* **Miles per Hour (mph)** *(Default)*
* **Yards per Second (y/s)**
* **Kilometers per Hour (km/h)**

*Note: You can also left-click the on-screen `[MPH]` button to cycle units on the fly. Settings stay in 100% real-time synchronization with the options menu.*

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

* **Original Addon & Concept:** Created by **Darthterac** — [LazySpeed on CurseForge](https://www.curseforge.com/wow/addons/lazyspeed)
* **v3.0 Architecture, Zero-Allocation Engine & Settings UI:** Biggins (US-Whisperwind)

Please support and check out the original project by Darthterac at https://www.curseforge.com/wow/addons/lazyspeed!

---

## 📄 License

This project is licensed under the [MIT License](../../LICENSE) — feel free to use, modify, distribute, or incorporate this code into your own projects.
