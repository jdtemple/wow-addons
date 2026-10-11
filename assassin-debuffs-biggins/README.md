# Assassin Debuffs Biggins

A lightweight, zero-allocation World of Warcraft addon that adds configurable horizontal debuff spacing and soft gradient halo borders for **Garrote**, **Rupture**, **Deathstalker's Mark**, **Kingsbane**, and **Deathmark** on Blizzard's stock nameplates.

Designed specifically for Assassination Rogues who want clean multi-target bleed and burst cooldown tracking without installing bloated nameplate replacement suites or corrupting game CVars.

---

## The Problem It Solves

On Blizzard's default nameplates, debuff countdown numbers are rendered dead-center over icons in large, bold font. Because **Garrote** and **Rupture** both feature dark red and black artwork, the large countdown digits cover ~80% of the icon texture, making them nearly impossible to tell apart during fast Mythic+ trash pulls.

Additionally, Blizzard's stock UI places debuff icons flush against each other (`0px` spacing), preventing clean borders and crowding the display.

**Assassin Debuffs Biggins** solves this by:
1. **Injecting horizontal spacing** between nameplate debuffs so each icon has dedicated breathing room.
2. **Applying soft gradient halo borders** around your core bleeds and burst cooldowns that fade smoothly into transparency toward the outer edges.
3. **Built-in auto-scaling**: Halo borders naturally conform to your debuff dimensions, and spacing/glow thickness scale proportionally whenever you adjust the game's native debuff icon size.
4. **Preserving your large centered timers** so you keep the valuable countdown numbers without visual clutter.
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

* **Soft Feathered Halo Borders**: Directional gradient edges that radiate from the icon boundary and smoothly dissolve into the background.
* **Built-in Auto-Scaling**: Halos automatically stretch to match any debuff icon size configured in game options. Halo thickness and spacing automatically adjust proportionally so your visual balance is maintained across all scales.
* **Customizable Debuff Spacing**: Slider in the game options to adjust horizontal gaps from `0px` to `12px` (Default: `4px`).
* **Glow Thickness Control**: Slider to adjust how far the halo radiates from `1px` to `8px` (Default: `3px`).
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
* **Horizontal Spacing Slider**: Set the base gap between debuff icons (`0` - `12` px).
* **Glow Halo Thickness Slider**: Set base halo width (`1` - `8` px).
* **Color Swatches**: Click to customize the halo color for any of the 5 debuffs.
* **Reset to Defaults Button**: Restores original spacing, thickness, and color presets in one click.

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
