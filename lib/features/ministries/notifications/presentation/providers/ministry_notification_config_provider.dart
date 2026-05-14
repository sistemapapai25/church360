import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/ministry_notification_config_repository.dart';
import '../../domain/models/ministry_notification_config.dart';

/// Provider do repository de configs de notificação por ministério (Lote 11.5).
final ministryNotificationConfigRepositoryProvider =
    Provider<MinistryNotificationConfigRepository>((ref) {
  return MinistryNotificationConfigRepository(Supabase.instance.client);
});

/// Provider que lê a config atual de um ministério.
/// Retorna `null` se ainda não existir — UI usa
/// `MinistryNotificationConfig.defaultFor(id)` como fallback.
final ministryNotificationConfigProvider = FutureProvider.family<
    MinistryNotificationConfig?, String>((ref, ministryId) async {
  final repo = ref.watch(ministryNotificationConfigRepositoryProvider);
  return repo.getByMinistry(ministryId);
});
