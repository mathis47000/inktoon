import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inktoon/services/download_manager.dart';
import 'package:inktoon/services/library_service.dart';
import 'package:inktoon/services/webtoon_service.dart';
import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/widgets/chapter_tile.dart';
import 'package:inktoon/widgets/download_overlay.dart';

class ListChapter extends StatefulWidget {
  final String webtoonId;
  final String webtoonTitle;

  const ListChapter({
    super.key,
    required this.webtoonId,
    this.webtoonTitle = '',
  });

  @override
  State<ListChapter> createState() => _ListChapterState();
}

class _ListChapterState extends State<ListChapter> {
  final _webtoonService = WebtoonService();
  final _libraryService = LibraryService();

  List<ApiEpisodeItem> _results = [];
  Set<int> _downloadedChapters = {};
  bool _isLoading = true;
  String? _error;

  final Set<int> _selectedChapters = {};

  // download progress (driven by DownloadManager stream)
  DownloadProgress? _progress;
  StreamSubscription<DownloadProgress>? _sub;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
    _subscribeToDownload();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribeToDownload() {
    // If a download is already running for this webtoon, pick up the current state.
    if (DownloadManager.instance.isRunning &&
        DownloadManager.instance.currentWebtoonId == widget.webtoonId) {
      _progress = DownloadManager.instance.lastProgress;
    }

    _sub = DownloadManager.instance.progress.listen((p) {
      if (!mounted) return;
      // Only show progress for this webtoon's download.
      if (DownloadManager.instance.currentWebtoonId != widget.webtoonId &&
          !p.isDone) { return; }
      setState(() => _progress = p);
      if (p.isDone) {
        _onDownloadDone(p);
      }
    });
  }

  Future<void> _onDownloadDone(DownloadProgress p) async {
    if (!mounted) return;
    setState(() {
      _progress = null;
      _selectedChapters.clear();
    });
    if (p.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${p.error}'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p.total} chapitre(s) téléchargé(s) !'),
          backgroundColor: Colors.green,
        ),
      );
      final downloaded = await _loadDownloadedChapters();
      if (!mounted) return;
      setState(() => _downloadedChapters = downloaded);
    }
  }

  Future<void> _loadEpisodes() async {
    try {
      final results = await _webtoonService.getEpisodes(widget.webtoonId);
      final downloaded = await _loadDownloadedChapters();
      setState(() {
        _results = results;
        _downloadedChapters = downloaded;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Set<int>> _loadDownloadedChapters() async {
    try {
      final item = await _libraryService.getWebtoon(widget.webtoonId);
      return {for (final c in item.chapters) c.chapterNumber};
    } catch (_) {
      return {};
    }
  }

  void _toggleSelection(int chapterNumber) {
    setState(() {
      if (_selectedChapters.contains(chapterNumber)) {
        _selectedChapters.remove(chapterNumber);
      } else {
        _selectedChapters.add(chapterNumber);
      }
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedChapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun chapitre sélectionné'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final sorted = _selectedChapters.toList()..sort();
    final chapters =
        sorted.map((no) => _results.firstWhere((c) => c.episodeNo == no)).toList();

    // Fire and forget — DownloadManager runs independently.
    unawaited(DownloadManager.instance.start(
      webtoonId: widget.webtoonId,
      webtoonTitle: widget.webtoonTitle,
      chapters: chapters,
    ));
  }

  bool get _isDownloading =>
      (_progress != null && !(_progress!.isDone)) ||
      (DownloadManager.instance.isRunning &&
          DownloadManager.instance.currentWebtoonId == widget.webtoonId);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chargement...'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erreur'),
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Erreur: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEpisodes,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chapitres'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(child: Text('Aucun chapitre trouvé')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapitres'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_selectedChapters.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.withValues(alpha: 0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedChapters.length} sélectionné(s)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _isDownloading
                                ? null
                                : () => setState(() => _selectedChapters.clear()),
                            child: const Text('Désélectionner'),
                          ),
                          TextButton.icon(
                            onPressed: _isDownloading
                                ? null
                                : () => setState(
                                      () => _selectedChapters.addAll(
                                        _results
                                            .where((c) => !_downloadedChapters
                                                .contains(c.episodeNo))
                                            .map((c) => c.episodeNo),
                                      ),
                                    ),
                            icon: const Icon(Icons.select_all),
                            label: const Text('Tout'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final chapter = _results[index];
                    return ChapterTile(
                      chapter: chapter,
                      isSelected:
                          _selectedChapters.contains(chapter.episodeNo),
                      isDisabled: _isDownloading,
                      isDownloaded:
                          _downloadedChapters.contains(chapter.episodeNo),
                      onTap: () => _toggleSelection(chapter.episodeNo),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_selectedChapters.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _isDownloading ? null : _downloadSelected,
                backgroundColor: _isDownloading ? Colors.grey : Colors.blue,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _isDownloading
                      ? 'En cours...'
                      : 'Télécharger (${_selectedChapters.length})',
                ),
              ),
            ),
          if (_isDownloading && _progress != null)
            DownloadOverlay(
              progress: _progress!.total > 0
                  ? _progress!.current / _progress!.total
                  : 0,
              currentChapter: _progress!.current,
              totalChapters: _progress!.total,
              status: _progress!.status,
            ),
        ],
      ),
    );
  }
}
