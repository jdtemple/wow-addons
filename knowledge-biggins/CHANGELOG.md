# Knowledge Biggins v1.3.2

### Fixed
- **Edit Mode Tooltip Placement:** Updated the floating button's hover tooltip to use `GameTooltip_SetDefaultAnchor`, allowing it to properly dock at the player's configured Edit Mode / UI Layout Editor location instead of forcing an override anchor directly above the button.

# Knowledge Biggins v1.3.1

### Polish
- **Options Slash Command Footer:** Elevated slash command documentation in the options panel with highlighted Blizzard Gold styling (`/knowledgeb`) to enhance visual hierarchy and readability across the Biggins Suite.

# Knowledge Biggins v1.3.0

### Added
- **Interactive Settings Tray Drag & Drop:** Added direct drag & drop and click-to-drop target zones to both the Custom Allow List and Block List visual trays in `Options -> AddOns -> Biggins AddOns -> Knowledge`. Players can now drop items directly into the options panel trays from their bags without needing to target the floating button.
- **Universal Container & Click-to-Open Support:** Expanded the Custom Allow List to support containers, lockboxes, satchels, patron order reward bags (such as *Artisan's Consortium Payout*), and coin purses. Items with `<Right Click to Open>` and `<Right Click to Read>` can now be whitelisted and opened with one click via the popup button.
- **Removed Restrictive Use Validation on Allow List:** Removed the strict `Use:` effect requirement on custom allow list additions, giving players full freedom to whitelist any click-to-use or click-to-open inventory items.

# Knowledge Biggins v1.2.0

### Added
- **Master Enable Checkbox:** Added top-level "Enable Knowledge Biggins" checkbox in `Options -> AddOns -> Biggins AddOns -> Knowledge` to seamlessly toggle the addon on or off, aligning with all other addons in the Biggins suite.
- **Toggle Slash Command:** Added `/knowledgeb toggle` (or `/knowledgeb enable`) slash command to quickly toggle the addon on or off from chat or macros.

# Knowledge Biggins v1.1.1

### Fixed
- **World & Bag Initialization on Login:** Added native `PLAYER_ENTERING_WORLD` handling to ensure items already in bags are immediately detected upon entering the game world without requiring a `/reload`.
- **Eliminated Negative Cache Poisoning:** The internal cache now only stores confirmed knowledge items. Newly looted items whose dynamic spell/use descriptions are still downloading from the server will no longer be permanently flagged as non-knowledge items.
- **Stock Action Bar Stack Count Styling:** Upgraded the stack count font string from `NumberFontNormalSmallGray` to native Blizzard `NumberFontNormal` (crisp white text with black outline) with right justification at `(-2, 2)`, matching stock action buttons.
- **Keybinding Label Shortened:** Shortened the keybindings settings label to "Study Knowledge" to prevent truncation in the Blizzard Keybindings UI.
- **TOC & Keybindings Optimization:** Removed `Bindings.xml` from the `.toc` manifest. The game client automatically loads `Bindings.xml` natively for keybindings; removing it from the `.toc` eliminates FrameXML parse warnings.

# Knowledge Biggins v1.1.0

### Added
- **Drag & Drop Custom Allow List:** Drag any item from your bags and drop it directly onto the floating button to add it to your custom allow list. Supports any click-to-use item across all expansions.
- **One-Click Ignore (Block List):** Hold `Alt + Right-Click` on the floating button to immediately block the current item from showing. Useful for saving specific knowledge items for later.
- **Settings Panel Management Trays:** Visual icon trays in `Options -> AddOns -> Biggins AddOns -> Knowledge` displaying all allowed and blocked items with mouseover tooltips and right-click removal.
- **Allow List & Block List Reset Controls:** Added `[ Reset Allow List ]` and `[ Reset Block List ]` buttons to quickly clear curated lists.
- **Full Reagent Bag Support:** Expanded bag scanning to cover all equipped bags including Bag 5 (`Enum.BagIndex.ReagentBag`), fully supporting unified bag addons (Baganator, Bagnon).
- **Use Action Validation:** Added guardrail requiring items to possess an active `Use:` action before allowing, preventing dead-button lockups on passive items.
- **Native Blizzard Keybindings:** Assign a dedicated keyboard shortcut in `Options -> Keybindings -> Knowledge Biggins` to consume queued knowledge items without mouse clicks.
- **Enhanced Slash Commands:** Added `/knowledgeb allow <id>`, `/knowledgeb block`, `/knowledgeb ignore`, `/knowledgeb clear`, `/knowledgeb help`, and `/knowledgeb ?`.

### Changed
- **Terminology & Clarity:** Standardized user-facing UI and settings to "Allow List" and "Block List".
- **Positioning Clarification:** Updated documentation and settings descriptions from "zero-maintenance" to "low-maintenance" to accurately reflect user curation options.

---

# Knowledge Biggins v1.0.0

### Initial Release
- **Universal Zero-Maintenance Detection:** Scans live item tooltips via `C_TooltipInfo` to automatically detect any consumable item that increases Profession Knowledge or skill across all professions (Mining, Herbalism, Skinning, Inscription, Blacksmithing, etc.) and expansions. Zero static item databases to maintain or update.
- **One-Click Secure Popup Consumer:** Automatically displays a sleek, native action button on your screen whenever unstudied profession knowledge items are in your bags. Left-clicking securely consumes the item on the spot without opening your bags or searching slots.
- **Draggable & Drop Movable:** Move the button anywhere on your screen at any time by holding `Shift` and dragging, or use `/kb unlock` for dedicated positioning mode. Position is saved across sessions in `KnowledgeBigginsDB`.
- **Stack Counter:** Displays total unconsumed items in your bags directly on the button face. Automatically steps through and consumes items one-by-one with each click until your bags are completely clear.
- **Combat Protection:** Strict combat lockdown handling suppresses button changes during combat and safely refreshes upon dropping combat (`PLAYER_REGEN_ENABLED`), ensuring zero interface action errors or execution taint.
- **Blizzard Canvas Settings Integration:** Fully integrated into the unified Biggins AddOns category in the native game options menu.
