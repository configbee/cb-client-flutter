import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'models/models.dart';
import 'utils/http_helper.dart';
import 'utils/sdk_info.dart';
import 'utils/storage_helper.dart';
import 'utils/modifier_evaluator.dart';

class ConfigbeeClientParams {
  final String? accountId;
  final String? projectId;
  final String? environmentId;
  final String? configGroupKey;
  final Map<String, String>? targetProperties;
  final String? key;
  final Map<String, ConfigbeeSource>? sources;
  final Function? onReady;
  final Function? onUpdate;

  ConfigbeeClientParams({
    this.accountId,
    this.projectId,
    this.environmentId,
    this.configGroupKey,
    this.targetProperties,
    this.key,
    this.sources,
    this.onReady,
    this.onUpdate,
  });
}

class ConfigbeeClient {
  final ConfigbeeClientParams params;

  late final String _envKey;
  late final String _distributionObjKey;
  // matches the key field in server responses (no account prefix)
  late final String _defaultGroupObjKey;

  Map<String, String>? _currentTargetProperties;
  final Map<String, DistributionObjData> _currentConfigGroupsData = {};
  final Map<String, TargetingData> _currentTargetingData = {};

  String? _previousSessionKey;
  Map<String, dynamic> _notifiedData = {};

  CbStatus _status = CbStatus.initializing;
  CbStatus _sessionStatus = CbStatus.deactive;
  bool _readyNotificationPending = true;

  final _statusController = StreamController<CbStatus>.broadcast();
  final _sessionStatusController = StreamController<CbStatus>.broadcast();
  final _configController = StreamController<void>.broadcast();

  Stream<CbStatus> get statusStream => _statusController.stream;
  Stream<CbStatus> get sessionStatusStream => _sessionStatusController.stream;
  Stream<void> get configStream => _configController.stream;

  StreamSubscription<SSEModel>? _sseSubscription;
  bool _sseActive = false;
  SSESource? _sseSource;
  String? _sseKey;
  List<Map<String, String>> _contextAssignments = [];
  String? _visitorId;
  String? _directBaseUrl;
  String? _lastTracedServingVersion;
  String? _lastTracedSessionVersionHash;

  Map<String, String>? _targetProperties;
  bool _targetPropertiesExplicitNull = false;

  // Matches the key field as sent by the server (no account prefix)
  static final RegExp _defaultGroupKeyRegex =
      RegExp(r'^p-([0-9A-Fa-f]{4,64})/e-([0-9A-Fa-f]{4,64})/cg-default$');

  CbStatus get status => _status;
  CbStatus get sessionStatus => _sessionStatus;
  CbStatus get targetingStatus => _sessionStatus;

  ConfigbeeClient(this.params) {
    final accountId = params.accountId ?? '';
    final projectId = params.projectId ?? '';
    final environmentId = params.environmentId ?? '';
    final configGroupKey = params.configGroupKey ?? 'default';

    _envKey = 'a-$accountId/p-$projectId/e-$environmentId';
    _distributionObjKey =
        'a-$accountId/p-$projectId/e-$environmentId/cg-$configGroupKey';
    // server sends keys without account prefix
    _defaultGroupObjKey = 'p-$projectId/e-$environmentId/cg-$configGroupKey';

    if (params.targetProperties != null) {
      _targetProperties = params.targetProperties;
    }
  }

  static ConfigbeeClient init(ConfigbeeClientParams params) {
    final resolvedParams = ConfigbeeClientParams(
      accountId: params.accountId,
      projectId: params.projectId,
      environmentId: params.environmentId,
      configGroupKey: params.configGroupKey ?? 'default',
      key: params.key ?? 'default',
      targetProperties: params.targetProperties,
      sources: params.sources ??
          {
            'sse': SSESource(
              eventsBaseUrl: ConfigbeeConfig.cbDefaultSseBaseUrl,
              fetchBaseUrls: SSEFetchBaseUrls(
                cdnCached: ConfigbeeConfig.cbDefaultCdnCachedFetchBaseUrl,
                staticStore: ConfigbeeConfig.cbDefaultStaticStoreFetchBaseUrl,
                direct: ConfigbeeConfig.cbDefaultDirectFetchBaseUrl,
              ),
            ),
          },
      onReady: params.onReady,
      onUpdate: params.onUpdate,
    );

    final client = ConfigbeeClient(resolvedParams);
    client._init();
    return client;
  }

