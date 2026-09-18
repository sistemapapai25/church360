import 'models/baptism_checklist.dart';
import 'models/baptism_student.dart';

/// Quanto do checklist um aluno já cumpriu.
///
/// Camada pura: não fala com Supabase nem com tela, e por isso o cálculo
/// pode ser testado sem subir nada. É o mesmo desenho do
/// `baptism_report_data.dart` da aba Relatórios.
class BaptismStudentProgress {
  final BaptismStudent student;

  /// As etapas que se aplicam a ESTE aluno, na ordem da tela — etapas do
  /// ministério mais as da turma dele, já sem as desligadas.
  final List<BaptismChecklistItem> items;

  /// Ids das etapas que ele cumpriu. Vem do banco: a linha existir é o
  /// "feito".
  final Set<String> doneItemIds;

  const BaptismStudentProgress({
    required this.student,
    required this.items,
    required this.doneItemIds,
  });

  int get total => items.length;

  /// Conta só o que está no denominador: uma marcação de etapa desligada
  /// (ou de outra turma, se o aluno mudou de turma depois de marcada)
  /// continua no banco e **não** infla o progresso.
  int get done => items.where((i) => doneItemIds.contains(i.id)).length;

  /// 0..1. Sem etapa aplicável o progresso é 0, não 1: ninguém "completou"
  /// um checklist que não existe.
  double get ratio => total == 0 ? 0 : done / total;

  bool get isComplete => total > 0 && done == total;

  bool isDone(BaptismChecklistItem item) => doneItemIds.contains(item.id);
}

/// Junta catálogo, alunos e marcações numa lista pronta para a tela.
///
/// [items] pode conter etapas de qualquer turma do ministério e etapas
/// desligadas — a filtragem acontece aqui, num lugar só, para a tela e o
/// resumo nunca discordarem sobre o denominador.
List<BaptismStudentProgress> buildBaptismChecklistProgress({
  required List<BaptismStudent> students,
  required List<BaptismChecklistItem> items,
  required List<BaptismChecklistEntry> entries,
}) {
  final active = items.where((i) => i.isActive).toList()
    ..sort((a, b) {
      final byOrder = a.orderIndex.compareTo(b.orderIndex);
      if (byOrder != 0) return byOrder;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

  final doneByStudent = <String, Set<String>>{};
  for (final entry in entries) {
    doneByStudent.putIfAbsent(entry.studentId, () => <String>{}).add(entry.itemId);
  }

  return [
    for (final student in students)
      BaptismStudentProgress(
        student: student,
        items: [
          for (final item in active)
            if (item.appliesToTurma(student.turmaId)) item,
        ],
        doneItemIds: doneByStudent[student.id] ?? const <String>{},
      ),
  ];
}

/// Progresso por aluno em forma de mapa, para quem só precisa do número.
///
/// É o que a aba Alunos consome: ela mostra "3/5" no card sem carregar a
/// máquina toda do checklist.
Map<String, ({int done, int total})> baptismChecklistTallyByStudent(
  List<BaptismStudentProgress> progress,
) {
  return {
    for (final p in progress) p.student.id: (done: p.done, total: p.total),
  };
}
