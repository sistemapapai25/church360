import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';

/// Configuração de rotas do aplicativo
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final isAuthenticated = session != null;
    
    final isSplash = state.matchedLocation == '/splash';
    final isLogin = state.matchedLocation == '/login';
    
    // Se está na splash, deixa passar
    if (isSplash) {
      return null;
    }
    
    // Se não está autenticado e não está no login, redireciona para login
    if (!isAuthenticated && !isLogin) {
      return '/login';
    }
    
    // Se está autenticado e está no login, redireciona para home
    if (isAuthenticated && isLogin) {
      return '/home';
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);

