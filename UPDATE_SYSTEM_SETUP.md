# Update System Setup Instructions

## Overview
This app now includes an automatic update system that:
- Allows users to check for updates manually in Settings
- Shows update notifications when available
- Forces updates after 10 days if not installed
- Downloads APK files from MEGA drive

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

### 3. Upload Your APK to MEGA

1. Build your release APK:
   ```bash
   flutter build apk --release
   ```

2. Upload the APK to your MEGA drive:
   - Go to https://mega.nz
   - Upload the APK file from `build/app/outputs/flutter-apk/app-release.apk`
   - Right-click the file and select "Get link"
   - Make sure it's a public download link

### 4. Update the JSON Configuration

#### Option A: Using GitHub (Recommended)

1. Create a file `update.json` in your GitHub repository root:
   ```json
   {
     "version": "1.0.1",
     "downloadUrl": "https://mega.nz/file/YOUR_FILE_ID#YOUR_KEY",
     "releaseNotes": "• Bug fixes and performance improvements\n• New features added\n• UI enhancements",
     "isForced": false
   }
   ```

2. Update `lib/services/update_service.dart` line 28:
   ```dart
   static const String _updateCheckUrl =
       'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/update.json';
   ```

#### Option B: Using MEGA for JSON (Alternative)

1. Upload `update.json` to MEGA
2. Get the public link
3. Update `lib/services/update_service.dart` with the MEGA link

### 5. Version Management

When releasing a new version:

1. Update `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Increment version number
   ```

2. Build the new APK:
   ```bash
   flutter build apk --release
   ```

3. Upload new APK to MEGA

4. Update `update.json` with:
   - New version number
   - New MEGA download link
   - Release notes
   - Set `isForced: false` for optional updates

### 6. Testing the Update System

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

### 7. Update Flow

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

### 8. Important Notes

- **MEGA Links:** Make sure to use direct download links from MEGA
- **File Size:** Keep APK size reasonable for user downloads
- **10-Day Rule:** After 10 days, update becomes mandatory
- **Internet Required:** App needs internet to check for updates
- **Permissions:** Users must grant "Install from unknown sources" permission

### 9. Troubleshooting

**Problem:** "Failed to check for updates"
- Check internet connection
- Verify JSON URL is accessible
- Check JSON format is valid

**Problem:** "Download failed"
- Verify MEGA link is public and valid
- Check storage permissions
- Ensure sufficient storage space

**Problem:** "Installation failed"
- Enable "Install from unknown sources" in Android settings
- Check if APK is corrupted
- Verify APK is signed properly

### 10. Release Checklist

Before each release:

- [ ] Update version in `pubspec.yaml`
- [ ] Build release APK
- [ ] Test APK installation manually
- [ ] Upload APK to MEGA
- [ ] Get MEGA public download link
- [ ] Update `update.json` with new version and link
- [ ] Upload `update.json` to GitHub/MEGA
- [ ] Test update flow
- [ ] Document changes in release notes

## Example update.json

```json
{
  "version": "1.0.1",
  "downloadUrl": "https://mega.nz/file/ABCDEFGH#123456789abcdefghijklmnopqrstuvwxyz",
  "releaseNotes": "Version 1.0.1 Changes:\n• Fixed attendance marking bug\n• Improved performance\n• Updated UI theme\n• Added export feature enhancements",
  "isForced": false
}
```

## Security Considerations

1. Always sign your APKs with the same keystore
2. Use HTTPS for all update URLs
3. Consider adding checksum verification for downloads
4. Monitor MEGA bandwidth limits
5. Keep backup of all APK versions

## Future Enhancements

Consider adding:
- APK signature verification
- Incremental updates
- Background download support
- Rollback capability
- Update history log
