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
import '../../features/ministries/presentation/screens/ministries_list_screen.dart';
import '../../features/ministries/presentation/screens/ministry_detail_screen.dart';
import '../../features/ministries/presentation/screens/ministry_form_screen.dart';
import '../../features/financial/presentation/screens/contribution_form_screen.dart';
import '../../features/financial/presentation/screens/expense_form_screen.dart';
import '../../features/financial/presentation/screens/financial_goal_form_screen.dart';
import '../../features/financial/presentation/screens/financial_reports_screen.dart';
import '../../features/worship/presentation/screens/worship_services_screen.dart';
import '../../features/worship/presentation/screens/worship_attendance_screen.dart';
import '../../features/worship/presentation/screens/worship_service_form_screen.dart';
import '../../features/worship/presentation/screens/worship_statistics_screen.dart';
import '../../features/visitors/presentation/screens/visitors_list_screen.dart';
import '../../features/visitors/presentation/screens/visitor_form_screen.dart';
import '../../features/visitors/presentation/screens/visitor_details_screen.dart';
import '../../features/visitors/presentation/screens/visitor_visit_form_screen.dart';
import '../../features/visitors/presentation/screens/visitor_followup_form_screen.dart';
import '../../features/visitors/presentation/screens/visitors_statistics_screen.dart';
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
    // Rotas de ministérios
    GoRoute(
      path: '/ministries/new',
      builder: (context, state) => const MinistryFormScreen(),
    ),
    GoRoute(
      path: '/ministries/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MinistryFormScreen(ministryId: id);
      },
    ),
    GoRoute(
      path: '/ministries/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MinistryDetailScreen(ministryId: id);
      },
    ),
    GoRoute(
      path: '/contributions/new',
      builder: (context, state) => const ContributionFormScreen(),
    ),
    GoRoute(
      path: '/contributions/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ContributionFormScreen(contributionId: id);
      },
    ),
    GoRoute(
      path: '/expenses/new',
      builder: (context, state) => const ExpenseFormScreen(),
    ),
    GoRoute(
      path: '/expenses/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ExpenseFormScreen(expenseId: id);
      },
    ),
    GoRoute(
      path: '/financial-goals/new',
      builder: (context, state) => const FinancialGoalFormScreen(),
    ),
    GoRoute(
      path: '/financial-goals/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return FinancialGoalFormScreen(goalId: id);
      },
    ),
    GoRoute(
      path: '/financial-reports',
      builder: (context, state) => const FinancialReportsScreen(),
    ),
    GoRoute(
      path: '/worship-services',
      builder: (context, state) => const WorshipServicesScreen(),
    ),
    GoRoute(
      path: '/worship-services/:id/attendance',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WorshipAttendanceScreen(worshipServiceId: id);
      },
    ),
    GoRoute(
      path: '/worship-services/new',
      builder: (context, state) => const WorshipServiceFormScreen(),
    ),
    GoRoute(
      path: '/worship-services/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WorshipServiceFormScreen(worshipServiceId: id);
      },
    ),
    GoRoute(
      path: '/worship-statistics',
      builder: (context, state) => const WorshipStatisticsScreen(),
    ),
    GoRoute(
      path: '/visitors',
      builder: (context, state) => const VisitorsListScreen(),
    ),
    GoRoute(
      path: '/visitors/statistics',
      builder: (context, state) => const VisitorsStatisticsScreen(),
    ),
    GoRoute(
      path: '/visitors/new',
      builder: (context, state) => const VisitorFormScreen(),
    ),
    GoRoute(
      path: '/visitors/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorDetailsScreen(visitorId: id);
      },
    ),
    GoRoute(
      path: '/visitors/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorFormScreen(visitorId: id);
      },
    ),
    GoRoute(
      path: '/visitors/:id/visit/new',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorVisitFormScreen(visitorId: id);
      },
    ),
    GoRoute(
      path: '/visitors/:id/followup/new',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VisitorFollowupFormScreen(visitorId: id);
      },
    ),
    GoRoute(
      path: '/visitors/:id/followup/:followupId/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final followupId = state.pathParameters['followupId']!;
        return VisitorFollowupFormScreen(
          visitorId: id,
          followupId: followupId,
        );
      },
    ),
  ],
);

