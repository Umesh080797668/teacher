# Quick Start Guide

## 🚀 Get Started in 3 Steps

### Step 1: Install Dependencies
```bash
cd "mobile attendence/teacher_attendance"
flutter pub get
```

### Step 2: Start Backend Server
```bash
cd backend
npm install
npm start
```
Backend runs on: `http://localhost:3001`

### Step 3: Run the App
```bash
flutter run
```

---

## 📱 App Structure

```
Home Screen (/)
├── Students (/students)
│   └── Add/View/Delete students
├── Mark Attendance (/attendance/mark)
│   └── Mark daily attendance
├── View Records (/attendance/view)
│   └── View attendance history & charts
└── Reports (Coming Soon!)
```

---

## 🎨 Key Features

### Students Management
- ✅ Add new students
- ✅ View student list with avatars
- ✅ Swipe to delete
- ✅ Statistics dashboard

### Mark Attendance
- ✅ Select date & session
- ✅ Quick status selection (P/A/L)
- ✅ Batch save
- ✅ Live statistics

### View Attendance
- ✅ Filter by month/year
- ✅ Pie chart visualization
- ✅ Detailed records
- ✅ Statistics summary

---

## 🛠️ Common Commands

### Development
```bash
flutter run                 # Run app
flutter run --release       # Release mode
flutter hot-reload          # Press 'r' while running
flutter hot-restart         # Press 'R' while running
```

### Building
```bash
flutter build apk           # Android APK
flutter build appbundle     # Android Bundle
flutter build ios           # iOS (macOS only)
```

### Debugging
```bash
flutter logs                # View logs
flutter analyze             # Analyze code
flutter clean               # Clean build
```

---

## 🎨 Color Reference

| Color | Hex | Usage |
|-------|-----|-------|
| 🟣 Purple | #6750A4 | Primary brand color |
| 🟢 Green | #4CAF50 | Present status |
| 🔴 Red | #E53935 | Absent status |
| 🟠 Orange | #FF9800 | Late status |

---

## 📖 Documentation Files

1. **ENHANCEMENTS.md** - Full feature list
2. **SETUP_GUIDE.md** - Detailed setup
3. **UI_REFERENCE.md** - Design system
4. **BEFORE_AFTER.md** - Visual comparison
5. **FRONTEND_SUMMARY.md** - Enhancement summary

---

## 🐛 Troubleshooting

### Cannot connect to server
→ Check backend is running on port 3001
→ For physical devices, use computer's IP address

### Packages not found
```bash
flutter clean
flutter pub get
```

### Build errors
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

---

## 📞 Need Help?

1. Check documentation files
2. Run `flutter doctor`
3. Visit https://flutter.dev

---

**Ready to go!** 🎉
