# World of Warcraft AddOns

Welcome to my personal collection of World of Warcraft addons.

I am an experienced software engineer dipping my toes into World of Warcraft addon development. This repository serves as a home for custom addons, performance-focused forks, and UI enhancements built primarily for personal gameplay optimization, with a strict emphasis on **zero-allocation programming, CPU efficiency, and clean native Blizzard UI integration**.

All projects here are open source and shared freely under the [MIT License](LICENSE) for the community to use, fork, or incorporate into upstream projects.

---

## Projects in this Repository

### [LazySpeed Biggins (v3.6.1)](./lazyspeed-biggins)
A high-performance flight, swim, and movement speedometer featuring a sleek nameplate-style HUD, designed for *World of Warcraft: Midnight* and *The War Within*. Originally based on [LazySpeed by Darthterac](https://www.curseforge.com/wow/addons/lazyspeed).

* **Nameplate-Style Integrated HUD:** A compact 180px x 20px status bar with centered high-contrast telemetry (`12pt OUTLINE` font) overlaid directly on the dynamic fill bar for a clean, modern castbar aesthetic.
* **Modular Visibility Triggers:** Fully customizable behavior via native Blizzard settings checkboxes:
  * **Show While Flying / Skyriding** *(Default: ON)*
  * **Show While Swimming** *(Default: ON)* - with dynamic Deep Ocean Blue -> Electric Cyan gradient!
  * **Show While on Ground** *(Default: OFF)*
  * **Hide During Combat** *(Default: ON)* - instant killswitch detachment.
* **Zero Idle Footprint:** Completely unhooks its update script (`OnUpdate = nil`) when grounded or dormant, achieving a verified **0.00ms CPU footprint** on foot.
* **Zero-Allocation C++ Pipeline:** Renders text using Blizzard's native `FontString:SetFormattedText()` with pre-cached static format string pointers, generating **0 bytes/sec of Lua garbage** heap allocations.
* **Stationary Dirty Check:** Skips redundant GPU texture redraws and text updates when stationary (`currentSpeed == 0`).
* **Blizzard Settings Integration:** Full native settings panel in `Escape -> Options -> AddOns -> LazySpeed Biggins` (or `/lazyspeed` / `/lsb`) with configurable **Speed Units** (MPH, Y/S, KM/H, %), custom **Bar Width & Height Sliders**, **Reset to Defaults Button**, and modular triggers.
* **Release & Publishing Guide:** See [CURSEFORGE_PUBLISHING.md](CURSEFORGE_PUBLISHING.md) for packaging and distribution instructions.

### [SummonPet Biggins (v1.0.2)](./summonpet-biggins)
An ultra-lightweight, event-driven companion pet summoner designed to keep your favorite companion pet summoned automatically without CPU stutter, memory bloat, or clumsy UI overlays. Inspired by Callie's (Caliaha) classic [BartrubySummonPet](https://github.com/Caliaha/BartrubySummonPet).

* **0.00% Movement CPU Usage:** Purely event-driven. Completely eliminates legacy movement and camera key hooking loops. Only executes for microseconds when you dismount, exit stealth, drop combat, or zone.
* **Native Game Engine Keybinding:** First-class `Bindings.xml` integration under `Game Menu -> Options -> Keybindings -> AddOns -> SummonPet Biggins`. Bind your toggle and pet-pinning hotkeys directly without consuming action bar slots or requiring macros.
* **Unified Native Settings:** Clean settings panel inside `Game Menu -> Options -> AddOns -> SummonPet Biggins` (or `/spb options`) with zero hooking or tampering of Blizzard's PetJournal frames (100% taint-free).
* **1-Click Pet Pinning:** Summon whatever companion pet you want in-game, then click `[ Use Currently Summoned Pet ]` (or type `/spb pin`) to instantly pin it.
* **Three Flexible Modes:** Random Favorites (starred pets), Completely Random (entire collection), or Specific Pinned Pet (e.g. Byte).
* **Granular Instance Auto-Dismiss:** Master toggle with individual sub-toggles ordered by challenge level:
  * **Raids**
  * **Mythic+ Dungeons**
  * **Regular Dungeons**
  * **Delves & Labyrinths**
* **Smart Stealth & Mounted Summoning:** Auto-dismisses in stealth for Rogues and Druids. Features an optional "Summon Companion While Mounted (Ground Only)" toggle with a touchdown watcher that instantly summons your pet upon landing from flight while continuously running.
* **Ultra-Lightweight (< 20 KB Footprint):** Pure standalone Lua with zero external library dependencies (no Ace3 overhead).
* **Release & Publishing Guide:** See [CURSEFORGE_PUBLISHING.md](CURSEFORGE_PUBLISHING.md) for packaging and distribution instructions.

---

## Performance & Engineering Philosophy

Many legacy addons suffer from continuous frame polling, dynamic string concatenation (`..`) in tick loops, and unthrottled texture redraws that contribute to frame hitches, Lua garbage collection spikes, and client lockups in high-intensity combat.

The addons in this repository adhere to the following engineering standards:

1. **Zero-Allocation in Hot Paths:** Eliminate table creations, closures, and string concatenations inside frequent update loops.
2. **Event-Driven Lifecycles:** Avoid per-frame polling whenever game events (`PLAYER_REGEN_DISABLED`, `PLAYER_MOUNT_DISPLAY_CHANGED`) can manage state transitions.
3. **Hard Script Detachment:** Unhook `OnUpdate` scripts entirely (`SetScript("OnUpdate", nil)`) when UI components are dormant.
4. **Native Blizzard Ecosystem:** Leverage modern Blizzard C-APIs (`Settings.RegisterAddOnCategory`, `FontString:SetFormattedText`) for clean visual integration and seamless persistence.

---

## License

This repository is licensed under the [MIT License](LICENSE) - feel free to use, modify, distribute, or incorporate any of this code into your own projects.
