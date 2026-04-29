import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/src/rust/api/simple.dart' as rust;
import 'package:path_provider/path_provider.dart';

class DownloadService {
  Future<CbzMetadata> downloadChapter({
    required String webtoonId,
    required String webtoonTitle,
    required ApiEpisodeItem chapter,
    required void Function(String status) onProgress,
  }) async {
    final directory = await getApplicationDocumentsDirectory();

    onProgress('Ch. ${chapter.episodeNo} - ${chapter.episodeTitle}');

    final metadata = await rust.downloadChapterAsCbz(
      basePath: directory.path,
      webtoonId: webtoonId,
      webtoonTitle: webtoonTitle,
      chapterUrl: chapter.viewerLink,
      chapterNumber: chapter.episodeNo,
      chapterTitle: chapter.episodeTitle,
    );

    print('[DownloadService] CBZ créé: ${metadata.filePath} (${metadata.pageCount} pages)');
    return metadata;
  }
}
