import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/onboarding_status.dart';

/// Primeiros passos do pastor: só RPC (migration 008400). O gate é
/// `church_info.edit` no servidor; aqui só traduz o JSON.
class OnboardingRepository {
  final SupabaseClient _supabase;

  OnboardingRepository(this._supabase);

  Future<OnboardingStatus> status() async =>
      _parse(await _supabase.rpc('onboarding_status'));

  /// Marca ou desmarca uma etapa à mão ("Pular"); `dismissed` esconde o card
  /// da Dashboard.
  Future<OnboardingStatus> setStep(String step, bool done) async => _parse(
        await _supabase.rpc(
          'onboarding_set_step',
          params: {'p_step': step, 'p_done': done},
        ),
      );

  /// Grava as dores e aplica o preset da Dashboard (F2).
  Future<OnboardingStatus> setPains(List<String> pains) async => _parse(
        await _supabase.rpc('onboarding_set_pains', params: {'p_pains': pains}),
      );

  OnboardingStatus _parse(dynamic json) =>
      OnboardingStatus.fromJson(Map<String, dynamic>.from(json as Map));
}
