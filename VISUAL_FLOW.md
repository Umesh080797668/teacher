# Update System - Visual Flow Diagrams

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        YOUR SETUP                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │   GitHub     │         │   GitHub    │                 │
│  │  Repository  │         │    Drive     │                 │
│  └──────┬───────┘         └──────┬───────┘                 │
│         │                         │                         │
│         │ update.json             │ app-release.apk         │
│         │ (version info)          │ (actual APK file)       │
│         │                         │                         │
└─────────┼─────────────────────────┼─────────────────────────┘
          │                         │
          │                         │
          ▼                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      USER'S DEVICE                           │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Teacher Attendance App                     │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │                                                         │ │
│  │  1. Checks GitHub for update.json                      │ │
│  │  2. Compares versions                                  │ │
│  │  3. Downloads APK from GitHub releases (if update available) │ │
│  │  4. Installs new version                               │ │
│  │                                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## User Flow - Manual Update Check

```
┌─────────────┐
│ User opens  │
│   Settings  │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ Taps "Check for  │
│    Updates"      │
└──────┬───────────┘
       │
       ▼
┌──────────────────────────┐
│ App fetches update.json  │
│   from GitHub            │
└──────┬───────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Compare Versions       │
└──────┬────────┬─────────┘
       │        │
  Same │        │ Different
       │        │
       ▼        ▼
┌────────┐  ┌────────────────┐
│"Latest"│  │ Update Dialog  │
│ Toast  │  │ • Version      │
└────────┘  │ • Release Notes│
            │ • [Later]      │
            │ • [Install]    │
            └────┬───────────┘
                 │
            ┌────┴────┐
            │         │
       Later│         │Install
            │         │
            ▼         ▼
        ┌──────┐  ┌──────────────────┐
        │ Done │  │ Download APK     │
        └──────┘  │ from GitHub       │
                  └────┬─────────────┘
                       │
                       ▼
                  ┌──────────────────┐
                  │ Progress Bar     │
                  │ 0% → 100%        │
                  └────┬─────────────┘
                       │
                       ▼
                  ┌──────────────────┐
                  │ Install APK      │
                  │ (Auto-prompt)    │
                  └────┬─────────────┘
                       │
                       ▼
                  ┌──────────────────┐
                  │ App Restarts     │
                  │ New Version!     │
                  └──────────────────┘
```

## Forced Update Flow (After 10 Days)

```
┌──────────────┐
│  User Opens  │
│     App      │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  Splash Screen       │
│  Checks Update       │
│  Status              │
└──────┬───────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Update Available?           │
└──────┬────────┬─────────────┘
       │        │
    No │        │ Yes
       │        │
       ▼        ▼
   ┌──────┐  ┌─────────────────────┐
   │ Home │  │ Days Since Update?  │
   │Screen│  └──────┬──────────────┘
   └──────┘         │
              ┌─────┴─────┐
              │           │
         < 10 │           │ >= 10
              │           │
              ▼           ▼
        ┌──────────┐  ┌────────────────────┐
        │  Home    │  │ FORCED UPDATE      │
        │ Screen   │  │ SCREEN             │
        └──────────┘  │                    │
                      │ ┌────────────────┐ │
                      │ │ Version Info   │ │
                      │ └────────────────┘ │
                      │ ┌────────────────┐ │
                      │ │ Release Notes  │ │
                      │ └────────────────┘ │
                      │ ┌────────────────┐ │
                      │ │ [Download &    │ │
                      │ │  Install Now]  │ │
                      │ └────────┬───────┘ │
                      └──────────┼─────────┘
                                 │
                          (Must Install,
                           Cannot Skip!)
                                 │
                                 ▼
                      ┌────────────────────┐
                      │ Download Progress  │
                      └────────┬───────────┘
                               │
                               ▼
                      ┌────────────────────┐
                      │ Install & Restart  │
                      └────────────────────┘
```

## Version Comparison Logic

```
┌─────────────────────────────────────┐
│      version: "1.0.0+1"             │
│      ┌───┬───┬───┬───┐             │
│      │ 1 │ 0 │ 0 │ 1 │             │
│      └─┬─┴─┬─┴─┬─┴─┬─┘             │
│        │   │   │   │                │
│     Major Minor Patch Build         │
│                                     │
└─────────────────────────────────────┘

Comparison Examples:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current: 1.0.0  Latest: 1.0.0
Result:  ✓ Up to date

Current: 1.0.0  Latest: 1.0.1
Result:  ⚠ Update available (Patch)

Current: 1.0.0  Latest: 1.1.0
Result:  ⚠ Update available (Minor)

Current: 1.0.0  Latest: 2.0.0
Result:  ⚠ Update available (Major)

Current: 1.0.1  Latest: 1.0.0
Result:  ✓ Up to date (Newer installed)
```

## File Structure & Responsibilities

