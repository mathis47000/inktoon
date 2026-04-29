import 'dart:io';

import 'package:flutter/material.dart';
import 'package:inktoon/screens/list_chapter.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final library = await _service.getLibrary();
      setState(() {
        _items = library.webtoons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
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
      return Center(
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
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucun téléchargement',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Téléchargez des chapitres depuis la recherche',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) => _WebtoonLibraryCard(
          item: _items[index],
          service: _service,
        ),
      ),
    );
  }
}

class _WebtoonLibraryCard extends StatelessWidget {
  final WebtoonLibraryItem item;
  final LibraryService service;

  const _WebtoonLibraryCard({required this.item, required this.service});

  void _openExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExportBottomSheet(item: item, service: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverFile = File(item.coverPath);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListChapter(webtoonId: item.webtoonId),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverFile.existsSync()
                    ? Image.file(
                        coverFile,
                        width: 80,
                        height: 100,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.book,
                          size: 40,
                          color: Colors.grey,
                        ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.book_outlined,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.chapters.length} chapitre(s)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.storage_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.formatSize(item.totalSize.toInt()),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: item.chapters
                          .take(5)
                          .map(
                            (ch) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'Ch. ${ch.chapterNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          )
                          .toList()
                        ..addAll(
                          item.chapters.length > 5
                              ? [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '+${item.chapters.length - 5}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ]
                              : [],
                        ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.save_alt),
                    color: Colors.blue[600],
                    iconSize: 20,
                    tooltip: 'Exporter pour liseuse',
                    onPressed: () => _openExportSheet(context),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportBottomSheet extends StatefulWidget {
  final WebtoonLibraryItem item;
  final LibraryService service;

  const _ExportBottomSheet({required this.item, required this.service});

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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.send_to_mobile, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exporter pour liseuse',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.item.title,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  activeColor: Colors.blue,
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
                      'Un seul fichier CBZ pour tous les chapitres',
                    ),
                    activeThumbColor: Colors.blue,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Les fichiers seront copiés dans le stockage externe de votre téléphone. Connectez ensuite un câble USB et copiez-les vers votre liseuse.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _selected.isEmpty || _loading ? null : _export,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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
