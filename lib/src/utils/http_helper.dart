import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_cache_client/http_cache_client.dart';
import 'package:http_cache_core/http_cache_core.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

enum FetchCacheMode { forceCache, request, noCache }

class HttpHelper {
  static CacheClient? _cacheClient;
  static CacheOptions? _defaultCacheOptions;

  static Future<CacheClient> _getClient() async {
    if (_cacheClient != null) return _cacheClient!;
    final CacheStore store;
    if (kIsWeb) {
      store = MemCacheStore();
    } else {
      final dir = await getApplicationCacheDirectory();
      store = HiveCacheStore('${dir.path}/configbee_cache');
    }
    _defaultCacheOptions = CacheOptions(
      store: store,
      policy: CachePolicy.request,
      hitCacheOnNetworkFailure: true,
      maxStale: const Duration(days: 7),
    );
    _cacheClient = CacheClient(http.Client(), options: _defaultCacheOptions!);
    return _cacheClient!;
  }

  static Future<http.Response> fetchRetry(
    String url, {
    Map<String, String>? headers,
    FetchCacheMode cacheMode = FetchCacheMode.request,
  }) async {
    final client = await _getClient();
    final policy = switch (cacheMode) {
      FetchCacheMode.forceCache => CachePolicy.forceCache,
      FetchCacheMode.noCache => CachePolicy.noCache,
      FetchCacheMode.request => CachePolicy.request,
    };
    final options = _defaultCacheOptions!.copyWith(policy: policy);

    // Retry on network error only (1 retry, 50ms delay) — matches JS SDK fetchRetry exactly
    Exception? lastError;
    for (int i = 0; i < 2; i++) {
      try {
        return await client.get(Uri.parse(url), headers: headers, options: options);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i == 0) await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    throw lastError!;
  }

  static Future<http.Response> postRetry(
    String url, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    // POST: no caching, retry on network error only — matches JS SDK fetchRetry exactly
    Exception? lastError;
    for (int i = 0; i < 2; i++) {
      try {
        return await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json', ...?headers},
          body: jsonEncode(body),
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i == 0) await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    throw lastError!;
  }
}
