# CurseForge Addon Publishing Guide

Comprehensive guide for packaging, publishing, and updating World of Warcraft addons from this repository on [CurseForge](https://authors.curseforge.com).

---

## 1. Prerequisites

1. **CurseForge Author Account:** Register or log in at [authors.curseforge.com](https://authors.curseforge.com).
2. **Project Artwork:** A square logo (minimum 512x512 PNG/JPG, ideally 1024x1024) showcasing the addon's identity (e.g. `logo.jpg` in the addon folder).
3. **Gallery Screenshots:** 2-4 clean screenshots showing settings, keybinds, or in-game usage placed in the addon's `screenshots/` directory.
4. **PowerShell:** Built-in on Windows for running the automated release packager.

---

## 2. Packaging Release Archives

CurseForge requires addon archives to be structured so that extracting the ZIP puts the root addon folder directly into `World of Warcraft\_retail_\Interface\AddOns\`.

The folder name inside the ZIP **must match the `.toc` file prefix** (e.g. `SummonPetBiggins` or `LazySpeedBiggins`).

### Automated Packaging Script

Each addon directory contains its own `package.ps1` script. Run it from within the specific addon folder:

```powershell
# Example: Packaging SummonPet Biggins
cd summonpet-biggins
.\package.ps1

# Example: Packaging LazySpeed Biggins
cd lazyspeed-biggins
.\package.ps1
```

The script automatically:
1. Reads the current version from the addon's `.toc` file (`## Version:`).
2. Creates a clean staging directory with the proper addon folder name.
3. Copies all required release files (`.lua`, `.toc`, `.xml`, `README.md`, `CHANGELOG.md`).
4. Generates a compressed archive in `dist/<AddonName>-v<Version>.zip`.
5. Cleans up temporary staging folders.

### Archive Structure Verification

CurseForge expects this exact structure inside the archive:

```text
<AddonName>-v<Version>.zip
└── <AddonName>/
    ├── <AddonName>.toc
    ├── <AddonName>.lua
    ├── Bindings.xml (if applicable)
    ├── README.md
    └── CHANGELOG.md
```

---

## 3. Creating the Project on CurseForge

1. Navigate to the [CurseForge Author Dashboard](https://authors.curseforge.com).
2. Click **Start a Project** (or **Create Project**).
3. Select **World of Warcraft** as the game.
4. Fill in the project details:

| Field                | Description & Guidance                              | Repository Examples                                         |
| :------------------- | :-------------------------------------------------- | :---------------------------------------------------------- |
| **Game**             | `World of Warcraft`                                 | Retail                                                      |
| **Project Name**     | Public display name                                 | `SummonPet Biggins` / `LazySpeed Biggins`                   |
| **Project Slug**     | URL identifier (`curseforge.com/wow/addons/<slug>`) | `summonpet-biggins` / `lazyspeed-biggins`                  |
| **Summary**          | Punchy 1-2 sentence description (max 200 chars)     | Short summary from the addon's `README.md`                  |
| **Primary Category** | Primary browse category                             | `Pet Battles` / `Companions` or `Unit Frames` / `Interface` |
| **License**          | Project open-source license                         | `MIT License` (matches repository root `LICENSE`)           |
| **Avatar / Icon**    | Square 512x512+ PNG/JPG                             | Use the addon's `logo.jpg`                                  |

5. **Description:** Copy and paste the markdown contents of the addon's `README.md` into the CurseForge description editor.
6. **Gallery:** Upload the images from the addon's `screenshots/` directory (e.g. options panel, keybindings, commands).
7. **Linking External GitHub Issue Tracker:**
   CurseForge buries the external issue tracker redirect setting in the legacy project interface:
   * From your project overview, click **Manage Project** (top right).
   * Click **Issues** from the menu (this redirects to the legacy CurseForge issues page).
   * On the legacy page, click the **Issues** tab.
   * Under **Issue Tracker**, change the selection to **External**.
   * Paste your GitHub repository issues link:
     ```
     https://github.com/<YourUsername>/<YourRepo>/issues
     ```
   * Click **Save Changes**. Clicking "Issues" on your public project page will now redirect straight to GitHub.

---

## 4. Uploading the Release File

1. In your project dashboard, navigate to the **Files** tab on the left sidebar.
2. Click **Upload File**.
3. Select the generated archive from `dist/<AddonName>-v<Version>.zip`.
4. Configure the release options:
   - **Display Name:** `<Addon Name> v<Version>` (e.g. `SummonPet Biggins v1.0.2` or `LazySpeed Biggins v3.4`)
   - **Release Type:** **Release** (stable public build)
   - **Game Version:** Check the boxes for the live client versions supported in your `.toc` (e.g. current live patches).
   - **Changelog:** Copy and paste the latest release notes from the top of the addon's `CHANGELOG.md`.
5. Click **Submit File**.

---

## 5. Review & Going Live

- **Moderation Queue:** Initial submissions for a new addon undergo standard manual review by CurseForge staff (typically 1 to 24 hours).
- **Live Discovery:** Once approved:
  - The project page goes live on the CurseForge website.
  - The addon is automatically indexed by the **CurseForge App**, **WoWUp**, and other addon managers for one-click installation and automated updates.

---

## 6. Pushing Future Updates

When releasing an update for any addon:
1. Update the `## Version:` field in the addon's `.toc` file and add the release notes under a new version heading in `CHANGELOG.md`.
2. Run `.\package.ps1` from within the addon directory to produce the new release ZIP.
3. In the CurseForge dashboard for that addon, go to **Files** -> **Upload File**.
4. Tag the supported game versions, paste the new section from `CHANGELOG.md`, and submit. Subsequent version uploads for approved projects are typically approved in minutes.
