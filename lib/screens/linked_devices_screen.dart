import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_widgets.dart';
import '../services/api_service.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('=== Loading Linked Devices ===');
      final FlutterSecureStorage storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (token == null) {
        print('❌ No auth token found');
        throw Exception('Not authenticated');
      }

      print('✓ Auth token found');
      print('Making request to: ${ApiService.baseUrl}/api/web-session/active');

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/web-session/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('❌ Request timed out after 30 seconds');
          throw Exception('Request timed out');
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final sessions = json.decode(response.body) as List;
        print('✓ Successfully loaded ${sessions.length} session(s)');
        
        if (sessions.isNotEmpty) {
          print('Session details:');
          for (var i = 0; i < sessions.length; i++) {
            print('  Session ${i + 1}: ${sessions[i]}');
          }
        } else {
          print('⚠ No active sessions found');
        }
        
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed (401)');
        print('Response: ${response.body}');
        throw Exception('Authentication failed. Please login again.');
      } else {
        print('❌ Failed with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load sessions (${response.statusCode})');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading sessions: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectSession(String sessionId, int index) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Text(
              'Disconnect Device',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to disconnect this device? The user will be logged out immediately.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      print('User cancelled disconnect operation');
      return;
    }

    try {
      print('=== Disconnecting Session ===');
      print('Session ID: $sessionId');
      
      final FlutterSecureStorage storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (token == null) {
        print('❌ No auth token found');
        throw Exception('Not authenticated');
      }

      print('✓ Auth token found, making disconnect request');
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/web-session/disconnect'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'sessionId': sessionId}),
      );

      print('Disconnect response status: ${response.statusCode}');
      print('Disconnect response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✓ Session disconnected successfully');
        setState(() {
          _sessions.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle),
                  SizedBox(width: 12),
                  Text('Device disconnected successfully'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        print('❌ Failed to disconnect with status: ${response.statusCode}');
        throw Exception('Failed to disconnect session (${response.statusCode})');
      }
    } catch (e, stackTrace) {
      print('❌ Error disconnecting session: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to disconnect: $e')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      // Convert to local timezone
      final localDate = date.toLocal();
      return DateFormat('MMM dd, yyyy HH:mm').format(localDate);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getDeviceIcon(String? userAgent) {
    if (userAgent == null) return 'desktop_windows';
    final lower = userAgent.toLowerCase();
    if (lower.contains('mobile') || lower.contains('android') || lower.contains('iphone')) {
      return 'phone_android';
    } else if (lower.contains('tablet') || lower.contains('ipad')) {
      return 'tablet';
    }
    return 'desktop_windows';
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'phone_android':
        return Icons.phone_android;
      case 'tablet':
        return Icons.tablet;
      default:
        return Icons.desktop_windows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0E17) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Gradient Header ───────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E1A2E), Color(0xFF2D2660)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFF3730A3),
                          Color(0xFF4F46E5),
                          Color(0xFF7C3AED)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Devices',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Manage your active web sessions',
                          style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.75),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadSessions,
                    tooltip: 'Refresh',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // ── Body ────────────────────────────────────────
            Expanded(
              child: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 4,
              itemBuilder: (_, __) => const LinkedDeviceSkeleton(),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load devices',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: isDark ? 0.7 : 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loadSessions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_other,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: isDark ? 0.5 : 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Active Devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You don\'t have any active web sessions',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: isDark ? 0.7 : 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final deviceIcon = _getDeviceIcon(session['userAgent']);
                          final isActive = session['isActive'] == true;
                          final createdAt = _formatDate(session['createdAt']);
                          final lastActive = _formatDate(session['lastActivity']);

                          final cs = Theme.of(context).colorScheme;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getIconData(deviceIcon),
                                        size: 32,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Web Session',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? const Color(0xFF22C55E)
                                                        : cs.surfaceContainerHigh,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    isActive
                                                        ? 'Active'
                                                        : 'Inactive',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isActive
                                                          ? Colors.white
                                                          : cs.onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'IP: ${session['ipAddress'] ?? 'Unknown'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 
                                                        isDark ? 0.7 : 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.logout,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        onPressed: () => _disconnectSession(
                                          session['sessionId'],
                                          index,
                                        ),
                                        tooltip: 'Disconnect',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: isDark ? 0.2 : 0.1),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: isDark ? 0.7 : 0.6),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Created: $createdAt',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: isDark ? 0.7 : 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: isDark ? 0.7 : 0.6),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Last Active: $lastActive',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: isDark ? 0.7 : 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (session['userAgent'] != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: isDark ? 0.7 : 0.6),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            session['userAgent'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 
                                                      isDark ? 0.5 : 0.4),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
