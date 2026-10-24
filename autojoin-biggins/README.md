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
- **Auto-Switch Active Chat to Group:** Automatically primes your chat input (`chatType`) to **Party** (`/p`), **Raid** (`/ra`), or **Instance** (`/i`) the moment you join a group so you never forget to type in the right channel.
- **Clean Popup Suppression:** Automatically dismisses the standard `PARTY_INVITE` and `PARTY_INVITE_XREALM` confirmation popups on accepted invitations, preventing screen clutter.
- **Untouched Non-Whitelisted Invites:** If a direct invite arrives from someone outside your active filters, the normal Blizzard invitation popup remains completely intact for manual review.
- **Zero Overhead & Zero Dependencies:** Pure standalone Lua (< 15 KB). No Ace3, no bloated libraries, and zero impact on frame rates.
- **Blizzard Settings UI Integration:** Full configuration panel built into the native modern WoW Settings panel under **Options -> AddOns -> AutoJoin Biggins**.

---

## Slash Commands

Commands are available via `/autojoin` or `/aj`:

| Command        | Action                                                             |
| :------------- | :----------------------------------------------------------------- |
| `/aj`          | Opens the settings panel in the game menu                          |
| `/aj toggle`   | Toggles the master auto-join system on or off                      |
| `/aj guild`    | Toggles auto-accepting invites from Guild members                  |
| `/aj friends`  | Toggles auto-accepting invites from Character Friends              |
| `/aj bnet`     | Toggles auto-accepting invites from Battle.net Friends             |
| `/aj all`      | Toggles auto-accepting invites from All Players (Use with caution) |
| `/aj chat`     | Toggles automatically switching active chat to group on join       |
| `/aj announce` | Toggles chat notifications when an invite is auto-accepted         |
| `/aj status`   | Displays your current configuration and filter states in chat      |

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
3. Type `/aj` or open **Game Menu -> Options -> AddOns -> AutoJoin Biggins** to customize your settings.

---

## Author

- **Biggins** (US-Whisperwind)
