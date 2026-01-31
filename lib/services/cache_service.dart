import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _cachePrefix = 'api_cache_';
  static const String _offlineCachePrefix = 'offline_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  
  // Memory cache for faster access (avoids SharedPreferences I/O)
  static final Map<String, _CacheEntry> _memoryCache = {};
  static const int maxMemoryCacheSize = 50; // Maximum number of items in memory cache
  
  // Cache statistics
  static int _hits = 0;
  static int _misses = 0;
  
  static Future<String?> getCachedResponse(String endpoint) async {
    // Check memory cache first (much faster)
    if (_memoryCache.containsKey(endpoint)) {
      final entry = _memoryCache[endpoint]!;
      if (DateTime.now().difference(entry.timestamp) < entry.duration) {
        _hits++;
        return entry.data;
      } else {
        // Memory cache expired
        _memoryCache.remove(endpoint);
      }
    }
    
    // Check persistent cache (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_cachePrefix$endpoint');
    if (cachedData != null) {
      final Map<String, dynamic> cacheEntry = json.decode(cachedData);
      final DateTime timestamp = DateTime.parse(cacheEntry['timestamp']);
      final Duration cacheDuration = Duration(minutes: cacheEntry['durationMinutes'] ?? 5);

      if (DateTime.now().difference(timestamp) < cacheDuration) {
        final data = cacheEntry['data'];
        
        // Load into memory cache for next time
        _addToMemoryCache(endpoint, data, cacheDuration);
        
        _hits++;
        return data;
      } else {
        // Cache expired, remove it
        await prefs.remove('$_cachePrefix$endpoint');
      }
    }
    
    _misses++;
    return null;
  }

  static Future<void> cacheResponse(String endpoint, String response, {Duration? duration}) async {
    final cacheDuration = duration ?? _defaultCacheDuration;
    
    // Cache in memory first
    _addToMemoryCache(endpoint, response, cacheDuration);
    
    // Cache in persistent storage
    final prefs = await SharedPreferences.getInstance();
    final cacheEntry = {
      'data': response,
      'timestamp': DateTime.now().toIso8601String(),
      'durationMinutes': cacheDuration.inMinutes,
    };
    await prefs.setString('$_cachePrefix$endpoint', json.encode(cacheEntry));
  }
  
  static void _addToMemoryCache(String endpoint, String data, Duration duration) {
    // Implement LRU eviction if cache is full
    if (_memoryCache.length >= maxMemoryCacheSize) {
      // Remove oldest entry
      String? oldestKey;
      DateTime? oldestTime;
      
      _memoryCache.forEach((key, entry) {
        if (oldestTime == null || entry.timestamp.isBefore(oldestTime!)) {
          oldestTime = entry.timestamp;
          oldestKey = key;
        }
      });
      
      if (oldestKey != null) {
        _memoryCache.remove(oldestKey);
      }
    }
    
    _memoryCache[endpoint] = _CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      duration: duration,
    );
  }

  static Future<void> clearCache() async {
    // Clear memory cache
    _memoryCache.clear();
    
    // Clear persistent cache
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    
    // Reset statistics
    _hits = 0;
    _misses = 0;
  }
  
  static void clearMemoryCache() {
    _memoryCache.clear();
  }
  
  /// Cache data for offline use (longer duration, never expires for offline mode)
  static Future<void> cacheOfflineData(String key, String data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheEntry = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'offline': true,
    };
    await prefs.setString('$_offlineCachePrefix$key', json.encode(cacheEntry));
  }
  
  /// Get offline cached data (ignores expiration)
  static Future<String?> getOfflineCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_offlineCachePrefix$key');
    if (cachedData != null) {
      final Map<String, dynamic> cacheEntry = json.decode(cachedData);
      return cacheEntry['data'];
    }
    return null;
  }
  
  /// Check if offline data exists for a key
  static Future<bool> hasOfflineData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_offlineCachePrefix$key');
  }
  
  /// Get any cached data regardless of expiration (for offline fallback)
  static Future<String?> getAnyCachedData(String endpoint) async {
    // First try memory cache
    if (_memoryCache.containsKey(endpoint)) {
      return _memoryCache[endpoint]!.data;
    }
    
    // Then try regular cache (even if expired)
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_cachePrefix$endpoint');
    if (cachedData != null) {
      final Map<String, dynamic> cacheEntry = json.decode(cachedData);
      return cacheEntry['data'];
    }
    
    // Finally try offline cache
    return await getOfflineCachedData(endpoint);
  }
  
  static Map<String, dynamic> getCacheStatistics() {
    final total = _hits + _misses;
    final hitRate = total > 0 ? (_hits / total * 100).toStringAsFixed(2) : '0.00';
    
    return {
      'hits': _hits,
      'misses': _misses,
      'total': total,
      'hitRate': '$hitRate%',
      'memoryCacheSize': _memoryCache.length,
      'maxMemoryCacheSize': maxMemoryCacheSize,
    };
  }
}

class _CacheEntry {
  final String data;
  final DateTime timestamp;
  final Duration duration;
  
  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.duration,
  });
}