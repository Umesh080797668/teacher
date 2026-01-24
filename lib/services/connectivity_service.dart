import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  ConnectivityService() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
     // If any of the results is mobile or wifi, we have internet (likely)
     // This is a simple check, validation against a real URL could be added for robust checking
     bool isConnected = results.any((result) => 
       result == ConnectivityResult.mobile || 
       result == ConnectivityResult.wifi || 
       result == ConnectivityResult.ethernet);
       
    _connectionStatusController.add(isConnected);
  }
  
  void dispose() {
    _connectionStatusController.close();
  }
}
