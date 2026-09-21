/// A presença de um aluno num encontro (`public.baptism_attendance`).
///
/// **Ausência de linha não é ausência do aluno.** Sem linha o aluno está
/// *não-marcado*: ninguém passou por ele ainda. Quem faltou tem linha com
/// `status = ausente`. A diferença é o que permite cadastrar um aluno
/// depois do encontro sem que o sistema o acuse de ter faltado a uma aula
/// anterior à matrícula dele.
///
/// Desmarcar apaga a linha, e é por isso que o DELETE desta tabela pede
/// `baptism.edit` e não `baptism.delete`: marcar e desmarcar são a mesma
/// ação vista dos dois lados.
class BaptismAttendance {
  final String id;
  final String tenantId;
  final String meetingId;
  final String studentId;
  final BaptismAttendanceStatus status;
  final DateTime markedAt;

  /// `auth.uid()` de quem marcou — não `user_account.id`. As duas
  /// convenções convivem neste banco.
  final String? markedBy;

  final String? notes;

  const BaptismAttendance({
    required this.id,
    required this.tenantId,
    required this.meetingId,
    required this.studentId,
    required this.status,
    required this.markedAt,
    this.markedBy,
    this.notes,
  });

  factory BaptismAttendance.fromJson(Map<String, dynamic> json) {
    return BaptismAttendance(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      meetingId: json['meeting_id'] as String,
      studentId: json['student_id'] as String,
      status: BaptismAttendanceStatus.fromCode(json['status'] as String?),
      markedAt: DateTime.tryParse('${json['marked_at']}') ?? DateTime.now(),
      markedBy: json['marked_by'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// Os três estados de uma presença — espelham o CHECK
/// `baptism_attendance_status_valido`.
///
/// Um valor fora desta lista é rejeitado pelo banco, então [fromCode] cai
/// em [presente] em vez de estourar. É `text` com CHECK no banco, e não
/// enum: enum novo exigiria `ALTER TYPE` a cada valor futuro.
enum BaptismAttendanceStatus {
  presente('presente', 'Presente'),
  ausente('ausente', 'Faltou'),
  justificado('justificado', 'Justificado');

  final String code;
  final String label;

  const BaptismAttendanceStatus(this.code, this.label);

  static BaptismAttendanceStatus fromCode(String? code) {
    return BaptismAttendanceStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => BaptismAttendanceStatus.presente,
    );
  }
}
