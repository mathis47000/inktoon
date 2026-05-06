import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inktoon/screens/home_webtoon_screen.dart';
import 'package:inktoon/screens/library_screen.dart';
import 'package:inktoon/screens/search_screen.dart';
import 'package:inktoon/screens/transfer_screen.dart';
import 'package:inktoon/services/download_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<void>? _startedSub;

  static const _screens = [HomeWebtoonScreen(), SearchScreen(), LibraryScreen(), TransferScreen()];

  @override
  void initState() {
    super.initState();
    _startedSub = DownloadManager.instance.started.listen((_) {
      if (mounted) setState(() => _currentIndex = 2);
    });
  }

  @override
  void dispose() {
    _startedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          const _DownloadBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Recherche',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Bibliothèque',
          ),
          NavigationDestination(
            icon: Icon(Icons.send_to_mobile_outlined),
            selectedIcon: Icon(Icons.send_to_mobile),
            label: 'Transfert',
          ),
        ],
      ),
    );
  }
}

class _DownloadBanner extends StatefulWidget {
  const _DownloadBanner();

  @override
  State<_DownloadBanner> createState() => _DownloadBannerState();
}

class _DownloadBannerState extends State<_DownloadBanner> {
  DownloadProgress? _progress;
  StreamSubscription<DownloadProgress>? _sub;

  @override
  void initState() {
    super.initState();
    _progress = DownloadManager.instance.lastProgress;
    _sub = DownloadManager.instance.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final visible = p != null && !p.isDone && DownloadManager.instance.isRunning;
    if (!visible) return const SizedBox.shrink();

    final chapterFraction =
        p.total > 0 ? (p.current + (p.totalPages > 0 ? p.currentPage / p.totalPages : 0)) / p.total : 0.0;

    final pageText = p.totalPages > 0
        ? ' · p. ${p.currentPage}/${p.totalPages}'
        : '';

    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ch. ${p.current + 1}/${p.total}$pageText',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  p.status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => DownloadManager.instance.cancel(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: chapterFraction.clamp(0.0, 1.0),
            minHeight: 2,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}
