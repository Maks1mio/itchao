import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_controller.dart';

class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({required this.callbackUri, super.key});

  final Uri callbackUri;

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handled) {
      return;
    }
    _handled = true;
    Future.microtask(() async {
      final profile = await ref
          .read(authControllerProvider.notifier)
          .completeOAuthCallback(widget.callbackUri);
      if (!mounted) {
        return;
      }
      if (profile != null) {
        context.go('/api-keys-setup');
      } else {
        context.go('/gate');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
