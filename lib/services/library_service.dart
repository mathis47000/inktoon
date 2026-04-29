import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/src/rust/api/simple.dart' as rust;
import 'package:path_provider/path_provider.dart';

class LibraryService {
  Future<LibraryInfo> getLibrary() async {
    final dir = await getApplicationDocumentsDirectory();
    print('[LibraryService] base path: ${dir.path}');
    final library = await rust.getLibrary(basePath: dir.path);
    print('[LibraryService] webtoons trouvés: ${library.webtoons.length}');
    for (final w in library.webtoons) {
      print('[LibraryService]  - ${w.webtoonId} | ${w.title} | ${w.chapters.length} chapitres | coverPath: ${w.coverPath}');
    }
    return library;
  }

  Future<WebtoonLibraryItem> getWebtoon(String webtoonId) async {
    final dir = await getApplicationDocumentsDirectory();
    return rust.getWebtoonLibrary(basePath: dir.path, webtoonId: webtoonId);
  }

  String formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
