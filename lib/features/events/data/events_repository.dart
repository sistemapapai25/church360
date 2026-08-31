import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/event.dart';
import '../domain/models/event_audience.dart';
import '../domain/models/event_reminder.dart';

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
          .map(
            (json) => {
              'code': (json['code'] ?? '').toString(),
              'label': (json['label'] ?? '').toString(),
            },
          )
          .where((e) => e['code']!.isNotEmpty)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> upsertEventType(String code, String label) async {
    try {
      await _supabase.from('event_type').upsert({'code': code, 'label': label});
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
        await _supabase.from('event_type').upsert({
          'code': code,
          'label': label,
        });
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

  /// Buscar catálogo de locais de eventos já utilizados
  Future<List<String>> getEventLocationsCatalog() async {
    try {
      final response = await _supabase
          .from('event_location')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('name');

      return (response as List)
          .map((json) => (json['name'] ?? '').toString())
          .where((v) => v.isNotEmpty)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> upsertEventLocation(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await _supabase.from('event_location').upsert({
        'name': trimmed,
        'tenant_id': SupabaseConstants.currentTenantId,
      }, onConflict: 'tenant_id,name');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteEventLocation(String name) async {
    try {
      await _supabase
          .from('event_location')
          .delete()
          .eq('name', name)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getEventsCountByLocation(String name) async {
    try {
      final response = await _supabase
          .from('event')
          .select()
          .eq('location', name)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();
      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Preenche o catálogo de locais a partir dos locais já digitados em
  /// eventos existentes (útil na primeira vez que o catálogo está vazio)
  Future<void> syncEventLocationsFromExistingEvents() async {
    try {
      final distinct = await _supabase
          .from('event')
          .select('location')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('location');
      final names = (distinct as List)
          .map((j) => (j['location'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      for (final name in names) {
        await upsertEventLocation(name);
      }
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
      payload['tenant_id'] =
          payload['tenant_id'] ?? SupabaseConstants.currentTenantId;
      final response = await _supabase
          .from('event')
          .insert(payload)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      final msg = e.toString();
      final fallback = Map<String, dynamic>.from(data);
      fallback['tenant_id'] =
          fallback['tenant_id'] ?? SupabaseConstants.currentTenantId;
      var changed = false;
      if (msg.contains("is_mandatory") &&
          fallback.containsKey('is_mandatory')) {
        fallback.remove('is_mandatory');
        changed = true;
      }
      if (msg.contains("is_free") && fallback.containsKey('is_free')) {
        fallback.remove('is_free');
        changed = true;
      }
      if (changed) {
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
      final fallback = Map<String, dynamic>.from(data);
      var changed = false;
      if (msg.contains("is_mandatory") &&
          fallback.containsKey('is_mandatory')) {
        fallback.remove('is_mandatory');
        changed = true;
      }
      if (msg.contains("is_free") && fallback.containsKey('is_free')) {
        fallback.remove('is_free');
        changed = true;
      }
      if (changed) {
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

  /// Deletar múltiplos eventos selecionados manualmente
  Future<void> deleteEvents(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase
          .from('event')
          .delete()
          .inFilter('id', ids)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar todos os eventos de uma mesma leva (lançamento fixo/recorrente)
  Future<List<Event>> getEventsByBatch(String batchId) async {
    try {
      final response = await _supabase
          .from('event')
          .select()
          .eq('batch_id', batchId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('start_date');

      return (response as List)
          .map((json) => Event.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar toda a série de eventos gerada no mesmo lançamento fixo/recorrente
  Future<void> deleteEventsByBatch(String batchId) async {
    try {
      await _supabase
          .from('event')
          .delete()
          .eq('batch_id', batchId)
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
          data['member_name'] =
              '${member['first_name']} ${member['last_name']}';
        }

        return EventRegistration.fromJson(data);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar a audiência de um evento para um papel específico
  /// (`responsible`, `visibility` ou `registration`).
  Future<List<EventAudience>> getEventAudience(
    String eventId,
    String role,
  ) async {
    try {
      final response = await _supabase
          .from('event_audience')
          .select()
          .eq('event_id', eventId)
          .eq('role', role);

      return (response as List)
          .map(
            (json) => EventAudience.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar responsáveis (event_audience, role='responsible') de um evento.
  /// Casca fina sobre [getEventAudience] — mantida porque é o call site da
  /// Fase 1 (formulário e `eventResponsiblesProvider`).
  Future<List<EventAudience>> getEventResponsibles(String eventId) =>
      getEventAudience(eventId, 'responsible');

  /// Substitui o conjunto de alvos de audiência de um evento para o papel
  /// recebido. Delete-then-insert declarativo (não upsert): torna a operação
  /// idempotente para o formulário sem exigir `onConflict` sobre a UNIQUE
  /// composta de `event_audience`. Nunca converter para `.upsert()` sem
  /// `onConflict` — o PostgREST infere a PK, o upsert vira INSERT e estoura
  /// 409 na UNIQUE (incidente CHU-317, quebrou produção).
  Future<void> setEventAudience(
    String eventId,
    String role,
    List<EventAudience> targets,
  ) async {
    try {
      await _supabase
          .from('event_audience')
          .delete()
          .eq('event_id', eventId)
          .eq('role', role);

      if (targets.isEmpty) return;

      final rows = targets.map((t) {
        // Mapa de reset com as 4 colunas de alvo explicitamente nulas: o
        // switch abaixo preenche exatamente uma, que é o que o CHECK
        // `num_nonnulls(user_id, group_id, ministry_id, rbac_role_id) = 1`
        // exige do servidor.
        final row = <String, dynamic>{
          'tenant_id': SupabaseConstants.currentTenantId,
          'event_id': eventId,
          'role': role,
          'user_id': null,
          'group_id': null,
          'ministry_id': null,
          'rbac_role_id': null,
        };
        switch (t.targetKind) {
          case EventAudienceTargetKind.person:
            row['user_id'] = t.userId;
            break;
          case EventAudienceTargetKind.group:
            row['group_id'] = t.groupId;
            break;
          case EventAudienceTargetKind.ministry:
            row['ministry_id'] = t.ministryId;
            break;
          case EventAudienceTargetKind.role:
            row['rbac_role_id'] = t.rbacRoleId;
            break;
        }
        return row;
      }).toList();

      await _supabase.from('event_audience').insert(rows);
    } catch (e) {
      rethrow;
    }
  }

  /// Substitui o conjunto de responsáveis de um evento. Casca fina sobre
  /// [setEventAudience] — mantida porque é o call site da Fase 1.
  Future<void> setEventResponsibles(
    String eventId,
    List<EventAudience> targets,
  ) => setEventAudience(eventId, 'responsible', targets);

  /// Fase 4 — NOTIF-02. Lembretes configuráveis de um evento (D-02/D-03).
  /// Ordenado por `offset_minutes` decrescente: o lembrete mais distante do
  /// evento ("48h antes") aparece primeiro, seguido do mais próximo
  /// ("2h antes") — leitura natural para quem está montando o formulário.
  Future<List<EventReminder>> getEventReminders(String eventId) async {
    try {
      final response = await _supabase
          .from('event_reminder')
          .select()
          .eq('event_id', eventId)
          .order('offset_minutes', ascending: false);

      return (response as List)
          .map(
            (json) => EventReminder.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Substitui o conjunto de lembretes de um evento. Delete-then-insert
  /// declarativo (não upsert) — mesmo padrão de [setEventAudience] e pelo
  /// mesmo motivo: a UNIQUE de `event_reminder` é composta
  /// (`event_id`, `offset_minutes`), e um `.upsert()` sem `onConflict`
  /// faria o PostgREST inferir a PK (`id`), virando um INSERT puro que
  /// estoura 409 na UNIQUE (incidente CHU-317, quebrou produção).
  ///
  /// Lista vazia é estado válido (D-03: evento sem nenhum lembrete) —
  /// deleta e retorna, sem nenhum insert.
  Future<void> setEventReminders(
    String eventId,
    List<EventReminder> reminders,
  ) async {
    try {
      await _supabase.from('event_reminder').delete().eq('event_id', eventId);

      if (reminders.isEmpty) return;

      final rows = reminders
          .map(
            (r) => <String, dynamic>{
              'tenant_id': SupabaseConstants.currentTenantId,
              'event_id': eventId,
              'offset_minutes': r.offsetMinutes,
            },
          )
          .toList();

      await _supabase.from('event_reminder').insert(rows);
    } catch (e) {
      rethrow;
    }
  }

  /// REG-03: "sou responsável por este evento?".
  ///
  /// Usa a wrapper de aridade 1 `am_i_event_responsible` (migration
  /// 20260825000200), que resolve a conta do usuário e o tenant DENTRO do
  /// servidor. O predicado de aridade 3 existe, mas não pode ser chamado
  /// daqui: obrigaria o cliente a escolher qual espaço de id enviar, e essa
  /// escolha é causa documentada de falha silenciosa neste projeto.
  ///
  /// Desserialização fail-closed: qualquer retorno que não seja `true`
  /// vira `false`.
  Future<bool> isEventResponsible(String eventId) async {
    try {
      final res = await _supabase.rpc(
        'am_i_event_responsible',
        params: {'p_event_id': eventId},
      );
      return (res as bool?) ?? false;
    } catch (e) {
      rethrow;
    }
  }

  /// VIS-03/VIS-04: "posso me inscrever neste evento?".
  ///
  /// Wrapper de aridade 1 (Plano 06) pelo mesmo motivo de
  /// [isEventResponsible]: os dois espaços de id (conta x auth) são
  /// resolvidos DENTRO do servidor, e obrigar o cliente a escolher qual
  /// enviar é causa documentada de falha silenciosa neste projeto.
  ///
  /// Desserialização fail-closed: qualquer retorno que não seja `true` vira
  /// `false`. O resultado é insumo de UX — quem decide a inscrição continua
  /// sendo a RPC de escrita, que checa de novo no servidor.
  Future<bool> amIEligibleToRegister(String eventId) async {
    try {
      final res = await _supabase.rpc(
        'am_i_eligible_to_register',
        params: {'p_event_id': eventId},
      );
      return (res as bool?) ?? false;
    } catch (e) {
      rethrow;
    }
  }

  /// VIS-03: membros que o servidor considera elegíveis a se inscrever neste
  /// evento. Devolve as mesmas colunas de `get_tenant_member_directory`.
  ///
  /// A guarda de autorização do chamador está dentro da própria RPC (Plano
  /// 06): quem não é responsável nem tem `events.manage_registrations`
  /// recebe lista vazia, não erro. Nunca reimplementar esse filtro aqui.
  Future<List<Map<String, dynamic>>> listEventEligibleMembers(
    String eventId,
  ) async {
    try {
      final res = await _supabase.rpc(
        'list_event_eligible_members',
        params: {'p_event_id': eventId},
      );
      return ((res as List?) ?? const [])
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
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
      // REG-04: inscrição de membro passa pela RPC porque `max_capacity`
      // precisa ser checado em uma transação serializada no servidor. `count()`
      // no Dart seguido de upsert não protege a última vaga; depois da migration
      // 20260825000600, INSERT direto em event_registration é negado. O antigo
      // onConflict do cliente migrou para a cláusula ON CONFLICT (event_id,
      // user_id) dentro da RPC.
      final registrationId = await _supabase.rpc(
        'register_member_in_event',
        params: {'p_event_id': eventId, 'p_user_id': memberId},
      );

      final id = registrationId?.toString();
      if (id == null || id.isEmpty) {
        throw StateError('register_member_in_event returned empty id');
      }

      final response = await _supabase
          .from('event_registration')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
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

  /// Inscrição pública (visitante sem login) via link compartilhável
  Future<String> registerGuest({
    required String eventId,
    required String guestName,
    required String guestEmail,
    String? guestPhone,
  }) async {
    final res = await _supabase.rpc(
      'register_event_guest',
      params: {
        'p_tenant_id': SupabaseConstants.currentTenantId,
        'p_event_id': eventId,
        'p_guest_name': guestName,
        'p_guest_email': guestEmail,
        'p_guest_phone': guestPhone,
      },
    );
    return (res as String?) ?? res.toString();
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
          .update({'checked_in_at': DateTime.now().toIso8601String()})
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
          .update({'checked_in_at': null})
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
