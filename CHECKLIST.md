# ✅ Update System - Setup Checklist

## Pre-Release Checklist

### Step 1: Configure GitHub URL ⚠️ REQUIRED
- [ ] Open `lib/services/update_service.dart`
- [ ] Go to line 28
- [ ] Replace with your GitHub URL:
  ```dart
  static const String _updateCheckUrl =
      'https://raw.githubusercontent.com/Umesh080797668/teacher/main/update.json';
  ```
- [ ] Save the file

### Step 2: Build Your APK
- [ ] Open terminal
- [ ] Run: `flutter build apk --release`
- [ ] Wait for build to complete
- [ ] Note the location: `build/app/outputs/flutter-apk/app-release.apk`

### Step 3: Create GitHub Release
- [ ] Go to your GitHub repository: https://github.com/Umesh080797668/teacher
- [ ] Click "Releases" in the right sidebar
- [ ] Click "Create a new release"
- [ ] Tag version: `v1.0.0` (with 'v' prefix)
- [ ] Release title: "Version 1.0.0"
- [ ] Upload `app-release.apk` from `build/app/outputs/flutter-apk/`
- [ ] Write release notes
- [ ] Click "Publish release"
- [ ] Copy the download URL from the release assets (right-click → Copy link)

### Step 4: Update update.json File
- [ ] Open `update.json` in your project
- [ ] Update the fields:
  ```json
  {
    "version": "1.0.0",
    "downloadUrl": "https://github.com/Umesh080797668/teacher/releases/download/v1.0.0/app-release.apk",
    "releaseNotes": "Initial release of the app",
    "isForced": false
  }
  ```
- [ ] Save the file

### Step 5: Push to GitHub
- [ ] Run: `git add .`
- [ ] Run: `git commit -m "Add update system"`
- [ ] Run: `git push origin main`
- [ ] Verify `update.json` is visible on GitHub

### Step 6: Test on Device
- [ ] Connect Android device via USB
- [ ] Enable USB debugging on device
- [ ] Run: `flutter install --release`
- [ ] Open the app
- [ ] Go to Settings
- [ ] Tap "Check for Updates"
- [ ] Should show: "You are using the latest version"

### Step 7: Test Update Flow (Optional but Recommended)
- [ ] Change version in `update.json` to "1.0.1"
- [ ] Commit and push to GitHub
- [ ] Wait 1-2 minutes for GitHub to update
- [ ] In the app, go to Settings → Check for Updates
- [ ] Should show update available dialog
- [ ] Test "Later" button (should close dialog)
- [ ] Test "Install Now" (should download but may fail since APK is same version)

---

## For Each New Release

### Release Checklist

#### 1. Update Version Number
- [ ] Open `pubspec.yaml`
- [ ] Change version line (e.g., `1.0.0+1` → `1.0.1+2`)
- [ ] Save file

#### 2. Build New APK
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter build apk --release`
- [ ] Test APK on device manually first

#### 3. Create GitHub Release
- [ ] Go to GitHub repository → Releases → Create new release
- [ ] Tag: `v1.0.1` (match pubspec.yaml version)
- [ ] Upload new APK file
- [ ] Publish release
- [ ] Copy the download URL

#### 4. Update Configuration
- [ ] Open `update.json`
- [ ] Update version number
- [ ] Update downloadUrl with new GitHub release link
- [ ] Write release notes
- [ ] Set `isForced` to `false` (unless critical)
- [ ] Save file

#### 5. Push to GitHub
- [ ] `git add update.json`
- [ ] `git commit -m "Release version X.X.X"`
- [ ] `git push origin main`

#### 6. Verify
- [ ] Check GitHub - `update.json` should be updated
- [ ] Open raw file URL in browser
- [ ] Should show new version and link

#### 7. Monitor
- [ ] Watch for user feedback
- [ ] Check GitHub release download stats
- [ ] Check for installation issues

---

## Troubleshooting Checklist

### If "Failed to check for updates"
- [ ] Check device has internet connection
- [ ] Verify GitHub URL in `update_service.dart` is correct
- [ ] Test URL in browser: `https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/update.json`
- [ ] Check JSON syntax at https://jsonlint.com

### If "Download failed"
- [ ] Open GitHub release link in browser
- [ ] Should download APK directly
- [ ] Check internet connection stability
- [ ] Verify release URL format: `https://github.com/.../releases/download/.../app-release.apk`

### If "Installation failed"
- [ ] Go to Settings → Security
- [ ] Enable "Install from unknown sources"
- [ ] Or: Settings → Apps → Special Access → Install Unknown Apps
- [ ] Enable for your browser/file manager
- [ ] Check storage space (need ~50MB free)

### If Version Shows "1.0.0" Always
- [ ] Rebuild app: `flutter clean && flutter build apk --release`
- [ ] Reinstall app completely
- [ ] Check `pubspec.yaml` version number

---

## Quick Commands Reference

```bash
# Build release APK
flutter build apk --release

# Install on connected device
flutter install --release

# Check for issues
flutter analyze

# Format code
flutter format .

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Complete rebuild
flutter clean && flutter pub get && flutter build apk --release
```

---

## Important Files Location

```
Your Project/
├── lib/
│   ├── services/
│   │   └── update_service.dart        ⚠️ Update line 28
│   └── screens/
│       ├── forced_update_screen.dart   ✓ Ready
│       └── settings_screen.dart        ✓ Ready
├── android/
│   └── app/
│       └── src/main/
│           ├── AndroidManifest.xml     ✓ Ready
│           └── res/xml/
│               └── provider_paths.xml  ✓ Ready
├── update.json                         ⚠️ Update before each release
└── pubspec.yaml                        ⚠️ Update version before build
```

---

## Current Status

✅ **Implementation**: Complete
✅ **Code**: Formatted and ready
✅ **Android Config**: Set up
✅ **Dependencies**: Installed

⚠️ **Action Required**:
1. Build APK
2. Create GitHub release
3. Update `update.json` with GitHub release link
4. Test on device

---

## Support

📖 **Detailed Guide**: See `UPDATE_SYSTEM_SETUP.md`
🚀 **Quick Start**: See `QUICK_START_UPDATES.md`
📋 **Summary**: See `IMPLEMENTATION_SUMMARY.md`

---

**Ready to test?** Follow Step 1-8 in the Pre-Release Checklist above!

**Last Updated**: December 10, 2025
**System Version**: 1.0
**Status**: ✅ Ready for Configuration
