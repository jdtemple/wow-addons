# Knowledge Biggins v1.0.0

### Initial Release
- **Universal Zero-Maintenance Detection:** Scans live item tooltips via `C_TooltipInfo` to automatically detect any consumable item that increases Profession Knowledge or skill across all professions (Mining, Herbalism, Skinning, Inscription, Blacksmithing, etc.) and expansions. Zero static item databases to maintain or update.
- **One-Click Secure Popup Consumer:** Automatically displays a sleek, native action button on your screen whenever unstudied profession knowledge items are in your bags. Left-clicking securely consumes the item on the spot without opening your bags or searching slots.
- **Draggable & Drop Movable:** Move the button anywhere on your screen at any time by holding `Shift` and dragging, or use `/kb unlock` for dedicated positioning mode. Position is saved across sessions in `KnowledgeBigginsDB`.
- **Stack Counter:** Displays total unconsumed items in your bags directly on the button face. Automatically steps through and consumes items one-by-one with each click until your bags are completely clear.
- **Combat Protection:** Strict combat lockdown handling suppresses button changes during combat and safely refreshes upon dropping combat (`PLAYER_REGEN_ENABLED`), ensuring zero interface action errors or execution taint.
- **Blizzard Canvas Settings Integration:** Fully integrated into the unified Biggins AddOns category in the native game options menu.
