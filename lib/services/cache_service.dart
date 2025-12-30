import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _cachePrefix = 'api_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  static Future<String?> getCachedResponse(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_cachePrefix$endpoint');
    if (cachedData != null) {
      final Map<String, dynamic> cacheEntry = json.decode(cachedData);
      final DateTime timestamp = DateTime.parse(cacheEntry['timestamp']);
      final Duration cacheDuration = Duration(minutes: cacheEntry['durationMinutes'] ?? 5);

      if (DateTime.now().difference(timestamp) < cacheDuration) {
        return cacheEntry['data'];
      } else {
        // Cache expired, remove it
        await prefs.remove('$_cachePrefix$endpoint');
      }
    }
    return null;
  }

  static Future<void> cacheResponse(String endpoint, String response, {Duration? duration}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheEntry = {
      'data': response,
      'timestamp': DateTime.now().toIso8601String(),
      'durationMinutes': duration?.inMinutes ?? _defaultCacheDuration.inMinutes,
    };
    await prefs.setString('$_cachePrefix$endpoint', json.encode(cacheEntry));
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}