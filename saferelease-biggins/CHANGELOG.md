# Changelog - SafeRelease Biggins

All notable changes to **SafeRelease Biggins** will be documented in this file.

---

## [1.0.0] - 2026-10-24

### Added
- Initial release of **SafeRelease Biggins**.
- **Zero-Taint Secure Hooking:** Intercepts `StaticPopup` death dialogs via `hooksecurefunc` without replacing or tainting protected Blizzard frame scripts.
- **Click-Interception Button Overlay:** Places an inert overlay button physically over the native "Release Spirit" button during lock periods, making accidental clicks impossible.
- **Three Guard Mechanisms:**
  - **Countdown Timer Delay (Default):** 1 to 10 second visual countdown on the button (`Release (5s)...`).
  - **Modifier-Key Hold:** Hides the button until `Alt`, `Shift`, or `Ctrl` is held down.
  - **Hybrid Mode:** Countdown delay with instant modifier-key bypass.
- **Full Raid Wipe Detection:** Automatically detects when all raid members are dead and drops the guard immediately so the raid team can release and run back without delay.
- **Usable Self-Resurrection Bypass:** Leaves the dialog unblocked if a Shaman Reincarnation, Warlock Soulstone, or other self-rez option is active.
- **Protected Content Scopes:** Independent toggles for Raids (Default: ON), Mythic+ Dungeons, Regular Dungeons, and Delves & Scenarios.
- **Modern Blizzard Canvas UI:** Full settings category under `Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease` with top-right `[ Defaults ]` button and master enable toggle with dynamic control attenuation.
- **Slash Commands:** Comprehensive command suite via `/saferelease` or `/srb` (`toggle`, `countdown`, `modifier`, `hybrid`, `raids`, `status`, `defaults`, `options`).
- **Biggins Suite Integration:** Embedded `LibBigginsSuite` integration with zero external dependencies.
