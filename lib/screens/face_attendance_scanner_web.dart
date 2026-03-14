import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/face_recognition_service.dart';

@JS('initFaceApi')
external JSPromise _initFaceApiJS();

@JS('detectFace')
external JSPromise _detectFaceJS(JSString videoElementId);

class FaceAttendanceScannerScreen extends StatefulWidget {
  final List<Student> students;
  final Function(Student) onStudentIdentified;

  const FaceAttendanceScannerScreen({
    super.key,
    required this.students,
    required this.onStudentIdentified,
  });

  @override
  State<FaceAttendanceScannerScreen> createState() => _FaceAttendanceScannerScreenState();
}

class _FaceAttendanceScannerScreenState extends State<FaceAttendanceScannerScreen> {
  final String viewType = 'face-scanner-video';
  web.HTMLVideoElement? _videoElement;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  String _statusMessage = 'Initializing Web Camera...';
  DateTime _lastIdentificationTime = DateTime.fromMillisecondsSinceEpoch(0);
  final double _threshold = 0.55; 
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _setupVideoElement();
    _initFaceApi();
  }

  void _setupVideoElement() {
    _videoElement = web.HTMLVideoElement()
      ..id = 'web-face-scanner'
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.objectFit = 'cover'
      ..style.width = '100%'
      ..style.height = '100%';

    _videoElement!.onplaying = (web.Event event) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Point camera at student';
        });
        _startDetectionLoop();
      }
    }.toJS;

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) => _videoElement!);

    _startCamera();
  }

  Future<void> _startCamera() async {
    web.console.log('Starting camera...'.toJS);
    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      
      final mediaStream = await mediaDevices.getUserMedia(web.MediaStreamConstraints(
        video: true.toJS, 
        audio: false.toJS,
      )).toDart;
      
      web.console.log('Got media stream'.toJS);
      _videoElement!.srcObject = mediaStream;
      // explicitly call play
      try {
        await _videoElement!.play().toDart;
        web.console.log('Video play() succeeded'.toJS);
      } catch (e) {
        web.console.log('Video play() failed: $e'.toJS);
      }
      
      // Safety initialization in case onplaying doesn't fire
      if (mounted && !_isCameraInitialized) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Point camera at student';
        });
        _startDetectionLoop();
      }
      
    } catch (e) {
      web.console.log('Camera Error: $e'.toJS);
      if (mounted) setState(() => _statusMessage = 'Camera Error: $e');
    }
  }

  Future<void> _initFaceApi() async {
    try {
      await _initFaceApiJS().toDart;
    } catch (e) {
      debugPrint("JS initFaceApi error: $e");
    }
  }

  void _startDetectionLoop() {
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_isDetecting || !_isCameraInitialized) return;
      _isDetecting = true;

      if (DateTime.now().difference(_lastIdentificationTime).inSeconds < 2) {
        _isDetecting = false;
        return;
      }

      try {
        final detectionPromise = _detectFaceJS('web-face-scanner'.toJS);
        final result = await detectionPromise.toDart;
        
        if (result != null) {
          // In JS Interop, arrays come back as JSArray.
          final jsArray = result as JSArray;
          final List<double> embedding = [];
          for (var i = 0; i < jsArray.length; i++) {
            // Need to handle numbers safely through dart:js_interop.
            // A JSNumber can be cast / converted. 
            // the returned array contains JSNumbers
            final JSNumber jsNum = jsArray[i] as JSNumber;
            embedding.add(jsNum.toDartDouble);
          }
          _processEmbedding(embedding);
        } else {
          if (mounted && _statusMessage != 'Point camera at student') {
            setState(() => _statusMessage = 'Point camera at student');
          }
        }
      } catch (e) {
        debugPrint('Web Detection Error: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  void _processEmbedding(List<double> embedding) {
    Student? closestStudent;
    double minDistance = double.infinity;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked Present: ${student.name}'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    widget.onStudentIdentified(student);
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    final stream = _videoElement?.srcObject as web.MediaStream?;
    if (stream != null) {
      final tracks = stream.getTracks();
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }
    }
    _videoElement?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: viewType),
          
          // Enhanced UI - Scanning Overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.4, 1.0],
              )
            ),
          ),
          
          // Focus Box Guide with Corner brackets
          Center(
            child: SizedBox(
              width: 280,
              height: 350,
              child: CustomPaint(
                painter: ScannerScannerOverlayPainter(),
              ),
            ),
          ),

          // Scan Line Animation
          Center(
            child: SizedBox(
              width: 280,
              height: 350,
              child: _ScannerAnimation(isDetecting: _isDetecting),
            ),
          ),

          // Overlay Message
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey<String>(_statusMessage),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 20, 
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          
          // Top bar / Close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Face Attendance",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// Visual Effects
class ScannerScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final length = size.width * 0.15;

    // Top Left
    canvas.drawLine(const Offset(0, 0), Offset(length, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, length), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerAnimation extends StatefulWidget {
  final bool isDetecting;
  const _ScannerAnimation({required this.isDetecting});

  @override
  State<_ScannerAnimation> createState() => _ScannerAnimationState();
}

class _ScannerAnimationState extends State<_ScannerAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDetecting) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: _controller.value * 350,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)
                  ]
                ),
              ),
            ),
          ],
        );
      }
    );
  }
}
