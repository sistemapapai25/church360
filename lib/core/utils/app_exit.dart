import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> exitApp(BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
    if (context.mounted) {
      context.go('/login');
    }
    return;
  }
  await SystemNavigator.pop();
}

Future<void> signOutAndExit(BuildContext context) async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {}
  if (!context.mounted) {
    return;
  }
  await exitApp(context);
}
