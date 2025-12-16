# Release Notes - v1.0.26

## 📱 Teacher Attendance App v1.0.26

**Release Date:** December 16, 2025

---

## 🔧 Bug Fixes

### QR Code Company Association Fix
- **Issue:** Teachers were not being added to companies when scanning QR codes from the admin dashboard
- **Root Cause:** QR code generation endpoint was missing `companyId` in the session data
- **Fix:** Updated Vercel serverless function to include `companyId` in QR code data and session storage
- **Impact:** Teachers now properly join companies when scanning QR codes

### Web Session Authentication Improvements
- **Issue:** Session authentication flow had issues with multi-company support
- **Fix:** Enhanced session validation and company association logic
- **Impact:** More reliable teacher login and company management

### Environment Configuration Fix
- **Issue:** App crashed with `FileNotFoundError` for missing `.env` file
- **Fix:** Added `.env` file and updated `pubspec.yaml` to include it in assets
- **Impact:** App now loads properly without environment configuration errors

### Active Sessions Tab Error
- **Issue:** "Cannot read properties of undefined (reading 'charAt')" error in admin dashboard
- **Root Cause:** Backend returned sessions with undefined teacher data
- **Fix:** Added safe fallbacks for missing teacher name/email and updated type definitions
- **Impact:** Active Sessions tab now displays properly even with incomplete data

---

## ✨ Improvements

### Enhanced QR Code Generation
- QR codes now include company identification for better validation
- Improved error handling in QR generation process
- More robust session creation with proper data validation

### Admin Dashboard Enhancements
- Better teacher management interface
- Improved session monitoring and logout functionality
- Enhanced error handling for edge cases

### Update System Improvements
- Comprehensive release notes in update notifications
- Better version checking and update prompts
- Improved user experience during app updates

---

## 📋 Technical Updates

### Backend Changes
- Updated `/api/web-session/generate-qr` endpoint to require and store `companyId`
- Enhanced `/api/web-session/teacher-sessions` with proper data formatting
- Improved session data population with teacher information

### Frontend Changes
- Updated admin dashboard to handle missing teacher data gracefully
- Enhanced type definitions for better TypeScript support
- Improved error handling in session management

### Configuration Updates
- Added `.env` and `.env.example` files for environment management
- Updated `pubspec.yaml` to include environment files in assets
- Enhanced build configuration for better release management

---

## 🔄 Migration Notes

### For Existing Users
- No manual migration required - all changes are backward compatible
- QR codes generated after this update will include company information
- Active sessions will display properly in the admin dashboard

### For Developers
- Ensure `.env` file is present in the Flutter project root
- Update any custom QR generation logic to include `companyId`
- Review session handling code for improved error resilience

---

## 📊 Version Information

- **Version:** 1.0.26
- **Build:** 26
- **Previous Version:** 1.0.25
- **Release Type:** Minor Update with Bug Fixes

---

## 🐛 Known Issues

- None reported for this release

---

## 📞 Support

For support or bug reports, please create an issue on the GitHub repository or contact the development team.

---

**Checksum (SHA-256):** `app-release.apk`
*Note: Checksum will be provided when APK is uploaded to GitHub Releases*