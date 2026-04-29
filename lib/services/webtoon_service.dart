import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/src/rust/api/simple.dart' as rust;

class WebtoonService {
  Future<List<WebtoonResult>> search(String keyword, String language) {
    return rust.searchWebtoons(keyword: keyword, langage: language);
  }

  Future<List<ApiEpisodeItem>> getEpisodes(String titleNo) {
    return rust.getWebtoonEpisodes(titleNo: titleNo);
  }

  Future<List<ChapterPage>> getChapterPages(String chapUrl) {
    return rust.getChapterPages(chapUrl: chapUrl);
  }
}
