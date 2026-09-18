import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
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
        .select('*, event(name, start_date)')
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
        .select('*, event(name, start_date)')
        .single();

    return BaptismTurma.fromJson(Map<String, dynamic>.from(response));
  }

  Future<BaptismTurma> updateTurma(BaptismTurma turma) async {
    final response = await _supabase
        .from('baptism_turma')
        .update(turma.toWriteJson())
        .eq('id', turma.id)
        .select('*, event(name, start_date)')
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
}
