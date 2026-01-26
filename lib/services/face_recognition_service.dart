import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();

  factory FaceRecognitionService() {
    return _instance;
  }

  FaceRecognitionService._internal();

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter; 
  // Depending on package version `isolateInterpreter` might be the way for background threads, 
  // but standard Interpreter is fine for small models like MobileFaceNet on UI or simple background thread.

  bool get isModelLoaded => _interpreter != null;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      // Using XNNPACK Delegate for faster inference on Android if available
      if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());
      if (Platform.isIOS) options.addDelegate(GpuDelegate());

      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite', options: options);
      debugPrint('Face Recognition Model Loaded Successfully');
      
      // Warmup
       // MobileFaceNet input: [1, 112, 112, 3] usually
       // Let's verify shape if needed, but standard mobilefacenet is 112
    } catch (e) {
      debugPrint('Error loading face recognition model: $e');
    }
  }

  // Generate Embedding
  Future<List<double>?> generateEmbedding(CameraImage cameraImage, Face face) async {
    if (_interpreter == null) {
      debugPrint('Interpreter not initialized');
      return null;
    }

    try {
      // 1. Convert CameraImage to RGB Image
      img.Image? image = await _convertToImage(cameraImage);
      if (image == null) return null;

      // 2. Crop Face
      // Ensure bounds are within image validity
      int left = max(0, face.boundingBox.left.toInt());
      int top = max(0, face.boundingBox.top.toInt());
      int width = min(image.width - left, face.boundingBox.width.toInt());
      int height = min(image.height - top, face.boundingBox.height.toInt());

      img.Image faceImg = img.copyCrop(
        image, 
        x: left, 
        y: top, 
        width: width, 
        height: height
      );

      // 3. Resize to Model Input Size (112x112 for MobileFaceNet)
      img.Image resizedImg = img.copyResize(faceImg, width: 112, height: 112);

      // 4. Preprocess (Normalize)
      // MobileFaceNet expects -1 to 1 or 0 to 1 depending on training. 
      // Standard: (pixel - 128) / 128
      var input = _preProcess(resizedImg);

      // 5. Run Inference
      // Output shape is [1, 192] for MobileFaceNet (usually), sometimes [1, 128]
      // We need to check output tensor shape or assume 192/128 based on common models.
      // Let's dynamically handle it.
      
      var outputTensorShape = _interpreter!.getOutputTensor(0).shape; // e.g., [1, 192]
      int outputSize = outputTensorShape.last; 
      
      var output = List.filled(outputSize, 0.0).reshape([1, outputSize]);
      
      _interpreter!.run(input, output);
      
      // 6. Return flattened list
      List<double> embedding = List<double>.from(output[0]);
      return embedding;

    } catch (e) {
      debugPrint('Error generating embedding: $e');
      return null;
    }
  }

  // Preprocess: Convert Image to Float32 List [1, 112, 112, 3]
  List<dynamic> _preProcess(img.Image image) {
    // Flatten 112x112x3
    var input = Float32List(1 * 112 * 112 * 3).reshape([1, 112, 112, 3]);
    
    for (var y = 0; y < 112; y++) {
      for (var x = 0; x < 112; x++) {
        var pixel = image.getPixel(x, y);
        // Normalize: (Value - 127.5) / 128.0 is common for TFLite models
        // Or (Value - 128) / 128
        input[0][y][x][0] = (pixel.r - 128) / 128.0;
        input[0][y][x][1] = (pixel.g - 128) / 128.0;
        input[0][y][x][2] = (pixel.b - 128) / 128.0;
      }
    }
    return input;
  }

  // CameraImage Conversion
  Future<img.Image?> _convertToImage(CameraImage image) async {
    try {
      if (Platform.isAndroid && image.format.group == ImageFormatGroup.nv21) {
        return _convertNV21(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(image);
      }
      return null;
    } catch (e) {
      debugPrint("Image conversion error: $e");
      return null;
    }
  }

  // Simplified conversion - in production consider using existing libraries or FFI for speed
  img.Image _convertNV21(CameraImage image) {
    // Check if we have enough planes for YUV (needs 3 usually: Y, U, V)
    // Some devices/configurations might return a single plane (Y only or raw)
    if (image.planes.length < 3) {
      debugPrint('Warning: Image has ${image.planes.length} planes. Fallback to Grayscale.');
      return _convertYOnly(image);
    }

    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int? uvPixelStride = image.planes[1].bytesPerPixel;

    var imgBuffer = img.Image(width: width, height: height); 

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride! * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        
        // YUV to RGB conversion
        int r = (yp + (1.370705 * (vp - 128))).round().clamp(0, 255);
        int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128))).round().clamp(0, 255);
        int b = (yp + (1.732446 * (up - 128))).round().clamp(0, 255);

        imgBuffer.setPixelRgb(x, y, r, g, b);
      }
    }
    return imgBuffer;
  }
  
  // Fallback for single plane images
  img.Image _convertYOnly(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    var imgBuffer = img.Image(width: width, height: height);
    
    final plane = image.planes[0];
    final bytes = plane.bytes;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * width + x;
        if (index < bytes.length) {
            final pixel = bytes[index];
            imgBuffer.setPixelRgb(x, y, pixel, pixel, pixel); // Grayscale
        }
      }
    }
    return imgBuffer;
  }

  img.Image _convertBGRA8888(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  // Utilities
  double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }
}
