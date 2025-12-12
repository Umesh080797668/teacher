# Release Notes v1.0.21

## ✨ New Features
- **Delete Student**: Added the ability to delete students directly from the students list by swiping left or using the delete action.

## 🐛 Bug Fixes
- **Students Screen Crash**: Fixed a critical issue where `setState() or markNeedsBuild() called during build` exception was thrown when loading students. This was caused by notifying listeners during the widget build phase.
- **Stability**: Improved the stability of the student loading process.

## 🔧 Technical Details
- Wrapped `_loadStudents` in `WidgetsBinding.instance.addPostFrameCallback` to ensure it runs after the build phase.
- Implemented `deleteStudent` in `ApiService` and `StudentsProvider`.
- Updated `StudentsScreen` to use the new delete functionality with a confirmation dialog.
