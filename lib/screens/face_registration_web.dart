import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student.dart';
import '../providers/students_provider.dart';

@JS('initFaceApi')
external JSPromise _initFaceApiJS();

@JS('detectFace')
external JSPromise _detectFaceJS(JSString videoElementId);

class FaceRegistrationScreen extends StatefulWidget {
  final Student student;

  const FaceRegistrationScreen({super.key, required this.student});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  final String viewType = 'face-registration-video';
  web.HTMLVideoElement? _videoElement;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  String _statusMessage = 'Initializing Web Camera...';
  List<double>? _capturedEmbedding;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _setupVideoElement();
    _initFaceApi();
  }

  void _setupVideoElement() {
    _videoElement = web.HTMLVideoElement()
      ..id = 'web-face-registration'
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
          _statusMessage = 'Look closely at the camera';
        });
        _startDetectionLoop();
      }
    }.toJS;

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) => _videoElement!);

    _startCamera();
  }

  Future<void> _startCamera() async {
    web.console.log('Starting camera (registration)...'.toJS);
    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      
      final mediaStream = await mediaDevices.getUserMedia(web.MediaStreamConstraints(
        video: true.toJS, 
        audio: false.toJS,
      )).toDart;
      
      web.console.log('Got media stream (registration)'.toJS);
      _videoElement!.srcObject = mediaStream;
      
      try {
        await _videoElement!.play().toDart;
      } catch (e) {
        web.console.log('Video play() failed: $e'.toJS);
      }
      
      // Safety initialization
      if (mounted && !_isCameraInitialized) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Look closely at the camera';
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
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) async {
      if (_isDetecting || !_isCameraInitialized || _capturedEmbedding != null) return;
      _isDetecting = true;

      try {
        final detectionPromise = _detectFaceJS('web-face-registration'.toJS);
        final result = await detectionPromise.toDart;
        
        if (result != null) {
          final jsArray = result as JSArray;
          final List<double> embedding = [];
          for (var i = 0; i < jsArray.length; i++) {
            final JSNumber jsNum = jsArray[i] as JSNumber;
            embedding.add(jsNum.toDartDouble);
          }
          if (mounted) {
            setState(() {
              _capturedEmbedding = embedding;
              _statusMessage = 'Face Detected Successfully!';
            });
          }
        } else {
           if (mounted && _statusMessage != 'Look closely at the camera') {
              setState(() => _statusMessage = 'Look closely at the camera');
           }
        }
      } catch (e) {
        debugPrint('Web Detection Error: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  void _saveRegistration() async {
    if (_capturedEmbedding == null) return;
    
    // Stop camera
    final stream = _videoElement?.srcObject as web.MediaStream?;
    if (stream != null) {
      final tracks = stream.getTracks();
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving face data...')),
    );

    try {
      final studentProvider = Provider.of<StudentsProvider>(context, listen: false);
      
      await studentProvider.updateFaceData(
        widget.student.id,
        _capturedEmbedding!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face Registered Successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving face data: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.blueAccent),
              SizedBox(height: 16),
              Text('Initializing Web Camera...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: viewType),
          
          // Enhanced UI - Vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.3, 1.0],
              )
            ),
          ),
          
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(color: Colors.black38, blurRadius: 8, spreadRadius: 1)
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Register Face',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.student.name,
                      style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.95, end: 1.05),
              duration: const Duration(seconds: 2),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: _capturedEmbedding != null ? 1.0 : scale,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _capturedEmbedding != null 
                            ? Colors.green.shade400 
                            : Colors.blueAccent.withValues(alpha: 0.6),
                        width: _capturedEmbedding != null ? 6 : 4,
                      ),
                      boxShadow: _capturedEmbedding != null ? [
                        BoxShadow(color: Colors.green.shade400.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5)
                      ] : [],
                    ),
                    child: _capturedEmbedding != null 
                      ? const Center(child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 80))
                      : null,
                  ),
                );
              },
            ),
          ),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey<String>(_statusMessage),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _capturedEmbedding != null ? Colors.green.shade800 : Colors.white24
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_capturedEmbedding == null)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 16, height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)
                            ),
                          ),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _capturedEmbedding != null ? Colors.greenAccent : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_capturedEmbedding != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saveRegistration,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 28),
                    label: const Text('Save Face Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      elevation: 8,
                      shadowColor: Colors.green.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  )
                ]
              ],
            ),
          ),
          
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24)
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          )
        ],
      ),
    );
  }
}
