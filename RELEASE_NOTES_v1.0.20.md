# Release Notes - Version 1.0.20

**Release Date:** TBD  
**Version:** 1.0.20+20

## 🎨 UI/UX Improvements

### Authentication Screens - Text Field Visibility
Fixed text field visibility issues across all authentication screens when filling in information:

- **Login Screen**: Enhanced text input, label, and icon visibility with proper color styling
- **Registration Screen**: Improved visibility for all 5 form fields (name, email, phone, password, confirm password)
- **Forgot Password Screen**: Fixed email field visibility
- **Reset Password Screen**: Enhanced password and confirm password field visibility

**Technical Details:**
- Added explicit color styling: `Colors.black87` for text input, `Colors.grey[700]` for labels/icons
- Improved focus state with theme-based colors
- Enhanced border visibility in both enabled and focused states

### Loading Button Visibility
Replaced confusing white space loading state with clear loading indicators:

- **Sign In**: Shows "Signing in..." with spinner
- **Create Account**: Shows "Creating account..." with spinner
- **Send Reset Code**: Shows "Sending code..." with spinner
- **Reset Password**: Shows "Resetting..." with spinner

**Technical Details:**
- Changed from single CircularProgressIndicator to Row layout with indicator + descriptive text
- Added disabled state colors for better visibility
- Consistent styling across all authentication flows

### Dark Mode Enhancements
Fixed visibility issues in dark mode for backup and restore functionality:

- **Backup Files Header**: Now clearly visible in dark mode
- **Restore Backup Dialog**: Enhanced with proper background and text colors
- **Delete Backup Dialog**: Fixed header and text visibility

**Technical Details:**
- Applied `Theme.of(context).colorScheme.onSurface` for text
- Added `Theme.of(context).colorScheme.surface` for dialog backgrounds
- Consistent theme-aware styling throughout

### Backup Text Clarification
Updated misleading text about backup storage location:

- **Before**: "Automatically backup data to cloud"
- **After**: "Automatically backup data to local device"

**Note**: The backup service has always saved data locally to the device, not to any cloud/server. This change corrects the UI text to accurately reflect the actual behavior.

## 🔧 Android Optimizations

### Graphics Performance
Fixed GraphicBuffer allocation errors and improved rendering:

- Enabled explicit hardware acceleration
- Added NDK filters for ARM architectures
- Configured vector drawable support
- Optimized packaging options

### Memory Management
Enhanced memory handling for better stability:

- Implemented `onTrimMemory()` callback for memory pressure handling
- Added parallel builds and build caching
- Configured D8 compiler for better performance

### Build Configuration
Improved Android build system:

- Updated ProGuard rules for release builds
- Enabled OnBackInvokedCallback to fix Android 14+ warnings
- Optimized Gradle properties for faster builds

## 📱 Technical Changes

### Modified Files
**Flutter/Dart:**
- `lib/screens/login_screen.dart`
- `lib/screens/registration_screen.dart`
- `lib/screens/forgot_password_screen.dart`
- `lib/screens/reset_password_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/backup_restore_screen.dart`

**Android:**
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/java/.../MainActivity.java`
- `android/app/proguard-rules.pro`
- `android/gradle.properties`

### Version Update
- Updated from version 1.0.19+19 to 1.0.20+20
- Updated pubspec.yaml accordingly

## 🐛 Bug Fixes

1. **Fixed Android GraphicBuffer Errors**: Resolved allocation errors in Android build logs
2. **Fixed OnBackInvokedCallback Warnings**: Eliminated warnings for Android 14+ devices
3. **Fixed Text Field Visibility**: All authentication forms now have clearly visible text while typing
4. **Fixed Loading State**: Loading buttons now show meaningful progress instead of white space
5. **Fixed Dark Mode Dialogs**: Backup dialogs are now fully visible in dark mode
6. **Fixed Reset Password Syntax**: Corrected syntax error in reset password loading button

## 📝 Notes

- All changes are backward compatible
- No database schema changes
- No API changes
- Existing user data remains intact
- Backup files remain compatible

## 🔮 Future Improvements

- Consider additional loading states for other operations
- Explore more dark mode refinements
- Continue Android performance optimizations

---

**Full Changelog:** v1.0.19...v1.0.20
