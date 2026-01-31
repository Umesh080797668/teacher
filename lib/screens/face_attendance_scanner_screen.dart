import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/student.dart';
import '../services/face_recognition_service.dart';

class FaceAttendanceScannerScreen extends StatefulWidget {
  final List<Student> students;
  final Function(Student) onStudentIdentified;

  const FaceAttendanceScannerScreen({
    Key? key,
    required this.students,
    required this.onStudentIdentified,
  }) : super(key: key);

  @override
  State<FaceAttendanceScannerScreen> createState() => _FaceAttendanceScannerScreenState();
}

class _FaceAttendanceScannerScreenState extends State<FaceAttendanceScannerScreen> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false, // Performance
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast, // Faster for scanning flow
    ),
  );
  
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  DateTime _lastIdentificationTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _statusMessage = 'Point camera at student';
  final double _threshold = 0.8; // Distance threshold (tunable)
  
  List<Face> _faces = [];
  Size _imageSize = Size.zero;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Ensure model is loaded
    FaceRecognitionService().loadModel();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      // Try to find back camera for "Scanning" mode (teacher scanning students), 
      // or front if user prefers. Usually teachers scan students -> Back Camera.
      // But let's check lens direction. User didn't specify. 
      // Teacher App -> Teacher holds phone -> Scans student -> Back Camera.
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraLensDirection = camera.lensDirection;

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      _startImageStream();
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Camera Error: $e');
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        // Debounce if just identified someone
        if (DateTime.now().difference(_lastIdentificationTime).inSeconds < 2) {
          _isDetecting = false;
          return;
        }

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
             if (mounted && _statusMessage != 'Point camera at student') {
                setState(() => _statusMessage = 'Point camera at student');
             }
        }
      } catch (e) {
        debugPrint('Detection Error: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    InputImageRotation rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    } else {
      var rotationCompensation = _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation) ?? InputImageRotation.rotation0deg;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;

    final bytes = Uint8List.fromList(
      image.planes.fold<List<int>>(<int>[], (previousValue, plane) => previousValue..addAll(plane.bytes)),
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<void> _processFace(Face face, CameraImage image) async {
    // Generate Embedding using Service
    final embedding = await FaceRecognitionService().generateEmbedding(image, face);
    
    if (embedding == null) return;

    Student? closestStudent;
    double minDistance = double.infinity;

    // Compare with all students who have face data
    for (var student in widget.students) {
      if (student.hasFaceData && student.faceEmbedding != null && student.faceEmbedding!.isNotEmpty) {
        double distance = FaceRecognitionService().euclideanDistance(embedding, student.faceEmbedding!);
        
        if (distance < minDistance) {
          minDistance = distance;
          closestStudent = student;
        }
      }
    }

    if (closestStudent != null && minDistance < _threshold) {
       _onStudentFound(closestStudent);
    } else {
       if (mounted) setState(() => _statusMessage = 'Unknown Face');
    }
  }

  void _onStudentFound(Student student) {
    _lastIdentificationTime = DateTime.now();
    
    if (mounted) {
      setState(() => _statusMessage = 'Marked: ${student.name}');
      // HapticFeedback.heavyImpact(); // Add haptics if desired
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked Present: ${student.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    
    widget.onStudentIdentified(student);
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
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          
          if (_imageSize != Size.zero)
            CustomPaint(
              painter: FacePainter(
                faces: _faces,
                imageSize: _imageSize,
                cameraLensDirection: _cameraLensDirection,
              ),
            ),

           // Static Guide Box
          Center(
            child: Container(
              width: 280,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Overlay
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          )
        ],
      ),
    );
  }
}

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

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required CameraLensDirection cameraLensDirection,
  }) {
    double scaleX, scaleY;
    
    bool isImageLandscape = imageSize.width > imageSize.height;
    bool isScreenLandscape = widgetSize.width > widgetSize.height;
    
    if (isImageLandscape != isScreenLandscape) {
      scaleX = widgetSize.width / imageSize.height;
      scaleY = widgetSize.height / imageSize.width;
    } else {
      scaleX = widgetSize.width / imageSize.width;
      scaleY = widgetSize.height / imageSize.height;
    }

    double left = rect.left * scaleX;
    double top = rect.top * scaleY;
    double right = rect.right * scaleX;
    double bottom = rect.bottom * scaleY;

    if (cameraLensDirection == CameraLensDirection.front) {
      left = widgetSize.width - right;
      right = widgetSize.width - (rect.left * scaleX);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
