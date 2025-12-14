# Release Notes - Version 1.0.25

## 🎯 Release Date
December 14, 2025

## 📝 Summary
This release focuses on fixing critical bugs related to student name display and profile picture updates, while also adding powerful new features for attendance reporting by class.

---

## ✅ Bug Fixes

### 1. Student Name Display in View Attendance
**Problem:** View attendance screen was showing database IDs instead of actual student names
**Solution:** 
- Added `StudentsProvider` integration to fetch student data
- Updated UI to display student names with their ID as subtitle
- Implemented proper error handling for missing student records

### 2. Profile Picture Not Updating
**Problem:** Teacher profile pictures were not being saved/updated properly
**Solution:**
- Fixed backend API to properly handle `profilePicture` field in updates
- Improved frontend logic with `_isNewImage` flag for better tracking
- Fixed both `backend/server.js` and `server.js` endpoints
- Enhanced image path handling for more reliable updates

---

## 🆕 New Features

### 1. Daily Attendance Checker by Class
- Added new section in Reports > Attendance Summary tab
- Shows today's attendance for each class separately
- Displays:
  - Total students per class
  - Present/Absent/Late counts
  - Attendance rate with visual progress bar
  - Color-coded indicators (green ≥75%, orange <75%)

### 2. Monthly Statistics by Class
- Completely redesigned Monthly Stats tab
- Now shows statistics grouped by class instead of combined
- Each class shows:
  - Last 12 months of attendance data
  - Monthly breakdown with present/absent/late counts
  - Average attendance rate per month
  - Visual progress indicators

---

## 🔧 Technical Improvements

### Backend Changes:
- Updated `/api/reports/daily-by-class` - New endpoint for daily class reports
- Updated `/api/reports/monthly-by-class` - New endpoint for monthly class statistics
- Enhanced `/api/teachers/:id` - Now properly handles `profilePicture` and `phone` fields
- Improved error handling and logging

### Frontend Changes:
- Enhanced `ReportsProvider` with new data streams
- Added `getDailyByClass()` and `getMonthlyByClass()` to `ApiService`
- Improved profile screen with better image tracking
- Better UI for attendance reports with cards and progress bars

---

## 📊 API Endpoints Added

1. **GET** `/api/reports/daily-by-class?teacherId=xxx&date=yyyy-mm-dd`
   - Returns daily attendance statistics grouped by class

2. **GET** `/api/reports/monthly-by-class?teacherId=xxx`
   - Returns monthly attendance statistics grouped by class

---

## 🎨 UI Improvements

- Enhanced attendance view with student names prominently displayed
- Improved profile picture upload/update flow
- Better visual feedback for class-level attendance reports
- Added progress bars and color coding for quick insights
- More intuitive class-based statistics presentation

---

## 🔄 Upgrade Notes

### For Users:
1. Profile pictures will now update correctly when changed
2. View attendance shows actual student names for better readability
3. New class-based reports available in Reports tab
4. No data migration required

### For Developers:
- Backend now requires `profilePicture` field handling in teacher updates
- New provider methods for class-based reports
- Updated API service with new endpoints

---

## 🐛 Known Issues
None at this time

---

## 📱 Installation

### From GitHub Release:
1. Download `app-release.apk` from [GitHub Releases](https://github.com/Umesh080797668/teacher/releases/tag/1.0.25)
2. Enable "Install from Unknown Sources" if prompted
3. Install the APK
4. App will auto-update if you have a previous version installed

### Auto-Update:
- App will notify users about this update automatically
- Users can update directly from within the app

---

## 🙏 Acknowledgments

Thank you to all users who reported the student name display issue and profile picture update bug. Your feedback helps make this app better!

---

## 📞 Support

If you encounter any issues, please:
1. Check the [GitHub Issues](https://github.com/Umesh080797668/teacher/issues)
2. Contact support through the app
3. Review the troubleshooting guide in the repository

---

**Previous Version:** 1.0.24  
**Current Version:** 1.0.25  
**Build Number:** 25
