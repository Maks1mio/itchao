import 'package:flutter/material.dart';

import '../../../core/theme/itch_colors.dart';

/// Заголовок секции настроек (`h2` в itch desktop Preferences).
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 5),
      child: Text(
        title,
        style: const TextStyle(
          color: ItchColors.ivory,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Пояснение под блоком (`p.explanation` на ПК).
class SettingsExplanation extends StatelessWidget {
  const SettingsExplanation({
    required this.text,
    this.child,
    super.key,
  });

  final String text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFB9B9B9),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 8),
            child!,
          ],
        ],
      ),
    );
  }
}

/// Группа строк настроек (`SettingsGroup` на ПК).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 1),
          children[i],
        ],
      ],
    );
  }
}

/// Строка настроек с левой полосой (`Label` / `prefChunk` на ПК).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.child,
    this.active = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: ItchColors.item,
        border: Border(
          left: BorderSide(
            color: active ? ItchColors.accent : ItchColors.zambezi,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: ItchColors.ivory,
            fontSize: 14,
            height: 1.35,
          ),
          child: IconTheme(
            data: const IconThemeData(color: ItchColors.secondaryText, size: 18),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return body;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class SettingsCheckRow extends StatelessWidget {
  const SettingsCheckRow({
    required this.label,
    required this.checked,
    super.key,
  });

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      active: checked,
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: checked ? ItchColors.accent : ItchColors.zambezi,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      active: value,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            width: 36,
            child: Checkbox(
              value: value,
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
              activeColor: ItchColors.accent,
              side: const BorderSide(color: ItchColors.zambezi),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ItchColors.secondaryText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: enabled ? const Color(0xFFECECEC) : ItchColors.zambezi,
      decoration: enabled ? TextDecoration.underline : TextDecoration.none,
      decorationColor: enabled ? const Color(0xFFECECEC) : ItchColors.zambezi,
    );
    return SettingsRow(
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: enabled ? const Color(0xFF87A7C3) : ItchColors.zambezi),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label, style: textStyle),
          ),
        ],
      ),
    );
  }
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    required this.icon,
    required this.label,
    this.detail,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ItchColors.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: const TextStyle(
                      color: ItchColors.secondaryText,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        color: ItchColors.accent,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: ItchColors.ivory),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: ItchColors.ivory,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
