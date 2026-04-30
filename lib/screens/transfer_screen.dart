import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _ExportedFile {
  final String id;
  final String name;
  final String subFolder;
  final String uri;
  final int size;
  final int dateMillis;

  const _ExportedFile({
    required this.id,
    required this.name,
    required this.subFolder,
    required this.uri,
    required this.size,
    required this.dateMillis,
  });

  factory _ExportedFile.fromMap(Map<Object?, Object?> map) => _ExportedFile(
        id: map['id'] as String,
        name: map['name'] as String,
        subFolder: map['subFolder'] as String,
        uri: map['uri'] as String,
        size: (map['size'] as num).toInt(),
        dateMillis: (map['date'] as num).toInt() * 1000,
      );
}

class _TransferScreenState extends State<TransferScreen> {
  static const _channel = MethodChannel('inktoon/downloads');

  List<_ExportedFile> _files = [];
  List<Map<String, Object?>> _usbDevices = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _transferring = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await Future.wait([_loadFiles(), _loadUsbDevices()]);
    setState(() => _loading = false);
  }

  Future<void> _loadFiles() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('listExportedFiles');
      final files = (raw ?? [])
          .whereType<Map<Object?, Object?>>()
          .map(_ExportedFile.fromMap)
          .toList();
      if (mounted) setState(() => _files = files);
    } catch (_) {
      if (mounted) setState(() => _files = []);
    }
  }

  Future<void> _loadUsbDevices() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('getConnectedUsbDevices');
      final devices = (raw ?? [])
          .whereType<Map<Object?, Object?>>()
          .map((m) => {
                'name': m['name'],
                'vendorId': m['vendorId'],
                'productId': m['productId'],
              })
          .toList();
      if (mounted) setState(() => _usbDevices = devices);
    } catch (_) {
      if (mounted) setState(() => _usbDevices = []);
    }
  }

  Future<void> _transfer() async {
    final selected = _files.where((f) => _selected.contains(f.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _transferring = true);
    try {
      final count = await _channel.invokeMethod<int>('transferToEReader', {
        'fileUris': selected.map((f) => f.uri).toList(),
        'fileNames': selected.map((f) => f.name).toList(),
      });
      if (!mounted) return;
      setState(() => _selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count fichier(s) transféré(s) avec succès')),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code != 'CANCELLED') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Map<String, List<_ExportedFile>> get _grouped {
    final map = <String, List<_ExportedFile>>{};
    for (final f in _files) {
      (map[f.subFolder] ??= []).add(f);
    }
    return map;
  }

  void _toggleAll(List<_ExportedFile> files) {
    final ids = files.map((f) => f.id).toSet();
    final allSelected = ids.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfert'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _UsbBanner(devices: _usbDevices),
                Expanded(
                  child: _files.isEmpty
                      ? const _EmptyState()
                      : ListView(
                          children: [
                            for (final entry in grouped.entries) ...[
                              _GroupHeader(
                                title: entry.key.isEmpty
                                    ? 'Inktoon'
                                    : entry.key,
                                files: entry.value,
                                selected: _selected,
                                onToggleAll: () => _toggleAll(entry.value),
                              ),
                              for (final file in entry.value)
                                _FileRow(
                                  file: file,
                                  selected: _selected.contains(file.id),
                                  formatSize: _formatSize,
                                  onToggle: () => setState(() {
                                    if (_selected.contains(file.id)) {
                                      _selected.remove(file.id);
                                    } else {
                                      _selected.add(file.id);
                                    }
                                  }),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: hasSelection
          ? FloatingActionButton.extended(
              onPressed: _transferring ? null : _transfer,
              icon: _transferring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_to_mobile),
              label: Text(
                _transferring
                    ? 'Transfert…'
                    : 'Transférer (${_selected.length})',
              ),
            )
          : null,
    );
  }
}

class _UsbBanner extends StatelessWidget {
  final List<Map<String, Object?>> devices;
  const _UsbBanner({required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Icons.usb_off,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Aucune liseuse détectée',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.usb,
              size: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              devices.length == 1
                  ? '${devices.first['name']} connecté'
                  : '${devices.length} appareils USB connectés',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final List<_ExportedFile> files;
  final Set<String> selected;
  final VoidCallback onToggleAll;

  const _GroupHeader({
    required this.title,
    required this.files,
    required this.selected,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final ids = files.map((f) => f.id).toSet();
    final allSelected = ids.every(selected.contains);
    return InkWell(
      onTap: onToggleAll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Checkbox(
              value: allSelected,
              tristate: true,
              onChanged: (_) => onToggleAll(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '${files.length} fichier${files.length > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final _ExportedFile file;
  final bool selected;
  final String Function(int) formatSize;
  final VoidCallback onToggle;

  const _FileRow({
    required this.file,
    required this.selected,
    required this.formatSize,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: (_) => onToggle(),
      title: Text(
        file.name,
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        formatSize(file.size),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      secondary: const Icon(Icons.picture_as_pdf_outlined),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Aucun fichier CBZ exporté',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exportez des chapitres depuis la bibliothèque\npour les voir apparaître ici.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
