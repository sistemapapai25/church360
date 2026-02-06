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

  Future<AutoScheduleConfig> upsertForRule({
    required DispatchRule rule,
    required bool active,
    required String sendTime,
    String timezone = 'America/Sao_Paulo',
  }) async {
    final repo = ref.read(autoSchedulerRepositoryProvider);
    return repo.upsertForRule(
      ruleId: rule.id,
      title: rule.title,
      active: active,
      sendTime: sendTime,
      timezone: timezone,
    );
  }

  Future<void> toggleActive(String configId, bool active) async {
    final repo = ref.read(autoSchedulerRepositoryProvider);
    await repo.toggleActive(configId, active);
  }

  Future<void> deleteSchedule(String configId) async {
    final repo = ref.read(autoSchedulerRepositoryProvider);
    await repo.deleteSchedule(configId);
  }
}

final autoSchedulerActionsProvider = Provider<AutoSchedulerActions>((ref) {
  return AutoSchedulerActions(ref);
});
