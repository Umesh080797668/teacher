import 'dart:math';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import '../models/student.dart';
import '../providers/students_provider.dart';
import '../services/face_recognition_service.dart';

class FaceRegistrationScreen extends StatefulWidget {
  final Student student;

  const FaceRegistrationScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true, // Need this for eyes open/smiling logic if we want strictness
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate, // Critical for production
    ),
  );
  
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  String _statusMessage = 'Initializing Camera...';

  // For visual feedback and quality control
  final double _minFaceWidthRatio = 0.35; // Face must be at least 35% of screen width
  final double _maxHeadEulerAngleY = 12.0; // Max turn (yaw)
  final double _maxHeadEulerAngleZ = 12.0; // Max tilt (roll)
  
  List<Face> _faces = [];
  Size _imageSize = Size.zero;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await FaceRecognitionService().loadModel();
    if (mounted) {
       if (FaceRecognitionService().isModelLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face Recognition Model Ready'), backgroundColor: Colors.green),
          );
       } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load Face Recognition Model'), backgroundColor: Colors.red),
          );
       }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // keep medium for performance/inference speed balance
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      _cameraLensDirection = frontCamera.lensDirection;

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = 'Position face within the frame';
      });

      _startImageStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera Error: $e';
        });
      }
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) {
          _isDetecting = false;
          return;
        }

        final faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
            _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          });
        }

        if (faces.isNotEmpty) {
           _processFace(faces.first, image); 
        } else {
             if (mounted && _statusMessage != 'Position face within the frame') {
                setState(() {
                  _statusMessage = 'Position face within the frame';
                });
             }
        }
      } catch (e) {
        debugPrint('Face detection error: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }
  
  // Robust InputImage creation handling orientation
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    // Correct rotation calculation for Android/iOS
    InputImageRotation rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    } else {
      var rotationCompensation = _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing calibration
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing calibration
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation) ?? InputImageRotation.rotation0deg;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;

    // nv21 on android is a single plane for bytes but handled differently by mlkit helper usually
    // but the official boilerplate combines planes.
    final bytes = Uint8List.fromList(
      image.planes.fold<List<int>>(<int>[], (previousValue, plane) => previousValue..addAll(plane.bytes)),
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow, // Main plane
      ),
    );
  }
  
  // Map device orientation to degrees
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  bool _isProcessingRegistration = false;
  bool _captureRequested = false;
  bool _isFaceAligned = false;

  Future<void> _processFace(Face face, CameraImage originalImage) async {
    if (_isProcessingRegistration) return;
    
    // 1. Strict Face Quality Logic
    
    // Determine effective image dimensions as seen by ML Kit (rotated)
    double imageWidth = originalImage.width.toDouble();
    double imageHeight = originalImage.height.toDouble();

    // On Android (specifically portrait), dimensions need swap for checking logic relative to screen
    // ML Kit processes image based on rotation metadata usually, but here we are checking
    // raw pixel coords from the detector which are in the image space.
    bool isPortrait = _cameraController!.value.deviceOrientation == DeviceOrientation.portraitUp;
    if (Platform.isAndroid && isPortrait) {
       imageWidth = originalImage.height.toDouble();
       imageHeight = originalImage.width.toDouble();
    } 

    // Check Box dimensions (Size)
    final double faceWidth = face.boundingBox.width;
    final double relativeWidth = faceWidth / imageWidth; 
    
    if (relativeWidth < 0.25) { 
       if (mounted) setState(() {
         _statusMessage = 'Move Closer';
         _isFaceAligned = false;
       });
       return;
    }

    // Check Centering
    final double centerX = imageWidth / 2;
    final double centerY = imageHeight / 2;
    final double faceCenterX = face.boundingBox.center.dx;
    final double faceCenterY = face.boundingBox.center.dy;
    
    if ((faceCenterX - centerX).abs() > (imageWidth * 0.15) || 
        (faceCenterY - centerY).abs() > (imageHeight * 0.15)) {
       if (mounted) setState(() {
         _statusMessage = 'Center your face';
         _isFaceAligned = false;
       });
       return;
    }
    
    // Check Head Pose
    if ((face.headEulerAngleY ?? 0).abs() > _maxHeadEulerAngleY) {
       if (mounted) setState(() {
         _statusMessage = 'Look Straight Ahead';
         _isFaceAligned = false;
       });
       return;
    }
    
    if ((face.headEulerAngleZ ?? 0).abs() > _maxHeadEulerAngleZ) {
       if (mounted) setState(() {
         _statusMessage = 'Keep Head Straight';
         _isFaceAligned = false;
       });
       return;
    }

    // If passed all checks
    if (mounted) {
       setState(() {
         _statusMessage = 'Face Aligned. Press Capture.';
         _isFaceAligned = true;
       });
    }

    if (!_captureRequested) return;

    _isProcessingRegistration = true;
    _captureRequested = false; 
    _stopCamera(); // Stop stream to capture

    if (mounted) {
      setState(() => _statusMessage = 'Processing Face...');
    }

    try {
      // 2. Crop Face & Generate Embedding
      final embedding = await FaceRecognitionService().generateEmbedding(originalImage, face);
      
      if (embedding == null) {
        throw Exception('Failed to generate face embedding');
      }

      await Provider.of<StudentsProvider>(context, listen: false).updateFaceData(
        widget.student.id,
        embedding,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              title: Text(
                'Registration Complete',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              content: Text(
                'Biometric data secured.',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); 
                    Navigator.of(context).pop(); 
                  },
                  child: Text(
                    'Finish',
                    style: TextStyle(color: isDark ? Colors.blueAccent : Colors.blue),
                  ),
                )
              ],
            );
          },
        );
      }
    } catch (e) {
      _isProcessingRegistration = false;
      _initializeCamera();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing Failed: $e')),
        );
      }
    }
  }

  Future<void> _stopCamera() async {
    await _cameraController?.stopImageStream();
    // Don't dispose yet if we might restart
  }

  @override
  void dispose() {
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Register Face')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Register Face')),
      body: Stack(
        children: [
          // Camera Preview
          SizedBox.expand(
            child: CameraPreview(_cameraController!),
          ),
          
          if (_imageSize != Size.zero)
            CustomPaint(
              painter: FacePainter(
                faces: _faces,
                imageSize: _imageSize,
                cameraLensDirection: _cameraLensDirection,
              ),
            ),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: OverlayShape(),
            ),
          ),
          
          // Capture Button
          Positioned(
            bottom: 120, 
            left: 0, 
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: (_isFaceAligned && !_isProcessingRegistration) 
                    ? () {
                        setState(() {
                          _captureRequested = true;
                          _statusMessage = "Capturing...";
                        });
                      } 
                    : null,
                icon: const Icon(Icons.camera),
                label: const Text('CAPTURE FACE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFaceAligned ? Colors.blue : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ),
          ),

          // Status & Instructions
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      ),
    );
  }
}

