import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Пункт меню «⋯» в прозрачном AppBar (обрабатывается в [TabChromeNotifier]).
class TabChromeMenuItem {
  const TabChromeMenuItem({required this.id, required this.label});

  final String id;
  final String label;
}

class TabChromeState {
  const TabChromeState({
    this.showTitle = true,
    this.menuItems = const [],
    this.appBarTitle,
    this.extraActions = const [],
    this.bottomBar,
  });

  final bool showTitle;
  final List<TabChromeMenuItem> menuItems;

  /// Центр AppBar (между ☰ и ⋯): поиск, фильтр и т.п.
  final Widget? appBarTitle;
  final List<Widget> extraActions;
  final Widget? bottomBar;

  static const appBarHeight = kToolbarHeight;
}

final tabChromeProvider = NotifierProvider<TabChromeNotifier, TabChromeState>(TabChromeNotifier.new);

class TabChromeNotifier extends Notifier<TabChromeState> {
  final Map<String, void Function()> _handlers = {};

  @override
  TabChromeState build() => const TabChromeState();

  void setAppBarContent({
    required Widget title,
    List<Widget> extraActions = const [],
    bool showTitle = false,
  }) {
    state = TabChromeState(
      showTitle: showTitle,
      menuItems: state.menuItems,
      appBarTitle: title,
      extraActions: extraActions,
      bottomBar: state.bottomBar,
    );
  }

  void clearAppBarContent() {
    state = TabChromeState(
      showTitle: state.showTitle,
      menuItems: state.menuItems,
      bottomBar: state.bottomBar,
    );
  }

  void setBottomBar(Widget? bar) {
    state = TabChromeState(
      showTitle: state.showTitle,
      menuItems: state.menuItems,
      appBarTitle: state.appBarTitle,
      extraActions: state.extraActions,
      bottomBar: bar,
    );
  }

  void setPageMenu({
    required List<TabChromeMenuItem> items,
    required Map<String, void Function()> handlers,
    bool showTitle = true,
  }) {
    _handlers
      ..clear()
      ..addAll(handlers);
    state = TabChromeState(
      showTitle: showTitle,
      menuItems: items,
      bottomBar: state.bottomBar,
    );
  }

  void clearPageMenu({bool showTitle = true}) {
    _handlers.clear();
    state = TabChromeState(showTitle: showTitle);
  }

  void invoke(String id) {
    _handlers[id]?.call();
  }
}
