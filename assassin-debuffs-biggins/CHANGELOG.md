# Changelog - Assassin Debuffs Biggins

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-10-10

### Initial Release
* **Built-in Auto-Scaling Architecture**: Halo borders dynamically stretch and conform to the game's debuff dimensions, automatically scaling spacing and halo thickness proportionally with changes to the game's icon size slider.
* **Horizontal Debuff Spacing**: Added configurable spacing slider (0px to 12px, default 4px) to separate nameplate debuff buttons.
* **Soft Gradient Halo Borders**: Implemented directional gradient borders that fade smoothly toward outer edges for 5 core debuffs:
  * **Garrote** (Default: Amber / Orange `#FF9900`)
  * **Rupture** (Default: Crimson / Red `#FF2020`)
  * **Deathstalker's Mark** (Default: Vivid Purple `#A335EE`)
  * **Kingsbane** (Default: Toxic / Neon Green `#00FF66`)
  * **Deathmark** (Default: Electric Cyan `#00D4FF`)
* **Glow Thickness Slider**: Added configurable halo border thickness slider (1px to 8px, default 3px).
* **Interactive Color Pickers**: Added color swatches for all 5 tracked debuffs supporting modern `ColorPickerFrame:SetupColorPickerAndShow`.
* **Zero-Allocation Architecture**: Pre-cached `ColorMixin` pointers and lazy-allocated border textures on debuff frames.
* **Settings & Slash Command**: Integrated with native Blizzard Settings panel and added `/adb` and `/assassindebuffs` slash commands.
* **Zero CVar Taint**: Runs 100% in RAM with zero `SetCVar` calls.
