import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/news_controller.dart';
import '../../models/news_item.dart';
import '../widgets/blur_in_text.dart';

/// Полный текст новости: заголовок, дата, фотографии и абзацы.
class NewsArticleScreen extends StatefulWidget {
  const NewsArticleScreen({super.key, required this.item});

  final NewsItem item;

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen> {
  late Future<NewsArticle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<NewsArticle> _load() {
    final controller = context.read<NewsController>();
    return controller.openArticle(widget.item);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.item.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Новость'),
        actions: [
          IconButton(
            tooltip: 'Открыть на сайте',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: FutureBuilder<NewsArticle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 36,
                      color: scheme.outline,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Не удалось открыть новость. Проверьте интернет.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                    TextButton(
                      onPressed: _openInBrowser,
                      child: const Text('Открыть на сайте'),
                    ),
                  ],
                ),
              ),
            );
          }

          final article = snapshot.data!;
          final title =
              article.title.isEmpty ? widget.item.title : article.title;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Заголовок «фокусируется» по буквам, абзацы — друг за
              // другом: к чтению подключаешься постепенно.
              BlurInText(
                title,
                by: BlurInBy.character,
                stagger: const Duration(milliseconds: 16),
                duration: const Duration(milliseconds: 460),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              BlurInText(
                _dateText(article.date ?? widget.item.date),
                by: BlurInBy.line,
                delay: const Duration(milliseconds: 180),
                duration: const Duration(milliseconds: 320),
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
              if (article.images.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final image in article.images.take(3)) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    builder:
                        (context, value, child) =>
                            Opacity(opacity: value, child: child),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 4),
              for (var i = 0; i < article.paragraphs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BlurInText(
                    article.paragraphs[i],
                    by: BlurInBy.line,
                    delay: Duration(milliseconds: 220 + i * 70),
                    duration: const Duration(milliseconds: 520),
                    style: const TextStyle(fontSize: 15, height: 1.55),
                  ),
                ),
              if (article.author.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  article.author,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: scheme.outline,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.link),
                label: const Text('Читать на сайте БелГУ'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _dateText(DateTime? date) {
  if (date == null) return 'Новости НИУ «БелГУ»';
  const months = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
