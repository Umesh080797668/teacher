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

### Step 2: Create MEGA Account
- [ ] Go to https://mega.nz
- [ ] Sign up for free account (50GB free storage)
- [ ] Verify your email
- [ ] Login to MEGA

### Step 3: Build Your APK
- [ ] Open terminal
- [ ] Run: `flutter build apk --release`
- [ ] Wait for build to complete
- [ ] Note the location: `build/app/outputs/flutter-apk/app-release.apk`

### Step 4: Upload APK to MEGA
- [ ] Go to MEGA web interface
- [ ] Create a folder called "App Updates" (optional)
- [ ] Upload `app-release.apk`
- [ ] Right-click the file → "Get link"
- [ ] Select "Link with key"
- [ ] Copy the link (should look like: `https://mega.nz/file/ABC123#KEY456`)
- [ ] Save this link somewhere safe

### Step 5: Update update.json File
- [ ] Open `update.json` in your project
- [ ] Update the fields:
  ```json
  {
    "version": "1.0.0",
    "downloadUrl": "PASTE_YOUR_MEGA_LINK_HERE",
    "releaseNotes": "Initial release of the app",
    "isForced": false
  }
  ```
- [ ] Save the file

### Step 6: Push to GitHub
- [ ] Run: `git add .`
- [ ] Run: `git commit -m "Add update system"`
- [ ] Run: `git push origin main`
- [ ] Verify `update.json` is visible on GitHub

### Step 7: Test on Device
- [ ] Connect Android device via USB
- [ ] Enable USB debugging on device
- [ ] Run: `flutter install --release`
- [ ] Open the app
- [ ] Go to Settings
- [ ] Tap "Check for Updates"
- [ ] Should show: "You are using the latest version"

### Step 8: Test Update Flow (Optional but Recommended)
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

#### 3. Upload to MEGA
- [ ] Upload new APK to MEGA
- [ ] Get public download link
- [ ] Copy the link

#### 4. Update Configuration
- [ ] Open `update.json`
- [ ] Update version number
- [ ] Update downloadUrl with new MEGA link
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
- [ ] Monitor MEGA bandwidth
- [ ] Check for installation issues

---

## Troubleshooting Checklist

### If "Failed to check for updates"
- [ ] Check device has internet connection
- [ ] Verify GitHub URL in `update_service.dart` is correct
- [ ] Test URL in browser: `https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/update.json`
- [ ] Check JSON syntax at https://jsonlint.com

### If "Download failed"
- [ ] Open MEGA link in incognito browser
- [ ] Should download without login
- [ ] Check MEGA account bandwidth (Daily limit: 5GB free)
- [ ] Verify link format: `https://mega.nz/file/ABC#KEY`
- [ ] Try generating new MEGA link

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
1. Update GitHub URL in `update_service.dart`
2. Upload APK to MEGA
3. Update `update.json` with MEGA link
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
