import 'models/baptism_attendance.dart';
import 'models/baptism_meeting.dart';
import 'models/baptism_student.dart';

/// A chamada de um encontro: o encontro, quem deveria estar lá, e o que
/// já foi marcado de cada um.
///
/// Camada pura: não fala com Supabase nem com tela, e por isso a regra
/// pode ser testada sem subir nada. Mesmo desenho do
/// `baptism_checklist_progress.dart` e do `baptism_report_data.dart`.
class BaptismMeetingRoll {
  final BaptismMeeting meeting;

  /// Os alunos da turma do encontro, na ordem da tela.
  final List<BaptismStudent> students;

  /// O que foi marcado, por `studentId`. Aluno **ausente deste mapa** está
  /// não-marcado — não é a mesma coisa que ter faltado.
  final Map<String, BaptismAttendanceStatus> statusByStudent;

  const BaptismMeetingRoll({
    required this.meeting,
    required this.students,
    required this.statusByStudent,
  });

  /// Total de alunos na turma do encontro.
  int get total => students.length;

  int _count(BaptismAttendanceStatus status) => students
      .where((s) => statusByStudent[s.id] == status)
      .length;

  int get present => _count(BaptismAttendanceStatus.presente);
  int get absent => _count(BaptismAttendanceStatus.ausente);
  int get justified => _count(BaptismAttendanceStatus.justificado);

  /// Quantos ainda não foram tocados.
  ///
  /// Conta os alunos SEM linha, nunca os com `ausente` — um encontro
  /// recém-criado tem a turma inteira aqui, e é isso que distingue
  /// "chamada não feita" de "ninguém veio".
  int get unmarked => students.where((s) => !statusByStudent.containsKey(s.id)).length;

  /// A chamada foi feita? Só quando ninguém sobrou sem marca.
  ///
  /// Turma vazia devolve `false`: não há chamada a fazer, e dizer que
  /// está pronta faria um encontro sem aluno parecer conferido.
  bool get isComplete => total > 0 && unmarked == 0;

  /// Ninguém marcado ainda. Separa "chamada em branco" de "chamada com
  /// falta", que a tela mostra de formas diferentes.
  bool get isUntouched => unmarked == total;

  BaptismAttendanceStatus? statusOf(BaptismStudent student) =>
      statusByStudent[student.id];
}

/// Junta encontros, alunos e marcações numa lista pronta para a tela.
///
/// [students] são os alunos de TODAS as turmas do ministério; cada
/// encontro fica só com os da turma dele. A filtragem acontece aqui, num
/// lugar só, para a tela e os contadores nunca discordarem.
///
/// A ordem é do encontro mais recente para o mais antigo: a chamada que
/// interessa é quase sempre a da última aula.
List<BaptismMeetingRoll> buildBaptismMeetingRolls({
  required List<BaptismMeeting> meetings,
  required List<BaptismStudent> students,
  required List<BaptismAttendance> attendance,
}) {
  final studentsByTurma = <String, List<BaptismStudent>>{};
  for (final student in students) {
    studentsByTurma.putIfAbsent(student.turmaId, () => []).add(student);
  }
  for (final list in studentsByTurma.values) {
    list.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

  final byMeeting = <String, Map<String, BaptismAttendanceStatus>>{};
  for (final row in attendance) {
    byMeeting.putIfAbsent(row.meetingId, () => {})[row.studentId] = row.status;
  }

  final ordered = [...meetings]..sort((a, b) {
      final byDate = b.day.compareTo(a.day);
      if (byDate != 0) return byDate;
      // Dois encontros no mesmo dia (manhã e noite) são permitidos pelo
      // UNIQUE do banco. O título desempata para a ordem não depender da
      // ordem de inserção.
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

  return [
    for (final meeting in ordered)
      BaptismMeetingRoll(
        meeting: meeting,
        students: studentsByTurma[meeting.turmaId] ?? const [],
        statusByStudent:
            byMeeting[meeting.id] ?? const <String, BaptismAttendanceStatus>{},
      ),
  ];
}