```
┌──────────────────────────────────────────────────────────┐
│                   update_service.dart                     │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  checkForUpdates()                                       │
│  ├─ Fetches update.json from GitHub                     │
│  ├─ Parses JSON to UpdateInfo object                    │
│  └─ Compares versions                                   │
│                                                           │
│  isUpdateRequired()                                      │
│  ├─ Checks SharedPreferences                            │
│  ├─ Calculates days since last check                    │
│  └─ Returns true if >= 10 days                          │
│                                                           │
│  downloadAndInstallUpdate()                              │
│  ├─ Downloads APK from GitHub releases using Dio          │
│  ├─ Shows progress via callback                         │
│  ├─ Saves to external storage                           │
│  └─ Triggers installation                               │
│                                                           │
│  getCachedUpdateInfo()                                   │
│  ├─ Reads from SharedPreferences                        │
│  └─ Returns version info without network call           │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                settings_screen.dart                       │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Shows current version (from package_info_plus)         │
│  "Check for Updates" button                             │
│  Handles update dialog display                          │
│  Shows download progress                                │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│              forced_update_screen.dart                    │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Full-screen blocking UI                                │
│  Cannot be dismissed (PopScope: canPop: false)          │
│  Shows version info & release notes                     │
│  Download progress indicator                            │
│  Mandatory installation                                 │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                 splash_screen.dart                        │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Checks for forced updates on startup                   │
│  If update required → forced_update_screen              │
│  If not → normal flow (login/home)                      │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌────────────────────────────────────────────────────────────┐
│                    GitHub (JSON)                           │
│  {                                                         │
│    "version": "1.0.1",                                     │
│    "downloadUrl": "https://github.com/.../releases/download/...", │
│    "releaseNotes": "Bug fixes...",                         │
│    "isForced": false                                       │
│  }                                                         │
└─────────────────┬──────────────────────────────────────────┘
                  │
                  │ HTTP GET
                  │
                  ▼
┌────────────────────────────────────────────────────────────┐
│            UpdateService.checkForUpdates()                 │
│  1. Dio HTTP request                                       │
│  2. Parse JSON                                             │
│  3. Create UpdateInfo object                               │
│  4. Compare versions                                       │
│  5. Save to SharedPreferences                              │
└─────────────────┬──────────────────────────────────────────┘
                  │
                  │ UpdateInfo object
                  │
                  ▼
┌────────────────────────────────────────────────────────────┐
│                  UI Layer (Settings/Splash)                │
│  • Display version info                                    │
│  • Show update dialog                                      │
│  • Handle user choice                                      │
└─────────────────┬──────────────────────────────────────────┘
                  │
                  │ User taps "Install"
                  │
                  ▼
┌────────────────────────────────────────────────────────────┐
│      UpdateService.downloadAndInstallUpdate()              │
│  1. Download from GitHub releases (Dio)                     │
│  2. Save to /storage/emulated/0/Android/data/...          │
│  3. Update progress callback                               │
│  4. InstallPlugin.install(path)                            │
└─────────────────┬──────────────────────────────────────────┘
                  │
                  │ APK file
                  │
                  ▼
┌────────────────────────────────────────────────────────────┐
│              Android Package Installer                     │
│  • Verify signature                                        │
│  • Request install permission                              │
│  • Install APK                                             │
│  • Restart app                                             │
└────────────────────────────────────────────────────────────┘
```

## Timeline Example

```
Day 0: New version 1.0.1 released
┌────────────────────────────────────────────┐
│ User opens app                             │
│ ✓ Optional update notification             │
│ User can choose "Later"                    │
└────────────────────────────────────────────┘

Day 5: User hasn't updated yet
┌────────────────────────────────────────────┐
│ User opens app                             │
│ ✓ Still optional                           │
│ Can continue using old version             │
└────────────────────────────────────────────┘

Day 10: Grace period over
┌────────────────────────────────────────────┐
│ User opens app                             │
│ ⚠ FORCED UPDATE SCREEN                     │
│ Must install to continue                   │
│ Cannot skip or close                       │
└────────────────────────────────────────────┘
```

## Success States

```
✓ Version Check Success
  ├─ Network: Connected
  ├─ GitHub: Accessible
  ├─ JSON: Valid format
  └─ Response: Version info retrieved

✓ Download Success
  ├─ GitHub: Link valid
  ├─ Storage: Permission granted
  ├─ Space: Sufficient
  └─ Network: Stable connection

✓ Installation Success
  ├─ APK: Valid signature
  ├─ Permission: "Unknown sources" enabled
  ├─ Storage: File readable
  └─ System: Installation allowed
```

## Error States & Recovery

```
❌ Network Error
   └─ Retry: Manual retry button
   
❌ JSON Parse Error
   └─ Fallback: Use cached data
   
❌ Download Failed
   └─ Retry: Try download again
   
❌ Installation Failed
   └─ Guide: Show permission instructions
   
❌ Network Connection Issues
   └─ Alternative: Retry download
```

---

## Quick Reference

**Current Version Location**: `pubspec.yaml`
**Update Config Location**: `update.json` (GitHub)
**APK Storage Location**: `GitHub Releases`
**Check Frequency**: On-demand + App startup
**Force Threshold**: 10 days
**Download Method**: Dio (HTTP)
**Installation**: InstallPlugin (Android)

---

**Visual Guide Created**: December 10, 2025
**System Version**: 1.0