  void _init() {
    params.sources?.forEach((key, source) {
      if (source is HttpFetchSource) {
        _runHttpSource(key: key, source: source);
      } else if (source is SSESource) {
        _runSSESource(key: key, source: source);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Target properties
  // ---------------------------------------------------------------------------

  void setTargetProperties(Map<String, String>? value) {
    waitToLoadTargeting().then((_) {
      _targetProperties = value;
      _targetPropertiesExplicitNull = (value == null);
      if (jsonEncode(_currentTargetProperties) != jsonEncode(value)) {
        _reinitSession();
      }
    });
  }

  void unsetTargetProperties() => setTargetProperties(null);

  // ---------------------------------------------------------------------------
  // Session helpers
  // ---------------------------------------------------------------------------

  bool _isSessionRequired() {
    if (_targetPropertiesExplicitNull) return false;
    if (_targetProperties != null) return true;
    return false;
  }

  bool _isSessionActive() => _sessionStatus == CbStatus.active;

  Future<void> _createSession({required String baseUrl}) async {
    final existingSession =
        await StorageHelper.getActiveSessionData(params.key!, _envKey);
    final csUrl =
        '${baseUrl}a-${params.accountId}/p-${params.projectId}/e-${params.environmentId}/cs';
    final response = await HttpHelper.postRetry(csUrl, body: {
      'previousSessionKey': _previousSessionKey ?? existingSession?.key,
      'targetProperties': _targetProperties,
    });
    final resBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (resBody['key'] == null) {
      throw Exception('Unable to create ConfigBee session');
    }

    final sessionData = SessionData(
      key: resBody['key'] as String,
      versionHash: resBody['versionHash'] as String,
    );
    await StorageHelper.setActiveSessionData(params.key!, _envKey, sessionData);
    _handleSessionData(resBody);
    _previousSessionKey = null;
    await _precacheSession(baseUrl: baseUrl);
  }

  Future<void> _refreshSession({required String baseUrl}) async {
    final sessionData =
        await StorageHelper.getActiveSessionData(params.key!, _envKey);
    if (sessionData == null) {
      await _createSession(baseUrl: baseUrl);
      return;
    }

    final res = await HttpHelper.fetchRetry(
        '$baseUrl$_envKey/cs-${sessionData.key}.json');
    if (res.statusCode == 404) {
      await _createSession(baseUrl: baseUrl);
      return;
    }

    final resBody = jsonDecode(res.body) as Map<String, dynamic>;
    if (resBody['configGroups'] == null) {
      throw Exception('Unable to refresh session');
    }

    await StorageHelper.setActiveSessionData(
        params.key!,
        _envKey,
        SessionData(
            key: sessionData.key,
            versionHash: resBody['versionHash'] as String));
    try {
      _handleSessionData(resBody);
    } catch (e) {
      if (e is CbError && e.type == 'TARGET_PROPERTIES_MISMATCH') {
        await _createSession(baseUrl: baseUrl);
        return;
      }
      rethrow;
    }
    await _precacheSession(baseUrl: baseUrl);
  }

  Future<void> _ensureSession({required String baseUrl}) async {
    if (_sessionStatus == CbStatus.deactive) {
      _sessionStatus = CbStatus.initializing;
      _sessionStatusController.add(_sessionStatus);
    }
    final sessionData =
        await StorageHelper.getActiveSessionData(params.key!, _envKey);
    if (sessionData == null) {
      await _createSession(baseUrl: baseUrl);
      return;
    }
    if (_currentTargetingData['default'] != null) return;

    final res = await HttpHelper.fetchRetry(
        '$baseUrl$_envKey/cs-${sessionData.key}--vh-${sessionData.versionHash}.json');
    if (res.statusCode == 404) {
      await _refreshSession(baseUrl: baseUrl);
      return;
    }

    final resBody = jsonDecode(res.body) as Map<String, dynamic>;
    if (resBody['configGroups'] == null) {
      throw Exception('Unable to activate session');
    }
    try {
      _handleSessionData(resBody);
    } catch (e) {
      if (e is CbError && e.type == 'TARGET_PROPERTIES_MISMATCH') {
        await _createSession(baseUrl: baseUrl);
        return;
      }
      rethrow;
    }
  }

  Future<void> _tryPreviousSessionClose({required String baseUrl}) async {
    final sessionData =
        await StorageHelper.getActiveSessionData(params.key!, _envKey);
    final prevKey = _previousSessionKey ?? sessionData?.key;
    if (prevKey == null) return;
    try {
      await http.post(
        Uri.parse(
            '${baseUrl}a-${params.accountId}/p-${params.projectId}/e-${params.environmentId}/cs-$prevKey.close'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (_) {}
    _previousSessionKey = null;
    await StorageHelper.clearActiveSessionData(params.key!, _envKey);
  }

  Future<void> _precacheSession({required String baseUrl}) async {
    final sessionData =
        await StorageHelper.getActiveSessionData(params.key!, _envKey);
    if (sessionData == null) return;
    try {
      unawaited(HttpHelper.fetchRetry(
          '$baseUrl$_envKey/cs-${sessionData.key}--vh-${sessionData.versionHash}.json'));
    } catch (_) {}
  }

  void _handleSessionData(Map<String, dynamic> resBody) {
    // restore target properties from session on first load
    _targetProperties ??=
        (resBody['targetProperties'] as Map?)?.cast<String, String>();

    if (jsonEncode(_targetProperties) !=
        jsonEncode(resBody['targetProperties'])) {
      throw CbError('TARGET_PROPERTIES_MISMATCH');
    }
    _currentTargetProperties =
        (resBody['targetProperties'] as Map?)?.cast<String, String>();
    _contextAssignments = (resBody['contextAssignments'] as List?)
            ?.map((e) => Map<String, String>.from(e as Map))
            .toList() ??
        [];

    _handleConfigGroupsData(resBody['configGroups'] as Map<String, dynamic>?);
    _handleTargetingData(resBody['targetingData'] as Map<String, dynamic>?);
    _handleStatusUpdate();
    _notifyConfigUpdate();
  }

  void _handleConfigGroupsData(Map<String, dynamic>? data) {
    if (data?['default'] != null) {
      _handleDistributionObj(
          DistributionObjData.fromJson(
              data!['default'] as Map<String, dynamic>),
          skipHandleUpdates: true);
    }
  }

  void _handleTargetingData(Map<String, dynamic>? data) {
    final targetingDefault = data?['default'] as Map<String, dynamic>?;
    if (targetingDefault == null) return;

    if (_currentTargetingData['default'] == null) {
      _currentTargetingData['default'] = TargetingData(
        distributionKeys: [],
        distributionData: {},
      );
    }
    _currentTargetingData['default'] = TargetingData(
      distributionKeys:
          (targetingDefault['distributionKeys'] as List).cast<String>(),
      distributionData: _currentTargetingData['default']!.distributionData,
    );

    final distData =
        targetingDefault['distributionData'] as Map<String, dynamic>? ?? {};
    distData.forEach((key, value) {
      _handleDistributionObj(
          DistributionObjData.fromJson(value as Map<String, dynamic>),
          skipHandleUpdates: true);
    });
  }

  // ---------------------------------------------------------------------------
  // Distribution object handling
  // ---------------------------------------------------------------------------

  void _handleDistributionObj(DistributionObjData obj,
      {bool skipHandleUpdates = false}) {
    final objKey = obj.key ?? _defaultGroupObjKey;

    if (_defaultGroupKeyRegex.hasMatch(objKey)) {
      final existing = _currentConfigGroupsData['default'];
      if (existing == null ||
          existing.meta.versionTs.compareTo(obj.meta.versionTs) < 0) {
        _currentConfigGroupsData['default'] = obj;
        StorageHelper.setDistObjectCurrentVersionId(
            params.key!, _distributionObjKey, obj.meta.versionId);
      }
    } else {
      final existing =
          _currentTargetingData['default']?.distributionData[objKey];
      if (existing == null ||
          existing.meta.versionTs.compareTo(obj.meta.versionTs) < 0) {
        _currentTargetingData['default']?.distributionData[objKey] = obj;
      }
    }

    if (!skipHandleUpdates) {
      _handleStatusUpdate();
      _notifyConfigUpdate();
    }
  }

  void _handleStatusUpdate() {
    if (_status != CbStatus.active &&
        _currentConfigGroupsData['default'] != null) {
      _status = CbStatus.active;
      _statusController.add(_status);
    }
    if (_sessionStatus != CbStatus.active &&
        _currentTargetingData['default'] != null) {
      _sessionStatus = CbStatus.active;
      _sessionStatusController.add(_sessionStatus);
    }
  }

  void _notifyConfigUpdate() {
    _configController.add(null);

    final snapshot = {
      'status': _status.name,
      'sessionStatus': _sessionStatus.name,
      'currentConfigGroupsData':
          _currentConfigGroupsData.map((k, v) => MapEntry(k, v.toJson())),
      'currentTargetingData': _currentTargetingData.map((k, v) => MapEntry(k, {
            'distributionKeys': v.distributionKeys,
            'distributionData':
                v.distributionData.map((k2, v2) => MapEntry(k2, v2.toJson())),
          })),
    };
    if (jsonEncode(snapshot) == jsonEncode(_notifiedData)) return;

    if (_readyNotificationPending) {
      _readyNotificationPending = false;
      try {
        params.onReady?.call();
      } catch (_) {}
      unawaited(_fireReadyTrace());
    } else {
      try {
        params.onUpdate?.call();
      } catch (_) {}
      unawaited(_fireUpdateTrace());
    }
    _notifiedData = snapshot;
  }

  // ---------------------------------------------------------------------------
  // SSE source
  // ---------------------------------------------------------------------------

  Future<void> _runSSESource(
      {required String key, required SSESource source}) async {
    _sseSource = source;
    _sseKey = key;
    _directBaseUrl = source.fetchBaseUrls.direct;
    _visitorId ??=
        await StorageHelper.getOrCreateVisitorId(params.key!, _distributionObjKey);

    Future<String> sessionFlow() async {
      if (_isSessionRequired()) {
        try {
          await _ensureSession(baseUrl: source.fetchBaseUrls.direct);
        } catch (e) {
          _sessionStatus = CbStatus.error;
          _sessionStatusController.add(_sessionStatus);
          return 'ERROR';
        }
      } else if (_targetProperties == null && !_targetPropertiesExplicitNull) {
        // "undefined" in TS — check if there's a stored session to restore
        final sessionData =
            await StorageHelper.getActiveSessionData(params.key!, _envKey);
        if (sessionData?.key != null) {
          try {
            await _ensureSession(baseUrl: source.fetchBaseUrls.direct);
          } catch (e) {
            _sessionStatus = CbStatus.error;
            _sessionStatusController.add(_sessionStatus);
            return 'ERROR';
          }
        } else {
          try {
            await _tryPreviousSessionClose(
                baseUrl: source.fetchBaseUrls.direct);
          } catch (_) {}
        }
      } else {
        try {
          await _tryPreviousSessionClose(baseUrl: source.fetchBaseUrls.direct);
        } catch (_) {}
      }
      return 'SUCCESS';
    }

    Future<String> defaultGroupFlow() async {
      if (_status == CbStatus.initializing || _status == CbStatus.deactive) {
        try {
          await _fetchWithFallback(_defaultGroupObjKey, source: source);
        } catch (_) {
          return 'ERROR';
        }
      }
      return 'SUCCESS';
    }

    final results = await Future.wait([defaultGroupFlow(), sessionFlow()]);
    if (results[0] == 'ERROR' && results[1] == 'ERROR') {
      _status = CbStatus.error;
      _statusController.add(_status);
      return;
    }
    unawaited(_continueSse(skipWait: true));
  }

  Future<void> _continueSse({bool skipWait = false}) async {
    if (!skipWait) await Future.delayed(const Duration(seconds: 1));

    if (_isSessionRequired()) {
      try {
        await _ensureSession(baseUrl: _sseSource!.fetchBaseUrls.direct);
      } catch (_) {
        unawaited(_continueSse());
        return;
      }
    }

    unawaited(_sseSubscription?.cancel());
    _sseActive = true;

    final ssePath = await _getSsePath();
    if (ssePath == null) return;

    try {
      _sseSubscription = SSEClient.subscribeToSSE(
        method: SSERequestType.GET,
        url: ssePath,
        header: {},
      ).listen(
        (event) {
          if (event.event != null && event.data != null) {
            _handleSseEvent(event.event!, event.data!);
          }
        },
        onError: (_) {
          if (_sseActive) _continueSse();
        },
        cancelOnError: true,
        onDone: () {
          if (_sseActive) _continueSse();
        },
      );
      _sendTrace([_makeEvent('stream-connected', {})]);
    } catch (_) {
      if (_sseActive) {
        unawaited(_continueSse());
      }
    }
  }

  void _handleSseEvent(String type, String data) async {
    try {
      final eventData = jsonDecode(data) as Map<String, dynamic>;
      final versionId = eventData['meta']?['versionId'] as String?;
      final versionTs = eventData['meta']?['versionTs'] as String?;
      final source = _sseSource!;

      if (!_isSessionRequired()) {
        final currentTs = _currentConfigGroupsData['default']?.meta.versionTs;
        if (currentTs != null &&
            versionTs != null &&
            currentTs.compareTo(versionTs) < 0) {
          await _fetchHttpAndProcess(await _getHttpPath(
              baseUrl: source.fetchBaseUrls.direct, versionId: versionId));
        }
      } else {
        switch (type) {
          case 'found':
          case 'updated':
            final objKey = 'a-${params.accountId}/${eventData['key'] ?? ''}';
            await _fetchHttpAndProcess(await _getHttpPath(
                baseUrl: source.fetchBaseUrls.direct,
                distributionObjKey: objKey,
                versionId: versionId));
            await _refreshSession(baseUrl: source.fetchBaseUrls.direct);
            break;
          case 'session-found':
            final sessionData =
                await StorageHelper.getActiveSessionData(params.key!, _envKey);
            final newHash = eventData['versionHash'] as String?;
            if (sessionData != null &&
                newHash != null &&
                sessionData.versionHash != newHash) {
              await StorageHelper.setActiveSessionData(params.key!, _envKey,
                  SessionData(key: sessionData.key, versionHash: newHash));
              _handleSessionData(eventData);
              await _precacheSession(baseUrl: source.fetchBaseUrls.direct);
            }
            break;
          case 'session-updated':
            await _refreshSession(baseUrl: source.fetchBaseUrls.direct);
            break;
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // HTTP source
  // ---------------------------------------------------------------------------

  Future<void> _runHttpSource(
      {required String key, required HttpFetchSource source}) async {
    final cacheMode = switch (source.cacheMode) {
      'none' => FetchCacheMode.noCache,
      'full' => FetchCacheMode.forceCache,
      _ => FetchCacheMode.request,
    };
    do {
      try {
        await _fetchHttpAndProcess(await _getHttpPath(baseUrl: source.baseUrl),
            cacheMode: cacheMode);
        if (!source.enablePolling) break;
      } catch (_) {}
      await Future.delayed(Duration(milliseconds: source.pollingDelay));
    } while (true);
  }

  // ---------------------------------------------------------------------------
  // HTTP fetch helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchWithFallback(String objKey,
      {required SSESource source}) async {
    // objKey here is the server-format key (no account prefix); build full fetch key
    final fetchObjKey = 'a-${params.accountId}/$objKey';
    final tries = [
      (
        url: await _getHttpPath(
            baseUrl: source.fetchBaseUrls.cdnCached,
            distributionObjKey: fetchObjKey,
            useVersionedUrl: true),
        cacheMode: FetchCacheMode.forceCache
      ),
      (
        url: await _getHttpPath(
            baseUrl: source.fetchBaseUrls.staticStore,
            distributionObjKey: fetchObjKey,
            useVersionedUrl: true),
        cacheMode: FetchCacheMode.request
      ),
      (
        url: await _getHttpPath(
            baseUrl: source.fetchBaseUrls.direct,
            distributionObjKey: fetchObjKey,
            useVersionedUrl: true),
        cacheMode: FetchCacheMode.request
      ),
      (
        url: await _getHttpPath(
            baseUrl: source.fetchBaseUrls.staticStore,
            distributionObjKey: fetchObjKey,
            useVersionedUrl: false),
        cacheMode: FetchCacheMode.request
      ),
    ];
    Exception? last;
    for (final t in tries) {
      try {
        await _fetchHttpAndProcess(t.url, cacheMode: t.cacheMode);
        return;
      } catch (e) {
        last = e is Exception ? e : Exception(e.toString());
      }
    }
    throw last!;
  }

  Future<void> _fetchHttpAndProcess(String url,
      {FetchCacheMode cacheMode = FetchCacheMode.request}) async {
    final res = await HttpHelper.fetchRetry(url, cacheMode: cacheMode);
    if (res.statusCode == 404) throw Exception('HTTP 404');
    if (res.statusCode != 200) {
      throw Exception('Unexpected HTTP status: ${res.statusCode}');
    }
    _handleDistributionObj(DistributionObjData.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>));
  }

  Future<String> _getHttpPath({
    required String baseUrl,
    String? distributionObjKey,
    String? versionId,
    bool useVersionedUrl = false,
  }) async {
    distributionObjKey ??= _distributionObjKey;
    if (useVersionedUrl || versionId != null) {
      final vid = versionId ??
          _currentConfigGroupsData['default']?.meta.versionId ??
          await StorageHelper.getDistObjectCurrentVersionId(
              params.key!, distributionObjKey);
      if (vid != null) return '$baseUrl$distributionObjKey--v-$vid.json';
    }
    return '$baseUrl$distributionObjKey.json';
  }

  Future<String?> _getSsePath() async {
    if (_isSessionRequired()) {
      final sessionData =
          await StorageHelper.getActiveSessionData(params.key!, _envKey);
      if (sessionData == null) return null;
      return '${_sseSource!.eventsBaseUrl}a-${params.accountId}/p-${params.projectId}/e-${params.environmentId}/cs-${sessionData.key}.events?svh=${sessionData.versionHash}&vid=$_visitorId';
    }
    final versionId = _currentConfigGroupsData['default']?.meta.versionId;
    return '${_sseSource!.eventsBaseUrl}$_distributionObjKey.events?sv=$versionId&vid=$_visitorId';
  }

  // ---------------------------------------------------------------------------
  // Session reinit
  // ---------------------------------------------------------------------------

  Future<void> _reinitSession() async {
    final sessionData =
        await StorageHelper.getActiveSessionData(params.key!, _envKey);

    _sseActive = false;
    unawaited(_sseSubscription?.cancel());
    _sseSubscription = null;

    _sessionStatus = CbStatus.deactive;
    _currentTargetProperties = null;
    _currentTargetingData.clear();
    _contextAssignments = [];

    if (sessionData?.key != null) _previousSessionKey = sessionData!.key;

    await StorageHelper.clearActiveSessionData(params.key!, _envKey);
    _handleStatusUpdate();
    _notifyConfigUpdate();

    if (_sseKey != null && _sseSource != null) {
      unawaited(_runSSESource(key: _sseKey!, source: _sseSource!));
    }
  }

  // ---------------------------------------------------------------------------
  // Wait helpers
  // ---------------------------------------------------------------------------

  Future<CbStatus> waitToLoad(
      {Duration timeout = const Duration(seconds: 60)}) async {
    if (_status == CbStatus.initializing) {
      await statusStream
          .firstWhere((s) => s != CbStatus.initializing)
          .timeout(timeout);
    }
    return _status;
  }

  Future<CbStatus> waitToLoadTargeting(
      {Duration timeout = const Duration(seconds: 60)}) async {
    final start = DateTime.now();
    await waitToLoad(timeout: timeout);
    final remaining = timeout - DateTime.now().difference(start);
    if (_sessionStatus == CbStatus.initializing) {
      await sessionStatusStream
          .firstWhere((s) => s != CbStatus.initializing)
          .timeout(remaining > Duration.zero ? remaining : Duration.zero);
    }
    return _sessionStatus;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Map<String, OptionData>? _getCombinedContent() {
    if (_status != CbStatus.active) return null;
    final baseObj = _currentConfigGroupsData['default'];
    if (baseObj == null) return null;
    final base = baseObj.content;

    final modifierExtras = <Map<String, OptionData>>[];
    final cm = baseObj.contentModifiers;
    if (cm != null && cm.keys.isNotEmpty) {
      for (final key in cm.keys) {
        final modifier = cm.data[key];
        if (modifier != null &&
            ModifierEvaluator.evaluate(
                modifier, _visitorId ?? '', _contextAssignments) &&
            modifier.content != null) {
          modifierExtras.add(modifier.content!);
        }
      }
    }

    if (_isSessionActive()) {
      final keys = _currentTargetingData['default']?.distributionKeys ?? [];
      final distData = _currentTargetingData['default']!.distributionData;
      final targetingExtras = keys
          .map((k) => distData[k]?.content)
          .whereType<Map<String, OptionData>>()
          .toList();
      return _combineContent(base: base, extras: [...modifierExtras, ...targetingExtras]);
    } else if (modifierExtras.isNotEmpty) {
      return _combineContent(base: base, extras: modifierExtras);
    }
    return base;
  }

  Map<String, OptionData> _combineContent({
    required Map<String, OptionData> base,
    required List<Map<String, OptionData>> extras,
  }) {
    final combined = Map<String, OptionData>.from(base);
    for (final extra in extras) {
      extra.forEach((key, value) {
        final hasValue = switch (value.optionType) {
          CbOptionType.flag => value.flagValue != null,
          CbOptionType.number => value.numberValue != null,
          CbOptionType.text => value.textValue != null,
          CbOptionType.json => value.jsonValue != null,
        };
        if (hasValue && combined.containsKey(key)) combined[key] = value;
      });
    }
    return combined;
  }

  bool? getFlag(String key) {
    final o = _getCombinedContent()?[key];
    return o?.optionType == CbOptionType.flag ? o!.flagValue : null;
  }

  Map<String, bool?>? getAllFlags() {
    final c = _getCombinedContent();
    if (c == null) return null;
    return {
      for (final e
          in c.entries.where((e) => e.value.optionType == CbOptionType.flag))
        e.key: e.value.flagValue
    };
  }

  num? getNumber(String key) {
    final o = _getCombinedContent()?[key];
    return o?.optionType == CbOptionType.number ? o!.numberValue : null;
  }

  Map<String, num?>? getAllNumbers() {
    final c = _getCombinedContent();
    if (c == null) return null;
    return {
      for (final e
          in c.entries.where((e) => e.value.optionType == CbOptionType.number))
        e.key: e.value.numberValue
    };
  }

  String? getText(String key) {
    final o = _getCombinedContent()?[key];
    return o?.optionType == CbOptionType.text ? o!.textValue : null;
  }

  Map<String, String?>? getAllTexts() {
    final c = _getCombinedContent();
    if (c == null) return null;
    return {
      for (final e
          in c.entries.where((e) => e.value.optionType == CbOptionType.text))
        e.key: e.value.textValue
    };
  }

  Map<String, dynamic>? getJson(String key) {
    final o = _getCombinedContent()?[key];
    return o?.optionType == CbOptionType.json ? o!.jsonValue : null;
  }

  Map<String, Map<String, dynamic>?>? getAllJsons() {
    final c = _getCombinedContent();
    if (c == null) return null;
    return {
      for (final e
          in c.entries.where((e) => e.value.optionType == CbOptionType.json))
        e.key: e.value.jsonValue
    };
  }

  // ---------------------------------------------------------------------------
  // Tracing
  // ---------------------------------------------------------------------------

  static String _generateEventId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Map<String, dynamic> _makeEvent(String type, Map<String, dynamic> props) => {
        'clientSideId': _generateEventId(),
        'clientSideTsMs': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'props': props,
      };

  void _sendTrace(List<Map<String, dynamic>> events) {
    if (_directBaseUrl == null) return;
    final traceUrl =
        '${_directBaseUrl}a-${params.accountId}/p-${params.projectId}/e-${params.environmentId}/trace';
    final servingVersion = _currentConfigGroupsData['default']?.meta.versionId;
    getSdkVersion().then((sdkVersion) async {
      final sessionHash =
          (await StorageHelper.getActiveSessionData(params.key!, _envKey))
              ?.versionHash;
      final payload = {
        'visitorId': _visitorId,
        'sdkName': 'cb-client-flutter',
        'sdkVersion': sdkVersion,
        'servingVersion': servingVersion,
        'sessionVersionHash': sessionHash,
        'events': events,
      };
      final body = base64Encode(utf8.encode(jsonEncode(payload)));
      unawaited(http
          .post(Uri.parse(traceUrl),
              headers: {'Content-Type': 'text/plain'}, body: body)
          .catchError((_) {}));
    }).catchError((_) {});
  }

  Future<void> _fireReadyTrace() async {
    final servingVersion =
        _currentConfigGroupsData['default']?.meta.versionId;
    final sessionHash =
        (await StorageHelper.getActiveSessionData(params.key!, _envKey))
            ?.versionHash;
    _lastTracedServingVersion = servingVersion;
    _lastTracedSessionVersionHash = sessionHash;
    _sendTrace([
      _makeEvent('client-ready', {
        'servingVersion': servingVersion,
        'sessionVersionHash': sessionHash,
      })
    ]);
  }

  Future<void> _fireUpdateTrace() async {
    final servingVersion =
        _currentConfigGroupsData['default']?.meta.versionId;
    final sessionHash =
        (await StorageHelper.getActiveSessionData(params.key!, _envKey))
            ?.versionHash;
    if (servingVersion == _lastTracedServingVersion &&
        sessionHash == _lastTracedSessionVersionHash) return;
    _lastTracedServingVersion = servingVersion;
    _lastTracedSessionVersionHash = sessionHash;
    _sendTrace([
      _makeEvent('client-state-updated', {
        'servingVersion': servingVersion,
        'sessionVersionHash': sessionHash,
      })
    ]);
  }

  void dispose() {
    _sseActive = false;
    _sseSubscription?.cancel();
    _statusController.close();
    _sessionStatusController.close();
    _configController.close();
  }
}
