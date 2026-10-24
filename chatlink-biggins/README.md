# ChatLink Biggins

**ChatLink Biggins** is an ultra-lightweight, dedicated World of Warcraft addon designed to make web links shared in chat clickable for instant, frictionless copy-pasting (`Ctrl+C` -> `Enter`).

---

## Key Features

- **Draggable Blizzard Factory Dialog:** Authentic Blizzard factory dialog frame that is freely draggable with left-click. Position is automatically remembered across sessions and reloads, with a 1-click `[ Reset Position ]` button in settings.
- **Single-Pattern Protocol Isolation:** Matches standard web protocols (`https://` and `http://`) with strict boundary isolation (`[^%s|]+`). Eliminates pattern collisions, chat loops, and false positives completely.
- **Sentence Punctuation Stripping:** Automatically trims trailing punctuation (`.,;:!?)[]'"`) so links copied at the end of sentences remain clean and valid in your browser.
- **Pipe Escape Protection:** Safely respects WoW's internal `|` escape sequences, ensuring item links, spell links, and player names immediately adjacent to a URL are never corrupted.
- **Fast 0.001ms Exit:** For messages without web links, the filter exits immediately via substring check without creating any string allocations or garbage collector churn.
- **Modern Blizzard Canvas Settings UI:** Integrated directly into `Game Menu -> Options -> AddOns -> Biggins AddOns -> ChatLink` with top-right `[ Defaults ]` button, master toggle, and dynamic control attenuation.
- **Zero Overhead & Zero Dependencies:** Under 30 KB memory footprint, 0.00% CPU overhead, and zero external Ace3 bloat.

---

## In-Game Configuration

Configure your preferences via the native Blizzard Settings panel (**Game Menu -> Options -> AddOns -> Biggins AddOns -> ChatLink**) or by typing:

```
/chatlink
```
*(or `/clb`)*

---

## Slash Commands

Commands are available via `/chatlink` or `/clb`:

| Command         | Action                                        |
| :-------------- | :-------------------------------------------- |
| `/clb`          | Opens the settings panel in the game menu     |
| `/clb toggle`   | Toggles ChatLink Biggins master enable state  |
| `/clb brackets` | Toggles `[ ]` brackets around chat links      |
| `/clb reset`    | Resets popup dialog position to screen center |
| `/clb status`   | Displays current addon configuration in chat  |
| `/clb defaults` | Restores all settings to default values       |

---

## Installation

### Automatic (via PowerShell)
Run the included packaging script:
```powershell
.\package.ps1 -Install
```

### Manual
1. Copy the `ChatLinkBiggins` folder into your World of Warcraft directory:
   `World of Warcraft\_retail_\Interface\AddOns\ChatLinkBiggins`
2. Restart World of Warcraft or run `/reload`.
3. Type `/clb` or open **Game Menu -> Options -> AddOns -> Biggins AddOns -> ChatLink** to customize your settings.
