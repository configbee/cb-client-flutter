import 'package:path_provider/path_provider.dart';

Future<String> getCacheDirectoryPath() async {
  final dir = await getApplicationCacheDirectory();
  return dir.path;
}
