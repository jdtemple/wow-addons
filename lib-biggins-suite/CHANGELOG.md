# Changelog - LibBigginsSuite

All notable changes to **LibBigginsSuite** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.4] - 2026-11-01

### Added
- **`PLAYER_LOGIN` Auto-Refresh:** Added background event listener at `PLAYER_LOGIN` to ensure all installed suite modules and version strings are 100% synchronized in memory before the user opens the options panel.
- **Dynamic Registration Hook:** Submodule registration via `RegisterSubcategory()` now triggers an immediate live refresh of the parent dashboard.
- **Slash Command Refresh:** `/biggins` now executes a live dashboard scan before opening the Blizzard Settings panel.

### Changed
- **Guaranteed `OnShow` Lifecycle:** Parent panel frame is now initialized in an explicitly hidden state (`parentPanel:Hide()`), ensuring Blizzard's settings canvas container triggers a clean hidden-to-shown transition and fires `OnShow` on the very first click.
- **Pre-Population on Construct:** The suite dashboard now runs an initial module scan immediately upon creation to prevent uninitialized or blank row states.
- **Catalog Updates:** Updated fallback versions and feature descriptions for `AutoJoin Biggins` (v1.3.0) and `ChatLink Biggins` (v1.1.0).

---

## [1.0.3] - 2026-10-24

### Added
- **ChatLink Biggins Module:** Registered `ChatLink Biggins` into the suite catalog with live detection and direct `[ Configure ]` jump navigation.

---

## [1.0.2] - 2026-10-24

### Added
- **SafeRelease Biggins Module:** Registered `SafeRelease Biggins` into the suite catalog with live detection and direct `[ Configure ]` jump navigation.

---

## [1.0.1] - 2026-10-22

### Added
- **Interactive Suite Dashboard:** Added dynamic module list to the root settings panel with loaded state checks, green version tags, and `(Available on CurseForge)` badges.
- **Direct Subpanel Navigation:** Added `[ Configure ]` buttons for each detected addon to jump straight to its child settings panel.
- **Registered Modules:** Added initial catalog entries for `AutoJoin`, `LazySpeed`, `Perf`, and `SummonPet`.

---

## [1.0.0] - 2026-10-21

### Added
- **Initial Release** of LibBigginsSuite-1.0.
- **Unified Parent Settings Category:** Creates and manages the top-level `Biggins AddOns` category in Blizzard's modern Canvas Settings UI.
- **Shared Suite Assets:** Centralized Mechagnome suite banner (`suite-logo.jpg`) and author engineering philosophy header.
- **Child Registration API:** Provided `LibBigginsSuite:RegisterSubcategory(addonDir, panel, shortName)` helper for clean submodule attachment.
- **Slash Command:** Added `/biggins` command to open the root suite settings directly.
