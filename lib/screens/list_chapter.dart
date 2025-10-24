import 'package:flutter/material.dart';
import 'package:inktoon/src/rust/api/simple.dart';

class ListChapter extends StatefulWidget {
  final String webtoonId;
  const ListChapter({super.key, required this.webtoonId});

  @override
  State<ListChapter> createState() => _ListChapterState();
}

class _ListChapterState extends State<ListChapter> {
  List<ApiEpisodeItem> _results = [];
  bool _isLoading = true;
  String? _error;

  // Set pour stocker les chapitres sélectionnés
  final Set<int> _selectedChapters = {};

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    try {
      final rustResults = await getWebtoonEpisodes(titleNo: widget.webtoonId);
      final results = rustResults.toList();

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

  // Séléctionner ou désélectionner tous les chapitres
  void _toggleSelectAll() {
    setState(() {
      if (_selectedChapters.length == _results.length) {
        _selectedChapters.clear();
      } else {
        _selectedChapters.addAll(_results.map((chapter) => chapter.episodeNo));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // État de chargement
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // État d'erreur
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
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    // État vide
    if (_results.isEmpty) {
      return const Center(child: Text('Aucun chapitre trouvé'));
    }

    // Grille des chapitres
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche Webtoons'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedChapters.length} chapitre(s) sélectionné(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _toggleSelectAll();
                  },
                  child: Text(
                    _selectedChapters.length == _results.length
                        ? 'Désélectionner tout'
                        : 'Sélectionner tout',
                  ),
                ),
              ],
            ),
          ),
          // Grille
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7, // Ratio largeur/hauteur
              ),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final chapter = _results[index];
                final isSelected = _selectedChapters.contains(
                  chapter.episodeNo,
                );

                return _buildChapterCell(chapter, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCell(ApiEpisodeItem chapter, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(chapter.episodeNo),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
        ),
        child: Stack(
          children: [
            // Contenu du chapitre
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                    child: Image.network(
                      chapter.thumbnail,
                      width: 80,
                      height: 100,
                      fit: BoxFit.cover,
                      headers: const {
                        'Referer': 'https://www.webtoons.com/',
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 40,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 80,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Informations
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      chapter.episodeTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            // Badge de sélection
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
