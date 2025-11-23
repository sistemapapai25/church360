import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/member.dart';

/// Repository de Membros
/// Responsável por toda comunicação com a tabela 'user_account' no Supabase
class MembersRepository {
  final SupabaseClient _supabase;

  MembersRepository(this._supabase);

  /// Buscar todos os membros (excluindo visitantes)
  Future<List<Member>> getAllMembers() async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .inFilter('status', ['new_convert', 'member_active', 'member_inactive', 'transferred', 'deceased'])
          .order('first_name', ascending: true);

      return (response as List)
          .map((json) => Member.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membro por ID
  Future<Member?> getMemberById(String id) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .eq('id', id)
          .maybeSingle();

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
          .maybeSingle();

      debugPrint('📦 [MembersRepository] Resposta: $response');

      if (response == null) {
        debugPrint('❌ [MembersRepository] Nenhum usuário encontrado');
        return null;
      }

      final member = Member.fromJson(response);
      debugPrint('✅ [MembersRepository] Usuário encontrado: ${member.firstName} ${member.lastName} (${member.status})');
      return member;
    } catch (e, stackTrace) {
      debugPrint('❌ [MembersRepository] ERRO ao buscar usuário: $e');
      debugPrint('Stack trace: $stackTrace');
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
          .order('first_name', ascending: true);

      return (response as List)
          .map((json) => Member.fromJson(json))
          .toList();
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
          .insert(member.toJson())
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
      data = {
        ...data,
        'created_by': data['created_by'] ?? _supabase.auth.currentUser?.id,
        'status': data['status'] ?? 'visitor',
        'id': data['id'] ?? const Uuid().v4(),
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
      final response = await _supabase
          .from('user_account')
          .update(member.toJson())
          .eq('id', member.id)
          .select()
          .single();

      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar membro
  Future<void> deleteMember(String id) async {
    try {
      await _supabase.from('user_account').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros por nome (pesquisa)
  Future<List<Member>> searchMembers(String query) async {
    try {
      final response = await _supabase
          .from('user_account')
          .select()
          .or('first_name.ilike.%$query%,last_name.ilike.%$query%')
          .order('first_name', ascending: true);

      return (response as List)
          .map((json) => Member.fromJson(json))
          .toList();
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
          .order('birthdate', ascending: true); // Ordenar por idade (mais velho primeiro)

      return (response as List)
          .map((json) => Member.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
