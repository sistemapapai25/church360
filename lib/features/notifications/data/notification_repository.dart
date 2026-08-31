import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/notification.dart';

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  Future<String?> _effectiveUserId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_nickname': nickname,
        });
      } catch (_) {}
    }
    return user.id;
  }

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  /// Obter todas as notificações do usuário
  Future<List<AppNotification>> getAllNotifications() async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Obter notificações não lidas
  Future<List<AppNotification>> getUnreadNotifications() async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .neq('status', 'read')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Obter notificações por tipo
  Future<List<AppNotification>> getNotificationsByType(NotificationType type) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('type', type.value)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Obter uma notificação por ID
  Future<AppNotification?> getNotificationById(String id) async {
    final userId = await _effectiveUserId();
    if (userId == null) return null;

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AppNotification.fromJson(response);
  }

  /// Obter contagem de notificações não lidas
  Future<int> getUnreadNotificationsCount() async {
    final userId = await _effectiveUserId();
    if (userId == null) return 0;

    final response = await _supabase
        .rpc('get_unread_notifications_count', params: {'target_user_id': userId});

    return response as int;
  }

  /// Marcar notificação como lida
  Future<AppNotification> markAsRead(String id) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('notifications')
        .update({
          'status': 'read',
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('id', id)
        .select()
        .single();

    return AppNotification.fromJson(response);
  }

  /// Marcar todas as notificações como lidas
  Future<void> markAllAsRead() async {
    final userId = await _effectiveUserId();
    if (userId == null) return;

    await _supabase.rpc('mark_all_notifications_as_read', params: {'target_user_id': userId});
  }

  /// Deletar notificação
  Future<void> deleteNotification(String id) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    await _supabase
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('id', id);
  }

  /// Deletar todas as notificações lidas
  Future<void> deleteAllReadNotifications() async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    await _supabase
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('status', 'read');
  }

  /// Criar notificação (para testes)
  Future<AppNotification> createNotification({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? route,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('notifications')
        .insert({
          'user_id': userId,
          'type': type.value,
          'title': title,
          'body': body,
          'data': data,
          'route': route,
          'status': 'pending',
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return AppNotification.fromJson(response);
  }

  /// Lote 8: cria uma notificação para um auth user específico (não o
  /// usuário corrente). Usado pelo gerador de escala quando um líder
  /// atribui uma pendência a outro coordenador. Falha silenciosamente
  /// (retorna null) se a inserção falhar — notificação é side effect
  /// que não pode bloquear a ação principal.
  Future<AppNotification?> createNotificationForUser({
    required String targetUserId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? route,
  }) async {
    try {
      final response = await _supabase
          .from('notifications')
          .insert({
            'user_id': targetUserId,
            'type': type.value,
            'title': title,
            'body': body,
            'data': data,
            'route': route,
            'status': 'pending',
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();
      return AppNotification.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Disparar notificação de novo evento para o tenant atual.
  ///
  /// OBSOLETO desde a Fase 4 (NOTIF-01 / D-01): nenhuma tela chama este método,
  /// e o disparo do anúncio passou a ser automático no banco (trigger de
  /// publicação do evento + tick que consome a outbox, Plano 04-03). Manter a
  /// chamada da RPC `notify_event_announcement` viva no cliente criaria um
  /// caminho paralelo de fan-out fora do filtro de audiência.
  /// Dívida registrada: a remoção deste método (e da RPC) é mudança de API
  /// independente de NOTIF-01, fora do escopo deste plano.
  @Deprecated(
    'Fase 4 / D-01: o anúncio é disparado por trigger + tick no banco. '
    'Não chamar — caminho paralelo sem filtro de audiência.',
  )
  Future<int> notifyEventAnnouncement({
    String? title,
    String? body,
    String? eventId,
    String? route,
    Map<String, dynamic>? data,
  }) async {
    final response = await _supabase.rpc(
      'notify_event_announcement',
      params: {
        'p_title': title,
        'p_body': body,
        'p_event_id': eventId,
        'p_route': route,
        'p_data': data,
      },
    );
    if (response is int) return response;
    return 0;
  }

  /// Disparar notificação de nova reunião para o tenant atual
  Future<int> notifyMeetingAnnouncement({
    String? title,
    String? body,
    String? eventId,
    String? route,
    Map<String, dynamic>? data,
  }) async {
    final response = await _supabase.rpc(
      'notify_meeting_announcement',
      params: {
        'p_title': title,
        'p_body': body,
        'p_event_id': eventId,
        'p_route': route,
        'p_data': data,
      },
    );
    if (response is int) return response;
    return 0;
  }

  /// Disparar notificação de novo culto para o tenant atual
  Future<int> notifyWorshipAnnouncement({
    String? title,
    String? body,
    String? eventId,
    String? route,
    Map<String, dynamic>? data,
  }) async {
    final response = await _supabase.rpc(
      'notify_worship_announcement',
      params: {
        'p_title': title,
        'p_body': body,
        'p_event_id': eventId,
        'p_route': route,
        'p_data': data,
      },
    );
    if (response is int) return response;
    return 0;
  }

  // =====================================================
  // NOTIFICATION PREFERENCES
  // =====================================================

  /// Obter preferências de notificação do usuário
  Future<NotificationPreferences?> getNotificationPreferences() async {
    final userId = await _effectiveUserId();
    if (userId == null) return null;

    final response = await _supabase
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) {
      final created = await _supabase
          .from('notification_preferences')
          .upsert({
            'user_id': userId,
            'tenant_id': SupabaseConstants.currentTenantId,
          }, onConflict: 'user_id')
          .select()
          .single();
      return NotificationPreferences.fromJson(created);
    }
    return NotificationPreferences.fromJson(response);
  }

  /// Atualizar preferências de notificação
  Future<NotificationPreferences> updateNotificationPreferences({
    bool? devotionalDaily,
    bool? prayerRequestPrayed,
    bool? prayerRequestAnswered,
    bool? eventReminder,
    // Fase 4 / NOTIF-01 (D-04): preferência do anúncio de publicação, gravada
    // em coluna própria — independente de `event_reminder`.
    bool? eventAnnouncement,
    bool? meetingReminder,
    bool? worshipReminder,
    bool? groupNewMember,
    bool? financialGoalReached,
    bool? birthdayReminder,
    bool? general,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final updates = <String, dynamic>{};
    if (devotionalDaily != null) updates['devotional_daily'] = devotionalDaily;
    if (prayerRequestPrayed != null) updates['prayer_request_prayed'] = prayerRequestPrayed;
    if (prayerRequestAnswered != null) updates['prayer_request_answered'] = prayerRequestAnswered;
    if (eventReminder != null) updates['event_reminder'] = eventReminder;
    if (eventAnnouncement != null) updates['event_announcement'] = eventAnnouncement;
    if (meetingReminder != null) updates['meeting_reminder'] = meetingReminder;
    if (worshipReminder != null) updates['worship_reminder'] = worshipReminder;
    if (groupNewMember != null) updates['group_new_member'] = groupNewMember;
    if (financialGoalReached != null) updates['financial_goal_reached'] = financialGoalReached;
    if (birthdayReminder != null) updates['birthday_reminder'] = birthdayReminder;
    if (general != null) updates['general'] = general;
    if (quietHoursEnabled != null) updates['quiet_hours_enabled'] = quietHoursEnabled;
    if (quietHoursStart != null) updates['quiet_hours_start'] = quietHoursStart;
    if (quietHoursEnd != null) updates['quiet_hours_end'] = quietHoursEnd;

    // A UNIQUE em produção é (user_id), sem o tenant. Sem `onConflict` o
    // PostgREST infere a PK (`id`) e o upsert vira INSERT puro: quem já tem
    // preferências gravadas leva 409 ao salvar de novo.
    // A falta do tenant na constraint é problema à parte — ver CHU-324.
    final response = await _supabase
        .from('notification_preferences')
        .upsert({
          'user_id': userId,
          ...updates,
          'tenant_id': SupabaseConstants.currentTenantId,
        }, onConflict: 'user_id')
        .select()
        .single();

    return NotificationPreferences.fromJson(response);
  }

  // =====================================================
  // FCM TOKENS
  // =====================================================

  /// Salvar token FCM
  Future<FcmToken> saveFcmToken({
    required String token,
    String? deviceId,
    String? deviceName,
    String? platform,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    // UNIQUE (user_id, device_id) — sem `onConflict` o PostgREST infere a PK
    // (`id`) e re-registrar o mesmo aparelho estoura 409. Enquanto o chamador
    // não mandar `deviceId`, o NULL impede a deduplicação (ver CHU-323).
    final response = await _supabase
        .from('fcm_tokens')
        .upsert({
          'user_id': userId,
          'token': token,
          'device_id': deviceId,
          'device_name': deviceName,
          'platform': platform,
          'is_active': true,
          'last_used_at': DateTime.now().toIso8601String(),
          'tenant_id': SupabaseConstants.currentTenantId,
        }, onConflict: 'user_id,device_id')
        .select()
        .single();

    return FcmToken.fromJson(response);
  }

  /// Obter tokens FCM do usuário
  Future<List<FcmToken>> getFcmTokens() async {
    final userId = await _effectiveUserId();
    if (userId == null) return [];

    final response = await _supabase
        .from('fcm_tokens')
        .select()
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true)
        .order('last_used_at', ascending: false);

    return (response as List)
        .map((json) => FcmToken.fromJson(json))
        .toList();
  }

  /// Desativar token FCM
  Future<void> deactivateFcmToken(String tokenId) async {
    await _supabase
        .from('fcm_tokens')
        .update({'is_active': false})
        .eq('id', tokenId);
  }

  /// Deletar token FCM
  Future<void> deleteFcmToken(String tokenId) async {
    await _supabase.from('fcm_tokens').delete().eq('id', tokenId);
  }

  // =====================================================
  // REALTIME SUBSCRIPTIONS
  // =====================================================


  /// Escutar novas notificações em tempo real
  Future<RealtimeChannel> subscribeToNotifications(void Function(AppNotification) onNotification) async {
    final userId = await _effectiveUserId();
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    return _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final recordTenant = record['tenant_id']?.toString();
            if (recordTenant == SupabaseConstants.currentTenantId) {
              final notification = AppNotification.fromJson(record);
              onNotification(notification);
            }
          },
        )
        .subscribe();
  }
}
