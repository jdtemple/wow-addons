# LibBigginsSuite

Canonical single source of truth for the shared Biggins AddOns settings category and suite management library.

## Overview

`LibBigginsSuite` provides:
- A unified **Biggins AddOns** top-level category in the modern World of Warcraft Settings UI.
- The Mechagnome suite logo banner (`suite-logo.jpg`).
- The Biggins AddOn suite philosophy statement.
- An interactive suite dashboard showing active/installed Biggins addons and `(Available on CurseForge)` badges for uninstalled addons.
- Helper method `LibBigginsSuite:RegisterSubcategory(addonDir, panel, shortName)` for child addons to attach subpanels cleanly.
- The `/biggins` slash command to open the suite settings directly.

## Distribution Architecture

This directory is the **Single Source of Truth (SSOT)**. 

Do not edit copies of `LibBigginsSuite.lua` or `suite-logo.jpg` inside individual addon directories. Instead:
1. Make all suite updates here in `lib-biggins-suite/`.
2. Run `..\sync-suite.ps1` from the repository root to synchronize changes directly to your live World of Warcraft Retail client.
3. Each addon's `package.ps1` script automatically pulls the latest version directly into the staging archive before building release packages for CurseForge and Wago. The individual addon source directories remain 100% free of duplicated library files.
