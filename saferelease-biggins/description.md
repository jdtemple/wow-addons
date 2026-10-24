# SafeRelease Biggins

**SafeRelease Biggins** is an ultra-lightweight, dedicated World of Warcraft addon designed to prevent accidental and reflexive "Release Spirit" clicks during wipes across raids, Mythic+ dungeons, and delves when combat resurrections, soulstones, or mass resurrections are available.

### Features
- **Zero-Taint Secure Hooking:** Hooks into Blizzard death dialogs with zero script replacement and zero Lua execution taint.
- **Physical Click Interceptor:** An inert overlay button physically covers the Release button during lockouts, making accidental clicks impossible.
- **3 Flexible Guard Modes:**
  - **Countdown Delay (Default):** 1-10 second visual countdown on the button (`Release (5s)...`).
  - **Modifier-Key Hold:** Locks the button until `Alt`, `Shift`, or `Ctrl` is held down (`Hold ALT`).
  - **Hybrid:** Visual countdown with instant modifier bypass indicator (`Hold ALT (5s)`).
- **Full Raid Wipe Detection (Optional):** Can automatically detect when the entire raid group is dead and unlock release for the run-back (Default: OFF).
- **Self-Resurrection Bypass:** Automatically leaves the dialog unblocked if a Shaman Reincarnation, Warlock Soulstone, or other self-rez option is ready.
- **Modular Content Scoping:** Independent toggles for Raids (Default: ON), Mythic+ Dungeons, Dungeons (Normal, Heroic, Mythic 0), and Delves & Scenarios. Never blocks release in open world or PvP.
- **Native Settings UI:** Integrates directly into **Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease**.
- **Slash Commands:** Quick toggles, configuration, and status via `/srb` or `/saferelease`.

---

## In-Game Configuration

Configure your preferences via the native Blizzard Settings panel (**Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease**) or by typing:

```
/saferelease
```
*(or `/srb`)*
