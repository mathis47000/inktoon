import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:inktoon/screens/list_chapter.dart';
import 'package:inktoon/services/download_manager.dart';
import 'package:inktoon/services/export_service.dart';
import 'package:inktoon/services/library_service.dart';
import 'package:inktoon/src/rust/api/models.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _service = LibraryService();

  List<WebtoonLibraryItem> _items = [];
  bool _isLoading = true;
  String? _error;

  DownloadProgress? _dlProgress;
  StreamSubscription<DownloadProgress>? _dlSub;

  @override
  void initState() {
    super.initState();
    _load();
    _dlProgress = DownloadManager.instance.lastProgress;
    _dlSub = DownloadManager.instance.progress.listen((p) {
      if (mounted) setState(() => _dlProgress = p);
      if (p.isDone && p.error == null && mounted) _load();
    });
  }

  @override
  void dispose() {
    _dlSub?.cancel();
    super.dispose();
  }

  bool get _isDownloading {
    final p = _dlProgress;
    return DownloadManager.instance.isRunning || (p != null && !p.isDone);
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final library = await _service.getLibrary();
      if (mounted) setState(() { _items = library.webtoons; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: scheme.error),
            const SizedBox(height: 16),
            Text('Erreur: $_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    if (_items.isEmpty && !_isDownloading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined,
                size: 80, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Aucun téléchargement',
                style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Téléchargez des chapitres depuis la recherche',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _items.length + (_isDownloading ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isDownloading && index == 0) {
            return _DownloadProgressCard(
              progress: _dlProgress,
              title: DownloadManager.instance.currentWebtoonTitle ?? 'Téléchargement',
              onCancel: DownloadManager.instance.cancel,
            );
          }
          final i = _isDownloading ? index - 1 : index;
          return _WebtoonLibraryCard(
            item: _items[i],
            service: _service,
            onRefresh: _load,
          );
        },
      ),
    );
  }
}

class _DownloadProgressCard extends StatelessWidget {
  final DownloadProgress? progress;
  final String title;
  final VoidCallback onCancel;

