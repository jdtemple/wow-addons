# CurseForge Addon Publishing Guide

Comprehensive guide for publishing and maintaining World of Warcraft addons from the `wow-addons` repository on [CurseForge](https://authors.curseforge.com).

---

## 1. Prerequisites

1. **CurseForge Author Account:** Register or log in at [authors.curseforge.com](https://authors.curseforge.com).
2. **Project Artwork:** A square logo (minimum 512x512 PNG/JPG) showcasing the addon's interface (e.g., the gold nameplate speedometer HUD).
3. **Packaging Tool:** PowerShell (built-in on Windows).

---

## 2. Packaging Release Archives

CurseForge requires addon archives to be structured so that extracting the ZIP puts the root addon folder directly into `World of Warcraft\_retail_\Interface\AddOns\`.

The folder name inside the ZIP **must match the `.toc` file prefix** (e.g. `LazySpeedBiggins`).

### Automated Packaging Script (PowerShell)
Run the automated packaging script from the addon's directory (`lazyspeed-biggins/`) to generate a clean distribution ZIP:

```powershell
# Run from within lazyspeed-biggins/
.\package.ps1
```

The script automatically detects the current version from `LazySpeedBiggins.toc`, stages the files, creates the release ZIP, and cleans up the staging area:
```
lazyspeed-biggins/dist/LazySpeedBiggins-v<version>.zip
```

### Archive Structure Verification
CurseForge expects this exact structure inside the archive:
```
LazySpeedBiggins-v3.4.zip
└── LazySpeedBiggins/
    ├── LazySpeedBiggins.lua
    ├── LazySpeedBiggins.toc
    └── README.md
```

---

## 3. Creating the Project on CurseForge

1. Navigate to the [CurseForge Author Dashboard](https://authors.curseforge.com).
2. Click **Start a Project** (or **Create Project**).
3. Fill in the project details:

| Field | Recommended Value | Notes |
| :--- | :--- | :--- |
| **Game** | `World of Warcraft` | Retail |
| **Project Name** | `LazySpeed Biggins` | Public display name |
| **Project Slug** | `lazyspeed-biggins` | URL: `curseforge.com/wow/addons/lazyspeed-biggins` |
| **Summary** | *High-performance flight, swim & movement speedometer with nameplate-style HUD and Blizzard Gold UI.* | Max 200 characters |
| **Primary Category** | `Interface` $\rightarrow$ `Unit Frames` or `Action Bars` | Also tag `Miscellaneous` / `Map & Minimap` |
| **License** | `MIT License` | Matches repository LICENSE |
| **Avatar / Icon** | 512x512 PNG/JPG | Screenshot of the nameplate speedometer HUD |

4. **Description:** Copy and paste the full markdown contents of [`lazyspeed-biggins/README.md`](./lazyspeed-biggins/README.md) into the description editor.

---

## 4. Uploading the Release File

1. In your project dashboard, navigate to the **Files** tab on the left sidebar.
2. Click **Upload File**.
3. Upload `dist\LazySpeedBiggins-v3.4.zip`.
4. Configure the release options:

* **Display Name:** `LazySpeed Biggins v3.4`
* **Release Type:** **Release** (stable public release)
* **Game Version:** Check the boxes for the current live client (e.g. `12.1.0` / current patch)
* **Changelog:**
  ```markdown
  ### v3.4 Release Highlights:
  * Sleek 180px x 20px Nameplate-style integrated status bar with centered numeric telemetry.
  * Modular checkbox triggers: Skyriding/Flight, Swimming, Ground movement, and In-Combat hide.
  * Zero-allocation C++ rendering pipeline with static format string pointers.
  * True script detachment engine (OnUpdate unhooked when inactive) for zero background CPU usage.
  * Full Blizzard Settings integration (/lazyspeed).
  ```
5. Click **Submit File**.

---

## 5. Review & Going Live

* **Moderation Queue:** New projects undergo a standard manual review by CurseForge staff to verify code safety (typically 1 to 24 hours).
* **Live Discovery:** Once approved:
  * The project page is immediately accessible on the web.
  * The addon is indexed by the **CurseForge App**, **WoWUp**, and other addon managers for one-click installation and automatic future updates.

---

## 6. Pushing Future Updates

When releasing a new version (e.g. `v3.5`):
1. Bump the `## Version:` field in `LazySpeedBiggins.toc` and update the version header in `README.md`.
2. Run the packaging command to produce `LazySpeedBiggins-vX.X.zip`.
3. In your CurseForge project dashboard, go to **Files** $\rightarrow$ **Upload File**.
4. Tag the new game version, paste the changelog, and submit. (Subsequent updates to existing projects are approved much faster, often within minutes).
