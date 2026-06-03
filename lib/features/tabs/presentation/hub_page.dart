import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/itch_colors.dart';
import '../itch_url.dart';
import '../tabs_controller.dart';
import 'hub_overlay_provider.dart';
import 'tab_back_handler_provider.dart';
import 'tab_chrome_provider.dart';
import 'widgets/hub_app_bar.dart';
import 'widgets/hub_drawer.dart';
import 'widgets/hub_tab_body.dart';

class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

class _HubPageState extends ConsumerState<HubPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(
      tabsControllerProvider.select(
        (async) => async.isLoading
            ? 0
            : async.hasError
                ? 1
                : 2,
      ),
    );

    if (boot == 0) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (boot == 1) {
      final error = ref.read(tabsControllerProvider).error;
      return Scaffold(
        body: Center(child: Text('Ошибка вкладок: $error')),
      );
    }
    return _buildHub(context);
  }

  Widget _buildHub(BuildContext context) {
    final tabs = ref.read(tabsControllerProvider.notifier);
    final chrome = ref.watch(tabChromeProvider);
    final isBrowserTab = ref.watch(
      tabsControllerProvider.select((async) {
        final url = async.asData?.value.activeTab?.url;
        if (url == null) {
          return false;
        }
        final parsed = ItchUrl.parse(url);
        return parsed.isExternal ||
            parsed.page == 'browser' ||
            parsed.page == 'featured' ||
            parsed.page == 'dashboard' ||
            parsed.page == 'upload';
      }),
    );
    final extendBehind = chrome.appBarTitle == null && !chrome.showTitle && !isBrowserTab;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _onSystemBack(tabs);
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBodyBehindAppBar: extendBehind,
        backgroundColor: ItchColors.background,
        drawerEnableOpenDragGesture: true,
        drawer: const HubDrawer(),
        onDrawerChanged: (isOpen) {
          ref.read(hubDrawerOpenProvider.notifier).state = isOpen;
        },
        resizeToAvoidBottomInset: true,
        appBar: HubAppBar(scaffoldKey: _scaffoldKey),
        body: const HubTabBody(),
      ),
    );
  }

  Future<void> _onSystemBack(TabsController tabs) async {
    final handler = ref.read(tabBackHandlerProvider);
    if (handler != null) {
      final handled = await handler();
      if (handled) {
        return;
      }
    }
    tabs.popActiveTab();
  }
}
