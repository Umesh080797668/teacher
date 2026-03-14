// Conditional import — routes to the native mobile implementation on
// Android/iOS and to a no-op web stub when compiling for the browser.
//
// Usage in any screen:
//   import '../services/face_recognition_service.dart';
//
// The FaceRecognitionService class API is identical in both files.

export 'face_recognition_service_web.dart'
    if (dart.library.io) 'face_recognition_service_mobile.dart';
