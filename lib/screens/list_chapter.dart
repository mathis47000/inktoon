import 'package:flutter/material.dart';
import 'package:inktoon/services/download_service.dart';
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
  final _downloadService = DownloadService();

  List<ApiEpisodeItem> _results = [];
  bool _isLoading = true;
  String? _error;

  final Set<int> _selectedChapters = {};

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  int _currentChapter = 0;
  int _totalChapters = 0;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    try {
      final results = await _webtoonService.getEpisodes(widget.webtoonId);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _totalChapters = sorted.length;
      _currentChapter = 0;
    });

    try {
      for (int i = 0; i < sorted.length; i++) {
        final chapter = _results.firstWhere((ch) => ch.episodeNo == sorted[i]);

        if (!mounted) return;
        setState(() {
          _currentChapter = i + 1;
          _downloadProgress = i / sorted.length;
        });

        await _downloadService.downloadChapter(
          webtoonId: widget.webtoonId,
          webtoonTitle: widget.webtoonTitle,
          chapter: chapter,
          onProgress: (status) {
            if (mounted) setState(() => _downloadStatus = status);
          },
        );

        if (!mounted) return;
        setState(() => _downloadProgress = (i + 1) / sorted.length);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _selectedChapters.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sorted.length} chapitre(s) téléchargé(s) !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
                                : () =>
                                      setState(() => _selectedChapters.clear()),
                            child: const Text('Désélectionner'),
                          ),
                          TextButton.icon(
                            onPressed: _isDownloading
                                ? null
                                : () => setState(
                                    () => _selectedChapters.addAll(
                                      _results.map((c) => c.episodeNo),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      isSelected: _selectedChapters.contains(chapter.episodeNo),
                      isDisabled: _isDownloading,
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
          if (_isDownloading)
            DownloadOverlay(
              progress: _downloadProgress,
              currentChapter: _currentChapter,
              totalChapters: _totalChapters,
              status: _downloadStatus,
            ),
        ],
      ),
    );
  }
}
