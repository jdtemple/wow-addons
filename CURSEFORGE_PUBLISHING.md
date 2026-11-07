# CurseForge Addon Publishing Guide

Comprehensive guide for packaging, publishing, and automating World of Warcraft addon releases for the Biggins AddOns suite on [CurseForge](https://authors.curseforge.com).

---

## 1. Automation vs. Manual Matrix

This repository uses a native **GitHub Actions CI/CD Pipeline** that automatically packages and publishes releases on every push to `main`. Because CurseForge does not expose API endpoints for storefront metadata, project setup and media remain a one-time manual task in the CurseForge portal.

| Area                | Component              | Method                | Details                                                                            |
| :------------------ | :--------------------- | :-------------------- | :--------------------------------------------------------------------------------- |
| **Release Files**   | `.zip` Packaging       | **Automated (CI/CD)** | GitHub Actions runner executes `package.ps1` in an ephemeral VM                    |
| **Release Upload**  | Submitting Builds      | **Automated (CI/CD)** | Native `curl.exe` streams `.zip` directly to CurseForge Upload REST API            |
| **Release Notes**   | Changelog Field        | **Automated (CI/CD)** | 1:1 verbatim text read directly from the addon's `CHANGELOG.md`                    |
| **Game Versions**   | Patch Compatibility    | **Automated (CI/CD)** | Auto-detected from active Retail game version endpoints                            |
| **Git Release Tag** | Version Tagging        | **Automated (CI/CD)** | Automatically tags the commit with `<addon>-<version>` (e.g. `perf-biggins-1.4.0`) |
| **Storefront Icon** | Project Avatar         | **Manual (One-time)** | Set once in CurseForge Author Portal using addon `logo.jpg`                        |
| **Media / Gallery** | Screenshots            | **Manual (Optional)** | Uploaded via CurseForge Author Portal Media tab                                    |
| **Storefront Text** | Project Description    | **Manual (One-time)** | Copied from addon `description.md` or `README.md` into web editor                  |
| **Issue Tracker**   | External GitHub Issues | **Manual (One-time)** | Configured once in project settings to redirect to GitHub                          |

---

## 2. Active Addons & CurseForge Project IDs

Each addon folder in this monorepo maps to a specific numeric **Project ID** on CurseForge, configured in [`scripts/addons-config.json`](file:///C:/Code/wow-addons/scripts/addons-config.json):

| Addon Directory       | Public Display Name | CurseForge Project ID | Primary Category          |
| :-------------------- | :------------------ | :-------------------- | :------------------------ |
| `autojoin-biggins`    | AutoJoin Biggins    | `1760364`             | Chat & Communication      |
| `chatlink-biggins`    | ChatLink Biggins    | `1763882`             | Chat & Communication      |
| `lazyspeed-biggins`   | LazySpeed Biggins   | `1678350`             | Action Bars / Movement    |
| `perf-biggins`        | Perf Biggins        | `1760380`             | Unit Frames / Performance |
| `saferelease-biggins` | SafeRelease Biggins | `1763542`             | Buffs & Debuffs / Utility |
| `summonpet-biggins`   | SummonPet Biggins   | `1747339`             | Pet Battles / Companions  |

---

## 3. Supported Game Versions & Compatibility Whitelist

To protect against accidentally tagging unsupported game versions (such as Classic, Era, Forever, or legacy 11.x expansions), game version targeting is controlled strictly via a whitelist in [`scripts/addons-config.json`](file:///C:/Code/wow-addons/scripts/addons-config.json).

### Suite-Wide Default
By default, all addons inherit the top-level `supportedGameVersions` array:
```json
{
  "supportedGameVersions": [
    "12.1.7",
    "12.1.5"
  ],
  "addons": { ... }
}
```

### Per-Addon Overrides
If an individual addon ever has unique compatibility requirements (e.g. it only supports a specific patch, or targets an upcoming PTR/beta build ahead of the rest of the suite), specify `supportedGameVersions` directly inside that addon's block:
```json
"addons": {
  "special-addon": {
    "name": "Special Biggins",
    "projectId": 1234567,
    "supportedGameVersions": [
      "12.1.7"
    ]
  }
}
```

### Resolution Hierarchy
When publishing, [`scripts/publish-curseforge.ps1`](file:///C:/Code/wow-addons/scripts/publish-curseforge.ps1) resolves version IDs using this order of precedence:
1. **Per-Addon Override:** Checks for `supportedGameVersions` in the addon's configuration block.
2. **Suite-Wide Default:** Falls back to the root `supportedGameVersions` list.
3. **CurseForge Filter:** Queries CurseForge strictly for **Retail** (`gameVersionTypeID: 517`) and matches **only** the exact version strings declared in the whitelist.

### Coordinating with `.toc` (`## Interface:`)
Always keep the `.toc` interface directive coordinated with your target versions:
```text
## Interface: 120107, 120105
```
- `120105` = 12.1.5 (current live retail build)
- `120107` = 12.1.7 (upcoming patch)
---

## 4. One-Time Pipeline Setup: GitHub Configuration

### A. Add CurseForge API Secret
To allow the GitHub Actions runner to authenticate with CurseForge's upload API:

1. Log into your [CurseForge Account Settings](https://authors.curseforge.com).
2. Click your profile pic -> Preferences -> **My API Tokens** and generate an API key.
3. In your GitHub repository (`jdtemple/wow-addons`), navigate to:
   **Settings -> Secrets and variables -> Actions**
4. Click **New repository secret**:
   - **Name:** `CF_API_KEY`
   - **Secret:** *(Paste your CurseForge API token)*
5. Click **Add secret**.

### B. Enable Workflow Read & Write Permissions
To allow the GitHub Actions runner to automatically create and push Git release tags (e.g. `perf-biggins-1.4.0`) after a successful upload:

1. In your GitHub repository (`jdtemple/wow-addons`), navigate to:
   **Settings -> Actions -> General**
2. Scroll down to **Workflow permissions**.
3. Select **Read and write permissions**.
4. Click **Save**.

---

## 5. Day-to-Day Workflow: Automated Push-to-Deploy

Once your addon is registered on CurseForge and the API secret is configured in GitHub, publishing a new version requires **zero manual uploads**:

### Step 1: Bump the Version
Update the `## Version:` field in the addon's `.toc` file (e.g. `PerfBiggins.toc`):
```text
## Version: 1.4.0
```

### Step 2: Write Release Notes
Write the release notes directly in `<addon-folder>/CHANGELOG.md`.

> [!TIP]
> Under our **1:1 Parity Model**, `CHANGELOG.md` contains *only* the notes for the current release. Git serves as the cumulative historical record. Whatever markdown you write in `CHANGELOG.md` lands directly in CurseForge's release changelog verbatim with zero parsing.

Example `CHANGELOG.md`:
```markdown
# Perf Biggins v1.4.0

### Added
- **Configurable Stacking Mode:** Added support for horizontal vs. vertical telemetry bar layouts.
  - **Vertical (Default):** Retains the classic nameplate stack.
  - **Horizontal:** Places active telemetry bars side-by-side in a sleek ribbon.
- **Slash Command:** Toggle stacking modes on the fly using `/pb stack`.
```

### Step 3: Commit and Push to `main`
Commit your code changes, the bumped `.toc`, and `CHANGELOG.md`, then push to `main`.

> [!TIP]
> **Skipping CI Deployment (`[skip ci]`):**
> If you are pushing changes (such as documentation, guides, or script adjustments) that should not trigger addon releases to CurseForge, include `[skip ci]` or `[ci skip]` in your commit message. GitHub Actions natively detects these keywords and skips workflow execution entirely:
> ```bash
> git commit -m "update publishing docs [skip ci]"
> git push origin main
> ```

### Step 4: GitHub Actions Deploys Automatically
1. The **`detect-changes`** job checks which files were modified.
2. If only `perf-biggins/` changed, only `perf-biggins` is queued.
3. If [`lib-biggins-suite/`](file:///C:/Code/wow-addons/lib-biggins-suite) changed, the pipeline automatically packages and publishes **all 6 addons** in parallel.
4. The **`publish`** matrix job runs, executes `package.ps1` in an isolated VM, and streams the `.zip` directly to CurseForge via REST API.
5. Upon a successful CurseForge upload, the pipeline automatically creates and pushes the matching Git release tag (e.g. `perf-biggins-1.4.0`) to your GitHub repository.

---

## 6. Manual Pipeline Trigger (On-Demand Releases)

You can trigger a deployment on demand without making a commit:

1. Navigate to the **Actions** tab in your GitHub repository.
2. Select the **Publish Addons** workflow from the left sidebar.
3. Click the **Run workflow** dropdown:
   - **Addon to publish:** Select a specific addon or choose `all`.
   - **Release Channel:** Select `release`, `beta`, or `alpha`.
4. Click the green **Run workflow** button.

---

## 7. Local Dry-Run Testing

You can test packaging, changelog extraction, and payload generation locally on your PC at any time without calling CurseForge:

```powershell
# 1. Test change detection locally:
.\scripts\detect-changed-addons.ps1 -Local
.\scripts\detect-changed-addons.ps1 -ManualTarget "perf-biggins" -Local

# 2. Test full packaging and payload generation (automatically deletes temporary zip when done):
.\scripts\publish-curseforge.ps1 -Addon "perf-biggins" -DryRun
```

---

## 8. Onboarding a Brand New Addon (Step-by-Step)

Because CurseForge requires project creation and initial staff moderation, onboarding a new addon into the suite follows this checklist:

### Phase 1: Create the Project on CurseForge (Manual)
1. Navigate to the [CurseForge Author Dashboard](https://authors.curseforge.com).
2. Click **Start a Project** (or **Create Project**).
3. Select **World of Warcraft** as the game.
4. Fill in project details:
   - **Project Name:** Public display name (e.g. `CoolNew Biggins`).
   - **Project Slug:** URL slug (e.g. `coolnew-biggins`).
   - **Summary:** Short 1-2 sentence overview (under 200 characters).
   - **Primary Category:** Select appropriate category (e.g. `Buffs & Debuffs`, `Action Bars`).
   - **License:** `MIT License` (matches repository root `LICENSE`).
   - **Avatar / Icon:** Upload the addon's square `logo.jpg` (512x512+).
5. **Description:** Paste the markdown from the addon's `description.md` or `README.md`.
6. Click **Submit Project**. CurseForge will assign a **Numeric Project ID** visible on the project's overview page.

### Phase 2: Link External GitHub Issue Tracker (Manual)
1. In your project dashboard, click **Manage Project** (top right).
2. Click **Issues** in the sidebar (redirects to legacy issues page).
3. Under **Issue Tracker**, change the setting to **External**.
4. Enter your GitHub repository issues link:
   ```text
   https://github.com/jdtemple/wow-addons/issues
   ```
5. Click **Save Changes**.

### Phase 3: Register in Repository Automation (Code)
1. Add the addon entry to [`scripts/addons-config.json`](file:///C:/Code/wow-addons/scripts/addons-config.json):
   ```json
   "coolnew-biggins": {
     "name": "CoolNew Biggins",
     "projectId": YOUR_NEW_PROJECT_ID
   }
   ```
2. Add the directory path to [`.github/workflows/publish-addons.yml`](file:///C:/Code/wow-addons/.github/workflows/publish-addons.yml):
   - Under `on.push.paths`: add `- 'coolnew-biggins/**'`
   - Under `on.workflow_dispatch.inputs.target.options`: add `- coolnew-biggins`
3. Commit and push to `main`. GitHub Actions will automatically compile and upload the initial release file.
