class WebtoonResult {
  final String title;
  final String author;
  final String views;
  final String url;
  final String coverUrl;

  WebtoonResult({
    required this.title,
    required this.author,
    required this.views,
    required this.url,
    required this.coverUrl,
  });

  @override
  String toString() {
    return 'WebtoonResult(title: $title, author: $author)';
  }
}
