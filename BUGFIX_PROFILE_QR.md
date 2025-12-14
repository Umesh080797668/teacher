# Bug Fixes: Profile Image & QR Scanner

## Critical Fix Required: Database Schema Update

### 🚨 **ISSUE: Profile Picture Not Saving to Database**

**Root Cause:** The `TeacherSchema` in MongoDB was missing the `profilePicture` field!

**Evidence from logs:**
```
Saving new profile picture...
New profile picture saved at: /data/user/0/.../TCH828985185_profile_1765712592870.jpg
API Response: {...} ← NO profilePicture field!
Updated Teacher Profile: null
State updated with new profile picture: null
```

**Fixed in:**
- `backend/server.js` (line ~160)
- `server.js` (line ~48)

**Changes Made:**
```javascript
const TeacherSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: { type: String },
  password: { type: String, required: true },
  teacherId: { type: String, unique: true },
  status: { type: String, enum: ['active', 'inactive'], default: 'active' },
  profilePicture: { type: String }, // ← ADDED THIS FIELD
}, { timestamps: true });
```

**⚠️ IMPORTANT: You MUST restart the backend server for this to take effect!**

---

## Issues Fixed

### 1. QR Scanner Crash - setState() After dispose()

**Problem:**
```
setState() called after dispose(): _QRScannerScreenState#4c556(lifecycle state: defunct, not mounted)
```

This error occurred when the user closed the QR scanner screen (by pressing back or after an error) but callbacks still tried to update the UI.

**Solution:**
Added `mounted` checks before all `setState()` calls to ensure the widget is still in the tree:

**File:** `lib/screens/qr_scanner_screen.dart`

**Changes:**
1. Added `mounted` check in `_handleQRCode()` before processing QR code
2. Added `mounted` check before all `setState()` calls in error handling
3. Added `mounted` check in `_showSuccessDialog()` and `_showErrorDialog()`
4. Wrapped all setState calls with `if (mounted)` conditions

**Key improvements:**
```dart
void _handleQRCode(BarcodeCapture capture) async {
  if (_isProcessing || !mounted) return;  // Added !mounted check
  
  // ... processing code ...
  
  if (!mounted) return;  // Check before setState
  setState(() {
    _isProcessing = true;
  });
}

void _showErrorDialog(String message) {
  if (!mounted) return;  // Added mounted check
  
  // ... dialog code ...
  
  if (mounted) {  // Wrapped setState
    setState(() {
      _isProcessing = false;
    });
  }
}
```

---

### 2. Profile Image Not Displaying After Update

**Problem:**
After updating the profile image, the API successfully saved the image but the frontend didn't show the updated image. The image was saved locally but the widget wasn't properly refreshing.

**Solution:**
Multiple improvements to ensure proper image display and refresh:

**File:** `lib/screens/profile_screen.dart`

**Changes:**

1. **Added ValueKey to force widget rebuild:**
```dart
Image.file(
  File(_profilePicturePath!),
  key: ValueKey(_profilePicturePath),  // Forces rebuild when path changes
  fit: BoxFit.cover,
  // ...
)
```

2. **Added mounted checks in update flow:**
```dart
if (mounted) {
  setState(() {
    _teacher = updatedTeacher;
    _profilePicturePath = updatedTeacher.profilePicture;
    _isNewImage = false;
    _isEditing = false;
  });
}
```

3. **Enhanced error handling and loading indicators:**
```dart
Image.file(
  File(_profilePicturePath!),
  key: ValueKey(_profilePicturePath),
  fit: BoxFit.cover,
  width: 120,
  height: 120,
  errorBuilder: (context, error, stackTrace) {
    debugPrint('Error loading image: $error');
    return Icon(Icons.person, size: 60);
  },
)
```

4. **Added loading indicator for network images:**
```dart
Image.network(
  _profilePicturePath!,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return Center(
      child: CircularProgressIndicator(
        value: loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
            : null,
      ),
    );
  },
)
```

5. **Enhanced debug logging:**
```dart
debugPrint('New profile picture saved at: $savedImagePath');
debugPrint('API Response: $updatedTeacherData');
debugPrint('Updated Teacher Profile: ${updatedTeacher.profilePicture}');
debugPrint('State updated with new profile picture: $_profilePicturePath');
```

---

## 🔧 Required Actions

### Step 1: Restart Backend Server
```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance/backend"
pkill -f "node.*server.js"  # Stop existing server
node server.js              # Start with new schema
```

