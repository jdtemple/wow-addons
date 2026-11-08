# SummonPet Biggins v1.4.0

### Breaking Changes
- **Standardized Slash Commands:** Replaced `/togglepet` and `/spb` with `/summonpetb` across the addon to establish a collision-free suite namespace and prevent conflicts with other addons. Please update any macros to `/summonpetb`.
- **Aligned Slash Command Behavior:** The bare `/summonpetb` command now opens the settings panel in the game menu (aligning with all other addons in the Biggins suite), while `/summonpetb toggle` toggles companion auto-summoning on or off.

### Added
- **Help Command & Alias:** Added `/summonpetb help` and `/summonpetb ?` slash commands with formatted in-game command documentation in chat.

# SummonPet Biggins v1.3.0

### Added
- **Named Companion Pinning:** `/spb pin <pet-name>` now allows pinning and summoning a specific companion directly by custom nickname or species name. If another pet is currently summoned, it will be automatically swapped to the requested pet.
