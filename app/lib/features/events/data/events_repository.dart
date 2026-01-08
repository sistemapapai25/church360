import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/event.dart';

/// Repository para gerenciar eventos
class EventsRepository {
  final SupabaseClient _supabase;

  EventsRepository(this._supabase);

  /// Buscar lista distinta de tipos de eventos
  Future<List<String>> getDistinctEventTypes() async {
    try {
      final response = await _supabase
          .from('event')
          .select('event_type')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('event_type');

      final list = (response as List)
          .map((json) => (json['event_type'] ?? '').toString())
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();
      list.sort();
      return list;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, String>>> getEventTypesCatalog() async {
    try {
      final response = await _supabase
          .from('event_type')
          .select()
          .order('label');

      return (response as List)
          .map((json) => {
                'code': (json['code'] ?? '').toString(),
                'label': (json['label'] ?? '').toString(),
              })
          .where((e) => e['code']!.isNotEmpty)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> upsertEventType(String code, String label) async {
    try {
      await _supabase
          .from('event_type')
          .upsert({'code': code, 'label': label});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncEventTypesFromExistingEvents() async {
    try {
      final distinct = await _supabase
          .from('event')
          .select('event_type')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('event_type');
      final codes = (distinct as List)
          .map((j) => (j['event_type'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      for (final code in codes) {
        final label = _guessLabel(code);
        await _supabase.from('event_type').upsert({'code': code, 'label': label});
      }
    } catch (e) {
      rethrow;
    }
  }

  String _guessLabel(String code) {
    switch (code) {
      case 'culto_normal':
        return 'Culto Normal / Ceia';
      case 'ensaio':
        return 'Ensaio';
      case 'reuniao_ministerio':
        return 'Reunião do Ministério (interna)';
      case 'reuniao_externa':
        return 'Reunião Externa / Célula';
      case 'evento_conjunto':
        return 'Evento Conjunto (vários ministérios)';
      case 'lideranca_geral':
        return 'Reunião de Liderança Geral';
      case 'vigilia':
        return 'Vigília ou Culto Especial';
      case 'mutirao':
        return 'Limpeza / Mutirão / Manutenção';
      default:
        final cleaned = code.replaceAll('_', ' ');
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }

  Future<int> getEventsCountByType(String code) async {
    try {
      final response = await _supabase
          .from('event')
          .select()
          .eq('event_type', code)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();
      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteEventType(String code) async {
    try {
      await _supabase.from('event_type').delete().eq('code', code);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar todos os eventos
  Future<List<Event>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('event')
          .select('''
            *,
            event_registration(count)
          ''')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('start_date', ascending: false);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        // Extrair contagem de inscrições
        if (data['event_registration'] != null) {
          final registrations = data['event_registration'];
          if (registrations is List && registrations.isNotEmpty) {
            data['registration_count'] = registrations[0]['count'];
          } else {
            data['registration_count'] = 0;
          }
        }
        
        return Event.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar eventos ativos
  Future<List<Event>> getActiveEvents() async {
    try {
      final response = await _supabase
          .from('event')
          .select('''
            *,
            event_registration(count)
          ''')
          .neq('status', 'cancelled')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('start_date', ascending: false);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['event_registration'] != null) {
          final registrations = data['event_registration'];
          if (registrations is List && registrations.isNotEmpty) {
            data['registration_count'] = registrations[0]['count'];
          } else {
            data['registration_count'] = 0;
          }
        }
        
        return Event.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar eventos futuros
  Future<List<Event>> getUpcomingEvents() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('event')
          .select('''
            *,
            event_registration(count)
          ''')
          .neq('status', 'cancelled')
          .gte('start_date', now)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('start_date', ascending: true);

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['event_registration'] != null) {
          final registrations = data['event_registration'];
          if (registrations is List && registrations.isNotEmpty) {
            data['registration_count'] = registrations[0]['count'];
          } else {
            data['registration_count'] = 0;
          }
        }
        
        return Event.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar evento por ID
  Future<Event?> getEventById(String id) async {
    try {
      final response = await _supabase
          .from('event')
          .select('''
            *,
            event_registration(count)
          ''')
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;

      final data = Map<String, dynamic>.from(response);
      
      if (data['event_registration'] != null) {
        final registrations = data['event_registration'];
        if (registrations is List && registrations.isNotEmpty) {
          data['registration_count'] = registrations[0]['count'];
        } else {
          data['registration_count'] = 0;
        }
      }

      return Event.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar evento a partir de JSON
  Future<Event> createEventFromJson(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['tenant_id'] = payload['tenant_id'] ?? SupabaseConstants.currentTenantId;
      final response = await _supabase
          .from('event')
          .insert(payload)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("is_mandatory") && data.containsKey('is_mandatory')) {
        final fallback = Map<String, dynamic>.from(data)..remove('is_mandatory');
        final response = await _supabase
            .from('event')
            .insert(fallback)
            .select()
            .single();
        return Event.fromJson(response);
      }
      rethrow;
    }
  }

  /// Criar evento (alias para createEventFromJson)
  Future<Event> createEvent(Map<String, dynamic> data) async {
    return createEventFromJson(data);
  }

  /// Atualizar evento com objeto Event
  Future<Event> updateEventObject(Event event) async {
    try {
      final response = await _supabase
          .from('event')
          .update(event.toJson())
          .eq('id', event.id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar evento com ID e dados
  Future<Event> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('event')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("is_mandatory") && data.containsKey('is_mandatory')) {
        final fallback = Map<String, dynamic>.from(data)..remove('is_mandatory');
        final response = await _supabase
            .from('event')
            .update(fallback)
            .eq('id', id)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .select()
            .single();
        return Event.fromJson(response);
      }
      rethrow;
    }
  }

  /// Deletar evento
  Future<void> deleteEvent(String id) async {
    try {
      await _supabase
          .from('event')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Contar total de eventos
  Future<int> getTotalEventsCount() async {
    try {
      final response = await _supabase
          .from('event')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar eventos ativos
  Future<int> getActiveEventsCount() async {
    try {
      final response = await _supabase
          .from('event')
          .select()
          .neq('status', 'cancelled')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar inscrições de um evento
  Future<List<EventRegistration>> getEventRegistrations(String eventId) async {
    try {
      final response = await _supabase
          .from('event_registration')
          .select('''
            *,
            user_account:user_id (first_name, last_name)
          ''')
          .eq('event_id', eventId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('registered_at');

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['user_account'] != null) {
          final member = data['user_account'];
          data['member_name'] = '${member['first_name']} ${member['last_name']}';
        }
        
        return EventRegistration.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Registrar membro em evento (alias para addRegistration)
  Future<EventRegistration> registerMemberInEvent({
    required String eventId,
    required String memberId,
  }) async {
    try {
      // Usar upsert para evitar problemas com constraints
      final response = await _supabase
          .from('event_registration')
          .upsert({
            'event_id': eventId,
            'user_id': memberId,
            'registered_at': DateTime.now().toIso8601String(),
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();

      return EventRegistration.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Adicionar inscrição (mesmo que registerMemberInEvent)
  Future<void> addRegistration(String eventId, String memberId) async {
    await registerMemberInEvent(eventId: eventId, memberId: memberId);
  }

  /// Cancelar inscrição
  Future<void> cancelRegistration(String eventId, String memberId) async {
    try {
      await _supabase
          .from('event_registration')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Marcar check-in
  Future<void> checkIn(String eventId, String memberId) async {
    try {
      await _supabase
          .from('event_registration')
          .update({
            'checked_in_at': DateTime.now().toIso8601String(),
          })
          .eq('event_id', eventId)
          .eq('user_id', memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancelar check-in
  Future<void> cancelCheckIn(String eventId, String memberId) async {
    try {
      await _supabase
          .from('event_registration')
          .update({
            'checked_in_at': null,
          })
          .eq('event_id', eventId)
          .eq('user_id', memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Remover inscrição
  Future<void> removeRegistration(String eventId, String memberId) async {
    try {
      await _supabase
          .from('event_registration')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', memberId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }
}
