import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/notification_provider.dart';

/// Cartão "Ativar notificações" da web: o navegador só aceita o pedido de
/// permissão vindo de um toque. Some quando a permissão já foi decidida
/// (aceita ou negada) ou quando a pessoa toca em "Agora não".
class PushPermissionCard extends ConsumerStatefulWidget {
  const PushPermissionCard({super.key});

  @override
  ConsumerState<PushPermissionCard> createState() => _PushPermissionCardState();
}

class _PushPermissionCardState extends ConsumerState<PushPermissionCard> {
  static const _dismissedKey = 'push_card_dismissed';
  bool _visible = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _check();
  }

  Future<void> _check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_dismissedKey) ?? false) return;
      final status = await ref.read(pushRegistrationServiceProvider).permissionStatus();
      if (mounted && status == AuthorizationStatus.notDetermined) {
        setState(() => _visible = true);
      }
    } catch (_) {
      // Navegador sem suporte a push (ex.: Safari do iPhone fora da tela inicial).
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final result = await ref.read(pushRegistrationServiceProvider).registerCurrentDevice();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _visible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: cs.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Receba avisos da igreja neste aparelho, mesmo com o app fechado.',
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _busy ? null : _dismiss, child: const Text('Agora não')),
                FilledButton(
                  onPressed: _busy ? null : _enable,
                  child: const Text('Ativar notificações'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
