# Quick Start Guide - App Update System

## What You Need

1. **MEGA Account** - Free account at https://mega.nz
2. **GitHub Repository** - To host the update.json file
3. **Your APK files** - Release builds of your app

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

### Step 3: Build and Upload Your First APK

1. Build release APK:
   ```bash
   flutter build apk --release
   ```

2. Find APK at: `build/app/outputs/flutter-apk/app-release.apk`

3. Upload to MEGA:
   - Go to https://mega.nz
   - Upload the APK
   - Right-click → "Get link" → Copy the link
   - Make sure it's a **public download link**

### Step 4: Update the JSON File

Edit `update.json` with your MEGA link:

```json
{
  "version": "1.0.0",
  "downloadUrl": "https://mega.nz/file/PASTE_YOUR_LINK_HERE",
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

### 3. Upload to MEGA

- Upload the new APK to MEGA
- Get the public download link

### 4. Update JSON

Edit `update.json`:
```json
{
  "version": "1.0.1",
  "downloadUrl": "https://mega.nz/file/NEW_LINK_HERE",
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

## Important MEGA Link Notes

### Good Link Format:
```
https://mega.nz/file/ABCD1234#KEY_HERE
```

### Bad Link Formats (Don't use):
```
https://mega.nz/#!ABCD1234!KEY_HERE  ❌ (old format)
https://mega.nz/folder/...            ❌ (folder link)
```

### How to Get Correct Link:
1. Upload file to MEGA
2. Right-click the file (not folder)
3. Click "Get link"
4. Choose "Link with key"
5. Copy the link that looks like: `https://mega.nz/file/...#...`

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

**Solution 1:** Verify MEGA link is public
- Open link in incognito browser
- Should download without login

**Solution 2:** Check MEGA bandwidth
- Free accounts have daily limits
- Wait 24 hours or upgrade account

**Solution 3:** Check storage permissions
- Settings → Apps → Your App → Permissions
- Enable Storage permission

### Problem: "Installation failed"

**Solution:** Enable "Install from unknown sources"
- Settings → Security → Unknown Sources → Enable
- Or: Settings → Apps → Special Access → Install Unknown Apps → Enable for your browser

## File Checklist

✅ Files you need to modify:
- `lib/services/update_service.dart` (Line 28: Update GitHub URL)
- `update.json` (Your version and MEGA link)
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
6. **Monitor MEGA storage/bandwidth**

## Emergency Rollback

If you need to roll back an update:

1. Upload previous version APK to MEGA
2. Update `update.json` with previous version number
3. Users can download and install older version

## Support

If users report issues:
1. Check MEGA link is still active
2. Verify JSON is accessible
3. Test APK installation manually
4. Check app permissions

## Next Steps

1. ✅ Set up GitHub URL in `update_service.dart`
2. ✅ Upload first APK to MEGA
3. ✅ Update `update.json` with link
4. ✅ Push to GitHub
5. ✅ Test on device
6. 🚀 Release to users!

---

**Need Help?** Check the detailed guide in `UPDATE_SYSTEM_SETUP.md`
