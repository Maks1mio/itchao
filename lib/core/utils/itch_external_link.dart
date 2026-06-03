import 'package:url_launcher/url_launcher.dart';

/// Открывает ссылку из HTML itch.io с учётом `target="_blank"`.
Future<bool> launchItchExternalLink(
  Uri uri, {
  Map<String, String>? linkAttributes,
}) {
  final target = linkAttributes?['target']?.toLowerCase().trim() ?? '';
  final openInNewWindow = target == '_blank' || target == '_new';

  return launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: openInNewWindow ? '_blank' : null,
  );
}

bool linkOpensInNewWindow(Map<String, String>? linkAttributes) {
  final target = linkAttributes?['target']?.toLowerCase().trim() ?? '';
  return target == '_blank' || target == '_new';
}
