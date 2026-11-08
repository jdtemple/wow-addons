# AutoJoin Biggins

**AutoJoin Biggins** is a lightweight, purpose-built World of Warcraft addon that automatically accepts party invitations from configurable whitelists (Guildmates, Character Friends, Battle.net Friends, or All Players) with instant popup suppression and zero bloat.

---

## Key Features

- **Event-Driven & Instant:** Executes only when a `PARTY_INVITE_REQUEST` event arrives. Never polls or uses background timers.
- **Granular Whitelist Control:**
  - **Guild Members:** Auto-joins party invites from anyone in your current guild.
  - **Character Friends:** Auto-joins party invites from your in-game friends list.
  - **Battle.net Friends:** Auto-joins party invites from active Battle.net contacts playing WoW.
  - **All Players (Optional):** Opt-in toggle to accept direct invitations from any player (disabled by default for safety).
- **Pause Auto-Accept While AFK:** Automatically pauses auto-acceptance whenever your character is flagged as Away (AFK). Leaves the standard Blizzard invitation popup on screen so you can review and accept when you return.
- **Auto-Switch Active Chat to Group:** Automatically primes your chat input (`chatType`) to **Party** (`/p`), **Raid** (`/ra`), or **Instance** (`/i`) the moment you join a group so you never forget to type in the right channel.
- **Clean Popup Suppression:** Automatically dismisses the standard `PARTY_INVITE` and `PARTY_INVITE_XREALM` confirmation popups on accepted invitations, preventing screen clutter.
- **Untouched Non-Whitelisted Invites:** If a direct invite arrives from someone outside your active filters, the normal Blizzard invitation popup remains completely intact for manual review.
- **Zero Overhead & Zero Dependencies:** Pure standalone Lua (< 15 KB). No Ace3, no bloated libraries, and zero impact on frame rates.
- **Blizzard Settings UI Integration:** Full configuration panel built into the native modern WoW Settings panel under **Options -> AddOns -> Biggins AddOns -> AutoJoin** (or type `/autojoinb`).

---

## Slash Commands

Commands are available via `/autojoinb`. In-game command help is available at any time by typing `/autojoinb ?` or `/autojoinb help`:

| Command                           | Action                                                             |
| :-------------------------------- | :----------------------------------------------------------------- |
| `/autojoinb`                      | Opens the settings panel in the game menu                          |
| `/autojoinb toggle`               | Toggles the master auto-join system on or off                      |
| `/autojoinb guild`                | Toggles auto-accepting invites from Guild members                  |
| `/autojoinb friends`              | Toggles auto-accepting invites from Character Friends              |
| `/autojoinb bnet`                 | Toggles auto-accepting invites from Battle.net Friends             |
| `/autojoinb all`                  | Toggles auto-accepting invites from All Players (Use with caution) |
| `/autojoinb afk`                  | Toggles pausing auto-accept while flagged Away (AFK)               |
| `/autojoinb chat`                 | Toggles automatically switching active chat to group on join       |
| `/autojoinb announce`             | Toggles chat notifications when an invite is auto-accepted         |
| `/autojoinb status`               | Displays your current configuration and filter states in chat      |
| `/autojoinb help`, `/autojoinb ?` | Displays available in-game slash commands and descriptions         |

---

## Installation

### Automatic (via PowerShell)
Run the included build and install script:
```powershell
.\package.ps1 -Install
```

### Manual
1. Copy the `AutoJoinBiggins` folder into your World of Warcraft directory:
   `World of Warcraft\_retail_\Interface\AddOns\AutoJoinBiggins`
2. Restart World of Warcraft or run `/reload`.
3. Type `/autojoinb` or open **Game Menu -> Options -> AddOns -> Biggins AddOns -> AutoJoin** to customize your settings.

---

## Author

- **Biggins** (US-Whisperwind)
