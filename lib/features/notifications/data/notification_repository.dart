import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/notification.dart';

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  /// Obter todas as notificações do usuário
  Future<List<AppNotification>> getAllNotifications() async {
    final response = await _supabase
        .from('notifications')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Obter notificações não lidas
  Future<List<AppNotification>> getUnreadNotifications() async {
    final response = await _supabase
        .from('notifications')
        .select()
        .neq('status', 'read')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Obter notificações por tipo
  Future<List<AppNotification>> getNotificationsByType(NotificationType type) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('type', type.value)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Obter uma notificação por ID
  Future<AppNotification?> getNotificationById(String id) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AppNotification.fromJson(response);
  }

  /// Obter contagem de notificações não lidas
  Future<int> getUnreadNotificationsCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _supabase
        .rpc('get_unread_notifications_count', params: {'target_user_id': userId});

    return response as int;
  }

  /// Marcar notificação como lida
  Future<AppNotification> markAsRead(String id) async {
    final response = await _supabase
        .from('notifications')
        .update({
          'status': 'read',
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return AppNotification.fromJson(response);
  }

  /// Marcar todas as notificações como lidas
  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.rpc('mark_all_notifications_as_read', params: {'target_user_id': userId});
  }

  /// Deletar notificação
  Future<void> deleteNotification(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }

  /// Deletar todas as notificações lidas
  Future<void> deleteAllReadNotifications() async {
    await _supabase.from('notifications').delete().eq('status', 'read');
  }

  /// Criar notificação (para testes)
  Future<AppNotification> createNotification({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? route,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
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
        })
        .select()
        .single();

    return AppNotification.fromJson(response);
  }

  // =====================================================
  // NOTIFICATION PREFERENCES
  // =====================================================

  /// Obter preferências de notificação do usuário
  Future<NotificationPreferences?> getNotificationPreferences() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return NotificationPreferences.fromJson(response);
  }

  /// Atualizar preferências de notificação
  Future<NotificationPreferences> updateNotificationPreferences({
    bool? devotionalDaily,
    bool? prayerRequestPrayed,
    bool? prayerRequestAnswered,
    bool? eventReminder,
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');

    final updates = <String, dynamic>{};
    if (devotionalDaily != null) updates['devotional_daily'] = devotionalDaily;
    if (prayerRequestPrayed != null) updates['prayer_request_prayed'] = prayerRequestPrayed;
    if (prayerRequestAnswered != null) updates['prayer_request_answered'] = prayerRequestAnswered;
    if (eventReminder != null) updates['event_reminder'] = eventReminder;
    if (meetingReminder != null) updates['meeting_reminder'] = meetingReminder;
    if (worshipReminder != null) updates['worship_reminder'] = worshipReminder;
    if (groupNewMember != null) updates['group_new_member'] = groupNewMember;
    if (financialGoalReached != null) updates['financial_goal_reached'] = financialGoalReached;
    if (birthdayReminder != null) updates['birthday_reminder'] = birthdayReminder;
    if (general != null) updates['general'] = general;
    if (quietHoursEnabled != null) updates['quiet_hours_enabled'] = quietHoursEnabled;
    if (quietHoursStart != null) updates['quiet_hours_start'] = quietHoursStart;
    if (quietHoursEnd != null) updates['quiet_hours_end'] = quietHoursEnd;

    final response = await _supabase
        .from('notification_preferences')
        .update(updates)
        .eq('user_id', userId)
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');

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
        })
        .select()
        .single();

    return FcmToken.fromJson(response);
  }

  /// Obter tokens FCM do usuário
  Future<List<FcmToken>> getFcmTokens() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('fcm_tokens')
        .select()
        .eq('user_id', userId)
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
  RealtimeChannel subscribeToNotifications(void Function(AppNotification) onNotification) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');

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
            final notification = AppNotification.fromJson(payload.newRecord);
            onNotification(notification);
          },
        )
        .subscribe();
  }
}

