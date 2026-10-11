# Assassin Debuffs Biggins

A lightweight, zero-allocation World of Warcraft addon that adds configurable horizontal debuff spacing and soft gradient halo borders for **Garrote**, **Rupture**, **Deathstalker's Mark**, **Kingsbane**, and **Deathmark** on Blizzard's stock nameplates.

Designed specifically for Assassination Rogues who want clean multi-target bleed and burst cooldown tracking without installing bloated nameplate replacement suites or corrupting game CVars.

---

## The Problem It Solves

On Blizzard's default nameplates, debuff countdown numbers are rendered dead-center over icons in large, bold font. Because **Garrote** and **Rupture** both feature dark red and black artwork, the large countdown digits cover ~80% of the icon texture, making them nearly impossible to tell apart during fast Mythic+ trash pulls.

Additionally, Blizzard's stock UI places debuff icons flush against each other (`0px` spacing), preventing clean borders and crowding the display.

**Assassin Debuffs Biggins** solves this by:
1. **Applying collision-free outward gradient halo borders** around your core bleeds and burst cooldowns that radiate cleanly above and below the icon.
2. **Eliminating icon collisions without layout crashes**: By radiating vertically (top and bottom only), neighboring debuffs in the horizontal row never bleed colors into each other, with zero risk of Blizzard layout engine errors or taint.
3. **Native button texture layering**: Renders directly on each debuff button on the high OVERLAY layer, naturally inheriting frame levels, scale, and visibility without separate child frame desync.
4. **Clean frame pool recycling**: Automatically clears glows on hide, guaranteeing recycled nameplate buttons never display stale colors from previous debuffs.
5. **Preserving 100% of your native CVars**: Runs purely in memory on UI frames without ever touching `SetCVar`.

---

## Tracked Debuffs & Default Color Palette

| Debuff                  | Role                 | Default Halo Color | Hex       |
| :---------------------- | :------------------- | :----------------- | :-------- |
| **Garrote**             | Core Bleed           | Amber / Orange     | `#FF9900` |
| **Rupture**             | Finisher Bleed       | Crimson / Red      | `#FF2020` |
| **Deathstalker's Mark** | Hero Talent Mark     | Vivid Purple       | `#A335EE` |
| **Kingsbane**           | Nature Poison Ramp   | Toxic / Neon Green | `#00FF66` |
| **Deathmark**           | Major Burst Cooldown | Electric Cyan      | `#00D4FF` |

---

## Features

* **Soft Feathered Halo Bars**: Directional gradient edges that radiate outward and smoothly dissolve into transparency.
* **Collision-Free Architecture**: Radiates outward above and below each icon, keeping horizontal edges clean so neighboring debuffs never collide or blend colors into each other.
* **Configurable Halo Position**: Dropdown selector to display halos above & below (`Top & Bottom`), above only (`Top Only`), or below only (`Bottom Only`).
* **Glow Thickness Control**: Slider to adjust how far the halo radiates from `1px` to `8px` (Default: `4px`).
* **Interactive Color Pickers**: Full color customization with native color picker integration for all 5 tracked debuffs.
* **Zero-Allocation Architecture**: Pre-cached `ColorMixin` objects and reusable border textures; generates **0 bytes/sec of Lua garbage** heap allocations during combat aura updates.
* **Native Settings Integration**: Configurable in `Escape -> Options -> AddOns -> Assassin Debuffs Biggins` or via `/adb` / `/assassindebuffs`.
* **Zero CVar Taint**: Never modifies `config-cache.wtf` or nameplate CVars. Disabling the addon returns your UI to 100% pure stock immediately.

---

## In-Game Configuration

Open the options panel via:
* `/adb`
* `/assassindebuffs`
* `Escape -> Options -> AddOns -> Assassin Debuffs Biggins`

### Controls Available:
* **Halo Position Dropdown**: Choose between `Top & Bottom` (default), `Top Only`, or `Bottom Only`.
* **Halo Thickness Slider**: Set base halo thickness (`1` - `8` px).
* **Color Swatches**: Click to customize the halo color for any of the 5 debuffs.
* **Reset to Defaults Button**: Restores original position, thickness, and color presets in one click.

---

## Engineering Standards

This addon adheres to the repository's strict performance standards:
1. **Zero Allocations in Hot Paths**: No table instantiations, closures, or string formatting inside `CompactUnitFrame_UpdateDebuffs`.
2. **Pre-Cached Gradients**: Solid and clear `ColorMixin` instances are pre-cached and reused across every nameplate frame.
3. **Safe Memory Hooks**: Built with `hooksecurefunc` on Blizzard's protected compact unit frames, completely avoiding combat taint.

---

## Author & License

* **Author**: Biggins (US-Whisperwind)
* **License**: [MIT License](../../LICENSE)
