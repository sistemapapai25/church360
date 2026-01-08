import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/member.dart';

/// Repository de Membros
/// Responsável por toda comunicação com a tabela 'user_account' no Supabase
class MembersRepository {
  final SupabaseClient _supabase;

  MembersRepository(this._supabase);

  Map<String, dynamic>? _pickBestMemberRow(List<dynamic> rows) {
    if (rows.isEmpty) return null;

    int statusScore(String? status) {
      switch ((status ?? '').trim()) {
        case 'member_active':
          return 4;
        case 'member_inactive':
          return 3;
        case 'visitor':
          return 1;
        default:
          return 0;
      }
    }

    int rowScore(Map<String, dynamic> r) {
      final isActive = (r['is_active'] == true) ? 1 : 0;
      final status = statusScore(r['status']?.toString());
      final fullName = (r['full_name']?.toString() ?? '').trim().isNotEmpty ? 1 : 0;
      return (isActive * 100) + (status * 10) + fullName;
    }

    Map<String, dynamic> best = Map<String, dynamic>.from(rows.first as Map);
    var bestScore = rowScore(best);
    for (final raw in rows.skip(1)) {
      final r = Map<String, dynamic>.from(raw as Map);
      final score = rowScore(r);
      if (score > bestScore) {
        best = r;
        bestScore = score;
      }
    }
    return best;
  }

