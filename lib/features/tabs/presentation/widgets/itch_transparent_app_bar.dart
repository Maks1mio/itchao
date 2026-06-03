import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/itch_colors.dart';

/// Прозрачный AppBar поверх контента (иконки с лёгкой тенью для читаемости).
class ItchTransparentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ItchTransparentAppBar({
    required this.leading,
    this.title,
    this.actions = const [],
    this.centerTitle = true,
    this.titleSpacing,
    super.key,
  });

  final Widget leading;
  final Widget? title;
  final List<Widget> actions;
  final bool centerTitle;
  final double? titleSpacing;

  static const _iconTheme = IconThemeData(
    color: Colors.white,
    shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
  );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: _iconTheme,
      actionsIconTheme: _iconTheme,
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: ItchColors.ivory,
        fontWeight: FontWeight.w600,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
      ),
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      leading: leading,
      title: title,
      actions: actions,
    );
  }
}
