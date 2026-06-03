import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../collections/collections_controller.dart';
import '../../tabs_controller.dart';
import '../tab_chrome_provider.dart';
import 'itch_browser_page.dart';
import '../widgets/collection_stripe.dart';
import '../widgets/tab_chrome_toolbars.dart';

class CollectionsPage extends ConsumerStatefulWidget {
  const CollectionsPage({super.key});

  @override
  ConsumerState<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends ConsumerState<CollectionsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindChrome());
  }

  @override
  void dispose() {
    final chrome = ref.read(tabChromeProvider.notifier);
    _searchController.dispose();
    super.dispose();
    Future.microtask(() => chrome.clearPageMenu());
  }

  void _bindChrome() {
    if (!mounted) {
      return;
    }
    final mode = ref.read(collectionsControllerProvider).valueOrNull?.mode;
    if (mode == CollectionsDisplayMode.webFallback) {
      ref.read(tabChromeProvider.notifier).clearPageMenu(showTitle: false);
      return;
    }
    ref.read(tabChromeProvider.notifier).setAppBarContent(
      title: CollectionsListAppBarTitle(searchController: _searchController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsControllerProvider);
    final controller = ref.read(collectionsControllerProvider.notifier);

    ref.listen(collectionsControllerProvider.select((s) => s.valueOrNull?.mode), (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _bindChrome());
      }
    });

    return collections.when(
      data: (state) {
        if (state.mode == CollectionsDisplayMode.webFallback) {
          return Column(
            children: [
              if (state.hint != null)
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(state.hint!, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              const Expanded(
                child: ItchBrowserPage(
                  initialUrl: 'https://itch.io/my-collections',
                  belowHubChrome: true,
                ),
              ),
            ],
          );
        }
        if (state.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'У вас пока нет коллекций на itch.io',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings),
                    label: const Text('Настройки'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            children: [
              if (state.limitedAccess && state.hint != null)
                Material(
                  color: ItchColors.item,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(state.hint!, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () => context.push('/settings'),
                              child: const Text('Добавить API key'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                ref.read(tabsControllerProvider.notifier).navigateActiveTab(
                                  'https://itch.io/my-collections',
                                  label: 'Коллекции на itch.io',
                                );
                              },
                              child: const Text('На сайте'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.loadingPreviews && state.pendingPreviewCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Загружаем обложки… (${state.pendingPreviewCount})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              for (final item in state.items) CollectionStripe(item: item),
            ],
          ),
        );
      },
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: $error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.refresh,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
