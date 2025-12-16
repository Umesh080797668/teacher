#!/bin/bash

# GitHub Release Creator for v1.0.26
# This script helps you create a GitHub release manually

echo "======================================"
echo "GitHub Release Creator - v1.0.26"
echo "======================================"
echo ""

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
VERSION="v1.0.26"
REPO="Umesh080797668/teacher"

echo "Version: $VERSION"
echo "APK Location: $APK_PATH"
echo ""

# Check if APK exists
if [ ! -f "$APK_PATH" ]; then
    echo "❌ Error: APK file not found at $APK_PATH"
    echo "Please build the APK first using: flutter build apk --release"
    exit 1
fi

echo "✅ APK file found!"
echo "APK Size: $(ls -lh "$APK_PATH" | awk '{print $5}')"
echo ""

echo "📋 Next Steps to Create GitHub Release:"
echo ""
echo "1. Go to: https://github.com/$REPO/releases/new"
echo ""
echo "2. Fill in the release form:"
echo "   - Tag: $VERSION"
echo "   - Release title: Teacher Attendance v1.0.26 - QR Code & Session Fixes"
echo ""
echo "3. Copy and paste these release notes:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat RELEASE_NOTES_v1.0.26.md
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "4. Upload the APK file from: $APK_PATH"
echo "   (Drag and drop or use the file selector)"
echo ""
echo "5. Check 'Set as the latest release'"
echo ""
echo "6. Click 'Publish release'"
echo ""
echo "======================================"
echo ""
echo "Or install GitHub CLI and run:"
echo "gh release create $VERSION '$APK_PATH' --title 'Teacher Attendance v1.0.26 - QR Code & Session Fixes' --notes-file RELEASE_NOTES_v1.0.26.md"
echo "  sudo apt install gh"
echo "  gh auth login"
echo "  gh release create $VERSION $APK_PATH --title 'Teacher Attendance v1.0.11 - Personalized Welcome' --notes-file RELEASE_NOTES_v1.0.11.md"
echo ""
echo "======================================"
