// Разбор новостей БелГУ: лента, страница новости и кеш для офлайна.
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:medusa/models/news_item.dart';
import 'package:medusa/services/news_service.dart';
import 'package:medusa/services/news_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _listHtml = '''
<html><body>
  <div class="arhive-item">
    <div class="arhive-item__date"><span class="archive_displ_date">20.10.2026</span></div>
    <a class="arhive_url" href="/bsu/news/news.php?ID=996581&amp;IBLOCK_ID=123">
      <span class="archive_detail_text">Студент завоевал золото на соревнованиях</span>
    </a>
    <img class="img" src="/upload/news/photo one.jpg" />
    <span class="archive_detail_text">
      Второкурсник успешно представил вуз на международной арене.
    </span>
  </div>
  <div class="arhive-item">
    <span class="archive_displ_date">19.10.2026</span>
    <a class="arhive_url" href="https://bsuedu.ru/bsu/news/news.php?ID=996577">
      <span class="archive_detail_text">В университете открылась выставка</span>
    </a>
    <span class="archive_detail_text">Экспозиция работает до конца месяца.</span>
  </div>
  <div class="arhive-item"><span>Без ссылки</span></div>
</body></html>
''';

const String _articleHtml = '''
<html><body>
  <div class="post_top_info"><span class="date">20.10.2026 12:30</span></div>
  <h1>Студент завоевал золото на соревнованиях</h1>
  <div class="news_text_dlya_lentaev">
    <p><b>Второкурсник успешно представил вуз.</b></p>
    <div><img class="detail_picture" src="/upload/news/photo.jpg" /></div>
    <p>Он прошёл подготовку в центре ушу и одержал победу.</p>
    <p>&nbsp;</p>
  </div>
  <div class="author"><small>Информация предоставлена пресс-службой</small></div>
</body></html>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Лента новостей', () {
    test('разбирает карточки, даты и ссылки', () {
      final service = NewsService();
      final items =
          service.parseNewsList(html_parser.parse(_listHtml));

      expect(items, hasLength(2));
      final first = items.first;
      expect(first.title, 'Студент завоевал золото на соревнованиях');
      expect(first.summary,
          'Второкурсник успешно представил вуз на международной арене.');
      expect(first.date, DateTime(2026, 10, 20));
      expect(first.url,
          'https://bsuedu.ru/bsu/news/news.php?ID=996581&IBLOCK_ID=123');
      // Пробел в пути к картинке кодируется, чтобы Image.network не падал.
      expect(first.imageUrl, contains('photo%20one.jpg'));
      expect(first.imageUrl, startsWith('https://bsuedu.ru/'));

      expect(items[1].title, 'В университете открылась выставка');
      expect(items[1].imageUrl, isEmpty);
      service.dispose();
    });

    test('страница новости: заголовок, дата, абзацы и фото', () {
      final service = NewsService();
      final article = service.parseArticle(
        _articleHtml,
        'https://bsuedu.ru/bsu/news/news.php?ID=996581',
      );

      expect(article.title, 'Студент завоевал золото на соревнованиях');
      expect(article.date, DateTime(2026, 10, 20));
      expect(article.paragraphs, hasLength(2));
      expect(article.paragraphs.first, contains('Второкурсник'));
      expect(article.images, hasLength(1));
      expect(article.images.first, startsWith('https://bsuedu.ru/'));
      expect(article.author, contains('пресс-службой'));
      service.dispose();
    });
  });

  group('Кеш новостей', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await NewsStorageService().getPrefs();
      await prefs.clear();
    });

    test('лента сохраняется и читается после перезапуска', () async {
      final storage = NewsStorageService();
      final item = NewsItem(
        id: 'https://bsuedu.ru/news/1',
        title: 'Заголовок',
        summary: 'Анонс',
        url: 'https://bsuedu.ru/news/1',
        imageUrl: 'https://bsuedu.ru/1.jpg',
        date: DateTime(2026, 10, 20),
      );

      await storage.saveItems(<NewsItem>[item]);
      await storage.saveCachedAt(DateTime(2026, 10, 20, 20, 28));

      final loaded = await NewsStorageService().loadItems();
      expect(loaded, hasLength(1));
      expect(loaded.first.title, 'Заголовок');
      expect(loaded.first.summary, 'Анонс');
      expect(loaded.first.date, DateTime(2026, 10, 20));

      final cachedAt = await NewsStorageService().loadCachedAt();
      expect(cachedAt, DateTime(2026, 10, 20, 20, 28));
    });
  });
}
