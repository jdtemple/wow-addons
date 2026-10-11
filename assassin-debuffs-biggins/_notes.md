# Project Findings & Abandonment Rationale

**Project:** Assassin Debuffs Biggins  
**Target Environment:** World of Warcraft Retail (Patch 12.1.0, Build 69933 - *Midnight*)  
**Specialization:** Rogue (Assassination)  
**Status:** Abandoned / Archived for Posterity  
**Date:** October 11, 2026  

---

## 1. Executive Summary

This addon was conceived to provide clean, high-performance gradient halo borders around Blizzard's default nameplate debuff icons for Assassination Rogues (*Garrote*, *Rupture*, *Deathstalker's Mark*, *Kingsbane*, and *Deathmark*).

During in-combat testing in World of Warcraft Retail Patch 12.1.0 (*Midnight*), we discovered that Blizzard has fundamentally redesigned the Addon API around combat data protection. In-combat enemy auras are now strictly classified as **Secret Values**. Because third-party addons cannot read, compare, format, or evaluate secret values during combat, it is structurally impossible for third-party addon code to identify which nameplate button corresponds to which debuff. Furthermore, any attempt to hook or overlay secure nameplate aura items triggers Blizzard's combat protection barrier (*Action Blocked* popup).

As a result, this concept cannot function in the *Midnight* client environment and has been formally abandoned.

---

## 2. WoW 12.0 / 12.1 *Midnight* Architecture: The "Secret Values" System

In Patch 12.0 (*Midnight*), Blizzard implemented an overhaul of the Addon API to eliminate combat automation and real-time guidance tools. This system introduces a new data type and execution sandbox:

1. **Secret Values (`issecretvalue`):**
   - Core combat data returned by unit APIs (such as `C_UnitAuras`, `UnitHealth`, and nameplate aura containers) are wrapped in opaque "black boxes."
   - When inspected by Lua, these values return `type = number` or `type = string`, but `issecretvalue(val)` evaluates to `true`.
   - Any attempt by untrusted addon code to compare (`==`), format (`tostring`), perform arithmetic on, or index tables with a secret value either produces `<secret>` or raises a fatal Lua error (`attempt to compare a secret number value`).

2. **Execution Context (`canaccesssecrets`):**
   - Blizzard's internal FrameXML code runs with `canaccesssecrets() == true`.
   - All third-party addon code runs in an untrusted sandbox with `canaccesssecrets() == false`.
   - Addon functions cannot elevate permissions or unwrap secret values.

3. **CVar Enforcement:**
   - Under `secretCombatRestrictionsForced`, combat restrictions immediately activate the moment the player or unit enters combat.
   - Out of combat, unit aura APIs return standard plaintext numbers and strings (`isSecret = false`).
   - The instant combat begins (e.g. attacking a training dummy or enemy NPC), all aura properties (`spellId`, `icon`, `name`, `duration`, `expirationTime`, `sourceUnit`) convert to Secret Values.

---

## 3. Detailed Technical Findings

### 3.1 Out-of-Combat vs. In-Combat State Flip
During diagnostic dump logging (`/adb debug`), we captured the exact behavioral difference between states:

- **Out of Combat (or after dropping target and backing off):**
  - `aura.spellId` = `703` (`isSecret = false`)
  - `aura.icon` = `7195162` (`isSecret = false`)
  - `aura.name` = `"Garrote"` (`isSecret = false`)
  - `aura.sourceUnit` = `"player"` (`isSecret = false`)
  - `button.spellID` = `703` (`isSecret = false`)
  - Halos were able to resolve keys (`key: garrote`, `key: deathstalker`) and render.

- **In Combat (during normal opener on target):**
  - `aura.spellId` = `<secret>` (`isSecret = true`)
  - `aura.icon` = `<secret>` (`isSecret = true`)
  - `aura.name` = `<secret>` (`isSecret = true`)
  - `aura.duration` = `<secret>` (`isSecret = true`)
  - `aura.sourceUnit` = `<secret>` (`isSecret = true`)
  - `button.spellID` = `<secret>` (`isSecret = true`)
  - `button.auraInstanceID` = `<secret>` (`isSecret = true`)
  - `C_UnitAuras.GetUnitAuras("target")` = `failed or nil (ok=false)`
  - Direct comparisons (`sid == 703` or `TRACKED_SPELLS[sid]`) fail or return `<secret>`.
  - Resolution completely fails (`key: none`), rendering zero halos.

### 3.2 Secure Engine Taint & Action Blocked Popup
When attempting to hook `NamePlateAuraItemMixin:SetAura` or pool acquisition via `hooksecurefunc` to refresh halo geometries dynamically, Blizzard's engine marks the nameplate item execution path as tainted.

When combat actions occur on that unit, the engine encounters tainted code touching Blizzard-owned nameplate widgets and throws the native security modal:
> *"AssassinDebuffsBiggins has been blocked from an action only available to the Blizzard UI. You can disable this addon and reload the UI."*

This confirmed that Blizzard treats enemy nameplate aura rendering as a protected Blizzard-only action in *Midnight*.

---

## 4. Industry Context & Precedent

This barrier is not specific to this addon. The wider World of Warcraft development community experienced the same wall across the Patch 12.0 release:

- **WeakAuras:** The core development team officially announced that WeakAuras cannot support real-time combat aura tracking in *Midnight* due to the inability to inspect live combat state.
- **TellMeWhen:** Displays explicit warnings informing players that enemy auras cannot be tracked during combat.
- **Plater Nameplates:** Had to strip custom aura filtering logic and now defers to Blizzard's native aura display mechanisms, using `issecretvalue` defensive checks throughout its codebase to avoid crashes.

---

## 5. Conclusion

Because World of Warcraft Patch 12.1.0 strictly prohibits untrusted third-party addons from reading, identifying, or modifying enemy debuff widgets on nameplates while in combat, the core premise of this addon cannot be realized without violating Blizzard's security model.

The codebase is preserved in this repository for historical documentation, diagnostic references, and architectural analysis.
