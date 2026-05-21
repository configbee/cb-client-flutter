import 'package:package_info_plus/package_info_plus.dart';

String? _cachedVersion;

Future<String> getSdkVersion() async {
  if (_cachedVersion != null) return _cachedVersion!;
  final info = await PackageInfo.fromPlatform();
  _cachedVersion = info.version;
  return _cachedVersion!;
}
