import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/models/baptism_member_suggestion.dart';
import '../domain/models/baptism_public_info.dart';
import '../domain/models/baptism_student.dart';
import '../domain/models/baptism_turma.dart';

final baptismRepositoryProvider = Provider<BaptismRepository>((ref) {
  return BaptismRepository(Supabase.instance.client);
});

/// Acesso às duas tabelas do módulo: `baptism_turma` e `baptism_student`.
///
/// Toda consulta filtra por `tenant_id` mesmo com RLS ligada. A policy é a
/// régua que vale; o filtro aqui é o que evita que uma falha de claim de
/// tenant vire lista de outra igreja na tela.
class BaptismRepository {
  final SupabaseClient _supabase;

  BaptismRepository(this._supabase);

  // -------------------------------------------------------------------
  // Turmas
  // -------------------------------------------------------------------

  /// Turmas de um ministério, mais recentes primeiro.
  Future<List<BaptismTurma>> getTurmas(String ministryId) async {
    final response = await _supabase
        .from('baptism_turma')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('ministry_id', ministryId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => BaptismTurma.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<BaptismTurma> createTurma(BaptismTurma turma) async {
    final payload = turma.toWriteJson()
      ..['tenant_id'] = SupabaseConstants.currentTenantId;

    final response = await _supabase
        .from('baptism_turma')
        .insert(payload)
        .select()
        .single();

    return BaptismTurma.fromJson(Map<String, dynamic>.from(response));
  }

  Future<BaptismTurma> updateTurma(BaptismTurma turma) async {
    final response = await _supabase
        .from('baptism_turma')
        .update(turma.toWriteJson())
        .eq('id', turma.id)
        .select()
        .single();

    return BaptismTurma.fromJson(Map<String, dynamic>.from(response));
  }

  /// Apaga a turma. Os alunos dela vão junto — a FK de `baptism_student`
  /// é `ON DELETE CASCADE`. Quem chama precisa avisar isso na tela.
  Future<void> deleteTurma(String turmaId) async {
    await _supabase.from('baptism_turma').delete().eq('id', turmaId);
  }

  /// Quantos alunos cada turma tem, por `turma_id`.
  ///
  /// Sai de uma consulta só (as turmas do ministério) em vez de um `count`
  /// por turma — a tela mostra o número em cada linha do gerenciador.
  Future<Map<String, int>> getStudentCountByTurma(String ministryId) async {
    final students = await getStudents(ministryId);
    final counts = <String, int>{};
    for (final s in students) {
      counts[s.turmaId] = (counts[s.turmaId] ?? 0) + 1;
    }
    return counts;
  }

  // -------------------------------------------------------------------
  // Alunos
  // -------------------------------------------------------------------

  /// Alunos de todas as turmas de um ministério.
  ///
  /// O `!inner` é o que amarra o aluno ao ministério: `baptism_student` não
  /// tem `ministry_id`, ela chega lá pela turma. Sem `!inner` o filtro do
  /// embed não recortaria nada e a lista viria com o tenant inteiro.
  Future<List<BaptismStudent>> getStudents(String ministryId) async {
    final response = await _supabase
        .from('baptism_student')
        .select('*, baptism_turma!inner(id, name, ministry_id)')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('baptism_turma.ministry_id', ministryId)
        .order('full_name', ascending: true);

    return (response as List)
        .map((row) => BaptismStudent.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<BaptismStudent> createStudent(BaptismStudent student) async {
    final payload = student.toWriteJson()
      ..['tenant_id'] = SupabaseConstants.currentTenantId;

    final response = await _supabase
        .from('baptism_student')
        .insert(payload)
        .select('*, baptism_turma!inner(id, name, ministry_id)')
        .single();

    return BaptismStudent.fromJson(Map<String, dynamic>.from(response));
  }

  Future<BaptismStudent> updateStudent(BaptismStudent student) async {
    final response = await _supabase
        .from('baptism_student')
        .update(student.toWriteJson())
        .eq('id', student.id)
        .select('*, baptism_turma!inner(id, name, ministry_id)')
        .single();

    return BaptismStudent.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> deleteStudent(String studentId) async {
    await _supabase.from('baptism_student').delete().eq('id', studentId);
  }

  // -------------------------------------------------------------------
  // Inscrição pública (sem login)
  // -------------------------------------------------------------------
  //
  // -------------------------------------------------------------------
  // Busca de membro (cadastro de aluno)
  // -------------------------------------------------------------------

  /// Membros do tenant que casam com [query], com telefone, e-mail e
  /// nascimento para o formulário preencher sozinho.
  ///
  /// Passa pela RPC `baptism_member_lookup` porque nenhum dos caminhos
  /// que já existiam serve: o diretório de membros não devolve contato, e
  /// ler `user_account` direto depende da RLS dessa tabela, que olha
  /// `role_global`/`access_level` e não o RBAC — quem lidera o batismo
  /// com `baptism.*` e sem papel elevado veria lista vazia.
  ///
  /// Abaixo de 3 caracteres devolve vazio sem ir à rede; a função no
  /// banco repete a mesma trava, para que uma chamada crua não vire um
  /// dump do diretório.
  Future<List<BaptismMemberSuggestion>> searchMembers({
    required String ministryId,
    required String query,
  }) async {
    if (query.trim().length < 3) return const [];

    final response = await _supabase.rpc(
      'baptism_member_lookup',
      params: {
        'p_ministry_id': ministryId,
        'p_query': query.trim(),
      },
    );

    return (response as List)
        .map((e) =>
            BaptismMemberSuggestion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // Os dois métodos abaixo rodam com a chave anônima, do lado de fora de
  // qualquer sessão: são o que o link de inscrição usa. Nenhum deles toca
  // `baptism_turma` ou `baptism_student` direto — as policies dessas
  // tabelas exigem vínculo no ministério, e afrouxá-las abriria a lista de
  // alunos para a internet. A régua e o recorte ficam nas duas funções
  // SECURITY DEFINER, mesmo desenho do fluxo de convidado dos eventos.

  /// Nome do curso e turmas abertas, para montar o formulário público.
  Future<BaptismPublicInfo> getPublicRegistrationInfo(
    String ministryId,
  ) async {
    final response = await _supabase.rpc(
      'baptism_public_registration_info',
      params: {
        'p_tenant_id': SupabaseConstants.currentTenantId,
        'p_ministry_id': ministryId,
      },
    );

    return BaptismPublicInfo.fromJson(Map<String, dynamic>.from(response));
  }

  /// Grava a inscrição e devolve o id do aluno criado.
  ///
  /// As recusas chegam como `PostgrestException` com o código cru
  /// (`TURMA_REGISTRATION_CLOSED`, `ALREADY_REGISTERED`...). A tradução
  /// para português é da tela, como no resto do projeto.
  Future<String> registerPublicStudent({
    required String ministryId,
    required String turmaId,
    required String fullName,
    required String phone,
    String? email,
    DateTime? birthDate,
  }) async {
    final response = await _supabase.rpc(
      'register_baptism_public',
      params: {
        'p_tenant_id': SupabaseConstants.currentTenantId,
        'p_ministry_id': ministryId,
        'p_turma_id': turmaId,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_email': email,
        'p_birth_date': _dateOnly(birthDate),
      },
    );

    return response is String ? response : '$response';
  }

  /// `birth_date` é `DATE` no banco: mandar um timestamp reintroduziria o
  /// contrato de hora-de-parede que as datas de turma evitam de propósito.
  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }
}
