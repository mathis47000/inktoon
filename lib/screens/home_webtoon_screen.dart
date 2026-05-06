import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:inktoon/screens/list_chapter.dart';
import 'package:inktoon/services/download_manager.dart';
import 'package:inktoon/services/library_service.dart';
import 'package:inktoon/services/webtoon_service.dart';
import 'package:inktoon/src/rust/api/models.dart';

class _NewChaptersEntry {
  final WebtoonLibraryItem webtoon;
  final List<ApiEpisodeItem> newChapters;

  const _NewChaptersEntry({required this.webtoon, required this.newChapters});
}

class HomeWebtoonScreen extends StatefulWidget {
  const HomeWebtoonScreen({super.key});

  @override
  State<HomeWebtoonScreen> createState() => _HomeWebtoonScreenState();
}

class _HomeWebtoonScreenState extends State<HomeWebtoonScreen> {
  final _libraryService = LibraryService();
  final _webtoonService = WebtoonService();

  List<_NewChaptersEntry> _entries = [];
  bool _hasLibrary = false;
  bool _loading = true;

  DownloadProgress? _dlProgress;
  StreamSubscription<DownloadProgress>? _dlSub;

  @override
  void initState() {
    super.initState();
    _load();
    _dlProgress = DownloadManager.instance.lastProgress;
    _dlSub = DownloadManager.instance.progress.listen((p) {
      if (mounted) setState(() => _dlProgress = p);
      if (p.isDone && p.error == null) _load();
    });
  }

  @override
  void dispose() {
    _dlSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final lib = await _libraryService.getLibrary();
      _hasLibrary = lib.webtoons.isNotEmpty;

      if (lib.webtoons.isEmpty) {
        if (mounted) setState(() { _entries = []; _loading = false; });
        return;
      }

      final fetched = await Future.wait(
        lib.webtoons.map(_fetchNewChapters),
      );

      final entries = fetched
          .whereType<_NewChaptersEntry>()
          .where((e) => e.newChapters.isNotEmpty)
          .toList();

      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_NewChaptersEntry?> _fetchNewChapters(WebtoonLibraryItem webtoon) async {
    try {
      final episodes = await _webtoonService.getEpisodes(webtoon.webtoonId);
      final downloaded = {for (final c in webtoon.chapters) c.chapterNumber};
      final newEps = episodes.where((e) => !downloaded.contains(e.episodeNo)).toList();
      return _NewChaptersEntry(webtoon: webtoon, newChapters: newEps);
    } catch (_) {
      return null;
    }
  }

  bool get _isAnyDownloading {
    final p = _dlProgress;
    return DownloadManager.instance.isRunning || (p != null && !p.isDone);
  }

  void _downloadAll(_NewChaptersEntry entry) {
    unawaited(DownloadManager.instance.start(
      webtoonId: entry.webtoon.webtoonId,
      webtoonTitle: entry.webtoon.title,
      chapters: entry.newChapters,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveaux chapitres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasLibrary
              ? const _EmptyLibraryState()
              : _entries.isEmpty
                  ? const _AllUpToDateState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final entry = _entries[i];
                          final isThisDownloading = _isAnyDownloading &&
                              DownloadManager.instance.currentWebtoonId ==
                                  entry.webtoon.webtoonId;
                          return _NewChaptersCard(
                            entry: entry,
                            isDownloading: isThisDownloading,
                            anyDownloading: _isAnyDownloading,
                            onDownloadAll: () => _downloadAll(entry),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ListChapter(
                                  webtoonId: entry.webtoon.webtoonId,
                                  webtoonTitle: entry.webtoon.title,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _NewChaptersCard extends StatelessWidget {
  final _NewChaptersEntry entry;
  final bool isDownloading;
  final bool anyDownloading;
  final VoidCallback onDownloadAll;
  final VoidCallback onTap;

  const _NewChaptersCard({
    required this.entry,
    required this.isDownloading,
    required this.anyDownloading,
    required this.onDownloadAll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = File(entry.webtoon.coverPath);
    final count = entry.newChapters.length;
    final preview = entry.newChapters.take(3).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: cover.existsSync()
                    ? Image.file(cover, width: 64, height: 90, fit: BoxFit.cover)
                    : Container(
                        width: 64,
                        height: 90,
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.book_outlined,
                            color: scheme.onSurfaceVariant),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.webtoon.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+$count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...preview.map((ep) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            'Ch. ${ep.episodeNo} – ${ep.episodeTitle}',
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                    if (count > 3)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '+ ${count - 3} autres',
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.7)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.tonalIcon(
                              onPressed: anyDownloading ? null : onDownloadAll,
                              icon: const Icon(Icons.download, size: 16),
                              label: Text('Télécharger ($count)'),
                              style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllUpToDateState extends StatelessWidget {
  const _AllUpToDateState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: scheme.primary),
            const SizedBox(height: 20),
            Text('Tout est à jour !',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tu as téléchargé tous les chapitres disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 80, color: scheme.onSurfaceVariant),
            const SizedBox(height: 20),
            Text('Aucun webtoon téléchargé',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Recherchez un webtoon et téléchargez des chapitres\npour les retrouver ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
