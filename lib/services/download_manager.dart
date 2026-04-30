import 'dart:async';
import 'package:flutter/services.dart';
import 'package:inktoon/services/download_service.dart';
import 'package:inktoon/src/rust/api/models.dart';

class DownloadProgress {
  final int current;
  final int total;
  final String status;
  final bool isDone;
  final String? error;

  const DownloadProgress({
    required this.current,
    required this.total,
    required this.status,
    required this.isDone,
    this.error,
  });
}

class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const _channel = MethodChannel('inktoon/downloads');
  final _downloadService = DownloadService();

  final _controller = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progress => _controller.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _currentWebtoonId;
  String? get currentWebtoonId => _currentWebtoonId;

  DownloadProgress? _last;
  DownloadProgress? get lastProgress => _last;

  void _emit(DownloadProgress p) {
    _last = p;
    _controller.add(p);
  }

  Future<void> start({
    required String webtoonId,
    required String webtoonTitle,
    required List<ApiEpisodeItem> chapters,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    _currentWebtoonId = webtoonId;
    _last = null;
    final total = chapters.length;

    try {
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        _emit(DownloadProgress(
          current: i + 1,
          total: total,
          status: 'Ch. ${chapter.episodeNo}',
          isDone: false,
        ));
        _updateNotification(i + 1, total, webtoonTitle);

        await _downloadService.downloadChapter(
          webtoonId: webtoonId,
          webtoonTitle: webtoonTitle,
          chapter: chapter,
          onProgress: (status) => _emit(DownloadProgress(
            current: i + 1,
            total: total,
            status: status,
            isDone: false,
          )),
        );
      }
      _emit(DownloadProgress(
        current: total,
        total: total,
        status: 'Terminé',
        isDone: true,
      ));
    } catch (e) {
      _emit(DownloadProgress(
        current: 0,
        total: total,
        status: '',
        isDone: true,
        error: e.toString(),
      ));
    } finally {
      _isRunning = false;
      _currentWebtoonId = null;
      _cancelNotification();
    }
  }

  void _updateNotification(int current, int total, String title) {
    _channel.invokeMethod('updateDownloadNotification', {
      'current': current,
      'total': total,
      'title': title,
    }).catchError((_) {});
  }

  void _cancelNotification() {
    _channel.invokeMethod('cancelDownloadNotification').catchError((_) {});
  }
}
