import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/members/presentation/screens/member_detail_screen.dart';
import '../../features/members/presentation/screens/member_form_screen.dart';
import '../../features/groups/presentation/screens/groups_list_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/group_form_screen.dart';
import '../../features/groups/presentation/screens/meeting_form_screen.dart';
import '../../features/groups/presentation/screens/meeting_detail_screen.dart';
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
    GoRoute(
      path: '/members/new',
      builder: (context, state) => const MemberFormScreen(),
    ),
    GoRoute(
      path: '/members/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MemberFormScreen(memberId: id);
      },
    ),
    GoRoute(
      path: '/members/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MemberDetailScreen(memberId: id);
      },
    ),
    GoRoute(
      path: '/groups/new',
      builder: (context, state) => const GroupFormScreen(),
    ),
    GoRoute(
      path: '/groups/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return GroupFormScreen(groupId: id);
      },
    ),
    GoRoute(
      path: '/groups/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return GroupDetailScreen(groupId: id);
      },
    ),
    // Rotas de reuniões
    GoRoute(
      path: '/groups/:groupId/meetings/new',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return MeetingFormScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/groups/:groupId/meetings/:meetingId/edit',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final meetingId = state.pathParameters['meetingId']!;
        return MeetingFormScreen(groupId: groupId, meetingId: meetingId);
      },
    ),
    GoRoute(
      path: '/groups/:groupId/meetings/:meetingId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final meetingId = state.pathParameters['meetingId']!;
        return MeetingDetailScreen(groupId: groupId, meetingId: meetingId);
      },
    ),
  ],
);

