import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/news_controller.dart';
import '../../models/news_item.dart';
import '../transitions/fade_up_page_route.dart';
import '../widgets/progressive_blur.dart';
import 'news_article_screen.dart';

/// Лента новостей НИУ «БелГУ» с сайта университета.
class NewsScreenView extends StatelessWidget {
  const NewsScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NewsController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Новости БелГУ'), centerTitle: true),
      body: _body(context, controller, scheme),
    );
  }

  Widget _body(
    BuildContext context,
    NewsController controller,
    ColorScheme scheme,
  ) {
    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 36, color: scheme.outline),
              const SizedBox(height: 12),
              Text(
                controller.error ?? 'Новостей пока нет',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (controller.isOffline) _OfflineStrip(cachedAt: controller.cachedAt),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: controller.items.length,
                  itemBuilder: (context, index) {
                    final item = controller.items[index];
                    return _NewsCard(
                      item: item,
                      onTap:
                          () => Navigator.of(context).push(
                            FadeUpPageRoute(
                              page: NewsArticleScreen(item: item),
                            ),
                          ),
                    );
                  },
                ),
              ),
              // Лёгкое размытие у кромок: карточки в середине остаются
              // в фокусе, а лента не «обрывается» резкой линией.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ProgressiveBlur(
                  position: ProgressiveBlurPosition.top,
                  height: 36,
                  sigma: 5,
                ),
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ProgressiveBlur(height: 88, sigma: 6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip({this.cachedAt});

  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final at = cachedAt;
    String when() {
      if (at == null) return '';
      String two(int v) => v.toString().padLeft(2, '0');
      return ' от ${two(at.day)}.${two(at.month)}, ${two(at.hour)}:${two(at.minute)}';
    }

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: scheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Нет интернета — новости сохранены${when()}',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          color: scheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.newspaper_outlined,
                            color: scheme.outline,
                          ),
                        ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.date != null)
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 13, color: scheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(item.date!),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
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
