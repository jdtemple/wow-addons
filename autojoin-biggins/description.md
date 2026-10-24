# AutoJoin Biggins

**AutoJoin Biggins** is an ultra-lightweight, dedicated World of Warcraft addon that automatically accepts party invitations from configurable sources:

- **Guild Members** (Current guildmates)
- **Character Friends** (In-game friends list)
- **Battle.net Friends** (Active Battle.net friends playing WoW)
- **All Players** (Optional opt-in toggle; off by default)

### Features
- **Auto-Switch Chat Channel:** Automatically sets your active chat channel to **Party** (`/p`), **Raid** (`/ra`), or **Instance** (`/i`) as soon as you join a group.
- **Instant & Event-Driven:** Hooks into `PARTY_INVITE_REQUEST` with zero background polling and zero frame stutter.
- **Popup Suppression:** Automatically dismisses the standard party invitation confirmation dialogs on accepted invites.
- **Safe Fallback:** If an invite arrives from someone outside your active filters, the normal Blizzard dialog remains untouched for manual handling.
- **Native Settings UI:** Integrates directly into **Game Menu -> Options -> AddOns -> Biggins AddOns -> AutoJoin**.
- **Slash Commands:** Quick toggles via `/aj` or `/autojoin`.

---

## In-Game Configuration

Configure your preferences via the native Blizzard Settings panel (**Game Menu -> Options -> AddOns -> Biggins AddOns -> AutoJoin**) or by typing:

```
/autojoin
```
*(or `/aj`)*
