# LibBigginsSuite Changelog

## v1.0.7

### Added
- **Scrollable Suite Overview Canvas:** Embedded a modern native `ScrollFrameTemplate` with `MinimalScrollBar` into the Biggins AddOns parent settings panel. All suite modules, descriptions, and configure buttons are now smoothly scrollable via mousewheel and scrollbar thumb drag, eliminating bottom-frame border bleeding and supporting infinite future module expansion.

---
## v1.0.6

### Changed
- **Dynamic TOC Metadata Versioning:** Eliminated hardcoded fallback version numbers across all suite modules; dynamically queries `## Version:` directly from each addon's `.toc` file at runtime via `C_AddOns.GetAddOnMetadata` with safe legacy fallback.
- **Alphabetical Module Ordering:** Standardized module rows into alphabetical order matching the native Blizzard settings category tree.
- **Streamlined Module Definitions:** Consolidated category ID resolution (`GetAddOnCategoryID`) and load status checks (`IsAddOnLoadedSafe`), removing duplicate anonymous functions.

---

## v1.0.5

### Added
- **Knowledge Biggins Integration:** Added Knowledge Biggins to the suite overview module list.

### Fixed
- **UI Collision Fix:** Constrained module row descriptions to the left of the `[ Configure ]` button with word wrapping enabled to prevent text overlap.
- **Left-Justification Fix:** Explicitly set left horizontal justification on header text and overview descriptions to resolve center-justified bullet list formatting.

---

## v1.0.4

### Changed
- **Reliable Registration:** Enhanced subcategory registration logic for instantaneous module detection and reliable first-click display in Blizzard settings.
