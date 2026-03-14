import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Data class to pass to isolate
class _ProcessingData {
  final List<Uint8List> planesBytes;
  final List<int> planesBytesPerRow;
  final List<int?> planesBytesPerPixel;
  final int width;
  final int height;
  final ImageFormatGroup formatGroup;
  final int cropX;
  final int cropY;
  final int cropW;
  final int cropH;

  _ProcessingData({
    required this.planesBytes,
    required this.planesBytesPerRow,
    required this.planesBytesPerPixel,
    required this.width,
    required this.height,
    required this.formatGroup,
    required this.cropX,
    required this.cropY,
    required this.cropW,
    required this.cropH,
  });
}

// Top-level function for isolate
List<dynamic> _processImageInIsolate(_ProcessingData data) {
  img.Image? image;

  // 1. Convert to RGB Image
  if (Platform.isAndroid && data.formatGroup == ImageFormatGroup.nv21) {
    image = _convertNV21(data);
  } else if (data.formatGroup == ImageFormatGroup.bgra8888) {
    image = _convertBGRA8888(data);
  } else if (data.formatGroup == ImageFormatGroup.yuv420) {
    // Fallback for yuv420 if nv21 not matched exactly (some androids)
    image = _convertNV21(data);
  }

  if (image == null) return [];

  // 2. Crop Face
  int left = max(0, data.cropX);
  int top = max(0, data.cropY);
  int width = min(image.width - left, data.cropW);
  int height = min(image.height - top, data.cropH);

  img.Image faceImg = img.copyCrop(
    image,
    x: left,
    y: top,
    width: width,
    height: height,
  );

  // 3. Resize to Model Input Size (112x112)
  img.Image resizedImg = img.copyResize(faceImg, width: 112, height: 112);

  // 4. Preprocess (Normalize)
  // Flatten 112x112x3
  var input = Float32List(1 * 112 * 112 * 3).reshape([1, 112, 112, 3]);

  for (var y = 0; y < 112; y++) {
    for (var x = 0; x < 112; x++) {
      var pixel = resizedImg.getPixel(x, y);
      input[0][y][x][0] = (pixel.r - 128) / 128.0;
      input[0][y][x][1] = (pixel.g - 128) / 128.0;
      input[0][y][x][2] = (pixel.b - 128) / 128.0;
    }
  }

  return input;
}

img.Image _convertNV21(_ProcessingData data) {
  final int width = data.width;
  final int height = data.height;
  
  // Basic check for planes
  if (data.planesBytes.length < 3) {
      // Fallback or error handling
      return img.Image(width: 1, height: 1); 
  }

  final int uvRowStride = data.planesBytesPerRow[1];
  final int? uvPixelStride = data.planesBytesPerPixel[1];

  var imgBuffer = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride! * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final int index = y * width + x;

      final yp = data.planesBytes[0][index];
      final up = data.planesBytes[1][uvIndex];
      final vp = data.planesBytes[2][uvIndex];

      int r = (yp + (1.370705 * (vp - 128))).round().clamp(0, 255);
      int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128))).round().clamp(0, 255);
      int b = (yp + (1.732446 * (up - 128))).round().clamp(0, 255);

      imgBuffer.setPixelRgb(x, y, r, g, b);
    }
  }
  return imgBuffer;
}

img.Image _convertBGRA8888(_ProcessingData data) {
  return img.Image.fromBytes(
    width: data.width,
    height: data.height,
    bytes: data.planesBytes[0].buffer,
    order: img.ChannelOrder.bgra,
  );
}

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();

  factory FaceRecognitionService() {
    return _instance;
  }

  FaceRecognitionService._internal();

  Interpreter? _interpreter;

  bool get isModelLoaded => _interpreter != null;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());
      if (Platform.isIOS) options.addDelegate(GpuDelegate());

      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite', options: options);
      debugPrint('Face Recognition Model Loaded Successfully');
    } catch (e) {
      debugPrint('Error loading face recognition model: $e');
    }
  }

  Future<List<double>?> generateEmbedding(CameraImage cameraImage, Face face) async {
    if (_interpreter == null) {
      debugPrint('Interpreter not initialized');
      return null;
    }

    try {
      // Prepare data for isolate
      final processingData = _ProcessingData(
        planesBytes: cameraImage.planes.map((p) => p.bytes).toList(),
        planesBytesPerRow: cameraImage.planes.map((p) => p.bytesPerRow).toList(),
        planesBytesPerPixel: cameraImage.planes.map((p) => p.bytesPerPixel).toList(),
        width: cameraImage.width,
        height: cameraImage.height,
        formatGroup: cameraImage.format.group,
        cropX: face.boundingBox.left.toInt(),
        cropY: face.boundingBox.top.toInt(),
        cropW: face.boundingBox.width.toInt(),
        cropH: face.boundingBox.height.toInt(),
      );

      // Run computationally expensive image processing in isolate
      final input = await compute(_processImageInIsolate, processingData);

      if (input.isEmpty) return null;

      // Run Inference (TFLite is usually fast enough on main thread for this model size)
      // but if needed, interpreter can also be moved. 
      // For now, image conversion was the main bottleneck (~200ms vs ~15ms inference).
      
      var outputTensorShape = _interpreter!.getOutputTensor(0).shape;
      int outputSize = outputTensorShape.last; 
      
      var output = List.filled(outputSize, 0.0).reshape([1, outputSize]);
      
      _interpreter!.run(input, output);
      
      List<double> embedding = List<double>.from(output[0]);
      return embedding;

    } catch (e) {
      debugPrint('Error generating embedding: $e');
      return null;
    }
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
