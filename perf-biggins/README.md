# Perf Biggins

**Perf Biggins** is a lightweight, high-performance telemetry HUD for World of Warcraft that displays an integrated tri-bar meter for **FPS**, **World Latency**, and **Home Latency** styled after the classic Blizzard gold and dark slate aesthetic of LazySpeed.

---

## Key Features

- **Tri-Bar Performance HUD:**
  - **FPS Bar:** Real-time frames per second with dynamic color shifts (Green &ge; 60, Yellow 30-59, Red < 30).
  - **World Latency Bar:** Latency to the combat/gameplay server (abilities, encounters, player positions). Color coded from optimal green (< 50ms) to lag spike red (> 200ms).
  - **Home Latency Bar:** Latency to the realm server (chat, auction house, guild system). Compare with World latency to isolate local Wi-Fi issues vs. Blizzard server load.
- **Zero Memory Churn:** Uses pre-cached format pointers with native C++ string formatting (`FontString:SetFormattedText`). Zero runtime string allocations and zero garbage collection spikes.
- **Dirty Tracking & Throttling:** Runs at 20 FPS (0.05s) and skips redraws whenever values remain unchanged, resulting in virtually 0.00ms idle CPU impact.
- **Dynamic Layout & Collapse:** Every bar can be independently toggled on or off. Active bars seamlessly snap together, and the container frame dynamically recalculates its height without empty space.
- **Movable & Lockable:** Drag the entire tri-bar HUD anywhere on your screen with Left-Click. Easily lock it via settings or `/pb lock` to prevent accidental movement.
- **Combat Visibility Toggle:** Option to automatically hide the HUD during combat and completely detach the update loop for zero combat overhead.
- **Blizzard Settings Integration:** Full configuration panel built into the native WoW Settings panel under **Options -> AddOns -> Biggins AddOns -> Perf** (or type `/pb`).

---

## Slash Commands

Commands are available via `/perf` or `/pb`:

| Command      | Action                                                  |
| :----------- | :------------------------------------------------------ |
| `/pb`        | Opens the settings panel in the game menu               |
| `/pb fps`    | Toggles the FPS status bar on or off                    |
| `/pb world`  | Toggles the World Latency status bar on or off          |
| `/pb home`   | Toggles the Home Latency status bar on or off           |
| `/pb lock`   | Toggles frame position lock (prevents/enables dragging) |
| `/pb combat` | Toggles automatically hiding the HUD while in combat    |
| `/pb reset`  | Resets the frame position to the center of your screen  |
| `/pb status` | Displays current settings and bar visibility in chat    |

---

## Installation

### Automatic (via PowerShell)
Run the included packaging script:
```powershell
.\package.ps1 -Install
```

### Manual
1. Copy the `PerfBiggins` folder into your World of Warcraft directory:
   `World of Warcraft\_retail_\Interface\AddOns\PerfBiggins`
2. Restart World of Warcraft or run `/reload`.
3. Type `/pb` or open **Game Menu -> Options -> AddOns -> Biggins AddOns -> Perf** to customize settings, or drag the HUD to your preferred screen location.

---

## Author

- **Biggins** (US-Whisperwind)
