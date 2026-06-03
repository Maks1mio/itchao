import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tabs_controller.dart';
import '../hub_overlay_provider.dart';
import '../tab_content_view.dart';

/// Активная вкладка — изолирована от drawer; анимации паузятся при открытом меню.
class HubTabBody extends ConsumerWidget {
  const HubTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      tabsControllerProvider.select((async) => async.asData?.value.activeTab),
    );
    final drawerOpen = ref.watch(hubDrawerOpenProvider);

    if (active == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RepaintBoundary(
      child: TickerMode(
        enabled: !drawerOpen,
        child: TabContentView(
          key: ValueKey('${active.id}:${active.url}'),
          url: active.url,
        ),
      ),
    );
  }
}
