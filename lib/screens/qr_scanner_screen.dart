import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  IO.Socket? socket;
  String? _teacherId;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
    _connectWebSocket();
  }

  Future<void> _loadTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _teacherId = prefs.getString('teacherId');
      _deviceId = prefs.getString('deviceId') ??
          DateTime.now().millisecondsSinceEpoch.toString();
    });

    // Save deviceId if it's new
    if (!prefs.containsKey('deviceId')) {
      await prefs.setString('deviceId', _deviceId!);
    }
  }

  void _connectWebSocket() {
    // Use the same backend URL as the mobile app API service
    const String backendUrl = ApiService.baseUrl;
    
    print('Connecting to WebSocket at: $backendUrl');

    socket = IO.io(backendUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    socket?.on('connect', (_) {
      print('WebSocket connected successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to server'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    socket?.on('connect_error', (error) {
      print('WebSocket connection error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection error. Please check your internet.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    socket?.on('auth-success', (data) {
      print('Authentication successful: $data');
      _showSuccessDialog('Successfully connected to web interface!');
    });

    socket?.on('auth-failed', (data) {
      print('Authentication failed: $data');
      _showErrorDialog(data['message'] ?? 'Authentication failed');
    });

    socket?.on('disconnect', (_) {
      print('WebSocket disconnected');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from server'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
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

      if (!qrJson.containsKey('sessionId') || !qrJson.containsKey('expiresAt')) {
        print('QR code missing required fields');
        _showErrorDialog('Invalid QR code format');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      final String sessionId = qrJson['sessionId'];
      final int expiresAt = qrJson['expiresAt'];
      print('Session ID: $sessionId, Expires at: $expiresAt');

      // Check if expired
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        _showErrorDialog('QR code has expired');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

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

      // Check WebSocket connection
      if (socket == null || !socket!.connected) {
        print('WebSocket not connected');
        _showErrorDialog('Connection error. Please try again.');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      print('Sending authentication request...');
      print('Teacher ID: $_teacherId');
      print('Device ID: $_deviceId');
      print('Session ID: $sessionId');

      // Send authentication to backend
      socket?.emit('authenticate-qr', {
        'sessionId': sessionId,
        'teacherId': _teacherId,
        'deviceId': _deviceId,
      });

      print('Authentication request sent');

      // Show loading dialog
      if (mounted) {
        _showLoadingDialog();
      }

      // Set timeout for authentication response
      Future.delayed(const Duration(seconds: 10), () {
        if (_isProcessing && mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _showErrorDialog('Authentication timeout. Please try again.');
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        }
      });
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
    socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = socket?.connected ?? false;
    
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
