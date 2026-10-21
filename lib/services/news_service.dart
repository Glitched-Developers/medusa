import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/news_item.dart';

/// Новости с сайта НИУ «БелГУ».
///
/// Сайт работает на Bitrix, отдельного API нет — разбираем HTML:
/// список новостей и страницу новости. Кодировка — UTF-8.
class NewsService {
  NewsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String site = 'https://bsuedu.ru';
  static const String _listPath = '/bsu/news/index.php';

  /// Сколько новостей показываем в ленте.
  static const int pageSize = 20;

  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) Meduzka/1.0',
    'Accept': 'text/html',
  };

  /// Лента новостей. [page] начинается с единицы.
  Future<List<NewsItem>> fetchNews({int page = 1}) async {
    final uri = Uri.parse('$site$_listPath').replace(
      queryParameters: <String, String>{'PAGEN_1': '$page'},
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Сайт БелГУ ответил ${response.statusCode}');
    }
    final doc = html_parser.parse(_decode(response));
    return parseNewsList(doc);
  }

  /// Разбор ленты — отдельно от сети, чтобы проверять тестами.
  List<NewsItem> parseNewsList(Document doc) {
    final items = <NewsItem>[];
    for (final element in doc.querySelectorAll('.arhive-item')) {
      final link = element.querySelector('a.arhive_url');
      if (link == null) continue;

      final href = link.attributes['href'] ?? '';
      final title = _clean(link.text);
      if (title.isEmpty || href.isEmpty) continue;

      final url = _absolute(href);
      final dateText =
          element.querySelector('.archive_displ_date')?.text.trim() ?? '';
      final summaryBlocks =
          element.querySelectorAll('span.archive_detail_text');
      // Первый блок — заголовок, последний — анонс.
      final summary = summaryBlocks.isEmpty
          ? ''
          : _clean(summaryBlocks.last.text);
      final image = element.querySelector('img.img')?.attributes['src'];

      items.add(NewsItem(
        id: url,
        title: title,
        summary: summary == title ? '' : summary,
        url: url,
        imageUrl: image == null ? '' : _absolute(image),
        date: _parseDate(dateText),
      ));
    }
    return items;
  }

  /// Полный текст новости по ссылке из ленты.
  Future<NewsArticle> fetchArticle(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Не удалось открыть новость (${response.statusCode})');
    }
    return parseArticle(_decode(response), url);
  }

  /// Разбор страницы новости.
  NewsArticle parseArticle(String html, [String url = '']) {
    final doc = html_parser.parse(html);
    final title = _clean(doc.querySelector('h1')?.text ?? '');
    final body = doc.querySelector('.news_text_dlya_lentaev') ??
        doc.querySelector('.news-detail');
    final dateText =
        doc.querySelector('.post_top_info .date')?.text.trim() ?? '';

    final paragraphs = <String>[];
    final images = <String>[];
    if (body != null) {
      for (final element in body.querySelectorAll('p')) {
        final text = _clean(element.text);
        if (text.isNotEmpty) paragraphs.add(text);
      }
      // В старых новостях абзацев в <p> может не быть — берём текст целиком.
      if (paragraphs.isEmpty) {
        for (final line in body.text.split('\n')) {
          final text = _clean(line);
          if (text.isNotEmpty) paragraphs.add(text);
        }
      }
      for (final img in body.querySelectorAll('img')) {
        final src = img.attributes['src'];
        if (src == null || src.isEmpty) continue;
        final absolute = _absolute(src);
        if (!images.contains(absolute)) images.add(absolute);
      }
    }

    final author = _clean(doc.querySelector('.author small')?.text ?? '');

    return NewsArticle(
      title: title,
      paragraphs: paragraphs,
      date: _parseDate(dateText),
      author: author,
      images: images,
      url: url,
    );
  }

  String _decode(http.Response response) =>
      utf8.decode(response.bodyBytes, allowMalformed: true);

  String _absolute(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$site$normalized').toString();
  }

  static DateTime? _parseDate(String text) {
    final match = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(text);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  static String _clean(String text) => text
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void dispose() => _client.close();
}
