import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_cache_client/http_cache_client.dart';
import 'package:http_cache_core/http_cache_core.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

enum FetchCacheMode { forceCache, request, noCache }

class HttpHelper {
  // Web: plain client — browser handles Cache-Control natively and persistently.
  static http.Client? _webClient;

  // Native: cache-aware client backed by Hive.
  static CacheClient? _cacheClient;
  static CacheOptions? _defaultCacheOptions;

  static http.Client _getWebClient() {
    return _webClient ??= http.Client();
  }

  static Future<CacheClient> _getNativeClient() async {
    if (_cacheClient != null) return _cacheClient!;
    final dir = await getApplicationCacheDirectory();
    final store = HiveCacheStore('${dir.path}/configbee_cache');
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
    // Retry on network error only (1 retry, 50ms delay).
    Exception? lastError;
    for (int i = 0; i < 2; i++) {
      try {
        if (kIsWeb) {
          // Let the browser cache handle Cache-Control headers from the CDN.
          return await _getWebClient().get(Uri.parse(url), headers: headers);
        } else {
          final client = await _getNativeClient();
          final policy = switch (cacheMode) {
            FetchCacheMode.forceCache => CachePolicy.forceCache,
            FetchCacheMode.noCache => CachePolicy.noCache,
            FetchCacheMode.request => CachePolicy.request,
          };
          final options = _defaultCacheOptions!.copyWith(policy: policy);
          return await client.get(Uri.parse(url), headers: headers, options: options);
        }
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
    // POST: no caching, retry on network error only.
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