  Future<String?> _currentMemberId() async {
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

  /// Buscar todos os membros (incluindo visitantes)
  Future<List<Member>> getAllMembers() async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('first_name', ascending: true);

      return (response as List).map((json) => Member.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membro por ID
  Future<Member?> getMemberById(String id) async {
    try {
      var response = await _supabase
          .from('user_account')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      response ??= await _supabase.from('user_account').select().eq('id', id).maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membro por email
  Future<Member?> getMemberByEmail(String email) async {
    try {
      debugPrint('🔍 [MembersRepository] Buscando usuário com email: $email');

      final response = await _supabase
          .from('user_account')
          .select()
          .eq('email', email)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      debugPrint('📦 [MembersRepository] Resposta: $response');

      if (response == null) {
        debugPrint('❌ [MembersRepository] Nenhum usuário encontrado');
        return null;
      }

      final member = Member.fromJson(response);
      debugPrint(
        '✅ [MembersRepository] Usuário encontrado: ${member.firstName} ${member.lastName} (${member.status})',
      );
      return member;
    } catch (e, stackTrace) {
      debugPrint('❌ [MembersRepository] ERRO ao buscar usuário: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Buscar membro por auth_user_id
  Future<Member?> getMemberByAuthUserId(String authUserId) async {
    try {
      Map<String, dynamic>? response;
      try {
        final rows = await _supabase
            .from('user_account')
            .select()
            .eq('auth_user_id', authUserId)
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .limit(10);
        if (rows.isNotEmpty) {
          response = _pickBestMemberRow(rows);
        }
      } catch (e) {
        final msg = e.toString();
        final missingAuthUserId = msg.contains('auth_user_id') &&
            (msg.contains('PGRST204') || msg.toLowerCase().contains('does not exist') || msg.toLowerCase().contains('column'));
        if (!missingAuthUserId) rethrow;
      }

      if (response == null) {
        try {
          final rows = await _supabase
              .from('user_account')
              .select()
              .eq('auth_user_id', authUserId)
              .limit(10);
          if (rows.isNotEmpty) {
            response = _pickBestMemberRow(rows);
          }
        } catch (_) {}
      }

      response ??= await _supabase
          .from('user_account')
          .select()
          .eq('id', authUserId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      response ??= await _supabase.from('user_account').select().eq('id', authUserId).maybeSingle();

      if (response == null) return null;
      return Member.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros por status
  Future<List<Member>> getMembersByStatus(String status) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('status', status)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('first_name', ascending: true);

      return (response as List).map((json) => Member.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros ativos
  Future<List<Member>> getActiveMembers() async {
    return getMembersByStatus('member_active');
  }

  /// Buscar visitantes
  Future<List<Member>> getVisitors() async {
    return getMembersByStatus('visitor');
  }

  /// Criar novo membro
  Future<Member> createMember(Member member) async {
    try {
      final response = await _supabase
          .from('user_account')
          .insert({
            ...member.toJson(),
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();

      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar novo membro a partir de JSON (sem ID)
  Future<Member> createMemberFromJson(Map<String, dynamic> data) async {
    try {
      final creatorId = await _currentMemberId();
      data = {
        ...data,
        'created_by': data['created_by'] ?? creatorId,
        'status': data['status'] ?? 'visitor',
        'id': data['id'] ?? const Uuid().v4(),
        'tenant_id': SupabaseConstants.currentTenantId,
      };

      final response = await _supabase
          .from('user_account')
          .insert(data)
          .select()
          .single();

      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar membro
  Future<Member> updateMember(Member member) async {
    try {
      final currentAuthId = _supabase.auth.currentUser?.id;
      final currentMemberId = await _currentMemberId();

      int? accessLevelNumber;
      String? roleGlobal;
      if (currentMemberId != null) {
        try {
          final level = await _supabase
              .from('user_access_level')
              .select('access_level_number')
              .eq('user_id', currentMemberId)
              .maybeSingle();
          accessLevelNumber = level?['access_level_number'] as int?;
        } catch (_) {}

        if (currentAuthId != null) {
          try {
            final rg = await _supabase
                .from('user_account')
                .select('role_global')
                .eq('id', currentAuthId)
                .eq('tenant_id', SupabaseConstants.currentTenantId)
                .maybeSingle();
            roleGlobal = rg?['role_global'] as String?;
          } catch (_) {}
        }
      }

      final isElevated = (accessLevelNumber ?? 0) >= 3 ||
          (roleGlobal != null &&
              (roleGlobal == 'owner' ||
                  roleGlobal == 'admin' ||
                  roleGlobal == 'leader'));

      if (!isElevated && currentMemberId != member.id) {
        throw Exception('Sem permissão para editar este membro');
      }

      final raw = Map<String, dynamic>.from(member.toJson());
      raw.remove('created_at');
      raw.remove('id');

      raw['created_by'] ??= currentMemberId;

      if (!isElevated) {
        raw.remove('status');
        raw.remove('member_type');
        raw.remove('membership_date');
        raw.remove('baptism_date');
        raw.remove('conversion_date');
        raw.remove('email');
      }

      final payload = <String, dynamic>{};
      for (final entry in raw.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value == null) continue;
        payload[key] = value;
      }

      final response = await _supabase
          .from('user_account')
          .update(payload)
          .eq('id', member.id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .maybeSingle();

      if (response != null) {
        return Member.fromJson(response);
      }

      throw Exception('Atualização não aplicada (RLS/sem permissões ou registro não encontrado)');
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar membro
  Future<void> deleteMember(String id) async {
    try {
      await _supabase
          .from('user_account')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros por nome (pesquisa)
  Future<List<Member>> searchMembers(String query) async {
    try {
      final q = query.trim();
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .ilike('full_name', '%$q%')
          .order('first_name', ascending: true);

      final members = (response as List).map((json) => Member.fromJson(json)).toList();
      final uniqueById = <String, Member>{};
      for (final m in members) {
        final existing = uniqueById[m.id];
        if (existing == null) {
          uniqueById[m.id] = m;
        } else {
          final hasPhoneExisting = (existing.phone ?? '').trim().isNotEmpty;
          final hasPhoneNew = (m.phone ?? '').trim().isNotEmpty;
          if (!hasPhoneExisting && hasPhoneNew) {
            uniqueById[m.id] = m;
          }
        }
      }
      final deduped = uniqueById.values.toList();
      deduped.sort((a, b) => (a.firstName ?? a.nickname ?? a.fullName ?? '').compareTo(b.firstName ?? b.nickname ?? b.fullName ?? ''));
      return deduped;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar membros por status
  Future<int> countMembersByStatus(String status) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('status', status)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar total de membros
  Future<int> countAllMembers() async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros da mesma família (household)
  Future<List<Member>> getHouseholdMembers(String householdId) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('household_id', householdId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order(
            'birthdate',
            ascending: true,
          ); // Ordenar por idade (mais velho primeiro)

      return (response as List).map((json) => Member.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar profissões por nome (autocomplete)
  Future<List<String>> searchProfessions(String query) async {
    try {
      final response = await _supabase
          .from('profissao')
          .select('profissao')
          .ilike('profissao', '%$query%')
          .limit(20);

      return (response as List)
          .map((json) => json['profissao'] as String)
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar profissões: $e');
      return [];
    }
  }

  /// Buscar aniversariantes do mês atual
  Future<List<Member>> getBirthdaysOfMonth() async {
    try {
      final now = DateTime.now();
      
      // Supabase não tem filtro de mês direto fácil no client dart sem usar filters específicos
      // Uma abordagem é usar o filtro .filter() com sintaxe postgrest ou buscar todos e filtrar no client (se forem poucos).
      // Mas para ser eficiente, vamos usar uma RPC se existir, ou raw filter.
      // Como não tenho RPC, vou tentar filtrar com query raw se possível ou buscar todos ativos e filtrar aqui (não ideal para muitos usuários).
      // Melhor abordagem: usar .rpc se criar, ou tentar o filter manual.
      // Dado que não posso criar RPC agora sem script, vou usar o filtro de texto na data.
      // Formato data: YYYY-MM-DD.
      // SQL: extract(month from birthdate) = X.
      // Dart client supporta filtros avançados?
      // Vou buscar todos os membros ativos (que costumam ter data de nascimento) e filtrar em memória por enquanto, 
      // pois é mais seguro do que tentar adivinhar a sintaxe do Postgrest filter complexo sem testar.
      // O ideal seria criar uma RPC 'get_birthdays_of_month'.
      
      // Tentativa de filtro mais otimizado: trazer apenas campos necessários
      final response = await _supabase
          .from('user_account')
          .select('id, full_name, nickname, birthdate, photo_url, phone, show_birthday, show_contact')
          .eq('status', 'member_active')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .not('birthdate', 'is', null);

      final members = (response as List).map((json) => Member.fromJson(json)).toList();
      
      return members.where((m) {
        if (m.birthdate == null) return false;
        // Verifica se é o mês atual
        if (m.birthdate!.month != now.month) return false;
        // Verifica privacidade (se show_birthday for false, não mostra - assumindo default true ou false conforme regra)
        // Regra atual: se show_birthday for false, esconde. Se for null, assume true? 
        // No Member model, bool? showBirthday.
        if (m.showBirthday == false) return false;
        
        return true;
      }).toList()
        ..sort((a, b) => a.birthdate!.day.compareTo(b.birthdate!.day));
        
    } catch (e) {
      debugPrint('Erro ao buscar aniversariantes: $e');
      return [];
    }
  }
    /// Buscar nome da profissão por ID
  Future<String?> getProfessionLabelById(String id) async {
    try {
      // Primeiro tenta pela coluna 'idprofissao' (conforme dados importados)
      final byCode = await _supabase
          .from('profissao')
          .select('profissao')
          .eq('idprofissao', id)
          .maybeSingle();

      if (byCode != null) {
        return byCode['profissao'] as String?;
      }

      // Fallback: tenta pela coluna 'id' caso exista
      try {
        final byId = await _supabase
            .from('profissao')
            .select('profissao')
            .eq('id', id)
            .maybeSingle();
        if (byId != null) {
          return byId['profissao'] as String?;
        }
      } catch (_) {}

      return null;
    } catch (e) {
      try {
        final rpc = await _supabase.rpc('get_profession_label', params: {
          'p_profession_id': id,
        });
        if (rpc is String && rpc.isNotEmpty) return rpc;
      } catch (_) {}
      return null;
    }
  }
}
