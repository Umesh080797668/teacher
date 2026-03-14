// Web stub for FaceRecognitionService.
// TFLite / dart:ffi / camera / ML Kit are NOT supported on the web target.
// This stub keeps the app compiling for web without the native FFI code.

import 'package:flutter/foundation.dart';

class FaceRecognitionService {
  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();

  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  bool get isModelLoaded => false;

  Future<void> loadModel() async {
    debugPrint('FaceRecognitionService: not supported on web.');
  }

  /// Always returns null on web — no inference possible without TFLite/FFI.
  Future<List<double>?> generateEmbedding(dynamic cameraImage, dynamic face) async {
    debugPrint('FaceRecognitionService.generateEmbedding: not supported on web.');
    return null;
  }

  double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      final diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sum == 0 ? 0 : sum; // just return squared distance as a stub
  }
}
