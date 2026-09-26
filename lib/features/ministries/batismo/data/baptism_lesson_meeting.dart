import '../domain/models/baptism_meeting.dart';
import 'baptism_repository.dart';

/// A aula do Batismo vista pela chamada: o suficiente para abrir o encontro
/// dela, sem o módulo do Batismo depender do modelo de `study_lessons`.
typedef BaptismLessonRef = ({
  String lessonId,
  int lessonNumber,
  String title,
  DateTime? scheduledDate,
});

/// Nome do encontro que nasce da aula: "Aula 3 · O batismo nas Escrituras".
String baptismLessonMeetingTitle(BaptismLessonRef lesson) =>
    'Aula ${lesson.lessonNumber} · ${lesson.title.trim()}';

/// Acha o encontro da aula ou, quando ainda não existe, cria (Etapa 5.3).
///
/// Desde 26/09 a presença do Batismo é registrada pela aula: o encontro
/// avulso acabou e o banco recusa encontro novo sem `study_lesson_id`.
///
/// - Existe: devolve. Se a aula mudou de nome ou de data depois e quem abre
///   pode editar ([canEdit]), o encontro é alinhado — é ele que aparece na
///   aba Presença e na frequência do aluno.
/// - Não existe e [canCreate] é `false`: devolve `null`; a tela diz que a
///   chamada ainda não foi aberta, em vez de tentar e bater na RLS.
/// - Duas pessoas abrindo a mesma aula ao mesmo tempo: a segunda bate no
///   UNIQUE (`study_lesson_id`, 23505) e relê o encontro que a primeira
///   criou.
///
/// Aula sem data vira encontro de hoje: `meeting_date` é `NOT NULL`, e a
/// chamada normalmente é feita no dia.
Future<BaptismMeeting?> ensureBaptismLessonMeeting(
  BaptismRepository repo, {
  required String turmaId,
  required BaptismLessonRef lesson,
  required bool canCreate,
  required bool canEdit,
  DateTime? today,
}) async {
  final title = baptismLessonMeetingTitle(lesson);
  final now = today ?? DateTime.now();
  final date = _day(lesson.scheduledDate ?? now);

  final existing = await repo.getMeetingForLesson(lesson.lessonId);
  if (existing != null) {
    // Sem data na aula, a data do encontro fica como está: foi o dia em que
    // a chamada foi aberta, e "hoje" mudaria a cada vez que alguém abre.
    final wantedDate = lesson.scheduledDate == null ? existing.day : date;
    final stale = existing.title != title || existing.day != wantedDate;
    if (!stale || !canEdit) return existing;
    return repo.updateMeeting(
      existing.copyWith(title: title, meetingDate: wantedDate),
    );
  }

  if (!canCreate) return null;

  try {
    return await repo.createMeeting(
      BaptismMeeting(
        // id, tenant_id e created_at são do banco; o INSERT leva só o que
        // toWriteJson() monta.
        id: '',
        tenantId: '',
        turmaId: turmaId,
        meetingDate: date,
        title: title,
        createdAt: now,
        studyLessonId: lesson.lessonId,
      ),
    );
  } catch (error) {
    if (!'$error'.contains('23505')) rethrow;
    final raced = await repo.getMeetingForLesson(lesson.lessonId);
    if (raced != null) return raced;
    // 23505 sem encontro da aula: é o outro UNIQUE, (turma, dia, título) —
    // um encontro antigo com o mesmo nome no mesmo dia.
    rethrow;
  }
}

/// `DateTime.parse` de um `timestamptz` devolve UTC; a data de parede já é
/// a parte de data dele (contrato parede-como-UTC). Nunca `toLocal()` aqui:
/// no Brasil isso jogaria a meia-noite para o dia anterior.
DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
