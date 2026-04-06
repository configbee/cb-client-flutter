abstract class ConfigbeeSource {
  final String type;
  ConfigbeeSource(this.type);
}

class OfflineSource extends ConfigbeeSource {
  final Map<String, dynamic> data;

  OfflineSource({required this.data}) : super('offline');
}

class HttpFetchSource extends ConfigbeeSource {
  final String baseUrl;
  final String cacheMode; // "none", "full", "default"
  final bool enablePolling;
  final int pollingDelay;
  final bool useVersionedUrl;

  HttpFetchSource({
    required this.baseUrl,
    this.cacheMode = 'default',
    this.enablePolling = false,
    this.pollingDelay = 5000,
    this.useVersionedUrl = false,
  }) : super('http-fetch');
}

class SSESource extends ConfigbeeSource {
  final String eventsBaseUrl;
  final SSEFetchBaseUrls fetchBaseUrls;
  final List<String>? fallbackSources;

  SSESource({
    required this.eventsBaseUrl,
    required this.fetchBaseUrls,
    this.fallbackSources,
  }) : super('sse');
}

class SSEFetchBaseUrls {
  final String cdnCached;
  final String staticStore;
  final String direct;

  SSEFetchBaseUrls({
    required this.cdnCached,
    required this.staticStore,
    required this.direct,
  });
}
