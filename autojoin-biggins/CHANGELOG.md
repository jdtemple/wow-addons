# Changelog - AutoJoin Biggins

All notable changes to **AutoJoin Biggins** will be documented in this file.

---

## [1.1.0] - 2026-10-22

### Added
- **Modern Canvas Options UI:** Migrated settings panel to Blizzard's modern Canvas layout (`Settings.RegisterCanvasLayoutCategory`) for pixel-perfect typography, aligned layout, and native look.
- **Master Enable Toggle:** Added top-level master toggle to easily enable or disable the entire invite auto-accept engine with a single click.
- **Top-Right Defaults Button:** Standardized top-right `[ Defaults ]` button matching Blizzard settings conventions to quickly restore default filter states.
- **Dynamic Control Attenuation:** Automatically grays out and disables all child invite filters when the master enable toggle is unchecked.

---

## [1.0.0] - 2026-10-21

### Added
- Initial release of **AutoJoin Biggins**.
- Event-driven party invite auto-acceptance via `PARTY_INVITE_REQUEST`.
- Filter support for **Guild Members**, **Character Friends**, **Battle.net Friends**, and **All Players**.
- Configurable **Auto-Switch Chat Channel** feature: automatically primes active chat input to **Party** (`/p`), **Raid** (`/ra`), or **Instance** (`/i`) upon joining a group.
- Automatic suppression of Blizzard `PARTY_INVITE` and `PARTY_INVITE_XREALM` popup dialogs.
- Modern Blizzard Settings panel integration (`Settings.RegisterAddOnCategory`) with backward compatibility.
- Comprehensive `/autojoin` and `/aj` slash command suite (`toggle`, `guild`, `friends`, `bnet`, `all`, `chat`, `announce`, `status`).
- Packaging script `package.ps1` with optional `-Install` switch to sync to local retail client.
