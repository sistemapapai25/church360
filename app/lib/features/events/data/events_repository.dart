import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/event.dart';

/// Repository para gerenciar eventos
class EventsRepository {
  final SupabaseClient _supabase;

  EventsRepository(this._supabase);

  /// Buscar todos os eventos
  Future<List<Event>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('event')
          .select('''
            *,
            event_registration(count)
          ''')
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
      final response = await _supabase
          .from('event')
          .insert(data)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
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
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar evento
  Future<void> deleteEvent(String id) async {
    try {
      await _supabase.from('event').delete().eq('id', id);
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
            member(first_name, last_name)
          ''')
          .eq('event_id', eventId)
          .order('registered_at');

      return (response as List).map((json) {
        final data = Map<String, dynamic>.from(json);
        
        if (data['member'] != null) {
          final member = data['member'];
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
      final response = await _supabase
          .from('event_registration')
          .insert({
            'event_id': eventId,
            'member_id': memberId,
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
          .eq('member_id', memberId);
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
          .eq('member_id', memberId);
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
          .eq('member_id', memberId);
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
          .eq('member_id', memberId);
    } catch (e) {
      rethrow;
    }
  }
}