### Step 2: Rebuild Flutter App
```bash
cd "/home/imantha/Desktop/Attendance/mobile attendence/teacher_attendance"
flutter clean
flutter pub get
flutter run
```

### Step 3: Test Profile Update
1. Open app and login
2. Go to Profile screen
3. Take/select a new photo
4. Save the profile
5. **Check logs for:**
   - `ProfilePicture added to update: [path]`
   - `Teacher updated successfully: {...profilePicture: [path]...}`
   - `Updated Teacher Profile: [path]` (should NOT be null)

---

## Testing Instructions

### Backend Schema Fix:
1. Stop and restart backend server (see above)
2. Update a teacher profile with image
3. Check server logs for:
   ```
   Update teacher request - ID: TCH828985185
   Update data received: {... profilePicture: '/path/to/image.jpg'}
   ProfilePicture added to update: /path/to/image.jpg
   Teacher updated successfully: {... profilePicture: '/path/to/image.jpg' ...}
   ```

### QR Scanner Fix:
1. Open the app and navigate to QR Scanner
2. Try scanning an invalid QR code
3. Quickly press back button after seeing error
4. **Expected:** No crash, app returns to previous screen
5. Try scanning valid QR then press back during processing
6. **Expected:** No crash or error messages

### Profile Image Fix:
1. Go to Profile screen
2. Tap on profile picture
3. Select "Take Photo" or "Choose from Gallery"
4. Pick an image
5. Tap "Save" icon
6. **Expected:** Profile image should update immediately (not null)
7. Navigate away and back to profile
8. **Expected:** Profile image should persist

### Debug Output to Monitor:
```
// GOOD - Should see this:
Saving new profile picture...
New profile picture saved at: [local_path]
ProfilePicture added to update: [local_path]
Updated Teacher Profile: [local_path]  ← NOT NULL!
State updated with new profile picture: [local_path]

// BAD - If you still see this:
Updated Teacher Profile: null  ← Problem!
```

---

## Technical Notes

### Database Schema Update:
- MongoDB schemas must explicitly define all fields
- Without `profilePicture: { type: String }`, the field is ignored
- Existing documents won't have this field until updated
- No migration needed - field is optional

### Why mounted checks are important:
- Flutter widgets can be disposed while async operations are still running
- Calling `setState()` on a disposed widget causes crashes
- Always check `mounted` before `setState()` in async callbacks

### Why ValueKey forces widget rebuild:
- Flutter's widget tree optimization can cache widgets
- When the same widget displays different data, it may not rebuild
- `ValueKey` tied to the data ensures rebuild when data changes
- This is critical for `Image.file` and `Image.network` widgets

---

## Files Modified

### Backend (Schema Fix):
1. `/backend/server.js` - Added `profilePicture` field to `TeacherSchema`
2. `/server.js` - Added `profilePicture` field to `TeacherSchema`
3. `/backend/server.js` - Added debug logging to PUT endpoint

### Frontend (Display Fix):
1. `/lib/screens/qr_scanner_screen.dart` - Added mounted checks
2. `/lib/screens/profile_screen.dart` - Added ValueKey and improved image handling

---

## Troubleshooting

### If profile picture is still null after update:

1. **Verify backend server restarted:**
   ```bash
   ps aux | grep "node.*server.js"
   ```

2. **Check server logs when updating:**
   Should see: `ProfilePicture added to update: [path]`

3. **Test direct API call:**
   ```bash
   curl -X PUT http://localhost:3004/api/teachers/TCH828985185 \
     -H "Content-Type: application/json" \
     -d '{"name":"Test","email":"test@test.com","profilePicture":"/test/path.jpg"}'
   ```

4. **Check MongoDB directly:**
   ```javascript
   db.teachers.findOne({teacherId: "TCH828985185"})
   // Should have profilePicture field
   ```

### If QR scanner still crashes:

1. Check camera permissions
2. Check QR code format (must be valid JSON)
3. Check WebSocket connection
4. Look for "setState called after dispose" in logs

---

## Related Issues

If users still experience issues with profile images:

1. **Check file permissions:** Ensure app has storage permissions
2. **Check image size:** Very large images may fail to load
3. **Check storage space:** Device may be out of storage
4. **Check network:** If using network images, ensure connectivity
5. **Check logs:** Look for "Error loading image" in debug output
