# Release Notes v1.0.22

## 🐛 Bug Fixes
- **Update Installation**: Fixed "Package Parse Error" during in-app updates by ensuring the correct `FileProvider` authority is used.
- **Download Validation**: Improved download logic to prevent saving corrupt files (e.g., 404 error pages) as APKs.
- **APK Optimization**: Removed unused x86 architectures to reduce APK size and improve compatibility with ARM devices.

## 🔧 Technical Details
- Updated `AndroidManifest.xml` to use `.installFileProvider` authority.
- Updated `update_service.dart` to validate HTTP 200 status before saving downloads.
- Updated `build.gradle.kts` to filter ABIs to `armeabi-v7a` and `arm64-v8a`.
