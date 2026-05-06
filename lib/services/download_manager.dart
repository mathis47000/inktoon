import 'dart:async';
import 'package:flutter/services.dart';
import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/src/rust/api/simple.dart' as rust;
import 'package:path_provider/path_provider.dart';

class DownloadProgress {
  final int current;
  final int total;
  final int currentPage;
  final int totalPages;
  final String status;
  final bool isDone;
  final String? error;

  const DownloadProgress({
    required this.current,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.status,
    required this.isDone,
    this.error,
  });
}

class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const _channel = MethodChannel('inktoon/downloads');

  final _controller = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progress => _controller.stream;

  final _startedController = StreamController<void>.broadcast();
  Stream<void> get started => _startedController.stream;

  Timer? _pollTimer;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _currentWebtoonId;
  String? get currentWebtoonId => _currentWebtoonId;

  String? _currentWebtoonTitle;
  String? get currentWebtoonTitle => _currentWebtoonTitle;

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

    // Set state synchronously before any await so the started event
    // fires immediately (HomeScreen receives it in the same microtask).
    _isRunning = true;
    _currentWebtoonId = webtoonId;
    _currentWebtoonTitle = webtoonTitle;
    _last = null;
    _startedController.add(null);

    final basePath = (await getApplicationDocumentsDirectory()).path;

    await _channel
        .invokeMethod('startDownloadService', {'title': webtoonTitle})
        .catchError((_) {});

    await rust.startBackgroundDownload(
      basePath: basePath,
      webtoonId: webtoonId,
      webtoonTitle: webtoonTitle,
      chapters: chapters
          .map((c) => BgChapterTask(
                chapterUrl: c.viewerLink,
                chapterNumber: c.episodeNo,
                chapterTitle: c.episodeTitle,
              ))
          .toList(),
    );

    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final state = await rust.pollDownloadProgress();
      final p = DownloadProgress(
        current: state.current,
        total: state.total,
        currentPage: state.currentPage,
        totalPages: state.totalPages,
        status: state.status,
        isDone: state.isDone,
        error: state.error,
      );
      _emit(p);
      _updateNotification(
          state.current, state.total, state.currentPage, state.totalPages, webtoonTitle);

      if (state.isDone) {
        _pollTimer?.cancel();
        _pollTimer = null;
        _isRunning = false;
        _currentWebtoonId = null;
        _currentWebtoonTitle = null;
        _cancelNotification();
      }
    });
  }

  void cancel() {
    rust.cancelBackgroundDownload();
  }

  void _updateNotification(
      int current, int total, int currentPage, int totalPages, String title) {
    _channel.invokeMethod('updateDownloadNotification', {
      'current': current,
      'total': total,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'title': title,
    }).catchError((_) {});
  }

  void _cancelNotification() {
    _channel.invokeMethod('cancelDownloadNotification').catchError((_) {});
  }
}
