# Quick Start Guide - App Update System

## What You Need

1. **GitHub Repository** - To host the update.json file and releases
2. **Your APK files** - Release builds of your app

## Step-by-Step Setup (5 Minutes)

### Step 1: Update GitHub Repository Settings

1. Edit `lib/services/update_service.dart` (Line 28)
2. Replace with your GitHub details:
   ```dart
   static const String _updateCheckUrl =
       'https://raw.githubusercontent.com/Umesh080797668/teacher/main/update.json';
   ```

### Step 2: Upload update.json to GitHub

1. Edit the `update.json` file in your project root
2. Commit and push to GitHub:
   ```bash
   git add update.json
   git commit -m "Add update configuration"
   git push origin main
   ```

### Step 3: Build and Create GitHub Release

1. Build release APK:
   ```bash
   flutter build apk --release
   ```

2. Find APK at: `build/app/outputs/flutter-apk/app-release.apk`

3. Create GitHub release:
   - Go to your GitHub repo → Releases → Create new release
   - Tag: `v1.0.0`
   - Title: "Version 1.0.0"
   - Upload the APK file
   - Publish release
   - Copy the download URL from the release assets

### Step 4: Update the JSON File

Edit `update.json` with your GitHub release link:

```json
{
  "version": "1.0.0",
  "downloadUrl": "https://github.com/Umesh080797668/teacher/releases/download/v1.0.0/app-release.apk",
  "releaseNotes": "Initial release",
  "isForced": false
}
```

Push to GitHub:
```bash
git add update.json
git commit -m "Update download link"
git push origin main
```

### Step 5: Test

1. Install the app on your device
2. Go to Settings → Check for Updates
3. Should say "You are using the latest version"

## How to Release a New Version

### 1. Update Version Number

Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2  # Change from 1.0.0+1
```

### 2. Build New APK

```bash
flutter build apk --release
```

### 3. Create GitHub Release

- Go to your GitHub repo → Releases → Create new release
- Tag: `v1.0.1`
- Upload the new APK file
- Publish release
- Copy the new download URL

### 4. Update JSON

Edit `update.json`:
```json
{
  "version": "1.0.1",
  "downloadUrl": "https://github.com/Umesh080797668/teacher/releases/download/v1.0.1/app-release.apk",
  "releaseNotes": "• Bug fixes\n• New features\n• Performance improvements",
  "isForced": false
}
```

### 5. Push to GitHub

```bash
git add update.json
git commit -m "Release version 1.0.1"
git push origin main
```

### 6. Users Get Update

- Users open Settings → Check for Updates
- They see the new version and can install
- After 10 days, update becomes mandatory

## Important GitHub Release Notes

### Release URL Format:
```
https://github.com/Umesh080797668/teacher/releases/download/v1.0.0/app-release.apk
```

### How to Create a Release:
1. Go to your GitHub repository
2. Click "Releases" in the right sidebar
3. Click "Create a new release"
4. Tag version: `v1.0.0` (with 'v' prefix)
5. Upload your APK file
6. Publish release
7. Copy the download URL from the release assets

### Benefits of GitHub Releases:
- ✅ Permanent download links
- ✅ No bandwidth limits
- ✅ Version history tracking
- ✅ Free and reliable

## Testing the Update Flow

### Test 1: No Update Available
```bash
# Current app version: 1.0.0
# JSON version: 1.0.0
# Expected: "You are using the latest version"
```

### Test 2: Update Available
```bash
# Current app version: 1.0.0
# JSON version: 1.0.1
# Expected: Shows update dialog with "Install Now" option
```

### Test 3: Forced Update (Manual Test)
```bash
# Install app
# After 10 days (or manually change date in SharedPreferences)
# Open app
# Expected: Shows forced update screen, can't skip
```

## Troubleshooting

### Problem: "Failed to check for updates"

**Solution 1:** Check internet connection

**Solution 2:** Verify JSON URL
```bash
# Test the URL in browser:
https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/update.json

# Should show JSON content
```

**Solution 3:** Check JSON format
```bash
# Validate JSON at: https://jsonlint.com/
```

### Problem: "Download failed"

**Solution 1:** Verify GitHub release link is valid
- Open link in browser
- Should download APK file directly

**Solution 2:** Check internet connection
- Ensure stable internet connection
- Try on different network

**Solution 3:** Check storage permissions
- Settings → Apps → Your App → Permissions
- Enable Storage permission

### Problem: "Installation failed"

**Solution:** Enable "Install from unknown sources"
- Settings → Security → Unknown Sources → Enable
- Or: Settings → Apps → Special Access → Install Unknown Apps → Enable for your browser

## File Checklist

✅ Files you need to modify:
- `update.json` (Your version and GitHub release link)
- `pubspec.yaml` (Version number when releasing)

✅ Files already configured:
- `android/app/src/main/AndroidManifest.xml` ✓
- `android/app/src/main/res/xml/provider_paths.xml` ✓
- `lib/screens/forced_update_screen.dart` ✓
- `lib/screens/settings_screen.dart` ✓
- `lib/screens/splash_screen.dart` ✓

## Version Number Format

```
1.0.0+1
│ │ │ │
│ │ │ └─ Build number (increment each build)
│ │ └─── Patch (bug fixes)
│ └───── Minor (new features)
└─────── Major (breaking changes)
```

Examples:
- `1.0.0+1` → `1.0.1+2` (bug fix)
- `1.0.1+2` → `1.1.0+3` (new feature)
- `1.1.0+3` → `2.0.0+4` (major change)

## Best Practices

1. **Always test updates on test device first**
2. **Keep old APK versions backed up**
3. **Write clear release notes**
4. **Increment version properly**
5. **Test download link before updating JSON**
6. **GitHub releases provide permanent hosting**

## Emergency Rollback

If you need to roll back an update:

1. Create a new GitHub release with previous version APK
2. Update `update.json` with previous version number and new release URL
3. Users can download and install older version

## Support

If users report issues:
1. Check GitHub release link is accessible
2. Verify JSON is accessible
3. Test APK installation manually
4. Check app permissions

## Next Steps

1. ✅ Update `update.json` with GitHub release link
2. ✅ Push to GitHub
3. ✅ Test on device
4. 🚀 Release to users!

---

**Need Help?** Check the detailed guide in `UPDATE_SYSTEM_SETUP.md`
