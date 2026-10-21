/// Новость с сайта НИУ «БелГУ».
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    this.imageUrl = '',
    this.date,
  });

  /// Стабильный id — ссылка на новость на сайте.
  final String id;

  final String title;
  final String summary;

  /// Полная ссылка на новость.
  final String url;

  /// Картинка анонса (может не быть).
  final String imageUrl;

  final DateTime? date;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'summary': summary,
        'url': url,
        'imageUrl': imageUrl,
        'date': date?.toIso8601String(),
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
        url: '${json['url'] ?? ''}',
        imageUrl: '${json['imageUrl'] ?? ''}',
        date: DateTime.tryParse('${json['date'] ?? ''}'),
      );
}

/// Полный текст новости: заголовок, дата, абзацы и фотографии.
class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.paragraphs,
    this.date,
    this.author = '',
    this.images = const <String>[],
    this.url = '',
  });

  final String title;
  final List<String> paragraphs;
  final DateTime? date;
  final String author;
  final List<String> images;
  final String url;
}
