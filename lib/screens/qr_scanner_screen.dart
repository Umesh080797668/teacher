import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  bool _isConnected = true; // HTTP is always "connected"
  String? _teacherId;
  String? _deviceId;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _teacherId = prefs.getString('teacherId');
        _deviceId = prefs.getString('deviceId') ??
            DateTime.now().millisecondsSinceEpoch.toString();
      });
    }

    // Save deviceId if it's new
    if (!prefs.containsKey('deviceId')) {
      await prefs.setString('deviceId', _deviceId!);
    }
  }

  Future<Map<String, dynamic>?> _authenticateQR({
    required String sessionId,
    required String teacherId,
    required String deviceId,
  }) async {
    try {
      print('Sending HTTP authentication request...');
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/web-session/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': sessionId,
          'teacherId': teacherId,
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Authentication response status: ${response.statusCode}');
      print('Authentication response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Authentication failed'};
      }
    } catch (e) {
      print('Authentication error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  void _handleQRCode(BarcodeCapture capture) async {
    if (_isProcessing || !mounted) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      print('No barcodes detected');
      return;
    }

    final String? qrData = barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) {
      print('QR data is null or empty');
      return;
    }

    print('QR Code scanned: $qrData');

    if (!mounted) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Parse QR code data
      final Map<String, dynamic> qrJson = jsonDecode(qrData);
      print('Parsed QR JSON: $qrJson');

      // Validate QR code structure
      if (!qrJson.containsKey('type')) {
        print('QR code missing "type" field');
        _showErrorDialog('Invalid QR code format - missing type');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      if (qrJson['type'] != 'web-auth') {
        print('QR code type is not "web-auth": ${qrJson['type']}');
        _showErrorDialog('Invalid QR code - wrong type');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      if (!qrJson.containsKey('sessionId')) {
        print('QR code missing sessionId field');
        _showErrorDialog('Invalid QR code format');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      final String sessionId = qrJson['sessionId'];
      print('Session ID: $sessionId');

      // Check if teacher is logged in
      if (_teacherId == null || _teacherId!.isEmpty) {
        print('Teacher not logged in');
        _showErrorDialog('Please login first');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      print('Sending HTTP authentication request...');
      print('Teacher ID: $_teacherId');
      print('Device ID: $_deviceId');
      print('Session ID: $sessionId');

      // Show loading dialog
      if (mounted) {
        _showLoadingDialog();
      }

      // Send authentication via HTTP
      final result = await _authenticateQR(
        sessionId: sessionId,
        teacherId: _teacherId!,
        deviceId: _deviceId!,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (result != null && result['success'] == true) {
        _showSuccessDialog('Successfully connected to web interface!');
      } else {
        final errorMessage = result?['message'] ?? 'Authentication failed';
        _showErrorDialog(errorMessage);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('Error parsing QR code: $e');
      _showErrorDialog('Invalid QR code format');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Authenticating...'),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    
    Navigator.of(context).pop(); // Close loading dialog
    Navigator.of(context).pop(); // Close scanner screen

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(); // Close any open dialogs
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
                if (mounted) {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _isConnected;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Flexible(
              child: Text(
                'Scan QR Code',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        actions: [
          IconButton(
            icon: Icon(cameraController.torchEnabled
                ? Icons.flash_on
                : Icons.flash_off),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleQRCode,
          ),

          // Overlay with instructions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'Scan Web QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Point your camera at the QR code\ndisplayed on the web interface',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          // Scanning frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Bottom instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How to connect:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Open the web interface on your computer'),
                  _buildStep('2', 'Click on "Connect Mobile Device"'),
                  _buildStep('3', 'Scan the displayed QR code'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
