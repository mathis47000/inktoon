import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/src/rust/api/simple.dart' as rust;

class ExportService {
  static const _channel = MethodChannel('inktoon/downloads');

  Future<ExportResult> exportToDevice({
    required WebtoonLibraryItem webtoon,
    required List<int> chapterNumbers,
    required bool merge,
  }) async {
    final sourceDir = await getApplicationDocumentsDirectory();
    final subFolder = 'Inktoon/${_sanitize(webtoon.title)}';

    final sourcePaths = await _getSourcePaths(
      webtoon: webtoon,
      chapterNumbers: chapterNumbers,
      merge: merge,
      basePath: sourceDir.path,
    );

    if (Platform.isAndroid) {
      for (final path in sourcePaths) {
        final fileName = path.split('/').last;
        await _channel.invokeMethod<String>('saveToDownloads', {
          'filePath': path,
          'fileName': fileName,
          'subFolder': subFolder,
        });
      }
      return ExportResult(
        directory: 'Téléchargements/$subFolder',
        fileCount: sourcePaths.length,
      );
    } else {
      // Fallback for non-Android platforms
      final destDir = Directory('${sourceDir.path}/$subFolder');
      await destDir.create(recursive: true);
      for (final path in sourcePaths) {
        final filename = path.split('/').last;
        await File(path).copy('${destDir.path}/$filename');
      }
      return ExportResult(
        directory: destDir.path,
        fileCount: sourcePaths.length,
      );
    }
  }

  Future<List<String>> _getSourcePaths({
    required WebtoonLibraryItem webtoon,
    required List<int> chapterNumbers,
    required bool merge,
    required String basePath,
  }) async {
    if (merge && chapterNumbers.length > 1) {
      final name = _sanitize(
        '${webtoon.title}_ch${chapterNumbers.first}-${chapterNumbers.last}',
      );
      final merged = await rust.mergeCbzFiles(
        basePath: basePath,
        webtoonId: webtoon.webtoonId,
        webtoonTitle: webtoon.title,
        chapterNumbers: chapterNumbers,
        outputName: name,
      );
      return [merged];
    }
    return chapterNumbers.map((no) {
      return webtoon.chapters.firstWhere((c) => c.chapterNumber == no).filePath;
    }).toList();
  }

  int selectedSize(WebtoonLibraryItem webtoon, List<int> chapterNumbers) {
    return chapterNumbers.fold(0, (sum, no) {
      final ch = webtoon.chapters.firstWhere((c) => c.chapterNumber == no);
      return sum + ch.fileSize.toInt();
    });
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*\s]+'), '_');
}

class ExportResult {
  final String directory;
  final int fileCount;
  ExportResult({required this.directory, required this.fileCount});
}
