# Update System Setup Instructions

## Overview
This app now includes an automatic update system that:
- Allows users to check for updates manually in Settings
- Shows update notifications when available
- Forces updates after 10 days if not installed
- Downloads APK files from GitHub releases

## Setup Steps

### 1. Configure Android Permissions

Add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
    
    <application
        android:requestLegacyExternalStorage="true"
        ...>
        
        <!-- Add this provider inside <application> tag -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/provider_paths" />
        </provider>
    </application>
</manifest>
```

### 2. Create Provider Paths File

Create file: `android/app/src/main/res/xml/provider_paths.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-path name="external_files" path="."/>
    <external-files-path name="external_files" path="." />
    <cache-path name="cache" path="." />
</paths>
```

### 3. Create GitHub Release

1. Build your release APK:
   ```bash
   flutter build apk --release
   ```

2. Go to your GitHub repository → **Releases** → **Create a new release**
3. Create a new tag (e.g., `v1.0.1`)
4. Upload the APK file from `build/app/outputs/flutter-apk/app-release.apk`
5. Publish the release
6. Copy the download URL from the release assets (right-click → Copy link)

### 4. Update the JSON Configuration

#### Option A: Using GitHub Releases (Recommended)

1. Create a release on GitHub with your APK file
2. Update `update.json` in your GitHub repository root:
   ```json
   {
     "version": "1.0.1",
     "downloadUrl": "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0.1/app-release.apk",
     "releaseNotes": "• Bug fixes and performance improvements\n• New features added\n• UI enhancements",
     "isForced": false
   }
   ```

2. The update check URL is already configured to use GitHub via jsDelivr CDN

### 4. Version Management

When releasing a new version:

1. Update `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Increment version number
   ```

2. Build the new APK:
   ```bash
   flutter build apk --release
   ```

3. Create a new GitHub release:
   - Go to Releases → Create new release
   - Tag: `v1.0.1`
   - Upload APK file
   - Publish release

4. Update `update.json` with:
   - New version number
   - New GitHub release download link
   - Release notes
   - Set `isForced: false` for optional updates

### 5. Testing the Update System

1. **Test Manual Check:**
   - Open app → Settings → Check for Updates
   - Should show "You are using the latest version" if versions match

2. **Test Update Available:**
   - Change version in `update.json` to a higher number (e.g., "1.0.1" → "1.0.2")
   - Check for updates in Settings
   - Should show update dialog

3. **Test Forced Update:**
   - Manually set the last check date to 11 days ago in SharedPreferences
   - Restart the app
   - Should show forced update screen

### 6. Update Flow

```
App Start
    ↓
Check if update required (>10 days)
    ↓
    Yes → Show Forced Update Screen (can't skip)
    ↓
    No → Continue to Login/Home
    
Settings Screen
    ↓
Tap "Check for Updates"
    ↓
Fetch update.json
    ↓
Compare versions
    ↓
Show "Latest version" OR "Update available" dialog
    ↓
User can choose "Later" or "Install Now"
```

### 7. Important Notes

- **GitHub Links:** Use direct download links from GitHub releases
- **File Size:** Keep APK size reasonable for user downloads
- **10-Day Rule:** After 10 days, update becomes mandatory
- **Internet Required:** App needs internet to check for updates
- **Permissions:** Users must grant "Install from unknown sources" permission

### 8. Troubleshooting

**Problem:** "Failed to check for updates"
- Check internet connection
- Verify JSON URL is accessible
- Check JSON format is valid

**Problem:** "Download failed"
- Verify GitHub release link is public and valid
- Check storage permissions
- Ensure sufficient storage space

**Problem:** "Installation failed"
- Enable "Install from unknown sources" in Android settings
- Check if APK is corrupted
- Verify APK is signed properly

### 9. Release Checklist

Before each release:

- [ ] Update version in `pubspec.yaml`
- [ ] Build release APK
- [ ] Test APK installation manually
- [ ] Create GitHub release and upload APK
- [ ] Get GitHub release download link
- [ ] Update `update.json` with new version and link
- [ ] Push `update.json` to GitHub
- [ ] Test update flow
- [ ] Document changes in release notes

## Example update.json

```json
{
  "version": "1.0.1",
  "downloadUrl": "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0.1/app-release.apk",
  "releaseNotes": "Version 1.0.1 Changes:\n• Fixed attendance marking bug\n• Improved performance\n• Updated UI theme\n• Added export feature enhancements",
  "isForced": false
}
```

## Security Considerations

1. Always sign your APKs with the same keystore
2. Use HTTPS for all update URLs
3. Consider adding checksum verification for downloads
4. Monitor GitHub bandwidth limits (though generous for releases)
5. Keep backup of all APK versions

## Future Enhancements

Consider adding:
- APK signature verification
- Incremental updates
- Background download support
- Rollback capability
- Update history log
