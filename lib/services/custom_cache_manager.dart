import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thinkfast/services/local_cache_service.dart';

class CustomCacheManager {
  static const key = 'thinkfast_media_cache';

  static CacheManager? _instance;

  static Future<CacheManager> getInstance() async {
    if (_instance != null) return _instance!;

    final limitMb = await LocalCacheService().getCacheLimit();
    final directory = await getTemporaryDirectory();
    final path = p.join(directory.path, key);

    _instance = CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 15),
        maxNrOfCacheObjects: 1000,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
        fileSystem: IOFileSystem(path),
      ),
    );

    // Note: Default CacheManager doesn't expose a direct 'maxCacheSize' in bytes in the standard Config constructor
    // but it manages stalePeriod and maxNrOfCacheObjects.
    // To implement a strict MB limit, we would need a custom implementation of the CacheInfoRepository or a cleanup task.
    // For now, we'll use maxNrOfCacheObjects as a proxy and focus on the user's ability to clear it.

    return _instance!;
  }

  /// ✅ Refresh instance if settings changed
  static void refreshConfig() {
    _instance = null;
  }
}