  const _DownloadProgressCard({
    required this.progress,
    required this.title,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = progress;

    final int current = p?.current ?? 0;
    final int total = p?.total ?? 0;
    final int currentPage = p?.currentPage ?? 0;
    final int totalPages = p?.totalPages ?? 0;
    final String status = p?.status ?? '';

    final double fraction = total > 0
        ? (current + (totalPages > 0 ? currentPage / totalPages : 0)) / total
        : 0.0;

    final String chapterText = total > 0
        ? 'Chapitre ${current + 1} / $total'
        : 'Démarrage…';

    final String pageText = totalPages > 0
        ? 'Page $currentPage / $totalPages'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chapterText.isNotEmpty)
                        Text(
                          chapterText,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                if (pageText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      pageText,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: scheme.onPrimaryContainer),
                  tooltip: 'Annuler',
                  onPressed: onCancel,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction > 0 ? fraction.clamp(0.0, 1.0) : null,
                minHeight: 4,
                backgroundColor:
                    scheme.primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _WebtoonLibraryCard extends StatelessWidget {
  final WebtoonLibraryItem item;
  final LibraryService service;
  final VoidCallback onRefresh;

  const _WebtoonLibraryCard({
    required this.item,
    required this.service,
    required this.onRefresh,
  });

  void _openExportSheet(BuildContext context) async {
    final refreshNeeded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ExportBottomSheet(item: item, service: service, onRefresh: onRefresh),
    );
    if (refreshNeeded == true) onRefresh();
  }

  Future<void> _confirmDeleteSeries(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la série ?'),
        content: Text(
            'Tous les chapitres de « ${item.title} » seront supprimés définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await service.deleteWebtoon(item.webtoonId);
    onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverFile = File(item.coverPath);
    final chapters = item.chapters;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListChapter(
                webtoonId: item.webtoonId, webtoonTitle: item.title),
          ),
        ),
        onLongPress: () => _confirmDeleteSeries(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverFile.existsSync()
                    ? Image.file(coverFile,
                        width: 72, height: 96, fit: BoxFit.cover)
                    : Container(
                        width: 72,
                        height: 96,
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
                    Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.book_outlined,
                            size: 14, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${chapters.length} chapitre${chapters.length > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 13, color: scheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.storage_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          service.formatSize(item.totalSize.toInt()),
                          style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final ch in chapters.take(5))
                          _ChapterChip(
                              label: 'Ch. ${ch.chapterNumber}',
                              scheme: scheme),
                        if (chapters.length > 5)
                          _ChapterChip(
                              label: '+${chapters.length - 5}',
                              scheme: scheme,
                              muted: true),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.save_alt),
                    iconSize: 20,
                    tooltip: 'Exporter pour liseuse',
                    onPressed: () => _openExportSheet(context),
                  ),
                  Icon(Icons.chevron_right,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterChip extends StatelessWidget {
  final String label;
  final ColorScheme scheme;
  final bool muted;

  const _ChapterChip({
    required this.label,
    required this.scheme,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: muted
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: muted ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ExportBottomSheet extends StatefulWidget {
  final WebtoonLibraryItem item;
  final LibraryService service;
  final VoidCallback onRefresh;

  const _ExportBottomSheet({
    required this.item,
    required this.service,
    required this.onRefresh,
  });

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  final _exportService = ExportService();
  late Set<int> _selected;
  bool _merge = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = {for (final c in widget.item.chapters) c.chapterNumber};
  }

  int get _selectedSize =>
      _exportService.selectedSize(widget.item, _selected.toList());

  Future<void> _deleteChapter(int chapterNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le chapitre ?'),
        content: Text('Le chapitre $chapterNumber sera supprimé définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.service.deleteChapter(widget.item.webtoonId, chapterNumber);
    setState(() => _selected.remove(chapterNumber));
    widget.onRefresh();
    // Close sheet if no chapters remain.
    if (widget.item.chapters.length == 1 && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _export() async {
    final sorted = _selected.toList()..sort();
    setState(() => _loading = true);
    try {
      final result = await _exportService.exportToDevice(
        webtoon: widget.item,
        chapterNumbers: sorted,
        merge: _merge && sorted.length > 1,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await showDialog(
        context: context,
        builder: (_) => _ExportResultDialog(result: result),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == widget.item.chapters.length;
    final multipleSelected = _selected.length > 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.save_alt,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exporter pour liseuse',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.item.title,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selected.length} chapitre(s) sélectionné(s)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _selected.clear();
                    } else {
                      _selected = {
                        for (final c in widget.item.chapters) c.chapterNumber,
                      };
                    }
                  }),
                  child: Text(allSelected ? 'Désélectionner' : 'Tout'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: widget.item.chapters.length,
              itemBuilder: (_, i) {
                final ch = widget.item.chapters[i];
                final isSelected = _selected.contains(ch.chapterNumber);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(ch.chapterNumber);
                    } else {
                      _selected.remove(ch.chapterNumber);
                    }
                  }),
                  title: Text('Chapitre ${ch.chapterNumber}'),
                  subtitle: Text(
                    '${ch.pageCount} pages · ${widget.service.formatSize(ch.fileSize.toInt())}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Supprimer ce chapitre',
                    onPressed: () => _deleteChapter(ch.chapterNumber),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 8),
                if (multipleSelected)
                  SwitchListTile(
                    value: _merge,
                    onChanged: (v) => setState(() => _merge = v),
                    title: const Text('Volume fusionné'),
                    subtitle: const Text(
                        'Un seul fichier CBZ pour tous les chapitres'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Les fichiers seront copiés dans le stockage externe de votre téléphone. Connectez ensuite un câble USB et copiez-les vers votre liseuse.',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _selected.isEmpty || _loading ? null : _export,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: _loading
                        ? const Text('Préparation...')
                        : Text(
                            _merge && multipleSelected
                                ? 'Exporter en volume · ${widget.service.formatSize(_selectedSize)}'
                                : 'Exporter ${_selected.length} fichier(s) · ${widget.service.formatSize(_selectedSize)}',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportResultDialog extends StatelessWidget {
  final ExportResult result;

  const _ExportResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Exporté !'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.fileCount} fichier(s) copié(s) dans :'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                result.directory,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Transfert par câble USB :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '1. Branchez votre câble USB au PC\n'
              '2. Sur le téléphone : sélectionnez "Transfert de fichiers"\n'
              '3. Sur le PC : Stockage interne → Téléchargements → Inktoon\n'
              '4. Copiez les fichiers .cbz vers votre liseuse',
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
