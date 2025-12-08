# Setup & Run Guide

## Prerequisites
- Flutter SDK (3.10.3 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extension
- Android Emulator or Physical Device

## Installation Steps

### 1. Install Dependencies
```bash
cd "mobile attendence/teacher_attendance"
flutter pub get
```

### 2. Check Flutter Setup
```bash
flutter doctor
```

### 3. Start the Backend Server
The mobile app requires the backend server to be running:
```bash
cd backend
npm install
npm start
```

The backend should be running on `http://localhost:3001`

### 4. Configure API Endpoint
If running on a physical device, update the API endpoint in:
`lib/services/api_service.dart`

Change:
```dart
static const String baseUrl = 'http://localhost:3001';
```

To your computer's IP address:
```dart
static const String baseUrl = 'http://192.168.1.X:3001';
```

### 5. Run the App

#### On Android Emulator
```bash
flutter run
```

#### On Specific Device
```bash
flutter devices  # List available devices
flutter run -d <device_id>
```

#### In Release Mode
```bash
flutter run --release
```

## Hot Reload & Hot Restart

While the app is running:
- Press `r` to hot reload
- Press `R` to hot restart
- Press `q` to quit

## Building for Production

### Android APK
```bash
flutter build apk --release
```

The APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

### iOS (requires macOS)
```bash
flutter build ios --release
```

## Troubleshooting

### Issue: "Unable to connect to server"
- Ensure backend is running
- Check API endpoint URL
- For physical devices, use computer's IP instead of localhost

### Issue: "Package not found"
```bash
flutter clean
flutter pub get
```

### Issue: "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Issue: Font loading errors
Fonts are loaded from Google Fonts at runtime. Ensure:
- Device has internet connection on first run
- Fonts will be cached after first load

## Development Tips

### Enable Flutter DevTools
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

### View Logs
```bash
flutter logs
```

### Analyze Code
```bash
flutter analyze
```

### Format Code
```bash
flutter format .
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── student.dart
│   └── attendance.dart
├── providers/                # State management
│   ├── students_provider.dart
│   └── attendance_provider.dart
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── students_screen.dart
│   ├── attendance_mark_screen.dart
│   └── attendance_view_screen.dart
├── services/                 # API services
│   └── api_service.dart
├── utils/                    # Utilities & constants
│   └── app_colors.dart
└── widgets/                  # Reusable widgets
    └── custom_widgets.dart
```

## Features

✅ Modern Material Design 3 UI
✅ Student Management
✅ Attendance Marking
✅ Attendance Viewing with Charts
✅ Statistics Dashboard
✅ Swipe Gestures
✅ Empty States
✅ Loading States
✅ Error Handling

## Performance Optimization

The app uses:
- Provider for efficient state management
- ListView.builder for lazy loading
- Consumer widgets for targeted rebuilds
- Cached network images (Google Fonts)

## Testing

### Run Tests
```bash
flutter test
```

### Run Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

## Next Steps

1. Configure your backend server
2. Add students
3. Mark attendance
4. View statistics and reports

## Support

For issues or questions:
- Check the ENHANCEMENTS.md file
- Review the inline code documentation
- Check Flutter documentation: https://flutter.dev

---

Happy coding! 🚀
