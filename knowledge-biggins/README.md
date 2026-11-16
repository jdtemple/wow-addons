# Knowledge Biggins

**Knowledge Biggins** is a lightweight, zero-maintenance World of Warcraft addon that provides an instant, one-click popup button to study and consume profession knowledge items (like shards, dragon/void shards, treatises, and skill books) directly from your bags without menu diving.

---

### Key Features

* **Universal & Future-Proof:** Reads live tooltip text directly from the game engine (`C_TooltipInfo`) using standard Blizzard pattern matching. Works out of the box for Mining, Herbalism, Skinning, crafting treatises, and one-time treasure books across all expansions. No static item ID databases to maintain!
* **One-Click Consumer:** When an unstudied knowledge item is in your bags, a clean button appears. Click it once to study the item on the spot.
* **Auto-Advancing Queue:** If you have multiple items in your bags (e.g. 2 Cloudy Quartz and 1 Treatise), the button displays the stack count and advances to the next item with each click, auto-hiding once all knowledge items are consumed.
* **Fully Draggable & Movable:** Hold **`Shift + Left-Click Drag`** to reposition the button anywhere on your screen. The button remembers its exact coordinates in `KnowledgeBigginsDB`.
* **Native Blizzard UI Scaling:** Fully parented to `UIParent` so it seamlessly inherits and auto-scales with Blizzard's stock Graphics -> UI Scale slider, maintaining action bar scale at all times.
* **Zero Combat Taint:** Strictly respects Blizzard combat lockdown. If items enter your bags during combat, button creation and updates are deferred until combat drops (`PLAYER_REGEN_ENABLED`).

---

### Slash Commands

* `/knowledgeb` - Open the Blizzard Settings options panel.
* `/knowledgeb lock` - Toggle locking the button position (prevents dragging).
* `/knowledgeb show` - Toggle always showing the button even with an empty bag.
* `/knowledgeb reset` - Reset the button position to default center screen.
* `/knowledgeb scan` - Force an immediate bag scan for unconsumed knowledge items.
* `/knowledgeb help` or `/knowledgeb ?` - Show available slash commands.

---

### Author & Compatibility

* **Author:** Biggins (US-Whisperwind)
* **Compatibility:** World of Warcraft: Midnight / The War Within (Retail 11.x - 12.x)
* **Suite:** Part of the Biggins Addon Family.
