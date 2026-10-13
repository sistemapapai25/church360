import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/notifications/data/push/push_registration_service.dart';

/// Só no Android (e desktop) o app fecha de verdade.
bool get _closesApp =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.iOS &&
    defaultTargetPlatform != TargetPlatform.macOS;

/// Web e iPhone não fecham o app: lá "sair" encerra a sessão, senão o router
/// devolvia a pessoa logada de /login para /home.
Future<void> exitApp(BuildContext context) async {
  if (_closesApp) return SystemNavigator.pop();
  await signOutAndExit(context);
}

Future<void> signOutAndExit(BuildContext context) async {
  try {
    await PushRegistrationService.deactivateThisDevice();
    await Supabase.instance.client.auth.signOut();
  } catch (_) {}
  if (!context.mounted) {
    return;
  }
  if (_closesApp) {
    await SystemNavigator.pop();
  } else {
    context.go('/login');
  }
}
