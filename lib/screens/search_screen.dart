import 'package:flutter/material.dart';
import 'package:inktoon/screens/list_chapter.dart';
import 'package:inktoon/services/webtoon_service.dart';
import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/widgets/webtoon_card.dart';

// ── Site config ────────────────────────────────────────────────────────────

class _SiteConfig {
  final String id;
  final String name;
  final String host;
  final Color brandColor;
  final Color onBrandColor;
  final IconData icon;
  final bool available;

  const _SiteConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.brandColor,
    required this.onBrandColor,
    required this.icon,
    this.available = false,
  });
}

const _kSites = [
  _SiteConfig(
    id: 'webtoon',
    name: 'LINE Webtoon',
    host: 'webtoons.com',
    brandColor: Color(0xFF00D564),
    onBrandColor: Color(0xFF001A0C),
    icon: Icons.auto_stories_outlined,
    available: true,
  ),
  _SiteConfig(
    id: 'naver',
    name: 'Naver Webtoon',
    host: 'webtoon.naver.com',
    brandColor: Color(0xFF03C75A),
    onBrandColor: Colors.white,
    icon: Icons.book_outlined,
  ),
  _SiteConfig(
    id: 'tapas',
    name: 'Tapas',
    host: 'tapas.io',
    brandColor: Color(0xFFFF6B35),
    onBrandColor: Colors.white,
    icon: Icons.collections_bookmark_outlined,
  ),
  _SiteConfig(
    id: 'mangadex',
    name: 'MangaDex',
    host: 'mangadex.org',
    brandColor: Color(0xFFFF6640),
    onBrandColor: Colors.white,
    icon: Icons.menu_book_outlined,
  ),
];

// ── Language config ────────────────────────────────────────────────────────

const _kLangFlag = {
  'en': '🇬🇧',
  'fr': '🇫🇷',
  'de': '🇩🇪',
  'es': '🇪🇸',
  'id': '🇮🇩',
  'th': '🇹🇭',
  'zh-hant': '🇹🇼',
};

const _kLangName = {
  'en': 'English',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'id': 'Indonesia',
  'th': 'ภาษาไทย',
  'zh-hant': '中文 (繁體)',
};

// ── Screen ─────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _service = WebtoonService();

  List<WebtoonResult> _results = [];
  bool _isLoading = false;
  String? _error;
  String _lang = 'en';
  _SiteConfig _site = _kSites.first;

  @override
  void initState() {
    super.initState();
    _performSearch('solo leveling');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.isEmpty) {
      setState(() { _results = []; _error = null; });
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await _service.search(keyword, _lang);
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _showSitePicker() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SitePickerSheet(
        selected: _site,
        onSelect: (site) {
          Navigator.pop(context);
          setState(() => _site = site);
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flag = _kLangFlag[_lang] ?? '🌐';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _lang,
            tooltip: 'Langue',
            onSelected: (lang) {
              setState(() => _lang = lang);
              _performSearch(_searchController.text);
            },
            itemBuilder: (_) => _kLangFlag.entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          Text(e.value,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Text(_kLangName[e.key] ?? e.key),
                        ],
                      ),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 4),
                  Text(
                    _lang.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Site selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: InkWell(
              onTap: _showSitePicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _SiteLogo(site: _site, size: 30),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _site.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _site.host,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.expand_more,
                        size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un webtoon...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onSubmitted: _performSearch,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          if (_error != null && !_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_outlined,
                        size: 56, color: scheme.error),
                    const SizedBox(height: 12),
                    const Text('Erreur de chargement'),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () =>
                          _performSearch(_searchController.text),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isLoading && _error == null)
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun résultat',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return WebtoonCard(
                          webtoon: result,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListChapter(
                                webtoonId: result.titleNo,
                                webtoonTitle: result.title,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Site logo ──────────────────────────────────────────────────────────────

class _SiteLogo extends StatelessWidget {
  final _SiteConfig site;
  final double size;

  const _SiteLogo({required this.site, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: site.brandColor,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(site.icon, color: site.onBrandColor, size: size * 0.58),
    );
  }
}

// ── Site picker bottom sheet ───────────────────────────────────────────────

class _SitePickerSheet extends StatelessWidget {
  final _SiteConfig selected;
  final void Function(_SiteConfig) onSelect;

  const _SitePickerSheet({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Choisir un site',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Sélectionnez la plateforme sur laquelle rechercher',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              itemCount: _kSites.length,
              itemBuilder: (context, i) {
                final site = _kSites[i];
                return _SiteCard(
                  site: site,
                  isSelected: site.id == selected.id,
                  onTap: site.available ? () => onSelect(site) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final _SiteConfig site;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SiteCard({
    required this.site,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: site.available ? 1.0 : 0.55,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        elevation: isSelected ? 2 : 0,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SiteLogo(site: site, size: 38),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: site.available
                            ? Colors.green.withValues(alpha: 0.12)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        site.available ? 'Dispo' : 'Bientôt',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: site.available
                              ? Colors.green[700]
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  site.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  site.host,
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
