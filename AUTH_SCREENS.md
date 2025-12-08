# Authentication Screens Documentation

## Overview
This document describes the new authentication flow implemented in the Teacher Attendance app, including splash screen, login, and registration screens.

## Features Implemented

### 1. Splash Screen (`splash_screen.dart`)
A beautiful loading screen that displays when the app starts.

**Features:**
- Smooth animations (fade, scale, and slide effects)
- Gradient background with app colors
- App logo with circular container
- Loading indicator
- Auto-navigates to login screen after 3 seconds

**Animations:**
- Logo fade-in and scale animation
- Title slide-up animation
- Loading spinner

### 2. Login Screen (`login_screen.dart`)
Allows teachers to sign in to the app.

**Features:**
- Email and password input fields
- Password visibility toggle
- Remember me checkbox
- Forgot password link (placeholder)
- Form validation
- Loading state during authentication
- Smooth animations on screen load
- Navigation to registration screen
- Saves credentials when "Remember me" is checked

**Validation:**
- Email must be valid format
- Password must be at least 6 characters

### 3. Registration Screen (`registration_screen.dart`)
Allows new teachers to create an account.

**Features:**
- Full name input
- Email input
- Phone number input
- Password and confirm password fields
- Password visibility toggles
- Terms and conditions checkbox
- Form validation
- Loading state during registration
- Smooth animations on screen load
- Navigation back to login screen

**Validation:**
- All fields are required
- Email must be valid format
- Password must be at least 6 characters
- Confirm password must match password
- Must agree to terms and conditions

### 4. Auth Provider (`auth_provider.dart`)
Manages authentication state across the app.

**Features:**
- Persistent login state using SharedPreferences
- User email and name storage
- Login and logout methods
- Loading state management
- Notifies listeners on state changes

## Color Scheme
The authentication screens use a beautiful purple gradient:
- Primary: `#6750A4`
- Secondary: `#8B7AB8`
- Accent: `#B39DDB`

## User Flow

```
App Start
    ↓
Splash Screen (3 seconds)
    ↓
Login Screen
    ├─→ Sign In → Home Screen
    └─→ Sign Up → Registration Screen
            ↓
        Registration Complete → Home Screen
```

## Implementation Details

### Session Management
- Uses `SharedPreferences` for persistent storage
- Stores:
  - `is_logged_in`: Boolean flag
  - `user_email`: User's email address
  - `user_name`: User's full name
  - `saved_email`: Saved email for "Remember me" feature
  - `remember_me`: Boolean flag for remember me preference

### Logout Functionality
Users can logout from the Home Screen via:
1. Tap the profile avatar in the top-right corner
2. Select "Logout" from the dropdown menu
3. User is redirected to Login Screen
4. All session data is cleared

## Files Created/Modified

### New Files:
1. `lib/screens/splash_screen.dart` - Splash/Loading screen
2. `lib/screens/login_screen.dart` - Login screen
3. `lib/screens/registration_screen.dart` - Registration screen
4. `lib/providers/auth_provider.dart` - Authentication state management

### Modified Files:
1. `lib/main.dart` - Updated to use SplashScreen and AuthProvider
2. `lib/screens/home_screen.dart` - Added logout functionality

## Dependencies Used
- `google_fonts` - For Poppins font
- `provider` - For state management
- `shared_preferences` - For persistent storage

## API Integration (TODO)
Currently, the login and registration use mock API calls with 2-second delays. To integrate with a real backend:

1. Update the `_login()` method in `login_screen.dart`
2. Update the `_register()` method in `registration_screen.dart`
3. Implement proper API calls in `lib/services/api_service.dart`

Example:
```dart
// In login_screen.dart
final response = await ApiService.login(_emailController.text, _passwordController.text);
if (response.success) {
  // Handle success
} else {
  // Handle error
}
```

## Customization

### Change Colors
Update the gradient colors in each screen file:
```dart
colors: [
  const Color(0xFF6750A4),  // Your primary color
  const Color(0xFF8B7AB8),  // Your secondary color
],
```

### Change Animation Duration
In `splash_screen.dart`:
```dart
Timer(const Duration(seconds: 3), () { // Change seconds value
  // Navigation code
});
```

### Change Logo Icon
Update the icon in each screen:
```dart
Icon(
  Icons.school_rounded,  // Change to your preferred icon
  size: 70,
  color: Color(0xFF6750A4),
)
```

## Testing Credentials
For development/testing, you can use any email and password (minimum 6 characters).

## Future Enhancements
- [ ] Forgot password functionality
- [ ] Email verification
- [ ] Social login (Google, Facebook)
- [ ] Biometric authentication
- [ ] Two-factor authentication
- [ ] Profile picture upload
- [ ] Email/SMS verification codes
- [ ] Password strength indicator
- [ ] Terms and conditions viewer

## Screenshots
The app features:
- Modern Material Design 3
- Smooth animations and transitions
- Responsive layouts
- Beautiful gradient backgrounds
- Clean, professional UI

## Support
For issues or questions, please refer to the main README.md file.
