import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_constants.dart';

/// Decide, logo após autenticação (login ou sessão restaurada no cold
/// start), se o usuário deve ver o seletor de unidade (CHU-300) antes de
/// entrar no app.
///
/// Usado nos dois pontos reais de entrada pós-autenticação:
/// `SplashScreen` (sessão restaurada) e `LoginScreen` (login novo). Contas
/// novas (signup) sempre têm exatamente 1 unidade, então nunca precisam do
/// seletor — `signup_screen.dart` não usa este gate.
class ChurchSelectionGate {
  ChurchSelectionGate._();

  static Future<String> resolveNextRoute(SupabaseClient client) async {
    final user = client.auth.currentUser ?? client.auth.currentSession?.user;
    if (user == null) return '/login';

    if (await SupabaseConstants.hasChosenActiveUnit(user.id)) {
      return '/home';
    }

    try {
      final rows = await client.rpc('listar_minhas_igrejas') as List;
      if (rows.length <= 1) {
        await SupabaseConstants.markChosenActiveUnit(user.id);
        return '/home';
      }
      return '/select-church';
    } catch (_) {
      // Fail-open: uma falha nessa checagem não pode bloquear o login.
      return '/home';
    }
  }
}
