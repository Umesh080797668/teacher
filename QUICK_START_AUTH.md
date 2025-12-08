# Authentication Screens - Quick Start Guide

## 🎨 Beautiful UI Features

### Splash Screen
- **Duration**: 3 seconds
- **Gradient Background**: Purple gradient (#6750A4 to #B39DDB)
- **Animations**:
  - Logo scales and fades in
  - Title slides up with fade
  - Smooth loading spinner
- **Auto-navigation**: Automatically moves to Login Screen

### Login Screen
- **Modern Card Design**: White card on gradient background
- **Input Fields**:
  - Email (with validation)
  - Password (with show/hide toggle)
- **Features**:
  - Remember Me checkbox
  - Forgot Password link
  - Sign Up navigation
  - Loading state with spinner
- **Validations**:
  - Valid email format required
  - Minimum 6 characters for password

### Registration Screen
- **Comprehensive Form**: All necessary teacher details
- **Input Fields**:
  - Full Name
  - Email
  - Phone Number
  - Password
  - Confirm Password
- **Features**:
  - Password visibility toggles
  - Terms and Conditions checkbox
  - Form validation
  - Loading state
  - Back to Login navigation
- **Validations**:
  - All fields required
  - Passwords must match
  - Terms must be accepted

### Home Screen (Enhanced)
- **New Feature**: Profile menu with logout
- **Logout Flow**:
  1. Tap profile avatar (top-right)
  2. Select "Logout"
  3. Redirected to Login Screen
  4. Session cleared

## 🚀 How to Run

1. **Navigate to project directory**:
   ```bash
   cd "mobile attendence/teacher_attendance"
   ```

2. **Install dependencies** (if not already done):
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## 📱 User Flow

```
App Launch
    ↓
[Splash Screen] (3 seconds)
    ↓
[Login Screen]
    ├─ Enter credentials → [Home Screen]
    └─ Don't have account? → [Registration Screen]
                                    ↓
                           Register → [Home Screen]

[Home Screen]
    └─ Profile Menu → Logout → [Login Screen]
```

## 🎯 Test the App

### Test Login:
1. Enter any email (e.g., `teacher@example.com`)
2. Enter any password (min 6 characters)
3. Click "Sign In"
4. Wait 2 seconds (simulated API call)
5. You'll be redirected to Home Screen

### Test Registration:
1. Click "Sign Up" on Login Screen
2. Fill all fields:
   - Name: `John Doe`
   - Email: `john@example.com`
   - Phone: `1234567890`
   - Password: `password123`
   - Confirm Password: `password123`
3. Check "I agree to Terms and Conditions"
4. Click "Sign Up"
5. Wait 2 seconds
6. You'll be redirected to Home Screen

### Test Remember Me:
1. On Login Screen, check "Remember me"
2. Login
3. Close and reopen the app
4. Your email will be pre-filled

### Test Logout:
1. From Home Screen, tap the profile avatar (top-right)
2. Select "Logout"
3. You'll be redirected to Login Screen
4. Session is cleared

## 🎨 Customization Tips

### Change Theme Colors:
Edit the gradient colors in each screen file:

**Splash Screen** (`lib/screens/splash_screen.dart`):
```dart
colors: [
  const Color(0xFF6750A4),  // Primary
  const Color(0xFF8B7AB8),  // Secondary
  const Color(0xFFB39DDB),  // Accent
],
```

**Login/Registration Screens**:
```dart
colors: [
  const Color(0xFF6750A4),
  const Color(0xFF8B7AB8),
],
```

### Change Splash Duration:
In `lib/screens/splash_screen.dart`:
```dart
Timer(const Duration(seconds: 3), () { // Change this number
  // ... navigation code
});
```

### Change App Logo:
Update the icon in screens:
```dart
Icon(
  Icons.school_rounded,  // Change this icon
  size: 70,
  color: Color(0xFF6750A4),
)
```

## 🔧 Backend Integration

Currently using mock authentication. To connect to your backend:

### 1. Update Login Screen (`lib/screens/login_screen.dart`):
```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);

  try {
    // Replace this with your API call
    final response = await ApiService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    
    if (response.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_email', response.email);
      await prefs.setString('user_name', response.name);
      await prefs.setString('auth_token', response.token);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      throw Exception(response.message);
    }
  } catch (e) {
    // Show error
  }
}
```

### 2. Update Registration Screen:
Similar pattern as login, but call the registration API endpoint.

### 3. Add API Service Methods:
In `lib/services/api_service.dart`, add:
```dart
static Future<LoginResponse> login({
  required String email,
  required String password,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'email': email, 'password': password}),
  );
  
  if (response.statusCode == 200) {
    return LoginResponse.fromJson(json.decode(response.body));
  } else {
    throw Exception('Login failed');
  }
}
```

## 📝 Features Overview

| Feature | Status | Description |
|---------|--------|-------------|
| Splash Screen | ✅ | Beautiful animated loading screen |
| Login Screen | ✅ | Email/password authentication |
| Registration | ✅ | New user signup |
| Remember Me | ✅ | Save credentials locally |
| Session Management | ✅ | Persistent login state |
| Logout | ✅ | Clear session and return to login |
| Form Validation | ✅ | Email, password validation |
| Loading States | ✅ | Visual feedback during API calls |
| Animations | ✅ | Smooth transitions and effects |
| Profile Menu | ✅ | Access to logout and settings |

## 🎬 Animation Details

### Splash Screen:
- **Fade Animation**: 0-50% of animation duration
- **Scale Animation**: Logo grows from 0.5 to 1.0
- **Slide Animation**: Title slides from 50% down to center

### Login/Registration:
- **Fade In**: All elements fade in on load
- **Slide Up**: Form slides up slightly for smooth entry

## 🔒 Security Notes

⚠️ **Important**: This is a frontend implementation with mock authentication.

For production:
1. Never store passwords in SharedPreferences
2. Use secure tokens (JWT) instead
3. Implement HTTPS for all API calls
4. Add token refresh mechanism
5. Implement proper session timeout
6. Add two-factor authentication
7. Use secure storage for sensitive data

## 📚 Additional Resources

- **Main Documentation**: See `AUTH_SCREENS.md` for detailed technical documentation
- **Flutter Documentation**: https://flutter.dev/docs
- **Material Design**: https://m3.material.io/
- **Google Fonts**: https://fonts.google.com/

## 🐛 Common Issues

### Issue: "Remember Me" not working
**Solution**: Make sure SharedPreferences is properly initialized

### Issue: Session persists after logout
**Solution**: Ensure all SharedPreferences keys are cleared in logout method

### Issue: Animations stuttering
**Solution**: Test on a physical device instead of emulator for best performance

## ✨ Next Steps

1. **Test all flows** on a device or emulator
2. **Customize colors** to match your brand
3. **Connect to backend** API
4. **Add error handling** for network issues
5. **Implement forgot password** functionality
6. **Add email verification** process
7. **Create profile screen** for viewing/editing user info

## 🎉 You're All Set!

The authentication system is now fully integrated into your Teacher Attendance app. Enjoy the beautiful, modern UI and smooth user experience!

For questions or issues, refer to the main project documentation.
