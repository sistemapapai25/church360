import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tela de Splash - Primeira tela do app
/// Verifica autenticação e redireciona
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Aguarda 2 segundos para mostrar a splash
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Verifica se está autenticado
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    
    if (session != null) {
      // Está autenticado, vai para home
      context.go('/home');
    } else {
      // Não está autenticado, vai para login
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone da igreja
            Icon(
              Icons.church,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            
            // Nome do app
            Text(
              'Church 360',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            
            // Subtítulo
            Text(
              'Gestão Completa de Igrejas',
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

