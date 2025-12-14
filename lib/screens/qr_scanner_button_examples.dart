import 'package:flutter/material.dart';
import 'qr_scanner_screen.dart';

// Add this method to your home screen widget

Widget _buildQRScannerFAB(BuildContext context) {
  return FloatingActionButton.extended(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );
    },
    backgroundColor: const Color(0xFF6366F1),
    icon: const Icon(Icons.qr_code_scanner),
    label: const Text('Connect Web'),
  );
}

// OR add as an action button in AppBar:

IconButton _buildQRScannerAppBarButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.qr_code_scanner),
    tooltip: 'Connect to Web',
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );
    },
  );
}

// OR add as a menu item in drawer:

ListTile _buildQRScannerDrawerItem(BuildContext context) {
  return ListTile(
    leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF6366F1)),
    title: const Text('Connect to Web'),
    subtitle: const Text('Scan QR code to access web interface'),
    onTap: () {
      Navigator.pop(context); // Close drawer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );
    },
  );
}

/* 
 * Example Integration in HomeScreen:
 * 
 * @override
 * Widget build(BuildContext context) {
 *   return Scaffold(
 *     appBar: AppBar(
 *       title: const Text('Home'),
 *       actions: [
 *         _buildQRScannerAppBarButton(context), // <-- Add this
 *         // ... other actions
 *       ],
 *     ),
 *     body: // Your existing body
 *     floatingActionButton: _buildQRScannerFAB(context), // <-- Or this
 *   );
 * }
 */