// Custom painter to darken area outside face frame
class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    for (final Face face in faces) {
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        cameraLensDirection: cameraLensDirection,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.faces != faces;
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required CameraLensDirection cameraLensDirection,
  }) {
    // The camera image (imageSize) might be 1280x720 (landscape)
    // while screen (widgetSize) is 400x800 (portrait).
    // Or image might be rotated.
    // In ML Kit, if we process bytes directly with rotation, ML Kit returns coords in that rotated space.
    // However, here we are painting on top of a CameraPreview which handles aspect ratio/rotation visually.
    
    // Simple scaling assuming the CameraPreview fits strictly or covers via aspect ratio.
    // Usually CameraPreview is aspect fill or fit.
    
    // For simplicity, let's assume we need to scale logic similar to standard implementations.
    
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    // Use max scale to cover if it is fitHeight/fitWidth logic, but CameraPreview logic varies.
    // A more robust implementation often checks rotations.
    
    // If we passed rotation to ML Kit, coords are relative to image dimensions as seen by ML Kit.
    // If the image was 640x480 but rotated 90deg, ML Kit sees 480x640.
    // 'imageSize' here comes from original camera image width/height in bytes usually.
    
    // Let's rely on standard scaling used in the other file but adapted if needed.
    // The other file had a swap check:
    
    double sX = scaleX;
    double sY = scaleY;
    
    if (Platform.isAndroid) {
        // On Android, raw image is landscape usually. Screen is portrait.
        // We need to swap dimensions for scaling factors if orientations differ
        if (imageSize.width > imageSize.height && widgetSize.width < widgetSize.height) {
            sX = widgetSize.width / imageSize.height;
            sY = widgetSize.height / imageSize.width;
        }
    }

    double left = rect.left * sX;
    double top = rect.top * sY;
    double right = rect.right * sX;
    double bottom = rect.bottom * sY;

    if (cameraLensDirection == CameraLensDirection.front) {
      // Mirror horizontally
      final w = widgetSize.width;
      return Rect.fromLTRB(w - right, top, w - left, bottom);
    } else {
      return Rect.fromLTRB(left, top, right, bottom);
    }
  }
}

class OverlayShape extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addOval(Rect.fromCenter(
        center: rect.center,
        width: rect.width * 0.7,
        height: rect.width * 0.9, // Oval
      ));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    // final height = rect.height; // Unused
    final center = rect.center;
    final holeWidth = width * 0.7;
    final holeHeight = width * 0.9;

    final path = Path()
      ..addOval(Rect.fromCenter(center: center, width: holeWidth, height: holeHeight))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black54);
    
    // Draw guide border
    canvas.drawOval(
      Rect.fromCenter(center: center, width: holeWidth, height: holeHeight),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
