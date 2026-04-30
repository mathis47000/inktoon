import 'package:flutter/material.dart';
import 'package:inktoon/src/rust/api/models.dart';
import 'package:inktoon/widgets/webtoon_image.dart';

class ChapterTile extends StatelessWidget {
  final ApiEpisodeItem chapter;
  final bool isSelected;
  final bool isDisabled;
  final bool isDownloaded;
  final VoidCallback onTap;

  const ChapterTile({
    super.key,
    required this.chapter,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
    this.isDownloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = isDisabled || isDownloaded;
    return GestureDetector(
      onTap: blocked ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDownloaded
                  ? Colors.grey[400]!
                  : isSelected
                      ? Colors.blue
                      : Colors.grey[300]!,
              width: isSelected ? 3 : 1,
            ),
            color: isDownloaded
                ? Colors.grey[100]
                : isSelected
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.white,
          ),
          child: Stack(
            children: [
              ColorFiltered(
                colorFilter: isDownloaded
                    ? const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ])
                    : const ColorFilter.matrix([
                        1, 0, 0, 0, 0,
                        0, 1, 0, 0, 0,
                        0, 0, 1, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7),
                          topRight: Radius.circular(7),
                        ),
                        child: WebtoonImage(url: chapter.thumbnail),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Ch. ${chapter.episodeNo}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDownloaded
                                    ? Colors.grey[500]
                                    : isSelected
                                        ? Colors.blue
                                        : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chapter.episodeTitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDownloaded)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.download_done,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                )
              else if (isSelected)
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
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
