import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/notification_repository.dart';
import '../../domain/models/notification.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

// =====================================================
// NOTIFICATIONS PROVIDERS
// =====================================================

/// Provider: Todas as notificações
final allNotificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getAllNotifications();
});

/// Provider: Notificações não lidas
final unreadNotificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadNotifications();
});

/// Provider: Notificações por tipo
final notificationsByTypeProvider = FutureProvider.family<List<AppNotification>, NotificationType>((ref, type) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotificationsByType(type);
});

/// Provider: Notificação por ID
final notificationByIdProvider = FutureProvider.family<AppNotification?, String>((ref, id) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotificationById(id);
});

/// Provider: Contagem de notificações não lidas
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadNotificationsCount();
});

// =====================================================
// NOTIFICATION PREFERENCES PROVIDERS
// =====================================================

/// Provider: Preferências de notificação
final notificationPreferencesProvider = FutureProvider<NotificationPreferences?>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotificationPreferences();
});

// =====================================================
// FCM TOKENS PROVIDERS
// =====================================================

/// Provider: Tokens FCM do usuário
final fcmTokensProvider = FutureProvider<List<FcmToken>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getFcmTokens();
});

// =====================================================
// ACTIONS
// =====================================================

/// Provider: Ações de notificação
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref _ref;

  NotificationActions(this._ref);

  NotificationRepository get _repository => _ref.read(notificationRepositoryProvider);

  /// Marcar notificação como lida
  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    
    // Invalidar providers
    _ref.invalidate(allNotificationsProvider);
    _ref.invalidate(unreadNotificationsProvider);
    _ref.invalidate(unreadNotificationsCountProvider);
    _ref.invalidate(notificationByIdProvider(id));
  }

  /// Marcar todas as notificações como lidas
  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    
    // Invalidar providers
    _ref.invalidate(allNotificationsProvider);
    _ref.invalidate(unreadNotificationsProvider);
    _ref.invalidate(unreadNotificationsCountProvider);
  }

  /// Deletar notificação
  Future<void> deleteNotification(String id) async {
    await _repository.deleteNotification(id);
    
    // Invalidar providers
    _ref.invalidate(allNotificationsProvider);
    _ref.invalidate(unreadNotificationsProvider);
    _ref.invalidate(unreadNotificationsCountProvider);
  }

  /// Deletar todas as notificações lidas
  Future<void> deleteAllReadNotifications() async {
    await _repository.deleteAllReadNotifications();
    
    // Invalidar providers
    _ref.invalidate(allNotificationsProvider);
    _ref.invalidate(unreadNotificationsProvider);
  }

  /// Criar notificação (para testes)
  Future<void> createNotification({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? route,
  }) async {
    await _repository.createNotification(
      type: type,
      title: title,
      body: body,
      data: data,
      route: route,
    );
    
    // Invalidar providers
    _ref.invalidate(allNotificationsProvider);
    _ref.invalidate(unreadNotificationsProvider);
    _ref.invalidate(unreadNotificationsCountProvider);
  }

  /// Atualizar preferências de notificação
  Future<void> updatePreferences({
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
    await _repository.updateNotificationPreferences(
      devotionalDaily: devotionalDaily,
      prayerRequestPrayed: prayerRequestPrayed,
      prayerRequestAnswered: prayerRequestAnswered,
      eventReminder: eventReminder,
      meetingReminder: meetingReminder,
      worshipReminder: worshipReminder,
      groupNewMember: groupNewMember,
      financialGoalReached: financialGoalReached,
      birthdayReminder: birthdayReminder,
      general: general,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
    );
    
    // Invalidar provider
    _ref.invalidate(notificationPreferencesProvider);
  }

  /// Salvar token FCM
  Future<void> saveFcmToken({
    required String token,
    String? deviceId,
    String? deviceName,
    String? platform,
  }) async {
    await _repository.saveFcmToken(
      token: token,
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
    );
    
    // Invalidar provider
    _ref.invalidate(fcmTokensProvider);
  }

  /// Desativar token FCM
  Future<void> deactivateFcmToken(String tokenId) async {
    await _repository.deactivateFcmToken(tokenId);
    
    // Invalidar provider
    _ref.invalidate(fcmTokensProvider);
  }

  /// Deletar token FCM
  Future<void> deleteFcmToken(String tokenId) async {
    await _repository.deleteFcmToken(tokenId);
    
    // Invalidar provider
    _ref.invalidate(fcmTokensProvider);
  }
}

// =====================================================
// REALTIME PROVIDER
// =====================================================

/// Provider: Estado de notificações em tempo real
final notificationRealtimeProvider = StateNotifierProvider<NotificationRealtimeNotifier, AsyncValue<AppNotification?>>((ref) {
  return NotificationRealtimeNotifier(ref);
});

class NotificationRealtimeNotifier extends StateNotifier<AsyncValue<AppNotification?>> {
  final Ref _ref;
  RealtimeChannel? _channel;

  NotificationRealtimeNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _subscribe();
  }

  void _subscribe() {
    final repository = _ref.read(notificationRepositoryProvider);
    
    _channel = repository.subscribeToNotifications((notification) {
      state = AsyncValue.data(notification);
      
      // Invalidar providers para atualizar a lista
      _ref.invalidate(allNotificationsProvider);
      _ref.invalidate(unreadNotificationsProvider);
      _ref.invalidate(unreadNotificationsCountProvider);
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

