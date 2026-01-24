import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    var connectionStatus = Provider.of<bool>(context);
    
    if (connectionStatus) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      bottom: false,
      child: Material(
        color: Colors.red,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
           child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Offline Mode - Local updates only',
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
