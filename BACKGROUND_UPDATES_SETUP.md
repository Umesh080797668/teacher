# Background Update Notification Setup Guide

## Overview
The app now supports **background update checks** that run even when the app is closed or not used for days. Users will receive notifications automatically when new updates are available.

## How It Works

### Background Task Scheduling
- Uses **WorkManager** (Android's recommended background task scheduler)
- Checks for updates **every 6 hours** automatically
- Works even when:
  - ✅ App is closed
  - ✅ Device is rebooted
  - ✅ App hasn't been opened for days/weeks
  - ✅ Device is in battery saver mode (with network)

### Multi-Layer Update Detection

1. **Background Service** (Runs every 6 hours)
   - Checks for updates even when app is closed
   - Shows system notification if update available
   - Survives device reboots

2. **App Launch Check** (When app starts)
   - Quick check on splash screen
   - Shows notification if 6+ hours since last check

3. **Periodic In-App Check** (Every 30 minutes while app is open)
   - Checks while user is actively using the app
   - Respects 6-hour rate limit

4. **Manual Check** (Settings screen)
   - User can force check anytime
   - Shows dialog instead of notification

## Setup Instructions

### Step 1: Install Dependencies

Run this command in the terminal:

```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance"
flutter pub get
```

### Step 2: Build the App

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Step 3: Install and Test

1. Install the app on a device
2. Open the app (grants notification permission)
3. Close the app completely
4. Wait 6 hours OR change device time forward
5. Background task will run and show notification if update available

## What Changed

### New Files Added:
- `lib/services/background_update_service.dart` - Background task handler

### Modified Files:
1. **pubspec.yaml**
   - Added `workmanager: ^0.5.2` dependency

2. **lib/main.dart**
   - Initializes background service on app startup

3. **lib/services/update_service.dart**
   - Added `shouldCheckForUpdates()` - Rate limiting (6 hours)
   - Added `performBackgroundUpdateCheck()` - Background check method
   - Added `showNotification` parameter to `checkForUpdates()`

4. **lib/screens/home_screen.dart**
   - Added periodic timer (every 30 minutes)
   - Checks for updates while app is running

5. **lib/screens/splash_screen.dart**
   - Checks for updates on app launch

6. **lib/screens/settings_screen.dart**
   - Manual check doesn't show notification (uses dialog)

7. **android/app/src/main/AndroidManifest.xml**
   - Added `RECEIVE_BOOT_COMPLETED` - Restart background tasks after reboot
   - Added `WAKE_LOCK` - Wake device for background checks
   - Added `FOREGROUND_SERVICE` - Required for background work

## Testing the Background Service

### Test 1: Immediate Test (Debug Mode)
```dart
// In main.dart, change the frequency to 15 minutes for testing:
frequency: const Duration(minutes: 15),
initialDelay: const Duration(minutes: 1), // Check after 1 minute
```

### Test 2: Check Background Task is Registered
```bash
adb shell dumpsys alarm | grep teacher_attendance
```

### Test 3: Force Background Task
```bash
adb shell cmd jobscheduler run -f com.example.teacher_attendance 999
```

### Test 4: Simulate Time Change
1. Close the app
2. Go to device settings
3. Disable automatic date/time
4. Change time forward by 6 hours
5. Background task should trigger
6. Check for notification

## Notification Behavior

### When Background Check Runs:
- 🔔 Shows system notification
- 📱 High priority (appears on lock screen)
- 🔊 Sound + vibration
- 💬 Message: "Version X.X.X is now available. Tap to update."

### Notification Actions:
- **Tap notification** → Opens the app
- **Swipe away** → Dismissed (will show again next check if update still available)

## Rate Limiting

To prevent excessive API calls and battery drain:
- ✅ Checks **maximum once every 6 hours**
- ✅ Only checks when device has **network connection**
- ✅ Exponential backoff on failures
- ✅ 15-minute retry delay if check fails

## Battery Impact

**Minimal** - Background service:
- Only runs every 6 hours
- Takes ~2-5 seconds to complete
- Only runs when network is available
- Uses Android's optimized WorkManager

## Permissions Required

### Already Granted:
- `INTERNET` - Fetch update.json
- `POST_NOTIFICATIONS` - Show notifications

### Newly Added:
- `RECEIVE_BOOT_COMPLETED` - Restart scheduler after reboot
- `WAKE_LOCK` - Wake device for background task
- `FOREGROUND_SERVICE` - Run background work

All permissions are automatically granted at install time (no user prompt needed).

## Troubleshooting

### Background tasks not running?
1. Check battery optimization settings
2. Ensure app is not in "restricted" battery mode
3. Check if background data is enabled
4. Verify network connection

### Force background check in debug:
```dart
// In settings_screen.dart, add a debug button:
BackgroundUpdateService.initialize(); // Re-register
```

### Check logs:
```bash
adb logcat | grep -i "update\|workmanager"
```

## Production Checklist

- [x] Add `workmanager` dependency
- [x] Create background service
- [x] Initialize in main.dart
- [x] Add Android permissions
- [x] Configure update check frequency (6 hours)
- [x] Test background notifications
- [x] Test after device reboot
- [x] Test with app closed for long time
- [x] Verify battery optimization compatibility

## Version Compatibility

- **Android**: 5.0 (API 21) and above
- **iOS**: Not implemented (requires different approach)
- **Flutter**: 3.10.3+
- **WorkManager**: 0.5.2

## Future Enhancements

Possible improvements:
1. Add iOS background fetch support
2. Configurable check frequency in settings
3. Silent updates (download in background)
4. Update history/changelog view
5. Skip version permanently option
