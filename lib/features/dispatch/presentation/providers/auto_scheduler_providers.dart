import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auto_scheduler_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../screens/dispatch_config_screen.dart';

final autoSchedulerRepositoryProvider = Provider<AutoSchedulerRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AutoSchedulerRepository(supabase);
});

final autoScheduleByRuleProvider =
    StreamProvider.family<AutoScheduleConfig?, DispatchRule>((ref, rule) {
  final repo = ref.watch(autoSchedulerRepositoryProvider);
  return repo.watchByRuleId(rule.id);
});

final allAutoSchedulesProvider = StreamProvider<List<AutoScheduleConfig>>((ref) {
  final repo = ref.watch(autoSchedulerRepositoryProvider);
  return repo.watchAll();
});

class AutoSchedulerActions {
  final Ref ref;
  AutoSchedulerActions(this.ref);

  /// Derruba o cache dos dois providers de agendamento depois de gravar.
  ///
  /// `autoScheduleByRuleProvider` e `allAutoSchedulesProvider` sao
  /// `StreamProvider` alimentados por `.stream()` do Supabase, ou seja,
  /// dependem do Realtime avisar. Nenhuma migration deste projeto adiciona
  /// `whatsapp_relatorios_automaticos` a publicacao `supabase_realtime`, entao
  /// esse aviso pode nunca chegar: a pessoa desativa ou exclui o agendamento e
  /// a tela continua mostrando o estado antigo, como se o toque nao tivesse
  /// funcionado. Invalidar nao substitui o Realtime -- garante o caso de quem
  /// acabou de agir.
  ///
  /// O family inteiro e invalidado porque `toggleActive` e `deleteSchedule`
  /// recebem o id da configuracao, nao a `DispatchRule` que indexa o provider.
  void _refreshSchedules() {
    ref.invalidate(autoScheduleByRuleProvider);
    ref.invalidate(allAutoSchedulesProvider);
  }

  Future<AutoScheduleConfig> upsertForRule({
    required DispatchRule rule,
    required bool active,
    required String sendTime,
    String timezone = 'America/Sao_Paulo',
  }) async {
    final repo = ref.read(autoSchedulerRepositoryProvider);
    final config = await repo.upsertForRule(
      ruleId: rule.id,
      title: rule.title,
      active: active,
      sendTime: sendTime,
      timezone: timezone,
    );
    _refreshSchedules();
    return config;
  }

  Future<void> toggleActive(String configId, bool active) async {
    final repo = ref.read(autoSchedulerRepositoryProvider);
    await repo.toggleActive(configId, active);
    _refreshSchedules();
  }

  Future<void> deleteSchedule(String configId) async {
    final repo = ref.read(autoSchedulerRepositoryProvider);
    await repo.deleteSchedule(configId);
    _refreshSchedules();
  }
}

final autoSchedulerActionsProvider = Provider<AutoSchedulerActions>((ref) {
  return AutoSchedulerActions(ref);
});
