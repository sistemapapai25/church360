import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/member.dart';

/// Repository de Membros
/// Responsável por toda comunicação com a tabela 'member' no Supabase
class MembersRepository {
  final SupabaseClient _supabase;

  MembersRepository(this._supabase);

  /// Buscar todos os membros
  Future<List<Member>> getAllMembers() async {
    try {
      final response = await _supabase
          .from('member')
          .select()
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
          .from('member')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros por status
  Future<List<Member>> getMembersByStatus(String status) async {
    try {
      final response = await _supabase
          .from('member')
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
          .from('member')
          .insert(member.toJson())
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
          .from('member')
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
      await _supabase.from('member').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros por nome (pesquisa)
  Future<List<Member>> searchMembers(String query) async {
    try {
      final response = await _supabase
          .from('member')
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
          .from('member')
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
          .from('member')
          .select()
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }
}

