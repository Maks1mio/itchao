import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../itch_url.dart';
import '../../tabs_controller.dart';
import '../tab_chrome_provider.dart';

/// Обёртка вкладки. Отступ сверху только если контент рисуется под прозрачным AppBar.
class ItchTabBody extends ConsumerWidget {
  const ItchTabBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUrl = ref.watch(
      tabsControllerProvider.select((async) => async.asData?.value.activeTab?.url),
    );
    final isBrowser = activeUrl != null &&
        (ItchUrl.parse(activeUrl).isExternal ||
            {
              'browser',
              'featured',
              'dashboard',
              'upload',
            }.contains(ItchUrl.parse(activeUrl).page));
    final extendBehind = ref.watch(
      tabChromeProvider.select(
        (c) => c.appBarTitle == null && !c.showTitle && !isBrowser,
      ),
    );
    if (!extendBehind) {
      return child;
    }
    final topInset = MediaQuery.paddingOf(context).top + TabChromeState.appBarHeight;
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: child,
    );
  }
}
