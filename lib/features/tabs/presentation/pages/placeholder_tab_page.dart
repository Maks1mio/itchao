import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceholderTabPage extends StatelessWidget {
  const PlaceholderTabPage({
    required this.title,
    this.message,
    this.externalUrl,
    super.key,
  });

  final String title;
  final String? message;
  final String? externalUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, textAlign: TextAlign.center),
            ],
            if (externalUrl != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final uri = Uri.parse(externalUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Открыть в браузере'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
