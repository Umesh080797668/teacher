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

    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Material(
        color: cs.error,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: cs.onError, size: 18),
              const SizedBox(width: 8),
              Text(
                'Offline Mode - Local updates only',
                style: TextStyle(
                  color: cs.onError,
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
