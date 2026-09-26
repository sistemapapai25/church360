import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../domain/models/baptism_attendance.dart';
import '../domain/models/baptism_checklist.dart';
import '../domain/models/baptism_enrollment.dart';
import '../domain/models/baptism_meeting.dart';
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

  /// Alunos de um ministério — de todas as turmas, ou só de [turmaId].
  ///
  /// O `!inner` é o que amarra o aluno ao ministério: `baptism_student` não
  /// tem `ministry_id`, ela chega lá pela turma. Sem `!inner` o filtro do
  /// embed não recortaria nada e a lista viria com o tenant inteiro.
  ///
  /// Com [turmaId] o recorte é feito no banco (`turma_id`), não na tela: é
  /// o que a tela da turma usa, e ela nunca recebe aluno de outra turma.
  Future<List<BaptismStudent>> getStudents(
    String ministryId, {
    String? turmaId,
  }) async {
    var query = _supabase
        .from('baptism_student')
        .select('*, baptism_turma!inner(id, name, ministry_id)')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('baptism_turma.ministry_id', ministryId);
    if (turmaId != null) query = query.eq('turma_id', turmaId);
    final response = await query.order('full_name', ascending: true);

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

  /// Matrículas do próprio usuário logado (área do aluno).
  ///
  /// Vai pela RPC e não por `baptism_student`: o aluno não tem policy nessa
  /// tabela, que carrega `notes` da liderança (etapa 4 do ROADMAP-FORMACAO).
  Future<List<BaptismEnrollment>> getMyEnrollments() async {
    final response = await _supabase.rpc('my_baptism_enrollments');
    return (response as List)
        .map((j) => BaptismEnrollment.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

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

  // -------------------------------------------------------------------
  // Checklist — catálogo de etapas
  // -------------------------------------------------------------------

  /// Etapas do ministério, ativas e desligadas.
  ///
  /// Traz as desligadas de propósito: quem administra precisa vê-las para
  /// reativar. Quem filtra é a camada de progresso, num lugar só.
  Future<List<BaptismChecklistItem>> getChecklistItems(
    String ministryId,
  ) async {
    final response = await _supabase
        .from('baptism_checklist_item')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('ministry_id', ministryId)
        .order('order_index', ascending: true)
        .order('title', ascending: true);

    return (response as List)
        .map((row) =>
            BaptismChecklistItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<BaptismChecklistItem> createChecklistItem(
    BaptismChecklistItem item,
  ) async {
    final payload = item.toWriteJson()
      ..['tenant_id'] = SupabaseConstants.currentTenantId;

    final response = await _supabase
        .from('baptism_checklist_item')
        .insert(payload)
        .select()
        .single();

    return BaptismChecklistItem.fromJson(Map<String, dynamic>.from(response));
  }

  Future<BaptismChecklistItem> updateChecklistItem(
    BaptismChecklistItem item,
  ) async {
    final response = await _supabase
        .from('baptism_checklist_item')
        .update(item.toWriteJson())
        .eq('id', item.id)
        .select()
        .single();

    return BaptismChecklistItem.fromJson(Map<String, dynamic>.from(response));
  }

  /// Apaga a etapa do catálogo.
  ///
  /// As marcações dos alunos vão junto (`ON DELETE CASCADE` em
  /// `baptism_student_checklist.item_id`) — é irreversível. A tela oferece
  /// desligar antes de apagar justamente por isso.
  Future<void> deleteChecklistItem(String itemId) async {
    await _supabase.from('baptism_checklist_item').delete().eq('id', itemId);
  }

  // -------------------------------------------------------------------
  // Checklist — marcações dos alunos
  // -------------------------------------------------------------------

  /// Marcações dos alunos informados.
  ///
  /// Recebe os ids em vez de filtrar por ministério dentro de um embed de
  /// dois níveis (`marcação → aluno → turma → ministry_id`): a tela já tem
  /// a lista de alunos carregada, e um filtro sobre embed aninhado depende
  /// de detalhe de versão do PostgREST — quando ele falha, falha devolvendo
  /// lista errada, não erro.
  Future<List<BaptismChecklistEntry>> getChecklistEntries(
    List<String> studentIds,
  ) async {
    if (studentIds.isEmpty) return const [];

    final response = await _supabase
        .from('baptism_student_checklist')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .inFilter('student_id', studentIds);

    return (response as List)
        .map((row) =>
            BaptismChecklistEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Marca etapas cumpridas.
  ///
  /// `onConflict` é obrigatório e não é zelo: sem ele o PostgREST infere a
  /// PK, o upsert vira INSERT e estoura 409 na UNIQUE `(student_id,
  /// item_id)` — foi o que quebrou o lote do CHU-317 em produção. Marcar a
  /// mesma etapa duas vezes precisa ser inofensivo, porque dois toques
  /// seguidos acontecem.
  Future<void> markChecklistItems(
    List<({String studentId, String itemId})> marks,
  ) async {
    if (marks.isEmpty) return;

    await _supabase.from('baptism_student_checklist').upsert(
      [
        for (final mark in marks)
          {
            'tenant_id': SupabaseConstants.currentTenantId,
            'student_id': mark.studentId,
            'item_id': mark.itemId,
          },
      ],
      onConflict: 'student_id,item_id',
      ignoreDuplicates: true,
    );
  }

  /// Desmarca uma etapa: apaga a linha.
  ///
  /// Pede `baptism.edit` no banco, não `baptism.delete` — desmarcar é a
  /// outra metade de marcar, e separar as duas deixaria a marcação
  /// irreversível para a maioria dos cargos.
  Future<void> unmarkChecklistItem({
    required String studentId,
    required String itemId,
  }) async {
    await _supabase
        .from('baptism_student_checklist')
        .delete()
        .eq('student_id', studentId)
        .eq('item_id', itemId);
  }

  // -------------------------------------------------------------------
  // Presença — encontros
  // -------------------------------------------------------------------

  /// Encontros das turmas informadas, do mais recente para o mais antigo.
  ///
  /// Recebe os ids das turmas em vez de filtrar por `ministry_id` dentro
  /// de um embed (`encontro → turma → ministry_id`) pela mesma razão de
  /// [getChecklistEntries]: filtro sobre embed aninhado depende de detalhe
  /// de versão do PostgREST e, quando falha, falha devolvendo lista
  /// errada em vez de erro. `baptism_meeting` não duplica `ministry_id` —
  /// a cadeia é encontro → turma → ministério, igual à do helper de RLS.
  Future<List<BaptismMeeting>> getMeetings(List<String> turmaIds) async {
    if (turmaIds.isEmpty) return const [];

    final response = await _supabase
        .from('baptism_meeting')
        .select('*, baptism_turma(name)')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .inFilter('turma_id', turmaIds)
        .order('meeting_date', ascending: false);

    return (response as List)
        .map((row) => BaptismMeeting.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<BaptismMeeting> createMeeting(BaptismMeeting meeting) async {
    final payload = meeting.toWriteJson()
      ..['tenant_id'] = SupabaseConstants.currentTenantId;

    final response = await _supabase
        .from('baptism_meeting')
        .insert(payload)
        .select('*, baptism_turma(name)')
        .single();

    return BaptismMeeting.fromJson(Map<String, dynamic>.from(response));
  }

  Future<BaptismMeeting> updateMeeting(BaptismMeeting meeting) async {
    final response = await _supabase
        .from('baptism_meeting')
        .update(meeting.toWriteJson())
        .eq('id', meeting.id)
        .select('*, baptism_turma(name)')
        .single();

    return BaptismMeeting.fromJson(Map<String, dynamic>.from(response));
  }

  /// Apaga o encontro. A chamada dele vai junto
  /// (`ON DELETE CASCADE` em `baptism_attendance.meeting_id`).
  Future<void> deleteMeeting(String meetingId) async {
    await _supabase.from('baptism_meeting').delete().eq('id', meetingId);
  }

  // -------------------------------------------------------------------
  // Presença — a chamada
  // -------------------------------------------------------------------

  /// Marcações dos encontros informados.
  Future<List<BaptismAttendance>> getAttendance(
    List<String> meetingIds,
  ) async {
    if (meetingIds.isEmpty) return const [];

    final response = await _supabase
        .from('baptism_attendance')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .inFilter('meeting_id', meetingIds);

    return (response as List)
        .map((row) => BaptismAttendance.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Grava a chamada — a turma inteira numa operação só.
  ///
  /// `onConflict` é obrigatório e não é zelo: sem ele o PostgREST infere a
  /// PK, o upsert vira INSERT e estoura 409 na UNIQUE
  /// `(meeting_id, student_id)` — foi o que quebrou o lote do CHU-317 em
  /// produção.
  ///
  /// Diferente de [markChecklistItems], aqui **não** entra
  /// `ignoreDuplicates`: no checklist a linha só existe ou não existe, e
  /// remarcar não muda nada; aqui a linha carrega um `status`, e trocar
  /// "faltou" por "presente" é justamente reescrever uma linha que já
  /// existe. Com `ignoreDuplicates: true` a correção seria engolida em
  /// silêncio.
  Future<void> markAttendance(
    List<({String meetingId, String studentId, BaptismAttendanceStatus status})>
        marks,
  ) async {
    if (marks.isEmpty) return;

    await _supabase.from('baptism_attendance').upsert(
      [
        for (final mark in marks)
          {
            'tenant_id': SupabaseConstants.currentTenantId,
            'meeting_id': mark.meetingId,
            'student_id': mark.studentId,
            'status': mark.status.code,
          },
      ],
      onConflict: 'meeting_id,student_id',
    );
  }

  /// Desmarca um aluno: apaga a linha, devolvendo-o a "não-marcado".
  ///
  /// Pede `baptism.edit` no banco, não `baptism.delete` — desmarcar é a
  /// outra metade de marcar, e separar as duas deixaria a chamada
  /// irreversível para a maioria dos cargos.
  ///
  /// Apagar é diferente de marcar `ausente`: quem faltou tem linha; quem
  /// foi desmarcado volta a não ter nenhuma.
  Future<void> unmarkAttendance({
    required String meetingId,
    required String studentId,
  }) async {
    await _supabase
        .from('baptism_attendance')
        .delete()
        .eq('meeting_id', meetingId)
        .eq('student_id', studentId);
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
