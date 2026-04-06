import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

class HttpHelper {
  static Dio? _dio;
  static CacheOptions? _defaultCacheOptions;

  static Future<Dio> _getDio() async {
    if (_dio != null) return _dio!;
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
    _dio = Dio()
      ..interceptors.add(DioCacheInterceptor(options: _defaultCacheOptions!));
    return _dio!;
  }

  static Future<http.Response> fetchRetry(
    String url, {
    int delay = 50,
    int tries = 2,
    Map<String, String>? headers,
    CachePolicy? cachePolicy,
  }) async {
    final dio = await _getDio();
    final effectivePolicy = cachePolicy ?? CachePolicy.request;
    final options =
        _defaultCacheOptions!.copyWith(policy: effectivePolicy).toOptions()
          ..responseType = ResponseType.plain
          ..headers = headers;

    Exception? lastError;
    for (int i = 0; i < tries; i++) {
      try {
        final res = await dio.get<String>(url, options: options);
        return http.Response(res.data ?? '', res.statusCode ?? 200);
      } catch (e) {
        if (e is DioException && e.response != null) {
          return http.Response(e.response!.data?.toString() ?? '',
              e.response!.statusCode ?? 500);
        }
        lastError = e is Exception ? e : Exception(e.toString());
        if (i < tries - 1) await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw lastError ?? Exception('Failed to fetch after $tries tries');
  }

  static Future<http.Response> postRetry(
    String url, {
    required Map<String, dynamic> body,
    int delay = 50,
    int tries = 2,
    Map<String, String>? headers,
  }) async {
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    Exception? lastError;
    for (int i = 0; i < tries; i++) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: defaultHeaders,
          body: jsonEncode(body),
        );
        return res;
      } catch (e) {
        lastError = e as Exception;
        if (i < tries - 1) await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw lastError ?? Exception('Failed to post after $tries tries');
  }
}
