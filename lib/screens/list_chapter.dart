import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inktoon/services/download_manager.dart';
import 'package:inktoon/services/library_service.dart';
import 'package:inktoon/services/webtoon_service.dart';
import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/widgets/chapter_tile.dart';

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
    if (DownloadManager.instance.isRunning &&
        DownloadManager.instance.currentWebtoonId == widget.webtoonId) {
      _progress = DownloadManager.instance.lastProgress;
    }
    _sub = DownloadManager.instance.progress.listen((p) {
      if (!mounted) return;
      if (DownloadManager.instance.currentWebtoonId != widget.webtoonId &&
          !p.isDone) {
        return;
      }
      setState(() => _progress = p);
      if (p.isDone) { _onDownloadDone(p); }
    });
  }

  Future<void> _onDownloadDone(DownloadProgress p) async {
    if (!mounted) return;
    setState(() { _progress = null; _selectedChapters.clear(); });
    if (p.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : ${p.error}'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${p.total} chapitre(s) téléchargé(s) !'),
        backgroundColor: Colors.green,
      ));
      final downloaded = await _loadDownloadedChapters();
      if (!mounted) return;
      setState(() => _downloadedChapters = downloaded);
    }
  }

  Future<void> _loadEpisodes() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final results = await _webtoonService.getEpisodes(widget.webtoonId);
      final downloaded = await _loadDownloadedChapters();
      if (mounted) {
        setState(() {
          _results = results;
          _downloadedChapters = downloaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
    if (_selectedChapters.isEmpty) return;
    final sorted = _selectedChapters.toList()..sort();
    final chapters =
        sorted.map((no) => _results.firstWhere((c) => c.episodeNo == no)).toList();
    unawaited(DownloadManager.instance.start(
      webtoonId: widget.webtoonId,
      webtoonTitle: widget.webtoonTitle,
      chapters: chapters,
    ));
    // started event fires synchronously above → HomeScreen switches to Library tab.
    // Pop back so the user sees the tab change.
    if (mounted) Navigator.of(context).pop();
  }

  bool get _isDownloading =>
      (_progress != null && !_progress!.isDone) ||
      (DownloadManager.instance.isRunning &&
          DownloadManager.instance.currentWebtoonId == widget.webtoonId);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.webtoonTitle.isNotEmpty ? widget.webtoonTitle : 'Chapitres';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) return const SizedBox.shrink();

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_outlined, size: 64, color: scheme.error),
              const SizedBox(height: 16),
              Text('Impossible de charger les chapitres',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                  onPressed: _loadEpisodes, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text('Aucun chapitre trouvé',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            if (_selectedChapters.isNotEmpty)
              Material(
                color: scheme.primaryContainer,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedChapters.length} sélectionné(s)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isDownloading
                            ? null
                            : () => setState(() => _selectedChapters.clear()),
                        child: const Text('Effacer'),
                      ),
                      TextButton.icon(
                        onPressed: _isDownloading
                            ? null
                            : () => setState(() => _selectedChapters.addAll(
                                  _results
                                      .where((c) => !_downloadedChapters
                                          .contains(c.episodeNo))
                                      .map((c) => c.episodeNo),
                                )),
                        icon: const Icon(Icons.select_all, size: 18),
                        label: const Text('Tout'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.7,
                ),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final chapter = _results[index];
                  return ChapterTile(
                    chapter: chapter,
                    isSelected: _selectedChapters.contains(chapter.episodeNo),
                    isDisabled: _isDownloading,
                    isDownloaded: _downloadedChapters.contains(chapter.episodeNo),
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
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isDownloading
                  ? 'En cours…'
                  : 'Télécharger (${_selectedChapters.length})'),
            ),
          ),
      ],
    );
  }
}
