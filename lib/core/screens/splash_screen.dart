import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_branding.dart';
import '../navigation/church_selection_gate.dart';
import '../widgets/app_logo.dart';

/// Tela de Splash - Primeira tela do app
/// Verifica autenticação e redireciona
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(seconds: 2), _checkAuth);
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;

    // Guarda contra a corrida com deep link (Pitfall 9 / Achado #13): no cold
    // start do iOS o app recebe `/` primeiro e o link chega logo depois, via
    // RouteInformationParser. Sem esta guarda, o temporizador de 2s dispara
    // `context.go('/home')` POR CIMA da rota que o link já resolveu — flash de
    // tela e navegação dupla, exatamente o que o critério de sucesso #2 do
    // ROADMAP proíbe. É só guarda de ENTRADA: o temporizador, o dispose que o
    // cancela e o fluxo normal de splash ficam intactos.
    if (GoRouterState.of(context).matchedLocation != '/splash') return;

    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session != null) {
        final route = await ChurchSelectionGate.resolveNextRoute(supabase);
        if (mounted) context.go(route);
      } else {
        context.go('/login');
      }
    } catch (_) {
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _redirectTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo do app
            SizedBox(
              width: 120,
              height: 120,
              child: const AppLogo(),
            ),
            const SizedBox(height: 24),
            
            // Nome do app
            Text(
              AppBranding.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            
            // Subtítulo
            Text(
              AppBranding.organizationName,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 48),
            
            // Loading indicator
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
