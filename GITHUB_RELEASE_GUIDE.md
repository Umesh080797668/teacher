# GitHub Release Guide for Teacher Attendance App

## Overview
This guide explains how to release version 1.0.9 (and future versions) using GitHub Releases. No custom scripts needed!

## ✅ What's Been Set Up

1. **Updated version**: `pubspec.yaml` now shows version `1.0.9+9`
2. **GitHub Actions workflow**: `.github/workflows/release.yml` automatically builds and uploads APK when you create a release
3. **Automatic update.json**: The workflow updates this file automatically

## 🚀 How to Release Version 1.0.9

### Step 1: Commit and Push Changes
```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance"
git add .
git commit -m "Bump version to 1.0.9"
git push origin main
```

### Step 2: Create a GitHub Release
1. Go to your repository on GitHub: `https://github.com/Umesh080797668/teacher`
2. Click on **"Releases"** (on the right sidebar)
3. Click **"Draft a new release"**
4. Fill in the release form:
   - **Tag version**: `v1.0.9` (must start with 'v')
   - **Release title**: `Version 1.0.9`
   - **Description**: Add release notes, for example:
     ```
     ## What's New in v1.0.9
     - Bug fixes and performance improvements
     - UI enhancements
     - Stability improvements
     ```
5. Click **"Publish release"**

### Step 3: Wait for Build
- GitHub Actions will automatically start building the APK
- You can watch the progress in the **"Actions"** tab
- Build takes about 5-10 minutes

### Step 4: APK is Ready!
- Once complete, the APK will be attached to your release
- Named: `teacher-attendance-v1.0.9.apk`
- The `update.json` file will be automatically updated in your repository

## 📱 What Happens Automatically

1. ✅ Checks out your code
2. ✅ Sets up Flutter and Java
3. ✅ Runs `flutter pub get`
4. ✅ Builds release APK
5. ✅ Uploads APK to the GitHub release
6. ✅ Updates `update.json` with version info and release notes
7. ✅ Commits and pushes `update.json` back to main branch

## 🔄 For Future Releases (1.0.10, 1.0.11, etc.)

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.10+10  # Increment both version and build number
   ```

2. Commit and push:
   ```bash
   git add pubspec.yaml
   git commit -m "Bump version to 1.0.10"
   git push origin main
   ```

3. Create GitHub release with tag `v1.0.10`

4. Done! 🎉

## 🔍 Monitoring Your Release

- **Actions Tab**: See build progress and logs
- **Releases Tab**: Download APK and see all releases
- **update.json**: Automatically updated in your repository

## ⚠️ Important Notes

- Always push changes **before** creating the release
- Tag must match the version in `pubspec.yaml` (e.g., v1.0.9)
- The workflow only triggers on **published** releases (not drafts)
- Keep your Flutter version updated in the workflow if needed

## 🐛 Troubleshooting

### Build Fails
- Check the Actions tab for detailed error logs
- Ensure `pubspec.yaml` is valid
- Verify all dependencies are correct

### APK Not Attached
- Workflow must complete successfully (green checkmark in Actions)
- Check that you published the release (not just saved as draft)

### update.json Not Updated
- The workflow might need write permissions
- Go to Settings → Actions → General → Workflow permissions
- Enable "Read and write permissions"

## 🎯 Benefits Over Custom Scripts

✅ No manual APK building
✅ No manual upload to GitHub
✅ Automated `update.json` generation
✅ Full build logs and history
✅ Easy rollback to previous releases
✅ Professional CI/CD pipeline
✅ Works from any computer (just create GitHub release)
